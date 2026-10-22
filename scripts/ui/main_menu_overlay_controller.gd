extends Node
class_name MainMenuOverlayController

signal museum_requested
signal vineyard_requested
signal tasting_requested
signal cellar_requested
signal xr_requested(mode: String)
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
var vineyard_button: Button
var tasting_button: Button
var cellar_button: Button
var vr_button: Button
var ar_button: Button
var capability_label: Label
var _columns: BoxContainer
var _intro: VBoxContainer
var _actions: VBoxContainer
var _title: Label
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
	var width: float = minf(1040.0, viewport_size.x - margin * 2.0)
	var height: float = minf(780.0 if width < 720.0 else 590.0, viewport_size.y - margin * 2.0)
	if _columns != null:
		_columns.vertical = width < 720.0
		_intro.custom_minimum_size.x = 0.0 if _columns.vertical else width * 0.39
		_actions.custom_minimum_size.x = 0.0
		_title.add_theme_font_size_override("font_size", 30 if _columns.vertical else 42)
		_title.text = "Η Κρήτη, σε μια ρώγα." if _columns.vertical else "Η Κρήτη,\nμέσα σε\nμια ρώγα."
		_intro.get_node("JourneyDescription").visible = not _columns.vertical
		_intro.get_node("JourneyNote").visible = not _columns.vertical
		_intro.get_node("JourneySteps").visible = not _columns.vertical
	panel.custom_minimum_size = Vector2(minf(320.0, width), minf(260.0, height))
	panel.size = Vector2(width, height)
	panel.position = (viewport_size - Vector2(width, height)) * 0.5
	panel.set_deferred("size", Vector2(width, height))


func set_xr_capabilities(capabilities: Dictionary, busy: bool = false) -> void:
	if vr_button == null:
		return
	vr_button.disabled = busy or not bool(capabilities.get("vr", false))
	ar_button.disabled = busy or not bool(capabilities.get("ar", false))
	capability_label.text = str(capabilities.get("message", "Υπολογιστής και αφή · έλεγχος διαθέσιμης συσκευής XR"))
	if busy:
		capability_label.text = "Σύνδεση με τη συσκευή…"


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
	dimmer.color = Color(0.012, 0.025, 0.022, 0.88)
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

	_columns = BoxContainer.new()
	_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_columns.add_theme_constant_override("separation", 30)
	margin.add_child(_columns)
	_intro = VBoxContainer.new()
	_intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_intro.add_theme_constant_override("separation", 20)
	_columns.add_child(_intro)
	_label(_intro, "W I N E V R   /   C R E T E", 14, PremiumUIStyles.GOLD_ACCENT)
	_title = _label(_intro, "Η Κρήτη,\nμέσα σε\nμια ρώγα.", 42, PremiumUIStyles.TEXT_TITLE)
	var description: Label = _label(_intro, "Άγγιξε τις ποικιλίες. Ανακάλυψε τον τόπο.\nΑκολούθησε το κρασί από το αμπέλι στο ποτήρι.", 17, PremiumUIStyles.TEXT_BODY)
	description.name = "JourneyDescription"
	_label(_intro, "01  ΣΤΑΦΥΛΙ     02  ΤΟΠΟΣ     03  ΚΡΑΣΙ", 12, PremiumUIStyles.GOLD_ACCENT).name = "JourneySteps"
	_label(_intro, "Μια διαδραστική, εκπαιδευτική συλλογή\nμε τρισδιάστατα εκθέματα και φυσική κίνηση.", 13, PremiumUIStyles.TEXT_MUTED).name = "JourneyNote"
	_actions = VBoxContainer.new()
	_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions.add_theme_constant_override("separation", 10)
	_columns.add_child(_actions)
	var vbox: VBoxContainer = _actions
	_label(vbox, "ΔΙΑΛΕΞΕ ΤΗ ΔΙΑΔΡΟΜΗ ΣΟΥ", 12, PremiumUIStyles.TEXT_MUTED)

	museum_button = _make_menu_button("01   Η συλλογή σταφυλιών\nΛιάτικο · Κοτσιφάλι · Βιδιανό", func() -> void: museum_requested.emit())
	museum_button.name = "GrapeMuseumButton"
	museum_button.custom_minimum_size.y = 70
	vbox.add_child(museum_button)
	vineyard_button = _make_menu_button("02   Στον αμπελώνα των Δαφνών\nΤοπίο · τόπος · ιστορία", func() -> void: vineyard_requested.emit())
	vineyard_button.custom_minimum_size.y = 70
	vbox.add_child(vineyard_button)
	tasting_button = _make_menu_button("03   Διάλεξε ένα κρασί\nΓνωριμία και γευστική εξερεύνηση", func() -> void: tasting_requested.emit())
	tasting_button.custom_minimum_size.y = 70
	vbox.add_child(tasting_button)
	cellar_button = _make_menu_button("04   Ξενάγηση στην κάβα\nΤρύγος · ζύμωση · παλαίωση", func() -> void: cellar_requested.emit())
	cellar_button.custom_minimum_size.y = 62
	vbox.add_child(cellar_button)
	var xr_row: HBoxContainer = HBoxContainer.new()
	xr_row.add_theme_constant_override("separation", 8)
	vbox.add_child(xr_row)
	vr_button = _make_menu_button("Είσοδος VR", func() -> void: xr_requested.emit("vr"))
	ar_button = _make_menu_button("Είσοδος AR", func() -> void: xr_requested.emit("ar"))
	vr_button.disabled = true
	ar_button.disabled = true
	xr_row.add_child(vr_button)
	xr_row.add_child(ar_button)
	capability_label = _label(vbox, "Έλεγχος διαθέσιμης συσκευής…", 12, PremiumUIStyles.TEXT_MUTED)
	resume_button = _make_menu_button("Συνέχεια εξερεύνησης", _on_resume_pressed)
	vbox.add_child(resume_button)

	var utility_row: HBoxContainer = HBoxContainer.new()
	utility_row.add_theme_constant_override("separation", 8)
	vbox.add_child(utility_row)
	options_button = _make_menu_button("Ρυθμίσεις", _on_options_pressed)
	utility_row.add_child(options_button)

	controls_button = _make_menu_button("Χειρισμός", _on_controls_pressed)
	utility_row.add_child(controls_button)

	quit_button = _make_menu_button("Έξοδος", _on_quit_pressed)
	utility_row.add_child(quit_button)

	message_label = Label.new()
	message_label.text = ""
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 12)
	message_label.add_theme_color_override("font_color", PremiumUIStyles.TEXT_MUTED)
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(message_label)
	resume_button.visible = false


func _label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _make_menu_button(text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.clip_text = true
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
