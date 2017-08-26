using System;
using System.IO;
using Klak.Motion;
using MiniEngineAO;
using UnityEngine;
using AmbientOcclusion = UnityStandardAssets.CinematicEffects.AmbientOcclusion;

public class AOSwitcher : MonoBehaviour
{
	[SerializeField] private ConstantMotion motion;
	[SerializeField] private BrownianMotion brownianMotion;
	[SerializeField] private NNAO nnao;
	[SerializeField] private AmbientOcclusion ambientOcclusion;
	[SerializeField] private MiniEngineAO.AmbientOcclusion miniAo;
	[SerializeField] private Camera normalCamera;

	private Camera[] cameras;

	float deltaTime = 0.0f;
	private int current;

	private void Awake()
	{
		cameras = new Camera[]
		{
			nnao.GetComponent<Camera>(),
			ambientOcclusion.GetComponent<Camera>(),
			miniAo.GetComponent<Camera>(),
			normalCamera
		};
	}

	private void Update()
	{
		deltaTime += (Time.deltaTime - deltaTime) * 0.1f;
	}

	private void OnGUI()
	{
		float msec = deltaTime * 1000.0f;
		float fps = 1.0f / deltaTime;
		string text = string.Format("{0:0.0} ms ({1:0.} fps)", msec, fps);
		GUILayout.Label(text);

		if (GUILayout.Button(cameras[current].name))
		{
			current++;
			if (current >= cameras.Length) current = 0;
			for (int i = 0; i < cameras.Length; i++)
			{
				cameras[i].enabled = current == i;
			}
		}

		nnao.Downsample = GUILayout.Toggle(nnao.Downsample, "Downsample");
		ambientOcclusion.settings.downsampling = nnao.Downsample;
		
		if (motion != null) motion.enabled = GUILayout.Toggle(motion.enabled, "Rotate");
		if (brownianMotion != null) brownianMotion.enabled = motion.enabled;
		nnao.Debug = GUILayout.Toggle(nnao.Debug, "Debug");
		ambientOcclusion.settings.debug = nnao.Debug;
		miniAo.Debug = nnao.Debug ? 17 : 0;

		if (GUILayout.Button("Save Screenshot"))
		{
			ScreenCapture.CaptureScreenshot(Application.dataPath.Replace("Assets","Screenshots") + "/Screenshot-"+DateTime.UtcNow.ToString("MM-dd-yy-H-mm-ss")+".png");
		}
	}
}
