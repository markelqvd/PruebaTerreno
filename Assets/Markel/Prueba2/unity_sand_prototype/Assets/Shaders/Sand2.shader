Shader "Custom/Sand2"
{
    Properties
    {
        [Header(Sand Base)]
        _SandColor ("Sand Color", Color) = (0.72, 0.32, 0.12, 1)
        _SandVariation ("Sand Variation", Range(0, 1)) = 0.08
        _SandDarkness ("Sand Darkness", Range(0, 1)) = 0.18

        [Header(Grain)]
        _GrainTex ("Grain Texture", 2D) = "white" {}
        _NoiseTiling ("Grain Tiling", Float) = 18
        _MipBias ("Sharp Mip Bias", Range(-2, 1)) = -0.5
        _SandNormalStrength ("Sand Normal Strength", Range(0, 1)) = 0.35

        [Header(Diffuse)]
        _DiffuseYScale ("Diffuse Y Scale", Range(0, 1)) = 0.3
        _DiffuseContrast ("Diffuse Contrast", Float) = 4

        [Header(Rim)]
        _RimColor ("Rim Color", Color) = (1, 0.32, 0.08, 1)
        _RimPower ("Rim Power", Float) = 5
        _RimStrength ("Rim Strength", Float) = 0.5

        [Header(Ocean Style Specular)]
        _OceanColor ("Ocean Specular Color", Color) = (1, 0.35, 0.08, 1)
        _OceanPower ("Ocean Specular Power", Float) = 28
        _OceanStrength ("Ocean Specular Strength", Float) = 0.55

        [Header(Glitter)]
        _GlitterTex ("Glitter Texture", 2D) = "white" {}
        _GlitterColor ("Glitter Color", Color) = (1, 0.9, 0.7, 1)
        _GlitterTiling ("Glitter Tiling", Float) = 22
        _GlitterThreshold ("Glitter Threshold", Range(0, 1)) = 0.985
        _GlitterStrength ("Glitter Strength", Float) = 5
        _AnisoStart ("Anisotropy Start", Float) = 8
        _AnisoEnd ("Anisotropy End", Float) = 24

        [Header(Ripples)]
        _RippleStrength ("Ripple Strength", Range(0, 2)) = 0.12
        _RippleFrequency ("Ripple Frequency", Float) = 7
        _RippleTiling ("Ripple Tiling", Float) = 0.08
        _RippleNoiseScale ("Ripple Noise Scale", Float) = 1.8
        _RippleNoiseStrength ("Ripple Noise Strength", Range(0, 1)) = 0.35
        _RippleSpeed ("Ripple Speed", Float) = 0.08
        _WindDirection ("Wind Direction", Vector) = (1, 0.25, 0, 0)

        [Header(Footprints)]
        _SandInteractionTex ("Sand Interaction", 2D) = "black" {}
        _InteractionCenter ("Interaction Center", Vector) = (0, 0, 0, 0)
        _InteractionWorldSize ("Interaction World Size", Float) = 100
        _FootprintDepth ("Footprint Depth", Range(0, 1)) = 0.3
        _FootprintNormalStrength ("Footprint Normal Strength", Range(0, 2)) = 0.8
        _FootprintDarkness ("Footprint Darkness", Range(0, 1)) = 0.18
        _FootprintEdgeStrength ("Footprint Edge Strength", Float) = 7
        _FootprintEdgeColor ("Footprint Edge Color", Color) = (1, 0.5, 0.18, 1)
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }

        Pass
        {
            Name "ForwardLit"
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM

            #pragma target 4.5
            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_GrainTex);
            SAMPLER(sampler_GrainTex);

            TEXTURE2D(_GlitterTex);
            SAMPLER(sampler_GlitterTex);

            TEXTURE2D(_SandInteractionTex);
            SAMPLER(sampler_SandInteractionTex);

            CBUFFER_START(UnityPerMaterial)
            float4 _SandColor;
            float _SandVariation;
            float _SandDarkness;

            float _NoiseTiling;
            float _MipBias;
            float _SandNormalStrength;

            float _DiffuseYScale;
            float _DiffuseContrast;

            float4 _RimColor;
            float _RimPower;
            float _RimStrength;

            float4 _OceanColor;
            float _OceanPower;
            float _OceanStrength;

            float4 _GlitterColor;
            float _GlitterTiling;
            float _GlitterThreshold;
            float _GlitterStrength;
            float _AnisoStart;
            float _AnisoEnd;

            float _RippleStrength;
            float _RippleFrequency;
            float _RippleTiling;
            float _RippleNoiseScale;
            float _RippleNoiseStrength;
            float _RippleSpeed;
            float4 _WindDirection;

            float4 _InteractionCenter;
            float _InteractionWorldSize;
            float _FootprintDepth;
            float _FootprintNormalStrength;
            float _FootprintDarkness;
            float _FootprintEdgeStrength;
            float4 _FootprintEdgeColor;
            CBUFFER_END

            float4 _SandInteractionTex_TexelSize;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float2 uv : TEXCOORD2;
            };

            Varyings Vert(Attributes IN)
            {
                Varyings OUT;

                VertexPositionInputs positionInputs =
                    GetVertexPositionInputs(IN.positionOS.xyz);

                VertexNormalInputs normalInputs =
                    GetVertexNormalInputs(IN.normalOS);

                OUT.positionCS = positionInputs.positionCS;
                OUT.positionWS = positionInputs.positionWS;
                OUT.normalWS = normalize(normalInputs.normalWS);
                OUT.uv = IN.uv;

                return OUT;
            }

            float Hash21(float2 p)
            {
                p = frac(p * float2(123.34, 456.21));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }

            float ValueNoise2D(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                f = f * f * (3.0 - 2.0 * f);

                float a = Hash21(i);
                float b = Hash21(i + float2(1, 0));
                float c = Hash21(i + float2(0, 1));
                float d = Hash21(i + float2(1, 1));

                return lerp(
                    lerp(a, b, f.x),
                    lerp(c, d, f.x),
                    f.y
                );
            }

            float DiffuseContrast(float3 normalWS, float3 lightDir)
            {
                float3 modifiedNormal = normalWS;
                modifiedNormal.y *= _DiffuseYScale;

                return saturate(
                    _DiffuseContrast *
                    dot(modifiedNormal, lightDir)
                );
            }

            float AnisotropicMask(float2 uv)
            {
                float2 dx = ddx(uv);
                float2 dy = ddy(uv);

                float lengthX = length(dx);
                float lengthY = length(dy);

                float major = max(lengthX, lengthY);
                float minor = max(min(lengthX, lengthY), 0.00001);

                float anisotropy = major / minor;

                return 1.0 - smoothstep(
                    _AnisoStart,
                    _AnisoEnd,
                    anisotropy
                );
            }

            float RippleHeight(float2 position)
            {
                float2 wind = normalize(_WindDirection.xy);
                float2 side = float2(-wind.y, wind.x);

                float2 moved = position + wind * (_Time.y * _RippleSpeed);

                float noise =
                    (ValueNoise2D(moved * _RippleNoiseScale) - 0.5)
                    * _RippleNoiseStrength;

                float wave1 = sin(
                    dot(moved, wind) * _RippleFrequency + noise * 2.0
                );

                float wave2 = sin(
                    dot(moved, side) * (_RippleFrequency * 0.45) + noise
                );

                float wave =
                    wave1 * 0.72 +
                    wave2 * 0.28;

                return wave * _RippleStrength;
            }

            float3 RippleNormal(
                float2 position,
                float3 originalNormal)
            {
                float epsilon = 0.03;

                float heightL = RippleHeight(
                    position - float2(epsilon, 0)
                );

                float heightR = RippleHeight(
                    position + float2(epsilon, 0)
                );

                float heightD = RippleHeight(
                    position - float2(0, epsilon)
                );

                float heightU = RippleHeight(
                    position + float2(0, epsilon)
                );

                float dx = (heightR - heightL) / (2.0 * epsilon);
                float dz = (heightU - heightD) / (2.0 * epsilon);

                float3 rippleNormal = normalize(
                    originalNormal - float3(dx, 0, dz)
                );

                return rippleNormal;
            }

            float3 SampleSandNormal(
                float2 uv,
                float3 normalWS)
            {
                float3 random = SAMPLE_TEXTURE2D_BIAS(
                    _GrainTex,
                    sampler_GrainTex,
                    uv,
                    _MipBias
                ).rgb;

                random = normalize(random * 2.0 - 1.0);

                float3 reference =
                    abs(normalWS.y) < 0.999
                    ? float3(0, 1, 0)
                    : float3(1, 0, 0);

                float3 tangent = normalize(cross(reference, normalWS));
                float3 bitangent = normalize(cross(normalWS, tangent));

                float3 randomWorld = normalize(
                    tangent * random.x +
                    bitangent * random.y +
                    normalWS * abs(random.z)
                );

                return normalize(
                    lerp(
                        normalWS,
                        randomWorld,
                        _SandNormalStrength
                    )
                );
            }

            float2 InteractionUV(float3 worldPosition)
            {
                return (worldPosition.xz - _InteractionCenter.xz)
                    / _InteractionWorldSize + 0.5;
            }

            float SampleInteraction(float2 uv)
            {
                if (uv.x < 0 || uv.x > 1 || uv.y < 0 || uv.y > 1)
                    return 0;

                return SAMPLE_TEXTURE2D(
                    _SandInteractionTex,
                    sampler_SandInteractionTex,
                    uv
                ).r;
            }

            void ApplyFootprintInteraction(
                float2 uv,
                inout float3 N,
                out float depth,
                out float edge)
            {
                depth = SampleInteraction(uv);

                float2 texel =
                    max(_SandInteractionTex_TexelSize.xy, 0.000001) * 1.5;

                float left = SampleInteraction(uv - float2(texel.x, 0));
                float right = SampleInteraction(uv + float2(texel.x, 0));
                float down = SampleInteraction(uv - float2(0, texel.y));
                float up = SampleInteraction(uv + float2(0, texel.y));

                float dx = (right - left) * 0.5 * _FootprintDepth;
                float dz = (up - down) * 0.5 * _FootprintDepth;
                depth *= _FootprintDepth;

                float3 reference =
                    abs(N.y) < 0.999
                    ? float3(0, 1, 0)
                    : float3(1, 0, 0);

                float3 tangent = normalize(cross(reference, N));
                float3 bitangent = normalize(cross(N, tangent));

                float3 imprintNormal = normalize(
                    N +
                    tangent * dx * _FootprintNormalStrength +
                    bitangent * dz * _FootprintNormalStrength
                );

                float mask = smoothstep(0.015, 0.15, depth);
                N = normalize(lerp(N, imprintNormal, mask));

                float neighbourAverage =
                    (left + right + down + up) * 0.25;

                edge = saturate(
                    abs(depth - neighbourAverage) *
                    _FootprintEdgeStrength
                );
            }

            float3 RimLighting(float3 N, float3 V)
            {
                float rim = 1.0 - saturate(dot(N, V));
                rim = pow(rim, _RimPower);
                rim *= _RimStrength;

                return rim * _RimColor.rgb;
            }

            float3 OceanSpecular(
                float3 N,
                float3 L,
                float3 V)
            {
                float3 H = normalize(L + V);
                float intensity = saturate(dot(N, H));
                intensity = pow(intensity, _OceanPower);
                intensity *= _OceanStrength;

                return intensity * _OceanColor.rgb;
            }

            float3 Glitter(
                float2 uv,
                float3 L,
                float3 V)
            {
                float3 G = SAMPLE_TEXTURE2D_BIAS(
                    _GlitterTex,
                    sampler_GlitterTex,
                    uv,
                    _MipBias
                ).rgb;

                G = normalize(G * 2.0 - 1.0);

                float3 R = reflect(-L, G);
                float alignment = saturate(dot(R, V));

                float sparkle = smoothstep(
                    _GlitterThreshold,
                    1.0,
                    alignment
                );

                sparkle = pow(sparkle, 6.0);
                sparkle *= _GlitterStrength;

                return sparkle * _GlitterColor.rgb;
            }

            float4 Frag(Varyings IN) : SV_Target
            {
                Light mainLight = GetMainLight();

                float3 L = normalize(mainLight.direction);
                float3 V = normalize(
                    GetWorldSpaceNormalizeViewDir(IN.positionWS)
                );

                float3 N = normalize(IN.normalWS);

                // ---------------------------------------------
                // RIPPLE
                // ---------------------------------------------
                float slope = 1.0 - saturate(dot(N, float3(0, 1, 0)));
                float rippleMask = smoothstep(0.05, 0.8, slope);

                float3 rippleN = RippleNormal(
                    IN.positionWS.xz * _RippleTiling,
                    N
                );

                N = normalize(lerp(N, rippleN, rippleMask));

                // ---------------------------------------------
                // MICRO GRAIN
                // ---------------------------------------------
                float2 grainUV = IN.positionWS.xz * _NoiseTiling;
                N = SampleSandNormal(grainUV, N);

                // ---------------------------------------------
                // FOOTPRINT INTERACTION
                // ---------------------------------------------
                float2 interactionUV = InteractionUV(IN.positionWS);
                float footprintDepth;
                float footprintEdge;

                ApplyFootprintInteraction(
                    interactionUV,
                    N,
                    footprintDepth,
                    footprintEdge
                );

                // ---------------------------------------------
                // BASE COLOR VARIATION
                // ---------------------------------------------
                float variation = ValueNoise2D(
                    IN.positionWS.xz * 0.12
                );

                float variationFactor = lerp(
                    1.0 - _SandDarkness,
                    1.0 + _SandVariation,
                    variation
                );

                float3 sandBase =
                    _SandColor.rgb * variationFactor;

                // ---------------------------------------------
                // DIFFUSE
                // ---------------------------------------------
                float diffuse = DiffuseContrast(N, L);

                float3 diffuseColor =
                    sandBase *
                    diffuse *
                    mainLight.color;

                // ---------------------------------------------
                // RIM + OCEAN SPECULAR
                // ---------------------------------------------
                float3 rimColor = RimLighting(N, V);
                float3 oceanColor = OceanSpecular(N, L, V);
                float3 specularColor = max(rimColor, oceanColor);

                // ---------------------------------------------
                // GLITTER
                // ---------------------------------------------
                float2 glitterUV =
                    IN.positionWS.xz * _GlitterTiling;

                float glitterMask =
                    AnisotropicMask(glitterUV);

                float3 glitterColor =
                    Glitter(glitterUV, L, V) *
                    glitterMask;

                // ---------------------------------------------
                // FOOTPRINT COLOR
                // ---------------------------------------------
                float footprintMask =
                    smoothstep(0.01, 0.2, footprintDepth);

                diffuseColor *= lerp(
                    1.0,
                    1.0 - _FootprintDarkness,
                    footprintMask
                );

                float3 edgeColor =
                    _FootprintEdgeColor.rgb *
                    footprintEdge *
                    0.12;

                // ---------------------------------------------
                // FINAL HDR COLOR
                // ---------------------------------------------
                return float4(
                    diffuseColor +
                    specularColor +
                    glitterColor +
                    edgeColor,
                    1
                );
            }

            ENDHLSL
        }
    }
}