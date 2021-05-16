using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;


public class FogRenderFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class FogRenderSetting {
        public string passName = "FogRenderPass";

        public Material material;
        public RenderPassEvent passEvent = RenderPassEvent.AfterRenderingTransparents;

        public int matPassIndex = -1;

    }

    public FogRenderSetting m_RenderSetting=new FogRenderSetting();

    class FogRenderPass : ScriptableRenderPass
    {
        FogRenderSetting renderSetting;

        //input
        public RenderTargetIdentifier source { get; set; }
        Matrix4x4 viewFrustumVec4;


        public void setup(RenderTargetIdentifier source) {
            this.source = source;
        }

        public FogRenderPass(FogRenderSetting renderSetting) {
            
            this.renderSetting = renderSetting;

        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd=CommandBufferPool.Get(renderSetting.passName);

            RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;

            Camera camera = renderingData.cameraData.camera;
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

            cmd.Blit(source, source, renderSetting.material, 0); 
            
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
            
            base.FrameCleanup(cmd);
        }

    }

    FogRenderPass renderPass;

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (m_RenderSetting.material != null) {
            renderPass.setup(renderer.cameraColorTarget);
            renderer.EnqueuePass(renderPass);
        }
    }

    public override void Create()
    {
        int passCount = m_RenderSetting.material == null ? 1 : m_RenderSetting.material.passCount - 1;
        m_RenderSetting.matPassIndex = Mathf.Clamp(m_RenderSetting.matPassIndex,-1,passCount);

        renderPass = new FogRenderPass(m_RenderSetting);
        
    }
}
