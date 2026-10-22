extends Node

var failures: Array[String] = []
var checks: int = 0

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("[VidianoQA] " + message)

func _clearance(springs: Node3D) -> float:
	var minimum: float = INF
	for a in range(springs.berries.size()):
		for b in range(a + 1, springs.berries.size()):
			var first: Dictionary = springs.berries[a]
			var second: Dictionary = springs.berries[b]
			var separation: Vector3 = Vector3(second["rest"]) + Vector3(second["offset"]) - Vector3(first["rest"]) - Vector3(first["offset"])
			var normal: Vector3 = separation.normalized()
			minimum = minf(minimum, separation.length() - springs._contact_extent(first, normal) - springs._contact_extent(second, normal))
	return minimum

func _run() -> void:
	var demo: Node3D = load("res://scenes/GrapeRoomDemo.tscn").instantiate()
	get_tree().root.add_child(demo)
	await get_tree().create_timer(1.0).timeout
	demo.settings.close()
	demo._started = true
	demo._pause(false)
	var museum: GrapeMuseum = demo.museum
	var body: RigidBody3D = demo.physics._body("vidiano")
	var springs: Node3D = body.get_node("BerryPhysics")
	springs.set_physics_process(false)
	body.freeze = true
	springs.reset_motion()
	_check(springs.berries.size() == 73, "All 73 white grapes retain independent skins and springs")
	var shapes: Array = body.get_node("InspectionRotation/AuthoredBunch/VidianoBerries").get_meta("berry_shapes")
	var correct_geometry: bool = true
	for index in range(springs.berries.size()):
		var berry: Dictionary = springs.berries[index]
		var shape: Transform3D = shapes[index]
		correct_geometry = correct_geometry and Vector3(berry["rest"]).distance_to(shape.origin) < 0.00001
		for vertex: int in berry["vertices"]:
			var point: Vector3 = berry["source_arrays"][Mesh.ARRAY_VERTEX][vertex]
			correct_geometry = correct_geometry and (shape.affine_inverse() * point).length() < 1.0001
	_check(correct_geometry, "Contact ellipsoids enclose every visible skin vertex and use its actual center")
	var rest_gap: float = _clearance(springs)
	print("[VidianoQA] rest minimum skin clearance=%s mm" % (rest_gap * 1000.0))
	_check(rest_gap >= 0.0015, "No berry pair overlaps in the generated rest geometry")
	for fps in [30, 60, 120]:
		springs.reset_motion()
		body.freeze = false
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		springs._physics_process(1.0 / fps)
		var gap: float = INF
		var movement: float = 0.0
		for frame in range(fps * 2):
			var t: float = float(frame) / fps
			body.linear_velocity = Vector3(sin(t * 12.0), cos(t * 10.0) * 0.4, sin(t * 7.0))
			body.angular_velocity = Vector3(0, sin(t * 9.0) * 3.0, 0)
			springs.apply_contact_force(body.to_global(springs.berries[8]["rest"]), Vector3(1.4, 0.4, 0))
			springs._physics_process(1.0 / fps)
			if frame % 3 == 0:
				gap = minf(gap, _clearance(springs))
			for berry: Dictionary in springs.berries:
				movement = maxf(movement, Vector3(berry["offset"]).length())
		print("[VidianoQA] %s Hz minimum moving clearance=%s mm motion=%s mm" % [fps, gap * 1000, movement * 1000])
		_check(gap >= -0.00001, "Visible skins remain separated under rotation and contact loads at %s Hz" % fps)
		_check(movement > 0.0001 and movement <= 0.0081, "Berries still sway within the stem travel limits at %s Hz" % fps)
	body.freeze = true
	springs.reset_motion()
	springs.set_physics_process(true)
	var center: Vector3 = body.to_global(body.center_of_mass)
	var winery: WineryInteriorController = demo.winery
	winery.player_rig.global_position = Vector3(center.x, 0, center.z + 1.25)
	winery.player_rig.rotation = Vector3.ZERO
	winery.camera_pivot.rotation = Vector3.ZERO
	winery.camera.rotation = Vector3.ZERO
	winery.camera.look_at(center, Vector3.UP)
	museum.inspect_exhibit("vidiano")
	await get_tree().create_timer(0.7).timeout
	if DisplayServer.get_name() != "headless":
		for angle in [0, 90, 180, 270]:
			demo.physics._demo_yaw_target = deg_to_rad(angle)
			await get_tree().create_timer(1.6).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://work/vidiano-contact-%s.png" % angle)
	print("[VidianoQA] checks=%s failures=%s" % [checks, failures.size()])
	demo.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
