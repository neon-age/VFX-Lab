using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class EnableDepthTexture : MonoBehaviour
{
    new Camera camera;

    void OnEnable()
    {
        camera = GetComponent<Camera>();
        camera.depthTextureMode |= DepthTextureMode.Depth;
    }

    void OnDisable()
    {
        camera.depthTextureMode ^= DepthTextureMode.Depth;
    }
}
