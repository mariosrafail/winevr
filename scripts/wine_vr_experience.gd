extends Node

const QR_CLIENT_MAP := {
	KEY_1: "demo_winery",
	KEY_2: "reserve_winery",
	KEY_3: "cellar_series"
}

@onready var vial_preview: VialPreviewController = $VialPreview
@onready var winery_interior: WineryInteriorController = $WineryInterior
@onready var intro_screen: Control = $CanvasLayer/IntroScreen
@onready var intro_card: PanelContainer = $CanvasLayer/IntroScreen/IntroCard
@onready var intro_winery_name: Label = $CanvasLayer/IntroScreen/IntroCard/Margin/VBox/WineryName
@onready var intro_wine_name: Label = $CanvasLayer/IntroScreen/IntroCard/Margin/VBox/WineName
@onready var intro_region: Label = $CanvasLayer/IntroScreen/IntroCard/Margin/VBox/Region
@onready var intro_text: RichTextLabel = $CanvasLayer/IntroScreen/IntroCard/Margin/VBox/IntroText
@onready var start_button: Button = $CanvasLayer/IntroScreen/IntroCard/Margin/VBox/StartButton
@onready var inspection_hud: Control = $CanvasLayer/InspectionHUD
@onready var inspection_info_card: PanelContainer = $CanvasLayer/InspectionHUD/InfoCard
@onready var inspection_winery_name: Label = $CanvasLayer/InspectionHUD/InfoCard/Margin/VBox/WineryName
@onready var inspection_wine_name: Label = $CanvasLayer/InspectionHUD/InfoCard/Margin/VBox/WineName
@onready var inspection_region: Label = $CanvasLayer/InspectionHUD/InfoCard/Margin/VBox/Region
@onready var inspection_text: RichTextLabel = $CanvasLayer/InspectionHUD/InfoCard/Margin/VBox/IntroText
@onready var enter_winery_button: Button = $CanvasLayer/InspectionHUD/InfoCard/Margin/VBox/EnterWineryButton
@onready var hotspots_layer: Control = $CanvasLayer/InspectionHUD/HotspotsLayer
@onready var panel_dim: ColorRect = $CanvasLayer/PanelDim
@onready var hotspot_panel: PanelContainer = $CanvasLayer/InspectionHUD/HotspotPanel
@onready var hotspot_title: Label = $CanvasLayer/InspectionHUD/HotspotPanel/Margin/VBox/Title
@onready var hotspot_text: RichTextLabel = $CanvasLayer/InspectionHUD/HotspotPanel/Margin/VBox/Text
@onready var hotspot_close_button: Button = $CanvasLayer/InspectionHUD/HotspotPanel/Margin/VBox/CloseButton
@onready var inspection_hint: Label = $CanvasLayer/InspectionHUD/InspectionHint
@onready var winery_hud: Control = $CanvasLayer/WineryHUD
@onready var winery_info_card: PanelContainer = $CanvasLayer/WineryHUD/InfoCard
@onready var winery_title: Label = $CanvasLayer/WineryHUD/InfoCard/Margin/VBox/Title
@onready var winery_text: RichTextLabel = $CanvasLayer/WineryHUD/InfoCard/Margin/VBox/Text
@onready var return_button: Button = $CanvasLayer/WineryHUD/InfoCard/Margin/VBox/ReturnButton
@onready var door_prompt_label: Label = $CanvasLayer/WineryHUD/DoorPrompt
@onready var winery_modal: PanelContainer = $CanvasLayer/WineryHUD/WineryModal
@onready var winery_modal_title: Label = $CanvasLayer/WineryHUD/WineryModal/Margin/VBox/Title
@onready var winery_modal_text: RichTextLabel = $CanvasLayer/WineryHUD/WineryModal/Margin/VBox/Text
@onready var winery_modal_close: Button = $CanvasLayer/WineryHUD/WineryModal/Margin/VBox/CloseButton
@onready var fade_rect: ColorRect = $CanvasLayer/FadeRect

var _transition_in_progress: bool = false
var _active_hotspots: Array[Dictionary] = []
var _viewed_hotspot_ids: Dictionary = {}
var _required_hotspot_ids: Dictionary = {}
var _active_client_id: String = ""


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	enter_winery_button.pressed.connect(_on_enter_winery_pressed)
	return_button.pressed.connect(_on_return_to_vial_pressed)
	hotspot_close_button.pressed.connect(_close_hotspot_panel)
	winery_modal_close.pressed.connect(_close_winery_modal)
	ClientProfileLoader.client_profile_changed.connect(_on_client_profile_changed)
	ExperienceManager.state_changed.connect(_on_state_changed)
	winery_interior.door_prompt_changed.connect(_on_door_prompt_changed)
	winery_interior.door_interacted.connect(_on_door_interacted)

	_apply_client_profile(ClientProfileLoader.get_active_client_data())
	_apply_state(ExperienceManager.current_state)
	_layout_panels()
	panel_dim.modulate.a = 0.0
	hotspot_panel.modulate.a = 0.0
	hotspot_panel.scale = Vector2(0.96, 0.96)
	winery_modal.modulate.a = 0.0
	winery_modal.scale = Vector2(0.96, 0.96)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_layout_panels()
		_layout_hotspots()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and QR_CLIENT_MAP.has(event.keycode):
		var client_id: String = QR_CLIENT_MAP[event.keycode]
		if ClientProfileLoader.load_client_profile(client_id):
			_close_hotspot_panel()
			_close_winery_modal()
			ExperienceManager.return_to_intro()


func _on_start_pressed() -> void:
	ExperienceManager.start_experience()


func _on_enter_winery_pressed() -> void:
	if _transition_in_progress:
		return
	ExperienceManager.enter_winery()


func _on_return_to_vial_pressed() -> void:
	if _transition_in_progress:
		return
	_return_to_vial_with_fade()


func _on_client_profile_changed(_client_id: String, client_data: Dictionary) -> void:
	_apply_client_profile(client_data)


func _on_state_changed(_previous_state: int, current_state: int) -> void:
	if current_state == ExperienceManager.ExperienceState.WINERY_ENTRY:
		_enter_winery_with_fade()
		return

	_apply_state(current_state)


func _apply_client_profile(client_data: Dictionary) -> void:
	if client_data.is_empty():
		return

	var client_id: String = str(client_data.get("client_id", ""))
	if client_id != _active_client_id:
		_active_client_id = client_id
		_viewed_hotspot_ids.clear()

	var winery_name_value: String = str(client_data.get("winery_name", "Unknown Winery"))
	var wine_name_value: String = str(client_data.get("wine_name", "Untitled Wine"))
	var region_value: String = "%s, %s" % [
		str(client_data.get("region_name", "")),
		str(client_data.get("country", ""))
	]
	var experience_settings: Dictionary = client_data.get("experience_settings", {})
	var intro_title_value: String = str(experience_settings.get("intro_title", wine_name_value))
	var intro_text_value: String = str(experience_settings.get("intro_text", ""))
	var winery_info_value: String = str(experience_settings.get("winery_info_text", ""))
	var winery_scene_name: String = str(experience_settings.get("winery_scene_name", "default_cellar"))
	var intro_body_value: String = "%s\n\n%s" % [intro_title_value, intro_text_value]

	intro_winery_name.text = winery_name_value
	intro_wine_name.text = wine_name_value
	intro_region.text = region_value
	intro_text.text = intro_body_value

	inspection_winery_name.text = winery_name_value
	inspection_wine_name.text = wine_name_value
	inspection_region.text = region_value
	inspection_text.text = intro_body_value

	winery_title.text = "%s / %s" % [winery_name_value, winery_scene_name.replace("_", " ").capitalize()]
	winery_text.text = winery_info_value
	winery_modal_title.text = wine_name_value
	winery_modal_text.text = winery_info_value

	vial_preview.apply_client_profile(client_data)
	winery_interior.apply_client_profile(client_data)
	_build_hotspots(experience_settings.get("hotspots", []))
	_update_enter_winery_state()


func _apply_state(state: int) -> void:
	intro_screen.visible = state == ExperienceManager.ExperienceState.INTRO
	inspection_hud.visible = state == ExperienceManager.ExperienceState.VIAL_INSPECTION
	winery_hud.visible = state == ExperienceManager.ExperienceState.WINERY_INTERIOR
	vial_preview.visible = state != ExperienceManager.ExperienceState.WINERY_INTERIOR
	winery_interior.visible = state == ExperienceManager.ExperienceState.WINERY_INTERIOR

	vial_preview.set_camera_active(state != ExperienceManager.ExperienceState.WINERY_INTERIOR)
	winery_interior.set_camera_active(state == ExperienceManager.ExperienceState.WINERY_INTERIOR)
	vial_preview.set_interaction_enabled(state == ExperienceManager.ExperienceState.VIAL_INSPECTION)
	winery_interior.set_controls_enabled(state == ExperienceManager.ExperienceState.WINERY_INTERIOR)
	inspection_hint.visible = state == ExperienceManager.ExperienceState.VIAL_INSPECTION

	if state != ExperienceManager.ExperienceState.VIAL_INSPECTION:
		_close_hotspot_panel()
	if state != ExperienceManager.ExperienceState.WINERY_INTERIOR:
		_close_winery_modal()
		door_prompt_label.text = ""


func _build_hotspots(raw_hotspots: Array) -> void:
	for child in hotspots_layer.get_children():
		child.free()

	_active_hotspots.clear()
	_required_hotspot_ids.clear()
	for raw_hotspot in raw_hotspots:
		if typeof(raw_hotspot) == TYPE_DICTIONARY:
			var hotspot_data: Dictionary = raw_hotspot
			_active_hotspots.append(hotspot_data)
			var hotspot_id: String = _get_hotspot_id(hotspot_data)
			if bool(hotspot_data.get("viewed_required_for_winery", true)):
				_required_hotspot_ids[hotspot_id] = true

	for index in range(_active_hotspots.size()):
		var hotspot_data: Dictionary = _active_hotspots[index]
		var marker := HotspotMarker.new()
		marker.configure(hotspot_data, _viewed_hotspot_ids.has(_get_hotspot_id(hotspot_data)))
		marker.hotspot_selected.connect(_on_hotspot_pressed)
		hotspots_layer.add_child(marker)

	_layout_hotspots()


func _layout_hotspots() -> void:
	for index in range(mini(_active_hotspots.size(), hotspots_layer.get_child_count())):
		var hotspot_data: Dictionary = _active_hotspots[index]
		var marker := hotspots_layer.get_child(index) as Control
		if marker == null:
			continue

		var position_data: Array = hotspot_data.get("screen_position", [0.72, 0.5])
		if position_data.size() < 2:
			position_data = [0.72, 0.5]

		var normalized_x: float = clampf(float(position_data[0]), 0.05, 0.95)
		var normalized_y: float = clampf(float(position_data[1]), 0.08, 0.92)
		var marker_size: Vector2 = marker.size if marker.size != Vector2.ZERO else marker.custom_minimum_size
		marker.position = Vector2(
			hotspots_layer.size.x * normalized_x - marker_size.x * 0.5,
			hotspots_layer.size.y * normalized_y - marker_size.y * 0.5
		)


func _layout_panels() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var margin: float = 20.0 if viewport_size.x >= 760.0 else 14.0
	var panel_width: float = minf(430.0, viewport_size.x - margin * 2.0)
	var intro_height: float = minf(390.0, viewport_size.y - margin * 2.0)
	var inspection_height: float = minf(320.0, viewport_size.y * 0.48)
	var hotspot_height: float = minf(210.0, viewport_size.y * 0.34)
	var winery_height: float = minf(260.0, viewport_size.y * 0.42)
	var modal_width: float = minf(430.0, viewport_size.x - margin * 2.0)

	_place_panel(intro_card, Vector2(margin * 2.0, margin * 2.0), Vector2(panel_width, intro_height))
	_place_panel(inspection_info_card, Vector2(margin, margin), Vector2(panel_width, inspection_height))
	_place_panel(hotspot_panel, Vector2(margin, viewport_size.y - hotspot_height - margin), Vector2(panel_width, hotspot_height))
	_place_panel(winery_info_card, Vector2(margin, margin), Vector2(panel_width, winery_height))

	var modal_x: float = viewport_size.x - modal_width - margin
	var modal_y: float = margin
	if viewport_size.x < 900.0:
		modal_x = margin
		modal_y = maxf(margin, viewport_size.y - 250.0 - margin)
	_place_panel(winery_modal, Vector2(modal_x, modal_y), Vector2(modal_width, 250.0))

	inspection_hint.position = Vector2(margin, viewport_size.y - 42.0)
	inspection_hint.size = Vector2(minf(360.0, viewport_size.x - margin * 2.0), 24.0)


func _place_panel(panel: Control, panel_position: Vector2, panel_size: Vector2) -> void:
	panel.position = panel_position
	panel.size = panel_size


func _on_hotspot_pressed(hotspot_data: Dictionary) -> void:
	var hotspot_id: String = _get_hotspot_id(hotspot_data)
	_viewed_hotspot_ids[hotspot_id] = true
	hotspot_title.text = str(hotspot_data.get("title", "Hotspot"))
	hotspot_text.text = str(hotspot_data.get("text", ""))
	_update_marker_viewed_state()
	_update_enter_winery_state()
	_show_hotspot_panel()


func _close_hotspot_panel() -> void:
	_hide_hotspot_panel()


func _on_door_prompt_changed(prompt: String) -> void:
	door_prompt_label.text = prompt


func _on_door_interacted() -> void:
	_show_winery_modal()


func _close_winery_modal() -> void:
	_hide_winery_modal()


func _enter_winery_with_fade() -> void:
	if _transition_in_progress:
		return

	_transition_in_progress = true
	vial_preview.set_interaction_enabled(false)
	await _fade_to(1.0)
	ExperienceManager.finish_winery_entry()
	winery_interior.reset_view()
	await _fade_to(0.0)
	_transition_in_progress = false


func _return_to_vial_with_fade() -> void:
	_transition_in_progress = true
	winery_interior.set_controls_enabled(false)
	await _fade_to(1.0)
	ExperienceManager.return_to_vial()
	vial_preview.reset_view()
	await _fade_to(0.0)
	_transition_in_progress = false


func _fade_to(target_alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", target_alpha, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _show_hotspot_panel() -> void:
	hotspot_panel.visible = true
	hotspot_panel.pivot_offset = hotspot_panel.size * 0.5
	vial_preview.set_idle_rotation_paused(true)
	_set_panel_dim(true)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(hotspot_panel, "modulate:a", 1.0, 0.16)
	tween.tween_property(hotspot_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _hide_hotspot_panel() -> void:
	if not hotspot_panel.visible:
		return

	vial_preview.set_idle_rotation_paused(false)
	_set_panel_dim(false)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(hotspot_panel, "modulate:a", 0.0, 0.12)
	tween.tween_property(hotspot_panel, "scale", Vector2(0.96, 0.96), 0.12)
	await tween.finished
	hotspot_panel.visible = false


func _show_winery_modal() -> void:
	winery_modal.visible = true
	winery_modal.pivot_offset = winery_modal.size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(winery_modal, "modulate:a", 1.0, 0.16)
	tween.tween_property(winery_modal, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _hide_winery_modal() -> void:
	if not winery_modal.visible:
		return

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(winery_modal, "modulate:a", 0.0, 0.12)
	tween.tween_property(winery_modal, "scale", Vector2(0.96, 0.96), 0.12)
	await tween.finished
	winery_modal.visible = false


func _set_panel_dim(visible: bool) -> void:
	var target_alpha: float = 1.0 if visible else 0.0
	var tween := create_tween()
	tween.tween_property(panel_dim, "modulate:a", target_alpha, 0.16)


func _update_marker_viewed_state() -> void:
	for child in hotspots_layer.get_children():
		var marker := child as HotspotMarker
		if marker == null:
			continue
		marker.viewed = _viewed_hotspot_ids.has(_get_hotspot_id(marker.hotspot_data))


func _update_enter_winery_state() -> void:
	var all_required_viewed: bool = true
	for hotspot_id in _required_hotspot_ids.keys():
		if not _viewed_hotspot_ids.has(str(hotspot_id)):
			all_required_viewed = false
			break

	enter_winery_button.disabled = not all_required_viewed
	enter_winery_button.modulate = Color(1.0, 1.0, 1.0, 1.0) if all_required_viewed else Color(0.72, 0.72, 0.72, 0.82)


func _get_hotspot_id(hotspot_data: Dictionary) -> String:
	return str(hotspot_data.get("id", hotspot_data.get("title", "")))
