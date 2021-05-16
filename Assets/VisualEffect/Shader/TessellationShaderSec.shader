Shader "URP/TessellationShaderSec"
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
		#pragma vertex vert
		#pragma hull HS
		#pragma domain DS
		#pragma fragment frag


		struct app_data
            {
                float4 positionOS:POSITION;
            };
            struct VertexOut
            {
                float3 PosL:TEXCOORD0;
            };
            VertexOut vert(app_data IN)
            {
                VertexOut o;
                o.PosL=IN.positionOS.xyz;
                return o;
            }
            
            struct PatchTess
            {
                float EdgeTess[3]:SV_TessFactor;
                float InsideTess:SV_InsideTessFactor;
            };
            PatchTess ConstantHS(InputPatch<VertexOut,3> patch,uint patchID:SV_PrimitiveID)
            {
                PatchTess pt;
                pt.EdgeTess[0]=15;
                pt.EdgeTess[1]=15;
                pt.EdgeTess[2]=15;
                pt.InsideTess=15;
                return pt;
                
            }
            
            
            struct HullOut
            {
                float3 PosL:TEXCOORD0;
            };
            
            [domain("tri")]
            [partitioning("integer")]
            [outputtopology("triangle_cw")]
            [outputcontrolpoints(3)]
            [patchconstantfunc("ConstantHS")]
            [maxtessfactor(64.0f)]
            HullOut HS(InputPatch<VertexOut,3> p,uint i:SV_OutputControlPointID)
            {
                HullOut hout;
                hout.PosL=p[i].PosL;
                return hout;
            }
            
            struct DomainOut
            {
                float4 PosH:SV_POSITION;    
            };
            [domain("tri")]
            DomainOut DS(PatchTess patchTess,float3 baryCoords:SV_DomainLocation,const OutputPatch<HullOut,3> triangles)
            {
                DomainOut dout;              
                float3 p=triangles[0].PosL*baryCoords.x+triangles[1].PosL*baryCoords.y+triangles[2].PosL*baryCoords.z;
                
                dout.PosH=TransformObjectToHClip(p.xyz);
                return dout;
            }
            half4 frag(DomainOut IN):SV_Target
            {
                return half4(1,1,1,1);
            }            



		ENDHLSL
		}
		
    }
}
