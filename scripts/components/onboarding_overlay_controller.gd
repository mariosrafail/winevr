extends Node
class_name OnboardingOverlayController

var overlay: Control
var card: PanelContainer
var has_shown: bool = false
var canvas_layer: CanvasLayer


func setup(parent_canvas_layer: CanvasLayer) -> void:
	canvas_layer = parent_canvas_layer
	overlay = Control.new()
	overlay.name = "OnboardingOverlay"
	overlay.visible = false
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 70
	canvas_layer.add_child(overlay)

	var dimmer: ColorRect = ColorRect.new()
	dimmer.color = Color(0.0, 0.0, 0.0, 0.66)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dimmer)

	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _make_panel_style())
	overlay.add_child(card)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	card.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	PremiumUIStyles.apply_panel_chrome_to_vbox(box)

	var title: Label = Label.new()
	title.text = "How to explore"
	title.label_settings = _make_label_settings(24, PremiumUIStyles.TEXT_TITLE)
	box.add_child(title)

	for text in [
		"Drag the vial to inspect it",
		"Tap glowing points to reveal wine details",
		"Enter the winery to continue the guided tasting"
	]:
		var label: Label = Label.new()
		label.text = text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.label_settings = _make_label_settings(15, PremiumUIStyles.TEXT_BODY)
		box.add_child(label)

	var button: Button = Button.new()
	button.text = "Got it"
	button.custom_minimum_size = Vector2(0.0, 46.0)
	PremiumUIStyles.apply_gold_outline_button(button)
	button.pressed.connect(hide)
	box.add_child(button)


func layout(viewport_size: Vector2) -> void:
	var edge_margin: float = 18.0 if viewport_size.x >= 760.0 else 12.0
	var width: float = minf(420.0, viewport_size.x - edge_margin * 2.0)
	var height: float = minf(285.0, viewport_size.y - edge_margin * 2.0)
	card.position = (viewport_size - Vector2(width, height)) * 0.5
	card.size = Vector2(width, height)


func show_once() -> void:
	if has_shown:
		return
	has_shown = true
	overlay.visible = true
	canvas_layer.move_child(overlay, canvas_layer.get_child_count() - 1)
	PremiumUIStyles.animate_panel_open(card, 10.0)


func hide() -> void:
	overlay.visible = false


func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = PremiumUIStyles.make_panel_style(0.94)
	style.set_content_margin_all(18.0)
	return style


func _make_label_settings(font_size: int, font_color: Color) -> LabelSettings:
	var settings: LabelSettings = LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = font_color
	return settings
