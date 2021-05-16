using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class SDFDebugRenderFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class SDFDebugRenderSetting{
        public string passName="SDFTest";
        public Material  material;

        public RenderPassEvent passEvent=RenderPassEvent.AfterRenderingSkybox;

    }

    public SDFDebugRenderSetting m_Setting=new SDFDebugRenderSetting();

    class SDFDebugRenderPass:ScriptableRenderPass{
        SDFDebugRenderSetting renderSetting;

        public RenderTargetIdentifier source{get;set;}

        Matrix4x4 viewFrustumVec4;

        public void setup(RenderTargetIdentifier source){
            this.source=source;
        }

        public SDFDebugRenderPass(SDFDebugRenderSetting setting){
            this.renderSetting=setting;
            renderPassEvent=renderSetting.passEvent;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer command=CommandBufferPool.Get(renderSetting.passName);

            RenderTextureDescriptor opaqueDesc=renderingData.cameraData.cameraTargetDescriptor;

            Camera camera=renderingData.cameraData.camera;

            float height = camera.nearClipPlane * Mathf.Tan(Mathf.Deg2Rad*camera.fieldOfView*0.5f);
            Vector3 up = height * camera.transform.up;
            Vector3 right = camera.transform.right * height * camera.aspect;
            Vector3 forward = camera.transform.forward * camera.nearClipPlane;

            //BottomLeft BL
            //BottomLeft BL
            Vector3 BL = forward - right - up;
            float scale = BL.magnitude / camera.nearClipPlane;
            BL.Normalize();
            BL *= scale;


            Vector3 BR = forward + right - up;
            BR.Normalize();
            BR *= scale;

            Vector3 TR = forward + right + up;
            TR.Normalize();
            TR *= scale;

            Vector3 TL = forward - right + up;
            TL.Normalize();
            TL *= scale;

            viewFrustumVec4.SetRow(0,BL);
            viewFrustumVec4.SetRow(1,BR);
            viewFrustumVec4.SetRow(2,TR);
            viewFrustumVec4.SetRow(3,TL);
            renderSetting.material.SetMatrix("viewFrustumVector4",viewFrustumVec4);

            renderSetting.material.SetMatrix("_InverseP", GL.GetGPUProjectionMatrix(camera.projectionMatrix, false).inverse);
            renderSetting.material.SetMatrix("_InverseV", camera.cameraToWorldMatrix);
            command.Blit(source,source,renderSetting.material,0);

            context.ExecuteCommandBuffer(command);
            CommandBufferPool.Release(command);
        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
            base.FrameCleanup(cmd);
        }
    }

    SDFDebugRenderPass renderPass;
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if(m_Setting.material!=null){
            renderPass.setup(renderer.cameraColorTarget);
            renderer.EnqueuePass(renderPass);
        }
    }

    public override void Create()
    {
        int passCount=m_Setting.material==null?1:m_Setting.material.passCount-1;
        renderPass=new SDFDebugRenderPass(m_Setting);
    }
}
