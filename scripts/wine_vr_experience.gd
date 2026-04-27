extends Node

@onready var vial_preview: VialPreviewController = $VialPreview
@onready var winery_interior: WineryInteriorController = $WineryInterior
@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var panel_dim: ColorRect = $CanvasLayer/PanelDim
@onready var fade_rect: ColorRect = $CanvasLayer/FadeRect

var _transition_in_progress: bool = false
var _profile_loading: bool = false
var _active_client_id: String = ""

var _qr_screen: QRScreenController
var _loading_overlay: LoadingOverlayController
var _hotspots: HotspotUIController
var _hud: ExperienceHUDController
var _mobile_controls: MobileControlsController
var _narrative_panel: NarrativePanelController
var _layout: ResponsiveLayoutController


func _ready() -> void:
	_build_components()
	canvas_layer.move_child(fade_rect, canvas_layer.get_child_count() - 1)

	ClientProfileLoader.client_profile_changed.connect(_on_client_profile_changed)
	ExperienceManager.state_changed.connect(_on_state_changed)
	winery_interior.door_prompt_changed.connect(Callable(_hud, "set_door_prompt"))
	winery_interior.door_interacted.connect(_on_winery_interacted)

	_apply_client_profile(ClientProfileLoader.get_active_client_data())
	_narrative_panel.refresh()
	_apply_state(ExperienceManager.current_state)
	_layout.layout(get_viewport().get_visible_rect().size)
	panel_dim.modulate.a = 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_layout.layout(get_viewport().get_visible_rect().size)
		_hotspots.layout_hotspots()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var registry_index: int = _get_debug_registry_index(event.keycode)
		if registry_index >= 0:
			_qr_screen.select_debug_index(registry_index)


func _build_components() -> void:
	_qr_screen = QRScreenController.new()
	add_child(_qr_screen)
	_qr_screen.setup(canvas_layer, ClientProfileLoader.get_client_registry(false))
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

	_mobile_controls = MobileControlsController.new()
	add_child(_mobile_controls)
	_mobile_controls.setup(canvas_layer, vial_preview, winery_interior)

	_narrative_panel = NarrativePanelController.new()
	add_child(_narrative_panel)
	_narrative_panel.setup(canvas_layer)

	_layout = ResponsiveLayoutController.new()
	add_child(_layout)
	_layout.setup(_qr_screen, _hud, _mobile_controls, _narrative_panel)


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
	_hotspots.build_hotspots(experience_settings.get("hotspots", []))


func _apply_state(state: int) -> void:
	_qr_screen.set_visible(state == ExperienceManager.ExperienceState.QR_SCAN)
	_hud.apply_state(state)
	_narrative_panel.apply_state(state)

	vial_preview.visible = state != ExperienceManager.ExperienceState.WINERY_INTERIOR
	winery_interior.visible = state == ExperienceManager.ExperienceState.WINERY_INTERIOR
	vial_preview.set_camera_active(state != ExperienceManager.ExperienceState.WINERY_INTERIOR)
	winery_interior.set_camera_active(state == ExperienceManager.ExperienceState.WINERY_INTERIOR)
	vial_preview.set_interaction_enabled(state == ExperienceManager.ExperienceState.VIAL_INSPECTION)
	winery_interior.set_controls_enabled(state == ExperienceManager.ExperienceState.WINERY_INTERIOR)
	_mobile_controls.set_zoom_visible(state == ExperienceManager.ExperienceState.VIAL_INSPECTION)
	_mobile_controls.set_winery_controls_visible(state == ExperienceManager.ExperienceState.WINERY_INTERIOR)

	if state != ExperienceManager.ExperienceState.VIAL_INSPECTION:
		_hotspots.close_panel()


func _on_hotspot_viewed(hotspot_data: Dictionary) -> void:
	NarrativeManager.complete_target("hotspot", _hotspots.get_hotspot_id(hotspot_data))


func _on_winery_interacted(interactable_data: Dictionary = {}) -> void:
	if not interactable_data.is_empty():
		var interactable_id: String = str(interactable_data.get("id", ""))
		var interactable_type: String = str(interactable_data.get("type", "zone"))
		NarrativeManager.complete_target("zone", interactable_id)
		NarrativeManager.complete_target(interactable_type, interactable_id)
		if interactable_data.has("target_type") and interactable_data.has("target_id"):
			NarrativeManager.complete_target(str(interactable_data.get("target_type", "")), str(interactable_data.get("target_id", "")))
	_hud.show_interactable_modal(interactable_data)


func _on_enter_winery_pressed() -> void:
	if not _transition_in_progress:
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
	_loading_overlay.show_loading("Loading experience")
	await get_tree().create_timer(0.18).timeout

	_hotspots.reset_viewed()
	_hotspots.close_panel()
	_hud.close_winery_modal()

	if not ClientProfileLoader.profile_exists(client_id):
		_qr_screen.set_error("Profile '%s' is listed but its config file is missing." % client_id)
		ExperienceManager.show_qr_scan()
	elif ClientProfileLoader.load_client_profile(client_id):
		vial_preview.reset_view()
		winery_interior.reset_view()
		ExperienceManager.enter_intro()
	else:
		_qr_screen.set_error("Profile '%s' is not available yet." % client_id)
		ExperienceManager.show_qr_scan()

	_loading_overlay.hide_loading()
	_profile_loading = false


func _get_debug_registry_index(keycode: int) -> int:
	if keycode >= KEY_1 and keycode <= KEY_9:
		return keycode - KEY_1
	return -1
