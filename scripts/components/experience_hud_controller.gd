extends Node
class_name ExperienceHUDController

signal start_requested
signal enter_winery_requested
signal return_to_vial_requested

var intro_screen: Control
var inspection_hud: Control
var winery_hud: Control
var intro_card: PanelContainer
var inspection_info_card: PanelContainer
var winery_info_card: PanelContainer
var hotspot_panel: PanelContainer
var winery_modal: PanelContainer
var inspection_hint: Label
var door_prompt_label: Label
var enter_winery_button: Button
var unlock_feedback_label: Label

var intro_winery_name: Label
var intro_wine_name: Label
var intro_region: Label
var intro_text: RichTextLabel
var inspection_winery_name: Label
var inspection_wine_name: Label
var inspection_region: Label
var inspection_text: RichTextLabel
var winery_title: Label
var winery_text: RichTextLabel
var winery_modal_title: Label
var winery_modal_text: RichTextLabel


func setup(root: Node) -> void:
	intro_screen = root.get_node("CanvasLayer/IntroScreen") as Control
	intro_card = root.get_node("CanvasLayer/IntroScreen/IntroCard") as PanelContainer
	intro_winery_name = root.get_node("CanvasLayer/IntroScreen/IntroCard/Margin/VBox/WineryName") as Label
	intro_wine_name = root.get_node("CanvasLayer/IntroScreen/IntroCard/Margin/VBox/WineName") as Label
	intro_region = root.get_node("CanvasLayer/IntroScreen/IntroCard/Margin/VBox/Region") as Label
	intro_text = root.get_node("CanvasLayer/IntroScreen/IntroCard/Margin/VBox/IntroText") as RichTextLabel
	var start_button: Button = root.get_node("CanvasLayer/IntroScreen/IntroCard/Margin/VBox/StartButton") as Button
	start_button.pressed.connect(func() -> void: start_requested.emit())

	inspection_hud = root.get_node("CanvasLayer/InspectionHUD") as Control
	inspection_info_card = root.get_node("CanvasLayer/InspectionHUD/InfoCard") as PanelContainer
	inspection_winery_name = root.get_node("CanvasLayer/InspectionHUD/InfoCard/Margin/VBox/WineryName") as Label
	inspection_wine_name = root.get_node("CanvasLayer/InspectionHUD/InfoCard/Margin/VBox/WineName") as Label
	inspection_region = root.get_node("CanvasLayer/InspectionHUD/InfoCard/Margin/VBox/Region") as Label
	inspection_text = root.get_node("CanvasLayer/InspectionHUD/InfoCard/Margin/VBox/IntroText") as RichTextLabel
	enter_winery_button = root.get_node("CanvasLayer/InspectionHUD/InfoCard/Margin/VBox/EnterWineryButton") as Button
	enter_winery_button.pressed.connect(func() -> void: enter_winery_requested.emit())
	unlock_feedback_label = Label.new()
	unlock_feedback_label.text = ""
	unlock_feedback_label.visible = false
	unlock_feedback_label.label_settings = _make_label_settings(13, Color(0.63, 0.86, 0.72, 1.0))
	(root.get_node("CanvasLayer/InspectionHUD/InfoCard/Margin/VBox") as VBoxContainer).add_child(unlock_feedback_label)
	hotspot_panel = root.get_node("CanvasLayer/InspectionHUD/HotspotPanel") as PanelContainer
	inspection_hint = root.get_node("CanvasLayer/InspectionHUD/InspectionHint") as Label

	winery_hud = root.get_node("CanvasLayer/WineryHUD") as Control
	winery_info_card = root.get_node("CanvasLayer/WineryHUD/InfoCard") as PanelContainer
	winery_title = root.get_node("CanvasLayer/WineryHUD/InfoCard/Margin/VBox/Title") as Label
	winery_text = root.get_node("CanvasLayer/WineryHUD/InfoCard/Margin/VBox/Text") as RichTextLabel
	var return_button: Button = root.get_node("CanvasLayer/WineryHUD/InfoCard/Margin/VBox/ReturnButton") as Button
	return_button.pressed.connect(func() -> void: return_to_vial_requested.emit())
	door_prompt_label = root.get_node("CanvasLayer/WineryHUD/DoorPrompt") as Label
	winery_modal = root.get_node("CanvasLayer/WineryHUD/WineryModal") as PanelContainer
	winery_modal_title = root.get_node("CanvasLayer/WineryHUD/WineryModal/Margin/VBox/Title") as Label
	winery_modal_text = root.get_node("CanvasLayer/WineryHUD/WineryModal/Margin/VBox/Text") as RichTextLabel
	var modal_close: Button = root.get_node("CanvasLayer/WineryHUD/WineryModal/Margin/VBox/CloseButton") as Button
	modal_close.pressed.connect(close_winery_modal)

	winery_modal.modulate.a = 0.0
	winery_modal.scale = Vector2(0.96, 0.96)


func apply_client_profile(client_data: Dictionary) -> void:
	var winery_name_value: String = str(client_data.get("winery_name", "Unknown Winery"))
	var wine_name_value: String = str(client_data.get("wine_name", "Untitled Wine"))
	var region_value: String = "%s, %s" % [str(client_data.get("region_name", "")), str(client_data.get("country", ""))]
	var experience_settings: Dictionary = client_data.get("experience_settings", {})
	var environment_settings: Dictionary = client_data.get("environment_settings", {})
	var intro_title_value: String = str(experience_settings.get("intro_title", wine_name_value))
	var intro_body_value: String = "%s\n\n%s" % [intro_title_value, str(experience_settings.get("intro_text", ""))]
	var winery_info_value: String = str(environment_settings.get("ambience_text", experience_settings.get("winery_info_text", "")))
	var winery_scene_name: String = str(experience_settings.get("winery_scene_name", "default_cellar"))

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


func apply_state(state: int) -> void:
	intro_screen.visible = state == ExperienceManager.ExperienceState.INTRO
	inspection_hud.visible = state == ExperienceManager.ExperienceState.VIAL_INSPECTION
	winery_hud.visible = state == ExperienceManager.ExperienceState.WINERY_INTERIOR
	inspection_hint.visible = state == ExperienceManager.ExperienceState.VIAL_INSPECTION
	if state != ExperienceManager.ExperienceState.WINERY_INTERIOR:
		close_winery_modal()
		door_prompt_label.text = ""


func set_enter_winery_enabled(enabled: bool) -> void:
	enter_winery_button.disabled = not enabled
	enter_winery_button.text = "Enter Winery" if enabled else "View required points first"
	enter_winery_button.modulate = Color(1.0, 1.0, 1.0, 1.0) if enabled else Color(0.72, 0.72, 0.72, 0.82)
	unlock_feedback_label.text = "Winery unlocked" if enabled else ""
	unlock_feedback_label.visible = enabled


func set_door_prompt(prompt: String) -> void:
	door_prompt_label.text = prompt


func show_interactable_modal(interactable_data: Dictionary) -> void:
	if not interactable_data.is_empty():
		winery_modal_title.text = str(interactable_data.get("title", winery_modal_title.text))
		winery_modal_text.text = str(interactable_data.get("text", winery_modal_text.text))
	_show_winery_modal()


func close_winery_modal() -> void:
	_hide_winery_modal()


func _show_winery_modal() -> void:
	winery_modal.visible = true
	winery_modal.pivot_offset = winery_modal.size * 0.5
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(winery_modal, "modulate:a", 1.0, 0.16)
	tween.tween_property(winery_modal, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _hide_winery_modal() -> void:
	if not winery_modal.visible:
		return
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(winery_modal, "modulate:a", 0.0, 0.12)
	tween.tween_property(winery_modal, "scale", Vector2(0.96, 0.96), 0.12)
	await tween.finished
	winery_modal.visible = false


func _make_label_settings(font_size: int, font_color: Color) -> LabelSettings:
	var settings: LabelSettings = LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = font_color
	return settings
