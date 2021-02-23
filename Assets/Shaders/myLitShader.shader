Shader "URP/myLitShader"
{
    Properties
    {
        _MainTex ("MainTex", 2D) = "white" {}
		_BaseColor("BaseColor",Color)=(1,1,1,1)
		_SpecularRange("SpecularRange",Range(10,300))=10
		[HDR]_SpecularColor("SpecularColor",Color)=(1,1,1,1)
		[Normal]_NormalTex("Normal",2D)="bump"{}
		_NormalScale("NormalScale",Range(0,1))=1

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
				float4 _NormalTex_ST;

				float4 _BaseColor;
				float _NormalScale;

				float _SpecularRange;
				float4 _SpecularColor;
			CBUFFER_END

			TEXTURE2D(_MainTex);	SAMPLER(sampler_MainTex);
			TEXTURE2D(_NormalTex);	SAMPLER(sampler_NormalTex);


			struct Attributes{
				float4 positionOS:POSITION;
				float4 normalOS:NORMAL;
				float4 tangentOS:TANGENT;
				float2 texcoord:TEXCOORD;
			};

			struct Varyings{
				float4 positionCS:SV_POSITION;
				float3 positionWS:VAR_POSITION;
				float2 texcoord:TEXCOORD;
				float3 tangentWS:VAR_TANGENTWS;
				float3 normalWS:VAR_NORMALWS;
				float3 bitangentWS:VAR_BITANGENTWS;
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
				output.positionWS=TransformObjectToWorld(input.positionOS.xyz);
				output.texcoord=TRANSFORM_TEX(input.texcoord,_MainTex);

				output.normalWS=normalize(TransformObjectToWorldNormal(input.normalOS.xyz));
				output.tangentWS=normalize(TransformObjectToWorldDir(input.tangentOS.xyz));
				output.bitangentWS=cross(output.normalWS,output.tangentWS)*input.tangentOS.w*unity_WorldTransformParams.w;



				return output;
			}

			float4 LitPassFragment(Varyings input):SV_TARGET{
				
				float3x3 TBN={input.tangentWS.xyz,input.bitangentWS.xyz,input.normalWS.xyz};

				float3 color =(SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord)*_BaseColor).rgb;

				float4 N_tex=SAMPLE_TEXTURE2D(_NormalTex,sampler_NormalTex,input.texcoord);
				float3 N=UnpackNormalScale(N_tex,_NormalScale);
				
				N=mul(N,TBN);
				N=normalize(N);

				Light mainLight=GetMainLight();
				float3 LightColor=mainLight.color;

				float3 L=normalize(mainLight.direction);
				
				float3 V=normalize(GetCameraPositionWS()-input.positionWS);
				float3 H=normalize(V+L);
				float NdotL=max(dot(L,N),0.0);
				float NdotH=max(dot(N,H),0.0);

				float  diff=NdotL;
				float3 diffuse=diff*color;


				float3 spec=pow(NdotH,_SpecularRange);
				float3 specular=LightColor*spec*_SpecularColor.rgb;

				float3 finalColor=(diffuse+specular)*color;

				return float4(finalColor,1.0);
			}

			ENDHLSL
        }
    }
}
