using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class DepthNormalRenderFeature : ScriptableRendererFeature
{
    class DepthNormalRenderPass : ScriptableRenderPass
    {
        private FilteringSettings filteringSettings;


        //input

        //output
        public RenderTargetHandle Destination;

        private ShaderTagId tagId = new ShaderTagId("DepthOnly");
        private Material depthNormalMaterial = null;

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            Destination.Init("_CameraDepthNormalsTexture");
            RenderTextureDescriptor descriptor = cameraTextureDescriptor;
            descriptor.depthBufferBits = 32;
            descriptor.colorFormat = RenderTextureFormat.ARGB32;
            
            cmd.GetTemporaryRT(Destination.id,descriptor,FilterMode.Point);
            ConfigureTarget(Destination.Identifier());

            ConfigureClear(ClearFlag.All,Color.black);

          
        }


        public DepthNormalRenderPass(RenderQueueRange renderQueueRange ,LayerMask layerMask,Material material)
        {
            this.renderPassEvent = RenderPassEvent.AfterRenderingPrePasses;
            this.filteringSettings = new FilteringSettings(renderQueueRange,layerMask);


            
            this.depthNormalMaterial = material;
        }


        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get("DepthNormalRenderPass");
            
            using (new ProfilingScope(cmd, new ProfilingSampler("DepthNormalRenderPass"))) {

                
            
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            
            var sortFlags = renderingData.cameraData.defaultOpaqueSortFlags;
            var drawSettings = CreateDrawingSettings(this.tagId, ref renderingData,sortFlags);
            drawSettings.perObjectData = PerObjectData.None;
            drawSettings.overrideMaterial = depthNormalMaterial;

            ref CameraData cameraData = ref renderingData.cameraData;
            if (cameraData.isStereoEnabled)
                context.StartMultiEye(cameraData.camera);
            
            context.DrawRenderers(renderingData.cullResults,ref drawSettings,ref filteringSettings);
            cmd.SetGlobalTexture("_CameraDepthNormalsTexture", Destination.id);

            }
            context.ExecuteCommandBuffer(cmd);

            CommandBufferPool.Release(cmd);

        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
            if (Destination != RenderTargetHandle.CameraTarget) {
                cmd.ReleaseTemporaryRT(Destination.id);
                Destination = RenderTargetHandle.CameraTarget;
            }
            
        }
    }

    DepthNormalRenderPass renderPass;
    Material depthNormalMaterial;
    //RenderTargetHandle depthNormalsTexture;


    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        //renderPass.destination = depthNormalsTexture;
        renderer.EnqueuePass(renderPass);
    }

    public override void Create()
    {
        depthNormalMaterial = CoreUtils.CreateEngineMaterial("Hidden/Internal-DepthNormalsTexture");
        //depthNormalsTexture.Init("_CameraDepthNormalsTexture");
        renderPass = new DepthNormalRenderPass(RenderQueueRange.opaque,-1, depthNormalMaterial);
        
    }
}
