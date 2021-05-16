Shader "URPPostProcess/WaterCaustics"
{
    Properties
    {
        [HideInInspector]_MainTex ("Texture", 2D) = "white" {}
        [HideInInspector] _CausticsTexture("CausticsTexture",2D)="white"{}
        _CausticsScale("CausticsScale",float)=0.0
        _WaterHeight("WaterHeight",float)=0.0
        _BlendDistance("BlendDistance",float)=0.0

        [HideInInspector]_SrcBlend("_src",float)=2.0
        [HideInInspector]_DstBlend("_dst",float)=0.0
    }
    SubShader
    {
        Tags{
            "RenderPipeline"="UniversalRenderPipeline"
        }

         ZWrite Off 

        HLSLINCLUDE
	        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl"
	        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float _CausticsScale;
                float _WaterHeight;
                float _BlendDistance;

                float4x4 _InverseP;
                float4x4 _InverseV;
                float4x4 _MainLightSpaceMat;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            TEXTURE2D(_CausticsTexture);
            SAMPLER(sampler_CausticsTexture);
        ENDHLSL

        Pass
        {
            Blend [_SrcBlend][_DstBlend],One Zero

            HLSLPROGRAM
            #pragma multi_compile _ _DEBUG

            #pragma vertex vertexShader
            #pragma fragment fragmentShader

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 texcoord : TEXCOORD;
            };

            struct Varyings
            {
                float4 screenPos:TEXCOORD;
                float4 positionCS : SV_POSITION;
            };
            /* float4 ComputeScreenPos(float4 positionCS)
            {
                float4 o = positionCS * 0.5f;
                o.xy = float2(o.x, o.y * _ProjectionParams.x) + o.w;
                o.zw = positionCS.zw;
                return o;
            } */
            Varyings vertexShader (Attributes input)
            {
                Varyings output;
                //[URP/Core.hlsl]
                VertexPositionInputs vertexInput=GetVertexPositionInputs(input.positionOS.xyz);

                //output.positionCS = TransformObjectToHClip(input.positionOS);
                output.positionCS = vertexInput.positionCS;
                
                output.screenPos=ComputeScreenPos(output.positionCS);
                return output;
            }

             float3 GetWorldSpacePostion(float2 screenPos,float depth){
                float4x4 mat = UNITY_MATRIX_I_VP;
                #if UNITY_REVERSED_Z
                mat._12_22_32_42 = -mat._12_22_32_42;              
                #else
                depth = depth * 2 - 1;
                #endif
                float4 raw = mul(mat, float4(screenPos * 2 - 1, depth, 1));
                float3 worldPos = raw.rgb / raw.a;
                return worldPos;
             }

            float2 CausticUVs(float2 input_uv,float offset){
                float2 uv=input_uv*_CausticsScale;
                return uv+offset*0.1;
            }

            float4 fragmentShader (Varyings input) : SV_Target
            {
                
                Light MainLight=GetMainLight();
                float4 screenPos=input.screenPos/input.screenPos.w;
                
                //real depth = SampleSceneDepth(screenPos.xy);[URP/DeclareDepthTexture.hlsl]
                float depth=SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,sampler_CameraDepthTexture,screenPos.xy);
                
                float4 worldPos=GetWorldSpacePostion(screenPos.xy,depth).xyzz;

                float3 lightUVs=mul(worldPos,_MainLightSpaceMat).xyz;

                float2 uv=worldPos.xz*0.025+_Time.x*0.25;
                //W通道噪波
                float waveOffset=SAMPLE_TEXTURE2D(_CausticsTexture,sampler_CausticsTexture,uv).w-0.5;
                //噪波扰动UV
                float2 causticUV=CausticUVs(lightUVs.xy,waveOffset);
                
                //根据遮罩使用LOD模糊，牛逼啊
                float LOD=abs(worldPos.y-_WaterHeight)*4/_BlendDistance;
                float4 A=SAMPLE_TEXTURE2D_LOD(_CausticsTexture,sampler_CausticsTexture,causticUV+_Time.x,LOD);
                float4 B=SAMPLE_TEXTURE2D_LOD(_CausticsTexture,sampler_CausticsTexture,causticUV*2.0,LOD);
                
                //Z通道为波纹，10用于增强A*B,+A+B叠加效果
                float CausticsDriver=(A.z*B.z)*10+A.z+B.z;

                
                //Upper&LowerMask
                half upperMask=saturate(-worldPos.y+_WaterHeight);
                half lowerMask=saturate((worldPos.y-_WaterHeight)/_BlendDistance+_BlendDistance);
                CausticsDriver*=min(upperMask,lowerMask);


                half3 causticsColor=CausticsDriver*half3(A.w*0.5,B.w*0.75,B.x)*MainLight.color*5.0;
                /*
                float FragToCamera=length(worldPos.xz-_WorldSpaceCameraPos.xz);

                float4 color0=lerp(causticsColor,color,saturate(worldPos.y-_WaterHeight));
                color=lerp(color0,color,saturate(FragToCamera-_CausticsScale*100)); 
                */
                #ifdef _DEBUG
                return float4(causticsColor,1.0);
                    #endif
                return float4(causticsColor+1.0,1.0);
            }
            ENDHLSL
        }
    }
}
