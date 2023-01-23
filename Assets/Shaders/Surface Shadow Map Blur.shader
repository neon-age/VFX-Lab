Shader "Surface/Shadow Map Blur"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _BumpMap ("Normal Map", 2D) = "bump" {}
        _Cutoff ("_Cutoff", Float) = 0.5
        _BumpScale ("Normal Scale", Float) = 1
        _Scale ("Scale", Float) = 0.5
        _Glossiness ("Smoothness", Float) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf  StandardTranslucent fullforwardshadows vertex:vert addshadow
        #pragma noshadowmask nodirlightmap nolightmap 
        #pragma noforwardadd nofog nolppv nometa 
        #pragma exclude_path:deferred 
        #include "UnityPBSLighting.cginc"
        //#include "UnityShadowLibrary.cginc"
        #pragma target 4.0

        sampler2D _MainTex;

        struct Input
        {
            float2 uv_MainTex;
            float3 localPos;
            float3 worldPos;
            float4 screenPos;
        };

        half _Cutoff;
        half _Glossiness;
        half _Metallic;
        half _LightWrap;
        fixed4 _Color;

        UNITY_INSTANCING_BUFFER_START(Props)/*
        UNITY_DEFINE_INSTANCED_PROP (half, _Glossiness)
        UNITY_DEFINE_INSTANCED_PROP (half, _Metallic)
        UNITY_DEFINE_INSTANCED_PROP (fixed4, _Color)*/
        UNITY_INSTANCING_BUFFER_END(Props)

        float camDist;

        half2 screenUV;
        float3 fragWorldPos;
        float3 fragLocalPos;
        sampler2D _ShadowMapCopy;
        sampler2D _MainLightShadowmap;
        sampler2D _CameraDepthTexture;

        sampler2D _SpiralBlurNoiseTex;
		float4 _SpiralBlurNoiseTex_TexelSize;
		float _SpiralBlurRadius;
        float _SpiralBlurDepthFactor;
        float _BlurDepthOffset;


        half4 ApplySpiralBlur(
		    sampler2D tex, sampler2D noiseTex, float2 uv, float2 noiseUV, float2 screenSize,
		    int samples, float pixelRadius, float noiseSize, float noiseBias)
		{
		    //const float GOLDEN_ANGLE = 2.3999632297286533222315555066336;
		    //const float TAU = 6.283185307179586476925286766559;

            //float centerDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv));

		    float noise = tex2D(noiseTex, noiseUV).x * noiseBias * 6.283185307179586476925286766559;

		    float ar = screenSize.x / screenSize.y;
		    half4 accum = 0;

		    for (int i = 1; i <= samples; ++i) 
		    {
		        float r = float(i) / float(samples);
		        r = sqrt(r);
		        r *= pixelRadius;
		        float a = float(i) * 2.3999632297286533222315555066336 + noise;
		        float2 p = float2(r * cos(a), ar * r * sin(a));
		       
                half4 c = tex2D(tex, uv + p);
                
                //float sampleDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv + p));
                //float depthDiff = (centerDepth - sampleDepth);

				accum += c;

		    }
			return accum / float(samples);
		}

        // https://forum.unity.com/threads/find-worldpos-from-light-depth-texture.869572/#post-5738488
        /*
        float3 worldPosToLight0Space(float3 worldPos)
        {
            float distCameraToWorldPos = distance(_WorldSpaceCameraPos, worldPos);
         
            float4 near = float4(distCameraToWorldPos >= _LightSplitsNear);
            float4 far = float4(distCameraToWorldPos < _LightSplitsFar);
            float4 weights = near * far;
         
            float4 worldPos4 = float4(worldPos, 1.);
            float3 shadowCoord0 = mul(unity_WorldToShadow[0], worldPos4).xyz;
            float3 shadowCoord1 = mul(unity_WorldToShadow[1], worldPos4).xyz;
            float3 shadowCoord2 = mul(unity_WorldToShadow[2], worldPos4).xyz;
            float3 shadowCoord3 = mul(unity_WorldToShadow[3], worldPos4).xyz;
            float3 fragCoordLightSpace =
                 shadowCoord0 * weights.x + // case: Cascaded one
                 shadowCoord1 * weights.y + // case: Cascaded two
                 shadowCoord2 * weights.z + // case: Cascaded three
                 shadowCoord3 * weights.w; // case: Cascaded four
         
            return fragCoordLightSpace;
         
        }*/
        
        float3 worldPosToLight0Space(float3 worldPos)
        {
            float4 worldPos4 = float4(worldPos, 1.);
            float3 shadowCoord0 = mul(unity_WorldToShadow[0], worldPos4).xyz;
            return shadowCoord0;
        }
        // same but doesnt work
        /*
        float3 distFragmentShadow(float3 fragWorldPos)
        {
            float3 fragCoordLightSpace = worldPosToLight0Space(fragWorldPos);
            float3 fragCoordLightSpaceLight = worldPosToLight0Space(fragWorldPos - _WorldSpaceLightPos0 * 100.);
         
            float shadowSample = tex2D(_MainLightShadowmap, fragCoordLightSpace.xy).r;
         
            float distFragToShadow = abs(shadowSample - fragCoordLightSpace.z);
            float distFragToLight = abs(fragCoordLightSpace.z - fragCoordLightSpaceLight.z);
         
            float fract = distFragToShadow / distFragToLight * 100.;
         
            return fragWorldPos - _WorldSpaceLightPos0 * fract;
        }*/
        
        inline half4 LightingStandardTranslucent(SurfaceOutputStandard s, fixed3 viewDir, UnityGI gi)
        {
            half4 pbr = LightingStandard(s, viewDir, gi);
            
            float3 L = gi.light.dir;
            float3 V = viewDir;
            float3 N = s.Normal;
            float atten = gi.light.color;
            
            half NdotL = saturate(dot(N, L));
            half lightAtten = (NdotL * _LightWrap + (1 - _LightWrap));

            half luma = dot(pbr.rgb, half3(0.299,0.587,0.114));

            //return half4(gi.light.color, 1);
            return half4(pbr.rgb + (gi.light.color * _LightColor0 * pbr.rgb * lightAtten), pbr.a);
        }

        float _SpiralBlurNoiseBias;
        float _SpiralBlurNoiseSize;
        int _SpiralBlurSamples;
        float _ShadowBlurMipBias;

        inline UnityGI CustomGI_Base(UnityGIInput data, half occlusion, half3 normalWorld)
        {
            UnityGI o_gi;
            ResetUnityGI(o_gi);

            // Base pass with Lightmap support is responsible for handling ShadowMask / blending here for performance reason
            #if defined(HANDLE_SHADOWS_BLENDING_IN_GI)
                half bakedAtten = UnitySampleBakedOcclusion(data.lightmapUV.xy, data.worldPos);
                float zDist = dot(_WorldSpaceCameraPos - data.worldPos, UNITY_MATRIX_V[2].xyz);
                float fadeDist = UnityComputeShadowFadeDistance(data.worldPos, zDist);
                data.atten = UnityMixRealtimeAndBakedShadows(data.atten, bakedAtten, UnityComputeShadowFade(fadeDist));
            #endif

            o_gi.light = data.light;
            o_gi.light.color *= data.atten;

            float3 fragCoordLightSpace = worldPosToLight0Space(fragWorldPos);
            float3 lightLocalSpace = worldPosToLight0Space(fragWorldPos + _WorldSpaceCameraPos);
            //float3 lightLocalSpace = mul(data.light.dir, float4(fragWorldPos, 1));

            half4 shadowSample = tex2Dlod(_MainLightShadowmap, half4(fragCoordLightSpace.xy, 0, _ShadowBlurMipBias));

            half2 noiseUV = screenUV * _SpiralBlurNoiseTex_TexelSize * 1000;

            //noiseUV = screenUV;
            noiseUV *= _SpiralBlurNoiseSize;
            //shadowSample = ApplySpiralBlur(_MainLightShadowmap, _SpiralBlurNoiseTex, fragCoordLightSpace.xy, noiseUV, _ScreenParams, 
			//	4, _SpiralBlurDepthFactor / 1000, 2000, _SpiralBlurNoiseBias);
 
            float depth = shadowSample - fragCoordLightSpace.z;
            //depth = shadowSample - fragCoordLightSpace.z;
            //depth = lerp(0, 1, depth );

            float distCameraToWorldPos = distance(_WorldSpaceCameraPos, fragWorldPos);

            half pixelRadius = _SpiralBlurRadius;

            pixelRadius /= distCameraToWorldPos;
            //pixelRadius = lerp(pixelRadius, pixelRadius * depth,  _BlurDepthOffset);
            pixelRadius =  pixelRadius * (depth * _BlurDepthOffset);


            o_gi.light.color = ApplySpiralBlur(_ShadowMapCopy, _SpiralBlurNoiseTex, screenUV, noiseUV, _ScreenParams, 
				_SpiralBlurSamples, pixelRadius, 2000, _SpiralBlurNoiseBias) ;

            //o_gi.light.color = depth;
           

            #if UNITY_SHOULD_SAMPLE_SH
                o_gi.indirect.diffuse = ShadeSHPerPixel(normalWorld, data.ambient, data.worldPos);
            #endif

            #ifdef DYNAMICLIGHTMAP_ON
                // Dynamic lightmaps
                fixed4 realtimeColorTex = UNITY_SAMPLE_TEX2D(unity_DynamicLightmap, data.lightmapUV.zw);
                half3 realtimeColor = DecodeRealtimeLightmap (realtimeColorTex);

                #ifdef DIRLIGHTMAP_COMBINED
                    half4 realtimeDirTex = UNITY_SAMPLE_TEX2D_SAMPLER(unity_DynamicDirectionality, unity_DynamicLightmap, data.lightmapUV.zw);
                    o_gi.indirect.diffuse += DecodeDirectionalLightmap (realtimeColor, realtimeDirTex, normalWorld);
                #else
                    o_gi.indirect.diffuse += realtimeColor;
                #endif
            #endif

            o_gi.indirect.diffuse *= occlusion;
            return o_gi;
        }
        inline void LightingStandardTranslucent_GI(SurfaceOutputStandard s, UnityGIInput data, inout UnityGI gi)
        {
            gi = CustomGI_Base(data, s.Occlusion, s.Normal);
        }

        void vert (inout appdata_full v, out Input o) 
        {
            UNITY_INITIALIZE_OUTPUT(Input,o);
            o.screenPos = ComputeScreenPos(v.vertex);
        }

        float _BumpScale;
        sampler2D _BumpMap;

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;

            if (c.a < _Cutoff)
                discard;

            camDist = distance(IN.localPos, _WorldSpaceCameraPos);
            half worldCamDist = distance(IN.worldPos, _WorldSpaceCameraPos);

            fragWorldPos = IN.worldPos;
            fragLocalPos = IN.localPos;

            screenUV = IN.screenPos.xy / IN.screenPos.w;
            
            o.Normal = UnpackScaleNormal (tex2D (_BumpMap, IN.uv_MainTex), _BumpScale);

            o.Albedo = c.rgb;
            o.Metallic = _Metallic;
            o.Smoothness = c * _Glossiness;
            o.Alpha = c.a;
        }
        ENDCG
    }
    Fallback "Diffuse"
}
