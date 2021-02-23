using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class BSCAdjustRenderFeatureCS : ScriptableRendererFeature
{
    [System.Serializable]
    public class BSCAdjustSetting
    {

        [Range(0, 1)] public float Intensity = 0.5f;

        public string passName = "BSCAdjustRenderFeatureCSPass";
        public ComputeShader CS = null;




        public RenderPassEvent passEvent = RenderPassEvent.AfterRenderingTransparents;

       
    }

    public BSCAdjustSetting m_Setting = new BSCAdjustSetting();



    //Gradient gradient = new Gradient();
    //gradient.Evaluate(0);

    class ChromaticAberrationRenderPass : ScriptableRenderPass
    {
        BSCAdjustSetting setting;

        public RenderTargetIdentifier Source { get; set; }

        RenderTexture renderTexture = new RenderTexture(3, 1, 0);
        Texture2D AberrationLUT = new Texture2D(3, 1);
        public RenderTargetHandle aberrationTex;

        public ChromaticAberrationRenderPass(BSCAdjustSetting setting)
        {
            this.setting = setting;

            AberrationLUT.SetPixel(0, 0, Color.red);
            AberrationLUT.SetPixel(1, 0, Color.green);
            AberrationLUT.SetPixel(2, 0, Color.blue);
            AberrationLUT.filterMode = FilterMode.Bilinear;
            AberrationLUT.Apply();
            aberrationTex.Init("passChromaticAberrationRT");
        }


        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(setting.passName);

            RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;

            Camera camera = renderingData.cameraData.camera;



            

            cmd.GetTemporaryRT(aberrationTex.id, opaqueDesc);



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
       
    }

    public override void Create()
    {
        
    }
}
