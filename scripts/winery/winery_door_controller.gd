extends RefCounted
class_name WineryDoorController

var door_hinge: Node3D
var door_mesh: MeshInstance3D
var door_material: StandardMaterial3D
var is_open: bool = false
var is_highlighted: bool = false


func setup(hinge: Node3D, mesh: MeshInstance3D) -> void:
	door_hinge = hinge
	door_mesh = mesh
	var source_material: Material = door_mesh.get_surface_override_material(0)
	if source_material is StandardMaterial3D:
		door_material = (source_material as StandardMaterial3D).duplicate()
	else:
		door_material = StandardMaterial3D.new()
		door_material.albedo_color = Color(0.329412, 0.211765, 0.121569, 1)
	door_material.emission_enabled = true
	door_material.emission = Color(0.0, 0.0, 0.0, 1.0)
	door_mesh.set_surface_override_material(0, door_material)


func apply_color(color: Color) -> void:
	if door_material != null:
		door_material.albedo_color = color


func toggle(owner: Node) -> void:
	is_open = not is_open
	var target_rotation: float = deg_to_rad(-78.0) if is_open else 0.0
	var tween: Tween = owner.create_tween()
	tween.tween_property(door_hinge, "rotation:y", target_rotation, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func set_highlight(enabled: bool) -> void:
	if is_highlighted == enabled or door_material == null:
		return
	is_highlighted = enabled
	door_material.emission = Color(0.95, 0.68, 0.28, 1.0) if enabled else Color(0.0, 0.0, 0.0, 1.0)
	door_material.emission_energy_multiplier = 0.55 if enabled else 0.0
