extends Node3D

@export var drag_rotate_speed := 0.01
@export var idle_rotate_speed := 0.45
@export var vertical_drag_ratio := 0.35
@export var min_tilt_degrees := -20.0
@export var max_tilt_degrees := 20.0

@onready var grab_debug_mesh: MeshInstance3D = $GrabBody/DebugMesh

var _is_dragging := false


func _ready() -> void:
	grab_debug_mesh.visible = false


func _process(delta: float) -> void:
	if not _is_dragging:
		rotate_y(delta * idle_rotate_speed)


func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_is_dragging = true
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_is_dragging = false
	elif event is InputEventMouseMotion and _is_dragging:
		rotate_y(event.relative.x * drag_rotate_speed)
		rotate_x(event.relative.y * drag_rotate_speed * vertical_drag_ratio)
		rotation.x = clamp(rotation.x, deg_to_rad(min_tilt_degrees), deg_to_rad(max_tilt_degrees))
