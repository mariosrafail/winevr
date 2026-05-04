extends Node
class_name GraphicsSettingsPanelController

signal apply_requested(preset_name: String, fps_friendly: bool)
signal fallback_accept_requested()
signal fallback_ignore_requested()
signal display_settings_applied(old_window_size: Vector2i, new_window_size: Vector2i, viewport_size: Vector2)

const CONFIG_PATH: String = "user://graphics_settings.cfg"

var root: CanvasLayer
var panel: PanelContainer
var quality_dropdown: OptionButton
var fps_toggle: CheckBox
var resolution_dropdown: OptionButton
var fullscreen_toggle: CheckBox
var vsync_dropdown: OptionButton
var apply_button: Button
var prompt_bar: PanelContainer
var menu_button: Button
var close_button: Button
var prompt_buttons: BoxContainer
var _last_viewport_size: Vector2 = Vector2.ZERO


func setup(canvas_layer: CanvasLayer) -> void:
	root = canvas_layer
	_build_options_panel()
	_build_prompt_bar()
	_load_display_settings()


func toggle() -> void:
	panel.visible = not panel.visible


func open() -> void:
	panel.visible = true


func close() -> void:
	panel.visible = false


func is_open() -> bool:
	return panel != null and panel.visible


func get_panel_rect() -> Rect2:
	if panel == null:
		return Rect2()
	return Rect2(panel.position, panel.size)


func layout(viewport_size: Vector2) -> void:
	_last_viewport_size = viewport_size
	if menu_button != null:
		menu_button.position = Vector2(16.0, 16.0)
		menu_button.size = Vector2(112.0, 40.0)

	if panel != null:
		var anchor_mode: String = "top_left"
		if viewport_size.x < 1100.0 or viewport_size.y < 760.0:
			anchor_mode = "center"
		var preferred: Vector2 = Vector2(500.0, 430.0)
		if viewport_size.x < 960.0 or viewport_size.y < 680.0:
			preferred = Vector2(viewport_size.x * 0.92, viewport_size.y * 0.9)
		ResponsiveLayoutController.apply_safe_panel_layout(panel, viewport_size, preferred, anchor_mode)

	if prompt_bar != null:
		var prompt_rect: Rect2 = ResponsiveLayoutController.apply_safe_panel_layout(prompt_bar, viewport_size, Vector2(760.0, 116.0), "top_right")
		prompt_bar.position = Vector2(maxf(8.0, prompt_rect.position.x), 8.0)
		if prompt_buttons != null:
			prompt_buttons.vertical = prompt_rect.size.x < 560.0


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


func _build_options_panel() -> void:
	panel = PanelContainer.new()
	panel.name = "OptionsPanel"
	panel.visible = false
	panel.z_index = 98
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	root.add_child(panel)

	menu_button = Button.new()
	menu_button.name = "OptionsMenuButton"
	menu_button.text = "Options"
	menu_button.tooltip_text = "Open Options"
	menu_button.z_index = 98
	menu_button.pressed.connect(toggle)
	root.add_child(menu_button)

	var outer_margin: MarginContainer = MarginContainer.new()
	outer_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 12)
	outer_margin.add_theme_constant_override("margin_right", 12)
	outer_margin.add_theme_constant_override("margin_top", 12)
	outer_margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(outer_margin)

	var outer_vbox: VBoxContainer = VBoxContainer.new()
	outer_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_theme_constant_override("separation", 10)
	outer_margin.add_child(outer_vbox)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	outer_vbox.add_child(header)

	var title: Label = Label.new()
	title.text = "Options"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.modulate = Color(0.97, 0.92, 0.82, 1.0)
	header.add_child(title)

	close_button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(88.0, 34.0)
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(scroll)

	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size = Vector2(0.0, 420.0)
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	var graphics_title: Label = Label.new()
	graphics_title.text = "Graphics Quality"
	graphics_title.modulate = Color(0.82, 0.82, 0.78, 1.0)
	content.add_child(graphics_title)

	quality_dropdown = OptionButton.new()
	quality_dropdown.add_item("Ultra Low")
	quality_dropdown.add_item("Low")
	quality_dropdown.add_item("Medium")
	quality_dropdown.add_item("High")
	quality_dropdown.add_item("Cinematic")
	content.add_child(quality_dropdown)

	fps_toggle = CheckBox.new()
	fps_toggle.text = "FPS-friendly"
	content.add_child(fps_toggle)

	var display_title: Label = Label.new()
	display_title.text = "Display"
	display_title.modulate = Color(0.82, 0.82, 0.78, 1.0)
	content.add_child(display_title)

	resolution_dropdown = OptionButton.new()
	_populate_resolution_options()
	content.add_child(resolution_dropdown)

	fullscreen_toggle = CheckBox.new()
	fullscreen_toggle.text = "Fullscreen"
	content.add_child(fullscreen_toggle)

	vsync_dropdown = OptionButton.new()
	vsync_dropdown.add_item("VSync: Off")
	vsync_dropdown.add_item("VSync: On")
	content.add_child(vsync_dropdown)

	apply_button = Button.new()
	apply_button.text = "Apply"
	apply_button.custom_minimum_size = Vector2(0.0, 40.0)
	apply_button.pressed.connect(_on_apply_pressed)
	content.add_child(apply_button)

	var hint: Label = Label.new()
	hint.text = "ESC: close panel"
	hint.modulate = Color(0.78, 0.76, 0.72, 1.0)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)


func _on_apply_pressed() -> void:
	var preset: String = quality_dropdown.get_item_text(quality_dropdown.selected)
	apply_requested.emit(preset, fps_toggle.button_pressed)
	await _apply_display_settings()


func _build_prompt_bar() -> void:
	prompt_bar = PanelContainer.new()
	prompt_bar.visible = false
	prompt_bar.z_index = 99
	prompt_bar.add_theme_stylebox_override("panel", _make_prompt_style())
	root.add_child(prompt_bar)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	prompt_bar.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var label: Label = Label.new()
	label.text = "Ultra Performance Mode recommended"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.modulate = Color(0.95, 0.93, 0.89, 1.0)
	vbox.add_child(label)

	prompt_buttons = BoxContainer.new()
	prompt_buttons.vertical = false
	prompt_buttons.add_theme_constant_override("separation", 10)
	vbox.add_child(prompt_buttons)

	var accept_button: Button = Button.new()
	accept_button.text = "Use Ultra Low"
	accept_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accept_button.pressed.connect(func() -> void:
		fallback_accept_requested.emit()
		hide_fallback_prompt()
	)
	prompt_buttons.add_child(accept_button)

	var ignore_button: Button = Button.new()
	ignore_button.text = "Ignore"
	ignore_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ignore_button.pressed.connect(func() -> void:
		fallback_ignore_requested.emit()
		hide_fallback_prompt()
	)
	prompt_buttons.add_child(ignore_button)


func _populate_resolution_options() -> void:
	resolution_dropdown.clear()
	var options: Array[Vector2i] = [
		Vector2i(1280, 720),
		Vector2i(1366, 768),
		Vector2i(1600, 900),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440)
	]
	var current_size: Vector2i = DisplayServer.window_get_size()
	var current_label: String = "%sx%s" % [current_size.x, current_size.y]
	var has_current: bool = false
	for size_option in options:
		var label: String = "%sx%s" % [size_option.x, size_option.y]
		resolution_dropdown.add_item(label)
		if label == current_label:
			has_current = true
	if not has_current:
		resolution_dropdown.add_item(current_label)
		resolution_dropdown.select(resolution_dropdown.item_count - 1)
	else:
		for index in range(resolution_dropdown.item_count):
			if resolution_dropdown.get_item_text(index) == current_label:
				resolution_dropdown.select(index)
				break


func _apply_display_settings() -> void:
	var old_window_size: Vector2i = DisplayServer.window_get_size()
	var resolution_text: String = resolution_dropdown.get_item_text(resolution_dropdown.selected)
	var size_parts: PackedStringArray = resolution_text.split("x")
	if size_parts.size() == 2:
		var width: int = int(size_parts[0])
		var height: int = int(size_parts[1])
		if width > 0 and height > 0:
			DisplayServer.window_set_size(Vector2i(width, height))
			_center_window(Vector2i(width, height))

	var window_mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen_toggle.button_pressed else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(window_mode)
	var vsync_mode: DisplayServer.VSyncMode = DisplayServer.VSYNC_ENABLED if vsync_dropdown.selected == 1 else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)
	_save_display_settings()

	await get_tree().process_frame
	var new_window_size: Vector2i = DisplayServer.window_get_size()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	layout(viewport_size)
	display_settings_applied.emit(old_window_size, new_window_size, viewport_size)


func _load_display_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		var fullscreen: bool = bool(config.get_value("display", "fullscreen", false))
		var vsync_enabled: bool = bool(config.get_value("display", "vsync", true))
		var resolution: String = str(config.get_value("display", "resolution", ""))
		fullscreen_toggle.button_pressed = fullscreen
		vsync_dropdown.selected = 1 if vsync_enabled else 0
		if not resolution.is_empty():
			for index in range(resolution_dropdown.item_count):
				if resolution_dropdown.get_item_text(index) == resolution:
					resolution_dropdown.select(index)
					break


func _save_display_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value("display", "fullscreen", fullscreen_toggle.button_pressed)
	config.set_value("display", "vsync", vsync_dropdown.selected == 1)
	config.set_value("display", "resolution", resolution_dropdown.get_item_text(resolution_dropdown.selected))
	config.save(CONFIG_PATH)


func _center_window(window_size: Vector2i) -> void:
	var screen_id: int = DisplayServer.window_get_current_screen()
	var screen_position: Vector2i = DisplayServer.screen_get_position(screen_id)
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen_id)
	DisplayServer.window_set_position(screen_position + (screen_size - window_size) / 2)


func _make_panel_style() -> StyleBoxFlat:
	return PremiumUIStyles.make_panel_style(0.9)


func _make_prompt_style() -> StyleBoxFlat:
	return PremiumUIStyles.make_panel_style(0.88)
