using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace UnityEngine.Experimental.Rendering.Universal {
    public class AdditionalPostProcessRenderFeature : ScriptableRendererFeature
    {
        public RenderPassEvent evt = RenderPassEvent.AfterRenderingTransparents;
        public AdditionalPostProcessData postData;
        static AdditionalPostProcessRenderPass postPass;

        static MaterialLibrary m_MaterialLib;
        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            var cameraColorTarget = renderer.cameraColorTarget;
            var cameraDepth = renderer.cameraDepth;
            var dest = renderer.cameraColorTarget;
            if (postData == null)
                return;
            postPass.Setup(evt, cameraColorTarget, cameraDepth, dest, postData,m_MaterialLib);
            renderer.EnqueuePass(postPass);
        }

        public override void Create()
        {
            postPass = new AdditionalPostProcessRenderPass();
            m_MaterialLib=new MaterialLibrary(postData);
        }
    }

}


