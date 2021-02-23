using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class RadialBlurRenderFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class RadialBlurRenderSetting {
        public string passName = "RadialBlurPass";
        public Material material;
        [Range(0, 1)] public float x;
        [Range(0, 1)] public float y;
        [Range(1, 8)] public int loop = 5;
        [Range(0.0f, 0.02f)] public float blurRadius ;
        [Range(1, 5)] public int downSample = 2;
        [Range(0, 1)] public float intensity = 0.5f;

        public RenderPassEvent passEvent = RenderPassEvent.AfterRenderingTransparents;
        public int matPassIndex = -1;
    }

    public RadialBlurRenderSetting m_Setting = new RadialBlurRenderSetting();

    class RadialBlurRenderPass : ScriptableRenderPass
    {
        RadialBlurRenderSetting renderSetting;

        public FilterMode passFilterMode { get; set; }
        public RenderTargetIdentifier Source { get; set; }

        public RenderTargetHandle BlurTex;
        public RenderTargetHandle targetHandle0;
        public RenderTargetHandle targetHandle1;



        int ssW;
        int ssH;

        public void setup(RenderTargetIdentifier source) {
            this.Source = source;
        }

        public RadialBlurRenderPass(RadialBlurRenderSetting renderSetting) {
            this.renderPassEvent = renderSetting.passEvent;
            this.renderSetting = renderSetting;
            this.passFilterMode = FilterMode.Bilinear;
            BlurTex.Init("passBlurColorRT");
            targetHandle0.Init("passBlurColorTempRT0");
            targetHandle1.Init("passBlurColorTempRT1");

        }



        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(renderSetting.passName);


            RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;
            ssW = opaqueDesc.width / renderSetting.downSample;
            ssH = opaqueDesc.height / renderSetting.downSample;

            cmd.GetTemporaryRT(targetHandle0.id,ssW,ssH,0,passFilterMode,RenderTextureFormat.ARGB32);//down sample
            //   desc:
            //     Use this RenderTextureDescriptor for the settings when creating the temporary
            //     RenderTexture.
            cmd.GetTemporaryRT(BlurTex.id,opaqueDesc);//res
            cmd.GetTemporaryRT(targetHandle1.id,opaqueDesc);//res


            cmd.SetGlobalFloat(Shader.PropertyToID("_Loop"),renderSetting.loop);
            cmd.SetGlobalFloat(Shader.PropertyToID("_X"),renderSetting.x);
            cmd.SetGlobalFloat(Shader.PropertyToID("_Y"),renderSetting.y);
            cmd.SetGlobalFloat(Shader.PropertyToID("_Blur"),renderSetting.blurRadius);
            cmd.SetGlobalFloat(Shader.PropertyToID("_Intensity"),renderSetting.intensity);

            

            cmd.Blit(Source,targetHandle0.Identifier());
            cmd.Blit(Source,targetHandle1.Identifier());
            

            cmd.Blit(targetHandle0.Identifier(), BlurTex.Identifier(), renderSetting.material, 0);
            
            cmd.SetGlobalTexture(Shader.PropertyToID("_SourceTex"), targetHandle1.Identifier());
            cmd.Blit(BlurTex.Identifier(), Source, renderSetting.material, 1);

            context.ExecuteCommandBuffer(cmd);

            CommandBufferPool.Release(cmd);
        }


        public override void FrameCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(targetHandle0.id);
            cmd.ReleaseTemporaryRT(targetHandle1.id);
            cmd.ReleaseTemporaryRT(BlurTex.id);

            base.FrameCleanup(cmd);
        }

    }
    RadialBlurRenderPass renderPass;


    public override void Create()
    {

        int passCount = m_Setting.material == null ? 1 : m_Setting.material.passCount - 1;

        m_Setting.matPassIndex = Mathf.Clamp(m_Setting.matPassIndex, -1, passCount);

        renderPass = new RadialBlurRenderPass(m_Setting);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (m_Setting.material != null)
        {
            renderPass.setup(renderer.cameraColorTarget);
            renderer.EnqueuePass(renderPass);
        }
        else {
            Debug.LogError("material miss");
        }
    }


}
