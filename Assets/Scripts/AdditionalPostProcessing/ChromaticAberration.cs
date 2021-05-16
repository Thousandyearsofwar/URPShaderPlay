using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace UnityEngine.Experimental.Rendering.Universal{

    [SerializeField, VolumeComponentMenu("Addition-post-processing/ChromaticAberration")]
    public class ChromaticAberration : VolumeComponent, IPostProcessComponent
    {
        //Post processing custom parameter
        public ClampedFloatParameter Intensity = new ClampedFloatParameter(0,0,0.2f);



        //Override function
        public bool IsActive()
        {
            return active&& Intensity.value!=0;
        }

        public bool IsTileCompatible()
        {
            return false;
        }
        
    }
    /*
    [Serializable]
    public sealed class GaussianFilerModeParameter : VolumeParameter<FilterMode>
    {
        public GaussianFilerModeParameter(FilterMode value, bool overrideState = false) : base(value, overrideState) { }
    }
    */
}


