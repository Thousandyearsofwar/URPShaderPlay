using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;


namespace UnityEngine.Experimental.Rendering.Universal {

    class AdditionalPostProcessRenderPass : ScriptableRenderPass
    {
        // Volume Render Setting parameter
        ChromaticAberration m_Chromatic;
        RayMarching m_RayMarching;
        SSPR m_SSPR;
        WaterCaustics m_WaterCaustics;

        //Materials and shaders Link Data
        MaterialLibrary m_Material;
        AdditionalPostProcessData m_Data;
        
        //Input RT
        RenderTargetIdentifier input_ColorAttachment;
        RenderTargetIdentifier input_CameraDepthAttachment;

        //WaterCaustics RT
        RenderTargetHandle waterCausticsRT;

        //RayMarching RT
        RenderTargetHandle DownSampleDepthRT;
        RenderTargetHandle DownSampleCloudRT;
        RenderTargetHandle output_Destination_RayMarching;

        //ChromaticAberration LUT
        RenderTexture renderTexture = new RenderTexture(3, 1, 0);
        Texture2D AberrationLUT = new Texture2D(3, 1);
        public RenderTargetHandle aberrationTex;


        //Final Output RT
        RenderTargetIdentifier output_Destination;

        const string RenderPostProcessingTag = "Render AdditionalPostProcessing Effects";
        const string RenderFinalPostProcessingTag = "Render Final AdditionalPostProcessing Effects";
        //WaterCausticsMesh
        private static Mesh m_Mesh;
        public AdditionalPostProcessRenderPass()
        {
            AberrationLUT.SetPixel(0, 0, Color.red);
            AberrationLUT.SetPixel(1, 0, Color.green);
            AberrationLUT.SetPixel(2, 0, Color.blue);
            AberrationLUT.filterMode = FilterMode.Bilinear;
            AberrationLUT.Apply();

            aberrationTex.Init("passChromaticAberrationRT");

            //ChromaticAberration pass RT
            DownSampleDepthRT.Init("RayMarchingPass_DownSampleDepthRT");
            DownSampleCloudRT.Init("RayMarchingPass_DownSampleCloudRT");
            output_Destination_RayMarching.Init("RayMarchingPass_OutPut");

        }

        public void Setup(RenderPassEvent @event,RenderTargetIdentifier source,
            RenderTargetIdentifier cameraDepth, RenderTargetIdentifier destination,AdditionalPostProcessData data,MaterialLibrary m_MaterialLib) {
            m_Data = data;
            renderPassEvent = @event;
            input_ColorAttachment = source;
            input_CameraDepthAttachment = cameraDepth;

            output_Destination = destination;

            m_Material = m_MaterialLib;

        }



        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var stack = VolumeManager.instance.stack;
            m_Chromatic = stack.GetComponent<ChromaticAberration>();
            m_RayMarching = stack.GetComponent<RayMarching>();
            m_SSPR=stack.GetComponent<SSPR>();
            m_WaterCaustics=stack.GetComponent<WaterCaustics>();

            CommandBuffer cmd = CommandBufferPool.Get(RenderPostProcessingTag);

            Render(cmd, ref renderingData);
            context.ExecuteCommandBuffer(cmd);

            CommandBufferPool.Release(cmd);

            
        }


        void Render(CommandBuffer cmd,ref RenderingData renderingData) {
            ref var cameraData = ref renderingData.cameraData;

            if(m_WaterCaustics.IsActive()&&!cameraData.isSceneViewCamera){
                SetupWaterCaustics(cmd,ref renderingData,m_Material.WaterCausticsMat);
            }
            if (m_RayMarching.IsActive() && !cameraData.isSceneViewCamera)
            {
                SetupRayMarching(cmd, ref renderingData, m_Material.RayMarchingMat);
            }
            if (m_SSPR.IsActive()&&!cameraData.isSceneViewCamera){
                SetupSSPR(cmd,ref renderingData,m_SSPR.ComputeShaderParameter.value);
            }
            if (m_Chromatic.IsActive() && !cameraData.isSceneViewCamera) {
                SetupChromaticAberration(cmd,ref renderingData, m_Material.ChromaticMat);
            }
            
        }

        public void SetupChromaticAberration(CommandBuffer cmd, ref RenderingData renderingData, Material mat) {
            RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;

            Camera camera = renderingData.cameraData.camera;

            

            m_Material.ChromaticMat.SetTexture("_AberrationLUT", AberrationLUT);
            m_Material.ChromaticMat.SetFloat("_Intensity", m_Chromatic.Intensity.value);


            cmd.GetTemporaryRT(aberrationTex.id, opaqueDesc);

            cmd.BeginSample("ChromaticAberration");

            cmd.Blit(output_Destination, output_Destination, m_Material.ChromaticMat, 0);

            cmd.EndSample("ChromaticAberration");
        }

        public void SetupRayMarching(CommandBuffer cmd, ref RenderingData renderingData, Material mat) {

            RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;

            Camera camera = renderingData.cameraData.camera;

            m_Material.RayMarchingMat.SetFloat("_Blend", m_RayMarching.blend.value);

            //精度控制
            m_Material.RayMarchingMat.SetFloat("_rayOffsetStrength", m_RayMarching._rayOffsetStrength.value);
            
            m_Material.RayMarchingMat.SetFloat("_step", m_RayMarching._step.value);
            
            m_Material.RayMarchingMat.SetFloat("_rayStep", m_RayMarching._rayStep.value);

            //在亮部光线被吸收
            m_Material.RayMarchingMat.SetFloat("_lightAbsorptionTowardSun", m_RayMarching.lightAbsorptionTowardSun.value);
            //在暗部光线被吸收
            m_Material.RayMarchingMat.SetFloat("_lightAbsorptionTowardCloud", m_RayMarching.lightAbsorptionTowardCloud.value);
            //亮度作为黑暗的阈值
            m_Material.RayMarchingMat.SetFloat("_darknessThreshold", m_RayMarching.darknessThreshold.value);
            
            //亮部的颜色偏移到暗部的大小
            m_Material.RayMarchingMat.SetFloat("_colorOffset1", m_RayMarching.colorOffset1.value);
            //暗部的颜色偏移到亮部的大小
            m_Material.RayMarchingMat.SetFloat("_colorOffset2", m_RayMarching.colorOffset2.value);
            
            //云受到光照的颜色
            m_Material.RayMarchingMat.SetColor("_Color", m_RayMarching.color.value);
            m_Material.RayMarchingMat.SetColor("_ColorA", m_RayMarching.colorA.value);
            m_Material.RayMarchingMat.SetColor("_ColorB", m_RayMarching.colorB.value);

            //噪声图
            m_Material.RayMarchingMat.SetTexture("_NoiseTexture",m_RayMarching.NoiseTexture.value);
            m_Material.RayMarchingMat.SetTexture("_MaskNoise",m_RayMarching._MaskNoiseTexture.value);
            m_Material.RayMarchingMat.SetFloat("_shapeTilling",m_RayMarching._shapeTilling.value);

            //散射
            m_Material.RayMarchingMat.SetVector("_phaseParams",m_RayMarching._phaseParams.value);

            //weather parameter 云的分布参数
            m_Material.RayMarchingMat.SetTexture("_WeatherTexture",m_RayMarching.WeatherTexture.value);
            m_Material.RayMarchingMat.SetVector("_shapeNoiseWeight",m_RayMarching._shapeNoiseWeight.value);
            m_Material.RayMarchingMat.SetFloat("_densityOffset",m_RayMarching._densityOffset.value);
            m_Material.RayMarchingMat.SetFloat("_densityMultiplier",m_RayMarching._densityMultiplier.value);

            //边缘过渡
            m_Material.RayMarchingMat.SetFloat("_containerEdgeFadeDst",m_RayMarching._containerEdgeFadeDst.value);

            //高度Remap
             m_Material.RayMarchingMat.SetFloat("_heightWeights",m_RayMarching._heightWeights.value);

            //细节噪声Detail Noise
            m_Material.RayMarchingMat.SetTexture("_NoiseDetailTexture",m_RayMarching._NoiseDetailTexture.value);
            m_Material.RayMarchingMat.SetFloat("_detailTilling",m_RayMarching._detailTilling.value);
            m_Material.RayMarchingMat.SetFloat("_detailFBMWeights",m_RayMarching._detailFBMWeights.value);
            m_Material.RayMarchingMat.SetFloat("_detailNoiseWeight",m_RayMarching._detailNoiseWeight.value);

            //BlurNoise解决伪影
            m_Material.RayMarchingMat.SetTexture("_BlueNoiseTexture",m_RayMarching.BlueNoise.value);

            //UV滚动速度
            m_Material.RayMarchingMat.SetVector("_Speed_xy_Wrap_zw",m_RayMarching._Speed_xy_Wrap_zw.value);

            //投影矩阵
            m_Material.RayMarchingMat.SetMatrix("_InverseP", GL.GetGPUProjectionMatrix(camera.projectionMatrix, false).inverse);
            m_Material.RayMarchingMat.SetMatrix("_InverseV", camera.cameraToWorldMatrix);

            if (m_RayMarching.rayMarchBox != null) {
                BoxCollider box = m_RayMarching.rayMarchBox;
                m_Material.RayMarchingMat.SetVector("_boundMin", box.transform.position+box.center-box.size/2f);
                m_Material.RayMarchingMat.SetVector("_boundMax", box.transform.position+box.center+box.size/2f);
            }


            cmd.GetTemporaryRT(output_Destination_RayMarching.id, opaqueDesc);

            cmd.BeginSample("RayMarching");
                    int width=renderingData.cameraData.cameraTargetDescriptor.width;
                    int height=renderingData.cameraData.cameraTargetDescriptor.height;
                    //深度降采样 Undo:会造成边缘锯齿，需要检测边缘，对边缘像素使用原深度计算体积云
                    cmd.GetTemporaryRT(DownSampleDepthRT.id,width/4,height/4,0,FilterMode.Point,RenderTextureFormat.R16);
                    cmd.Blit(input_ColorAttachment,DownSampleDepthRT.Identifier(), m_Material.RayMarchingMat, 1);

                    //渲染云
                    cmd.GetTemporaryRT(DownSampleCloudRT.id,width,height,0,FilterMode.Trilinear,RenderTextureFormat.ARGB32);
                    cmd.SetGlobalTexture(Shader.PropertyToID("_DownSampleDepthTexture"),DownSampleDepthRT.Identifier());
                    cmd.Blit(input_ColorAttachment, DownSampleCloudRT.Identifier(), m_Material.RayMarchingMat, 0);
                    
                    //合成
                    //cmd.GetTemporaryRT(DownSampleDepthRT.id,width,height,0,FilterMode.Bilinear,RenderTextureFormat.ARGB32);
                    cmd.SetGlobalTexture(Shader.PropertyToID("_SampleCloudColor"),DownSampleCloudRT.Identifier());
                    cmd.Blit(input_ColorAttachment, output_Destination, m_Material.RayMarchingMat, 2);    
            cmd.EndSample("RayMarching");
        }

        public void SetupSSPR(CommandBuffer cmd,ref RenderingData renderingData,ComputeShader CS){
            
        }

        public void SetupWaterCaustics(CommandBuffer cmd, ref RenderingData renderingData, Material mat){
            RenderTextureDescriptor opaqueDesc=renderingData.cameraData.cameraTargetDescriptor;
            Camera camera=renderingData.cameraData.camera;

            m_Material.WaterCausticsMat.SetFloat("_WaterHeight",m_WaterCaustics.WaterHeight.value);
            m_Material.WaterCausticsMat.SetFloat("_BlendDistance",m_WaterCaustics.BlendDistance.value);
            m_Material.WaterCausticsMat.SetFloat("_CausticsScale",m_WaterCaustics.CausticsScale.value);
            m_Material.WaterCausticsMat.SetTexture("_CausticsTexture",m_WaterCaustics.CausticsTexture.value);

            var _LightSpaceMat=RenderSettings.sun!=null?
                RenderSettings.sun.transform.localToWorldMatrix:
                Matrix4x4.TRS(Vector3.zero,Quaternion.Euler(-45.0f,45.0f,0.0f),Vector3.one);
                
             m_Material.WaterCausticsMat.SetMatrix("_MainLightSpaceMat",_LightSpaceMat);


            if(m_WaterCaustics.mode.value==DebugMode.Debug){
                m_Material.WaterCausticsMat.EnableKeyword("_DEBUG");
            }else
            {
                m_Material.WaterCausticsMat.DisableKeyword("_DEBUG");
            }


            cmd.BeginSample("WaterCaustics");
                if(!m_Mesh)
                    m_Mesh=GenerateCausticsMesh(1000f);
                var position=camera.transform.position;
                position.y=0;
                var matrix=Matrix4x4.TRS(position,Quaternion.identity,Vector3.one);

                cmd.DrawMesh(m_Mesh,matrix,m_Material.WaterCausticsMat,0,0);
                //cmd.Blit(output_Destination,output_Destination,m_Material.WaterCausticsMat,0);
            cmd.EndSample("WaterCaustics");

        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
            
            cmd.ReleaseTemporaryRT(waterCausticsRT.id);
            cmd.ReleaseTemporaryRT(output_Destination_RayMarching.id);
            cmd.ReleaseTemporaryRT(DownSampleCloudRT.id);
            cmd.ReleaseTemporaryRT(DownSampleCloudRT.id);

            cmd.ReleaseTemporaryRT(aberrationTex.id);

            base.FrameCleanup(cmd);
        }

        private static Mesh GenerateCausticsMesh(float size){
            var mesh=new Mesh();
            size*=0.5f;

            var verts=new [] {
                new Vector3(-size,0f,-size),
                new Vector3(size,0f,-size),
                new Vector3(-size,0f,size),
                new Vector3(size,0f,size),
            };
            mesh.vertices=verts;

            var tris=new[]{
                0,2,1,
                2,3,1
            };
            mesh.triangles=tris;

            return mesh;
        }


    }
}

