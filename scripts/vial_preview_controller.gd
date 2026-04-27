extends Node3D
class_name VialPreviewController

@export var drag_rotate_speed: float = 0.01
@export var idle_rotate_speed: float = 0.45
@export var vertical_drag_ratio: float = 0.35
@export var min_tilt_degrees: float = -20.0
@export var max_tilt_degrees: float = 20.0

@export var zoom_step: float = 0.05
@export var min_camera_z: float = 0.28
@export var max_camera_z: float = 0.95

@onready var vial: Vial = $Vial
@onready var camera: Camera3D = $Camera3D

var _is_dragging: bool = false
var _interaction_enabled: bool = true
var _idle_rotation_paused: bool = false
var _touch_points: Dictionary = {}
var _last_pinch_distance: float = 0.0


func _ready() -> void:
	apply_client_profile(ClientProfileLoader.get_active_client_data())


func _process(delta: float) -> void:
	if not _is_dragging and not _idle_rotation_paused:
		vial.rotate_y(delta * idle_rotate_speed)


func _unhandled_input(event: InputEvent) -> void:
	if not _interaction_enabled:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_points[event.index] = event.position
		else:
			_touch_points.erase(event.index)
			if _touch_points.size() < 2:
				_last_pinch_distance = 0.0
		return

	if event is InputEventScreenDrag:
		_touch_points[event.index] = event.position
		if _touch_points.size() == 1:
			_rotate_vial(event.relative)
		elif _touch_points.size() >= 2:
			_update_pinch_zoom()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = event.pressed
			return
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.position.z = maxf(min_camera_z, camera.position.z - zoom_step)
			return
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.position.z = minf(max_camera_z, camera.position.z + zoom_step)
			return

	if event is InputEventMouseMotion and _is_dragging:
		_rotate_vial(event.relative)


func apply_client_profile(client_data: Dictionary) -> void:
	if client_data.is_empty():
		return

	var vial_settings: Dictionary = client_data.get("vial_settings", {})
	vial.liquid_fill_amount = float(vial_settings.get("liquid_fill_amount", vial.liquid_fill_amount))
	vial.liquid_color = _parse_color(vial_settings.get("liquid_color", vial.liquid_color))
	vial.cap_color = _parse_color(vial_settings.get("cap_color", vial.cap_color))
	vial.rebuild_vial()


func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	if not enabled:
		_is_dragging = false
		_touch_points.clear()
		_last_pinch_distance = 0.0


func set_camera_active(active: bool) -> void:
	camera.current = active


func set_idle_rotation_paused(paused: bool) -> void:
	_idle_rotation_paused = paused


func reset_view() -> void:
	vial.rotation = Vector3.ZERO
	camera.position.z = 0.62


func zoom_in() -> void:
	camera.position.z = maxf(min_camera_z, camera.position.z - zoom_step)


func zoom_out() -> void:
	camera.position.z = minf(max_camera_z, camera.position.z + zoom_step)


func _rotate_vial(relative_motion: Vector2) -> void:
	vial.rotate_y(relative_motion.x * drag_rotate_speed)
	vial.rotate_x(relative_motion.y * drag_rotate_speed * vertical_drag_ratio)
	vial.rotation.x = clampf(vial.rotation.x, deg_to_rad(min_tilt_degrees), deg_to_rad(max_tilt_degrees))


func _update_pinch_zoom() -> void:
	var points: Array = _touch_points.values()
	if points.size() < 2:
		return

	var distance: float = (points[0] as Vector2).distance_to(points[1] as Vector2)
	if _last_pinch_distance > 0.0:
		var delta_distance: float = distance - _last_pinch_distance
		camera.position.z = clampf(camera.position.z - delta_distance * 0.0012, min_camera_z, max_camera_z)
	_last_pinch_distance = distance


func _parse_color(value, default_color: Color = Color.WHITE) -> Color:
	if value is Color:
		return value
	if value is String:
		var color_text: String = value
		if color_text.is_valid_html_color():
			return Color.from_string(color_text, default_color)
	return default_color
