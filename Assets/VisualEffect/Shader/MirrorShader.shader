Shader "URP/MirrorShader"
{
    Properties
    {
        _BaseMap ("MainTex", 2D) = "white" {}
        _NoiseMap ("NoiseTex", 2D) = "white" {}
		_BaseColor("BaseColor",Color)=(1,1,1,1)
		_SpecularRange("SpecularRange",Range(10,300))=10
		[HDR]_SpecColor("SpecularColor",Color)=(1,1,1,1)
		[Normal]_NormalTex("Normal",2D)="bump"{}
		_NormalScale("NormalScale",Range(0,1))=1
		_Amount("amount",float)=100
		_Blur("Blur",float)=100
		[KeywordEnum(WS_N,TS_N)]_NORMAL_OFFSET("_NormalOffset",Float)=1

		[HideInInspector] _ZWrite("__zw", Float) = 1.0
		[HideInInspector] _SrcBlend("__src", Float) = 1.0
        [HideInInspector] _DstBlend("__dst", Float) = 0.0
		[HideInInspector] _Cull("__cull", Float) = 2.0
    }
    SubShader
    {
        Tags { 
		"RenderType"="Transparent" 
		"Queue"="Transparent" 
		"RenderPipeline"="UniversalRenderPipeline"

		}
        LOD 100
		HLSLINCLUDE
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			CBUFFER_START(UnityPerMaterial)
				float4 _BaseMap_ST;
				half4 _BaseColor;
				half4 _SpecColor;
				half4 _EmissionColor;
				half _Cutoff;
				half _Smoothness;
				half _Metallic;
				half _BumpScale;
				half _OcclusionStrength;
				half _SpecularRange;
				float _Amount;
				float _Blur;
			CBUFFER_END

			TEXTURE2D(_BaseMap);	SAMPLER(sampler_BaseMap);
			TEXTURE2D(_NoiseMap);	SAMPLER(sampler_NoiseMap);
			TEXTURE2D(_NormalTex);	SAMPLER(sampler_NormalTex);
			float4 _CameraColorTexture_TexelSize;
			SAMPLER(_CameraColorTexture);

			struct Attributes{
				float4 positionOS:POSITION;
				float4 normalOS:NORMAL;
				float4 tangentOS:TANGENT;
				float2 texcoord:TEXCOORD;
			};

			struct Varyings{
				float4 positionCS:SV_POSITION;
				float3 positionWS:VAR_POSITION;
				float3 normalWS:VAR_NORMAL;
				float2 texcoord:TEXCOORD;
			};
		ENDHLSL
        Pass
        {
		Tags{
				"LightMode"="UniversalForward"
			}

			Blend[_SrcBlend][_DstBlend]
            ZWrite[_ZWrite]
            Cull[_Cull]
            HLSLPROGRAM
			

			#pragma vertex LitPassVertex
			#pragma fragment LitPassFragment

			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE

			#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
			
			#pragma multi_compile _ _SHADOWS_SOFT

			#pragma shader_feature_local _NORMAL_OFFSET_WS_N


			Varyings LitPassVertex(Attributes input){
				Light mainLight=GetMainLight();
				float3 L=normalize(mainLight.direction);

				Varyings output;
				output.positionCS=TransformObjectToHClip(input.positionOS.xyz);
				output.positionWS=TransformObjectToWorld(input.positionOS.xyz);
				output.texcoord=TRANSFORM_TEX(input.texcoord,_BaseMap);

				float3x3 normalMatrix=transpose((float3x3)UNITY_MATRIX_M);
				output.normalWS=normalize(mul(input.normalOS.xyz,normalMatrix));

				

				return output;
			}

			float4 LitPassFragment(Varyings input):SV_TARGET{
				
				float3 color =(SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,input.texcoord)*_BaseColor).rgb;

				float3 N=normalize(input.normalWS);

				float2 SS_texcoord=input.positionCS.xy/_ScreenParams.xy;

				float2 SS_bias=N.xy*_Amount*_CameraColorTexture_TexelSize.xy;

				float4 glassColor=tex2D(_CameraColorTexture,SS_texcoord+SS_bias);


				glassColor+=tex2D(_CameraColorTexture,SS_texcoord+float2(-1,-1)*_CameraColorTexture_TexelSize.xy*_Blur);
				glassColor+=tex2D(_CameraColorTexture,SS_texcoord+float2(1,-1)*_CameraColorTexture_TexelSize.xy*_Blur);
				glassColor+=tex2D(_CameraColorTexture,SS_texcoord+float2(-1,1)*_CameraColorTexture_TexelSize.xy*_Blur);
				glassColor+=tex2D(_CameraColorTexture,SS_texcoord+float2(1,1)*_CameraColorTexture_TexelSize.xy*_Blur);

				glassColor*=0.2f;



				Light mainLight=GetMainLight(TransformWorldToShadowCoord(input.positionWS));
				float3 LightColor=mainLight.color;

				float3 L=normalize(mainLight.direction);
				
				float3 V=normalize(GetCameraPositionWS()-input.positionWS);
				float3 H=normalize(V+L);
				float NdotL=max(dot(L,N),0.0);
				float NdotH=max(dot(N,H),0.0);

				float  diff=NdotL;
				float3 diffuse=diff*color;


				float3 spec=pow(NdotH,_SpecularRange);
				float3 specular=LightColor*spec*_SpecColor.rgb;

				float3 mainLightColor=(diffuse+specular)*color*mainLight.shadowAttenuation;

				int addLightsCount=GetAdditionalLightsCount();
				float3 addLightColor=float3(0,0,0);
				for(int i=0;i<addLightsCount;i++){
					Light addLight=GetAdditionalLight(i,input.positionWS);
					float3 add_L=normalize(addLight.direction);
					
					float3 add_H=normalize(V+add_L);
					float add_NdotL=saturate(dot(add_L,N));
					float add_NdotH=saturate(dot(add_H,N));

					float  add_diff=add_NdotL;
					float3 add_Diffuse=add_diff*color;


					float3 add_spec=pow(add_NdotH,_SpecularRange);
					float3 add_Specular=add_spec*_SpecColor.rgb;


					addLightColor+=(add_Diffuse+add_Specular)*addLight.color*addLight.distanceAttenuation*addLight.shadowAttenuation;
				}


				

				return float4(glassColor.xyz+mainLightColor+addLightColor,1.0);
			}

			ENDHLSL
        }





		UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}
