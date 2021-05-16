using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;
using UnityEditor.ProjectWindowCallback;
#endif

using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;

namespace UnityEngine.Experimental.Rendering.Universal {
[Serializable]
    public class AdditionalPostProcessData : ScriptableObject
    {
#if UNITY_EDITOR
        [System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Performance", "CA1812")]

        [MenuItem("Assets/Create/Rendering/Universal Render Pipeline/Additional Post-process Data", priority = CoreUtils.assetCreateMenuPriority3 + 1)]

        static void CreateAdditionalPostProcessData() {
            var instance = CreateInstance<AdditionalPostProcessData>();
            instance.shaders = new Shaders();
            instance.shaders.ChromaticShader=Shader.Find("URPPostProcess/ChromaticAberration");
            instance.shaders.RayMarchingShader = Shader.Find("URPPostProcess/RayMarching");
            instance.shaders.WaterCausticsShader = Shader.Find("URPPostProcess/WaterCaustics");
            AssetDatabase.CreateAsset(instance,string.Format("Assets/Settings/{0}.asset",typeof(AdditionalPostProcessData)));
            Selection.activeObject = instance;
        }
#endif
        [Serializable, ReloadGroup]
        public sealed class Shaders {
            [Reload("Shaders/URPPostProcess/ChromaticAberration")]
            public Shader ChromaticShader;

            [Reload("Shaders/URPPostProcess/RayMarching")]
            public Shader RayMarchingShader;

            [Reload("Shaders/WaterRender/WaterCaustics.shader")]
            public Shader WaterCausticsShader;

        }
        public Shaders shaders;
    }
}