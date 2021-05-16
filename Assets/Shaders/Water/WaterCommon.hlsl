#ifndef WATER_COMMON_INCLUDED
#define WATER_COMMON_INCLUDED

#define SHADOWS_SCREEN 0

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "WaterInput.hlsl"
#include "WaterUtilities.hlsl"
#include "GerstnerWaves.hlsl"
#include "WaterLighting.hlsl"

struct WaterVertexInput{
    float4 posOS:POSITION;
    float2 texcoord:TEXCOORD0;
    
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct WaterVertexOutput{
    float4 texcoord:TEXCOORD0;
    float3 posWS:TEXCOORD1;
    half3 normal:NORMAL;
    float3 viewDir:TEXCOORD2;
    float3 preWaveSP:TEXCOORD3;
    half2 fogFactorNoise:TEXCOORD4;
    float4 additionalData:TEXCOORD5;
    half4 shadowCoord:TEXCOORD6;
    
    float4 clipPos:SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};


float2 AdjustedDepth(half2 uvs,half4 additionalData){
    float rawDepth=SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,sampler_ScreenTextures_linear_clamp,uvs);
    float depth=LinearEyeDepth(rawDepth,_ZBufferParams);
    return float2(depth*additionalData.x-additionalData.y,(rawDepth*-_ProjectionParams.x)+(1-UNITY_REVERSED_Z));
}

float WaterTextureDepth(float3 posWS){
    return (1-SAMPLE_TEXTURE2D_LOD(_WaterDepthMap,sampler_WaterDepthMap_linear_clamp,posWS.xz*0.002+0.5,1).r)*
    (_MaxDepth+_Water_DepthCamParams.x)-_Water_DepthCamParams.x;
}

float3 WaterDepth(float3 posWS,half4 additionalData,half2 screenUVs){
    float3 outDepth=0;
    outDepth.xz=AdjustedDepth(screenUVs,additionalData);//x /z=0?

    float waterDepth=WaterTextureDepth(posWS);
    outDepth.y=waterDepth+posWS.y;
    return outDepth;

}

half2 DistortionUVs(half depth,float3 normalWS){
    half3 viewNormal=mul((float3x3)GetWorldToHClipMatrix(),-normalWS).xyz;

    return viewNormal.xz*saturate(depth*0.005);
}


half3 Scattering(half depth){
    return SAMPLE_TEXTURE2D(_AbsorptionScatteringRamp,sampler_AbsorptionScatteringRamp,half2(depth,0.375h)).rgb;
}

half3 Absorption(half depth){
    return SAMPLE_TEXTURE2D(_AbsorptionScatteringRamp,sampler_AbsorptionScatteringRamp,half2(depth,0.0h)).rgb;
}

//折射
half3 Refraction(half2 distortion,half depth,real depthMulti){
    half3 output=SAMPLE_TEXTURE2D_LOD(_CameraOpaqueTexture,sampler_CameraOpaqueTexture_linear_clamp,distortion,depth*0.25).rgb;
    output *=Absorption((depth)*depthMulti);
    return output;
}


half4 AdditionalData(float3 positionWS,WaveStruct wave){
    half4 data=half4(0,0,0,0);
    float3 viewPos=TransformWorldToView(positionWS);
    data.x=length(viewPos/viewPos.z);//透视除法之后再求distance to surface 虽然是逐顶点
    data.y=length(GetCameraPositionWS().xyz-positionWS);//camera to vertexPosWS
    data.z=wave.position.y/_MaxWaveHeight*0.5+0.5;//[-1,1]->[0,1] waveHeight
    data.w=wave.position.x+wave.position.z;
    return data;
}


WaterVertexOutput WaveVertexOperations(WaterVertexOutput input){
    #if defined(_STATIC_WATER)
        float time=0;
    #else
        float time=_Time.y;
    #endif

    input.normal=float3(0,1,0);
    input.fogFactorNoise.y=(
        noise((input.posWS.xz*0.5)+time)
        +noise(input.posWS.xz+time)
        )*0.25+0.5;
    
    input.texcoord.zw=input.posWS.xz*0.1+time*0.05+(input.fogFactorNoise.y*0.1);
    input.texcoord.xy=input.posWS.xz*0.4-time*0.1+(input.fogFactorNoise.y*0.2);

    half4 screenUV=ComputeScreenPos(TransformWorldToHClip(input.posWS));
    screenUV.xyz/=screenUV.w;

    half waterDepth=WaterTextureDepth(input.posWS);
    input.posWS.y+=pow(saturate((-waterDepth+1.5)*0.4),2);

    WaveStruct wave;
    SampleWaves(input.posWS,saturate((waterDepth*0.1+0.05)),wave);
    input.normal=wave.normal;
    input.posWS+=wave.position;

    half4 waterFX=SAMPLE_TEXTURE2D_LOD(_WaterFXMap,sampler_ScreenTextures_linear_clamp,screenUV.xy,0);
    input.posWS.y+=waterFX.w*2-1;//[0,1]->[-1,1]

    input.clipPos=TransformWorldToHClip(input.posWS);
    input.shadowCoord=ComputeScreenPos(input.clipPos);
    input.viewDir=SafeNormalize(_WorldSpaceCameraPos-input.posWS);

    input.fogFactorNoise.x=ComputeFogFactor(input.clipPos.z);
    input.preWaveSP=screenUV.xyz;

    input.additionalData=AdditionalData(input.posWS,wave);

    half distanceBlend=saturate ( abs( length((_WorldSpaceCameraPos.xz-input.posWS.xz)*0.005))-0.25);
    input.normal=lerp(input.normal,half3(0,1,0),distanceBlend);

    return input;
}

WaterVertexOutput WaterVertex(WaterVertexInput input){
    WaterVertexOutput output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input,output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    output.texcoord.xy=input.texcoord;
    output.posWS=TransformObjectToWorld(input.posOS.xyz);

    output=WaveVertexOperations(output);
    return output;
}

float4 WaterFragment(WaterVertexOutput input):SV_TARGET{
    UNITY_SETUP_INSTANCE_ID(input);
    half3 screenUV=input.shadowCoord.xyz/input.shadowCoord.w;

    float3 depth=WaterDepth(input.posWS,input.additionalData,screenUV.xy);
    half depthMulti=1/_MaxDepth;

    half2 detailBump0=SAMPLE_TEXTURE2D(_SurfaceMap,sampler_SurfaceMap,input.texcoord.xy).xy*2-1;
    half2 detailBump1=SAMPLE_TEXTURE2D(_SurfaceMap,sampler_SurfaceMap,input.texcoord.zw).xy*2-1;
    half2 detailBump=(detailBump0*0.5+detailBump1)*saturate(depth.x*0.25+0.25);

    input.normal+=half3(detailBump.x,0,detailBump.y)*_BumpScale;
    input.normal=normalize(input.normal);

    Light mainLight=GetMainLight(TransformWorldToShadowCoord(input.posWS));
    half Shadow=SoftShadows(screenUV,input.posWS);
    half GI=SampleSH(input.normal);

    half3 directLighting=dot(mainLight.direction,half3(0,1,0))*mainLight.color;
    directLighting=saturate(pow(dot(input.viewDir,-mainLight.direction)*input.additionalData.z,3))*5*mainLight.color;
    half3 sss=directLighting*Shadow+GI;

    //foam
    half3 foamTex=SAMPLE_TEXTURE2D(_FoamMap,sampler_FoamMap,input.texcoord.zw).rgb;
    half depthEdge=saturate(depth.x*20);
    half H0=0.75;
    half HMax=1;
    half waveFoam=saturate((input.additionalData.z-H0)/(HMax-H0));

    half depthAdd=saturate(1-depth.x*4)*0.5;
    half edgeFoam=saturate((1-min(depth.x,depth.y)*0.5-0.25)+depthAdd)*depthEdge;
    half foamBlendMask=max(max(waveFoam,edgeFoam),0);
    half foamBlend=SAMPLE_TEXTURE2D(_AbsorptionScatteringRamp,sampler_AbsorptionScatteringRamp,half2(foamBlendMask,0.66)).rgb;
    half foamMask=saturate(length(foamTex*foamBlend)*1.5-0.1);

    half3 foam=foamMask.xxx*(mainLight.shadowAttenuation*mainLight.color+GI);

    //Distortion

    half2 distortion=DistortionUVs(depth.x,input.normal);
    distortion=screenUV.xy+distortion;
    float d=depth.x;
    depth.xz=AdjustedDepth(distortion,input.additionalData);
    distortion=depth.x<0?screenUV.xy:distortion;
    depth.x=depth.x<0?d:depth.x;


    //Fresnel
    half fresnel=CalculateFresnelTerm(input.normal,input.viewDir.xyz);


    BRDFData brdfData;
    InitializeBRDFData(half3(0,0,0),0,half3(1,1,1),0.95,1,brdfData);
    half3 spec=DirectBDRF(brdfData,input.normal,mainLight.direction,input.viewDir)*Shadow*mainLight.color;
    #ifdef _ADDITIONAL_LIGHTS
        uint pixelLightCount=GetAdditionalLightsCount();
        for(uint lightIndex=0u;lightIndex<pixelLightCount;++lightIndex){
            Light light=GetAdditionalLight(lightIndex,input.posWS);
            spec+=LightingPhysicallyBased(brdfData,light,input.normal,input.viewDir);
            sss+=light.distanceAttenuation*light.color;
        }
    #endif

    sss*=Scattering(depth.x*depthMulti);

    half3 reflection=SampleReflections(input.normal,input.viewDir.xyz,screenUV.xy,0.0);

    half3 refraction=Refraction(distortion,depth.x,depthMulti);

    half3 comp=lerp(lerp(refraction,reflection,fresnel)+sss+spec,foam,foamMask);

    float4 debug=float4(1,1,1,1);
    debug.xyz*=spec;

    return float4(comp,1.0f);
}

#endif