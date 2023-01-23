// This shader can combine up to four grayscale textures into a single texture
// by sampling each texture on a channel of the resulting texture. Only used
// on the editor tool.

Shader "Editor/CombinedTexture" {

	Properties {

		_TexR ("Texture R", 2D) = "black" {}
		_TexG ("Texture G", 2D) = "black" {}
		_TexB ("Texture B", 2D) = "black" {}
		_TexA ("Texture A", 2D) = "white" {}
	}

	SubShader {

		Pass {

			CGPROGRAM

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

			sampler2D _TexR, _TexG, _TexB, _TexA;

			v2f vert (appdata v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}

			float4 frag (v2f i) : SV_TARGET {
				float4 col = float4(0, 0, 0, 1);
				col.r = tex2D(_TexR, i.uv).x;
				col.g = tex2D(_TexG, i.uv).x;
				col.b = tex2D(_TexB, i.uv).x;
				col.a = tex2D(_TexA, i.uv).x;

				return col;
			}

			ENDCG
		}
	}
}
