using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;


public class ChromaticAberrationRenderFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class ChromaticAberrationSetting {

        [Range(0,1)]public float Intensity=0.5f;

        public string passName = "ChromaticAberrationPass";
        public Material material;

        public RenderPassEvent passEvent = RenderPassEvent.AfterRenderingOpaques;

        private FilteringSettings filteringSettings;
    }

    public ChromaticAberrationSetting m_Setting = new ChromaticAberrationSetting();

    

    //Gradient gradient = new Gradient();
    //gradient.Evaluate(0);

    class ChromaticAberrationRenderPass : ScriptableRenderPass
    {
        ChromaticAberrationSetting setting;

        public RenderTargetIdentifier Source { get; set; }

        RenderTexture renderTexture = new RenderTexture(3,1,0);
        Texture2D AberrationLUT = new Texture2D(3, 1);
        public RenderTargetHandle aberrationTex;

        public ChromaticAberrationRenderPass(ChromaticAberrationSetting setting) {
            this.setting = setting;
            
            AberrationLUT.SetPixel(0,0, Color.red);
            AberrationLUT.SetPixel(1,0, Color.green);
            AberrationLUT.SetPixel(2,0, Color.blue);
            AberrationLUT.filterMode = FilterMode.Bilinear;
            AberrationLUT.Apply();
            aberrationTex.Init("passChromaticAberrationRT");
        }


        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(setting.passName);

            RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;

            Camera camera = renderingData.cameraData.camera;

            
            
            setting.material.SetTexture("_AberrationLUT", AberrationLUT);
            setting.material.SetFloat("_Intensity", setting.Intensity);

            cmd.GetTemporaryRT(aberrationTex.id, opaqueDesc);

            cmd.Blit(Source,aberrationTex.id,setting.material,0);
            cmd.Blit(aberrationTex.id, Source);
            
            context.ExecuteCommandBuffer(cmd);

            CommandBufferPool.Release(cmd);
        }



        public override void FrameCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(aberrationTex.id);
            base.FrameCleanup(cmd);
        }

    }

    ChromaticAberrationRenderPass renderPass;

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (m_Setting.material != null)
        {
            renderPass.Source = renderer.cameraColorTarget;
            renderer.EnqueuePass(renderPass);
        }
        
        


    }

    public override void Create()
    {
       
        renderPass = new ChromaticAberrationRenderPass(m_Setting);
    }
}
