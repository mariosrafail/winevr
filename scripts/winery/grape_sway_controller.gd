extends Node3D
class_name GrapeSwayController

@export var max_sway_degrees: float = 5.5
@export var spring_stiffness: float = 8.5
@export var spring_damping: float = 4.8
@export var leaf_flutter_degrees: float = 1.9

var _model_root: Node3D
var _leaf: Node3D
var _leaf_base_rotation: Vector3 = Vector3.ZERO
var _base_rotation: Vector3 = Vector3.ZERO
var _angle: Vector2 = Vector2.ZERO
var _angular_velocity: Vector2 = Vector2.ZERO
var _time: float = 0.0


func setup(model_root: Node3D) -> void:
	_model_root = model_root
	_base_rotation = rotation
	_leaf = _find_leaf(model_root)
	if _leaf != null:
		_leaf_base_rotation = _leaf.rotation


func _process(delta: float) -> void:
	if _model_root == null:
		return
	_time += delta

	# Multi-frequency wind target so the motion feels like light air rather than
	# a looping rigid animation. The spring/damping below gives the cluster mass.
	var max_angle: float = deg_to_rad(max_sway_degrees)
	var target_x: float = max_angle * (
		0.52 * sin(_time * 0.57 + 0.35)
		+ 0.21 * sin(_time * 1.31 + 1.7)
		+ 0.08 * sin(_time * 2.7 + 0.4)
	)
	var target_z: float = max_angle * (
		0.44 * sin(_time * 0.49 + 2.0)
		+ 0.24 * sin(_time * 1.17 + 0.15)
		+ 0.07 * sin(_time * 3.1 + 1.2)
	)
	var target := Vector2(target_x, target_z)

	var acceleration: Vector2 = (target - _angle) * spring_stiffness - _angular_velocity * spring_damping
	_angular_velocity += acceleration * delta
	_angle += _angular_velocity * delta
	_angle.x = clampf(_angle.x, -max_angle, max_angle)
	_angle.y = clampf(_angle.y, -max_angle, max_angle)

	rotation = Vector3(
		_base_rotation.x + _angle.x,
		_base_rotation.y + deg_to_rad(0.45) * sin(_time * 0.33),
		_base_rotation.z + _angle.y
	)

	# The leaf is much lighter than the berries, so it reacts a little faster.
	if _leaf != null:
		var flutter: float = deg_to_rad(leaf_flutter_degrees)
		_leaf.rotation = _leaf_base_rotation + Vector3(
			flutter * sin(_time * 2.9 + 0.7),
			flutter * 0.35 * sin(_time * 2.1 + 1.4),
			flutter * 0.55 * sin(_time * 3.7)
		)


func _find_leaf(root: Node) -> Node3D:
	if root == null:
		return null
	if root is Node3D and root.name == "GrapeLeaf_Blade":
		return root as Node3D
	for child in root.get_children():
		var match: Node3D = _find_leaf(child)
		if match != null:
			return match
	return null
