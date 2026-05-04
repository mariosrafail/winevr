extends RefCounted
class_name PremiumUIStyles

const PANEL_BG: Color = Color(0.066, 0.062, 0.051, 0.86)
const PANEL_BG_INNER: Color = Color(0.094, 0.086, 0.071, 0.92)
const PANEL_BG_HOVER: Color = Color(0.13, 0.118, 0.092, 0.96)
const GOLD_BORDER: Color = Color(0.784, 0.655, 0.353, 0.65)
const GOLD_ACCENT: Color = Color(0.839, 0.694, 0.369, 1.0)
const GOLD_GLOW: Color = Color(0.839, 0.694, 0.369, 0.28)
const TEXT_TITLE: Color = Color(0.961, 0.937, 0.89, 1.0)
const TEXT_BODY: Color = Color(0.851, 0.82, 0.753, 1.0)
const TEXT_MUTED: Color = Color(0.655, 0.612, 0.537, 1.0)
const SHADOW: Color = Color(0.0, 0.0, 0.0, 0.36)

const HOVER_SCALE: Vector2 = Vector2(1.03, 1.03)
const PRESSED_SCALE: Vector2 = Vector2(0.98, 0.98)
const NORMAL_SCALE: Vector2 = Vector2.ONE


static func make_panel_style(alpha: float = 0.86) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(PANEL_BG.r, PANEL_BG.g, PANEL_BG.b, alpha)
	style.border_color = GOLD_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.shadow_color = SHADOW
	style.shadow_size = 12
	style.shadow_offset = Vector2(0.0, 3.0)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style


static func make_button_style(background: Color, border: Color = GOLD_BORDER, shadow_alpha: float = 0.0) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8.0)
	if shadow_alpha > 0.0:
		style.shadow_color = Color(GOLD_ACCENT.r, GOLD_ACCENT.g, GOLD_ACCENT.b, shadow_alpha)
		style.shadow_size = 8
		style.shadow_offset = Vector2.ZERO
	return style


static func apply_gold_outline_button(button: Button) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", make_button_style(Color(PANEL_BG.r, PANEL_BG.g, PANEL_BG.b, 0.7), Color(GOLD_BORDER.r, GOLD_BORDER.g, GOLD_BORDER.b, 0.55)))
	button.add_theme_stylebox_override("hover", make_button_style(PANEL_BG_HOVER, GOLD_ACCENT, 0.16))
	button.add_theme_stylebox_override("pressed", make_button_style(Color(0.16, 0.13, 0.075, 0.98), GOLD_ACCENT, 0.08))
	button.add_theme_stylebox_override("focus", make_button_style(Color(PANEL_BG.r, PANEL_BG.g, PANEL_BG.b, 0.78), Color(GOLD_ACCENT.r, GOLD_ACCENT.g, GOLD_ACCENT.b, 0.9), 0.12))
	button.add_theme_stylebox_override("disabled", make_button_style(Color(0.05, 0.052, 0.058, 0.55), Color(GOLD_BORDER.r, GOLD_BORDER.g, GOLD_BORDER.b, 0.18)))
	button.add_theme_color_override("font_color", TEXT_TITLE)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.68, 1.0))
	button.add_theme_color_override("font_pressed_color", TEXT_TITLE)
	button.add_theme_color_override("font_focus_color", TEXT_TITLE)
	button.add_theme_color_override("font_disabled_color", Color(TEXT_MUTED.r, TEXT_MUTED.g, TEXT_MUTED.b, 0.72))
	_connect_button_motion(button)


static func apply_profile_card_button(button: Button) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", make_button_style(PANEL_BG_INNER, Color(GOLD_BORDER.r, GOLD_BORDER.g, GOLD_BORDER.b, 0.42), 0.02))
	button.add_theme_stylebox_override("hover", make_button_style(PANEL_BG_HOVER, Color(GOLD_ACCENT.r, GOLD_ACCENT.g, GOLD_ACCENT.b, 0.86), 0.14))
	button.add_theme_stylebox_override("pressed", make_button_style(Color(0.16, 0.13, 0.075, 0.98), GOLD_ACCENT, 0.1))
	button.add_theme_stylebox_override("focus", make_button_style(PANEL_BG_HOVER, GOLD_ACCENT, 0.16))
	button.add_theme_color_override("font_color", TEXT_TITLE)
	button.add_theme_color_override("font_hover_color", TEXT_TITLE)
	button.add_theme_color_override("font_pressed_color", TEXT_TITLE)
	button.add_theme_color_override("font_focus_color", TEXT_TITLE)
	_connect_button_motion(button)


static func apply_dropdown_style(dropdown: OptionButton) -> void:
	if dropdown == null:
		return
	apply_gold_outline_button(dropdown)
	dropdown.add_theme_color_override("font_color", TEXT_BODY)
	dropdown.add_theme_color_override("font_hover_color", TEXT_TITLE)
	var popup: PopupMenu = dropdown.get_popup()
	if popup != null:
		popup.add_theme_stylebox_override("panel", make_panel_style(0.94))
		popup.add_theme_stylebox_override("hover", make_button_style(PANEL_BG_HOVER, Color(GOLD_ACCENT.r, GOLD_ACCENT.g, GOLD_ACCENT.b, 0.55), 0.08))
		popup.add_theme_color_override("font_color", TEXT_BODY)
		popup.add_theme_color_override("font_hover_color", TEXT_TITLE)
		popup.add_theme_color_override("font_disabled_color", TEXT_MUTED)


static func apply_panel_chrome_to_vbox(vbox: VBoxContainer) -> void:
	if vbox == null:
		return
	if vbox.get_node_or_null("PremiumTopAccent") == null:
		var top_accent: ColorRect = ColorRect.new()
		top_accent.name = "PremiumTopAccent"
		top_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_accent.color = Color(GOLD_ACCENT.r, GOLD_ACCENT.g, GOLD_ACCENT.b, 0.82)
		top_accent.custom_minimum_size = Vector2(0.0, 2.0)
		vbox.add_child(top_accent)
		vbox.move_child(top_accent, 0)
	if vbox.get_node_or_null("PremiumDivider") == null:
		var divider: ColorRect = ColorRect.new()
		divider.name = "PremiumDivider"
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		divider.color = Color(GOLD_ACCENT.r, GOLD_ACCENT.g, GOLD_ACCENT.b, 0.22)
		divider.custom_minimum_size = Vector2(0.0, 1.0)
		vbox.add_child(divider)
		var insert_index: int = mini(3, max(0, vbox.get_child_count() - 1))
		vbox.move_child(divider, insert_index)


static func animate_panel_open(panel: Control, offset_y: float = 10.0) -> Tween:
	if panel == null:
		return null
	if panel.has_meta("premium_panel_tween") and panel.get_meta("premium_panel_tween") is Tween:
		(panel.get_meta("premium_panel_tween") as Tween).kill()
	var target_position: Vector2 = panel.position
	panel.position = target_position + Vector2(0.0, offset_y)
	panel.modulate.a = 0.0
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.98, 0.98)
	var tween: Tween = panel.create_tween()
	panel.set_meta("premium_panel_tween", tween)
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "position", target_position, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tween


static func _connect_button_motion(button: Button) -> void:
	if button.has_meta("premium_motion_connected"):
		return
	button.set_meta("premium_motion_connected", true)
	button.mouse_entered.connect(func() -> void:
		_tween_control_scale(button, HOVER_SCALE, 0.12)
	)
	button.mouse_exited.connect(func() -> void:
		_tween_control_scale(button, NORMAL_SCALE, 0.14)
	)
	button.button_down.connect(func() -> void:
		_tween_control_scale(button, PRESSED_SCALE, 0.08)
	)
	button.button_up.connect(func() -> void:
		var target_scale: Vector2 = HOVER_SCALE if button.is_hovered() else NORMAL_SCALE
		_tween_control_scale(button, target_scale, 0.10)
	)


static func _tween_control_scale(control: BaseButton, target_scale: Vector2, duration: float) -> void:
	if control == null:
		return
	if control.disabled:
		return
	if control.has_meta("premium_scale_tween") and control.get_meta("premium_scale_tween") is Tween:
		(control.get_meta("premium_scale_tween") as Tween).kill()
	control.pivot_offset = control.size * 0.5
	var tween: Tween = control.create_tween()
	control.set_meta("premium_scale_tween", tween)
	tween.tween_property(control, "scale", target_scale, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
