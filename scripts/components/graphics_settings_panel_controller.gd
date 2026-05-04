extends Node
class_name GraphicsSettingsPanelController

signal apply_requested(preset_name: String, fps_friendly: bool)
signal fallback_accept_requested()
signal fallback_ignore_requested()

var root: CanvasLayer
var panel: PanelContainer
var quality_dropdown: OptionButton
var fps_toggle: CheckBox
var apply_button: Button
var prompt_bar: PanelContainer
var gear_button: Button


func setup(canvas_layer: CanvasLayer) -> void:
	root = canvas_layer
	panel = PanelContainer.new()
	panel.name = "GraphicsSettingsPanel"
	panel.visible = false
	panel.z_index = 98
	panel.position = Vector2(20.0, 80.0)
	panel.size = Vector2(320.0, 210.0)
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	root.add_child(panel)

	gear_button = Button.new()
	gear_button.name = "GraphicsGearButton"
	gear_button.text = "GFX"
	gear_button.tooltip_text = "Graphics Settings"
	gear_button.position = Vector2(16.0, 16.0)
	gear_button.size = Vector2(38.0, 38.0)
	gear_button.z_index = 98
	gear_button.pressed.connect(toggle)
	root.add_child(gear_button)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title: Label = Label.new()
	title.text = "Graphics"
	title.modulate = Color(0.97, 0.92, 0.82, 1.0)
	vbox.add_child(title)

	quality_dropdown = OptionButton.new()
	quality_dropdown.add_item("Ultra Low")
	quality_dropdown.add_item("Low")
	quality_dropdown.add_item("Medium")
	quality_dropdown.add_item("High")
	quality_dropdown.add_item("Cinematic")
	vbox.add_child(quality_dropdown)

	fps_toggle = CheckBox.new()
	fps_toggle.text = "FPS-friendly"
	vbox.add_child(fps_toggle)

	apply_button = Button.new()
	apply_button.text = "Apply"
	vbox.add_child(apply_button)
	apply_button.pressed.connect(_on_apply_pressed)

	var hint: Label = Label.new()
	hint.text = "ESC: close panel"
	hint.modulate = Color(0.78, 0.76, 0.72, 1.0)
	vbox.add_child(hint)

	_build_prompt_bar()


func toggle() -> void:
	panel.visible = not panel.visible


func open() -> void:
	panel.visible = true


func close() -> void:
	panel.visible = false


func is_open() -> bool:
	return panel != null and panel.visible


func set_values(preset_name: String, fps_friendly: bool) -> void:
	var index: int = 2
	match preset_name:
		"Ultra Low":
			index = 0
		"Low":
			index = 1
		"Medium":
			index = 2
		"High":
			index = 3
		"Cinematic":
			index = 4
	quality_dropdown.selected = index
	fps_toggle.button_pressed = fps_friendly


func show_fallback_prompt() -> void:
	if prompt_bar != null:
		prompt_bar.visible = true


func hide_fallback_prompt() -> void:
	if prompt_bar != null:
		prompt_bar.visible = false


func _on_apply_pressed() -> void:
	var preset: String = quality_dropdown.get_item_text(quality_dropdown.selected)
	apply_requested.emit(preset, fps_toggle.button_pressed)


func _build_prompt_bar() -> void:
	prompt_bar = PanelContainer.new()
	prompt_bar.visible = false
	prompt_bar.z_index = 99
	prompt_bar.position = Vector2(20.0, 20.0)
	prompt_bar.size = Vector2(500.0, 68.0)
	prompt_bar.add_theme_stylebox_override("panel", _make_prompt_style())
	root.add_child(prompt_bar)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	prompt_bar.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)

	var label: Label = Label.new()
	label.text = "Ultra Performance Mode recommended"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.modulate = Color(0.95, 0.93, 0.89, 1.0)
	hbox.add_child(label)

	var accept_button: Button = Button.new()
	accept_button.text = "Use Ultra Low"
	accept_button.pressed.connect(func() -> void:
		fallback_accept_requested.emit()
		hide_fallback_prompt()
	)
	hbox.add_child(accept_button)

	var ignore_button: Button = Button.new()
	ignore_button.text = "Ignore"
	ignore_button.pressed.connect(func() -> void:
		fallback_ignore_requested.emit()
		hide_fallback_prompt()
	)
	hbox.add_child(ignore_button)


func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.04, 0.92)
	style.border_color = Color(0.84, 0.65, 0.38, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style


func _make_prompt_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.05, 0.9)
	style.border_color = Color(0.84, 0.65, 0.38, 0.48)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style
