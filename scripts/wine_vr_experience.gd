extends Node

const QR_CLIENT_MAP := {
	KEY_1: "demo_winery",
	KEY_2: "reserve_winery",
	KEY_3: "cellar_series"
}

@onready var vial_preview: VialPreviewController = $VialPreview
@onready var winery_interior: WineryInteriorController = $WineryInterior
@onready var intro_screen: Control = $CanvasLayer/IntroScreen
@onready var intro_winery_name: Label = $CanvasLayer/IntroScreen/IntroCard/Margin/VBox/WineryName
@onready var intro_wine_name: Label = $CanvasLayer/IntroScreen/IntroCard/Margin/VBox/WineName
@onready var intro_region: Label = $CanvasLayer/IntroScreen/IntroCard/Margin/VBox/Region
@onready var intro_text: RichTextLabel = $CanvasLayer/IntroScreen/IntroCard/Margin/VBox/IntroText
@onready var start_button: Button = $CanvasLayer/IntroScreen/IntroCard/Margin/VBox/StartButton
@onready var inspection_hud: Control = $CanvasLayer/InspectionHUD
@onready var inspection_winery_name: Label = $CanvasLayer/InspectionHUD/InfoCard/Margin/VBox/WineryName
@onready var inspection_wine_name: Label = $CanvasLayer/InspectionHUD/InfoCard/Margin/VBox/WineName
@onready var inspection_region: Label = $CanvasLayer/InspectionHUD/InfoCard/Margin/VBox/Region
@onready var inspection_text: RichTextLabel = $CanvasLayer/InspectionHUD/InfoCard/Margin/VBox/IntroText
@onready var enter_winery_button: Button = $CanvasLayer/InspectionHUD/InfoCard/Margin/VBox/EnterWineryButton
@onready var hotspots_layer: Control = $CanvasLayer/InspectionHUD/HotspotsLayer
@onready var hotspot_panel: PanelContainer = $CanvasLayer/InspectionHUD/HotspotPanel
@onready var hotspot_title: Label = $CanvasLayer/InspectionHUD/HotspotPanel/Margin/VBox/Title
@onready var hotspot_text: RichTextLabel = $CanvasLayer/InspectionHUD/HotspotPanel/Margin/VBox/Text
@onready var hotspot_close_button: Button = $CanvasLayer/InspectionHUD/HotspotPanel/Margin/VBox/CloseButton
@onready var winery_hud: Control = $CanvasLayer/WineryHUD
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
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

	if state != ExperienceManager.ExperienceState.VIAL_INSPECTION:
		_close_hotspot_panel()
	if state != ExperienceManager.ExperienceState.WINERY_INTERIOR:
		_close_winery_modal()
		door_prompt_label.text = ""


func _build_hotspots(raw_hotspots: Array) -> void:
	for child in hotspots_layer.get_children():
		child.free()

	_active_hotspots.clear()
	for raw_hotspot in raw_hotspots:
		if typeof(raw_hotspot) == TYPE_DICTIONARY:
			_active_hotspots.append(raw_hotspot)

	for index in range(_active_hotspots.size()):
		var hotspot_data: Dictionary = _active_hotspots[index]
		var button := Button.new()
		button.text = str(index + 1)
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(38.0, 38.0)
		button.pressed.connect(_on_hotspot_pressed.bind(hotspot_data))
		hotspots_layer.add_child(button)

	_layout_hotspots()


func _layout_hotspots() -> void:
	for index in range(mini(_active_hotspots.size(), hotspots_layer.get_child_count())):
		var hotspot_data: Dictionary = _active_hotspots[index]
		var button := hotspots_layer.get_child(index) as Control
		if button == null:
			continue

		var position_data: Array = hotspot_data.get("screen_position", [0.72, 0.5])
		if position_data.size() < 2:
			position_data = [0.72, 0.5]

		var normalized_x: float = clampf(float(position_data[0]), 0.05, 0.95)
		var normalized_y: float = clampf(float(position_data[1]), 0.08, 0.92)
		var button_size: Vector2 = button.size if button.size != Vector2.ZERO else button.custom_minimum_size
		button.position = Vector2(
			hotspots_layer.size.x * normalized_x - button_size.x * 0.5,
			hotspots_layer.size.y * normalized_y - button_size.y * 0.5
		)


func _on_hotspot_pressed(hotspot_data: Dictionary) -> void:
	hotspot_title.text = str(hotspot_data.get("title", "Hotspot"))
	hotspot_text.text = str(hotspot_data.get("text", ""))
	hotspot_panel.visible = true


func _close_hotspot_panel() -> void:
	hotspot_panel.visible = false


func _on_door_prompt_changed(prompt: String) -> void:
	door_prompt_label.text = prompt


func _on_door_interacted() -> void:
	winery_modal.visible = true


func _close_winery_modal() -> void:
	winery_modal.visible = false


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
