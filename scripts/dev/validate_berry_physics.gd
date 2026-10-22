extends Node

var failures: Array[String] = []
var checks: int = 0

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("[BerryQA] " + message)

func _click(button: Button) -> void:
	var point: Vector2 = button.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	for pressed in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		get_viewport().push_input(event, true)
		await get_tree().process_frame

func _run() -> void:
	get_viewport().size = Vector2i(1280, 800)
	var app: Node = load("res://scenes/WineVRExperience.tscn").instantiate()
	get_tree().root.add_child(app)
	await get_tree().create_timer(2.0).timeout
	var winery: WineryInteriorController = app.get_node("WineryInterior")
	var museum: GrapeMuseum = winery.get("_grape_museum")
	(app.get("_main_menu") as MainMenuOverlayController).museum_button.pressed.emit()
	await get_tree().create_timer(0.8).timeout
	var expected: Dictionary = {"liatiko": 178, "kotsifali": 152, "vidiano": 73}
	for id: String in museum.exhibit_nodes:
		var body: RigidBody3D = museum.exhibit_nodes[id]["pivot"]
		var springs: Node3D = body.get_node("BerryPhysics")
		_check(springs.berries.size() == int(expected[id]), id + " every berry has an independent stem spring (%s)" % springs.berries.size())
		if springs.berries.is_empty():
			continue
		springs.set_physics_process(false)
		for fps in [30, 60, 120]:
			springs.reset_motion()
			body.linear_velocity = Vector3.ZERO
			body.angular_velocity = Vector3.ZERO
			springs._physics_process(1.0 / fps)
			body.linear_velocity = Vector3(1.2, 0, 0)
			var maximum: float = 0.0
			var attached: bool = true
			for frame in range(fps / 2):
				springs._physics_process(1.0 / fps)
				for berry: Dictionary in springs.berries:
					var offset: Vector3 = berry["offset"]
					maximum = maxf(maximum, offset.length())
					attached = attached and offset.is_finite() and offset.length() <= minf(0.008, float(berry["radius"]) * 0.18) + 0.00001
			_check(attached, id + " all springs remain bounded at %s Hz" % fps)
			_check(maximum > 0.00005, id + " berries lag behind an accelerated bunch at %s Hz" % fps)
			for frame in range(fps * 3):
				springs._physics_process(1.0 / fps)
			var remaining: float = 0.0
			for berry: Dictionary in springs.berries:
				remaining = maxf(remaining, Vector3(berry["offset"]).length())
			_check(remaining < 0.0001, id + " oscillation settles at %s Hz" % fps)
		springs.reset_motion()
		body.linear_velocity = Vector3.ZERO
		springs._physics_process(1.0 / 60.0)
		var contacted: Dictionary = springs.berries[0]
		for frame in range(12):
			springs.apply_contact_force(body.to_global(contacted["rest"]), Vector3(0.5, 0, 0))
			springs._physics_process(1.0 / 60.0)
		_check(Vector3(contacted["offset"]).x > 0.0001, id + " berries at the grasp point respond to contact load")
		body.freeze = true
		springs._physics_process(1.0 / 60.0)
		_check(Vector3(springs.berries[0]["offset"]).is_zero_approx(), id + " paused and transition poses reset secondary motion")
		body.freeze = false
		springs.set_physics_process(true)
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://work/berry-physics-preview.png")
	app.call("_navigate_section", "vineyard")
	await get_tree().create_timer(0.5).timeout
	var exploration: ExplorationModeController = app.get("_exploration_mode")
	if not exploration.active:
		exploration.enter_mode()
	var vineyard: VineyardLandscapeController = winery.get("_vineyard")
	var station: Interactable = vineyard.stations.values()[0]
	winery.player_rig.global_position = Vector3(station.global_position.x, 0, station.global_position.z + 1.4)
	winery.player_rig.rotation = Vector3.ZERO
	winery.camera_pivot.rotation = Vector3.ZERO
	winery.camera.look_at(station.global_position, Vector3.UP)
	await get_tree().physics_frame
	for cycle in range(3):
		winery.interaction_ray.force_raycast_update()
		var key: InputEventKey = InputEventKey.new()
		key.keycode = KEY_E
		key.pressed = true
		get_viewport().push_input(key, true)
		await get_tree().create_timer(0.4).timeout
		_check(winery.get_info_panel().visible, "Exploring opens station info")
		_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Info releases the exploration cursor")
		if cycle == 0 and "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://work/exploration-info-preview.png")
		var rotation: Vector3 = winery.player_rig.rotation
		await _click(winery.get("_info_close_button") as Button)
		await get_tree().create_timer(0.25).timeout
		_check(not winery.get_info_panel().visible, "Real pointer click closes station panel, cycle %s" % cycle)
		_check(winery.player_rig.rotation.is_equal_approx(rotation), "Pointer movement over modal cannot turn the player")
		if DisplayServer.get_name() != "headless":
			_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Closing station info resumes exploration")
	var options: GraphicsSettingsPanelController = app.get("_graphics_panel")
	options.open()
	await get_tree().create_timer(0.3).timeout
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Options also releases exploration cursor")
	await _click(options.close_button)
	await get_tree().create_timer(0.3).timeout
	_check(not options.is_open(), "Options closes after repeated info modals")
	print("[BerryQA] checks=%s failures=%s" % [checks, failures.size()])
	app.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
