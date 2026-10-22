extends "res://scripts/winery/vineyard_landscape_controller.gd"
class_name CellarTour

const CELLAR_DATA_PATH: String = "res://data/cellar_tour.json"
const OAK_SHADER: Shader = preload("res://assets/shaders/cellar_oak.gdshader")
const JOINERY_SHADER: Shader = preload("res://assets/shaders/cellar_joinery.gdshader")

var _steel: StandardMaterial3D
var _hoop: StandardMaterial3D
var _warm_glow: StandardMaterial3D
var _barrel_mesh: ArrayMesh
var _barrel_hoops: ArrayMesh
var _lights: Array[OmniLight3D] = []
var _joinery: ShaderMaterial


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CELLAR_DATA_PATH))
	if not parsed is Dictionary:
		push_error("[WineVR][Cellar] Invalid tour content")
		return
	data = parsed as Dictionary
	_rng.seed = 270106
	_stone = ShaderMaterial.new()
	_stone.shader = STONE_SHADER
	_stone.set_shader_parameter("stone_color", Color("827b68"))
	_stone.set_shader_parameter("grain_scale", 28.0)
	_dark = _material(Color("232c29"), 0.70)
	_gold = _material(Color("bda571"), 0.34, 0.70)
	_wood = ShaderMaterial.new()
	_wood.shader = OAK_SHADER
	_joinery = ShaderMaterial.new()
	_joinery.shader = JOINERY_SHADER
	_steel = _material(Color("a0aaa9"), 0.28, 0.83)
	_hoop = _material(Color("494f4c"), 0.41, 0.78)
	_warm_glow = _material(Color("ffd99c"), 0.6)
	_warm_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_warm_glow.emission_enabled = true
	_warm_glow.emission = Color("ffcb83")
	_warm_glow.emission_energy_multiplier = 0.8
	_build_cellar_architecture()
	_build_barrel_collection()
	_build_fermenters()
	_build_harvest_table()
	_build_tasting_table()
	_build_cellar_stations()
	_cache_collision_layers(self)
	print("[WineVR][Cellar] Four educational stations in a modeled limestone cellar")


func get_spawn_position() -> Vector3:
	return Vector3(0, 0, 3.2)


func get_bounds_min() -> Vector2:
	return Vector2(-4.1, -6.0)


func get_bounds_max() -> Vector2:
	return Vector2(4.1, 4.2)


func configure_environment(environment: Environment) -> void:
	if environment == null:
		return
	var compatibility: bool = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("151c1b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c6d1d2")
	environment.ambient_light_energy = 0.30 if compatibility else 0.50
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	environment.fog_enabled = false
	environment.volumetric_fog_enabled = false
	environment.glow_enabled = false
	for light: OmniLight3D in _lights:
		light.light_energy = float(light.get_meta("cellar_energy")) * (0.55 if compatibility else 1.0)


func _build_cellar_architecture() -> void:
	var floor_material: ShaderMaterial = _stone.duplicate() as ShaderMaterial
	floor_material.set_shader_parameter("stone_color", Color("77786d"))
	floor_material.set_shader_parameter("tile_scale", 0.72)
	_box(self, "HonedLimestoneFloor", Vector3(9.6, 0.18, 12.0), Vector3(0, -0.09, -1.0), floor_material)
	_floor_collider(Vector3(9.2, 0.08, 11.8), Vector3(0, -0.04, -1.0))
	for x: float in [-4.75, 4.75]:
		_box(self, "LimestoneSideWall", Vector3(0.35, 2.35, 12), Vector3(x, 1.175, -1), _stone)
		_solid_boundary(Vector3(0.35, 4.5, 12), Vector3(x, 2.25, -1))
	for z: float in [-6.95, 4.95]:
		_box(self, "CellarEndWall", Vector3(9.6, 4.8, 0.25), Vector3(0, 2.4, z), _stone)
		_solid_boundary(Vector3(9.6, 4.8, 0.25), Vector3(0, 2.4, z))
	var vault: SurfaceTool = SurfaceTool.new()
	vault.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(48):
		var a: float = PI * float(index) / 48.0
		var b: float = PI * float(index + 1) / 48.0
		var p: Vector3 = Vector3(cos(a) * 4.65, 2.1 + sin(a) * 2.65, 4.9)
		var q: Vector3 = Vector3(cos(b) * 4.65, 2.1 + sin(b) * 2.65, 4.9)
		var r: Vector3 = p + Vector3(0, 0, -11.8)
		var s: Vector3 = q + Vector3(0, 0, -11.8)
		for vertex: Vector3 in [p, r, q, q, r, s]:
			vault.add_vertex(vertex)
	vault.generate_normals()
	var vault_instance: MeshInstance3D = MeshInstance3D.new()
	vault_instance.name = "ContinuousLimestoneVault"
	vault_instance.mesh = vault.commit()
	vault_instance.material_override = _stone
	add_child(vault_instance)
	var rib_material: ShaderMaterial = _stone.duplicate() as ShaderMaterial
	rib_material.set_shader_parameter("stone_color", Color("a29476"))
	for z: float in [4.4, 1.65, -1.1, -3.85, -6.6]:
		for index: int in range(20):
			var a: float = PI * float(index) / 20.0
			var b: float = PI * float(index + 1) / 20.0
			var p: Vector3 = Vector3(cos(a) * 4.59, 2.1 + sin(a) * 2.59, z)
			var q: Vector3 = Vector3(cos(b) * 4.59, 2.1 + sin(b) * 2.59, z)
			var rib: MeshInstance3D = _box(self, "ArchVoussoir", Vector3(0.16, p.distance_to(q) + 0.008, 0.23), (p + q) * 0.5, rib_material)
			rib.quaternion = Quaternion(Vector3.UP, (q - p).normalized())
		for x: float in [-4.56, 4.56]:
			_box(self, "StonePier", Vector3(0.23, 2.13, 0.30), Vector3(x, 1.065, z), rib_material)
			_box(self, "PierFoot", Vector3(0.36, 0.15, 0.42), Vector3(x, 0.075, z), rib_material)
	# Warm sconces and a single pendant make the architecture readable without
	# relying on screen-space effects unavailable on mobile XR and WebGL.
	for z: float in [2.6, -1.8, -5.6]:
		for x: float in [-4.44, 4.44]:
			_box(self, "SconceBackplate", Vector3(0.09, 0.38, 0.16), Vector3(x, 2.0, z), _dark)
			var lamp_x: float = x - signf(x) * 0.13
			_box(self, "SconceGlass", Vector3(0.14, 0.24, 0.14), Vector3(lamp_x, 2.0, z), _warm_glow)
			_add_light(Vector3(lamp_x - signf(x) * 0.20, 2.15, z), 2.2, 4.8, Color("ffcf94"))
	_segment(self, "PendantCable", Vector3(0, 4.65, -4.4), Vector3(0, 3.0, -4.4), 0.008, _dark)
	var shade: CylinderMesh = CylinderMesh.new()
	shade.top_radius = 0.12
	shade.bottom_radius = 0.38
	shade.height = 0.26
	shade.radial_segments = 24
	_mesh(self, "PendantShade", shade, Vector3(0, 3.0, -4.4), _dark)
	var diffuser: CylinderMesh = CylinderMesh.new()
	diffuser.top_radius = 0.34
	diffuser.bottom_radius = 0.34
	diffuser.height = 0.012
	diffuser.radial_segments = 24
	_mesh(self, "PendantDiffuser", diffuser, Vector3(0, 2.86, -4.4), _warm_glow)
	_add_light(Vector3(0, 2.72, -4.4), 3.1, 5.4, Color("ffdfb2"))
	_box(self, "ArrivalTitleBacking", Vector3(5.5, 0.74, 0.09), Vector3(0, 3.0, -6.77), _dark)
	_label(self, "Η ΔΙΑΔΡΟΜΗ ΤΟΥ ΟΙΝΟΥ", Vector3(0, 3.10, -6.71), 57, IVORY, 0.0024)
	_label(self, "ΤΡΥΓΟΣ   /   ΖΥΜΩΣΗ   /   ΩΡΙΜΑΣΗ   /   ΠΑΡΑΤΗΡΗΣΗ", Vector3(0, 2.83, -6.70), 25, GOLD, 0.0022)
	for x: float in [-1.25, 1.25]:
		_box(self, "BrassFloorGuide", Vector3(0.012, 0.004, 10.9), Vector3(x, 0.004, -0.8), _gold)


func _add_light(center: Vector3, energy: float, radius: float, color: Color) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "CellarPracticalLight"
	light.position = center
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.omni_attenuation = 1.35
	light.shadow_enabled = false
	light.set_meta("cellar_energy", energy)
	add_child(light)
	_lights.append(light)


func _build_barrel_collection() -> void:
	_barrel_mesh = _make_barrel_mesh()
	_barrel_hoops = _make_hoop_mesh()
	var barrel_transforms: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		for z: float in [1.9, 0.55, -0.8]:
			for tier: int in range(2):
				var pos: Vector3 = Vector3(side * 3.8, 0.63 + tier * 0.91, z)
				var basis: Basis = Basis(Vector3.UP, PI * 0.5)
				barrel_transforms.append(Transform3D(basis, pos))
				# A recessed end grain disc, bung and branding provide close detail.
				var cap: CylinderMesh = CylinderMesh.new()
				cap.top_radius = 0.345
				cap.bottom_radius = 0.345
				cap.height = 0.035
				cap.radial_segments = 26
				var cap_mesh: MeshInstance3D = _mesh(self, "RecessedBarrelHead", cap, pos + Vector3(-side * 0.578, 0, 0), _joinery)
				cap_mesh.rotation.z = PI * 0.5
				var bung: CylinderMesh = CylinderMesh.new()
				bung.top_radius = 0.029
				bung.bottom_radius = 0.029
				bung.height = 0.018
				bung.radial_segments = 10
				_mesh(self, "OakBung", bung, pos + Vector3(0, 0.423, 0), _gold)
				var end_label: Label3D = _label(self, "GRAPES OF CRETE\nΚΡΗΤΗ", pos + Vector3(-side * 0.603, 0, 0), 26, Color("2b251c"), 0.0016)
				end_label.rotation.y = -side * PI * 0.5
		for z: float in [2.48, 1.12, -0.23, -1.5]:
			_box(self, "BarrelRackUpright", Vector3(0.09, 1.65, 0.07), Vector3(side * 3.8, 0.83, z), _hoop)
		for y: float in [0.14, 1.03]:
			for x: float in [side * 3.38, side * 4.20]:
				_box(self, "BarrelRackRunner", Vector3(0.065, 0.08, 4.05), Vector3(x, y, 0.5), _hoop)
		_solid_boundary(Vector3(1.7, 2.1, 4.4), Vector3(side * 3.8, 1.05, 0.55))
	_multimesh("OakBarrelStaves", _barrel_mesh, barrel_transforms, _wood)
	_multimesh("IronBarrelHoops", _barrel_hoops, barrel_transforms, _hoop)


func _make_barrel_mesh() -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lengths: Array[float] = [-0.6, -0.49, -0.31, 0.0, 0.31, 0.49, 0.6]
	var radii: Array[float] = [0.35, 0.385, 0.415, 0.43, 0.415, 0.385, 0.35]
	for stave: int in range(26):
		var a: float = TAU * float(stave) / 26.0 + 0.004
		var b: float = TAU * float(stave + 1) / 26.0 - 0.004
		for ring: int in range(lengths.size() - 1):
			var points: Array[Vector3] = [Vector3(cos(a) * radii[ring], sin(a) * radii[ring], lengths[ring]), Vector3(cos(b) * radii[ring], sin(b) * radii[ring], lengths[ring]), Vector3(cos(a) * radii[ring + 1], sin(a) * radii[ring + 1], lengths[ring + 1]), Vector3(cos(b) * radii[ring + 1], sin(b) * radii[ring + 1], lengths[ring + 1])]
			var uvs: Array[Vector2] = [Vector2(float(stave) / 26, float(ring) / 6), Vector2(float(stave + 1) / 26, float(ring) / 6), Vector2(float(stave) / 26, float(ring + 1) / 6), Vector2(float(stave + 1) / 26, float(ring + 1) / 6)]
			for index: int in [0, 2, 1, 1, 2, 3]:
				surface.set_uv(uvs[index])
				surface.add_vertex(points[index])
	surface.generate_normals()
	return surface.commit()


func _make_hoop_mesh() -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z: float in [-0.53, -0.38, 0.38, 0.53]:
		var radius: float = 0.377 if absf(z) > 0.5 else 0.411
		for segment: int in range(36):
			var a: float = TAU * float(segment) / 36.0
			var b: float = TAU * float(segment + 1) / 36.0
			var points: Array[Vector3] = [Vector3(cos(a) * radius, sin(a) * radius, z - 0.021), Vector3(cos(b) * radius, sin(b) * radius, z - 0.021), Vector3(cos(a) * radius, sin(a) * radius, z + 0.021), Vector3(cos(b) * radius, sin(b) * radius, z + 0.021)]
			for index: int in [0, 2, 1, 1, 2, 3]:
				surface.add_vertex(points[index])
	surface.generate_normals()
	return surface.commit()


func _build_fermenters() -> void:
	for x: float in [-3.3, 3.3]:
		var tank: CylinderMesh = CylinderMesh.new()
		tank.top_radius = 0.66
		tank.bottom_radius = 0.66
		tank.height = 2.0
		tank.radial_segments = 40
		_mesh(self, "BrushedSteelFermenter", tank, Vector3(x, 1.58, -5.25), _steel)
		var cone: CylinderMesh = CylinderMesh.new()
		cone.top_radius = 0.66
		cone.bottom_radius = 0.12
		cone.height = 0.46
		cone.radial_segments = 40
		_mesh(self, "FermenterCone", cone, Vector3(x, 0.35, -5.25), _steel)
		for dx: float in [-0.49, 0.49]:
			for dz: float in [-0.35, 0.35]:
				_segment(self, "TankLeg", Vector3(x + dx, 0.04, -5.25 + dz), Vector3(x + dx, 0.85, -5.25 + dz), 0.032, _steel)
		for y: float in [0.72, 1.65, 2.50]:
			_torus(self, "TankWeldRing", Vector3(x, y, -5.25), 0.658, 0.671, _steel)
		var lid: SphereMesh = SphereMesh.new()
		lid.radius = 0.66
		lid.height = 1.32
		lid.radial_segments = 32
		lid.rings = 12
		var lid_instance: MeshInstance3D = _mesh(self, "TankDome", lid, Vector3(x, 2.55, -5.25), _steel)
		lid_instance.scale.y = 0.30
		var manway: CylinderMesh = CylinderMesh.new()
		manway.top_radius = 0.22
		manway.bottom_radius = 0.22
		manway.height = 0.06
		manway.radial_segments = 32
		var hatch: MeshInstance3D = _mesh(self, "TankManway", manway, Vector3(x, 1.35, -4.57), _hoop)
		hatch.rotation.x = PI * 0.5
		_segment(self, "ManwayHandle", Vector3(x - 0.12, 1.35, -4.51), Vector3(x + 0.12, 1.35, -4.51), 0.014, _steel)
		_segment(self, "RackingValve", Vector3(x, 0.48, -5.25), Vector3(x, 0.48, -4.38), 0.027, _steel)
		_segment(self, "ValveHandle", Vector3(x - 0.09, 0.52, -4.44), Vector3(x + 0.09, 0.52, -4.44), 0.018, _dark)
		_box(self, "TankSampleBadge", Vector3(0.42, 0.20, 0.025), Vector3(x, 2.10, -4.575), _dark)
		_label(self, "ΕΚΠΑΙΔΕΥΤΙΚΟ\nΜΟΝΤΕΛΟ", Vector3(x, 2.10, -4.55), 17, IVORY, 0.0012)
		_solid_boundary(Vector3(1.5, 2.8, 1.6), Vector3(x, 1.4, -5.25))


func _build_harvest_table() -> void:
	_box(self, "SelectionTableTop", Vector3(1.85, 0.08, 0.85), Vector3(-3.15, 0.94, 3.6), _joinery)
	for x: float in [-3.88, -2.42]:
		for z: float in [3.28, 3.92]:
			_box(self, "HarvestTableLeg", Vector3(0.06, 0.92, 0.06), Vector3(x, 0.46, z), _dark)
	var berry_mesh: SphereMesh = SphereMesh.new()
	berry_mesh.radius = 0.025
	berry_mesh.height = 0.050
	berry_mesh.radial_segments = 10
	berry_mesh.rings = 6
	for index: int in range(3):
		var x: float = -3.70 + index * 0.55
		_box(self, "HarvestTray", Vector3(0.45, 0.035, 0.55), Vector3(x, 1.0, 3.6), _dark)
		var palette: Array[Color] = [Color("58283d"), Color("2e213b"), Color("a2a151")]
		var material: StandardMaterial3D = _material(palette[index], 0.48)
		var transforms: Array[Transform3D] = []
		for berry: int in range(38):
			var row: int = berry / 8
			var pos: Vector3 = Vector3(x + _rng.randf_range(-0.13, 0.13), 1.04 + _rng.randf_range(0, 0.06), 3.40 + row * 0.065 + _rng.randf_range(-0.025, 0.025))
			transforms.append(Transform3D(Basis.IDENTITY, pos))
		_multimesh("HarvestBerrySample", berry_mesh, transforms, material)
	_solid_boundary(Vector3(1.9, 1.0, 0.85), Vector3(-3.15, 0.5, 3.6))


func _build_tasting_table() -> void:
	var top_material: ShaderMaterial = _stone.duplicate() as ShaderMaterial
	top_material.set_shader_parameter("stone_color", Color("c7bda4"))
	_box(self, "TastingCounter", Vector3(3.75, 0.13, 1.0), Vector3(0, 1.02, -5.62), top_material)
	for x: float in [-1.52, 1.52]:
		_box(self, "CounterLeg", Vector3(0.20, 0.96, 0.70), Vector3(x, 0.48, -5.62), _joinery)
	_box(self, "CounterFootRail", Vector3(3.15, 0.035, 0.035), Vector3(0, 0.22, -5.01), _gold)
	var mat_glass: StandardMaterial3D = _material(Color(0.72, 0.82, 0.84, 0.23), 0.10, 0.1)
	mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_glass.metallic_specular = 0.8
	var glass_mesh: ArrayMesh = _make_glass_bowl()
	for index: int in range(3):
		var x: float = -0.85 + 0.85 * index
		var coaster: CylinderMesh = CylinderMesh.new()
		coaster.top_radius = 0.16
		coaster.bottom_radius = 0.16
		coaster.height = 0.008
		coaster.radial_segments = 24
		_mesh(self, "TastingCoaster", coaster, Vector3(x, 1.092, -5.43), _dark)
		var base: CylinderMesh = CylinderMesh.new()
		base.top_radius = 0.079
		base.bottom_radius = 0.085
		base.height = 0.008
		base.radial_segments = 24
		_mesh(self, "GlassFoot", base, Vector3(x, 1.104, -5.43), mat_glass)
		_segment(self, "GlassStem", Vector3(x, 1.11, -5.43), Vector3(x, 1.26, -5.43), 0.007, mat_glass)
		_mesh(self, "TulipWineGlass", glass_mesh, Vector3(x, 1.26, -5.43), mat_glass)
		_torus(self, "GlassRim", Vector3(x, 1.485, -5.43), 0.063, 0.065, mat_glass)
		var wine: CylinderMesh = CylinderMesh.new()
		wine.top_radius = 0.089
		wine.bottom_radius = 0.065
		wine.height = 0.065
		wine.radial_segments = 24
		var colors: Array[Color] = [Color("641b32"), Color("3c132d"), Color("bfa849")]
		_mesh(self, "IllustrativeWine", wine, Vector3(x, 1.318, -5.43), _material(colors[index], 0.21))
		var names: Array[String] = ["ΛΙΑΤΙΚΟ", "ΚΟΤΣΙΦΑΛΙ", "ΒΙΔΙΑΝΟ"]
		var card: Label3D = _label(self, names[index], Vector3(x, 1.099, -5.19), 16, Color("3d3b30"), 0.0011)
		card.rotation.x = -PI * 0.5
	_solid_boundary(Vector3(3.75, 1.1, 1.0), Vector3(0, 0.55, -5.62))


func _make_glass_bowl() -> ArrayMesh:
	var profile: Array[Vector2] = [Vector2(0.014, 0), Vector2(0.061, 0.025), Vector2(0.093, 0.070), Vector2(0.101, 0.115), Vector2(0.092, 0.165), Vector2(0.064, 0.225)]
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring: int in range(profile.size() - 1):
		for index: int in range(32):
			var a: float = TAU * float(index) / 32
			var b: float = TAU * float(index + 1) / 32
			var points: Array[Vector3] = [Vector3(cos(a) * profile[ring].x, profile[ring].y, sin(a) * profile[ring].x), Vector3(cos(b) * profile[ring].x, profile[ring].y, sin(b) * profile[ring].x), Vector3(cos(a) * profile[ring + 1].x, profile[ring + 1].y, sin(a) * profile[ring + 1].x), Vector3(cos(b) * profile[ring + 1].x, profile[ring + 1].y, sin(b) * profile[ring + 1].x)]
			for vertex_index: int in [0, 1, 2, 1, 3, 2]:
				surface.add_vertex(points[vertex_index])
	surface.generate_normals()
	return surface.commit()


func _build_cellar_stations() -> void:
	var positions: Array[Vector3] = [Vector3(-2.10, 1.35, 2.6), Vector3(2.65, 1.43, -3.8), Vector3(-2.55, 1.43, -1.55), Vector3(0, 0.70, -5.03)]
	var angles: Array[float] = [0.35, -0.35, 0.35, 0.0]
	var list: Array = data.get("stations", [])
	for index: int in range(list.size()):
		var entry: Dictionary = list[index] as Dictionary
		var station: Interactable = _make_interactable("cellar_" + str(entry["id"]), str(entry["title"]), str(entry["description"]), positions[index])
		station.rotation.y = angles[index]
		stations[str(entry["id"])] = station
		_box(station, "InterpretationPlaque", Vector3(1.82, 0.59, 0.06), Vector3.ZERO, _dark)
		_box(station, "PlaqueGoldRule", Vector3(1.69, 0.008, 0.006), Vector3(0, 0.265, 0.036), _gold)
		_segment(station, "PlaqueStand", Vector3(0, -positions[index].y, 0), Vector3(0, -0.27, 0), 0.024, _gold)
		_label(station, str(entry["number"]) + "  /  " + str(entry["eyebrow"]), Vector3(0, 0.19, 0.038), 20, GOLD, 0.0017)
		_label(station, str(entry["title"]), Vector3(0, 0.055, 0.04), 36, IVORY, 0.0020)
		_label(station, str(entry["caption"]), Vector3(0, -0.09, 0.04), 21, Color("c1bead"), 0.0017)
		var hint: Label3D = _label(station, "ΕΠΙΛΕΞΕ ΓΙΑ ΝΑ ΕΞΕΡΕΥΝΗΣΕΙΣ", Vector3(0, -0.22, 0.04), 16, GOLD, 0.0017)
		station.set_meta("visit_label", hint)
		_add_hit_area(station, Vector3(1.86, 0.64, 0.15))
		station.interacted.connect(func(_item: Interactable) -> void: _visit_station(str(entry["id"])))
	var exit: Interactable = _make_interactable("cellar_return", "Επιστροφή στη συλλογή", "Επέστρεψε στις ποικιλίες της Κρήτης.", Vector3(2.4, 1.32, 3.9))
	exit.set_meta("navigation_action", true)
	exit.rotation.y = -0.35
	_box(exit, "ReturnPlaque", Vector3(1.65, 0.43, 0.06), Vector3.ZERO, _dark)
	_label(exit, "ΣΤΗ ΣΥΛΛΟΓΗ →", Vector3(0, 0.045, 0.04), 31, GOLD, 0.0020)
	_label(exit, "Λιάτικο · Κοτσιφάλι · Βιδιανό", Vector3(0, -0.095, 0.04), 19, IVORY, 0.0016)
	_segment(exit, "ReturnStand", Vector3(0, -1.32, 0), Vector3(0, -0.2, 0), 0.026, _gold)
	_add_hit_area(exit, Vector3(1.7, 0.48, 0.16))
	exit.interacted.connect(func(_item: Interactable) -> void: return_to_museum_requested.emit())
	_progress_label = _label(self, "4 ΣΤΑΣΕΙΣ · Η ΔΙΑΔΡΟΜΗ ΤΟΥ ΟΙΝΟΥ", Vector3(0, 0.014, 2.2), 28, Color("baa575"), 0.0022)
	_progress_label.rotation.x = -PI * 0.5
	_label(self, "ΕΚΠΑΙΔΕΥΤΙΚΟ ΟΙΝΟΠΟΙΕΙΟ · ΚΑΛΛΙΤΕΧΝΙΚΗ ΑΝΑΠΑΡΑΣΤΑΣΗ", Vector3(0, 2.48, -6.75), 21, Color("b9b09b"), 0.0017)


func _mesh(parent: Node3D, name_value: String, mesh: Mesh, center: Vector3, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = name_value
	instance.mesh = mesh
	instance.position = center
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _multimesh(name_value: String, mesh: Mesh, transforms: Array[Transform3D], material: Material) -> void:
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multi.set_instance_transform(index, transforms[index])
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = name_value
	instance.multimesh = multi
	instance.material_override = material
	add_child(instance)


func _torus(parent: Node3D, name_value: String, center: Vector3, inner_radius: float, outer_radius: float, material: Material) -> void:
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 24
	mesh.ring_segments = 6
	_mesh(parent, name_value, mesh, center, material)
