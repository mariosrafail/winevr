extends RefCounted
class_name MuseumSkin

const SKIN_SHADER: Shader = preload("res://assets/shaders/museum_skin.gdshader")
static var _mesh_cache: Dictionary = {}
static var _material_cache: Dictionary = {}
static var _dorsal_grid: Dictionary = {}
static var _skin_vertices: PackedVector3Array = PackedVector3Array()
static var _skin_indices: PackedInt32Array = PackedInt32Array()
const SKIN_GRID_SIZE: float = 0.0025


static func apply_to(model: Node3D) -> void:
	# Enrich the skin material and fit the existing nail plates to its surface.
	# The hand mesh, armature, weights, collisions, cuff and sleeve stay intact.
	var skin_node: MeshInstance3D = model.find_child("AnatomicalHandSkin", true, false) as MeshInstance3D
	if _dorsal_grid.is_empty() and skin_node != null:
		_index_dorsal_skin(skin_node.mesh)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh == null or mesh_instance.has_meta("museum_skin_applied"):
			continue
		for surface in range(mesh_instance.mesh.get_surface_count()):
			var source: StandardMaterial3D = mesh_instance.get_active_material(surface) as StandardMaterial3D
			if source == null:
				continue
			if source.resource_name.begins_with("Skin"):
				mesh_instance.mesh = _anatomical_mesh(mesh_instance.mesh as ArrayMesh)
				mesh_instance.set_surface_override_material(surface, _skin_material(source))
			elif source.resource_name.begins_with("Natural translucent nail"):
				mesh_instance.mesh = _flush_nail(mesh_instance.mesh as ArrayMesh, false)
				mesh_instance.set_surface_override_material(surface, _nail_material(source, false))
			elif source.resource_name.begins_with("Short ivory"):
				mesh_instance.mesh = _flush_nail(mesh_instance.mesh as ArrayMesh, true)
				mesh_instance.set_surface_override_material(surface, _nail_material(source, true))
		mesh_instance.set_meta("museum_skin_applied", true)


static func _skin_material(source: StandardMaterial3D) -> ShaderMaterial:
	var key: String = "skin_" + str(source.get_instance_id())
	if _material_cache.has(key):
		return _material_cache[key] as ShaderMaterial
	var result: ShaderMaterial = ShaderMaterial.new()
	result.resource_name = "Anatomical skin — living colour and restrained pores"
	result.shader = SKIN_SHADER
	result.set_shader_parameter("skin_albedo", source.albedo_texture)
	result.set_shader_parameter("skin_normal", source.normal_texture)
	_material_cache[key] = result
	return result


static func _index_dorsal_skin(mesh: Mesh) -> void:
	var arrays: Array = mesh.surface_get_arrays(0)
	_skin_vertices = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	_skin_indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	for triangle in range(0, _skin_indices.size(), 3):
		var a: Vector3 = _skin_vertices[_skin_indices[triangle]]
		var b: Vector3 = _skin_vertices[_skin_indices[triangle + 1]]
		var c: Vector3 = _skin_vertices[_skin_indices[triangle + 2]]
		if minf(a.y, minf(b.y, c.y)) >= 0.0 or minf(a.z, minf(b.z, c.z)) > 0.015:
			continue
		var first: Vector2i = Vector2i(floori(minf(a.x, minf(b.x, c.x)) / SKIN_GRID_SIZE), floori(minf(a.z, minf(b.z, c.z)) / SKIN_GRID_SIZE))
		var last: Vector2i = Vector2i(floori(maxf(a.x, maxf(b.x, c.x)) / SKIN_GRID_SIZE), floori(maxf(a.z, maxf(b.z, c.z)) / SKIN_GRID_SIZE))
		for x in range(first.x, last.x + 1):
			for z in range(first.y, last.y + 1):
				var cell: Vector2i = Vector2i(x, z)
				if not _dorsal_grid.has(cell):
					_dorsal_grid[cell] = PackedInt32Array()
				_dorsal_grid[cell].append(triangle)


static func _skin_height(p: Vector3) -> float:
	var cell: Vector2i = Vector2i(floori(p.x / SKIN_GRID_SIZE), floori(p.z / SKIN_GRID_SIZE))
	var height: float = INF
	for triangle in _dorsal_grid.get(cell, PackedInt32Array()):
		var a: Vector3 = _skin_vertices[_skin_indices[triangle]]
		var b: Vector3 = _skin_vertices[_skin_indices[triangle + 1]]
		var c: Vector3 = _skin_vertices[_skin_indices[triangle + 2]]
		var denominator: float = (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
		if absf(denominator) < 0.0000000001:
			continue
		var wa: float = ((b.z - c.z) * (p.x - c.x) + (c.x - b.x) * (p.z - c.z)) / denominator
		var wb: float = ((c.z - a.z) * (p.x - c.x) + (a.x - c.x) * (p.z - c.z)) / denominator
		if wa >= -0.00001 and wb >= -0.00001 and wa + wb <= 1.00001:
			height = minf(height, wa * a.y + wb * b.y + (1.0 - wa - wb) * c.y)
	return height if is_finite(height) else p.y


static func _flush_nail(source: ArrayMesh, edge: bool) -> ArrayMesh:
	var key: String = "flush_nail_" + str(source.get_instance_id())
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var result: ArrayMesh = ArrayMesh.new()
	result.resource_name = source.resource_name + " — flush natural nail"
	for surface in range(source.get_surface_count()):
		var arrays: Array = source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var center: Vector3 = source.get_aabb().get_center()
		for i in range(vertices.size()):
			var p: Vector3 = vertices[i]
			# The source coordinates are already in bind space. Keep the authored
			# nail outline, but fit its underside to the actual distal-pad surface.
			p.y = _skin_height(p) - (0.00090 if edge else 0.00035) + (p.y - center.y) * (0.20 if edge else 0.32)
			vertices[i] = p
		arrays[Mesh.ARRAY_VERTEX] = vertices
		_rebuild_nail_normals(arrays)
		result.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays, [], _surface_lods(source, surface))
		result.surface_set_material(surface, source.surface_get_material(surface))
	_mesh_cache[key] = result
	return result


static func _rebuild_nail_normals(arrays: Array) -> void:
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var original: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	var normals: PackedVector3Array = PackedVector3Array()
	normals.resize(points.size())
	for triangle in range(0, indices.size(), 3):
		var a: int = indices[triangle]
		var b: int = indices[triangle + 1]
		var c: int = indices[triangle + 2]
		var normal: Vector3 = (points[b] - points[a]).cross(points[c] - points[a])
		if normal.dot(original[a] + original[b] + original[c]) < 0.0:
			normal = -normal
		normals[a] += normal
		normals[b] += normal
		normals[c] += normal
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array
	for i in range(normals.size()):
		normals[i] = normals[i].normalized() if normals[i].length_squared() > 0.0000000000001 else original[i]
		if tangents.size() == normals.size() * 4:
			var tangent: Vector3 = Vector3(tangents[i * 4], tangents[i * 4 + 1], tangents[i * 4 + 2])
			tangent = (tangent - normals[i] * tangent.dot(normals[i])).normalized()
			tangents[i * 4] = tangent.x
			tangents[i * 4 + 1] = tangent.y
			tangents[i * 4 + 2] = tangent.z
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents


static func _nail_material(source: StandardMaterial3D, edge: bool) -> StandardMaterial3D:
	var key: String = "nail_" + str(source.get_instance_id())
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D
	var result: StandardMaterial3D = source.duplicate() as StandardMaterial3D
	# A short unpolished nail reflects a broad, quiet highlight. Its free edge is
	# warm ivory, not a bright white painted strip.
	result.albedo_color = source.albedo_color.lerp(Color(0.72, 0.57, 0.53) if not edge else Color(0.68, 0.60, 0.52), 0.45 if not edge else 0.85)
	result.roughness = 0.46 if edge else 0.40
	result.metallic_specular = 0.28
	_material_cache[key] = result
	return result


static func _anatomical_mesh(source: ArrayMesh) -> ArrayMesh:
	var key: int = source.get_instance_id()
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var result: ArrayMesh = ArrayMesh.new()
	result.resource_name = source.resource_name + " — stable anatomical shading"
	result.blend_shape_mode = source.blend_shape_mode
	for blend_shape in range(source.get_blend_shape_count()):
		result.add_blend_shape(source.get_blend_shape_name(blend_shape))
	for surface in range(source.get_surface_count()):
		var arrays: Array = source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var anatomical_uv: PackedVector2Array = PackedVector2Array()
		var masks: PackedColorArray = PackedColorArray()
		anatomical_uv.resize(vertices.size())
		masks.resize(vertices.size())
		for i in range(vertices.size()):
			var p: Vector3 = vertices[i]
			anatomical_uv[i] = Vector2(p.x, p.z)
			var pads: float = _pads(p)
			var mottling: float = 0.5 + 0.20 * sin(p.x * 276.0 + p.z * 41.0) * sin(p.z * 188.0 - p.y * 99.0)
			mottling += 0.10 * sin(p.x * 619.0 + p.z * 483.0)
			var veins: float = _veins(p)
			masks[i] = Color(pads, mottling, veins, clampf((p.y + 0.05) / 0.10, 0.0, 1.0))
		arrays[Mesh.ARRAY_TEX_UV2] = anatomical_uv
		arrays[Mesh.ARRAY_COLOR] = masks
		var flags: int = source.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		result.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays, source.surface_get_blend_shape_arrays(surface), _surface_lods(source, surface), flags)
		# Godot normally decodes and requantizes packed normals/tangents during a
		# rebuild. Restore their original vertex buffer byte-for-byte; only the
		# separate colour/UV attribute buffer was intentionally enriched.
		var original_surface: Dictionary = RenderingServer.mesh_get_surface(source.get_rid(), surface)
		var rebuilt_surface: Dictionary = RenderingServer.mesh_get_surface(result.get_rid(), surface)
		var original_vertices: PackedByteArray = original_surface["vertex_data"] as PackedByteArray
		if original_vertices.size() == (rebuilt_surface["vertex_data"] as PackedByteArray).size():
			result.surface_update_vertex_region(surface, 0, original_vertices)
		result.surface_set_material(surface, source.surface_get_material(surface))
		result.surface_set_name(surface, source.surface_get_name(surface))
	result.custom_aabb = source.custom_aabb
	result.shadow_mesh = source.shadow_mesh
	_mesh_cache[key] = result
	return result


static func _surface_lods(source: ArrayMesh, surface: int) -> Dictionary:
	# Rebuilding the attribute streams must retain the imported mobile LODs.
	var raw: Dictionary = RenderingServer.mesh_get_surface(source.get_rid(), surface)
	var lods: Dictionary = {}
	var bytes_per_index: int = 2 if int(raw.get("vertex_count", 0)) <= 65536 else 4
	for entry in raw.get("lods", []):
		var bytes: PackedByteArray = entry["index_data"] as PackedByteArray
		var indices: PackedInt32Array = PackedInt32Array()
		indices.resize(bytes.size() / bytes_per_index)
		for i in range(indices.size()):
			indices[i] = bytes.decode_u16(i * 2) if bytes_per_index == 2 else bytes.decode_u32(i * 4)
		lods[float(entry["edge_length"])] = indices
	return lods


static func _pads(p: Vector3) -> float:
	var result: float = 0.0
	for point in [Vector2(-0.030, -0.120), Vector2(-0.009, -0.135), Vector2(0.013, -0.125), Vector2(0.032, -0.097), Vector2(-0.083, -0.039)]:
		var distance: float = Vector2(p.x, p.z).distance_to(point)
		result = maxf(result, exp(-pow(distance / 0.011, 2.0)))
	return result


static func _veins(p: Vector3) -> float:
	var region: float = smoothstep(-0.035, -0.009, p.z) * (1.0 - smoothstep(0.16, 0.23, p.z))
	var path_a: float = p.x - 0.007 - 0.005 * sin(p.z * 34.0)
	var path_b: float = p.x + 0.014 + 0.007 * sin(p.z * 24.0 + 0.8)
	return clampf(region * (exp(-pow(path_a / 0.0026, 2.0)) + exp(-pow(path_b / 0.0021, 2.0))), 0.0, 1.0)
