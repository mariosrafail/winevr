extends Node
class_name ResponsiveLayoutController

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
	var panel_width: float = maxf(180.0, minf(430.0, viewport_size.x - safe_margin * 2.0))
	var intro_height: float = maxf(160.0, minf(390.0, viewport_size.y - safe_margin * 2.0))
	var inspection_height: float = maxf(140.0, minf(320.0, viewport_size.y * 0.48))
	var hotspot_height: float = maxf(120.0, minf(210.0, viewport_size.y * 0.34))
	var winery_height: float = maxf(140.0, minf(260.0, viewport_size.y * 0.42))
	var modal_width: float = maxf(200.0, minf(430.0, viewport_size.x - safe_margin * 2.0))
	var centered_x: float = (viewport_size.x - panel_width) * 0.5

	_place_clamped(qr_screen.card, Vector2(centered_x, safe_margin), Vector2(panel_width, maxf(150.0, minf(430.0, viewport_size.y - safe_margin * 2.0))), viewport_size, safe_margin)
	_place_clamped(hud.intro_card, Vector2(centered_x, (viewport_size.y - intro_height) * 0.5), Vector2(panel_width, intro_height), viewport_size, safe_margin)
	_place_clamped(hud.inspection_info_card, Vector2(centered_x, safe_margin), Vector2(panel_width, inspection_height), viewport_size, safe_margin)
	_place_clamped(hud.hotspot_panel, Vector2(centered_x, viewport_size.y - hotspot_height - safe_margin), Vector2(panel_width, hotspot_height), viewport_size, safe_margin)
	_place_clamped(hud.winery_info_card, Vector2(centered_x, safe_margin), Vector2(panel_width, winery_height), viewport_size, safe_margin)

	var modal_height: float = maxf(140.0, minf(250.0, viewport_size.y - safe_margin * 2.0))
	var modal_x: float = (viewport_size.x - modal_width) * 0.5
	var modal_y: float = (viewport_size.y - modal_height) * 0.5
	_place_clamped(hud.winery_modal, Vector2(modal_x, modal_y), Vector2(modal_width, modal_height), viewport_size, safe_margin)

	hud.inspection_hint.position = Vector2((viewport_size.x - minf(460.0, viewport_size.x - safe_margin * 2.0)) * 0.5, maxf(safe_margin, viewport_size.y - 42.0))
	hud.inspection_hint.size = Vector2(maxf(120.0, minf(460.0, viewport_size.x - safe_margin * 2.0)), 24.0)
	mobile_controls.layout(viewport_size, safe_margin)
	narrative_panel.layout(viewport_size, safe_margin)
	onboarding.layout(viewport_size)


func _place(panel: Control, panel_position: Vector2, panel_size: Vector2) -> void:
	panel.position = panel_position
	panel.size = panel_size


func _place_clamped(panel: Control, panel_position: Vector2, panel_size: Vector2, viewport_size: Vector2, margin: float) -> void:
	var width: float = clampf(panel_size.x, 64.0, maxf(64.0, viewport_size.x - margin * 2.0))
	var height: float = clampf(panel_size.y, 64.0, maxf(64.0, viewport_size.y - margin * 2.0))
	var x: float = clampf(panel_position.x, margin, maxf(margin, viewport_size.x - width - margin))
	var y: float = clampf(panel_position.y, margin, maxf(margin, viewport_size.y - height - margin))
	_place(panel, Vector2(x, y), Vector2(width, height))
