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

	var title: Label = Label.new()
	title.text = "How to explore"
	title.label_settings = _make_label_settings(24, Color(0.976, 0.968, 0.941, 1.0))
	box.add_child(title)

	for text in [
		"Drag the vial to inspect it",
		"Tap glowing points to reveal wine details",
		"Enter the winery to continue the guided tasting"
	]:
		var label: Label = Label.new()
		label.text = text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.label_settings = _make_label_settings(15, Color(0.86, 0.86, 0.82, 1.0))
		box.add_child(label)

	var button: Button = Button.new()
	button.text = "Got it"
	button.custom_minimum_size = Vector2(0.0, 46.0)
	button.pressed.connect(hide)
	box.add_child(button)


func layout(viewport_size: Vector2) -> void:
	var width: float = minf(390.0, viewport_size.x - 28.0)
	var height: float = minf(265.0, viewport_size.y - 28.0)
	card.position = (viewport_size - Vector2(width, height)) * 0.5
	card.size = Vector2(width, height)


func show_once() -> void:
	if has_shown:
		return
	has_shown = true
	overlay.visible = true
	canvas_layer.move_child(overlay, canvas_layer.get_child_count() - 1)


func hide() -> void:
	overlay.visible = false


func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0352941, 0.0392157, 0.0470588, 0.96)
	style.border_color = Color(0.92, 0.76, 0.45, 0.32)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	return style


func _make_label_settings(font_size: int, font_color: Color) -> LabelSettings:
	var settings: LabelSettings = LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = font_color
	return settings
