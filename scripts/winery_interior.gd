extends Node3D
class_name WineryInteriorController

signal door_prompt_changed(prompt: String)
signal door_interacted(interactable_data: Dictionary)
signal interactable_hover_started(interactable: Interactable)
signal interactable_hover_ended(interactable: Interactable)
signal interactable_clicked(interactable: Interactable)
signal guided_step_started(step_index: int, interactable_id: String)
signal guided_step_completed(step_index: int, interactable_id: String)
signal layout_refresh_requested(reason: String)
signal interaction_target_changed(can_interact: bool, prompt_text: String)
signal vr_vial_hotspot_viewed(hotspot_data: Dictionary)
signal desktop_info_panel_opened
signal desktop_info_panel_closed
signal presentation_changed(mode: String)
signal xr_state_changed(active: bool, mode: String)
signal xr_capabilities_changed(capabilities: Dictionary)
signal collection_requested
signal tour_station_visited(station_id: String)

@export var move_speed: float = 2.4
@export var look_sensitivity: float = 0.005
@export var min_pitch_degrees: float = -30.0
@export var max_pitch_degrees: float = 30.0
@export var ambient_audio_path: String = ""
@export var hover_audio_path: String = ""
@export var click_audio_path: String = ""
@export var completion_audio_path: String = ""
# Safe VR test switch: leave false for headset/OpenXR tests, enable to force the existing desktop path.
@export var force_desktop_mode: bool = false
@export var vr_teleport_max_distance: float = 5.2
@export var debug_preview_vr_hand: bool = false
@export var debug_force_show_vr_hand: bool = false
@export var debug_vr_hand_distance: float = 0.65
@export var debug_vr_hand_scale: float = 0.9

@onready var player_rig: Node3D = $PlayerRig
@onready var camera_pivot: Node3D = $PlayerRig/CameraPivot
@onready var camera: Camera3D = $PlayerRig/CameraPivot/Camera3D
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var interaction_ray: RayCast3D = $PlayerRig/CameraPivot/Camera3D/InteractionRay
@onready var held_vial: Vial = $PlayerRig/CameraPivot/Camera3D/HeldVial
@onready var vr_player_rig: XROrigin3D = get_node_or_null("VRPlayerRig") as XROrigin3D
@onready var vr_camera: XRCamera3D = get_node_or_null("VRPlayerRig/XRCamera3D") as XRCamera3D
@onready var vr_left_controller: XRController3D = get_node_or_null("VRPlayerRig/LeftController") as XRController3D
@onready var vr_right_controller: XRController3D = get_node_or_null("VRPlayerRig/RightController") as XRController3D
@onready var vr_interaction_ray: RayCast3D = get_node_or_null("VRPlayerRig/RightController/InteractionRay") as RayCast3D
@onready var vr_pointer: MeshInstance3D = get_node_or_null("VRPlayerRig/RightController/Pointer") as MeshInstance3D
@onready var directional_light: DirectionalLight3D = $DirectionalLight3D
@onready var fill_light: OmniLight3D = $FillLight
@onready var floor_mesh: MeshInstance3D = $Floor
@onready var door_hinge: Node3D = $DoorAssembly/DoorHinge
@onready var door_mesh: MeshInstance3D = $DoorAssembly/DoorHinge/Door/DoorMesh

const VR_MANAGER_SCRIPT: Script = preload("res://scripts/vr/vr_manager.gd")
const VR_TELEPORT_CONTROLLER_SCRIPT: Script = preload("res://scripts/vr/vr_teleport_controller.gd")
const VR_GUIDED_TASTING_CONTROLLER_SCRIPT: Script = preload("res://scripts/vr/vr_guided_tasting_controller.gd")
const VR_VIAL_HOTSPOT_CONTROLLER_SCRIPT: Script = preload("res://scripts/vr/vr_vial_hotspot_controller.gd")
const VIAL_SCENE: PackedScene = preload("res://scenes/Vial.tscn")
const VR_HAND_VIAL_HOLDER_SCENE: PackedScene = preload("res://scenes/vr/VRHandVialHolder.tscn")
const VR_INFO_PANEL_SCENE_PATH: String = "res://scenes/vr/VRInfoPanel.tscn"
const GRAPE_MUSEUM_SCENE: PackedScene = preload("res://scenes/GrapeMuseum.tscn")
const KEYBOARD_INTERACTION_COOLDOWN_MSEC: int = 250
const VR_TELEPORT_BOUNDS_MIN: Vector2 = Vector2(-3.2, -3.2)
const VR_TELEPORT_BOUNDS_MAX: Vector2 = Vector2(3.2, 3.2)

var _movement: WineryMovementController
var _door: WineryDoorController
var _environment: WineryEnvironmentApplier
var _visual_details: WineryVisualDetailer
var _props: WineryPropFactory
var _zones: WineryZoneManager
var _guided: GuidedExperienceManager
var _current_hovered_interactable: Interactable
var _interactable_by_id: Dictionary = {}
var _completed_guided_ids: Dictionary = {}
var _is_demo_mode: bool = false
var _active_showcase_tween: Tween
var _camera_transition_quality: float = 1.0
var _ultra_low_mode: bool = false
var _ambient_player: AudioStreamPlayer
var _hover_player: AudioStreamPlayer
var _click_player: AudioStreamPlayer
var _completion_player: AudioStreamPlayer
var _spotlight_root: Node3D
var _exploration_mode_active: bool = false
var _vr_manager: WineVRVRManager
var _is_vr_active: bool = false
var _vr_hand_vial_holder: Node3D
var _vr_trigger_was_pressed: bool = false
var _vr_input_controller: XRController3D
var _vr_teleport_system: Node
var _vr_guided_tasting: Node
var _vr_vial_hotspots: Node
var _vr_info_panel: Node3D
var _vr_last_feedback: String = ""
var _controls_enabled: bool = false
var _active_client_data: Dictionary = {}
var _grape_museum: GrapeMuseum
var _vineyard: Node3D
var _cellar: Node3D
var presentation_mode: String = "museum"
var _xr_focused: bool = true
var _last_xr_interaction_msec: int = -300

var _interaction_ui_layer: CanvasLayer
var _tooltip_panel: PanelContainer
var _tooltip_title: Label
var _tooltip_description: Label
var _tooltip_action: Label
var _info_panel: PanelContainer
var _info_title: Label
var _info_description: Label
var _info_close_button: Button
var _tooltip_max_height: float = 220.0
var _info_max_height: float = 280.0
var _info_panel_tween: Tween
var _info_auto_hide_token: int = 0
var _desktop_modal_active_id: String = ""
var _interact_feedback: Control
var _interact_feedback_label: Label
var _interact_feedback_tween: Tween
var _interact_feedback_target_id: String = ""
var _interact_feedback_visible: bool = false
var _last_keyboard_interaction_msec: int = -KEYBOARD_INTERACTION_COOLDOWN_MSEC


func _ready() -> void:
	interaction_ray.collide_with_areas = true
	if vr_interaction_ray != null:
		vr_interaction_ray.collide_with_areas = true
	_setup_player_mode()
	_door = WineryDoorController.new()
	_door.setup(door_hinge, door_mesh)

	_environment = WineryEnvironmentApplier.new()
	_environment.setup(
		floor_mesh,
		[$BackWall, $FrontWall, $LeftWall, $RightWall],
		[$BarrelA, $BarrelB, $BarrelC, $BarrelD],
		directional_light,
		fill_light,
		_door,
		world_environment
	)
	_visual_details = WineryVisualDetailer.new()
	_visual_details.setup(self, _environment)

	_props = WineryPropFactory.new()
	_props.setup(self, _environment)
	_zones = WineryZoneManager.new()
	_zones.setup(self)

	_movement = WineryMovementController.new()
	_movement.setup(player_rig, camera_pivot, move_speed, look_sensitivity, min_pitch_degrees, max_pitch_degrees)

	_guided = GuidedExperienceManager.new()
	_guided.step_started.connect(_on_guided_step_started)
	_guided.step_completed.connect(_on_guided_step_completed)

	_setup_interaction_ui()
	if _is_vr_active and _interaction_ui_layer != null:
		_interaction_ui_layer.visible = false
	_setup_audio_players()
	_setup_spotlight_root()
	_setup_grape_museum()
	fill_light.add_to_group("optional_lights")
	fill_light.add_to_group("performance_optional")
	_register_scene_interactables()
	apply_client_profile(ClientProfileLoader.get_active_client_data())
	_refresh_vr_hand_vial_holder("ready")
	_update_interaction_prompt()


func _setup_grape_museum() -> void:
	_grape_museum = GRAPE_MUSEUM_SCENE.instantiate() as GrapeMuseum
	add_child(_grape_museum)
	_grape_museum.setup_interaction(self)
	_apply_museum_presentation()


func _apply_museum_presentation() -> void:
	if _grape_museum == null:
		return
	if presentation_mode == "cellar" and _cellar != null:
		_cellar.call("configure_environment", world_environment.environment)
	elif presentation_mode == "vineyard" and _vineyard != null:
		_vineyard.call("configure_environment", world_environment.environment)
	else:
		_grape_museum.configure_environment(world_environment.environment)
	if presentation_mode == "museum" and _grape_museum.has_method("set_passthrough_mode"):
		_grape_museum.call("set_passthrough_mode", is_ar_active())
	if is_ar_active():
		world_environment.environment.background_mode = Environment.BG_COLOR
		world_environment.environment.background_color = Color(0, 0, 0, 0)
		world_environment.environment.fog_enabled = false
		world_environment.environment.ambient_light_energy = 0.85
	directional_light.visible = false
	fill_light.visible = false
	held_vial.visible = false
	for ob in [floor_mesh, $BackWall, $FrontWall, $LeftWall, $RightWall, $BarrelA, $BarrelB, $BarrelC, $BarrelD, $ColumnLeft, $ColumnRight, $DoorAssembly]:
		(ob as Node3D).visible = false
	for legacy_root in [_props.root, _props.interaction_root, _props.highlight_root, _visual_details.root, _zones.root, _spotlight_root]:
		if legacy_root != null:
			legacy_root.visible = false
			_disable_museum_legacy_collisions(legacy_root)


func set_presentation_mode(mode: String) -> void:
	if mode not in ["museum", "vineyard", "cellar"]:
		return
	if is_ar_active() and mode != "museum":
		return
	if _grape_museum.physics != null:
		_grape_museum.physics.call("close_inspection", true)
		_grape_museum.physics.call("end_grab")
	_grape_museum.selected_id = ""
	_hide_info_panel()
	_set_hovered_interactable(null)
	presentation_mode = mode
	if mode == "vineyard" and _vineyard == null:
		_vineyard = (load("res://scenes/VineyardLandscape.tscn") as PackedScene).instantiate() as Node3D
		add_child(_vineyard)
		_vineyard.connect("return_to_museum_requested", func() -> void: collection_requested.emit())
		_vineyard.connect("station_selected", func(id: String) -> void: tour_station_visited.emit(id))
	if mode == "cellar" and _cellar == null:
		_cellar = (load("res://scenes/CellarTour.tscn") as PackedScene).instantiate() as Node3D
		add_child(_cellar)
		_cellar.connect("return_to_museum_requested", func() -> void: collection_requested.emit())
		_cellar.connect("station_selected", func(id: String) -> void: tour_station_visited.emit(id))
	if _cellar != null:
		_cellar.call("set_active", mode == "cellar")
	_set_branch_active(_grape_museum, mode == "museum")
	_grape_museum.controls_enabled = _controls_enabled and mode == "museum" and _xr_focused and _desktop_modal_active_id.is_empty()
	if _vineyard != null:
		_vineyard.call("set_active", mode == "vineyard")
	var minimum: Vector2 = Vector2(-2.6, -2.8)
	var maximum: Vector2 = Vector2(2.6, 2.2)
	var spawn: Vector3 = Vector3(0, 0, 1.55)
	var tour: Node3D = _cellar if mode == "cellar" else _vineyard
	if mode != "museum" and tour != null:
		minimum = tour.call("get_bounds_min")
		maximum = tour.call("get_bounds_max")
		spawn = tour.call("get_spawn_position")
	_movement.configure_bounds(minimum, maximum)
	_movement.set_camera_start(spawn, Vector3.ZERO)
	if _vr_teleport_system != null:
		_vr_teleport_system.call("configure_bounds", minimum, maximum)
	_apply_museum_presentation()
	_register_scene_interactables()
	reset_view()
	presentation_changed.emit(mode)


func _set_branch_active(branch: Node, active: bool) -> void:
	if branch is Node3D:
		(branch as Node3D).visible = active
	branch.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	_set_branch_collisions(branch, active)


func _set_branch_collisions(node: Node, active: bool) -> void:
	if node is CollisionObject3D:
		var body: CollisionObject3D = node as CollisionObject3D
		if not body.has_meta("presentation_layer"):
			body.set_meta("presentation_layer", body.collision_layer)
			body.set_meta("presentation_mask", body.collision_mask)
		body.collision_layer = int(body.get_meta("presentation_layer")) if active else 0
		body.collision_mask = int(body.get_meta("presentation_mask")) if active else 0
		if body is RigidBody3D:
			(body as RigidBody3D).freeze = not active
	for child in node.get_children():
		_set_branch_collisions(child, active)


func is_ar_active() -> bool:
	return _is_vr_active and _vr_manager != null and _vr_manager.get_session_mode() == "ar"


func get_xr_capabilities() -> Dictionary:
	_ensure_vr_manager()
	return _vr_manager.get_capabilities()


func get_xr_status() -> String:
	return _vr_manager.get_status_message() if _vr_manager != null else "Δεν βρέθηκε συνδεδεμένη συσκευή XR."


func end_immersive_mode() -> void:
	if _vr_manager != null:
		_vr_manager.end_session()


func _disable_museum_legacy_collisions(root: Node) -> void:
	if root is CollisionObject3D:
		(root as CollisionObject3D).collision_layer = 0
	for child in root.get_children():
		_disable_museum_legacy_collisions(child)


func _count_mesh_instances(node: Node) -> int:
	var total: int = 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		total += _count_mesh_instances(child)
	return total


func _physics_process(delta: float) -> void:
	if not _controls_enabled:
		_set_vr_teleport_enabled(false)
		return
	if not _desktop_modal_active_id.is_empty() or _is_desktop_info_panel_open():
		return
	if _is_vr_active:
		_update_interaction_prompt()
		_set_vr_teleport_enabled(true)
		return
	if _grape_museum != null and (_grape_museum.is_inspecting() or (_grape_museum.physics != null and bool(_grape_museum.physics.get("room_demo")) and bool(_grape_museum.physics.get("_transitioning")))):
		_update_interaction_prompt()
		return
	if _movement != null and _movement.physics_update(delta):
		_update_interaction_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if _movement == null or not _controls_enabled:
		return
	if _is_desktop_info_panel_open():
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_hide_info_panel()
		return
	if not _desktop_modal_active_id.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo and OS.is_debug_build() and not _has_text_input_focus():
		if event.keycode == KEY_H:
			debug_preview_vr_hand = not debug_preview_vr_hand
			print("[WineVR][VRHand] debug_preview_vr_hand=%s" % str(debug_preview_vr_hand))
			_refresh_vr_hand_vial_holder("debug_preview_toggle")
			return
		if event.keycode == KEY_J:
			debug_force_show_vr_hand = not debug_force_show_vr_hand
			print("[WineVR][VRHand] debug_force_show_vr_hand=%s" % str(debug_force_show_vr_hand))
			_refresh_vr_hand_vial_holder("debug_force_toggle")
			return
		if event.keycode == KEY_K:
			_debug_print_vr_hand_status("manual")
			return

	# Desktop inspection is keyboard-driven. VR trigger input is handled by XRController3D signals below.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_try_keyboard_interact()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		show_current_guided_target()
		return
	if _grape_museum != null and (_grape_museum.is_inspecting() or (_grape_museum.physics != null and bool(_grape_museum.physics.get("room_demo")) and bool(_grape_museum.physics.get("_transitioning")))):
		return
	if _movement.handle_input(event):
		_update_interaction_prompt()


func apply_client_profile(client_data: Dictionary) -> void:
	if client_data.is_empty():
		return
	_active_client_data = client_data.duplicate(true)
	if _environment == null or _props == null or _zones == null:
		return

	var vial_settings: Dictionary = _dict_value(client_data.get("vial_settings", {}))
	if held_vial != null:
		_apply_vial_profile(held_vial, vial_settings, client_data)
	_apply_vr_hand_vial_profile(client_data)

	var environment_settings: Dictionary = _dict_value(client_data.get("environment_settings", {}))
	_environment.apply(environment_settings)
	if _visual_details != null:
		_visual_details.apply(environment_settings)
	_zones.door_interactable = _get_interactable_by_type(environment_settings, "door")
	if _zones.door_interactable.is_empty():
		_zones.door_interactable = {
			"id": "cellar_door",
			"title": "Cellar Door",
			"text": str(environment_settings.get("ambience_text", "")),
			"type": "door"
		}

	_apply_camera_start(environment_settings.get("camera_start", {}))
	_props.rebuild_with_quality(environment_settings.get("props", []), str(environment_settings.get("visual_quality", "medium")))
	_rebuild_prop_spotlights()
	_zones.rebuild(environment_settings.get("zones", []))
	var guided_ids: Variant = environment_settings.get("guided_interactable_ids", [])
	if typeof(guided_ids) == TYPE_ARRAY:
		configure_guided_steps(guided_ids as Array)
	else:
		configure_guided_steps([])
	_configure_vr_guided_tasting()
	_configure_vr_vial_hotspots()
	_refresh_vr_hand_vial_holder("profile changed")
	_apply_museum_presentation()


func set_controls_enabled(enabled: bool) -> void:
	if _movement == null:
		return
	_controls_enabled = enabled
	if _grape_museum != null:
		_grape_museum.controls_enabled = enabled and presentation_mode == "museum" and _xr_focused and _desktop_modal_active_id.is_empty()
	_movement.set_controls_enabled(enabled and not _is_vr_active)
	if vr_player_rig != null and vr_player_rig.has_method("set_input_enabled"):
		vr_player_rig.call("set_input_enabled", enabled and _desktop_modal_active_id.is_empty() and _xr_focused)
	if _interaction_ui_layer != null:
		_interaction_ui_layer.visible = enabled and not _is_vr_active
		if not _interaction_ui_layer.visible:
			_hide_interact_text_feedback()
	if _is_vr_active:
		if vr_interaction_ray != null:
			vr_interaction_ray.enabled = enabled and _xr_focused and _desktop_modal_active_id.is_empty()
		if vr_pointer != null:
			vr_pointer.visible = enabled
		_set_vr_teleport_enabled(enabled)
		_set_vr_guided_tasting_enabled(enabled)
		_set_vr_vial_hotspots_enabled(enabled)
		if not enabled:
			_hide_vr_info_panel()
	if not enabled:
		_exploration_mode_active = false
		_door.set_highlight(false)
		_set_hovered_interactable(null)
		_hide_info_panel()
		_hide_interact_text_feedback()
		interaction_target_changed.emit(false, "")
	_refresh_vr_hand_vial_holder("controls enabled")
	door_prompt_changed.emit("")


func set_camera_active(active: bool) -> void:
	camera.environment = world_environment.environment
	if vr_camera != null:
		vr_camera.environment = world_environment.environment
	if _is_vr_active:
		if player_rig != null:
			player_rig.visible = false
		if camera != null:
			camera.current = false
		if vr_player_rig != null:
			vr_player_rig.visible = active
		if vr_camera != null:
			vr_camera.current = active
		return
	if camera != null:
		camera.current = active


func reset_view() -> void:
	if _movement != null:
		_movement.reset_view()
	if _is_vr_active and vr_player_rig != null and _movement != null:
		if vr_player_rig.has_method("reset_origin"):
			vr_player_rig.call("reset_origin", _movement.camera_start_position, _movement.camera_start_rotation)
		else:
			vr_player_rig.position = _movement.camera_start_position
			vr_player_rig.rotation = _movement.camera_start_rotation


func set_mobile_move_axis(axis: String, pressed: bool) -> void:
	if _movement != null:
		_movement.set_mobile_move_axis(axis, pressed)


func handle_look_drag(relative_motion: Vector2) -> void:
	if _movement == null:
		return
	_movement.apply_look_drag(relative_motion)
	_update_interaction_prompt()


func set_exploration_mode_active(active: bool) -> void:
	_exploration_mode_active = active
	if _movement != null:
		_movement.set_exploration_mode(active)
	_hide_tooltip()
	if active:
		_update_interaction_prompt()
	else:
		interaction_target_changed.emit(false, "")


func interact_current() -> void:
	if _controls_enabled and (_is_vr_active or (_movement != null and _movement.controls_enabled)):
		_try_interact()


func close_grape_inspection() -> bool:
	return _grape_museum != null and _grape_museum.close_inspection()


func is_vr_active() -> bool:
	return _is_vr_active


func _setup_player_mode() -> void:
	_ensure_vr_interact_input_action()
	_ensure_vr_manager()
	_activate_desktop_mode()


func can_request_immersive_mode() -> bool:
	_ensure_vr_manager()
	return _vr_manager != null and _vr_manager.may_have_supported_interface(force_desktop_mode)


func request_immersive_mode(mode: String = "vr") -> bool:
	if _is_vr_active:
		return _vr_manager != null and _vr_manager.get_session_mode() == mode.to_lower()
	_ensure_vr_manager()
	if _vr_manager == null:
		return false

	# Immersive mode must be requested from a user action, so startup stays on
	# the desktop rig until this method is called by the intro/QR UI.
	var initialized: bool = await _vr_manager.initialize(force_desktop_mode, mode)
	if initialized and (vr_player_rig == null or vr_camera == null or vr_interaction_ray == null):
		push_warning("[WineVR][VR] Incomplete rig; returning to desktop.")
		_vr_manager.end_session()
		return false
	# Session state signals own activation and cleanup, including asynchronous exit.
	return initialized



func _ensure_vr_manager() -> void:
	if _vr_manager != null:
		return
	_vr_manager = VR_MANAGER_SCRIPT.new() as WineVRVRManager
	_vr_manager.name = "VRManager"
	add_child(_vr_manager)
	_vr_manager.session_state_changed.connect(_on_xr_session_state_changed)
	_vr_manager.capabilities_changed.connect(func(caps: Dictionary) -> void: xr_capabilities_changed.emit(caps))
	_vr_manager.focus_changed.connect(_on_xr_focus_changed)
	_vr_manager.selection_requested.connect(_on_webxr_selection)
	_vr_manager.reference_space_changed.connect(func(space: String) -> void:
		if vr_player_rig.has_method("apply_reference_space"):
			vr_player_rig.call("apply_reference_space", space)
	)


func _on_xr_session_state_changed(active: bool, mode: String) -> void:
	_is_vr_active = active
	_vr_trigger_was_pressed = false
	if _grape_museum != null and _grape_museum.physics != null:
		_grape_museum.physics.call("close_inspection", true)
		_grape_museum.physics.call("end_grab")
	if active:
		_activate_vr_mode()
		if mode == "ar":
			set_presentation_mode("museum")
	else:
		_activate_desktop_mode()
		_xr_focused = true
	set_controls_enabled(_controls_enabled)
	set_camera_active(is_visible_in_tree())
	_apply_museum_presentation()
	xr_state_changed.emit(active, mode)


func _on_xr_focus_changed(focused: bool) -> void:
	_xr_focused = focused
	if not focused:
		_vr_trigger_was_pressed = false
		_vr_input_controller = null
	if not focused and _grape_museum != null and _grape_museum.physics != null:
		_grape_museum.physics.call("end_grab")
	if vr_player_rig != null and vr_player_rig.has_method("set_input_enabled"):
		vr_player_rig.call("set_input_enabled", focused and _controls_enabled and _desktop_modal_active_id.is_empty())
	_set_vr_teleport_enabled(focused and _controls_enabled)
	if _grape_museum != null:
		_grape_museum.controls_enabled = focused and _controls_enabled and presentation_mode == "museum" and _desktop_modal_active_id.is_empty()


func _on_webxr_selection(source_id: int) -> void:
	if not _is_vr_active or not _controls_enabled or not _xr_focused:
		return
	if vr_player_rig.has_method("route_web_selection"):
		if not bool(vr_player_rig.call("route_web_selection", _vr_manager, source_id)):
			return
	_update_interaction_prompt()
	_try_xr_interact()


func _try_xr_interact() -> void:
	if not _is_vr_active or not _controls_enabled or not _xr_focused or not _desktop_modal_active_id.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_xr_interaction_msec < 250:
		return
	_last_xr_interaction_msec = now
	_try_interact()


func _activate_desktop_mode() -> void:
	_is_vr_active = false
	if vr_player_rig != null and vr_player_rig.has_method("set_xr_enabled"):
		vr_player_rig.call("set_xr_enabled", false)
	get_viewport().use_xr = false
	if player_rig != null:
		player_rig.visible = true
	if camera != null:
		camera.current = false
	if interaction_ray != null:
		interaction_ray.enabled = true
	if held_vial != null:
		held_vial.visible = true
	if vr_player_rig != null:
		vr_player_rig.visible = false
	if vr_interaction_ray != null:
		vr_interaction_ray.enabled = false
	if vr_pointer != null:
		vr_pointer.visible = false
	_refresh_vr_hand_vial_holder("desktop mode")
	_set_vr_teleport_enabled(false)
	_set_vr_guided_tasting_enabled(false)
	_set_vr_vial_hotspots_enabled(false)
	_hide_vr_info_panel()


func _activate_vr_mode() -> void:
	if vr_player_rig.has_method("set_xr_enabled"):
		vr_player_rig.call("set_xr_enabled", true, is_ar_active())
	if player_rig != null:
		player_rig.visible = false
	if camera != null:
		camera.current = false
	if interaction_ray != null:
		interaction_ray.enabled = false
	if held_vial != null:
		held_vial.visible = false
	if vr_player_rig != null:
		vr_player_rig.visible = false
	if vr_camera != null:
		vr_camera.current = false
	if vr_interaction_ray != null:
		vr_interaction_ray.enabled = false
	if vr_pointer != null:
		vr_pointer.visible = false
	if _interaction_ui_layer != null:
		_interaction_ui_layer.visible = false
	_connect_vr_controller_input()
	_ensure_vr_teleport_system()
	_set_vr_teleport_enabled(_controls_enabled)
	_ensure_vr_guided_tasting()
	_configure_vr_guided_tasting()
	_set_vr_guided_tasting_enabled(_controls_enabled)
	_setup_vr_info_panel()
	_refresh_vr_hand_vial_holder("vr mode")
	_ensure_vr_vial_hotspots()
	_configure_vr_vial_hotspots()
	_set_vr_vial_hotspots_enabled(_controls_enabled)
	print("[WineVR][VR] VR mode active: using XRCamera3D and RightController/InteractionRay")


func _connect_vr_controller_input() -> void:
	for controller: XRController3D in [vr_right_controller, vr_left_controller]:
		if controller == null:
			continue
		var button_callable: Callable = _on_vr_controller_button_from.bind(controller)
		if not controller.button_pressed.is_connected(button_callable):
			controller.button_pressed.connect(button_callable)
		var float_callable: Callable = _on_vr_controller_float_from.bind(controller)
		if not controller.input_float_changed.is_connected(float_callable):
			controller.input_float_changed.connect(float_callable)


func _prepare_xr_controller_input(controller: XRController3D) -> bool:
	if vr_player_rig == null or controller != vr_player_rig.call("get_interaction_controller"):
		return false
	if _vr_input_controller != controller:
		_vr_trigger_was_pressed = false
		_vr_input_controller = controller
	return true


func _on_vr_controller_button_from(button_name: String, controller: XRController3D) -> void:
	if _prepare_xr_controller_input(controller):
		_on_vr_controller_button_pressed(button_name)


func _on_vr_controller_float_from(input_name: String, value: float, controller: XRController3D) -> void:
	if _prepare_xr_controller_input(controller):
		_on_vr_controller_input_float_changed(input_name, value)


func _ensure_vr_teleport_system() -> void:
	if _vr_teleport_system != null:
		return
	if vr_player_rig == null or vr_camera == null:
		return
	_vr_teleport_system = VR_TELEPORT_CONTROLLER_SCRIPT.new() as Node
	if _vr_teleport_system == null:
		return
	_vr_teleport_system.name = "VRTeleportController"
	add_child(_vr_teleport_system)
	_vr_teleport_system.set("max_distance", vr_teleport_max_distance)
	_vr_teleport_system.call("configure_bounds", VR_TELEPORT_BOUNDS_MIN, VR_TELEPORT_BOUNDS_MAX)
	_vr_teleport_system.call("setup", vr_player_rig, vr_camera, vr_left_controller, vr_right_controller)
	_vr_teleport_system.call("set_enabled", false)


func _set_vr_teleport_enabled(enabled: bool) -> void:
	if _vr_teleport_system == null and enabled:
		_ensure_vr_teleport_system()
	if _vr_teleport_system != null:
		_vr_teleport_system.call("set_enabled", enabled and _is_vr_active and not is_ar_active() and _xr_focused and _desktop_modal_active_id.is_empty())


func _ensure_vr_guided_tasting() -> void:
	if _vr_guided_tasting != null:
		return
	if vr_camera == null:
		return
	_vr_guided_tasting = VR_GUIDED_TASTING_CONTROLLER_SCRIPT.new() as Node
	if _vr_guided_tasting == null:
		return
	_vr_guided_tasting.name = "VRGuidedTastingController"
	add_child(_vr_guided_tasting)
	_vr_guided_tasting.call(
		"setup",
		vr_camera,
		Callable(self, "_highlight_vr_guided_target"),
		Callable(self, "clear_narrative_highlight"),
		Callable(self, "_vr_guided_target_exists")
	)


func _configure_vr_guided_tasting() -> void:
	if _vr_guided_tasting == null:
		return
	_vr_guided_tasting.call("configure_from_profile", _active_client_data)


func _set_vr_guided_tasting_enabled(enabled: bool) -> void:
	if _vr_guided_tasting == null and enabled:
		_ensure_vr_guided_tasting()
		_configure_vr_guided_tasting()
	if _vr_guided_tasting != null:
		_vr_guided_tasting.call("set_enabled", enabled and _is_vr_active and _grape_museum == null)


func _ensure_vr_vial_hotspots() -> void:
	if _vr_vial_hotspots == null:
		if vr_camera == null or vr_interaction_ray == null:
			return
		_vr_vial_hotspots = VR_VIAL_HOTSPOT_CONTROLLER_SCRIPT.new() as Node
		if _vr_vial_hotspots == null:
			return
		_vr_vial_hotspots.name = "VRVialHotspotController"
		_get_vr_vial_hotspot_anchor().add_child(_vr_vial_hotspots)
		_vr_vial_hotspots.call(
			"setup",
			vr_camera,
			vr_interaction_ray,
			Callable(self, "_show_vr_info_panel"),
			Callable(self, "_on_vr_vial_hotspot_activated")
		)
	_attach_vr_vial_hotspots_to_anchor()


func _configure_vr_vial_hotspots() -> void:
	if _vr_vial_hotspots == null:
		return
	_vr_vial_hotspots.call("configure_from_profile", _active_client_data)


func _set_vr_vial_hotspots_enabled(enabled: bool) -> void:
	if _vr_vial_hotspots == null and enabled:
		_ensure_vr_vial_hotspots()
		_configure_vr_vial_hotspots()
	if _vr_vial_hotspots != null:
		_vr_vial_hotspots.call("set_enabled", enabled and _is_vr_active and _grape_museum == null)


func _try_activate_vr_vial_hotspot() -> bool:
	if not _is_vr_active or _vr_vial_hotspots == null:
		return false
	return bool(_vr_vial_hotspots.call("try_activate_hovered"))


func _vr_vial_hotspot_hovered() -> bool:
	if not _is_vr_active or _vr_vial_hotspots == null:
		return false
	return bool(_vr_vial_hotspots.call("has_hovered_label"))


func _on_vr_vial_hotspot_activated(hotspot_data: Dictionary) -> void:
	vr_vial_hotspot_viewed.emit(hotspot_data)


func _get_vr_vial_hotspot_anchor() -> Node3D:
	if _vr_hand_vial_holder != null:
		return _vr_hand_vial_holder
	if vr_left_controller != null:
		return vr_left_controller
	if vr_camera != null:
		return vr_camera
	return self


func _attach_vr_vial_hotspots_to_anchor() -> void:
	if _vr_vial_hotspots == null:
		return
	var hotspot_node: Node3D = _vr_vial_hotspots as Node3D
	if hotspot_node == null:
		return
	var anchor: Node3D = _get_vr_vial_hotspot_anchor()
	if hotspot_node.get_parent() != anchor:
		hotspot_node.reparent(anchor, false)
	hotspot_node.position = Vector3.ZERO
	hotspot_node.rotation = Vector3.ZERO
	hotspot_node.scale = Vector3.ONE


func _refresh_vr_hand_vial_holder(reason: String) -> void:
	var should_show: bool = _should_show_vr_hand_holder()
	if not should_show and _vr_hand_vial_holder == null:
		_debug_print_vr_hand_status(reason)
		return
	_ensure_vr_hand_vial_holder()
	_attach_vr_hand_holder_to_correct_parent()
	_apply_profile_to_vr_hand_holder()
	_show_vr_hand_holder(should_show)
	_debug_print_vr_hand_status(reason)


func _should_show_vr_hand_holder() -> bool:
	if _grape_museum != null:
		return false
	if debug_force_show_vr_hand:
		return true
	if _is_vr_active:
		return _controls_enabled
	return debug_preview_vr_hand


func _ensure_vr_hand_vial_holder() -> void:
	if _vr_hand_vial_holder != null:
		_debug_print_vr_hand_status("ensure existing")
		return
	_vr_hand_vial_holder = VR_HAND_VIAL_HOLDER_SCENE.instantiate() as Node3D
	if _vr_hand_vial_holder == null:
		push_warning("[WineVR][VRHand] Failed to instantiate VRHandVialHolder.tscn")
		_debug_print_vr_hand_status("create failed")
		return
	_vr_hand_vial_holder.name = "VRHandVialHolder"
	add_child(_vr_hand_vial_holder)
	if _vr_hand_vial_holder.has_method("setup"):
		_vr_hand_vial_holder.call("setup", VIAL_SCENE)
	if _vr_hand_vial_holder.has_method("ensure_visible_glove_meshes"):
		_vr_hand_vial_holder.call("ensure_visible_glove_meshes")
	if _count_vr_hand_child_meshes() == 0:
		_create_vr_hand_fallback_debug_meshes()
	_disable_shadows_recursive(_vr_hand_vial_holder)
	_debug_print_vr_hand_status("created")


func _attach_vr_hand_holder_to_correct_parent() -> void:
	if _vr_hand_vial_holder == null:
		_ensure_vr_hand_vial_holder()
	if _vr_hand_vial_holder == null:
		return

	var parent_node: Node3D = null
	var local_position: Vector3 = Vector3.ZERO
	var local_rotation_degrees: Vector3 = Vector3.ZERO
	var local_scale: Vector3 = Vector3.ONE

	if _is_vr_active and vr_left_controller != null:
		parent_node = vr_left_controller
		local_position = Vector3(0.02, -0.08, -0.18)
		local_rotation_degrees = Vector3(-12.0, -18.0, 8.0)
		local_scale = Vector3.ONE * 0.85
	elif (debug_preview_vr_hand or debug_force_show_vr_hand) and camera != null:
		parent_node = camera
		local_position = Vector3(-0.28, -0.18, -0.65)
		local_rotation_degrees = Vector3(-10.0, -20.0, 8.0)
		local_scale = Vector3.ONE * 0.9
	else:
		parent_node = self
		push_warning("[WineVR][VRHand] No active VR controller or desktop preview parent; attaching holder to WineryInterior root.")
		if camera != null:
			local_position = to_local(camera.global_transform.origin + (-camera.global_transform.basis.z * maxf(0.25, debug_vr_hand_distance)) + Vector3(-0.28, -0.18, 0.0))
			local_rotation_degrees = camera.global_rotation_degrees + Vector3(-10.0, -20.0, 8.0)
		else:
			local_position = Vector3(0.0, 1.2, -0.8)
			local_rotation_degrees = Vector3(-10.0, -20.0, 8.0)
		local_scale = Vector3.ONE * debug_vr_hand_scale

	if _vr_hand_vial_holder.get_parent() != parent_node:
		_vr_hand_vial_holder.reparent(parent_node, false)
	_vr_hand_vial_holder.position = local_position
	_vr_hand_vial_holder.rotation_degrees = local_rotation_degrees
	_vr_hand_vial_holder.scale = local_scale
	_attach_vr_vial_hotspots_to_anchor()
	_debug_print_vr_hand_status("attached")


func _show_vr_hand_holder(enabled: bool) -> void:
	if _vr_hand_vial_holder == null:
		return
	_vr_hand_vial_holder.visible = enabled
	_vr_hand_vial_holder.set_process(enabled)
	if enabled:
		_set_visible_recursive(_vr_hand_vial_holder, true)
		_disable_shadows_recursive(_vr_hand_vial_holder)
		if not _is_vr_active and debug_preview_vr_hand and _vr_hand_vial_holder.get_parent() == camera:
			print("[WineVR][VRHand] desktop preview visible")
		if _is_vr_active and _vr_hand_vial_holder.get_parent() == vr_left_controller:
			print("[WineVR][VRHand] VR left hand visible")
		print("[WineVR][VRHand] shown")
	else:
		print("[WineVR][VRHand] hidden")
	_debug_print_vr_hand_status("shown" if enabled else "hidden")


func _apply_profile_to_vr_hand_holder() -> void:
	if _vr_hand_vial_holder == null:
		return
	if held_vial != null and _vr_hand_vial_holder.has_method("apply_vial_profile"):
		_vr_hand_vial_holder.call("apply_vial_profile", held_vial)
	elif held_vial != null:
		var vial_node: Vial = _find_vial_child(_vr_hand_vial_holder)
		if vial_node != null:
			vial_node.liquid_fill_amount = held_vial.liquid_fill_amount
			vial_node.liquid_color = held_vial.liquid_color
			vial_node.cap_color = held_vial.cap_color
			if vial_node.has_method("rebuild_vial"):
				vial_node.call("rebuild_vial")
			if not _active_client_data.is_empty() and vial_node.has_method("apply_qr_profile"):
				vial_node.call("apply_qr_profile", _active_client_data)
	if not _active_client_data.is_empty() and _vr_hand_vial_holder.has_method("apply_client_profile"):
		_vr_hand_vial_holder.call("apply_client_profile", _active_client_data)
	_debug_print_vr_hand_status("profile applied")


func _debug_print_vr_hand_status(reason: String) -> void:
	var exists: bool = _vr_hand_vial_holder != null
	print("[WineVR][VRHand] reason=%s" % reason)
	print("[WineVR][VRHand] exists=%s" % str(exists))
	if not exists:
		print("[WineVR][VRHand] parent=none")
		print("[WineVR][VRHand] global_position=%s" % str(Vector3.ZERO))
		print("[WineVR][VRHand] local_position=%s" % str(Vector3.ZERO))
		print("[WineVR][VRHand] scale=%s" % str(Vector3.ZERO))
		print("[WineVR][VRHand] visible=false")
		print("[WineVR][VRHand] child_mesh_count=0")
		print("[WineVR][VRHand] vial_found=false")
		return
	var parent: Node = _vr_hand_vial_holder.get_parent()
	print("[WineVR][VRHand] parent=%s" % (str(parent.get_path()) if parent != null and parent.is_inside_tree() else "none"))
	print("[WineVR][VRHand] global_position=%s" % str(_vr_hand_vial_holder.global_position))
	print("[WineVR][VRHand] local_position=%s" % str(_vr_hand_vial_holder.position))
	print("[WineVR][VRHand] scale=%s" % str(_vr_hand_vial_holder.scale))
	print("[WineVR][VRHand] visible=%s" % str(_vr_hand_vial_holder.visible))
	print("[WineVR][VRHand] child_mesh_count=%d" % _count_vr_hand_child_meshes())
	print("[WineVR][VRHand] vial_found=%s" % str(_find_vial_child(_vr_hand_vial_holder) != null))


func _setup_vr_hand_vial_holder() -> void:
	_refresh_vr_hand_vial_holder("legacy setup")


func _apply_vr_hand_vial_profile(client_data: Dictionary = {}) -> void:
	if not client_data.is_empty():
		_active_client_data = client_data.duplicate(true)
	_apply_profile_to_vr_hand_holder()


func _show_vr_hand_vial_holder() -> void:
	_show_vr_hand_holder(true)


func _hide_vr_hand_vial_holder() -> void:
	_show_vr_hand_holder(false)


func _count_vr_hand_child_meshes() -> int:
	if _vr_hand_vial_holder == null:
		return 0
	if _vr_hand_vial_holder.has_method("count_visible_mesh_instance_nodes"):
		return int(_vr_hand_vial_holder.call("count_visible_mesh_instance_nodes"))
	return _count_visible_mesh_instance_nodes(_vr_hand_vial_holder)


func _count_visible_mesh_instance_nodes(root: Node) -> int:
	if root == null:
		return 0
	var count: int = 0
	if root is MeshInstance3D:
		var mesh_instance: MeshInstance3D = root as MeshInstance3D
		if mesh_instance.visible and mesh_instance.mesh != null:
			count += 1
	for child in root.get_children():
		count += _count_visible_mesh_instance_nodes(child)
	return count


func _find_vial_child(root: Node) -> Vial:
	if root == null:
		return null
	if root is Vial:
		return root as Vial
	for child in root.get_children():
		var vial_child: Vial = _find_vial_child(child)
		if vial_child != null:
			return vial_child
	return null


func _set_visible_recursive(root: Node, visible_enabled: bool) -> void:
	if root is CanvasItem:
		(root as CanvasItem).visible = visible_enabled
	if root is Node3D:
		(root as Node3D).visible = visible_enabled
	if root is MeshInstance3D:
		var mesh_instance: MeshInstance3D = root as MeshInstance3D
		mesh_instance.visible = visible_enabled
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in root.get_children():
		_set_visible_recursive(child, visible_enabled)


func _create_vr_hand_fallback_debug_meshes() -> void:
	if _vr_hand_vial_holder == null:
		return
	if _vr_hand_vial_holder.has_method("ensure_visible_glove_meshes"):
		_vr_hand_vial_holder.call("ensure_visible_glove_meshes")
		if _count_vr_hand_child_meshes() > 0:
			return
	if _vr_hand_vial_holder.get_node_or_null("FallbackGlove") != null:
		return
	var fallback_root: Node3D = Node3D.new()
	fallback_root.name = "FallbackGlove"
	_vr_hand_vial_holder.add_child(fallback_root)

	var glove_material: StandardMaterial3D = _make_vr_hand_debug_material(Color(0.075, 0.029, 0.045, 1.0), 0.8)
	var gold_material: StandardMaterial3D = _make_vr_hand_debug_material(Color(0.84, 0.69, 0.37, 1.0), 0.44)

	var palm_mesh: BoxMesh = BoxMesh.new()
	palm_mesh.size = Vector3(0.095, 0.055, 0.07)
	var palm: MeshInstance3D = _make_vr_hand_debug_mesh("Palm", palm_mesh, glove_material)
	palm.position = Vector3(-0.01, 0.072, -0.061)
	palm.rotation_degrees = Vector3(6.0, -8.0, -4.0)
	fallback_root.add_child(palm)

	var finger_names: Array = ["FingerIndex", "FingerMiddle", "FingerRing"]
	var finger_positions: Array = [
		Vector3(-0.033, 0.105, -0.029),
		Vector3(-0.003, 0.111, -0.036),
		Vector3(0.027, 0.101, -0.031)
	]
	var finger_rotations: Array = [
		Vector3(15.0, -18.0, -8.0),
		Vector3(11.0, -8.0, 0.0),
		Vector3(13.0, 4.0, 9.0)
	]
	for i in range(finger_names.size()):
		var finger_mesh: CylinderMesh = CylinderMesh.new()
		finger_mesh.top_radius = 0.0105
		finger_mesh.bottom_radius = 0.013
		finger_mesh.height = 0.155
		finger_mesh.radial_segments = 10
		var finger: MeshInstance3D = _make_vr_hand_debug_mesh(str(finger_names[i]), finger_mesh, glove_material)
		finger.position = finger_positions[i]
		finger.rotation_degrees = finger_rotations[i]
		fallback_root.add_child(finger)

	var thumb_mesh: CylinderMesh = CylinderMesh.new()
	thumb_mesh.top_radius = 0.012
	thumb_mesh.bottom_radius = 0.015
	thumb_mesh.height = 0.112
	thumb_mesh.radial_segments = 10
	var thumb: MeshInstance3D = _make_vr_hand_debug_mesh("Thumb", thumb_mesh, glove_material)
	thumb.position = Vector3(-0.053, 0.074, -0.023)
	thumb.rotation_degrees = Vector3(68.0, -18.0, -48.0)
	fallback_root.add_child(thumb)

	var cuff_mesh: BoxMesh = BoxMesh.new()
	cuff_mesh.size = Vector3(0.112, 0.036, 0.078)
	var wrist_cuff: MeshInstance3D = _make_vr_hand_debug_mesh("WristCuff", cuff_mesh, glove_material)
	wrist_cuff.position = Vector3(-0.012, 0.012, -0.063)
	wrist_cuff.rotation_degrees = Vector3(4.0, -8.0, 0.0)
	fallback_root.add_child(wrist_cuff)

	var trim_mesh: BoxMesh = BoxMesh.new()
	trim_mesh.size = Vector3(0.104, 0.007, 0.084)
	var trim: MeshInstance3D = _make_vr_hand_debug_mesh("CuffGoldTrim", trim_mesh, gold_material)
	trim.position = Vector3(-0.012, 0.033, -0.063)
	trim.rotation_degrees = Vector3(4.0, -8.0, 0.0)
	fallback_root.add_child(trim)

	var anchor_mesh: CylinderMesh = CylinderMesh.new()
	anchor_mesh.top_radius = 0.031
	anchor_mesh.bottom_radius = 0.031
	anchor_mesh.height = 0.006
	anchor_mesh.radial_segments = 18
	var anchor_guide: MeshInstance3D = _make_vr_hand_debug_mesh("VialAnchorGuide", anchor_mesh, gold_material)
	anchor_guide.position = Vector3(0.0, 0.082, -0.027)
	anchor_guide.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	fallback_root.add_child(anchor_guide)
	print("[WineVR][VRHand] visible glove mesh created")


func _make_vr_hand_debug_mesh(mesh_name: String, mesh: Mesh, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = mesh_name
	mesh_instance.mesh = mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.set_surface_override_material(0, material)
	return mesh_instance


func _make_vr_hand_debug_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _apply_vial_profile(vial: Vial, vial_settings: Dictionary, client_data: Dictionary) -> void:
	if vial == null:
		return
	vial.liquid_fill_amount = float(vial_settings.get("liquid_fill_amount", vial.liquid_fill_amount))
	vial.liquid_color = _environment.parse_color(vial_settings.get("liquid_color", vial.liquid_color), vial.liquid_color)
	vial.cap_color = _environment.parse_color(vial_settings.get("cap_color", vial.cap_color), vial.cap_color)
	vial.rebuild_vial()
	vial.apply_qr_profile(client_data)


func _disable_shadows_recursive(root: Node) -> void:
	if root is GeometryInstance3D:
		(root as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in root.get_children():
		_disable_shadows_recursive(child)


func _ensure_vr_interact_input_action() -> void:
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
	_add_joypad_button_to_action("interact", JOY_BUTTON_A)
	_add_joypad_button_to_action("interact", JOY_BUTTON_RIGHT_SHOULDER)
	_add_joypad_motion_to_action("interact", JOY_AXIS_TRIGGER_RIGHT, 1.0)


func _add_joypad_button_to_action(action_name: String, button_index: int) -> void:
	for event in InputMap.action_get_events(action_name):
		var joy_event: InputEventJoypadButton = event as InputEventJoypadButton
		if joy_event != null and joy_event.button_index == button_index:
			return
	var new_event: InputEventJoypadButton = InputEventJoypadButton.new()
	new_event.button_index = button_index
	InputMap.action_add_event(action_name, new_event)


func _add_joypad_motion_to_action(action_name: String, axis: int, axis_value: float) -> void:
	for event in InputMap.action_get_events(action_name):
		var motion_event: InputEventJoypadMotion = event as InputEventJoypadMotion
		if motion_event != null and motion_event.axis == axis and is_equal_approx(motion_event.axis_value, axis_value):
			return
	var new_event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	new_event.axis = axis
	new_event.axis_value = axis_value
	InputMap.action_add_event(action_name, new_event)


func _on_vr_controller_button_pressed(button_name: Variant) -> void:
	if not _is_vr_active or not _controls_enabled or not _xr_focused or OS.has_feature("web"):
		return
	if _is_vr_interact_button(button_name):
		_try_xr_interact()


func _on_vr_controller_input_float_changed(input_name: Variant, value: float) -> void:
	if not _is_vr_active or not _controls_enabled or not _xr_focused or OS.has_feature("web") or not _is_vr_interact_axis(input_name):
		return
	var pressed: bool = value >= 0.72
	if pressed and not _vr_trigger_was_pressed:
		_try_xr_interact()
	_vr_trigger_was_pressed = pressed


func _is_vr_interact_button(button_name: Variant) -> bool:
	var normalized: String = String(button_name).to_lower()
	return normalized in ["trigger_click", "select_button", "ax_button", "primary_click"]


func _is_vr_interact_axis(input_name: Variant) -> bool:
	var normalized: String = String(input_name).to_lower()
	return normalized == "trigger"


func _get_active_interaction_ray() -> RayCast3D:
	if _is_vr_active and vr_interaction_ray != null:
		if vr_player_rig.has_method("get_active_interaction_ray"):
			return vr_player_rig.call("get_active_interaction_ray") as RayCast3D
		return vr_interaction_ray
	return interaction_ray


func _show_interaction_feedback(data: Dictionary) -> void:
	if _is_vr_active:
		print("[WineVR][VR] Interacted: %s" % str(data.get("title", data.get("id", "target"))))
		_notify_vr_guided_interaction(data)
		_show_vr_info_panel(data)
		return
	_hide_tooltip()
	_show_info_panel(data)
	_hide_interact_text_feedback()
	print("[WineVR][InteractUI] action performed=%s" % str(data.get("id", "target")))


func _notify_vr_guided_interaction(data: Dictionary) -> void:
	if _vr_guided_tasting != null:
		_vr_guided_tasting.call("notify_interaction", data)


func _setup_vr_info_panel() -> void:
	if _vr_info_panel != null:
		return
	if vr_camera == null:
		push_warning("[WineVR][VR] VRInfoPanel unavailable")
		return
	var panel_scene: PackedScene = ResourceLoader.load(VR_INFO_PANEL_SCENE_PATH) as PackedScene
	if panel_scene == null:
		push_warning("[WineVR][VR] VRInfoPanel unavailable")
		return
	_vr_info_panel = panel_scene.instantiate() as Node3D
	if _vr_info_panel == null:
		push_warning("[WineVR][VR] VRInfoPanel unavailable")
		return
	add_child(_vr_info_panel)
	_vr_info_panel.call("set_follow_camera", vr_camera)


func _show_vr_info_panel(data: Dictionary) -> void:
	if not _is_vr_active:
		return
	var title: String = str(data.get("title", data.get("id", "Detail")))
	var body: String = str(data.get("description", data.get("text", "")))
	_setup_vr_info_panel()
	if _vr_info_panel == null:
		push_warning("[WineVR][VR] VRInfoPanel unavailable")
		print("%s: %s" % [title, body])
		return
	print("[WineVR][VR] Showing VR info panel: %s" % title)
	_vr_info_panel.call("show_info", title, body)


func _hide_vr_info_panel() -> void:
	if _vr_info_panel != null:
		_vr_info_panel.call("hide_panel")


func _update_vr_feedback(prompt: String, can_interact: bool, action_text: String) -> void:
	if not _is_vr_active:
		return
	var next_feedback: String = ""
	if can_interact and not prompt.is_empty():
		next_feedback = "%s - %s" % [prompt, action_text]
	if next_feedback == _vr_last_feedback:
		return
	_vr_last_feedback = next_feedback
	if not next_feedback.is_empty():
		print("[WineVR][VR] %s" % next_feedback)


func configure_guided_steps(step_ids: Array) -> void:
	_completed_guided_ids.clear()
	_guided.configure(step_ids)


func set_demo_mode(enabled: bool) -> void:
	_is_demo_mode = enabled


func set_camera_transition_quality(multiplier: float) -> void:
	_camera_transition_quality = clampf(multiplier, 0.0, 1.35)
	_ultra_low_mode = _camera_transition_quality <= 0.01


func show_current_guided_target() -> void:
	if _guided == null or not _guided.is_active():
		return
	var target_id: String = _guided.get_current_interactable_id()
	if _is_vr_active:
		print("[WineVR][VR] Guided target: %s" % target_id)
		if _props != null and _props.pulse_prop(target_id, self):
			return
		if _zones != null and _zones.pulse_zone(target_id, self):
			return
		if _door_target_matches(target_id):
			_door.set_highlight(true)
		return
	if _interactable_by_id.has(target_id):
		smooth_look_at(_interactable_by_id[target_id] as Node3D)
		return
	if _props != null and _props.highlight_prop(target_id):
		return
	if _zones != null and _zones.highlight_zone(target_id):
		return
	if _door_target_matches(target_id):
		_door.set_highlight(true)


func smooth_look_at(target: Node3D) -> void:
	if target == null or camera_pivot == null or camera == null:
		return
	if _active_showcase_tween != null:
		_active_showcase_tween.kill()
	var look_transform: Transform3D = camera_pivot.global_transform.looking_at(target.global_position, Vector3.UP)
	var target_basis: Basis = look_transform.basis
	var target_euler: Vector3 = target_basis.get_euler()
	var target_pitch: float = clampf(target_euler.x, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))
	var target_yaw: float = target_euler.y
	if _ultra_low_mode:
		camera_pivot.rotation.x = target_pitch
		player_rig.rotation.y = target_yaw
		camera.fov = 68.0
		return

	var move_duration: float = (0.95 if _is_demo_mode else 0.72) * _camera_transition_quality
	var zoom_fov: float = 58.0 if _is_demo_mode else 60.0
	var hold_duration: float = (0.34 if _is_demo_mode else 0.22) * _camera_transition_quality
	_active_showcase_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_active_showcase_tween.tween_property(camera_pivot, "rotation:x", target_pitch, move_duration)
	_active_showcase_tween.parallel().tween_property(player_rig, "rotation:y", target_yaw, move_duration)
	_active_showcase_tween.parallel().tween_property(camera, "fov", zoom_fov, move_duration * 0.7)
	_active_showcase_tween.tween_interval(hold_duration)
	_active_showcase_tween.tween_property(camera, "fov", 68.0, move_duration * 0.55)


func highlight_narrative_target(target_type: String, target_id: String) -> bool:
	clear_narrative_highlight()
	match target_type:
		"zone":
			return _zones.highlight_zone(target_id)
		"prop":
			return _props.highlight_prop(target_id)
		"door":
			if not _door_target_matches(target_id):
				return false
			_door.set_highlight(true)
			return true
		_:
			return false


func pulse_narrative_target(target_type: String, target_id: String) -> bool:
	clear_narrative_highlight()
	match target_type:
		"zone":
			return _zones.pulse_zone(target_id, self)
		"prop":
			return _props.pulse_prop(target_id, self)
		"door":
			if not _door_target_matches(target_id):
				return false
			_door.set_highlight(true)
			return true
		_:
			return false


func _highlight_vr_guided_target(target_type: String, target_id: String) -> bool:
	if target_type == "interactable" and _interactable_by_id.has(target_id):
		var interactable: Interactable = _interactable_by_id[target_id] as Interactable
		if interactable != null:
			interactable.set_hovered(true)
			return true
	return pulse_narrative_target(target_type, target_id)


func _vr_guided_target_exists(target_type: String, target_id: String) -> bool:
	if target_id.is_empty():
		return false
	match target_type:
		"door":
			return _door_target_matches(target_id)
		"zone":
			return _zones != null and _zones.zone_data_by_id.has(target_id)
		"prop":
			return _props != null and _props.prop_data_by_id.has(target_id)
		"interactable", "generic", "glass", "bottle", "plaque":
			return _interactable_by_id.has(target_id)
		_:
			return false


func clear_narrative_highlight() -> void:
	if _zones != null:
		_zones.clear_highlight()
	if _props != null:
		_props.clear_highlight()
	if _door != null:
		_door.set_highlight(false)


func _try_interact() -> void:
	_update_interaction_prompt()
	var action_hovered: bool = _current_hovered_interactable != null and _current_hovered_interactable.has_meta("museum_action")
	if not action_hovered and close_grape_inspection():
		return
	if _try_activate_vr_vial_hotspot():
		_play_click_audio()
		return

	if _current_hovered_interactable != null:
		var interactable_id: String = _current_hovered_interactable.id
		if not _can_interact_interactable(_current_hovered_interactable):
			return
		_play_click_audio()
		var target: Interactable = _current_hovered_interactable
		target.interact()
		if target.has_meta("museum_exhibit") or target.has_meta("museum_action") or target.has_meta("navigation_action"):
			interactable_clicked.emit(target)
			_hide_tooltip()
			return
		interactable_clicked.emit(target)
		door_interacted.emit(target.to_dict())
		if _guided != null:
			_guided.try_complete_step(interactable_id)
		_show_interaction_feedback(target.to_dict())
		return

	var active_ray: RayCast3D = _get_active_interaction_ray()
	if active_ray == null or not active_ray.is_colliding():
		return

	var collider: Object = active_ray.get_collider()
	if collider is Node and (collider as Node).is_in_group("winery_door"):
		var door_data: Dictionary = _zones.door_interactable.duplicate(true)
		if _can_interact_payload(door_data):
			_door.toggle(self)
			door_interacted.emit(door_data)
			_show_interaction_feedback(door_data)
			_complete_guided_from_payload(door_data)
			_play_click_audio()
		return

	var zone_data: Dictionary = _zones.get_zone_data_from_collider(collider)
	if not zone_data.is_empty() and _can_interact_payload(zone_data):
		door_interacted.emit(zone_data)
		_show_interaction_feedback(zone_data)
		_complete_guided_from_payload(zone_data)
		_play_click_audio()
		return

	var prop_data: Dictionary = _props.get_prop_data_from_collider(collider)
	if not prop_data.is_empty():
		var payload: Dictionary = {
			"id": str(prop_data.get("id", "")),
			"title": str(prop_data.get("id", "Prop")).replace("_", " ").capitalize(),
			"text": "This configured prop is part of the current winery layout.",
			"type": "prop"
		}
		if _can_interact_payload(payload):
			door_interacted.emit(payload)
			_show_interaction_feedback(payload)
			_complete_guided_from_payload(payload)
			_play_click_audio()


func _try_keyboard_interact() -> void:
	if _is_vr_active or _is_desktop_info_panel_open():
		return
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_keyboard_interaction_msec < KEYBOARD_INTERACTION_COOLDOWN_MSEC:
		return
	_last_keyboard_interaction_msec = now_msec
	_try_interact()


func _update_interaction_prompt() -> void:
	var active_ray: RayCast3D = _get_active_interaction_ray()
	if active_ray == null:
		_hide_interact_text_feedback()
		_set_hovered_interactable(null)
		if _door != null:
			_door.set_highlight(false)
		door_prompt_changed.emit("")
		interaction_target_changed.emit(false, "")
		_update_vr_feedback("", false, "")
		return
	var looking_at_door: bool = false
	var prompt: String = ""
	var hovered: Interactable = null
	var crosshair_can_interact: bool = false
	var crosshair_prompt: String = ""
	active_ray.force_raycast_update()
	if active_ray.is_colliding():
		var collider: Object = active_ray.get_collider()
		if _is_vr_active and _vr_vial_hotspots != null and bool(_vr_vial_hotspots.call("is_vial_hotspot_collider", collider)):
			_set_hovered_interactable(null)
			if _door != null:
				_door.set_highlight(false)
			door_prompt_changed.emit("Inspect tasting note")
			interaction_target_changed.emit(true, "Trigger to inspect")
			_update_vr_feedback("Inspect tasting note", true, "Trigger to inspect")
			return
		hovered = _find_interactable_node(collider)
		if _grape_museum != null and _grape_museum.is_inspecting() and (hovered == null or not hovered.has_meta("museum_action")):
			_set_hovered_interactable(null)
			door_prompt_changed.emit("")
			interaction_target_changed.emit(false, "")
			return
		looking_at_door = collider is Node and (collider as Node).is_in_group("winery_door")
		if hovered != null:
			prompt = hovered.title
			crosshair_can_interact = _can_interact_interactable(hovered)
			crosshair_prompt = "Επιλογή για εξέταση" if _is_vr_active else ("Πάτησε Εξέταση" if DisplayServer.is_touchscreen_available() or "--touch-ui" in OS.get_cmdline_user_args() else "E · Εξέταση")
			if not _is_vr_active:
				_hide_tooltip()
		elif looking_at_door:
			prompt = "Open the cellar door"
			var door_data: Dictionary = _zones.door_interactable.duplicate(true)
			crosshair_can_interact = _can_interact_payload(door_data)
			crosshair_prompt = "Trigger to open" if _is_vr_active else "Press E to inspect"
			if not _is_vr_active:
				_hide_tooltip()
		else:
			var zone_data: Dictionary = _zones.get_zone_data_from_collider(collider)
			if not zone_data.is_empty():
				prompt = "View " + str(zone_data.get("title", "this detail"))
				crosshair_can_interact = _can_interact_payload(zone_data)
				crosshair_prompt = "Trigger to inspect" if _is_vr_active else "Press E to inspect"
				if not _is_vr_active:
					_hide_tooltip()
			else:
				var prop_data: Dictionary = _props.get_prop_data_from_collider(collider)
				if not prop_data.is_empty():
					prompt = "Inspect " + str(prop_data.get("id", "this cellar detail")).replace("_", " ")
					crosshair_can_interact = _guided == null or _guided.can_interact(str(prop_data.get("id", "")))
					crosshair_prompt = "Trigger to inspect" if _is_vr_active else "Press E to inspect"
					if not _is_vr_active:
						_hide_tooltip()
				else:
					_hide_tooltip()
	else:
		_hide_tooltip()

	if _exploration_mode_active:
		_hide_tooltip()
	_set_hovered_interactable(hovered)
	if _door != null:
		_door.set_highlight(looking_at_door)
	door_prompt_changed.emit(prompt)
	interaction_target_changed.emit(crosshair_can_interact, crosshair_prompt if crosshair_can_interact else "")
	_hide_interact_text_feedback()
	_update_vr_feedback(prompt, crosshair_can_interact, crosshair_prompt)


func _set_hovered_interactable(next_hovered: Interactable) -> void:
	if _current_hovered_interactable == next_hovered:
		return
	if _current_hovered_interactable != null:
		_current_hovered_interactable.set_hovered(false)
		interactable_hover_ended.emit(_current_hovered_interactable)
	_current_hovered_interactable = next_hovered
	if _current_hovered_interactable != null:
		_current_hovered_interactable.set_hovered(true)
		interactable_hover_started.emit(_current_hovered_interactable)
		_play_hover_audio()


func _find_interactable_node(collider: Object) -> Interactable:
	if collider is Node:
		var node: Node = collider as Node
		while node != null:
			if node is Interactable:
				return node as Interactable
			node = node.get_parent()
	return null


func _register_scene_interactables() -> void:
	_interactable_by_id.clear()
	for node in find_children("*", "Interactable", true, false):
		var interactable: Interactable = node as Interactable
		if interactable == null:
			continue
		if interactable.id.is_empty():
			interactable.id = interactable.name.to_lower().replace(" ", "_")
		_interactable_by_id[interactable.id] = interactable


func _can_interact_interactable(interactable: Interactable) -> bool:
	if interactable == null or not interactable.is_visible_in_tree():
		return false
	if interactable.bypass_guided_lock:
		return true
	if _guided == null:
		return true
	return _guided.can_interact(interactable.id)


func _can_interact_payload(data: Dictionary) -> bool:
	if _guided == null:
		return true
	return _guided.can_interact(str(data.get("id", "")))


func _complete_guided_from_payload(data: Dictionary) -> void:
	if _guided == null:
		return
	_guided.try_complete_step(str(data.get("id", "")))


func _tooltip_action_text(interactable_id: String) -> String:
	if _completed_guided_ids.has(interactable_id):
		return "Completed ✓"
	if _guided != null and _guided.is_active() and not _guided.can_interact(interactable_id):
		return "Next"
	return "Interact"


func _get_interactable_by_type(environment_settings: Dictionary, interactable_type: String) -> Dictionary:
	var interactables: Array = environment_settings.get("interactables", [])
	for raw_interactable in interactables:
		if typeof(raw_interactable) != TYPE_DICTIONARY:
			continue
		var interactable: Dictionary = raw_interactable as Dictionary
		if str(interactable.get("type", "")) == interactable_type:
			return interactable.duplicate(true)
	return {}


func _door_target_matches(target_id: String) -> bool:
	if target_id.is_empty():
		return true
	if str(_zones.door_interactable.get("id", "")) == target_id:
		return true
	return _zones.zone_data_by_id.has(target_id)


func _apply_camera_start(raw_camera_start: Variant) -> void:
	if _movement == null:
		return
	if typeof(raw_camera_start) != TYPE_DICTIONARY:
		_movement.set_camera_start(Vector3(0.0, 0.0, 1.55), Vector3.ZERO)
		if vr_player_rig != null:
			vr_player_rig.position = Vector3(0.0, 0.0, 1.55)
			vr_player_rig.rotation = Vector3.ZERO
		return
	var camera_start: Dictionary = raw_camera_start as Dictionary
	var start_position: Vector3 = _array_to_vector3(camera_start.get("position", [0.0, 0.0, 1.55]), Vector3(0.0, 0.0, 1.55))
	var start_rotation: Vector3 = _array_to_rotation(camera_start.get("rotation", [0.0, 0.0, 0.0]))
	_movement.set_camera_start(start_position, start_rotation)
	if vr_player_rig != null:
		vr_player_rig.position = start_position
		vr_player_rig.rotation = start_rotation


func _array_to_vector3(value: Variant, fallback: Vector3) -> Vector3:
	if typeof(value) != TYPE_ARRAY:
		return fallback
	var data: Array = value as Array
	if data.size() < 3:
		return fallback
	return Vector3(float(data[0]), float(data[1]), float(data[2]))


func _array_to_rotation(value: Variant) -> Vector3:
	var degrees: Vector3 = _array_to_vector3(value, Vector3.ZERO)
	return Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z))


func _dict_value(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value as Dictionary
	return {}


func _on_guided_step_started(step_index: int, interactable_id: String) -> void:
	guided_step_started.emit(step_index, interactable_id)
	if _door_target_matches(interactable_id):
		_door.set_highlight(true)
		return
	if _interactable_by_id.has(interactable_id):
		var interactable: Interactable = _interactable_by_id[interactable_id] as Interactable
		if interactable != null:
			interactable.set_hovered(true)
			return
	if _props != null and _props.pulse_prop(interactable_id, self):
		return
	if _zones != null and _zones.pulse_zone(interactable_id, self):
		return


func _on_guided_step_completed(step_index: int, interactable_id: String) -> void:
	guided_step_completed.emit(step_index, interactable_id)
	_completed_guided_ids[interactable_id] = true
	_play_completion_audio()
	if _door_target_matches(interactable_id):
		_door.set_highlight(false)
	if _props != null and _props.prop_data_by_id.has(interactable_id):
		_props.set_highlight_completed(true)
	if _zones != null and _zones.zone_data_by_id.has(interactable_id):
		_zones.set_highlight_completed(true)
	if _interactable_by_id.has(interactable_id):
		var interactable: Interactable = _interactable_by_id[interactable_id] as Interactable
		if interactable != null and interactable != _current_hovered_interactable:
			interactable.set_hovered(false)


func _setup_interaction_ui() -> void:
	_interaction_ui_layer = CanvasLayer.new()
	_interaction_ui_layer.name = "InteractionUI"
	add_child(_interaction_ui_layer)
	_ensure_interact_text_feedback()

	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.custom_minimum_size = Vector2(320.0, 120.0)
	_tooltip_panel.position = Vector2(20.0, 20.0)
	_tooltip_panel.modulate.a = 0.0
	_tooltip_panel.visible = false
	_interaction_ui_layer.add_child(_tooltip_panel)

	var tooltip_bg: StyleBoxFlat = PremiumUIStyles.make_panel_style(0.88)
	_tooltip_panel.add_theme_stylebox_override("panel", tooltip_bg)

	var tooltip_margin: MarginContainer = MarginContainer.new()
	tooltip_margin.add_theme_constant_override("margin_left", 12)
	tooltip_margin.add_theme_constant_override("margin_right", 12)
	tooltip_margin.add_theme_constant_override("margin_top", 10)
	tooltip_margin.add_theme_constant_override("margin_bottom", 10)
	_tooltip_panel.add_child(tooltip_margin)

	var tooltip_vbox: VBoxContainer = VBoxContainer.new()
	tooltip_vbox.add_theme_constant_override("separation", 6)
	tooltip_margin.add_child(tooltip_vbox)
	PremiumUIStyles.apply_panel_chrome_to_vbox(tooltip_vbox)
	_tooltip_title = Label.new()
	_tooltip_title.modulate = PremiumUIStyles.TEXT_TITLE
	tooltip_vbox.add_child(_tooltip_title)
	_tooltip_description = Label.new()
	_tooltip_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_description.modulate = PremiumUIStyles.TEXT_BODY
	tooltip_vbox.add_child(_tooltip_description)
	_tooltip_action = Label.new()
	_tooltip_action.modulate = PremiumUIStyles.GOLD_ACCENT
	tooltip_vbox.add_child(_tooltip_action)

	_info_panel = PanelContainer.new()
	_info_panel.custom_minimum_size = Vector2(420.0, 180.0)
	_info_panel.position = Vector2(20.0, 150.0)
	_info_panel.modulate.a = 0.0
	_info_panel.visible = false
	_interaction_ui_layer.add_child(_info_panel)

	var info_bg: StyleBoxFlat = PremiumUIStyles.make_panel_style(0.9)
	_info_panel.add_theme_stylebox_override("panel", info_bg)

	var info_margin: MarginContainer = MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 14)
	info_margin.add_theme_constant_override("margin_right", 14)
	info_margin.add_theme_constant_override("margin_top", 12)
	info_margin.add_theme_constant_override("margin_bottom", 12)
	_info_panel.add_child(info_margin)
	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 7)
	info_margin.add_child(info_vbox)
	PremiumUIStyles.apply_panel_chrome_to_vbox(info_vbox)
	_info_title = Label.new()
	_info_title.modulate = PremiumUIStyles.TEXT_TITLE
	info_vbox.add_child(_info_title)
	_info_description = Label.new()
	_info_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_description.modulate = PremiumUIStyles.TEXT_BODY
	info_vbox.add_child(_info_description)
	_info_close_button = Button.new()
	_info_close_button.text = "Close"
	_info_close_button.custom_minimum_size = Vector2(0.0, 42.0)
	PremiumUIStyles.apply_gold_outline_button(_info_close_button)
	_info_close_button.pressed.connect(_hide_info_panel)
	info_vbox.add_child(_info_close_button)


func set_desktop_modal_context(active_modal_id: String) -> void:
	_desktop_modal_active_id = active_modal_id
	if _is_vr_active:
		if vr_player_rig != null and vr_player_rig.has_method("set_input_enabled"):
			vr_player_rig.call("set_input_enabled", _controls_enabled and active_modal_id.is_empty() and _xr_focused)
		_set_vr_teleport_enabled(_controls_enabled and active_modal_id.is_empty())
	if _grape_museum != null:
		_grape_museum.controls_enabled = _controls_enabled and active_modal_id.is_empty() and presentation_mode == "museum" and _xr_focused
	if not _desktop_modal_active_id.is_empty():
		_hide_tooltip()
		_hide_interact_text_feedback()


func get_tooltip_panel() -> PanelContainer:
	return _tooltip_panel


func get_info_panel() -> PanelContainer:
	return _info_panel


func close_desktop_info_panel() -> void:
	_hide_info_panel()


func close_tooltip_panel() -> void:
	_hide_tooltip()


func _is_desktop_info_panel_open() -> bool:
	return _info_panel != null and _info_panel.visible


func _ensure_interact_text_feedback() -> void:
	if _interact_feedback != null or _interaction_ui_layer == null:
		return
	_interact_feedback = VBoxContainer.new()
	_interact_feedback.name = "InteractTextFeedback"
	_interact_feedback.visible = false
	_interact_feedback.modulate.a = 0.0
	_interact_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interact_feedback.z_index = 120
	_interact_feedback.set_anchors_preset(Control.PRESET_CENTER, false)
	_interact_feedback.offset_left = -74.0
	_interact_feedback.offset_right = 74.0
	_interact_feedback.offset_top = -44.0
	_interact_feedback.offset_bottom = 42.0
	(_interact_feedback as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	(_interact_feedback as VBoxContainer).add_theme_constant_override("separation", 0)
	_interaction_ui_layer.add_child(_interact_feedback)

	_interact_feedback_label = Label.new()
	_interact_feedback_label.name = "InteractLabel"
	_interact_feedback_label.text = "Interact"
	_interact_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact_feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interact_feedback_label.add_theme_font_size_override("font_size", 14)
	_interact_feedback_label.add_theme_color_override("font_color", PremiumUIStyles.GOLD_ACCENT)
	_interact_feedback_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_interact_feedback_label.add_theme_constant_override("shadow_offset_x", 1)
	_interact_feedback_label.add_theme_constant_override("shadow_offset_y", 1)
	_interact_feedback.add_child(_interact_feedback_label)


func _show_interact_text_feedback(_data: Dictionary) -> void:
	_hide_interact_text_feedback()


func _hide_interact_text_feedback() -> void:
	if _interact_feedback == null:
		return
	if not _interact_feedback_visible and not _interact_feedback.visible:
		return
	if _interact_feedback_tween != null:
		_interact_feedback_tween.kill()
	_interact_feedback_visible = false
	_interact_feedback_target_id = ""
	_interact_feedback_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_interact_feedback_tween.tween_property(_interact_feedback, "modulate:a", 0.0, 0.12)
	_interact_feedback_tween.finished.connect(func() -> void:
		if _interact_feedback != null and not _interact_feedback_visible:
			_interact_feedback.visible = false
	)
	print("[WineVR][InteractUI] hidden")


func _can_show_desktop_interact_feedback() -> bool:
	if _is_vr_active or not _controls_enabled:
		return false
	if _interaction_ui_layer == null or not _interaction_ui_layer.visible:
		return false
	if not _desktop_modal_active_id.is_empty():
		return false
	return not _has_text_input_focus()


func _interact_feedback_label_for_data(data: Dictionary) -> String:
	var data_type: String = str(data.get("type", "")).to_lower()
	if data_type == "door" or str(data.get("id", "")).to_lower().find("door") >= 0:
		return "Open"
	if data_type == "prop" or data_type == "zone":
		return "Inspect"
	return "Interact"


func _has_text_input_focus() -> bool:
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	return focus_owner is LineEdit or focus_owner is TextEdit


func _show_tooltip(title_text: String, description_text: String, action_text: String) -> void:
	if _tooltip_panel == null:
		return
	if not _desktop_modal_active_id.is_empty():
		print("[WineVR][UI] Suppressed tooltip because modal active: %s" % _desktop_modal_active_id)
		_hide_tooltip()
		return
	var was_visible: bool = _tooltip_panel.visible
	_tooltip_title.text = title_text
	_tooltip_description.text = description_text
	_tooltip_action.text = action_text
	_tooltip_panel.visible = true
	if _tooltip_panel.has_meta("anim_tween") and _tooltip_panel.get_meta("anim_tween") is Tween:
		(_tooltip_panel.get_meta("anim_tween") as Tween).kill()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var tooltip_width: float = clampf(360.0, 260.0, viewport_size.x - 32.0)
	var tooltip_height: float = clampf(float(_tooltip_description.get_minimum_size().y) + 86.0, 120.0, minf(_tooltip_max_height, viewport_size.y * 0.28))
	_tooltip_panel.size = Vector2(tooltip_width, tooltip_height)
	ResponsiveLayoutController.center_panel_safe(_tooltip_panel, get_viewport(), clampf(viewport_size.x * 0.36, 360.0, 560.0), 0.28)
	var target_pos: Vector2 = _tooltip_panel.position
	_tooltip_panel.position = target_pos + Vector2(0.0, 10.0)
	if not was_visible:
		layout_refresh_requested.emit("panel opened")
	_tooltip_panel.modulate.a = 0.0
	var tween: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tooltip_panel.set_meta("anim_tween", tween)
	tween.set_parallel(true)
	tween.tween_property(_tooltip_panel, "modulate:a", 1.0, 0.16)
	tween.tween_property(_tooltip_panel, "position", target_pos, 0.2)


func _hide_tooltip() -> void:
	if _tooltip_panel != null:
		if _tooltip_panel.has_meta("anim_tween") and _tooltip_panel.get_meta("anim_tween") is Tween:
			(_tooltip_panel.get_meta("anim_tween") as Tween).kill()
		_tooltip_panel.modulate.a = 0.0
		_tooltip_panel.visible = false


func _show_info_panel(data: Dictionary) -> void:
	if _info_panel == null:
		return
	_info_auto_hide_token += 1
	_info_title.text = str(data.get("title", "Detail"))
	_info_description.text = str(data.get("description", data.get("text", "")))
	_info_panel.visible = true
	desktop_info_panel_opened.emit()
	_stop_info_panel_tween()
	_info_panel.modulate.a = 0.0
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var info_width: float = clampf(460.0, 300.0, viewport_size.x - 40.0)
	var info_height: float = clampf(float(_info_description.get_minimum_size().y) + 154.0, 220.0, minf(_info_max_height, viewport_size.y * 0.5))
	_info_panel.size = Vector2(info_width, info_height)
	ResponsiveLayoutController.center_panel_safe(_info_panel, get_viewport(), clampf(viewport_size.x * 0.36, 360.0, 560.0), 0.45)
	var target_pos: Vector2 = _info_panel.position
	_info_panel.position = target_pos + Vector2(0.0, 14.0)
	layout_refresh_requested.emit("panel opened")
	_info_panel_tween = create_tween()
	_info_panel_tween.set_parallel(true)
	_info_panel_tween.tween_property(_info_panel, "modulate:a", 1.0, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_info_panel_tween.tween_property(_info_panel, "position", target_pos, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _hide_info_panel() -> void:
	if _info_panel == null or not _info_panel.visible:
		return
	_info_auto_hide_token += 1
	_stop_info_panel_tween()
	_info_panel_tween = create_tween()
	_info_panel_tween.tween_property(_info_panel, "modulate:a", 0.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _info_panel_tween.finished
	_info_panel.visible = false
	desktop_info_panel_closed.emit()


func _stop_info_panel_tween() -> void:
	if _info_panel_tween != null:
		_info_panel_tween.kill()
		_info_panel_tween = null


func _setup_audio_players() -> void:
	_ambient_player = _make_audio_player("AmbientWineCellar", true)
	_hover_player = _make_audio_player("HoverSfx")
	_click_player = _make_audio_player("ClickSfx")
	_completion_player = _make_audio_player("CompleteSfx")
	_assign_stream_if_exists(_ambient_player, ambient_audio_path)
	_assign_stream_if_exists(_hover_player, hover_audio_path)
	_assign_stream_if_exists(_click_player, click_audio_path)
	_assign_stream_if_exists(_completion_player, completion_audio_path)
	if _ambient_player != null:
		_ambient_player.add_to_group("performance_optional")
	if _completion_player != null:
		_completion_player.add_to_group("cinematic_only")
	if _ambient_player != null and _ambient_player.stream != null:
		_ambient_player.volume_db = -16.0
		_ambient_player.play()
	if _hover_player != null:
		_hover_player.volume_db = -21.0
	if _click_player != null:
		_click_player.volume_db = -14.0
	if _completion_player != null:
		_completion_player.volume_db = -12.0


func _make_audio_player(player_name: String, looped: bool = false) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = player_name
	player.bus = "Master"
	player.stream_paused = false
	add_child(player)
	if looped and player.stream is AudioStream:
		(player.stream as AudioStream).resource_local_to_scene = true
	return player


func _assign_stream_if_exists(player: AudioStreamPlayer, path: String) -> void:
	if player == null or path.is_empty():
		return
	if ResourceLoader.exists(path):
		player.stream = load(path)


func _play_hover_audio() -> void:
	if _hover_player != null and _hover_player.stream != null and not _hover_player.playing:
		_hover_player.play()


func _play_click_audio() -> void:
	if _click_player != null and _click_player.stream != null:
		_click_player.play()


func _play_completion_audio() -> void:
	if _completion_player != null and _completion_player.stream != null:
		_completion_player.play()


func _setup_spotlight_root() -> void:
	_spotlight_root = Node3D.new()
	_spotlight_root.name = "CinematicPropSpotlights"
	_spotlight_root.add_to_group("premium_lights")
	_spotlight_root.add_to_group("performance_optional")
	add_child(_spotlight_root)


func _rebuild_prop_spotlights() -> void:
	if _spotlight_root == null or _props == null:
		return
	for child in _spotlight_root.get_children():
		child.queue_free()
	var target_props: Array[Dictionary] = _props.get_props_by_types(["wine_glass", "bottle_silhouette", "tasting_card", "wall_plaque"])
	for prop_data in target_props:
		var spotlight: SpotLight3D = SpotLight3D.new()
		spotlight.light_color = Color(1.0, 0.83, 0.62, 1.0)
		spotlight.light_energy = 1.55
		spotlight.spot_angle = 34.0
		spotlight.spot_range = 3.2
		spotlight.shadow_enabled = false
		spotlight.light_volumetric_fog_energy = 0.08
		spotlight.add_to_group("premium_lights")
		spotlight.add_to_group("performance_optional")
		var pos: Vector3 = _array_to_vector3((prop_data as Dictionary).get("position", [0.0, 0.0, 0.0]), Vector3.ZERO)
		spotlight.position = pos + Vector3(0.0, 1.45, 0.15)
		spotlight.look_at_from_position(spotlight.position, pos + Vector3(0.0, 0.35, 0.0), Vector3.UP)
		_spotlight_root.add_child(spotlight)


func refresh_interaction_ui_layout(viewport_size: Vector2) -> void:
	if _interact_feedback != null:
		_interact_feedback.set_anchors_preset(Control.PRESET_CENTER, false)
		_interact_feedback.offset_left = -74.0
		_interact_feedback.offset_right = 74.0
		_interact_feedback.offset_top = -44.0
		_interact_feedback.offset_bottom = 42.0
	if _tooltip_panel != null and _tooltip_panel.visible:
		var tooltip_width: float = clampf(_tooltip_panel.size.x, 260.0, viewport_size.x - 32.0)
		var tooltip_height: float = clampf(_tooltip_panel.size.y, 120.0, minf(_tooltip_max_height, viewport_size.y * 0.28))
		_tooltip_panel.size = Vector2(tooltip_width, tooltip_height)
		_tooltip_panel.position = Vector2(
			clampf(_tooltip_panel.position.x, 12.0, maxf(12.0, viewport_size.x - tooltip_width - 12.0)),
			clampf(_tooltip_panel.position.y, 12.0, maxf(12.0, viewport_size.y - tooltip_height - 12.0))
		)
	if _info_panel != null and _info_panel.visible:
		var info_width: float = clampf(_info_panel.size.x, 300.0, viewport_size.x - 40.0)
		var info_height: float = clampf(_info_panel.size.y, 180.0, minf(_info_max_height, viewport_size.y * 0.5))
		_info_panel.size = Vector2(info_width, info_height)
		_info_panel.position = Vector2(
			clampf(_info_panel.position.x, 14.0, maxf(14.0, viewport_size.x - info_width - 14.0)),
			clampf(_info_panel.position.y, 14.0, maxf(14.0, viewport_size.y - info_height - 14.0))
		)
