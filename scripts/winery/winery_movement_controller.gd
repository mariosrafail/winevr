extends RefCounted
class_name WineryMovementController

var player_rig: Node3D
var camera_pivot: Node3D
var move_speed: float = 2.4
var look_sensitivity: float = 0.005
var min_pitch_degrees: float = -30.0
var max_pitch_degrees: float = 30.0
var controls_enabled: bool = false
var look_dragging: bool = false
var exploration_mode: bool = false
var mobile_move_vector: Vector2 = Vector2.ZERO
var camera_start_position: Vector3 = Vector3(0.0, 0.0, 1.55)
var camera_start_rotation: Vector3 = Vector3.ZERO


func setup(rig: Node3D, pivot: Node3D, speed: float, sensitivity: float, min_pitch: float, max_pitch: float) -> void:
	player_rig = rig
	camera_pivot = pivot
	move_speed = speed
	look_sensitivity = sensitivity
	min_pitch_degrees = min_pitch
	max_pitch_degrees = max_pitch


func physics_update(delta: float) -> bool:
	if not controls_enabled:
		return false

	var input_vector: Vector3 = Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		input_vector.z += 1.0
	if Input.is_key_pressed(KEY_S):
		input_vector.z -= 1.0
	if Input.is_key_pressed(KEY_A):
		input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_vector.x += 1.0
	input_vector.x += mobile_move_vector.x
	input_vector.z += mobile_move_vector.y

	if input_vector.length() <= 0.0:
		return false

	input_vector = input_vector.normalized()
	var basis: Basis = player_rig.global_transform.basis
	var forward: Vector3 = -basis.z
	var right: Vector3 = basis.x
	var movement: Vector3 = (right * input_vector.x + forward * input_vector.z) * move_speed * delta
	player_rig.global_position += Vector3(movement.x, 0.0, movement.z)
	player_rig.position.x = clampf(player_rig.position.x, -2.6, 2.6)
	player_rig.position.z = clampf(player_rig.position.z, -2.8, 2.2)
	return true


func handle_input(event: InputEvent) -> bool:
	if not controls_enabled:
		return false

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if exploration_mode:
			return true
		look_dragging = event.pressed
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if look_dragging else Input.MOUSE_MODE_VISIBLE
		return true

	if event is InputEventMouseMotion and exploration_mode:
		apply_look_drag(event.relative)
		return true

	if event is InputEventMouseMotion and look_dragging:
		apply_look_drag(event.relative)
		return true

	return false


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if not enabled:
		look_dragging = false
		exploration_mode = false
		mobile_move_vector = Vector2.ZERO
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func set_exploration_mode(enabled: bool) -> void:
	exploration_mode = enabled
	look_dragging = false


func set_mobile_move_axis(axis: String, pressed: bool) -> void:
	var amount: float = 1.0 if pressed else 0.0
	match axis:
		"forward":
			mobile_move_vector.y = amount
		"back":
			mobile_move_vector.y = -amount
		"left":
			mobile_move_vector.x = -amount
		"right":
			mobile_move_vector.x = amount


func apply_look_drag(relative_motion: Vector2) -> void:
	if not controls_enabled:
		return
	player_rig.rotate_y(-relative_motion.x * look_sensitivity)
	camera_pivot.rotate_x(-relative_motion.y * look_sensitivity)
	camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))


func set_camera_start(position: Vector3, rotation: Vector3) -> void:
	camera_start_position = position
	camera_start_rotation = rotation


func reset_view() -> void:
	player_rig.position = camera_start_position
	player_rig.rotation = camera_start_rotation
	camera_pivot.rotation = Vector3.ZERO
