extends RefCounted
class_name WineryMovementController
signal footstep(strength: float)
signal walking_stopped

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
var bounds_min: Vector2 = Vector2(-2.6, -2.8)
var bounds_max: Vector2 = Vector2(2.6, 2.2)
var _touch_directions: Dictionary = {}
var camera_start_position: Vector3 = Vector3(0.0, 0.0, 1.55)
var camera_start_rotation: Vector3 = Vector3.ZERO
var natural_walk: bool = false
var _walk_velocity: Vector3 = Vector3.ZERO
var _pending_look: Vector2 = Vector2.ZERO
var _eye_rest: Vector3
var _step_phase: float = 0.0
var _step_offset: Vector3 = Vector3.ZERO
var _walking: bool = false
var _until_step: float = 0.18

func enable_natural_walk() -> void:
	natural_walk = true
	move_speed = 1.65
	look_sensitivity = 0.0026
	_eye_rest = camera_pivot.position
	reset_motion()

func reset_motion() -> void:
	_stop_footsteps()
	_walk_velocity = Vector3.ZERO
	_pending_look = Vector2.ZERO
	_step_offset = Vector3.ZERO
	_step_phase = 0.0
	if natural_walk:
		camera_pivot.position = _eye_rest
	if player_rig is CharacterBody3D:
		(player_rig as CharacterBody3D).velocity = Vector3.ZERO

func _stop_footsteps() -> void:
	if _walking:
		walking_stopped.emit()
	_walking = false
	_until_step = 0.18

func update_view(delta: float, active: bool) -> void:
	if not natural_walk:
		return
	if not active:
		reset_motion()
		return
	# Consume mouse motion at render frequency for a short, frame-rate independent settle.
	var look: Vector2 = _pending_look * (1.0 - exp(-28.0 * delta))
	_pending_look -= look
	player_rig.rotate_y(-look.x * look_sensitivity)
	camera_pivot.rotation.x = clampf(camera_pivot.rotation.x - look.y * look_sensitivity, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))
	camera_pivot.position = camera_pivot.position.lerp(_eye_rest + _step_offset, 1.0 - exp(-16.0 * delta))

func _natural_walk_update(input_vector: Vector3, delta: float) -> bool:
	input_vector = input_vector.limit_length(1.0)
	var basis: Basis = player_rig.global_basis
	var pace: float = 0.75 if input_vector.z < 0.0 else 1.0
	var desired: Vector3 = (basis.x * input_vector.x * 0.88 - basis.z * input_vector.z) * move_speed * pace
	desired.y = 0.0
	_walk_velocity = _walk_velocity.move_toward(desired, (5.5 if not input_vector.is_zero_approx() else 8.0) * delta)
	var before: Vector3 = player_rig.global_position
	if player_rig is CharacterBody3D:
		var body: CharacterBody3D = player_rig as CharacterBody3D
		body.velocity = _walk_velocity
		body.move_and_slide()
		_walk_velocity = body.velocity
	else:
		player_rig.global_position += _walk_velocity * delta
	var unclamped: Vector3 = player_rig.position
	player_rig.position.x = clampf(unclamped.x, bounds_min.x, bounds_max.x)
	player_rig.position.z = clampf(unclamped.z, bounds_min.y, bounds_max.y)
	if not is_equal_approx(unclamped.x, player_rig.position.x):
		_walk_velocity.x = 0.0
	if not is_equal_approx(unclamped.z, player_rig.position.z):
		_walk_velocity.z = 0.0
	var travelled: float = before.distance_to(player_rig.global_position)
	var effort: float = clampf(travelled / maxf(delta * move_speed, 0.0001), 0.0, 1.0)
	if travelled > 0.0001 and not input_vector.is_zero_approx():
		_walking = true
		_until_step -= travelled
		if _until_step <= 0.0:
			footstep.emit(effort)
			_until_step += 0.825
	else:
		_stop_footsteps()
	# Distance drives the gait: there are no footsteps while pushing against a wall.
	_step_phase = fmod(_step_phase + travelled * TAU / 1.65, TAU)
	_step_offset = Vector3(sin(_step_phase) * 0.006, sin(_step_phase * 2.0) * 0.012, 0.0) * effort
	return travelled > 0.00001


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
	if natural_walk:
		return _natural_walk_update(input_vector, delta)

	if input_vector.length() <= 0.0:
		return false

	input_vector = input_vector.normalized()
	var basis: Basis = player_rig.global_transform.basis
	var forward: Vector3 = -basis.z
	var right: Vector3 = basis.x
	var movement: Vector3 = (right * input_vector.x + forward * input_vector.z) * move_speed * delta
	if player_rig is CharacterBody3D:
		var body: CharacterBody3D = player_rig as CharacterBody3D
		body.velocity = Vector3(movement.x, 0.0, movement.z) / maxf(delta, 0.0001)
		body.move_and_slide()
	else:
		player_rig.global_position += Vector3(movement.x, 0.0, movement.z)
	player_rig.position.x = clampf(player_rig.position.x, bounds_min.x, bounds_max.x)
	player_rig.position.z = clampf(player_rig.position.z, bounds_min.y, bounds_max.y)
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

	if event is InputEventMouseMotion and exploration_mode and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_look_drag(event.relative)
		return true

	if event is InputEventMouseMotion and look_dragging:
		apply_look_drag(event.relative)
		return true

	return false


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if not enabled:
		if natural_walk:
			reset_motion()
		look_dragging = false
		exploration_mode = false
		mobile_move_vector = Vector2.ZERO
		_touch_directions.clear()
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func set_exploration_mode(enabled: bool) -> void:
	exploration_mode = enabled
	look_dragging = false


func configure_bounds(minimum: Vector2, maximum: Vector2) -> void:
	bounds_min = minimum
	bounds_max = maximum


func set_mobile_move_axis(axis: String, pressed: bool) -> void:
	_touch_directions[axis] = pressed
	mobile_move_vector = Vector2(
		float(_touch_directions.get("right", false)) - float(_touch_directions.get("left", false)),
		float(_touch_directions.get("forward", false)) - float(_touch_directions.get("back", false))
	)


func apply_look_drag(relative_motion: Vector2) -> void:
	if not controls_enabled:
		return
	if natural_walk:
		_pending_look += relative_motion
		return
	player_rig.rotate_y(-relative_motion.x * look_sensitivity)
	camera_pivot.rotate_x(-relative_motion.y * look_sensitivity)
	camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))


func set_camera_start(position: Vector3, rotation: Vector3) -> void:
	camera_start_position = position
	camera_start_rotation = rotation


func reset_view() -> void:
	if natural_walk:
		reset_motion()
	player_rig.position = camera_start_position
	player_rig.rotation = camera_start_rotation
	camera_pivot.rotation = Vector3.ZERO
