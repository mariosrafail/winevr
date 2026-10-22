extends RefCounted

const REST_GAP: float = 0.0016

static func _root(parents: PackedInt32Array, index: int) -> int:
	while parents[index] != index:
		index = parents[index]
	return index

static func _groups(vertices: PackedVector3Array, indices: PackedInt32Array) -> Array:
	var parents: PackedInt32Array = PackedInt32Array()
	parents.resize(vertices.size())
	var welded: Dictionary = {}
	for index in range(vertices.size()):
		parents[index] = index
		var key: Vector3i = Vector3i((vertices[index] * 100000.0).round())
		if welded.has(key):
			parents[index] = int(welded[key])
		else:
			welded[key] = index
	for triangle in range(0, indices.size() if not indices.is_empty() else vertices.size(), 3):
		var a: int = _root(parents, indices[triangle] if not indices.is_empty() else triangle)
		for corner in [1, 2]:
			var b: int = _root(parents, indices[triangle + corner] if not indices.is_empty() else triangle + corner)
			parents[b] = a
	var groups: Dictionary = {}
	for index in range(vertices.size()):
		var key: int = _root(parents, index)
		if not groups.has(key):
			groups[key] = []
		groups[key].append(index)
	return groups.values()

static func _extent(berry: Dictionary, normal: Vector3) -> float:
	return (Basis(berry["basis"]).transposed() * normal).length()

static func _gap(berries: Array[Dictionary]) -> float:
	var minimum: float = INF
	for a in range(berries.size()):
		for b in range(a + 1, berries.size()):
			var separation: Vector3 = Vector3(berries[b]["point"]) - Vector3(berries[a]["point"])
			var normal: Vector3 = separation.normalized()
			minimum = minf(minimum, separation.length() - _extent(berries[a], normal) - _extent(berries[b], normal))
	return minimum

static func pack_model(model: Node3D, body: Node3D) -> Dictionary:
	var records: Array[Dictionary] = []
	var berries: Array[Dictionary] = []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = node as MeshInstance3D
		var mesh_to_body: Transform3D = body.global_transform.affine_inverse() * instance.global_transform
		var record: Dictionary = {"instance": instance, "transform": mesh_to_body, "surfaces": [], "materials": [], "berries": []}
		for surface in range(instance.mesh.get_surface_count()):
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var material: Material = instance.get_active_material(surface)
			record["surfaces"].append(arrays)
			record["materials"].append(material)
			if material == null or not "baked skin" in material.resource_name:
				continue
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			for group: Array in _groups(vertices, indices):
				if group.size() < 12:
					continue
				var bounds: AABB = AABB(vertices[group[0]], Vector3.ZERO)
				for index: int in group:
					bounds = bounds.expand(vertices[index])
				var center: Vector3 = bounds.get_center()
				var axes: Vector3 = bounds.size * 0.5
				# Fit an ellipsoid that contains every authored skin vertex,
				# including the small irregularities of the original berries.
				var inflation: float = 1.0
				for index: int in group:
					inflation = maxf(inflation, ((vertices[index] - center) / axes).length())
				var visual_basis: Basis = Basis.IDENTITY.scaled(axes * (inflation + 0.00001))
				var point: Vector3 = mesh_to_body * center
				var berry: Dictionary = {"surface": surface, "vertices": group, "center": center, "point": point, "seed": point,
					"visual_basis": visual_basis, "basis": mesh_to_body.basis * visual_basis, "delta": Vector3.ZERO}
				berries.append(berry)
				record["berries"].append(berry)
		records.append(record)
	var before: float = _gap(berries)
	var iterations: int = 0
	for iteration in range(500):
		iterations = iteration + 1
		var deepest: float = 0.0
		for a in range(berries.size()):
			for b in range(a + 1, berries.size()):
				var separation: Vector3 = Vector3(berries[b]["point"]) - Vector3(berries[a]["point"])
				var normal: Vector3 = separation.normalized() if separation.length_squared() > 0.000000001 else Vector3.RIGHT
				var penetration: float = _extent(berries[a], normal) + _extent(berries[b], normal) + REST_GAP - separation.length()
				deepest = maxf(deepest, penetration)
				if penetration > 0.0:
					berries[a]["point"] = Vector3(berries[a]["point"]) - normal * penetration * 0.501
					berries[b]["point"] = Vector3(berries[b]["point"]) + normal * penetration * 0.501
		if deepest < 0.000001:
			break
	var maximum_shift: float = 0.0
	for berry: Dictionary in berries:
		berry["delta"] = Vector3(berry["point"]) - Vector3(berry["seed"])
		maximum_shift = maxf(maximum_shift, Vector3(berry["delta"]).length())
	for record: Dictionary in records:
		var instance: MeshInstance3D = record["instance"]
		var transform: Transform3D = record["transform"]
		var shapes: Array[Transform3D] = []
		for berry: Dictionary in record["berries"]:
			var arrays: Array = record["surfaces"][int(berry["surface"])]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var local_delta: Vector3 = transform.basis.inverse() * Vector3(berry["delta"])
			for index: int in berry["vertices"]:
				vertices[index] += local_delta
			arrays[Mesh.ARRAY_VERTEX] = vertices
			shapes.append(Transform3D(berry["visual_basis"], Vector3(berry["center"]) + local_delta))
		var result: ArrayMesh = ArrayMesh.new()
		for surface in range(record["surfaces"].size()):
			var arrays: Array = record["surfaces"][surface]
			var material: Material = record["materials"][surface]
			if material != null and "olive rachis" in material.resource_name:
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for index in range(vertices.size()):
					var point: Vector3 = transform * vertices[index]
					var shift: Vector3 = Vector3.ZERO
					var total: float = 0.0
					for berry: Dictionary in berries:
						var distance: float = point.distance_to(berry["seed"])
						var axes: Vector3 = Basis(berry["basis"]).get_scale().abs()
						var radius: float = maxf(axes.x, maxf(axes.y, axes.z))
						var weight: float = pow(1.0 - smoothstep(radius * 0.85, radius * 1.8, distance), 2.0)
						shift += Vector3(berry["delta"]) * weight
						total += weight
					if total > 0.00001:
						vertices[index] += transform.basis.inverse() * shift / total * minf(total, 1.0)
				arrays[Mesh.ARRAY_VERTEX] = vertices
			result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			result.surface_set_material(surface, material)
		instance.mesh = result
		instance.set_meta("berry_shapes", shapes)
	return {"berries": berries.size(), "before_gap_mm": before * 1000.0, "after_gap_mm": _gap(berries) * 1000.0,
		"max_shift_mm": maximum_shift * 1000.0, "iterations": iterations}
