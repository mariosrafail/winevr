extends AnimatableBody3D
class_name MuseumGlove

# Continuous anatomical mesh with sixteen bones, including an opposing thumb.
const HAND_SCENE: PackedScene = preload("res://assets/models/museum_hand/museum_hand.glb")
const PROFILE_ROWS: int = 40
const PROFILE_ANGLES: int = 48
static var _profile_cache: Dictionary = {}
var grip_target: float = 0.0
var grip_amount: float = 0.0
var is_left: bool = false
var skeleton: Skeleton3D
var finger_contacts: Dictionary = {}
var finger_angles: Dictionary = {}
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

func _ready() -> void:
	collision_layer = 16
	collision_mask = 4
	sync_to_physics = true
	_model = HAND_SCENE.instantiate() as Node3D
	_model.name = "AnatomicalHand"
	add_child(_model)
	_model.scale = Vector3(-1.05 if is_left else 1.05, 1.05, 1.05)
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
	for mesh in _model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(0.075, 0.026, 0.095)
	collision.shape = shape
	collision.position.z = 0.01
	add_child(collision)

func prepare_grasp(body: RigidBody3D) -> void:
	var key: int = body.get_instance_id()
	if not _profile_cache.has(key):
		_profile_cache[key] = _measure_fruit(body)

func start_grasp(body: RigidBody3D, picked_point: Vector3, view: Camera3D) -> void:
	_fruit = body
	add_collision_exception_with(body)
	prepare_grasp(body)
	_profile = _profile_cache[body.get_instance_id()]
	_grasp_center = Vector3(0, clampf(picked_point.y, -0.52, -0.20), 0)
	var up: Vector3 = body.global_basis.y.normalized()
	var outside: Vector3 = view.global_basis.z * 0.90 + view.global_basis.x * 0.44
	outside = (outside - up * outside.dot(up)).normalized()
	var tangent: Vector3 = up.cross(outside).normalized()
	_outward = body.global_basis.inverse() * outside
	_tangent = body.global_basis.inverse() * tangent
	var radius: float = _radius_at(_grasp_center.y, atan2(_outward.z, _outward.x))
	var basis: Basis = Basis(-up, -outside, tangent)
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
	_closed_angles.clear()
	_thumb_closed.clear()
	for digit in _digits:
		if digit["name"] != "thumb":
			_closed_angles[digit["name"]] = _solve_finger(digit)
	grip_target = 1.0

func grasp_transform() -> Transform3D:
	return _fruit.global_transform * _grasp_local if is_instance_valid(_fruit) else global_transform

func release_grasp() -> void:
	if is_instance_valid(_fruit):
		remove_collision_exception_with(_fruit)
	_fruit = null
	grip_target = 0.0
	finger_contacts.clear()

func _process(delta: float) -> void:
	if skeleton == null or not visible:
		return
	grip_amount = move_toward(grip_amount, grip_target, delta * 4.5)
	for digit in _digits:
		if digit["name"] == "thumb":
			_pose_thumb(digit)
		else:
			_pose_finger(digit)

func _solve_finger(digit: Dictionary) -> Array[float]:
	# Couple proximal/distal flexion anatomically, rather than locking a straight
	# phalanx at its first contact. Each finger finds its own collision-limited curl.
	var lo: float = 0.0
	var hi: float = 1.0
	var contact: bool = false
	for step in range(1, 33):
		var curl: float = float(step) / 32.0
		if _curl_touches(digit, curl):
			hi = curl
			contact = true
			break
		lo = curl
	if contact:
		for iteration in range(9):
			var middle: float = (lo + hi) * 0.5
			if _curl_touches(digit, middle):
				hi = middle
			else:
				lo = middle
	finger_contacts[digit["name"]] = 1 if contact else 0
	return [lo * 0.40, lo * 1.35, lo * 1.00]

func _curl_touches(digit: Dictionary, curl: float) -> bool:
	var rest: Array[Vector3] = digit["points"]
	var point: Vector3 = rest[0]
	var angle: float = 0.0
	for j in range(3):
		angle += curl * [0.40, 1.35, 1.00][j]
		var end: Vector3 = point + Basis(Vector3.RIGHT, angle) * Vector3(0, 0, -rest[j].distance_to(rest[j + 1]))
		if _segment_touches(point, end, float(digit["radius"]) * [0.94, 0.80, 0.70][j]):
			return true
		point = end
	return false

func _pose_finger(digit: Dictionary) -> void:
	var rest_points: Array[Vector3] = digit["points"]
	var points: Array[Vector3] = [rest_points[0]]
	var cumulative: float = 0.0
	var angles: Array[float] = []
	var closed: Array = _closed_angles.get(digit["name"], [0.8, 1.1, 0.7])
	for j in range(3):
		var flex: float = lerpf([0.05, 0.10, 0.06][j], float(closed[j]), smoothstep(0.0, 1.0, grip_amount))
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
		var radial: Vector3 = (_outward * cos(0.40) - _tangent * sin(0.40)).normalized()
		var height: float = _grasp_center.y + 0.050
		var radius: float = _radius_at(height, atan2(radial.z, radial.x))
		var contact: Vector3 = Vector3(0, height, 0) + radial * (radius + 0.008)
		var target: Vector3 = _model_to_fruit.affine_inverse() * contact
		var lengths: Array[float] = []
		var total: float = 0.0
		for j in range(3):
			lengths.append(source[j].distance_to(source[j + 1]))
			total += lengths[-1]
		target = source[0] + (target - source[0]).limit_length(total * 0.995)
		# FABRIK opposition: the thumb approaches from above, against the fingers.
		points[1].y -= 0.012
		points[2].y -= 0.012
		for iteration in range(12):
			points[3] = target
			for j in range(2, -1, -1):
				points[j] = points[j + 1] + (points[j] - points[j + 1]).normalized() * lengths[j]
			points[0] = source[0]
			for j in range(3):
				points[j + 1] = points[j] + (points[j + 1] - points[j]).normalized() * lengths[j]
		_thumb_closed = points.duplicate()
		finger_contacts["thumb"] = 1 if points[-1].distance_to(target) < 0.012 else 0
	if not _thumb_closed.is_empty():
		for j in range(1, 4):
			points[j] = source[j].lerp(_thumb_closed[j], smoothstep(0.0, 1.0, grip_amount))
	_apply_chain(digit, points)

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
	for step in range(1, 7):
		var point: Vector3 = _model_to_fruit * start.lerp(end, float(step) / 6.0)
		var radius: float = _radius_at(point.y, atan2(point.z, point.x))
		if Vector2(point.x, point.z).length() < radius + pad * 1.05 + 0.001:
			return true
	return false

func _radius_at(height: float, angle: float) -> float:
	var row: int = clampi(int((-height - 0.10) / 0.70 * PROFILE_ROWS), 0, PROFILE_ROWS - 1)
	var column: int = posmod(int((angle + PI) / TAU * PROFILE_ANGLES), PROFILE_ANGLES)
	return _profile[row * PROFILE_ANGLES + column] if not _profile.is_empty() else 0.09

func _measure_fruit(body: RigidBody3D) -> PackedFloat32Array:
	var bins: PackedFloat32Array = PackedFloat32Array()
	bins.resize(PROFILE_ROWS * PROFILE_ANGLES)
	for raw in body.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = raw as MeshInstance3D
		var transform: Transform3D = body.global_transform.affine_inverse() * instance.global_transform
		for surface in range(instance.mesh.get_surface_count()):
			var vertices: PackedVector3Array = instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for i in range(0, vertices.size(), 6):
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
				for dx in range(-2, 3):
					radius = maxf(radius, bins[clampi(row + dy, 0, PROFILE_ROWS - 1) * PROFILE_ANGLES + posmod(col + dx, PROFILE_ANGLES)])
			envelope[row * PROFILE_ANGLES + col] = radius
	return envelope
