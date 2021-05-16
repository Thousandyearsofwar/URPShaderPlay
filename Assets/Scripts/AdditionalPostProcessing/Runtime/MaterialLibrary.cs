using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;


namespace UnityEngine.Experimental.Rendering.Universal {
    public class MaterialLibrary
    {
        public readonly Material ChromaticMat;
        public readonly Material RayMarchingMat;
        public readonly Material WaterCausticsMat;

        public MaterialLibrary(AdditionalPostProcessData data) {
            ChromaticMat = Load(data.shaders.ChromaticShader);
            RayMarchingMat = Load(data.shaders.RayMarchingShader);
            WaterCausticsMat=Load(data.shaders.WaterCausticsShader);
        } 

        Material Load(Shader shader) {
            if (shader == null)
            {
                Debug.LogErrorFormat($"Missing shader. {GetType().DeclaringType.Name} render pass will not execute. Check for missing reference in the renderer resources.");
                return null;
            }
            else if (!shader.isSupported) {
                return null;
            }

            return CoreUtils.CreateEngineMaterial(shader);
        }

        internal void Cleanup() {
            CoreUtils.Destroy(ChromaticMat);
        }
}
}
