Shader "URPPostProcess/ModelShelter"
{
    Properties
    {
		[HideInInspector]_MainTex ("MainTex", 2D) = "white" {}
		[HideInInspector]_Blur("Blur",float)=2
    }
    SubShader
    {
        Tags {
			"RenderPipeline"="UniversalRenderPipeline"
		}
		Cull Off
		ZWrite Off
		ZTest LEqual
		HLSLINCLUDE

		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
		CBUFFER_START(UnityPerMaterial)
		float _Blur;
		float4 _MainTex_TexelSize;
		float4 _ModelShelterColor;
		CBUFFER_END

		TEXTURE2D(_MainTex);
		SAMPLER(sampler_MainTex);


		ENDHLSL

		Pass{

		  HLSLPROGRAM
		#pragma vertex vertexShader
		#pragma fragment fragmentShader
		
		struct Attributes{
			float4 positionOS:POSITION;			
		};
		struct Varyings{
			float4 positionCS:SV_POSITION;
		};

		Varyings vertexShader(Attributes input){
			Varyings output;
			output.positionCS=TransformObjectToHClip(input.positionOS.xyz);
			return output;
		}

		float4 fragmentShader(Varyings input):SV_TARGET{
			return float4(0.0,0.0,1.0,1.0);
		}


		ENDHLSL
		
		
		
		}

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
			float4 texcoord[3]:TEXCOORD;
		};

		Varyings vertexShader(Attributes input){
			Varyings output;
			output.positionCS=TransformObjectToHClip(input.positionOS.xyz);
			output.texcoord[2].xy=input.texcoord;
			output.texcoord[0].xy=input.texcoord+float2(0.5,0.5)*_MainTex_TexelSize.xy*(1+_Blur);
			output.texcoord[0].zw=input.texcoord+float2(-0.5,0.5)*_MainTex_TexelSize.xy*(1+_Blur);
			output.texcoord[1].xy=input.texcoord+float2(0.5,-0.5)*_MainTex_TexelSize.xy*(1+_Blur);
			output.texcoord[1].zw=input.texcoord+float2(-0.5,-0.5)*_MainTex_TexelSize.xy*(1+_Blur);
			return output;
		}

		float4 fragmentShader(Varyings input):SV_TARGET{
			float4 tex=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord[2].xy)*0.5;
				
			tex+=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord[0].xy)*0.125;
			tex+=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord[0].zw)*0.125;
			tex+=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord[1].xy)*0.125;
			tex+=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord[1].zw)*0.125;

			return tex;
		}


		ENDHLSL
		}

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
			float4 texcoord[4]:TEXCOORD;
		};




		Varyings vertexShader(Attributes input){
			Varyings output;
			output.positionCS=TransformObjectToHClip(input.positionOS.xyz);
			output.texcoord[0].xy=input.texcoord+float2(0.5,0.5)*_MainTex_TexelSize.xy*(1+_Blur);
			output.texcoord[0].zw=input.texcoord+float2(-0.5,0.5)*_MainTex_TexelSize.xy*(1+_Blur);
			output.texcoord[1].xy=input.texcoord+float2(0.5,-0.5)*_MainTex_TexelSize.xy*(1+_Blur);
			output.texcoord[1].zw=input.texcoord+float2(-0.5,-0.5)*_MainTex_TexelSize.xy*(1+_Blur);

			output.texcoord[2].xy=input.texcoord+float2(2,0)*_MainTex_TexelSize.xy*(1+_Blur);
			output.texcoord[2].zw=input.texcoord+float2(-2,0)*_MainTex_TexelSize.xy*(1+_Blur);
			output.texcoord[3].xy=input.texcoord+float2(0,2)*_MainTex_TexelSize.xy*(1+_Blur);
			output.texcoord[3].zw=input.texcoord+float2(0,-2)*_MainTex_TexelSize.xy*(1+_Blur);

			return output;
		}

		float4 fragmentShader(Varyings input):SV_TARGET{
			float4 tex=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord[0].xy)*0.167;
			tex+=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord[0].zw)*0.167;
			tex+=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord[1].xy)*0.167;
			tex+=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord[1].zw)*0.167;

			tex+=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord[2].xy)*0.083;
			tex+=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord[2].zw)*0.083;
			tex+=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord[3].xy)*0.083;
			tex+=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord[3].zw)*0.083;

			return tex;
		}

		
		ENDHLSL
		}
  
    }
    
}
