using UnityEngine;

public class SandNoiseGenerator : MonoBehaviour
{
    public Renderer targetRenderer;

    [Range(64, 1024)]
    public int textureSize = 512;

    public int seed = 12345;

    [ContextMenu("Generate Sand Noise")]
    public void Generate()
    {
        Texture2D texture = new Texture2D(
            textureSize,
            textureSize,
            TextureFormat.RGBA32,
            true
        );

        System.Random random = new System.Random(seed);

        Color[] pixels = new Color[textureSize * textureSize];

        for (int y = 0; y < textureSize; y++)
        {
            for (int x = 0; x < textureSize; x++)
            {
                float r = (float)random.NextDouble();
                float g = (float)random.NextDouble();
                float b = (float)random.NextDouble();

                pixels[y * textureSize + x] =
                    new Color(r, g, b, 1);
            }
        }

        texture.SetPixels(pixels);

        texture.wrapMode = TextureWrapMode.Repeat;
        texture.filterMode = FilterMode.Trilinear;
        texture.anisoLevel = 8;

        texture.Apply(
            updateMipmaps: true,
            makeNoLongerReadable: true
        );

        targetRenderer.sharedMaterial.SetTexture(
            "_NoiseTex",
            texture
        );
    }

    private void Start()
    {
        Generate();
    }
}