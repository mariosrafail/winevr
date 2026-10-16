extends Node3D
class_name VRVialHotspotController

const LABEL_SCENE: PackedScene = preload("res://scenes/vr/VRVialHotspotLabel.tscn")
const FALLBACK_HOTSPOTS: Array[Dictionary] = [
	{"id": "origin", "title": "Origin", "description": "Discover where this wine comes from."},
	{"id": "aroma", "title": "Aroma", "description": "Explore the aroma notes."},
	{"id": "craft", "title": "Craft", "description": "Learn how this wine was crafted."},
	{"id": "pairing", "title": "Pairing", "description": "Find a pairing suggestion for this tasting."},
	{"id": "qr", "title": "QR", "description": "Review the connected bottle profile."}
]
const NAMED_POSITIONS: Dictionary = {
	"origin": Vector3(-0.22, 0.12, -0.04),
	"aroma": Vector3(0.22, 0.12, -0.04),
	"craft": Vector3(-0.20, -0.04, -0.03),
	"pairing": Vector3(0.20, -0.04, -0.03),
	"qr": Vector3(0.0, 0.22, -0.06)
}

var _camera: Camera3D
var _interaction_ray: RayCast3D
var _show_info_callback: Callable
var _activated_callback: Callable
var _labels: Array[Area3D] = []
var _completed_ids: Dictionary = {}
var _hovered_label: Area3D
var _enabled: bool = false


func _ready() -> void:
	set_enabled(false)


func setup(camera: Camera3D, interaction_ray: RayCast3D, show_info_callback: Callable = Callable(), activated_callback: Callable = Callable()) -> void:
	_camera = camera
	_interaction_ray = interaction_ray
	_show_info_callback = show_info_callback
	_activated_callback = activated_callback
	set_process(_enabled)


func configure_from_profile(client_data: Dictionary) -> void:
	clear_labels()
	var hotspot_data: Array[Dictionary] = _extract_hotspots(client_data)
	for index in range(hotspot_data.size()):
		var label: Area3D = LABEL_SCENE.instantiate() as Area3D
		if label == null:
			continue
		add_child(label)
		label.call("setup", hotspot_data[index])
		label.position = _position_for_label(str(label.get("hotspot_id")), index, hotspot_data.size())
		label.rotation_degrees = Vector3.ZERO
		label.call("set_enabled", _enabled)
		label.call("set_completed", _completed_ids.has(str(label.get("hotspot_id"))))
		_labels.append(label)
	print("[WineVR][VR] Vial hotspot labels created: %d" % _labels.size())


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	visible = enabled
	set_process(enabled)
	for label in _labels:
		if label != null:
			label.call("set_enabled", enabled)
	if not enabled:
		_set_hovered_label(null)
		if not _labels.is_empty():
			print("[WineVR][VR] Vial hotspot labels hidden")


func clear_labels() -> void:
	_set_hovered_label(null)
	for label in _labels:
		if label != null:
			label.call("set_enabled", false)
			label.queue_free()
	_labels.clear()
	print("[WineVR][VR] Vial hotspot labels cleared")


func has_hovered_label() -> bool:
	return _enabled and _hovered_label != null


func try_activate_hovered() -> bool:
	_update_hover_from_ray()
	if not _enabled or _hovered_label == null:
		return false
	var payload: Dictionary = _hovered_label.call("get_payload")
	var hotspot_id: String = str(payload.get("id", ""))
	_completed_ids[hotspot_id] = true
	_hovered_label.call("set_completed", true)
	print("[WineVR][VR] Vial hotspot activated: %s" % hotspot_id)
	if _show_info_callback.is_valid():
		_show_info_callback.call(payload)
	else:
		print("%s: %s" % [str(payload.get("title", "Detail")), str(payload.get("description", ""))])
	if _activated_callback.is_valid():
		_activated_callback.call(payload)
	return true


func is_vial_hotspot_collider(collider: Object) -> bool:
	return _label_from_collider(collider) != null


func _process(_delta: float) -> void:
	if not _enabled:
		return
	_face_labels_to_camera()
	_update_hover_from_ray()


func _face_labels_to_camera() -> void:
	if _camera == null:
		return
	for label in _labels:
		if label == null or not is_instance_valid(label):
			continue
		var to_camera: Vector3 = _camera.global_position - label.global_position
		if to_camera.length_squared() > 0.0001:
			label.look_at(_camera.global_position, Vector3.UP, true)


func _update_hover_from_ray() -> void:
	if _interaction_ray == null or not _interaction_ray.enabled:
		_set_hovered_label(null)
		return
	_interaction_ray.force_raycast_update()
	if not _interaction_ray.is_colliding():
		_set_hovered_label(null)
		return
	_set_hovered_label(_label_from_collider(_interaction_ray.get_collider()))


func _set_hovered_label(next_label: Area3D) -> void:
	if _hovered_label == next_label:
		return
	if _hovered_label != null and is_instance_valid(_hovered_label):
		_hovered_label.call("set_hovered", false)
	_hovered_label = next_label
	if _hovered_label != null:
		_hovered_label.call("set_hovered", true)
		print("[WineVR][VR] Vial hotspot hovered: %s" % str(_hovered_label.get("hotspot_id")))


func _label_from_collider(collider: Object) -> Area3D:
	var node: Node = collider as Node
	while node != null:
		if node.has_method("get_payload") and node.has_method("set_hovered"):
			return node as Area3D
		node = node.get_parent()
	return null


func _extract_hotspots(client_data: Dictionary) -> Array[Dictionary]:
	var profile_hotspots: Array[Dictionary] = []
	var experience_settings: Dictionary = _dict_value(client_data.get("experience_settings", {}))
	var raw_hotspots: Variant = experience_settings.get("hotspots", [])
	if typeof(raw_hotspots) == TYPE_ARRAY:
		for raw in raw_hotspots:
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var source: Dictionary = raw as Dictionary
			var id_value: String = str(source.get("id", "")).strip_edges()
			var title_value: String = str(source.get("title", _fallback_title(id_value))).strip_edges()
			var body_value: String = str(source.get("description", source.get("text", source.get("body", "")))).strip_edges()
			if id_value.is_empty() and title_value.is_empty():
				continue
			profile_hotspots.append({
				"id": id_value if not id_value.is_empty() else title_value.to_snake_case(),
				"title": title_value if not title_value.is_empty() else _fallback_title(id_value),
				"description": body_value,
				"text": body_value,
				"type": "hotspot"
			})
	if profile_hotspots.is_empty():
		return FALLBACK_HOTSPOTS.duplicate(true)
	return profile_hotspots


func _position_for_label(hotspot_id: String, index: int, count: int) -> Vector3:
	var normalized_id: String = hotspot_id.to_lower()
	if NAMED_POSITIONS.has(normalized_id):
		return NAMED_POSITIONS[normalized_id]
	var safe_count: int = max(count, 1)
	var angle: float = (TAU * float(index) / float(safe_count)) - PI * 0.5
	var radius_x: float = 0.23
	var radius_y: float = 0.14
	return Vector3(cos(angle) * radius_x, sin(angle) * radius_y + 0.06, -0.05)


func _fallback_title(id_value: String) -> String:
	if id_value.is_empty():
		return "Detail"
	return id_value.replace("_", " ").capitalize()


func _dict_value(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}
