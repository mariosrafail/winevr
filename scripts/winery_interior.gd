extends Node3D
class_name WineryInteriorController

signal door_prompt_changed(prompt: String)
signal door_interacted

@export var move_speed: float = 2.4
@export var look_sensitivity: float = 0.005
@export var min_pitch_degrees: float = -30.0
@export var max_pitch_degrees: float = 30.0

@onready var player_rig: Node3D = $PlayerRig
@onready var camera_pivot: Node3D = $PlayerRig/CameraPivot
@onready var camera: Camera3D = $PlayerRig/CameraPivot/Camera3D
@onready var interaction_ray: RayCast3D = $PlayerRig/CameraPivot/Camera3D/InteractionRay
@onready var held_vial: Vial = $PlayerRig/CameraPivot/Camera3D/HeldVial
@onready var door_hinge: Node3D = $DoorAssembly/DoorHinge

var _controls_enabled: bool = false
var _look_dragging: bool = false
var _door_open: bool = false


func _ready() -> void:
	apply_client_profile(ClientProfileLoader.get_active_client_data())
	_update_door_prompt()


func _physics_process(delta: float) -> void:
	if not _controls_enabled:
		return

	var input_vector := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		input_vector.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_vector.z += 1.0
	if Input.is_key_pressed(KEY_A):
		input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_vector.x += 1.0

	if input_vector.length() > 0.0:
		input_vector = input_vector.normalized()
		var basis := player_rig.global_transform.basis
		var forward := -basis.z
		var right := basis.x
		var movement := (right * input_vector.x + forward * input_vector.z) * move_speed * delta
		player_rig.global_position += Vector3(movement.x, 0.0, movement.z)
		player_rig.position.x = clampf(player_rig.position.x, -2.6, 2.6)
		player_rig.position.z = clampf(player_rig.position.z, -2.8, 2.2)

	_update_door_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if not _controls_enabled:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_look_dragging = event.pressed
			return
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_try_interact_with_door()
			return

	if event is InputEventMouseMotion and _look_dragging:
		player_rig.rotate_y(-event.relative.x * look_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * look_sensitivity)
		camera_pivot.rotation.x = clampf(
			camera_pivot.rotation.x,
			deg_to_rad(min_pitch_degrees),
			deg_to_rad(max_pitch_degrees)
		)


func apply_client_profile(client_data: Dictionary) -> void:
	if client_data.is_empty():
		return

	var vial_settings: Dictionary = client_data.get("vial_settings", {})
	held_vial.liquid_fill_amount = float(vial_settings.get("liquid_fill_amount", held_vial.liquid_fill_amount))
	held_vial.liquid_color = _parse_color(vial_settings.get("liquid_color", held_vial.liquid_color))
	held_vial.cap_color = _parse_color(vial_settings.get("cap_color", held_vial.cap_color))
	held_vial.rebuild_vial()


func set_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled
	if not enabled:
		_look_dragging = false


func set_camera_active(active: bool) -> void:
	camera.current = active


func reset_view() -> void:
	player_rig.position = Vector3(0.0, 0.0, 1.55)
	player_rig.rotation = Vector3.ZERO
	camera_pivot.rotation = Vector3.ZERO


func _try_interact_with_door() -> void:
	if not interaction_ray.is_colliding():
		return

	var collider: Object = interaction_ray.get_collider()
	if collider is Node and (collider as Node).is_in_group("winery_door"):
		_toggle_door()
		door_interacted.emit()


func _toggle_door() -> void:
	_door_open = not _door_open
	var target_rotation: float = deg_to_rad(-78.0) if _door_open else 0.0
	var tween := create_tween()
	tween.tween_property(door_hinge, "rotation:y", target_rotation, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _update_door_prompt() -> void:
	door_prompt_changed.emit("")


func _parse_color(value, default_color: Color = Color.WHITE) -> Color:
	if value is Color:
		return value
	if value is String:
		var color_text: String = value
		if color_text.is_valid_html_color():
			return Color.from_string(color_text, default_color)
	return default_color
