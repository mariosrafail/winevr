extends SceneTree

const MANAGER: Script = preload("res://scripts/vr/vr_manager.gd")
const RIG: PackedScene = preload("res://scenes/VRPlayerRig.tscn")
const TELEPORT: Script = preload("res://scripts/vr/vr_teleport_controller.gd")
var _failures: Array[String] = []
var _session_events: Array[bool] = []
var _request_events: Array[bool] = []

class FocusRuntime:
	extends XRInterfaceExtension
	var backend: StringName = &"OpenXR"
	var state: int = OpenXRInterface.SESSION_STATE_VISIBLE
	var visibility_state: String = "visible-blurred"
	func _get_name() -> StringName:
		return backend
	func get_session_state() -> int:
		return state

class NavigationOwner:
	extends Node3D
	var selected_mode: String = ""
	var exit_requested: bool = false
	func is_ar_active() -> bool:
		return false
	func set_presentation_mode(mode: String) -> void:
		selected_mode = mode
	func end_immersive_mode() -> void:
		exit_requested = true


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, description: String) -> void:
	if not value:
		_failures.append(description)
		push_error("[XRQA] " + description)


func _run() -> void:
	var manager: WineVRVRManager = MANAGER.new() as WineVRVRManager
	root.add_child(manager)
	manager.session_state_changed.connect(func(active: bool, _mode: String) -> void: _session_events.append(active))
	manager.initialization_finished.connect(func(success: bool) -> void: _request_events.append(success))
	_check(not manager.supports_mode("ar"), "Headless run does not falsely advertise AR")
	_check(not manager.supports_mode("vr"), "Headless run does not falsely advertise VR")
	_check(not await manager.initialize(true), "Forced desktop never starts an XR session")
	_check(not await manager.initialize(false, "ar"), "Unsupported AR safely keeps the desktop")
	_check(MANAGER._choose_ar_blend_mode([0]) == -1, "Opaque-only runtimes cannot use AR")
	_check(MANAGER._choose_ar_blend_mode([0, 1]) == 1, "Additive displays can use AR")
	_check(MANAGER._choose_ar_blend_mode([0, 1, 2]) == 2, "Alpha passthrough is preferred when supported")
	manager._capabilities = {"vr": false, "ar": false, "checking": true, "pending_modes": ["immersive-vr", "immersive-ar"]}
	manager._on_webxr_session_supported("immersive-ar", true)
	_check(manager.supports_mode("ar") and not manager.supports_mode("vr"), "AR support does not imply VR support")
	_check(bool(manager.get_capabilities()["checking"]), "Detection waits for both independent browser results")
	manager._on_webxr_session_supported("immersive-vr", false)
	_check(not bool(manager.get_capabilities()["checking"]), "Browser capability detection completes")
	var previous_ticks: int = Engine.physics_ticks_per_second
	manager.is_vr_active = true
	manager.is_ar_active = true
	manager.active_mode = "ar"
	manager._presentation_saved = true
	manager._saved_physics_ticks = previous_ticks
	manager._saved_transparent_bg = false
	Engine.physics_ticks_per_second = 90
	root.transparent_bg = true
	manager._on_webxr_session_ended()
	_check(not manager.is_vr_active and manager.active_mode == "desktop", "Browser exit resets the active mode")
	_check(not root.transparent_bg and Engine.physics_ticks_per_second == previous_ticks, "Browser exit restores render and physics settings")
	manager._on_webxr_session_ended()
	_check(_session_events == [false], "Repeated exit callback emits one state transition")
	manager._webxr_initializing = true
	manager._on_request_timeout()
	_check(manager._webxr_request_abandoned, "Timed-out permission prompt remains tracked until the browser settles it")
	_check(not await manager.initialize(false, "ar"), "Retry cannot overlap an unresolved browser permission request")
	manager._on_webxr_session_failed("late failure")
	_check(not manager._webxr_request_abandoned, "Browser refusal releases the pending request latch")
	_check(_request_events == [false], "Timeout plus delayed failure resolves a pending request exactly once")
	var focus_runtime: FocusRuntime = FocusRuntime.new()
	_check(not manager._runtime_has_focus(focus_runtime), "Visible OpenXR output alone does not grant input focus")
	focus_runtime.state = OpenXRInterface.SESSION_STATE_FOCUSED
	_check(manager._runtime_has_focus(focus_runtime), "Focused native runtime permits input")
	focus_runtime.backend = &"WebXR"
	_check(not manager._runtime_has_focus(focus_runtime), "Browser permission/system overlay blocks input at session start")
	focus_runtime.visibility_state = "visible"
	_check(manager._runtime_has_focus(focus_runtime), "Visible browser session permits input")
	manager.refresh_capabilities()

	var navigation_owner: NavigationOwner = NavigationOwner.new()
	root.add_child(navigation_owner)
	var rig: WineVRPlayerRig = RIG.instantiate() as WineVRPlayerRig
	navigation_owner.add_child(rig)
	rig.xr_camera.position = Vector3(0.35, 1.65, 0.3)
	rig.set_xr_enabled(true)
	rig.set_input_enabled(true)
	_check(rig._navigation != null, "Immersive mode creates an in-world navigation menu")
	var buttons: Array = rig._navigation.get("_buttons") as Array
	_check(buttons.size() == 4, "World-space menu exposes collection, vineyard, cellar and exit")
	(buttons[1] as Interactable).interact()
	_check(navigation_owner.selected_mode == "vineyard", "Vineyard button performs navigation")
	(buttons[0] as Interactable).interact()
	_check(navigation_owner.selected_mode == "museum", "Collection button performs navigation")
	(buttons[2] as Interactable).interact()
	_check(navigation_owner.selected_mode == "cellar", "Cellar button performs navigation")
	(buttons[3] as Interactable).interact()
	_check(navigation_owner.exit_requested, "Exit button requests a real immersive session exit")
	var head_before: Vector3 = rig.xr_camera.global_position
	rig.snap_turn(deg_to_rad(30.0))
	_check(rig.xr_camera.global_position.distance_to(head_before) < 0.0001, "Snap turn rotates around the real headset position")
	rig.apply_reference_space("local")
	var local_height: float = rig.position.y
	rig.reset_origin(Vector3(0, 0, 1.55), Vector3.ZERO)
	_check(is_equal_approx(rig.position.y, local_height), "Changing presentation preserves local-space eye height")
	rig.apply_reference_space("local")
	_check(is_equal_approx(rig.position.y, local_height), "Reference-space reset never accumulates eye height")
	rig.apply_reference_space("local-floor")
	_check(is_zero_approx(rig.position.y), "Floor reference restores the original rig height")
	rig.set_xr_enabled(true, true)
	var ar_transform: Transform3D = rig.transform
	rig.snap_turn(PI * 0.5)
	_check(rig.transform.is_equal_approx(ar_transform), "Artificial snap locomotion is disabled in AR")
	rig.set_xr_enabled(true, false)
	rig.set_input_enabled(true)
	rig._physics_process(0.0)
	_check(rig.interaction_ray.global_transform.is_equal_approx(rig.xr_camera.global_transform), "Missing controllers use a real gaze ray")
	rig.set_input_enabled(false)
	_check(not rig.interaction_ray.enabled, "Focus/modal gating disables interaction")

	var action_map: OpenXRActionMap = load("res://scripts/vr/openxr_action_map.tres") as OpenXRActionMap
	_check(action_map != null and action_map.get_interaction_profile_count() >= 8, "Cross-vendor OpenXR bindings are included")
	for profile in ["/interaction_profiles/khr/simple_controller", "/interaction_profiles/oculus/touch_controller", "/interaction_profiles/valve/index_controller", "/interaction_profiles/bytedance/pico4_controller"]:
		_check(action_map.find_interaction_profile(profile) != null, "Action map includes " + profile)

	# Exercise the real physics ray path with a registered tracked controller.
	var tracker: XRControllerTracker = XRControllerTracker.new()
	tracker.name = &"left_hand"
	tracker.type = XRServer.TRACKER_CONTROLLER
	tracker.set_pose(&"aim", Transform3D(Basis.IDENTITY, Vector3(-0.2, 1.2, 0)), Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	XRServer.add_tracker(tracker)
	rig.transform = Transform3D.IDENTITY
	var floor_body: StaticBody3D = _body(Vector3(8, 0.1, 8), Vector3(0, -0.05, 0), 8)
	floor_body.add_to_group("vr_teleport_floor")
	root.add_child(floor_body)
	var teleport: VRTeleportController = TELEPORT.new() as VRTeleportController
	root.add_child(teleport)
	teleport.setup(rig, rig.xr_camera, rig.left_controller, rig.right_controller)
	teleport.set_enabled(true)
	await physics_frame
	await physics_frame
	teleport._update_target()
	_check(teleport._target_valid, "Ballistic arc reaches a clear authored teleport floor")
	var wall: StaticBody3D = _body(Vector3(0.7, 2.0, 0.2), Vector3(-0.2, 1.0, -1.0), 1)
	root.add_child(wall)
	await physics_frame
	await physics_frame
	teleport._update_target()
	_check(not teleport._target_valid, "Teleport arc cannot pass through a solid obstacle")
	wall.queue_free()
	await physics_frame
	await physics_frame
	teleport._update_target()
	_check(teleport._target_valid, "Removing the obstacle restores a valid floor target")
	teleport._on_button_pressed("trigger_click", rig.left_controller)
	_check(not teleport._aiming, "A sole left controller reserves its trigger for selection")
	teleport._on_input_vector2_changed("primary", Vector2(0, 1), rig.left_controller)
	_check(teleport._aiming, "A sole left controller can still aim teleport with its stick")
	var right_tracker: XRControllerTracker = XRControllerTracker.new()
	right_tracker.name = &"right_hand"
	right_tracker.type = XRServer.TRACKER_CONTROLLER
	right_tracker.set_pose(&"aim", Transform3D(Basis.IDENTITY, Vector3(0.2, 1.2, 0)), Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	XRServer.add_tracker(right_tracker)
	await physics_frame
	var before_loss: Transform3D = rig.global_transform
	XRServer.remove_tracker(tracker)
	await physics_frame
	await physics_frame
	_check(teleport._aim_controller == rig.right_controller and not teleport._aiming, "Losing the left controller switches to right and cancels the held arc")
	_check(rig.global_transform.is_equal_approx(before_loss), "Controller loss never commits a pending teleport")
	teleport._on_button_pressed("trigger_click", rig.right_controller)
	_check(not teleport._aiming, "Right primary trigger is reserved for selection")
	teleport._on_button_pressed("by_button", rig.right_controller)
	_check(teleport._aiming, "A right-only controller can aim teleport with its secondary button")
	XRServer.remove_tracker(right_tracker)
	await physics_frame
	await physics_frame
	_check(not teleport._aiming and not teleport._target_valid, "Losing all tracking clears the pending target")
	teleport.set_enabled(false)
	_check(not teleport._marker.visible and not teleport._ray_mesh_instance.visible, "Disabling teleport clears all aiming visuals")
	rig.set_xr_enabled(false)
	_check(not rig.visible and not rig.interaction_ray.enabled, "Exiting XR hides and disables the tracked rig")
	manager.queue_free()
	rig.queue_free()
	navigation_owner.queue_free()
	teleport.queue_free()
	floor_body.queue_free()
	await process_frame
	print("[XRQA] ", "PASS" if _failures.is_empty() else "FAIL: " + str(_failures))
	quit(0 if _failures.is_empty() else 1)


func _body(size: Vector3, at: Vector3, layer: int) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = at
	body.collision_layer = layer
	body.collision_mask = 0
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body
