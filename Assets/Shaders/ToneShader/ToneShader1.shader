Shader "URP/ToneShader1"
{
    Properties
    {
        _RAMPTex ("RAMP", 2D) = "white" {}
        _PatterrnMap ("Patterrn", 2D) = "white" {}

        _BaseMap ("MainTex", 2D) = "white" {}
		_BaseColor("BaseColor",Color)=(1,1,1,1)

		_LightColor("LightColor",Color)=(1,1,1,1)
		_DarkColor("DarkColor",Color)=(1,1,1,1)


		_LineColor("LineColor",Color)=(1,1,1,1)
		
		_LineWidth("LineWidth",Range(0,0.0015))=0

		_Fresnel("Fresnel",Range(0,1))=0

		_OffsetU("Offset U",Range(0,1))=0
		

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

				float4 _PatterrnMap_ST;

				float4 _BaseColor;
				float4 _LineColor;

				float _LineWidth;

				float _OffsetU;
			CBUFFER_END

			TEXTURE2D(_BaseMap);	SAMPLER(sampler_BaseMap);
			TEXTURE2D(_PatterrnMap);	SAMPLER(sampler_PatterrnMap);
			TEXTURE2D(_RAMPTex);	SAMPLER(sampler_RAMPTex);
			TEXTURE2D(_CameraDepthTexture);SAMPLER(sampler_CameraDepthTexture);

			struct Attributes{
				float4 positionOS:POSITION;
				float3 normalOS:NORMAL;
				float2 texcoord:TEXCOORD0;
				
			};

			struct Varyings{
				float4 positionCS:SV_POSITION;
				
				float3 normalWS:NORMAL;
				
				float2 texcoord:TEXCOORD0;

				float2 patterrnMapTexcoord:TEXCOORD1;
				
				float3 viewDirWS:TEXCOORD2;
				float3 positionWS:TEXCOORD3;
				float3 positionVS:TEXCOORD4;
				float4 positionSS:TEXCOORD5;
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

				output.positionWS=vertexInput.positionWS;
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
				output.patterrnMapTexcoord=TRANSFORM_TEX(input.texcoord,_PatterrnMap);

				output.viewDirWS=GetCameraPositionWS()-vertexInput.positionWS;

				output.positionWS=vertexInput.positionWS;
				output.positionVS=vertexInput.positionVS;
				

				output.positionSS=ComputeScreenPos(output.positionCS);
				output.positionSS.z=-mul(UNITY_MATRIX_MV, input.positionOS).z;
				/*
				ComputeScreenPos:
				output.positionSS.xy = vertexInput.positionCS.xy*0.5+0.5*float2( vertexInput.positionCS.w, vertexInput.positionCS.w);
				output.positionSS.zw = vertexInput.positionCS.zw;
				*/

				return output;
			}

			float4 LitPassFragment(Varyings input):SV_TARGET{
				Light mainLight=GetMainLight();
				float3 LightColor=mainLight.color;


				float2 ScreenUV=input.positionSS.xy/input.positionSS.w;

				
				
				
				/*
				input.positionSS.xy/=input.positionSS.w;
				#ifdef UNITY_STARTS_AT_Top
				input.positionSS.y=1-input.positionSS.y;
				#endif

				float3 PatterrnColor=SAMPLE_TEXTURE2D(_PatterrnMap,sampler_PatterrnMap,TRANSFORM_TEX(input.positionSS.xy,_PatterrnMap)).rgb;
				*/
				float partZ=max(0,input.positionSS.z-_ProjectionParams.y);

				float3 PatterrnColor=SAMPLE_TEXTURE2D(_PatterrnMap,sampler_PatterrnMap,TRANSFORM_TEX((float2((ScreenUV.x * 2 - 1)*(_ScreenParams.x/_ScreenParams.y), ScreenUV.y * 2 - 1).xy*partZ),_PatterrnMap)).rgb;

				float3 N=input.normalWS;
				float3 L=normalize(mainLight.direction);
				float3 V=SafeNormalize(GetCameraPositionWS()-input.positionWS);
				float3 H=normalize(V+L);

				float NdotL=saturate(dot(L,N));
				
				NdotL=NdotL*0.5f+0.5f;
				float3 rampColor =SAMPLE_TEXTURE2D(_RAMPTex,sampler_RAMPTex,float2(NdotL+_OffsetU,1.0)).rgb;

				//return float4(saturate(PatterrnColor),1);

				//return float4(partZ,partZ,partZ,1);
				
				return float4(PatterrnColor,1.0);
				

			}

			ENDHLSL
        }




    }
}
