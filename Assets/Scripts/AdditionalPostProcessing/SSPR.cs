using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace UnityEngine.Experimental.Rendering.Universal{
[SerializeField,VolumeComponentMenu("Addition-post-processing/SSPR")]
public class SSPR:VolumeComponent,IPostProcessComponent
{
    public ComputeShaderParameter ComputeShaderParameter=new ComputeShaderParameter(null);


    public bool IsActive(){
        return active;
    }
    public bool IsTileCompatible(){
        return false;
    }

}

    [Serializable] 
    public sealed class ComputeShaderParameter : VolumeParameter<ComputeShader> { 
        public ComputeShaderParameter(ComputeShader value, bool overrideState = false) 
        : base(value, overrideState)
         { } 
    }

}
