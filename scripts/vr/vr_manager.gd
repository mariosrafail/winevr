extends Node
class_name WineVRVRManager

signal initialization_finished(success: bool)

var is_vr_active: bool = false
var active_interface: XRInterface
var openxr_interface: XRInterface
var webxr_interface: XRInterface
var _webxr_initializing: bool = false


func initialize(force_desktop_mode: bool = false) -> bool:
	is_vr_active = false

	# Test without a headset by enabling WineryInterior.force_desktop_mode in the inspector.
	if force_desktop_mode:
		get_viewport().use_xr = false
		print("[WineVR][VR] force_desktop_mode enabled, using desktop mode")
		return false

	if OS.has_feature("web"):
		return await _initialize_webxr()

	return _initialize_openxr()


func may_have_supported_interface(force_desktop_mode: bool = false) -> bool:
	if force_desktop_mode:
		return false
	if OS.has_feature("web"):
		return true
	return XRServer.find_interface("OpenXR") != null or XRServer.find_interface("WebXR") != null


func _initialize_openxr() -> bool:
	openxr_interface = XRServer.find_interface("OpenXR")
	if openxr_interface == null:
		get_viewport().use_xr = false
		print("[WineVR][VR] OpenXR unavailable, using desktop mode")
		return false

	print("[WineVR][VR] OpenXR available")
	if openxr_interface.is_initialized() or openxr_interface.initialize():
		get_viewport().use_xr = true
		is_vr_active = true
		active_interface = openxr_interface
		print("[WineVR][VR] OpenXR initialized")
		return true

	get_viewport().use_xr = false
	print("[WineVR][VR] OpenXR unavailable, using desktop mode")
	return false


func _initialize_webxr() -> bool:
	webxr_interface = XRServer.find_interface("WebXR")
	if webxr_interface == null:
		get_viewport().use_xr = false
		print("[WineVR][VR] WebXR unavailable, using desktop mode")
		return false

	_connect_webxr_signal("session_started", _on_webxr_session_started)
	_connect_webxr_signal("session_failed", _on_webxr_session_failed)
	_connect_webxr_signal("session_ended", _on_webxr_session_ended)

	webxr_interface.set("session_mode", "immersive-vr")
	webxr_interface.set("requested_reference_space_types", "bounded-floor, local-floor, local")
	webxr_interface.set("required_features", "local-floor")
	webxr_interface.set("optional_features", "bounded-floor, hand-tracking")

	_webxr_initializing = true
	if not webxr_interface.initialize():
		_webxr_initializing = false
		get_viewport().use_xr = false
		print("[WineVR][VR] WebXR session request failed, using desktop mode")
		return false

	print("[WineVR][VR] WebXR session requested")
	await initialization_finished
	return is_vr_active


func _connect_webxr_signal(signal_name: String, target: Callable) -> void:
	if webxr_interface == null or not webxr_interface.has_signal(signal_name):
		return
	if not webxr_interface.is_connected(signal_name, target):
		webxr_interface.connect(signal_name, target)


func _on_webxr_session_started() -> void:
	get_viewport().use_xr = true
	is_vr_active = true
	active_interface = webxr_interface
	print("[WineVR][VR] WebXR initialized")
	if _webxr_initializing:
		_webxr_initializing = false
		initialization_finished.emit(true)


func _on_webxr_session_failed(message: String = "") -> void:
	get_viewport().use_xr = false
	is_vr_active = false
	active_interface = null
	print("[WineVR][VR] WebXR unavailable, using desktop mode%s" % (": " + message if not message.is_empty() else ""))
	if _webxr_initializing:
		_webxr_initializing = false
		initialization_finished.emit(false)


func _on_webxr_session_ended() -> void:
	get_viewport().use_xr = false
	is_vr_active = false
	active_interface = null
	print("[WineVR][VR] WebXR session ended, using desktop mode")
	if _webxr_initializing:
		_webxr_initializing = false
		initialization_finished.emit(false)
