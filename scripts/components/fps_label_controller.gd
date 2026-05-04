extends Label
class_name FPSLabelController

@export var refresh_interval: float = 0.5

var _elapsed: float = 0.0


func _ready() -> void:
	visible = OS.is_debug_build()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if label_settings == null:
		label_settings = LabelSettings.new()
	label_settings.font_size = 18
	label_settings.font_color = Color(0.96, 0.97, 0.98, 1.0)
	label_settings.outline_size = 4
	label_settings.outline_color = Color(0.04, 0.04, 0.04, 0.9)
	_update_fps_text()


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	if _elapsed < refresh_interval:
		return
	_elapsed = 0.0
	_update_fps_text()


func _update_fps_text() -> void:
	text = "FPS: " + str(int(round(Engine.get_frames_per_second())))
