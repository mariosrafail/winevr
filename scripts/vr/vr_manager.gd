extends Node
class_name WineVRVRManager

## Runtime support is discovered, never inferred from a headset/browser name.
## WebXR initialize() must be reached directly from the user's button press.
signal initialization_finished(success: bool)
signal session_state_changed(active: bool, mode: String)
signal capabilities_changed(capabilities: Dictionary)
signal focus_changed(focused: bool)
signal selection_requested(input_source_id: int)
signal reference_space_changed(reference_space: String)

const REQUEST_TIMEOUT_SECONDS: float = 25.0
# OpenXRInterface.SESSION_STATE_FOCUSED = 5 in Godot/OpenXR. The native class
# is absent from web templates, so shared scripts must not reference its type.
const OPENXR_SESSION_STATE_FOCUSED: int = 5

var is_vr_active: bool = false
var is_ar_active: bool = false
var is_focused: bool = true
var active_mode: String = "desktop"
var active_interface: XRInterface
var openxr_interface: XRInterface
var webxr_interface: XRInterface
var _webxr_initializing: bool = false
var _webxr_request_abandoned: bool = false
var _requested_mode: String = "vr"
var _capabilities: Dictionary = {"vr": false, "ar": false, "checking": false, "backend": "desktop"}
var _status_message: String = "Desktop mode is ready."
var _saved_vsync: int = DisplayServer.VSYNC_ENABLED
var _saved_physics_ticks: int = 60
var _saved_transparent_bg: bool = false
var _presentation_saved: bool = false
var _request_timer: Timer


func _ready() -> void:
	_request_timer = Timer.new()
	_request_timer.one_shot = true
	_request_timer.wait_time = REQUEST_TIMEOUT_SECONDS
	_request_timer.timeout.connect(_on_request_timeout)
	add_child(_request_timer)
	refresh_capabilities()


func refresh_capabilities() -> void:
	_capabilities = {"vr": false, "ar": false, "checking": false, "backend": "desktop"}
	if DisplayServer.get_name() == "headless":
		_status_message = "XR requires a display and a connected runtime."
		capabilities_changed.emit(get_capabilities())
		return
	if OS.has_feature("web"):
		webxr_interface = XRServer.find_interface("WebXR")
		if webxr_interface == null:
			_status_message = "This browser does not expose WebXR. Desktop and touch controls remain available."
			capabilities_changed.emit(get_capabilities())
			return
		_connect_webxr_signals()
		# Secure context is a WebXR prerequisite; localhost is also considered secure.
		var secure_context: Variant = JavaScriptBridge.eval("window.isSecureContext === true", true)
		if not bool(secure_context):
			_status_message = "Open the experience over HTTPS to check VR and AR availability."
			capabilities_changed.emit(get_capabilities())
			return
		_capabilities["backend"] = "WebXR"
		_capabilities["checking"] = true
		_capabilities["pending_modes"] = ["immersive-vr", "immersive-ar"]
		_status_message = "Checking this browser's VR and AR support…"
		webxr_interface.call("is_session_supported", "immersive-vr")
		webxr_interface.call("is_session_supported", "immersive-ar")
	else:
		openxr_interface = XRServer.find_interface("OpenXR")
		# OpenXR must initialize at engine startup (xr/openxr/enabled). Calling
		# initialize here cannot repair a missing loader or disconnected headset.
		if openxr_interface != null and openxr_interface.is_initialized():
			_connect_openxr_signals()
			_capabilities["backend"] = "OpenXR"
			var modes: Array = openxr_interface.get_supported_environment_blend_modes()
			_capabilities["vr"] = XRInterface.XR_ENV_BLEND_MODE_OPAQUE in modes
			_capabilities["ar"] = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND in modes or XRInterface.XR_ENV_BLEND_MODE_ADDITIVE in modes
			_capabilities["blend_modes"] = modes
			_status_message = "OpenXR headset ready. Choose VR or an available AR mode."
		else:
			_status_message = "No active OpenXR headset. Connect it and start its OpenXR runtime, then relaunch Grapes of Crete."
	capabilities_changed.emit(get_capabilities())


func get_capabilities() -> Dictionary:
	return _capabilities.duplicate(true)


func get_status_message() -> String:
	return _status_message


func get_session_mode() -> String:
	return active_mode


func get_interface_name() -> String:
	return active_interface.get_name() if active_interface != null else str(_capabilities.get("backend", "desktop"))


func supports_mode(mode: String) -> bool:
	return bool(_capabilities.get(mode.to_lower(), false))


func may_have_supported_interface(force_desktop_mode: bool = false) -> bool:
	return not force_desktop_mode and (supports_mode("vr") or supports_mode("ar"))


func initialize(force_desktop_mode: bool = false, requested_mode: String = "vr") -> bool:
	var mode: String = requested_mode.to_lower()
	if force_desktop_mode:
		end_session()
		_status_message = "Desktop mode is selected."
		return false
	if mode != "vr" and mode != "ar":
		_status_message = "Choose either VR or AR."
		return false
	if is_vr_active:
		# Switching WebXR session types needs a fresh user gesture after exit.
		return active_mode == mode
	if _webxr_initializing:
		return false
	if _webxr_request_abandoned:
		_status_message = "Κλείσε το προηγούμενο αίτημα πρόσβασης XR του περιηγητή και δοκίμασε ξανά."
		return false
	if not supports_mode(mode):
		_status_message = ("Still checking browser support. Try again shortly." if bool(_capabilities.get("checking", false)) else "This runtime does not currently support %s. Desktop mode is available." % mode.to_upper())
		return false
	_requested_mode = mode
	if OS.has_feature("web"):
		return await _initialize_webxr()
	return _initialize_openxr()


func _initialize_openxr() -> bool:
	if openxr_interface == null or not openxr_interface.is_initialized():
		_status_message = "The OpenXR runtime is no longer available."
		return false
	var blend_mode: int = XRInterface.XR_ENV_BLEND_MODE_OPAQUE
	if _requested_mode == "ar":
		blend_mode = _choose_ar_blend_mode(openxr_interface.get_supported_environment_blend_modes())
		if blend_mode < 0:
			_status_message = "This headset does not provide AR passthrough or an additive display."
			return false
	if not openxr_interface.set_environment_blend_mode(blend_mode):
		_status_message = "The runtime could not switch to the requested display mode."
		return false
	_begin_session(openxr_interface)
	return true


static func _choose_ar_blend_mode(modes: Array) -> int:
	if XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND in modes:
		return XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
	if XRInterface.XR_ENV_BLEND_MODE_ADDITIVE in modes:
		return XRInterface.XR_ENV_BLEND_MODE_ADDITIVE
	return -1


func _initialize_webxr() -> bool:
	webxr_interface.set("session_mode", "immersive-" + _requested_mode)
	webxr_interface.set("requested_reference_space_types", "bounded-floor,local-floor,local")
	# Floor tracking is optional so seated / local-reference devices can join.
	# Hand tracking is also optional; select events support pinch, gaze and taps.
	webxr_interface.set("required_features", "")
	webxr_interface.set("optional_features", "local-floor,bounded-floor,hand-tracking")
	_webxr_initializing = true
	_request_timer.start()
	if not webxr_interface.initialize():
		_resolve_web_request(false)
		_status_message = "The browser could not request an immersive session. Use a direct button press and allow XR access."
		return false
	# Do not await capability detection before initialize: that would lose the
	# browser's user activation and cause a valid permission request to fail.
	await initialization_finished
	return is_vr_active


func _begin_session(interface: XRInterface) -> void:
	if not _presentation_saved:
		_saved_vsync = DisplayServer.window_get_vsync_mode()
		_saved_physics_ticks = Engine.physics_ticks_per_second
		_saved_transparent_bg = get_viewport().transparent_bg
		_presentation_saved = true
	active_interface = interface
	active_mode = _requested_mode
	is_vr_active = true
	is_ar_active = active_mode == "ar"
	get_viewport().transparent_bg = is_ar_active
	get_viewport().use_xr = true
	if not OS.has_feature("web"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# Match the runtime if it reports a rate; 90 Hz is a comfortable default.
	var refresh_rate: float = 90.0
	if interface.has_method("get_display_refresh_rate"):
		var reported: float = float(interface.call("get_display_refresh_rate"))
		if reported >= 60.0:
			refresh_rate = reported
	Engine.physics_ticks_per_second = clampi(roundi(refresh_rate), 60, 144)
	_status_message = "%s active via %s." % [active_mode.to_upper(), interface.get_name()]
	_set_focus(_runtime_has_focus(interface))
	session_state_changed.emit(true, active_mode)
	print("[WineVR][XR] " + _status_message)


func end_session() -> void:
	# Keep native OpenXR initialized: its graphics integration is startup-only.
	# WebXR's browser session can be stopped and requested again with a click.
	var web_to_end: XRInterface = webxr_interface if OS.has_feature("web") else null
	_webxr_request_abandoned = _webxr_request_abandoned or _webxr_initializing
	_finish_session("Immersive session ended. Desktop mode is ready.")
	if web_to_end != null and web_to_end.is_initialized() and not _webxr_request_abandoned:
		web_to_end.uninitialize()
	# A browser permission prompt cannot be cancelled through Godot. Preserve
	# its initialized interface until its result arrives, so a late grant can
	# be closed, and do not overlap another request with that pending promise.


func _runtime_has_focus(interface: XRInterface) -> bool:
	if interface.get_name() == "OpenXR" and interface.has_method("get_session_state"):
		return int(interface.call("get_session_state")) == OPENXR_SESSION_STATE_FOCUSED
	if interface.get_name() == "WebXR":
		return str(interface.get("visibility_state")) == "visible"
	return false


func _finish_session(message: String) -> void:
	var had_session: bool = is_vr_active
	is_vr_active = false
	is_ar_active = false
	active_mode = "desktop"
	active_interface = null
	get_viewport().use_xr = false
	if _presentation_saved:
		get_viewport().transparent_bg = _saved_transparent_bg
		Engine.physics_ticks_per_second = _saved_physics_ticks
		if DisplayServer.get_name() != "headless" and not OS.has_feature("web"):
			DisplayServer.window_set_vsync_mode(_saved_vsync)
		_presentation_saved = false
	_status_message = message
	_resolve_web_request(false)
	_set_focus(true)
	if had_session:
		session_state_changed.emit(false, "desktop")


func _connect_signal(source: Object, signal_name: StringName, target: Callable) -> void:
	if source.has_signal(signal_name) and not source.is_connected(signal_name, target):
		source.connect(signal_name, target)


func _connect_webxr_signals() -> void:
	_connect_signal(webxr_interface, &"session_supported", _on_webxr_session_supported)
	_connect_signal(webxr_interface, &"session_started", _on_webxr_session_started)
	_connect_signal(webxr_interface, &"session_failed", _on_webxr_session_failed)
	_connect_signal(webxr_interface, &"session_ended", _on_webxr_session_ended)
	_connect_signal(webxr_interface, &"select", _on_webxr_select)
	_connect_signal(webxr_interface, &"visibility_state_changed", _on_webxr_visibility_changed)
	_connect_signal(webxr_interface, &"reference_space_reset", _on_reference_space_reset)


func _connect_openxr_signals() -> void:
	_connect_signal(openxr_interface, &"session_stopping", _on_openxr_stopped)
	_connect_signal(openxr_interface, &"session_loss_pending", _on_openxr_stopped)
	_connect_signal(openxr_interface, &"instance_exiting", _on_openxr_stopped)
	_connect_signal(openxr_interface, &"session_focussed", _on_openxr_focused)
	_connect_signal(openxr_interface, &"session_visible", _on_openxr_unfocused)
	_connect_signal(openxr_interface, &"session_synchronized", _on_openxr_unfocused)


func _on_webxr_session_supported(session_mode: String, supported: bool) -> void:
	var mode: String = session_mode.trim_prefix("immersive-")
	if mode != "vr" and mode != "ar":
		return
	_capabilities[mode] = supported
	var pending: Array = _capabilities.get("pending_modes", []) as Array
	pending.erase(session_mode)
	_capabilities["pending_modes"] = pending
	_capabilities["checking"] = not pending.is_empty()
	if pending.is_empty():
		_status_message = "Choose an available VR or AR mode." if supports_mode("vr") or supports_mode("ar") else "This browser has no available immersive VR or AR session. Explore using mouse or touch."
	capabilities_changed.emit(get_capabilities())


func _on_webxr_session_started() -> void:
	# Ignore a delayed result after cancellation/timeout, and close its session.
	if not _webxr_initializing:
		_webxr_request_abandoned = false
		if webxr_interface != null:
			webxr_interface.uninitialize()
		return
	_begin_session(webxr_interface)
	reference_space_changed.emit(str(webxr_interface.get("reference_space_type")))
	_resolve_web_request(true)


func _on_webxr_session_failed(message: String = "") -> void:
	_webxr_request_abandoned = false
	_finish_session("XR access was declined or unavailable. " + message)


func _on_webxr_session_ended() -> void:
	_webxr_request_abandoned = false
	_finish_session("Immersive session ended. Desktop mode is ready.")


func _resolve_web_request(success: bool) -> void:
	if _request_timer != null:
		_request_timer.stop()
	if _webxr_initializing:
		_webxr_initializing = false
		initialization_finished.emit(success)


func _on_request_timeout() -> void:
	_webxr_request_abandoned = _webxr_initializing
	_finish_session("The XR request timed out. Close any pending browser prompt and try again.")


func _on_webxr_select(input_source_id: int) -> void:
	if is_vr_active and is_focused:
		selection_requested.emit(input_source_id)


func _on_webxr_visibility_changed() -> void:
	_set_focus(str(webxr_interface.get("visibility_state")) == "visible")


func _on_reference_space_reset() -> void:
	if webxr_interface != null and is_vr_active:
		reference_space_changed.emit(str(webxr_interface.get("reference_space_type")))


func _on_openxr_stopped() -> void:
	_finish_session("The headset session stopped. Desktop mode is ready.")


func _on_openxr_focused() -> void:
	_set_focus(true)


func _on_openxr_unfocused() -> void:
	_set_focus(false)


func _set_focus(focused: bool) -> void:
	if is_focused == focused:
		return
	is_focused = focused
	focus_changed.emit(focused)


func _exit_tree() -> void:
	if is_vr_active or _webxr_initializing:
		end_session()
