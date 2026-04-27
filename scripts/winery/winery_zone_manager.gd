extends RefCounted
class_name WineryZoneManager

var root: Node3D
var zone_data_by_instance_id: Dictionary = {}
var door_interactable: Dictionary = {}


func setup(parent: Node3D) -> void:
	root = Node3D.new()
	root.name = "ConfigZones"
	parent.add_child(root)


func rebuild(raw_zones: Array) -> void:
	for child in root.get_children():
		child.queue_free()
	zone_data_by_instance_id.clear()

	for raw_zone in raw_zones:
		if typeof(raw_zone) != TYPE_DICTIONARY:
			continue
		var zone_data: Dictionary = raw_zone as Dictionary
		if str(zone_data.get("type", "")) == "door":
			door_interactable = zone_data.duplicate(true)
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


func get_zone_data_from_collider(collider: Object) -> Dictionary:
	if collider is Node:
		var node: Node = collider as Node
		while node != null:
			if node.is_in_group("winery_zone") and zone_data_by_instance_id.has(node.get_instance_id()):
				return (zone_data_by_instance_id[node.get_instance_id()] as Dictionary).duplicate(true)
			node = node.get_parent()
	return {}


func _array_to_vector3(value: Variant, fallback: Vector3) -> Vector3:
	if typeof(value) != TYPE_ARRAY:
		return fallback
	var data: Array = value as Array
	if data.size() < 3:
		return fallback
	return Vector3(float(data[0]), float(data[1]), float(data[2]))
