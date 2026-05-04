extends Node
class_name GraphicsSettingsPanelController

signal apply_requested(preset_name: String, fps_friendly: bool)
signal fallback_accept_requested()
signal fallback_ignore_requested()
signal display_settings_applied(old_window_size: Vector2i, new_window_size: Vector2i, viewport_size: Vector2)
signal layout_refresh_requested(reason: String)

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
var options_scroll: ScrollContainer
var options_content: BoxContainer
var left_column: VBoxContainer
var right_column: VBoxContainer
var buttons_row: HBoxContainer
var _options_scroll_enabled: bool = false
var _last_viewport_size: Vector2 = Vector2.ZERO


func setup(canvas_layer: CanvasLayer) -> void:
	root = canvas_layer
	_build_options_panel()
	_build_prompt_bar()
	_load_display_settings()


func toggle() -> void:
	if panel.visible:
		close()
	else:
		open()


func open() -> void:
	panel.visible = true
	layout_refresh_requested.emit("panel opened")
	await get_tree().process_frame
	_apply_centered_panel_layout()


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
		var safe_margin: float = 20.0 if viewport_size.x >= 760.0 else 16.0
		menu_button.size = Vector2(128.0, 44.0)
		menu_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT, false)
		menu_button.set_offset(SIDE_LEFT, safe_margin)
		menu_button.set_offset(SIDE_TOP, -menu_button.size.y - safe_margin)
		menu_button.set_offset(SIDE_RIGHT, safe_margin + menu_button.size.x)
		menu_button.set_offset(SIDE_BOTTOM, -safe_margin)

	if panel != null:
		_apply_centered_panel_layout(viewport_size)

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
		layout_refresh_requested.emit("panel opened")


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
	PremiumUIStyles.apply_gold_outline_button(menu_button)
	menu_button.pressed.connect(toggle)
	root.add_child(menu_button)

	var outer_margin: MarginContainer = MarginContainer.new()
	outer_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 18)
	outer_margin.add_theme_constant_override("margin_right", 18)
	outer_margin.add_theme_constant_override("margin_top", 18)
	outer_margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(outer_margin)

	var outer_vbox: VBoxContainer = VBoxContainer.new()
	outer_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_vbox.add_theme_constant_override("separation", 16)
	outer_margin.add_child(outer_vbox)
	PremiumUIStyles.apply_panel_chrome_to_vbox(outer_vbox)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	outer_vbox.add_child(header)

	var title: Label = Label.new()
	title.text = "Options"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.modulate = PremiumUIStyles.TEXT_TITLE
	header.add_child(title)

	options_content = BoxContainer.new()
	options_content.name = "OptionsContent"
	options_content.vertical = false
	options_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	options_content.add_theme_constant_override("separation", 24)
	outer_vbox.add_child(options_content)

	left_column = VBoxContainer.new()
	left_column.name = "LeftColumn"
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override("separation", 12)
	options_content.add_child(left_column)

	right_column = VBoxContainer.new()
	right_column.name = "RightColumn"
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 12)
	options_content.add_child(right_column)

	_add_section_title(left_column, "Graphics")

	quality_dropdown = OptionButton.new()
	quality_dropdown.add_item("Ultra Low")
	quality_dropdown.add_item("Low")
	quality_dropdown.add_item("Medium")
	quality_dropdown.add_item("High")
	quality_dropdown.add_item("Cinematic")
	quality_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PremiumUIStyles.apply_dropdown_style(quality_dropdown)
	left_column.add_child(quality_dropdown)

	_add_section_title(left_column, "Resolution")

	resolution_dropdown = OptionButton.new()
	_populate_resolution_options()
	resolution_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PremiumUIStyles.apply_dropdown_style(resolution_dropdown)
	left_column.add_child(resolution_dropdown)

	fullscreen_toggle = CheckBox.new()
	fullscreen_toggle.text = "Fullscreen"
	fullscreen_toggle.modulate = PremiumUIStyles.TEXT_BODY
	left_column.add_child(fullscreen_toggle)

	vsync_dropdown = OptionButton.new()
	vsync_dropdown.add_item("VSync: Off")
	vsync_dropdown.add_item("VSync: On")
	vsync_dropdown.selected = 1
	vsync_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PremiumUIStyles.apply_dropdown_style(vsync_dropdown)
	left_column.add_child(vsync_dropdown)

	_add_section_title(right_column, "Controls")

	var explore_hint: Label = Label.new()
	explore_hint.text = "Explore Mode: Tab or E\nExit Explore Mode: ESC"
	explore_hint.modulate = PremiumUIStyles.TEXT_BODY
	explore_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explore_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.add_child(explore_hint)

	_add_section_title(right_column, "Performance")

	fps_toggle = CheckBox.new()
	fps_toggle.text = "FPS-friendly"
	fps_toggle.modulate = PremiumUIStyles.TEXT_BODY
	right_column.add_child(fps_toggle)

	var hint: Label = Label.new()
	hint.text = "ESC closes this panel when Explore Mode is off."
	hint.modulate = PremiumUIStyles.TEXT_MUTED
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.add_child(hint)

	options_scroll = ScrollContainer.new()
	options_scroll.name = "OptionsScrollFallback"
	options_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	options_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	options_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	options_scroll.visible = false

	buttons_row = HBoxContainer.new()
	buttons_row.name = "ButtonsRow"
	buttons_row.add_theme_constant_override("separation", 12)
	buttons_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(buttons_row)

	apply_button = Button.new()
	apply_button.text = "Apply"
	apply_button.custom_minimum_size = Vector2(0.0, 44.0)
	apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PremiumUIStyles.apply_gold_outline_button(apply_button)
	apply_button.pressed.connect(_on_apply_pressed)
	buttons_row.add_child(apply_button)

	close_button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(0.0, 44.0)
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PremiumUIStyles.apply_gold_outline_button(close_button)
	close_button.pressed.connect(close)
	buttons_row.add_child(close_button)


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
	PremiumUIStyles.apply_panel_chrome_to_vbox(vbox)

	var label: Label = Label.new()
	label.text = "Ultra Performance Mode recommended"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.modulate = PremiumUIStyles.TEXT_TITLE
	vbox.add_child(label)

	prompt_buttons = BoxContainer.new()
	prompt_buttons.vertical = false
	prompt_buttons.add_theme_constant_override("separation", 10)
	vbox.add_child(prompt_buttons)

	var accept_button: Button = Button.new()
	accept_button.text = "Use Ultra Low"
	accept_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PremiumUIStyles.apply_gold_outline_button(accept_button)
	accept_button.pressed.connect(func() -> void:
		fallback_accept_requested.emit()
		hide_fallback_prompt()
	)
	prompt_buttons.add_child(accept_button)

	var ignore_button: Button = Button.new()
	ignore_button.text = "Ignore"
	ignore_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PremiumUIStyles.apply_gold_outline_button(ignore_button)
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
	var requested_size: Vector2i = Vector2i.ZERO
	var size_parts: PackedStringArray = resolution_text.split("x")
	if size_parts.size() == 2:
		var width: int = int(size_parts[0])
		var height: int = int(size_parts[1])
		if width > 0 and height > 0:
			requested_size = Vector2i(width, height)
	print("Resolution requested:", requested_size)

	if fullscreen_toggle.button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		if requested_size != Vector2i.ZERO:
			DisplayServer.window_set_size(requested_size)
			_center_window(requested_size)

	var vsync_mode: DisplayServer.VSyncMode = DisplayServer.VSYNC_ENABLED if vsync_dropdown.selected == 1 else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)
	_save_display_settings()

	await get_tree().process_frame
	await get_tree().process_frame
	var new_window_size: Vector2i = DisplayServer.window_get_size()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	print("Window size after apply:", new_window_size)
	print("Viewport visible size:", viewport_size)
	layout(viewport_size)
	display_settings_applied.emit(old_window_size, new_window_size, viewport_size)


func apply_saved_display_settings() -> void:
	await get_tree().process_frame
	await _apply_display_settings()


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


func _apply_centered_panel_layout(viewport_size: Vector2 = Vector2.ZERO) -> Rect2:
	if panel == null:
		return Rect2()
	var actual_viewport_size: Vector2 = viewport_size
	if actual_viewport_size == Vector2.ZERO:
		actual_viewport_size = get_viewport().get_visible_rect().size
	if actual_viewport_size.x < 120.0 or actual_viewport_size.y < 120.0:
		return Rect2(panel.position, panel.size)
	var margin: float = 28.0 if actual_viewport_size.x >= 900.0 else 20.0
	var max_width: float = maxf(320.0, actual_viewport_size.x - margin * 2.0)
	var max_height: float = maxf(320.0, actual_viewport_size.y - margin * 2.0)
	var preferred_width: float = clampf(actual_viewport_size.x * 0.5, 420.0, 900.0)
	var ratio_height_cap: float = maxf(260.0, actual_viewport_size.y * 0.85)
	var preferred_height: float = clampf(actual_viewport_size.y * 0.7, minf(400.0, ratio_height_cap), ratio_height_cap)
	var target_size: Vector2 = Vector2(minf(preferred_width, max_width), minf(preferred_height, max_height))
	panel.custom_minimum_size = Vector2(minf(420.0, target_size.x), minf(360.0, target_size.y))
	panel.size = target_size
	_configure_options_content_layout(actual_viewport_size, target_size)
	var rect: Rect2 = ResponsiveLayoutController.center_panel_safe(panel, get_viewport(), target_size.x, 0.85)
	print("[WineVR][Options] viewport=%s panel_size=%s scroll_enabled=%s" % [
		str(actual_viewport_size),
		str(rect.size),
		str(_options_scroll_enabled)
	])
	return rect


func _configure_options_content_layout(viewport_size: Vector2, panel_size: Vector2) -> void:
	var use_scroll: bool = viewport_size.y < 650.0
	_set_options_scroll_enabled(use_scroll)
	if options_content != null:
		var use_single_column: bool = viewport_size.x < 980.0 or panel_size.x < 680.0
		options_content.vertical = use_single_column
		options_content.add_theme_constant_override("separation", 16 if use_single_column else 24)
	if buttons_row != null:
		buttons_row.size_flags_vertical = Control.SIZE_SHRINK_END


func _set_options_scroll_enabled(enabled: bool) -> void:
	if options_content == null or options_scroll == null:
		return
	if _options_scroll_enabled == enabled:
		return
	_options_scroll_enabled = enabled
	if enabled:
		var current_parent: Node = options_content.get_parent()
		if current_parent == null:
			return
		var insert_index: int = options_content.get_index()
		current_parent.remove_child(options_content)
		if options_scroll.get_parent() == null:
			current_parent.add_child(options_scroll)
			current_parent.move_child(options_scroll, insert_index)
		options_scroll.visible = true
		options_scroll.add_child(options_content)
	else:
		var scroll_parent: Node = options_scroll.get_parent()
		if scroll_parent == null:
			return
		var insert_index: int = options_scroll.get_index()
		options_scroll.remove_child(options_content)
		scroll_parent.remove_child(options_scroll)
		scroll_parent.add_child(options_content)
		scroll_parent.move_child(options_content, insert_index)
		options_scroll.visible = false


func _add_section_title(parent: VBoxContainer, text: String) -> void:
	var title: Label = Label.new()
	title.text = text
	title.modulate = PremiumUIStyles.GOLD_ACCENT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(title)
