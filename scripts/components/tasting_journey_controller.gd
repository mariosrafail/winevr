extends Node
class_name TastingJourneyController

signal active_step_changed(step: Dictionary)
signal journey_completed
signal restart_requested
signal choose_another_requested
signal show_qr_requested
signal cellar_requested
signal layout_refresh_requested(reason: String)
signal journey_modal_opened(id: String)
signal journey_modal_closed(id: String)

var canvas_layer: CanvasLayer
var progress_panel: PanelContainer
var title_label: Label
var count_label: Label
var dots_row: HBoxContainer
var tasting_card_button: Button
var tasting_card_panel: PanelContainer
var tasting_card_text: RichTextLabel
var tasting_card_close: Button
var completion_panel: PanelContainer
var completion_title: Label
var completion_body: RichTextLabel
var restart_button: Button
var choose_button: Button
var show_qr_button: Button
var cellar_button: Button
var continue_button: Button

var steps: Array[Dictionary] = []
var completed_ids: Dictionary = {}
var current_index: int = 0
var active: bool = false
var selected_profile: Dictionary = {}
var runtime_profile: Dictionary = {}


func setup(parent_canvas_layer: CanvasLayer) -> void:
	canvas_layer = parent_canvas_layer
	_build_progress_ui()
	_build_tasting_card_panel()
	_build_completion_panel()


func configure_from_profile(profile_data: Dictionary, client_data: Dictionary = {}) -> void:
	selected_profile = profile_data.duplicate(true)
	runtime_profile = client_data.duplicate(true)
	steps.clear()
	completed_ids.clear()
	current_index = 0
	if show_qr_button != null:
		show_qr_button.visible = not bool(selected_profile.get("demo_collection", client_data.get("demo_collection", false)))

	var raw_hotspots: Array = []
	if selected_profile.has("hotspots") and typeof(selected_profile.get("hotspots")) == TYPE_ARRAY:
		raw_hotspots = selected_profile.get("hotspots") as Array
	elif client_data.has("experience_settings"):
		var experience_settings: Dictionary = client_data.get("experience_settings", {})
		if typeof(experience_settings.get("hotspots", [])) == TYPE_ARRAY:
			raw_hotspots = experience_settings.get("hotspots", []) as Array

	var sorted_hotspots: Array = raw_hotspots.duplicate(true)
	sorted_hotspots.sort_custom(func(a: Variant, b: Variant) -> bool:
		var order_a: int = 999
		var order_b: int = 999
		if typeof(a) == TYPE_DICTIONARY:
			order_a = int((a as Dictionary).get("order", 999))
		if typeof(b) == TYPE_DICTIONARY:
			order_b = int((b as Dictionary).get("order", 999))
		return order_a < order_b
	)

	for index in range(sorted_hotspots.size()):
		if typeof(sorted_hotspots[index]) != TYPE_DICTIONARY:
			continue
		var raw_step: Dictionary = (sorted_hotspots[index] as Dictionary).duplicate(true)
		var step_id: String = str(raw_step.get("id", "step_%s" % index))
		steps.append({
			"id": step_id,
			"title": str(raw_step.get("title", "Tasting Step")),
			"description": str(raw_step.get("description", raw_step.get("text", ""))),
			"order": int(raw_step.get("order", index + 1)),
			"completion_required": bool(raw_step.get("completion_required", raw_step.get("viewed_required_for_winery", true))),
			"category": _infer_category(raw_step)
		})

	active = not steps.is_empty()
	progress_panel.visible = not steps.is_empty()
	tasting_card_button.visible = not steps.is_empty()
	_hide_completion_panel()
	_hide_tasting_card()
	_emit_active_step()
	_update_progress_ui()
	layout_refresh_requested.emit("panel opened")


func set_visible_for_state(is_visible: bool) -> void:
	if progress_panel != null:
		progress_panel.visible = not steps.is_empty() and is_visible
	if tasting_card_button != null:
		tasting_card_button.visible = not steps.is_empty() and is_visible
	if not is_visible:
		_hide_tasting_card()
		_hide_completion_panel()


func close_open_modal() -> bool:
	if tasting_card_panel != null and tasting_card_panel.visible:
		_hide_tasting_card()
		return true
	if completion_panel != null and completion_panel.visible:
		_hide_completion_panel()
		return true
	return false


func close_tasting_card() -> void:
	_hide_tasting_card()


func close_completion_panel() -> void:
	_hide_completion_panel()


func complete_hotspot(hotspot_id: String) -> void:
	if hotspot_id.is_empty():
		return
	# Optional discoveries remain collectible after the required route unlocks.
	if not active:
		if _required_steps_complete():
			for step in steps:
				if str(step.get("id", "")) == hotspot_id:
					completed_ids[hotspot_id] = true
					_update_progress_ui()
		return
	if current_index < 0 or current_index >= steps.size():
		return
	var current_step: Dictionary = steps[current_index]
	if str(current_step.get("id", "")) != hotspot_id:
		return

	completed_ids[hotspot_id] = true
	var completed_index: int = current_index
	current_index += 1
	_update_progress_ui()
	_animate_completed_dot(completed_index)

	if _required_steps_complete():
		active = false
		active_step_changed.emit({})
		_update_progress_ui()
		_show_completion_panel()
		journey_completed.emit()
		layout_refresh_requested.emit("panel opened")
		return

	_skip_completed_steps()
	_emit_active_step()
	_update_progress_ui()


func get_active_step_id() -> String:
	if not active or current_index < 0 or current_index >= steps.size():
		return ""
	return str(steps[current_index].get("id", ""))


func get_active_step() -> Dictionary:
	if not active or current_index < 0 or current_index >= steps.size():
		return {}
	return steps[current_index].duplicate(true)


func get_completed_ids() -> Dictionary:
	return completed_ids.duplicate(true)


func layout(viewport_size: Vector2) -> void:
	var margin: float = 20.0 if viewport_size.x >= 760.0 else 12.0
	var compact: bool = viewport_size.x < 700.0
	if progress_panel != null:
		var width: float = minf(340.0, viewport_size.x - margin * 2.0)
		var height: float = 90.0
		progress_panel.size = Vector2(width, height)
		progress_panel.position = Vector2(viewport_size.x - width - margin, 88.0 if compact else margin)
	if tasting_card_button != null:
		tasting_card_button.size = Vector2(152.0, 42.0)
		tasting_card_button.position = Vector2(viewport_size.x - tasting_card_button.size.x - margin, (88.0 if compact else margin) + 102.0)
	if tasting_card_panel != null and tasting_card_panel.visible:
		_size_modal(tasting_card_panel, viewport_size, Vector2(560, 480))
	if completion_panel != null and completion_panel.visible:
		_size_modal(completion_panel, viewport_size, Vector2(560, 500))


func _size_modal(panel: PanelContainer, viewport_size: Vector2, preferred: Vector2) -> void:
	panel.custom_minimum_size = Vector2.ZERO
	panel.size = Vector2(minf(preferred.x, viewport_size.x - 24.0), minf(preferred.y, viewport_size.y - 132.0))
	panel.position = Vector2((viewport_size.x - panel.size.x) * 0.5, maxf(86.0, (viewport_size.y - panel.size.y) * 0.5))


func _build_progress_ui() -> void:
	progress_panel = PanelContainer.new()
	progress_panel.name = "TastingJourneyProgress"
	progress_panel.visible = false
	progress_panel.z_index = 96
	progress_panel.add_theme_stylebox_override("panel", PremiumUIStyles.make_panel_style(0.88))
	canvas_layer.add_child(progress_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	progress_panel.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	PremiumUIStyles.apply_panel_chrome_to_vbox(box)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)

	title_label = Label.new()
	title_label.text = "Η διαδρομή του κρασιού"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_color_override("font_color", PremiumUIStyles.TEXT_TITLE)
	header.add_child(title_label)

	count_label = Label.new()
	count_label.text = "0/0"
	count_label.add_theme_color_override("font_color", PremiumUIStyles.GOLD_ACCENT)
	header.add_child(count_label)

	dots_row = HBoxContainer.new()
	dots_row.add_theme_constant_override("separation", 5)
	box.add_child(dots_row)

	tasting_card_button = Button.new()
	tasting_card_button.name = "TastingCardButton"
	tasting_card_button.text = "Οι σημειώσεις μου"
	tasting_card_button.visible = false
	tasting_card_button.z_index = 96
	tasting_card_button.pressed.connect(_show_tasting_card)
	PremiumUIStyles.apply_gold_outline_button(tasting_card_button)
	canvas_layer.add_child(tasting_card_button)


func _build_tasting_card_panel() -> void:
	tasting_card_panel = PanelContainer.new()
	tasting_card_panel.name = "TastingCardPanel"
	tasting_card_panel.visible = false
	tasting_card_panel.z_index = 101
	tasting_card_panel.add_theme_stylebox_override("panel", PremiumUIStyles.make_panel_style(1.0))
	canvas_layer.add_child(tasting_card_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	tasting_card_panel.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	PremiumUIStyles.apply_panel_chrome_to_vbox(box)

	var title: Label = Label.new()
	title.text = "ΟΙ ΑΝΑΚΑΛΥΨΕΙΣ ΣΟΥ"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", PremiumUIStyles.TEXT_TITLE)
	box.add_child(title)

	tasting_card_text = RichTextLabel.new()
	tasting_card_text.bbcode_enabled = true
	tasting_card_text.fit_content = false
	tasting_card_text.scroll_active = true
	tasting_card_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tasting_card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tasting_card_text.custom_minimum_size = Vector2(0.0, 72.0)
	tasting_card_text.add_theme_font_size_override("normal_font_size", 16)
	tasting_card_text.add_theme_color_override("default_color", PremiumUIStyles.TEXT_BODY)
	box.add_child(tasting_card_text)

	tasting_card_close = Button.new()
	tasting_card_close.text = "Συνέχεια στη διαδρομή"
	tasting_card_close.custom_minimum_size = Vector2(0.0, 42.0)
	tasting_card_close.pressed.connect(_hide_tasting_card)
	PremiumUIStyles.apply_gold_outline_button(tasting_card_close)
	box.add_child(tasting_card_close)


func _build_completion_panel() -> void:
	completion_panel = PanelContainer.new()
	completion_panel.name = "TastingJourneyCompletion"
	completion_panel.visible = false
	completion_panel.z_index = 102
	completion_panel.add_theme_stylebox_override("panel", PremiumUIStyles.make_panel_style(1.0))
	canvas_layer.add_child(completion_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	completion_panel.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	PremiumUIStyles.apply_panel_chrome_to_vbox(box)

	completion_title = Label.new()
	completion_title.text = "ΤΟ ΚΡΑΣΙ ΕΧΕΙ ΜΙΑ ΙΣΤΟΡΙΑ"
	completion_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	completion_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	completion_title.add_theme_color_override("font_color", PremiumUIStyles.TEXT_TITLE)
	box.add_child(completion_title)

	completion_body = RichTextLabel.new()
	completion_body.bbcode_enabled = false
	completion_body.fit_content = false
	completion_body.scroll_active = true
	completion_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	completion_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	completion_body.custom_minimum_size = Vector2(0.0, 72.0)
	completion_body.add_theme_font_size_override("normal_font_size", 16)
	completion_body.add_theme_color_override("default_color", PremiumUIStyles.TEXT_BODY)
	box.add_child(completion_body)

	cellar_button = _make_modal_button("Συνέχεια στο κελάρι →")
	cellar_button.pressed.connect(func() -> void:
		if not _required_steps_complete():
			return
		_hide_completion_panel()
		cellar_requested.emit()
	)
	box.add_child(cellar_button)
	continue_button = _make_modal_button("Ανακάλυψε και το επιπλέον σημείο")
	continue_button.pressed.connect(_continue_optional_steps)
	box.add_child(continue_button)
	var buttons: GridContainer = GridContainer.new()
	buttons.columns = 2
	buttons.add_theme_constant_override("separation", 10)
	buttons.add_theme_constant_override("h_separation", 10)
	buttons.add_theme_constant_override("v_separation", 8)
	box.add_child(buttons)

	restart_button = _make_modal_button("Από την αρχή")
	restart_button.pressed.connect(func() -> void:
		_hide_completion_panel()
		restart_requested.emit()
	)
	buttons.add_child(restart_button)

	choose_button = _make_modal_button("Άλλο κρασί")
	choose_button.pressed.connect(func() -> void:
		_hide_completion_panel()
		choose_another_requested.emit()
	)
	buttons.add_child(choose_button)

	show_qr_button = _make_modal_button("Πληροφορίες QR")
	show_qr_button.pressed.connect(func() -> void:
		_hide_completion_panel()
		show_qr_requested.emit()
	)
	buttons.add_child(show_qr_button)


func _make_modal_button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 42.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PremiumUIStyles.apply_gold_outline_button(button)
	return button


func _update_progress_ui() -> void:
	if title_label == null or count_label == null:
		return
	var step_title: String = "Η διαδρομή ολοκληρώθηκε"
	if active and current_index >= 0 and current_index < steps.size():
		step_title = str(steps[current_index].get("title", "Tasting Step"))
	title_label.text = step_title
	count_label.text = "%s/%s" % [completed_ids.size(), steps.size()]
	_rebuild_dots()
	_update_tasting_card_text()


func _rebuild_dots() -> void:
	for child in dots_row.get_children():
		child.free()
	for index in range(steps.size()):
		var step: Dictionary = steps[index]
		var dot: ColorRect = ColorRect.new()
		dot.name = "StepDot_%s" % index
		dot.custom_minimum_size = Vector2(34.0, 5.0)
		var step_id: String = str(step.get("id", ""))
		if completed_ids.has(step_id):
			dot.color = PremiumUIStyles.GOLD_ACCENT
		elif index == current_index and active:
			dot.color = Color(1.0, 0.93, 0.72, 0.92)
		else:
			dot.color = Color(PremiumUIStyles.TEXT_MUTED.r, PremiumUIStyles.TEXT_MUTED.g, PremiumUIStyles.TEXT_MUTED.b, 0.32)
		dots_row.add_child(dot)


func _animate_completed_dot(index: int) -> void:
	if dots_row == null or index < 0 or index >= dots_row.get_child_count():
		return
	var dot: Control = dots_row.get_child(index) as Control
	if dot == null:
		return
	dot.pivot_offset = dot.size * 0.5
	var tween: Tween = dot.create_tween()
	tween.tween_property(dot, "scale", Vector2(1.18, 1.6), 0.12)
	tween.tween_property(dot, "scale", Vector2.ONE, 0.14)


func _show_tasting_card() -> void:
	_update_tasting_card_text()
	tasting_card_panel.visible = true
	journey_modal_opened.emit("journey_card")
	layout(tasting_card_panel.get_viewport().get_visible_rect().size)
	PremiumUIStyles.animate_panel_open(tasting_card_panel, 10.0)


func _hide_tasting_card() -> void:
	if tasting_card_panel != null:
		var was_visible: bool = tasting_card_panel.visible
		tasting_card_panel.visible = false
		if was_visible:
			journey_modal_closed.emit("journey_card")


func _show_completion_panel() -> void:
	_update_completion_text()
	completion_panel.visible = true
	journey_modal_opened.emit("journey_completion")
	layout(completion_panel.get_viewport().get_visible_rect().size)
	PremiumUIStyles.animate_panel_open(completion_panel, 10.0)


func _hide_completion_panel() -> void:
	if completion_panel != null:
		var was_visible: bool = completion_panel.visible
		completion_panel.visible = false
		if was_visible:
			journey_modal_closed.emit("journey_completion")


func _update_tasting_card_text() -> void:
	if tasting_card_text == null:
		return
	var lines: Array[String] = []
	var wine: String = str(selected_profile.get("name", runtime_profile.get("wine_name", "")))
	lines.append("[b]" + _escape_bbcode(wine) + "[/b]\n")
	for discovery in steps:
		var step_id: String = str(discovery.get("id", ""))
		var is_complete: bool = completed_ids.has(step_id)
		var label_color: String = "#D6B15E" if is_complete else "#9C927F"
		var body_color: String = "#D9D1C0" if is_complete else "#9C927F"
		var body: String = str(discovery.get("description", "")) if is_complete else "Άνοιξε αυτό το σημείο στη διαδρομή."
		var title: String = ("✓ " if is_complete else "○ ") + str(discovery.get("title", "Σημείο"))
		lines.append("[color=%s][b]%s[/b][/color]\n[color=%s]%s[/color]" % [label_color, _escape_bbcode(title), body_color, _escape_bbcode(body)])
	tasting_card_text.text = "\n\n".join(lines)


func _escape_bbcode(value: String) -> String:
	return value.replace("[", "[lb]")


func _update_completion_text() -> void:
	var wine_name: String = str(selected_profile.get("name", runtime_profile.get("wine_name", "Selected Wine")))
	var region: String = str(selected_profile.get("region", runtime_profile.get("region_name", "")))
	completion_body.text = "%s\n%s\n\nΣημεία που ανακάλυψες: %s/%s\nΗ συνέχεια σε περιμένει στο κελάρι." % [
		wine_name,
		region,
		str(completed_ids.size()),
		str(steps.size())
	]
	continue_button.visible = completed_ids.size() < steps.size()
	cellar_button.disabled = not _required_steps_complete()
	show_qr_button.visible = not bool(selected_profile.get("demo_collection", runtime_profile.get("demo_collection", false)))


func _continue_optional_steps() -> void:
	_hide_completion_panel()
	current_index = 0
	_skip_completed_steps()
	active = current_index < steps.size()
	_emit_active_step()
	_update_progress_ui()


func _emit_active_step() -> void:
	if not active or current_index < 0 or current_index >= steps.size():
		active_step_changed.emit({})
		return
	active_step_changed.emit(steps[current_index].duplicate(true))


func _required_steps_complete() -> bool:
	for step: Dictionary in steps:
		if bool(step.get("completion_required", true)) and not completed_ids.has(str(step.get("id", ""))):
			return false
	return true


func _skip_completed_steps() -> void:
	while current_index < steps.size() and completed_ids.has(str(steps[current_index].get("id", ""))):
		current_index += 1
	if current_index >= steps.size():
		active = false


func _find_step_for_category(category: String) -> Dictionary:
	for step: Dictionary in steps:
		if str(step.get("category", "")) == category:
			return step
	return {}


func _infer_category(step: Dictionary) -> String:
	var haystack: String = (str(step.get("id", "")) + " " + str(step.get("title", "")) + " " + str(step.get("description", "")) + " " + str(step.get("text", ""))).to_lower()
	if haystack.contains("color") or haystack.contains("origin") or haystack.contains("body"):
		return "Color"
	if haystack.contains("aroma") or haystack.contains("nose"):
		return "Aroma"
	if haystack.contains("texture") or haystack.contains("structure") or haystack.contains("tannin"):
		return "Texture"
	if haystack.contains("pairing") or haystack.contains("food"):
		return "Pairing"
	if haystack.contains("story") or haystack.contains("estate"):
		return "Story"
	return "Story"
