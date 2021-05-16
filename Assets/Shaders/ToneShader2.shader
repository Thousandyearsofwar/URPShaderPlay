Shader "URP/ToneShader_SSS"
{
    Properties
    {
        _BaseMap ("Texture", 2D) = "white" {}
        _RampMap ("Texture", 2D) = "white" {}

		[Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("__src", Float) = 1.0
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("__dst", Float) = 0.0

		[HideInInspector] _ZWrite("__zw", Float) = 1.0
		[HideInInspector] _Cull("__cull", Float) = 2.0

    }
    SubShader
    {
        Tags {
		"RenderType"="Transparent" 
		"RenderPipeline"="UniversalRenderPipeline"
		}
        LOD 100
		HLSLINCLUDE
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			CBUFFER_START(UnityPerMaterial)
				float4 _BaseMap_ST;
				
			CBUFFER_END
			TEXTURE2D(_BaseMap);	SAMPLER(sampler_BaseMap);
			TEXTURE2D(_RampMap);	SAMPLER(sampler_RampMap);
			struct Attributes
            {
                float3 positionOS : POSITION;
				float3 normalOS:NORMAL;
                float2 texcoord : TEXCOORD0;
            };

            struct Varyings
            {
				float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD1;

                float3 normalWS : NORMAL;
                float3 normalOS : TEXCOORD2;
                
				float2 texcoord : TEXCOORD0;
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
            #pragma vertex vert
            #pragma fragment frag



            Varyings vert (Attributes input)
            {
                Varyings output;
				VertexPositionInputs vertexInput=GetVertexPositionInputs(input.positionOS);

                output.positionCS = vertexInput.positionCS;
                output.positionWS = vertexInput.positionWS;

                output.texcoord = TRANSFORM_TEX(input.texcoord, _BaseMap);
				output.normalWS=normalize(TransformObjectToWorldNormal(input.normalOS));
				output.normalOS=input.normalOS;
                return output;
            }

            float4 frag (Varyings input) : SV_Target
            {
                float3 col = SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,input.texcoord).rgb;
				

				Light mainLight=GetMainLight();
				float3 LightColor=mainLight.color;

				float3 L=normalize(mainLight.direction);
				float3 N=input.normalWS;
				float3 V=SafeNormalize(GetCameraPositionWS()-input.positionWS);

				float3 H=normalize(V+L);

				float NdotL=saturate(dot(N,L));
				NdotL=NdotL*0.5f+0.5f;

				float3 RampColor=SAMPLE_TEXTURE2D(_RampMap,sampler_RampMap,NdotL).rgb;
				RampColor*=2.0;
				RampColor=saturate(RampColor);
				col*=NdotL*LightColor*RampColor;

                return float4(col,1.0);
            }
            ENDHLSL
        }
    }
}
