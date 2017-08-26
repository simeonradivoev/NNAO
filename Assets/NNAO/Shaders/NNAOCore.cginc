#define SOURCE_GBUFFER

sampler2D _CameraGBufferTexture2;
sampler2D _CameraGBufferTexture3;
sampler2D _CameraDepthTexture;
sampler2D _LastCameraDepthTexture;
sampler2D _CameraDepthNormalsTexture;
sampler2D _LastOcclusionTexture;

float3 ReconstructViewPosition(float2 uv, float depth)
{
	const float2 p11_22 = float2(unity_CameraProjection._11, unity_CameraProjection._22);
	const float2 p13_31 = float2(unity_CameraProjection._13, unity_CameraProjection._23);
	return float3((uv * 2 - 1 - p13_31) / p11_22 * depth, depth);
}

void SampleDepthNormal(float2 uv,out float3 normal,out float depth)
{
#if defined(SOURCE_GBUFFER)
	normal = tex2D(_CameraGBufferTexture2, uv).xyz;
	normal = normal * 2 - any(normal); // gets (0,0,0) when norm == 0
	normal = mul((float3x3)unity_WorldToCamera, normal);
	depth = LinearEyeDepth  (SAMPLE_DEPTH_TEXTURE(_LastCameraDepthTexture, uv));
#else
	float4 cdn = tex2D(_CameraDepthNormalsTexture, uv);
	normal = DecodeViewNormalStereo(cdn) * float3(1, 1, -1);
				
	depth = DecodeFloatRG(cdn.zw) * _ProjectionParams.z;
	// Offset the depth value to avoid precision error.
	// (depth in the DepthNormals mode has only 16-bit precision)
	depth -= _ProjectionParams.z / 65536;
#endif
}

v2f_img baseVert (appdata_img v)
{
	v2f_img o;
	o.pos = UnityObjectToClipPos(v.vertex);
	o.uv = v.texcoord;
	o.uv = TransformStereoScreenSpaceTex(o.uv, 1);
	return o;
}