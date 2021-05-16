Shader "UniversalRenderPipeline/WaterShader"
{
    Properties
    {
        _BumpScale("Detail Wave Amount",Range(0,2))=0.2

        _DitherPattern("Dithering Pattern",2D)="bump"{}
        [Toggle(_STATIC_SHADER)]_Static("Static",float)=0
        
    }
    SubShader
    {
        Tags {
                "RenderType"="Transparent"
                "Queue"="Transparent-100"
                "RenderPipeline"="UniversalRenderPipeline"
                "LightMode"="UniversalForward"
             }
        ZWrite On
        Pass
        {
            HLSLPROGRAM
                #pragma shader_feature _ _STATIC_SHADER _REFLECTION_PLANARREFLECTION
                
                #pragma multi_compile _ USE_STRUCTURED_BUFFER

                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE

                #pragma multi_compile _ _ADDITIONAL_LIGHT_VERTEX _ADDITIONAL_LIGHTS
                #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
                #pragma multi_compile _ _SHADOWS_SOFT

                #pragma multi_compile_instancing
                #pragma multi_compile_fog

                #include "WaterCommon.hlsl"

                #pragma vertex WaterVertex
                #pragma fragment WaterFragment

            ENDHLSL
        }
    }
}
