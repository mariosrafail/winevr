extends RefCounted
class_name PremiumUIStyles

const PANEL_BG: Color = Color(0.066, 0.062, 0.051, 0.86)
const PANEL_BG_INNER: Color = Color(0.094, 0.086, 0.071, 0.92)
const GOLD_BORDER: Color = Color(0.784, 0.655, 0.353, 0.65)
const GOLD_ACCENT: Color = Color(0.839, 0.694, 0.369, 1.0)
const TEXT_TITLE: Color = Color(0.961, 0.937, 0.89, 1.0)
const TEXT_BODY: Color = Color(0.851, 0.82, 0.753, 1.0)
const TEXT_MUTED: Color = Color(0.655, 0.612, 0.537, 1.0)
const SHADOW: Color = Color(0.0, 0.0, 0.0, 0.36)


static func make_panel_style(alpha: float = 0.86) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(PANEL_BG.r, PANEL_BG.g, PANEL_BG.b, alpha)
	style.border_color = GOLD_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.shadow_color = SHADOW
	style.shadow_size = 8
	style.shadow_offset = Vector2(0.0, 2.0)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style


static func make_button_style(background: Color, border: Color = GOLD_BORDER) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style


static func apply_gold_outline_button(button: Button) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", make_button_style(Color(PANEL_BG.r, PANEL_BG.g, PANEL_BG.b, 0.68), GOLD_BORDER))
	button.add_theme_stylebox_override("hover", make_button_style(GOLD_ACCENT, GOLD_ACCENT))
	button.add_theme_stylebox_override("pressed", make_button_style(Color(0.52, 0.42, 0.2, 1.0), GOLD_ACCENT))
	button.add_theme_stylebox_override("disabled", make_button_style(Color(0.05, 0.052, 0.058, 0.55), Color(GOLD_BORDER.r, GOLD_BORDER.g, GOLD_BORDER.b, 0.18)))
	button.add_theme_color_override("font_color", TEXT_TITLE)
	button.add_theme_color_override("font_hover_color", Color(PANEL_BG.r, PANEL_BG.g, PANEL_BG.b, 1.0))
	button.add_theme_color_override("font_pressed_color", TEXT_TITLE)
	button.add_theme_color_override("font_disabled_color", Color(TEXT_MUTED.r, TEXT_MUTED.g, TEXT_MUTED.b, 0.72))
