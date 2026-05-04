extends Node
class_name ResponsiveLayoutController

const SAFE_MARGIN_DEFAULT: float = 16.0
const SAFE_MARGIN_SMALL: float = 10.0
const SAFE_MIN_WIDTH: float = 260.0
const SAFE_MIN_HEIGHT: float = 180.0

var qr_screen: QRScreenController
var hud: ExperienceHUDController
var mobile_controls: MobileControlsController
var narrative_panel: NarrativePanelController
var onboarding: OnboardingOverlayController


func setup(qr: QRScreenController, experience_hud: ExperienceHUDController, mobile: MobileControlsController, narrative: NarrativePanelController, onboarding_overlay: OnboardingOverlayController) -> void:
	qr_screen = qr
	hud = experience_hud
	mobile_controls = mobile
	narrative_panel = narrative
	onboarding = onboarding_overlay


func layout(viewport_size: Vector2) -> void:
	var margin: float = 20.0 if viewport_size.x >= 760.0 else 14.0
	var safe_margin: float = minf(margin, minf(viewport_size.x * 0.1, viewport_size.y * 0.1))
	var intro_width: float = clampf(430.0, 320.0, viewport_size.x - safe_margin * 2.0)
	var left_panel_width: float = clampf(340.0, 300.0, viewport_size.x - safe_margin * 2.0)
	var modal_width: float = clampf(470.0, 420.0, viewport_size.x - safe_margin * 2.0)
	var intro_height: float = clampf(340.0, 180.0, viewport_size.y * 0.62)
	var left_panel_height: float = clampf(300.0, 200.0, viewport_size.y * 0.55)
	var hotspot_height: float = clampf(200.0, 120.0, minf(220.0, viewport_size.y * 0.28))
	var modal_height: float = clampf(280.0, 180.0, viewport_size.y * 0.5)

	apply_safe_panel_layout(qr_screen.card, viewport_size, Vector2(intro_width, minf(430.0, viewport_size.y - safe_margin * 2.0)), "center")
	apply_safe_panel_layout(hud.intro_card, viewport_size, Vector2(intro_width, intro_height), "center")
	apply_safe_panel_layout(hud.inspection_info_card, viewport_size, Vector2(left_panel_width, left_panel_height), "top_left")
	apply_safe_panel_layout(hud.hotspot_panel, viewport_size, Vector2(left_panel_width, hotspot_height), "bottom_center")
	apply_safe_panel_layout(hud.winery_info_card, viewport_size, Vector2(left_panel_width, left_panel_height), "top_left")
	apply_safe_panel_layout(hud.winery_modal, viewport_size, Vector2(modal_width, modal_height), "center")

	hud.inspection_hint.position = Vector2((viewport_size.x - minf(460.0, viewport_size.x - safe_margin * 2.0)) * 0.5, maxf(safe_margin, viewport_size.y - 42.0))
	hud.inspection_hint.size = Vector2(maxf(120.0, minf(460.0, viewport_size.x - safe_margin * 2.0)), 24.0)
	mobile_controls.layout(viewport_size, safe_margin)
	narrative_panel.layout(viewport_size, safe_margin)
	onboarding.layout(viewport_size)


static func apply_safe_panel_layout(panel: Control, viewport_size: Vector2, preferred_size: Vector2, anchor_mode: String) -> Rect2:
	if panel == null:
		return Rect2()

	var margin: float = SAFE_MARGIN_DEFAULT if viewport_size.x >= 900.0 else SAFE_MARGIN_SMALL
	var max_w: float = maxf(120.0, viewport_size.x - margin * 2.0)
	var max_h: float = maxf(120.0, minf(viewport_size.y - margin * 2.0, viewport_size.y * 0.68))
	var width: float = clampf(preferred_size.x, minf(SAFE_MIN_WIDTH, max_w), max_w)
	var height: float = clampf(preferred_size.y, minf(SAFE_MIN_HEIGHT, max_h), max_h)

	# Small windows: use near full screen with safety margins.
	if (viewport_size.x <= 980.0 or viewport_size.y <= 680.0) and anchor_mode == "center":
		width = max_w
		height = clampf(viewport_size.y * 0.9, minf(SAFE_MIN_HEIGHT, viewport_size.y - margin * 2.0), maxf(minf(SAFE_MIN_HEIGHT, viewport_size.y - margin * 2.0), viewport_size.y - margin * 2.0))

	var pos := Vector2.ZERO
	match anchor_mode:
		"top_left":
			pos = Vector2(margin, margin + 52.0)
		"top_right":
			pos = Vector2(viewport_size.x - width - margin, margin)
		"bottom_center":
			pos = Vector2((viewport_size.x - width) * 0.5, viewport_size.y - height - margin)
		_:
			pos = Vector2((viewport_size.x - width) * 0.5, (viewport_size.y - height) * 0.5)

	pos.x = clampf(pos.x, margin, maxf(margin, viewport_size.x - width - margin))
	pos.y = clampf(pos.y, margin, maxf(margin, viewport_size.y - height - margin))
	panel.position = pos
	panel.size = Vector2(width, height)
	return Rect2(panel.position, panel.size)


static func apply_compact_panel_size(panel: Control, viewport_size: Vector2, max_height_ratio: float, preferred_width: float, min_height: float = SAFE_MIN_HEIGHT) -> Vector2:
	if panel == null:
		return Vector2.ZERO
	var max_h: float = maxf(min_height, viewport_size.y * max_height_ratio)
	var max_w: float = maxf(minf(SAFE_MIN_WIDTH, viewport_size.x - 20.0), viewport_size.x - 20.0)
	var width: float = clampf(preferred_width, minf(SAFE_MIN_WIDTH, max_w), max_w)
	var height: float = clampf(panel.size.y, min_height, max_h)
	panel.custom_minimum_size.y = min_height
	panel.size = Vector2(width, height)
	return panel.size


static func apply_scroll_safe_content(scroll: ScrollContainer, panel_height: float, reserved_bottom: float, min_scroll_height: float, max_scroll_height: float) -> float:
	if scroll == null:
		return 0.0
	var target: float = clampf(panel_height - reserved_bottom, min_scroll_height, max_scroll_height)
	scroll.custom_minimum_size.y = target
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return target


static func apply_premium_panel_style(panel: PanelContainer) -> void:
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel", PremiumUIStyles.make_panel_style())
