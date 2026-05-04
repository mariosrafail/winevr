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
var _winery_modal_tween: Tween
var _intro_scroll: ScrollContainer
var _inspection_scroll: ScrollContainer
var _winery_info_scroll: ScrollContainer
var _winery_modal_scroll: ScrollContainer


func setup(root: Node) -> void:
	intro_screen = root.get_node("CanvasLayer/IntroScreen") as Control
	intro_card = root.get_node("CanvasLayer/IntroScreen/IntroCard") as PanelContainer
	intro_winery_name = root.get_node("CanvasLayer/IntroScreen/IntroCard/Margin/VBox/WineryName") as Label
	intro_wine_name = root.get_node("CanvasLayer/IntroScreen/IntroCard/Margin/VBox/WineName") as Label
	intro_region = root.get_node("CanvasLayer/IntroScreen/IntroCard/Margin/VBox/Region") as Label
	intro_text = root.get_node("CanvasLayer/IntroScreen/IntroCard/Margin/VBox/IntroText") as RichTextLabel
	var start_button: Button = root.get_node("CanvasLayer/IntroScreen/IntroCard/Margin/VBox/StartButton") as Button
	PremiumUIStyles.apply_gold_outline_button(start_button)
	start_button.pressed.connect(func() -> void: start_requested.emit())

	inspection_hud = root.get_node("CanvasLayer/InspectionHUD") as Control
	inspection_info_card = root.get_node("CanvasLayer/InspectionHUD/InfoCard") as PanelContainer
	inspection_winery_name = root.get_node("CanvasLayer/InspectionHUD/InfoCard/Margin/VBox/WineryName") as Label
	inspection_wine_name = root.get_node("CanvasLayer/InspectionHUD/InfoCard/Margin/VBox/WineName") as Label
	inspection_region = root.get_node("CanvasLayer/InspectionHUD/InfoCard/Margin/VBox/Region") as Label
	inspection_text = root.get_node("CanvasLayer/InspectionHUD/InfoCard/Margin/VBox/IntroText") as RichTextLabel
	enter_winery_button = root.get_node("CanvasLayer/InspectionHUD/InfoCard/Margin/VBox/EnterWineryButton") as Button
	enter_winery_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_enter_winery_button_style()
	enter_winery_button.pressed.connect(_on_enter_winery_button_pressed)
	unlock_feedback_label = Label.new()
	unlock_feedback_label.text = ""
	unlock_feedback_label.visible = false
	unlock_feedback_label.label_settings = _make_label_settings(13, Color(0.92, 0.76, 0.45, 1.0))
	(root.get_node("CanvasLayer/InspectionHUD/InfoCard/Margin/VBox") as VBoxContainer).add_child(unlock_feedback_label)
	hotspot_panel = root.get_node("CanvasLayer/InspectionHUD/HotspotPanel") as PanelContainer
	inspection_hint = root.get_node("CanvasLayer/InspectionHUD/InspectionHint") as Label

	winery_hud = root.get_node("CanvasLayer/WineryHUD") as Control
	winery_info_card = root.get_node("CanvasLayer/WineryHUD/InfoCard") as PanelContainer
	winery_title = root.get_node("CanvasLayer/WineryHUD/InfoCard/Margin/VBox/Title") as Label
	winery_text = root.get_node("CanvasLayer/WineryHUD/InfoCard/Margin/VBox/Text") as RichTextLabel
	var return_button: Button = root.get_node("CanvasLayer/WineryHUD/InfoCard/Margin/VBox/ReturnButton") as Button
	PremiumUIStyles.apply_gold_outline_button(return_button)
	return_button.pressed.connect(func() -> void: return_to_vial_requested.emit())
	door_prompt_label = root.get_node("CanvasLayer/WineryHUD/DoorPrompt") as Label
	winery_modal = root.get_node("CanvasLayer/WineryHUD/WineryModal") as PanelContainer
	winery_modal_title = root.get_node("CanvasLayer/WineryHUD/WineryModal/Margin/VBox/Title") as Label
	winery_modal_text = root.get_node("CanvasLayer/WineryHUD/WineryModal/Margin/VBox/Text") as RichTextLabel
	var modal_close: Button = root.get_node("CanvasLayer/WineryHUD/WineryModal/Margin/VBox/CloseButton") as Button
	PremiumUIStyles.apply_gold_outline_button(modal_close)
	modal_close.pressed.connect(close_winery_modal)
	_intro_scroll = _wrap_rich_text_with_scroll(intro_text)
	_inspection_scroll = _wrap_rich_text_with_scroll(inspection_text)
	_winery_info_scroll = _wrap_rich_text_with_scroll(winery_text)
	_winery_modal_scroll = _wrap_rich_text_with_scroll(winery_modal_text)
	_configure_scroll_text(intro_text)
	_configure_scroll_text(inspection_text)
	_configure_scroll_text(winery_text)
	_configure_scroll_text(winery_modal_text)
	_apply_premium_visual_style()

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
	if OS.is_debug_build():
		print("[WineVR][EnterWinery] HUD button enabled=%s disabled=%s text=\"%s\"" % [enabled, enter_winery_button.disabled, enter_winery_button.text])


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
	_stop_winery_modal_tween()
	winery_modal.visible = true
	winery_modal.pivot_offset = winery_modal.size * 0.5
	_winery_modal_tween = create_tween()
	_winery_modal_tween.set_parallel(true)
	_winery_modal_tween.tween_property(winery_modal, "modulate:a", 1.0, 0.16)
	_winery_modal_tween.tween_property(winery_modal, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _hide_winery_modal() -> void:
	if not winery_modal.visible:
		return
	_stop_winery_modal_tween()
	_winery_modal_tween = create_tween()
	_winery_modal_tween.set_parallel(true)
	_winery_modal_tween.tween_property(winery_modal, "modulate:a", 0.0, 0.12)
	_winery_modal_tween.tween_property(winery_modal, "scale", Vector2(0.96, 0.96), 0.12)
	await _winery_modal_tween.finished
	winery_modal.visible = false


func _make_label_settings(font_size: int, font_color: Color) -> LabelSettings:
	var settings: LabelSettings = LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = font_color
	return settings


func _apply_enter_winery_button_style() -> void:
	PremiumUIStyles.apply_gold_outline_button(enter_winery_button)


func _on_enter_winery_button_pressed() -> void:
	if OS.is_debug_build():
		print("[WineVR][EnterWinery] button pressed disabled=%s visible=%s" % [enter_winery_button.disabled, enter_winery_button.visible])
	enter_winery_requested.emit()


func _make_button_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style


func _stop_winery_modal_tween() -> void:
	if _winery_modal_tween != null:
		_winery_modal_tween.kill()
		_winery_modal_tween = null


func apply_panel_height_policy(viewport_size: Vector2) -> void:
	var small_min_h: float = 120.0
	var modal_min_h: float = 180.0
	_apply_scroll_height(intro_card, _intro_scroll, intro_text, modal_min_h, viewport_size.y * 0.5, 86.0, 110.0)
	_apply_scroll_height(inspection_info_card, _inspection_scroll, inspection_text, modal_min_h, viewport_size.y * 0.55, 90.0, 130.0)
	_apply_scroll_height(winery_info_card, _winery_info_scroll, winery_text, modal_min_h, viewport_size.y * 0.55, 94.0, 130.0)
	_apply_scroll_height(winery_modal, _winery_modal_scroll, winery_modal_text, modal_min_h, viewport_size.y * 0.5, 92.0, 130.0)
	if hotspot_panel != null:
		hotspot_panel.custom_minimum_size.y = small_min_h


func _configure_scroll_text(text_node: RichTextLabel) -> void:
	text_node.fit_content = true
	text_node.scroll_active = false
	text_node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_node.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _wrap_rich_text_with_scroll(text_node: RichTextLabel) -> ScrollContainer:
	var vbox: VBoxContainer = text_node.get_parent() as VBoxContainer
	if vbox == null:
		return null
	var old_index: int = text_node.get_index()
	vbox.remove_child(text_node)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = text_node.name + "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var content: VBoxContainer = VBoxContainer.new()
	content.name = "ContentVBox"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	content.add_child(text_node)
	vbox.add_child(scroll)
	vbox.move_child(scroll, old_index)
	return scroll


func _apply_scroll_height(panel_node: PanelContainer, scroll: ScrollContainer, text_node: RichTextLabel, min_h: float, max_h: float, reserved_bottom: float, min_scroll_height: float) -> void:
	if scroll == null:
		return
	if panel_node == null:
		return
	var panel_height_cap: float = clampf(panel_node.size.y - reserved_bottom, min_scroll_height, max_h)
	var content_h: float = maxf(min_h, text_node.get_content_height() + 20.0)
	var target_h: float = clampf(content_h, min_scroll_height, panel_height_cap)
	scroll.custom_minimum_size.y = target_h
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _apply_premium_visual_style() -> void:
	for panel_node in [intro_card, inspection_info_card, winery_info_card, hotspot_panel, winery_modal]:
		if panel_node is PanelContainer:
			var card: PanelContainer = panel_node as PanelContainer
			ResponsiveLayoutController.apply_premium_panel_style(card)
			_attach_premium_chrome(card)

	for lbl in [intro_winery_name, inspection_winery_name]:
		lbl.modulate = PremiumUIStyles.GOLD_ACCENT
	for lbl in [intro_wine_name, inspection_wine_name, winery_title, winery_modal_title]:
		lbl.modulate = PremiumUIStyles.TEXT_TITLE
	for lbl in [intro_region, inspection_region, door_prompt_label]:
		lbl.modulate = PremiumUIStyles.TEXT_MUTED
	for txt in [intro_text, inspection_text, winery_text, winery_modal_text]:
		txt.add_theme_color_override("default_color", PremiumUIStyles.TEXT_BODY)


func _attach_premium_chrome(panel_node: PanelContainer) -> void:
	if panel_node == null:
		return
	var vbox: VBoxContainer = panel_node.get_node_or_null("Margin/VBox") as VBoxContainer
	if vbox == null:
		return
	if vbox.get_node_or_null("TopAccent") == null:
		var top_accent: ColorRect = ColorRect.new()
		top_accent.name = "TopAccent"
		top_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_accent.color = Color(PremiumUIStyles.GOLD_ACCENT.r, PremiumUIStyles.GOLD_ACCENT.g, PremiumUIStyles.GOLD_ACCENT.b, 0.82)
		top_accent.custom_minimum_size = Vector2(0.0, 2.0)
		vbox.add_child(top_accent)
		vbox.move_child(top_accent, 0)
	if vbox.get_node_or_null("TitleDivider") == null:
		var divider: ColorRect = ColorRect.new()
		divider.name = "TitleDivider"
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		divider.color = Color(PremiumUIStyles.GOLD_ACCENT.r, PremiumUIStyles.GOLD_ACCENT.g, PremiumUIStyles.GOLD_ACCENT.b, 0.24)
		divider.custom_minimum_size = Vector2(0.0, 1.0)
		var insert_index: int = mini(3, vbox.get_child_count())
		vbox.add_child(divider)
		vbox.move_child(divider, insert_index)
