Shader "URPPostProcess/BokehBlur"
{
    Properties
    {
        [HideInInspector]_MainTex ("MainTex", 2D) = "white" {}
		[KeywordEnum(TILTSHIFT,IRIS)]_BLUR_MODE("BlurMode",Float)=1

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
		float _BlurRadius;
		float _Loop;
		
		float _BlurSmoothness;
		float4 _MainTex_TexelSize;
		float4 _GoldenRot;

		float2 _Offset;
		float _AreaSize;

		float _Spread;
		

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
			float2x2 Rot=float2x2(_GoldenRot);
			
			float4 accumulator=0.0;
			float4 divisor=0.0;

			float r=1.0;
			float2 angle=float2(0.0,_BlurRadius);

			for(int j=0;j<_Loop;j++){
				r+=1.0/r;
				angle=mul(Rot,angle);
				float4 bokeh=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,float2(input.texcoord.xy+_MainTex_TexelSize.xy*(r-1.0)*angle));
				accumulator+=bokeh*bokeh;
				divisor+=bokeh;

			}
			return accumulator/divisor;
		}


		ENDHLSL
		}

		pass{
		HLSLPROGRAM
		#pragma vertex vertexShader
		#pragma fragment fragmentShader
		
		#pragma shader_feature_local _BLUR_MODE_TILTSHIFT

		struct Attributes{
			float4 positionOS:POSITION;
			float2 texcoord:TEXCOORD;
		};
		struct Varyings{
			float4 positionCS:SV_POSITION;
			float2 texcoord:TEXCOORD;
		};

		float TiltShiftMask(float2 uv){
			float centerY=uv.y*2.0-1.0+_Offset;
			return pow(abs(centerY*_AreaSize),_Spread);
		}

		float IrisMask(float2 uv){
			float2 center=uv*2.0-1.0+_Offset;
			return dot(center,center)*_AreaSize;
		
		}

		Varyings vertexShader(Attributes input){
			Varyings output;
			output.positionCS=TransformObjectToHClip(input.positionOS.xyz);
			output.texcoord=input.texcoord;
			
			return output;
		}

		float4 fragmentShader(Varyings input):SV_TARGET{
			float4 blur=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord);
			float4 Source=SAMPLE_TEXTURE2D(_SourceTex,sampler_SourceTex,input.texcoord);

			#ifdef _BLUR_MODE_TILTSHIFT
				float mask=TiltShiftMask(input.texcoord);
			#else
				float mask=IrisMask(input.texcoord);
			#endif
			//float4 maskColor=float4(mask,mask,mask,1.0);
			return lerp(Source,blur,mask);
			//return blur;
		}

		
		ENDHLSL
		}

    }
}
