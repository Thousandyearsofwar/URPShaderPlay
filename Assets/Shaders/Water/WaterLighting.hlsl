#ifndef WATER_LIGHTING_INCLUDED
#define WATER_LIGHTING_INCLUDED
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

half CalculateFresnelTerm(half3 normalWS,half3 viewDirWS){
return saturate(pow(1.0-dot(normalWS,viewDirWS),5));
}

half SoftShadows(float3 screenUV,float3 positionWS){

    half2 jitterUV=screenUV.xy*_ScreenParams.xy*_DitherPattern_TexelSize.xy;
    half shadowAttuation=0;

    uint loop=4;
    float loopDiv=1.0/loop;
    for(uint i=0u;i<loop;++i){
        #ifndef _STATIC_WATER
            jitterUV+=frac(half2(_Time.x,_Time.z));
        #endif
        float3 jitterTex = SAMPLE_TEXTURE2D(_DitherPattern, sampler_DitherPattern, jitterUV + i * _ScreenParams.xy).xyz * 2 - 1;
        float3 lightJitter=positionWS+jitterTex.xzy*2;

        shadowAttuation+=SAMPLE_TEXTURE2D_SHADOW(_MainLightShadowmapTexture,sampler_MainLightShadowmapTexture,TransformWorldToShadowCoord(lightJitter));

    }
    return BEYOND_SHADOW_FAR(TransformWorldToShadowCoord(positionWS*1.1))?1.0:shadowAttuation*loopDiv;
}

half3 SampleReflections(half3 normalWS,half3 viewDirectionWS,half2 screenUV,half roughness){

    half3 reflection=0;
    half2 reOffset=0;

    #if _REFLECTION_CBUEMAP
        half3 reflectVector=reflect(- viewDirectionWS,normalWS);
        reflection=SAMPLE_TEXTURECUBE(_CubeMapTexture,sampler_CubeMapTexture,reflectVector).rgb;
    #elif _REFLECTION_PROBES
        half3 reflectVector=reflect(-viewDirectionWS,normalWS);
        reflection= GlossyEnvironmentReflection(reflectVector,0,1);
    #elif _REFLECTION_PLANARREFLECTION

        float2 p11_22 =float2(unity_CameraInvProjection._11,unity_CameraInvProjection._22)*10;

        float3 viewDir=-(float3((screenUV*2-1)/p11_22,-1));

        half3 viewNormal=mul(normalWS,(float3x3)GetWorldToViewMatrix()).xyz;
        half3 reflectVector=reflect(-viewDir,viewNormal);

        half2 reflectionUV=screenUV+normalWS.zx*half2(0.02,0.15);
        reflection+=SAMPLE_TEXTURE2D_LOD(_PlanarReflectionTexture,sampler_ScreenTextures_linear_clamp,reflectionUV,6*roughness).rgb;
    #endif

    return reflection;
}



#endif