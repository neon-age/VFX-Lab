using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace AV.Rendering
{
    public class ShaderGlobals : MonoBehaviour
    {
        [Serializable]
        public class Property<T>
        {
            public string name;
            public T value;
        }
        //public class Float : Property<float> {}
        //public class Int : Property<int> {}
        //public class Color : Property<Color> {}

        public Property<float>[] floats;
        public Property<Color>[] colors;
        public Property<Vector4>[] vectors;
        public Property<Texture>[] textures;

        void OnEnable() => OnValidate();

        void OnValidate()
        {
            foreach (var p in floats) Shader.SetGlobalFloat(p.name, p.value);
            foreach (var p in colors) Shader.SetGlobalColor(p.name, p.value);
            foreach (var p in vectors) Shader.SetGlobalVector(p.name, p.value);
            foreach (var p in textures) Shader.SetGlobalTexture(p.name, p.value);
        }
    }
}