extends Node
class_name QRScreenController

signal client_selected(client_id: String)
signal immersive_mode_requested

var screen: Control
var card: PanelContainer
var error_label: Label
var immersive_mode_button: Button
var immersive_message_label: Label
var button_box: VBoxContainer
var registry_entries: Array[Dictionary] = []
var canvas_layer: CanvasLayer
var search_field: LineEdit
var region_filter: OptionButton
var result_label: Label
var results_scroll: ScrollContainer
var content_scroll: ScrollContainer
var code_toggle: Button
var code_box: VBoxContainer
var code_field: LineEdit
var code_submit_button: Button
var code_entry_active: bool = false
var _code_submitting: bool = false


func setup(parent_canvas_layer: CanvasLayer, entries: Array[Dictionary]) -> void:
	canvas_layer = parent_canvas_layer
	registry_entries = entries
	screen = Control.new()
	screen.name = "QRSimulationScreen"
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(screen)
	canvas_layer.move_child(screen, 1)

	var dimmer: ColorRect = ColorRect.new()
	dimmer.color = Color(0.02, 0.024, 0.03, 0.72)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(dimmer)

	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _make_panel_style())
	screen.add_child(card)
	content_scroll = ScrollContainer.new()
	content_scroll.name = "CatalogContentScroll"
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content_scroll.follow_focus = true
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(content_scroll)

	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 2)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	content_scroll.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	PremiumUIStyles.apply_panel_chrome_to_vbox(box)

	var title: Label = Label.new()
	title.text = "Διάλεξε ένα κρασί"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.label_settings = _make_label_settings(28, PremiumUIStyles.TEXT_TITLE)
	box.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "Ποικιλίες, τόποι και γευστικές ιστορίες."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.label_settings = _make_label_settings(15, PremiumUIStyles.TEXT_MUTED)
	box.add_child(subtitle)

	immersive_mode_button = Button.new()
	immersive_mode_button.text = _immersive_button_label()
	immersive_mode_button.tooltip_text = _immersive_button_label()
	immersive_mode_button.custom_minimum_size = Vector2(0.0, 52.0)
	immersive_mode_button.focus_mode = Control.FOCUS_ALL
	immersive_mode_button.visible = false
	PremiumUIStyles.apply_gold_outline_button(immersive_mode_button)
	immersive_mode_button.pressed.connect(func() -> void: immersive_mode_requested.emit())
	box.add_child(immersive_mode_button)

	immersive_message_label = Label.new()
	immersive_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	immersive_message_label.visible = false
	immersive_message_label.label_settings = _make_label_settings(14, PremiumUIStyles.TEXT_MUTED)
	box.add_child(immersive_message_label)
	_build_sample_code_entry(box)

	search_field = LineEdit.new()
	search_field.placeholder_text = "Ποικιλία ή περιοχή…"
	search_field.custom_minimum_size.y = 44
	search_field.clear_button_enabled = true
	search_field.text_changed.connect(func(_text: String) -> void: _build_buttons())
	box.add_child(search_field)
	region_filter = OptionButton.new()
	region_filter.add_item("Όλη η συλλογή")
	region_filter.add_item("Κρήτη")
	region_filter.add_item("Άλλες περιοχές")
	region_filter.custom_minimum_size.y = 38
	PremiumUIStyles.apply_dropdown_style(region_filter)
	region_filter.item_selected.connect(func(_index: int) -> void: _build_buttons())
	box.add_child(region_filter)
	result_label = Label.new()
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.label_settings = _make_label_settings(12, PremiumUIStyles.TEXT_MUTED)
	box.add_child(result_label)
	results_scroll = ScrollContainer.new()
	results_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	results_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results_scroll.custom_minimum_size.y = 100
	box.add_child(results_scroll)
	button_box = VBoxContainer.new()
	button_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_box.add_theme_constant_override("separation", 8)
	results_scroll.add_child(button_box)
	_build_buttons()

	error_label = Label.new()
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.label_settings = _make_label_settings(14, Color(1.0, 0.55, 0.46, 1.0))
	box.add_child(error_label)
	set_error("")


func set_visible(is_visible: bool) -> void:
	screen.visible = is_visible
	if is_visible:
		_code_submitting = false
	elif code_field != null:
		code_field.release_focus()


func set_error(message: String) -> void:
	error_label.text = message
	error_label.visible = not message.is_empty()


func _build_sample_code_entry(box: VBoxContainer) -> void:
	code_toggle = Button.new()
	code_toggle.text = "Έχω κωδικό δείγματος"
	code_toggle.toggle_mode = true
	code_toggle.custom_minimum_size.y = 40
	PremiumUIStyles.apply_gold_outline_button(code_toggle)
	code_toggle.toggled.connect(set_code_entry_visible)
	box.add_child(code_toggle)
	code_box = VBoxContainer.new()
	code_box.name = "SampleCodeEntry"
	code_box.visible = false
	code_box.add_theme_constant_override("separation", 12)
	box.add_child(code_box)
	var hint: Label = Label.new()
	hint.text = "Πληκτρολόγησε τον κωδικό του δείγματος.\nΔοκίμασε WV-LIA-01 για το Λιάτικο της εκπαιδευτικής συλλογής."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.label_settings = _make_label_settings(15, PremiumUIStyles.TEXT_BODY)
	code_box.add_child(hint)
	code_field = LineEdit.new()
	code_field.name = "SampleCode"
	code_field.placeholder_text = "π.χ. WV-LIA-01"
	# The accepted bound is much shorter than this UI cap. Truncated oversized
	# pastes therefore remain invalid and can never become a valid prefix.
	code_field.max_length = 128
	code_field.custom_minimum_size.y = 48
	code_field.clear_button_enabled = true
	code_field.text_submitted.connect(submit_sample_code)
	code_field.text_changed.connect(func(value: String) -> void:
		_code_submitting = false
		code_submit_button.disabled = value.strip_edges().is_empty() or value.length() > 64
		if error_label != null:
			set_error("Ο κωδικός είναι πολύ μεγάλος." if value.length() > 64 else "")
	)
	code_box.add_child(code_field)
	code_submit_button = Button.new()
	code_submit_button.text = "Άνοιγμα δείγματος"
	code_submit_button.custom_minimum_size.y = 46
	code_submit_button.disabled = true
	PremiumUIStyles.apply_gold_outline_button(code_submit_button)
	code_submit_button.pressed.connect(func() -> void: submit_sample_code(code_field.text))
	code_box.add_child(code_submit_button)


func set_code_entry_visible(enabled: bool) -> void:
	code_entry_active = enabled
	code_toggle.set_pressed_no_signal(enabled)
	code_toggle.text = "Επιστροφή στη συλλογή" if enabled else "Έχω κωδικό δείγματος"
	code_box.visible = enabled
	content_scroll.scroll_vertical = 0
	for control in [search_field, region_filter, result_label, results_scroll]:
		if control != null:
			(control as Control).visible = not enabled
	set_error("")
	_code_submitting = false
	if enabled:
		code_field.call_deferred("grab_focus")
	else:
		code_field.release_focus()


func submit_sample_code(raw_code: String) -> void:
	if not code_entry_active or not screen.is_visible_in_tree() or _code_submitting:
		return
	var result: Dictionary = WineDatabase.resolve_sample_code(raw_code)
	if not bool(result.get("ok", false)):
		match str(result.get("error", "unknown")):
			"empty": set_error("Γράψε πρώτα τον κωδικό του δείγματος.")
			"too_long": set_error("Ο κωδικός είναι πολύ μεγάλος.")
			"invalid": set_error("Χρησιμοποίησε λατινικά γράμματα, αριθμούς και παύλες.")
			"duplicate": set_error("Ο κωδικός αντιστοιχεί σε περισσότερα δείγματα. Διάλεξε από τη συλλογή.")
			_: set_error("Δεν βρέθηκε αυτός ο κωδικός. Έλεγξέ τον ή διάλεξε από τη συλλογή.")
		return
	var profile_id: String = str(result.get("profile_id", ""))
	for entry in registry_entries:
		if str(entry.get("client_id", "")) == profile_id and bool(entry.get("enabled", true)):
			_code_submitting = true
			set_error("")
			code_field.release_focus()
			client_selected.emit(profile_id)
			return
	set_error("Το δείγμα δεν είναι διαθέσιμο σε αυτή τη συλλογή.")


func set_immersive_mode_available(available: bool) -> void:
	if immersive_mode_button != null:
		immersive_mode_button.visible = available
	if not available:
		set_immersive_mode_message("")


func set_immersive_mode_busy(busy: bool) -> void:
	if immersive_mode_button == null:
		return
	immersive_mode_button.disabled = busy
	immersive_mode_button.text = "Entering VR..." if busy and OS.has_feature("web") else ("Entering Immersive Mode..." if busy else _immersive_button_label())


func set_immersive_mode_active(active: bool) -> void:
	if immersive_mode_button == null:
		return
	immersive_mode_button.disabled = active
	immersive_mode_button.text = "VR Active" if active and OS.has_feature("web") else ("Immersive Mode Active" if active else _immersive_button_label())


func set_immersive_mode_message(message: String, is_error: bool = false) -> void:
	if immersive_message_label == null:
		return
	immersive_message_label.text = message
	immersive_message_label.visible = not message.is_empty()
	immersive_message_label.label_settings = _make_label_settings(14, Color(1.0, 0.55, 0.46, 1.0) if is_error else PremiumUIStyles.TEXT_MUTED)


func select_debug_index(index: int) -> void:
	if index >= 0 and index < registry_entries.size():
		client_selected.emit(str(registry_entries[index].get("client_id", "")))


func _build_buttons() -> void:
	for child in button_box.get_children():
		child.free()

	if registry_entries.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No tasting profiles are available."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.label_settings = _make_label_settings(14, Color(1.0, 0.55, 0.46, 1.0))
		button_box.add_child(empty_label)
		return

	var matches: int = 0
	for index in range(registry_entries.size()):
		var entry: Dictionary = registry_entries[index]
		if not _entry_matches(entry):
			continue
		matches += 1
		var button: Button = Button.new()
		var line_1: String = str(entry.get("display_name", ""))
		var wine_name: String = str(entry.get("wine_name", ""))
		var winery: String = str(entry.get("winery", ""))
		var region: String = str(entry.get("region", ""))
		var wine_type: String = str(entry.get("wine_type", ""))
		var line_2: String = winery
		var line_3: String = region + ("  |  " + wine_type if not wine_type.is_empty() else "")
		button.text = line_1 + "\n" + line_2 + "\n" + line_3
		button.tooltip_text = wine_name + "\n" + str(entry.get("client_id", ""))
		button.clip_text = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, 96.0)
		button.focus_mode = Control.FOCUS_ALL
		_apply_selection_button_style(button)
		button.pressed.connect(_on_button_pressed.bind(str(entry.get("client_id", ""))))
		button_box.add_child(button)
	result_label.text = "%s κρασιά · οι εκπαιδευτικές εγγραφές επισημαίνονται" % matches
	if matches == 0:
		var empty: Label = Label.new()
		empty.text = "Δεν βρέθηκε κρασί. Δοκίμασε άλλη ποικιλία ή περιοχή."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.label_settings = _make_label_settings(14, PremiumUIStyles.TEXT_BODY)
		button_box.add_child(empty)
	results_scroll.scroll_vertical = 0


func _entry_matches(entry: Dictionary) -> bool:
	var region: String = _search_key(str(entry.get("region", "")))
	var cretan: bool = "κρητ" in region or "crete" in region or "δαφν" in region
	if region_filter != null and region_filter.selected == 1 and not cretan:
		return false
	if region_filter != null and region_filter.selected == 2 and cretan:
		return false
	var query: String = _search_key(search_field.text if search_field != null else "")
	var haystack: String = _search_key(" ".join([str(entry.get("display_name", "")), str(entry.get("grape_variety", "")), region, str(entry.get("client_id", "")), str(entry.get("winery", ""))]))
	for term in query.split(" ", false):
		if not term in haystack:
			return false
	return true


func _search_key(value: String) -> String:
	var result: String = value.to_lower().strip_edges()
	for pair in [["ά", "α"], ["έ", "ε"], ["ή", "η"], ["ί", "ι"], ["ό", "ο"], ["ύ", "υ"], ["ώ", "ω"], ["ς", "σ"]]:
		result = result.replace(pair[0], pair[1])
	return result


func _on_button_pressed(client_id: String) -> void:
	client_selected.emit(client_id)


func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = PremiumUIStyles.make_panel_style(0.86)
	style.set_content_margin_all(22.0)
	return style


func _apply_selection_button_style(button: Button) -> void:
	PremiumUIStyles.apply_profile_card_button(button)


func _make_label_settings(font_size: int, font_color: Color) -> LabelSettings:
	var settings: LabelSettings = LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = font_color
	return settings


func _immersive_button_label() -> String:
	return "Enter VR (Headset)" if OS.has_feature("web") else "Enter Immersive Mode"
