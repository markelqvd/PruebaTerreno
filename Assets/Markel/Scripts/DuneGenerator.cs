using UnityEngine;

[RequireComponent(typeof(MeshFilter))]
[RequireComponent(typeof(MeshRenderer))]
public class DuneGenerator : MonoBehaviour
{
    [Header("Mesh")]
    [Min(16)]
    public int resolution = 160;

    public float size = 100f;
    public float height = 12f;

    [Header("Large Dunes")]
    public float noiseScale = 0.035f;
    public int octaves = 4;
    [Range(0f, 1f)]
    public float persistence = 0.45f;
    public float lacunarity = 2f;

    [Header("Shape")]
    public AnimationCurve heightCurve =
        AnimationCurve.EaseInOut(0f, 0f, 1f, 1f);

    private Mesh generatedMesh;

    private void Start()
    {
        Generate();
    }

    [ContextMenu("Generate Dunes")]
    public void Generate()
    {
        MeshFilter meshFilter = GetComponent<MeshFilter>();

        if (generatedMesh != null)
        {
            Destroy(generatedMesh);
        }

        generatedMesh = new Mesh();
        generatedMesh.name = "Procedural Dune";

        int vertexCount = (resolution + 1) * (resolution + 1);

        Vector3[] vertices = new Vector3[vertexCount];
        Vector2[] uvs = new Vector2[vertexCount];
        int[] triangles = new int[resolution * resolution * 6];

        for (int z = 0; z <= resolution; z++)
        {
            for (int x = 0; x <= resolution; x++)
            {
                float u = x / (float)resolution;
                float v = z / (float)resolution;

                float localX = (u - 0.5f) * size;
                float localZ = (v - 0.5f) * size;

                float noise = FractalNoise(
                    localX * noiseScale,
                    localZ * noiseScale
                );

                float finalHeight = heightCurve.Evaluate(noise) * height;

                int index = z * (resolution + 1) + x;

                vertices[index] = new Vector3(
                    localX,
                    finalHeight,
                    localZ
                );

                uvs[index] = new Vector2(u, v);
            }
        }

        int triangleIndex = 0;

        for (int z = 0; z < resolution; z++)
        {
            for (int x = 0; x < resolution; x++)
            {
                int current = z * (resolution + 1) + x;

                int next = current + resolution + 1;

                triangles[triangleIndex++] = current;
                triangles[triangleIndex++] = next;
                triangles[triangleIndex++] = current + 1;

                triangles[triangleIndex++] = current + 1;
                triangles[triangleIndex++] = next;
                triangles[triangleIndex++] = next + 1;
            }
        }

        generatedMesh.vertices = vertices;
        generatedMesh.uv = uvs;
        generatedMesh.triangles = triangles;

        generatedMesh.RecalculateNormals();
        generatedMesh.RecalculateBounds();

        meshFilter.sharedMesh = generatedMesh;
    }

    private float FractalNoise(float x, float z)
    {
        float value = 0f;

        float amplitude = 1f;
        float frequency = 1f;

        float normalization = 0f;

        for (int i = 0; i < octaves; i++)
        {
            float sample = Mathf.PerlinNoise(
                x * frequency,
                z * frequency
            );

            value += sample * amplitude;

            normalization += amplitude;

            amplitude *= persistence;
            frequency *= lacunarity;
        }

        return value / normalization;
    }
}