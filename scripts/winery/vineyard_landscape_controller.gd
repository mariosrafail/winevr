extends Node3D
class_name VineyardLandscapeController

const LANDSCAPE_GLB_PATH: String = "res://assets/models/vineyard_landscape/vineyard_landscape.glb"
const FOLIAGE_SHADER: Shader = preload("res://assets/models/vineyard_landscape/landscape_foliage_wind.gdshader")
const GROUND_SHADER: Shader = preload("res://assets/models/vineyard_landscape/landscape_ground.gdshader")
const BARREL_SHADER: Shader = preload("res://assets/models/vineyard_landscape/barrel_wood.gdshader")
const GRAVEL_SHADER: Shader = preload("res://assets/models/vineyard_landscape/gravel_road.gdshader")
const HILL_SHADER: Shader = preload("res://assets/models/vineyard_landscape/distant_hill.gdshader")
const BARK_SHADER: Shader = preload("res://assets/models/vineyard_landscape/landscape_bark.gdshader")
const METAL_SHADER: Shader = preload("res://assets/models/vineyard_landscape/weathered_metal.gdshader")

@export var wind_strength_scale: float = 1.0
@export var visibility_distance: float = 80.0


func _ready() -> void:
	_load_landscape()
	_apply_materials(self)


func _load_landscape() -> void:
	if not FileAccess.file_exists(LANDSCAPE_GLB_PATH):
		push_warning("[WineVR][Landscape] Missing landscape asset: %s" % LANDSCAPE_GLB_PATH)
		return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error: Error = document.append_from_file(LANDSCAPE_GLB_PATH, state)
	if error != OK:
		push_warning("[WineVR][Landscape] GLB load failed with error %s" % error)
		return
	var generated: Node = document.generate_scene(state)
	if generated == null or not generated is Node3D:
		push_warning("[WineVR][Landscape] GLB scene generation failed")
		return
	generated.name = "VineyardLandscapeVisual"
	add_child(generated)


func _apply_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var lower_name: String = mesh_instance.name.to_lower()
		if "vineyardfoliage" in lower_name:
			var source_leaf_material: Material = mesh_instance.get_active_material(0)
			mesh_instance.material_override = _make_foliage_material(
				0.020,
				0.7,
				Color(0.045, 0.155, 0.020),
				Color(0.22, 0.39, 0.055),
				source_leaf_material,
				Color(0.64, 0.86, 0.54),
				0.055
			)
		elif "vineyardcanopymass" in lower_name:
			mesh_instance.material_override = _make_foliage_material(
				0.010,
				0.75,
				Color(0.050, 0.145, 0.016),
				Color(0.17, 0.30, 0.040),
				null,
				Color.WHITE,
				0.075
			)
		elif "landscapetreefoliage" in lower_name:
			mesh_instance.material_override = _make_foliage_material(
				0.038,
				4.0,
				Color(0.055, 0.145, 0.020),
				Color(0.25, 0.38, 0.060),
				null,
				Color.WHITE,
				0.19
			)
		elif "landscapeterrain" in lower_name:
			var ground := ShaderMaterial.new()
			ground.shader = GROUND_SHADER
			mesh_instance.material_override = ground
		elif "vineyardrowsoil" in lower_name:
			var row_ground := ShaderMaterial.new()
			row_ground.shader = GROUND_SHADER
			row_ground.set_shader_parameter("grass_a", Color(0.085, 0.040, 0.010))
			row_ground.set_shader_parameter("grass_b", Color(0.16, 0.072, 0.017))
			row_ground.set_shader_parameter("earth", Color(0.055, 0.024, 0.007))
			mesh_instance.material_override = row_ground
		elif "gravelroad" in lower_name:
			var gravel := ShaderMaterial.new()
			gravel.shader = GRAVEL_SHADER
			mesh_instance.material_override = gravel
		elif "distanthills" in lower_name:
			var hills := ShaderMaterial.new()
			hills.shader = HILL_SHADER
			mesh_instance.material_override = hills
		elif "barrelwood" in lower_name:
			var barrel := ShaderMaterial.new()
			barrel.shader = BARREL_SHADER
			mesh_instance.material_override = barrel
		elif "barrelbands" in lower_name:
			var bands := ShaderMaterial.new()
			bands.shader = METAL_SHADER
			bands.set_shader_parameter("metal_dark", Color(0.15, 0.16, 0.16))
			bands.set_shader_parameter("metal_light", Color(0.46, 0.47, 0.45))
			bands.set_shader_parameter("metallic_amount", 0.82)
			mesh_instance.material_override = bands
		elif "barrelracks" in lower_name:
			var rack := ShaderMaterial.new()
			rack.shader = METAL_SHADER
			rack.set_shader_parameter("metal_dark", Color(0.035, 0.040, 0.038))
			rack.set_shader_parameter("metal_light", Color(0.12, 0.13, 0.12))
			rack.set_shader_parameter("rust_color", Color(0.18, 0.065, 0.020))
			rack.set_shader_parameter("metallic_amount", 0.62)
			mesh_instance.material_override = rack
		elif "landscapetreewood" in lower_name:
			var bark := ShaderMaterial.new()
			bark.shader = BARK_SHADER
			mesh_instance.material_override = bark
		mesh_instance.visibility_range_end = visibility_distance
		mesh_instance.visibility_range_end_margin = 6.0
	for child in node.get_children():
		_apply_materials(child)


func _make_foliage_material(
	base_strength: float,
	scale_hint: float,
	dark_color: Color,
	sun_color: Color,
	source_material: Material,
	texture_tint: Color,
	emission_strength: float
) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FOLIAGE_SHADER
	material.set_shader_parameter("wind_strength", base_strength * wind_strength_scale)
	material.set_shader_parameter("object_scale_hint", scale_hint)
	material.set_shader_parameter("dark_green", dark_color)
	material.set_shader_parameter("sun_green", sun_color)
	material.set_shader_parameter("texture_tint", texture_tint)
	material.set_shader_parameter("emission_strength", emission_strength)
	if source_material != null:
		var albedo: Variant = source_material.get("albedo_texture")
		var normal: Variant = source_material.get("normal_texture")
		var roughness: Variant = source_material.get("roughness_texture")
		if albedo is Texture2D and normal is Texture2D and roughness is Texture2D:
			material.set_shader_parameter("albedo_texture", albedo)
			material.set_shader_parameter("normal_texture", normal)
			material.set_shader_parameter("roughness_texture", roughness)
			material.set_shader_parameter("use_pbr_textures", true)
	return material
