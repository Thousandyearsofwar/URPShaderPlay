using System.Collections;
using System.Collections.Generic;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace Water.Data{
    [System.Serializable][CreateAssetMenu(fileName="WaterSettingData",menuName="Water/Settings",order=0)]
public class WaterSettingData : ScriptableObject
{
    public ReflectionType reflectionType;

    public PlanarReflections.PlanarReflectionSettings planarReflectionSettings;

    public Vector4 originOffset=new Vector4(0f,0f,500f,500f);

}

[System.Serializable]
public enum ReflectionType{
    CubeMap,
    ReflectionProbe,
    PlanarReflection
}

}

