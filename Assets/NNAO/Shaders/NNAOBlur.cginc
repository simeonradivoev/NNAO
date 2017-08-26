float3 _TexelOffsetScale;

float _DepthBias;
float _NormalBias;
float _BlurQuality;
float _BlurAmount;

sampler2D _MainTex;

static const float weights[8] = { 0.071303, 0.131514, 0.189879, 0.321392, 0.452906,  0.584419, 0.715932, 0.847445 };

inline half compareNormalAndDepth( float3 sourceNormal, float sourceDepth, float2 uv)
{
	float3 otherNormal;
	float otherDepth;
	SampleDepthNormal(uv,otherNormal,otherDepth);
				
	float3 normalDelta = abs( otherNormal - sourceNormal);
	float depthDelta = abs( otherDepth - sourceDepth);
				
	return step( normalDelta.x + normalDelta.y + normalDelta.z, _NormalBias) * step( depthDelta, _DepthBias);
}

inline void processSample( float2 uv,
						 	float3 sourceNormal,
						 	float sourceDepth,
							float i,
							float _BlurQuality, //sampleCount
							float2 stepSize, 
							inout half accumulator, 
							inout half denominator)
{
	float2 offsetUV = stepSize * i + uv;
	half isSame = compareNormalAndDepth( sourceNormal, sourceDepth, offsetUV);
	half coefficient = weights[ _BlurQuality - abs(i)] * isSame;
	accumulator += tex2D( _MainTex, offsetUV).r * coefficient;
	denominator += coefficient;
}

half4 blurFrag(v2f_img i) : Color
{
	float3 sourceNormal;
	float sourceDepth;
	SampleDepthNormal(i.uv,sourceNormal,sourceDepth);
			    
	const float2 stepSize = _TexelOffsetScale.xy;
	half4 col = tex2D( _MainTex, i.uv);
	half accumulator = col.r * 0.214607;
	half denominator = 0.214607;
			    
	processSample( i.uv, sourceNormal, sourceDepth, 1, _BlurQuality, stepSize, accumulator, denominator);
	processSample( i.uv, sourceNormal, sourceDepth, 0.2, _BlurQuality, stepSize, accumulator, denominator);
	processSample( i.uv, sourceNormal, sourceDepth, 0.4, _BlurQuality, stepSize, accumulator, denominator);
	processSample( i.uv, sourceNormal, sourceDepth, 0.6, _BlurQuality, stepSize, accumulator, denominator);
	processSample( i.uv, sourceNormal, sourceDepth, 0.8, _BlurQuality, stepSize, accumulator, denominator);
	processSample( i.uv, sourceNormal, sourceDepth, 1.2, _BlurQuality, stepSize, accumulator, denominator);
	processSample( i.uv, sourceNormal, sourceDepth, 1.4, _BlurQuality, stepSize, accumulator, denominator);
	processSample( i.uv, sourceNormal, sourceDepth, 1.6, _BlurQuality, stepSize, accumulator, denominator);
	processSample( i.uv, sourceNormal, sourceDepth, 1.8, _BlurQuality, stepSize, accumulator, denominator);
	processSample( i.uv, sourceNormal, sourceDepth, 2.0, _BlurQuality, stepSize, accumulator, denominator);
			    
	processSample( i.uv, sourceNormal, sourceDepth, -1, _BlurQuality, stepSize, accumulator, denominator);
	processSample( i.uv, sourceNormal, sourceDepth, -0.2, _BlurQuality, stepSize, accumulator, denominator);
	processSample( i.uv, sourceNormal, sourceDepth, -0.4, _BlurQuality, stepSize, accumulator, denominator);
	processSample( i.uv, sourceNormal, sourceDepth, -0.6, _BlurQuality, stepSize, accumulator, denominator);
	processSample( i.uv, sourceNormal, sourceDepth, -0.8, _BlurQuality, stepSize, accumulator, denominator);
	processSample( i.uv, sourceNormal, sourceDepth, -1.2, _BlurQuality, stepSize, accumulator, denominator);
	processSample( i.uv, sourceNormal, sourceDepth, -1.4, _BlurQuality, stepSize, accumulator, denominator);
	processSample( i.uv, sourceNormal, sourceDepth, -1.6, _BlurQuality, stepSize, accumulator, denominator);
	processSample( i.uv, sourceNormal, sourceDepth, -1.8, _BlurQuality, stepSize, accumulator, denominator);
	processSample( i.uv, sourceNormal, sourceDepth, -2.0, _BlurQuality, stepSize, accumulator, denominator);
			    
	accumulator /= denominator;

	return half4(accumulator,col.gba);
}