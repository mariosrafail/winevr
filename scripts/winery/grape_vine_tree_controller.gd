extends Node3D
class_name GrapeVineTreeController

const LEAF_SHADER: Shader = preload("res://assets/models/grape_vine_tree/grape_leaf_wind.gdshader")
const BERRY_SHADER: Shader = preload("res://assets/models/grape_vine_tree/grape_berry_wind.gdshader")
const BARK_SHADER: Shader = preload("res://assets/models/grape_vine_tree/grape_bark_wind.gdshader")
const STEM_SHADER: Shader = preload("res://assets/models/grape_vine_tree/grape_stem_wind.gdshader")

const VINE_GLB_PATH: String = "res://assets/models/grape_vine_tree/grape_vine_tree.glb"

@export var wind_strength_scale: float = 1.0
@export var visibility_distance: float = 14.0
@export_enum("liatiko", "kotsifali", "vidiano") var grape_variety: String = "liatiko"

var _berry_materials: Array[ShaderMaterial] = []
static var _cached_visual: PackedScene


func _ready() -> void:
	_load_vine_visual()
	_apply_game_materials(self)


func _load_vine_visual() -> void:
	# Reuse imported meshes and textures across the outdoor demonstration vines.
	if _cached_visual == null and ResourceLoader.exists(VINE_GLB_PATH):
		_cached_visual = load(VINE_GLB_PATH) as PackedScene
	if _cached_visual != null:
		var imported: Node = _cached_visual.instantiate()
		imported.name = "GrapeVineVisual"
		add_child(imported)
		return
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
	_berry_materials.append(material)
	_apply_variety_palette(material)
	return material


func set_variety(variety_id: String) -> void:
	if variety_id not in ["liatiko", "kotsifali", "vidiano"]:
		return
	grape_variety = variety_id
	for material: ShaderMaterial in _berry_materials:
		_apply_variety_palette(material)


func _apply_variety_palette(material: ShaderMaterial) -> void:
	# These are visual skin palettes, never chemical measurements.
	match grape_variety:
		"vidiano":
			material.set_shader_parameter("grape_deep", Color("5c6c26"))
			material.set_shader_parameter("grape_mid", Color("c3b85e"))
			material.set_shader_parameter("bloom_tint", Color("e4df9c"))
		"kotsifali":
			material.set_shader_parameter("grape_deep", Color("19132b"))
			material.set_shader_parameter("grape_mid", Color("46213d"))
			material.set_shader_parameter("bloom_tint", Color("888497"))
		_:
			material.set_shader_parameter("grape_deep", Color("321124"))
			material.set_shader_parameter("grape_mid", Color("702b40"))
			material.set_shader_parameter("bloom_tint", Color("a48b95"))


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
