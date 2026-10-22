extends Node

var failures: Array[String] = []
var checks: int = 0

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("[RoomDemoQA] " + message)

func _key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	get_viewport().push_input(event, true)

func _click(point: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_viewport().push_input(event, true)
	event.pressed = false
	get_viewport().push_input(event, true)

func _wheel(up: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = get_viewport().get_visible_rect().size * Vector2(0.33, 0.5)
	event.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	get_viewport().push_input(event, true)
	event.pressed = false
	get_viewport().push_input(event, true)

func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://work/room-demo-" + name + ".png")

func _run() -> void:
	var saved_config: String = FileAccess.get_file_as_string("user://graphics_settings.cfg") if FileAccess.file_exists("user://graphics_settings.cfg") else ""
	var demo: Node3D = (load("res://scenes/GrapeRoomDemo.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(demo)
	await get_tree().create_timer(1.5).timeout
	_check(demo.paused and demo.settings.is_open(), "Startup opens display settings above the main menu")
	await _capture("settings")
	if DisplayServer.get_name() != "headless":
		var initial_resolution: int = demo.settings.resolution_dropdown.selected
		demo.settings.fullscreen_toggle.button_pressed = false
		demo.settings.resolution_dropdown.select(0)
		await demo.settings._apply_display_settings()
		_check(DisplayServer.window_get_size() == Vector2i(1280, 720), "Display settings apply the selected window resolution")
		await demo.settings.toggle_fullscreen()
		_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "Display settings enter fullscreen")
		await demo.settings.toggle_fullscreen()
		_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "Display settings return to windowed mode")
		demo.settings.resolution_dropdown.select(initial_resolution)
		await demo.settings._apply_display_settings()
		demo.graphics.apply_current()
		var config: ConfigFile = ConfigFile.new()
		config.load("user://graphics_settings.cfg")
		_check(config.has_section_key("display", "resolution"), "Quality changes preserve saved display preferences")
	if DisplayServer.get_name() == "headless":
		demo.settings.close()
	else:
		_click(demo.settings.close_button.get_global_rect().get_center())
	await get_tree().create_timer(0.3).timeout
	_check(demo.paused and demo._pause_panel.visible, "Closing settings returns to the menu")
	await _capture("menu")
	if DisplayServer.get_name() == "headless":
		demo._start_button.pressed.emit()
	else:
		_click(demo._start_button.get_global_rect().get_center())
	await get_tree().process_frame
	_check(not demo.paused and demo._started, "Start enters the room")
	var museum: GrapeMuseum = demo.museum
	var physics: MuseumPhysicsController = demo.physics
	var winery: WineryInteriorController = demo.winery
	_check(museum.exhibit_nodes.size() == 3, "The standalone scene starts directly in the three-grape room")
	_check(physics.room_demo and physics.hand == null and physics.left_hand == null, "No hand meshes or hand controllers are created")
	_check(winery.get("_vineyard") == null and winery.get("_cellar") == null, "No other experience sections load")
	_check(not physics.begin_grab(false, true), "Berry picking and tearing are disabled")
	await _capture("overview")
	for id: String in museum.exhibit_nodes:
		var body: RigidBody3D = physics._body(id)
		var springs: Node3D = body.get_node("BerryPhysics")
		_check(springs._neighbors.size() > 0 and springs.secondary_rotation, id + " uses neighboring berry contacts and stem bending")
		var center: Vector3 = body.to_global(body.center_of_mass)
		winery.player_rig.global_position = Vector3(center.x, 0, center.z + 1.25)
		winery.player_rig.rotation = Vector3.ZERO
		winery.camera_pivot.rotation = Vector3.ZERO
		winery.camera.rotation = Vector3.ZERO
		winery.camera.look_at(center, Vector3.UP)
		await get_tree().physics_frame
		winery.interaction_ray.force_raycast_update()
		await get_tree().process_frame
		await get_tree().process_frame
		_check(demo._target_id == id and demo._interaction_prompt.visible and not demo._crosshair.visible, id + " shows the hand and E only over an inspectable grape")
		_check((demo._interaction_prompt.global_position + Vector2(18, 24)).distance_to(get_viewport().get_visible_rect().size * 0.5) < 2.0, id + " hand prompt is centered on the aiming point")
		await _capture(id + "-hand")
		if id == "liatiko":
			winery.camera.look_at(winery.camera.global_position + Vector3(0, 1, 1), Vector3.UP)
			await get_tree().process_frame
			await get_tree().process_frame
			_check(not demo._interaction_prompt.visible and demo._crosshair.visible, "Looking away restores the normal crosshair")
			winery.camera.look_at(center, Vector3.UP)
			await get_tree().physics_frame
		_key(KEY_E, true)
		_key(KEY_E, false)
		await get_tree().create_timer(0.25).timeout
		_check(physics._transitioning and body.global_position.distance_to(physics._inspect_transform().origin) > 0.02, id + " opening has a visible flight before settling in front")
		await get_tree().create_timer(0.5).timeout
		_check(physics.inspecting_id == id, id + " E opens the actual grape")
		var screen_center: Vector2 = winery.camera.unproject_position(body.to_global(physics._demo_bounds.get_center()))
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		_check(screen_center.distance_to(viewport_size * Vector2(0.33, 0.5)) < 3.0, id + " comes forward into the screen inspection area")
		_check(body.freeze and demo._inspection_canvas.visible and demo._inspection_camera.cull_mask == demo.INSPECTION_LAYER, id + " renders in an independent foreground depth buffer")
		_check((winery.camera.cull_mask & demo.INSPECTION_LAYER) == 0, id + " inspected object is excluded from the room render")
		_check((museum.exhibit_nodes[id]["panel"] as Node3D).visible, id + " inspection restores charts")
		_check(not (museum.exhibit_nodes[id]["panel"] as Node3D).get_node("museum_" + id + "_turn_0").visible, id + " has no rotation buttons")
		var panel: Node3D = museum.exhibit_nodes[id]["panel"]
		_check(is_equal_approx(physics._demo_zoom, 1.0), id + " inspection starts at the default zoom")
		var default_distance: float = winery.camera.global_position.distance_to(body.to_global(physics._demo_bounds.get_center()))
		var panel_pose: Transform3D = panel.global_transform
		for index in range(3):
			_wheel(true)
		await get_tree().create_timer(0.4).timeout
		_check(winery.camera.global_position.distance_to(body.to_global(physics._demo_bounds.get_center())) < default_distance * 0.8, id + " wheel zooms smoothly towards the bunch")
		_check(panel.global_transform.is_equal_approx(panel_pose), id + " zoom leaves the right panel unchanged")
		for index in range(30):
			_wheel(true)
		_check(physics._demo_zoom_target <= 1.60, id + " near zoom is bounded")
		for index in range(40):
			_wheel(false)
		_check(physics._demo_zoom_target >= 0.75, id + " far zoom is bounded")
		physics.demo_zoom(1.0 / physics._demo_zoom_target)
		await get_tree().create_timer(0.5).timeout
		var tab: Node3D = panel.get_node("museum_" + id + "_page_1")
		_click(winery.camera.unproject_position(tab.global_position))
		await get_tree().process_frame
		_check(panel.get_node("BerryPage").visible and not panel.get_node("ProfilePage").visible, id + " chart tabs respond to mouse clicks")
		await get_tree().create_timer(0.3).timeout
		await _capture(id + "-berry-text")
		tab = panel.get_node("museum_" + id + "_page_2")
		_click(winery.camera.unproject_position(tab.global_position))
		await get_tree().create_timer(0.3).timeout
		await _capture(id + "-ripening-text")
		tab = panel.get_node("museum_" + id + "_page_0")
		_click(winery.camera.unproject_position(tab.global_position))
		await get_tree().process_frame
		_check(panel.get_node("ProfilePage").visible, id + " chart profile can be restored")
		var yaw: float = physics._demo_yaw
		var point: Vector2 = winery.camera.unproject_position(body.to_global(body.center_of_mass))
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		get_viewport().push_input(click, true)
		_check(demo._dragging, id + " clicking the grape begins mouse rotation")
		await get_tree().process_frame
		_check(Input.get_current_cursor_shape() == Input.CURSOR_DRAG or DisplayServer.get_name() == "headless", id + " cursor becomes a grabbing hand")
		var drag: InputEventMouseMotion = InputEventMouseMotion.new()
		drag.position = point
		drag.relative = Vector2(-120, 45)
		get_viewport().push_input(drag, true)
		var peak_motion: float = 0.0
		var deadline: int = Time.get_ticks_msec() + 700
		while Time.get_ticks_msec() < deadline:
			await get_tree().physics_frame
			for berry: Dictionary in springs.berries:
				peak_motion = maxf(peak_motion, Vector3(berry["offset"]).length())
		click.pressed = false
		get_viewport().push_input(click, true)
		await get_tree().create_timer(0.35).timeout
		_check(absf(wrapf(physics._demo_yaw - yaw, -PI, PI)) > 0.25, id + " mouse drag rotates the bunch")
		_check(wrapf(physics._demo_yaw - yaw, -PI, PI) < -0.25, id + " mouse drag uses the requested inverted direction")
		_check(body.global_basis.y.dot(winery.camera.global_basis.y) > 0.99999, id + " rotation stays upright relative to the viewer")
		_check(winery.camera.unproject_position(body.to_global(physics._demo_bounds.get_center())).distance_to(screen_center) < 3.0, id + " rotation preserves the screen center")
		_check(peak_motion > 0.00002 and peak_motion <= 0.0081, id + " individual berries react with bounded inertial motion")
		await _capture(id)
		if id == "vidiano":
			var back: Node3D = panel.get_node("museum_" + id + "_close")
			_click(winery.camera.unproject_position(back.global_position))
		else:
			_key(KEY_E, true)
			_key(KEY_E, false)
		await get_tree().create_timer(0.25).timeout
		_check(physics._transitioning and physics.demo_returning_id == id and demo._inspection_canvas.visible, id + " return flight keeps its foreground projection until it reaches home")
		await get_tree().create_timer(0.5).timeout
		_check(not museum.is_inspecting() and is_instance_valid(museum.exhibit_nodes[id]["joint"]), id + " E returns the bunch to its physical suspension")
		_check(not demo._inspection_canvas.visible and demo._inspection_nodes.is_empty(), id + " return restores the normal scene rendering")
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await get_tree().process_frame
	_check(demo.paused and not museum.controls_enabled, "Escape pauses without opening any other section")
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await get_tree().process_frame
	_check(not demo.paused and museum.controls_enabled, "Escape resumes room movement")
	# Interrupt animations in both directions: the final requested state must win.
	demo._pause(true)
	await get_tree().create_timer(0.05).timeout
	demo._pause(false)
	await get_tree().create_timer(0.05).timeout
	demo._pause(true)
	await get_tree().create_timer(0.35).timeout
	_check(demo._pause_panel.visible and demo._pause_panel.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(demo._pause_panel.modulate.a, 1.0), "Rapid pause toggles settle on a fully visible menu")
	demo.settings.open()
	await get_tree().create_timer(0.08).timeout
	demo.settings.close()
	await get_tree().create_timer(0.05).timeout
	demo.settings.open()
	await get_tree().create_timer(0.35).timeout
	_check(demo.settings.is_open() and demo.settings.panel.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(demo.settings.overlay_root.modulate.a, 1.0), "Reopening settings cancels its closing animation")
	demo.settings.close()
	await get_tree().create_timer(0.5).timeout
	_check(not demo.settings.is_open() and not demo.settings.overlay_root.visible and demo._pause_panel.visible, "Animated settings close returns to the pause menu")
	print("[RoomDemoQA] checks=%s failures=%s FPS=%s" % [checks, failures.size(), Engine.get_frames_per_second()])
	if not saved_config.is_empty():
		var config_file: FileAccess = FileAccess.open("user://graphics_settings.cfg", FileAccess.WRITE)
		config_file.store_string(saved_config)
		config_file.close()
	demo.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
