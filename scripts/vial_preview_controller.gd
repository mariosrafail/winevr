extends Node3D

@export var drag_rotate_speed: float = 0.01
@export var idle_rotate_speed: float = 0.45
@export var vertical_drag_ratio: float = 0.35
@export var min_tilt_degrees: float = -20.0
@export var max_tilt_degrees: float = 20.0

@export var zoom_step: float = 0.05
@export var min_camera_z: float = 0.28
@export var max_camera_z: float = 0.95

@onready var vial: Node3D = $Vial
@onready var camera: Camera3D = $Camera3D

var _is_dragging: bool = false


func _process(delta: float) -> void:
	if not _is_dragging:
		vial.rotate_y(delta * idle_rotate_speed)


func _unhandled_input(event: InputEvent) -> void:
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
		vial.rotate_y(event.relative.x * drag_rotate_speed)
		vial.rotate_x(event.relative.y * drag_rotate_speed * vertical_drag_ratio)
		vial.rotation.x = clamp(vial.rotation.x, deg_to_rad(min_tilt_degrees), deg_to_rad(max_tilt_degrees))