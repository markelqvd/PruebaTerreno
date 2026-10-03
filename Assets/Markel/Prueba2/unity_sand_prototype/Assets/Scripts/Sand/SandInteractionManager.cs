using System.Collections.Generic;
using UnityEngine;

[DisallowMultipleComponent]
public class SandInteractionManager : MonoBehaviour
{
    [Header("World Mapping")]
    [Min(64)] public int textureSize = 512;
    [Min(1f)] public float worldSize = 100f;
    public Vector3 worldCenter = Vector3.zero;

    [Header("Persistence")]
    [Range(0f, 1f)] public float erosionPerSecond = 0.003f;

    [Header("References")]
    [Tooltip("Material using the Hidden/Sand/InteractionStamp shader.")]
    public Material interactionMaterialTemplate;
    public Material sandMaterial;

    [Header("Debug")]
    public bool logInitialization = false;

    private RenderTexture frontBuffer;
    private RenderTexture backBuffer;
    private Material interactionMaterial;

    private readonly List<FootprintRequest> pendingFootprints = new();

    private static readonly int StampUVId = Shader.PropertyToID("_StampUV");
    private static readonly int StampSizeId = Shader.PropertyToID("_StampSize");
    private static readonly int StampAngleId = Shader.PropertyToID("_StampAngle");
    private static readonly int StampStrengthId = Shader.PropertyToID("_StampStrength");
    private static readonly int DecayId = Shader.PropertyToID("_Decay");

    private static readonly int SandInteractionTexId = Shader.PropertyToID("_SandInteractionTex");
    private static readonly int InteractionCenterId = Shader.PropertyToID("_InteractionCenter");
    private static readonly int InteractionWorldSizeId = Shader.PropertyToID("_InteractionWorldSize");

    private struct FootprintRequest
    {
        public Vector3 position;
        public Vector3 forward;
        public Vector2 size;
        public float strength;
    }

    private void Awake()
    {
        Initialize();
    }

    private void OnDestroy()
    {
        Release();
    }

    private void LateUpdate()
    {
        if (!IsReady())
            return;

        float decay = Mathf.Clamp01(1f - erosionPerSecond * Time.deltaTime);
        BlitPass(decay, Vector2.zero, Vector2.zero, 0f, 0f, false);

        for (int i = 0; i < pendingFootprints.Count; i++)
        {
            FootprintRequest request = pendingFootprints[i];
            Vector2 uv = WorldToUV(request.position);

            if (uv.x < 0f || uv.x > 1f || uv.y < 0f || uv.y > 1f)
                continue;

            Vector3 forward = request.forward.sqrMagnitude > 0.001f
                ? request.forward.normalized
                : Vector3.forward;

            float angle = Mathf.Atan2(forward.z, forward.x) - Mathf.PI * 0.5f;

            Vector2 uvSize = new Vector2(
                Mathf.Max(0.001f, request.size.x / worldSize),
                Mathf.Max(0.001f, request.size.y / worldSize)
            );

            BlitPass(
                1f,
                uv,
                uvSize,
                angle,
                request.strength,
                true
            );
        }

        pendingFootprints.Clear();
    }

    public void QueueFootprint(
        Vector3 position,
        Vector3 forward,
        Vector2 size,
        float strength = 1f)
    {
        if (!IsReady())
            return;

        pendingFootprints.Add(new FootprintRequest
        {
            position = position,
            forward = forward,
            size = size,
            strength = Mathf.Clamp01(strength)
        });
    }

    public RenderTexture GetInteractionTexture()
    {
        return frontBuffer;
    }

    public Vector2 WorldToUV(Vector3 worldPosition)
    {
        float minX = worldCenter.x - worldSize * 0.5f;
        float minZ = worldCenter.z - worldSize * 0.5f;

        return new Vector2(
            (worldPosition.x - minX) / worldSize,
            (worldPosition.z - minZ) / worldSize
        );
    }

    private void Initialize()
    {
        Release();

        textureSize = Mathf.Max(64, textureSize);
        worldSize = Mathf.Max(1f, worldSize);

        RenderTextureFormat format = RenderTextureFormat.RHalf;
        if (!SystemInfo.SupportsRenderTextureFormat(format))
            format = RenderTextureFormat.ARGBHalf;

        RenderTextureDescriptor descriptor = new RenderTextureDescriptor(
            textureSize,
            textureSize,
            format,
            0
        )
        {
            autoGenerateMips = false,
            useMipMap = false,
            msaaSamples = 1,
            sRGB = false
        };

        frontBuffer = CreateBuffer("Sand Interaction A", descriptor);
        backBuffer = CreateBuffer("Sand Interaction B", descriptor);

        if (interactionMaterialTemplate == null)
        {
            Debug.LogError(
                "SandInteractionManager: Assign an interaction material using the Hidden/Sand/InteractionStamp shader.",
                this
            );
            enabled = false;
            return;
        }

        interactionMaterial = new Material(interactionMaterialTemplate)
        {
            name = "Sand Interaction Runtime"
        };

        Graphics.Blit(Texture2D.blackTexture, frontBuffer);
        Graphics.Blit(Texture2D.blackTexture, backBuffer);

        BindToSandMaterial();

        if (logInitialization)
        {
            Debug.Log(
                $"SandInteractionManager initialized: {textureSize}x{textureSize}, world size {worldSize}.",
                this
            );
        }
    }

    private RenderTexture CreateBuffer(string bufferName, RenderTextureDescriptor descriptor)
    {
        RenderTexture buffer = new RenderTexture(descriptor)
        {
            name = bufferName,
            filterMode = FilterMode.Bilinear,
            wrapMode = TextureWrapMode.Clamp
        };

        buffer.Create();
        return buffer;
    }

    private void BindToSandMaterial()
    {
        if (sandMaterial == null || frontBuffer == null)
            return;

        sandMaterial.SetTexture(SandInteractionTexId, frontBuffer);
        sandMaterial.SetVector(
            InteractionCenterId,
            new Vector4(worldCenter.x, worldCenter.y, worldCenter.z, 0f)
        );
        sandMaterial.SetFloat(InteractionWorldSizeId, worldSize);
    }

    private void BlitPass(
        float decay,
        Vector2 stampUV,
        Vector2 stampSize,
        float stampAngle,
        float stampStrength,
        bool stampEnabled)
    {
        if (!IsReady())
            return;

        interactionMaterial.SetFloat(DecayId, decay);
        interactionMaterial.SetVector(StampUVId, stampUV);
        interactionMaterial.SetVector(StampSizeId, stampSize);
        interactionMaterial.SetFloat(StampAngleId, stampAngle);
        interactionMaterial.SetFloat(
            StampStrengthId,
            stampEnabled ? stampStrength : 0f
        );

        Graphics.Blit(frontBuffer, backBuffer, interactionMaterial);
        SwapBuffers();
    }

    private void SwapBuffers()
    {
        (frontBuffer, backBuffer) = (backBuffer, frontBuffer);

        if (sandMaterial != null)
            sandMaterial.SetTexture(SandInteractionTexId, frontBuffer);
    }

    private bool IsReady()
    {
        return enabled &&
               frontBuffer != null &&
               backBuffer != null &&
               interactionMaterial != null;
    }

    private void Release()
    {
        pendingFootprints.Clear();

        if (frontBuffer != null)
        {
            frontBuffer.Release();
            DestroyRuntimeObject(frontBuffer);
            frontBuffer = null;
        }

        if (backBuffer != null)
        {
            backBuffer.Release();
            DestroyRuntimeObject(backBuffer);
            backBuffer = null;
        }

        if (interactionMaterial != null)
        {
            DestroyRuntimeObject(interactionMaterial);
            interactionMaterial = null;
        }
    }

    private static void DestroyRuntimeObject(Object target)
    {
        if (target == null)
            return;

        if (Application.isPlaying)
            Destroy(target);
        else
            DestroyImmediate(target);
    }
}
