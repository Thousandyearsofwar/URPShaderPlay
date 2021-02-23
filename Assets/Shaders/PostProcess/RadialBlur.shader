Shader "URPPostProcess/RadialBlur"
{
    Properties
    {
        [HideInInspector]_MainTex ("MainTex", 2D) = "white" {}
		//[HideInInspector]_Blur("Blur",float)=2
    }
    SubShader
    {
        Tags {
			"RenderPipeline"="UniversalRenderPipeline"
		}
		Cull Off
		ZWrite Off
		ZTest Always
		HLSLINCLUDE

		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
		CBUFFER_START(UnityPerMaterial)
		float _Blur;
		float _Loop;
		float _X;
		float _Y;
		float _Intensity;
		float4 _MainTex_TexelSize;
		CBUFFER_END

		TEXTURE2D(_MainTex);
		SAMPLER(sampler_MainTex);
		TEXTURE2D(_SourceTex);
		SAMPLER(sampler_SourceTex);

	   ENDHLSL
	   Pass{
	   HLSLPROGRAM
		#pragma vertex vertexShader
		#pragma fragment fragmentShader

		struct Attributes{
			float4 positionOS:POSITION;
			float2 texcoord:TEXCOORD;
		};
		struct Varyings{
			float4 positionCS:SV_POSITION;
			float2 texcoord:TEXCOORD;
		};

		Varyings vertexShader(Attributes input){
			Varyings output;
			output.positionCS=TransformObjectToHClip(input.positionOS.xyz);
			output.texcoord=input.texcoord;
			
			return output;
		}

		float4 fragmentShader(Varyings input):SV_TARGET{
			float4 col=float4(0,0,0,0);
			float2 blurVec=(float2(_X,_Y)-input.texcoord)*_Blur;
			[unroll(30)]
			for(int t=0;t<_Loop;t++){
				col+=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord);
				input.texcoord+=blurVec;
			}


			return col/_Loop;
		}


		ENDHLSL
		}

		pass{
		HLSLPROGRAM
		#pragma vertex vertexShader
		#pragma fragment fragmentShader
		
		struct Attributes{
			float4 positionOS:POSITION;
			float2 texcoord:TEXCOORD;
		};
		struct Varyings{
			float4 positionCS:SV_POSITION;
			float2 texcoord:TEXCOORD;
		};

		Varyings vertexShader(Attributes input){
			Varyings output;
			output.positionCS=TransformObjectToHClip(input.positionOS.xyz);
			output.texcoord=input.texcoord;
			
			return output;
		}

		float4 fragmentShader(Varyings input):SV_TARGET{
			float4 blur=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord);
			float4 Source=SAMPLE_TEXTURE2D(_SourceTex,sampler_SourceTex,input.texcoord);

			return lerp(Source,blur,_Intensity);
		}

		
		ENDHLSL
		}

    }
   
}
