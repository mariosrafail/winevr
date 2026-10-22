extends MeshInstance3D

# Continue the authored cuff back to the player's body. The wrist end stays in
# hand space; the elbow end lives below the camera frame, including after resize.
const SIDES: int = 32
const RINGS: int = 56
const FOREARM_LENGTH: float = 0.72
const FABRIC_SHADER: Shader = preload("res://assets/shaders/museum_cotton.gdshader")
var _surface: ArrayMesh = ArrayMesh.new()
var _indices: PackedInt32Array
var _last_end: Vector3 = Vector3.INF
var _last_direction: Vector3 = Vector3.INF
var forearm_bend: Vector2 = Vector2.ZERO
var _last_bend: Vector2 = Vector2.INF

func set_fabric(source: Material) -> void:
	var fabric: ShaderMaterial = ShaderMaterial.new()
	fabric.shader = FABRIC_SHADER
	if source is BaseMaterial3D:
		fabric.set_shader_parameter("fabric_color", (source as BaseMaterial3D).albedo_color)
	material_override = fabric

func _ready() -> void:
	mesh = _surface
	for ring in range(RINGS - 1):
		for side in range(SIDES):
			var a: int = ring * SIDES + side
			var b: int = ring * SIDES + (side + 1) % SIDES
			_indices.append_array(PackedInt32Array([a, a + SIDES, b, b, a + SIDES, b + SIDES]))

func update_from_view(view: Camera3D) -> void:
	var size: Vector2 = view.get_viewport().get_visible_rect().size
	var wrist_depth: float = -view.to_local(global_position).z
	var endpoint: Vector3 = view.project_position(size * Vector2(1.15, 1.50), clampf(wrist_depth * 0.70, 0.30, 0.85))
	var end: Vector3 = to_local(endpoint)
	var direction: Vector3 = (global_basis.inverse() * (view.global_basis.x * 0.45 - view.global_basis.y)).normalized()
	var sideways: Vector2 = Vector2(end.x - 0.003, end.y + 0.003)
	var desired_bend: Vector2 = sideways.normalized() * minf(0.30, sideways.length() * 0.55)
	forearm_bend = forearm_bend.lerp(desired_bend, 1.0 - exp(-get_process_delta_time() * 14.0))
	if end.distance_squared_to(_last_end) < 0.00000001 and direction.distance_squared_to(_last_direction) < 0.00000001 and forearm_bend.distance_squared_to(_last_bend) < 0.00000001:
		return
	_last_end = end
	_last_direction = direction
	_last_bend = forearm_bend
	var cuff_distance: float = (0.208 - 0.035) * FOREARM_LENGTH
	var offset: Vector2 = forearm_bend * cuff_distance * cuff_distance / 0.36
	var start: Vector3 = Vector3(0.003 + offset.x, -0.003 + offset.y, 0.035 + cuff_distance)
	var slope: Vector2 = forearm_bend * cuff_distance / 0.18
	var start_tangent: Vector3 = Vector3(slope.x, slope.y, 1.0).normalized()
	var reach: float = start.distance_to(end)
	# Begin turning at the cuff instead of extending a rigid tube and making
	# a tight elbow. Long handles spread the curve over the whole forearm.
	var control_a: Vector3 = start + start_tangent * reach * 0.32
	var control_b: Vector3 = end - direction * reach * 0.28
	var vertices: PackedVector3Array
	var normals: PackedVector3Array
	var uvs: PackedVector2Array
	vertices.resize(RINGS * SIDES)
	normals.resize(RINGS * SIDES)
	uvs.resize(RINGS * SIDES)
	# Parallel-transport each cross section to avoid twisting or flattening the
	# sleeve when the bunch and wrist rotate during the physical grab.
	var axis: Vector3 = Vector3.RIGHT
	var previous_center: Vector3 = start
	var seam_length: float = 0.0
	for ring in range(RINGS):
		var t: float = float(ring) / (RINGS - 1)
		var center: Vector3 = start.bezier_interpolate(control_a, control_b, end, t)
		var tangent: Vector3 = start.bezier_derivative(control_a, control_b, end, t).normalized()
		var radius: Vector2 = Vector2(0.038, 0.030).lerp(Vector2(0.060, 0.049), smoothstep(0.0, 1.0, t))
		axis = axis - tangent * axis.dot(tangent)
		if axis.length_squared() < 0.0001:
			axis = tangent.cross(Vector3.UP if absf(tangent.y) < 0.9 else Vector3.RIGHT)
		axis = axis.normalized()
		var second_axis: Vector3 = tangent.cross(axis).normalized()
		seam_length += center.distance_to(previous_center)
		previous_center = center
		for side in range(SIDES):
			var angle: float = float(side) * TAU / SIDES
			# Shallow irregular folds gather near the cuff and relax up the arm.
			# Keep the skin opening circular and safely outside the forearm mesh.
			var gather: float = smoothstep(0.015, 0.055, seam_length) * exp(-seam_length * 3.0)
			var folds: float = sin(seam_length * 82.0 + sin(angle * 2.0) * 0.75)
			var ripple: float = 1.0 + gather * (folds * 0.042 + sin(angle * 5.0 + seam_length * 15.0) * 0.025)
			var opening: Vector3 = Vector3(cos(angle) * radius.x, sin(angle) * radius.y, 0)
			var transported: Vector3 = axis * cos(angle) * radius.x + second_axis * sin(angle) * radius.y
			# Match the sheared skin opening, then gradually turn its cross section.
			vertices[ring * SIDES + side] = center + opening.lerp(transported, smoothstep(0.0, 0.16, t)) * ripple
			uvs[ring * SIDES + side] = Vector2(float(side) / SIDES, seam_length)
	for ring in range(RINGS):
		for side in range(SIDES):
			var across: Vector3 = vertices[ring * SIDES + (side + 1) % SIDES] - vertices[ring * SIDES + (side + SIDES - 1) % SIDES]
			var along: Vector3 = vertices[mini(ring + 1, RINGS - 1) * SIDES + side] - vertices[maxi(ring - 1, 0) * SIDES + side]
			normals[ring * SIDES + side] = across.cross(along).normalized()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	_surface.clear_surfaces()
	_surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
