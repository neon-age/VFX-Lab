using System;
using System.IO;
using System.Linq;
using UnityEditor;

using UnityEngine;
using UnityEngine.Rendering;
using Object = UnityEngine.Object;

[UnityEditor.AssetImporters.ScriptedImporter(k_SmartTextureVersion, k_SmartTextureExtesion)]
public class SmartTextureImporter : UnityEditor.AssetImporters.ScriptedImporter
{
    public const string k_SmartTextureExtesion = "smartex";
    public const int k_SmartTextureVersion = 1;
    public const int k_MenuPriority = 320;

    [Serializable] internal class InputProperty { public string propertyName; }
    [Serializable] class InputTexture : InputProperty { public Texture value; }
    [Serializable] class InputFloat : InputProperty { public float value; }
    [Serializable] class InputColor : InputProperty { [ColorUsage(true, true)] public Color value; }
    [Serializable] class InputVector : InputProperty { public Vector4 value; }

    [Serializable] class Inputs {
        public InputTexture[] m_Textures;
        public InputFloat[] m_Floats;
        public InputColor[] m_Colors;
        public InputVector[] m_Vectors;
        
    }
    // Input Texture Settings
    [SerializeField] Material m_BlitMaterial;
    [SerializeField] Vector2Int m_OutputSize;
    [SerializeField] bool m_Preview;
    [SerializeField] Inputs m_Inputs;

    // Output Texture Settings
    [SerializeField] bool m_HasAlpha = false;
    [SerializeField] bool m_IsReadable = false;
    [SerializeField] bool m_sRGBTexture = false;
    
    [SerializeField] bool m_EnableMipMap = true;
    [SerializeField] bool m_StreamingMipMaps = false;
    [SerializeField] int m_StreamingMipMapPriority = 0;
    
    // TODO: MipMap Generation, is it possible to configure?
    //[SerializeField] bool m_BorderMipMaps = false;
    //[SerializeField] TextureImporterMipFilter m_MipMapFilter = TextureImporterMipFilter.BoxFilter;
    //[SerializeField] bool m_MipMapsPreserveCoverage = false;
    //[SerializeField] bool m_FadeoutMipMaps = false;

    [SerializeField] FilterMode m_FilterMode = FilterMode.Bilinear;
    [SerializeField] TextureWrapMode m_WrapMode = TextureWrapMode.Repeat;
    [SerializeField] int m_AnisotricLevel = 1;

    [SerializeField] TextureImporterPlatformSettings m_TexturePlatformSettings = new TextureImporterPlatformSettings();

    [SerializeField] TextureFormat m_TextureFormat = TextureFormat.ARGB32;
    [SerializeField] bool m_UseExplicitTextureFormat = false;

    [MenuItem("Assets/Create/Smart Texture", priority = k_MenuPriority)]
    static void CreateSmartTextureMenuItem()
    {
        // Asset creation code from pschraut Texture2DArrayImporter
        // https://github.com/pschraut/UnityTexture2DArrayImportPipeline/blob/master/Editor/Texture2DArrayImporter.cs#L360-L383
        string directoryPath = "Assets";
        foreach (Object obj in Selection.GetFiltered(typeof(Object), SelectionMode.Assets))
        {
            directoryPath = AssetDatabase.GetAssetPath(obj);
            if (!string.IsNullOrEmpty(directoryPath) && File.Exists(directoryPath))
            {
                directoryPath = Path.GetDirectoryName(directoryPath);
                break;
            }
        }

        directoryPath = directoryPath.Replace("\\", "/");
        if (directoryPath.Length > 0 && directoryPath[directoryPath.Length - 1] != '/')
            directoryPath += "/";
        if (string.IsNullOrEmpty(directoryPath))
            directoryPath = "Assets/";

        var fileName = string.Format("SmartTexture.{0}", k_SmartTextureExtesion);
        directoryPath = AssetDatabase.GenerateUniqueAssetPath(directoryPath + fileName);
        ProjectWindowUtil.CreateAssetWithContent(directoryPath,
            "Smart Texture Asset for Unity. Allows to channel pack textures by using a ScriptedImporter. Requires Smart Texture Package from https://github.com/phi-lira/SmartTexture. Developed by Felipe Lira.");
    }
    
    public override void OnImportAsset(UnityEditor.AssetImporters.AssetImportContext ctx)
    {
        int width = m_TexturePlatformSettings.maxTextureSize;
        int height = m_TexturePlatformSettings.maxTextureSize;
        var maxSize = m_OutputSize;

        foreach (var t in m_Inputs.m_Textures)
        {
            if (t.value == null) continue;
            if (m_OutputSize.x == 0 && t.value.width > maxSize.x) maxSize.x = t.value.width;
            if (m_OutputSize.y == 0 && t.value.height > maxSize.y) maxSize.y = t.value.height;
        }
        var canGenerateTexture = maxSize != default;
        maxSize.x = Mathf.Max(maxSize.x, 1);
        maxSize.y = Mathf.Max(maxSize.y, 1);

        //Mimic default importer. We use max size unless assets are smaller
        width = width < maxSize.x ? width : maxSize.x;
        height = height < maxSize.y ? height : maxSize.y;

        Texture2D texture = new Texture2D(width, height, m_HasAlpha ? TextureFormat.ARGB32 : TextureFormat.RGB24, m_EnableMipMap, m_sRGBTexture)
        {
            filterMode = m_FilterMode,
            wrapMode = m_WrapMode,
            anisoLevel = m_AnisotricLevel,
        };

        if (canGenerateTexture)
        {
            //Only attempt to apply any settings if the inputs exist

            PackChannels(m_BlitMaterial, texture, m_Inputs);

            // Mark all input textures as dependency to the texture array.
            // This causes the texture array to get re-generated when any input texture changes or when the build target changed.
            foreach (var t in m_Inputs.m_Textures)
            {
                if (t.value != null)
                {
                    var path = AssetDatabase.GetAssetPath(t.value);
                    ctx.DependsOnSourceAsset(path);
                }
            }

            // TODO: Seems like we need to call TextureImporter.SetPlatformTextureSettings to register/apply platform
            // settings. However we can't subclass from TextureImporter... Is there other way?

            //Currently just supporting one compression format in liew of TextureImporter.SetPlatformTextureSettings
            if (m_UseExplicitTextureFormat)
                EditorUtility.CompressTexture(texture, m_TextureFormat, 100);
            else if (m_TexturePlatformSettings.textureCompression != TextureImporterCompression.Uncompressed)
                texture.Compress(m_TexturePlatformSettings.textureCompression == TextureImporterCompression.CompressedHQ);

            ApplyPropertiesViaSerializedObj(texture);
        }
        
		//If we pass the tex to the 3rd arg we can have it show in an Icon as normal, maybe configurable?
        //ctx.AddObjectToAsset("mask", texture, texture);
		ctx.AddObjectToAsset("mask", texture, texture);
        ctx.SetMainObject(texture);
    }

    static void PackChannels(Material mat, Texture2D mask, Inputs inputs)
    {
        int width = mask.width;
        int height = mask.height;

        mat = new Material(mat);

        foreach (var i in inputs.m_Textures) mat.SetTexture(i.propertyName, i.value);
        foreach (var i in inputs.m_Floats) mat.SetFloat(i.propertyName, i.value);
        foreach (var i in inputs.m_Colors) mat.SetColor(i.propertyName, i.value);
        foreach (var i in inputs.m_Vectors) mat.SetVector(i.propertyName, i.value);
        
        var rt = RenderTexture.GetTemporary(width, height, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
        RenderTexture previous = RenderTexture.active;
        RenderTexture.active = rt;

        CommandBuffer cmd = new CommandBuffer();
        cmd.Blit(null, rt, mat);
        cmd.SetRenderTarget(BuiltinRenderTextureType.CameraTarget);
        Graphics.ExecuteCommandBuffer(cmd);
        mask.ReadPixels(new Rect(0, 0, width, height), 0, 0);
        mask.Apply();

        RenderTexture.active = previous;
        RenderTexture.ReleaseTemporary(rt);
    }

    void ApplyPropertiesViaSerializedObj(Texture tex)
    {
        var so = new SerializedObject(tex);
        
        so.FindProperty("m_IsReadable").boolValue = m_IsReadable;
        so.FindProperty("m_StreamingMipmaps").boolValue = m_StreamingMipMaps;
        so.FindProperty("m_StreamingMipmapsPriority").intValue = m_StreamingMipMapPriority;
        //Set ColorSpace on ctr instead
        //so.FindProperty("m_ColorSpace").intValue = (int)(m_sRGBTexture ? ColorSpace.Gamma : ColorSpace.Linear);

        so.ApplyModifiedPropertiesWithoutUndo();
    }
}
