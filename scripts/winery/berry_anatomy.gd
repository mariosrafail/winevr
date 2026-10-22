extends Node3D
class_name BerryAnatomy

# A deliberately enlarged teaching model, not a scan or a lab measurement.
# Longitudinal cutaway informed by Frontiers 2021 (doi:10.3389/fpls.2021.662433)
# and Bondada & Keller 2012 (doi:10.4236/ajps.2012.37105).
const PULP_SHADER: Shader = preload("res://assets/shaders/grape_pulp.gdshader")
const SEED_SHADER: Shader = preload("res://assets/shaders/grape_seed.gdshader")
const GOLD: Color = Color("d8bd7b")
const IVORY: Color = Color("f2e9d8")
const MUTED: Color = Color("aaa393")
const PARTS: Array[String] = ["skin", "pulp", "seeds"]
const TITLES: Array[String] = ["ΦΛΟΥΔΑ", "ΣΑΡΚΑ", "ΚΟΥΚΟΥΤΣΙΑ"]

var selected_part: String = "skin"
var active: bool = false
var is_white: bool = false
var model: Node3D
var _description: Label3D
var _part_materials: Dictionary = {}
var _buttons: Array[Interactable] = []
var _collisions: Array[CollisionObject3D] = []


func build(variety: Dictionary) -> void:
	name = "AnatomyPage"
	is_white = str(variety.get("id", "")) == "vidiano"
	model = Node3D.new()
	model.name = "BerryCutaway"
	model.position = Vector3(0, 0.015, 0.16)
	model.rotation = Vector3(deg_to_rad(7), deg_to_rad(-26), deg_to_rad(-3))
	add_child(model)
	var variety_id: String = str(variety.get("id", "vidiano"))
	var skin: StandardMaterial3D = _material(Color.WHITE, 0.56)
	skin.albedo_texture = load("res://assets/textures/grape_museum/" + variety_id + "_skin_albedo.png")
	skin.albedo_color = Color(0.85, 0.85, 0.85)
	var pulp: ShaderMaterial = ShaderMaterial.new()
	pulp.shader = PULP_SHADER
	pulp.set_shader_parameter("pulp_albedo", load("res://assets/textures/grape_museum/grape_pulp_albedo.png"))
	pulp.set_shader_parameter("flesh_tint", Vector3(0.98, 1.03, 0.96) if is_white else Vector3(1.04, 1.0, 1.02))
	var seeds: ShaderMaterial = ShaderMaterial.new()
	seeds.shader = SEED_SHADER
	_part_materials = {"skin": skin, "pulp": pulp, "seeds": seeds}
	_mesh(model, "NaturalSkin", _half_berry(0.17), skin)
	_mesh(model, "CutSkinRim", _disc(0.17, 0.1665), skin)
	_mesh(model, "JuicyPulp", _cut_pulp(0.1665), pulp)
	var vascular: StandardMaterial3D = _material(Color("c6cfaa"), 0.46)
	# Longitudinal peripheral bundles lie close to the skin. The central
	# strands continue from the pedicel and branch towards the seed locules.
	for side in [-1.0, 1.0]:
		var path: Array[Vector3] = []
		for step in range(25):
			var t: float = float(step) / 24.0
			var y: float = lerpf(0.184, -0.184, t)
			var x: float = side * (0.014 + sin(t * PI) * 0.137)
			path.append(Vector3(x, y, _cut_depth(Vector2(x, y), 0.1665) + 0.0012))
		_path(model, path, 0.00035, vascular)
	var axial: Array[Vector3] = []
	for step in range(25):
		var y: float = lerpf(0.19, -0.187, float(step) / 24.0)
		var x: float = sin(float(step) * 0.23) * 0.003
		axial.append(Vector3(x, y, _cut_depth(Vector2(x, y), 0.1665) + 0.0014))
	_path(model, axial, 0.00055, vascular)
	# Two visible seeds in this example of a longitudinal cut, rather than
	# four identical capsules imposed as a universal cultivar seed count.
	for index in range(2):
		var side: float = -1.0 if index == 0 else 1.0
		var seed_node: MeshInstance3D = _mesh(model, "Seed_%d" % index, _seed_mesh(), seeds)
		seed_node.position = Vector3(side * 0.034, -0.023 + float(index) * 0.009, -0.009)
		seed_node.rotation.z = side * -0.23
		seed_node.rotation.y = side * 0.11
		if index == 1:
			seed_node.scale = Vector3(0.94, 0.96, 0.94)
		_path(model, [Vector3(0, 0.09, 0.0015), Vector3(side * 0.014, 0.052, 0.001), seed_node.position + Vector3(0, 0.041, 0.007)], 0.00048, vascular)
	_segment(model, Vector3(0, 0.193, -0.021), Vector3(0.007, 0.247, -0.028), 0.0065, _material(Color("73764b"), 0.82))
	for index in range(PARTS.size()):
		var part: String = PARTS[index]
		var button: Interactable = Interactable.new()
		button.name = "Anatomy_" + part
		button.id = "museum_" + str(variety.get("id", "")) + "_anatomy_" + part
		button.title = TITLES[index].capitalize()
		button.set_meta("museum_action", true)
		button.bypass_guided_lock = true
		button.hover_scale_multiplier = 1.0
		button.glow_on_hover = false
		button.position = Vector3(-0.30 + index * 0.30, -0.25, 0.046)
		add_child(button)
		var backing: BoxMesh = BoxMesh.new()
		backing.size = Vector3(0.28, 0.075, 0.018)
		_mesh(button, "Backing", backing, _material(Color("394039"), 0.8))
		var label: Label3D = _label(TITLES[index], Vector3.ZERO, 13, MUTED)
		label.reparent(button, false)
		label.position = Vector3(0, 0, 0.013)
		label.name = "PartLabel"
		var area: Area3D = Area3D.new()
		area.collision_layer = 0
		area.collision_mask = 0
		button.add_child(area)
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(0.29, 0.085, 0.04)
		collision.shape = shape
		area.add_child(collision)
		_collisions.append(area)
		_buttons.append(button)
		button.interacted.connect(func(_item: Interactable) -> void:
			if active:
				select_part(part)
		)
	_description = _label("", Vector3(-0.43, -0.35, 0.035), 17, IVORY)
	_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label("Επιμήκης τομή · Frontiers 2021 / WSU 2012", Vector3(0, -0.51, 0.035), 11, MUTED)
	select_part("skin")
	set_active(false)


func set_active(enabled: bool) -> void:
	active = enabled
	visible = enabled
	for collider in _collisions:
		collider.collision_layer = 1 if enabled else 0


func select_part(part: String) -> void:
	if not PARTS.has(part):
		return
	selected_part = part
	for key in _part_materials:
		var mat: Material = _part_materials[key]
		if mat is ShaderMaterial:
			(mat as ShaderMaterial).set_shader_parameter("selected", 1.0 if key == part else 0.0)
		elif mat is StandardMaterial3D:
			(mat as StandardMaterial3D).emission_enabled = false
	for index in range(_buttons.size()):
		(_buttons[index].get_node("PartLabel") as Label3D).modulate = GOLD if PARTS[index] == part else MUTED
	match part:
		"skin":
			_description.text = "Φλούδα: φαινολικές ενώσεις και αρώματα.\nΣτις ερυθρές ποικιλίες φιλοξενεί\nτις ανθοκυάνες που δίνουν χρώμα."
			if is_white:
				_description.text = "Η λευκή φλούδα περιέχει φαινολικές\nενώσεις. Η απουσία ερυθρού χρώματος\nδεν σημαίνει απουσία πολυφαινολών."
		"pulp":
			_description.text = "Σάρκα: νερό, σάκχαρα και οργανικά οξέα.\nΣτην ωρίμανση τα σάκχαρα αυξάνονται\nκαι συνήθως η οξύτητα μειώνεται."
		"seeds":
			_description.text = "Κουκούτσια: ταννίνες που μπορούν\nνα συμβάλουν σε πικράδα και στυφάδα.\nΗ εκχύλιση επηρεάζει το τελικό κρασί."


func _half_berry(radius: float) -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for latitude in range(40):
		for longitude in range(48):
			var points: Array[Vector3] = []
			for offset in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var theta: float = PI * float(latitude + offset.x) / 40.0
				var phi: float = PI * float(longitude + offset.y) / 48.0
				points.append(Vector3(sin(theta) * cos(phi), cos(theta) * 1.20, -sin(theta) * sin(phi)) * radius)
			_triangle(surface, points[0], points[1], points[2])
			_triangle(surface, points[0], points[2], points[3])
	surface.generate_normals()
	return surface.commit()


func _disc(outer: float, inner: float) -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(64):
		var first: float = TAU * float(index) / 64.0
		var second: float = TAU * float(index + 1) / 64.0
		var a: Vector3 = Vector3(cos(first) * outer, sin(first) * outer * 1.20, 0)
		var b: Vector3 = Vector3(cos(second) * outer, sin(second) * outer * 1.20, 0)
		var c: Vector3 = Vector3(cos(second) * inner, sin(second) * inner * 1.20, 0)
		var d: Vector3 = Vector3(cos(first) * inner, sin(first) * inner * 1.20, 0)
		for point in [a, c, b, a, d, c]:
			surface.set_normal(Vector3.BACK)
			surface.set_uv(Vector2(point.x / (outer * 2.0) + 0.5, point.y / (outer * 2.4) + 0.5))
			surface.add_vertex(point)
	return surface.commit()


func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Godot's visible front faces use clockwise winding.
	if (b - a).cross(c - a).dot(a + b + c) > 0:
		var swap: Vector3 = b
		b = c
		c = swap
	for point in [a, b, c]:
		var unit: Vector3 = point.normalized()
		surface.set_uv(Vector2(atan2(-unit.z, unit.x) / TAU + 0.5, acos(clampf(unit.y, -1.0, 1.0)) / PI))
		surface.add_vertex(point)


func _cut_depth(point: Vector2, radius: float) -> float:
	var p: Vector2 = point / Vector2(radius, radius * 1.20)
	var cavities: float = 0.0
	for side in [-1.0, 1.0]:
		var delta: Vector2 = (p - Vector2(side * 0.205, -0.12)) / Vector2(0.17, 0.31)
		cavities += exp(-delta.length_squared() * 1.65)
	return 0.0010 * sin(point.x * 78.0) * sin(point.y * 63.0) - cavities * 0.014

func _cut_pulp(radius: float) -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(40):
		for segment in range(112):
			var points: Array[Vector3] = []
			for offset in [Vector2i(0,0), Vector2i(1,0), Vector2i(1,1), Vector2i(0,1)]:
				var radial: float = radius * float(ring + offset.x) / 40.0
				var angle: float = TAU * float(segment + offset.y) / 112.0
				var point: Vector2 = Vector2(cos(angle) * radial, sin(angle) * radial * 1.20)
				points.append(Vector3(point.x, point.y, _cut_depth(point, radius)))
			for index in [0,2,1,0,3,2]:
				var point: Vector3 = points[index]
				surface.set_uv(Vector2(point.x / (radius * 2.0) + 0.5, point.y / (radius * 2.4) + 0.5))
				surface.add_vertex(point)
	surface.generate_normals()
	return surface.commit()

func _seed_mesh() -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(36):
		for segment in range(40):
			var points: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			for offset in [Vector2i(0,0), Vector2i(1,0), Vector2i(1,1), Vector2i(0,1)]:
				var t: float = float(ring + offset.x) / 36.0
				var angle: float = TAU * float(segment + offset.y) / 40.0
				var width: float = pow(maxf(0.0, sin(t * PI)), 0.66) * lerpf(0.033, 0.009, t)
				var groove: float = 1.0 - exp(-pow(cos(angle) / 0.16, 2.0)) * 0.12
				points.append(Vector3(cos(angle) * width + pow(t, 5.0) * 0.003, lerpf(-0.035, 0.047, t), sin(angle) * width * 0.70 * groove))
				uvs.append(Vector2(float(segment + offset.y) / 40.0, t))
			for index in [0,2,1,0,3,2]:
				surface.set_uv(uvs[index])
				surface.add_vertex(points[index])
	surface.generate_normals()
	return surface.commit()

func _path(parent: Node3D, points: Array[Vector3], radius: float, material: Material) -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(points.size() - 1):
		var start: Vector3 = points[index]
		var end: Vector3 = points[index + 1]
		var cylinder: CylinderMesh = CylinderMesh.new()
		cylinder.top_radius = radius
		cylinder.bottom_radius = radius
		cylinder.height = start.distance_to(end)
		cylinder.radial_segments = 6
		var basis: Basis = Basis(Quaternion(Vector3.UP, (end - start).normalized()))
		surface.append_from(cylinder, 0, Transform3D(basis, (start + end) * 0.5))
	_mesh(parent, "VascularBundle", surface.commit(), material)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.albedo_color = color.srgb_to_linear()
	result.roughness = roughness
	result.metallic_specular = 0.3
	return result


func _mesh(parent: Node3D, mesh_name: String, geometry: Mesh, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = mesh_name
	instance.mesh = geometry
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _label(text: String, at: Vector3, size: int, color: Color) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.0016
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	label.position = at
	add_child(label)
	return label


func _segment(parent: Node3D, start: Vector3, end: Vector3, radius: float, material: Material) -> void:
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = start.distance_to(end)
	cylinder.radial_segments = 8
	var instance: MeshInstance3D = _mesh(parent, "VascularBundle", cylinder, material)
	instance.position = (start + end) * 0.5
	instance.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
