extends Node
class_name QRScreenController

signal client_selected(client_id: String)

var screen: Control
var card: PanelContainer
var error_label: Label
var button_box: VBoxContainer
var registry_entries: Array[Dictionary] = []
var canvas_layer: CanvasLayer


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

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 2)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	card.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var title: Label = Label.new()
	title.text = "Select Your Tasting"
	title.label_settings = _make_label_settings(28, Color(0.976, 0.968, 0.941, 1.0))
	box.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "Choose a wine profile to begin"
	subtitle.label_settings = _make_label_settings(15, Color(0.84, 0.86, 0.86, 1.0))
	box.add_child(subtitle)

	button_box = VBoxContainer.new()
	button_box.add_theme_constant_override("separation", 8)
	box.add_child(button_box)
	_build_buttons()

	error_label = Label.new()
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.label_settings = _make_label_settings(14, Color(1.0, 0.55, 0.46, 1.0))
	box.add_child(error_label)


func set_visible(is_visible: bool) -> void:
	screen.visible = is_visible


func set_error(message: String) -> void:
	error_label.text = message


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

	for index in range(registry_entries.size()):
		var entry: Dictionary = registry_entries[index]
		var button: Button = Button.new()
		var line_1: String = str(entry.get("display_name", ""))
		var wine_name: String = str(entry.get("wine_name", ""))
		var winery: String = str(entry.get("winery", ""))
		var region: String = str(entry.get("region", ""))
		var wine_type: String = str(entry.get("wine_type", ""))
		var line_2: String = wine_name + "  |  " + winery
		var line_3: String = region + ("  |  " + wine_type if not wine_type.is_empty() else "")
		button.text = line_1 + "\n" + line_2 + "\n" + line_3
		button.tooltip_text = ""
		button.custom_minimum_size = Vector2(0.0, 68.0)
		button.focus_mode = Control.FOCUS_ALL
		_apply_selection_button_style(button)
		button.pressed.connect(_on_button_pressed.bind(str(entry.get("client_id", ""))))
		button_box.add_child(button)


func _on_button_pressed(client_id: String) -> void:
	client_selected.emit(client_id)


func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = PremiumUIStyles.make_panel_style(0.86)
	style.set_content_margin_all(22.0)
	return style


func _apply_selection_button_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", PremiumUIStyles.make_button_style(PremiumUIStyles.PANEL_BG_INNER, Color(PremiumUIStyles.GOLD_BORDER.r, PremiumUIStyles.GOLD_BORDER.g, PremiumUIStyles.GOLD_BORDER.b, 0.45)))
	button.add_theme_stylebox_override("hover", PremiumUIStyles.make_button_style(Color(0.12, 0.108, 0.085, 0.96), PremiumUIStyles.GOLD_BORDER))
	button.add_theme_stylebox_override("pressed", PremiumUIStyles.make_button_style(Color(0.16, 0.13, 0.075, 0.98), PremiumUIStyles.GOLD_ACCENT))
	button.add_theme_color_override("font_color", PremiumUIStyles.TEXT_TITLE)
	button.add_theme_color_override("font_hover_color", PremiumUIStyles.TEXT_TITLE)
	button.add_theme_color_override("font_pressed_color", PremiumUIStyles.TEXT_TITLE)


func _make_label_settings(font_size: int, font_color: Color) -> LabelSettings:
	var settings: LabelSettings = LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = font_color
	return settings
