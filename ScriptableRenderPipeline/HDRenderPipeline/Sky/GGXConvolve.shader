Shader "Hidden/HDRenderPipeline/GGXConvolve"
{
    SubShader
    {
        Pass
        {
            ZWrite Off
            ZTest Always
            Blend One Zero
            Cull Off

            HLSLPROGRAM
            #pragma target 4.5
            #pragma only_renderers d3d11 ps4 metal  // TEMP: until we go further in dev

            #pragma multi_compile _ USE_MIS

            #pragma vertex Vert
            #pragma fragment Frag

            #include "../../Core/ShaderLibrary/Common.hlsl"
            #include "../../Core/ShaderLibrary/ImageBasedLighting.hlsl"
            #include "SkyManager.cs.hlsl"

            TEXTURECUBE(_MainTex);
            SAMPLERCUBE(sampler_MainTex);

            TEXTURE2D_FLOAT(_GgxIblSamples);

            #ifdef USE_MIS
                TEXTURE2D(_MarginalRowDensities);
                TEXTURE2D(_ConditionalDensities);
            #endif

            float _Level;
            float _LastLevel;
            float _InvOmegaP;
            float4x4 _PixelCoordToViewDirWS; // Actually just 3x3, but Unity can only set 4x4

            struct Attributes
            {
                uint vertexID : SV_VertexID;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };

            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID);
                return output;
            }

            float4 Frag(Varyings input) : SV_Target
            {
                // Points towards the camera
                float3 viewDirWS = normalize(mul(float3(input.positionCS.xy, 1.0), (float3x3)_PixelCoordToViewDirWS));
                // Reverse it to point into the scene
                float3 N = -viewDirWS;
                // Remove view-dependency from GGX, effectively making the BSDF isotropic.
                float3 V = N;

                float perceptualRoughness = MipmapLevelToPerceptualRoughness(_Level);
                float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
                uint  sampleCount = GetIBLRuntimeFilterSampleCount(_Level);

            #ifdef USE_MIS
                float4 val = IntegrateLD_MIS(TEXTURECUBE_PARAM(_MainTex, sampler_MainTex),
                                             _MarginalRowDensities, _ConditionalDensities,
                                             V, N,
                                             roughness,
                                             _InvOmegaP,
                                             LIGHTSAMPLINGPARAMETERS_TEXTURE_WIDTH,
                                             LIGHTSAMPLINGPARAMETERS_TEXTURE_HEIGHT,
                                             1024,
                                             false);
            #else
                float4 val = IntegrateLD(TEXTURECUBE_PARAM(_MainTex, sampler_MainTex),
                                         _GgxIblSamples,
                                         V, N,
                                         roughness,
                                         _Level - 1,
                                         _LastLevel,
                                         _InvOmegaP,
                                         sampleCount, // Must be a Fibonacci number
                                         true,
                                         true);
            #endif

                return val;
            }
            ENDHLSL
        }
    }
}
