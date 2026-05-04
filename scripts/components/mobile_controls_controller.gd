extends Node
class_name MobileControlsController

var zoom_controls: HBoxContainer
var mobile_controls: Control
var look_pad: Control
var vial_preview: VialPreviewController
var winery_interior: WineryInteriorController
var canvas_layer: CanvasLayer


func setup(parent_canvas_layer: CanvasLayer, preview: VialPreviewController, winery: WineryInteriorController) -> void:
	canvas_layer = parent_canvas_layer
	vial_preview = preview
	winery_interior = winery
	_build_zoom_controls()
	_build_mobile_winery_controls()


func set_zoom_visible(is_visible: bool) -> void:
	zoom_controls.visible = is_visible


func set_winery_controls_visible(is_visible: bool) -> void:
	mobile_controls.visible = is_visible
	_hide_move_pad()


func layout(viewport_size: Vector2, margin: float) -> void:
	zoom_controls.position = Vector2(viewport_size.x - 146.0 - margin, viewport_size.y - 64.0)
	zoom_controls.size = Vector2(146.0, 48.0)
	mobile_controls.position = Vector2.ZERO
	mobile_controls.size = viewport_size

	var move_pad: Control = mobile_controls.get_node_or_null("MovePad") as Control
	if move_pad != null:
		move_pad.visible = false
		move_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		move_pad.position = Vector2(margin, viewport_size.y - 132.0)
		move_pad.size = Vector2.ZERO

	if look_pad == null:
		return
	if viewport_size.x < 560.0:
		look_pad.position = Vector2(margin, maxf(margin, viewport_size.y - 286.0))
		look_pad.size = Vector2(viewport_size.x - margin * 2.0, 126.0)
	else:
		var look_pad_width: float = maxf(180.0, viewport_size.x - 280.0)
		look_pad.position = Vector2(viewport_size.x - look_pad_width - margin, viewport_size.y - 164.0)
		look_pad.size = Vector2(look_pad_width, 150.0)


func _build_zoom_controls() -> void:
	zoom_controls = HBoxContainer.new()
	zoom_controls.name = "VialZoomControls"
	zoom_controls.visible = false
	zoom_controls.add_theme_constant_override("separation", 10)
	canvas_layer.add_child(zoom_controls)

	var zoom_out_button: Button = Button.new()
	zoom_out_button.text = "-"
	zoom_out_button.custom_minimum_size = Vector2(68.0, 48.0)
	zoom_out_button.pressed.connect(vial_preview.zoom_out)
	zoom_controls.add_child(zoom_out_button)

	var zoom_in_button: Button = Button.new()
	zoom_in_button.text = "+"
	zoom_in_button.custom_minimum_size = Vector2(68.0, 48.0)
	zoom_in_button.pressed.connect(vial_preview.zoom_in)
	zoom_controls.add_child(zoom_in_button)


func _build_mobile_winery_controls() -> void:
	mobile_controls = Control.new()
	mobile_controls.name = "MobileWineryControls"
	mobile_controls.visible = false
	mobile_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(mobile_controls)

	var pad: Control = Control.new()
	pad.name = "MovePad"
	pad.visible = false
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mobile_controls.add_child(pad)

	_add_move_button(pad, "forward", "^", Vector2(70.0, 0.0))
	_add_move_button(pad, "left", "<", Vector2(0.0, 58.0))
	_add_move_button(pad, "back", "v", Vector2(70.0, 58.0))
	_add_move_button(pad, "right", ">", Vector2(140.0, 58.0))

	look_pad = ColorRect.new()
	look_pad.name = "LookPad"
	(look_pad as ColorRect).color = Color(0.0, 0.0, 0.0, 0.0)
	look_pad.mouse_filter = Control.MOUSE_FILTER_STOP
	look_pad.gui_input.connect(_on_look_pad_input)
	mobile_controls.add_child(look_pad)
	_hide_move_pad()


func _add_move_button(parent: Control, axis: String, label: String, button_position: Vector2) -> void:
	var button: Button = Button.new()
	button.text = label
	button.position = button_position
	button.custom_minimum_size = Vector2(56.0, 52.0)
	button.visible = false
	button.disabled = true
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.button_down.connect(winery_interior.set_mobile_move_axis.bind(axis, true))
	button.button_up.connect(winery_interior.set_mobile_move_axis.bind(axis, false))
	parent.add_child(button)


func _on_look_pad_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		winery_interior.handle_look_drag(event.relative)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		winery_interior.handle_look_drag(event.relative)


func _hide_move_pad() -> void:
	if mobile_controls == null:
		return
	var move_pad: Control = mobile_controls.get_node_or_null("MovePad") as Control
	if move_pad == null:
		return
	move_pad.visible = false
	move_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in move_pad.get_children():
		if child is Control:
			var control: Control = child as Control
			control.visible = false
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if child is BaseButton:
			(child as BaseButton).disabled = true
