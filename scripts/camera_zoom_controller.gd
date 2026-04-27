extends Node3D

@export var zoom_step := 0.2
@export var min_camera_z := 1.6
@export var max_camera_z := 4.4

@onready var camera: Camera3D = $Camera3D


func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.position.z = maxf(min_camera_z, camera.position.z - zoom_step)
			return true
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.position.z = minf(max_camera_z, camera.position.z + zoom_step)
			return true
	return false
