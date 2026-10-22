extends AnimatableBody3D
class_name MuseumGlove

# Continuous anatomical mesh with sixteen bones, including an opposing thumb.
const HAND_SCENE: PackedScene = preload("res://assets/models/museum_hand/museum_hand.glb")
const SLEEVE_SCRIPT: Script = preload("res://scripts/winery/museum_sleeve.gd")
const SKIN_SCRIPT: Script = preload("res://scripts/winery/museum_skin.gd")
const PROFILE_ROWS: int = 64
const PROFILE_ANGLES: int = 96
static var _profile_cache: Dictionary = {}
static var _surface_cache: Dictionary = {}
var grip_target: float = 0.0
var grip_amount: float = 0.0
var is_left: bool = false
var skeleton: Skeleton3D
var finger_contacts: Dictionary = {}
var finger_angles: Dictionary = {}
var thumb_contact_error: float = INF
var _model: Node3D
var _digits: Array[Dictionary] = []
var _rest: Dictionary = {}
var _fruit: RigidBody3D
var _profile: PackedFloat32Array
var _grasp_local: Transform3D
var _grasp_center: Vector3
var _outward: Vector3
var _tangent: Vector3
var _model_to_fruit: Transform3D
var _model_to_skeleton: Transform3D
var _closed_angles: Dictionary = {}
var _thumb_closed: Array[Vector3] = []
var _sleeve: MeshInstance3D
var _authored_cuff: MeshInstance3D
var _skin_material: ShaderMaterial
var _tracked_grasp: bool = false
var _fit_elapsed: float = 0.0
var pinching: bool = false
var pinch_center: Vector3 = Vector3(-0.039, 0.025, -0.032)
var pinch_errors: Dictionary = {}
var _pinch_chains: Dictionary = {}
var _pinch_releasing: bool = false
var _pinch_surface: TriangleMesh
var pinch_surface_transform: Transform3D
var pinch_clearances: Dictionary = {}
var _pinch_skin_samples: Dictionary = {}
var _pinch_skin: Skin

func set_pinch_surface(mesh: Mesh, world_transform: Transform3D) -> void:
	var faces: PackedVector3Array = mesh.get_faces()
	for index in range(faces.size()):
		faces[index] *= 32.0
	_pinch_surface = TriangleMesh.new()
	_pinch_surface.create_from_faces(faces)
	pinch_surface_transform = world_transform
	pinch_clearances.clear()

func _cache_pinch_skin(mesh: MeshInstance3D) -> void:
	_pinch_skin = mesh.skin
	for name: String in ["index", "thumb"]:
		_pinch_skin_samples[name] = []
	for surface in range(mesh.mesh.get_surface_count()):
		var arrays: Array = mesh.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		for vertex in range(0, vertices.size(), 2):
			var point: Vector3 = (_model.global_transform.affine_inverse() * mesh.global_transform) * vertices[vertex]
			for digit: Dictionary in _digits:
				var name: String = digit["name"]
				if name not in ["index", "thumb"] or point.distance_to(digit["points"][3]) > 0.027:
					continue
				var bindings: Array[Dictionary] = []
				for influence in range(4):
					var slot: int = vertex * 4 + influence
					if weights[slot] <= 0.0:
						continue
					var bind: int = bones[slot]
					var bone: int = _pinch_skin.get_bind_bone(bind)
					if not _pinch_skin.get_bind_name(bind).is_empty():
						bone = skeleton.find_bone(_pinch_skin.get_bind_name(bind))
					bindings.append({"bone": bone, "point": _pinch_skin.get_bind_pose(bind) * vertices[vertex], "weight": weights[slot]})
				_pinch_skin_samples[name].append(bindings)
	for name: String in ["index", "thumb"]:
		var samples: Array = _pinch_skin_samples[name]
		if samples.size() > 192:
			var reduced: Array = []
			for index in range(192):
				reduced.append(samples[index * samples.size() / 192])
			_pinch_skin_samples[name] = reduced

func _pinch_gap(name: String) -> Dictionary:
	var minimum: float = INF
	var normal: Vector3 = Vector3.ZERO
	var inverse: Transform3D = pinch_surface_transform.affine_inverse()
	for sample: Array in _pinch_skin_samples.get(name, []):
		var point: Vector3 = Vector3.ZERO
		for binding: Dictionary in sample:
			point += (skeleton.get_bone_global_pose(int(binding["bone"])) * Vector3(binding["point"])) * float(binding["weight"])
		point = skeleton.global_transform * point
		var local: Vector3 = inverse * point
		if local.length_squared() < 0.0000001:
			continue
		var hit: Dictionary = _pinch_surface.intersect_segment(local.normalized() * 6.4, Vector3.ZERO)
		if hit.is_empty():
			continue
		var boundary: Vector3 = pinch_surface_transform * (Vector3(hit["position"]) / 32.0)
		var outward: Vector3 = (point - pinch_surface_transform.origin).normalized()
		var gap: float = (point - boundary).dot(outward)
		if gap < minimum:
			minimum = gap
			normal = (pinch_surface_transform.basis.inverse().transposed() * Vector3(hit["normal"])).normalized()
			if normal.dot(outward) < 0.0:
				normal = -normal
	return {"gap": minimum, "normal": normal}

func _fit_pinch_skin(digit: Dictionary, points: Array[Vector3]) -> void:
	if _pinch_surface == null or _pinch_releasing or grip_amount < 0.15:
		return
	var name: String = digit["name"]
	var source: Array[Vector3] = digit["points"]
	for refinement in range(5):
		var contact: Dictionary = _pinch_gap(name)
		pinch_clearances[name] = contact["gap"]
		if not is_finite(float(contact["gap"])) or absf(float(contact["gap"]) - 0.0003) < 0.0004:
			break
		if grip_amount < 0.99 and float(contact["gap"]) >= 0.0003:
			break
		var correction: float = clampf(0.0003 - float(contact["gap"]), -0.002, 0.003)
		var target: Vector3 = points[3] + _model.global_basis.inverse() * Vector3(contact["normal"]) * correction
		for iteration in range(16):
			points[3] = target
			for j in range(2, -1, -1):
				points[j] = points[j + 1] + (points[j] - points[j + 1]).normalized() * source[j].distance_to(source[j + 1])
			points[0] = source[0]
			for j in range(3):
				points[j + 1] = points[j] + (points[j + 1] - points[j]).normalized() * source[j].distance_to(source[j + 1])
		_apply_chain(digit, points)
	if grip_amount >= 0.99:
		_pinch_chains[name] = points

func start_pinch(radius: float, thumb_radius: float = -1.0) -> void:
	release_grasp()
	pinching = true
	_pinch_releasing = false
	_pinch_chains.clear()
	pinch_errors.clear()
	for digit: Dictionary in _digits:
		var name: String = digit["name"]
		if name not in ["index", "thumb"]:
			_closed_angles[name] = [0.85, 1.20, 0.90]
			continue
		var points: Array[Vector3] = (digit["points"] as Array[Vector3]).duplicate()
		var lengths: Array[float] = []
		for j in range(3):
			lengths.append(points[j].distance_to(points[j + 1]))
		var root: Vector3 = points[0]
		var pad: float = float(digit["radius"]) * 0.65
		var surface_radius: float = thumb_radius if name == "thumb" and thumb_radius > 0.0 else radius
		var target: Vector3 = pinch_center + Vector3.RIGHT * (surface_radius / 1.05 + pad) * (-1.0 if name == "thumb" else 1.0)
		# Seed a bent chain above the palm; preserve each phalanx length.
		points[1] += Vector3(0, 0.045, 0)
		points[2] += Vector3(0, 0.040, 0)
		for iteration in range(48):
			points[3] = target
			for j in range(2, -1, -1):
				points[j] = points[j + 1] + (points[j] - points[j + 1]).normalized() * lengths[j]
			points[0] = root
			for j in range(3):
				points[j + 1] = points[j] + (points[j + 1] - points[j]).normalized() * lengths[j]
		_pinch_chains[name] = points
		pinch_errors[name] = points[3].distance_to(target)
	grip_target = 1.0

func pinch_transform(point: Vector3, view: Camera3D) -> Transform3D:
	var wrist_basis: Basis = view.global_basis * Basis.from_euler(Vector3(0.90, -0.15, -0.35))
	return Transform3D(wrist_basis, point - wrist_basis * (_model.transform * pinch_center))

func _pose_pinch_digit(digit: Dictionary) -> void:
	var source: Array[Vector3] = digit["points"]
	var closed: Array[Vector3] = _pinch_chains[digit["name"]]
	var points: Array[Vector3] = [source[0]]
	var blend: float = smoothstep(0.0, 1.0, grip_amount)
	for j in range(3):
		var open_direction: Vector3 = (source[j + 1] - source[j]).normalized()
		var closed_direction: Vector3 = (closed[j + 1] - closed[j]).normalized()
		points.append(points[j] + open_direction.slerp(closed_direction, blend) * source[j].distance_to(source[j + 1]))
	_apply_chain(digit, points)
	_fit_pinch_skin(digit, points)

func _ready() -> void:
	collision_layer = 16
	collision_mask = 4
	sync_to_physics = true
	_model = HAND_SCENE.instantiate() as Node3D
	_model.name = "AnatomicalHand"
	add_child(_model)
	_model.scale = Vector3(-1.05 if is_left else 1.05, 1.05, 1.05)
	SKIN_SCRIPT.apply_to(_model)
	var skin: MeshInstance3D = _model.find_child("AnatomicalHandSkin", true, false) as MeshInstance3D
	_skin_material = skin.get_active_material(0).duplicate() as ShaderMaterial
	skin.set_surface_override_material(0, _skin_material)
	skeleton = _model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_model_to_skeleton = skeleton.global_transform.affine_inverse() * _model.global_transform
	for index in range(skeleton.get_bone_count()):
		_rest[index] = skeleton.get_bone_global_rest(index)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/museum_hand/hand_rig.json")) as Dictionary
	for raw in source["digits"]:
		var points: Array[Vector3] = []
		var indices: Array[int] = []
		for p in raw["points"]:
			points.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
		for j in range(3):
			indices.append(skeleton.find_bone(str(raw["name"]) + "_" + str(j)))
		_digits.append({"name": str(raw["name"]), "points": points, "bones": indices, "radius": float(raw["radius"])})
	_cache_pinch_skin(skin)
	for mesh in _model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if str(mesh.name).contains("Museum_jacket") or str(mesh.name).contains("Museum jacket"):
			_authored_cuff = mesh as MeshInstance3D
	_sleeve = SLEEVE_SCRIPT.new() as MeshInstance3D
	_sleeve.name = "ContinuousSleeve"
	_model.add_child(_sleeve)
	_sleeve.visible = false
	if _authored_cuff != null:
		_sleeve.set_fabric(_authored_cuff.get_active_material(0))
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(0.075, 0.026, 0.095)
	collision.shape = shape
	collision.position.z = 0.01
	add_child(collision)

func update_arm(view: Camera3D, immersive: bool) -> void:
	# A desktop hand needs to continue out of the frame. In XR the wrist remains
	# entirely controller-driven; never invent an elbow anchored to head movement.
	var continuous: bool = is_visible_in_tree() and view != null and not immersive
	_sleeve.visible = continuous
	if _authored_cuff != null:
		_authored_cuff.visible = not continuous
	if continuous:
		_sleeve.update_from_view(view)
	_skin_material.set_shader_parameter("forearm_bend", _sleeve.forearm_bend if continuous else Vector2.ZERO)
	_skin_material.set_shader_parameter("forearm_length", SLEEVE_SCRIPT.FOREARM_LENGTH if continuous else 1.0)

func prepare_grasp(body: RigidBody3D) -> void:
	var key: int = body.get_instance_id()
	if not _profile_cache.has(key):
		_profile_cache[key] = _measure_fruit(body)
		var surfaces: Array[Dictionary] = []
		for node in body.find_children("*", "MeshInstance3D", true, false):
			var instance: MeshInstance3D = node as MeshInstance3D
			var local: Transform3D = body.global_transform.affine_inverse() * instance.global_transform
			# Imported grapes contain sub-millimetre triangles. Query in a larger
			# coordinate space so intersection tolerances do not discard them.
			var faces: PackedVector3Array = instance.mesh.get_faces()
			for vertex in range(faces.size()):
				faces[vertex] *= 32.0
			var triangles: TriangleMesh = TriangleMesh.new()
			triangles.create_from_faces(faces)
			local = local.scaled_local(Vector3.ONE / 32.0)
			surfaces.append({"mesh": triangles, "transform": local, "inverse": local.affine_inverse()})
		_surface_cache[key] = surfaces

func start_grasp(body: RigidBody3D, picked_point: Vector3, view: Camera3D, tracked_wrist: bool = false) -> void:
	pinching = false
	_pinch_releasing = false
	_fruit = body
	_tracked_grasp = tracked_wrist
	_fit_elapsed = 0.0
	add_collision_exception_with(body)
	prepare_grasp(body)
	_profile = _profile_cache[body.get_instance_id()]
	if tracked_wrist:
		_grasp_local = body.global_transform.affine_inverse() * global_transform
		_model_to_fruit = _grasp_local * _model.transform
		_solve_grasp_targets()
		grip_target = 1.0
		return
	_grasp_center = Vector3(0, clampf(picked_point.y, -0.52, -0.20), 0)
	var up: Vector3 = body.global_basis.y.normalized()
	var outside: Vector3 = view.global_basis.z * 0.90 + view.global_basis.x * (-0.44 if is_left else 0.44)
	outside -= up * outside.dot(up)
	if outside.length_squared() < 0.0001:
		outside = view.global_basis.x - up * view.global_basis.x.dot(up)
	if outside.length_squared() < 0.0001:
		outside = up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT)
	outside = outside.normalized()
	var tangent: Vector3 = up.cross(outside).normalized() * (-1.0 if is_left else 1.0)
	_outward = body.global_basis.inverse() * outside
	_tangent = body.global_basis.inverse() * tangent
	var radius: float = _radius_at(_grasp_center.y, atan2(_outward.z, _outward.x))
	var basis: Basis = Basis(up if is_left else -up, -outside, tangent)
	_grasp_local = Transform3D(body.global_basis.inverse() * basis, _grasp_center + _outward * (radius + 0.020))
	# Fit all four straight fingers outside the uneven berry envelope before
	# closing them; an already intersecting root would lock every joint straight.
	for adjustment in range(30):
		_model_to_fruit = _grasp_local * _model.transform
		var clear: bool = true
		for digit in _digits:
			if digit["name"] == "thumb":
				continue
			var points: Array[Vector3] = digit["points"]
			for j in range(3):
				if _segment_touches(points[j], points[j + 1], float(digit["radius"]) * 0.95):
					clear = false
		if clear:
			break
		_grasp_local.origin += _outward * 0.002
	_model_to_fruit = _grasp_local * _model.transform
	_solve_grasp_targets()
	grip_target = 1.0

func _solve_grasp_targets() -> void:
	_closed_angles.clear()
	_thumb_closed.clear()
	finger_contacts.clear()
	for digit in _digits:
		if digit["name"] != "thumb":
			_closed_angles[digit["name"]] = _solve_finger(digit)

func grasp_transform() -> Transform3D:
	return _fruit.global_transform * _grasp_local if is_instance_valid(_fruit) else global_transform

func release_grasp() -> void:
	_pinch_releasing = pinching
	if is_instance_valid(_fruit):
		remove_collision_exception_with(_fruit)
	_fruit = null
	_tracked_grasp = false
	grip_target = 0.0
	finger_contacts.clear()

func _process(delta: float) -> void:
	if skeleton == null or not visible:
		return
	if _tracked_grasp and is_instance_valid(_fruit):
		_fit_elapsed += delta
		var current: Transform3D = _fruit.global_transform.affine_inverse() * global_transform * _model.transform
		var moved: bool = current.origin.distance_to(_model_to_fruit.origin) > 0.0025
		var turned: bool = current.basis.z.normalized().dot(_model_to_fruit.basis.z.normalized()) < 0.9994 or current.basis.y.normalized().dot(_model_to_fruit.basis.y.normalized()) < 0.9994
		if _fit_elapsed >= 0.05 and (moved or turned):
			_fit_elapsed = 0.0
			_model_to_fruit = current
			_solve_grasp_targets()
	grip_amount = move_toward(grip_amount, grip_target, delta * 4.5)
	if _pinch_releasing and grip_amount <= 0.001:
		pinching = false
		_pinch_releasing = false
	for digit in _digits:
		if pinching and digit["name"] in ["thumb", "index"]:
			_pose_pinch_digit(digit)
		elif digit["name"] == "thumb":
			_pose_thumb(digit)
		else:
			_pose_finger(digit)

func _solve_finger(digit: Dictionary) -> Array[float]:
	# Proximal contact stops that joint, not the whole digit. The other two
	# joints can continue around the berry, like a finger closing around a cup.
	var angles: Array[float] = [0.0, 0.0, 0.0]
	var limits: Array[float] = [0.70, 1.55, 1.05]
	for step in range(32):
		for joint in range(3):
			var candidate: Array[float] = angles.duplicate()
			candidate[joint] = minf(limits[joint], angles[joint] + limits[joint] / 32.0)
			# Distal flexion stays coupled to the middle joint without preventing
			# a fingertip from settling after the proximal pad has made contact.
			if joint == 2:
				candidate[joint] = minf(candidate[joint], angles[1] * 0.80 + 0.12)
			if _finger_clearance(digit, candidate, joint) >= 0.0:
				angles = candidate
			else:
				var low: float = angles[joint]
				var high: float = candidate[joint]
				for refinement in range(6):
					candidate[joint] = (low + high) * 0.5
					if _finger_clearance(digit, candidate, joint) >= 0.0:
						low = candidate[joint]
					else:
						high = candidate[joint]
				angles[joint] = low
	finger_contacts[digit["name"]] = 1 if _finger_clearance(digit, angles) < 0.004 else 0
	return angles

func _finger_clearance(digit: Dictionary, angles: Array[float], from_joint: int = 0) -> float:
	var rest: Array[Vector3] = digit["points"]
	var point: Vector3 = rest[0]
	var angle: float = 0.0
	var clearance: float = INF
	for j in range(3):
		angle += angles[j]
		var end: Vector3 = point + Basis(Vector3.RIGHT, angle) * Vector3(0, 0, -rest[j].distance_to(rest[j + 1]))
		if j >= from_joint:
			clearance = minf(clearance, _segment_clearance(point, end, float(digit["radius"]) * [0.94, 0.80, 0.70][j]))
		point = end
	return clearance

func _pose_finger(digit: Dictionary) -> void:
	var rest_points: Array[Vector3] = digit["points"]
	var points: Array[Vector3] = [rest_points[0]]
	var cumulative: float = 0.0
	var angles: Array[float] = []
	var closed: Array = _closed_angles.get(digit["name"], [0.8, 1.1, 0.7])
	var delay: float = {"index": 0.04, "middle": 0.0, "ring": 0.02, "little": 0.06}.get(digit["name"], 0.0)
	var blend: float = smoothstep(0.0, 1.0, clampf((grip_amount - delay) / (1.0 - delay), 0.0, 1.0))
	for j in range(3):
		var flex: float = lerpf([0.06, 0.14, 0.08][j], float(closed[j]), blend)
		cumulative += flex
		angles.append(flex)
		var length: float = rest_points[j].distance_to(rest_points[j + 1])
		points.append(points[-1] + Basis(Vector3.RIGHT, cumulative) * Vector3(0, 0, -length))
	finger_angles[digit["name"]] = angles
	_apply_chain(digit, points)

func _pose_thumb(digit: Dictionary) -> void:
	var source: Array[Vector3] = digit["points"]
	var points: Array[Vector3] = source.duplicate()
	if is_instance_valid(_fruit) and _thumb_closed.is_empty():
		var lengths: Array[float] = []
		var total: float = 0.0
		for j in range(3):
			lengths.append(source[j].distance_to(source[j + 1]))
			total += lengths[-1]
		var target: Vector3 = source[-1]
		var best_score: float = INF
		var inverse_model: Transform3D = _model_to_fruit.affine_inverse()
		var open_tip: Vector3 = _model_to_fruit * source[-1]
		# Find a reachable pad contact on the upper/opposing side. Do not label
		# a reach-clamped point in empty space as touching the fruit.
		for height_step in range(11):
			var height: float = _grasp_center.y + 0.015 + height_step * 0.007
			if _tracked_grasp:
				height = open_tip.y - 0.042 + height_step * 0.007
			for angle_step in range(19):
				var around: float = -0.24 + angle_step * 0.05
				var radial: Vector3 = (_outward * cos(around) - _tangent * sin(around)).normalized()
				if _tracked_grasp:
					var angle: float = atan2(open_tip.z, open_tip.x) - 0.45 + angle_step * 0.05
					radial = Vector3(cos(angle), 0, sin(angle))
				var contact: Dictionary = _berry_contact(height, radial)
				if contact.is_empty():
					continue
				var candidate: Vector3 = inverse_model * (contact["position"] + contact["normal"] * 0.007)
				if candidate.distance_to(source[0]) > total * 0.96:
					continue
				var score: float = candidate.distance_to(source[-1]) + absf(around - 0.30) * 0.012
				if score < best_score:
					best_score = score
					target = candidate
		# FABRIK opposition: the thumb approaches from above, against the fingers.
		points[1].y -= 0.012
		points[2].y -= 0.012
		for iteration in range(18):
			points[3] = target
			for j in range(2, -1, -1):
				points[j] = points[j + 1] + (points[j] - points[j + 1]).normalized() * lengths[j]
			points[0] = source[0]
			for j in range(3):
				points[j + 1] = points[j] + (points[j + 1] - points[j]).normalized() * lengths[j]
		_thumb_closed = points.duplicate()
		thumb_contact_error = points[-1].distance_to(target) if best_score < INF else INF
		finger_contacts["thumb"] = 1 if thumb_contact_error < 0.003 else 0
	if not _thumb_closed.is_empty():
		var blend: float = smoothstep(0.0, 1.0, grip_amount)
		for j in range(3):
			var open_direction: Vector3 = (source[j + 1] - source[j]).normalized()
			var closed_direction: Vector3 = (_thumb_closed[j + 1] - _thumb_closed[j]).normalized()
			points[j + 1] = points[j] + open_direction.slerp(closed_direction, blend) * source[j].distance_to(source[j + 1])
	_apply_chain(digit, points)

func _berry_contact(height: float, radial: Vector3) -> Dictionary:
	# The thumb must rest on a real berry, not the inflated silhouette used for
	# conservative finger collision. Native triangle queries are cached per bunch.
	var start: Vector3 = Vector3(0, height, 0) + radial * 0.50
	var end: Vector3 = Vector3(0, height, 0)
	var nearest: float = INF
	var result: Dictionary = {}
	for surface in _surface_cache.get(_fruit.get_instance_id(), []):
		var inverse: Transform3D = surface["inverse"]
		var hit: Dictionary = (surface["mesh"] as TriangleMesh).intersect_segment(inverse * start, inverse * end)
		if hit.is_empty():
			continue
		var transform: Transform3D = surface["transform"]
		var point: Vector3 = transform * (hit["position"] as Vector3)
		var distance: float = start.distance_squared_to(point)
		if distance < nearest:
			nearest = distance
			var normal: Vector3 = (transform.basis.inverse().transposed() * (hit["normal"] as Vector3)).normalized()
			if normal.dot(radial) < 0.0:
				normal = -normal
			result = {"position": point, "normal": normal}
	return result

func _apply_chain(digit: Dictionary, points: Array[Vector3]) -> void:
	var parent: Transform3D = skeleton.get_bone_global_rest(skeleton.find_bone("palm"))
	for j in range(3):
		var index: int = digit["bones"][j]
		var rest: Transform3D = _rest[index]
		var start: Vector3 = _model_to_skeleton * points[j]
		var end: Vector3 = _model_to_skeleton * points[j + 1]
		var direction: Vector3 = (end - start).normalized()
		var swing: Quaternion = Quaternion(rest.basis.y.normalized(), direction)
		var pose: Transform3D = Transform3D(Basis(swing) * rest.basis, start)
		skeleton.set_bone_pose(index, parent.affine_inverse() * pose)
		parent = pose

func _segment_touches(start: Vector3, end: Vector3, pad: float) -> bool:
	return _segment_clearance(start, end, pad) < 0.0

func _segment_clearance(start: Vector3, end: Vector3, pad: float) -> float:
	var clearance: float = INF
	for step in range(1, 7):
		var point: Vector3 = _model_to_fruit * start.lerp(end, float(step) / 6.0)
		var radius: float = _radius_at(point.y, atan2(point.z, point.x))
		clearance = minf(clearance, Vector2(point.x, point.z).length() - radius - pad * 1.05 - 0.001)
	return clearance

func _radius_at(height: float, angle: float) -> float:
	if _profile.is_empty():
		return 0.09
	if height > -0.10 or height < -0.80:
		return 0.0
	var row: float = clampf((-height - 0.10) / 0.70 * PROFILE_ROWS - 0.5, 0.0, PROFILE_ROWS - 1.0)
	var column: float = (angle + PI) / TAU * PROFILE_ANGLES - 0.5
	var row_a: int = int(floor(row))
	var row_b: int = mini(row_a + 1, PROFILE_ROWS - 1)
	var col_a: int = posmod(int(floor(column)), PROFILE_ANGLES)
	var col_b: int = (col_a + 1) % PROFILE_ANGLES
	var fraction: float = column - floor(column)
	return lerpf(lerpf(_profile[row_a * PROFILE_ANGLES + col_a], _profile[row_a * PROFILE_ANGLES + col_b], fraction), lerpf(_profile[row_b * PROFILE_ANGLES + col_a], _profile[row_b * PROFILE_ANGLES + col_b], fraction), row - floor(row))

func _measure_fruit(body: RigidBody3D) -> PackedFloat32Array:
	var bins: PackedFloat32Array = PackedFloat32Array()
	bins.resize(PROFILE_ROWS * PROFILE_ANGLES)
	for raw in body.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = raw as MeshInstance3D
		var transform: Transform3D = body.global_transform.affine_inverse() * instance.global_transform
		for surface in range(instance.mesh.get_surface_count()):
			var vertices: PackedVector3Array = instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for i in range(0, vertices.size(), 3):
				var point: Vector3 = transform * vertices[i]
				if point.y > -0.10 or point.y < -0.80:
					continue
				var row: int = clampi(int((-point.y - 0.10) / 0.70 * PROFILE_ROWS), 0, PROFILE_ROWS - 1)
				var col: int = posmod(int((atan2(point.z, point.x) + PI) / TAU * PROFILE_ANGLES), PROFILE_ANGLES)
				bins[row * PROFILE_ANGLES + col] = maxf(bins[row * PROFILE_ANGLES + col], Vector2(point.x, point.z).length())
	# Maximum envelope prevents the fingertips from sinking between berries.
	var envelope: PackedFloat32Array = bins.duplicate()
	for row in range(PROFILE_ROWS):
		for col in range(PROFILE_ANGLES):
			var radius: float = 0.025
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					radius = maxf(radius, bins[clampi(row + dy, 0, PROFILE_ROWS - 1) * PROFILE_ANGLES + posmod(col + dx, PROFILE_ANGLES)])
			envelope[row * PROFILE_ANGLES + col] = radius
	return envelope
