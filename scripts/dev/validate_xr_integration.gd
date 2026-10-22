extends Node

## Full-scene regression harness. Runtime callbacks are simulated; rendering
## and tracking on a physical headset still require device acceptance testing.
var failures: Array[String] = []
var checks: int = 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("[XRIntegration] " + message)


func _run() -> void:
	if "--xr-capture" in OS.get_cmdline_user_args():
		DisplayServer.window_set_size(Vector2i(1280, 800))
	var app: Node = (load("res://scenes/WineVRExperience.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(app)
	await get_tree().create_timer(1.0).timeout
	var winery: WineryInteriorController = app.get_node("WineryInterior") as WineryInteriorController
	var manager: WineVRVRManager = winery.get("_vr_manager") as WineVRVRManager
	var rig: WineVRPlayerRig = winery.vr_player_rig as WineVRPlayerRig
	var museum: GrapeMuseum = winery.get("_grape_museum") as GrapeMuseum
	var menu: MainMenuOverlayController = app.get("_main_menu") as MainMenuOverlayController
	_check(not winery.is_vr_active() and not get_viewport().use_xr, "No headset keeps complete scene in desktop mode")
	manager._capabilities = {"vr": true, "ar": false, "checking": false, "backend": "simulation"}
	manager.capabilities_changed.emit(manager.get_capabilities())
	_check(not menu.vr_button.disabled and menu.ar_button.disabled, "Native capability signals independently update menu VR/AR availability")
	manager._capabilities = {"vr": false, "ar": true, "checking": false, "backend": "simulation"}
	manager.capabilities_changed.emit(manager.get_capabilities())
	_check(menu.vr_button.disabled and not menu.ar_button.disabled, "AR-only capability does not advertise VR in the app")
	manager.refresh_capabilities()
	menu.museum_button.pressed.emit()
	await get_tree().create_timer(0.7).timeout
	_check(winery.camera.current and museum.controls_enabled, "Desktop collection is active before simulated session")
	_simulate_session(manager, "vr")
	rig.xr_camera.position = Vector3(0.0, 1.65, 0.0)
	rig.reset_origin(Vector3(0.0, 0.0, 1.55), Vector3.ZERO)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(winery.is_vr_active() and rig.visible and winery.vr_camera.current, "Session callback activates the tracked camera and rig")
	_check(not await winery.request_immersive_mode("ar"), "An existing VR session cannot report a successful switch to AR")
	_check(not winery.camera.current and winery.vr_interaction_ray.enabled, "XR input replaces the desktop camera")
	_check(rig._navigation != null, "Session callback provides navigation inside the headset")
	_check(not bool(winery.get("_vr_guided_tasting").get("_enabled")), "Legacy tasting panel cannot obscure collection navigation")
	_check(not bool(winery.get("_vr_vial_hotspots").get("_enabled")), "Legacy vial hotspots remain hidden without a vial")
	winery.set("_vr_trigger_was_pressed", true)
	manager._set_focus(false)
	_check(not bool(winery.get("_vr_trigger_was_pressed")), "System-menu focus loss clears the previous trigger press")
	_check(not winery.vr_interaction_ray.enabled and not museum.controls_enabled, "System-menu focus loss disables selection and grabbing")
	_check(not bool(winery.get("_vr_teleport_system").get("_enabled")), "Focus loss also disables locomotion")
	manager._set_focus(true)
	_check(winery.vr_interaction_ray.enabled and museum.controls_enabled, "Returning focus restores XR input")
	winery.set_desktop_modal_context("qa_modal")
	_check(not winery.vr_interaction_ray.enabled and not museum.controls_enabled, "Opening a modal immediately blocks XR selection and grabbing")
	_check(not bool(winery.get("_vr_teleport_system").get("_enabled")), "Opening a modal cancels teleport immediately")
	manager._set_focus(false)
	manager._set_focus(true)
	_check(not winery.vr_interaction_ray.enabled and not museum.controls_enabled, "Returning headset focus cannot bypass an open modal")
	var last_interaction: int = int(winery.get("_last_xr_interaction_msec"))
	winery._on_vr_controller_button_pressed("trigger_click")
	_check(int(winery.get("_last_xr_interaction_msec")) == last_interaction, "Controller selection is rejected behind a modal")
	winery.set_desktop_modal_context("")
	_check(winery.vr_interaction_ray.enabled and museum.controls_enabled, "Closing a modal restores focused XR controls")
	_check(not winery._is_vr_interact_button("trigger_touch"), "Resting a finger on a capacitive trigger does not select")
	_check(winery._is_vr_interact_button("select_button"), "Khronos simple controllers can select")
	manager.reference_space_changed.emit("local")
	winery.reset_view()
	_check(is_equal_approx(rig.position.y, rig.seated_eye_height), "Scene reset preserves WebXR local-reference eye height")
	manager.reference_space_changed.emit("local-floor")
	# Drive the actual ray -> hover -> controller action -> Interactable path.
	# This includes reentrant presentation changes and deleting the exit menu.
	rig.set_physics_process(false)
	var left_tracker: XRControllerTracker = _tracker("left_hand", Vector3(-0.2, 1.2, 0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(rig.get_interaction_controller() == rig.left_controller, "Native selection falls back to the sole tracked left controller")
	museum.inspect_exhibit("vidiano")
	await get_tree().create_timer(0.4).timeout
	var navigation: Node3D = rig._navigation
	var buttons: Array = navigation.get("_buttons") as Array
	await _aim_at(winery, buttons[1] as Interactable)
	rig.left_controller.button_pressed.emit("trigger_click")
	await get_tree().process_frame
	_check(winery.presentation_mode == "vineyard", "XR menu navigates while an exhibit is selected")
	_check(not museum.is_inspecting() and museum.physics.grabbed_id.is_empty(), "Navigation clears inspection and physical grasp")
	var right_tracker: XRControllerTracker = _tracker("right_hand", Vector3(0.2, 1.2, 0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(rig.get_interaction_controller() == rig.right_controller, "Restored right tracking becomes the primary selection hand")
	await get_tree().create_timer(0.28).timeout
	await _aim_at(winery, buttons[2] as Interactable)
	rig.left_controller.button_pressed.emit("trigger_click")
	_check(winery.presentation_mode == "vineyard", "Left trigger cannot select while the tracked right hand owns the ray")
	rig.right_controller.button_pressed.emit("trigger_click")
	await get_tree().process_frame
	var cellar: Node3D = winery.get("_cellar") as Node3D
	_check(winery.presentation_mode == "cellar" and cellar != null and cellar.visible, "XR menu enters the cellar from the vineyard")
	var vineyard: Node3D = winery.get("_vineyard") as Node3D
	_check(vineyard != null and not vineyard.visible and not museum.visible, "Cellar transition hides both previous sub-scenes")
	_check(not museum.controls_enabled, "Hidden museum cannot grab while exploring the cellar")
	var hidden_room_collisions: int = 0
	for collider: StaticBody3D in museum.find_children("*", "StaticBody3D", true, false):
		if collider.collision_layer != 0:
			hidden_room_collisions += 1
	_check(hidden_room_collisions == 0, "Presentation changes cannot restore hidden museum floor or wall colliders")
	_check(rig._navigation == navigation and rig.visible and winery.vr_camera.current, "Cellar navigation preserves the active XR rig and menu")
	var teleport: VRTeleportController = winery.get("_vr_teleport_system") as VRTeleportController
	_check(cellar != null and teleport.bounds_min == cellar.call("get_bounds_min") and teleport.bounds_max == cellar.call("get_bounds_max"), "Cellar navigation applies its own teleport bounds")
	await _capture("xr_cellar_menu")
	await get_tree().create_timer(0.28).timeout
	await _aim_at(winery, buttons[0] as Interactable)
	winery._on_vr_controller_button_pressed("select_button")
	await get_tree().process_frame
	_check(winery.presentation_mode == "museum", "Simple-controller selection returns to the collection")
	_check(cellar != null and not cellar.visible and museum.controls_enabled, "Returning from the cellar restores collection interaction")
	museum.inspect_exhibit("liatiko")
	await get_tree().create_timer(0.4).timeout
	await _aim_at(winery, buttons[3] as Interactable)
	winery._on_vr_controller_button_pressed("trigger_click")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not winery.is_vr_active() and not rig.visible, "Exit menu ends the full-scene XR session")
	_check(rig._navigation == null and not is_instance_valid(navigation), "Exit safely releases the currently selected menu after callback")
	_check(not winery.vr_interaction_ray.enabled and not museum.is_inspecting(), "Exit clears the XR ray and inspection")
	_check(menu.is_open(), "Desktop navigation is accessible after headset exit")
	XRServer.remove_tracker(left_tracker)
	XRServer.remove_tracker(right_tracker)
	# AR uses the same complete-scene lifecycle and restores opaque presentation.
	menu.museum_button.pressed.emit()
	await get_tree().create_timer(0.5).timeout
	_simulate_session(manager, "ar")
	await get_tree().physics_frame
	_check(winery.is_ar_active() and get_viewport().transparent_bg, "AR callback enables transparent collection presentation")
	_check(winery.world_environment.environment.background_mode == Environment.BG_COLOR, "AR uses an explicit clear background")
	_check(winery.world_environment.environment.background_color.a == 0.0, "AR background has zero alpha")
	await _capture("xr_ar_menu")
	_check(not bool(winery.get("_vr_teleport_system").get("_enabled")), "AR disables artificial teleportation")
	var before_mode: String = winery.presentation_mode
	winery.set_presentation_mode("vineyard")
	_check(winery.presentation_mode == before_mode, "AR cannot replace the transparent collection with opaque terrain")
	winery.set_presentation_mode("cellar")
	_check(winery.presentation_mode == before_mode, "AR cannot enter the opaque cellar")
	manager._on_webxr_session_ended()
	await get_tree().process_frame
	_check(not winery.is_ar_active() and not get_viewport().transparent_bg, "Browser exit restores the desktop background")
	_check(winery.world_environment.environment.background_color.a > 0.99, "Museum environment is restored after AR")
	manager._on_webxr_session_ended()
	_check(not winery.is_vr_active(), "Duplicate backend end callback leaves the desktop stable")
	print("[XRIntegration] " + JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "headset_tested": false}))
	app.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)


func _simulate_session(manager: WineVRVRManager, mode: String) -> void:
	manager._saved_transparent_bg = get_viewport().transparent_bg
	manager._saved_physics_ticks = Engine.physics_ticks_per_second
	manager._presentation_saved = true
	manager.is_vr_active = true
	manager.is_ar_active = mode == "ar"
	manager.active_mode = mode
	get_viewport().transparent_bg = mode == "ar"
	manager.session_state_changed.emit(true, mode)


func _aim_at(winery: WineryInteriorController, target: Interactable) -> void:
	await get_tree().physics_frame
	var ray: RayCast3D = winery.vr_interaction_ray
	ray.global_position = target.global_position + target.global_basis.z * 0.22
	ray.look_at(target.global_position, Vector3.UP)
	ray.enabled = true
	ray.force_raycast_update()
	winery._update_interaction_prompt()
	_check(winery.get("_current_hovered_interactable") == target, "World-space ray resolves " + target.id)


func _tracker(tracker_name: String, at: Vector3) -> XRControllerTracker:
	var tracker: XRControllerTracker = XRControllerTracker.new()
	tracker.name = StringName(tracker_name)
	tracker.type = XRServer.TRACKER_CONTROLLER
	tracker.set_pose(&"aim", Transform3D(Basis.IDENTITY, at), Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	XRServer.add_tracker(tracker)
	return tracker


func _capture(filename: String) -> void:
	if not "--xr-capture" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://work/" + filename + ".png")
	print("[XRVisual] " + JSON.stringify({"capture": filename, "native_mono_fps": Engine.get_frames_per_second(), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), "headset_tested": false}))
