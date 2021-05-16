Shader "URPPostProcess/FogProcess"
{
    Properties
    {
		[HideInInspector] _MainTex("MainTex",2D)="White"{}
		
		_fogDensity("fogDensity",float)=1.0
		[HDR]_fogColor("fogColor",Color)=(1,1,1,1)
		_fogStart("fogStart",float)=0.0
		_fogEnd("fogEnd",float)=2.0

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
			float4 _fogColor;
			float _fogDensity;
			float _fogStart;
			float _fogEnd;
		CBUFFER_END
		float4x4 viewFrustumVector4;

		TEXTURE2D(_CameraDepthNormalsTexture);
		SAMPLER(sampler_CameraDepthNormalsTexture);

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
			float4 texcoord:TEXCOORD;
		};

		struct Varyings{
			float4 positionCS:SV_POSITION;
			float2 texcoord:TEXCOORD;
			float3 direction:TEXCOORD1;
		};

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


		Varyings vertexShader(Attributes input){
			Varyings output;
			output.positionCS=TransformObjectToHClip(input.positionOS.xyz);
			output.texcoord=input.texcoord;
			int index=0;

			if(input.texcoord.x<0.5&&input.texcoord.y<0.5)
				index=0;
			else if(input.texcoord.x>0.5&&input.texcoord.y<0.5)
				index=1;
			else if(input.texcoord.x>0.5&&input.texcoord.y>0.5)
				index=2;
			else if(input.texcoord.x<0.5&&input.texcoord.y>0.5)
				index=3;
			output.direction=viewFrustumVector4[index].xyz;

			return output;
		}

		float4 fragmentShader(Varyings input):SV_TARGET{
			
			
			half depth=LinearEyeDepth(SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture,sampler_CameraDepthNormalsTexture,input.texcoord).x,_ZBufferParams).x;
		
			float3 WPos=_WorldSpaceCameraPos+depth*input.direction+float3(0.1,0.1,0.1);

			float2 speed=_Time.y*float2(0.05,0.005);
			float PerlinNoise=perlin_noise_sum(input.texcoord+speed);

			float fogDensity=(_fogEnd-WPos.y)/(_fogEnd-_fogStart);
			fogDensity=saturate(fogDensity*_fogDensity*(1+PerlinNoise));
			
			float4 finalColor=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord);
			finalColor.rgb=lerp(finalColor.rgb,_fogColor.rgb,fogDensity);

			return  finalColor;
		}


		ENDHLSL
		}

		

		
        
    }
}
