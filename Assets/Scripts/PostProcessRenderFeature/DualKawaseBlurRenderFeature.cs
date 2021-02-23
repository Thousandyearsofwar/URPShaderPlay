using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class DualKawaseBlurRenderFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class DualKawaseBlurSetting
    {
        public RenderPassEvent passEvent = RenderPassEvent.AfterRenderingTransparents;
        public Material material;

        [Range(2, 10)] public int downSample = 2;
        [Range(2, 10)] public int loop = 2;
        [Range(0, 5)] public float blur = 0.5f;



        public int matPassIndex = -1;
    }
    public DualKawaseBlurSetting m_Setting = new DualKawaseBlurSetting();


    class DualKawaseBlurRenderPass : ScriptableRenderPass
    {
        public Material passMaterial = null;
        public int passMaterialIndex = 0;
        public int passdownSample = 2;
        public int passLoop = 2;
        public float passBlur = 4;
        public FilterMode passFilterMode { get; set; }
        public RenderTargetIdentifier passSource { get; set; }



        RenderTargetHandle []passBlurColorRTDown;
        RenderTargetHandle []passBlurColorRTUp;

        string passTag;

        public DualKawaseBlurRenderPass(RenderPassEvent passEvent, Material material, int passMatIndex, string tag, DualKawaseBlurSetting blurSetting)
        {
            this.renderPassEvent = passEvent;
            this.passMaterial = material;
            this.passMaterialIndex = passMatIndex;
            this.passdownSample = blurSetting.downSample;
            this.passLoop = blurSetting.loop;
            this.passBlur = blurSetting.blur;
            this.passTag = tag;

            this.passFilterMode = FilterMode.Bilinear;

            passBlurColorRTDown = new RenderTargetHandle[passLoop];
            passBlurColorRTUp = new RenderTargetHandle[passLoop];

            for(int i=0;i<passLoop;i++) {
                passBlurColorRTDown[i].Init("passBlurColorRTDown"+i);
                passBlurColorRTUp[i].Init("passBlurColorRTUp"+i);
            }
        }

        public void setup(RenderTargetIdentifier source)
        {
            this.passSource = source;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(passTag);
            passMaterial.SetFloat("_Blur",passBlur);

            RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;
            int width = opaqueDesc.width / passdownSample;
            int height = opaqueDesc.height / passdownSample;

            opaqueDesc.depthBufferBits = 0;


            //input
            RenderTargetIdentifier LastDown = passSource;

            //Blur Down Sampler
            for (int t = 0; t < passLoop; t++) {
                int midDown = passBlurColorRTDown[t].id;
                int midUp = passBlurColorRTUp[t].id;

                cmd.GetTemporaryRT(midDown,width,height,0,passFilterMode,RenderTextureFormat.ARGB32);
                cmd.GetTemporaryRT(midUp, width, height, 0, passFilterMode, RenderTextureFormat.ARGB32);

                cmd.Blit(LastDown,midDown,passMaterial,0);
                LastDown = midDown;

                width = Mathf.Max(width/2,1);
                height = Mathf.Max(height/2,1);

            }

            RenderTargetIdentifier LastUp = passBlurColorRTDown[passLoop-1].id;
            //Blur Up Sampler
            for (int t = 0; t < passLoop-1; t++)
            { 
                int midUp = passBlurColorRTUp[t].id;  

                cmd.Blit(LastUp, midUp, passMaterial, 1);
                LastUp = midUp;
            }
            cmd.Blit(LastUp, passSource, passMaterial, 1);
            context.ExecuteCommandBuffer(cmd);

            CommandBufferPool.Release(cmd);

        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
            for (int t = 0; t < passLoop; t++)
            {
                cmd.ReleaseTemporaryRT(passBlurColorRTUp[t].id);
                cmd.ReleaseTemporaryRT(passBlurColorRTDown[t].id);
            }
            base.FrameCleanup(cmd);
        }

    }

    DualKawaseBlurRenderPass renderPass;




    public override void Create()
    {
        int passCount = m_Setting.material == null ? 1 : m_Setting.material.passCount - 1;

        m_Setting.matPassIndex = Mathf.Clamp(m_Setting.matPassIndex, -1, passCount);

        renderPass = new DualKawaseBlurRenderPass(m_Setting.passEvent, m_Setting.material, m_Setting.matPassIndex, name, m_Setting);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {

        renderPass.setup(renderer.cameraColorTarget);
        renderer.EnqueuePass(renderPass);

    }


}