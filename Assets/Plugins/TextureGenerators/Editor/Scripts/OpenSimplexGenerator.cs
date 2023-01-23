using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEditor;

public class OpenSimplexGenerator : EditorWindow {

    [MenuItem(
        "Tools/Support Textures Generators/Open Simplex Noise Generator",
        false, 101)]
    public static void OpenWindow () => GetWindow<OpenSimplexGenerator>();

    private bool _seamless;
    private int _seed;
    private float _frequency;
    private int _octaves;
    private float _persistance;
    private float _lacunarity;
    private float _rangeMin;
    private float _rangeMax;
    private float _power;
    private bool _inverted;
    private Vector2Int _resolution;
    private string _path;

    private long[] _seeds;
    private Texture2D _preview;

    private void OnEnable () {

        // EditorPrefs to load settings when you last used it.
        _seamless = EditorPrefs.GetBool(
            "TOOL_OPENSIMPLEXGENERATOR_seamless", true);
        _seed = EditorPrefs.GetInt(
            "TOOL_OPENSIMPLEXGENERATOR_seed", 0);
        _frequency = EditorPrefs.GetFloat(
            "TOOL_OPENSIMPLEXGENERATOR_frequency", 1f);
        _octaves = EditorPrefs.GetInt(
            "TOOL_OPENSIMPLEXGENERATOR_octaves", 1);
        _persistance = EditorPrefs.GetFloat(
            "TOOL_OPENSIMPLEXGENERATOR_persistance", 0.5f);
        _lacunarity = EditorPrefs.GetFloat(
            "TOOL_OPENSIMPLEXGENERATOR_lacunarity", 1f);
        _rangeMin = EditorPrefs.GetFloat(
            "TOOL_OPENSIMPLEXGENERATOR_rangeMin", 0f);
        _rangeMax = EditorPrefs.GetFloat(
            "TOOL_OPENSIMPLEXGENERATOR_rangeMax", 1f);
        _power = EditorPrefs.GetFloat(
            "TOOL_OPENSIMPLEXGENERATOR_power", 1f);
        _inverted = EditorPrefs.GetBool(
            "TOOL_OPENSIMPLEXGENERATOR_inverted", false);
        _resolution.x = EditorPrefs.GetInt(
            "TOOL_OPENSIMPLEXGENERATOR_resolution_x", 256);
        _resolution.y = EditorPrefs.GetInt(
            "TOOL_OPENSIMPLEXGENERATOR_resolution_y", 256);
        _path = EditorPrefs.GetString(
            "TOOL_OPENSIMPLEXGENERATOR_path", "Textures/new-noise.png");

        SetSeeds(_seed);
        _preview = GenerateTexture(192, 192);

        this.minSize = new Vector2(300, 660);
    }

    private void OnDisable() {

        // EditorPrefs to save settings for when you next use it.
        EditorPrefs.SetBool(
            "TOOL_OPENSIMPLEXGENERATOR_seamless", _seamless);
        EditorPrefs.SetInt(
            "TOOL_OPENSIMPLEXGENERATOR_seed", _seed);
        EditorPrefs.SetFloat(
            "TOOL_OPENSIMPLEXGENERATOR_frequency", _frequency);
        EditorPrefs.SetInt(
            "TOOL_OPENSIMPLEXGENERATOR_octaves", _octaves);
        EditorPrefs.SetFloat(
            "TOOL_OPENSIMPLEXGENERATOR_persistance", _persistance);
        EditorPrefs.SetFloat(
            "TOOL_OPENSIMPLEXGENERATOR_lacunarity", _lacunarity);
        EditorPrefs.SetFloat(
            "TOOL_OPENSIMPLEXGENERATOR_rangeMin", _rangeMin);
        EditorPrefs.SetFloat(
            "TOOL_OPENSIMPLEXGENERATOR_rangeMax", _rangeMax);
        EditorPrefs.SetFloat(
            "TOOL_OPENSIMPLEXGENERATOR_power", _power);
        EditorPrefs.SetBool(
            "TOOL_OPENSIMPLEXGENERATOR_inverted", _inverted);
        EditorPrefs.SetInt(
            "TOOL_OPENSIMPLEXGENERATOR_resolution_x", _resolution.x);
        EditorPrefs.SetInt(
            "TOOL_OPENSIMPLEXGENERATOR_resolution_y", _resolution.y);
        EditorPrefs.SetString(
            "TOOL_OPENSIMPLEXGENERATOR_path", _path);
    }

    private void OnGUI () {

        // Seeds. We need a different seed for each octave, which is why we
        // use a seeds array.
        EditorGUI.BeginChangeCheck();
        _seamless = EditorGUILayout.ToggleLeft(
            "Seamless", _seamless);
        _seed = EditorGUILayout.IntField(
            "Seed", _seed);
        if (EditorGUI.EndChangeCheck()) {
            SetSeeds(_seed);
            _preview = GenerateTexture(_preview.width, _preview.height);
        }

        // Noise settings.
        EditorGUI.BeginChangeCheck();
        _frequency = EditorGUILayout.FloatField("Frequency", _frequency);
        
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
        _inverted = EditorGUILayout.ToggleLeft(
            "Inverted", _inverted);

        if (EditorGUI.EndChangeCheck()) {
            _frequency = _frequency < 0f ? 0f : _frequency;
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
        EditorGUI.DrawPreviewTexture(new Rect(32, 400, 192, 192), _preview);

        // Save button.
        GUILayout.Space(236);
        if (GUILayout.Button("Save Texture")) {
            Texture2D tex = GenerateTexture(_resolution.x, _resolution.y);
            byte[] data = tex.EncodeToPNG();
            Object.DestroyImmediate(tex);
            File.WriteAllBytes(
                string.Format("{0}/{1}", Application.dataPath, _path), data);
            AssetDatabase.Refresh(ImportAssetOptions.ForceUpdate);
        }
    }

    private void SetSeeds (int newSeed) {
        System.Random rng = new System.Random(newSeed);
        _seeds = new long[9];
        for (int i = 0; i < 9; i++) {
            _seeds[i] = rng.Next(-100000, 100000);
        }
    }

    private double[] TorusMapping (float x, float y) {
        double[] map = new double[4];
        map[0] = Mathf.Sin(2f * Mathf.PI * x);
        map[1] = Mathf.Cos(2f * Mathf.PI * x);
        map[2] = Mathf.Sin(2f * Mathf.PI * y);
        map[3] = Mathf.Cos(2f * Mathf.PI * y);
        return map;
    }

    private Texture2D GenerateTexture (int width, int height) {
        float[,] values = new float[width, height];
        Texture2D tex = new Texture2D(width, height);

        // This next block is for filling the array. We will later turn this
        // array into a texture. We're doing the torus mapping on 4D.
        float maxValue = Mathf.NegativeInfinity;  // We set these so we can
        float minValue = Mathf.Infinity;          // normalize values later.
        for (int i = 0; i < width; i++) {
            for (int j = 0; j < height; j++) {
                float sum = 0f;
                float amplitude = 1f;
                float frequency = _frequency;

                for (int k = 0; k < _octaves; k++) {
                    float noise = 0f;
                    if (_seamless) {
                        double[] coords = TorusMapping(
                            (float)i / (float)width, (float)j / (float)height);
                        double nx = coords[0] * frequency;
                        double ny = coords[1] * frequency;
                        double nz = coords[2] * frequency;
                        double nw = coords[3] * frequency;
                        noise = OpenSimplex2S.Noise4_Fallback(
                            _seeds[k], nx, ny, nz, nw);
                    }
                    else {
                        double x = ((float)i / (float)width) * frequency * 5;
                        double y = ((float)j / (float)height) * frequency * 5;
                        noise = OpenSimplex2S.Noise2(_seeds[k], x, y);
                    }   

                    sum += noise * amplitude;
                    amplitude *= _persistance;
                    frequency *= _lacunarity;
                }

                values[i,j] = sum;
                maxValue = sum > maxValue ? sum : maxValue;
                minValue = sum < minValue ? sum : minValue;
            }
        }

        // For the final touches, we normalize, apply power and inverse.
        for (int i = 0; i < width; i++) {
            for (int j = 0; j < height; j++) {
                float value = values[i, j];
                value = Mathf.InverseLerp(minValue, maxValue, value);
                value = Mathf.InverseLerp(_rangeMin, _rangeMax, value);
                
                float k = Mathf.Pow(2f, _power - 1f);
                if (value < 0.5f) {
                    value = k * Mathf.Pow(value, _power);
                }
                else {
                    value = 1f - k * Mathf.Pow(1f - value, _power);
                }

                value = _inverted ? 1f - value : value;

                // Finally, we make the texture.
                tex.SetPixel(i, j, new Color(value, value, value, 1.0f));
            }
        }
        tex.Apply();
        return tex;
    }

}
