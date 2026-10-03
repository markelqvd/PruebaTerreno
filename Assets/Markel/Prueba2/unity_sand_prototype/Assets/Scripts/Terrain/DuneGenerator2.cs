using UnityEngine;

[DisallowMultipleComponent]
[RequireComponent(typeof(MeshFilter))]
[RequireComponent(typeof(MeshRenderer))]
[RequireComponent(typeof(MeshCollider))]
public class DuneGenerator2 : MonoBehaviour
{
    [Header("Mesh")]
    [Min(16)] public int resolution = 160;
    [Min(1f)] public float size = 100f;

    [Header("Adaptive Resolution")]
    [Tooltip("Cantidad de densidad adicional alrededor del agujero/centro.")]
    [Range(0f, 1f)] public float centralDensity = 0.85f;
    [Tooltip("Mayor valor = más vértices concentrados cerca del centro.")]
    [Min(1f)] public float centralDensityPower = 2.5f;
    [Tooltip("Radio alrededor del centro donde se concentra la resolución.")]
    [Min(0.1f)] public float centralDensityRadius = 12f;

    [Header("Playable Area")]
    [Min(0f)] public float playableRadius = 20f;
    [Min(0.1f)] public float transitionWidth = 18f;
    [Min(0f)] public float flatHeight = 0f;
    [Min(0f)] public float flatNoiseScale = 0.10f;
    [Min(0f)] public float flatNoiseStrength = 0.35f;

    [Header("Mountain Boundary")]
    [Min(0f)] public float mountainBaseHeight = 6f;
    [Min(0f)] public float mountainHeight = 16f;
    [Min(0.001f)] public float mountainNoiseScale = 0.035f;
    [Min(0f)] public float mountainNoiseStrength = 1f;
    [Range(1, 8)] public int mountainOctaves = 4;
    [Min(0f)] public float boundaryWarp = 8f;
    [Min(0.001f)] public float boundaryNoiseScale = 0.02f;

    [Header("Central Hole")]
    public bool enableHole = true;
    [Tooltip("Posición X/Z del centro del agujero.")]
    public Vector2 holeCenter = Vector2.zero;
    [Min(0.1f)] public float holeRadius = 3f;
    [Min(0.1f)] public float holeDepth = 8f;
    [Min(0.1f)] public float holeEdgeWidth = 1.5f;
    [Tooltip("Si está activado, holeFloorHeight será una altura absoluta.")]
    public bool useAbsoluteHoleFloorHeight = false;
    [Tooltip("Altura absoluta del fondo del agujero.")]
    public float holeFloorHeight = -8f;

    [Header("Seed")]
    public int seed = 12345;

    [Header("Runtime")]
    public bool regenerateOnStart = true;

    private MeshFilter meshFilter;
    private MeshCollider meshCollider;
    private Mesh generatedMesh;

    private void Awake()
    {
        CacheComponents();
        if (Application.isPlaying && regenerateOnStart)
        {
            Generate();
        }
    }

    private void CacheComponents()
    {
        if (meshFilter == null) meshFilter = GetComponent<MeshFilter>();
        if (meshCollider == null) meshCollider = GetComponent<MeshCollider>();
    }

    [ContextMenu("Generate Terrain")]
    public void Generate()
    {
        CacheComponents();

        resolution = Mathf.Max(16, resolution);
        size = Mathf.Max(1f, size);
        playableRadius = Mathf.Max(0f, playableRadius);
        transitionWidth = Mathf.Max(0.1f, transitionWidth);
        centralDensityRadius = Mathf.Max(0.1f, centralDensityRadius);
        centralDensityPower = Mathf.Max(1f, centralDensityPower);

        int verticesPerSide = resolution + 1;
        int vertexCount = verticesPerSide * verticesPerSide;

        Vector3[] vertices = new Vector3[vertexCount];
        Vector2[] uvs = new Vector2[vertexCount];
        int[] triangles = new int[resolution * resolution * 6];

        float halfSize = size * 0.5f;
        Vector2 seedOffset = new Vector2(
            HashTo01(seed, 17.13f) * 1000f,
            HashTo01(seed, 53.71f) * 1000f
        );

        for (int z = 0; z <= resolution; z++)
        {
            float v = z / (float)resolution;
            float normalizedZ = Mathf.Lerp(-1f, 1f, v);

            for (int x = 0; x <= resolution; x++)
            {
                float u = x / (float)resolution;
                float normalizedX = Mathf.Lerp(-1f, 1f, u);

                float holeCenterNormalizedX = holeCenter.x / halfSize;
                float holeCenterNormalizedZ = holeCenter.y / halfSize;

                float adaptedX = RemapCoordinateAroundCenter(normalizedX, holeCenterNormalizedX, centralDensityRadius / halfSize, centralDensity, centralDensityPower);
                float adaptedZ = RemapCoordinateAroundCenter(normalizedZ, holeCenterNormalizedZ, centralDensityRadius / halfSize, centralDensity, centralDensityPower);

                float localX = adaptedX * halfSize;
                float localZ = adaptedZ * halfSize;
                Vector2 local = new Vector2(localX, localZ);

                Vector2 holeOffset = local - holeCenter;
                float radius = holeOffset.magnitude;

                float boundaryNoise = FractalNoise01(localX * boundaryNoiseScale + seedOffset.x, localZ * boundaryNoiseScale + seedOffset.y, 3, 2f, 0.5f);
                float warpedRadius = playableRadius + (boundaryNoise - 0.5f) * boundaryWarp;
                float transitionT = Mathf.InverseLerp(warpedRadius, warpedRadius + transitionWidth, radius);
                float mountainMask = Smooth01(transitionT);

                float flatNoise = FractalNoise01(localX * flatNoiseScale + seedOffset.x * 0.17f, localZ * flatNoiseScale + seedOffset.y * 0.17f, 3, 2f, 0.5f);
                float flatSurface = flatHeight + (flatNoise - 0.5f) * 2f * flatNoiseStrength;

                float mountainNoise = FractalNoise01(localX * mountainNoiseScale + seedOffset.x, localZ * mountainNoiseScale + seedOffset.y, mountainOctaves, 2f, 0.5f);
                float mountainSurface = flatHeight + mountainBaseHeight + mountainNoise * mountainHeight * mountainNoiseStrength;

                float height = Mathf.Lerp(flatSurface, mountainSurface, mountainMask);

                if (enableHole)
                {
                    float floorRadius = Mathf.Max(0f, holeRadius - holeEdgeWidth);
                    float holeBottom = useAbsoluteHoleFloorHeight ? holeFloorHeight : flatHeight - holeDepth;

                    if (radius <= floorRadius)
                    {
                        height = holeBottom;
                    }
                    else if (radius < holeRadius)
                    {
                        float wallT = Mathf.InverseLerp(floorRadius, holeRadius, radius);
                        wallT = Smooth01(wallT);
                        height = Mathf.Lerp(holeBottom, height, wallT);
                    }
                }

                int index = z * verticesPerSide + x;
                vertices[index] = new Vector3(localX, height, localZ);
                uvs[index] = new Vector2(u, v);
            }
        }

        int triangleIndex = 0;
        for (int z = 0; z < resolution; z++)
        {
            for (int x = 0; x < resolution; x++)
            {
                int current = z * verticesPerSide + x;
                int nextRow = current + verticesPerSide;

                triangles[triangleIndex++] = current;
                triangles[triangleIndex++] = nextRow;
                triangles[triangleIndex++] = current + 1;

                triangles[triangleIndex++] = current + 1;
                triangles[triangleIndex++] = nextRow;
                triangles[triangleIndex++] = nextRow + 1;
            }
        }

        Mesh mesh = new Mesh { name = "Procedural Dune Terrain" };

        if (vertexCount > 65535)
        {
            mesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;
        }

        mesh.vertices = vertices;
        mesh.uv = uvs;
        mesh.triangles = triangles;

        mesh.RecalculateNormals();
        mesh.RecalculateBounds();

        ReplaceGeneratedMesh(mesh);
    }

    private void ReplaceGeneratedMesh(Mesh mesh)
    {
        Mesh oldMesh = generatedMesh;
        generatedMesh = mesh;

        meshFilter.sharedMesh = generatedMesh;

        meshCollider.sharedMesh = null;
        meshCollider.sharedMesh = generatedMesh;
        meshCollider.convex = false;

        if (oldMesh != null && oldMesh != generatedMesh)
        {
            DestroyGeneratedMesh(oldMesh);
        }
    }

    private void DestroyGeneratedMesh(Mesh mesh)
    {
        if (Application.isPlaying)
        {
            Destroy(mesh);
        }
        else
        {
            DestroyImmediate(mesh);
        }
    }

    private static float RemapCoordinateAroundCenter(float value, float center, float radius, float density, float power)
    {
        if (radius <= 0f) return value;

        float offset = value - center;
        float distance = Mathf.Abs(offset);

        if (distance >= radius) return value;

        float t = Mathf.Clamp01(distance / radius);
        float concentrated = Mathf.Pow(t, power);

        float transition = Mathf.InverseLerp(0.65f, 1f, t);
        transition = Smooth01(transition);

        float localDensity = density * (1f - transition);
        float mappedT = Mathf.Lerp(t, concentrated, localDensity);

        float sign = offset >= 0f ? 1f : -1f;
        float mappedOffset = mappedT * radius * sign;

        return center + mappedOffset;
    }

    private static float Smooth01(float t)
    {
        t = Mathf.Clamp01(t);
        return t * t * (3f - 2f * t);
    }

    private static float HashTo01(int input, float salt)
    {
        float value = Mathf.Sin(input * 12.9898f + salt * 78.233f) * 43758.5453f;
        return value - Mathf.Floor(value);
    }

    private static float FractalNoise01(float x, float z, int octaves, float lacunarity, float persistence)
    {
        float value = 0f;
        float amplitude = 1f;
        float frequency = 1f;
        float normalization = 0f;

        for (int i = 0; i < octaves; i++)
        {
            float sample = Mathf.PerlinNoise(x * frequency, z * frequency);
            value += sample * amplitude;
            normalization += amplitude;
            frequency *= lacunarity;
            amplitude *= persistence;
        }

        return normalization > 0f ? value / normalization : 0f;
    }
}