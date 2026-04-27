extends Node3D
class_name WineryInteriorController

signal door_prompt_changed(prompt: String)
signal door_interacted(interactable_data: Dictionary)

@export var move_speed: float = 2.4
@export var look_sensitivity: float = 0.005
@export var min_pitch_degrees: float = -30.0
@export var max_pitch_degrees: float = 30.0

@onready var player_rig: Node3D = $PlayerRig
@onready var camera_pivot: Node3D = $PlayerRig/CameraPivot
@onready var camera: Camera3D = $PlayerRig/CameraPivot/Camera3D
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
var _props: WineryPropFactory
var _zones: WineryZoneManager


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
		_door
	)

	_props = WineryPropFactory.new()
	_props.setup(self, _environment)
	_zones = WineryZoneManager.new()
	_zones.setup(self)

	_movement = WineryMovementController.new()
	_movement.setup(player_rig, camera_pivot, move_speed, look_sensitivity, min_pitch_degrees, max_pitch_degrees)

	apply_client_profile(ClientProfileLoader.get_active_client_data())
	_update_interaction_prompt()


func _physics_process(delta: float) -> void:
	if _movement.physics_update(delta):
		_update_interaction_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if not _movement.controls_enabled:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_interact()
		return
	if event is InputEventScreenTouch and event.pressed:
		_try_interact()
		return
	if _movement.handle_input(event):
		_update_interaction_prompt()


func apply_client_profile(client_data: Dictionary) -> void:
	if client_data.is_empty():
		return

	var vial_settings: Dictionary = client_data.get("vial_settings", {})
	held_vial.liquid_fill_amount = float(vial_settings.get("liquid_fill_amount", held_vial.liquid_fill_amount))
	held_vial.liquid_color = _environment.parse_color(vial_settings.get("liquid_color", held_vial.liquid_color), held_vial.liquid_color)
	held_vial.cap_color = _environment.parse_color(vial_settings.get("cap_color", held_vial.cap_color), held_vial.cap_color)
	held_vial.rebuild_vial()

	var environment_settings: Dictionary = client_data.get("environment_settings", {})
	_environment.apply(environment_settings)
	_zones.door_interactable = _get_interactable_by_type(environment_settings, "door")
	if _zones.door_interactable.is_empty():
		_zones.door_interactable = {
			"id": "cellar_door",
			"title": "Cellar Door",
			"text": str(environment_settings.get("ambience_text", "")),
			"type": "door"
		}

	_apply_camera_start(environment_settings.get("camera_start", {}))
	_props.rebuild(environment_settings.get("props", []))
	_zones.rebuild(environment_settings.get("zones", []))


func set_controls_enabled(enabled: bool) -> void:
	_movement.set_controls_enabled(enabled)
	if not enabled:
		_door.set_highlight(false)
		door_prompt_changed.emit("")


func set_camera_active(active: bool) -> void:
	camera.current = active


func reset_view() -> void:
	_movement.reset_view()


func set_mobile_move_axis(axis: String, pressed: bool) -> void:
	_movement.set_mobile_move_axis(axis, pressed)


func handle_look_drag(relative_motion: Vector2) -> void:
	_movement.apply_look_drag(relative_motion)
	_update_interaction_prompt()


func interact_current() -> void:
	if _movement.controls_enabled:
		_try_interact()


func _try_interact() -> void:
	if not interaction_ray.is_colliding():
		return

	var collider: Object = interaction_ray.get_collider()
	if collider is Node and (collider as Node).is_in_group("winery_door"):
		_door.toggle(self)
		door_interacted.emit(_zones.door_interactable.duplicate(true))
		return

	var zone_data: Dictionary = _zones.get_zone_data_from_collider(collider)
	if not zone_data.is_empty():
		door_interacted.emit(zone_data)
		return

	var prop_data: Dictionary = _props.get_prop_data_from_collider(collider)
	if not prop_data.is_empty():
		door_interacted.emit({
			"id": str(prop_data.get("id", "")),
			"title": str(prop_data.get("id", "Prop")).replace("_", " ").capitalize(),
			"text": "This configured prop is part of the current winery layout.",
			"type": "prop"
		})


func _update_interaction_prompt() -> void:
	var looking_at_door: bool = false
	var prompt: String = ""
	interaction_ray.force_raycast_update()
	if interaction_ray.is_colliding():
		var collider: Object = interaction_ray.get_collider()
		looking_at_door = collider is Node and (collider as Node).is_in_group("winery_door")
		if looking_at_door:
			prompt = "Tap / Click to open the cellar door"
		else:
			var zone_data: Dictionary = _zones.get_zone_data_from_collider(collider)
			if not zone_data.is_empty():
				prompt = "Tap / Click to view %s" % str(zone_data.get("title", "this point"))
			else:
				var prop_data: Dictionary = _props.get_prop_data_from_collider(collider)
				if not prop_data.is_empty():
					prompt = "Tap / Click to inspect %s" % str(prop_data.get("id", "this prop")).replace("_", " ")

	_door.set_highlight(looking_at_door)
	door_prompt_changed.emit(prompt)


func _get_interactable_by_type(environment_settings: Dictionary, interactable_type: String) -> Dictionary:
	var interactables: Array = environment_settings.get("interactables", [])
	for raw_interactable in interactables:
		if typeof(raw_interactable) != TYPE_DICTIONARY:
			continue
		var interactable: Dictionary = raw_interactable as Dictionary
		if str(interactable.get("type", "")) == interactable_type:
			return interactable.duplicate(true)
	return {}


func _apply_camera_start(raw_camera_start: Variant) -> void:
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
