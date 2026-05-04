extends Node
class_name GraphicsSettingsManager

signal preset_applied(preset_name: String)
signal performance_fallback_suggested()
signal camera_quality_changed(multiplier: float)

const PRESET_ULTRA_LOW: String = "Ultra Low"
const PRESET_LOW: String = "Low"
const PRESET_MEDIUM: String = "Medium"
const PRESET_HIGH: String = "High"
const PRESET_CINEMATIC: String = "Cinematic"
const CONFIG_PATH: String = "user://graphics_settings.cfg"

var current_preset: String = PRESET_MEDIUM
var fps_friendly: bool = false

var _viewport: Viewport
var _environment: Environment
var _tree: SceneTree
var _low_fps_seconds: float = 0.0
var _suggestion_cooldown: float = 0.0
var _suggestion_shown: bool = false
var _disabled_nodes_count: int = 0


func setup(tree: SceneTree, viewport: Viewport, environment: Environment = null) -> void:
	_tree = tree
	_viewport = viewport
	_environment = environment
	load_settings()
	apply_current()
	set_process(true)


func set_environment(environment: Environment) -> void:
	_environment = environment
	apply_current()


func set_preset(preset_name: String) -> void:
	if not _is_valid_preset(preset_name):
		return
	current_preset = preset_name


func set_fps_friendly(enabled: bool) -> void:
	fps_friendly = enabled


func apply_current() -> void:
	_apply_profile(current_preset, fps_friendly)
	save_settings()


func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	var loaded_preset: String = str(config.get_value("graphics", "preset", PRESET_MEDIUM))
	var loaded_friendly: bool = bool(config.get_value("graphics", "fps_friendly", false))
	if _is_valid_preset(loaded_preset):
		current_preset = loaded_preset
	fps_friendly = loaded_friendly


func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("graphics", "preset", current_preset)
	config.set_value("graphics", "fps_friendly", fps_friendly)
	config.save(CONFIG_PATH)


func mark_fallback_suggestion_resolved() -> void:
	_suggestion_shown = true
	_suggestion_cooldown = 20.0
	_low_fps_seconds = 0.0


func _process(delta: float) -> void:
	if _viewport == null:
		return
	if _suggestion_cooldown > 0.0:
		_suggestion_cooldown = maxf(0.0, _suggestion_cooldown - delta)

	var fps: float = Engine.get_frames_per_second()
	if fps < 25.0:
		_low_fps_seconds += delta
	else:
		_low_fps_seconds = maxf(0.0, _low_fps_seconds - delta * 0.7)

	if _low_fps_seconds >= 3.0 and _suggestion_cooldown <= 0.0 and not _suggestion_shown and current_preset != PRESET_ULTRA_LOW:
		performance_fallback_suggested.emit()
		_suggestion_shown = true


func _apply_profile(base_preset: String, friendly: bool) -> void:
	var preset: String = _effective_preset(base_preset, friendly)
	_disabled_nodes_count = 0
	_apply_viewport_profile(preset)
	_apply_environment_profile(preset)
	_apply_group_profile(preset)
	_apply_camera_profile(preset)
	_apply_material_simplification(preset)
	_apply_particle_profile(preset)
	current_preset = base_preset
	camera_quality_changed.emit(_camera_multiplier_for_preset(preset))
	preset_applied.emit(preset)
	if preset == PRESET_ULTRA_LOW:
		print("[GFX] Ultra Low mode applied")
		print("[GFX] disabled/hidden nodes=" + str(_disabled_nodes_count))


func _apply_viewport_profile(preset: String) -> void:
	if _viewport == null:
		return
	match preset:
		PRESET_ULTRA_LOW:
			_viewport.scaling_3d_scale = 0.6
			_viewport.msaa_3d = Viewport.MSAA_DISABLED
		PRESET_LOW:
			_viewport.scaling_3d_scale = 0.75
			_viewport.msaa_3d = Viewport.MSAA_DISABLED
		PRESET_MEDIUM:
			_viewport.scaling_3d_scale = 0.9
			_viewport.msaa_3d = Viewport.MSAA_2X
		PRESET_HIGH:
			_viewport.scaling_3d_scale = 1.0
			_viewport.msaa_3d = Viewport.MSAA_2X
		PRESET_CINEMATIC:
			_viewport.scaling_3d_scale = 1.0
			_viewport.msaa_3d = Viewport.MSAA_4X


func _apply_environment_profile(preset: String) -> void:
	if _environment == null:
		return
	match preset:
		PRESET_ULTRA_LOW:
			_environment.glow_enabled = false
			_environment.ssao_enabled = false
			_environment.ssil_enabled = false
			_set_env_property_if_exists("ssr_enabled", false)
			_set_env_property_if_exists("sdfgi_enabled", false)
			_set_env_property_if_exists("volumetric_fog_enabled", false)
			_environment.fog_enabled = false
		PRESET_LOW:
			_environment.glow_enabled = false
			_environment.ssao_enabled = false
			_environment.ssil_enabled = false
			_set_env_property_if_exists("ssr_enabled", false)
		PRESET_MEDIUM:
			_environment.glow_enabled = true
			_environment.ssao_enabled = false
			_environment.ssil_enabled = false
			_set_env_property_if_exists("ssr_enabled", false)
		PRESET_HIGH:
			_environment.glow_enabled = true
			_environment.ssao_enabled = true
			_environment.ssil_enabled = true
			_set_env_property_if_exists("ssr_enabled", true)
		PRESET_CINEMATIC:
			_environment.glow_enabled = true
			_environment.ssao_enabled = true
			_environment.ssil_enabled = true
			_set_env_property_if_exists("ssr_enabled", true)


func _apply_group_profile(preset: String) -> void:
	if _tree == null:
		return

	var premium_lights: Array = _tree.get_nodes_in_group("premium_lights")
	var cinematic_only: Array = _tree.get_nodes_in_group("cinematic_only")
	var performance_optional: Array = _tree.get_nodes_in_group("performance_optional")
	var highlight_effects: Array = _tree.get_nodes_in_group("highlight_effects")
	var ultra_disable: Array = _tree.get_nodes_in_group("ultra_disable")
	var optional_lights: Array = _tree.get_nodes_in_group("optional_lights")
	var particles_group: Array = _tree.get_nodes_in_group("particles")

	for node in premium_lights:
		if node is Light3D:
			var light: Light3D = node as Light3D
			match preset:
				PRESET_ULTRA_LOW:
					if light.visible:
						_disabled_nodes_count += 1
					light.visible = false
					light.shadow_enabled = false
				PRESET_LOW:
					light.visible = false
					light.shadow_enabled = false
				PRESET_MEDIUM:
					light.visible = true
					light.shadow_enabled = false
					light.light_energy = minf(light.light_energy, 1.0)
				PRESET_HIGH:
					light.visible = true
					light.shadow_enabled = true
				PRESET_CINEMATIC:
					light.visible = true
					light.shadow_enabled = true

	for node in optional_lights:
		if node is Light3D:
			var opt_light: Light3D = node as Light3D
			var disable_light: bool = preset == PRESET_ULTRA_LOW or preset == PRESET_LOW
			if disable_light and opt_light.visible:
				_disabled_nodes_count += 1
			opt_light.visible = not disable_light
			if disable_light:
				opt_light.shadow_enabled = false

	for node in ultra_disable:
		_set_node_enabled(node, preset != PRESET_ULTRA_LOW)

	for node in cinematic_only:
		var cinematic_enabled: bool = preset == PRESET_CINEMATIC
		if node is Node3D:
			_set_node_enabled(node, cinematic_enabled)
		elif node is AudioStreamPlayer:
			(node as AudioStreamPlayer).stream_paused = not cinematic_enabled

	for node in performance_optional:
		var optional_enabled: bool = preset != PRESET_ULTRA_LOW and preset != PRESET_LOW
		if node is Node3D:
			_set_node_enabled(node, optional_enabled)
		elif node is AudioStreamPlayer:
			(node as AudioStreamPlayer).stream_paused = not optional_enabled

	for node in particles_group:
		if node is GPUParticles3D:
			(node as GPUParticles3D).emitting = preset != PRESET_ULTRA_LOW and preset != PRESET_LOW
		elif node is CPUParticles3D:
			(node as CPUParticles3D).emitting = preset != PRESET_ULTRA_LOW and preset != PRESET_LOW

	var highlight_intensity: float = _highlight_multiplier_for_preset(preset)
	for node in highlight_effects:
		_apply_highlight_intensity(node, highlight_intensity)

	# Ultra Low: keep only one main light if possible and remove all shadows globally.
	if preset == PRESET_ULTRA_LOW:
		_ensure_single_main_light()
		for light in _tree.get_nodes_in_group("optional_lights"):
			if light is Light3D:
				(light as Light3D).shadow_enabled = false
		for light in _tree.get_nodes_in_group("premium_lights"):
			if light is Light3D:
				(light as Light3D).shadow_enabled = false

	# Global light shadow clamp in lower presets.
	if preset == PRESET_ULTRA_LOW or preset == PRESET_LOW:
		_disable_all_light_shadows()


func _apply_camera_profile(preset: String) -> void:
	if _viewport == null:
		return
	var camera: Camera3D = _viewport.get_camera_3d()
	if camera == null:
		return
	match preset:
		PRESET_ULTRA_LOW:
			camera.far = 28.0
			camera.near = 0.08
		PRESET_LOW:
			camera.far = 38.0
			camera.near = 0.06
		PRESET_MEDIUM:
			camera.far = 60.0
			camera.near = 0.05
		_:
			camera.far = 100.0
			camera.near = 0.05


func _apply_material_simplification(preset: String) -> void:
	if _tree == null:
		return
	var simplify: bool = preset == PRESET_ULTRA_LOW
	for node in _tree.get_nodes_in_group("performance_optional"):
		if node is MeshInstance3D:
			_simplify_mesh_materials(node as MeshInstance3D, simplify)
	for node in _tree.get_nodes_in_group("highlight_effects"):
		if node is MeshInstance3D:
			_simplify_mesh_materials(node as MeshInstance3D, simplify)


func _apply_particle_profile(preset: String) -> void:
	if _tree == null:
		return
	for node in _tree.get_nodes_in_group("particles"):
		if node is GPUParticles3D:
			(node as GPUParticles3D).emitting = preset != PRESET_ULTRA_LOW and preset != PRESET_LOW
		elif node is CPUParticles3D:
			(node as CPUParticles3D).emitting = preset != PRESET_ULTRA_LOW and preset != PRESET_LOW


func _simplify_mesh_materials(mesh_instance: MeshInstance3D, simplify: bool) -> void:
	if mesh_instance == null or mesh_instance.mesh == null:
		return
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var mat: Material = mesh_instance.get_surface_override_material(surface_index)
		if not (mat is StandardMaterial3D):
			continue
		var std: StandardMaterial3D = mat as StandardMaterial3D
		if simplify:
			var base_roughness: float = float(std.get_meta("base_roughness", std.roughness))
			std.set_meta("base_roughness", base_roughness)
			std.roughness = 1.0
			std.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			std.clearcoat_enabled = false
			std.refraction_enabled = false
			std.emission_enabled = false
			_set_std_property_if_exists(std, "metallic", 0.0)
			_set_std_property_if_exists(std, "rim_enabled", false)
		else:
			if std.has_meta("base_roughness"):
				std.roughness = float(std.get_meta("base_roughness"))


func _apply_highlight_intensity(node: Node, multiplier: float) -> void:
	if node is MeshInstance3D:
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.mesh != null:
			for surface_index in range(mesh.mesh.get_surface_count()):
				var mat: Material = mesh.get_surface_override_material(surface_index)
				if mat is StandardMaterial3D:
					var std: StandardMaterial3D = mat as StandardMaterial3D
					if std.emission_enabled:
						var base_energy: float = float(std.get_meta("base_emission_energy", std.emission_energy_multiplier))
						std.set_meta("base_emission_energy", base_energy)
						std.emission_energy_multiplier = clampf(base_energy * multiplier, 0.0, 2.0)
	for child in node.get_children():
		if child is Node:
			_apply_highlight_intensity(child as Node, multiplier)


func _effective_preset(base_preset: String, friendly: bool) -> String:
	if not friendly:
		return base_preset
	match base_preset:
		PRESET_CINEMATIC:
			return PRESET_HIGH
		PRESET_HIGH:
			return PRESET_MEDIUM
		PRESET_MEDIUM:
			return PRESET_LOW
		PRESET_LOW:
			return PRESET_ULTRA_LOW
		_:
			return base_preset


func _camera_multiplier_for_preset(preset: String) -> float:
	match preset:
		PRESET_ULTRA_LOW:
			return 0.0
		PRESET_LOW:
			return 0.7
		PRESET_MEDIUM:
			return 1.0
		PRESET_HIGH:
			return 1.08
		PRESET_CINEMATIC:
			return 1.2
		_:
			return 1.0


func _highlight_multiplier_for_preset(preset: String) -> float:
	match preset:
		PRESET_ULTRA_LOW:
			return 0.0
		PRESET_LOW:
			return 0.4
		PRESET_MEDIUM:
			return 0.78
		PRESET_HIGH:
			return 1.0
		PRESET_CINEMATIC:
			return 1.12
		_:
			return 1.0


func _is_valid_preset(value: String) -> bool:
	return [PRESET_ULTRA_LOW, PRESET_LOW, PRESET_MEDIUM, PRESET_HIGH, PRESET_CINEMATIC].has(value)


func _set_node_enabled(node: Node, enabled: bool) -> void:
	if node is Node3D:
		var n3d: Node3D = node as Node3D
		if n3d.visible != enabled and not enabled:
			_disabled_nodes_count += 1
		n3d.visible = enabled
	elif node is CanvasItem:
		var ci: CanvasItem = node as CanvasItem
		if ci.visible != enabled and not enabled:
			_disabled_nodes_count += 1
		ci.visible = enabled


func _set_env_property_if_exists(property_name: String, value: Variant) -> void:
	if _environment == null:
		return
	for item in _environment.get_property_list():
		if str((item as Dictionary).get("name", "")) == property_name:
			_environment.set(property_name, value)
			return


func _set_std_property_if_exists(mat: StandardMaterial3D, property_name: String, value: Variant) -> void:
	for item in mat.get_property_list():
		if str((item as Dictionary).get("name", "")) == property_name:
			mat.set(property_name, value)
			return


func _disable_all_light_shadows() -> void:
	if _tree == null or _tree.root == null:
		return
	_disable_light_shadows_recursive(_tree.root)


func _ensure_single_main_light() -> void:
	if _tree == null or _tree.root == null:
		return
	var main_light: DirectionalLight3D = _find_first_directional_light(_tree.root)
	if main_light != null:
		main_light.visible = true
		main_light.light_energy = maxf(main_light.light_energy, 0.65)
		main_light.shadow_enabled = false


func _find_first_directional_light(node: Node) -> DirectionalLight3D:
	if node is DirectionalLight3D:
		return node as DirectionalLight3D
	for child in node.get_children():
		if child is Node:
			var found: DirectionalLight3D = _find_first_directional_light(child as Node)
			if found != null:
				return found
	return null


func _disable_light_shadows_recursive(node: Node) -> void:
	if node is Light3D:
		(node as Light3D).shadow_enabled = false
	for child in node.get_children():
		if child is Node:
			_disable_light_shadows_recursive(child as Node)
