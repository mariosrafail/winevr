extends Node
class_name WineVRVRManager

var is_vr_active: bool = false
var openxr_interface: XRInterface


func initialize(force_desktop_mode: bool = false) -> bool:
	is_vr_active = false

	# Test without a headset by enabling WineryInterior.force_desktop_mode in the inspector.
	if force_desktop_mode:
		get_viewport().use_xr = false
		print("[WineVR][VR] force_desktop_mode enabled, using desktop mode")
		return false

	openxr_interface = XRServer.find_interface("OpenXR")
	if openxr_interface == null:
		get_viewport().use_xr = false
		print("[WineVR][VR] OpenXR unavailable, using desktop mode")
		return false

	print("[WineVR][VR] OpenXR available")
	if openxr_interface.is_initialized() or openxr_interface.initialize():
		get_viewport().use_xr = true
		is_vr_active = true
		print("[WineVR][VR] OpenXR initialized")
		return true

	get_viewport().use_xr = false
	print("[WineVR][VR] OpenXR unavailable, using desktop mode")
	return false
