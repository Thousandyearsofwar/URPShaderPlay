Shader "URP/rampMapping"
{
    Properties
    {
        _MainTex ("RAMP", 2D) = "white" {}
		_BaseColor("BaseColor",Color)=(1,1,1,1)


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
				float4 _MainTex_ST;
				float4 _BaseColor;
			CBUFFER_END

			TEXTURE2D(_MainTex);	SAMPLER(sampler_MainTex);

			struct Attributes{
				float4 positionOS:POSITION;
				float3 normalOS:NORMAL;
			};

			struct Varyings{
				float4 positionCS:SV_POSITION;
				float3 normalWS:NORMAL;

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

			Varyings LitPassVertex(Attributes input){
				Varyings output;
				output.positionCS=TransformObjectToHClip(input.positionOS.xyz);
				output.normalWS=normalize(TransformObjectToWorldNormal(input.normalOS));
				

				return output;
			}

			float4 LitPassFragment(Varyings input):SV_TARGET{
				Light mainLight=GetMainLight();
				float3 LightColor=mainLight.color;

				

				float3 N=input.normalWS;
				float3 L=normalize(mainLight.direction);
			
				float NdotL=max(dot(L,N),0.0);
				
				float3 color =(SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,float2(NdotL,0.5)*_MainTex_ST)*_BaseColor).rgb;


				float  diff=NdotL;
				float3 diffuse=diff*color;

				float3 finalColor=(diffuse)*color;

				return float4(finalColor,1.0);
			}

			ENDHLSL
        }
    }
}
