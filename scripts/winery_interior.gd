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

@export var move_speed: float = 2.4
@export var look_sensitivity: float = 0.005
@export var min_pitch_degrees: float = -30.0
@export var max_pitch_degrees: float = 30.0
@export var ambient_audio_path: String = ""
@export var hover_audio_path: String = ""
@export var click_audio_path: String = ""
@export var completion_audio_path: String = ""

@onready var player_rig: Node3D = $PlayerRig
@onready var camera_pivot: Node3D = $PlayerRig/CameraPivot
@onready var camera: Camera3D = $PlayerRig/CameraPivot/Camera3D
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var interaction_ray: RayCast3D = $PlayerRig/CameraPivot/Camera3D/InteractionRay
@onready var held_vial: Vial = $PlayerRig/CameraPivot/Camera3D/HeldVial
@onready var directional_light: DirectionalLight3D = $DirectionalLight3D
@onready var fill_light: OmniLight3D = $FillLight
@onready var floor_mesh: MeshInstance3D = $Floor
@onready var door_hinge: Node3D = $DoorAssembly/DoorHinge
@onready var door_mesh: MeshInstance3D = $DoorAssembly/DoorHinge/Door/DoorMesh

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

var _interaction_ui_layer: CanvasLayer
var _tooltip_panel: PanelContainer
var _tooltip_title: Label
var _tooltip_description: Label
var _tooltip_action: Label
var _info_panel: PanelContainer
var _info_title: Label
var _info_description: Label
var _tooltip_max_height: float = 220.0
var _info_max_height: float = 280.0


func _ready() -> void:
	interaction_ray.collide_with_areas = true
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
	_setup_audio_players()
	_setup_spotlight_root()
	fill_light.add_to_group("optional_lights")
	fill_light.add_to_group("performance_optional")
	_register_scene_interactables()
	apply_client_profile(ClientProfileLoader.get_active_client_data())
	_update_interaction_prompt()


func _physics_process(delta: float) -> void:
	if _movement != null and _movement.physics_update(delta):
		_update_interaction_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if _movement == null or not _movement.controls_enabled:
		return

	if event.is_action_pressed("interact") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		_try_interact()
		return
	if event is InputEventScreenTouch and event.pressed:
		_try_interact()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		show_current_guided_target()
		return
	if _movement.handle_input(event):
		_update_interaction_prompt()


func apply_client_profile(client_data: Dictionary) -> void:
	if client_data.is_empty():
		return
	if _environment == null or _props == null or _zones == null:
		return

	var vial_settings: Dictionary = _dict_value(client_data.get("vial_settings", {}))
	if held_vial != null:
		held_vial.liquid_fill_amount = float(vial_settings.get("liquid_fill_amount", held_vial.liquid_fill_amount))
		held_vial.liquid_color = _environment.parse_color(vial_settings.get("liquid_color", held_vial.liquid_color), held_vial.liquid_color)
		held_vial.cap_color = _environment.parse_color(vial_settings.get("cap_color", held_vial.cap_color), held_vial.cap_color)
		held_vial.rebuild_vial()
		held_vial.apply_qr_profile(client_data)

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


func set_controls_enabled(enabled: bool) -> void:
	if _movement == null:
		return
	_movement.set_controls_enabled(enabled)
	if _interaction_ui_layer != null:
		_interaction_ui_layer.visible = enabled
	if not enabled:
		_exploration_mode_active = false
		_door.set_highlight(false)
		interaction_target_changed.emit(false, "")
		door_prompt_changed.emit("")


func set_camera_active(active: bool) -> void:
	if camera != null:
		camera.current = active


func reset_view() -> void:
	if _movement != null:
		_movement.reset_view()


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
	if _movement != null and _movement.controls_enabled:
		_try_interact()


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


func clear_narrative_highlight() -> void:
	if _zones != null:
		_zones.clear_highlight()
	if _props != null:
		_props.clear_highlight()
	if _door != null:
		_door.set_highlight(false)


func _try_interact() -> void:
	if _current_hovered_interactable != null:
		var interactable_id: String = _current_hovered_interactable.id
		if _guided != null and not _guided.can_interact(interactable_id):
			return
		_play_click_audio()
		_current_hovered_interactable.interact()
		interactable_clicked.emit(_current_hovered_interactable)
		door_interacted.emit(_current_hovered_interactable.to_dict())
		if _guided != null:
			_guided.try_complete_step(interactable_id)
		_show_info_panel(_current_hovered_interactable.to_dict())
		return

	if not interaction_ray.is_colliding():
		return

	var collider: Object = interaction_ray.get_collider()
	if collider is Node and (collider as Node).is_in_group("winery_door"):
		var door_data: Dictionary = _zones.door_interactable.duplicate(true)
		if _can_interact_payload(door_data):
			_door.toggle(self)
			door_interacted.emit(door_data)
			_show_info_panel(door_data)
			_complete_guided_from_payload(door_data)
			_play_click_audio()
		return

	var zone_data: Dictionary = _zones.get_zone_data_from_collider(collider)
	if not zone_data.is_empty() and _can_interact_payload(zone_data):
		door_interacted.emit(zone_data)
		_show_info_panel(zone_data)
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
			_show_info_panel(payload)
			_complete_guided_from_payload(payload)
			_play_click_audio()


func _update_interaction_prompt() -> void:
	if interaction_ray == null:
		return
	var looking_at_door: bool = false
	var prompt: String = ""
	var hovered: Interactable = null
	var crosshair_can_interact: bool = false
	var crosshair_prompt: String = "Click to interact"
	interaction_ray.force_raycast_update()
	if interaction_ray.is_colliding():
		var collider: Object = interaction_ray.get_collider()
		hovered = _find_interactable_node(collider)
		looking_at_door = collider is Node and (collider as Node).is_in_group("winery_door")
		if hovered != null:
			prompt = "Interact"
			crosshair_can_interact = _guided == null or _guided.can_interact(hovered.id)
			crosshair_prompt = "Click to interact"
			if not _exploration_mode_active:
				_show_tooltip(hovered.title, hovered.description, _tooltip_action_text(hovered.id))
		elif looking_at_door:
			prompt = "Open the cellar door"
			var door_data: Dictionary = _zones.door_interactable.duplicate(true)
			crosshair_can_interact = _can_interact_payload(door_data)
			crosshair_prompt = "Click to open"
			if not _exploration_mode_active:
				_show_tooltip("Cellar Door", str(_zones.door_interactable.get("text", "")), _tooltip_action_text(str(_zones.door_interactable.get("id", ""))))
		else:
			var zone_data: Dictionary = _zones.get_zone_data_from_collider(collider)
			if not zone_data.is_empty():
				prompt = "View " + str(zone_data.get("title", "this detail"))
				crosshair_can_interact = _can_interact_payload(zone_data)
				crosshair_prompt = "Click to inspect"
				if not _exploration_mode_active:
					_show_tooltip(str(zone_data.get("title", "Detail")), str(zone_data.get("text", "")), _tooltip_action_text(str(zone_data.get("id", ""))))
			else:
				var prop_data: Dictionary = _props.get_prop_data_from_collider(collider)
				if not prop_data.is_empty():
					prompt = "Inspect " + str(prop_data.get("id", "this cellar detail")).replace("_", " ")
					crosshair_can_interact = _guided == null or _guided.can_interact(str(prop_data.get("id", "")))
					crosshair_prompt = "Click to inspect"
					if not _exploration_mode_active:
						_show_tooltip(str(prop_data.get("id", "Prop")).replace("_", " ").capitalize(), "Configured winery detail.", _tooltip_action_text(str(prop_data.get("id", ""))))
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
	interaction_target_changed.emit(crosshair_can_interact, crosshair_prompt)


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
		return
	var camera_start: Dictionary = raw_camera_start as Dictionary
	_movement.set_camera_start(
		_array_to_vector3(camera_start.get("position", [0.0, 0.0, 1.55]), Vector3(0.0, 0.0, 1.55)),
		_array_to_rotation(camera_start.get("rotation", [0.0, 0.0, 0.0]))
	)


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


func _show_tooltip(title_text: String, description_text: String, action_text: String) -> void:
	if _tooltip_panel == null:
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
	_info_title.text = str(data.get("title", "Detail"))
	_info_description.text = str(data.get("description", data.get("text", "")))
	_info_panel.visible = true
	if _info_panel.has_meta("fade_tween") and _info_panel.get_meta("fade_tween") is Tween:
		(_info_panel.get_meta("fade_tween") as Tween).kill()
	var tween: Tween = create_tween()
	_info_panel.set_meta("fade_tween", tween)
	_info_panel.modulate.a = 0.0
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var info_width: float = clampf(460.0, 300.0, viewport_size.x - 40.0)
	var info_height: float = clampf(float(_info_description.get_minimum_size().y) + 100.0, 180.0, minf(_info_max_height, viewport_size.y * 0.5))
	_info_panel.size = Vector2(info_width, info_height)
	ResponsiveLayoutController.center_panel_safe(_info_panel, get_viewport(), clampf(viewport_size.x * 0.36, 360.0, 560.0), 0.45)
	var target_pos: Vector2 = _info_panel.position
	_info_panel.position = target_pos + Vector2(0.0, 14.0)
	layout_refresh_requested.emit("panel opened")
	tween.set_parallel(true)
	tween.tween_property(_info_panel, "modulate:a", 1.0, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_info_panel, "position", target_pos, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


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
