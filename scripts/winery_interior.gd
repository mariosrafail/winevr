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

var _controls_enabled: bool = false
var _look_dragging: bool = false
var _door_open: bool = false
var _door_highlighted: bool = false
var _wall_meshes: Array = []
var _barrel_meshes: Array = []
var _floor_material: StandardMaterial3D
var _wall_material: StandardMaterial3D
var _barrel_material: StandardMaterial3D
var _door_material: StandardMaterial3D
var _door_interactable: Dictionary = {}
var _mobile_move_vector: Vector2 = Vector2.ZERO
var _props_root: Node3D
var _zones_root: Node3D
var _zone_data_by_instance_id: Dictionary = {}
var _camera_start_position: Vector3 = Vector3(0.0, 0.0, 1.55)
var _camera_start_rotation: Vector3 = Vector3.ZERO


func _ready() -> void:
	_wall_meshes = [$BackWall, $FrontWall, $LeftWall, $RightWall]
	_barrel_meshes = [$BarrelA, $BarrelB, $BarrelC, $BarrelD]
	interaction_ray.collide_with_areas = true
	_props_root = Node3D.new()
	_props_root.name = "ConfigProps"
	add_child(_props_root)
	_zones_root = Node3D.new()
	_zones_root.name = "ConfigZones"
	add_child(_zones_root)
	_prepare_environment_materials()
	_prepare_door_material()
	apply_client_profile(ClientProfileLoader.get_active_client_data())
	_update_door_prompt()


func _physics_process(delta: float) -> void:
	if not _controls_enabled:
		return

	var input_vector := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		input_vector.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_vector.z += 1.0
	if Input.is_key_pressed(KEY_A):
		input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_vector.x += 1.0
	input_vector.x += _mobile_move_vector.x
	input_vector.z += _mobile_move_vector.y

	if input_vector.length() > 0.0:
		input_vector = input_vector.normalized()
		var basis := player_rig.global_transform.basis
		var forward := -basis.z
		var right := basis.x
		var movement := (right * input_vector.x + forward * input_vector.z) * move_speed * delta
		player_rig.global_position += Vector3(movement.x, 0.0, movement.z)
		player_rig.position.x = clampf(player_rig.position.x, -2.6, 2.6)
		player_rig.position.z = clampf(player_rig.position.z, -2.8, 2.2)

	_update_door_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if not _controls_enabled:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_look_dragging = event.pressed
			return
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_try_interact()
			return

	if event is InputEventScreenTouch and event.pressed:
		_try_interact()
		return

	if event is InputEventMouseMotion and _look_dragging:
		player_rig.rotate_y(-event.relative.x * look_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * look_sensitivity)
		camera_pivot.rotation.x = clampf(
			camera_pivot.rotation.x,
			deg_to_rad(min_pitch_degrees),
			deg_to_rad(max_pitch_degrees)
		)
		_update_door_prompt()


func apply_client_profile(client_data: Dictionary) -> void:
	if client_data.is_empty():
		return

	var vial_settings: Dictionary = client_data.get("vial_settings", {})
	held_vial.liquid_fill_amount = float(vial_settings.get("liquid_fill_amount", held_vial.liquid_fill_amount))
	held_vial.liquid_color = _parse_color(vial_settings.get("liquid_color", held_vial.liquid_color))
	held_vial.cap_color = _parse_color(vial_settings.get("cap_color", held_vial.cap_color))
	held_vial.rebuild_vial()

	var environment_settings: Dictionary = client_data.get("environment_settings", {})
	_apply_environment_settings(environment_settings)


func set_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled
	if not enabled:
		_look_dragging = false
		_mobile_move_vector = Vector2.ZERO
		_set_door_highlight(false)
		door_prompt_changed.emit("")


func set_camera_active(active: bool) -> void:
	camera.current = active


func reset_view() -> void:
	player_rig.position = _camera_start_position
	player_rig.rotation = _camera_start_rotation
	camera_pivot.rotation = Vector3.ZERO


func set_mobile_move_axis(axis: String, pressed: bool) -> void:
	var amount: float = 1.0 if pressed else 0.0
	match axis:
		"forward":
			_mobile_move_vector.y = -amount
		"back":
			_mobile_move_vector.y = amount
		"left":
			_mobile_move_vector.x = -amount
		"right":
			_mobile_move_vector.x = amount


func handle_look_drag(relative_motion: Vector2) -> void:
	if not _controls_enabled:
		return
	player_rig.rotate_y(-relative_motion.x * look_sensitivity)
	camera_pivot.rotate_x(-relative_motion.y * look_sensitivity)
	camera_pivot.rotation.x = clampf(
		camera_pivot.rotation.x,
		deg_to_rad(min_pitch_degrees),
		deg_to_rad(max_pitch_degrees)
	)
	_update_door_prompt()


func interact_current() -> void:
	if _controls_enabled:
		_try_interact()


func _try_interact() -> void:
	if not interaction_ray.is_colliding():
		return

	var collider: Object = interaction_ray.get_collider()
	if collider is Node and (collider as Node).is_in_group("winery_door"):
		_toggle_door()
		door_interacted.emit(_door_interactable.duplicate(true))
		return

	var zone_data: Dictionary = _get_zone_data_from_collider(collider)
	if not zone_data.is_empty():
		door_interacted.emit(zone_data)


func _toggle_door() -> void:
	_door_open = not _door_open
	var target_rotation: float = deg_to_rad(-78.0) if _door_open else 0.0
	var tween := create_tween()
	tween.tween_property(door_hinge, "rotation:y", target_rotation, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _update_door_prompt() -> void:
	var looking_at_door: bool = false
	var prompt: String = ""
	interaction_ray.force_raycast_update()
	if interaction_ray.is_colliding():
		var collider: Object = interaction_ray.get_collider()
		looking_at_door = collider is Node and (collider as Node).is_in_group("winery_door")
		if looking_at_door:
			prompt = "Tap / Click to open the cellar door"
		else:
			var zone_data: Dictionary = _get_zone_data_from_collider(collider)
			if not zone_data.is_empty():
				prompt = "Tap / Click to view %s" % str(zone_data.get("title", "this point"))

	_set_door_highlight(looking_at_door)
	door_prompt_changed.emit(prompt)


func _prepare_door_material() -> void:
	var source_material: Material = door_mesh.get_surface_override_material(0)
	if source_material is StandardMaterial3D:
		_door_material = (source_material as StandardMaterial3D).duplicate()
	else:
		_door_material = StandardMaterial3D.new()
		_door_material.albedo_color = Color(0.329412, 0.211765, 0.121569, 1)
	_door_material.emission_enabled = true
	_door_material.emission = Color(0.0, 0.0, 0.0, 1.0)
	door_mesh.set_surface_override_material(0, _door_material)


func _prepare_environment_materials() -> void:
	_floor_material = _duplicate_mesh_material(floor_mesh, Color(0.318, 0.282, 0.239, 1.0))
	var first_wall: MeshInstance3D = _wall_meshes[0] as MeshInstance3D
	var first_barrel: MeshInstance3D = _barrel_meshes[0] as MeshInstance3D
	_wall_material = _duplicate_mesh_material(first_wall, Color(0.545, 0.506, 0.447, 1.0))
	_barrel_material = _duplicate_mesh_material(first_barrel, Color(0.451, 0.29, 0.176, 1.0))

	for raw_wall in _wall_meshes:
		var wall: MeshInstance3D = raw_wall as MeshInstance3D
		if wall != null:
			wall.set_surface_override_material(0, _wall_material)
	for raw_barrel in _barrel_meshes:
		var barrel: MeshInstance3D = raw_barrel as MeshInstance3D
		if barrel != null:
			barrel.set_surface_override_material(0, _barrel_material)


func _duplicate_mesh_material(mesh_instance: MeshInstance3D, fallback_color: Color) -> StandardMaterial3D:
	var source_material: Material = mesh_instance.get_surface_override_material(0)
	var material: StandardMaterial3D
	if source_material is StandardMaterial3D:
		material = (source_material as StandardMaterial3D).duplicate()
	else:
		material = StandardMaterial3D.new()
		material.albedo_color = fallback_color
	mesh_instance.set_surface_override_material(0, material)
	return material


func _apply_environment_settings(environment_settings: Dictionary) -> void:
	if environment_settings.is_empty():
		environment_settings = {
			"lighting_preset": "warm_classic",
			"wall_color": "#8B8172",
			"floor_color": "#51483D",
			"barrel_color": "#734A2D",
			"door_color": "#51341F",
			"interactables": [],
			"props": [],
			"zones": [],
			"camera_start": {
				"position": [0.0, 0.0, 1.55],
				"rotation": [0.0, 0.0, 0.0]
			}
		}

	if _floor_material != null:
		_floor_material.albedo_color = _parse_color(environment_settings.get("floor_color", _floor_material.albedo_color), _floor_material.albedo_color)
	if _wall_material != null:
		_wall_material.albedo_color = _parse_color(environment_settings.get("wall_color", _wall_material.albedo_color), _wall_material.albedo_color)
	if _barrel_material != null:
		_barrel_material.albedo_color = _parse_color(environment_settings.get("barrel_color", _barrel_material.albedo_color), _barrel_material.albedo_color)
	if _door_material != null:
		_door_material.albedo_color = _parse_color(environment_settings.get("door_color", _door_material.albedo_color), _door_material.albedo_color)

	_apply_lighting_preset(str(environment_settings.get("lighting_preset", "warm_classic")))
	_door_interactable = _get_interactable_by_type(environment_settings, "door")
	if _door_interactable.is_empty():
		_door_interactable = {
			"id": "cellar_door",
			"title": "Cellar Door",
			"text": str(environment_settings.get("ambience_text", "")),
			"type": "door"
		}
	_apply_camera_start(environment_settings.get("camera_start", {}))
	_rebuild_props(environment_settings.get("props", []))
	_rebuild_zones(environment_settings.get("zones", []))


func _apply_lighting_preset(lighting_preset: String) -> void:
	match lighting_preset:
		"dark_premium":
			directional_light.light_color = Color(1.0, 0.78, 0.55, 1.0)
			directional_light.light_energy = 1.05
			fill_light.light_color = Color(0.95, 0.54, 0.32, 1.0)
			fill_light.light_energy = 0.72
		"bright_modern":
			directional_light.light_color = Color(0.95, 0.98, 1.0, 1.0)
			directional_light.light_energy = 2.65
			fill_light.light_color = Color(0.82, 0.92, 1.0, 1.0)
			fill_light.light_energy = 1.85
		_:
			directional_light.light_color = Color(1.0, 0.925, 0.831, 1.0)
			directional_light.light_energy = 2.0
			fill_light.light_color = Color(1.0, 0.875, 0.733, 1.0)
			fill_light.light_energy = 1.5


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
		_camera_start_position = Vector3(0.0, 0.0, 1.55)
		_camera_start_rotation = Vector3.ZERO
		return

	var camera_start: Dictionary = raw_camera_start as Dictionary
	_camera_start_position = _array_to_vector3(camera_start.get("position", [0.0, 0.0, 1.55]), Vector3(0.0, 0.0, 1.55))
	_camera_start_rotation = _array_to_rotation(camera_start.get("rotation", [0.0, 0.0, 0.0]))


func _rebuild_props(raw_props: Array) -> void:
	for child in _props_root.get_children():
		child.queue_free()

	for raw_prop in raw_props:
		if typeof(raw_prop) != TYPE_DICTIONARY:
			continue
		var prop_data: Dictionary = raw_prop as Dictionary
		if not bool(prop_data.get("visible", true)):
			continue
		var prop_node: Node3D = _create_prop(prop_data)
		_props_root.add_child(prop_node)


func _create_prop(prop_data: Dictionary) -> Node3D:
	var prop_type: String = str(prop_data.get("type", "crate"))
	var prop_node: Node3D
	match prop_type:
		"barrel":
			prop_node = _create_barrel_prop(prop_data)
		"table":
			prop_node = _create_table_prop(prop_data)
		"sign":
			prop_node = _create_sign_prop(prop_data)
		"column":
			prop_node = _create_column_prop(prop_data)
		_:
			prop_node = _create_crate_prop(prop_data)

	prop_node.name = str(prop_data.get("id", prop_type))
	prop_node.position = _array_to_vector3(prop_data.get("position", [0.0, 0.0, 0.0]), Vector3.ZERO)
	prop_node.rotation = _array_to_rotation(prop_data.get("rotation", [0.0, 0.0, 0.0]))
	prop_node.scale = _array_to_vector3(prop_data.get("scale", [1.0, 1.0, 1.0]), Vector3.ONE)
	return prop_node


func _create_barrel_prop(prop_data: Dictionary) -> Node3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.38
	mesh.bottom_radius = 0.38
	mesh.height = 0.95
	mesh.radial_segments = 16
	var prop := MeshInstance3D.new()
	prop.mesh = mesh
	prop.set_surface_override_material(0, _make_prop_material(prop_data, _barrel_material.albedo_color if _barrel_material != null else Color(0.451, 0.29, 0.176, 1.0)))
	return prop


func _create_crate_prop(prop_data: Dictionary) -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.75, 0.55, 0.55)
	var prop := MeshInstance3D.new()
	prop.mesh = mesh
	prop.set_surface_override_material(0, _make_prop_material(prop_data, Color(0.36, 0.23, 0.13, 1.0)))
	return prop


func _create_column_prop(prop_data: Dictionary) -> Node3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.28
	mesh.bottom_radius = 0.28
	mesh.height = 1.2
	mesh.radial_segments = 12
	var prop := MeshInstance3D.new()
	prop.mesh = mesh
	prop.set_surface_override_material(0, _make_prop_material(prop_data, _wall_material.albedo_color if _wall_material != null else Color(0.545, 0.506, 0.447, 1.0)))
	return prop


func _create_sign_prop(prop_data: Dictionary) -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 0.55, 0.06)
	var prop := MeshInstance3D.new()
	prop.mesh = mesh
	prop.set_surface_override_material(0, _make_prop_material(prop_data, Color(0.78, 0.62, 0.34, 1.0)))
	return prop


func _create_table_prop(prop_data: Dictionary) -> Node3D:
	var table_root := Node3D.new()
	var top := _create_box_part(Vector3(1.2, 0.12, 0.65), Vector3(0.0, 0.28, 0.0), prop_data, Color(0.42, 0.25, 0.15, 1.0))
	table_root.add_child(top)
	for x in [-0.48, 0.48]:
		for z in [-0.22, 0.22]:
			var leg := _create_box_part(Vector3(0.09, 0.48, 0.09), Vector3(x, 0.0, z), prop_data, Color(0.34, 0.20, 0.12, 1.0))
			table_root.add_child(leg)
	return table_root


func _create_box_part(size: Vector3, part_position: Vector3, prop_data: Dictionary, fallback_color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := MeshInstance3D.new()
	part.position = part_position
	part.mesh = mesh
	part.set_surface_override_material(0, _make_prop_material(prop_data, fallback_color))
	return part


func _make_prop_material(prop_data: Dictionary, fallback_color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = _parse_color(prop_data.get("color", ""), fallback_color)
	material.roughness = 0.82
	return material


func _rebuild_zones(raw_zones: Array) -> void:
	for child in _zones_root.get_children():
		child.queue_free()
	_zone_data_by_instance_id.clear()

	for raw_zone in raw_zones:
		if typeof(raw_zone) != TYPE_DICTIONARY:
			continue
		var zone_data: Dictionary = raw_zone as Dictionary
		if str(zone_data.get("type", "")) == "door":
			_door_interactable = zone_data.duplicate(true)
			continue
		var zone := Area3D.new()
		zone.name = str(zone_data.get("id", "zone"))
		zone.add_to_group("winery_zone")
		zone.position = _array_to_vector3(zone_data.get("position", [0.0, 1.1, -1.0]), Vector3(0.0, 1.1, -1.0))
		zone.collision_layer = 1
		zone.collision_mask = 1
		var collision_shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = maxf(0.15, float(zone_data.get("radius", 0.7)))
		collision_shape.shape = sphere
		zone.add_child(collision_shape)
		_zones_root.add_child(zone)
		_zone_data_by_instance_id[zone.get_instance_id()] = zone_data.duplicate(true)


func _get_zone_data_from_collider(collider: Object) -> Dictionary:
	if collider is Node:
		var node: Node = collider as Node
		while node != null:
			if node.is_in_group("winery_zone") and _zone_data_by_instance_id.has(node.get_instance_id()):
				return (_zone_data_by_instance_id[node.get_instance_id()] as Dictionary).duplicate(true)
			node = node.get_parent()
	return {}


func _set_door_highlight(enabled: bool) -> void:
	if _door_highlighted == enabled or _door_material == null:
		return

	_door_highlighted = enabled
	_door_material.emission = Color(0.95, 0.68, 0.28, 1.0) if enabled else Color(0.0, 0.0, 0.0, 1.0)
	_door_material.emission_energy_multiplier = 0.55 if enabled else 0.0


func _parse_color(value, default_color: Color = Color.WHITE) -> Color:
	if value is Color:
		return value
	if value is String:
		var color_text: String = value
		if color_text.is_valid_html_color():
			return Color.from_string(color_text, default_color)
	return default_color


func _array_to_vector3(value: Variant, fallback: Vector3) -> Vector3:
	if typeof(value) != TYPE_ARRAY:
		return fallback
	var data: Array = value as Array
	if data.size() < 3:
		return fallback
	return Vector3(float(data[0]), float(data[1]), float(data[2]))


func _array_to_rotation(value: Variant) -> Vector3:
	var rotation_degrees_value: Vector3 = _array_to_vector3(value, Vector3.ZERO)
	return Vector3(
		deg_to_rad(rotation_degrees_value.x),
		deg_to_rad(rotation_degrees_value.y),
		deg_to_rad(rotation_degrees_value.z)
	)
