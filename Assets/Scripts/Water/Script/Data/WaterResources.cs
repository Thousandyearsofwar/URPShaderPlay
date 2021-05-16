using System.Collections;
using System.Collections.Generic;
using Unity.Mathematics;
using UnityEngine;
namespace Water{
    [System.Serializable][CreateAssetMenu(fileName="WaterResources",menuName="Water/Resource",order=0)]
public class WaterResources : ScriptableObject
{
    public Texture2D defaultFoamRamp;

    public Texture2D defaultFoamMap;

    public Texture2D defaultSurfaceMap;

    public Material defaultWaterMaterial;

    public Mesh[] defaultWaterMeshes;
}

}

