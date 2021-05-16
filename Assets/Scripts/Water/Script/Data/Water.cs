using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Water.Data;
using UnityEngine.Experimental.Rendering;

namespace Water{
    [ExecuteAlways]
public class Water : MonoBehaviour
{
    private static Water _instance;
    public static Water _Instance{
        get{
            if(_instance==null)
                _instance=(Water)FindObjectOfType(typeof(Water));
            return _instance;
        }
    }

    private PlanarReflections _planarReflections;

    private Camera _depthCam;
    //--------------------------------------
    //Render Setting Parameter
    private bool _useComputeBuffer;
    public bool computeOverride;
    private float _maxWaveHeight;
    private float _waveHeight;
    //--------------------------------------
    //render wave data
    [SerializeField] Wave[] _waves;
    [SerializeField]private ComputeBuffer waveDataBuffer;
    //-------------------------------------- 
    //Render use textures
    [SerializeField] RenderTexture _depthTex;
    private Texture bakeDepthTex;
    private Texture2D _rampTexture;
    //--------------------------------------
    //Data Assets
    [SerializeField] WaterSettingData waterSettingData;
    [SerializeField] WaterSurfaceData waterSurfaceData;
    [SerializeField] private WaterResources resources;
    //--------------------------------------
    //Shader Location
    private static readonly int _sWaveHeight=Shader.PropertyToID("_WaveHeight");
    private static readonly int _sMaxWaveHeight=Shader.PropertyToID("_MaxWaveHeight");
    private static readonly int _sWaterMaxVisibility=Shader.PropertyToID("_MaxDepth");
    private static readonly int _sWaveCount=Shader.PropertyToID("_WaveCount");
    
    private static readonly int _sInvViewProjection=Shader.PropertyToID("_InvViewProjection");

    private static readonly int _sAbsorptionScatteringRampTex=Shader.PropertyToID("_AbsorptionScatteringRamp");
    private static readonly int _sSurfaceMap=Shader.PropertyToID("_SurfaceMap");
    private static readonly int _sFoamTex=Shader.PropertyToID("_FoamMap");
    private static readonly int _sBakeDepthTex=Shader.PropertyToID("_WaterDepthMap");

    private static readonly int _sWaveDataBuffer=Shader.PropertyToID("_WaveDataBuffer");
    private static readonly int _sWaveData=Shader.PropertyToID("waveData");

    private void OnEnable() {

        if(!computeOverride)
            _useComputeBuffer=SystemInfo.supportsComputeShaders&&
                            Application.platform!=RuntimePlatform.WebGLPlayer&&
                            Application.platform!=RuntimePlatform.Android;
        else
            _useComputeBuffer=false;
        Init();
        RenderPipelineManager.beginCameraRendering+=BeginCameraRendering;

        if(resources==null)
            resources=Resources.Load("WaterResources")as WaterResources;


    }

    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    private void OnDisable() {
        CleanUp();
    }

    public void Init(){
        SetWave();

        GenerateColorRamp();
        if(bakeDepthTex)
            Shader.SetGlobalTexture(_sBakeDepthTex,bakeDepthTex);

        if(!gameObject.TryGetComponent(out _planarReflections))
            _planarReflections=gameObject.AddComponent<PlanarReflections>();
        _planarReflections.hideFlags=HideFlags.None;
        _planarReflections.m_Settings=waterSettingData.planarReflectionSettings;
        _planarReflections.enabled=waterSettingData.reflectionType==ReflectionType.PlanarReflection;
        
        if(resources==null)
            resources=Resources.Load("WaterResources")as WaterResources;

        if(Application.platform!=RuntimePlatform.WebGLPlayer)
            Invoke(nameof(CaptureDepthMap),1.0f);


    }

    
    void CleanUp(){
        RenderPipelineManager.beginCameraRendering-=BeginCameraRendering;

        if(_depthCam){
            _depthCam.targetTexture=null;
            SafeDestory(_depthCam.gameObject);
        }
        if(_depthTex)
            SafeDestory(_depthTex);

        waveDataBuffer?.Dispose();
    }

    private static void SafeDestory(Object o){
        if(Application.isPlaying)
            Destroy(o);
        else
            DestroyImmediate(o);
    }


    private void BeginCameraRendering(ScriptableRenderContext scriptable,Camera cam){
        if(cam.cameraType==CameraType.Preview)
            return;
        var roll=cam.transform.localEulerAngles.z;//Infinite Water parameter
        Shader.SetGlobalMatrix(_sInvViewProjection,(GL.GetGPUProjectionMatrix(cam.projectionMatrix,false)*cam.worldToCameraMatrix).inverse);
        
        const float quantizeValue=6.25f;
        const float forwards=10f;
        const float yOffset=-0.25f;

        var newPos=cam.transform.TransformPoint(Vector3.forward*forwards);
        newPos.y=yOffset;
        newPos.x=quantizeValue*(int)(newPos.x/quantizeValue);
        newPos.z=quantizeValue*(int)(newPos.z/quantizeValue);

        var matrix=Matrix4x4.TRS(newPos+transform.position,Quaternion.identity,transform.localScale);

        foreach(var mesh in resources.defaultWaterMeshes){
            Graphics.DrawMesh(
                mesh,matrix,resources.defaultWaterMaterial,gameObject.layer,cam,0,null,ShadowCastingMode.Off,true,null,LightProbeUsage.Off,null
            );

        }

    } 


    private void SetWave(){
        SetupWaves(waterSurfaceData._customWaves);

        //set Texture 
        Shader.SetGlobalTexture(_sFoamTex,resources.defaultFoamMap);
        Shader.SetGlobalTexture(_sSurfaceMap,resources.defaultSurfaceMap);

        _maxWaveHeight=0.0f;
        foreach(var w in _waves){
            _maxWaveHeight+=w.amplitude;
        }
        _maxWaveHeight/=_waves.Length;

        _waveHeight=transform.position.y;

        Shader.SetGlobalFloat(_sWaveHeight,_waveHeight);
        Shader.SetGlobalFloat(_sMaxWaveHeight,_maxWaveHeight);
        Shader.SetGlobalFloat(_sWaterMaxVisibility,waterSurfaceData._waterMaxVisibility);

        Shader.SetGlobalInt(_sWaveCount,_waves.Length);

        switch(waterSettingData.reflectionType){
            case ReflectionType.CubeMap:
                Shader.EnableKeyword("_REFLECTION_CBUEMAP");
                Shader.DisableKeyword("_REFLECTION_PROBES");
                Shader.DisableKeyword("_REFLECTION_PLANARREFLECTION");
                
                break;
            case ReflectionType.ReflectionProbe:
                Shader.DisableKeyword("_REFLECTION_CBUEMAP");
                Shader.EnableKeyword("_REFLECTION_PROBES");
                Shader.DisableKeyword("_REFLECTION_PLANARREFLECTION");
                
                break;
            case ReflectionType.PlanarReflection:
                Shader.DisableKeyword("_REFLECTION_CBUEMAP");
                Shader.DisableKeyword("_REFLECTION_PROBES");
                Shader.EnableKeyword("_REFLECTION_PLANARREFLECTION");
                break;
            default:
                Debug.LogError("Setting Data Null");
                break;

        }
        //Debug.Log(_planarReflections._planarReflectionTexId);
        if(_useComputeBuffer){
            Shader.EnableKeyword("USE_STRUCTURED_BUFFER");
            waveDataBuffer?.Dispose();
            waveDataBuffer=new ComputeBuffer(10,(sizeof(float)*6));
            waveDataBuffer.SetData(_waves);
            Shader.SetGlobalBuffer(_sWaveDataBuffer,waveDataBuffer);

        }
        else{
            Shader.DisableKeyword("USE_STRUCTURED_BUFFER");
            Shader.SetGlobalVectorArray(_sWaveData,WaveToVecData());
        }

    }

    private Vector4[] WaveToVecData(){
        var waveData=new Vector4[20];
        for(var i=0;i<_waves.Length;i++){
            waveData[i]=new Vector4(_waves[i].amplitude,_waves[i].direction,_waves[i].wavelength,_waves[i].omniDir);
            waveData[i+10]=new Vector4(_waves[i].origin.x,_waves[i].origin.y,0,0);
        }
        return waveData;
    }

    private void SetupWaves(bool custom){

        if(!custom){
            var backupSeed=Random.state;
            Random.InitState(waterSurfaceData.randomSeed);

            var basicWaves=waterSurfaceData._basicWaveSettings;
            var amplitude=basicWaves.amplitude;
            var direction=basicWaves.direction;
            var wavelength=basicWaves.wavelength;
            var numWaves=basicWaves.numWaves;
            _waves=new Wave[numWaves];

            var r=1f/numWaves;

            for(int i=0;i<numWaves;i++){
                var p=Mathf.Lerp(0.5f,1.5f,i*r);
                var amp=amplitude*p*Random.Range(0.8f,1.2f);
                var dir=direction+Random.Range(-90.0f,90.0f);
                var len=wavelength*p*Random.Range(0.6f,1.4f);

                _waves[i]=new Wave(amp,dir,len,Vector2.zero,false);
                Random.InitState(waterSurfaceData.randomSeed+i+1);
            }

            Random.state=backupSeed;

        }
        else
        {
            _waves=waterSurfaceData._Waves.ToArray();
        }

    }

    private void GenerateColorRamp(){
        if(_rampTexture==null)
            _rampTexture=new Texture2D(128,4,GraphicsFormat.R8G8B8A8_SRGB,TextureCreationFlags.None);
        _rampTexture.wrapMode=TextureWrapMode.Clamp;

        var defaultFoamRamp=resources.defaultFoamRamp;

        var colors=new Color[512];
        for(var i=0;i<128;i++){
            colors[i]=waterSurfaceData._absorptionRamp.Evaluate(i/128f);
        }

        for(var i=0;i<128;i++){
            colors[i+128]=waterSurfaceData._scatterRamp.Evaluate(i/128f);
        }

        for(var i=0;i<128;i++){
            switch(waterSurfaceData._foamSettings.foamType)
            {
                case 0://default auto
                colors[i+256]=defaultFoamRamp.GetPixelBilinear(i/128f,0.5f);
                break;
                case 1://simple
                colors[i+256]=defaultFoamRamp.GetPixelBilinear(waterSurfaceData._foamSettings.basicFoam.Evaluate(i/128f),0.5f);
                break;
                case 2://custom
                colors[i+256]=Color.black;
                break;
            }
        }
        _rampTexture.SetPixels(colors);
        _rampTexture.Apply();
        Shader.SetGlobalTexture(_sAbsorptionScatteringRampTex,_rampTexture);
    }


    [ContextMenu("Capture Depth")]
    public void CaptureDepthMap(){
        if(_depthCam==null){
            var go=new GameObject("depthCamera"){
                hideFlags=HideFlags.HideAndDontSave
            };
            _depthCam=go.AddComponent<Camera>();
        }
        var additionalCamData=_depthCam.GetUniversalAdditionalCameraData();
        additionalCamData.renderShadows=false;
        additionalCamData.requiresColorOption=CameraOverrideOption.Off;
        additionalCamData.requiresDepthOption=CameraOverrideOption.Off;

        var trans=_depthCam.transform;
        var depthExtra=4.0f;
        trans.position=Vector3.up*(transform.position.y+depthExtra);
        trans.up=Vector3.forward;

        _depthCam.enabled=true;
        _depthCam.orthographic=true;
        _depthCam.orthographicSize=250;
        _depthCam.nearClipPlane=0.01f;
        _depthCam.farClipPlane=waterSurfaceData._waterMaxVisibility+depthExtra;
        _depthCam.allowHDR=false;
        _depthCam.allowMSAA=false;
        _depthCam.cullingMask=(1<<9);

        if(!_depthTex)
            _depthTex=new RenderTexture(1024,1024,24,RenderTextureFormat.Depth,RenderTextureReadWrite.Linear);
        if(SystemInfo.graphicsDeviceType==GraphicsDeviceType.OpenGLES2||
            SystemInfo.graphicsDeviceType==GraphicsDeviceType.OpenGLES3
        )
        {
            _depthTex.filterMode=FilterMode.Point;
        }
        _depthTex.wrapMode=TextureWrapMode.Clamp;
        _depthTex.name="WaterDepthMap";

        _depthCam.targetTexture=_depthTex;
        _depthCam.Render();

        Shader.SetGlobalTexture(Shader.PropertyToID("_WaterDepthMap"),_depthTex);


        var _params=new Vector4(trans.position.y,250,0,0);
        Shader.SetGlobalVector(Shader.PropertyToID("_Water_DepthCamParams"),_params);


        _depthCam.enabled=false;
        _depthCam.targetTexture=null;
    }


    [ContextMenu("Debug")]
    public void DebugLog() {
            Debug.Log(computeOverride); 
    }
}


}

