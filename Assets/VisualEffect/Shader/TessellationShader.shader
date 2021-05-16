Shader "URP/TessellationShader"
{
    Properties
    {
        _BaseMap ("BaseTex", 2D) = "white" {}
		_BaseColor("BaseColor",Color)=(1,1,1,1)
        _SnowColor("SnowColor",Color)=(1,1,1,1)
		_SnowTex("SonwTex",2D)="white"{}
		_Displacement("Displacement",Range(0,30))=1
		_MaskTex("MaskTex",2D)="black"{}
		_TesslationLevel("TesslationLevel",Range(0.1,100))=0.145

		[HideInInspector] _ZWrite("__zw",Float)=1.0
		[HideInInspector] _SrcBlend("__src",Float)=1.0
		[HideInInspector] _DstBlend("__dst",Float)=0.0
		[HideInInspector] _Cull("__cull",Float)=2.0


    }
    SubShader
    {
        Tags { 
		"RenderPipeline"="UniversalRenderPipeline"
		}
        LOD 200
		HLSLINCLUDE
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
		#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/GeometricTools.hlsl"
		#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Tessellation.hlsl"


		CBUFFER_START(UnityPerMaterial)
			float4 _BaseMap_ST;
			float4 _MaskTex_ST;
			float4 _SnowTex_ST;
			float4 _SnowColor;
			float4 _BaseColor;
			
			float _Displacement;
			float _TesslationLevel;

		CBUFFER_END

		TEXTURE2D(_BaseMap);	SAMPLER(sampler_BaseMap);
		TEXTURE2D(_SnowTex);	SAMPLER(sampler_SnowTex);
		TEXTURE2D(_MaskTex);	SAMPLER(sampler_MaskTex);




		ENDHLSL

		Pass{
		Tags{
		"LightMode"="UniversalForward"
		}
		
		Blend[_SrcBlend][_DstBlend]
		ZWrite[_ZWrite]
		Cull[_Cull]

		HLSLPROGRAM
		
		//#pragma vertex vertexShader
		#pragma target 4.6 
		#pragma vertex VertexTessellationShader
		#pragma hull hull
		#pragma domain domain
		#pragma fragment FragmentShader


		struct VertexInput{
			float4 positionOS:POSITION;
			float3 normalOS:NORMAL;
			float4 tangentOS:TANGENT;
			float2 texcoord:TEXCOORD0;
		};
		
		struct VertexOutput{
			float3 positionWS :INTERNALTESSPOS;
			float3 normalWS:NORMAL;
			float4 tangentOS:TANGENT;
			float2 texcoord:TEXCOORD0;
		};

		float random(float2 st){
			return frac(sin(dot(st.xy,float2(12.9898,78.233)))*43758.543123);
		}


		//VertexShader
		VertexOutput VertexTessellationShader(VertexInput input){
			VertexOutput output;

			output.tangentOS=input.tangentOS;
			output.texcoord=input.texcoord;
			output.normalWS=GetVertexNormalInputs(input.normalOS).normalWS;

			

			
			output.positionWS=TransformObjectToWorld(input.positionOS).xyz;

			return output;
		}


		//Vertex->ConstantHS+hull->domain
		struct OutputPatchConstant{
			float edge[3]:SV_TESSFACTOR;
			float inside:SV_INSIDETESSFACTOR;
			float3 vTangent[4]:TANGENT;
			float2 vUV[4]:TEXCOORD;
			float3 vTanUcorner[4]:TANUCORNER;
			float3 uTanUcorner[4]:TANVCORNER;
			float4 vCWts:TANWEIGHTS;
		};

		//Tesslation function
		real4 Tessellation(VertexOutput v,VertexOutput v1,VertexOutput v2){
			float minDist=0.0;
			float maxDist=50.0;

			real3 triVertexFactors=GetDistanceBasedTessFactor(v.positionWS,v1.positionWS,v2.positionWS,GetCameraPositionWS(),minDist,maxDist);




			return CalcTriTessFactorsFromEdgeTessFactors(triVertexFactors);
		
		}

		//细分不做距离处理
		float Tessellation(VertexOutput v){
			return _TesslationLevel;
		}

		//HS-ConstantHS
		OutputPatchConstant ConstantHS(InputPatch<VertexOutput,3> patch,uint patchID:SV_PRIMITIVEID){
			OutputPatchConstant pt=(OutputPatchConstant)0;
			real4 ts=Tessellation(patch[0],patch[1],patch[2]);
			pt.edge[0]=max(2,30*ts.x);
			pt.edge[1]=max(2,30*ts.y);
			pt.edge[2]=max(2,30*ts.z);
			pt.inside=max(2,30*ts.w);
			return pt;
		}


		//Hull
		[domain("tri")]
		[partitioning("fractional_odd")]
		//顺时针
		[outputtopology("triangle_cw")]
		[patchconstantfunc("ConstantHS")]
		[outputcontrolpoints(3)]
		
		VertexOutput hull(InputPatch<VertexOutput,3> v,uint id:SV_OUTPUTCONTROLPOINTID){
			return v[id];
		}


		//Domain
		struct DomainOutput{
			float4 positionCS:SV_POSITION;
			float3 positionWS:TEXCOORD0;
			float2 texcoord:TEXCOORD1;
			float3 normalWS:TEXCOORD2;
			float4 tangentOS:TEXCOORD3;
			
		};

		[domain("tri")]
		DomainOutput domain(OutputPatchConstant tessFactor,const OutputPatch<VertexOutput,3>vi,float3 bary:SV_DOMAINLOCATION){
			DomainOutput output =(DomainOutput)0;
			
			output.tangentOS=vi[0].tangentOS*bary.x+vi[1].tangentOS*bary.y+vi[2].tangentOS*bary.z;

			output.normalWS=vi[0].normalWS*bary.x+vi[1].normalWS*bary.y+vi[2].normalWS*bary.z;

			
			output.texcoord=vi[0].texcoord*bary.x+vi[1].texcoord*bary.y+vi[2].texcoord*bary.z;


			float _MaskTex_var=SAMPLE_TEXTURE2D_LOD(_MaskTex,sampler_MaskTex,output.texcoord.xy,0).r;
			//tex2Dlod(sampler_MaskTex,float4(output.texcoord.xy,0,0)).r;
			float _BaseTex_var=SAMPLE_TEXTURE2D_LOD(_BaseMap,sampler_BaseMap,output.texcoord.xy,0).r;
			//tex2Dlod(sampler_BaseMap,float4(output.texcoord.xy,0,0)).r;

			
			


			output.positionWS=vi[0].positionWS*bary.x+vi[1].positionWS*bary.y+vi[2].positionWS*bary.z;

			//output.positionWS.xyz-=output.normalWS*random(output.texcoord.xy);
			output.positionWS.xyz-=output.normalWS*(_BaseTex_var-0.7+_MaskTex_var)*_Displacement;

			output.positionCS=TransformWorldToHClip(output.positionWS);

			
		
			return output;
		}


		float4 FragmentShader(DomainOutput input):SV_TARGET{
			float4 _MaskTexColor=SAMPLE_TEXTURE2D(_MaskTex,sampler_MaskTex,TRANSFORM_TEX(input.texcoord,_MaskTex));
		
			float4 _BaseMapColor=SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,TRANSFORM_TEX(input.texcoord,_BaseMap))*_BaseColor;
			float4 _SnowMapColor=SAMPLE_TEXTURE2D(_SnowTex,sampler_SnowTex,TRANSFORM_TEX(input.texcoord,_SnowTex))*_SnowColor;
		
			float4 c=lerp(_BaseMapColor,_SnowMapColor,_MaskTexColor);

			float3 finalColor=c.xyz;

			return float4(finalColor,1.0);
		
		}



		ENDHLSL
		}
		
    }
}
