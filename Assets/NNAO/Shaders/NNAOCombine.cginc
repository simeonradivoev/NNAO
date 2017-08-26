struct CompositionOutput
{
	half4 gbuffer0 : SV_Target0;
	half4 gbuffer3 : SV_Target1;
};

sampler2D _OcclusionTexture;
sampler2D _CameraDepthTexture;
float4 _CameraDepthTexture_TexelSize;
sampler2D _LastCameraDepthTexture;
sampler2D _MainTex;
float4 _MainTex_TexelSize;
float _DepthThreshold;

void UpdateNearestSample(	inout float MinDist,
								inout float2 NearestUV,
								float Z,
								float2 UV,
								float ZFull
								)
{
	float Dist = abs(Z - ZFull);
	if (Dist < MinDist)
	{
		MinDist = Dist;
		NearestUV = UV;
	}
}

float4 GetNearestDepthSample(float2 uv)
{
	//read full resolution depth
	float ZFull = Linear01Depth( SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv) );

	//find low res depth texture texel size
	const float2 lowResTexelSize = 2.0 * _CameraDepthTexture_TexelSize.xy;
	const float depthTreshold =  _DepthThreshold;
		
	float2 lowResUV = uv; 
		
	float MinDist = 1.e8f;
		
	float2 UV00 = lowResUV - 0.5 * lowResTexelSize;
	float2 NearestUV = UV00;
	float Z00 = Linear01Depth( SAMPLE_DEPTH_TEXTURE( _LastCameraDepthTexture, UV00) );   
	UpdateNearestSample(MinDist, NearestUV, Z00, UV00, ZFull);
		
	float2 UV10 = float2(UV00.x+lowResTexelSize.x, UV00.y);
	float Z10 = Linear01Depth( SAMPLE_DEPTH_TEXTURE( _LastCameraDepthTexture, UV10) );  
	UpdateNearestSample(MinDist, NearestUV, Z10, UV10, ZFull);
		
	float2 UV01 = float2(UV00.x, UV00.y+lowResTexelSize.y);
	float Z01 = Linear01Depth( SAMPLE_DEPTH_TEXTURE( _LastCameraDepthTexture, UV01) );  
	UpdateNearestSample(MinDist, NearestUV, Z01, UV01, ZFull);
		
	float2 UV11 = UV00 + lowResTexelSize;
	float Z11 = Linear01Depth( SAMPLE_DEPTH_TEXTURE( _LastCameraDepthTexture, UV11) );  
	UpdateNearestSample(MinDist, NearestUV, Z11, UV11, ZFull);
		
	float4 aoSample = float4(0,0,0,0);
		
	[branch]
	if (abs(Z00 - ZFull) < depthTreshold &&
		abs(Z10 - ZFull) < depthTreshold &&
		abs(Z01 - ZFull) < depthTreshold &&
		abs(Z11 - ZFull) < depthTreshold )
	{
		aoSample = tex2Dlod(_OcclusionTexture, float4(lowResUV,0,0));
	}
	else
	{
		aoSample = tex2Dlod(_OcclusionTexture, float4(NearestUV,0,0));
	}
		
	return aoSample;
}

v2f_img vert (uint vid : SV_VertexID)
{
	float x = vid == 1 ? 2 : 0;
	float y = vid >  1 ? 2 : 0;

	v2f_img o;
	o.pos = float4(x * 2 - 1, 1 - y * 2, 0, 1);
#if UNITY_UV_STARTS_AT_TOP
	o.uv = float2(x, y);
#else
	o.uv = float2(x, 1 - y);
#endif
	o.uv = TransformStereoScreenSpaceTex(o.uv, 1);
	return o;
}

CompositionOutput frag (v2f_img i) : SV_Target
{
#ifdef DOWNSAMPLE
	half ao = GetNearestDepthSample(i.uv);
#else
	half ao = tex2D(_OcclusionTexture,i.uv);
#endif

	CompositionOutput o;
	o.gbuffer0 = half4(0, 0, 0, ao);
	o.gbuffer3 = float4(ao,ao,ao,0);
	return o;
}

v2f_img debugVert (appdata_img v)
{
	v2f_img o;
	o.pos = UnityObjectToClipPos(v.vertex);
	o.uv = v.texcoord;
	o.uv = TransformStereoScreenSpaceTex(o.uv, 1);
	return o;
}

half4 debugFrag(v2f_img i) : Color
{
#ifdef DOWNSAMPLE
	half ao = GetNearestDepthSample(i.uv);
#else
	half ao = tex2D(_OcclusionTexture,i.uv);
#endif
	return 1 - ao;
}