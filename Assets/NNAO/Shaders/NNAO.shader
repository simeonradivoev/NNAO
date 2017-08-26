Shader "Hidden/NNAO"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		// No culling or depth
		Cull Off ZWrite Off ZTest Always

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#define SOURCE_GBUFFER
			
			#include "UnityCG.cginc"
			#include "NNAOCore.cginc"

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
			
			sampler2D _F0Tex;
			sampler2D _F1Tex;
			sampler2D _F2Tex;
			sampler2D _F3Tex;
			sampler2D _MainTex;
			float _Radius;
			float _Intensity;
			float _Contrast;

			static const float4 F0a = float4( 2.364370,  2.399485,  0.889055,  4.055205);
			static const float4 F0b = float4(-1.296360, -0.926747, -0.441784, -3.308158);
			static const float4 F1a = float4( 1.418117,  1.505182,  1.105307,  1.728971);
			static const float4 F1b = float4(-0.491502, -0.789398, -0.328302, -1.141073);
			static const float4 F2a = float4( 1.181042,  1.292263,  2.136337,  1.616358);
			static const float4 F2b = float4(-0.535625, -0.900996, -0.405372, -1.030838);
			static const float4 F3a = float4( 1.317336,  2.012828,  1.945621,  5.841383);
			static const float4 F3b = float4(-0.530946, -1.091267, -1.413035, -3.908190);

			static const float4 Xmean = float4( 0.000052, -0.000003, -0.000076,  0.004600);
			static const float4 Xstd  = float4( 0.047157,  0.052956,  0.030938,  0.056321);
			static const float Ymean = 0.000000;
			static const float Ystd  = 0.116180;

			static const float4x4 W1 = float4x4(
				-0.147624, -0.150471,  0.154306, -0.006904,
				 0.303306,  0.057305, -0.240071,  0.036727,
				 0.009158, -0.371759, -0.259837,  0.302215,
				-0.111847, -0.183312,  0.044680, -0.190296
			 );

			static const float4x4 W2 = float4x4(
				 0.212815,  0.028991,  0.105671, -0.111834,
				 0.316173, -0.166099,  0.058121, -0.170316,
				 0.135707, -0.478362, -0.156021, -0.413203,
				-0.097283,  0.189983,  0.019879, -0.260882
			);

			static const float4 W3 = float4( 0.774455,  0.778138, -0.318566, -0.523377);

			static const float4 b0 = float4( 0.428451,  2.619065,  3.756697,  1.636395);
			static const float4 b1 = float4( 0.566310,  1.877808,  1.316716,  1.091115);
			static const float4 b2 = float4( 0.033848,  0.036487, -1.316707, -1.067260);
			static const float  b3 = 0.151472;

			static const float4 alpha0 = float4( 0.326746, -0.380245,  0.179183,  0.104307);
			static const float4 alpha1 = float4( 0.255981,  0.009228,  0.211068,  0.110055);
			static const float4 alpha2 = float4(-0.252365,  0.016463, -0.232611,  0.069798);
			static const float  alpha3 = -0.553760;

			static const float4 beta0 = float4( 0.482399,  0.562806,  0.947146,  0.460560);
			static const float4 beta1 = float4( 0.670060,  1.090481,  0.461880,  0.322837);
			static const float4 beta2 = float4( 0.760696,  1.016398,  1.686991,  1.744554);
			static const float  beta3 = 0.777760;

			float f3_f(float3 c) 
			{ 
				return dot(round(c * 255), float3(65536, 256, 1)); 
			}

			float3 f_f3(float f) 
			{ 
				return frac(f / float3(16777216, 65536, 256)); 
			}

			// Z buffer depth to linear 0-1 depth
			float LinearizeDepth(float z)
			{
				float isOrtho = unity_OrthoParams.w;
				float isPers = 1 - unity_OrthoParams.w;
				z *= _ZBufferParams.x;
				return (1 - isOrtho * z) / (isPers * z + _ZBufferParams.y);
			}

			// Depth/normal sampling functions

			float3 rand(float3 seed)
			{
				float x = sin(dot(seed, float3(12.9898, 78.233, 21.317)));
				return frac(x * float3(43758.5453, 21383.21227, 20431.20563)) * 2 - 1;
			}

			float prelu(float x, float alpha, float beta)
			{
				return beta * max(x, 0) + alpha * min(x, 0);
			}

			float4 prelu(float4 x, float4 alpha, float4 beta)
			{
				return beta * max(x, 0) + alpha * min(x, 0);
			}

			float2 spiral(float t, float l, float o)
			{
				float x = l * 2 * UNITY_PI * (t + o);
				return t * float2(cos(x), sin(x));
			}

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				const int SAMPLES = 8;
				// Full/half filter width
				const int FW = 31;
				const int HW = (FW - 1) / 2;

				float2 uv = i.uv;
				float3 viewNormal;
				float depth;
				SampleDepthNormal(uv,viewNormal,depth);
				float3 base = ReconstructViewPosition(uv, depth);
				float3 seed = rand(base + _Time.xyz);

				// First Layer
				float4 H0 = 0;

				// New Faster Sampler Method
				[unroll(SAMPLES)]
				for (int i = 0; i < SAMPLES; i++)
				{
					float t = (float)(i + 1) / (SAMPLES + 1);
					float scale = UNITY_PI * FW * FW * t / (SAMPLES * 2); 
					float2 indx = spiral(t, 2.5, UNITY_PI * 2 * seed.x);

					float4 next = float4(base.xy + indx * _Radius, base.z, 1);
					next = mul(unity_CameraProjection, next);

					float2 next_uv = (next.xy / base.z + 1) / 2;
					float3 sample_norm;
					float sampleDepth;
					SampleDepthNormal(next_uv,sample_norm,sampleDepth);

					float3 actu = ReconstructViewPosition(next_uv, sampleDepth);
					float2 fltr = (indx * HW + HW + 0.5) / (HW * 2 + 2);

					float4 X = float4(sample_norm - viewNormal, (actu.z - base.z) / _Radius);
					X *= saturate(1 - distance(actu, base) / _Radius);

					X.xzw = -X.xzw;

					float4x4 m = float4x4(
						tex2D(_F0Tex, fltr) * F0a + F0b,
						tex2D(_F1Tex, fltr) * F1a + F1b,
						tex2D(_F2Tex, fltr) * F2a + F2b,
						tex2D(_F3Tex, fltr) * F3a + F3b
					);

					H0 += scale * mul(m, (X - Xmean) / Xstd);
				}

				H0 = prelu(H0 + b0, alpha0, beta0);

				// Other Layers
				float4 H1 = prelu(mul(transpose(W1), H0) + b1, alpha1, beta1);
				float4 H2 = prelu(mul(transpose(W2), H1) + b2, alpha2, beta2);
				float  Y  = prelu(dot(W3, H2) + b3, alpha3, beta3);

				// Output
				float ao = saturate(pow((Y * Ystd + Ymean) * _Intensity,_Contrast));
				return fixed4(ao,0,0,0);
			}
			ENDCG
		}
		//1 - Blur
		Pass
		{
			CGPROGRAM
			#pragma vertex baseVert
			#pragma fragment blurFrag
			
			#include "UnityCG.cginc"
			#include "NNAOCore.cginc"
			#include "NNAOBlur.cginc"
			
			ENDCG
		}
		//2 - Temporam Smoothing
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment temporalFrag
			
			#include "UnityCG.cginc"
			#include "NNAOTemporal.cginc"
			
			ENDCG
		}
		//3 - Combine
		Pass
		{
			Blend Zero OneMinusSrcColor, Zero OneMinusSrcAlpha

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 3.5
			
			#include "UnityCG.cginc"
			#include "NNAOCombine.cginc"
			
			ENDCG
		}
		//4 - Combine Downsampled
		Pass
		{
			Blend Zero OneMinusSrcColor, Zero OneMinusSrcAlpha

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 3.5
			#define DOWNSAMPLE
			
			#include "UnityCG.cginc"
			#include "NNAOCombine.cginc"
			
			ENDCG
		}
		//5 - Debug Combine
		Pass
		{
			CGPROGRAM
			#pragma vertex debugVert
			#pragma fragment debugFrag
			#pragma target 3.5
			
			#include "UnityCG.cginc"
			#include "NNAOCombine.cginc"
			
			ENDCG
		}
		//6 - Debug Combine DOWNSAMPLED
		Pass
		{
			CGPROGRAM
			#pragma vertex debugVert
			#pragma fragment debugFrag
			#define DOWNSAMPLE
			#pragma target 3.5
			
			#include "UnityCG.cginc"
			#include "NNAOCombine.cginc"
			
			ENDCG
		}
		//7 Copy Motion Vectors
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment copyMotionVectorsFrag
			
			#include "UnityCG.cginc"
			#include "NNAOTemporal.cginc"
			
			ENDCG
		}

	}
}
