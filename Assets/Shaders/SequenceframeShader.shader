Shader "URP/SequenceframeShader"
{
	Properties
    {
        _BaseMap ("MainTex", 2D) = "white" {}
		_BaseColor("BaseColor",Color)=(1,1,1,1)
		_SpecularRange("SpecularRange",Range(10,300))=10
		[HDR]_SpecColor("SpecularColor",Color)=(1,1,1,1)
		[Normal]_NormalTex("Normal",2D)="bump"{}
		_NormalScale("NormalScale",Range(0,1))=1
		_Cutoff("Cutoff",Range(0,1))=0
		[Enum(Off,0,On,1)] _ZWrite("Z Write", Float) = 1.0
		[Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Src Blend", Float) = 1.0
        [Enum(UnityEngine.Rendering.BlendMode)]  _DstBlend("Dst Blend", Float) = 0.0
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
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
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


			TEXTURE2D(_NormalTex);	SAMPLER(sampler_NormalTex);


			
		ENDHLSL
        Pass
        {


		Tags{
				"LightMode"="UniversalForward"
			}

			Blend[_SrcBlend][_DstBlend]
            ZWrite[_ZWrite]
            Cull [Off]
            HLSLPROGRAM
			

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
				
				uint curFrame=fmod(floor(_Time.y*30),68);
				uint _Row,_Column;
				_Row=curFrame/8+1;
				_Column=fmod(curFrame,8.0);


				float2 texcoord;
				
				texcoord.x=input.texcoord.x/8.0+_Column/8.0f;
				texcoord.y=input.texcoord.y/9.0+1.0-_Row/9.0f;
				

				float3 color =((SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,texcoord))*_BaseColor).rgb;
				float alpha=SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,texcoord).a;

				float4 N_tex=SAMPLE_TEXTURE2D(_NormalTex,sampler_NormalTex,input.texcoord);
				float3 N=UnpackNormalScale(N_tex,1.0);

				N=normalize(N);

				Light mainLight=GetMainLight(TransformWorldToShadowCoord(input.positionWS));
				float3 LightColor=mainLight.color;

				float3 L=normalize(input.tangentLightDir);
				
				float3 V=normalize(input.tangentViewPos-input.tangentFragPos);
				float3 H=normalize(V+L);
				float NdotL=saturate(dot(L,N));
				float NdotH=saturate(dot(N,H));

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

				clip(alpha-_Cutoff);
				

				return float4(mainLightColor+addLightColor,alpha);
			}

			ENDHLSL
        }

		Pass{
		Name "ShadowCaster"
		Tags{
			"LightMode"="ShadowCaster"
		}
		ZWrite On
        ZTest LEqual
		Cull[_Cull]

		HLSLPROGRAM
		#pragma vertex ShadowPassVertex
		#pragma fragment ShadowPassFragment

		float3 _LightDirection;

		struct Attributes{
			float4 positionOS:POSITION;
			float3 normalOS:NORMAL;
			float2 texcoord:TEXCOORD0;
			
		};

		struct Varyings{
			float2 uv:TEXCOORD0;
			float4 positionCS:SV_POSITION;		
		};
			
		float4 GetShadowPositionHClip(Attributes input){
			float3 positionWS=TransformObjectToWorld(input.positionOS.xyz);
			float3 normalWS=TransformObjectToWorldNormal(input.normalOS);
			float4 positionCS=TransformWorldToHClip(ApplyShadowBias(positionWS,normalWS,_LightDirection));
			#if UNITY_REVERSED_Z
				positionCS.z=min(positionCS.z,positionCS.w*UNITY_NEAR_CLIP_VALUE);
			#else
				positionCS.z=max(positionCS.z,positionCS.w*UNITY_NEAR_CLIP_VALUE);
			#endif

			return positionCS;
		}

		Varyings ShadowPassVertex(Attributes input){
			Varyings output;
			

			output.uv=TRANSFORM_TEX(input.texcoord,_BaseMap);
			output.positionCS=GetShadowPositionHClip(input);
			return output;
		}

		half4 ShadowPassFragment(Varyings input): SV_TARGET{
			uint curFrame=fmod(floor(_Time.y*30),68);
			uint _Row,_Column;
			_Row=ceil(curFrame/8)+1;
			_Column=fmod(curFrame,8.0);


			float2 texcoord;
				
			texcoord.x=input.uv.x/8.0+_Column/8.0;
			texcoord.y=input.uv.y/9.0+1.0-_Row/9.0;

			clip(SampleAlbedoAlpha(texcoord,TEXTURE2D_ARGS(_BaseMap,sampler_BaseMap)).a*_BaseColor.a-_Cutoff);
			return 0;
		}

			
		ENDHLSL
		}
	}
}
