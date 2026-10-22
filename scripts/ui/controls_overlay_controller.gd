extends Node
class_name ControlsOverlayController

signal start_requested
signal skip_requested
signal close_requested
signal controls_opened
signal controls_closed

var root: Control
var dimmer: ColorRect
var panel: PanelContainer
var title_label: Label
var subtitle_label: Label
var scroll: ScrollContainer
var content_columns: BoxContainer
var essential_column: VBoxContainer
var advanced_column: VBoxContainer
var vr_section: VBoxContainer
var start_button: Button
var skip_button: Button
var close_button: Button
var footer_label: Label

var _seen_this_session: bool = false
var _show_vr_controls: bool = false
var _show_debug_controls: bool = false
var _last_viewport_size: Vector2 = Vector2.ZERO


func setup(parent_canvas_layer: CanvasLayer) -> void:
	_build_overlay(parent_canvas_layer)
	hide_controls(false)


func show_controls() -> void:
	if root == null:
		return
	if root.visible:
		return
	_rebuild_controls()
	root.visible = true
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_layout(get_viewport().get_visible_rect().size)
	PremiumUIStyles.animate_panel_open(panel, 12.0)
	print("[WineVR][Controls] overlay shown")
	controls_opened.emit()
	# Newly rebuilt wrapping labels need a layout pass before their minimum sizes settle.
	await get_tree().process_frame
	await get_tree().process_frame
	if is_open():
		_layout(get_viewport().get_visible_rect().size)


func hide_controls(emit_signal: bool = true) -> void:
	if root == null:
		return
	if not root.visible:
		return
	root.visible = false
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	print("[WineVR][Controls] overlay hidden")
	if emit_signal:
		controls_closed.emit()


func mark_seen_this_session() -> void:
	_seen_this_session = true


func has_seen_this_session() -> bool:
	return _seen_this_session


func configure(show_vr_controls: bool, show_debug_controls: bool) -> void:
	_show_vr_controls = show_vr_controls
	_show_debug_controls = show_debug_controls
	if root != null and root.visible:
		_rebuild_controls()
		_layout(get_viewport().get_visible_rect().size)


func is_open() -> bool:
	return root != null and root.visible


func layout(viewport_size: Vector2) -> void:
	_last_viewport_size = viewport_size
	_layout(viewport_size)


func _build_overlay(parent_canvas_layer: CanvasLayer) -> void:
	root = Control.new()
	root.name = "ControlsOverlay"
	root.visible = false
	root.z_index = 130
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent_canvas_layer.add_child(root)

	dimmer = ColorRect.new()
	dimmer.name = "ControlsDimmer"
	dimmer.color = Color(0.012, 0.01, 0.009, 0.72)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dimmer)

	panel = PanelContainer.new()
	panel.name = "ControlsPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", PremiumUIStyles.make_panel_style(0.94))
	root.add_child(panel)

	var outer_margin: MarginContainer = MarginContainer.new()
	outer_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 20)
	outer_margin.add_theme_constant_override("margin_right", 20)
	outer_margin.add_theme_constant_override("margin_top", 20)
	outer_margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(outer_margin)

	var outer_vbox: VBoxContainer = VBoxContainer.new()
	outer_vbox.name = "ControlsOuter"
	outer_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_theme_constant_override("separation", 14)
	outer_margin.add_child(outer_vbox)
	PremiumUIStyles.apply_panel_chrome_to_vbox(outer_vbox)

	title_label = Label.new()
	title_label.text = "Πώς εξερευνάς"
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", PremiumUIStyles.TEXT_TITLE)
	outer_vbox.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "Πλησίασε ένα τσαμπί, φέρ’ το κοντά σου και παρατήρησε τις λεπτομέρειες."
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", 14)
	subtitle_label.add_theme_color_override("font_color", PremiumUIStyles.TEXT_BODY)
	outer_vbox.add_child(subtitle_label)

	scroll = ScrollContainer.new()
	scroll.name = "ControlsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(scroll)

	content_columns = BoxContainer.new()
	content_columns.name = "ControlsColumns"
	content_columns.vertical = false
	content_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_columns.add_theme_constant_override("separation", 18)
	scroll.add_child(content_columns)

	essential_column = VBoxContainer.new()
	essential_column.name = "EssentialControls"
	essential_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	essential_column.add_theme_constant_override("separation", 8)
	content_columns.add_child(essential_column)

	advanced_column = VBoxContainer.new()
	advanced_column.name = "AdvancedControls"
	advanced_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	advanced_column.add_theme_constant_override("separation", 8)
	content_columns.add_child(advanced_column)

	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.name = "ControlsButtons"
	button_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.add_theme_constant_override("separation", 12)
	outer_vbox.add_child(button_row)

	close_button = Button.new()
	close_button.text = "Κλείσιμο"
	close_button.custom_minimum_size = Vector2(0.0, 44.0)
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PremiumUIStyles.apply_gold_outline_button(close_button)
	close_button.pressed.connect(_on_close_pressed)
	button_row.add_child(close_button)

	footer_label = Label.new()
	footer_label.text = "Οι οδηγίες ανοίγουν ξανά από το μενού ή με F1."
	footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer_label.add_theme_font_size_override("font_size", 12)
	footer_label.add_theme_color_override("font_color", PremiumUIStyles.TEXT_MUTED)
	outer_vbox.add_child(footer_label)
	outer_vbox.move_child(button_row, outer_vbox.get_child_count() - 1)

	_rebuild_controls()


func _rebuild_controls() -> void:
	_clear_children(essential_column)
	_clear_children(advanced_column)

	_add_section_title(essential_column, "01  /  Περιήγηση στη συλλογή")
	_add_control_row(essential_column, "W A S D", "Περπάτησε ανάμεσα στα εκθέματα")
	_add_control_row(essential_column, "Ποντίκι", "Κοίτα ελεύθερα γύρω σου")
	_add_control_row(essential_column, "E", "Φέρε το επιλεγμένο τσαμπί κοντά σου")
	_add_control_row(essential_column, "Αριστερό κλικ", "Πιάσε και τράβηξε ένα κοντινό τσαμπί")
	_add_control_row(essential_column, "Tab", "Ελευθέρωσε ή δέσμευσε το ποντίκι")
	_add_control_row(essential_column, "Esc", "Άνοιξε το μενού")
	_add_control_row(essential_column, "F11", "Πλήρης οθόνη ή παράθυρο")

	_add_section_title(advanced_column, "02  /  Κοντινή παρατήρηση")
	_add_control_row(advanced_column, "Αριστερό κλικ", "Πιάσε και μετακίνησε το σταφύλι")
	_add_control_row(advanced_column, "Δεξί κλικ", "Περίστρεψε το τσαμπί")
	_add_control_row(advanced_column, "Ροδέλα", "Πλησίασε ή απομάκρυνε το σταφύλι")
	_add_control_row(advanced_column, "← / →", "Περιστροφή αριστερά ή δεξιά")
	_add_control_row(advanced_column, "0°", "Επαναφορά από το κουμπί 0° της καρτέλας")
	_add_control_row(advanced_column, "E / Esc", "Επέστρεψε το τσαμπί στη θέση του")
	_add_control_row(advanced_column, "C", "Άλλαξε σελίδα πληροφοριών")
	_add_control_row(advanced_column, "F1", "Άνοιξε αυτές τις οδηγίες")
	if DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or "--touch-ui" in OS.get_cmdline_user_args():
		_add_section_title(essential_column, "Αφή")
		_add_control_row(essential_column, "Βέλη", "Κράτησε πατημένο για κίνηση")
		_add_control_row(essential_column, "Σύρσιμο", "Σύρε στην κάτω περιοχή για να κοιτάξεις")
		_add_control_row(essential_column, "Εξέταση", "Άνοιξε το έκθεμα που στοχεύεις")
		_add_control_row(essential_column, "Καρτέλες", "Προφίλ, ρώγα, ωρίμανση και τομή 3D")
	if _show_debug_controls:
		_add_section_title(advanced_column, "Εργαλεία δοκιμών")
		_add_control_row(advanced_column, "F3", "Πληροφορίες δοκιμών")
		_add_control_row(advanced_column, "F6", "Δοκιμή μεγέθους οθόνης")
		_add_control_row(advanced_column, "F8 / F9", "Κρύψε ή εμφάνισε το περιβάλλον")
		_add_control_row(advanced_column, "H", "Προεπισκόπηση χεριού VR")
		_add_control_row(advanced_column, "J", "Εμφάνισε τη βάση χεριού VR")
		_add_control_row(advanced_column, "K", "Καταγραφή κατάστασης χεριού")

	if _show_vr_controls:
		_add_section_title(advanced_column, "VR")
		_add_control_row(advanced_column, "Κάσκα", "Κοίτα γύρω σου")
		_add_control_row(advanced_column, "Χειριστήριο", "Στόχευσε τις καρτέλες και τα εκθέματα")
		_add_control_row(advanced_column, "Σκανδάλη / A", "Επίλεξε ή αλληλεπίδρασε")
		_add_control_row(advanced_column, "Αριστερό χέρι", "Στόχευσε τη διαδρομή τηλεμεταφοράς")
		_add_control_row(advanced_column, "Σκανδάλη / μοχλός", "Μετακίνηση σε έγκυρο σημείο")
		_add_control_row(advanced_column, "Δεξί grip", "Πιάσε ένα κοντινό τσαμπί")


func _add_section_title(parent: VBoxContainer, text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", PremiumUIStyles.GOLD_ACCENT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)


func _add_control_row(parent: VBoxContainer, key_text: String, description: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var key_label: Label = Label.new()
	key_label.text = key_text
	key_label.custom_minimum_size = Vector2(128.0, 0.0)
	key_label.add_theme_color_override("font_color", PremiumUIStyles.TEXT_TITLE)
	key_label.add_theme_font_size_override("font_size", 12)
	key_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(key_label)

	var desc_label: Label = Label.new()
	desc_label.text = description
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.add_theme_color_override("font_color", PremiumUIStyles.TEXT_BODY)
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(desc_label)


func _layout(viewport_size: Vector2) -> void:
	if root == null or panel == null:
		return
	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.x < 120.0 or viewport_size.y < 120.0:
		return
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)

	var margin: float = 22.0 if viewport_size.x >= 760.0 else 12.0
	var max_width: float = maxf(220.0, viewport_size.x - margin * 2.0)
	var max_height: float = minf(viewport_size.y * 0.86, viewport_size.y - margin * 2.0)
	var preferred_width: float = minf(max_width, 900.0)
	var target_size: Vector2 = Vector2(preferred_width, minf(580.0, max_height))
	panel.custom_minimum_size = Vector2(minf(320.0, target_size.x), minf(280.0, target_size.y))
	subtitle_label.visible = viewport_size.y > 450
	footer_label.visible = viewport_size.y > 450
	panel.size = target_size
	panel.set_deferred("size", target_size)
	panel.position = (viewport_size - target_size) * 0.5

	var single_column: bool = viewport_size.x < 760.0 or target_size.x < 680.0
	content_columns.vertical = single_column
	content_columns.add_theme_constant_override("separation", 14 if single_column else 18)
	if scroll != null:
		scroll.custom_minimum_size = Vector2(0.0, 96.0)


func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		node.remove_child(child)
		child.free()


func _on_start_pressed() -> void:
	print("[WineVR][Controls] start pressed")
	mark_seen_this_session()
	hide_controls()
	start_requested.emit()


func _on_skip_pressed() -> void:
	mark_seen_this_session()
	hide_controls()
	skip_requested.emit()


func _on_close_pressed() -> void:
	mark_seen_this_session()
	hide_controls()
	close_requested.emit()
