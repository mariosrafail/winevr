extends Node
class_name NarrativePanelController

signal show_target_requested(current_step: Dictionary)

var panel: PanelContainer
var title_label: Label
var target_label: Label
var text_label: RichTextLabel
var hint_label: Label
var progress_label: Label
var next_button: Button
var show_me_button: Button
var show_button: Button
var collapsed: bool = false
var canvas_layer: CanvasLayer


func setup(parent_canvas_layer: CanvasLayer) -> void:
	canvas_layer = parent_canvas_layer
	_build_panel()
	NarrativeManager.narrative_changed.connect(_on_narrative_changed)


func apply_state(state: int) -> void:
	_update_visibility(state != ExperienceManager.ExperienceState.QR_SCAN)


func layout(viewport_size: Vector2, margin: float) -> void:
	var width: float = minf(380.0, viewport_size.x - margin * 2.0)
	var height: float = minf(190.0, viewport_size.y * 0.32)
	panel.position = Vector2(viewport_size.x - width - margin, viewport_size.y - height - margin)
	panel.size = Vector2(width, height)
	show_button.position = Vector2(viewport_size.x - 104.0 - margin, margin)
	show_button.size = Vector2(104.0, 44.0)


func refresh() -> void:
	_on_narrative_changed(NarrativeManager.get_current_step(), 0, NarrativeManager.narrative_steps.size())


func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.name = "NarrativePanel"
	panel.visible = false
	panel.z_index = 40
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	canvas_layer.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 2)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	panel.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)

	progress_label = Label.new()
	progress_label.text = "0/0"
	progress_label.label_settings = _make_label_settings(13, Color(0.92, 0.76, 0.45, 1.0))
	header.add_child(progress_label)

	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.label_settings = _make_label_settings(16, Color(0.976, 0.968, 0.941, 1.0))
	header.add_child(title_label)

	var hide_button: Button = Button.new()
	hide_button.text = "Hide"
	hide_button.custom_minimum_size = Vector2(62.0, 38.0)
	hide_button.pressed.connect(_set_collapsed.bind(true))
	header.add_child(hide_button)

	target_label = Label.new()
	target_label.label_settings = _make_label_settings(12, Color(0.92, 0.76, 0.45, 0.9))
	box.add_child(target_label)

	text_label = RichTextLabel.new()
	text_label.fit_content = true
	text_label.scroll_active = false
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(0.0, 66.0)
	box.add_child(text_label)

	hint_label = Label.new()
	hint_label.visible = false
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.label_settings = _make_label_settings(13, Color(0.35, 0.78, 1.0, 1.0))
	box.add_child(hint_label)

	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)

	show_me_button = Button.new()
	show_me_button.text = "Show me"
	show_me_button.custom_minimum_size = Vector2(0.0, 44.0)
	show_me_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	show_me_button.pressed.connect(_on_show_me_pressed)
	actions.add_child(show_me_button)

	next_button = Button.new()
	next_button.text = "Next"
	next_button.custom_minimum_size = Vector2(0.0, 44.0)
	next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_button.pressed.connect(_on_next_pressed)
	actions.add_child(next_button)

	show_button = Button.new()
	show_button.name = "NarrativeShowButton"
	show_button.text = "Guide"
	show_button.visible = false
	show_button.z_index = 50
	show_button.mouse_filter = Control.MOUSE_FILTER_STOP
	show_button.custom_minimum_size = Vector2(104.0, 44.0)
	show_button.pressed.connect(_set_collapsed.bind(false))
	canvas_layer.add_child(show_button)


func _on_narrative_changed(current_step: Dictionary, _current_index: int, _total_steps: int) -> void:
	if current_step.is_empty():
		panel.visible = false
		show_button.visible = false
		return
	title_label.text = str(current_step.get("title", "Guided Step"))
	target_label.text = _format_target_type(str(current_step.get("target_type", "free")))
	text_label.text = str(current_step.get("text", ""))
	progress_label.text = NarrativeManager.get_progress_text()
	next_button.disabled = not NarrativeManager.can_advance_current_step()
	_update_visibility(ExperienceManager.current_state != ExperienceManager.ExperienceState.QR_SCAN)


func _set_collapsed(value: bool) -> void:
	collapsed = value
	_update_visibility(ExperienceManager.current_state != ExperienceManager.ExperienceState.QR_SCAN)
	_raise_to_front()


func _update_visibility(can_show: bool) -> void:
	var has_step: bool = not NarrativeManager.get_current_step().is_empty()
	panel.visible = has_step and can_show and not collapsed
	show_button.visible = has_step and can_show and collapsed
	if panel.visible or show_button.visible:
		_raise_to_front()


func _on_next_pressed() -> void:
	NarrativeManager.next_step()


func show_hint(message: String) -> void:
	hint_label.text = message
	hint_label.visible = not message.strip_edges().is_empty()
	_raise_to_front()


func clear_hint() -> void:
	show_hint("")


func _on_show_me_pressed() -> void:
	show_target_requested.emit(NarrativeManager.get_current_step())


func _raise_to_front() -> void:
	if panel.get_parent() == canvas_layer:
		canvas_layer.move_child(panel, canvas_layer.get_child_count() - 1)
	if show_button.get_parent() == canvas_layer:
		canvas_layer.move_child(show_button, canvas_layer.get_child_count() - 1)


func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0352941, 0.0392157, 0.0470588, 0.9)
	style.border_color = Color(0.92, 0.76, 0.45, 0.22)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(20.0)
	return style


func _make_label_settings(font_size: int, font_color: Color) -> LabelSettings:
	var settings: LabelSettings = LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = font_color
	return settings


func _format_target_type(target_type: String) -> String:
	match target_type:
		"hotspot":
			return "Hotspot"
		"zone":
			return "Cellar Point"
		"prop":
			return "Winery Object"
		"door":
			return "Cellar Door"
		_:
			return "Free Step"
