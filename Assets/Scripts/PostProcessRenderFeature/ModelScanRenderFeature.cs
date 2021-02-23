using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ModelScanRenderFeature :ScriptableRendererFeature
{

    [System.Serializable]
    public class ModelScanRenderSetting
    {
        public string passName = "ModelScanPass";
        public Material material;
        public RenderPassEvent passEvent = RenderPassEvent.AfterRenderingTransparents;


        public int matPassIndex = -1;


    }

    public ModelScanRenderSetting m_Setting = new ModelScanRenderSetting();

    class ModelScanRenderPass : ScriptableRenderPass
    {
        ModelScanRenderSetting renderSetting;

        public FilterMode passFilterMode { get; set; }

        //input
        public RenderTargetIdentifier Source { get; set; }
        Matrix4x4 viewFrustumVector4;

        public RenderTargetHandle resTex;


        public void setup(RenderTargetIdentifier source)
        {
            this.Source = source;
        }

        public ModelScanRenderPass(ModelScanRenderSetting renderSetting)
        {
            this.renderPassEvent = renderSetting.passEvent;
            this.renderSetting = renderSetting;
            this.passFilterMode = FilterMode.Bilinear;


            resTex.Init("passModelScanRT");

        }


        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(renderSetting.passName);
            
            RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;

            Camera camera = renderingData.cameraData.camera;
            float height = camera.nearClipPlane * Mathf.Tan(Mathf.Deg2Rad*camera.fieldOfView*0.5f);
            Vector3 up = height * camera.transform.up;
            Vector3 right = camera.transform.right * height * camera.aspect;
            Vector3 forward = camera.transform.forward*camera.nearClipPlane;

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

            viewFrustumVector4.SetRow(0,BL);
            viewFrustumVector4.SetRow(1,BR);
            viewFrustumVector4.SetRow(2,TR);
            viewFrustumVector4.SetRow(3,TL);
            renderSetting.material.SetMatrix("viewFrustumVector4", viewFrustumVector4);
            
            cmd.GetTemporaryRT(resTex.id, opaqueDesc);
            
            cmd.Blit(Source, resTex.id, renderSetting.material, 0);

            cmd.Blit(resTex.id, Source);
            
            context.ExecuteCommandBuffer(cmd);

            CommandBufferPool.Release(cmd);
        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(resTex.id);
            base.FrameCleanup(cmd);
        }
    }

    ModelScanRenderPass renderPass;

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (m_Setting.material != null)
        {
            renderPass.setup(renderer.cameraColorTarget);
            renderer.EnqueuePass(renderPass);
        }

    }

    public override void Create()
    {
        int passCount = m_Setting.material == null ? 1 : m_Setting.material.passCount - 1;

        m_Setting.matPassIndex = Mathf.Clamp(m_Setting.matPassIndex, -1, passCount);

        renderPass = new ModelScanRenderPass(m_Setting);
    }
}
