using UnityEngine;
using UnityEngine.Rendering;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class NNAO : MonoBehaviour
{
	[SerializeField] private bool downsample;
	[SerializeField] private float radius = 1;
	[SerializeField] private float intensity = 1;
	[SerializeField] private float contrast = 1;
	[SerializeField] private bool debug;
	[SerializeField,Range(2.0f, 4.0f)] private int blurQuality = 2;
	[SerializeField,Range(0.0f, 16.0f)] private float maxBlurRadius = 8;
	[SerializeField] private float normalBias = 1.5f;
	[SerializeField] private float depthBias = 0.2f;
	[SerializeField] private Shader shader;
	[SerializeField] private Texture2D f0Texture;
	[SerializeField] private Texture2D f1Texture;
	[SerializeField] private Texture2D f2Texture;
	[SerializeField] private Texture2D f3Texture;
	[SerializeField] private Camera camera;
	private Material material;
	private RenderTexture LastAmbientOcclusion;
	private RenderTexture LastCameraMotionVectors;
	CommandBuffer _aoCommands;

	private void Reset()
	{
		camera = GetComponent<Camera>();
	}

	private void Awake()
	{
		if (camera == null) camera = GetComponent<Camera>();
	}

	private CommandBuffer aoCommands
	{
		get
		{
			if (_aoCommands == null)
			{
				_aoCommands = new CommandBuffer { name = "AmbientOcclusion" };
			}
			return _aoCommands;
		}
	}

	private void OnEnable()
	{
		SetupMaterial();
		camera.AddCommandBuffer(CameraEvent.BeforeReflections, aoCommands);
	}

	private void Start()
	{
		SetupMaterial();
		BuildCommands(aoCommands);
		UpdateMaterialProperties();
	}

	private void OnDisable()
	{
		camera.RemoveCommandBuffer(CameraEvent.BeforeReflections, _aoCommands);
	}

	public void OnValidate()
	{
		UpdateMaterialProperties();
	}

	public void ValidateCommands()
	{
		if (_aoCommands == null) return;
		_aoCommands.Clear();
		if (!debug)
		{
			BuildCommands(_aoCommands);
		}
		UpdateMaterialProperties();
	}

	private void BuildCommands(CommandBuffer cb)
	{
		var tw = camera.pixelWidth;
		var ts = downsample ? 2 : 1;
		var th = camera.pixelHeight;
		var format = RenderTextureFormat.R8;
		var rwMode = RenderTextureReadWrite.Linear;
		var filter = FilterMode.Bilinear;

		// AO buffer
		var rtMask = Shader.PropertyToID("_OcclusionTexture1");

		if(LastAmbientOcclusion != null) DestroyImmediate(LastAmbientOcclusion);
		LastAmbientOcclusion = new RenderTexture(tw / ts, th / ts,0,format,rwMode);
		LastCameraMotionVectors = new RenderTexture(tw / ts, th / ts, 0, RenderTextureFormat.RGHalf, rwMode);
		cb.SetGlobalTexture("_LastOcclusionTexture", LastAmbientOcclusion);
		cb.SetGlobalTexture("_LastMotionVectors", LastCameraMotionVectors);
		cb.GetTemporaryRT(rtMask, tw / ts, th / ts, 0, filter, format, rwMode);

		// AO estimation
		cb.Blit(LastAmbientOcclusion, rtMask, material,0);

		// Blur buffer
		var rtBlur = Shader.PropertyToID("_OcclusionTexture2");
		var rtBlur2 = Shader.PropertyToID("_OcclusionTexture3");
		var rtTemporal = Shader.PropertyToID("_OcclusionTexture4");

		// Blur
		cb.SetGlobalVector("_TexelOffsetScale", new Vector4(maxBlurRadius / (tw / ts), 0, 0, 0));
		cb.GetTemporaryRT(rtBlur, tw / ts, th / ts, 0, filter, format, rwMode);
		cb.Blit(rtMask, rtBlur, material, 1);
		cb.ReleaseTemporaryRT(rtMask);

		cb.SetGlobalVector("_TexelOffsetScale", new Vector4(0, maxBlurRadius / (th / ts), 0, 0));
		cb.GetTemporaryRT(rtBlur2, tw / ts, th / ts, 0, filter, format, rwMode);
		cb.Blit(rtBlur, rtBlur2, material, 1);
		cb.ReleaseTemporaryRT(rtBlur);

		//Temporal Smoothing
		cb.GetTemporaryRT(rtTemporal, tw / ts, th / ts, 0, filter, format, rwMode);
		cb.Blit(rtBlur2, rtTemporal, material, 2);
		cb.ReleaseTemporaryRT(rtBlur2);

		// Combine AO to the G-buffer.
		var mrt = new RenderTargetIdentifier[] {
			BuiltinRenderTextureType.GBuffer0,      // Albedo, Occ
			BuiltinRenderTextureType.CameraTarget   // Ambient
		};
		cb.SetRenderTarget(mrt, BuiltinRenderTextureType.CameraTarget);
		cb.SetGlobalTexture("_OcclusionTexture", rtTemporal);
		cb.DrawProcedural(Matrix4x4.identity, material, downsample ? 4 : 3, MeshTopology.Triangles, 3);

		cb.Blit(rtTemporal, LastAmbientOcclusion);
		cb.ReleaseTemporaryRT(rtTemporal);
	}

	private void SetupMaterial()
	{
		if (material == null && shader != null)
		{
			material = new Material(shader){hideFlags = HideFlags.HideAndDontSave};
		}
	}

	private void Update()
	{
		camera.depthTextureMode |= DepthTextureMode.Depth | DepthTextureMode.DepthNormals | DepthTextureMode.MotionVectors;
	}

	private void UpdateMaterialProperties()
	{
		if (material != null)
		{
			material.SetTexture("_F0Tex", f0Texture);
			material.SetTexture("_F1Tex", f1Texture);
			material.SetTexture("_F2Tex", f2Texture);
			material.SetTexture("_F3Tex", f3Texture);
			material.SetFloat("_Radius", radius);
			material.SetFloat("_Intensity",intensity);
			material.SetFloat("_Contrast", contrast);

			material.SetFloat("_BlurQuality", blurQuality);
			material.SetFloat("_DepthBias", depthBias);
			material.SetFloat("_NormalBias", normalBias);
		}
	}

	private void OnRenderImage(RenderTexture src, RenderTexture dest)
	{
		Graphics.Blit(null, LastCameraMotionVectors,material,7);

		if (debug)
		{
			Shader.SetGlobalTexture("_LastOcclusionTexture", LastAmbientOcclusion);

			var format = RenderTextureFormat.R8;
			var rwMode = RenderTextureReadWrite.Linear;

			var ts = downsample ? 2 : 1;
			var tw = src.width / ts;
			var th = src.height / ts;

			RenderTexture rtMask = RenderTexture.GetTemporary(tw, th, 0, format, rwMode);
			Graphics.Blit(src, rtMask, material, 0);

			Shader.SetGlobalVector("_TexelOffsetScale", new Vector4(maxBlurRadius / tw, 0, 0, 0));
			RenderTexture rtBlur = RenderTexture.GetTemporary(tw, th, 0, format, rwMode);
			Graphics.Blit(rtMask, rtBlur, material, 1);
			RenderTexture.ReleaseTemporary(rtMask);

			Shader.SetGlobalVector("_TexelOffsetScale", new Vector4(0, maxBlurRadius / th, 0, 0));
			RenderTexture rtBlur1 = RenderTexture.GetTemporary(tw, th, 0, format, rwMode);
			Graphics.Blit(rtBlur, rtBlur1, material, 1);
			RenderTexture.ReleaseTemporary(rtBlur);

			RenderTexture rtTemporal = RenderTexture.GetTemporary(tw, th, 0, format, rwMode);
			Graphics.Blit(rtBlur1, rtTemporal, material, 2);
			RenderTexture.ReleaseTemporary(rtBlur1);

			Shader.SetGlobalTexture("_OcclusionTexture", rtTemporal);
			Graphics.Blit(src, dest, material, downsample ? 6 : 5);

			Graphics.Blit(rtTemporal, LastAmbientOcclusion);
			RenderTexture.ReleaseTemporary(rtTemporal);
		}
		else
		{
			Graphics.Blit(src, dest);
		}
	}

	private void OnDestroy()
	{
		if(material != null) DestroyImmediate(material);
		if(LastAmbientOcclusion != null) DestroyImmediate(LastAmbientOcclusion);
		if(LastCameraMotionVectors != null) DestroyImmediate(LastCameraMotionVectors);
	}

	#region Properties

	public bool Debug
	{
		get { return debug; }
		set
		{
			if (debug != value)
			{
				debug = value;
				ValidateCommands();
			}
		}
	}

	public bool Downsample
	{
		get { return downsample; }
		set
		{
			if (downsample != value)
			{
				downsample = value;
				ValidateCommands();
			}
		}
	}

	#endregion

}
