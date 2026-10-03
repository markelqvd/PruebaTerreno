Shader "Hidden/Sand/InteractionStamp"
{
    Properties
    {
        _MainTex ("Source", 2D) = "black" {}
        _StampUV ("Stamp UV", Vector) = (0.5, 0.5, 0, 0)
        _StampSize ("Stamp Size", Vector) = (0.01, 0.02, 0, 0)
        _StampAngle ("Stamp Angle", Float) = 0
        _StampStrength ("Stamp Strength", Range(0, 1)) = 1
        _Decay ("Decay", Range(0, 1)) = 1
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Overlay"
        }

        Pass
        {
            ZTest Always
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
            float4 _StampUV;
            float4 _StampSize;
            float _StampAngle;
            float _StampStrength;
            float _Decay;
            CBUFFER_END

            float4 _MainTex_TexelSize;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Varyings Vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionCS = float4(IN.positionOS.xy, 0, 1);
                OUT.uv = IN.uv;
                return OUT;
            }

            float2 Rotate(float2 value, float angle)
            {
                float s = sin(angle);
                float c = cos(angle);
                return float2(
                    value.x * c - value.y * s,
                    value.x * s + value.y * c
                );
            }

            float FootprintMask(float2 uv)
            {
                float2 size = max(_StampSize.xy, float2(0.0001, 0.0001));
                float2 p = (uv - _StampUV.xy) / size;
                p = Rotate(p, _StampAngle);

                float2 toeP = float2(
                    p.x * 1.15,
                    (p.y - 0.28) * 1.05
                );

                float2 heelP = float2(
                    p.x * 1.5,
                    (p.y + 0.30) * 1.35
                );

                float2 bridgeP = float2(
                    p.x * 1.4,
                    p.y * 0.75
                );

                float toe = exp(-dot(toeP, toeP) * 3.5);
                float heel = exp(-dot(heelP, heelP) * 4.0);
                float bridge = exp(-dot(bridgeP, bridgeP) * 7.0);

                float mask = max(toe, heel);
                mask = max(mask, bridge * 0.8);

                float border = 1.0 - smoothstep(
                    1.0,
                    1.35,
                    length(p)
                );

                return saturate(mask * border);
            }

            float4 Frag(Varyings IN) : SV_Target
            {
                float2 sourceUV = IN.uv;

                #if UNITY_UV_STARTS_AT_TOP
                if (_MainTex_TexelSize.y < 0)
                    sourceUV.y = 1.0 - sourceUV.y;
                #endif

                float oldValue = SAMPLE_TEXTURE2D(
                    _MainTex,
                    sampler_MainTex,
                    sourceUV
                ).r;

                float stamp =
                    FootprintMask(IN.uv) *
                    _StampStrength;

                float value = saturate(
                    oldValue * _Decay + stamp
                );

                return float4(value, 0, 0, 1);
            }
            ENDHLSL
        }
    }
}
