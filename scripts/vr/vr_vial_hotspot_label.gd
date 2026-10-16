extends Area3D
class_name VRVialHotspotLabel

@export var hotspot_id: String = ""
@export var title: String = ""
@export_multiline var body: String = ""

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var background: MeshInstance3D = $Background
@onready var text_label: Label3D = $Text
@onready var gold_dot: MeshInstance3D = $GoldDot

var _base_scale: Vector3 = Vector3.ONE
var _background_material: StandardMaterial3D
var _accent_material: StandardMaterial3D
var _text_base_modulate: Color = Color(1.0, 0.92, 0.78, 1.0)


func _ready() -> void:
	_base_scale = scale
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	monitorable = true
	_apply_materials()
	_disable_shadows_recursive(self)
	set_hovered(false)
	set_completed(false)


func setup(data: Dictionary) -> void:
	hotspot_id = str(data.get("id", ""))
	title = str(data.get("title", _fallback_title(hotspot_id)))
	body = str(data.get("description", data.get("text", data.get("body", ""))))
	if hotspot_id.is_empty():
		hotspot_id = title.to_snake_case()
	if text_label != null:
		text_label.text = _short_title(title)


func set_hovered(active: bool) -> void:
	scale = _base_scale * (1.12 if active else 1.0)
	if _background_material != null:
		_background_material.albedo_color = Color(0.13, 0.065, 0.075, 0.82) if active else Color(0.055, 0.035, 0.04, 0.68)
	if _accent_material != null:
		_accent_material.albedo_color = Color(1.0, 0.82, 0.36, 1.0) if active else Color(0.84, 0.64, 0.24, 0.94)
	if text_label != null:
		text_label.modulate = Color(1.0, 0.96, 0.82, 1.0) if active else _text_base_modulate


func set_completed(active: bool) -> void:
	if text_label != null:
		text_label.modulate = Color(0.82, 0.78, 0.68, 1.0) if active else _text_base_modulate
	if _accent_material != null and active:
		_accent_material.albedo_color = Color(0.55, 0.48, 0.32, 0.9)


func set_enabled(enabled: bool) -> void:
	visible = enabled
	monitoring = enabled
	monitorable = enabled
	if collision_shape != null:
		collision_shape.disabled = not enabled
	if not enabled:
		set_hovered(false)


func get_payload() -> Dictionary:
	return {
		"id": hotspot_id,
		"title": title,
		"description": body,
		"text": body,
		"type": "hotspot"
	}


func _apply_materials() -> void:
	_background_material = StandardMaterial3D.new()
	_background_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_background_material.albedo_color = Color(0.055, 0.035, 0.04, 0.68)
	_background_material.roughness = 0.76
	_background_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if background != null:
		background.set_surface_override_material(0, _background_material)

	_accent_material = StandardMaterial3D.new()
	_accent_material.albedo_color = Color(0.84, 0.64, 0.24, 0.94)
	_accent_material.emission_enabled = true
	_accent_material.emission = Color(0.45, 0.31, 0.08, 1.0)
	_accent_material.emission_energy_multiplier = 0.18
	_accent_material.roughness = 0.48
	if gold_dot != null:
		gold_dot.set_surface_override_material(0, _accent_material)

	if text_label != null:
		text_label.modulate = _text_base_modulate
		text_label.no_depth_test = true


func _short_title(value: String) -> String:
	var clean_title: String = value.strip_edges()
	if clean_title.length() <= 18:
		return clean_title
	return clean_title.substr(0, 16).strip_edges() + ".."


func _fallback_title(id_value: String) -> String:
	if id_value.is_empty():
		return "Detail"
	return id_value.replace("_", " ").capitalize()


func _disable_shadows_recursive(root: Node) -> void:
	if root is GeometryInstance3D:
		(root as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in root.get_children():
		_disable_shadows_recursive(child)
