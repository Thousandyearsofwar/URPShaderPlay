Shader "URP/myLitShaderMuiltLight"
{
    Properties
    {
        _BaseMap ("MainTex", 2D) = "white" {}
		_BaseColor("BaseColor",Color)=(1,1,1,1)
		_SpecularRange("SpecularRange",Range(10,300))=10
		[HDR]_SpecColor("SpecularColor",Color)=(1,1,1,1)
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
				float4 _BaseMap_ST;
				half4 _BaseColor;
				half4 _SpecColor;
				half4 _EmissionColor;
				half _Cutoff;
				half _Smoothness;
				half _Metallic;
				half _BumpScale;
				half _OcclusionStrength;
				half _SpecularRange;
			CBUFFER_END

			TEXTURE2D(_BaseMap);	SAMPLER(sampler_BaseMap);
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
				float3 tangentLightDir:VAR_TANGENTLIGHT;
				float3 tangentViewPos:VAR_TANGENTVIEW;
				float3 tangentFragPos:VAR_TANGENTFRAG;
				float3x3 TBN:VAR_TBN;
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
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE

			#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
			
			
			#pragma multi_compile _ _SHADOWS_SOFT



			Varyings LitPassVertex(Attributes input){
				Light mainLight=GetMainLight();
				float3 L=normalize(mainLight.direction);

				Varyings output;
				output.positionCS=TransformObjectToHClip(input.positionOS.xyz);
				output.positionWS=TransformObjectToWorld(input.positionOS.xyz);
				output.texcoord=TRANSFORM_TEX(input.texcoord,_BaseMap);

				float3x3 normalMatrix=transpose((float3x3)UNITY_MATRIX_M);
				float3 T=normalize(mul(input.tangentOS.xyz,normalMatrix));
				float3 N=normalize(mul(input.normalOS.xyz,normalMatrix));
				T=normalize(T-dot(T,N)*N);
				float3 B=cross(N,T);
				
				float3x3 TBN;
				TBN[0]=T;
				TBN[1]=B;
				TBN[2]=N;
				TBN=transpose(TBN);

				output.TBN=TBN;
				output.tangentLightDir=mul(L,TBN);
				output.tangentViewPos=mul(GetCameraPositionWS(),TBN);
				output.tangentFragPos=mul(output.positionWS,TBN);

				return output;
			}

			float4 LitPassFragment(Varyings input):SV_TARGET{
				
				

				float3 color =(SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,input.texcoord)*_BaseColor).rgb;

				float4 N_tex=SAMPLE_TEXTURE2D(_NormalTex,sampler_NormalTex,input.texcoord);
				float3 N=UnpackNormalScale(N_tex,1.0);

				N=normalize(N);

				Light mainLight=GetMainLight(TransformWorldToShadowCoord(input.positionWS));
				float3 LightColor=mainLight.color;

				float3 L=normalize(input.tangentLightDir);
				
				
				float3 V=normalize(input.tangentViewPos-input.tangentFragPos);
				float3 H=normalize(V+L);
				float NdotL=max(dot(L,N),0.0);
				float NdotH=max(dot(N,H),0.0);

				float  diff=NdotL;
				float3 diffuse=diff*color;


				float3 spec=pow(NdotH,_SpecularRange);
				float3 specular=LightColor*spec*_SpecColor.rgb;

				float3 mainLightColor=(diffuse+specular)*color*mainLight.shadowAttenuation;

				int addLightsCount=GetAdditionalLightsCount();
				float3 addLightColor=float3(0,0,0);
				for(int i=0;i<addLightsCount;i++){
					Light addLight=GetAdditionalLight(i,input.positionWS);
					float3 add_L=normalize(addLight.direction);
					add_L=mul(add_L,input.TBN);
					float3 add_H=normalize(V+add_L);
					float add_NdotL=saturate(dot(add_L,N));
					float add_NdotH=saturate(dot(add_H,N));

					float  add_diff=add_NdotL;
					float3 add_Diffuse=add_diff*color;


					float3 add_spec=pow(add_NdotH,_SpecularRange);
					float3 add_Specular=add_spec*_SpecColor.rgb;


					addLightColor+=(add_Diffuse+add_Specular)*addLight.color*addLight.distanceAttenuation*addLight.shadowAttenuation;
				}


				

				return float4(mainLightColor+addLightColor,1.0);
			}

			ENDHLSL
        }





		UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}
