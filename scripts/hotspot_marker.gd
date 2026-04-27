extends Button
class_name HotspotMarker

signal hotspot_selected(hotspot_data: Dictionary)

@export var pulse_speed: float = 2.4
@export var marker_color: Color = Color(0.95, 0.76, 0.42, 1.0)
@export var viewed_color: Color = Color(0.63, 0.86, 0.72, 1.0)
@export var active_target_color: Color = Color(0.35, 0.78, 1.0, 1.0)

var hotspot_data: Dictionary = {}
var viewed: bool = false:
	set(value):
		_viewed = value
		queue_redraw()
	get:
		return _viewed

var _pulse_time: float = 0.0
var _title_label: Label
var _viewed: bool = false
var _active_target: bool = false
var active_target: bool = false:
	set(value):
		_active_target = value
		queue_redraw()
	get:
		return _active_target


func _ready() -> void:
	text = ""
	flat = true
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(48.0, 48.0)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	_title_label = Label.new()
	_title_label.visible = false
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88, 1.0))
	_title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
	_title_label.add_theme_constant_override("shadow_offset_x", 1)
	_title_label.add_theme_constant_override("shadow_offset_y", 1)
	_title_label.text = str(hotspot_data.get("title", ""))
	add_child(_title_label)

	mouse_entered.connect(_show_title)
	mouse_exited.connect(_hide_title)
	focus_entered.connect(_show_title)
	focus_exited.connect(_hide_title)
	pressed.connect(_emit_selected)


func _process(delta: float) -> void:
	_pulse_time += delta * pulse_speed
	queue_redraw()


func configure(data: Dictionary, already_viewed: bool) -> void:
	hotspot_data = data
	viewed = already_viewed
	if _title_label != null:
		_title_label.text = str(hotspot_data.get("title", ""))


func set_active_target(enabled: bool) -> void:
	active_target = enabled


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var color: Color = active_target_color if active_target else viewed_color if viewed else marker_color
	var pulse: float = (sin(_pulse_time) + 1.0) * 0.5
	var ring_radius: float = lerpf(12.0, 27.0 if active_target else 21.0, pulse)
	var ring_alpha: float = lerpf(0.7 if active_target else 0.48, 0.12 if active_target else 0.08, pulse)

	draw_circle(center, ring_radius, Color(color.r, color.g, color.b, ring_alpha))
	draw_arc(center, 17.0 if active_target else 15.0, 0.0, TAU, 64, Color(color.r, color.g, color.b, 0.96 if active_target else 0.86), 3.0 if active_target else 2.0)
	draw_circle(center, 5.0, color)
	draw_circle(center, 2.0, Color(1.0, 0.98, 0.9, 1.0))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _title_label != null:
		_title_label.position = Vector2(-70.0, -30.0)
		_title_label.size = Vector2(188.0, 24.0)


func _show_title() -> void:
	_title_label.visible = true


func _hide_title() -> void:
	_title_label.visible = false


func _emit_selected() -> void:
	hotspot_selected.emit(hotspot_data)
