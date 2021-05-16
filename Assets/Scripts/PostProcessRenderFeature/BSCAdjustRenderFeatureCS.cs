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
        public string passName = "BSCAdjustRenderFeatureCSPass";
        public ComputeShader CS = null;

        [Range(0, 2)] public float Saturate = 1f;
        [Range(0, 2)] public float Bright = 1f;
        [Range(-2,3)] public float Constrast = 1f;


        public RenderPassEvent passEvent = RenderPassEvent.AfterRenderingTransparents;

       
    }

    public BSCAdjustSetting m_Setting = new BSCAdjustSetting();

    class BSCAdjustRenderPass : ScriptableRenderPass
    {
        BSCAdjustSetting setting;

        public RenderTargetIdentifier Source { get; set; }

        public RenderTargetHandle BSCAdjustTex;

        public BSCAdjustRenderPass(BSCAdjustSetting setting)
        {
            this.setting = setting;

            BSCAdjustTex.Init("BSCAdjustRT");
        }

        public void setup(RenderTargetIdentifier source) {
            this.Source = source;
        }


        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(setting.passName);

            RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;

            opaqueDesc.enableRandomWrite = true;

            Camera camera = renderingData.cameraData.camera;

            cmd.GetTemporaryRT(BSCAdjustTex.id, opaqueDesc);
            cmd.SetComputeFloatParam(setting.CS,"_Bright",setting.Bright);
            cmd.SetComputeFloatParam(setting.CS,"_Saturate",setting.Saturate);
            cmd.SetComputeFloatParam(setting.CS, "_Constrast", setting.Constrast);

            cmd.SetComputeTextureParam(setting.CS,0,"_Result",BSCAdjustTex.id);
            cmd.SetComputeTextureParam(setting.CS,0,"_Source",Source);

            cmd.DispatchCompute(setting.CS,0,(int)opaqueDesc.width/8,(int)opaqueDesc.height/8,1);
            cmd.Blit(BSCAdjustTex.id,Source);

            context.ExecuteCommandBuffer(cmd);

            CommandBufferPool.Release(cmd);
        }



        public override void FrameCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(BSCAdjustTex.id);
            base.FrameCleanup(cmd);
        }

    }

    BSCAdjustRenderPass renderPass;



    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (m_Setting.CS != null) {
            var src = renderer.cameraColorTarget;
            renderPass.setup(src);
            renderer.EnqueuePass(renderPass);
        }
    }

    public override void Create()
    {
        renderPass = new BSCAdjustRenderPass(m_Setting);
    }
}
