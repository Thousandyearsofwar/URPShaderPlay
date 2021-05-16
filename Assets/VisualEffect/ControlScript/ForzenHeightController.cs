using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ForzenHeightController : MonoBehaviour
{
    public float forzenHeight;
    public ParticleSystem forzenParticle;


    public Material[] TernadoMaterials;


    // Start is called before the first frame update
    void Start()
    {
        forzenHeight = 0;
        
        foreach (var mat in TernadoMaterials)
            mat.SetFloat("FrozenHeight", 0);
    }

    // Update is called once per frame
    void Update()
    {      
        foreach (var mat in TernadoMaterials)
            mat.SetFloat("FrozenHeight", forzenHeight);
    }

    private void OnDestroy()
    {
        foreach (var mat in TernadoMaterials)
            mat.SetFloat("FrozenHeight", 0);
    }

    private void OnValidate()
    {
        foreach (var mat in TernadoMaterials)
            mat.SetFloat("FrozenHeight", 0);
    }
}
