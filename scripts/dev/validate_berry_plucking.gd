extends Node

var failures: Array[String] = []
var checks: int = 0
var physics: MuseumPhysicsController

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("[PluckQA] " + message)

func _mouse(pressed: bool, pixel: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = pixel
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	get_viewport().push_input(event, true)

func _pick(body: RigidBody3D, springs: Node3D) -> Dictionary:
	for berry: Dictionary in springs.berries:
		var pixel: Vector2 = physics.camera().unproject_position(springs.berry_position(springs.berries.find(berry)))
		physics._pointer = pixel
		physics._pointer_valid = true
		var hit: Dictionary = physics._view_ray(4)
		if hit.get("collider") == body:
			var index: int = springs.berry_for_shape(int(hit["shape"]))
			if index >= 0:
				return {"pixel": pixel, "index": index}
	return {}

func _check_rendered_pinch(hand: MuseumGlove, context: String) -> void:
	for digit: Dictionary in hand._digits:
		if digit["name"] not in ["index", "thumb"]:
			continue
		var last: int = digit["bones"][2]
		var rest_tip: Vector3 = hand._model_to_skeleton * Vector3(digit["points"][3])
		var tip_local: Vector3 = hand.skeleton.get_bone_global_rest(last).affine_inverse() * rest_tip
		var rendered_tip: Vector3 = hand.skeleton.global_transform * (hand.skeleton.get_bone_global_pose(last) * tip_local)
		var intended_tip: Vector3 = hand._model.global_transform * Vector3(hand._pinch_chains[digit["name"]][3])
		_check(rendered_tip.distance_to(intended_tip) < 0.002, context + " rendered " + str(digit["name"]) + " reaches its contact, beyond solver metadata")

func _run() -> void:
	get_viewport().size = Vector2i(1280, 800)
	var app: Node = load("res://scenes/WineVRExperience.tscn").instantiate()
	get_tree().root.add_child(app)
	await get_tree().create_timer(1.8).timeout
	var winery: WineryInteriorController = app.get_node("WineryInterior")
	var museum: GrapeMuseum = winery.get("_grape_museum")
	physics = museum.physics
	(app.get("_main_menu") as MainMenuOverlayController).museum_button.pressed.emit()
	await get_tree().create_timer(0.8).timeout
	for id: String in museum.exhibit_nodes:
		museum.inspect_exhibit(id)
		await get_tree().create_timer(0.7).timeout
		var body: RigidBody3D = physics._body(id)
		var springs: Node3D = body.get_node("BerryPhysics")
		if id == "vidiano":
			var smallest: float = INF
			var largest: float = 0.0
			for berry: Dictionary in springs.berries:
				smallest = minf(smallest, float(berry["radius"]))
				largest = maxf(largest, float(berry["radius"]))
			_check(springs.berries.size() == 73 and largest / smallest > 1.6, "Vidiano retains 73 individually physical berries with visibly varied sizes")
		var pick: Dictionary = _pick(body, springs)
		_check(not pick.is_empty(), id + " a real pointer ray selects a berry sphere")
		if pick.is_empty():
			continue
		_mouse(true, pick["pixel"])
		await get_tree().physics_frame
		_check(physics.is_holding_berry() and physics.grabbed_id.is_empty(), id + " left click holds one berry instead of the whole bunch")
		await get_tree().create_timer(0.7).timeout
		_check(physics.hand.pinching and physics.hand.grip_amount > 0.95, id + " fingers close before pulling begins")
		for name: String in ["index", "thumb"]:
			var gap: float = float(physics.hand.pinch_clearances.get(name, INF))
			print("[PinchGap] ", id, " ", name, " = ", gap)
			_check(gap >= -0.0006 and gap <= 0.0015, id + " visible " + name + " skin rests on fruit without penetration")
		if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://work/pinch-attached-" + id + ".png")
		var small: InputEventMouseMotion = InputEventMouseMotion.new()
		small.position = pick["pixel"]
		small.relative = Vector2(4, 0)
		get_viewport().push_input(small, true)
		await get_tree().create_timer(0.22).timeout
		_check(not bool(springs.berries[int(pick["index"])]["detached"]), id + " a gentle pull cannot sever the stem")
		_mouse(false, pick["pixel"])
		await get_tree().create_timer(0.35).timeout
		pick = _pick(body, springs)
		if pick.is_empty():
			_check(false, id + " berry remains pickable after a gentle release")
			continue
		_mouse(true, pick["pixel"])
		await get_tree().physics_frame
		await get_tree().create_timer(0.65).timeout
		var drag: InputEventMouseMotion = InputEventMouseMotion.new()
		drag.position = Vector2(pick["pixel"]) + Vector2(240, 0)
		drag.relative = Vector2(240, 0)
		get_viewport().push_input(drag, true)
		await get_tree().create_timer(0.14).timeout
		_check(physics._berry_owner != null and physics.berry_tension > 0.0 and physics.berry_tension < 1.0, id + " stem resists after fingers have reached the fruit")
		if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://work/pinch-resistance-" + id + ".png")
		await get_tree().create_timer(0.65).timeout
		var detached_count: int = 0
		var selected: Dictionary = {}
		for berry: Dictionary in springs.berries:
			if bool(berry["detached"]):
				detached_count += 1
				selected = berry
		_check(detached_count == 1, id + " dragging severs exactly one berry")
		if detached_count != 1:
			physics.end_grab()
			continue
		var loose: RigidBody3D = selected["loose_body"]
		_check(physics.hand.visible and physics.hand.pinching and physics.hand.grip_amount > 0.95, id + " visible hand pinches the detached berry")
		_check(float(physics.hand.pinch_errors.get("index", INF)) < 0.003 and float(physics.hand.pinch_errors.get("thumb", INF)) < 0.003, id + " thumb and index reach opposite berry contacts")
		_check(physics.hand.global_position.distance_to(physics.hand.pinch_transform(loose.global_position, physics.camera()).origin) < 0.025, id + " wrist follows the detached berry")
		_check_rendered_pinch(physics.hand, id)
		for name: String in ["index", "thumb"]:
			var contact: Dictionary = physics.hand._pinch_gap(name)
			_check(float(contact["gap"]) >= -0.0006 and float(contact["gap"]) <= 0.0015, id + " " + name + " keeps skin contact after detachment")
		_check(is_instance_valid(loose) and loose.get_parent() != body and not loose.freeze, id + " severed berry has independent dynamic physics")
		_check((selected["collider"] as CollisionShape3D).disabled and (selected["skeleton"] as Skeleton3D).get_bone_pose_scale(int(selected["bone"])).is_zero_approx(), id + " original berry geometry and collider are removed")
		var mesh: MeshInstance3D = loose.get_child(1) as MeshInstance3D
		_check(mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == selected["vertices"].size() and mesh.get_active_material(0) == selected["material"], id + " detached fruit preserves its authored mesh and material")
		var orientation: Quaternion = loose.global_basis.get_rotation_quaternion()
		var position_before_spin: Vector3 = loose.global_position
		var right: InputEventMouseButton = InputEventMouseButton.new()
		right.button_index = MOUSE_BUTTON_RIGHT
		right.pressed = true
		right.position = drag.position
		get_viewport().push_input(right, true)
		for frame in range(12):
			var spin: InputEventMouseMotion = InputEventMouseMotion.new()
			spin.position = drag.position
			spin.relative = Vector2(8, 3)
			get_viewport().push_input(spin, true)
			await get_tree().create_timer(1.0 / 60.0).timeout
		right.pressed = false
		get_viewport().push_input(right, true)
		await get_tree().create_timer(0.30).timeout
		_check(orientation.angle_to(loose.global_basis.get_rotation_quaternion()) > 0.15, id + " right drag rolls the severed berry between the fingers")
		_check(loose.global_position.distance_to(position_before_spin) < 0.035 and physics.is_holding_berry(), id + " rotation preserves the held position")
		for name: String in ["index", "thumb"]:
			var rolled_contact: Dictionary = physics.hand._pinch_gap(name)
			_check(float(rolled_contact["gap"]) >= -0.001 and float(rolled_contact["gap"]) <= 0.002, id + " " + name + " follows the rolling skin")
		var pixel_before_zoom: Vector2 = physics.camera().unproject_position(loose.global_position)
		var depth_before_zoom: float = -physics.camera().to_local(loose.global_position).z
		for tick in range(14):
			var wheel: InputEventMouseButton = InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_UP
			wheel.pressed = true
			wheel.position = drag.position
			get_viewport().push_input(wheel, true)
		await get_tree().create_timer(0.85).timeout
		var close_depth: float = -physics.camera().to_local(loose.global_position).z
		_check(close_depth > 0.24 and close_depth < 0.34 and close_depth < depth_before_zoom * 0.5, id + " wheel brings the held berry into close view")
		_check(physics.camera().unproject_position(loose.global_position).distance_to(pixel_before_zoom) < 28.0, id + " close inspection preserves framing")
		_check(physics.hand.visible and physics.hand.pinching, id + " close inspection keeps the visible pinch")
		if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://work/berry-close-" + id + ".png")
		if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://work/plucked-" + id + ".png")
		var height: float = loose.global_position.y
		_mouse(false, drag.position)
		await get_tree().create_timer(0.15).timeout
		_check(not physics.is_holding_berry() and loose.linear_velocity.y < -0.3 and loose.global_position.y < height, id + " releasing lets gravity drop the loose berry")
		var pixel: Vector2 = physics.camera().unproject_position(loose.global_position)
		_mouse(true, pixel)
		await get_tree().physics_frame
		_check(physics.is_holding_berry() and physics._loose_berry == loose, id + " detached berry can be picked up again")
		var reset: InputEventKey = InputEventKey.new()
		reset.keycode = KEY_T
		reset.pressed = true
		get_viewport().push_input(reset, true)
		await get_tree().create_timer(0.1).timeout
		_check(not is_instance_valid(loose) and not bool(selected["detached"]) and not (selected["collider"] as CollisionShape3D).disabled, id + " T restores the bunch and cleans up the loose body")
		physics.close_inspection(true)
		await get_tree().physics_frame
	print("[PluckQA] checks=%s failures=%s" % [checks, failures.size()])
	app.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
