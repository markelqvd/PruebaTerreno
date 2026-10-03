Shader "Custom/Sand"
{
    Properties
    {
        _SandColor ("Sand Color", Color) = (0.82, 0.52, 0.25, 1)

        _NoiseTex ("Sand Noise", 2D) = "white" {}

        _NoiseTiling ("Noise Tiling", Float) = 18
        _MipBias ("Sharp Mip Bias", Range(-2, 1)) = -1
        _SandNormalStrength ("Sand Normal Strength", Range(0, 1)) = 0.35

        _DiffuseYScale ("Diffuse Y Scale", Range(0, 1)) = 0.3
        _DiffuseContrast ("Diffuse Contrast", Float) = 4

        _RimColor ("Rim Color", Color) = (1, 0.55, 0.2, 1)
        _RimPower ("Rim Power", Float) = 5
        _RimStrength ("Rim Strength", Float) = 1

        _OceanColor ("Ocean Specular Color", Color) = (1, 0.45, 0.2, 1)
        _OceanPower ("Ocean Specular Power", Float) = 24
        _OceanStrength ("Ocean Specular Strength", Float) = 1

        _GlitterColor ("Glitter Color", Color) = (1, 0.75, 0.35, 1)
        _GlitterThreshold ("Glitter Threshold", Range(0, 1)) = 0.96
        _GlitterStrength ("Glitter Strength", Float) = 10

        _AnisoStart ("Anisotropy Start", Float) = 8
        _AnisoEnd ("Anisotropy End", Float) = 24

        _RippleStrength ("Ripple Strength", Range(0, 2)) = 0.15
        _RippleFrequency ("Ripple Frequency", Float) = 7
        _RippleTiling ("Ripple Tiling", Float) = 0.08
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

            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);

            CBUFFER_START(UnityPerMaterial)

            float4 _SandColor;

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
            float _GlitterThreshold;
            float _GlitterStrength;

            float _AnisoStart;
            float _AnisoEnd;

            float _RippleStrength;
            float _RippleFrequency;
            float _RippleTiling;

            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS   : TEXCOORD1;
                float2 uv         : TEXCOORD2;
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

            float DiffuseContrast(float3 normalWS, float3 lightDir)
            {
                float3 modifiedNormal = normalWS;

                modifiedNormal.y *= _DiffuseYScale;

                float value = saturate(
                    _DiffuseContrast *
                    dot(modifiedNormal, lightDir)
                );

                return value;
            }

            float AnisotropicMask(float2 uv)
            {
                float2 dx = ddx(uv);
                float2 dy = ddy(uv);

                float lengthX = length(dx);
                float lengthY = length(dy);

                float major = max(lengthX, lengthY);

                float minor = max(
                    min(lengthX, lengthY),
                    0.00001
                );

                float anisotropy = major / minor;

                float mask = 1.0 - smoothstep(
                    _AnisoStart,
                    _AnisoEnd,
                    anisotropy
                );

                return mask;
            }

            float RippleHeight(float2 position)
            {
                float2 wind =
                    normalize(float2(1.0, 0.25));

                float2 side =
                    float2(
                        -wind.y,
                        wind.x
                    );

                float wave1 =
                    sin(
                        dot(position, wind)
                        *
                        _RippleFrequency
                    );

                float wave2 =
                    sin(
                        dot(position, side)
                        *
                        (_RippleFrequency * 0.45)
                    );

                float wave =
                    wave1 * 0.75 +
                    wave2 * 0.25;

                return wave * _RippleStrength;
            }

            float3 RippleNormal(
                float2 position,
                float3 originalNormal
            )
            {
                float epsilon = 0.03;

                float heightL =
                    RippleHeight(
                        position - float2(epsilon, 0)
                    );

                float heightR =
                    RippleHeight(
                        position + float2(epsilon, 0)
                    );

                float heightD =
                    RippleHeight(
                        position - float2(0, epsilon)
                    );

                float heightU =
                    RippleHeight(
                        position + float2(0, epsilon)
                    );

                float dx =
                    (heightR - heightL)
                    /
                    (2.0 * epsilon);

                float dz =
                    (heightU - heightD)
                    /
                    (2.0 * epsilon);

                float3 rippleNormal =
                    normalize(
                        originalNormal
                        -
                        float3(
                            dx,
                            0,
                            dz
                        )
                    );

                return rippleNormal;
            }

            float3 SampleSandNormal(
                float2 uv,
                float3 normalWS
            )
            {
                float3 random =
                    SAMPLE_TEXTURE2D_BIAS(
                        _NoiseTex,
                        sampler_NoiseTex,
                        uv,
                        _MipBias
                    ).rgb;

                random = random * 2.0 - 1.0;

                random = normalize(random);

                float3 reference =
                    abs(normalWS.y) < 0.999
                    ? float3(0,1,0)
                    : float3(1,0,0);

                float3 tangent =
                    normalize(cross(reference, normalWS));

                float3 bitangent =
                    normalize(cross(normalWS, tangent));

                float3 randomWorld =
                    normalize(
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

            float3 RimLighting(
                float3 N,
                float3 V
            )
            {
                float rim = 1.0 - saturate(dot(N, V));

                rim = pow(rim, _RimPower);

                rim *= _RimStrength;

                return rim * _RimColor.rgb;
            }

            float3 OceanSpecular(
                float3 N,
                float3 L,
                float3 V
            )
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
                float3 V
            )
            {
                float3 G =
                    SAMPLE_TEXTURE2D_BIAS(
                        _NoiseTex,
                        sampler_NoiseTex,
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
                // --------------------------------------------------
                // DIRECCIONES
                // --------------------------------------------------

                Light mainLight = GetMainLight();

                float3 L =
                    normalize(mainLight.direction);

                float3 V =
                    normalize(
                        GetWorldSpaceNormalizeViewDir(
                            IN.positionWS
                        )
                    );

                // --------------------------------------------------
                // NORMAL BASE
                // --------------------------------------------------

                float3 N =
                    normalize(IN.normalWS);

                // --------------------------------------------------
                // RIPPLES
                // --------------------------------------------------

                float slope =
                    1.0 -
                    saturate(
                        dot(
                            N,
                            float3(0, 1, 0)
                        )
                    );

                float rippleMask =
                    smoothstep(
                        0.05,
                        0.8,
                        slope
                    );

                float3 rippleN =
                    RippleNormal(
                        IN.positionWS.xz * _RippleTiling,
                        N
                    );

                N =
                    normalize(
                        lerp(
                            N,
                            rippleN,
                            rippleMask
                        )
                    );

                // --------------------------------------------------
                // GRAINOS DE ARENA
                // --------------------------------------------------

                float2 noiseUV =
                    IN.positionWS.xz *
                    _NoiseTiling;

                N =
                    SampleSandNormal(
                        noiseUV,
                        N
                    );

                // --------------------------------------------------
                // DIFFUSE CONTRAST
                // --------------------------------------------------

                float diffuse =
                    DiffuseContrast(
                        N,
                        L
                    );

                float3 diffuseColor =
                    _SandColor.rgb *
                    diffuse *
                    mainLight.color;

                // --------------------------------------------------
                // RIM LIGHT
                // --------------------------------------------------

                float3 rimColor =
                    RimLighting(
                        N,
                        V
                    );

                // --------------------------------------------------
                // OCEAN SPECULAR
                // --------------------------------------------------

                float3 oceanColor =
                    OceanSpecular(
                        N,
                        L,
                        V
                    );

                float3 specularColor =
                    max(
                        rimColor,
                        oceanColor
                    );

                // --------------------------------------------------
                // GLITTER
                // --------------------------------------------------

                float glitterMask =
                    AnisotropicMask(
                        noiseUV
                    );

                float3 glitterColor =
                    Glitter(
                        noiseUV,
                        L,
                        V
                    );

                glitterColor *=
                    glitterMask;

                // --------------------------------------------------
                // FINAL
                // --------------------------------------------------

                float3 finalColor =
                    diffuseColor +
                    specularColor +
                    glitterColor;

                return float4(
                    finalColor,
                    1
                );
            }

            ENDHLSL
        }
    }
}