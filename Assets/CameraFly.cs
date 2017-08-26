using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CameraFly : MonoBehaviour
{
	[SerializeField] private float lookSpeed = 1;
	[SerializeField] private float moveSpeed = 1;
	[SerializeField] private float tiltSpeed = 1;

	// Use this for initialization
	void Start ()
	{
		Cursor.lockState = CursorLockMode.Locked;
		Cursor.visible = false;
	}
	
	// Update is called once per frame
	void Update ()
	{
		Quaternion tiltRotation = Quaternion.identity;
		if (Input.GetKey(KeyCode.Q))
		{
			tiltRotation = Quaternion.AngleAxis(-tiltSpeed * lookSpeed * Time.deltaTime, Vector3.forward);
		}
		else if (Input.GetKey(KeyCode.E))
		{
			tiltRotation = Quaternion.AngleAxis(tiltSpeed * lookSpeed * Time.deltaTime, Vector3.forward);
		}

		transform.localRotation *= tiltRotation * Quaternion.AngleAxis(Input.GetAxis("Mouse X") * lookSpeed, Vector3.up) * Quaternion.AngleAxis(Input.GetAxis("Mouse Y") * lookSpeed, Vector3.left);
		transform.position += transform.forward * Input.GetAxis("Vertical") * Time.deltaTime * moveSpeed + transform.right * Time.deltaTime * moveSpeed * Input.GetAxis("Horizontal");
		if (Input.GetKey(KeyCode.Space))
		{
			transform.position += transform.up * Time.deltaTime * moveSpeed;
		}
		else if (Input.GetKey(KeyCode.LeftShift))
		{
			transform.position -= transform.up * Time.deltaTime * moveSpeed;
		}
	}
}
