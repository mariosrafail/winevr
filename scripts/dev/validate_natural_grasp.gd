extends Node

## Independent geometric checks use rendered skeleton poses and ray intersections
## against original grape triangles, rather than the solver's contact metadata.
var failures: Array[String] = []
var checks: int = 0
var measurements: Dictionary = {}
var capture: bool = false
var _triangles: PackedVector3Array
var _triangle_cells: Dictionary = {}
const CELL: float = 0.04


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("[NaturalGraspQA] " + message)


func _run() -> void:
	capture = "--grasp-capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	get_tree().root.size = Vector2i(1440, 900)
	var app: Node = load("res://scenes/WineVRExperience.tscn").instantiate()
	get_tree().root.add_child(app)
	await get_tree().create_timer(2.0).timeout
	var winery: WineryInteriorController = app.get_node("WineryInterior")
	var museum: GrapeMuseum = winery.get("_grape_museum")
	var physics: MuseumPhysicsController = museum.physics
	(app.get("_main_menu") as MainMenuOverlayController).museum_button.pressed.emit()
	# Let the asynchronous scene-entry/exploration setup finish before changing
	# camera modes; the solver's geometry audit intentionally blocks a few frames.
	await get_tree().create_timer(2.0).timeout
	for id in ["liatiko", "kotsifali", "vidiano"]:
		var body: RigidBody3D = physics._body(id)
		var center: Vector3 = body.to_global(body.center_of_mass)
		winery.player_rig.global_position = Vector3(center.x, 0, center.z + 1.1)
		winery.player_rig.rotation = Vector3.ZERO
		winery.camera_pivot.rotation = Vector3.ZERO
		winery.camera.look_at(center, Vector3.UP)
		await get_tree().physics_frame
		await get_tree().physics_frame
		winery.interaction_ray.force_raycast_update()
		winery.call("_update_interaction_prompt")
		winery.interact_current()
		await get_tree().create_timer(0.5).timeout
		await get_tree().physics_frame
		await get_tree().physics_frame
		await get_tree().process_frame
		_check(physics.inspecting_id == id and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, id + ": inspection is established with its pointing cursor")
		var triangle_mesh: TriangleMesh = _fruit_triangles(body)
		_check_surface_sign(id)
		var hand: MuseumGlove = physics.hand
		var open_pose: Dictionary = _joint_points(hand)
		var down: InputEventMouseButton = InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.shift_pressed = true
		down.pressed = true
		down.position = winery.camera.unproject_position(body.to_global(body.center_of_mass))
		var move: InputEventMouseMotion = InputEventMouseMotion.new()
		move.position = down.position
		_send_mouse(move, physics)
		await get_tree().physics_frame
		await get_tree().process_frame
		print("[NaturalGraspInput] ", id, " controls=", museum.controls_enabled, " transition=", physics._transitioning, " inspecting=", physics.inspecting_id, " mouse_mode=", Input.mouse_mode, " pointer=", down.position, " ray=", physics._view_ray(4).get("collider"))
		_send_mouse(down, physics)
		await get_tree().process_frame
		await get_tree().physics_frame
		await get_tree().process_frame
		_check(physics.grabbed_id == id, id + ": pointer input physically grabs the inspected grape")
		if physics.grabbed_id != id:
			app.queue_free()
			await get_tree().process_frame
			await _finish()
			return
		var max_length_error: float = 0.0
		# The hand now reaches before it closes; audit contact after arrival.
		await get_tree().create_timer(0.7).timeout
		var prior_grip: float = hand.grip_amount
		for fraction: float in [0.25, 0.5, 0.75]:
			hand.grip_amount = fraction
			hand._process(0.0)
			max_length_error = maxf(max_length_error, _segment_length_error(hand))
			var phase: String = str(int(fraction * 100))
			measurements[id + "_closing_" + phase] = _measure_grasp(hand, body, triangle_mesh, id + " at " + phase + "% closure", false)
		hand.grip_amount = prior_grip
		hand._process(0.0)
		for sample in range(18):
			await get_tree().create_timer(0.02).timeout
			max_length_error = maxf(max_length_error, _segment_length_error(hand))
		_check(hand.grip_amount > 0.98, id + ": fingers finish the actual closing animation")
		_check(max_length_error < 0.001, id + ": every phalanx keeps its length throughout closure (including thumb)")
		var result: Dictionary = _measure_grasp(hand, body, triangle_mesh, id)
		result["animation_length_error_m"] = max_length_error
		measurements[id] = result
		_check(hand.global_position.distance_to(hand.grasp_transform().origin) < 0.015, id + ": wrist stays attached to the held fruit")
		await _capture(id)
		# Reconstruct opening in hand-local space so the moving wrist cannot make
		# unchanged fingertip bones appear to have travelled.
		var closed_pose: Dictionary = _joint_points(hand)
		var moving_fingers: int = 0
		for digit: String in ["index", "middle", "ring", "little"]:
			if (open_pose[digit][-1] as Vector3).distance_to(closed_pose[digit][-1]) > 0.015:
				moving_fingers += 1
		_check(moving_fingers >= 3, id + ": at least three rendered fingertips travel more than 15 mm")
		down.pressed = false
		_send_mouse(down, physics)
		await get_tree().create_timer(0.3).timeout
		var released: Dictionary = _joint_points(hand)
		var return_error: float = 0.0
		for digit: String in open_pose:
			return_error = maxf(return_error, (open_pose[digit][-1] as Vector3).distance_to(released[digit][-1]))
		_check(physics.grabbed_id.is_empty() and hand.grip_amount < 0.02, id + ": releasing the pointer opens and detaches the hand")
		_check(return_error < 0.002, id + ": rendered fingertips return to their relaxed pose within 2 mm")
		museum.close_inspection()
		await get_tree().create_timer(0.45).timeout
		# The same model is mirrored for a sole left controller. Test its fitted
		# geometric grasp separately without changing the tracked runtime path.
		var left: MuseumGlove = physics.left_hand
		left.sync_to_physics = false
		left.start_grasp(body, body.center_of_mass, winery.camera)
		left.global_transform = left.grasp_transform()
		left.grip_amount = 1.0
		left.visible = true
		left._process(0.0)
		measurements[id + "_left"] = _measure_grasp(left, body, triangle_mesh, id + " left")
		_check(_segment_length_error(left) < 0.001, id + ": mirrored left hand keeps anatomical segment lengths")
		left.release_grasp()
		left.grip_amount = 0.0
		left._process(0.0)
		left.visible = false
		left.sync_to_physics = true
	app.queue_free()
	await _finish()


func _finish() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var report: Dictionary = {"checks": checks, "passed": failures.is_empty(), "failures": failures, "measurements": measurements, "headset_tested": false}
	var output: FileAccess = FileAccess.open("res://work/natural-grasp-qa.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print("[NaturalGraspQA] " + JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)


func _send_mouse(event: InputEventMouse, physics: MuseumPhysicsController) -> void:
	if DisplayServer.get_name() == "headless":
		physics._unhandled_input(event)
	else:
		Input.parse_input_event(event.duplicate())
		Input.flush_buffered_events()


func _joint_points(hand: MuseumGlove) -> Dictionary:
	var result: Dictionary = {}
	var model: Node3D = hand.get("_model")
	var model_to_skeleton: Transform3D = hand.skeleton.global_transform.affine_inverse() * model.global_transform
	var skeleton_to_hand: Transform3D = hand.global_transform.affine_inverse() * hand.skeleton.global_transform
	for digit: Dictionary in hand.get("_digits"):
		var points: Array[Vector3] = []
		for bone_index: int in digit["bones"]:
			points.append(skeleton_to_hand * hand.skeleton.get_bone_global_pose(bone_index).origin)
		var last: int = digit["bones"][2]
		var tip_rest: Vector3 = model_to_skeleton * (digit["points"][3] as Vector3)
		var tip_bone_local: Vector3 = hand.skeleton.get_bone_global_rest(last).affine_inverse() * tip_rest
		points.append(skeleton_to_hand * (hand.skeleton.get_bone_global_pose(last) * tip_bone_local))
		result[digit["name"]] = points
	return result


func _segment_length_error(hand: MuseumGlove) -> float:
	var points: Dictionary = _joint_points(hand)
	var model: Node3D = hand.get("_model")
	var error: float = 0.0
	for digit: Dictionary in hand.get("_digits"):
		for joint in range(3):
			var rest_start: Vector3 = model.transform * (digit["points"][joint] as Vector3)
			var rest_end: Vector3 = model.transform * (digit["points"][joint + 1] as Vector3)
			var actual: float = (points[digit["name"]][joint] as Vector3).distance_to(points[digit["name"]][joint + 1])
			error = maxf(error, absf(actual - rest_start.distance_to(rest_end)))
	return error


func _fruit_triangles(body: RigidBody3D) -> TriangleMesh:
	var faces: PackedVector3Array
	_triangles.clear()
	_triangle_cells.clear()
	for node in body.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = node as MeshInstance3D
		var local: Transform3D = body.global_transform.affine_inverse() * instance.global_transform
		var normal_basis: Basis = local.basis.inverse().transposed()
		for surface in range(instance.mesh.get_surface_count()):
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			for index in range(0, indices.size() if not indices.is_empty() else vertices.size(), 3):
				var ia: int = indices[index] if not indices.is_empty() else index
				var ib: int = indices[index + 1] if not indices.is_empty() else index + 1
				var ic: int = indices[index + 2] if not indices.is_empty() else index + 2
				var a: Vector3 = local * vertices[ia]
				var b: Vector3 = local * vertices[ib]
				var c: Vector3 = local * vertices[ic]
				faces.append_array(PackedVector3Array([a, b, c]))
				var normal: Vector3 = (normal_basis * (normals[ia] + normals[ib] + normals[ic])).normalized()
				var record: int = _triangles.size()
				_triangles.append_array(PackedVector3Array([a, b, c, normal]))
				var low: Vector3i = Vector3i((a.min(b).min(c) / CELL).floor())
				var high: Vector3i = Vector3i((a.max(b).max(c) / CELL).floor())
				for x in range(low.x, high.x + 1):
					for y in range(low.y, high.y + 1):
						for z in range(low.z, high.z + 1):
							var cell: Vector3i = Vector3i(x, y, z)
							if not _triangle_cells.has(cell):
								_triangle_cells[cell] = []
							_triangle_cells[cell].append(record)
	var triangle_mesh: TriangleMesh = TriangleMesh.new()
	_check(triangle_mesh.create_from_faces(faces), "Independent triangle queries contain the actual rendered grape surfaces")
	return triangle_mesh


func _measure_grasp(hand: MuseumGlove, body: RigidBody3D, _bvh: TriangleMesh, context: String, require_contact: bool = true) -> Dictionary:
	var pose: Dictionary = _joint_points(hand)
	var hand_to_fruit: Transform3D = body.global_transform.affine_inverse() * hand.global_transform
	var digits: Dictionary = {}
	var contacting: int = 0
	var independently_curled: int = 0
	var deepest: float = 0.0
	var all_queries_valid: bool = true
	for digit: Dictionary in hand.get("_digits"):
		var points: Array = pose[digit["name"]]
		var minimum_gap: float = INF
		var distal_gap: float = INF
		var pip: float = (points[1] - points[0]).angle_to(points[2] - points[1])
		var dip: float = (points[2] - points[1]).angle_to(points[3] - points[2])
		for joint in range(3):
			var pad: float = float(digit["radius"]) * [0.94, 0.80, 0.70][joint] * 1.05
			for sample in range(1, 5):
				var point: Vector3 = hand_to_fruit * (points[joint] as Vector3).lerp(points[joint + 1], float(sample) / 4.0)
				var clearance: float = _surface_distance(point)
				all_queries_valid = all_queries_valid and is_finite(clearance)
				var gap: float = clearance - pad
				minimum_gap = minf(minimum_gap, gap)
				if joint == 2:
					distal_gap = minf(distal_gap, gap)
		if digit["name"] != "thumb" and minimum_gap < 0.012:
			contacting += 1
		if digit["name"] != "thumb" and pip > 0.12 and dip > 0.08:
			independently_curled += 1
		deepest = minf(deepest, minimum_gap)
		digits[digit["name"]] = {"pad_gap_m": minimum_gap if is_finite(minimum_gap) else null, "distal_gap_m": distal_gap if is_finite(distal_gap) else null, "pip_degrees": rad_to_deg(pip), "dip_degrees": rad_to_deg(dip)}
	_check(all_queries_valid, context + ": every sampled phalanx has a real nearby triangle query")
	_check(deepest > -0.008, context + ": no finger segment sinks more than 8 mm through the actual berry surface")
	if require_contact:
		_check(contacting >= 3, context + ": at least three finger pads reach the actual grape surface within 12 mm")
		_check(independently_curled >= 3, context + ": at least three fingers visibly bend both middle and distal joints")
		_check(digits["thumb"]["distal_gap_m"] != null and float(digits["thumb"]["distal_gap_m"]) < 0.015, context + ": thumb distal pad reaches actual fruit rather than only a clamped IK target")
		_check(int(hand.finger_contacts.get("thumb", 0)) == 1, context + ": the thumb solver found and reached a real opposing contact")
	var target_error: Variant = hand.get("thumb_contact_error")
	var rendered_tip: Vector3 = hand_to_fruit * (pose["thumb"][-1] as Vector3)
	var thumb_points: Array = hand.get("_thumb_closed")
	var fitted_tip: Vector3 = (hand.get("_model_to_fruit") as Transform3D) * (thumb_points[-1] as Vector3) if not thumb_points.is_empty() else rendered_tip
	return {"digits": digits, "contacting_fingers": contacting, "curled_fingers": independently_curled, "deepest_pad_gap_m": deepest, "grip_amount": hand.grip_amount, "thumb_target_error_m": target_error if target_error != null and is_finite(float(target_error)) else null, "thumb_reported_contact": int(hand.finger_contacts.get("thumb", 0)), "thumb_fit_to_rendered_tip_m": rendered_tip.distance_to(fitted_tip), "thumb_rendered_tip_fruit": [rendered_tip.x, rendered_tip.y, rendered_tip.z], "thumb_fitted_tip_fruit": [fitted_tip.x, fitted_tip.y, fitted_tip.z]}


func _check_surface_sign(context: String) -> void:
	var selected: int = -1
	var outermost: float = -INF
	for index in range(0, _triangles.size(), 4):
		var center: Vector3 = (_triangles[index] + _triangles[index + 1] + _triangles[index + 2]) / 3.0
		if center.y > -0.55 and center.y < -0.20 and _triangles[index + 3].x > 0.8 and center.x > outermost:
			selected = index
			outermost = center.x
	_check(selected >= 0, context + ": contact QA locates a reference outer berry face")
	if selected >= 0:
		var center: Vector3 = (_triangles[selected] + _triangles[selected + 1] + _triangles[selected + 2]) / 3.0
		var distance: float = _surface_distance(center + _triangles[selected + 3] * 0.001)
		_check(distance > 0.0005 and distance < 0.0015, context + ": authored normals give positive clearance for a known outside point")


func _surface_distance(point: Vector3) -> float:
	var cell: Vector3i = Vector3i((point / CELL).floor())
	var nearest_squared: float = INF
	var signed_distance: float = INF
	var visited: Dictionary = {}
	for x in range(-2, 3):
		for y in range(-2, 3):
			for z in range(-2, 3):
				for index: int in _triangle_cells.get(cell + Vector3i(x, y, z), []):
					if visited.has(index):
						continue
					visited[index] = true
					var closest: Vector3 = _closest_on_triangle(point, _triangles[index], _triangles[index + 1], _triangles[index + 2])
					var offset: Vector3 = point - closest
					var squared: float = offset.length_squared()
					if squared < nearest_squared:
						nearest_squared = squared
						signed_distance = sqrt(squared) * (-1.0 if offset.dot(_triangles[index + 3]) < 0.0 else 1.0)
	# An unusually distant open fingertip must still be measured, not silently
	# omitted from contact/penetration checks because its local bins were empty.
	if not is_finite(signed_distance):
		for index in range(0, _triangles.size(), 4):
			var closest: Vector3 = _closest_on_triangle(point, _triangles[index], _triangles[index + 1], _triangles[index + 2])
			var offset: Vector3 = point - closest
			var squared: float = offset.length_squared()
			if squared < nearest_squared:
				nearest_squared = squared
				signed_distance = sqrt(squared) * (-1.0 if offset.dot(_triangles[index + 3]) < 0.0 else 1.0)
	return signed_distance


func _closest_on_triangle(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab: Vector3 = b - a
	var ac: Vector3 = c - a
	var ap: Vector3 = p - a
	var d1: float = ab.dot(ap)
	var d2: float = ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp: Vector3 = p - b
	var d3: float = ab.dot(bp)
	var d4: float = ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc: float = d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / maxf(d1 - d3, 0.0000001))
	var cp: Vector3 = p - c
	var d5: float = ab.dot(cp)
	var d6: float = ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb: float = d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / maxf(d2 - d6, 0.0000001))
	var va: float = d3 * d6 - d5 * d4
	if va <= 0.0 and d4 - d3 >= 0.0 and d5 - d6 >= 0.0:
		return b + (c - b) * ((d4 - d3) / maxf((d4 - d3) + (d5 - d6), 0.0000001))
	var denom: float = va + vb + vc
	if absf(denom) < 0.000000000001:
		return a
	return a + ab * (vb / denom) + ac * (vc / denom)


func _capture(id: String) -> void:
	if not capture:
		return
	await RenderingServer.frame_post_draw
	var error: Error = get_viewport().get_texture().get_image().save_png("res://work/natural_grasp_" + id + ".png")
	_check(error == OK, "Rendered grasp capture saved for " + id)
