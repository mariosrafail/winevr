extends RefCounted
class_name WineryEnvironmentApplier

var directional_light: DirectionalLight3D
var fill_light: OmniLight3D
var floor_material: StandardMaterial3D
var wall_material: StandardMaterial3D
var barrel_material: StandardMaterial3D
var door_controller: WineryDoorController
var world_environment: WorldEnvironment


func setup(floor_mesh: MeshInstance3D, wall_meshes: Array, barrel_meshes: Array, directional: DirectionalLight3D, fill: OmniLight3D, door: WineryDoorController, world_env: WorldEnvironment = null) -> void:
	directional_light = directional
	fill_light = fill
	door_controller = door
	world_environment = world_env
	floor_material = _duplicate_mesh_material(floor_mesh, Color(0.318, 0.282, 0.239, 1.0))
	if not wall_meshes.is_empty():
		wall_material = _duplicate_mesh_material(wall_meshes[0] as MeshInstance3D, Color(0.545, 0.506, 0.447, 1.0))
	if not barrel_meshes.is_empty():
		barrel_material = _duplicate_mesh_material(barrel_meshes[0] as MeshInstance3D, Color(0.451, 0.29, 0.176, 1.0))

	for raw_wall in wall_meshes:
		var wall: MeshInstance3D = raw_wall as MeshInstance3D
		if wall != null:
			wall.set_surface_override_material(0, wall_material)
	for raw_barrel in barrel_meshes:
		var barrel: MeshInstance3D = raw_barrel as MeshInstance3D
		if barrel != null:
			barrel.set_surface_override_material(0, barrel_material)


func apply(environment_settings: Dictionary) -> void:
	if floor_material != null:
		floor_material.albedo_color = parse_color(environment_settings.get("floor_color", floor_material.albedo_color), floor_material.albedo_color)
	if wall_material != null:
		wall_material.albedo_color = parse_color(environment_settings.get("wall_color", wall_material.albedo_color), wall_material.albedo_color)
	if barrel_material != null:
		barrel_material.albedo_color = parse_color(environment_settings.get("barrel_color", barrel_material.albedo_color), barrel_material.albedo_color)
	if door_controller != null:
		door_controller.apply_color(parse_color(environment_settings.get("door_color", Color(0.329412, 0.211765, 0.121569, 1)), Color(0.329412, 0.211765, 0.121569, 1)))
	var quality: String = _normalize_quality(str(environment_settings.get("visual_quality", "medium")))
	_apply_lighting_preset(str(environment_settings.get("lighting_preset", "warm_classic")), environment_settings)
	_apply_quality(quality, environment_settings)


func parse_color(value: Variant, default_color: Color = Color.WHITE) -> Color:
	if value is Color:
		return value
	if value is String:
		var color_text: String = value
		if color_text.is_valid_html_color():
			return Color.from_string(color_text, default_color)
	return default_color


func _duplicate_mesh_material(mesh_instance: MeshInstance3D, fallback_color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D
	if mesh_instance == null:
		material = StandardMaterial3D.new()
		material.albedo_color = fallback_color
		return material
	var source_material: Material = mesh_instance.get_surface_override_material(0)
	if source_material is StandardMaterial3D:
		material = (source_material as StandardMaterial3D).duplicate()
	else:
		material = StandardMaterial3D.new()
		material.albedo_color = fallback_color
	mesh_instance.set_surface_override_material(0, material)
	return material


func _apply_lighting_preset(lighting_preset: String, environment_settings: Dictionary) -> void:
	var secondary_light_color: Color = parse_color(environment_settings.get("secondary_light_color", ""), Color.TRANSPARENT)
	match lighting_preset:
		"dark_premium":
			_set_directional_light(Color(1.0, 0.78, 0.55, 1.0), 1.05)
			_set_fill_light(secondary_light_color if secondary_light_color.a > 0.0 else Color(0.95, 0.54, 0.32, 1.0), 0.72)
		"bright_modern":
			_set_directional_light(Color(0.95, 0.98, 1.0, 1.0), 2.65)
			_set_fill_light(secondary_light_color if secondary_light_color.a > 0.0 else Color(0.82, 0.92, 1.0, 1.0), 1.85)
		_:
			_set_directional_light(Color(1.0, 0.925, 0.831, 1.0), 2.0)
			_set_fill_light(secondary_light_color if secondary_light_color.a > 0.0 else Color(1.0, 0.875, 0.733, 1.0), 1.5)


func _apply_quality(quality: String, environment_settings: Dictionary) -> void:
	if directional_light != null:
		directional_light.shadow_enabled = quality != "low"
	if fill_light != null:
		fill_light.shadow_enabled = quality == "high"
	if world_environment == null or world_environment.environment == null:
		return

	var env: Environment = world_environment.environment
	var fog_enabled: bool = bool(environment_settings.get("fog_enabled", false)) and quality == "high"
	env.fog_enabled = fog_enabled
	env.fog_light_color = parse_color(environment_settings.get("fog_color", "#1C1714"), Color(0.11, 0.09, 0.08, 1.0))
	env.fog_density = 0.018
	env.glow_enabled = quality == "high"


func _set_directional_light(color: Color, energy: float) -> void:
	if directional_light == null:
		return
	directional_light.light_color = color
	directional_light.light_energy = energy


func _set_fill_light(color: Color, energy: float) -> void:
	if fill_light == null:
		return
	fill_light.light_color = color
	fill_light.light_energy = energy


func _normalize_quality(value: String) -> String:
	if ["low", "medium", "high"].has(value):
		return value
	return "medium"
