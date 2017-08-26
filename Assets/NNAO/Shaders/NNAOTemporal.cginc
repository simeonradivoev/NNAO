sampler2D _MainTex;
sampler2D _LastOcclusionTexture;
sampler2D_half _CameraMotionVectorsTexture;
sampler2D_half _LastMotionVectors;

v2f_img vert (appdata_img v)
{
	v2f_img o;
	o.pos = UnityObjectToClipPos(v.vertex);
	o.uv = v.texcoord;
	o.uv = TransformStereoScreenSpaceTex(o.uv, 1);
	return o;
}

half4 temporalFrag(v2f_img i) : Color
{  
	half4 col = tex2D( _MainTex, i.uv);
	half ao = col.r;

	float3 dir = tex2D(_LastMotionVectors,i.uv).rgb;
	float lastAo = tex2D(_LastOcclusionTexture,i.uv - dir.xy).r;
	float blendFactor = length(dir) * 40;
	blendFactor += abs(lastAo - ao) * 2;
	blendFactor = clamp(blendFactor,unity_DeltaTime.x,1);
	ao = lerp(lastAo,ao,blendFactor);

	return half4(ao,col.gba);
}

half4 copyMotionVectorsFrag(v2f_img i) : Color
{
	return tex2D(_CameraMotionVectorsTexture,i.uv);
}