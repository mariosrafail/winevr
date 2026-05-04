extends RefCounted
class_name WineryPropFactory

var root: Node3D
var interaction_root: Node3D
var highlight_root: Node3D
var prop_data_by_instance_id: Dictionary = {}
var prop_data_by_id: Dictionary = {}
var environment: WineryEnvironmentApplier
var _pulse_tween: Tween
var _current_quality: String = "medium"
var _active_marker_material: StandardMaterial3D
var _active_marker_label: Label3D


func setup(parent: Node3D, environment_applier: WineryEnvironmentApplier) -> void:
	environment = environment_applier
	root = Node3D.new()
	root.name = "ConfigProps"
	parent.add_child(root)
	interaction_root = Node3D.new()
	interaction_root.name = "ConfigPropInteractionAreas"
	parent.add_child(interaction_root)
	highlight_root = Node3D.new()
	highlight_root.name = "ConfigPropHighlights"
	highlight_root.add_to_group("highlight_effects")
	highlight_root.add_to_group("performance_optional")
	parent.add_child(highlight_root)


func rebuild(raw_props: Array) -> void:
	rebuild_with_quality(raw_props, "medium")


func rebuild_with_quality(raw_props: Array, quality: String) -> void:
	if root == null or interaction_root == null or highlight_root == null:
		return
	for child in root.get_children():
		child.free()
	for child in interaction_root.get_children():
		child.free()
	clear_highlight()
	prop_data_by_instance_id.clear()
	prop_data_by_id.clear()

	var safe_quality: String = _normalize_quality(quality)
	_current_quality = safe_quality
	var max_props: int = _max_props_for_quality(safe_quality, raw_props.size())
	var created_count: int = 0
	for raw_prop in raw_props:
		if created_count >= max_props:
			break
		if typeof(raw_prop) != TYPE_DICTIONARY:
			continue
		var prop_data: Dictionary = raw_prop as Dictionary
		if not bool(prop_data.get("visible", true)):
			continue
		var prop_node: Node3D = _create_prop(prop_data)
		_tag_prop_for_performance_groups(prop_node, prop_data)
		root.add_child(prop_node)
		_attach_prop_label(prop_node, prop_data)
		_attach_prop_interaction(prop_data)
		prop_data_by_id[str(prop_data.get("id", ""))] = prop_data.duplicate(true)
		created_count += 1


func get_prop_data_from_collider(collider: Object) -> Dictionary:
	if collider is Node:
		var node: Node = collider as Node
		while node != null:
			if node.is_in_group("winery_prop") and prop_data_by_instance_id.has(node.get_instance_id()):
				return (prop_data_by_instance_id[node.get_instance_id()] as Dictionary).duplicate(true)
			node = node.get_parent()
	return {}


func highlight_prop(prop_id: String) -> bool:
	clear_highlight()
	if not prop_data_by_id.has(prop_id):
		return false

	var prop_data: Dictionary = prop_data_by_id[prop_id]
	var marker: Node3D = _create_highlight_marker(str(prop_data.get("title", prop_data.get("id", prop_id))).replace("_", " ").capitalize())
	marker.position = _array_to_vector3(prop_data.get("position", [0.0, 0.0, 0.0]), Vector3.ZERO) + Vector3(0.0, 0.75, 0.0)
	highlight_root.add_child(marker)
	_capture_active_marker_refs()
	return true


func pulse_prop(prop_id: String, owner: Node) -> bool:
	if not highlight_prop(prop_id):
		return false
	var marker: Node3D = null
	if highlight_root.get_child_count() > 0:
		marker = highlight_root.get_child(0) as Node3D
	if marker == null:
		return false
	if _pulse_tween != null:
		_pulse_tween.kill()
	marker.scale = Vector3.ONE
	_pulse_tween = owner.create_tween()
	_pulse_tween.set_loops(6)
	_pulse_tween.tween_property(marker, "scale", Vector3(1.12, 1.12, 1.12), 0.42)
	_pulse_tween.tween_property(marker, "scale", Vector3.ONE, 0.42)
	return true


func clear_highlight() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
	for child in highlight_root.get_children():
		child.free()
	_active_marker_material = null
	_active_marker_label = null


func set_highlight_completed(completed: bool) -> void:
	if _active_marker_material == null:
		return
	if completed:
		_active_marker_material.emission = Color(0.64, 0.56, 0.38, 1.0)
		_active_marker_material.emission_energy_multiplier = 0.25
		_active_marker_material.albedo_color = Color(0.62, 0.54, 0.38, 0.44)
		if _active_marker_label != null:
			_active_marker_label.text = _active_marker_label.text + "  ✓"
	else:
		_active_marker_material.emission = Color(0.96, 0.73, 0.32, 1.0)
		_active_marker_material.emission_energy_multiplier = 1.05
		_active_marker_material.albedo_color = Color(0.92, 0.68, 0.28, 0.66)


func _create_highlight_marker(label_text: String) -> Node3D:
	var marker_root: Node3D = Node3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	sphere.radial_segments = 16
	sphere.rings = 8
	var marker: MeshInstance3D = MeshInstance3D.new()
	marker.mesh = sphere
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.92, 0.68, 0.28, 0.66)
	material.emission_enabled = true
	material.emission = Color(0.96, 0.73, 0.32, 1.0)
	material.emission_energy_multiplier = 1.05
	marker.set_surface_override_material(0, material)
	marker_root.add_child(marker)

	var label: Label3D = Label3D.new()
	label.text = label_text
	label.position = Vector3(0.0, 0.3, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 24
	label.modulate = Color(0.98, 0.93, 0.84, 1.0)
	marker_root.add_child(label)
	return marker_root


func _capture_active_marker_refs() -> void:
	_active_marker_material = null
	_active_marker_label = null
	if highlight_root.get_child_count() == 0:
		return
	var marker_root: Node3D = highlight_root.get_child(0) as Node3D
	if marker_root == null:
		return
	for child in marker_root.get_children():
		if child is MeshInstance3D and _active_marker_material == null:
			_active_marker_material = (child as MeshInstance3D).get_active_material(0) as StandardMaterial3D
		if child is Label3D and _active_marker_label == null:
			_active_marker_label = child as Label3D


func get_props_by_types(types: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_prop in prop_data_by_id.values():
		if typeof(raw_prop) != TYPE_DICTIONARY:
			continue
		var prop_data: Dictionary = raw_prop as Dictionary
		if types.has(str(prop_data.get("type", ""))):
			result.append(prop_data.duplicate(true))
	return result


func _create_prop(prop_data: Dictionary) -> Node3D:
	var prop_type: String = str(prop_data.get("type", "crate"))
	var prop_node: Node3D
	match prop_type:
		"barrel":
			prop_node = _create_barrel_prop(prop_data)
		"table":
			prop_node = _create_table_prop(prop_data)
		"sign":
			prop_node = _create_sign_prop(prop_data)
		"column":
			prop_node = _create_column_prop(prop_data)
		"wine_glass":
			prop_node = _create_wine_glass_prop(prop_data)
		"bottle_silhouette":
			prop_node = _create_bottle_silhouette_prop(prop_data)
		"tasting_card":
			prop_node = _create_tasting_card_prop(prop_data)
		"wall_plaque":
			prop_node = _create_wall_plaque_prop(prop_data)
		_:
			prop_node = _create_crate_prop(prop_data)
	prop_node.name = str(prop_data.get("id", prop_type))
	prop_node.position = _array_to_vector3(prop_data.get("position", [0.0, 0.0, 0.0]), Vector3.ZERO)
	prop_node.rotation = _array_to_rotation(prop_data.get("rotation", [0.0, 0.0, 0.0]))
	prop_node.scale = _array_to_vector3(prop_data.get("scale", [1.0, 1.0, 1.0]), Vector3.ONE)
	return prop_node


func _create_barrel_prop(prop_data: Dictionary) -> Node3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.34
	mesh.bottom_radius = 0.39
	mesh.height = 1.05
	mesh.radial_segments = 16
	return _mesh_instance(mesh, prop_data, environment.barrel_material.albedo_color if environment.barrel_material != null else Color(0.451, 0.29, 0.176, 1.0))


func _create_crate_prop(prop_data: Dictionary) -> Node3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.82, 0.42, 0.58)
	return _mesh_instance(mesh, prop_data, Color(0.36, 0.23, 0.13, 1.0))


func _create_column_prop(prop_data: Dictionary) -> Node3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.28
	mesh.bottom_radius = 0.28
	mesh.height = 1.2
	mesh.radial_segments = 12
	return _mesh_instance(mesh, prop_data, environment.wall_material.albedo_color if environment.wall_material != null else Color(0.545, 0.506, 0.447, 1.0))


func _create_sign_prop(prop_data: Dictionary) -> Node3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(1.18, 0.62, 0.055)
	return _mesh_instance(mesh, prop_data, Color(0.78, 0.62, 0.34, 1.0))


func _create_table_prop(prop_data: Dictionary) -> Node3D:
	var table_root: Node3D = Node3D.new()
	table_root.add_child(_create_box_part(Vector3(1.35, 0.1, 0.72), Vector3(0.0, 0.38, 0.0), prop_data, Color(0.42, 0.25, 0.15, 1.0)))
	for x in [-0.48, 0.48]:
		for z in [-0.22, 0.22]:
			table_root.add_child(_create_box_part(Vector3(0.08, 0.58, 0.08), Vector3(x, 0.05, z), prop_data, Color(0.34, 0.20, 0.12, 1.0)))
	return table_root


func _create_wine_glass_prop(prop_data: Dictionary) -> Node3D:
	var glass_root: Node3D = Node3D.new()
	var material: StandardMaterial3D = _make_glass_material(prop_data)

	var bowl_mesh: CylinderMesh = CylinderMesh.new()
	bowl_mesh.top_radius = 0.14
	bowl_mesh.bottom_radius = 0.09
	bowl_mesh.height = 0.28
	bowl_mesh.radial_segments = 16
	var bowl: MeshInstance3D = MeshInstance3D.new()
	bowl.mesh = bowl_mesh
	bowl.position = Vector3(0.0, 0.34, 0.0)
	bowl.set_surface_override_material(0, material)
	glass_root.add_child(bowl)

	var stem_mesh: CylinderMesh = CylinderMesh.new()
	stem_mesh.top_radius = 0.018
	stem_mesh.bottom_radius = 0.018
	stem_mesh.height = 0.28
	stem_mesh.radial_segments = 10
	var stem: MeshInstance3D = MeshInstance3D.new()
	stem.mesh = stem_mesh
	stem.position = Vector3(0.0, 0.18, 0.0)
	stem.set_surface_override_material(0, material)
	glass_root.add_child(stem)

	var base_mesh: CylinderMesh = CylinderMesh.new()
	base_mesh.top_radius = 0.12
	base_mesh.bottom_radius = 0.13
	base_mesh.height = 0.035
	base_mesh.radial_segments = 16
	var base: MeshInstance3D = MeshInstance3D.new()
	base.mesh = base_mesh
	base.position = Vector3(0.0, 0.02, 0.0)
	base.set_surface_override_material(0, material)
	glass_root.add_child(base)
	return glass_root


func _create_bottle_silhouette_prop(prop_data: Dictionary) -> Node3D:
	var bottle_root: Node3D = Node3D.new()
	var bottle_color: Color = Color(0.08, 0.06, 0.045, 1.0)
	bottle_root.add_child(_create_cylinder_part(0.13, 0.15, 0.52, Vector3(0.0, 0.28, 0.0), 14, prop_data, bottle_color))
	bottle_root.add_child(_create_cylinder_part(0.055, 0.065, 0.28, Vector3(0.0, 0.68, 0.0), 12, prop_data, bottle_color))
	bottle_root.add_child(_create_cylinder_part_with_color(0.062, 0.062, 0.06, Vector3(0.0, 0.85, 0.0), 12, Color(0.62, 0.46, 0.22, 1.0)))
	return bottle_root


func _create_tasting_card_prop(prop_data: Dictionary) -> Node3D:
	var card_root: Node3D = Node3D.new()
	card_root.add_child(_create_box_part(Vector3(0.58, 0.035, 0.38), Vector3.ZERO, prop_data, Color(0.88, 0.81, 0.64, 1.0)))
	card_root.add_child(_create_box_part_with_color(Vector3(0.54, 0.038, 0.035), Vector3(0.0, 0.005, -0.13), Color(0.58, 0.42, 0.2, 1.0)))
	return card_root


func _create_wall_plaque_prop(prop_data: Dictionary) -> Node3D:
	var plaque_root: Node3D = Node3D.new()
	plaque_root.add_child(_create_box_part(Vector3(0.86, 0.5, 0.055), Vector3.ZERO, prop_data, Color(0.38, 0.27, 0.16, 1.0)))
	plaque_root.add_child(_create_box_part_with_color(Vector3(0.76, 0.055, 0.064), Vector3(0.0, 0.2, 0.006), Color(0.74, 0.56, 0.28, 1.0)))
	plaque_root.add_child(_create_box_part_with_color(Vector3(0.76, 0.055, 0.064), Vector3(0.0, -0.2, 0.006), Color(0.74, 0.56, 0.28, 1.0)))
	return plaque_root


func _mesh_instance(mesh: Mesh, prop_data: Dictionary, fallback_color: Color) -> MeshInstance3D:
	var prop: MeshInstance3D = MeshInstance3D.new()
	prop.mesh = mesh
	prop.set_surface_override_material(0, _make_prop_material(prop_data, fallback_color))
	return prop


func _create_box_part(size: Vector3, part_position: Vector3, prop_data: Dictionary, fallback_color: Color) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var part: MeshInstance3D = _mesh_instance(mesh, prop_data, fallback_color)
	part.position = part_position
	return part


func _create_box_part_with_color(size: Vector3, part_position: Vector3, color: Color) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var part: MeshInstance3D = MeshInstance3D.new()
	part.mesh = mesh
	part.position = part_position
	part.set_surface_override_material(0, _make_fixed_material(color))
	return part


func _create_cylinder_part(top_radius: float, bottom_radius: float, height: float, part_position: Vector3, radial_segments: int, prop_data: Dictionary, fallback_color: Color) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	var part: MeshInstance3D = _mesh_instance(mesh, prop_data, fallback_color)
	part.position = part_position
	return part


func _create_cylinder_part_with_color(top_radius: float, bottom_radius: float, height: float, part_position: Vector3, radial_segments: int, color: Color) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	var part: MeshInstance3D = MeshInstance3D.new()
	part.mesh = mesh
	part.position = part_position
	part.set_surface_override_material(0, _make_fixed_material(color))
	return part


func _make_prop_material(prop_data: Dictionary, fallback_color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = environment.parse_color(prop_data.get("color", ""), fallback_color) if environment != null else fallback_color
	material.roughness = 0.82
	return material


func _make_fixed_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material


func _make_glass_material(prop_data: Dictionary) -> StandardMaterial3D:
	var material: StandardMaterial3D = _make_prop_material(prop_data, Color(0.86, 0.9, 0.88, 0.32))
	var glass_color: Color = material.albedo_color
	glass_color.a = 0.32
	material.albedo_color = glass_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.18
	material.metallic = 0.0
	return material


func _attach_prop_interaction(prop_data: Dictionary) -> void:
	var area: Area3D = Area3D.new()
	area.name = "PropInteractionArea"
	area.add_to_group("winery_prop")
	area.collision_layer = 1
	area.collision_mask = 1
	area.position = _array_to_vector3(prop_data.get("position", [0.0, 0.0, 0.0]), Vector3.ZERO)
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 0.55
	collision_shape.shape = sphere
	area.add_child(collision_shape)
	interaction_root.add_child(area)
	prop_data_by_instance_id[area.get_instance_id()] = prop_data.duplicate(true)


func _attach_prop_label(prop_node: Node3D, prop_data: Dictionary) -> void:
	if prop_node == null:
		return
	var label_text: String = str(prop_data.get("label", ""))
	if label_text.is_empty():
		return
	if _current_quality == "low" and not bool(prop_data.get("show_label_on_low_quality", false)):
		return
	var label: Label3D = Label3D.new()
	if label == null:
		return
	label.text = label_text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = clampi(int(prop_data.get("label_font_size", 22)), 12, 32)
	label.modulate = environment.parse_color(prop_data.get("label_color", "#F5E8C7"), Color(0.96, 0.91, 0.78, 1.0)) if environment != null else Color(0.96, 0.91, 0.78, 1.0)
	label.outline_size = clampi(int(prop_data.get("label_outline_size", 5)), 3, 8)
	label.outline_modulate = Color(0.04, 0.035, 0.03, 0.9)
	label.position = _clamp_label_offset(_array_to_vector3(prop_data.get("label_offset", [0.0, 0.85, 0.0]), Vector3(0.0, 0.85, 0.0)))
	prop_node.add_child(label)


func _array_to_vector3(value: Variant, fallback: Vector3) -> Vector3:
	if typeof(value) != TYPE_ARRAY:
		return fallback
	var data: Array = value as Array
	if data.size() < 3:
		return fallback
	return Vector3(float(data[0]), float(data[1]), float(data[2]))


func _array_to_rotation(value: Variant) -> Vector3:
	var degrees: Vector3 = _array_to_vector3(value, Vector3.ZERO)
	return Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z))


func _clamp_label_offset(offset: Vector3) -> Vector3:
	return Vector3(
		clampf(offset.x, -1.15, 1.15),
		clampf(offset.y, 0.12, 1.25),
		clampf(offset.z, -0.45, 0.45)
	)


func _max_props_for_quality(quality: String, total: int) -> int:
	match quality:
		"low":
			return mini(total, 3)
		"high":
			return total
		_:
			return mini(total, 6)


func _normalize_quality(value: String) -> String:
	if ["low", "medium", "high"].has(value):
		return value
	return "medium"


func _tag_prop_for_performance_groups(prop_node: Node3D, prop_data: Dictionary) -> void:
	if prop_node == null:
		return
	var prop_type: String = str(prop_data.get("type", ""))
	if ["barrel", "crate", "column", "sign", "table"].has(prop_type):
		prop_node.add_to_group("performance_optional")
		prop_node.add_to_group("ultra_disable")
