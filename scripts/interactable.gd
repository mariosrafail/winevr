extends Node3D
class_name Interactable

signal interacted(interactable: Interactable)

@export var id: String = ""
@export var title: String = "Interactable"
@export_multiline var description: String = ""
@export_enum("glass", "bottle", "plaque", "generic") var type: String = "generic"
@export var hover_scale_multiplier: float = 1.04
@export var hover_tween_duration: float = 0.12
@export var glow_on_hover: bool = false
@export var glow_color: Color = Color(0.95, 0.72, 0.34, 1.0)
@export var glow_energy: float = 0.7

var _is_hovered: bool = false
var _base_scale: Vector3 = Vector3.ONE
var _hover_tween: Tween
var _mesh_material_cache: Dictionary = {}
var _mesh_original_material_cache: Dictionary = {}


func _ready() -> void:
	_base_scale = scale


func set_hovered(hovered: bool) -> void:
	if _is_hovered == hovered:
		return
	_is_hovered = hovered

	if _hover_tween != null:
		_hover_tween.kill()
	_hover_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var target_scale: Vector3 = _base_scale * hover_scale_multiplier if hovered else _base_scale
	_hover_tween.tween_property(self, "scale", target_scale, hover_tween_duration)

	if glow_on_hover:
		_apply_hover_glow(hovered)


func interact() -> void:
	interacted.emit(self)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"text": description,
		"description": description,
		"type": type
	}


func _apply_hover_glow(enabled: bool) -> void:
	var mesh_nodes: Array = _find_mesh_nodes(self)
	for raw_node in mesh_nodes:
		var mesh_node: MeshInstance3D = raw_node as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null:
			continue
		var surface_count: int = mesh_node.mesh.get_surface_count()
		for surface_index in range(surface_count):
			var key: String = str(mesh_node.get_instance_id()) + ":" + str(surface_index)
			if not _mesh_material_cache.has(key):
				var source_material: Material = mesh_node.get_active_material(surface_index)
				_mesh_original_material_cache[key] = source_material
				if source_material is StandardMaterial3D:
					_mesh_material_cache[key] = (source_material as StandardMaterial3D).duplicate()
				else:
					_mesh_material_cache[key] = StandardMaterial3D.new()
			var hover_material: StandardMaterial3D = _mesh_material_cache[key] as StandardMaterial3D
			hover_material.emission_enabled = enabled
			hover_material.emission = glow_color if enabled else Color(0.0, 0.0, 0.0, 1.0)
			hover_material.emission_energy_multiplier = glow_energy if enabled else 0.0
			mesh_node.set_surface_override_material(surface_index, hover_material if enabled else _mesh_original_material_cache[key])


func _find_mesh_nodes(root: Node) -> Array:
	var result: Array = []
	if root is MeshInstance3D:
		result.append(root)
	for child in root.get_children():
		if child is Node:
			result.append_array(_find_mesh_nodes(child as Node))
	return result
