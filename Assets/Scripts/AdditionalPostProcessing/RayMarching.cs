using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;


namespace UnityEngine.Experimental.Rendering.Universal {
    [SerializeField,VolumeComponentMenu("Addition-post-processing/RayMarching")]
    public class RayMarching : VolumeComponent, IPostProcessComponent
    {
        
        public ClampedFloatParameter _step = new ClampedFloatParameter(0.0f,0.0f,10.0f);
        public ClampedFloatParameter _rayStep = new ClampedFloatParameter(0.0f,0.0f,1.0f);
        public ClampedFloatParameter _rayOffsetStrength = new ClampedFloatParameter(0.0f,0.0f,5.0f);
        public ColorParameter color = new ColorParameter(new Color(1,1,1));
        public ColorParameter colorA = new ColorParameter(new Color(1,1,1));
        public ColorParameter colorB = new ColorParameter(new Color(0.2f,0.2f,0.2f));

        public TextureParameter NoiseTexture = new TextureParameter(null);
        public TextureParameter _MaskNoiseTexture= new TextureParameter(null);

        public ClampedFloatParameter _shapeTilling = new ClampedFloatParameter(0.0f,0.0f,0.01f);

        public BoxCollider rayMarchBox;
        
        public ClampedFloatParameter blend = new ClampedFloatParameter(0.0f,0.0f,1.0f);
        
        public ClampedFloatParameter lightAbsorptionTowardSun = new ClampedFloatParameter(0.0f,0.0f,1.0f);
        public ClampedFloatParameter lightAbsorptionTowardCloud = new ClampedFloatParameter(0.0f,0.0f,1.0f);
        public ClampedFloatParameter darknessThreshold = new ClampedFloatParameter(0.0f,0.0f,1.0f);

        public ClampedFloatParameter colorOffset1 = new ClampedFloatParameter(0.0f,0.0f,1.0f);
        public ClampedFloatParameter colorOffset2 = new ClampedFloatParameter(0.0f,0.0f,1.0f);

        //散射
        public Vector4Parameter _phaseParams = new Vector4Parameter(new Vector4(0.72f,1.0f,0.5f,1.58f));
        //Weather
        public TextureParameter WeatherTexture=new TextureParameter(null);
        public Vector4Parameter _shapeNoiseWeight = new Vector4Parameter(new Vector4(-0.17f,27.17f,-3.65f,-0.08f));
		public FloatParameter _densityOffset=new FloatParameter(-10.9f);
        public ClampedFloatParameter _densityMultiplier=new ClampedFloatParameter(1,1,3);

        //边缘过渡距离
        public ClampedFloatParameter _containerEdgeFadeDst= new ClampedFloatParameter(60.0f,10.0f,100.0f);
        public ClampedFloatParameter _heightWeights = new ClampedFloatParameter(0.0f,0.0f,1.0f);

        //Detail Noise
        public TextureParameter _NoiseDetailTexture=new TextureParameter(null);
        public ClampedFloatParameter _detailTilling = new ClampedFloatParameter(0.0f,0.0f,0.01f);
        public FloatParameter _detailFBMWeights = new FloatParameter(-3.76f);
        public FloatParameter _detailNoiseWeight=new FloatParameter(0.12f);
        //BlueNoise
        public TextureParameter BlueNoise=new TextureParameter(null);

        //Speed
        public Vector4Parameter _Speed_xy_Wrap_zw=new Vector4Parameter(new Vector4(0.12f,0.5f,0f,0f));

        public bool IsActive()
        {
            GameObject boxObj = GameObject.Find("RayMarchBox");
            if (boxObj!=null)
                 boxObj.TryGetComponent(out rayMarchBox);
            
            return blend!=0&&active;
        }

        public bool IsTileCompatible()
        {
            return false;
        }
    }
}

