Shader "URP/SequenceframeBillboardShader"
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
		_RowSum("Row",float)=8
		_ColumnSum("Column",float)=16
		_FrameSum("Frame",float)=128
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

				half _RowSum;
				half _ColumnSum;
				half _FrameSum;
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
				/*
				float4 pivotWS=mul(UNITY_MATRIX_M,float4(0,0,0,1));
				float4 pivotVS=mul(UNITY_MATRIX_V,pivotWS);
				
				float ScaleX=length(float3(UNITY_MATRIX_M[0].x,UNITY_MATRIX_M[1].x,UNITY_MATRIX_M[2].x));
				float ScaleY=length(float3(UNITY_MATRIX_M[0].y,UNITY_MATRIX_M[1].y,UNITY_MATRIX_M[2].y));
				float4 positionVS=pivotVS+float4(input.positionOS.xy*float2(ScaleX,ScaleY),0,1);
				
				output.positionCS=mul(UNITY_MATRIX_P,positionVS);
				output.positionWS=TransformObjectToWorld(input.positionOS.xyz);
				*/
				float3 newZ=TransformWorldToObject(_WorldSpaceCameraPos);
				newZ=normalize(newZ);
				float3 newX=abs(newZ.y<0.99)?cross(float3(0,1,0),newZ):cross(newZ,float3(0,0,1));
				newX=normalize(newX);
				float3 newY=cross(newZ,newX);
				newY=normalize(newY);
				float3x3 Matrix={newX,newY,newZ};
				float3 newpos=mul(input.positionOS.xyz,Matrix);


				output.positionCS=TransformObjectToHClip(newpos);
				output.positionWS=TransformObjectToWorld(newpos);
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
				
				uint curFrame=fmod(floor(_Time.y*30),_FrameSum);
				uint _Row,_Column;
				_Row=curFrame/_ColumnSum+1;
				_Column=fmod(curFrame,_ColumnSum);


				float2 texcoord;
				
				texcoord.x=input.texcoord.x/_ColumnSum+_Column/_ColumnSum;
				texcoord.y=input.texcoord.y/_RowSum+1.0-_Row/_RowSum;
				

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

		
	}
}
