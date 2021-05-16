Shader "URP/ToneShader0"
{
    Properties
    {
        _RAMPTex ("RAMP", 2D) = "white" {}
        _BaseMap ("MainTex", 2D) = "white" {}
		_BaseColor("BaseColor",Color)=(1,1,1,1)

		_FresnelColor("FresnelColor",Color)=(1,1,1,1)

		_LineColor("LineColor",Color)=(1,1,1,1)
		
		_LineWidth("LineWidth",Range(0,0.0015))=0

		_OffsetU("Offset",Range(0,1))=0
		_Fresnel("Fresnel",Range(0,1))=0
		_OffsetN0("Offset Normal0",vector)=(0,0,0)
		_OffsetN1("Offset Normal1",vector)=(0,0,0)

		_SpecularSpotThreshold0("Threshold0",Range(0.9,1))=1
		_SpecularSpotThreshold1("Threshold1",Range(0.9,1))=1

		[HideInInspector] _ZWrite("__zw", Float) = 1.0
		[HideInInspector] _SrcBlend("__src", Float) = 1.0
        [HideInInspector] _DstBlend("__dst", Float) = 0.0
		[HideInInspector] _Cull("__cull", Float) = 2.0

       
    }
    SubShader
    {
        Tags { 
		"RenderType"="Opaque" 
		"RenderPipeline"="UniversalRenderPipeline"

		}
        LOD 100
		HLSLINCLUDE
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/BSDF.hlsl"
			CBUFFER_START(UnityPerMaterial)
				float4 _BaseMap_ST;
				float4 _BaseColor;
				float4 _LineColor;
				float4 _FresnelColor;
				float _LineWidth;

				float _Fresnel;

				float _OffsetU;
				

				float3 _OffsetN0;
				float3 _OffsetN1;

				float _SpecularSpotThreshold0;
				float _SpecularSpotThreshold1;
			CBUFFER_END

			TEXTURE2D(_BaseMap);	SAMPLER(sampler_BaseMap);
			TEXTURE2D(_RAMPTex);	SAMPLER(sampler_RAMPTex);

			struct Attributes{
				float4 positionOS:POSITION;
				float3 normalOS:NORMAL;
				float2 texcoord:TEXCOORD0;
				
			};

			struct Varyings{
				float4 positionCS:SV_POSITION;
				
				float3 normalWS:NORMAL;
				
				float2 texcoord:TEXCOORD0;
				float3 viewDirWS:TEXCOORD1;
				float3 positionWS:TEXCOORD2;
			};
		ENDHLSL
		Pass{
		
		Blend[_SrcBlend][_DstBlend]
        ZWrite[_ZWrite]
        Cull Front
		HLSLPROGRAM
		#pragma vertex LitPassVertex
		#pragma fragment LitPassFragment

		Varyings LitPassVertex(Attributes input){
				Varyings output;
				VertexPositionInputs vertexInput=GetVertexPositionInputs(input.positionOS);

				output.positionCS=TransformObjectToHClip(float4(input.positionOS.xyz+input.normalOS*_LineWidth,1));
				
				output.normalWS=normalize(TransformObjectToWorldNormal(input.normalOS));
				output.texcoord=TRANSFORM_TEX(input.texcoord,_BaseMap);

				output.viewDirWS=GetCameraPositionWS()-vertexInput.positionWS;
				return output;
		}

		float4 LitPassFragment(Varyings input):SV_TARGET{
				return float4(_LineColor.xyz,1.0);
		}


		ENDHLSL
		}



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

			Varyings LitPassVertex(Attributes input){
				Varyings output;
				VertexPositionInputs vertexInput=GetVertexPositionInputs(input.positionOS);

				output.positionCS=vertexInput.positionCS;

				output.normalWS=normalize(TransformObjectToWorldNormal(input.normalOS));
				output.texcoord=TRANSFORM_TEX(input.texcoord,_BaseMap);

				output.positionWS=vertexInput.positionWS;
				return output;
			}

			float4 LitPassFragment(Varyings input):SV_TARGET{
				Light mainLight=GetMainLight();
				float3 LightColor=mainLight.color;

				

				float3 N=input.normalWS;
				float3 L=normalize(mainLight.direction);
				float3 V=SafeNormalize(GetCameraPositionWS()-input.positionWS);
				float3 H=normalize(V+L);

				float NdotL=saturate(dot(L,N));
				
				NdotL=NdotL*0.5f+0.5f;
				float3 rampColor =SAMPLE_TEXTURE2D(_RAMPTex,sampler_RAMPTex,float2(NdotL+_OffsetU,1.0)).rgb;

				//calculate Specular part
				float3 N_Offset0=normalize(N+_OffsetN0);
				NdotL=saturate(dot(L,N_Offset0));
				float Specular0=step(_SpecularSpotThreshold0,NdotL);

				
				float3 N_Offset1=normalize(N+_OffsetN1);
				NdotL=saturate(dot(L,N_Offset1));
				float Specular1=step(_SpecularSpotThreshold1,NdotL);

				float Spec=max(Specular0,Specular1);

				float Fresnel=F_Schlick(real3(_Fresnel,_Fresnel,_Fresnel),saturate(dot(N,V)));

				return float4(saturate(
				lerp( rampColor,_BaseColor,Spec)
				+Fresnel*_FresnelColor
				),1.0);
				//return float4( Specular+rampColor,1.0);
			}

			ENDHLSL
        }




    }
}
