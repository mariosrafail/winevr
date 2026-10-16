extends Node
class_name MainMenuOverlayController

signal museum_requested
signal resume_requested
signal options_requested
signal controls_requested
signal quit_requested
signal menu_opened
signal menu_closed

var root: Control
var dimmer: ColorRect
var panel: PanelContainer
var message_label: Label
var resume_button: Button
var museum_button: Button
var options_button: Button
var controls_button: Button
var quit_button: Button
var _closing: bool = false


func setup(parent_canvas_layer: CanvasLayer) -> void:
	_build_overlay(parent_canvas_layer)
	hide_menu(false)


func show_menu() -> void:
	if root == null:
		return
	if root.visible and root.mouse_filter == Control.MOUSE_FILTER_STOP:
		return
	_closing = false
	message_label.text = ""
	root.visible = true
	_set_interactive(true)
	layout(get_viewport().get_visible_rect().size)
	_animate(true)
	menu_opened.emit()


func hide_menu(emit_signal: bool = true) -> void:
	if root == null:
		return
	if not root.visible:
		return
	_closing = true
	_set_interactive(false)
	_animate(false)
	if emit_signal:
		menu_closed.emit()


func is_open() -> bool:
	return root != null and root.visible


func layout(viewport_size: Vector2) -> void:
	if root == null or panel == null:
		return
	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.x < 120.0 or viewport_size.y < 120.0:
		return
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	var margin: float = 22.0 if viewport_size.x >= 760.0 else 12.0
	var width: float = minf(380.0, viewport_size.x - margin * 2.0)
	var height: float = minf(480.0, viewport_size.y * 0.86)
	panel.custom_minimum_size = Vector2(minf(320.0, width), minf(260.0, height))
	panel.size = Vector2(width, height)
	panel.position = (viewport_size - panel.size) * 0.5


func show_message(message: String) -> void:
	if message_label == null:
		return
	message_label.text = message


func _build_overlay(parent_canvas_layer: CanvasLayer) -> void:
	root = Control.new()
	root.name = "MainMenuOverlay"
	root.visible = false
	root.z_index = 140
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent_canvas_layer.add_child(root)

	dimmer = ColorRect.new()
	dimmer.name = "MainMenuDimmer"
	dimmer.color = Color(0.012, 0.01, 0.009, 0.74)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dimmer)

	panel = PanelContainer.new()
	panel.name = "MainMenuPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", PremiumUIStyles.make_panel_style(0.94))
	root.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)
	PremiumUIStyles.apply_panel_chrome_to_vbox(vbox)

	var title: Label = Label.new()
	title.text = "Main Menu"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", PremiumUIStyles.TEXT_TITLE)
	vbox.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "WineVR"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", PremiumUIStyles.TEXT_BODY)
	vbox.add_child(subtitle)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 4.0)
	vbox.add_child(spacer)

	resume_button = _make_menu_button("Resume", _on_resume_pressed)
	vbox.add_child(resume_button)

	museum_button = _make_menu_button("Αίθουσα σταφυλιών", func() -> void: museum_requested.emit())
	museum_button.name = "GrapeMuseumButton"
	vbox.add_child(museum_button)

	options_button = _make_menu_button("Options", _on_options_pressed)
	vbox.add_child(options_button)

	controls_button = _make_menu_button("Controls", _on_controls_pressed)
	vbox.add_child(controls_button)

	quit_button = _make_menu_button("Quit", _on_quit_pressed)
	vbox.add_child(quit_button)

	message_label = Label.new()
	message_label.text = ""
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 12)
	message_label.add_theme_color_override("font_color", PremiumUIStyles.TEXT_MUTED)
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(message_label)


func _make_menu_button(text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 44.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PremiumUIStyles.apply_gold_outline_button(button)
	button.pressed.connect(callback)
	return button


func _animate(opening: bool) -> void:
	if root == null:
		return
	if root.has_meta("main_menu_tween") and root.get_meta("main_menu_tween") is Tween:
		(root.get_meta("main_menu_tween") as Tween).kill()
	var tween: Tween = root.create_tween()
	root.set_meta("main_menu_tween", tween)
	if opening:
		_closing = false
		root.modulate.a = 0.0
		tween.tween_property(root, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		root.modulate.a = 1.0
		tween.tween_property(root, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.finished.connect(func() -> void:
			if root != null and _closing:
				root.visible = false
				root.modulate.a = 1.0
				_closing = false
		)


func _set_interactive(enabled: bool) -> void:
	_set_interactive_recursive(root, enabled)


func _set_interactive_recursive(node: Node, enabled: bool) -> void:
	if node == null:
		return
	if node is Control:
		var control: Control = node as Control
		if not enabled:
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif control == root or control == dimmer or control == panel or control is BaseButton:
			control.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			control.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		_set_interactive_recursive(child, enabled)


func _on_resume_pressed() -> void:
	resume_requested.emit()


func _on_options_pressed() -> void:
	options_requested.emit()


func _on_controls_pressed() -> void:
	controls_requested.emit()


func _on_quit_pressed() -> void:
	quit_requested.emit()
