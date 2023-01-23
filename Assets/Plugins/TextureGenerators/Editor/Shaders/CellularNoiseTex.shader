// This shader is meant to generate a Voronoi noise texture so we can Blit it
// into a render texture and save it on a png. Since it's on a shader, it uses
// the GPU and therefore is much faster than the CPU. You can use it as a
// reference on how to use it on a realtime shader for your game.

Shader "Editor/CellularNoiseGenerator" {

	Properties {

		_Variation ("Variation", Float) = 0
		[Toggle(_SEAMLESS)] _Seamless ("Seamless", Float) = 1
		[KeywordEnum(One, Two)] _Combination ("Combination", Float) = 0
		[Toggle(_SQUARED_DISTANCE)] _SquaredDistance ("Squared Distance", Float) = 0

		[Header(Noise Properties)]
		_Frequency ("Frequency", Float) = 1
		_Octaves ("Octaves", Int) = 1
		_Persistance ("Persistance", Range(0, 1)) = 0.5
		_Lacunarity ("Lacunarity", Range(0.1, 4)) = 2
		_Jitter ("Jitter", Range(0, 1)) = 1

		[Header(Noise Modifiers)]
		[HideInInspector] _NormFactor ("Normalization Factor", Float) = 1
		_RangeMin ("Range Min", Float) = 0
		_RangeMax ("Range Max", Float) = 1
		_Power ("Power", Range(1, 8)) = 1
		[Toggle(_INVERTED)] _Inverted ("Inverted", Float) = 0
	}

	SubShader {

		Pass {

			CGPROGRAM

			#pragma multi_compile _ _SEAMLESS
			#pragma multi_compile _COMBINATION_ONE _COMBINATION_TWO
			#pragma multi_compile _ _SQUARED_DISTANCE
			#pragma multi_compile _ _INVERTED

			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			struct appdata {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

			float _Variation;
			float _Octaves, _Frequency, _Lacunarity, _Persistance, _Jitter;
			float _NormFactor, _RangeMin, _RangeMax, _Power;

			///////////////////////////////////////////////////////////////////////////////////////
			// This is Justin Hawkin's repository cginc with some modifications                  //
			// in order to accomodate the needs of this project. I didn't do an #include         //
			// line because these are dangerous due to their string reference nature             //
			// but if you want Justin's original to use as an include to your project,           //
			// feel free to erase this block.                                                    //
			///////////////////////////////////////////////////////////////////////////////////////
			#define K 0.142857142857
			#define Ko 0.428571428571

			float4 mod(float4 x, float y) { return x - y * floor(x/y); }
			float3 mod(float3 x, float y) { return x - y * floor(x/y); }

			// Permutation polynomial: (34x^2 + x) mod 289
			float3 Permutation(float3 x) 
			{
			return mod((34.0 * x + 1.0) * x, 289.0);
			}

			float2 inoise(float4 P, float jitter)
			{			
				float4 Pi = mod(floor(P), 289.0);
				float4 Pf = frac(P);
				float3 oi = float3(-1.0, 0.0, 1.0);
				float3 of = float3(-0.5, 0.5, 1.5);
				float3 px = Permutation(Pi.x + oi);
				float3 py = Permutation(Pi.y + oi);
				float3 pz = Permutation(Pi.z + oi);

				float3 p, ox, oy, oz, ow, dx, dy, dz, dw, d;
				float2 F = 1e6;
				int i, j, k, n;

				for(i = 0; i < 3; i++)
				{
					for(j = 0; j < 3; j++)
					{
						for(k = 0; k < 3; k++)
						{
							p = Permutation(px[i] + py[j] + pz[k] + Pi.w + oi);
				
							ox = frac(p*K) - Ko;
							oy = mod(floor(p*K),7.0)*K - Ko;
							
							p = Permutation(p);
							
							oz = frac(p*K) - Ko;
							ow = mod(floor(p*K),7.0)*K - Ko;
						
							dx = Pf.x - of[i] + jitter*ox;
							dy = Pf.y - of[j] + jitter*oy;
							dz = Pf.z - of[k] + jitter*oz;
							dw = Pf.w - of + jitter*ow;
							
							d = dx * dx + dy * dy + dz * dz + dw * dw;
							
							//Find the lowest and second lowest distances
							for(n = 0; n < 3; n++)
							{
								if(d[n] < F[0])
								{
									F[1] = F[0];
									F[0] = d[n];
								}
								else if(d[n] < F[1])
								{
									F[1] = d[n];
								}
							}
						}
					}
				}
				
				return F;
			}
			///////////////////////////////////////////////////////////////////////////////////////
			///////////////////////////////////////////////////////////////////////////////////////



			float4 TorusMapping (float2 i) {
				float4 o = 0;
				o.x = sin(i.x * UNITY_TWO_PI);
				o.y = cos(i.x * UNITY_TWO_PI);
				o.z = sin(i.y * UNITY_TWO_PI);
				o.w = cos(i.y * UNITY_TWO_PI);
				return o;
			}

			v2f vert (appdata v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}

			float4 frag (v2f i) : SV_TARGET {
				#ifdef _SEAMLESS
					float4 coords = TorusMapping(i.uv);
				#else
					float4 coords = float4(i.uv * 5, 0, 0);
				#endif

				float noise = 0;
				float freq = _Frequency;
				float amp = 0.5;	
				for (int i = 0; i < _Octaves; i++) {
					float4 p = coords * freq;

					#ifdef _SEAMLESS
						p += _Variation + i + freq * 5;
					#else
						p += float4(0, 0, 0, _Variation + i);
					#endif

					float2 F = inoise(p, _Jitter);

					#ifdef _COMBINATION_ONE
						#ifdef _SQUARED_DISTANCE
							noise += F.x * amp;
						#else
							noise += sqrt(F.x) * amp;
						#endif
					#endif

					#ifdef _COMBINATION_TWO
						#ifdef _SQUARED_DISTANCE
							noise += (F.y - F.x) * amp;
						#else
							noise += (sqrt(F.y) - sqrt(F.x)) * amp;
						#endif
					#endif
					
					freq *= _Lacunarity;
					amp *= _Persistance;
				}
			
				noise = noise / _NormFactor;
				noise = (noise - _RangeMin) / (_RangeMax - _RangeMin);
				noise = saturate(noise);

				float k = pow(2, _Power - 1);
				noise = noise <= 0.5 ? k * pow(noise, _Power) : noise;
				noise = noise >= 0.5 ? 1 - k * pow(1 - noise, _Power) : noise;

				#ifdef _INVERTED
					noise = 1 - noise;
				#endif

				return float4(noise, noise, noise, 1);
			}

			ENDCG
		}
	}
}
