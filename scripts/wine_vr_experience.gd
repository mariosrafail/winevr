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
const IMMERSIVE_UNAVAILABLE_MESSAGE: String = "Immersive mode is not available on this device. You can continue in desktop mode."
const UI_MODAL_PRIORITY_MANAGER_SCRIPT: Script = preload("res://scripts/ui/ui_modal_priority_manager.gd")
const CONTROLS_OVERLAY_CONTROLLER_SCRIPT: Script = preload("res://scripts/ui/controls_overlay_controller.gd")
const MAIN_MENU_OVERLAY_CONTROLLER_SCRIPT: Script = preload("res://scripts/ui/main_menu_overlay_controller.gd")

var _transition_in_progress: bool = false
var _profile_loading: bool = false
var _active_client_id: String = ""
var _demo_viewport_preset_index: int = 0
var _native_window_size: Vector2i = Vector2i.ZERO
var _last_window_size: Vector2i = Vector2i.ZERO
var _demo_mode: bool = false
var _ui_hidden_for_capture: bool = false
var _immersive_mode_loading: bool = false
var _browser_free_explore_mode: bool = false
var _section_bar: HBoxContainer
var _section_label: Label
var _visited_stations: Dictionary = {}

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
var _ui_modal_priority: Node
var _controls_overlay: ControlsOverlayController
var _main_menu: MainMenuOverlayController
var _return_to_main_menu_after_submenu: bool = false
var _opening_menu_submenu: bool = false


func _ready() -> void:
	_ensure_exploration_input_actions()
	_build_components()
	_graphics_manager.preset_applied.connect(func(_preset: String) -> void: winery_interior.call("_apply_museum_presentation"))
	_setup_ui_modal_priority()
	canvas_layer.move_child(fade_rect, canvas_layer.get_child_count() - 1)
	if _graphics_panel != null:
		await _graphics_panel.apply_saved_display_settings()

	ClientProfileLoader.client_profile_changed.connect(_on_client_profile_changed)
	ExperienceManager.state_changed.connect(_on_state_changed)
	winery_interior.door_prompt_changed.connect(Callable(_hud, "set_door_prompt"))
	winery_interior.door_interacted.connect(_on_winery_interacted)
	winery_interior.vr_vial_hotspot_viewed.connect(_on_hotspot_viewed)
	winery_interior.desktop_info_panel_opened.connect(func() -> void: _open_ui_modal("winery_info_panel"))
	winery_interior.desktop_info_panel_closed.connect(func() -> void: _close_ui_modal("winery_info_panel"))
	winery_interior.layout_refresh_requested.connect(refresh_all_ui_layouts)
	winery_interior.xr_state_changed.connect(_on_xr_state_changed)
	winery_interior.xr_capabilities_changed.connect(func(_caps: Dictionary) -> void: _refresh_xr_menu())
	winery_interior.collection_requested.connect(func() -> void: _navigate_section("museum"))
	winery_interior.tour_station_visited.connect(_on_tour_station_visited)
	winery_interior.presentation_changed.connect(func(_mode: String) -> void: _update_section_bar())

	_apply_client_profile(ClientProfileLoader.get_active_client_data())
	_narrative_panel.refresh()
	_sync_immersive_mode_controls()
	_apply_state(ExperienceManager.current_state)
	_last_window_size = DisplayServer.window_get_size()
	panel_dim.modulate.a = 0.0
	await refresh_all_ui_layouts("startup")
	await refresh_all_ui_layouts("startup")
	_show_main_menu()
	_refresh_xr_menu()
	_print_runtime_health_status()
	if "--grape-museum" in OS.get_cmdline_user_args():
		_on_grape_museum_requested()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		var new_window_size: Vector2i = DisplayServer.window_get_size()
		await refresh_all_ui_layouts("window size changed")
		_update_section_bar()
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
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		_graphics_panel.toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and not _ui_modal_has_active_modal() and winery_interior.close_grape_inspection():
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and not _has_text_input_focus():
		_handle_escape_menu_flow()
		get_viewport().set_input_as_handled()
		return
	if _ui_modal_has_active_modal():
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1 and not _has_text_input_focus():
		_return_to_main_menu_after_submenu = false
		_toggle_controls_overlay_from_f1()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if _exploration_mode != null and _exploration_mode.handle_input(event):
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_R:
			_reset_current_experience()
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
	_qr_screen.immersive_mode_requested.connect(_on_immersive_mode_requested)

	_loading_overlay = LoadingOverlayController.new()
	add_child(_loading_overlay)
	_loading_overlay.setup(canvas_layer)

	_hud = ExperienceHUDController.new()
	add_child(_hud)
	_hud.setup(self)
	_hud.start_requested.connect(Callable(ExperienceManager, "start_experience"))
	_hud.enter_winery_requested.connect(_on_enter_winery_pressed)
	_hud.return_to_vial_requested.connect(_on_return_to_vial_pressed)
	_hud.immersive_mode_requested.connect(_on_immersive_mode_requested)
	_hud.explore_winery_requested.connect(_on_browser_explore_winery_requested)
	_hud.layout_refresh_requested.connect(refresh_all_ui_layouts)
	_hud.winery_modal_opened.connect(_on_winery_modal_opened)
	_hud.winery_modal_closed.connect(_on_winery_modal_closed)

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
	_hotspots.annotation_opened.connect(_on_hotspot_annotation_opened)
	_hotspots.annotation_closed.connect(_on_hotspot_annotation_closed)

	_mobile_controls = MobileControlsController.new()
	add_child(_mobile_controls)
	_mobile_controls.setup(canvas_layer, vial_preview, winery_interior)
	var mobile_inspector: Node = (load("res://scripts/components/mobile_grape_inspector.gd") as Script).new()
	mobile_inspector.name = "MobileGrapeInspectorController"
	add_child(mobile_inspector)
	mobile_inspector.call("setup", canvas_layer, winery_interior)

	_narrative_panel = NarrativePanelController.new()
	add_child(_narrative_panel)
	_narrative_panel.setup(canvas_layer)
	_narrative_panel.show_target_requested.connect(_on_show_narrative_target_requested)
	_narrative_panel.restart_requested.connect(_reset_current_experience)
	_narrative_panel.layout_refresh_requested.connect(refresh_all_ui_layouts)
	_narrative_panel.narrative_modal_opened.connect(_on_narrative_modal_opened)
	_narrative_panel.narrative_modal_closed.connect(_on_narrative_modal_closed)
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
	_graphics_panel.options_opened.connect(_on_options_opened)
	_graphics_panel.options_closed.connect(_on_options_closed)
	_graphics_panel.controls_requested.connect(_on_controls_requested_from_options)

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
	_journey.cellar_requested.connect(_on_enter_winery_pressed)
	_journey.restart_requested.connect(_reset_current_experience)
	_journey.choose_another_requested.connect(_choose_another_tasting)
	_journey.show_qr_requested.connect(_show_selected_qr_info)
	_journey.layout_refresh_requested.connect(refresh_all_ui_layouts)
	_journey.journey_modal_opened.connect(_on_journey_modal_opened)
	_journey.journey_modal_closed.connect(_on_journey_modal_closed)

	_controls_overlay = CONTROLS_OVERLAY_CONTROLLER_SCRIPT.new() as ControlsOverlayController
	add_child(_controls_overlay)
	_controls_overlay.setup(canvas_layer)
	_controls_overlay.start_requested.connect(_on_controls_start_pressed)
	_controls_overlay.skip_requested.connect(_on_controls_skip_pressed)
	_controls_overlay.controls_opened.connect(func() -> void: _open_ui_modal("controls"))
	_controls_overlay.controls_closed.connect(_on_controls_closed)

	_main_menu = MAIN_MENU_OVERLAY_CONTROLLER_SCRIPT.new() as MainMenuOverlayController
	add_child(_main_menu)
	_main_menu.setup(canvas_layer)
	_main_menu.resume_requested.connect(_on_main_menu_resume_requested)
	_main_menu.options_requested.connect(_on_main_menu_options_requested)
	_main_menu.museum_requested.connect(_on_grape_museum_requested)
	_main_menu.vineyard_requested.connect(func() -> void: _navigate_section("vineyard"))
	_main_menu.tasting_requested.connect(_open_tasting_catalog)
	_main_menu.cellar_requested.connect(func() -> void: _navigate_section("cellar"))
	_main_menu.xr_requested.connect(_on_immersive_mode_requested)
	_main_menu.controls_requested.connect(_on_main_menu_controls_requested)
	_main_menu.quit_requested.connect(_on_main_menu_quit_requested)
	_main_menu.menu_opened.connect(func() -> void: _open_ui_modal("main_menu"))
	_main_menu.menu_closed.connect(func() -> void: _close_ui_modal("main_menu"))
	_build_section_bar()


func _setup_ui_modal_priority() -> void:
	_ui_modal_priority = UI_MODAL_PRIORITY_MANAGER_SCRIPT.new() as Node
	_ui_modal_priority.name = "UIModalPriorityManager"
	add_child(_ui_modal_priority)
	_ui_modal_priority.connect("modal_opened", Callable(self, "_sync_winery_modal_context"))
	_ui_modal_priority.connect("modal_closed", func(_id: String) -> void: _sync_winery_modal_context(str(_ui_modal_priority.call("get_active_modal_id"))))
	_ui_modal_priority.connect("modal_focus_applied", func(_id: String) -> void: _sync_winery_modal_context(str(_ui_modal_priority.call("get_active_modal_id"))))

	if _main_menu != null:
		_ui_modal_priority.call("register_panel", "main_menu", _main_menu.root, 130, Callable(_main_menu, "hide_menu"))
	if _controls_overlay != null:
		_ui_modal_priority.call("register_panel", "controls", _controls_overlay.root, 120, Callable(_controls_overlay, "hide_controls"))
	_ui_modal_priority.call("register_panel", "options", _graphics_panel.overlay_root, 115, Callable(_graphics_panel, "close"))
	_ui_modal_priority.call("register_panel", "hotspot_modal", _hotspots.panel, 90, Callable(_hotspots, "close_panel"))
	_ui_modal_priority.call("register_panel", "winery_modal", _hud.winery_modal, 90, Callable(_hud, "close_winery_modal"))
	_ui_modal_priority.call("register_panel", "journey_completion", _journey.completion_panel, 90, Callable(_journey, "close_completion_panel"))
	_ui_modal_priority.call("register_panel", "journey_card", _journey.tasting_card_panel, 85, Callable(_journey, "close_tasting_card"))
	_ui_modal_priority.call("register_panel", "narrative_completion", _narrative_panel.completion_overlay, 85, Callable(_narrative_panel, "_hide_completion_modal"))
	_ui_modal_priority.call("register_panel", "narrative_panel", _narrative_panel.panel, 70)
	_ui_modal_priority.call("register_panel", "narrative_button", _narrative_panel.show_button, 70)
	_ui_modal_priority.call("register_panel", "winery_tooltip", winery_interior.get_tooltip_panel(), 60, Callable(winery_interior, "close_tooltip_panel"))
	_ui_modal_priority.call("register_panel", "winery_info_panel", winery_interior.get_info_panel(), 60, Callable(winery_interior, "close_desktop_info_panel"))
	_ui_modal_priority.call("register_panel", "inspection_info_card", _hud.inspection_info_card, 40)
	_ui_modal_priority.call("register_panel", "winery_info_card", _hud.winery_info_card, 40)
	_ui_modal_priority.call("register_panel", "journey_progress", _journey.progress_panel, 30)
	_ui_modal_priority.call("register_panel", "journey_card_button", _journey.tasting_card_button, 30)
	_ui_modal_priority.call("register_panel", "explore_button", _exploration_mode.explore_button, 30)
	_ui_modal_priority.call("register_panel", "options_menu", _graphics_panel.menu_button, 30)
	_sync_winery_modal_context("")


func _on_options_opened() -> void:
	_open_ui_modal("options")


func _on_options_closed() -> void:
	_close_ui_modal("options")
	_return_to_menu_after_submenu_if_needed()


func _on_winery_modal_opened() -> void:
	_open_ui_modal("winery_modal")


func _on_winery_modal_closed() -> void:
	_close_ui_modal("winery_modal")


func _on_hotspot_annotation_opened() -> void:
	_open_ui_modal("hotspot_modal")


func _on_hotspot_annotation_closed() -> void:
	_close_ui_modal("hotspot_modal")


func _on_journey_modal_opened(id: String) -> void:
	_open_ui_modal(id)


func _on_journey_modal_closed(id: String) -> void:
	_close_ui_modal(id)


func _on_narrative_modal_opened(id: String) -> void:
	_open_ui_modal(id)


func _on_narrative_modal_closed(id: String) -> void:
	_close_ui_modal(id)


func _open_ui_modal(id: String) -> void:
	if _ui_modal_priority == null or winery_interior.is_vr_active():
		return
	_release_explore_mode_for_modal(id)
	_ui_modal_priority.call("open_modal", id)
	_sync_winery_modal_context(str(_ui_modal_priority.call("get_active_modal_id")))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_ui_modal(id: String) -> void:
	if _ui_modal_priority == null:
		return
	_ui_modal_priority.call("close_modal", id)
	_sync_winery_modal_context(str(_ui_modal_priority.call("get_active_modal_id")))
	_keep_closing_overlay_noninteractive(id)
	_restore_mouse_capture_after_modal_if_needed()


func _sync_winery_modal_context(_id: String = "") -> void:
	if winery_interior == null:
		return
	var active_id: String = str(_ui_modal_priority.call("get_active_modal_id")) if _ui_modal_priority != null else ""
	winery_interior.set_desktop_modal_context(active_id)
	if not active_id.is_empty():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _crosshair != null:
		_crosshair.set_blocked_by_modal(not active_id.is_empty())
	if _hud != null and _hud.door_prompt_label != null:
		_hud.door_prompt_label.visible = active_id.is_empty() and ExperienceManager.current_state == ExperienceManager.ExperienceState.WINERY_INTERIOR


func _release_explore_mode_for_modal(id: String) -> void:
	var keep_explore_mode: bool = ["main_menu", "options", "controls", "winery_info_panel"].has(id)
	if _exploration_mode != null and _exploration_mode.active and not keep_explore_mode:
		_exploration_mode.exit_mode()
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _restore_mouse_capture_after_modal_if_needed() -> void:
	if winery_interior != null and winery_interior.get("_grape_museum") != null and (winery_interior.get("_grape_museum") as GrapeMuseum).is_inspecting():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if _graphics_panel != null and _graphics_panel.is_open():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if _ui_modal_priority != null and bool(_ui_modal_priority.call("has_active_modal")):
		return
	if _exploration_mode != null and _exploration_mode.active and ExperienceManager.current_state == ExperienceManager.ExperienceState.WINERY_INTERIOR:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _keep_closing_overlay_noninteractive(id: String) -> void:
	match id:
		"main_menu":
			if _main_menu != null and _main_menu.root != null and _main_menu.root.visible and not (_ui_modal_priority != null and str(_ui_modal_priority.call("get_active_modal_id")) == "main_menu"):
				_set_control_tree_mouse_filter(_main_menu.root, Control.MOUSE_FILTER_IGNORE)
		"options":
			if _graphics_panel != null and _graphics_panel.overlay_root != null and _graphics_panel.overlay_root.visible and not _graphics_panel.is_open():
				_set_control_tree_mouse_filter(_graphics_panel.overlay_root, Control.MOUSE_FILTER_IGNORE)


func _set_control_tree_mouse_filter(node: Node, mouse_filter: int) -> void:
	if node is Control:
		(node as Control).mouse_filter = mouse_filter
	for child in node.get_children():
		_set_control_tree_mouse_filter(child, mouse_filter)


func _ui_modal_has_active_modal() -> bool:
	return _ui_modal_priority != null and bool(_ui_modal_priority.call("has_active_modal"))


func _close_active_ui_modal() -> void:
	if _ui_modal_priority == null:
		return
	var active_id: String = str(_ui_modal_priority.call("get_active_modal_id"))
	match active_id:
		"main_menu":
			_on_main_menu_resume_requested()
		"controls":
			_controls_overlay.hide_controls()
		"options":
			_graphics_panel.close()
		"hotspot_modal":
			_hotspots.close_panel()
		"winery_modal":
			_hud.close_winery_modal()
		"winery_info_panel":
			winery_interior.close_desktop_info_panel()
		"journey_card":
			_journey.close_tasting_card()
		"journey_completion":
			_journey.close_completion_panel()
		"narrative_completion":
			_narrative_panel.call("_hide_completion_modal")


func _on_controls_requested_from_options() -> void:
	_opening_menu_submenu = true
	if _graphics_panel != null and _graphics_panel.is_open():
		_graphics_panel.close()
	_opening_menu_submenu = false
	_show_controls_overlay(true)


func _on_controls_start_pressed() -> void:
	_close_ui_modal("controls")
	if ExperienceManager.current_state == ExperienceManager.ExperienceState.INTRO:
		ExperienceManager.start_experience()


func _on_controls_skip_pressed() -> void:
	_close_ui_modal("controls")


func _on_controls_closed() -> void:
	_close_ui_modal("controls")
	_return_to_menu_after_submenu_if_needed()


func _show_main_menu() -> void:
	if _main_menu == null:
		return
	if winery_interior != null and winery_interior.is_vr_active():
		return
	_return_to_main_menu_after_submenu = false
	_qr_screen.set_visible(false)
	_main_menu.resume_button.visible = ExperienceManager.current_state == ExperienceManager.ExperienceState.WINERY_INTERIOR
	_main_menu.show_menu()
	_refresh_xr_menu()


func _handle_escape_menu_flow() -> void:
	if _ui_modal_priority != null and bool(_ui_modal_priority.call("has_active_modal")):
		var active_id: String = str(_ui_modal_priority.call("get_active_modal_id"))
		match active_id:
			"main_menu":
				_on_main_menu_resume_requested()
			"options":
				_return_to_main_menu_after_submenu = true
				_graphics_panel.close()
			"controls":
				_return_to_main_menu_after_submenu = true
				_controls_overlay.hide_controls()
			_:
				_close_active_ui_modal()
		return
	_show_main_menu()


func _on_main_menu_resume_requested() -> void:
	_qr_screen.set_visible(ExperienceManager.current_state == ExperienceManager.ExperienceState.QR_SCAN)
	_return_to_main_menu_after_submenu = false
	if _main_menu != null:
		_main_menu.hide_menu()
	_restore_mouse_capture_after_modal_if_needed()


func _on_grape_museum_requested() -> void:
	_navigate_section("museum")


func _navigate_section(section: String) -> void:
	if _transition_in_progress or winery_interior.is_ar_active():
		return
	_return_to_main_menu_after_submenu = false
	_main_menu.hide_menu()
	winery_interior.set_presentation_mode(section)
	if ExperienceManager.current_state == ExperienceManager.ExperienceState.WINERY_INTERIOR:
		_browser_free_explore_mode = true
		NarrativeManager.load_from_client_data({})
		_apply_state(ExperienceManager.current_state)
		_exploration_mode.enter_mode()
	else:
		_enter_free_explore_mode()
	_update_section_bar()


func _open_tasting_catalog() -> void:
	if _transition_in_progress:
		return
	_main_menu.hide_menu()
	winery_interior.close_grape_inspection()
	_browser_free_explore_mode = false
	NarrativeManager.load_from_client_data({})
	ExperienceManager.show_qr_scan()
	_apply_state(ExperienceManager.current_state)
	_update_section_bar()


func _build_section_bar() -> void:
	_section_bar = HBoxContainer.new()
	_section_bar.name = "CollectionNavigation"
	_section_bar.add_theme_constant_override("separation", 6)
	_section_bar.z_index = 90
	canvas_layer.add_child(_section_bar)
	for item in [["Συλλογή", "museum"], ["Δαφνές", "vineyard"], ["Κάβα", "cellar"], ["Κρασιά", "catalog"], ["☰", "menu"]]:
		var button: Button = Button.new()
		button.text = item[0]
		button.custom_minimum_size = Vector2(62, 42)
		PremiumUIStyles.apply_gold_outline_button(button)
		var destination: String = item[1]
		button.pressed.connect(func() -> void:
			match destination:
				"catalog": _open_tasting_catalog()
				"menu": _show_main_menu()
				_: _navigate_section(destination)
		)
		_section_bar.add_child(button)
	_section_label = Label.new()
	_section_label.add_theme_font_size_override("font_size", 12)
	_section_label.add_theme_color_override("font_color", PremiumUIStyles.TEXT_MUTED)
	_section_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(_section_label)
	_update_section_bar()


func _update_section_bar() -> void:
	if _section_bar == null:
		return
	var show: bool = ExperienceManager.current_state == ExperienceManager.ExperienceState.WINERY_INTERIOR and not winery_interior.is_vr_active()
	_section_bar.visible = show
	_section_label.visible = show
	_section_bar.position = Vector2(16, 16)
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	var compact: bool = viewport_width < 560
	var button_width: float = floorf((viewport_width - 56) / 5) if compact else 80
	for item in _section_bar.get_children():
		var button: Button = item as Button
		button.clip_text = true
		button.custom_minimum_size = Vector2(button_width, 42)
		button.add_theme_font_size_override("font_size", 12 if compact else 15)
	_section_bar.size = Vector2.ZERO
	_section_label.position = Vector2(18, 62)
	var mode: String = winery_interior.presentation_mode
	var tour: Node = winery_interior.get("_cellar") if mode == "cellar" else winery_interior.get("_vineyard")
	var count: int = (tour.get("visited_stations") as Dictionary).size() if tour != null else 0
	_section_label.text = ("04 / Η ΚΑΒΑ" if mode == "cellar" else "02 / ΔΑΦΝΕΣ") + "  ·  %s / 4 σημεία" % count if mode != "museum" else "01 / Η ΣΥΛΛΟΓΗ ΤΗΣ ΚΡΗΤΗΣ"
	for button in _section_bar.get_children():
		(button as Button).mouse_filter = Control.MOUSE_FILTER_STOP


func _on_tour_station_visited(id: String) -> void:
	_visited_stations[id] = true
	_update_section_bar()


func _refresh_xr_menu() -> void:
	if _main_menu == null or winery_interior == null:
		return
	var capabilities: Dictionary = winery_interior.get_xr_capabilities()
	var message: String = "Υπολογιστής και αφή · σύνδεσε συσκευή XR για VR/AR."
	if bool(capabilities.get("checking", false)):
		message = "Έλεγχος VR / AR στον περιηγητή…"
	elif bool(capabilities.get("vr", false)) or bool(capabilities.get("ar", false)):
		message = "Συμβατή συσκευή · ενεργοποίησε τη διαθέσιμη λειτουργία."
	capabilities["message"] = message
	_main_menu.set_xr_capabilities(capabilities, _immersive_mode_loading)


func _on_xr_state_changed(active: bool, _mode: String) -> void:
	if _hud == null:
		return
	if not active:
		_apply_state(ExperienceManager.current_state)
		if ExperienceManager.current_state == ExperienceManager.ExperienceState.WINERY_INTERIOR:
			_show_main_menu()
	_refresh_xr_menu()
	_update_section_bar()


func _on_main_menu_options_requested() -> void:
	if _graphics_panel == null:
		return
	_return_to_main_menu_after_submenu = true
	_opening_menu_submenu = true
	if _main_menu != null and _main_menu.is_open():
		_main_menu.hide_menu()
	_graphics_panel.open()
	_opening_menu_submenu = false


func _on_main_menu_controls_requested() -> void:
	_return_to_main_menu_after_submenu = true
	_opening_menu_submenu = true
	if _main_menu != null and _main_menu.is_open():
		_main_menu.hide_menu()
	_show_controls_overlay(true)
	_opening_menu_submenu = false


func _on_main_menu_quit_requested() -> void:
	if OS.has_feature("web"):
		if _main_menu != null:
			_main_menu.show_message("Για έξοδο, κλείσε την καρτέλα της εμπειρίας.")
		return
	get_tree().quit()


func _return_to_menu_after_submenu_if_needed() -> void:
	if _opening_menu_submenu:
		return
	if not _return_to_main_menu_after_submenu:
		return
	_return_to_main_menu_after_submenu = false
	_show_main_menu()


func _toggle_controls_overlay_from_f1() -> void:
	print("[WineVR][Controls] F1 toggled")
	if _controls_overlay == null:
		return
	if _controls_overlay.is_open():
		_controls_overlay.hide_controls()
	else:
		_return_to_main_menu_after_submenu = false
		_show_controls_overlay(true)


func _show_controls_overlay(force: bool = false) -> void:
	if _controls_overlay == null:
		return
	if winery_interior != null and winery_interior.is_vr_active():
		return
	if not force and _controls_overlay.has_seen_this_session():
		return
	_controls_overlay.configure(_should_show_vr_controls_section(), OS.is_debug_build())
	_controls_overlay.show_controls()


func _show_controls_overlay_after_selection() -> void:
	return


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
	var vr_winery_active: bool = winery_interior.is_vr_active() and state == ExperienceManager.ExperienceState.WINERY_INTERIOR
	_sync_immersive_mode_controls()
	_qr_screen.set_visible(state == ExperienceManager.ExperienceState.QR_SCAN)
	_hud.apply_state(state)
	_narrative_panel.apply_state(state)
	_narrative_panel.set_external_guidance_active(_browser_free_explore_mode)
	_hud.set_vr_winery_mode(vr_winery_active)
	if _browser_free_explore_mode:
		_hud.winery_info_card.visible = false
	_narrative_panel.set_vr_winery_mode(vr_winery_active)
	canvas_layer.visible = not _ui_hidden_for_capture

	vial_preview.visible = state != ExperienceManager.ExperienceState.WINERY_INTERIOR
	winery_interior.visible = state == ExperienceManager.ExperienceState.WINERY_INTERIOR
	vial_preview.set_camera_active(state != ExperienceManager.ExperienceState.WINERY_INTERIOR)
	winery_interior.set_camera_active(state == ExperienceManager.ExperienceState.WINERY_INTERIOR)
	vial_preview.set_interaction_enabled(state == ExperienceManager.ExperienceState.VIAL_INSPECTION)
	winery_interior.set_controls_enabled(state == ExperienceManager.ExperienceState.WINERY_INTERIOR)
	_mobile_controls.set_zoom_visible(state == ExperienceManager.ExperienceState.VIAL_INSPECTION)
	_mobile_controls.set_winery_controls_visible(state == ExperienceManager.ExperienceState.WINERY_INTERIOR and not vr_winery_active)
	if _crosshair != null:
		_crosshair.set_active(state == ExperienceManager.ExperienceState.WINERY_INTERIOR and not vr_winery_active)
	if _exploration_mode != null:
		_exploration_mode.set_available(state == ExperienceManager.ExperienceState.WINERY_INTERIOR and not vr_winery_active)
	if _journey != null:
		_journey.set_visible_for_state(state == ExperienceManager.ExperienceState.VIAL_INSPECTION)
	_relayout_all_ui(get_viewport().get_visible_rect().size)

	if state != ExperienceManager.ExperienceState.VIAL_INSPECTION:
		_hotspots.close_panel()
	_apply_narrative_target_highlight(NarrativeManager.get_current_step(), false)
	_update_dev_overlay_context()
	_update_section_bar()


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
	if not interactable_data.is_empty():
		var interactable_id: String = str(interactable_data.get("id", ""))
		var interactable_type: String = str(interactable_data.get("type", "zone"))
		NarrativeManager.complete_target("zone", interactable_id)
		NarrativeManager.complete_target(interactable_type, interactable_id)
		if interactable_data.has("target_type") and interactable_data.has("target_id"):
			NarrativeManager.complete_target(str(interactable_data.get("target_type", "")), str(interactable_data.get("target_id", "")))
	# Normal winery interactions now use lightweight in-scene feedback. Keep the HUD
	# winery modal available for future explicit "More info" actions.


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
		_browser_free_explore_mode = true
		NarrativeManager.load_from_client_data({})
		winery_interior.set_presentation_mode("cellar")
		ExperienceManager.enter_winery()


func _on_return_to_vial_pressed() -> void:
	if not _transition_in_progress:
		if _browser_free_explore_mode:
			_browser_free_explore_mode = false
			NarrativeManager.load_from_client_data(ClientProfileLoader.get_active_client_data())
		_return_to_vial_with_fade()


func _on_immersive_mode_requested(mode: String = "vr") -> void:
	if _immersive_mode_loading:
		return
	_immersive_mode_loading = true
	_set_immersive_mode_busy(true)
	_set_immersive_mode_message("")

	_refresh_xr_menu()
	var initialized: bool = await winery_interior.request_immersive_mode(mode)
	_immersive_mode_loading = false
	if initialized:
		_set_immersive_mode_active(true)
		_set_immersive_mode_message("")
		_main_menu.hide_menu()
		_browser_free_explore_mode = true
		NarrativeManager.load_from_client_data({})
		if mode == "ar":
			winery_interior.set_presentation_mode("museum")
		ExperienceManager.finish_winery_entry()
		_apply_state(ExperienceManager.current_state)
		await refresh_all_ui_layouts("immersive mode initialized")
	else:
		_set_immersive_mode_busy(false)
		_set_immersive_mode_active(false)
		_set_immersive_mode_message(winery_interior.get_xr_status(), true)
		_main_menu.show_message(winery_interior.get_xr_status())
		await refresh_all_ui_layouts("immersive mode unavailable")
	_refresh_xr_menu()


func _on_browser_explore_winery_requested() -> void:
	if not OS.has_feature("web"):
		return
	_enter_free_explore_mode()


func _enter_free_explore_mode() -> void:
	if _transition_in_progress:
		return
	_browser_free_explore_mode = true
	_hotspots.close_panel()
	_hud.close_winery_modal()
	_narrative_panel.clear_hint()
	NarrativeManager.load_from_client_data({})
	if _journey != null:
		_journey.set_visible_for_state(false)
	ExperienceManager.enter_winery()


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
	if _browser_free_explore_mode and not winery_interior.is_vr_active() and _exploration_mode != null:
		_exploration_mode.enter_mode()
	_update_section_bar()


func _return_to_vial_with_fade() -> void:
	_transition_in_progress = true
	winery_interior.set_controls_enabled(false)
	if _crosshair != null:
		_crosshair.set_active(false)
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
	_browser_free_explore_mode = false
	winery_interior.set_presentation_mode("museum")

	_profile_loading = true
	_qr_screen.set_error("")
	_loading_overlay.show_loading("Ετοιμάζουμε τη γευστική διαδρομή…")
	await get_tree().create_timer(0.18).timeout

	_hotspots.reset_viewed()
	_hotspots.close_panel()
	_hud.close_winery_modal()
	var profile_loaded_for_controls: bool = false
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
			profile_loaded_for_controls = true
		else:
			_qr_screen.set_error("Το προφίλ δεν είναι διαθέσιμο. Διάλεξε άλλο κρασί από τη συλλογή.")
			ExperienceManager.show_qr_scan()
	elif not ClientProfileLoader.profile_exists(client_id):
		_qr_screen.set_error("Αυτό το προφίλ δεν είναι ακόμη έτοιμο. Διάλεξε άλλο κρασί.")
		ExperienceManager.show_qr_scan()
	elif ClientProfileLoader.load_client_profile(client_id):
		AppState.clear_selected_profile()
		vial_preview.reset_view()
		winery_interior.reset_view()
		ExperienceManager.enter_intro()
		_onboarding.show_once()
		await refresh_all_ui_layouts("tasting selected")
		profile_loaded_for_controls = true
	else:
		_qr_screen.set_error("Το προφίλ δεν είναι διαθέσιμο. Διάλεξε άλλο κρασί από τη συλλογή.")
		ExperienceManager.show_qr_scan()

	_loading_overlay.hide_loading()
	_profile_loading = false
	if profile_loaded_for_controls:
		_show_controls_overlay_after_selection()


func _reset_current_experience() -> void:
	if _browser_free_explore_mode:
		_browser_free_explore_mode = false
		NarrativeManager.load_from_client_data(ClientProfileLoader.get_active_client_data())
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


func _sync_immersive_mode_controls() -> void:
	if winery_interior == null or _qr_screen == null or _hud == null:
		return
	var available: bool = winery_interior.can_request_immersive_mode()
	var active: bool = winery_interior.is_vr_active()
	_qr_screen.set_immersive_mode_available(available)
	_hud.set_immersive_mode_available(available)
	if _immersive_mode_loading:
		_set_immersive_mode_busy(true)
	else:
		_set_immersive_mode_active(active)
	if _controls_overlay != null:
		_controls_overlay.configure(_should_show_vr_controls_section(), OS.is_debug_build())


func _should_show_vr_controls_section() -> bool:
	return winery_interior != null and (winery_interior.is_vr_active() or winery_interior.can_request_immersive_mode())


func _set_immersive_mode_busy(busy: bool) -> void:
	if _qr_screen != null:
		_qr_screen.set_immersive_mode_busy(busy)
	if _hud != null:
		_hud.set_immersive_mode_busy(busy)


func _set_immersive_mode_active(active: bool) -> void:
	if _qr_screen != null:
		_qr_screen.set_immersive_mode_active(active)
	if _hud != null:
		_hud.set_immersive_mode_active(active)


func _set_immersive_mode_message(message: String, is_error: bool = false) -> void:
	if _qr_screen != null:
		_qr_screen.set_immersive_mode_message(message, is_error)
	if _hud != null:
		_hud.set_immersive_mode_message(message, is_error)


func _has_text_input_focus() -> bool:
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	return focus_owner is LineEdit or focus_owner is TextEdit


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


# Dev-only helper retained for scripted resets; Escape now belongs to the Main Menu flow.
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
	if _controls_overlay != null:
		_controls_overlay.layout(viewport_size)
	if _main_menu != null:
		_main_menu.layout(viewport_size)
	if _ui_modal_priority != null:
		_ui_modal_priority.call("refresh")


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
	if _controls_overlay != null:
		_controls_overlay.layout(viewport_size)
	if _main_menu != null:
		_main_menu.layout(viewport_size)
	if _ui_modal_priority != null:
		_ui_modal_priority.call("refresh")
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
