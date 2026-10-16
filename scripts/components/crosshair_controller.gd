extends Control
class_name CrosshairController

const STATE_DEFAULT: String = "default"
const STATE_INTERACTABLE: String = "interactable"
const STATE_HIDDEN: String = "hidden"

var instruction_label: Label
var prompt_label: Label
var is_interactable: bool = false
var blocked_by_modal: bool = false

var _active: bool = false
var _state: String = STATE_HIDDEN
var _last_prompt_text: String = ""
var _prompt_tween: Tween
var _prompt_visible: bool = false
var _pulse_phase: float = 0.0


func setup(parent_canvas_layer: CanvasLayer) -> void:
	name = "ExploreCrosshair"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	parent_canvas_layer.add_child(self)
	_build_labels()
	set_process(true)
	hide_crosshair()


func set_active(active: bool) -> void:
	_active = active
	if not _active:
		hide_crosshair()
		return
	set_default_state()


func set_default_state() -> void:
	is_interactable = false
	_last_prompt_text = ""
	if not _active or _has_text_input_focus():
		hide_crosshair()
		return
	visible = true
	_set_prompt_visible(false)
	if instruction_label != null:
		instruction_label.visible = false
	_log_state(STATE_DEFAULT)
	queue_redraw()


func set_interactable_state(can_interact: bool, _prompt_text: String = "Interact") -> void:
	if not can_interact:
		set_default_state()
		return
	if not _active or _has_text_input_focus():
		hide_crosshair()
		return

	is_interactable = not blocked_by_modal
	visible = true
	if prompt_label != null and not blocked_by_modal:
		prompt_label.text = "Press E to inspect"
		_set_prompt_visible(true)
	else:
		_set_prompt_visible(false)
	if instruction_label != null:
		instruction_label.visible = false
	_log_state(STATE_INTERACTABLE, "Press E to inspect")
	queue_redraw()


func hide_crosshair() -> void:
	is_interactable = false
	visible = false
	_set_prompt_visible(false)
	if instruction_label != null:
		instruction_label.visible = false
	_log_state(STATE_HIDDEN)
	queue_redraw()


func set_blocked_by_modal(blocked: bool) -> void:
	blocked_by_modal = blocked
	_set_prompt_visible(false)
	if _active:
		set_default_state()


func layout(_viewport_size: Vector2) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	queue_redraw()


func _process(delta: float) -> void:
	if not visible or not _active:
		return
	_pulse_phase = fmod(_pulse_phase + delta * 3.0, TAU)
	if is_interactable and not blocked_by_modal:
		queue_redraw()


func _draw() -> void:
	if not visible or not _active:
		return
	var center: Vector2 = size * 0.5
	var show_interactable_state: bool = is_interactable and not blocked_by_modal
	var pulse: float = (sin(_pulse_phase) + 1.0) * 0.5 if show_interactable_state else 0.0
	if show_interactable_state:
		var glow_color: Color = PremiumUIStyles.GOLD_ACCENT
		draw_circle(center, 18.0 + pulse * 4.0, Color(glow_color.r, glow_color.g, glow_color.b, 0.055))
		draw_circle(center, 11.0 + pulse * 2.0, Color(glow_color.r, glow_color.g, glow_color.b, 0.09))
	var dot_alpha: float = 0.62 + pulse * 0.16 if show_interactable_state else 0.58
	var ring_alpha: float = 0.34 + pulse * 0.16 if show_interactable_state else 0.24
	var ring_radius: float = 6.0 + pulse * 1.2 if show_interactable_state else 6.0
	draw_circle(center, 2.2, Color(1.0, 0.94, 0.82, dot_alpha))
	draw_arc(center, ring_radius, 0.0, TAU, 40, Color(PremiumUIStyles.GOLD_ACCENT.r, PremiumUIStyles.GOLD_ACCENT.g, PremiumUIStyles.GOLD_ACCENT.b, ring_alpha), 1.4, true)


func _build_labels() -> void:
	instruction_label = Label.new()
	instruction_label.name = "ExploreInstruction"
	instruction_label.text = "Press Esc to open Main Menu"
	instruction_label.visible = false
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
	prompt_label.text = "Press E to inspect"
	prompt_label.visible = false
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 15)
	prompt_label.add_theme_color_override("font_color", PremiumUIStyles.TEXT_TITLE)
	prompt_label.add_theme_color_override("font_shadow_color", Color(PremiumUIStyles.GOLD_ACCENT.r, PremiumUIStyles.GOLD_ACCENT.g, PremiumUIStyles.GOLD_ACCENT.b, 0.54))
	prompt_label.add_theme_constant_override("shadow_offset_x", 0)
	prompt_label.add_theme_constant_override("shadow_offset_y", 0)
	prompt_label.add_theme_constant_override("outline_size", 1)
	prompt_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	prompt_label.anchor_left = 0.5
	prompt_label.anchor_right = 0.5
	prompt_label.anchor_top = 0.5
	prompt_label.anchor_bottom = 0.5
	prompt_label.offset_left = -140.0
	prompt_label.offset_right = 140.0
	prompt_label.offset_top = 22.0
	prompt_label.offset_bottom = 50.0
	prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_label.modulate.a = 0.0
	add_child(prompt_label)


func _set_prompt_visible(show_prompt: bool) -> void:
	if prompt_label == null:
		return
	if _prompt_visible == show_prompt and prompt_label.visible == show_prompt:
		return
	_prompt_visible = show_prompt
	if _prompt_tween != null:
		_prompt_tween.kill()
	if show_prompt:
		prompt_label.visible = true
		_prompt_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_prompt_tween.tween_property(prompt_label, "modulate:a", 1.0, 0.16)
	else:
		_prompt_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_prompt_tween.tween_property(prompt_label, "modulate:a", 0.0, 0.12)
		_prompt_tween.finished.connect(func() -> void:
			if prompt_label != null and not _prompt_visible:
				prompt_label.visible = false
		)


func _log_state(next_state: String, prompt_text: String = "") -> void:
	if _state == next_state and _last_prompt_text == prompt_text:
		return
	_state = next_state
	_last_prompt_text = prompt_text
	match _state:
		STATE_DEFAULT:
			print("[WineVR][Crosshair] default")
		STATE_INTERACTABLE:
			print("[WineVR][Crosshair] interactable: %s" % prompt_text)
		STATE_HIDDEN:
			print("[WineVR][Crosshair] hidden")


func _has_text_input_focus() -> bool:
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	return focus_owner is LineEdit or focus_owner is TextEdit
