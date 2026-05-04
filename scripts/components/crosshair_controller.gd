extends Control
class_name CrosshairController

var instruction_label: Label
var prompt_label: Label
var is_interactable: bool = false


func setup(parent_canvas_layer: CanvasLayer) -> void:
	name = "ExploreCrosshair"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	parent_canvas_layer.add_child(self)
	_build_labels()


func set_active(active: bool) -> void:
	visible = active
	is_interactable = false
	if prompt_label != null:
		prompt_label.visible = false
	if instruction_label != null:
		instruction_label.visible = active
	queue_redraw()


func set_interactable_state(can_interact: bool, prompt_text: String = "Click to interact") -> void:
	is_interactable = can_interact
	if prompt_label != null:
		prompt_label.text = prompt_text
		prompt_label.visible = visible and can_interact
	queue_redraw()


func layout(_viewport_size: Vector2) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var center: Vector2 = size * 0.5
	if is_interactable:
		draw_circle(center, 8.0, Color(PremiumUIStyles.GOLD_ACCENT.r, PremiumUIStyles.GOLD_ACCENT.g, PremiumUIStyles.GOLD_ACCENT.b, 0.92))
		draw_circle(center, 5.0, Color(1.0, 1.0, 1.0, 0.92))
	else:
		draw_circle(center, 7.0, Color(0.0, 0.0, 0.0, 0.9))
		draw_circle(center, 5.0, Color(1.0, 1.0, 1.0, 0.9))


func _build_labels() -> void:
	instruction_label = Label.new()
	instruction_label.name = "ExploreInstruction"
	instruction_label.text = "Press ESC to exit Explore Mode"
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.add_theme_color_override("font_color", PremiumUIStyles.TEXT_TITLE)
	instruction_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	instruction_label.add_theme_constant_override("shadow_offset_x", 1)
	instruction_label.add_theme_constant_override("shadow_offset_y", 1)
	instruction_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	instruction_label.offset_left = 0.0
	instruction_label.offset_right = 0.0
	instruction_label.offset_top = -52.0
	instruction_label.offset_bottom = -24.0
	instruction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(instruction_label)

	prompt_label = Label.new()
	prompt_label.name = "InteractPrompt"
	prompt_label.text = "Click to interact"
	prompt_label.visible = false
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_color_override("font_color", PremiumUIStyles.GOLD_ACCENT)
	prompt_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	prompt_label.add_theme_constant_override("shadow_offset_x", 1)
	prompt_label.add_theme_constant_override("shadow_offset_y", 1)
	prompt_label.anchor_left = 0.5
	prompt_label.anchor_right = 0.5
	prompt_label.anchor_top = 0.5
	prompt_label.anchor_bottom = 0.5
	prompt_label.offset_left = -120.0
	prompt_label.offset_right = 120.0
	prompt_label.offset_top = 18.0
	prompt_label.offset_bottom = 44.0
	prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prompt_label)
