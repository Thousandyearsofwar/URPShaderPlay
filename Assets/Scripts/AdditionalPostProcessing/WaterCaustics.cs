using System;

namespace UnityEngine.Rendering.Universal{
    public  enum DebugMode{
        Normal,Debug
    }
    [SerializeField,VolumeComponentMenu("Addition-post-processing/WaterCaustics")]
    public class WaterCaustics : VolumeComponent,IPostProcessComponent
    {
        public ClampedFloatParameter CausticsScale=new ClampedFloatParameter(0.1f,0.1f,2.0f);
        public ClampedFloatParameter BlendDistance=new ClampedFloatParameter(0.0f,0.0f,5.0f);
        public ClampedFloatParameter WaterHeight=new ClampedFloatParameter(0.0f,0.0f,1.0f);
        
        public TextureParameter CausticsTexture=new TextureParameter(null);

        public DebugModeParameter mode=new DebugModeParameter(DebugMode.Normal);
        public bool IsActive(){      
            return active;
        }

        public bool IsTileCompatible(){
            return false;
        }

        
    }
    [Serializable] 
    public sealed class DebugModeParameter : VolumeParameter<DebugMode> { public DebugModeParameter(DebugMode value, bool overrideState = false) : base(value, overrideState) { } }
}
