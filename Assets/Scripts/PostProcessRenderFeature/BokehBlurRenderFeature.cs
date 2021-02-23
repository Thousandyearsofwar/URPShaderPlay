using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class BokehBlurRenderFeature : ScriptableRendererFeature
{

    [System.Serializable]
    public class BokehBlurRenderSetting {
        public string passName = "BokehBlurPass";
        public Material material;

        [Range(8, 128)] public int loop=50;
        [Range(0, 3)] public float blurRadius=1;

        [Range(0, 0.5f)] public float blurSmoothness = 0.1f;


        [Range(-1, 1)] public float Offset_X = 0f;
        [Range(-1, 1)] public float Offset_Y = 0f;

        [Range(0, 1)] public float AreaSize = 0.5f;

        [Range(1, 20)] public float Spread = 0.5f;

        [Range(2, 10)] public int downSample = 2;
        public RenderPassEvent passEvent = RenderPassEvent.AfterRenderingTransparents;

        public int matPassIndex = -1;


    }

    public BokehBlurRenderSetting m_Setting = new BokehBlurRenderSetting();

    class BokehBlurRenderPass : ScriptableRenderPass
    {
        BokehBlurRenderSetting renderSetting;

        public FilterMode passFilterMode { get; set; }
        public RenderTargetIdentifier Source { get; set; }

        public RenderTargetHandle blurTex;

        int ssW;
        int ssH;
        Vector4 GoldenRot = new Vector4();

        public void setup(RenderTargetIdentifier source) {
            this.Source = source;
        }

        public BokehBlurRenderPass(BokehBlurRenderSetting renderSetting) {
            this.renderPassEvent = renderSetting.passEvent;
            this.renderSetting = renderSetting;
            this.passFilterMode = FilterMode.Bilinear;

            float c = Mathf.Cos(2.39996323f);
            float s = Mathf.Sin(2.39996323f);
            GoldenRot.Set(c,s,-s,c);
            
            blurTex.Init("passBlurColorRT");

        }


        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(renderSetting.passName);

            RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;
            ssW = opaqueDesc.width / renderSetting.downSample;
            ssH = opaqueDesc.height / renderSetting.downSample;

            cmd.GetTemporaryRT(blurTex.id,ssW,ssH,0,passFilterMode,RenderTextureFormat.ARGB32);

            cmd.SetGlobalVector(Shader.PropertyToID("_GoldenRot"), GoldenRot);
            cmd.SetGlobalFloat(Shader.PropertyToID("_BlurRadius"), renderSetting.blurRadius);
            cmd.SetGlobalFloat(Shader.PropertyToID("_Loop"), renderSetting.loop);
            cmd.SetGlobalFloat(Shader.PropertyToID("_BlurSmoothness"), renderSetting.blurSmoothness);

            cmd.SetGlobalVector(Shader.PropertyToID("_Offset"), new Vector2(renderSetting.Offset_X, renderSetting.Offset_Y));
            cmd.SetGlobalFloat(Shader.PropertyToID("_AreaSize"), renderSetting.AreaSize);

            cmd.SetGlobalFloat(Shader.PropertyToID("_Spread"), renderSetting.Spread);

            cmd.Blit(Source, blurTex.id,renderSetting.material,0);
            cmd.SetGlobalTexture(Shader.PropertyToID("_SourceTex"), Source);
            cmd.Blit(blurTex.id, Source, renderSetting.material, 1);

            context.ExecuteCommandBuffer(cmd);

            CommandBufferPool.Release(cmd);
        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(blurTex.id);
            base.FrameCleanup(cmd);
        }
    }

    BokehBlurRenderPass renderPass;

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

        renderPass = new BokehBlurRenderPass(m_Setting);
    }
}
