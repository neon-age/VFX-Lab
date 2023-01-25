Shader "Custom/Wave"
{
    Properties
    {
        _Layer1 ("_Layer1", 2D) = "white" {}
        _Layer2 ("_Layer2", 2D) = "white" {}
        _Layer1Params ("_Layer1Params", Vector) = (1, 0.5, 0, 0)
        _Layer2Params ("_Layer2Params", Vector) = (1, 0.5, 0, 0)
        _LayersBlend ("_LayersBlend", Float) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _Layer1;
            sampler2D _Layer2;
            float4 _Layer1_ST;
            half4 _Layer1Params;
            half4 _Layer2Params;
            half _LayersBlend;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _Layer1);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                half4 l1 = tex2D(_Layer1, i.uv * _Layer1Params.x + (_Time.x * _Layer1Params.z)) * _Layer1Params.y;
                half4 l2 = tex2D(_Layer2, i.uv * _Layer2Params.x + (_Time.x * _Layer2Params.z)) * _Layer2Params.y;

                half4 c = smoothstep(l1, l2, _LayersBlend);
                return c;
            }
            ENDCG
        }
    }
}
