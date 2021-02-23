using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ModelShelterRenderFeature : ScriptableRendererFeature
{

    [System.Serializable]
    public class ModelShelterRenderSetting
    {
        public string passName = "ModelShelterPass";
        public Material material;

        //Blur parameter
        [Range(0.0f, 3.0f)] public float blur = 1.0f;
        [Range(1, 5)] public int passloop = 3;
        //Shelter mask color
        public Color ModelShelterColor;

        //what
        public LayerMask layer;
        [Range(1000, 5000)] public int QueueMin = 2000;
        [Range(1000, 5000)] public int QueueMax = 2500;

        //when
        public RenderPassEvent passEvent = RenderPassEvent.AfterRenderingSkybox;


        

        private FilteringSettings filter;

        public int matPassIndex = -1;


    }

    public ModelShelterRenderSetting m_Setting = new ModelShelterRenderSetting();

    class MaskRenderPass : ScriptableRenderPass
    {
        ModelShelterRenderSetting renderSetting;
        FilteringSettings filteringSetting;

        public FilterMode passFilterMode { get; set; }

        //shader tag
        ShaderTagId tagId = new ShaderTagId("DepthOnly");



        public RenderTargetHandle maskTex;
        
        

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            maskTex.Init("passMaskRT");

            RenderTextureDescriptor descriptor = cameraTextureDescriptor;
            descriptor.depthBufferBits = 32;
            descriptor.colorFormat = RenderTextureFormat.ARGB32;

            cmd.GetTemporaryRT(maskTex.id, descriptor);

            ConfigureTarget(maskTex.Identifier());
            ConfigureClear(ClearFlag.All, Color.black);


        }

        public MaskRenderPass(ModelShelterRenderSetting renderSetting)
        {
            this.renderPassEvent = renderSetting.passEvent;
            this.renderSetting = renderSetting;
            this.passFilterMode = FilterMode.Bilinear;

            RenderQueueRange queue = new RenderQueueRange();
            queue.lowerBound = Mathf.Min(renderSetting.QueueMax,renderSetting.QueueMin);
            queue.upperBound = Mathf.Max(renderSetting.QueueMax,renderSetting.QueueMin);

            //filteringSetting = new FilteringSettings(queue,filteringSetting.layerMask);
            filteringSetting = new FilteringSettings(queue, renderSetting.layer);

        }


        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(renderSetting.passName);

            RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;

            using (new ProfilingScope(cmd, new ProfilingSampler("MaskRenderPass"))) {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();

                var sortFlags = renderingData.cameraData.defaultOpaqueSortFlags;
                var drawSettings = CreateDrawingSettings(this.tagId,ref renderingData, sortFlags);
                
                drawSettings.overrideMaterial = renderSetting.material;
                drawSettings.overrideMaterialPassIndex = 0;

                context.DrawRenderers(renderingData.cullResults,ref drawSettings,ref filteringSetting);

                context.ExecuteCommandBuffer(cmd);

                CommandBufferPool.Release(cmd);
            }
           
        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(maskTex.id);
            base.FrameCleanup(cmd);
        }
    }

    class BlurRenderPass : ScriptableRenderPass
    {
        ModelShelterRenderSetting renderSetting;
        FilteringSettings filteringSetting;

        public FilterMode passFilterMode { get; set; }

        //shader tag
        ShaderTagId tagId = new ShaderTagId("DepthOnly");

        //input
        public RenderTargetIdentifier Source { get; set; }
        public RenderTargetHandle maskTex;

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            maskTex.Init("passModelShelterRT");

            RenderTextureDescriptor descriptor = cameraTextureDescriptor;
            descriptor.depthBufferBits = 32;
            descriptor.colorFormat = RenderTextureFormat.R8;

            cmd.GetTemporaryRT(maskTex.id, descriptor, FilterMode.Point);
            ConfigureTarget(maskTex.Identifier());
            ConfigureClear(ClearFlag.All, Color.black);


        }

        public BlurRenderPass(ModelShelterRenderSetting renderSetting)
        {
            this.renderPassEvent = renderSetting.passEvent;
            this.renderSetting = renderSetting;
            this.passFilterMode = FilterMode.Bilinear;

            RenderQueueRange queue = new RenderQueueRange();
            queue.lowerBound = Mathf.Min(renderSetting.QueueMax, renderSetting.QueueMin);
            queue.upperBound = Mathf.Max(renderSetting.QueueMax, renderSetting.QueueMin);

            filteringSetting = new FilteringSettings(queue, filteringSetting.layerMask);


        }


        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(renderSetting.passName);

            RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;

            cmd.GetTemporaryRT(maskTex.id, opaqueDesc);

            cmd.Blit(Source, maskTex.id, renderSetting.material, 0);

            cmd.Blit(maskTex.id, Source);

            context.ExecuteCommandBuffer(cmd);

            CommandBufferPool.Release(cmd);
        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(maskTex.id);
            base.FrameCleanup(cmd);
        }
    }


    MaskRenderPass maskRenderPass;


    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (m_Setting.material != null)
        {
            renderer.EnqueuePass(maskRenderPass);           
        }

    }

    public override void Create()
    {
        int passCount = m_Setting.material == null ? 1 : m_Setting.material.passCount - 1;

        m_Setting.matPassIndex = Mathf.Clamp(m_Setting.matPassIndex, -1, passCount);

        maskRenderPass = new MaskRenderPass(m_Setting);
       
    }
}
