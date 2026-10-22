extends RefCounted

## Original educational model. Deliberately not labelled a scan or cultivar specimen.
## Three joined surfaces keep the exhibit practical on standalone headsets.
const SKIN: Shader = preload("res://assets/shaders/vidiano_skin.gdshader")


static func build() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "AuthoredBunch"
	root.set_meta("representation", "Procedural educational Vidiano illustration; not a botanical scan")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 171026
	var fruit: SurfaceTool = SurfaceTool.new()
	fruit.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stems: SurfaceTool = SurfaceTool.new()
	stems.begin(Mesh.PRIMITIVE_TRIANGLES)
	var berry: SphereMesh = SphereMesh.new()
	berry.radius = 1.0
	berry.height = 2.0
	berry.radial_segments = 32
	berry.rings = 20
	var layout: Array[Dictionary] = _berry_layout(rng)
	var shapes: Array[Transform3D] = []
	var stem_color: Color = Color("665c27")
	for item: Dictionary in layout:
		var transform: Transform3D = item["shape"]
		shapes.append(transform)
		_append(fruit, berry, transform, item["color"], Vector2(fposmod(float(shapes.size()) * 0.6180339, 1.0), fposmod(float(shapes.size()) * 0.4142136, 1.0)))
		# Pedicels meet the top of each ellipsoid after the packing solve.
		var neck: Vector3 = transform.origin + transform.basis.y * 0.94
		var junction: Vector3 = item["stem"]
		var fork: Vector3 = junction.lerp(neck, 0.60) + Vector3.UP * 0.008
		_branch(stems, junction, fork, 0.0018, stem_color)
		_branch(stems, fork, neck, 0.0011, stem_color)
	for row in range(8):
		var y: float = -0.16 - float(row) * 0.052
		var center: Vector3 = Vector3(sin(float(row) * 0.7) * 0.023, y, cos(float(row) * 0.6) * 0.013)
		var next: Vector3 = Vector3(sin(float(row + 1) * 0.7) * 0.023, y - 0.052, cos(float(row + 1) * 0.6) * 0.013)
		_branch(stems, center, next, lerpf(0.005, 0.0017, float(row) / 8.0), stem_color)
	_branch(stems, Vector3.ZERO, Vector3(0.015, -0.075, 0), 0.008, stem_color)
	_branch(stems, Vector3(0.015, -0.075, 0), Vector3(0, -0.16, 0.008), 0.007, stem_color)
	_branch(stems, Vector3(0.012, -0.07, 0), Vector3(0.015, -0.055, 0.025), 0.0035, stem_color)
	var skin: ShaderMaterial = ShaderMaterial.new()
	skin.shader = SKIN
	skin.set_shader_parameter("skin_albedo", load("res://assets/textures/grape_museum/vidiano_skin_albedo.png"))
	_add_mesh(root, "VidianoBerries", fruit.commit(), skin)
	root.get_node("VidianoBerries").set_meta("berry_shapes", shapes)
	var stalk: StandardMaterial3D = StandardMaterial3D.new()
	stalk.vertex_color_use_as_albedo = true
	stalk.roughness = 0.72
	_add_mesh(root, "ConnectedRachis", stems.commit(), stalk)
	_build_leaf(root)
	return root


static func _berry_layout(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var layout: Array[Dictionary] = []
	var counts: Array[int] = [7, 10, 12, 12, 11, 9, 7, 4, 1]
	var radii: Array[float] = [0.059, 0.079, 0.091, 0.086, 0.078, 0.067, 0.051, 0.029, 0.0]
	for row in range(counts.size()):
		var y: float = -0.16 - float(row) * 0.052
		var center: Vector3 = Vector3(sin(float(row) * 0.7) * 0.023, y, cos(float(row) * 0.6) * 0.013)
		for item in range(counts[row]):
			var angle: float = TAU * float(item) / float(counts[row]) + float(row) * 1.77 + rng.randf_range(-0.22, 0.22)
			var radial: float = radii[row] + rng.randf_range(-0.014, 0.014)
			var point: Vector3 = center + Vector3(cos(angle) * radial, rng.randf_range(-0.019, 0.019), sin(angle) * radial)
			var size: float = rng.randf_range(0.023, 0.035) * lerpf(1.03, 0.82, float(row) / 8.0)
			if item % 7 == 3:
				size *= 0.76
			var axes: Vector3 = Vector3(size * rng.randf_range(0.94, 1.04), size * rng.randf_range(1.07, 1.24), size * rng.randf_range(0.93, 1.05))
			var basis: Basis = Basis.from_euler(Vector3(rng.randf_range(-0.24, 0.24), angle, rng.randf_range(-0.22, 0.22))).scaled_local(axes)
			var color: Color = Color("929e62").lerp(Color("afaa72"), rng.randf())
			layout.append({"shape": Transform3D(basis, point), "seed": point, "stem": center + Vector3.UP * 0.032, "color": color})
	# Resolve the visible ellipsoids before generating any mesh or stems.
	# A separating plane between every pair guarantees the skins cannot cut
	# through one another; the old ring spacing alone did not guarantee this.
	for iteration in range(400):
		var deepest: float = 0.0
		if iteration < 150:
			for item: Dictionary in layout:
				var shape: Transform3D = item["shape"]
				shape.origin = shape.origin.lerp(item["seed"], 0.003)
				item["shape"] = shape
		for a in range(layout.size()):
			for b in range(a + 1, layout.size()):
				var sa: Transform3D = layout[a]["shape"]
				var sb: Transform3D = layout[b]["shape"]
				var separation: Vector3 = sb.origin - sa.origin
				var normal: Vector3 = separation.normalized() if separation.length_squared() > 0.00000001 else Vector3.RIGHT
				var required: float = (sa.basis.transposed() * normal).length() + (sb.basis.transposed() * normal).length() + 0.0016
				var penetration: float = required - separation.length()
				deepest = maxf(deepest, penetration)
				if penetration > 0.0:
					sa.origin -= normal * penetration * 0.501
					sb.origin += normal * penetration * 0.501
					layout[a]["shape"] = sa
					layout[b]["shape"] = sb
		if iteration >= 150 and deepest < 0.000001:
			break
	return layout


static func _append(target: SurfaceTool, mesh: Mesh, transform: Transform3D, color: Color, texture_offset: Vector2 = Vector2.ZERO) -> void:
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normal_basis: Basis = transform.basis.inverse().transposed()
	for index in indices:
		target.set_normal((normal_basis * normals[index]).normalized())
		target.set_uv(uvs[index])
		target.set_uv2(texture_offset)
		target.set_color(color.srgb_to_linear())
		target.add_vertex(transform * vertices[index])


static func _branch(target: SurfaceTool, a: Vector3, b: Vector3, radius: float, color: Color) -> void:
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = radius * 0.70
	cylinder.bottom_radius = radius
	cylinder.height = a.distance_to(b)
	cylinder.radial_segments = 7
	var basis: Basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	_append(target, cylinder, Transform3D(basis, (a + b) * 0.5), color)


static func _build_leaf(root: Node3D) -> void:
	# Reuse the project's artist-authored, textured leaf surface. The fruit and
	# connected rachis remain original; no whole red bunch is recolored as white.
	var source: Node3D = (load("res://assets/models/grape_museum/kotsifali_bunch.glb") as PackedScene).instantiate() as Node3D
	for child in source.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = child as MeshInstance3D
		for surface in range(mesh.mesh.get_surface_count()):
			var original: Material = mesh.get_active_material(surface)
			if original != null and "double-sided leaf" in original.resource_name:
				var leaf_mesh: ArrayMesh = ArrayMesh.new()
				leaf_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.mesh.surface_get_arrays(surface))
				var leaf_instance: MeshInstance3D = MeshInstance3D.new()
				leaf_instance.name = "AuthoredTexturedLeaf"
				leaf_instance.mesh = leaf_mesh
				leaf_instance.material_override = original
				leaf_instance.transform = mesh.transform.scaled(Vector3.ONE * 2.3)
				root.add_child(leaf_instance)
				source.free()
				return
	source.free()
	var leaf: SurfaceTool = SurfaceTool.new()
	leaf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center: Vector3 = Vector3(0.16, -0.075, 0.025)
	# A gently folded, five-lobed silhouette with small serrations.
	for index in range(60):
		for offset in [0, 1]:
			var angle: float = TAU * float(index + offset) / 60.0
			var radius: float = (0.065 + 0.025 * cos(angle * 5.0)) * (0.94 if (index + offset) % 2 == 0 else 1.0)
			var point: Vector3 = center + Vector3(cos(angle) * radius, sin(angle) * radius, sin(angle * 2.0) * 0.012)
			leaf.set_color(Color("536c32").lerp(Color("788442"), float((index + offset) % 5) / 8.0).srgb_to_linear())
			leaf.set_uv(Vector2(cos(angle), sin(angle)) * 0.5 + Vector2.ONE * 0.5)
			leaf.add_vertex(point)
		leaf.set_color(Color("82994b").srgb_to_linear())
		leaf.set_uv(Vector2.ONE * 0.5)
		leaf.add_vertex(center + Vector3(0, 0, 0.012))
	leaf.generate_normals()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.77
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_mesh(root, "FiveLobedLeaf", leaf.commit(), material)


static func _add_mesh(parent: Node3D, title: String, mesh: ArrayMesh, material: Material) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = title
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
