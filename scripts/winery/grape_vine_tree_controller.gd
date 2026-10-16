extends Node3D
class_name GrapeVineTreeController

const LEAF_SHADER: Shader = preload("res://assets/models/grape_vine_tree/grape_leaf_wind.gdshader")
const BERRY_SHADER: Shader = preload("res://assets/models/grape_vine_tree/grape_berry_wind.gdshader")
const BARK_SHADER: Shader = preload("res://assets/models/grape_vine_tree/grape_bark_wind.gdshader")
const STEM_SHADER: Shader = preload("res://assets/models/grape_vine_tree/grape_stem_wind.gdshader")

const VINE_GLB_PATH: String = "res://assets/models/grape_vine_tree/grape_vine_tree.glb"

@export var wind_strength_scale: float = 1.0
@export var visibility_distance: float = 14.0


func _ready() -> void:
	_load_vine_visual()
	_apply_game_materials(self)


func _load_vine_visual() -> void:
	if not FileAccess.file_exists(VINE_GLB_PATH):
		push_warning("[WineVR][Vine] Missing grape vine asset: %s" % VINE_GLB_PATH)
		return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error: Error = document.append_from_file(VINE_GLB_PATH, state)
	if error != OK:
		push_warning("[WineVR][Vine] GLB load failed with error %s" % error)
		return
	var generated: Node = document.generate_scene(state)
	if generated == null or not generated is Node3D:
		push_warning("[WineVR][Vine] GLB scene generation failed")
		return
	generated.name = "GrapeVineVisual"
	add_child(generated)

func _apply_game_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var lower_name: String = mesh_instance.name.to_lower()
		if "vineleaves" in lower_name:
			mesh_instance.material_override = _make_leaf_material(mesh_instance.get_active_material(0))
		elif "grapeberries" in lower_name:
			mesh_instance.material_override = _make_berry_material()
		elif "grapestems" in lower_name:
			mesh_instance.material_override = _make_stem_material()
		elif "vinewood" in lower_name:
			mesh_instance.material_override = _make_bark_material()
		mesh_instance.visibility_range_end = visibility_distance
		mesh_instance.visibility_range_end_margin = 1.5
	for child in node.get_children():
		_apply_game_materials(child)


func _make_leaf_material(source_material: Material) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = LEAF_SHADER
	# The exported GLB embeds the decimated source leaf's albedo/normal/roughness
	# textures. Reuse those imported Texture2D resources so exported PCK builds do
	# not depend on loose PNG files.
	if source_material != null:
		var albedo: Variant = source_material.get("albedo_texture")
		var normal: Variant = source_material.get("normal_texture")
		var roughness: Variant = source_material.get("roughness_texture")
		if albedo is Texture2D:
			material.set_shader_parameter("albedo_texture", albedo)
		if normal is Texture2D:
			material.set_shader_parameter("normal_texture", normal)
		if roughness is Texture2D:
			material.set_shader_parameter("roughness_texture", roughness)
	material.set_shader_parameter("wind_strength", 0.038 * wind_strength_scale)
	return material


func _make_berry_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = BERRY_SHADER
	material.set_shader_parameter("wind_strength", 0.010 * wind_strength_scale)
	return material


func _make_bark_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = BARK_SHADER
	material.set_shader_parameter("branch_sway", 0.006 * wind_strength_scale)
	return material


func _make_stem_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = STEM_SHADER
	material.set_shader_parameter("wind_strength", 0.010 * wind_strength_scale)
	return material
