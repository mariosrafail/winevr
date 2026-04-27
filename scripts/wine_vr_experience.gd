extends Node

@onready var vial_preview: VialPreviewController = $VialPreview
@onready var winery_interior: WineryInteriorController = $WineryInterior
@onready var canvas_layer: CanvasLayer = $CanvasLayer
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
var _profile_loading: bool = false
var _active_hotspots: Array[Dictionary] = []
var _viewed_hotspot_ids: Dictionary = {}
var _required_hotspot_ids: Dictionary = {}
var _active_client_id: String = ""
var _qr_screen: Control
var _qr_card: PanelContainer
var _qr_error_label: Label
var _loading_overlay: Control
var _loading_label: Label
var _zoom_controls: HBoxContainer
var _mobile_controls: Control
var _look_pad: Control
var _registry_entries: Array[Dictionary] = []
var _qr_button_box: VBoxContainer


func _ready() -> void:
	_registry_entries = ClientProfileLoader.get_client_registry(false)
	_build_runtime_ui()
	canvas_layer.move_child(fade_rect, canvas_layer.get_child_count() - 1)
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
	if event is InputEventKey and event.pressed and not event.echo:
		var registry_index: int = _get_debug_registry_index(event.keycode)
		if registry_index >= 0 and registry_index < _registry_entries.size():
			var entry: Dictionary = _registry_entries[registry_index]
			_select_qr_client(str(entry.get("client_id", "")))


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
	var environment_settings: Dictionary = client_data.get("environment_settings", {})
	var intro_title_value: String = str(experience_settings.get("intro_title", wine_name_value))
	var intro_text_value: String = str(experience_settings.get("intro_text", ""))
	var winery_info_value: String = str(environment_settings.get("ambience_text", experience_settings.get("winery_info_text", "")))
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
	_qr_screen.visible = state == ExperienceManager.ExperienceState.QR_SCAN
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
	_zoom_controls.visible = state == ExperienceManager.ExperienceState.VIAL_INSPECTION
	_mobile_controls.visible = state == ExperienceManager.ExperienceState.WINERY_INTERIOR

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

	_place_panel(_qr_card, Vector2(margin * 2.0, margin * 2.0), Vector2(panel_width, minf(430.0, viewport_size.y - margin * 2.0)))
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

	_zoom_controls.position = Vector2(viewport_size.x - 146.0 - margin, viewport_size.y - 64.0)
	_zoom_controls.size = Vector2(146.0, 48.0)
	_mobile_controls.position = Vector2(0.0, 0.0)
	_mobile_controls.size = viewport_size
	var move_pad := _mobile_controls.get_node_or_null("MovePad") as Control
	if move_pad != null:
		move_pad.position = Vector2(margin, viewport_size.y - 132.0)
		move_pad.size = Vector2(210.0, 116.0)
	if _look_pad != null:
		if viewport_size.x < 560.0:
			_look_pad.position = Vector2(margin, maxf(margin, viewport_size.y - 286.0))
			_look_pad.size = Vector2(viewport_size.x - margin * 2.0, 126.0)
		else:
			var look_pad_width: float = maxf(180.0, viewport_size.x - 280.0)
			_look_pad.position = Vector2(viewport_size.x - look_pad_width - margin, viewport_size.y - 164.0)
			_look_pad.size = Vector2(look_pad_width, 150.0)


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


func _on_door_interacted(interactable_data: Dictionary = {}) -> void:
	if not interactable_data.is_empty():
		winery_modal_title.text = str(interactable_data.get("title", winery_modal_title.text))
		winery_modal_text.text = str(interactable_data.get("text", winery_modal_text.text))
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


func _build_runtime_ui() -> void:
	_build_qr_screen()
	_build_loading_overlay()
	_build_zoom_controls()
	_build_mobile_winery_controls()


func _build_qr_screen() -> void:
	_qr_screen = Control.new()
	_qr_screen.name = "QRSimulationScreen"
	_qr_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(_qr_screen)
	canvas_layer.move_child(_qr_screen, 1)

	var dimmer := ColorRect.new()
	dimmer.color = Color(0.02, 0.024, 0.03, 0.72)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_qr_screen.add_child(dimmer)

	_qr_card = PanelContainer.new()
	_qr_card.add_theme_stylebox_override("panel", _make_panel_style())
	_qr_screen.add_child(_qr_card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 2)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	_qr_card.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Scan Vial QR"
	title.label_settings = _make_label_settings(28, Color(0.976, 0.968, 0.941, 1.0))
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Select a simulated QR profile"
	subtitle.label_settings = _make_label_settings(15, Color(0.84, 0.86, 0.86, 1.0))
	box.add_child(subtitle)

	_qr_button_box = VBoxContainer.new()
	_qr_button_box.add_theme_constant_override("separation", 8)
	box.add_child(_qr_button_box)
	_build_qr_buttons()

	_qr_error_label = Label.new()
	_qr_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_qr_error_label.label_settings = _make_label_settings(14, Color(1.0, 0.55, 0.46, 1.0))
	box.add_child(_qr_error_label)


func _build_qr_buttons() -> void:
	for child in _qr_button_box.get_children():
		child.free()

	if _registry_entries.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No enabled client profiles are available."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.label_settings = _make_label_settings(14, Color(1.0, 0.55, 0.46, 1.0))
		_qr_button_box.add_child(empty_label)
		return

	for index in range(_registry_entries.size()):
		var entry: Dictionary = _registry_entries[index]
		_add_qr_button(_qr_button_box, entry, index)


func _add_qr_button(parent: Control, entry: Dictionary, index: int) -> void:
	var button := Button.new()
	button.text = "%s\n%s / %s" % [
		str(entry.get("display_name", "")),
		str(entry.get("wine_name", "")),
		str(entry.get("region", ""))
	]
	button.tooltip_text = "Debug key %s" % str(index + 1)
	button.custom_minimum_size = Vector2(0.0, 68.0)
	button.focus_mode = Control.FOCUS_ALL
	var client_id: String = str(entry.get("client_id", ""))
	button.pressed.connect(_select_qr_client.bind(client_id))
	parent.add_child(button)


func _build_loading_overlay() -> void:
	_loading_overlay = Control.new()
	_loading_overlay.name = "LoadingOverlay"
	_loading_overlay.visible = false
	_loading_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(_loading_overlay)
	canvas_layer.move_child(_loading_overlay, canvas_layer.get_child_count() - 1)

	var dimmer := ColorRect.new()
	dimmer.color = Color(0.0, 0.0, 0.0, 0.62)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_overlay.add_child(dimmer)

	_loading_label = Label.new()
	_loading_label.text = "Loading experience"
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_label.label_settings = _make_label_settings(20, Color(0.98, 0.95, 0.88, 1.0))
	_loading_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_overlay.add_child(_loading_label)


func _build_zoom_controls() -> void:
	_zoom_controls = HBoxContainer.new()
	_zoom_controls.name = "VialZoomControls"
	_zoom_controls.visible = false
	_zoom_controls.add_theme_constant_override("separation", 10)
	canvas_layer.add_child(_zoom_controls)

	var zoom_out_button := Button.new()
	zoom_out_button.text = "-"
	zoom_out_button.custom_minimum_size = Vector2(68.0, 48.0)
	zoom_out_button.pressed.connect(vial_preview.zoom_out)
	_zoom_controls.add_child(zoom_out_button)

	var zoom_in_button := Button.new()
	zoom_in_button.text = "+"
	zoom_in_button.custom_minimum_size = Vector2(68.0, 48.0)
	zoom_in_button.pressed.connect(vial_preview.zoom_in)
	_zoom_controls.add_child(zoom_in_button)


func _build_mobile_winery_controls() -> void:
	_mobile_controls = Control.new()
	_mobile_controls.name = "MobileWineryControls"
	_mobile_controls.visible = false
	_mobile_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(_mobile_controls)

	var pad := Control.new()
	pad.name = "MovePad"
	pad.position = Vector2(18.0, 0.0)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mobile_controls.add_child(pad)

	_add_move_button(pad, "forward", "^", Vector2(70.0, 0.0))
	_add_move_button(pad, "left", "<", Vector2(0.0, 58.0))
	_add_move_button(pad, "back", "v", Vector2(70.0, 58.0))
	_add_move_button(pad, "right", ">", Vector2(140.0, 58.0))

	_look_pad = ColorRect.new()
	_look_pad.name = "LookPad"
	_look_pad.color = Color(0.0, 0.0, 0.0, 0.0)
	_look_pad.mouse_filter = Control.MOUSE_FILTER_STOP
	_look_pad.gui_input.connect(_on_look_pad_input)
	_mobile_controls.add_child(_look_pad)


func _add_move_button(parent: Control, axis: String, label: String, button_position: Vector2) -> void:
	var button := Button.new()
	button.text = label
	button.position = button_position
	button.custom_minimum_size = Vector2(56.0, 52.0)
	button.button_down.connect(winery_interior.set_mobile_move_axis.bind(axis, true))
	button.button_up.connect(winery_interior.set_mobile_move_axis.bind(axis, false))
	parent.add_child(button)


func _on_look_pad_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		winery_interior.handle_look_drag(event.relative)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		winery_interior.handle_look_drag(event.relative)


func _select_qr_client(client_id: String) -> void:
	if _profile_loading:
		return

	_profile_loading = true
	_qr_error_label.text = ""
	_show_loading("Loading experience")
	await get_tree().create_timer(0.18).timeout

	_viewed_hotspot_ids.clear()
	_close_hotspot_panel()
	_close_winery_modal()

	if not ClientProfileLoader.profile_exists(client_id):
		_qr_error_label.text = "Profile '%s' is listed but its config file is missing." % client_id
		ExperienceManager.show_qr_scan()
	elif ClientProfileLoader.load_client_profile(client_id):
		vial_preview.reset_view()
		winery_interior.reset_view()
		ExperienceManager.enter_intro()
	else:
		_qr_error_label.text = "Profile '%s' is not available yet." % client_id
		ExperienceManager.show_qr_scan()

	_hide_loading()
	_profile_loading = false


func _get_debug_registry_index(keycode: int) -> int:
	if keycode >= KEY_1 and keycode <= KEY_9:
		return keycode - KEY_1
	return -1


func _show_loading(message: String) -> void:
	_loading_label.text = message
	_loading_overlay.visible = true
	canvas_layer.move_child(_loading_overlay, canvas_layer.get_child_count() - 1)


func _hide_loading() -> void:
	_loading_overlay.visible = false


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0352941, 0.0392157, 0.0470588, 0.9)
	style.border_color = Color(0.92, 0.76, 0.45, 0.22)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(20.0)
	return style


func _make_label_settings(font_size: int, font_color: Color) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = font_color
	return settings
