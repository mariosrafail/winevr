extends Node

var failures: Array[String] = []
var checks: int = 0

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("[GrapeContactsQA] " + message)

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
	var expected: Dictionary = {"liatiko": 178, "kotsifali": 152, "vidiano": 73}
	for id: String in expected:
		var body: RigidBody3D = demo.physics._body(id)
		var springs: Node3D = body.get_node("BerryPhysics")
		springs.set_physics_process(false)
		body.freeze = true
		springs.reset_motion()
		_check(springs.berries.size() == int(expected[id]), id + " keeps every independent berry")
		var shapes: Array = []
		for node in body.get_node("InspectionRotation/AuthoredBunch").find_children("*", "MeshInstance3D", true, false):
			shapes.append_array(node.get_meta("berry_shapes", []))
		var correct_geometry: bool = true
		for index in range(springs.berries.size()):
			var berry: Dictionary = springs.berries[index]
			var shape: Transform3D = shapes[index]
			correct_geometry = correct_geometry and Vector3(berry["center"]).distance_to(shape.origin) < 0.00001
			for vertex: int in berry["vertices"]:
				var point: Vector3 = berry["source_arrays"][Mesh.ARRAY_VERTEX][vertex]
				correct_geometry = correct_geometry and (shape.affine_inverse() * point).length() < 1.0001
		_check(correct_geometry, "Contact ellipsoids enclose every visible skin vertex and use its actual center")
		var rest_gap: float = _clearance(springs)
		print("[GrapeContactsQA] %s rest minimum skin clearance=%s mm" % [id, rest_gap * 1000.0])
		_check(rest_gap >= 0.0015, id + " no berry pair overlaps in the packed rest geometry")
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
			print("[GrapeContactsQA] %s %s Hz minimum moving clearance=%s mm motion=%s mm" % [id, fps, gap * 1000, movement * 1000])
			_check(gap >= -0.00001, id + " visible skins remain separated under rotation and contact loads at %s Hz" % fps)
			_check(movement > 0.0001 and movement <= 0.0081, id + " berries still sway within the stem travel limits at %s Hz" % fps)
		body.freeze = true
		springs.reset_motion()
		springs.set_physics_process(true)
	print("[GrapeContactsQA] checks=%s failures=%s" % [checks, failures.size()])
	demo.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
