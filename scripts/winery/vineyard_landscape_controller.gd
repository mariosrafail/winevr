extends Node3D
class_name VineyardLandscapeController

signal station_selected(station_id: String)
signal return_to_museum_requested

const LANDSCAPE_GLB_PATH: String = "res://assets/models/vineyard_landscape/vineyard_landscape.glb"
const FOLIAGE_SHADER: Shader = preload("res://assets/models/vineyard_landscape/landscape_foliage_wind.gdshader")
const GROUND_SHADER: Shader = preload("res://assets/models/vineyard_landscape/landscape_ground.gdshader")
const SKY_SHADER: Shader = preload("res://assets/shaders/cretan_sky.gdshader")
const TERRAIN_ALBEDO: Texture2D = preload("res://assets/textures/cretan_terrain/rocky_terrain_02_diffuse_2k.jpg")
const TERRAIN_ARM: Texture2D = preload("res://assets/textures/cretan_terrain/rocky_terrain_02_arm_2k.jpg")
const TERRAIN_NORMAL: Texture2D = preload("res://assets/textures/cretan_terrain/rocky_terrain_02_nor_gl_2k.jpg")
const BARREL_SHADER: Shader = preload("res://assets/models/vineyard_landscape/barrel_wood.gdshader")
const GRAVEL_SHADER: Shader = preload("res://assets/models/vineyard_landscape/gravel_road.gdshader")
const HILL_SHADER: Shader = preload("res://assets/models/vineyard_landscape/distant_hill.gdshader")
const BARK_SHADER: Shader = preload("res://assets/models/vineyard_landscape/landscape_bark.gdshader")
const METAL_SHADER: Shader = preload("res://assets/models/vineyard_landscape/weathered_metal.gdshader")
const STONE_SHADER: Shader = preload("res://assets/shaders/museum_stone.gdshader")
const RIDGE_SHADER: Shader = preload("res://assets/shaders/cretan_ridge.gdshader")
const TERROIR_PATH: String = "res://data/cretan_terroir.json"
const VINE_SCENE: PackedScene = preload("res://scenes/GrapeVineTree.tscn")
const TERRACE_HEIGHT: float = 0.18
const GOLD: Color = Color("ceae6c")
const IVORY: Color = Color("f0e7d6")

@export var wind_strength_scale: float = 1.0
@export var visibility_distance: float = 80.0

var data: Dictionary = {}
var stations: Dictionary = {}
var visited_stations: Dictionary = {}
var _collision_layers: Dictionary = {}
var _progress_label: Label3D
var _stone: ShaderMaterial
var _dark: StandardMaterial3D
var _gold: StandardMaterial3D
var _wood: ShaderMaterial
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_load_landscape()
	_apply_materials(self)
	_load_terroir()
	_rng.seed = 241009
	_stone = ShaderMaterial.new()
	_stone.shader = STONE_SHADER
	_stone.set_shader_parameter("stone_color", Color("b8ac91"))
	_stone.set_shader_parameter("tile_scale", 0.85)
	_dark = _material(Color("303c36"), 0.78)
	_gold = _material(GOLD, 0.39, 0.65)
	_wood = ShaderMaterial.new()
	_wood.shader = BARK_SHADER
	_build_terrace()
	_build_horizon()
	_build_dry_stone_details()
	_build_demonstration_vines()
	_build_tour()
	_cache_collision_layers(self)
	print("[WineVR][Terroir] Four source-backed stations; artistic Cretan vineyard landscape")


func _load_terroir() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TERROIR_PATH))
	if parsed is Dictionary:
		data = parsed as Dictionary
	else:
		push_error("[WineVR][Terroir] Invalid tour data")


func get_spawn_position() -> Vector3:
	return Vector3(0.0, TERRACE_HEIGHT, 3.2)


func get_bounds_min() -> Vector2:
	return Vector2(-8.6, -1.8)


func get_bounds_max() -> Vector2:
	return Vector2(8.6, 3.6)


func set_active(active: bool) -> void:
	visible = active
	for body: CollisionObject3D in _collision_layers:
		if is_instance_valid(body):
			body.collision_layer = int(_collision_layers[body]) if active else 0
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func _cache_collision_layers(node: Node) -> void:
	if node is CollisionObject3D:
		_collision_layers[node] = (node as CollisionObject3D).collision_layer
	for child in node.get_children():
		_cache_collision_layers(child)


func configure_environment(environment: Environment) -> void:
	if environment == null:
		return
	var compatibility: bool = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	($LateAfternoonSun as DirectionalLight3D).light_energy = 0.78 if compatibility else 1.30
	($WarmFill as DirectionalLight3D).light_energy = 0.08 if compatibility else 0.12
	var sky_material: ShaderMaterial = ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	var sky: Sky = Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.sky_material = sky_material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("dae3e3")
	environment.ambient_light_energy = 0.30 if compatibility else 0.45
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0 if compatibility else 1.05
	environment.fog_enabled = true
	environment.fog_light_color = Color("b5cad1")
	environment.fog_light_energy = 0.6
	environment.fog_density = 0.0015
	environment.fog_aerial_perspective = 0.22
	environment.fog_sky_affect = 0.0
	environment.volumetric_fog_enabled = false
	environment.glow_enabled = false


func _load_landscape() -> void:
	# Imported scenes work in exported PCK files even when loose GLBs are absent.
	# The fallback keeps editable/source-only copies usable during development.
	if ResourceLoader.exists(LANDSCAPE_GLB_PATH):
		var packed: PackedScene = load(LANDSCAPE_GLB_PATH) as PackedScene
		if packed != null:
			var imported: Node3D = packed.instantiate() as Node3D
			if imported != null:
				imported.name = "VineyardLandscapeVisual"
				imported.position.z = -7.0
				add_child(imported)
				return
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
	(generated as Node3D).position.z = -7.0
	add_child(generated)


func _apply_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var lower_name: String = mesh_instance.name.to_lower()
		# Replace the flat backdrop and oversized sunset disc with a continuous
		# modeled horizon and a directional sky sun. Keep authored vines intact.
		if "distanthills" in lower_name or "sunsetdisc" in lower_name:
			mesh_instance.hide()
		if "barrel" in lower_name or "landscapetree" in lower_name:
			mesh_instance.hide()
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
			_apply_scanned_ground(ground)
			ground.set_shader_parameter("grass_a", Color("74744a"))
			ground.set_shader_parameter("grass_b", Color("9b895b"))
			ground.set_shader_parameter("earth", Color("8a6b47"))
			mesh_instance.material_override = ground
		elif "vineyardrowsoil" in lower_name:
			var row_ground := ShaderMaterial.new()
			row_ground.shader = GROUND_SHADER
			_apply_scanned_ground(row_ground, 0.70)
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


func _build_terrace() -> void:
	_box(self, "LimestoneViewingTerrace", Vector3(18.4, 0.9, 7.0), Vector3(0, TERRACE_HEIGHT - 0.45, 0.6), _stone)
	_floor_collider(Vector3(18.0, 0.08, 6.2), Vector3(0, TERRACE_HEIGHT - 0.04, 0.6))
	# Quiet brass joints guide the visitor along the four story stations.
	for x: float in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		_box(self, "TerraceJoint", Vector3(0.012, 0.006, 5.8), Vector3(x, TERRACE_HEIGHT + 0.004, 0.6), _gold)
	_box(self, "NorthCoping", Vector3(18.4, 0.10, 0.36), Vector3(0, 0.24, -2.70), _stone)
	for x: float in [-9.0, 9.0]:
		_box(self, "SideCoping", Vector3(0.30, 0.10, 6.4), Vector3(x, 0.24, 0.6), _stone)
	# Low timber rail leaves the view open, with an actual collision boundary.
	for x: float in [-9.0, -7.5, -4.5, -1.5, 1.5, 4.5, 7.5, 9.0]:
		_segment(self, "WeatheredRailPost", Vector3(x, 0.25, -2.55), Vector3(x, 0.94, -2.55), 0.035, _wood)
	for y: float in [0.55, 0.87]:
		_segment(self, "TerraceRail", Vector3(-9.0, y, -2.55), Vector3(9.0, y, -2.55), 0.025, _wood)
	_solid_boundary(Vector3(18.4, 1.1, 0.12), Vector3(0, 0.65, -2.55))
	for x: float in [-9.0, 9.0]:
		_solid_boundary(Vector3(0.12, 1.1, 6.7), Vector3(x, 0.65, 0.6))
	_solid_boundary(Vector3(18.4, 1.1, 0.12), Vector3(0, 0.65, 4.0))
	# A low, tactile orientation table sits behind the first station.
	_box(self, "MapPedestal", Vector3(1.40, 0.66, 0.70), Vector3(-7.65, 0.51, 1.0), _stone)
	_solid_boundary(Vector3(1.40, 0.66, 0.70), Vector3(-7.65, 0.51, 1.0))
	_build_crete_map(Vector3(-7.65, 0.855, 1.0))
	var entry: Node3D = Node3D.new()
	entry.name = "WelcomeMarker"
	entry.position = Vector3(0, 0, 3.85)
	entry.rotation.y = PI
	add_child(entry)
	_box(entry, "WelcomeStone", Vector3(3.35, 0.68, 0.17), Vector3(0, 0.69, 0), _dark)
	_label(entry, "ΔΑΦΝΕΣ · ΚΡΗΤΗ", Vector3(0, 0.81, 0.095), 47, IVORY, 0.0017)
	_label(entry, "Ο ΤΟΠΟΣ ΠΡΙΝ ΑΠΟ ΤΟ ΠΟΤΗΡΙ", Vector3(0, 0.58, 0.096), 24, GOLD, 0.0015)


func _build_tour() -> void:
	var station_data: Array = data.get("stations", [])
	for index: int in range(station_data.size()):
		var item: Dictionary = station_data[index] as Dictionary
		var x: float = -6.0 + 4.0 * index
		var station: Interactable = _make_interactable("terroir_" + str(item["id"]), str(item["title"]), str(item["description"]), Vector3(x, 1.25, -0.85))
		stations[str(item["id"])] = station
		_box(station, "WalnutInterpretationBoard", Vector3(2.35, 0.68, 0.085), Vector3.ZERO, _dark)
		_box(station, "BrassHeading", Vector3(2.18, 0.012, 0.008), Vector3(0, 0.31, 0.048), _gold)
		for dx: float in [-0.93, 0.93]:
			_segment(station, "SlenderLeg", Vector3(dx, -1.07, 0), Vector3(dx, -0.30, 0), 0.026, _gold)
		_label(station, str(item["number"]) + "   /   " + str(item["eyebrow"]), Vector3(0, 0.22, 0.052), 22, GOLD, 0.0019)
		_label(station, str(item["title"]), Vector3(0, 0.055, 0.054), 40, IVORY, 0.0022)
		_label(station, str(item["caption"]), Vector3(0, -0.10, 0.054), 24, Color("bfc6b9"), 0.0019)
		var hint: Label3D = _label(station, "ΕΠΙΛΕΞΕ ΓΙΑ ΝΑ ΑΝΑΚΑΛΥΨΕΙΣ", Vector3(0, -0.25, 0.054), 19, GOLD, 0.0019)
		station.set_meta("visit_label", hint)
		_add_hit_area(station, Vector3(2.35, 0.78, 0.18))
		station.interacted.connect(func(_ob: Interactable) -> void: _visit_station(str(item["id"])))
		var number: Label3D = _label(self, str(item["number"]), Vector3(x, TERRACE_HEIGHT + 0.012, 0.40), 72, Color("7a6542"), 0.0022)
		number.rotation.x = -PI * 0.5
	var exit: Interactable = _make_interactable("terroir_return", "Επιστροφή στη συλλογή", "Συνέχισε από τον τόπο στη ρώγα: Λιάτικο, Κοτσιφάλι και Βιδιανό.", Vector3(7.95, 1.12, 2.7))
	exit.set_meta("navigation_action", true)
	exit.rotation.y = -0.5
	_box(exit, "ReturnPlaque", Vector3(1.4, 0.55, 0.09), Vector3.ZERO, _dark)
	_segment(exit, "ReturnStem", Vector3(0, -0.93, 0), Vector3(0, -0.24, 0), 0.03, _gold)
	_label(exit, "ΕΠΙΣΤΡΟΦΗ", Vector3(0, 0.095, 0.052), 30, GOLD, 0.0017)
	_label(exit, "Στη συλλογή σταφυλιών →", Vector3(0, -0.10, 0.052), 21, IVORY, 0.0017)
	_add_hit_area(exit, Vector3(1.45, 0.60, 0.2))
	exit.interacted.connect(func(_ob: Interactable) -> void: return_to_museum_requested.emit())
	_progress_label = _label(self, "4 ΣΤΑΣΕΙΣ · ΕΞΕΡΕΥΝΗΣΕ ΕΛΕΥΘΕΡΑ", Vector3(0, 0.45, 2.9), 26, Color("695b3e"), 0.0020)
	_progress_label.rotation.x = -PI * 0.5


func _visit_station(station_id: String) -> void:
	if not stations.has(station_id):
		return
	visited_stations[station_id] = true
	var station: Interactable = stations[station_id] as Interactable
	var hint: Label3D = station.get_meta("visit_label") as Label3D
	hint.text = "ΑΝΑΚΑΛΥΦΘΗΚΕ · ΕΠΙΛΕΞΕ ΞΑΝΑ"
	hint.modulate = Color("a6c89c")
	_progress_label.text = "%d / %d ΣΤΑΣΕΙΣ · Ο ΤΟΠΟΣ ΠΡΙΝ ΑΠΟ ΤΟ ΠΟΤΗΡΙ" % [visited_stations.size(), stations.size()]
	station_selected.emit(station_id)


func _build_crete_map(center: Vector3) -> void:
	# Deliberately schematic island outline, labeled as such in the station.
	var outline: PackedVector2Array = PackedVector2Array([
		Vector2(-0.61, -0.08), Vector2(-0.54, -0.18), Vector2(-0.42, -0.14), Vector2(-0.30, -0.19),
		Vector2(-0.18, -0.13), Vector2(-0.02, -0.16), Vector2(0.13, -0.11), Vector2(0.28, -0.10),
		Vector2(0.39, -0.04), Vector2(0.55, -0.06), Vector2(0.63, 0.02), Vector2(0.56, 0.09),
		Vector2(0.39, 0.05), Vector2(0.27, 0.12), Vector2(0.12, 0.10), Vector2(-0.07, 0.12),
		Vector2(-0.24, 0.07), Vector2(-0.42, 0.08), Vector2(-0.56, 0.01)
	])
	var triangulation: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point_index: int in triangulation:
		var point: Vector2 = outline[point_index]
		surface.set_normal(Vector3.UP)
		surface.add_vertex(center + Vector3(point.x, 0.018, point.y))
	var island: MeshInstance3D = MeshInstance3D.new()
	island.name = "CreteSchematicRelief"
	island.mesh = surface.commit()
	var island_material: StandardMaterial3D = _material(Color("597259"), 0.85)
	island_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	island.material_override = island_material
	add_child(island)
	var marker: SphereMesh = SphereMesh.new()
	marker.radius = 0.025
	marker.height = 0.05
	marker.radial_segments = 10
	marker.rings = 5
	var pin: MeshInstance3D = MeshInstance3D.new()
	pin.name = "DafnesMapPin"
	pin.mesh = marker
	pin.position = center + Vector3(0.02, 0.08, 0.0)
	pin.material_override = _gold
	add_child(pin)
	_segment(self, "DafnesPinStem", center + Vector3(0.02, 0.02, 0), pin.position, 0.005, _gold)
	var label: Label3D = _label(self, "ΚΡΗΤΗ · ΣΧΗΜΑΤΙΚΟΣ ΧΑΡΤΗΣ", center + Vector3(0, 0.025, 0.23), 17, Color("3c4537"), 0.00125)
	label.rotation.x = -PI * 0.5


func _build_horizon() -> void:
	for ridge_index: int in range(3):
		var surface: SurfaceTool = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rows: int = 15
		var columns: int = 160
		for row: int in range(rows - 1):
			for column: int in range(columns - 1):
				var a: Vector3 = _ridge_vertex(column, row, ridge_index, columns)
				var b: Vector3 = _ridge_vertex(column + 1, row, ridge_index, columns)
				var c: Vector3 = _ridge_vertex(column, row + 1, ridge_index, columns)
				var d: Vector3 = _ridge_vertex(column + 1, row + 1, ridge_index, columns)
				for vertex: Vector3 in [a, b, c, b, d, c]:
					surface.add_vertex(vertex)
		surface.generate_normals()
		var ridge: MeshInstance3D = MeshInstance3D.new()
		ridge.name = "CretanRidge_%d" % ridge_index
		ridge.mesh = surface.commit()
		var colors: Array[Color] = [Color("777b5e"), Color("8b9584"), Color("a3afaa")]
		var ridge_material: ShaderMaterial = ShaderMaterial.new()
		ridge_material.shader = RIDGE_SHADER
		ridge_material.set_shader_parameter("hillside_color", colors[ridge_index])
		ridge.material_override = ridge_material
		ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ridge)
	# A few distant limestone farm buildings give the vineyard a human scale.
	var village_stone: StandardMaterial3D = _material(Color("c2bda5"), 0.95)
	var terracotta: StandardMaterial3D = _material(Color("88664d"), 0.95)
	for index: int in range(9):
		var x: float = 19.0 + _rng.randf_range(-4.0, 7.0)
		var z: float = -44.0 - _rng.randf_range(0.0, 9.0)
		var y: float = 2.8 + _rng.randf_range(-0.2, 0.7)
		var dimensions: Vector3 = Vector3(_rng.randf_range(0.9, 1.8), _rng.randf_range(0.8, 1.4), _rng.randf_range(1.0, 1.8))
		_box(self, "DistantStoneFarm", dimensions, Vector3(x, y, z), village_stone)
		_box(self, "FarmRoof", Vector3(dimensions.x + 0.15, 0.16, dimensions.z + 0.15), Vector3(x, y + dimensions.y * 0.5, z), terracotta)


func _ridge_vertex(column: int, row: int, layer: int, columns: int) -> Vector3:
	var x: float = -220.0 + 440.0 * float(column) / float(columns - 1)
	var t: float = float(row) / 14.0
	var ridge_height: float = 7.5 + layer * 3.0 + sin(x * 0.047 + layer) * 3.2 + sin(x * 0.117 + layer * 2) * 1.5 + cos(x * 0.29) * 0.5
	var height: float = -3.0 + pow(sin(t * PI), 1.4) * ridge_height
	return Vector3(x, height, -52.0 - layer * 22.0 - t * 33.0)


func _build_dry_stone_details() -> void:
	var stone_mesh: SphereMesh = SphereMesh.new()
	stone_mesh.radius = 0.5
	stone_mesh.height = 1.0
	stone_mesh.radial_segments = 7
	stone_mesh.rings = 3
	var stones: MultiMesh = MultiMesh.new()
	stones.transform_format = MultiMesh.TRANSFORM_3D
	stones.use_colors = true
	stones.mesh = stone_mesh
	stones.instance_count = 195
	var rock_material: StandardMaterial3D = _material(Color("a39577"), 0.96)
	rock_material.vertex_color_use_as_albedo = true
	for index: int in range(stones.instance_count):
		var x: float = -9.3 + fmod(float(index), 65.0) * 0.29 + _rng.randf_range(-0.05, 0.05)
		var y: float = -0.46 + floorf(float(index) / 65.0) * 0.20
		var scale_value: Vector3 = Vector3(_rng.randf_range(0.30, 0.43), _rng.randf_range(0.18, 0.26), _rng.randf_range(0.27, 0.40))
		var basis: Basis = Basis.from_euler(Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf_range(0, TAU), 0)).scaled(scale_value)
		stones.set_instance_transform(index, Transform3D(basis, Vector3(x, y, -2.89)))
		stones.set_instance_color(index, Color.WHITE.darkened(_rng.randf_range(0.0, 0.18)))
	var wall: MultiMeshInstance3D = MultiMeshInstance3D.new()
	wall.name = "HandLaidDryStoneWall"
	wall.multimesh = stones
	wall.material_override = rock_material
	add_child(wall)
	# Silver-green herbs and dry stems, batched into two small draw calls.
	var herb_mesh: SphereMesh = SphereMesh.new()
	herb_mesh.radius = 0.5
	herb_mesh.height = 1.0
	herb_mesh.radial_segments = 8
	herb_mesh.rings = 4
	var herbs: MultiMesh = MultiMesh.new()
	herbs.transform_format = MultiMesh.TRANSFORM_3D
	herbs.use_colors = true
	herbs.mesh = herb_mesh
	herbs.instance_count = 90
	var herb_material: StandardMaterial3D = _material(Color("697353"), 0.95)
	herb_material.vertex_color_use_as_albedo = true
	for index: int in range(herbs.instance_count):
		var side: float = -1.0 if index < 45 else 1.0
		var position_value: Vector3 = Vector3(side * _rng.randf_range(9.6, 14.0), -0.05, _rng.randf_range(-5.0, 4.0))
		var size_value: Vector3 = Vector3(_rng.randf_range(0.22, 0.60), _rng.randf_range(0.25, 0.52), _rng.randf_range(0.23, 0.55))
		herbs.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(size_value), position_value))
		herbs.set_instance_color(index, Color.WHITE.darkened(_rng.randf_range(0.0, 0.3)))
	var herbs_instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	herbs_instance.name = "MediterraneanHerbs"
	herbs_instance.multimesh = herbs
	herbs_instance.material_override = herb_material
	herbs_instance.visibility_range_end = 28.0
	herbs_instance.add_to_group("performance_optional")
	add_child(herbs_instance)
	# The terrace is grounded in an apron of pale, weathered Cretan soil.
	var apron: ShaderMaterial = ShaderMaterial.new()
	apron.shader = GROUND_SHADER
	_apply_scanned_ground(apron)
	apron.set_shader_parameter("grass_a", Color("88825b"))
	apron.set_shader_parameter("grass_b", Color("a3956d"))
	apron.set_shader_parameter("earth", Color("9c805b"))
	_box(self, "VisitorTerraceEarth", Vector3(32, 0.18, 15), Vector3(0, -0.45, 1.8), apron)
	var surround: MeshInstance3D = _box(self, "SurroundingValleySoil", Vector3(480, 0.2, 240), Vector3(0, -3.2, -80), apron)
	surround.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_demonstration_vines() -> void:
	var ids: Array[String] = ["liatiko", "kotsifali", "vidiano"]
	var names: Array[String] = ["ΛΙΑΤΙΚΟ", "ΚΟΤΣΙΦΑΛΙ", "ΒΙΔΙΑΝΟ"]
	for index: int in range(ids.size()):
		var vine: GrapeVineTreeController = VINE_SCENE.instantiate() as GrapeVineTreeController
		vine.name = "DemonstrationVine_" + ids[index]
		vine.grape_variety = ids[index]
		vine.position = Vector3(-4.0 + index * 4.0, -0.2, -4.15)
		vine.scale = Vector3.ONE * 0.68
		vine.visibility_distance = 28.0
		vine.wind_strength_scale = 0.6
		add_child(vine)
		_box(self, "VineSamplePlate", Vector3(0.95, 0.19, 0.04), vine.position + Vector3(0, 0.50, 0.5), _dark)
		_label(self, names[index], vine.position + Vector3(0, 0.50, 0.526), 27, IVORY, 0.0020)


func _make_interactable(id: String, title: String, description: String, position_value: Vector3) -> Interactable:
	var item: Interactable = Interactable.new()
	item.name = id
	item.id = id
	item.title = title
	item.description = description
	item.position = position_value
	item.bypass_guided_lock = true
	item.hover_scale_multiplier = 1.015
	item.type = "plaque"
	add_child(item)
	return item


func _add_hit_area(parent: Node3D, size_value: Vector3) -> void:
	var area: Area3D = Area3D.new()
	area.collision_layer = 1
	area.collision_mask = 0
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size_value
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	area.add_child(collision)
	parent.add_child(area)


func _floor_collider(size_value: Vector3, center: Vector3) -> void:
	var floor_body: StaticBody3D = _solid_boundary(size_value, center)
	floor_body.name = "VineyardTeleportFloor"
	floor_body.collision_layer = 8
	floor_body.add_to_group("vr_teleport_floor")


func _solid_boundary(size_value: Vector3, center: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.position = center
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size_value
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body


func _box(parent: Node3D, name_value: String, size_value: Vector3, center: Vector3, material: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size_value
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = name_value
	instance.mesh = mesh
	instance.position = center
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _segment(parent: Node3D, name_value: String, a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius * 0.92
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 8
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = name_value
	instance.mesh = mesh
	instance.position = (a + b) * 0.5
	instance.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	instance.material_override = material
	parent.add_child(instance)


func _label(parent: Node3D, text_value: String, center: Vector3, font_size_value: int, color: Color, pixel_size_value: float) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = text_value
	label.position = center
	label.font_size = font_size_value
	label.pixel_size = pixel_size_value
	label.modulate = color
	label.outline_size = 0
	label.shaded = false
	label.no_depth_test = false
	label.double_sided = false
	parent.add_child(label)
	return label


func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _apply_scanned_ground(material: ShaderMaterial, blend: float = 0.97) -> void:
	material.set_shader_parameter("terrain_albedo", TERRAIN_ALBEDO)
	material.set_shader_parameter("terrain_arm", TERRAIN_ARM)
	material.set_shader_parameter("terrain_normal", TERRAIN_NORMAL)
	material.set_shader_parameter("use_scanned_surface", true)
	material.set_shader_parameter("scanned_blend", blend)
	material.set_shader_parameter("scanned_scale", 0.18)
