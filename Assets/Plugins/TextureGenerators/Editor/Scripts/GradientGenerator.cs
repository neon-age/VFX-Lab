using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEditor;

public class GradientGenerator : EditorWindow {

    [MenuItem(
        "Tools/Support Textures Generators/Gradient Texture Generator",
        false, 103)]
    public static void OpenWindow () => GetWindow<GradientGenerator>();

    private Gradient _gradient;
    private AnimationCurve _curve;
    private Vector2Int _resolution;
    private string _path;

     private void OnEnable () {
        _gradient = new Gradient();
        _curve = new AnimationCurve();

        // EditorPrefs to load settings when you last used it.
        _resolution.x = EditorPrefs.GetInt(
            "TOOL_GRADIENTGENERATOR_resolution_x", 128);
        _resolution.y = EditorPrefs.GetInt(
            "TOOL_GRADIENTGENERATOR_resolution_y", 1);
        _path = EditorPrefs.GetString(
            "TOOL_GRADIENTGENERATOR_path", "Textures/new-gradient.png");
        
        // Load gradient mode.
        _gradient.mode = (GradientMode)EditorPrefs.GetInt(
            "TOOL_GRADIENTGENERATOR_gradient_mode", 0);

        // Load gradient color keys data.
        int colorKeysLength = EditorPrefs.GetInt(
            "TOOL_GRADIENTGENERATOR_gradient_colorKeys_length", 2);
        GradientColorKey[] colorKeys = new GradientColorKey[colorKeysLength];
        for (int i = 0; i < colorKeysLength; i++) {
            float initialValue = (float)i;
            Color color = new Color(0f, 0f, 0f, 1f);
            color.r = EditorPrefs.GetFloat(
                "TOOL_GRADIENTGENERATOR_gradient_color_R_" + i.ToString(),
                initialValue);
            color.g = EditorPrefs.GetFloat(
                "TOOL_GRADIENTGENERATOR_gradient_color_G_" + i.ToString(),
                initialValue);
            color.b = EditorPrefs.GetFloat(
                "TOOL_GRADIENTGENERATOR_gradient_color_B_" + i.ToString(),
                initialValue);
            float time = EditorPrefs.GetFloat(
                "TOOL_GRADIENTGENERATOR_gradient_color_time_" + i.ToString(),
                initialValue);
            colorKeys[i] = new GradientColorKey(color, time);
        }

        // Load gradient alpha keys data.
        int alphaKeysLength = EditorPrefs.GetInt(
            "TOOL_GRADIENTGENERATOR_gradient_alphaKeys_length", 2);
        GradientAlphaKey[] alphaKeys = new GradientAlphaKey[alphaKeysLength];
        for (int i = 0; i < alphaKeysLength; i++) {
            float initialValue = (float)i;
            float alpha = EditorPrefs.GetFloat(
                "TOOL_GRADIENTGENERATOR_gradient_alpha_" + i.ToString(), 1f);
            float time = EditorPrefs.GetFloat(
                "TOOL_GRADIENTGENERATOR_gradient_alpha_time_" + i.ToString(),
                initialValue);
            alphaKeys[i] = new GradientAlphaKey(alpha, time);
        }

        // Load curve keyframes data.
        int keyframesLength = EditorPrefs.GetInt(
            "TOOL_GRADIENTGENERATOR_curve_keyframes_length", 2);
        Keyframe[] keyframes = new Keyframe[keyframesLength];
        for (int i = 0; i < keyframesLength; i++) {
            float initialValue = (float)i;
            keyframes[i] = new Keyframe(0f, 0f);
            keyframes[i].inTangent = EditorPrefs.GetFloat(
                "TOOL_GRADIENTGENERATOR_curve_inTangent_" + i.ToString(), 0f);
            keyframes[i].inWeight = EditorPrefs.GetFloat(
                "TOOL_GRADIENTGENERATOR_curve_inWeight_" + i.ToString(), 1f);
            keyframes[i].outTangent = EditorPrefs.GetFloat(
                "TOOL_GRADIENTGENERATOR_curve_outTangent_" + i.ToString(), 0f);
            keyframes[i].outWeight = EditorPrefs.GetFloat(
                "TOOL_GRADIENTGENERATOR_curve_outWeight_" + i.ToString(), 1f);
            keyframes[i].value = EditorPrefs.GetFloat(
                "TOOL_GRADIENTGENERATOR_curve_value_" + i.ToString(),
                initialValue);
            keyframes[i].time = EditorPrefs.GetFloat(
                "TOOL_GRADIENTGENERATOR_curve_time_" + i.ToString(),
                initialValue);
            keyframes[i].weightedMode = (WeightedMode)EditorPrefs.GetInt(
                "TOOL_GRADIENTGENERATOR_curve_mode_" + i.ToString(), 0);
        }

        // All loaded, now set the gradient and curve with the data we loaded.
        _gradient.SetKeys(colorKeys, alphaKeys);
        _curve = new AnimationCurve(keyframes);

        this.minSize = new Vector2(300, 275);
     }

     private void OnDisable () {

        // EditorPrefs to save settings for when you next use it.
        EditorPrefs.SetInt(
            "TOOL_GRADIENTGENERATOR_resolution_x", _resolution.x);
        EditorPrefs.SetInt(
            "TOOL_GRADIENTGENERATOR_resolution_y", _resolution.y);
        EditorPrefs.SetString(
            "TOOL_GRADIENTGENERATOR_path", _path);
        
        // Saving gradient mode.
        EditorPrefs.SetInt(
            "TOOL_GRADIENTGENERATOR_gradient_mode", (int)_gradient.mode);

        // Saving gradient color keys.
        EditorPrefs.SetInt(
            "TOOL_GRADIENTGENERATOR_gradient_colorKeys_length",
            _gradient.colorKeys.Length);
        for (int i = 0; i < _gradient.colorKeys.Length; i++) {
            EditorPrefs.SetFloat(
                "TOOL_GRADIENTGENERATOR_gradient_color_R_" + i.ToString(),
                _gradient.colorKeys[i].color.r);
            EditorPrefs.SetFloat(
                "TOOL_GRADIENTGENERATOR_gradient_color_G_" + i.ToString(),
                _gradient.colorKeys[i].color.g);
            EditorPrefs.SetFloat(
                "TOOL_GRADIENTGENERATOR_gradient_color_B_" + i.ToString(),
                _gradient.colorKeys[i].color.b);
            EditorPrefs.SetFloat(
                "TOOL_GRADIENTGENERATOR_gradient_color_time_" + i.ToString(),
                _gradient.colorKeys[i].time);
        }

        // Saving gradient alpha keys.
        EditorPrefs.SetInt(
            "TOOL_GRADIENTGENERATOR_gradient_alphaKeys_length",
            _gradient.alphaKeys.Length);
        for (int i = 0; i < _gradient.alphaKeys.Length; i++) {
            EditorPrefs.SetFloat(
                "TOOL_GRADIENTGENERATOR_gradient_alpha_" + i.ToString(),
                _gradient.alphaKeys[i].alpha);
            EditorPrefs.SetFloat(
                "TOOL_GRADIENTGENERATOR_gradient_alpha_time_" + i.ToString(),
                _gradient.alphaKeys[i].time);
        }

        // Saving curve keyframes.
        EditorPrefs.SetInt(
            "TOOL_GRADIENTGENERATOR_curve_keyframes_length",
            _curve.keys.Length);
        for (int i = 0; i < _curve.keys.Length; i++) {
            EditorPrefs.SetFloat(
                "TOOL_GRADIENTGENERATOR_curve_inTangent_" + i.ToString(),
                _curve.keys[i].inTangent);
            EditorPrefs.SetFloat(
                "TOOL_GRADIENTGENERATOR_curve_inWeight_" + i.ToString(),
                _curve.keys[i].inWeight);
            EditorPrefs.SetFloat(
                "TOOL_GRADIENTGENERATOR_curve_outTangent_" + i.ToString(),
                _curve.keys[i].outTangent);
            EditorPrefs.SetFloat(
                "TOOL_GRADIENTGENERATOR_curve_outWeight_" + i.ToString(),
                _curve.keys[i].outWeight);
            EditorPrefs.SetFloat(
                "TOOL_GRADIENTGENERATOR_curve_value_" + i.ToString(),
                _curve.keys[i].value);
            EditorPrefs.SetFloat(
                "TOOL_GRADIENTGENERATOR_curve_time_" + i.ToString(),
                _curve.keys[i].time);
            EditorPrefs.SetInt(
                "TOOL_GRADIENTGENERATOR_curve_mode_" + i.ToString(),
                (int)_curve.keys[i].weightedMode);
        }
     }

     private void OnGUI () {
        GUILayout.Space(16);
        _gradient = EditorGUILayout.GradientField(
            "Gradient", _gradient);
        GUILayout.Space(8);
        _curve = EditorGUILayout.CurveField(
            "Curve", _curve);

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

        GUILayout.Space(32);
        if (GUILayout.Button("Save from Gradient")) {
            Texture2D tex = new Texture2D(
                _resolution.x, _resolution.y, TextureFormat.ARGB32, false);
            for (int i = 0; i < _resolution.x; i++) {
                Color value = _gradient.Evaluate(i / (float)_resolution.x);
                for (int j = 0; j < _resolution.y; j++) {
                    tex.SetPixel(i, j, value);
                }
            }
            byte[] data = tex.EncodeToPNG();
            Object.DestroyImmediate(tex);
            File.WriteAllBytes(
                string.Format("{0}/{1}", Application.dataPath, _path), data);
            AssetDatabase.Refresh(ImportAssetOptions.ForceUpdate);
        }

        GUILayout.Space(8);
        if (GUILayout.Button("Save from Curve")) {
            Texture2D tex = new Texture2D(
                _resolution.x, _resolution.y, TextureFormat.ARGB32, false);
            for (int i = 0; i < _resolution.x; i++) {
                float value = _curve.Evaluate(i / (float)_resolution.x);
                value = Mathf.Clamp01(value);
                for (int j = 0; j < _resolution.y; j++) {
                    tex.SetPixel(i, j, new Color(value, value, value, 1f));
                }
            }
            byte[] data = tex.EncodeToPNG();
            Object.DestroyImmediate(tex);
            File.WriteAllBytes(
                string.Format("{0}/{1}", Application.dataPath, _path), data);
            AssetDatabase.Refresh(ImportAssetOptions.ForceUpdate);
        }
     }
}
