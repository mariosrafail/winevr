extends Node3D

@onready var bottle: Node3D = $Bottle
@onready var grab_debug_mesh: MeshInstance3D = $Bottle/GrabBody/DebugMesh
@onready var camera: Camera3D = $CameraRig/Camera3D

const DRAG_ROTATE_SPEED := 0.01
const IDLE_ROTATE_SPEED := 0.45
const ZOOM_STEP := 0.2
const MIN_CAMERA_Z := 1.6
const MAX_CAMERA_Z := 4.4

var _is_dragging_bottle := false


func _ready() -> void:
	grab_debug_mesh.visible = false


func _process(delta: float) -> void:
	if not _is_dragging_bottle:
		bottle.rotate_y(delta * IDLE_ROTATE_SPEED)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera.position.z = maxf(MIN_CAMERA_Z, camera.position.z - ZOOM_STEP)
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera.position.z = minf(MAX_CAMERA_Z, camera.position.z + ZOOM_STEP)
			return
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_is_dragging_bottle = true
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_is_dragging_bottle = false
	elif event is InputEventMouseMotion and _is_dragging_bottle:
		bottle.rotate_y(event.relative.x * DRAG_ROTATE_SPEED)
		bottle.rotate_x(event.relative.y * DRAG_ROTATE_SPEED * 0.35)
		bottle.rotation.x = clamp(bottle.rotation.x, deg_to_rad(-20.0), deg_to_rad(20.0))
