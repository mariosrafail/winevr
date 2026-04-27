extends RefCounted
class_name WineryPropFactory

var root: Node3D
var interaction_root: Node3D
var prop_data_by_instance_id: Dictionary = {}
var environment: WineryEnvironmentApplier


func setup(parent: Node3D, environment_applier: WineryEnvironmentApplier) -> void:
	environment = environment_applier
	root = Node3D.new()
	root.name = "ConfigProps"
	parent.add_child(root)
	interaction_root = Node3D.new()
	interaction_root.name = "ConfigPropInteractionAreas"
	parent.add_child(interaction_root)


func rebuild(raw_props: Array) -> void:
	for child in root.get_children():
		child.queue_free()
	for child in interaction_root.get_children():
		child.queue_free()
	prop_data_by_instance_id.clear()

	for raw_prop in raw_props:
		if typeof(raw_prop) != TYPE_DICTIONARY:
			continue
		var prop_data: Dictionary = raw_prop as Dictionary
		if not bool(prop_data.get("visible", true)):
			continue
		var prop_node: Node3D = _create_prop(prop_data)
		root.add_child(prop_node)
		_attach_prop_interaction(prop_data)


func get_prop_data_from_collider(collider: Object) -> Dictionary:
	if collider is Node:
		var node: Node = collider as Node
		while node != null:
			if node.is_in_group("winery_prop") and prop_data_by_instance_id.has(node.get_instance_id()):
				return (prop_data_by_instance_id[node.get_instance_id()] as Dictionary).duplicate(true)
			node = node.get_parent()
	return {}


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
		_:
			prop_node = _create_crate_prop(prop_data)
	prop_node.name = str(prop_data.get("id", prop_type))
	prop_node.position = _array_to_vector3(prop_data.get("position", [0.0, 0.0, 0.0]), Vector3.ZERO)
	prop_node.rotation = _array_to_rotation(prop_data.get("rotation", [0.0, 0.0, 0.0]))
	prop_node.scale = _array_to_vector3(prop_data.get("scale", [1.0, 1.0, 1.0]), Vector3.ONE)
	return prop_node


func _create_barrel_prop(prop_data: Dictionary) -> Node3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.38
	mesh.bottom_radius = 0.38
	mesh.height = 0.95
	mesh.radial_segments = 16
	return _mesh_instance(mesh, prop_data, environment.barrel_material.albedo_color if environment.barrel_material != null else Color(0.451, 0.29, 0.176, 1.0))


func _create_crate_prop(prop_data: Dictionary) -> Node3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.75, 0.55, 0.55)
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
	mesh.size = Vector3(1.0, 0.55, 0.06)
	return _mesh_instance(mesh, prop_data, Color(0.78, 0.62, 0.34, 1.0))


func _create_table_prop(prop_data: Dictionary) -> Node3D:
	var table_root: Node3D = Node3D.new()
	table_root.add_child(_create_box_part(Vector3(1.2, 0.12, 0.65), Vector3(0.0, 0.28, 0.0), prop_data, Color(0.42, 0.25, 0.15, 1.0)))
	for x in [-0.48, 0.48]:
		for z in [-0.22, 0.22]:
			table_root.add_child(_create_box_part(Vector3(0.09, 0.48, 0.09), Vector3(x, 0.0, z), prop_data, Color(0.34, 0.20, 0.12, 1.0)))
	return table_root


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


func _make_prop_material(prop_data: Dictionary, fallback_color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = environment.parse_color(prop_data.get("color", ""), fallback_color)
	material.roughness = 0.82
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
