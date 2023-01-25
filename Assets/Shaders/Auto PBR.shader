
Shader "Surface/Auto-PBR"
{
    Properties
    {
        [HDR] _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo Grayscale", 2D) = "white" {}
        _BumpMap ("Bump Map", 2D) = "bump" {}
        _ColorRamp ("Color Ramp", 2D) = "white" {}

        [Enum(Off, 0, Low (1 Direction), 1, Medium (2 Directions), 2, High (4 Directions), 3)] 
        _BumpFromAlbedoQuality ("Albedo Bump Quality", Float) = 0
        _BumpFromAlbedoDirection ("Albedo Bump Direction", Float) = 1
        _BumpFromAlbedoParams ("Albedo Bump (Scale, Detail Scale, Offset, Mip Bias)", Vector) = (0, 0, 0, 0)

        [Toggle] _UseNormalMap ("Use Normal Map", Float) = 0
        _BumpScale ("Normal Map Scale", Float) = 1

        _Cutoff ("_Cutoff", Range(0, 1)) = 0.5
        _LightWrap ("_LightWrap", Float) = 0.5
        _Glossiness ("Smoothness", Float) = 0.5
        _GlossinessLimit ("_GlossinessLimit", Range(0, 1)) = 1
        _Metallic ("Metallic", Range(0,1)) = 0.0
        _Occlusion ("Occlusion", Float) = 1
        _Parallax ("Parallax", Float) = 1
        _ParallaxParams ("Parallax Adjust (Multiply, Offset, Mip Bias)", Float) = (1, 0, 0, 0)
        _ParallaxEdgeDiscard ("_ParallaxEdgeDiscard", Range(0, 1)) = 0
        
        _ParallaxSamples ("Parallax Samples Factor", Float) = 0.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200
        //Cull Off

        CGPROGRAM
        #pragma surface surf CustomStandard vertex:vert fullforwardshadows alphatest:_Cutoff
        #include "UnityPBSLighting.cginc"
        #include "AutoLight.cginc"

        #pragma target 3.0

        sampler2D _MainTex;
        sampler2D _BumpMap;
        sampler2D _ColorRamp;
        struct Input
        {
            float2 uv_MainTex;
            float2 uv_SplatMap;
            float4 parallaxEye; // xyz - tangent view dir, w - sample ratio
            float4 color : COLOR; 
        };

        #define _AlbedoBumpOffset _BumpFromAlbedoParams.z
        #define _AlbedoBumpMipBias _BumpFromAlbedoParams.w
        #define _AlbedoBumpScale _BumpFromAlbedoParams.x
        #define _AlbedoBumpDetailScale _BumpFromAlbedoParams.y

        half4 _BumpFromAlbedoParams;
        half _BumpFromAlbedoDirection;
       // half _Cutoff;
        half _Glossiness;
        half _GlossinessLimit;
        half _Metallic;
        half _BumpScale;
        int _BumpFromAlbedoQuality;
        int _UseNormalMap;
        half _Occlusion;
        half _Parallax;
        half _LightWrap;
        half _ParallaxEdgeDiscard;
        half4 _ParallaxParams;
        int _ParallaxSamples;
        fixed4 _Color;

        
        float invLerp(float from, float to, float value){
          return (value - from) / (to - from);
        }

        // https://github.com/TwoTailsGames/Unity-Built-in-Shaders/blob/master/CGIncludes/UnityStandardBRDF.cginc
        half4 BRDF_Unity_PBS (half3 diffColor, half3 specColor, half oneMinusReflectivity, half smoothness,
            float3 normal, float3 viewDir,
            UnityLight light, UnityIndirect gi)
        {
            /*
            float3 reflDir = reflect (viewDir, normal);
        
            half nl = saturate(dot(normal, light.dir));
            half nv = saturate(dot(normal, viewDir));
            half lightAtten = (nl * _LightWrap + (1 - _LightWrap));
        
            // Vectorize Pow4 to save instructions
            half2 rlPow4AndFresnelTerm = Pow4 (float2(dot(reflDir, light.dir), 1-nv));  // use R.L instead of N.H to save couple of instructions
            half rlPow4 = rlPow4AndFresnelTerm.x; // power exponent must match kHorizontalWarpExp in NHxRoughness() function in GeneratedTextures.cpp
            half fresnelTerm = rlPow4AndFresnelTerm.y;
        
            half grazingTerm = saturate(smoothness + (1-oneMinusReflectivity));
        
            half3 color = BRDF3_Direct(diffColor, specColor, rlPow4, smoothness);
            color *= light.color * lightAtten;
            color += BRDF3_Indirect(diffColor, specColor, gi, grazingTerm, fresnelTerm);
        
            return half4(color, 1);*/
            float perceptualRoughness = SmoothnessToPerceptualRoughness (smoothness);
            float3 halfDir = Unity_SafeNormalize (float3(light.dir) + viewDir);
        
        // NdotV should not be negative for visible pixels, but it can happen due to perspective projection and normal mapping
        // In this case normal should be modified to become valid (i.e facing camera) and not cause weird artifacts.
        // but this operation adds few ALU and users may not want it. Alternative is to simply take the abs of NdotV (less correct but works too).
        // Following define allow to control this. Set it to 0 if ALU is critical on your platform.
        // This correction is interesting for GGX with SmithJoint visibility function because artifacts are more visible in this case due to highlight edge of rough surface
        // Edit: Disable this code by default for now as it is not compatible with two sided lighting used in SpeedTree.
        #define UNITY_HANDLE_CORRECTLY_NEGATIVE_NDOTV 0
        
        #if UNITY_HANDLE_CORRECTLY_NEGATIVE_NDOTV
            // The amount we shift the normal toward the view vector is defined by the dot product.
            half shiftAmount = dot(normal, viewDir);
            normal = shiftAmount < 0.0f ? normal + viewDir * (-shiftAmount + 1e-5f) : normal;
            // A re-normalization should be applied here but as the shift is small we don't do it to save ALU.
            //normal = normalize(normal);
        
            float nv = saturate(dot(normal, viewDir)); // TODO: this saturate should no be necessary here
        #else
            half nv = abs(dot(normal, viewDir));    // This abs allow to limit artifact
        #endif
        
            float nl = saturate(dot(normal, light.dir));
            float nh = saturate(dot(normal, halfDir));
            nl = (nl * _LightWrap + (1 - _LightWrap));
        
            half lv = saturate(dot(light.dir, viewDir));
            half lh = saturate(dot(light.dir, halfDir));
        
            // Diffuse term
            half diffuseTerm = DisneyDiffuse(nv, nl, lh, perceptualRoughness) * nl;
        
            // Specular term
            // HACK: theoretically we should divide diffuseTerm by Pi and not multiply specularTerm!
            // BUT 1) that will make shader look significantly darker than Legacy ones
            // and 2) on engine side "Non-important" lights have to be divided by Pi too in cases when they are injected into ambient SH
            float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
        #if UNITY_BRDF_GGX
            // GGX with roughtness to 0 would mean no specular at all, using max(roughness, 0.002) here to match HDrenderloop roughtness remapping.
            roughness = max(roughness, 0.002);
            float V = SmithJointGGXVisibilityTerm (nl, nv, roughness);
            float D = GGXTerm (nh, roughness);
        #else
            // Legacy
            half V = SmithBeckmannVisibilityTerm (nl, nv, roughness);
            half D = NDFBlinnPhongNormalizedTerm (nh, PerceptualRoughnessToSpecPower(perceptualRoughness));
        #endif
        
            float specularTerm = V*D * UNITY_PI; // Torrance-Sparrow model, Fresnel is applied later
        
        #   ifdef UNITY_COLORSPACE_GAMMA
                specularTerm = sqrt(max(1e-4h, specularTerm));
        #   endif
        
            // specularTerm * nl can be NaN on Metal in some cases, use max() to make sure it's a sane value
            specularTerm = max(0, specularTerm * nl);
        #if defined(_SPECULARHIGHLIGHTS_OFF)
            specularTerm = 0.0;
        #endif
        
            // surfaceReduction = Int D(NdotH) * NdotH * Id(NdotL>0) dH = 1/(roughness^2+1)
            half surfaceReduction;
        #   ifdef UNITY_COLORSPACE_GAMMA
                surfaceReduction = 1.0-0.28*roughness*perceptualRoughness;      // 1-0.28*x^3 as approximation for (1/(x^4+1))^(1/2.2) on the domain [0;1]
        #   else
                surfaceReduction = 1.0 / (roughness*roughness + 1.0);           // fade \in [0.5;1]
        #   endif
        
            // To provide true Lambert lighting, we need to be able to kill specular completely.
            specularTerm *= any(specColor) ? 1.0 : 0.0;
        
            half grazingTerm = saturate(smoothness + (1-oneMinusReflectivity));
            half3 color =   diffColor * (gi.diffuse + light.color * diffuseTerm)
                            + specularTerm * light.color * FresnelTerm (specColor, lh)
                            + surfaceReduction * gi.specular * FresnelLerp (specColor, grazingTerm, nv);
        
            return half4(color, 1);
        }

        inline half4 LightingCustomStandard(SurfaceOutputStandard s, half3 viewDir, UnityGI gi)
        {
            //return LightingStandard(s, viewDir, gi);
            
            // https://github.com/TwoTailsGames/Unity-Built-in-Shaders/blob/master/CGIncludes/UnityPBSLighting.cginc
            s.Normal = normalize(s.Normal);

            half oneMinusReflectivity;
            half3 specColor;
            s.Albedo = DiffuseAndSpecularFromMetallic (s.Albedo, s.Metallic, specColor, oneMinusReflectivity);

            // shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)
            // this is necessary to handle transparency in physically correct way - only diffuse component gets affected by alpha
            half outputAlpha;
            s.Albedo = PreMultiplyAlpha (s.Albedo, s.Alpha, oneMinusReflectivity, outputAlpha);

            half4 c = BRDF_Unity_PBS (s.Albedo, specColor, oneMinusReflectivity, s.Smoothness, s.Normal, viewDir, gi.light, gi.indirect);
            c.a = s.Alpha;
            return half4(c.rgb, 0);
        }
        inline void LightingCustomStandard_GI(SurfaceOutputStandard s, UnityGIInput data, inout UnityGI gi)
        {
             LightingStandard_GI(s, data, gi);
             /*
            half occlusion = s.Occlusion;
            half normalWorld = s.Normal;
            UnityGI o_gi;
            ResetUnityGI(o_gi);

            #if defined(HANDLE_SHADOWS_BLENDING_IN_GI)
                half bakedAtten = UnitySampleBakedOcclusion(data.lightmapUV.xy, data.worldPos);
                float zDist = dot(_WorldSpaceCameraPos - data.worldPos, UNITY_MATRIX_V[2].xyz);
                float fadeDist = UnityComputeShadowFadeDistance(data.worldPos, zDist);
                data.atten = UnityMixRealtimeAndBakedShadows(data.atten, bakedAtten, UnityComputeShadowFade(fadeDist));
            #endif

            o_gi.light = data.light;
            o_gi.light.color *= data.atten;

            #if UNITY_SHOULD_SAMPLE_SH
                o_gi.indirect.diffuse = ShadeSHPerPixel(normalWorld, data.ambient, data.worldPos);
            #endif

            #ifdef DYNAMICLIGHTMAP_ON
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
            gi = o_gi;*/
        }

        half4 currSplatmap;

        half BlendChannels(half4 c, half4 splat)
        {
            half r = c.a;
            r = lerp(r, c.r, splat.r);
            r = lerp(r, c.g, splat.g);
            r = lerp(r, c.b, splat.b);
            return r;
        }

        float GetPOMHeight(float2 texcoord)
        {
            half4 params = _ParallaxParams;
            half mipBias = params.z;

            half4 lod = tex2Dlod(_MainTex, float4(texcoord, mipBias, mipBias));
            half c = BlendChannels(lod, currSplatmap);

            half invert = lerp(1 - c, c, normalize(_Parallax) / 2 + 0.5);

            half h = clamp(invert * abs(params.x) + abs(params.y), 0, 0.999);
            return abs(h);
            //return c * params.x + params.y;
        }

        #include<POM.cginc>

		void vert(inout appdata_full v, out Input OUT)
		{
            UNITY_INITIALIZE_OUTPUT(Input, OUT);
            float3 eye;
            float sampleRatio;

            // https://github.com/candycat1992/Unity_Shaders_Book/blob/master/Assets/Shaders/Chapter7/Chapter7-NormalMapTangentSpace.shader
            // Construct a matrix that transforms a point/vector from tangent space to world space
			fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);  
			fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);  
			fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w; 

			//wToT = the inverse of tToW = the transpose of tToW as long as tToW is an orthogonal matrix.
			float3x3 worldToTangent = float3x3(worldTangent, worldBinormal, worldNormal);

			// Transform the light and view dir from world space to tangent space
			//o.lightDir = mul(worldToTangent, WorldSpaceLightDir(v.vertex));
			OUT.parallaxEye = float4(mul(worldToTangent, WorldSpaceViewDir(v.vertex)), 1);
		}

        float luminance(float3 c)
        {
        	return dot(c, float3(0.2126, 0.7152, 0.0722));
        }

        float4 ColorMask(float3 In, float3 MaskColor, float Range, float Fuzziness)
        {
            float Distance = distance(MaskColor, In);
            return saturate(1 - (Distance - Range) / max(Fuzziness, 1e-5));
        }

        //float blend(float a1, float a2)
        //{
        //    return a1 > a2 ? a1 : a2;
        //}
        //float blend(float texture1, float a1, float texture2, float a2)
        //{
        //    return texture1 + a1 > texture2 + a2 ? texture1 : texture2;
        //}
        float blend(float texture1, float a1, float texture2, float a2)
        {
            //float depth = _SplatBlend;
            float depth = 0.2;
            float ma = max(texture1 + a1, texture2 + a2) - depth;

            float b1 = max(texture1 + a1 - ma, 0);
            float b2 = max(texture2 + a2 - ma, 0);

            return (texture1 * b1 + texture2 * b2) / (b1 + b2);
        }

        float RotateUV(float2 UV, float Rotation)
        {
            //UV -= Center;
            float s = sin(Rotation);
            float c = cos(Rotation);
            float2x2 rMatrix = float2x2(c, -s, s, c);
            rMatrix *= 0.5;
            rMatrix += 0.5;
            rMatrix = rMatrix * 2 - 1;
            UV.xy = mul(UV.xy, rMatrix);
            //UV += Center;
            return UV;
        }

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            float2 uv = IN.uv_MainTex;
            //half4 splatmap = tex2D(_SplatMap, IN.uv_SplatMap);
            //splatmap = IN.color;
            //currSplatmap = splatmap;
            currSplatmap = 1;

            float2 offset = 0;
            half sampledHeight = 0;
            if (_Parallax != 0)
            {
                offset = parallax_offset (abs(_Parallax) / 100, IN.parallaxEye.xyz, IN.parallaxEye.w, uv, 
			        _MainTex, 1, _ParallaxSamples, sampledHeight);

                half flip = normalize(_Parallax) / 2 + 0.5;

                float2 discardUV = abs(offset);

                if(_ParallaxEdgeDiscard > 0 && (abs(discardUV.x) > (1 - _ParallaxEdgeDiscard) || abs(discardUV.y) > (1 - _ParallaxEdgeDiscard)) ) 
				    discard;

                //sampledHeight = lerp(1 - sampledHeight, sampledHeight, flip);
            }

            uv += offset;
            half4 c = tex2D (_MainTex, uv);

/*
            half4 normalPacked = tex2D (_NormalMapPacked, uv);
             
            half2 nmUnpacked = normalPacked.xy;
             nmUnpacked = Unpack3FloatsFrom8Bit(normalPacked.r);

            half nx = nmUnpacked.x * 2 - 1;
            half ny = nmUnpacked.y * 2 - 1;
            
            half nz = sqrt(1 - saturate(dot(nx, ny )) );
*/
            half normalOffset = _AlbedoBumpOffset / 100 * _BumpFromAlbedoDirection;

            half albedoBumpScale = _AlbedoBumpScale * _BumpFromAlbedoDirection;

            half mipBias = _AlbedoBumpMipBias;

            //float2 uv_dx = clamp(ddx(uv), mipBias, mipBias );
			//float2 uv_dy = clamp(ddy(uv), -mipBias, -mipBias );

            half2 nxy = 0;
            if (_BumpFromAlbedoQuality == 1)
            {
                half4 lT = tex2Dlod(_MainTex, half4(uv - RotateUV(half2(0, -normalOffset), 1), mipBias, mipBias));

                half l = lT.r;

                nxy += (c.r - l) * _AlbedoBumpDetailScale;
                half nz = sqrt(1 - saturate(dot(nxy.x, nxy.y)));

                o.Normal = float3(nxy * albedoBumpScale,  nz);
            }
            else if (_BumpFromAlbedoQuality == 2)
            {
                half4 rT = tex2Dlod(_MainTex, half4(uv - half2(-normalOffset, 0), mipBias, mipBias));
                half4 dT = tex2Dlod(_MainTex, half4(uv - half2(0, -normalOffset), mipBias, mipBias));

                half r = rT.r;
                half d = dT.r;

                nxy = half2(c.r-r, c.r-d);
                half nz = sqrt(1 - saturate(dot(nxy.x, nxy.y)));
                nxy += (c.r - half2(r, d)) * _AlbedoBumpDetailScale;

              
                o.Normal = float3(nxy * albedoBumpScale,  nz);
            }
            else if (_BumpFromAlbedoQuality == 3)
            {
                half4 lT = tex2Dlod(_MainTex, half4(uv - half2(normalOffset, 0), mipBias, mipBias));
                half4 rT = tex2Dlod(_MainTex, half4(uv - half2(-normalOffset, 0), mipBias, mipBias));
                half4 uT = tex2Dlod(_MainTex, half4(uv - half2(0, normalOffset), mipBias, mipBias));
                half4 dT = tex2Dlod(_MainTex, half4(uv - half2(0, -normalOffset), mipBias, mipBias)); // * 2 - 1

                //half l = BlendChannels(lT, splatmap);
                //half r = BlendChannels(rT, splatmap);
                //half u = BlendChannels(uT, splatmap);
                //half d = BlendChannels(dT, splatmap);

                half l = lT.r;
                half r = rT.r;
                half u = uT.r;
                half d = dT.r;
                
                nxy = half2(l-r, u-d);
                half nz = sqrt(1 - saturate(dot(nxy.x, nxy.y)));
                //nxy = c.r - lerp(half2(l, u), half2(r, d), normalize(_AlbedoBumpDetail) / 2 + 0.5);
                //nxy += c.r - lerp(half2(l, r), half2(r, l), normalize(_AlbedoBumpDetail) / 2 + 0.5);
                //nxy += c.r - lerp(half2(d, u), half2(u, d), normalize(_AlbedoBumpDetail) / 2 + 0.5);
                //nxy += c.r - lerp(half2(d, u), half2(r, l), normalize(_AlbedoBumpDetail) / 2 + 0.5);
                //nxy += (c.r - half2(r, u)) * -1 - (c.r - half2(r, u));
                //half sign = normalize(_AlbedoBumpDetailScale == 0 ? 0.0001 : _AlbedoBumpDetailScale);
                half sign = _AlbedoBumpDetailScale > 0 ? 1 : 0;

                nxy += (c.r - lerp(half2(l, u), half2(r, d), sign) ) * _AlbedoBumpDetailScale;
                //  nxy += (c.r - lerp(half2(l, u), half2(r, d), sign / 2 + 0.5)) * _AlbedoBumpDetailScale;
               
                o.Normal = float3(nxy * albedoBumpScale,  nz);
            }
            

            //float dx = (c - d1) / delta;
	        //float dy = (c - d2) / delta;
            //
	        //normals = normalize(vec3(dx, dy, 1.0 - c));
            //nx = nxy.x;
            //ny = nxy.y;

            //half nx = luminance(tex2Dbias(_MainTex, half4(uv - half2(normalOffset, -normalOffset), mipBias, mipBias)).r * 2 - 1);
            //half ny = luminance(tex2Dbias(_MainTex, half4(uv - half2(-normalOffset, normalOffset), mipBias, mipBias)).r * 2 - 1);

            
            //o.Normal = float3((nxy.x) * _BumpScale, (nxy.y) * _BumpScale,  nz);
            
            if (_UseNormalMap == 1)
            {
                /*
                half2 nmUnpacked = tex2D(_BumpMap, uv).wy;

                half nx = nmUnpacked.x * 2 - 1;
                half ny = nmUnpacked.y * 2 - 1;
                half nz = sqrt(1 - saturate(dot(nx, ny )));

                o.Normal += float3(nx * _BumpScale / 2, ny * _BumpScale / 2, nz);*/
                o.Normal += UnpackNormalWithScale(tex2D(_BumpMap, uv), _BumpScale);
            }
            
            //half splatA = ColorMask(splatmap, half3(0, 0, 0), 0.01, 0.5);
            /*
            half albedo = 0;
            //albedo = lerp(albedo, c.a, splatmap.a); 
            albedo +=  c.a;
            albedo = lerp(albedo, c.r, smoothstep(saturate(0 + _SplatBlend.x), saturate(c.r + _SplatBlend.y), splatmap.r - _SplatBlend.z));
            albedo = lerp(albedo, c.g, smoothstep(saturate(0 + _SplatBlend.x), saturate(c.g + _SplatBlend.y), splatmap.g - _SplatBlend.z));
            albedo = lerp(albedo, c.b, smoothstep(saturate(0 + _SplatBlend.x), saturate(c.b + _SplatBlend.y), splatmap.b - _SplatBlend.z));
           */
            half albedo = c;
            //albedo = blend(albedo, 0, c.r, splatmap.r);
            //albedo = blend(albedo, 0, c.g, splatmap.g);
            //albedo = blend(albedo, 0, c.b, splatmap.b);
            //albedo = blend(c.a, 0, albedo, splatA);
            //albedo = blend(albedo, splatmap.b, c.a, splatmap.a);
            //albedo = blend(albedo, lerp(albedo, c.g, splatmap.g));
            //albedo = blend(albedo, lerp(albedo, c.b, splatmap.b));

            //albedo = lerp(albedo, c.r, smoothstep(saturate(albedo - _SplatBlend), saturate(c.r + _SplatBlend), splatmap.r));
            //albedo = lerp(albedo, c.g, smoothstep(saturate(albedo - _SplatBlend), saturate(c.g + _SplatBlend), splatmap.g));
            //albedo = lerp(albedo, c.b, smoothstep(saturate(albedo - _SplatBlend), saturate(c.b + _SplatBlend), splatmap.b));

            //albedo = ColorMask(c.a, 0, 1, 0.5);
            //albedo += ColorMask(c.r, splatmap.r, 1, 0.5);
            //albedo += ColorMask(c.g, splatmap.g, 1, 0.5);
            //albedo += ColorMask(c.b, splatmap.b, 1, 0.5);

            //sampledHeight = _Parallax > 0 ? sampledHeight : 1 - sampledHeight;

            half4 color = tex2D(_ColorRamp, float2(clamp(albedo, 0.02, 0.98), 0));

            o.Alpha = color.a;
            //if (color.a < _Cutoff)
            //    discard;
            
            half albedoOcclusion = lerp(1, sampledHeight, _Occlusion / 2);

            o.Albedo = color * albedoOcclusion * _Color;
            o.Occlusion = lerp(1, sampledHeight, _Occlusion);
            o.Metallic = _Metallic;
            
            //o.Smoothness = saturate(_Glossiness);
            o.Smoothness = clamp(albedo * _Glossiness * albedoOcclusion, 0, _GlossinessLimit);
            
           
        }
        ENDCG
    }
    FallBack "Diffuse"
}
