extends Node
class_name LoadingOverlayController

var overlay: Control
var label: Label
var canvas_layer: CanvasLayer


func setup(parent_canvas_layer: CanvasLayer) -> void:
	canvas_layer = parent_canvas_layer
	overlay = Control.new()
	overlay.name = "LoadingOverlay"
	overlay.visible = false
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(overlay)
	canvas_layer.move_child(overlay, canvas_layer.get_child_count() - 1)

	var dimmer: ColorRect = ColorRect.new()
	dimmer.color = Color(0.0, 0.0, 0.0, 0.62)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dimmer)

	label = Label.new()
	label.text = "Loading experience"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.label_settings = _make_label_settings(20, Color(0.98, 0.95, 0.88, 1.0))
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(label)


func show_loading(message: String) -> void:
	label.text = message
	overlay.visible = true
	canvas_layer.move_child(overlay, canvas_layer.get_child_count() - 1)


func hide_loading() -> void:
	overlay.visible = false


func _make_label_settings(font_size: int, font_color: Color) -> LabelSettings:
	var settings: LabelSettings = LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = font_color
	return settings
