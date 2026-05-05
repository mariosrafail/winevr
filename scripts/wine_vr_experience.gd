extends Node

@onready var vial_preview: VialPreviewController = $VialPreview
@onready var winery_interior: WineryInteriorController = $WineryInterior
@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var panel_dim: ColorRect = $CanvasLayer/PanelDim
@onready var fade_rect: ColorRect = $CanvasLayer/FadeRect

const DEMO_VIEWPORT_PRESETS: Array[Dictionary] = [
	{"name": "native", "size": Vector2i.ZERO},
	{"name": "desktop 16:9", "size": Vector2i(1280, 720)},
	{"name": "mobile portrait", "size": Vector2i(390, 844)},
	{"name": "tablet landscape", "size": Vector2i(1024, 768)}
]

var _transition_in_progress: bool = false
var _profile_loading: bool = false
var _active_client_id: String = ""
var _demo_viewport_preset_index: int = 0
var _native_window_size: Vector2i = Vector2i.ZERO
var _last_window_size: Vector2i = Vector2i.ZERO
var _demo_mode: bool = false
var _ui_hidden_for_capture: bool = false

var _qr_screen: QRScreenController
var _loading_overlay: LoadingOverlayController
var _hotspots: HotspotUIController
var _hud: ExperienceHUDController
var _mobile_controls: MobileControlsController
var _narrative_panel: NarrativePanelController
var _onboarding: OnboardingOverlayController
var _dev_overlay: DevOverlayController
var _layout: ResponsiveLayoutController
var _graphics_manager: GraphicsSettingsManager
var _graphics_panel: GraphicsSettingsPanelController
var _crosshair: CrosshairController
var _exploration_mode: ExplorationModeController
var _journey: TastingJourneyController


func _ready() -> void:
	_ensure_exploration_input_actions()
	_build_components()
	canvas_layer.move_child(fade_rect, canvas_layer.get_child_count() - 1)
	if _graphics_panel != null:
		await _graphics_panel.apply_saved_display_settings()

	ClientProfileLoader.client_profile_changed.connect(_on_client_profile_changed)
	ExperienceManager.state_changed.connect(_on_state_changed)
	winery_interior.door_prompt_changed.connect(Callable(_hud, "set_door_prompt"))
	winery_interior.door_interacted.connect(_on_winery_interacted)
	winery_interior.layout_refresh_requested.connect(refresh_all_ui_layouts)

	_apply_client_profile(ClientProfileLoader.get_active_client_data())
	_narrative_panel.refresh()
	_apply_state(ExperienceManager.current_state)
	_last_window_size = DisplayServer.window_get_size()
	panel_dim.modulate.a = 0.0
	await refresh_all_ui_layouts("startup")
	await refresh_all_ui_layouts("startup")
	_print_runtime_health_status()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		var new_window_size: Vector2i = DisplayServer.window_get_size()
		await refresh_all_ui_layouts("window size changed")
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		var panel_rect: Rect2 = _graphics_panel.get_panel_rect() if _graphics_panel != null else Rect2()
		print("[WineVR][Viewport] old_window=%s new_window=%s viewport=%s options_pos=%s options_size=%s" % [
			str(_last_window_size),
			str(new_window_size),
			str(viewport_size),
			str(panel_rect.position),
			str(panel_rect.size)
		])
		_last_window_size = new_window_size


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _exploration_mode != null and _exploration_mode.handle_input(event):
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_R:
			_reset_current_experience()
			return
		if event.keycode == KEY_ESCAPE:
			if _graphics_panel != null and _graphics_panel.is_open():
				_graphics_panel.close()
				return
			if _journey != null and _journey.close_open_modal():
				return
			if _graphics_panel != null and ExperienceManager.current_state != ExperienceManager.ExperienceState.QR_SCAN:
				_graphics_panel.open()
				return
			_return_to_qr_scan_debug()
			return
		if event.keycode == KEY_F7:
			_set_demo_mode(not _demo_mode)
			return
		if event.keycode == KEY_F8:
			_set_ui_hidden_for_capture(true)
			return
		if event.keycode == KEY_F9:
			_set_ui_hidden_for_capture(false)
			return
		if event.keycode == KEY_F10:
			_reset_current_view_for_demo()
			return
		if event.keycode == KEY_F3:
			if _demo_mode:
				return
			_dev_overlay.toggle()
			return
		if event.keycode == KEY_F6:
			_cycle_demo_viewport_preset()
			return
		var registry_index: int = _get_debug_registry_index(event.keycode)
		if registry_index >= 0:
			_qr_screen.select_debug_index(registry_index)
	elif _exploration_mode != null:
		if _exploration_mode.handle_input(event):
			get_viewport().set_input_as_handled()


func _build_components() -> void:
	WineDatabase.load_profiles()
	var tasting_entries: Array[Dictionary] = WineDatabase.get_selection_entries()
	var selection_entries: Array[Dictionary] = tasting_entries if not tasting_entries.is_empty() else ClientProfileLoader.get_client_registry(false)
	if tasting_entries.is_empty():
		print("[WineDB] No selection entries from database. Falling back to client registry.")

	_qr_screen = QRScreenController.new()
	add_child(_qr_screen)
	_qr_screen.setup(canvas_layer, selection_entries)
	_qr_screen.client_selected.connect(_select_qr_client)

	_loading_overlay = LoadingOverlayController.new()
	add_child(_loading_overlay)
	_loading_overlay.setup(canvas_layer)

	_hud = ExperienceHUDController.new()
	add_child(_hud)
	_hud.setup(self)
	_hud.start_requested.connect(Callable(ExperienceManager, "start_experience"))
	_hud.enter_winery_requested.connect(_on_enter_winery_pressed)
	_hud.return_to_vial_requested.connect(_on_return_to_vial_pressed)
	_hud.layout_refresh_requested.connect(refresh_all_ui_layouts)

	_hotspots = HotspotUIController.new()
	add_child(_hotspots)
	_hotspots.setup(
		$CanvasLayer/InspectionHUD/HotspotsLayer,
		$CanvasLayer/InspectionHUD/HotspotPanel,
		$CanvasLayer/InspectionHUD/HotspotPanel/Margin/VBox/Title,
		$CanvasLayer/InspectionHUD/HotspotPanel/Margin/VBox/Text,
		$CanvasLayer/InspectionHUD/HotspotPanel/Margin/VBox/CloseButton,
		panel_dim,
		vial_preview
	)
	_hotspots.hotspot_viewed.connect(_on_hotspot_viewed)
	_hotspots.enter_winery_state_changed.connect(Callable(_hud, "set_enter_winery_enabled"))
	_hotspots.layout_refresh_requested.connect(refresh_all_ui_layouts)

	_mobile_controls = MobileControlsController.new()
	add_child(_mobile_controls)
	_mobile_controls.setup(canvas_layer, vial_preview, winery_interior)

	_narrative_panel = NarrativePanelController.new()
	add_child(_narrative_panel)
	_narrative_panel.setup(canvas_layer)
	_narrative_panel.show_target_requested.connect(_on_show_narrative_target_requested)
	_narrative_panel.restart_requested.connect(_reset_current_experience)
	_narrative_panel.layout_refresh_requested.connect(refresh_all_ui_layouts)
	NarrativeManager.narrative_changed.connect(_on_narrative_changed)

	_onboarding = OnboardingOverlayController.new()
	add_child(_onboarding)
	_onboarding.setup(canvas_layer)

	_dev_overlay = DevOverlayController.new()
	add_child(_dev_overlay)
	_dev_overlay.setup(canvas_layer)
	_dev_overlay.set_viewport_mode(_demo_viewport_preset_name())

	_layout = ResponsiveLayoutController.new()
	add_child(_layout)
	_layout.setup(_qr_screen, _hud, _mobile_controls, _narrative_panel, _onboarding)

	_graphics_manager = GraphicsSettingsManager.new()
	add_child(_graphics_manager)
	_graphics_manager.setup(get_tree(), get_viewport(), _resolve_world_environment())
	_graphics_manager.camera_quality_changed.connect(_on_camera_quality_changed)
	_graphics_manager.performance_fallback_suggested.connect(_on_performance_fallback_suggested)

	_graphics_panel = GraphicsSettingsPanelController.new()
	add_child(_graphics_panel)
	_graphics_panel.setup(canvas_layer)
	_graphics_panel.set_values(_graphics_manager.current_preset, _graphics_manager.fps_friendly)
	_graphics_panel.layout(get_viewport().get_visible_rect().size)
	_layout.register_panel(_graphics_panel.prompt_bar, "top_right", Vector2(760.0, 116.0), 0.25)
	_graphics_panel.apply_requested.connect(_on_graphics_apply_requested)
	_graphics_panel.fallback_accept_requested.connect(_on_performance_fallback_accepted)
	_graphics_panel.fallback_ignore_requested.connect(_on_performance_fallback_ignored)
	_graphics_panel.display_settings_applied.connect(_on_display_settings_applied)
	_graphics_panel.layout_refresh_requested.connect(refresh_all_ui_layouts)

	_crosshair = CrosshairController.new()
	_crosshair.setup(canvas_layer)
	winery_interior.interaction_target_changed.connect(_crosshair.set_interactable_state)

	_exploration_mode = ExplorationModeController.new()
	add_child(_exploration_mode)
	_exploration_mode.setup(canvas_layer, winery_interior, _crosshair, _graphics_panel)

	_journey = TastingJourneyController.new()
	add_child(_journey)
	_journey.setup(canvas_layer)
	_journey.active_step_changed.connect(_on_journey_active_step_changed)
	_journey.restart_requested.connect(_reset_current_experience)
	_journey.choose_another_requested.connect(_choose_another_tasting)
	_journey.show_qr_requested.connect(_show_selected_qr_info)
	_journey.layout_refresh_requested.connect(refresh_all_ui_layouts)


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
		_hotspots.reset_viewed()

	var experience_settings: Dictionary = client_data.get("experience_settings", {})
	_hud.apply_client_profile(client_data)
	vial_preview.apply_client_profile(client_data)
	winery_interior.apply_client_profile(client_data)
	if _graphics_manager != null:
		_graphics_manager.set_environment(_resolve_world_environment())
		_graphics_manager.apply_current()
	_hotspots.build_hotspots(experience_settings.get("hotspots", []))
	if _journey != null:
		_journey.configure_from_profile(_get_current_journey_profile(client_data), client_data)
	_update_dev_overlay_context()
	refresh_all_ui_layouts("profile cards loaded")


func _apply_state(state: int) -> void:
	_qr_screen.set_visible(state == ExperienceManager.ExperienceState.QR_SCAN)
	_hud.apply_state(state)
	_narrative_panel.apply_state(state)
	canvas_layer.visible = not _ui_hidden_for_capture

	vial_preview.visible = state != ExperienceManager.ExperienceState.WINERY_INTERIOR
	winery_interior.visible = state == ExperienceManager.ExperienceState.WINERY_INTERIOR
	vial_preview.set_camera_active(state != ExperienceManager.ExperienceState.WINERY_INTERIOR)
	winery_interior.set_camera_active(state == ExperienceManager.ExperienceState.WINERY_INTERIOR)
	vial_preview.set_interaction_enabled(state == ExperienceManager.ExperienceState.VIAL_INSPECTION)
	winery_interior.set_controls_enabled(state == ExperienceManager.ExperienceState.WINERY_INTERIOR)
	_mobile_controls.set_zoom_visible(state == ExperienceManager.ExperienceState.VIAL_INSPECTION)
	_mobile_controls.set_winery_controls_visible(state == ExperienceManager.ExperienceState.WINERY_INTERIOR)
	if _exploration_mode != null:
		_exploration_mode.set_available(state == ExperienceManager.ExperienceState.WINERY_INTERIOR)
	if _journey != null:
		_journey.set_visible_for_state(state == ExperienceManager.ExperienceState.VIAL_INSPECTION)
	_relayout_all_ui(get_viewport().get_visible_rect().size)

	if state != ExperienceManager.ExperienceState.VIAL_INSPECTION:
		_hotspots.close_panel()
	_apply_narrative_target_highlight(NarrativeManager.get_current_step(), false)
	_update_dev_overlay_context()


func _on_hotspot_viewed(hotspot_data: Dictionary) -> void:
	var hotspot_id: String = _hotspots.get_hotspot_id(hotspot_data)
	if _journey != null:
		_journey.complete_hotspot(hotspot_id)
	NarrativeManager.complete_target("hotspot", hotspot_id)


func _on_journey_active_step_changed(step: Dictionary) -> void:
	if _hotspots == null:
		return
	if step.is_empty():
		_hotspots.set_guided_active_hotspot("", false)
		if _crosshair != null and _crosshair.visible:
			_crosshair.set_interactable_state(false, "")
		return

	var hotspot_id: String = str(step.get("id", ""))
	var title: String = str(step.get("title", "Tasting Step"))
	_hotspots.set_guided_active_hotspot(hotspot_id, true)
	_hotspots.pulse_target(hotspot_id)
	if _crosshair != null and _crosshair.visible:
		_crosshair.set_interactable_state(true, title)


func _choose_another_tasting() -> void:
	if _exploration_mode != null and _exploration_mode.active:
		_exploration_mode.exit_mode()
	_hotspots.close_panel()
	_hud.close_winery_modal()
	_narrative_panel.clear_hint()
	ExperienceManager.show_qr_scan()
	refresh_all_ui_layouts("choose another tasting")


func _show_selected_qr_info() -> void:
	var profile: Dictionary = AppState.selected_profile_data
	var organization_name: String = str(profile.get("organization_name", profile.get("winery", "this winery")))
	var qr_url: String = str(profile.get("qr_target_url", ""))
	var qr_image: String = str(profile.get("qr_code_image", ""))
	var body: String = "Scan this QR to learn more about %s." % organization_name
	if not qr_url.is_empty():
		body += "\n\n%s" % qr_url
	await _hotspots.open_centered_annotation_panel("Winery QR", body, {
		"qr_image": qr_image,
		"min_height": 420.0,
		"max_height_ratio": 0.82
	})


func _get_current_journey_profile(client_data: Dictionary) -> Dictionary:
	if not AppState.selected_profile_data.is_empty():
		return AppState.selected_profile_data
	var profile: Dictionary = {
		"name": str(client_data.get("wine_name", client_data.get("client_name", "Selected Wine"))),
		"winery": str(client_data.get("organization_name", client_data.get("client_name", ""))),
		"region": str(client_data.get("region_name", client_data.get("region", "")))
	}
	var experience_settings: Dictionary = client_data.get("experience_settings", {})
	profile["hotspots"] = experience_settings.get("hotspots", [])
	return profile


func _on_winery_interacted(interactable_data: Dictionary = {}) -> void:
	if _exploration_mode != null and _exploration_mode.active:
		_exploration_mode.exit_mode()
	if not interactable_data.is_empty():
		var interactable_id: String = str(interactable_data.get("id", ""))
		var interactable_type: String = str(interactable_data.get("type", "zone"))
		NarrativeManager.complete_target("zone", interactable_id)
		NarrativeManager.complete_target(interactable_type, interactable_id)
		if interactable_data.has("target_type") and interactable_data.has("target_id"):
			NarrativeManager.complete_target(str(interactable_data.get("target_type", "")), str(interactable_data.get("target_id", "")))
	_hud.show_interactable_modal(interactable_data)


func _on_narrative_changed(current_step: Dictionary, _current_index: int, _total_steps: int) -> void:
	_apply_narrative_target_highlight(current_step, false)
	_update_dev_overlay_context()


func _on_show_narrative_target_requested(current_step: Dictionary) -> void:
	_apply_narrative_target_highlight(current_step, true, true)


func _apply_narrative_target_highlight(current_step: Dictionary, show_hint: bool, pulse_target: bool = false) -> void:
	var journey_step: Dictionary = _journey.get_active_step() if _journey != null else {}
	var journey_controls_hotspots: bool = not journey_step.is_empty() and ExperienceManager.current_state == ExperienceManager.ExperienceState.VIAL_INSPECTION
	if not journey_controls_hotspots:
		_hotspots.clear_target_highlight()
	winery_interior.clear_narrative_highlight()
	_narrative_panel.clear_hint()
	if current_step.is_empty():
		if journey_controls_hotspots:
			_on_journey_active_step_changed(journey_step)
		return

	var target_type: String = str(current_step.get("target_type", "free"))
	var target_id: String = str(current_step.get("target_id", ""))
	var state: int = ExperienceManager.current_state

	match target_type:
		"hotspot":
			if state == ExperienceManager.ExperienceState.VIAL_INSPECTION:
				if journey_controls_hotspots:
					if show_hint:
						_narrative_panel.show_hint("Follow the active tasting step: %s." % str(journey_step.get("title", "Tasting Step")))
				else:
					var hotspot_found: bool = false
					if pulse_target:
						hotspot_found = _hotspots.pulse_target(target_id)
					else:
						hotspot_found = _hotspots.highlight_target(target_id)
					if show_hint:
						_narrative_panel.show_hint("Open the highlighted note on the vial." if hotspot_found else "This tasting note is not available in the current vial.")
			elif show_hint:
				_narrative_panel.show_hint("Return to the vial to continue the tasting.")
		"zone", "prop", "door":
			if state == ExperienceManager.ExperienceState.WINERY_INTERIOR:
				var highlighted: bool = winery_interior.pulse_narrative_target(target_type, target_id) if pulse_target else winery_interior.highlight_narrative_target(target_type, target_id)
				if show_hint:
					_narrative_panel.show_hint("Explore the cellar and open the highlighted detail." if highlighted else "This winery detail is not available in the current room.")
			elif show_hint:
				_narrative_panel.show_hint("Enter the winery first to reveal this cellar detail.")
		_:
			if show_hint:
				_narrative_panel.show_hint("Continue when you are ready.")
	if journey_controls_hotspots:
		_on_journey_active_step_changed(journey_step)


func _on_enter_winery_pressed() -> void:
	var can_enter: bool = _hotspots.can_enter_winery()
	if OS.is_debug_build():
		print("[WineVR][EnterWinery] request received transition=%s can_enter=%s state=%s" % [_transition_in_progress, can_enter, _state_name(ExperienceManager.current_state)])
	if not _transition_in_progress and can_enter:
		ExperienceManager.enter_winery()


func _on_return_to_vial_pressed() -> void:
	if not _transition_in_progress:
		_return_to_vial_with_fade()


func _enter_winery_with_fade() -> void:
	if _transition_in_progress:
		return
	_transition_in_progress = true
	vial_preview.set_interaction_enabled(false)
	await _fade_to(1.0)
	ExperienceManager.finish_winery_entry()
	winery_interior.reset_view()
	await refresh_all_ui_layouts("winery scene loaded")
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
	var tween: Tween = create_tween()
	tween.tween_property(fade_rect, "color:a", target_alpha, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _select_qr_client(client_id: String) -> void:
	if _profile_loading:
		return

	_profile_loading = true
	_qr_screen.set_error("")
	_loading_overlay.show_loading("Preparing tasting")
	await get_tree().create_timer(0.18).timeout

	_hotspots.reset_viewed()
	_hotspots.close_panel()
	_hud.close_winery_modal()
	var selected_wine_profile: Dictionary = WineDatabase.get_profile_by_id(client_id)
	if not selected_wine_profile.is_empty():
		AppState.set_selected_profile(client_id, selected_wine_profile)
		var runtime_profile: Dictionary = WineDatabase.build_runtime_client_profile(selected_wine_profile)
		if ClientProfileLoader.load_runtime_profile(client_id, runtime_profile):
			vial_preview.reset_view()
			winery_interior.reset_view()
			ExperienceManager.enter_intro()
			_onboarding.show_once()
			await refresh_all_ui_layouts("tasting selected")
		else:
			_qr_screen.set_error("This tasting profile is not available right now.")
			ExperienceManager.show_qr_scan()
	elif not ClientProfileLoader.profile_exists(client_id):
		_qr_screen.set_error("This tasting profile is not ready yet.")
		ExperienceManager.show_qr_scan()
	elif ClientProfileLoader.load_client_profile(client_id):
		AppState.clear_selected_profile()
		vial_preview.reset_view()
		winery_interior.reset_view()
		ExperienceManager.enter_intro()
		_onboarding.show_once()
		await refresh_all_ui_layouts("tasting selected")
	else:
		_qr_screen.set_error("This tasting profile is not available right now.")
		ExperienceManager.show_qr_scan()

	_loading_overlay.hide_loading()
	_profile_loading = false


func _reset_current_experience() -> void:
	_hotspots.reset_viewed()
	_hotspots.close_panel()
	_hud.close_winery_modal()
	_narrative_panel.clear_hint()
	NarrativeManager.reset()
	if _journey != null:
		_journey.configure_from_profile(_get_current_journey_profile(ClientProfileLoader.get_active_client_data()), ClientProfileLoader.get_active_client_data())
		_journey.set_visible_for_state(false)
	vial_preview.reset_view()
	winery_interior.reset_view()
	winery_interior.clear_narrative_highlight()
	ExperienceManager.enter_intro()
	_update_dev_overlay_context()
	refresh_all_ui_layouts("panel opened")


func _set_demo_mode(enabled: bool) -> void:
	_demo_mode = enabled
	winery_interior.set_demo_mode(enabled)
	if _demo_mode and _dev_overlay != null:
		_dev_overlay.hide_overlay()
	if OS.is_debug_build():
		print("[WineVR][Demo] demo_mode=%s" % _demo_mode)


func _on_graphics_apply_requested(preset_name: String, fps_friendly: bool) -> void:
	if _graphics_manager == null:
		return
	_graphics_manager.set_preset(preset_name)
	_graphics_manager.set_fps_friendly(fps_friendly)
	_graphics_manager.apply_current()
	_graphics_panel.set_values(_graphics_manager.current_preset, _graphics_manager.fps_friendly)


func _on_camera_quality_changed(multiplier: float) -> void:
	winery_interior.set_camera_transition_quality(multiplier)


func _on_performance_fallback_suggested() -> void:
	if _graphics_panel != null:
		_graphics_panel.show_fallback_prompt()


func _on_performance_fallback_accepted() -> void:
	if _graphics_manager == null:
		return
	_graphics_manager.set_preset(GraphicsSettingsManager.PRESET_ULTRA_LOW)
	_graphics_manager.set_fps_friendly(true)
	_graphics_manager.apply_current()
	_graphics_manager.mark_fallback_suggestion_resolved()
	if _graphics_panel != null:
		_graphics_panel.set_values(_graphics_manager.current_preset, _graphics_manager.fps_friendly)


func _on_performance_fallback_ignored() -> void:
	if _graphics_manager != null:
		_graphics_manager.mark_fallback_suggestion_resolved()


func _resolve_world_environment() -> Environment:
	if winery_interior == null or winery_interior.world_environment == null:
		return null
	return winery_interior.world_environment.environment


func _set_ui_hidden_for_capture(hidden: bool) -> void:
	_ui_hidden_for_capture = hidden
	canvas_layer.visible = not hidden
	if not hidden:
		_apply_state(ExperienceManager.current_state)
	if OS.is_debug_build():
		print("[WineVR][Demo] ui_hidden=%s" % _ui_hidden_for_capture)


func _reset_current_view_for_demo() -> void:
	match ExperienceManager.current_state:
		ExperienceManager.ExperienceState.WINERY_INTERIOR:
			winery_interior.reset_view()
		ExperienceManager.ExperienceState.WINERY_ENTRY:
			winery_interior.reset_view()
		_:
			vial_preview.reset_view()
	if OS.is_debug_build():
		print("[WineVR][Demo] reset view for state=%s" % _state_name(ExperienceManager.current_state))


# Dev-only shortcut: Escape returns to the QR/client selection screen without unloading data.
func _return_to_qr_scan_debug() -> void:
	_hotspots.close_panel()
	_hud.close_winery_modal()
	_narrative_panel.clear_hint()
	_hotspots.clear_target_highlight()
	winery_interior.clear_narrative_highlight()
	ExperienceManager.show_qr_scan()
	_update_dev_overlay_context()


func _get_debug_registry_index(keycode: int) -> int:
	if keycode >= KEY_1 and keycode <= KEY_9:
		return keycode - KEY_1
	return -1


func _update_dev_overlay_context() -> void:
	if _dev_overlay == null:
		return
	_dev_overlay.set_viewport_mode(_demo_viewport_preset_name())
	var step: Dictionary = NarrativeManager.get_current_step()
	_dev_overlay.set_context(
		_active_client_id,
		_state_name(ExperienceManager.current_state),
		str(step.get("title", "")),
		str(step.get("target_type", "")),
		str(step.get("target_id", ""))
	)


func _cycle_demo_viewport_preset() -> void:
	if OS.has_feature("web"):
		return
	if _native_window_size == Vector2i.ZERO:
		_native_window_size = DisplayServer.window_get_size()
	_demo_viewport_preset_index = (_demo_viewport_preset_index + 1) % DEMO_VIEWPORT_PRESETS.size()
	var preset: Dictionary = DEMO_VIEWPORT_PRESETS[_demo_viewport_preset_index]
	var raw_preset_size: Variant = preset.get("size", Vector2i.ZERO)
	var preset_size: Vector2i = raw_preset_size if raw_preset_size is Vector2i else Vector2i.ZERO
	if preset_size == Vector2i.ZERO:
		preset_size = _native_window_size
	DisplayServer.window_set_size(preset_size)
	_center_window(preset_size)
	_relayout_all_ui(Vector2(preset_size))
	refresh_all_ui_layouts("resolution changed")
	if _dev_overlay != null:
		_dev_overlay.set_viewport_mode(_demo_viewport_preset_name())


func _center_window(window_size: Vector2i) -> void:
	var screen_id: int = DisplayServer.window_get_current_screen()
	var screen_position: Vector2i = DisplayServer.screen_get_position(screen_id)
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen_id)
	DisplayServer.window_set_position(screen_position + (screen_size - window_size) / 2)


func _demo_viewport_preset_name() -> String:
	if _demo_viewport_preset_index < 0 or _demo_viewport_preset_index >= DEMO_VIEWPORT_PRESETS.size():
		return "native"
	return str(DEMO_VIEWPORT_PRESETS[_demo_viewport_preset_index].get("name", "native"))


func _print_runtime_health_status() -> void:
	var enabled_clients: Array[Dictionary] = ClientProfileLoader.get_client_registry(false)
	var active_client_data: Dictionary = ClientProfileLoader.get_active_client_data()
	var raw_environment_settings: Variant = active_client_data.get("environment_settings", {})
	var environment_settings: Dictionary = {}
	if typeof(raw_environment_settings) == TYPE_DICTIONARY:
		environment_settings = raw_environment_settings as Dictionary
	var visual_quality: String = str(environment_settings.get("visual_quality", "medium"))
	var validation_status: String = _runtime_validation_status(enabled_clients, active_client_data, visual_quality)
	print("[WineVR][Health] registry loaded: %s" % (enabled_clients.size() > 0))
	print("[WineVR][Health] enabled clients: %s" % enabled_clients.size())
	print("[WineVR][Health] active client: %s" % (ClientProfileLoader.active_client_id if not ClientProfileLoader.active_client_id.is_empty() else "<none>"))
	print("[WineVR][Health] validation status: %s" % validation_status)
	print("[WineVR][Health] visual quality: %s" % visual_quality)


func _runtime_validation_status(enabled_clients: Array[Dictionary], active_client_data: Dictionary, visual_quality: String) -> String:
	if enabled_clients.is_empty():
		return "warning: no enabled clients"
	if active_client_data.is_empty():
		return "warning: no active client profile"
	if not ["low", "medium", "high"].has(visual_quality):
		return "warning: invalid visual_quality '%s'" % visual_quality
	if not active_client_data.has("experience_settings") or not active_client_data.has("environment_settings"):
		return "warning: active profile missing required runtime sections"
	return "ok"


func _state_name(state: int) -> String:
	match state:
		ExperienceManager.ExperienceState.QR_SCAN:
			return "QR_SCAN"
		ExperienceManager.ExperienceState.INTRO:
			return "INTRO"
		ExperienceManager.ExperienceState.VIAL_INSPECTION:
			return "VIAL_INSPECTION"
		ExperienceManager.ExperienceState.WINERY_ENTRY:
			return "WINERY_ENTRY"
		ExperienceManager.ExperienceState.WINERY_INTERIOR:
			return "WINERY_INTERIOR"
		_:
			return "UNKNOWN"


func _on_display_settings_applied(old_window_size: Vector2i, new_window_size: Vector2i, viewport_size: Vector2) -> void:
	await refresh_all_ui_layouts("resolution changed")
	var panel_rect: Rect2 = _graphics_panel.get_panel_rect() if _graphics_panel != null else Rect2()
	print("[WineVR][Viewport] old_window=%s new_window=%s viewport=%s options_pos=%s options_size=%s" % [
		str(old_window_size),
		str(new_window_size),
		str(viewport_size),
		str(panel_rect.position),
		str(panel_rect.size)
	])
	_last_window_size = new_window_size


func _relayout_all_ui(viewport_size: Vector2) -> void:
	if _layout != null:
		_layout.refresh_all(viewport_size, "legacy relayout")
	if _hud != null:
		_hud.apply_panel_height_policy(viewport_size)
	if _graphics_panel != null:
		_graphics_panel.layout(viewport_size)
	if _hotspots != null:
		_hotspots.layout_hotspots()
	if winery_interior != null:
		winery_interior.refresh_interaction_ui_layout(viewport_size)
	if _dev_overlay != null:
		_dev_overlay.layout(viewport_size, 20.0)
	if _exploration_mode != null:
		_exploration_mode.layout(viewport_size)
	if _journey != null:
		_journey.layout(viewport_size)


func refresh_all_ui_layouts(reason: String = "manual") -> void:
	await get_tree().process_frame
	await _wait_for_valid_viewport()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if _layout != null:
		_layout.refresh_all(viewport_size, reason)
	if _hud != null:
		_hud.apply_panel_height_policy(viewport_size)
	if _graphics_panel != null:
		_graphics_panel.layout(viewport_size)
	if _hotspots != null:
		_hotspots.layout_hotspots()
	if winery_interior != null:
		winery_interior.refresh_interaction_ui_layout(viewport_size)
	if _dev_overlay != null:
		_dev_overlay.layout(viewport_size, 20.0)
	if _exploration_mode != null:
		_exploration_mode.layout(viewport_size)
	if _journey != null:
		_journey.layout(viewport_size)
	var panel_rect: Rect2 = _graphics_panel.get_panel_rect() if _graphics_panel != null else Rect2()
	print("[WineVR][UI] layout refresh complete: %s viewport=%s options_pos=%s options_size=%s" % [
		reason,
		str(viewport_size),
		str(panel_rect.position),
		str(panel_rect.size)
	])


func _wait_for_valid_viewport() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x >= 120.0 and viewport_size.y >= 120.0:
		return
	await get_tree().process_frame
	viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.x >= 120.0 and viewport_size.y >= 120.0:
		return
	await get_tree().process_frame


func _ensure_exploration_input_actions() -> void:
	_ensure_input_action_key("toggle_explore_mode", KEY_TAB)
	_ensure_input_action_key("toggle_explore_mode", KEY_E)
	_ensure_input_action_key("exit_mode", KEY_ESCAPE)
	_ensure_input_action_mouse("interact", MOUSE_BUTTON_LEFT)


func _ensure_input_action_key(action_name: String, keycode: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for event in InputMap.action_get_events(action_name):
		var existing_key_event: InputEventKey = event as InputEventKey
		if existing_key_event != null and existing_key_event.keycode == keycode:
			return
	var key_event: InputEventKey = InputEventKey.new()
	key_event.keycode = keycode
	InputMap.action_add_event(action_name, key_event)


func _ensure_input_action_mouse(action_name: String, button_index: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for event in InputMap.action_get_events(action_name):
		var existing_mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if existing_mouse_event != null and existing_mouse_event.button_index == button_index:
			return
	var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
	mouse_event.button_index = button_index
	InputMap.action_add_event(action_name, mouse_event)
