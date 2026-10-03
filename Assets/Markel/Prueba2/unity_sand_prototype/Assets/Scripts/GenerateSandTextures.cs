using UnityEngine;
using UnityEditor;
using System.IO;

public class GenerateSandTextures
{
    [MenuItem("Tools/Generate Sand Textures")]
    public static void GenerateTextures()
    {
        int resolution = 512;
        string folderPath = "Assets/SandTextures";

        if (!Directory.Exists(folderPath))
        {
            Directory.CreateDirectory(folderPath);
        }

        // Generate Grain Texture
        string grainPath = $"{folderPath}/Sand_Grain_512.png";
        CreateRandomRGBTexture(grainPath, resolution);

        // Generate Glitter Texture
        string glitterPath = $"{folderPath}/Sand_Glitter_512.png";
        CreateRandomRGBTexture(glitterPath, resolution);

        AssetDatabase.Refresh();

        // Apply correct import settings to both
        ConfigureImporter(grainPath);
        ConfigureImporter(glitterPath);

        Debug.Log("Sand textures created successfully at " + folderPath);
    }

    private static void CreateRandomRGBTexture(string path, int size)
    {
        Texture2D tex = new Texture2D(size, size, TextureFormat.RGBA32, false);
        Color[] pixels = new Color[size * size];

        for (int i = 0; i < pixels.Length; i++)
        {
            // Uniform random vector direction in RGB channels
            pixels[i] = new Color(
                Random.value,
                Random.value,
                Random.value,
                1.0f
            );
        }

        tex.SetPixels(pixels);
        tex.Apply();

        byte[] bytes = tex.EncodeToPNG();
        File.WriteAllBytes(path, bytes);
        Object.DestroyImmediate(tex);
    }

    private static void ConfigureImporter(string path)
    {
        TextureImporter importer = AssetImporter.GetAtPath(path) as TextureImporter;
        if (importer != null)
        {
            importer.textureType = TextureImporterType.Default;
            importer.sRGBTexture = false; // Keep raw vector values linear
            importer.wrapMode = TextureWrapMode.Repeat;
            importer.mipmapEnabled = true;
            importer.filterMode = FilterMode.Bilinear;
            importer.maxTextureSize = 512;
            importer.SaveAndReimport();
        }
    }
}