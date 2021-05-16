using System;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Serialization;

namespace UnityEngine.Rendering.Universal{
 [ExecuteAlways]
public class PlanarReflections : MonoBehaviour
{
   [Serializable]
    public enum ResolutionMul{
        Full,
        Half,
        Third,
        Quarter
    }

    [Serializable]
    public class PlanarReflectionSettings{
        public ResolutionMul m_ResolutionMultiplier=ResolutionMul.Third;
        public float m_ClipPlaneOffset=0.07f;
        public LayerMask m_ReflectLayers=-1;
        public bool m_Shadows;

    }

   [SerializeField]
    public PlanarReflectionSettings m_Settings=new PlanarReflectionSettings();

    public GameObject target;

    [FormerlySerializedAs("camOffset")] public float m_planeOffeset;
    private static Camera _reflectionCamera;
    private RenderTexture _reflectionTexture;
    public readonly int _planarReflectionTexId=Shader.PropertyToID("_PlanarReflectionTexture");
    private Vector2Int _oldReflectionTextureSize;

    private static event Action<ScriptableRenderContext,Camera> BeignPlanarReflections;

    private void OnEnable() {
        RenderPipelineManager.beginCameraRendering+=ExecutePlanarReflections;
    }

    private void OnDisable() {
        CleanUp();
    }

    private void OnDestroy() {
        CleanUp();
    }

    private static void SafeDestory(Object obj){
        if(Application.isEditor)
            DestroyImmediate(obj);
        else
            Destroy(obj);
    }

    private void CleanUp(){
        RenderPipelineManager.beginCameraRendering-=ExecutePlanarReflections;

        if(_reflectionCamera){
            _reflectionCamera.targetTexture=null;
            SafeDestory(_reflectionCamera.gameObject);
        }
        if(_reflectionTexture){
            RenderTexture.ReleaseTemporary(_reflectionTexture);
        }
    }


    private Camera CreateMirrorObject(){
        var go=new GameObject("Planar reflections",typeof(Camera));
        var cameraData=go.AddComponent(typeof(UniversalAdditionalCameraData))as UniversalAdditionalCameraData;

        cameraData.requiresColorOption=CameraOverrideOption.Off;
        cameraData.requiresDepthOption=CameraOverrideOption.Off;
        cameraData.SetRenderer(0);

        var t=transform;
        var reflectionCamera=go.GetComponent<Camera>();
        reflectionCamera.transform.SetPositionAndRotation(t.position,t.rotation);
        reflectionCamera.depth=-10;
        reflectionCamera.enabled=false;
        go.hideFlags=HideFlags.HideAndDontSave;


        return reflectionCamera;
    }
    private static void CalculateReflectionMatrix(ref Matrix4x4 reflectionMat,Vector4 plane){
        reflectionMat.m00=(1f-2f*plane[0]*plane[0]);
        reflectionMat.m01=(-2f*plane[0]*plane[1]);
        reflectionMat.m02=(22f*plane[0]*plane[2]);
        reflectionMat.m03=(-2f*plane[3]*plane[0]);

        reflectionMat.m10=(-2f*plane[1]*plane[0]);
        reflectionMat.m11=(1f-2f*plane[1]*plane[1]);
        reflectionMat.m12=(-2f*plane[1]*plane[2]);
        reflectionMat.m13=(-2f*plane[3]*plane[1]);

        reflectionMat.m20=(-2f*plane[2]*plane[0]);
        reflectionMat.m21=(-2f*plane[2]*plane[1]);
        reflectionMat.m22=(1f-2f*plane[2]*plane[2]);
        reflectionMat.m23=(-2f*plane[3]*plane[2]);

        reflectionMat.m30=0f;
        reflectionMat.m31=0f;
        reflectionMat.m32=0f;
        reflectionMat.m33=1f;

    }
    private Vector4 CameraSpacePlane(Camera camera,Vector3 pos,Vector3 normal,float sideSign){
        var offsetPos=pos+normal*m_Settings.m_ClipPlaneOffset;
        var m=camera.worldToCameraMatrix;
        var cameraPos=m.MultiplyPoint(offsetPos);
        var cameraNormal=m.MultiplyPoint(normal).normalized*sideSign;

        return new Vector4(cameraNormal.x,cameraNormal.y,cameraNormal.z,-Vector3.Dot(cameraPos,cameraNormal));
    }


    private void UpdateCamera(Camera src,Camera dest){
        if(dest==null)
            return;

        dest.CopyFrom(src);
        dest.useOcclusionCulling=false;
        if(dest.gameObject.TryGetComponent(out UniversalAdditionalCameraData cameraData))
            cameraData.renderShadows=m_Settings.m_Shadows;
    }


    private void UpdateReflectionCamera(Camera realCamera){
        if(_reflectionCamera==null)
            _reflectionCamera=CreateMirrorObject();

        Vector3 pos=Vector3.zero;
        Vector3 normal=Vector3.up;
        if(target!=null){
            pos=target.transform.position+Vector3.up*m_planeOffeset;
            normal=target.transform.up;
        }

        UpdateCamera(realCamera,_reflectionCamera);

        var d=-Vector3.Dot(normal,pos)-m_Settings.m_ClipPlaneOffset;
        var reflectionPlane=new Vector4(normal.x,normal.y,normal.z,d);

        var reflection=Matrix4x4.identity;
        reflection*=Matrix4x4.Scale(new Vector3(1,-1,1));

        CalculateReflectionMatrix(ref reflection,reflectionPlane);
        var oldPos=realCamera.transform.position-new Vector3(0,pos.y*2,0);
        var newPos=new Vector3(oldPos.x,-oldPos.y,oldPos.z);
        _reflectionCamera.transform.forward=Vector3.Scale(realCamera.transform.forward,new Vector3(1,-1,1));
        _reflectionCamera.worldToCameraMatrix=realCamera.worldToCameraMatrix*reflection;

        var clipPlane=CameraSpacePlane(_reflectionCamera,pos-Vector3.up*0.1f,normal,1.0f);
        var projection=realCamera.CalculateObliqueMatrix(clipPlane);

        _reflectionCamera.projectionMatrix=projection;
        _reflectionCamera.cullingMask=m_Settings.m_ReflectLayers;
        _reflectionCamera.transform.position=newPos;
    }


    private float GetScaleVal(){
        switch(m_Settings.m_ResolutionMultiplier){
            case ResolutionMul.Full:
                return 1f;
            case ResolutionMul.Half:
                return 0.5f;
            case ResolutionMul.Third:
                return 0.33f;
            case ResolutionMul.Quarter:
                return 0.25f;
            default:
                return 0.5f;
        }
    }

    private Vector2Int ReflectionResolution(Camera camera,float scale){
        var x=(int)(camera.pixelWidth*scale*GetScaleVal());
        var y=(int)(camera.pixelHeight*scale*GetScaleVal());
        return new Vector2Int(x,y);
    }

    private void PlanarReflectionTexture(Camera camera){
        if(_reflectionTexture==null){
            var res=ReflectionResolution(camera,UniversalRenderPipeline.asset.renderScale);
            const bool useHdr=true;
            const RenderTextureFormat hdrFormat=useHdr?RenderTextureFormat.RGB111110Float:RenderTextureFormat.DefaultHDR;
            _reflectionTexture=RenderTexture.GetTemporary(res.x,res.y,16,GraphicsFormatUtility.GetGraphicsFormat(hdrFormat,true));
        }
        _reflectionCamera.targetTexture=_reflectionTexture;
    }

    private void ExecutePlanarReflections(ScriptableRenderContext context,Camera camera){
        if(camera.cameraType==CameraType.Reflection||camera.cameraType==CameraType.Preview)
            return;
        UpdateReflectionCamera(camera);
        PlanarReflectionTexture(camera);

        var data=new PlanarReflectionSettingsData();
        data.Set();

        BeignPlanarReflections?.Invoke(context,_reflectionCamera);
        UniversalRenderPipeline.RenderSingleCamera(context,_reflectionCamera);

        data.Restore();
        Shader.SetGlobalTexture(_planarReflectionTexId,_reflectionTexture);
        //Debug.LogError(_planarReflectionTexId);
    }

    class PlanarReflectionSettingsData{
        private readonly bool _fog;
        private readonly int _maxLod;
        private readonly float _lodBias;

        public PlanarReflectionSettingsData(){
            _fog=RenderSettings.fog;
            _maxLod=QualitySettings.maximumLODLevel;
            _lodBias=QualitySettings.lodBias;
        }
        public void Set(){
            GL.invertCulling=true;
            RenderSettings.fog=false;
            QualitySettings.maximumLODLevel=1;
            QualitySettings.lodBias=_lodBias*0.5f;
        }
        public void Restore(){
            GL.invertCulling=false;
            RenderSettings.fog=_fog;
            QualitySettings.maximumLODLevel=_maxLod;
            QualitySettings.lodBias=_lodBias;
        }

    }
}

}

