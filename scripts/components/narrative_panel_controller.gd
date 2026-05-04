extends Node
class_name NarrativePanelController

signal show_target_requested(current_step: Dictionary)
signal restart_requested
signal layout_refresh_requested(reason: String)

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
var completion_active: bool = false
var completion_overlay: Control
var completion_card: PanelContainer
var completion_title: Label
var completion_text: RichTextLabel
var restart_button: Button
var text_scroll: ScrollContainer


func setup(parent_canvas_layer: CanvasLayer) -> void:
	canvas_layer = parent_canvas_layer
	_build_panel()
	NarrativeManager.narrative_changed.connect(_on_narrative_changed)


func apply_state(state: int) -> void:
	_update_visibility(state != ExperienceManager.ExperienceState.QR_SCAN)


func layout(viewport_size: Vector2, margin: float) -> void:
	var min_height: float = 190.0
	var max_height: float = maxf(min_height, viewport_size.y * 0.5)
	var width: float = clampf(minf(420.0, viewport_size.x - margin * 2.0), 220.0, maxf(220.0, viewport_size.x - margin * 2.0))
	var height: float = clampf(minf(260.0, max_height), min_height, maxf(min_height, viewport_size.y - margin * 2.0))
	var panel_position: Vector2 = Vector2((viewport_size.x - width) * 0.5, viewport_size.y - height - margin)
	if ExperienceManager.current_state == ExperienceManager.ExperienceState.VIAL_INSPECTION and viewport_size.x >= 760.0:
		panel_position.y = margin
	if viewport_size.x < 760.0:
		width = clampf(minf(390.0, viewport_size.x - margin * 2.0), 220.0, maxf(220.0, viewport_size.x - margin * 2.0))
		height = clampf(minf(max_height, viewport_size.y * 0.5), min_height, maxf(min_height, viewport_size.y - margin * 2.0))
		panel_position = Vector2((viewport_size.x - width) * 0.5, margin)
	panel_position.y = clampf(panel_position.y, margin, maxf(margin, viewport_size.y - height - margin))
	panel.position = panel_position
	panel.size = Vector2(width, height)
	var reserved_bottom: float = 118.0
	var text_max: float = clampf(height - reserved_bottom, 84.0, maxf(84.0, max_height - reserved_bottom))
	text_scroll.custom_minimum_size.y = text_max
	show_button.position = Vector2((viewport_size.x - 104.0) * 0.5, clampf(margin, 4.0, maxf(4.0, viewport_size.y - 44.0 - 4.0)))
	show_button.size = Vector2(104.0, 44.0)

	var completion_width: float = clampf(minf(460.0, viewport_size.x - margin * 2.0), 200.0, maxf(200.0, viewport_size.x - margin * 2.0))
	var completion_height: float = clampf(minf(285.0, viewport_size.y - margin * 2.0), 160.0, maxf(160.0, viewport_size.y - margin * 2.0))
	completion_card.position = (viewport_size - Vector2(completion_width, completion_height)) * 0.5
	completion_card.size = Vector2(completion_width, completion_height)


func refresh() -> void:
	_on_narrative_changed(NarrativeManager.get_current_step(), NarrativeManager.current_step_index, NarrativeManager.narrative_steps.size())


func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.name = "NarrativePanel"
	panel.visible = false
	panel.z_index = 40
	ResponsiveLayoutController.apply_premium_panel_style(panel)
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
	PremiumUIStyles.apply_panel_chrome_to_vbox(box)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)

	progress_label = Label.new()
	progress_label.text = "0/0"
	progress_label.label_settings = _make_label_settings(13, PremiumUIStyles.GOLD_ACCENT)
	header.add_child(progress_label)

	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.label_settings = _make_label_settings(16, Color(0.976, 0.968, 0.941, 1.0))
	header.add_child(title_label)

	var hide_button: Button = Button.new()
	hide_button.text = "Minimize"
	hide_button.custom_minimum_size = Vector2(62.0, 38.0)
	PremiumUIStyles.apply_gold_outline_button(hide_button)
	hide_button.pressed.connect(_set_collapsed.bind(true))
	header.add_child(hide_button)

	target_label = Label.new()
	target_label.label_settings = _make_label_settings(12, Color(PremiumUIStyles.GOLD_ACCENT.r, PremiumUIStyles.GOLD_ACCENT.g, PremiumUIStyles.GOLD_ACCENT.b, 0.9))
	box.add_child(target_label)

	text_scroll = ScrollContainer.new()
	text_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	text_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	box.add_child(text_scroll)

	var content_box: VBoxContainer = VBoxContainer.new()
	content_box.name = "ContentVBox"
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_scroll.add_child(content_box)

	text_label = RichTextLabel.new()
	text_label.fit_content = true
	text_label.scroll_active = false
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(0.0, 84.0)
	content_box.add_child(text_label)

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
	PremiumUIStyles.apply_gold_outline_button(show_me_button)
	show_me_button.pressed.connect(_on_show_me_pressed)
	actions.add_child(show_me_button)

	next_button = Button.new()
	next_button.text = "Continue"
	next_button.custom_minimum_size = Vector2(0.0, 44.0)
	next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PremiumUIStyles.apply_gold_outline_button(next_button)
	next_button.pressed.connect(_on_next_pressed)
	actions.add_child(next_button)

	show_button = Button.new()
	show_button.name = "NarrativeShowButton"
	show_button.text = "Guide"
	show_button.visible = false
	show_button.z_index = 50
	show_button.mouse_filter = Control.MOUSE_FILTER_STOP
	show_button.custom_minimum_size = Vector2(104.0, 44.0)
	PremiumUIStyles.apply_gold_outline_button(show_button)
	show_button.pressed.connect(_set_collapsed.bind(false))
	canvas_layer.add_child(show_button)

	_build_completion_modal()


func _build_completion_modal() -> void:
	completion_overlay = Control.new()
	completion_overlay.name = "CompletionOverlay"
	completion_overlay.visible = false
	completion_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	completion_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	completion_overlay.z_index = 80
	canvas_layer.add_child(completion_overlay)

	var dimmer: ColorRect = ColorRect.new()
	dimmer.color = Color(0.0, 0.0, 0.0, 0.68)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	completion_overlay.add_child(dimmer)

	completion_card = PanelContainer.new()
	completion_card.add_theme_stylebox_override("panel", _make_completion_style())
	completion_overlay.add_child(completion_card)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	completion_card.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	PremiumUIStyles.apply_panel_chrome_to_vbox(box)

	completion_title = Label.new()
	completion_title.text = "Tasting Complete"
	completion_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	completion_title.label_settings = _make_label_settings(28, Color(0.976, 0.968, 0.941, 1.0))
	box.add_child(completion_title)

	completion_text = RichTextLabel.new()
	completion_text.text = "You discovered the wine story, its essential tasting notes, and the winery details that shape this guided tasting."
	completion_text.fit_content = true
	completion_text.scroll_active = false
	completion_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	completion_text.custom_minimum_size = Vector2(0.0, 96.0)
	completion_text.add_theme_color_override("default_color", Color(0.86, 0.86, 0.82, 1.0))
	box.add_child(completion_text)

	restart_button = Button.new()
	restart_button.text = "Restart Experience"
	restart_button.custom_minimum_size = Vector2(0.0, 48.0)
	PremiumUIStyles.apply_gold_outline_button(restart_button)
	restart_button.pressed.connect(_on_restart_pressed)
	box.add_child(restart_button)


func _on_narrative_changed(current_step: Dictionary, _current_index: int, _total_steps: int) -> void:
	if current_step.is_empty():
		completion_active = _total_steps > 0 and _current_index >= _total_steps
		if completion_active:
			_show_completion_modal()
		else:
			panel.visible = false
			show_button.visible = false
			_hide_completion_modal()
		return
	completion_active = false
	_hide_completion_modal()
	title_label.text = str(current_step.get("title", "Tasting Step"))
	target_label.text = _format_target_type(str(current_step.get("target_type", "free")))
	text_label.text = str(current_step.get("text", ""))
	progress_label.text = NarrativeManager.get_progress_text()
	show_me_button.visible = true
	next_button.visible = true
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
	completion_overlay.visible = completion_active and can_show
	if panel.visible or show_button.visible or completion_overlay.visible:
		layout_refresh_requested.emit("panel opened")
		_raise_to_front()


func _on_next_pressed() -> void:
	NarrativeManager.next_step()


func show_hint(message: String) -> void:
	var is_visible: bool = not message.strip_edges().is_empty()
	if hint_label.text == message and hint_label.visible == is_visible:
		return
	hint_label.text = message
	hint_label.visible = is_visible
	if is_visible:
		_raise_to_front()


func clear_hint() -> void:
	show_hint("")


func _on_show_me_pressed() -> void:
	show_target_requested.emit(NarrativeManager.get_current_step())


func _on_restart_pressed() -> void:
	_hide_completion_modal()
	restart_requested.emit()


func _show_completion_modal() -> void:
	panel.visible = false
	show_button.visible = false
	completion_overlay.visible = true
	layout_refresh_requested.emit("panel opened")
	_raise_to_front()


func _hide_completion_modal() -> void:
	if completion_overlay != null:
		completion_overlay.visible = false


func _raise_to_front() -> void:
	if panel.get_parent() == canvas_layer:
		canvas_layer.move_child(panel, canvas_layer.get_child_count() - 1)
	if show_button.get_parent() == canvas_layer:
		canvas_layer.move_child(show_button, canvas_layer.get_child_count() - 1)
	if completion_overlay.get_parent() == canvas_layer:
		canvas_layer.move_child(completion_overlay, canvas_layer.get_child_count() - 1)


func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = PremiumUIStyles.make_panel_style(0.9)
	style.set_content_margin_all(20.0)
	return style


func _make_completion_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = PremiumUIStyles.make_panel_style(0.94)
	style.set_content_margin_all(18.0)
	return style


func _make_label_settings(font_size: int, font_color: Color) -> LabelSettings:
	var settings: LabelSettings = LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = font_color
	return settings


func _format_target_type(target_type: String) -> String:
	match target_type:
		"hotspot":
			return "Tasting Note"
		"zone":
			return "Winery Detail"
		"prop":
			return "Cellar Detail"
		"door":
			return "Entry Point"
		_:
			return "Opening Note"
