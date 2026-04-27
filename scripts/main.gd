extends Node3D

@onready var bottle: Node3D = $Bottle
@onready var camera_rig: Node3D = $CameraRig


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
		return
	if camera_rig.handle_input(event):
		return
	bottle.handle_input(event)
