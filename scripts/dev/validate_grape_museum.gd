extends Node

var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error("[MuseumQA] " + message)

func _run() -> void:
	var packed: PackedScene = load("res://scenes/WineVRExperience.tscn") as PackedScene
	_check(packed != null, "Main game scene loads")
	if packed == null:
		get_tree().quit(1)
		return
	var app: Node = packed.instantiate()
	get_tree().root.add_child(app)
	await get_tree().create_timer(2.0).timeout
	var winery: WineryInteriorController = app.get_node("WineryInterior") as WineryInteriorController
	var museum: GrapeMuseum = winery.get_node("GrapeMuseum") as GrapeMuseum
	_check(museum != null and museum.exhibit_nodes.size() >= 3, "Three distinct Cretan varieties loaded")
	_check(bool(museum.data.get("values_are_illustrative", false)), "Illustrative values are labelled")
	_check(museum.exhibit_nodes.has("vidiano"), "White Vidiano joins the two red exhibits")
	_check((museum.data.get("metrics", []) as Array).size() == 5, "Chemical profile includes berry bitterness")
	if museum.exhibit_nodes.size() < 3:
		print("[MuseumQA] Missing exhibit data/assets; aborting integration checks")
		app.queue_free()
		await get_tree().process_frame
		get_tree().quit(1)
		return
	var menu: MainMenuOverlayController = app.get("_main_menu") as MainMenuOverlayController
	_check(menu.museum_button != null, "Museum has a real main-menu entry")
	var capture: bool = "--museum-capture" in OS.get_cmdline_user_args()
	if capture:
		DisplayServer.window_set_size(Vector2i(1440, 900))
		await get_tree().create_timer(0.3).timeout
		await _capture("museum_menu")
	menu.museum_button.pressed.emit()
	await get_tree().create_timer(1.2).timeout
	_check(winery.visible and winery.camera.current, "Menu enters the real game room with the desktop camera")
	_check(winery.get("_controls_enabled"), "Walking controls enabled")
	_check(museum.controls_enabled, "Museum interaction enabled")
	_check((app.get("_exploration_mode") as ExplorationModeController).active, "Mouse look starts automatically")
	_check(not winery.held_vial.visible, "Vial does not obscure museum inspection")
	if capture:
		await _capture("museum_overview")
	var options: GraphicsSettingsPanelController = app.get("_graphics_panel") as GraphicsSettingsPanelController
	options.open()
	await get_tree().create_timer(0.25).timeout
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Options releases the cursor after modal focus changes")
	_check(not museum.controls_enabled, "Options blocks movement/grabbing")
	_check(options.fullscreen_button != null and options.fullscreen_button.is_visible_in_tree(), "Immediate fullscreen button is visible")
	if capture:
		await _capture("museum_options")
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		_check(options.panel.size.y <= viewport_size.y - 20, "Options fits vertically in the actual window")
		var saved_preferences: String = FileAccess.get_file_as_string(GraphicsSettingsPanelController.CONFIG_PATH)
		var original_window: Vector2i = DisplayServer.window_get_size()
		options.fullscreen_button.pressed.emit()
		await get_tree().create_timer(0.3).timeout
		_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "Fullscreen button changes the actual native window mode")
		_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Cursor remains visible in fullscreen Options")
		var fullscreen_key: InputEventKey = InputEventKey.new()
		fullscreen_key.keycode = KEY_F11
		fullscreen_key.pressed = true
		Input.parse_input_event(fullscreen_key)
		await get_tree().create_timer(0.3).timeout
		_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "F11 returns to windowed mode")
		fullscreen_key.pressed = false
		Input.parse_input_event(fullscreen_key)
		var preferences: FileAccess = FileAccess.open(GraphicsSettingsPanelController.CONFIG_PATH, FileAccess.WRITE)
		preferences.store_string(saved_preferences)
		preferences.close()
		DisplayServer.window_set_size(original_window)
	options.close()
	await get_tree().create_timer(0.25).timeout
	if DisplayServer.get_name() != "headless":
		_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Closing Options restores normal mouse look")
	var physics: MuseumPhysicsController = museum.physics as MuseumPhysicsController
	for id in museum.exhibit_nodes.keys():
		var entry: Dictionary = museum.exhibit_nodes[id]
		var bunch: RigidBody3D = entry["pivot"] as RigidBody3D
		var model: Node3D = (entry["turntable"] as Node3D).get_node("AuthoredBunch") as Node3D
		var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
		_check(not meshes.is_empty(), id + " has actual authored 3D geometry")
		var panel: Interactable = entry["panel"] as Interactable
		_check(not panel.visible, id + " profile bars are hidden during walking")
		_check(is_instance_valid(entry.get("joint")), id + " hangs from a real physics joint")
		var anchor: Vector3 = (entry["anchor"] as Node3D).global_position
		var old_rotation: Quaternion = bunch.global_basis.get_rotation_quaternion()
		bunch.apply_impulse(Vector3(0.06, 0, 0.015), Vector3(0, -0.30, 0))
		await get_tree().create_timer(0.30).timeout
		_check(bunch.angular_velocity.length() > 0.01 or old_rotation.angle_to(bunch.global_basis.get_rotation_quaternion()) > 0.005, id + " physically swings after an impulse")
		_check(bunch.global_position.distance_to(anchor) < 0.025, id + " stays connected to its suspension point")
		var hit_center: Vector3 = bunch.to_global(bunch.center_of_mass)
		winery.player_rig.global_position = Vector3(hit_center.x, 0, hit_center.z + 1.1)
		winery.player_rig.rotation = Vector3.ZERO
		winery.camera_pivot.rotation = Vector3.ZERO
		winery.camera.look_at(hit_center, Vector3.UP)
		await get_tree().physics_frame
		winery.interaction_ray.force_raycast_update()
		var hanging_down: InputEventMouseButton = InputEventMouseButton.new()
		hanging_down.button_index = MOUSE_BUTTON_LEFT
		hanging_down.shift_pressed = true
		hanging_down.pressed = true
		hanging_down.position = winery.camera.unproject_position(hit_center)
		_send_mouse(hanging_down, physics)
		await get_tree().physics_frame
		_check(physics.grabbed_id == id, id + " can be grabbed while still hanging")
		var hanging_drag: InputEventMouseMotion = InputEventMouseMotion.new()
		hanging_drag.position = hanging_down.position + Vector2(90, 0)
		hanging_drag.relative = Vector2(90, 0)
		hanging_drag.button_mask = MOUSE_BUTTON_MASK_LEFT
		var hanging_rotation: Quaternion = bunch.global_basis.get_rotation_quaternion()
		_send_mouse(hanging_drag, physics)
		await get_tree().create_timer(0.75).timeout
		_check(hanging_rotation.angle_to(bunch.global_basis.get_rotation_quaternion()) > 0.01, id + " hand pulls produce a real hanging swing")
		_check(bunch.global_position.distance_to(anchor) < 0.025, id + " hand pulling preserves the stem attachment")
		hanging_down.pressed = false
		_send_mouse(hanging_down, physics)
		await get_tree().physics_frame
		winery.camera.look_at(bunch.to_global(bunch.center_of_mass), Vector3.UP)
		winery.interaction_ray.force_raycast_update()
		winery.call("_update_interaction_prompt")
		_check(winery.get("_current_hovered_interactable") == museum.exhibits.get_node("museum_" + id), id + " is selected through the actual game ray")
		winery.interact_current()
		await get_tree().create_timer(0.65).timeout
		_check(museum.selected_id == id and physics.inspecting_id == id, id + " enters close inspection")
		_check(panel.visible and not is_instance_valid(entry.get("joint")), id + " profile is shown and hook released only for inspection")
		var sugar_score: Label3D = panel.get_node("ProfilePage/Score_sugars") as Label3D
		_check(" / 100" in sugar_score.text and not "%" in sugar_score.text, id + " illustrative scores cannot be confused with sugar percentages")
		var berry_tab: Interactable = panel.get_node("museum_" + id + "_page_1") as Interactable
		berry_tab.interact()
		_check((panel.get_node("BerryPage") as Node3D).visible and not (panel.get_node("ProfilePage") as Node3D).visible, id + " berry anatomy tab changes the actual world panel")
		var maturity_tab: Interactable = panel.get_node("museum_" + id + "_page_2") as Interactable
		maturity_tab.interact()
		_check((panel.get_node("RipeningPage") as Node3D).visible and not (panel.get_node("BerryPage") as Node3D).visible, id + " maturity and origin card is selectable")
		if capture and id == "vidiano":
			await _capture("museum_vidiano_learning")
		var anatomy_tab: Interactable = panel.get_node("museum_" + id + "_page_3") as Interactable
		anatomy_tab.interact()
		var anatomy: BerryAnatomy = panel.get_node("AnatomyPage") as BerryAnatomy
		_check(anatomy.active and anatomy.is_visible_in_tree(), id + " fourth tab reveals the actual 3D berry cutaway")
		for part in ["skin", "pulp", "seeds"]:
			(anatomy.get_node("Anatomy_" + part) as Interactable).interact()
			_check(anatomy.selected_part == part and not anatomy.get("_description").text.is_empty(), id + " anatomy selection explains " + part)
		if capture and id == "vidiano":
			await _capture("museum_vidiano_anatomy")
		museum.set_profile_page(id, 0)
		_check(not anatomy.visible and not anatomy.active, id + " switching page hides cutaway")
		for collider in anatomy.find_children("*", "Area3D", true, false):
			_check((collider as Area3D).collision_layer == 0, id + " hidden anatomy cannot intercept pointing")
		_check(winery.camera.global_position.distance_to(bunch.to_global(bunch.center_of_mass)) < 1.4, id + " is brought physically close to the camera")
		_check(physics.hand.visible, "The anatomical 3D hand is visible")
		_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Inspect allows pointing at the bunch with the cursor")
		var rotate_button: Interactable = panel.get_node("museum_" + id + "_turn_2") as Interactable
		rotate_button.interact()
		await get_tree().physics_frame
		await get_tree().process_frame
		await get_tree().physics_frame
		_check(bunch.angular_velocity.length() > 0.005, id + " rotation applies physics torque")
		var right_click: InputEventMouseButton = InputEventMouseButton.new()
		right_click.button_index = MOUSE_BUTTON_RIGHT
		right_click.pressed = true
		right_click.position = get_viewport().get_visible_rect().size * 0.5
		_send_mouse(right_click, physics)
		var turn: InputEventMouseMotion = InputEventMouseMotion.new()
		turn.position = right_click.position
		turn.relative = Vector2(70, 15)
		_send_mouse(turn, physics)
		await get_tree().physics_frame
		_check(bunch.angular_velocity.length() > 0.05, id + " right mouse drag applies torque")
		right_click.pressed = false
		_send_mouse(right_click, physics)
		var wheel: InputEventMouseButton = InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		_send_mouse(wheel, physics)
		await get_tree().physics_frame
		await get_tree().process_frame
		_check(physics.get("_inspect_distance") < 1.1, "Mouse wheel moves inspection closer")
		museum.reset_exhibit(id)
		await get_tree().create_timer(0.15).timeout
		# Click the fruit at its actual projected position, then drag the mouse.
		var pixel: Vector2 = winery.camera.unproject_position(bunch.to_global(bunch.center_of_mass))
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.position = pixel
		motion.global_position = pixel
		_send_mouse(motion, physics)
		await get_tree().physics_frame
		var down: InputEventMouseButton = InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.shift_pressed = true
		down.pressed = true
		down.position = pixel
		_send_mouse(down, physics)
		await get_tree().physics_frame
		await get_tree().process_frame
		_check(physics.grabbed_id == id, id + " left mouse button actually grabs the fruit")
		var before: Vector3 = bunch.global_position
		var drag: InputEventMouseMotion = InputEventMouseMotion.new()
		drag.position = pixel + Vector2(75, -25)
		drag.relative = Vector2(75, -25)
		drag.button_mask = MOUSE_BUTTON_MASK_LEFT
		_send_mouse(drag, physics)
		await get_tree().create_timer(0.75).timeout
		_check(bunch.global_position.distance_to(before) > 0.005, id + " hand drag produces physical movement")
		_check(physics.hand.grip_target > 0.5, "The hand curls while grasping")
		_check(physics.hand.skeleton.get_bone_count() == 16, "The anatomical hand has a real articulated skeleton")
		_check(physics.hand.grip_amount > 0.95, "The fingers finish their closing animation")
		var distal: int = physics.hand.skeleton.find_bone("middle_2")
		var rest_rotation: Quaternion = physics.hand.skeleton.get_bone_global_rest(distal).basis.get_rotation_quaternion()
		var held_rotation: Quaternion = physics.hand.skeleton.get_bone_global_pose(distal).basis.get_rotation_quaternion()
		_check(rest_rotation.angle_to(held_rotation) > 0.5, "The rendered fingertip bones really bend, beyond the grip metadata")
		var contacting_fingers: int = 0
		for finger in ["index", "middle", "ring", "little"]:
			if int(physics.hand.finger_contacts.get(finger, 0)) > 0:
				contacting_fingers += 1
		_check(contacting_fingers >= 3, id + " multiple fingers conform to the actual berry envelope")
		_check(int(physics.hand.finger_contacts.get("thumb", 0)) > 0, "The thumb opposes the fingers at the fruit surface")
		_check(physics.hand.global_position.distance_to(physics.hand.grasp_transform().origin) < 0.015, "The wrist follows the held bunch rather than floating at the mouse goal")
		print("[HandQA] ", id, " angles=", physics.hand.finger_angles, " contacts=", physics.hand.finger_contacts)
		if capture:
			await _capture("museum_" + id + "_detail")
		var up: InputEventMouseButton = down.duplicate() as InputEventMouseButton
		up.pressed = false
		_send_mouse(up, physics)
		await get_tree().physics_frame
		_check(physics.grabbed_id.is_empty(), "Mouse release lets go of the fruit")
		await get_tree().create_timer(0.25).timeout
		_check(physics.hand.grip_amount < 0.05, "Releasing opens all fingers again")
		options.open()
		await get_tree().create_timer(0.12).timeout
		_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not museum.controls_enabled, "Options also releases input during Inspect")
		options.close()
		await get_tree().create_timer(0.12).timeout
		_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and museum.controls_enabled, "Closing Options preserves the Inspect cursor")
		museum.set_profile_page(id, 3)
		var return_key: InputEventKey = InputEventKey.new()
		return_key.keycode = KEY_E if id == "liatiko" else KEY_ESCAPE
		return_key.pressed = true
		Input.parse_input_event(return_key)
		await get_tree().physics_frame
		return_key.pressed = false
		Input.parse_input_event(return_key)
		await get_tree().create_timer(0.65).timeout
		_check(not museum.is_inspecting() and not panel.visible, id + " E/Esc return hides its profile again")
		_check(not anatomy.active and not anatomy.is_visible_in_tree(), id + " leaving inspection cleans up cutaway and its hit targets")
		museum.set_profile_page(id, 0)
		_check(is_instance_valid(entry.get("joint")) and bunch.global_position.distance_to(anchor) < 0.025, id + " returns to its original physical hook")
		if DisplayServer.get_name() != "headless":
			_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Returning resumes normal mouse look")
	# Exercise actual WASD motion and the existing room bounds.
	var movement: WineryMovementController = winery.get("_movement") as WineryMovementController
	var start: Vector3 = winery.player_rig.position
	var press: InputEventKey = InputEventKey.new()
	press.physical_keycode = KEY_W
	press.keycode = KEY_W
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().physics_frame
	await get_tree().physics_frame
	movement.physics_update(0.10)
	var release: InputEventKey = press.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	_check(winery.player_rig.position.distance_to(start) > 0.01, "WASD moves the player in the museum")
	_check(winery.player_rig is CharacterBody3D, "The walking rig has physical collisions")
	var body: CharacterBody3D = winery.player_rig as CharacterBody3D
	var first_exhibit: Dictionary = museum.exhibit_nodes[museum.exhibit_nodes.keys()[0]]
	body.global_position = Vector3((first_exhibit["anchor"] as Node3D).global_position.x, 0, -0.8)
	await get_tree().physics_frame
	_check(body.test_move(body.global_transform, Vector3(0, 0, -1.0)), "Stone plinth blocks walking through the exhibit")
	museum.set_passthrough_mode(true)
	_check(not museum.architecture.visible, "Passthrough presentation hides the virtual room")
	_check((first_exhibit["pivot"] as Node3D).is_visible_in_tree(), "Passthrough keeps the grape exhibit visible")
	museum.set_passthrough_mode(false)
	_check(museum.architecture.visible, "Leaving passthrough restores the gallery")
	museum.inspect_exhibit("vidiano")
	await get_tree().create_timer(0.65).timeout
	museum.set_profile_page("vidiano", 3)
	museum.visible = false
	var hidden_anatomy: BerryAnatomy = (museum.exhibit_nodes["vidiano"]["panel"] as Node3D).get_node("AnatomyPage") as BerryAnatomy
	_check(not hidden_anatomy.active, "Leaving the museum deactivates the cutaway immediately")
	museum.visible = true
	museum.close_inspection()
	await get_tree().create_timer(0.65).timeout
	menu.show_menu()
	_check(not museum.controls_enabled, "Menu blocks inspection input")
	app.call("_on_main_menu_resume_requested")
	await get_tree().create_timer(0.2).timeout
	_check(museum.controls_enabled, "Resume restores inspection")
	var report: Dictionary = {"passed": _failures.is_empty(), "failures": _failures, "varieties": museum.exhibit_nodes.keys(), "ray_inspection": true, "world_space_bars": true, "close_inspection": true, "physical_grab": true, "options_cursor": true, "anatomical_hand": true, "contact_finger_curl": true, "opposing_thumb": true, "animated_release": true, "berry_cutaway": true, "cutaway_cleanup": true}
	var file: FileAccess = FileAccess.open("res://work/museum_qa.json", FileAccess.WRITE)
	if file == null:
		file = FileAccess.open("user://museum_qa.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
	print("[MuseumQA] " + JSON.stringify(report))
	app.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)

func _capture(name: String) -> void:
	var previous_scale: float = get_viewport().scaling_3d_scale
	get_viewport().scaling_3d_scale = 1.0
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png("res://work/" + name + ".png")
	_check(error == OK, "Screenshot captured: " + name)
	print("[MuseumQA] Capture: ", name, " ", image.get_size(), " FPS=", Performance.get_monitor(Performance.TIME_FPS))
	get_viewport().scaling_3d_scale = previous_scale


func _send_mouse(event: InputEventMouse, physics: MuseumPhysicsController) -> void:
	# Headless has a 64px dummy window and no native mouse capture or GUI pointer.
	# The rendered run exercises the actual viewport event propagation instead.
	if DisplayServer.get_name() == "headless":
		physics._unhandled_input(event)
	else:
		# Native input reaches _unhandled_input after GUI propagation. Copy the
		# event because the caller may change a down event into its matching up.
		Input.parse_input_event(event.duplicate())
		Input.flush_buffered_events()
