using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[ExecuteAlways]
[ExecuteInEditMode]
public class AutoLoadPipelineAsset : MonoBehaviour
{
    public UniversalRenderPipelineAsset pipelineAsset;
    RenderPipelineAsset prevAsset;
    
    void OnEnable(){ 
        UpdatePipeline();
    }
    void OnDisable(){
        if (prevAsset){
            GraphicsSettings.renderPipelineAsset = prevAsset;
            prevAsset = null;
        }
    }
    void OnValidate() => UpdatePipeline();

    void UpdatePipeline()
    {
        if (!prevAsset)
            prevAsset = GraphicsSettings.renderPipelineAsset;
        GraphicsSettings.renderPipelineAsset = pipelineAsset;
    }
}
