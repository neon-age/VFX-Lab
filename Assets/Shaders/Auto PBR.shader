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
        _Glossiness ("Smoothness", Float) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
        _Occlusion ("Occlusion", Float) = 1
        _Parallax ("Parallax", Float) = 1
        _ParallaxParams ("Parallax Adjust (Offset, Multiply, Mip Bias)", Float) = (0, 1, 0, 0)
        
        _ParallaxSamples ("Parallax Samples Factor", Float) = 0.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200
        //Cull Off

        CGPROGRAM
        #pragma surface surf CustomStandard vertex:vert fullforwardshadows
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
        half _Cutoff;
        half _Glossiness;
        half _Metallic;
        half _BumpScale;
        int _BumpFromAlbedoQuality;
        int _UseNormalMap;
        half _Occlusion;
        half _Parallax;
        half4 _ParallaxParams;
        int _ParallaxSamples;
        fixed4 _Color;

        
        float invLerp(float from, float to, float value){
          return (value - from) / (to - from);
        }

        inline half4 LightingCustomStandard(SurfaceOutputStandard s, half3 viewDir, UnityGI gi)
        {
            half4 pbr = LightingStandard(s, viewDir, gi);
            return pbr;
        }
        inline void LightingCustomStandard_GI(SurfaceOutputStandard s, UnityGIInput data, inout UnityGI gi)
        {
            LightingStandard_GI(s, data, gi);
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
            return c * params.x + params.y;
        }

        #include<POM.cginc>

		void vert(inout appdata_full IN, out Input OUT)
		{
            UNITY_INITIALIZE_OUTPUT(Input, OUT);
            float3 eye;
            float sampleRatio;
            parallax_vert( IN.vertex, IN.normal, IN.tangent, eye, sampleRatio );
            OUT.parallaxEye = float4(eye, sampleRatio);
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

            
            half sampledHeight = 0;
            float2 offset = parallax_offset (_Parallax / 100, IN.parallaxEye.xyz, IN.parallaxEye.w, uv, 
			    _MainTex, 1, _ParallaxSamples, sampledHeight);

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

            sampledHeight = _Parallax > 0 ? sampledHeight : 1 - sampledHeight;

            half4 color = tex2D(_ColorRamp, float2(clamp(albedo, 0.02, 0.98), 0));
            if (color.a < _Cutoff)
                discard;
            
            half albedoOcclusion = lerp(1, sampledHeight, _Occlusion / 2);

            o.Albedo = color * albedoOcclusion * _Color;
            o.Occlusion = lerp(1, sampledHeight, _Occlusion);
            o.Metallic = _Metallic;
            
            o.Smoothness = saturate(_Glossiness);
            o.Smoothness = saturate(albedo * _Glossiness * albedoOcclusion);
            
            o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
