#ifndef WATER_INPUT_INCLUDED
#define WATER_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

CBUFFER_START(UnityPerMaterial)
half _BumpScale;
half4 _DitherPattern_TexelSize;
//_waterMaxVisibility
half _MaxDepth;
half _MaxWaveHeight;

half4 _Water_DepthCamParams;
float4x4 _InvViewProjection;
CBUFFER_END



//使用双线性插值 filtering和clamp的warp mode
SAMPLER(sampler_ScreenTextures_linear_clamp);

#if defined(_REFLECTION_PLANARREFLECTION)
TEXTURE2D(_PlanarReflectionTexture);
#elif defined(_REFLECTION_CBUEMAP)
TEXTURECUBE(_CubeMapTexture);SAMPLER(sampler_CubeMapTexture);
#endif

TEXTURE2D(_WaterFXMap);

TEXTURE2D(_CameraDepthTexture);
TEXTURE2D(_CameraOpaqueTexture);SAMPLER(sampler_CameraOpaqueTexture_linear_clamp);

TEXTURE2D(_WaterDepthMap);SAMPLER(sampler_WaterDepthMap_linear_clamp);


TEXTURE2D(_AbsorptionScatteringRamp);SAMPLER(sampler_AbsorptionScatteringRamp);
TEXTURE2D(_SurfaceMap);SAMPLER(sampler_SurfaceMap);
TEXTURE2D(_FoamMap);SAMPLER(sampler_FoamMap);
TEXTURE2D(_DitherPattern);SAMPLER(sampler_DitherPattern);
#endif