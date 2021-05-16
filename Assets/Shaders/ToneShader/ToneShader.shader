Shader "URP/ToneShader"
{
    Properties
    {
        _RAMPTex ("RAMP", 2D) = "white" {}
        _BaseMap ("MainTex", 2D) = "white" {}
		_BaseColor("BaseColor",Color)=(1,1,1,1)

		_LineColor("LineColor",Color)=(1,1,1,1)
		_LineWidth("LineWidth",Range(0,0.0015))=0

		_OffsetU("Offset",Range(0,1))=0

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
			CBUFFER_START(UnityPerMaterial)
				float4 _BaseMap_ST;
				float4 _BaseColor;
				float4 _LineColor;
				float _LineWidth;
				float _OffsetU;
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
				float2 texcoord:TEXCOORD;

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
				output.positionCS=TransformObjectToHClip(float4(input.positionOS.xyz+input.normalOS*_LineWidth,1));
				output.normalWS=normalize(TransformObjectToWorldNormal(input.normalOS));
				output.texcoord=TRANSFORM_TEX(input.texcoord,_BaseMap);

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
				output.positionCS=TransformObjectToHClip(input.positionOS.xyz);
				output.normalWS=normalize(TransformObjectToWorldNormal(input.normalOS));
				output.texcoord=TRANSFORM_TEX(input.texcoord,_BaseMap);

				return output;
			}

			float4 LitPassFragment(Varyings input):SV_TARGET{
				Light mainLight=GetMainLight();
				float3 LightColor=mainLight.color;

				

				float3 N=input.normalWS;
				float3 L=normalize(mainLight.direction);


				float NdotL=(dot(L,N));
				
				NdotL=NdotL*0.5f+0.5f;
				float3 rampcColor =SAMPLE_TEXTURE2D(_RAMPTex,sampler_RAMPTex,float2(NdotL+_OffsetU,1.0)).rgb;

				float3 albedoColor=SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,input.texcoord).rgb;
				
				return float4(saturate(rampcColor*albedoColor),1.0);
			}

			ENDHLSL
        }




    }
}
