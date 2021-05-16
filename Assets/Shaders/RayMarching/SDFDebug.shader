Shader "URPPostProcess/SDFDebug"
{
    Properties
    {
        
    }
    SubShader
    {
        Tags{
            "RenderPipeline"="UniversalRenderPipeline"
        }
        Cull Off ZWrite Off ZTest Always

        HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
		        float4x4 _InverseP;
		        float4x4 _InverseV;
                float4x4 viewFrustumVector4;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

        ENDHLSL
        Pass
        {
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
                float3 ray:TEXCOORD1;
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

                output.ray=viewFrustumVector4[(int)index].xyz;
                //output.ray=mul(_InverseV,output.ray);
                return output;
            }
            float4 GetWorldSpacePostion(float2 uv,float depth){
                float4 viewPos=mul(_InverseP,float4(uv*2-1,depth,1));
                viewPos.xyz/=viewPos.w;

                float4 worldPos=mul(_InverseV,float4(viewPos.xyz,1));
                return worldPos;
            }

            float sdSphere(in float3 pos){
                return length(pos)-1;
            }
            float sdBox(float3 p,float3 b){
                float3 d=abs(p)-b;
                return min(max(d.x,max(d.y,d.z)),0.0)+length(max(d,0.0));
            }
            float map(float3 p){
                float box=sdBox(float3(p.x-0.4,p.y-0.1,p.z-0.2),float3(0.2,0.52,0.2));
                return box;
            }


            float3 getNormal(in float3 pos){
                float dx=(sdSphere(pos+float3(0.01,0,0))-sdSphere(pos))/0.01;
                float dy=(sdSphere(pos+float3(0,0.01,0))-sdSphere(pos))/0.01;
                float dz=(sdSphere(pos+float3(0,0,0.01))-sdSphere(pos))/0.01;
                return normalize(float3(dx,dy,dz));
            }

            float4 fragmentShader(Varyings input):SV_TARGET{
                
                float3 Ray=input.ray;
                float3 dir=normalize(Ray);

                float4 ret=float4(0,0,0,0);
                float t=0;
                for(int i=0;i<64;i++){
                    float3 p=_WorldSpaceCameraPos+dir*t;
                    float d=map(p);
                    if(d<0.001){
                        ret=float4(0.5,0.5,0.5,1);
                        break;
                    }
                    t+=d;
                }

                
                return ret;
            }

           ENDHLSL
        }
    }
}
