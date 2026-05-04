extends RefCounted
class_name WineryZoneManager

var root: Node3D
var zone_data_by_instance_id: Dictionary = {}
var door_interactable: Dictionary = {}
var zone_data_by_id: Dictionary = {}
var highlight_root: Node3D
var active_highlight: Node3D
var _pulse_tween: Tween
var _active_marker_material: StandardMaterial3D
var _active_marker_label: Label3D


func setup(parent: Node3D) -> void:
	root = Node3D.new()
	root.name = "ConfigZones"
	parent.add_child(root)
	highlight_root = Node3D.new()
	highlight_root.name = "ConfigZoneHighlights"
	highlight_root.add_to_group("highlight_effects")
	highlight_root.add_to_group("performance_optional")
	parent.add_child(highlight_root)


func rebuild(raw_zones: Array) -> void:
	for child in root.get_children():
		child.free()
	clear_highlight()
	zone_data_by_instance_id.clear()
	zone_data_by_id.clear()
	active_highlight = null

	for raw_zone in raw_zones:
		if typeof(raw_zone) != TYPE_DICTIONARY:
			continue
		var zone_data: Dictionary = raw_zone as Dictionary
		if str(zone_data.get("type", "")) == "door":
			door_interactable = zone_data.duplicate(true)
			zone_data_by_id[str(zone_data.get("id", ""))] = zone_data.duplicate(true)
			continue
		var zone: Area3D = Area3D.new()
		zone.name = str(zone_data.get("id", "zone"))
		zone.add_to_group("winery_zone")
		zone.position = _array_to_vector3(zone_data.get("position", [0.0, 1.1, -1.0]), Vector3(0.0, 1.1, -1.0))
		zone.collision_layer = 1
		zone.collision_mask = 1
		var collision_shape: CollisionShape3D = CollisionShape3D.new()
		var sphere: SphereShape3D = SphereShape3D.new()
		sphere.radius = maxf(0.15, float(zone_data.get("radius", 0.7)))
		collision_shape.shape = sphere
		zone.add_child(collision_shape)
		root.add_child(zone)
		zone_data_by_instance_id[zone.get_instance_id()] = zone_data.duplicate(true)
		zone_data_by_id[str(zone_data.get("id", ""))] = zone_data.duplicate(true)


func get_zone_data_from_collider(collider: Object) -> Dictionary:
	if collider is Node:
		var node: Node = collider as Node
		while node != null:
			if node.is_in_group("winery_zone") and zone_data_by_instance_id.has(node.get_instance_id()):
				return (zone_data_by_instance_id[node.get_instance_id()] as Dictionary).duplicate(true)
			node = node.get_parent()
	return {}


func highlight_zone(zone_id: String) -> bool:
	clear_highlight()
	if not zone_data_by_id.has(zone_id):
		return false

	var zone_data: Dictionary = zone_data_by_id[zone_id]
	active_highlight = _create_highlight_marker(str(zone_data.get("title", zone_id)))
	active_highlight.position = _array_to_vector3(zone_data.get("position", [0.0, 1.1, -1.0]), Vector3(0.0, 1.1, -1.0))
	highlight_root.add_child(active_highlight)
	_capture_active_marker_refs()
	return true


func pulse_zone(zone_id: String, owner: Node) -> bool:
	if not highlight_zone(zone_id):
		return false
	_pulse_active_highlight(owner)
	return true


func clear_highlight() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
	for child in highlight_root.get_children():
		child.free()
	active_highlight = null
	_active_marker_material = null
	_active_marker_label = null


func set_highlight_completed(completed: bool) -> void:
	if _active_marker_material == null:
		return
	if completed:
		_active_marker_material.emission = Color(0.64, 0.56, 0.38, 1.0)
		_active_marker_material.emission_energy_multiplier = 0.24
		_active_marker_material.albedo_color = Color(0.62, 0.54, 0.38, 0.44)
		if _active_marker_label != null:
			_active_marker_label.text = _active_marker_label.text + "  ✓"
	else:
		_active_marker_material.emission = Color(0.96, 0.73, 0.32, 1.0)
		_active_marker_material.emission_energy_multiplier = 1.0
		_active_marker_material.albedo_color = Color(0.92, 0.68, 0.28, 0.66)


func _create_highlight_marker(label_text: String) -> Node3D:
	var marker_root: Node3D = Node3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	sphere.radial_segments = 16
	sphere.rings = 8
	var marker: MeshInstance3D = MeshInstance3D.new()
	marker.mesh = sphere
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.92, 0.68, 0.28, 0.66)
	material.emission_enabled = true
	material.emission = Color(0.96, 0.73, 0.32, 1.0)
	material.emission_energy_multiplier = 1.0
	marker.set_surface_override_material(0, material)
	marker_root.add_child(marker)

	var label: Label3D = Label3D.new()
	label.text = label_text
	label.position = Vector3(0.0, 0.34, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 24
	label.modulate = Color(0.98, 0.93, 0.84, 1.0)
	marker_root.add_child(label)
	return marker_root


func _pulse_active_highlight(owner: Node) -> void:
	if active_highlight == null:
		return
	if _pulse_tween != null:
		_pulse_tween.kill()
	active_highlight.scale = Vector3.ONE
	_pulse_tween = owner.create_tween()
	_pulse_tween.set_loops(6)
	_pulse_tween.tween_property(active_highlight, "scale", Vector3(1.1, 1.1, 1.1), 0.42)
	_pulse_tween.tween_property(active_highlight, "scale", Vector3.ONE, 0.42)


func _capture_active_marker_refs() -> void:
	_active_marker_material = null
	_active_marker_label = null
	if active_highlight == null:
		return
	for child in active_highlight.get_children():
		if child is MeshInstance3D and _active_marker_material == null:
			_active_marker_material = (child as MeshInstance3D).get_active_material(0) as StandardMaterial3D
		if child is Label3D and _active_marker_label == null:
			_active_marker_label = child as Label3D


func _array_to_vector3(value: Variant, fallback: Vector3) -> Vector3:
	if typeof(value) != TYPE_ARRAY:
		return fallback
	var data: Array = value as Array
	if data.size() < 3:
		return fallback
	return Vector3(float(data[0]), float(data[1]), float(data[2]))
