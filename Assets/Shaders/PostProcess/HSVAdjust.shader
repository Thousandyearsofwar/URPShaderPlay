Shader "URPPostProcess/HSVAdjust"
{
    Properties
    {
        [HideInInspector]_MainTex("MainTex",2D)="white"{}
		_brightness("Brightness",Range(0,1))=1
		_saturate("Saturate",Range(0,1))=1
		_contranst("Constant",Range(-1,2))=1

    }
    SubShader
    {
       Tags{
		"RenderPipeline"="UniversalRenderPipeline"
	   }
	   Cull Off
	   ZWrite Off
	   ZTest Always

	   HLSLINCLUDE

	   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

	   CBUFFER_START(UnityPerMaterial)
		float _brightness;
		float _saturate;
		float _contranst;
	   CBUFFER_END

	   TEXTURE2D(_MainTex);
	   SAMPLER(sampler_MainTex);

	   struct Attributes{
		float4 positionOS:POSITION;
		float2 texcoord:TEXCOORD;
	   };
	   struct Varyings{
		float4 positionCS:SV_POSITION;
		float2 texcoord:TEXCOORD;
	   };
	   ENDHLSL

	   pass{
		HLSLPROGRAM
			#pragma vertex vertexShader
			#pragma fragment fragmentShader

			Varyings vertexShader(Attributes input){
				Varyings output;
				output.positionCS=TransformObjectToHClip(input.positionOS.xyz);
				output.texcoord=input.texcoord;
				return output;
			}

			float4 fragmentShader(Varyings input):SV_TARGET{
				float4 tex=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord);
				
				float gray=0.2125*tex.x+0.7154*tex.y+0.0721*tex.z;

				tex.xyz*=_brightness;
				tex.xyz=lerp(float3(gray,gray,gray),tex.xyz,_saturate);
				tex.xyz=lerp(float3(0.5,0.5,0.5),tex.xyz,_contranst);

				return tex;
			}

		ENDHLSL
	   }

    }

}
