using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEditor;

public class TextureCombiner : EditorWindow {
    
    [MenuItem("Tools/Support Textures Generators/Texture Combiner",
    false, 120)]
    public static void OpenWindow () => GetWindow<TextureCombiner>();

    private Texture2D _textureR;
    private Texture2D _textureG;
    private Texture2D _textureB;
    private Texture2D _textureA;
    private bool _normalize;
    private Vector2Int _resolution;
    private string _path;

    private Material _material;
    private Texture2D _preview;

    private void OnEnable () {
        // EditorPrefs to load settings when you last used it.
        _resolution.x = EditorPrefs.GetInt(
            "TOOL_TEXTURECOMBINER_resolution_x", 256);
        _resolution.y = EditorPrefs.GetInt(
            "TOOL_TEXTURECOMBINER_resolution_y", 256);
        _path = EditorPrefs.GetString(
            "TOOL_TEXTURECOMBINER_path", "Textures/new-noise.png");

        _material = new Material(Shader.Find("Editor/CombinedTexture"));
        _preview = GenerateTexture(192, 192);

        this.minSize = new Vector2(300, 686);
    }

    private void OnDisable () {

        // EditorPrefs to save settings for when you next use it.
        EditorPrefs.SetInt(
            "TOOL_TEXTURECOMBINER_resolution_x", _resolution.x);
        EditorPrefs.SetInt(
            "TOOL_TEXTURECOMBINER_resolution_y", _resolution.y);
        EditorPrefs.SetString(
            "TOOL_TEXTURECOMBINER_path", _path);
    }

    private void OnGUI () {

        // Textures to be combined.
        EditorGUI.BeginChangeCheck();
        _textureR = (Texture2D)EditorGUILayout.ObjectField(
            "Texture R", _textureR, typeof(Texture), false);
        _textureG = (Texture2D)EditorGUILayout.ObjectField(
            "Texture G", _textureG, typeof(Texture), false);
        _textureB = (Texture2D)EditorGUILayout.ObjectField(
            "Texture B", _textureB, typeof(Texture), false);
        _textureA = (Texture2D)EditorGUILayout.ObjectField(
            "Texture A", _textureA, typeof(Texture), false);
        _normalize = EditorGUILayout.ToggleLeft(
            "Normalize", _normalize);
        if (EditorGUI.EndChangeCheck()) {
            UpdateMaterial();
            _preview = GenerateTexture(_preview.width, _preview.height);
        }

        // Texture settings. They don't cause the preview to change.
        GUILayout.Space(32);
        GUILayout.Label("Target File Settings", EditorStyles.boldLabel);
        EditorGUI.BeginChangeCheck();
        _resolution = EditorGUILayout.Vector2IntField(
            "Texture Resolution", _resolution);
        _path = EditorGUILayout.TextField(
            "File Path", _path);
        if (EditorGUI.EndChangeCheck()) {
            _resolution.x = _resolution.x < 1 ? 1 : _resolution.x;
            _resolution.y = _resolution.y < 1 ? 1 : _resolution.y;
        }

        // Draw preview texture.
        GUILayout.Space(10);
        EditorGUI.DrawPreviewTexture(new Rect(32, 428, 192, 192), _preview);

        // Save button.
        GUILayout.Space(244);
        if (GUILayout.Button("Save Texture")) {
            Texture2D tex = GenerateTexture(_resolution.x, _resolution.y);
            byte[] data = tex.EncodeToPNG();
            Object.DestroyImmediate(tex);
            File.WriteAllBytes(
                string.Format("{0}/{1}", Application.dataPath, _path), data);
            AssetDatabase.Refresh(ImportAssetOptions.ForceUpdate);
        }

    }

    private void UpdateMaterial () {
        _material.SetTexture("_TexR", _textureR);
        _material.SetTexture("_TexG", _textureG);
        _material.SetTexture("_TexB", _textureB);
        _material.SetTexture("_TexA", _textureA);
    }

    private Texture2D GenerateTexture (int width, int height) {
        Texture2D tex = new Texture2D(
            width, height, TextureFormat.ARGB32, false);
        RenderTexture temp = RenderTexture.GetTemporary(
            width, height, 0, RenderTextureFormat.ARGB32);
        Graphics.Blit(tex, temp, _material);

        RenderTexture.active = temp;
        tex.ReadPixels(new Rect(0, 0, width, height), 0, 0);
        RenderTexture.active = null;
        RenderTexture.ReleaseTemporary(temp);
        tex.Apply();

        if (_normalize) {
            tex = NormalizePixels(tex);
        }

        return tex;
    }

    private Texture2D NormalizePixels (Texture2D input) {
        Color max = new Color(0f, 0f, 0f, 0f);
        Color min = new Color(1f, 1f, 1f, 1f);
        for (int i = 0; i < input.width; i++) {
            for (int j = 0; j < input.height; j++) {
                Color col = input.GetPixel(i, j);
                max.r = col.r > max.r ? col.r : max.r;
                max.g = col.g > max.g ? col.g : max.g;
                max.b = col.b > max.b ? col.b : max.b;
                max.a = col.a > max.a ? col.a : max.a;
                min.r = col.r < min.r ? col.r : min.r;
                min.g = col.g < min.g ? col.g : min.g;
                min.b = col.b < min.b ? col.b : min.b;
                min.a = col.a < min.a ? col.a : min.a;
            }
        }

        Texture2D tex = new Texture2D(
            input.width, input.height, TextureFormat.ARGB32, false);
        for (int i = 0; i < tex.width; i++) {
            for (int j = 0; j < tex.height; j++) {
                Color inputCol = input.GetPixel(i, j);
                Color newCol = new Color(0f, 0f, 0f, 1f);

                newCol.r = Mathf.InverseLerp(min.r, max.r, inputCol.r);
                newCol.g = Mathf.InverseLerp(min.g, max.g, inputCol.g);
                newCol.b = Mathf.InverseLerp(min.b, max.b, inputCol.b);
                newCol.a = Mathf.InverseLerp(min.a, max.a, inputCol.a);

                if (min.r == max.r) {
                    newCol.r = min.r;
                }
                if (min.g == max.g) {
                    newCol.g = min.g;
                }
                if (min.b == max.b) {
                    newCol.b = min.b;
                }
                if (min.a == max.a) {
                    newCol.a = min.a;
                }

                tex.SetPixel(i, j, newCol);
            }
        }
        tex.Apply();
        return tex;
    }

}