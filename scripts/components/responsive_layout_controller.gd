extends Node
class_name ResponsiveLayoutController

var qr_screen: QRScreenController
var hud: ExperienceHUDController
var mobile_controls: MobileControlsController
var narrative_panel: NarrativePanelController


func setup(qr: QRScreenController, experience_hud: ExperienceHUDController, mobile: MobileControlsController, narrative: NarrativePanelController) -> void:
	qr_screen = qr
	hud = experience_hud
	mobile_controls = mobile
	narrative_panel = narrative


func layout(viewport_size: Vector2) -> void:
	var margin: float = 20.0 if viewport_size.x >= 760.0 else 14.0
	var panel_width: float = minf(430.0, viewport_size.x - margin * 2.0)
	var intro_height: float = minf(390.0, viewport_size.y - margin * 2.0)
	var inspection_height: float = minf(320.0, viewport_size.y * 0.48)
	var hotspot_height: float = minf(210.0, viewport_size.y * 0.34)
	var winery_height: float = minf(260.0, viewport_size.y * 0.42)
	var modal_width: float = minf(430.0, viewport_size.x - margin * 2.0)

	_place(qr_screen.card, Vector2(margin * 2.0, margin * 2.0), Vector2(panel_width, minf(430.0, viewport_size.y - margin * 2.0)))
	_place(hud.intro_card, Vector2(margin * 2.0, margin * 2.0), Vector2(panel_width, intro_height))
	_place(hud.inspection_info_card, Vector2(margin, margin), Vector2(panel_width, inspection_height))
	_place(hud.hotspot_panel, Vector2(margin, viewport_size.y - hotspot_height - margin), Vector2(panel_width, hotspot_height))
	_place(hud.winery_info_card, Vector2(margin, margin), Vector2(panel_width, winery_height))

	var modal_x: float = viewport_size.x - modal_width - margin
	var modal_y: float = margin
	if viewport_size.x < 900.0:
		modal_x = margin
		modal_y = maxf(margin, viewport_size.y - 250.0 - margin)
	_place(hud.winery_modal, Vector2(modal_x, modal_y), Vector2(modal_width, 250.0))

	hud.inspection_hint.position = Vector2(margin, viewport_size.y - 42.0)
	hud.inspection_hint.size = Vector2(minf(360.0, viewport_size.x - margin * 2.0), 24.0)
	mobile_controls.layout(viewport_size, margin)
	narrative_panel.layout(viewport_size, margin)


func _place(panel: Control, panel_position: Vector2, panel_size: Vector2) -> void:
	panel.position = panel_position
	panel.size = panel_size
