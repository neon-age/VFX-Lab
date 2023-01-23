using UnityEngine;
using UnityEngine.Rendering;
using System.Collections.Generic;

[ExecuteInEditMode]
public class LightCopyShadowMapBuffers : MonoBehaviour
{
    CommandBuffer shadowBuffer;
    CommandBuffer depthBuffer;

    new Light light;

    void Cleanup()
    {
        if (shadowBuffer != null) light.RemoveCommandBuffer(LightEvent.AfterScreenspaceMask, shadowBuffer);
        if (depthBuffer != null) light.RemoveCommandBuffer(LightEvent.AfterShadowMapPass, depthBuffer);
        shadowBuffer = null;
        depthBuffer = null;
    }

    void OnValidate()
    {
        Setup();
    }
    void OnEnable()
    {
        Setup();
    }

    void OnDisable()
    {
        Cleanup();
    }
    

    void Setup()
    {
        Cleanup();

        light = GetComponent<Light>();
        
        if (depthBuffer == null)
        {
            depthBuffer = new CommandBuffer();
            depthBuffer.name = "Copy light depth buffer";

            int copyId = Shader.PropertyToID("_MainLightShadowmap");
           

            var currTex = Shader.GetGlobalTexture("_ShadowMapTexture");
            var desc = new RenderTextureDescriptor(currTex.width, currTex.height, RenderTextureFormat.RGFloat, 0, 9);
            desc.useMipMap = true;
            desc.autoGenerateMips = true;

            //(currTex as RenderTexture).autoGenerateMips = true;
            //desc.useMipMap = true;
            //desc.autoGenerateMips = true;

            //depthBuffer.GetTemporaryRT(copyId, currTex.width, currTex.height, 0, FilterMode.Bilinear, RenderTextureFormat.RGFloat);
            depthBuffer.GetTemporaryRT(copyId, desc, FilterMode.Bilinear);
            //depthBuffer.SetGlobalTexture(copyId, copyId);
            //var copyTex = Shader.GetGlobalTexture("_MainLightShadowmap");
            //(copyTex as RenderTexture).autoGenerateMips = true;


            depthBuffer.SetShadowSamplingMode(BuiltinRenderTextureType.CurrentActive, ShadowSamplingMode.RawDepth);
            //depthBuffer.Blit(BuiltinRenderTextureType.CurrentActive, copyId);
            depthBuffer.Blit(BuiltinRenderTextureType.CurrentActive, copyId);
            //depthBuffer.SetGlobalTexture(copyId, BuiltinRenderTextureType.CurrentActive);

            light.AddCommandBuffer(LightEvent.AfterShadowMapPass, depthBuffer);
        }

        if (shadowBuffer == null)
        {
            shadowBuffer = new CommandBuffer();
            shadowBuffer.name = "Copy screenspace shadowmap";
            
            int copyId = Shader.PropertyToID("_ShadowMapCopy");
            shadowBuffer.GetTemporaryRT(copyId, -1, -1, 0, FilterMode.Bilinear);
            shadowBuffer.Blit(BuiltinRenderTextureType.CurrentActive, copyId);
            shadowBuffer.SetGlobalTexture(copyId, copyId);

            light.AddCommandBuffer(LightEvent.AfterScreenspaceMask, shadowBuffer);
        }
    }
}