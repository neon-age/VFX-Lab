using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEditor;

public class CellularGenerator : EditorWindow {

    [MenuItem(
        "Tools/Support Textures Generators/Cellular Noise Generator",
        false, 102)]
    public static void OpenWindow () => GetWindow<CellularGenerator>();

    private enum CombinationMode {
        First = 0,
        SecondMinusFirst = 1
    }

    private bool _seamless;
    private CombinationMode _combination;
    private bool _squaredDistance;
    private float _variation;
    private float _frequency;
    private int _octaves;
    private float _persistance;
    private float _lacunarity;
    private float _jitter;
    private float _rangeMin;
    private float _rangeMax;
    private float _power;
    private bool _inverted;
    private Vector2Int _resolution;
    private string _path;

    private Material _material;
    private Texture2D _preview;

    private void OnEnable () {

        // EditorPrefs to load settings when you last used it.
        _seamless = EditorPrefs.GetBool(
            "TOOL_CELLULARGENERATOR_seamless", true);
        _combination = (CombinationMode)EditorPrefs.GetInt(
            "TOOL_CELLULARGENERATOR_combination", 0);
        _squaredDistance = EditorPrefs.GetBool(
            "TOOL_CELLULARGENERATOR_squaredDistance", false);
        _variation = EditorPrefs.GetFloat(
            "TOOL_CELLULARGENERATOR_variation", 0f);
        _frequency = EditorPrefs.GetFloat(
            "TOOL_CELLULARGENERATOR_frequency", 1f);
        _octaves = EditorPrefs.GetInt(
            "TOOL_CELLULARGENERATOR_octaves", 1);
        _persistance = EditorPrefs.GetFloat(
            "TOOL_CELLULARGENERATOR_persistance", 0.5f);
        _lacunarity = EditorPrefs.GetFloat(
            "TOOL_CELLULARGENERATOR_lacunarity", 2f);
        _jitter = EditorPrefs.GetFloat(
            "TOOL_CELLULARGENERATOR_jitter", 1f);
        _rangeMin = EditorPrefs.GetFloat(
            "TOOL_CELLULARGENERATOR_rangeMin", 0f);
        _rangeMax = EditorPrefs.GetFloat(
            "TOOL_CELLULARGENERATOR_rangeMax", 1f);
        _power = EditorPrefs.GetFloat(
            "TOOL_CELLULARGENERATOR_power", 1f);
        _inverted = EditorPrefs.GetBool(
            "TOOL_CELLULARGENERATOR_inverted", false);
        _resolution.x = EditorPrefs.GetInt(
            "TOOL_CELLULARGENERATOR_resolution_x", 256);
        _resolution.y = EditorPrefs.GetInt(
            "TOOL_CELLULARGENERATOR_resolution_y", 256);
        _path = EditorPrefs.GetString(
            "TOOL_CELLULARGENERATOR_path", "Textures/new-noise.png");
        
        _material = new Material(Shader.Find("Editor/CellularNoiseGenerator"));
        UpdateMaterial();
        _preview = GeneratePreview(192, 192);

        this.minSize = new Vector2(300, 760);
    }

    private void OnDisable () {

        // EditorPrefs to save settings for when you next use it.
        EditorPrefs.SetBool(
            "TOOL_CELLULARGENERATOR_seamless", _seamless);
        EditorPrefs.SetInt(
            "TOOL_CELLULARGENERATOR_combination", (int)_combination);
        EditorPrefs.SetBool(
            "TOOL_CELLULARGENERATOR_squaredDistance", _squaredDistance);
        EditorPrefs.SetFloat(
            "TOOL_CELLULARGENERATOR_variation", _variation);
        EditorPrefs.SetFloat(
            "TOOL_CELLULARGENERATOR_frequency", _frequency);
        EditorPrefs.SetInt(
            "TOOL_CELLULARGENERATOR_octaves", _octaves);
        EditorPrefs.SetFloat(
            "TOOL_CELLULARGENERATOR_persistance", _persistance);
        EditorPrefs.SetFloat(
            "TOOL_CELLULARGENERATOR_lacunarity", _lacunarity);
        EditorPrefs.SetFloat(
            "TOOL_CELLULARGENERATOR_jitter", _jitter);
        EditorPrefs.SetFloat(
            "TOOL_CELLULARGENERATOR_rangeMin", _rangeMin);
        EditorPrefs.SetFloat(
            "TOOL_CELLULARGENERATOR_rangeMax", _rangeMax);
        EditorPrefs.SetFloat(
            "TOOL_CELLULARGENERATOR_power", _power);
        EditorPrefs.SetBool(
            "TOOL_CELLULARGENERATOR_inverted", _inverted);
        EditorPrefs.SetInt(
            "TOOL_CELLULARGENERATOR_resolution_x", _resolution.x);
        EditorPrefs.SetInt(
            "TOOL_CELLULARGENERATOR_resolution_y", _resolution.y);
        EditorPrefs.SetString(
            "TOOL_CELLULARGENERATOR_path", _path);
    }

    private void OnGUI () {

        // Noise settings.
        EditorGUI.BeginChangeCheck();
        _seamless = EditorGUILayout.ToggleLeft(
            "Seamless", _seamless);
        _combination = (CombinationMode)EditorGUILayout.EnumPopup(
            "Combination Mode", (CombinationMode)_combination);
        _squaredDistance = EditorGUILayout.ToggleLeft(
            "Squared Distance", _squaredDistance);
        _variation = EditorGUILayout.FloatField(
            "Variation", _variation);
        _frequency = EditorGUILayout.FloatField(
            "Frequency", _frequency);
        _jitter = EditorGUILayout.Slider(
            "Jitter", _jitter, 0f, 1f);
        
        GUILayout.Space(16);
        GUILayout.Label("Fractal Settings", EditorStyles.boldLabel);
        _octaves = EditorGUILayout.IntSlider(
            "Octaves", _octaves, 1, 9);
        _persistance = EditorGUILayout.Slider(
            "Persistance", _persistance, 0f, 1f);
        _lacunarity = EditorGUILayout.Slider(
            "Lacunarity", _lacunarity, 0.1f, 4.0f);

        GUILayout.Space(16);
        GUILayout.Label("Modifiers", EditorStyles.boldLabel);
        EditorGUILayout.LabelField(
            "Range:", _rangeMin.ToString() + " to " + _rangeMax.ToString());
        EditorGUILayout.MinMaxSlider(ref _rangeMin, ref _rangeMax, 0f, 1f);

        _power = EditorGUILayout.Slider(
            "Interpolation Power", _power, 1f, 8f);
        _inverted = EditorGUILayout.Toggle(
            "Inverted", _inverted);
        
        if (EditorGUI.EndChangeCheck()) {
            _variation = _variation < 0f ? 0f : _variation;
            _frequency = _frequency < 0f ? 0f : _frequency;
            UpdateMaterial();
            _preview = GeneratePreview(_preview.width, _preview.height);
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
        EditorGUI.DrawPreviewTexture(new Rect(32, 464, 192, 192), _preview);

        // Save button.
        GUILayout.Space(254);
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
        switch (_seamless) {
            case true:
                _material.EnableKeyword("_SEAMLESS");
                break;
            case false:
                _material.DisableKeyword("_SEAMLESS");
                break;
        }

        float normFactor = 0f;
        for (int i = 0; i < _octaves; i++) {
            normFactor += Mathf.Pow(_persistance, i);
        }
        switch (_combination) {
            case CombinationMode.First:
                _material.EnableKeyword("_COMBINATION_ONE");
                _material.DisableKeyword("_COMBINATION_TWO");
                normFactor *= 0.7f;
                break;
            case CombinationMode.SecondMinusFirst:
                _material.EnableKeyword("_COMBINATION_TWO");
                _material.DisableKeyword("_COMBINATION_ONE");
                normFactor *= 0.4f;
                break;
        }
        _material.SetFloat("_NormFactor", normFactor);

        switch (_squaredDistance) {
            case true:
                _material.EnableKeyword("_SQUARED_DISTANCE");
                break;
            case false:
                _material.DisableKeyword("_SQUARED_DISTANCE");
                break;
        }

        _material.SetFloat("_Variation", _variation);
        _material.SetFloat("_Frequency", _frequency);
        _material.SetFloat("_Jitter", _jitter);
        _material.SetFloat("_Octaves", (float)_octaves);
        _material.SetFloat("_Persistance", _persistance);
        _material.SetFloat("_Lacunarity", _lacunarity);

        _material.SetFloat("_RangeMin", _rangeMin);
        _material.SetFloat("_RangeMax", _rangeMax);
        _material.SetFloat("_Power", _power);
        switch (_inverted) {
            case true:
                _material.EnableKeyword("_INVERTED");
                break;
            case false:
                _material.DisableKeyword("_INVERTED");
                break;
        }
    }

    private Texture2D GeneratePreview (int width, int height) {
        Texture2D tex = new Texture2D(
            width, height, TextureFormat.ARGB32, false);
        RenderTexture temp = RenderTexture.GetTemporary(
            width, height, 0, RenderTextureFormat.ARGB32);
        Graphics.Blit(tex, temp, _material);
        Graphics.CopyTexture(temp, tex);
        RenderTexture.ReleaseTemporary(temp);
        return tex;
    }

    private Texture2D GenerateTexture (int width, int height) {
        Texture2D tex = new Texture2D(
            width, height, TextureFormat.ARGB32, false);
        RenderTexture temp = RenderTexture.GetTemporary(
            width, height, 0, RenderTextureFormat.ARGB32);
        Graphics.Blit(tex, temp, _material);

        // We can't just .CopyTexture() and .EncodeToPNG() because
        // .EncodeToPNG() grabs what's on the texture on the RAM, but
        // .CopyTexture() only changes the texture on the GPU. In order
        // to bring the GPU memory back into the CPU, we need a .ReadPixels()
        // call, whence why the existence of this whole function.
        RenderTexture.active = temp;
        tex.ReadPixels(new Rect(0, 0, width, height), 0, 0);
        RenderTexture.active = null;
        RenderTexture.ReleaseTemporary(temp);

        return tex;
    }

}

