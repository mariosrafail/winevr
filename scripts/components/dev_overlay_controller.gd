extends Node
class_name DevOverlayController

var panel: PanelContainer
var label: Label
var canvas_layer: CanvasLayer
var visible_enabled: bool = false
var current_client_id: String = ""
var current_state: String = ""
var current_step: String = ""
var active_target: String = ""
var input_hint: String = "Mouse/touch. Dev: R reset, Esc QR, F3 overlay."


func setup(parent_canvas_layer: CanvasLayer) -> void:
	canvas_layer = parent_canvas_layer
	panel = PanelContainer.new()
	panel.name = "DevOverlay"
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 95
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	canvas_layer.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	label = Label.new()
	label.label_settings = _make_label_settings()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(label)
	_refresh_text()


func layout(viewport_size: Vector2, margin: float) -> void:
	panel.position = Vector2(margin, margin)
	panel.size = Vector2(minf(360.0, viewport_size.x - margin * 2.0), 142.0)


func toggle() -> void:
	visible_enabled = not visible_enabled
	panel.visible = visible_enabled
	if visible_enabled:
		canvas_layer.move_child(panel, canvas_layer.get_child_count() - 1)
		_refresh_text()


func set_context(client_id: String, state_name: String, step_name: String, target_type: String, target_id: String) -> void:
	current_client_id = client_id
	current_state = state_name
	current_step = step_name
	if target_type.is_empty():
		active_target = ""
	else:
		active_target = "%s:%s" % [target_type, target_id]
	if visible_enabled:
		_refresh_text()


func _process(_delta: float) -> void:
	if visible_enabled:
		_refresh_text()


func _refresh_text() -> void:
	label.text = "Client: %s\nState: %s\nStep: %s\nTarget: %s\nFPS: %s\nInput: %s" % [
		current_client_id if not current_client_id.is_empty() else "<none>",
		current_state if not current_state.is_empty() else "<unknown>",
		current_step if not current_step.is_empty() else "<none>",
		active_target if not active_target.is_empty() else "<none>",
		Engine.get_frames_per_second(),
		input_hint
	]


func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.024, 0.03, 0.82)
	style.border_color = Color(0.35, 0.78, 1.0, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style


func _make_label_settings() -> LabelSettings:
	var settings: LabelSettings = LabelSettings.new()
	settings.font_size = 12
	settings.font_color = Color(0.86, 0.92, 0.96, 1.0)
	return settings
