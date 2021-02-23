Shader "URP/PerlinNoiseShader"
{
   Properties
    {
        _BaseMap ("MainTex", 2D) = "white" {}
		_BaseColor("BaseColor",Color)=(1,1,1,1)
		_SpecularRange("SpecularRange",Range(10,300))=10
		[HDR]_SpecColor("SpecularColor",Color)=(1,1,1,1)
		[HDR]_BurnColor("BurnColor",Color)=(1,1,1,1)
		[Normal]_NormalTex("Normal",2D)="bump"{}
		_NormalScale("NormalScale",Range(0,1))=1


		_Cutoff("Alpha Cutoff",Range(0.0,1.0))=0.5
		[Toggle(_CLIPPING)]_Clipping("Alpha Clipping",Float)=0
		[Toggle(_Noise)]_Noise("_NoiseView",Float)=0

		[Enum(Off,0,On,1)]_ZWrite("Z Write",Float)=1
		[Enum(UnityEngine.Rendering.BlendMode)]_SrcBlend("Src Blend",Float)=1
		[Enum(UnityEngine.Rendering.BlendMode)]_DstBlend("Dst Blend",Float)=0
		[HideInInspector] _Cull("__cull", Float) = 2.0
    }
    SubShader
    {
        Tags { 
		"RenderType"="Transparent" 
		"Queue"="Transparent" 
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

				float4 _NormalTex_ST;
				float _NormalScale;
				half4 _BurnColor;
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
			#pragma shader_feature _Noise

			#pragma vertex LitPassVertex
			#pragma fragment LitPassFragment

			float2 randVec(float2 value){
				float2 vec=float2(dot(value,float2(127.1,337.1)),dot(value,float2(269.5,183.3)));
 				vec=-1.0+2.0*frac(sin(vec)*43758.5453123);
				return vec;
			}
			
			float perlin_noise(float2 p){
				float2 pi=floor(p);
				float2 pf=p-pi;
				
				float2 w=pf*pf*(3.0-2.0*pf);
				
				float a,b,c,d;
				a=dot(randVec(pi+float2(0.0,0.0)),pf-float2(0.0,0.0));
				b=dot(randVec(pi+float2(1.0,0.0)),pf-float2(1.0,0.0));
				c=dot(randVec(pi+float2(0.0,1.0)),pf-float2(0.0,1.0));
				d=dot(randVec(pi+float2(1.0,1.0)),pf-float2(1.0,1.0));
			
				a=lerp(a,b,w.x);
				b=lerp(c,d,w.x);
				a=lerp(a,b,w.y);
				return a;
			}


			float perlin_noise_sum(float2 p){
				float f=0.0;
				p=p*4.0;
				f+=1.0000*perlin_noise(p);p=2.0*p;
				f+=0.5000*perlin_noise(p);p=2.0*p;
				f+=0.2500*perlin_noise(p);p=2.0*p;
				f+=0.1250*perlin_noise(p);p=2.0*p;
				f+=0.0625*perlin_noise(p);p=2.0*p;
				f+=0.0625/2.0*perlin_noise(p);p=2.0*p;
			
				return f;
			}




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

				output.tangentLightDir=mul(L,TBN);
				output.tangentViewPos=mul(GetCameraPositionWS(),TBN);
				output.tangentFragPos=mul(output.positionWS,TBN);

				return output;
			}

			float4 LitPassFragment(Varyings input):SV_TARGET{
				
				float alpha =(perlin_noise_sum(input.texcoord));
				//float alpha =SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord).a;

				float3 color =(SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,input.texcoord)*_BaseColor).rgb;
				float4 N_tex=SAMPLE_TEXTURE2D(_NormalTex,sampler_NormalTex,input.texcoord);
				float3 N=UnpackNormalScale(N_tex,_NormalScale);

				N=normalize(N);

				Light mainLight=GetMainLight();
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

				float3 finalColor=(diffuse+specular)*color;

				#ifdef _CLIPPING
					clip(step(_Cutoff,alpha)-0.01);
				#endif
				finalColor=lerp(finalColor,_BurnColor,step(alpha,saturate(_Cutoff+0.1)));
				
				#ifdef _Noise
					return float4(alpha,alpha,alpha,1.0);
				#else
					return float4(finalColor,1.0);
				#endif
			}

			ENDHLSL
        }
		UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}
