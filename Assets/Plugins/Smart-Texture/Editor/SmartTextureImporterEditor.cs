#if UNITY_EDITOR
using System;
using UnityEditor;
using UnityEngine;


[CustomEditor(typeof(SmartTextureImporter), true)]
class SmartTextureImporterEditor : UnityEditor.AssetImporters.ScriptedImporterEditor
{
    [CustomPropertyDrawer(typeof(SmartTextureImporter.InputProperty), true)]
    class InputPropertyDrawer : PropertyDrawer
    {
        GUIContent temp = new GUIContent();

        public override void OnGUI(Rect rect, SerializedProperty property, GUIContent label)
        {
            var name = property.FindPropertyRelative("propertyName");
            var value = property.FindPropertyRelative("value");

            rect.width /= 2;
            EditorGUI.PropertyField(rect, name, GUIContent.none);

            EditorGUIUtility.labelWidth = 15;
            rect.x += rect.width;
            if (value.propertyType == SerializedPropertyType.Vector4){
                rect.width /= 4;
                temp.text = " x"; EditorGUI.PropertyField(rect, value.FindPropertyRelative("x"), temp); rect.x += rect.width;
                temp.text = " y"; EditorGUI.PropertyField(rect, value.FindPropertyRelative("y"), temp); rect.x += rect.width;
                temp.text = " z"; EditorGUI.PropertyField(rect, value.FindPropertyRelative("z"), temp); rect.x += rect.width;
                temp.text = " w"; EditorGUI.PropertyField(rect, value.FindPropertyRelative("w"), temp); 
            }
            else{
                temp.text = " ";
                EditorGUI.PropertyField(rect, value, temp);
            }
        }
    }

    internal static class Styles
    {
        public static readonly GUIContent readWrite = EditorGUIUtility.TrTextContent("Read/Write Enabled", "Enable to be able to access the raw pixel data from code.");
        public static readonly GUIContent generateMipMaps = EditorGUIUtility.TrTextContent("Generate Mip Maps");
        public static readonly GUIContent streamingMipMaps = EditorGUIUtility.TrTextContent("Streaming Mip Maps");
        public static readonly GUIContent streamingMipMapsPrio = EditorGUIUtility.TrTextContent("Streaming Mip Maps Priority");
        public static readonly GUIContent sRGBTexture = EditorGUIUtility.TrTextContent("sRGB (Color Texture)", "Texture content is stored in gamma space. Non-HDR color textures should enable this flag (except if used for IMGUI).");

        public static readonly GUIContent textureFilterMode = EditorGUIUtility.TrTextContent("Filter Mode");
        public static readonly GUIContent textureWrapMode = EditorGUIUtility.TrTextContent("Wrap Mode");
        public static readonly GUIContent textureAnisotropicLevel = EditorGUIUtility.TrTextContent("Anisotropic Level");

        public static readonly GUIContent crunchCompression = EditorGUIUtility.TrTextContent("Crunch");
        public static readonly GUIContent useExplicitTextureFormat = EditorGUIUtility.TrTextContent("Use Explicit Texture Format");

        public static readonly string[] textureSizeOptions =
        {
            "32", "64", "128", "256", "512", "1024", "2048", "4096", "8192",
        };

        public static readonly string[] textureCompressionOptions = Enum.GetNames(typeof(TextureImporterCompression));
        public static readonly string[] textureFormat = Enum.GetNames(typeof(TextureFormat));
        public static readonly string[] resizeAlgorithmOptions = Enum.GetNames(typeof(TextureResizeAlgorithm));
    }

    SerializedProperty m_Inputs;
    SerializedProperty m_BlitMaterial;
    SerializedProperty m_OutputSize;
    SerializedProperty m_Preview;
    
    SerializedProperty m_IsReadableProperty;
    SerializedProperty m_sRGBTextureProperty;
    SerializedProperty m_HasAlpha;
    
    SerializedProperty m_EnableMipMap;
    SerializedProperty m_StreamingMipMaps;
    SerializedProperty m_StreamingMipMapPriority;

    SerializedProperty m_FilterModeProperty;
    SerializedProperty m_WrapModeProperty;
    SerializedProperty m_AnisotropiceLevelPropery;

    SerializedProperty m_TexturePlatformSettings;

    SerializedProperty m_TextureFormat;
    SerializedProperty m_UseExplicitTextureFormat;

    bool m_ShowAdvanced = false;

    const string k_AdvancedTextureSettingName = "SmartTextureImporterShowAdvanced";
        
    public override void OnEnable()
    {
        base.OnEnable();
        CacheSerializedProperties();
    }
    
    public override void OnInspectorGUI()
    {
        serializedObject.Update();
        
        m_ShowAdvanced = EditorPrefs.GetBool(k_AdvancedTextureSettingName, m_ShowAdvanced);
        
        EditorGUI.BeginChangeCheck();
      
        EditorGUILayout.BeginHorizontal();
        ApplyRevertGUI();
        if (GUILayout.Button("Repack"))
            ApplyAndImport();
        GUILayout.FlexibleSpace();
        EditorGUILayout.EndHorizontal();
        GUILayout.Space(5);

        EditorGUILayout.PropertyField(m_BlitMaterial);
        EditorGUILayout.PropertyField(m_OutputSize);

        EditorGUILayout.PropertyField(m_Inputs);
        
        if (m_EnableMipMap.isExpanded = EditorGUILayout.BeginFoldoutHeaderGroup(m_EnableMipMap.isExpanded, "Output Texture"))
        {
            // TODO: Figure out how to apply TextureImporterSettings on ScriptedImporter
            EditorGUILayout.PropertyField(m_HasAlpha);
            EditorGUILayout.PropertyField(m_IsReadableProperty, Styles.readWrite);
            EditorGUILayout.PropertyField(m_sRGBTextureProperty, Styles.sRGBTexture);
            EditorGUILayout.Space();
            
            EditorGUILayout.PropertyField(m_EnableMipMap, Styles.generateMipMaps);
            EditorGUILayout.PropertyField(m_StreamingMipMaps, Styles.streamingMipMaps);
            EditorGUILayout.PropertyField(m_StreamingMipMapPriority, Styles.streamingMipMapsPrio);
            EditorGUILayout.Space();

            EditorGUILayout.PropertyField(m_FilterModeProperty, Styles.textureFilterMode);
            EditorGUILayout.PropertyField(m_WrapModeProperty, Styles.textureWrapMode);

            EditorGUILayout.IntSlider(m_AnisotropiceLevelPropery, 0, 16, Styles.textureAnisotropicLevel);
            EditorGUILayout.Space();
        }
        EditorGUILayout.EndFoldoutHeaderGroup();

        // TODO: Figure out how to apply PlatformTextureImporterSettings on ScriptedImporter
        DrawTextureImporterSettings();
        serializedObject.ApplyModifiedProperties();
    }

    void DrawTextureImporterSettings()
    {
        SerializedProperty maxTextureSize = m_TexturePlatformSettings.FindPropertyRelative("m_MaxTextureSize");
        SerializedProperty resizeAlgorithm =
            m_TexturePlatformSettings.FindPropertyRelative("m_ResizeAlgorithm");
        SerializedProperty textureCompression =
            m_TexturePlatformSettings.FindPropertyRelative("m_TextureCompression");
        SerializedProperty textureCompressionCrunched =
            m_TexturePlatformSettings.FindPropertyRelative("m_CrunchedCompression");

        if (m_TexturePlatformSettings.isExpanded = EditorGUILayout.BeginFoldoutHeaderGroup(m_TexturePlatformSettings.isExpanded, "Texture Platform Settings"))
        {
            EditorGUI.BeginChangeCheck();
            int sizeOption = EditorGUILayout.Popup("Texture Size", (int)Mathf.Log(maxTextureSize.intValue, 2) - 5, Styles.textureSizeOptions);
            if (EditorGUI.EndChangeCheck())
                maxTextureSize.intValue = 32 << sizeOption;

            EditorGUI.BeginChangeCheck();
            int resizeOption = EditorGUILayout.Popup("Resize Algorithm", resizeAlgorithm.intValue, Styles.resizeAlgorithmOptions);
            if (EditorGUI.EndChangeCheck())
                resizeAlgorithm.intValue = resizeOption;

            //EditorGUILayout.LabelField("Compression", EditorStyles.boldLabel);
            //using (new EditorGUI.IndentLevelScope())
            {
                EditorGUI.BeginChangeCheck();
                bool explicitFormat = EditorGUILayout.Toggle(Styles.useExplicitTextureFormat, m_UseExplicitTextureFormat.boolValue);
                if (EditorGUI.EndChangeCheck())
                    m_UseExplicitTextureFormat.boolValue = explicitFormat;

                using (new EditorGUI.DisabledScope(explicitFormat))
                {
                    GUILayout.BeginHorizontal();
                    EditorGUI.BeginChangeCheck();
                    int compressionOption = EditorGUILayout.Popup("Texture Type", textureCompression.intValue, Styles.textureCompressionOptions);
                    if (EditorGUI.EndChangeCheck())
                        textureCompression.intValue = compressionOption;

                    EditorGUI.BeginChangeCheck();
                    var oldWidth = EditorGUIUtility.labelWidth;
                    EditorGUIUtility.labelWidth = 100f;
                    bool crunchOption = EditorGUILayout.Toggle(Styles.crunchCompression, textureCompressionCrunched.boolValue);
                    EditorGUIUtility.labelWidth = oldWidth;
                    if (EditorGUI.EndChangeCheck())
                        textureCompressionCrunched.boolValue = crunchOption;
                    GUILayout.EndHorizontal();
                }

                using (new EditorGUI.DisabledScope(!explicitFormat))
                {
                    EditorGUI.BeginChangeCheck();
                    int format = EditorGUILayout.EnumPopup("Texture Format", (TextureFormat)m_TextureFormat.intValue).GetHashCode();//("Compression", m_TextureFormat.enumValueIndex, Styles.textureFormat);
                    if (EditorGUI.EndChangeCheck())
                        m_TextureFormat.intValue = format;
                }
            }
        }
        EditorGUILayout.EndFoldoutHeaderGroup();
    }
    
    void CacheSerializedProperties()
    {
        m_BlitMaterial = serializedObject.FindProperty("m_BlitMaterial");
        m_OutputSize = serializedObject.FindProperty("m_OutputSize");
        m_Inputs = serializedObject.FindProperty("m_Inputs");
        m_Preview = serializedObject.FindProperty("m_Preview");
        
        m_IsReadableProperty = serializedObject.FindProperty("m_IsReadable");
        m_sRGBTextureProperty = serializedObject.FindProperty("m_sRGBTexture");
        m_HasAlpha = serializedObject.FindProperty("m_HasAlpha");
        
        m_EnableMipMap = serializedObject.FindProperty("m_EnableMipMap");
        m_StreamingMipMaps = serializedObject.FindProperty("m_StreamingMipMaps");
        m_StreamingMipMapPriority = serializedObject.FindProperty("m_StreamingMipMapPriority");

        m_FilterModeProperty = serializedObject.FindProperty("m_FilterMode");
        m_WrapModeProperty = serializedObject.FindProperty("m_WrapMode");
        m_AnisotropiceLevelPropery = serializedObject.FindProperty("m_AnisotricLevel");

        m_TexturePlatformSettings = serializedObject.FindProperty("m_TexturePlatformSettings");
        m_TextureFormat = serializedObject.FindProperty("m_TextureFormat");
        m_UseExplicitTextureFormat = serializedObject.FindProperty("m_UseExplicitTextureFormat");
    }
}
#endif