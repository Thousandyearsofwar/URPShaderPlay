Shader "URPPostProcess/ModelScan"
{
    Properties
    {
        [HideInInspector]_MainTex ("MainTex", 2D) = "white" {}
		[HDR]_XColor("X Color",Color)=(1,1,1,1)
		[HDR]_YColor("Y Color",Color)=(1,1,1,1)
		[HDR]_ZColor("Z Color",Color)=(1,1,1,1)
		[HDR]_OutLineColor("OutLine Color",Color)=(1,1,1,1)

		_Width("Width",float)=0.02
		_Spacing("Spacing",float)=1
		_Speed("Speed",float)=1

		_Intensity("Intensity",Range(0,1))=1
		_EdgeSample("Edge Sample",Range(0,1))=1
		_DepthSensitivity("Depth Sensitivity",float)=1
		_NormalSensitivity("Normal Sensitivity",float)=1
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

		float4 _MainTex_ST;
		float4 _MainTex_TexelSize;
		real4 _XColor;
		real4 _YColor;
		real4 _ZColor;
		real4 _OutLineColor;

		float _Width;
		float _Spacing;
		float _Speed;

		float _EdgeSample;
		float _DepthSensitivity;
		float _NormalSensitivity;


		float _Intensity;
		CBUFFER_END

		float4x4 viewFrustumVector4;

		TEXTURE2D(_CameraDepthTexture);
		SAMPLER(sampler_CameraDepthTexture);

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
			float2 texcoord:TEXCOORD;
		};
		struct Varyings{
			float4 positionCS:SV_POSITION;
			float2 texcoord:TEXCOORD;
			float3 direction:VAR_DIR;
		};

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
		


		int sobel(Varyings input){
			real depth[4];
			real2 normal[4];
			float2 uv[4];
			uv[0]=input.texcoord+float2(-1,-1)*_EdgeSample*_MainTex_TexelSize.xy;
			uv[1]=input.texcoord+float2(1,-1)*_EdgeSample*_MainTex_TexelSize.xy;
			uv[2]=input.texcoord+float2(-1,1)*_EdgeSample*_MainTex_TexelSize.xy;
			uv[3]=input.texcoord+float2(1,1)*_EdgeSample*_MainTex_TexelSize.xy;
		
			for(int t=0;t<4;t++){
				real4 depthNoramlTex=SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture,sampler_CameraDepthNormalsTexture,uv[t]);
				normal[t]=depthNoramlTex.xy;
				depth[t]=depthNoramlTex.z*1.0+depthNoramlTex.w/255.0;

			
			}
			int Dep= (abs(depth[0]-depth[3])+abs(depth[1]-depth[2]))*_DepthSensitivity>0.01?1:0;
			float2 nor=(abs(normal[0]-normal[3])+abs(normal[1]-normal[2]))*_NormalSensitivity;
			int Nor=(nor.x+nor.y)>0.01?1:0;
			return saturate(Dep+Nor);

		}

		float4 fragmentShader(Varyings input):SV_TARGET{
			real4 tex=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord);
			int outline=sobel(input);

			half depth=LinearEyeDepth(SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_CameraDepthTexture,input.texcoord).x,_ZBufferParams).x;

			float3 WPos=_WorldSpaceCameraPos+depth*input.direction+float3(0.1,0.1,0.1);

			float3 Line=step(1-_Width,frac(WPos/_Spacing));

			float4 LineColor=Line.x*_XColor+Line.y*_YColor+Line.z*_ZColor+outline*_OutLineColor;

			

			float mask=saturate(pow(abs(frac(WPos.z*_ProjectionParams.w+_Time.y*0.1*_Speed)-0.75),10)*30);
			mask+=step(0.999,mask);
			//return mask;
			//return lerp(tex,LineColor,saturate( _Intensity*mask));
			return tex+(LineColor)*mask+saturate(_OutLineColor*mask*_Intensity);

		}


		ENDHLSL
		}


    }
}
