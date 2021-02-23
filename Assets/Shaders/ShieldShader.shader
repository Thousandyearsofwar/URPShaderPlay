Shader "URP/PerlinShieldShader"
{
   Properties
    {
        _MainTex ("MainTex", 2D) = "white" {}
		[HDR]_BaseColor("BaseColor",Color)=(1,1,1,1)
		_SpecularRange("SpecularRange",Range(10,300))=10
		[HDR]_SpecularColor("SpecularColor",Color)=(1,1,1,1)
		
		[Normal]_NormalTex("Normal",2D)="bump"{}
		_NormalScale("NormalScale",Range(0,1))=1

		[Toggle(_CLIPPING)]_Clipping("Alpha Clipping",Float)=0


		_depthoffset("depthoffset",float)=1

		[HDR]_EmissionColor("EmissionColor",Color)=(1,1,1,1)

		[Enum(Off,0,On,1)]_ZWrite("Z Write",Float)=1
		[Enum(UnityEngine.Rendering.BlendMode)]_SrcBlend("Src Blend",Float)=1
		[Enum(UnityEngine.Rendering.BlendMode)]_DstBlend("Dst Blend",Float)=0
		[HideInInspector] _Cull("__cull", Float) = 2.0
    }
    SubShader
    {
        Tags { 
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

				float4 _EmissionColor;

				float _depthoffset;
			CBUFFER_END

			TEXTURE2D(_MainTex);	SAMPLER(sampler_MainTex);
			TEXTURE2D(_NormalTex);	SAMPLER(sampler_NormalTex);
			SAMPLER(_CameraDepthTexture);

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
				float4 ssPos:VAR_SCRPOS;
				float3 tangentLightDir:VAR_TANGENTLIGHT;
				float3 tangentViewPos:VAR_TANGENTVIEW;
				float3 tangentFragPos:VAR_TANGENTFRAG;
			};
		ENDHLSL
        Pass
        {
		Tags{
				"LightMode"="UniversalForward"
			}
			Blend[_SrcBlend][_DstBlend]
            ZWrite[_ZWrite]
            Cull Off

            HLSLPROGRAM
			#pragma shader_feature _CLIPPING


			#pragma vertex LitPassVertex
			#pragma fragment LitPassFragment


			float3 FresnelSchlick(float cosTheta,float3 F0){
				return F0+(1.0-F0)*pow(1.0-cosTheta,5.0);
			}


			Varyings LitPassVertex(Attributes input){
				Light mainLight=GetMainLight();
				float3 L=normalize(mainLight.direction);

				Varyings output;
				output.positionCS=TransformObjectToHClip(input.positionOS.xyz);
				output.positionWS=TransformObjectToWorld(input.positionOS.xyz);
				output.texcoord=TRANSFORM_TEX(input.texcoord,_MainTex);

				output.ssPos.xy=output.positionCS.xy*0.5+float2(output.positionCS.w,output.positionCS.w)*0.5;
				output.ssPos.zw=output.positionCS.zw;

				float3x3 normalMatrix=transpose(UNITY_MATRIX_M);
				float3 T=normalize(mul(input.tangentOS,normalMatrix));
				float3 N=normalize(mul(input.normalOS,normalMatrix));
				T=normalize(T-dot(T,N)*N);
				float3 B=cross(N,T);
				
				float3x3 TBN;
				TBN[0]=T;
				TBN[1]=B;
				TBN[2]=N;
				TBN=transpose(TBN);

				output.tangentLightDir=mul(L,TBN);
				output.tangentViewPos=mul(GetCameraPositionWS(),TBN);
				output.tangentFragPos=mul(output.positionWS,TBN);

				return output;
			}

			float4 LitPassFragment(Varyings input):SV_TARGET{
				float3 color_Tex =(SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord)*_BaseColor).rgb;

				float4 N_tex=SAMPLE_TEXTURE2D(_NormalTex,sampler_NormalTex,input.texcoord);
				float3 N=UnpackNormalScale(N_tex,_NormalScale);

				N=normalize(N);	
				
				float3 V=normalize(input.tangentViewPos-input.tangentFragPos);
				float NdotV=abs(dot(N,V));
				float color=FresnelSchlick(NdotV,0.15).r;

				input.ssPos.xy/=input.ssPos.w;
				#ifdef UNITY_UV_STARTS_AT_TOP
				input.ssPos.y=1-input.ssPos.y;
				#endif

				float4 depthColor=tex2D(_CameraDepthTexture,input.ssPos.xy);
				float depthBuffer=Linear01Depth(depthColor,_ZBufferParams);

				float depth=input.positionCS.z;
				depth=Linear01Depth(depth,_ZBufferParams);

				float edgeLight=saturate(depth-depthBuffer+0.005)*100*_depthoffset;

				float flow=saturate(pow(1-abs(frac(input.positionWS.y*0.25-_Time.y*0.3)-0.5),10)*0.3);
				float4 flowColor=flow*_EmissionColor;


				return float4(color_Tex,color*edgeLight)+flowColor;
			}


			ENDHLSL
        }
		
		
    }
}
