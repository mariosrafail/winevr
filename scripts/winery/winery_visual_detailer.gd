extends RefCounted
class_name WineryVisualDetailer

var root: Node3D
var environment: WineryEnvironmentApplier
var floor_material: StandardMaterial3D
var wall_material: StandardMaterial3D
var accent_material: StandardMaterial3D


func setup(parent: Node3D, environment_applier: WineryEnvironmentApplier) -> void:
	environment = environment_applier
	root = Node3D.new()
	root.name = "ProceduralVisualDetails"
	root.add_to_group("performance_optional")
	root.add_to_group("ultra_disable")
	parent.add_child(root)


func apply(environment_settings: Dictionary) -> void:
	clear()
	if environment == null:
		return
	var quality: String = _normalize_quality(str(environment_settings.get("visual_quality", "medium")))
	var floor_pattern: String = _normalize_floor_pattern(str(environment_settings.get("floor_pattern", "stone")))
	var wall_pattern: String = _normalize_wall_pattern(str(environment_settings.get("wall_pattern", "blocks")))
	var accent_color: Color = environment.parse_color(environment_settings.get("accent_color", "#D8B86A"), Color(0.85, 0.72, 0.42, 1.0))
	var floor_color: Color = environment.parse_color(environment_settings.get("floor_color", "#51483D"), Color(0.32, 0.28, 0.24, 1.0))
	var wall_color: Color = environment.parse_color(environment_settings.get("wall_color", "#8B8172"), Color(0.55, 0.51, 0.45, 1.0))

	floor_material = _make_material(floor_color.lightened(0.04), 0.94)
	wall_material = _make_material(wall_color.darkened(0.035), 0.96)
	accent_material = _make_material(accent_color.darkened(0.12), 0.8)
	accent_material.emission_enabled = quality == "high"
	accent_material.emission = accent_color
	accent_material.emission_energy_multiplier = 0.18

	if quality != "low":
		_build_floor_pattern(floor_pattern, quality)
	_build_wall_pattern(wall_pattern, quality)
	_build_trim()


func clear() -> void:
	if root == null:
		return
	for child in root.get_children():
		child.free()


func _build_floor_pattern(pattern: String, quality: String) -> void:
	match pattern:
		"tile":
			_build_floor_tiles(quality)
		"plank":
			_build_floor_planks(quality)
		"smooth":
			pass
		_:
			_build_floor_stones(quality)


func _build_wall_pattern(pattern: String, quality: String) -> void:
	match pattern:
		"panels":
			_build_wall_panels(quality)
		"smooth":
			pass
		_:
			_build_wall_blocks(quality)


func _build_floor_tiles(quality: String) -> void:
	var count: int = 6 if quality == "high" else 4
	var tile_size: float = 7.6 / float(count)
	for x in range(count):
		for z in range(count):
			if quality == "medium" and (x + z) % 2 == 1:
				continue
			var tile: MeshInstance3D = _box(Vector3(tile_size - 0.04, 0.012, tile_size - 0.04), floor_material)
			tile.position = Vector3(-3.8 + tile_size * (x + 0.5), 0.112, -3.8 + tile_size * (z + 0.5))
			root.add_child(tile)


func _build_floor_planks(quality: String) -> void:
	var count: int = 9 if quality == "high" else 6
	var plank_width: float = 7.6 / float(count)
	for x in range(count):
		var plank: MeshInstance3D = _box(Vector3(plank_width - 0.035, 0.012, 7.55), floor_material)
		plank.position = Vector3(-3.8 + plank_width * (x + 0.5), 0.112, 0.0)
		root.add_child(plank)


func _build_floor_stones(quality: String) -> void:
	var count: int = 18 if quality == "high" else 10
	for index in range(count):
		var width: float = 0.5 + float(index % 3) * 0.16
		var depth: float = 0.38 + float(index % 4) * 0.11
		var stone: MeshInstance3D = _box(Vector3(width, 0.014, depth), floor_material)
		stone.position = Vector3(-3.2 + float(index % 6) * 1.25, 0.114, -3.05 + float(index / 6) * 1.15)
		root.add_child(stone)


func _build_wall_blocks(quality: String) -> void:
	var rows: int = 3 if quality == "high" else 2
	var columns: int = 7 if quality == "high" else 5
	for row in range(rows):
		for col in range(columns):
			var block: MeshInstance3D = _box(Vector3(0.86, 0.22, 0.035), wall_material)
			block.position = Vector3(-3.0 + col * 1.0 + (0.18 if row % 2 == 1 else 0.0), 0.85 + row * 0.55, -3.785)
			root.add_child(block)


func _build_wall_panels(quality: String) -> void:
	var count: int = 5 if quality == "high" else 3
	for col in range(count):
		var panel: MeshInstance3D = _box(Vector3(0.88, 1.05, 0.035), wall_material)
		panel.position = Vector3(-2.4 + col * 1.2, 1.42, -3.78)
		root.add_child(panel)


func _build_trim() -> void:
	for z in [-3.78, 3.78]:
		var trim: MeshInstance3D = _box(Vector3(7.8, 0.08, 0.08), accent_material)
		trim.position = Vector3(0.0, 0.26, z)
		root.add_child(trim)
	for x in [-3.78, 3.78]:
		var trim: MeshInstance3D = _box(Vector3(0.08, 0.08, 7.8), accent_material)
		trim.position = Vector3(x, 0.26, 0.0)
		root.add_child(trim)


func _box(size: Vector3, material: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.set_surface_override_material(0, material)
	return instance


func _make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _normalize_quality(value: String) -> String:
	if ["low", "medium", "high"].has(value):
		return value
	return "medium"


func _normalize_floor_pattern(value: String) -> String:
	if ["stone", "tile", "plank", "smooth"].has(value):
		return value
	return "stone"


func _normalize_wall_pattern(value: String) -> String:
	if ["blocks", "panels", "smooth"].has(value):
		return value
	return "blocks"
