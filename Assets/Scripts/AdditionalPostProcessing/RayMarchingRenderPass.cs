using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace UnityEngine.Experimental.Rendering.Universal {
    public class RayMarchingRenderPass : ScriptableRenderPass
    {
        RenderTargetIdentifier input_ColorAttachment;
        RenderTargetIdentifier input_CameraDepthAttachment;

        RenderTargetIdentifier output_Destination;

        const string RenderPostProcessingTag = "Render AdditionalPostProcessing Effects";
        const string RenderFinalPostProcessingTag = "Render Final AdditionalPostProcessing Effects";

        //Material&ShaderData
        //MaterialLibrary m_Material;
        Material m_Material;
        Shader m_Shader;
        AdditionalPostProcessData m_Data;

        public RayMarchingRenderPass() {

        }

        public void Setup(RenderPassEvent @event, RenderTargetIdentifier source,
            RenderTargetIdentifier cameraDepth, RenderTargetIdentifier destination, AdditionalPostProcessData data
            )
        {
            m_Data = data;
            renderPassEvent = @event;

            input_ColorAttachment = source;
            input_CameraDepthAttachment = cameraDepth;

            output_Destination = destination;

            //m_Material = new MaterialLibrary(data);
            m_Shader=data.shaders.RayMarchingShader;
            m_Material = CoreUtils.CreateEngineMaterial(m_Shader);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var stack = VolumeManager.instance.stack;
            
        }
    }
}
