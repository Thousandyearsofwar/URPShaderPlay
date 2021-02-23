using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class KawaseBlurRenderFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class KawaseBlurSetting
    {
        public RenderPassEvent passEvent = RenderPassEvent.AfterRenderingTransparents;
        public Material material;

        [Range(2, 10)] public int downSample = 2;
        [Range(2, 10)] public int loop = 2;
        [Range(0.5f, 5)] public float blur = 0.5f;

        

        public int matPassIndex = -1;
    }
    public KawaseBlurSetting m_Setting = new KawaseBlurSetting();


    class KawaseBlurRenderPass : ScriptableRenderPass
    {
        public Material passMaterial = null;
        public int passMaterialIndex = 0;
        public int passdownSample=2;
        public int passLoop=2;
        public float passBlur=4;
        public FilterMode passFilterMode { get; set; }
        public RenderTargetIdentifier passSource { get; set; }



        RenderTargetHandle passBlurColorRT0;
        RenderTargetHandle passBlurColorRT1;

        string passTag;

        public KawaseBlurRenderPass(RenderPassEvent passEvent, Material material, int passMatIndex, string tag,KawaseBlurSetting blurSetting)
        {
            this.renderPassEvent = passEvent;
            this.passMaterial = material;
            this.passMaterialIndex = passMatIndex;
            this.passdownSample = blurSetting.downSample;
            this.passLoop = blurSetting.loop;
            this.passBlur = blurSetting.blur;
            this.passTag = tag;

            this.passFilterMode = FilterMode.Bilinear;
            passBlurColorRT0.Init("passBlurColorRT0");
            passBlurColorRT1.Init("passBlurColorRT1");

        }

        public void setup(RenderTargetIdentifier source)
        {
            this.passSource = source;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(passTag);

            RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;
            int width = opaqueDesc.width / passdownSample;
            int height = opaqueDesc.height / passdownSample;

            opaqueDesc.depthBufferBits = 0;

            cmd.GetTemporaryRT(passBlurColorRT0.id,width,height,0, passFilterMode,RenderTextureFormat.ARGB32);
            cmd.GetTemporaryRT(passBlurColorRT1.id,width,height,0, passFilterMode,RenderTextureFormat.ARGB32);


            cmd.SetGlobalFloat("_Blur",1f);
            cmd.Blit(passSource,passBlurColorRT0.Identifier(),passMaterial);
            for (int i = 1; i < passLoop; i++) {
                cmd.SetGlobalFloat("_Blur", i*passBlur+1);
                cmd.Blit(passBlurColorRT0.Identifier(), passBlurColorRT1.Identifier(), passMaterial);
                var tempRT = passBlurColorRT0;
                passBlurColorRT0 = passBlurColorRT1;
                passBlurColorRT1 = tempRT;
            }
            cmd.SetGlobalFloat("_Blur",passLoop* passBlur + 1);
            cmd.Blit(passBlurColorRT0.Identifier(),passSource,passMaterial);

            context.ExecuteCommandBuffer(cmd);

            CommandBufferPool.Release(cmd);
            
        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(passBlurColorRT0.id);
            cmd.ReleaseTemporaryRT(passBlurColorRT1.id);

            base.FrameCleanup(cmd);
        }

    }

    KawaseBlurRenderPass renderPass;




    public override void Create()
    {
        int passCount = m_Setting.material == null ? 1 : m_Setting.material.passCount - 1;

        m_Setting.matPassIndex = Mathf.Clamp(m_Setting.matPassIndex, -1, passCount);

        renderPass = new KawaseBlurRenderPass(m_Setting.passEvent,m_Setting.material,m_Setting.matPassIndex,name,m_Setting);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {

        renderPass.setup(renderer.cameraColorTarget);
        renderer.EnqueuePass(renderPass);
        
    }


}
