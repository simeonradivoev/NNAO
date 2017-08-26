using UnityEditor;
using UnityEditorInternal;
using UnityEngine;

[CustomEditor(typeof(NNAO))]
public class NNAOEditor : Editor
{
	private SerializedProperty samples;
	private SerializedProperty radius;
	private SerializedProperty intensity;
	private SerializedProperty contrast;
	private SerializedProperty debug;
	private SerializedProperty blurQuality;
	private SerializedProperty maxBlurRadius;
	private SerializedProperty normalBias;
	private SerializedProperty depthBias;
	private SerializedProperty downsample;

	private void OnEnable()
	{
		radius = serializedObject.FindProperty("radius");
		intensity = serializedObject.FindProperty("intensity");
		contrast = serializedObject.FindProperty("contrast");
		debug = serializedObject.FindProperty("debug");
		blurQuality = serializedObject.FindProperty("blurQuality");
		maxBlurRadius = serializedObject.FindProperty("maxBlurRadius");
		normalBias = serializedObject.FindProperty("normalBias");
		depthBias = serializedObject.FindProperty("depthBias");
		downsample = serializedObject.FindProperty("downsample");
	}

	public override void OnInspectorGUI()
	{
		bool needsValidation = false;
		var nnao = (NNAO)target;
		serializedObject.UpdateIfRequiredOrScript();

		EditorGUI.BeginChangeCheck();
		EditorGUILayout.PropertyField(downsample);
		needsValidation |= EditorGUI.EndChangeCheck();
		EditorGUILayout.PropertyField(radius);
		EditorGUILayout.PropertyField(intensity);
		EditorGUILayout.PropertyField(contrast);

		EditorGUI.BeginChangeCheck();
		EditorGUILayout.PropertyField(debug);
		needsValidation |= EditorGUI.EndChangeCheck();
		
		EditorGUILayout.LabelField(new GUIContent("Blur"));
		EditorGUILayout.PropertyField(blurQuality);
		EditorGUI.BeginChangeCheck();
		EditorGUILayout.PropertyField(maxBlurRadius);
		needsValidation |= EditorGUI.EndChangeCheck();
		EditorGUILayout.PropertyField(normalBias);
		EditorGUILayout.PropertyField(depthBias);

		serializedObject.ApplyModifiedProperties();

		if(needsValidation) nnao.ValidateCommands();
	}
}
