extends Node3D
class_name GrapeMuseum

signal exhibit_inspected(variety_id: String)

const DATA_PATH: String = "res://data/grape_museum.json"
const STONE_SHADER: Shader = preload("res://assets/shaders/museum_stone.gdshader")
const GOLD: Color = Color("d8bd7b")
const IVORY: Color = Color("f2e9d8")
const MUTED: Color = Color("aaa393")
const MODEL_SCALE: float = 2.5

var architecture: Node3D
var exhibits: Node3D
var data: Dictionary = {}
var exhibit_nodes: Dictionary = {}
var selected_id: String = ""
var controls_enabled: bool = false
var physics: Node3D
var _mat_dark: StandardMaterial3D
var _mat_gold: StandardMaterial3D
var _mat_wood: StandardMaterial3D
var _desktop_hint: Label


func _ready() -> void:
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(DATA_PATH)) != OK or not json.data is Dictionary:
		push_error("[WineVR][Museum] Invalid exhibit data: " + json.get_error_message())
		return
	data = json.data as Dictionary
	_mat_dark = _material(Color("242723"), 0.82)
	_mat_gold = _material(GOLD, 0.35, 0.68)
	_mat_wood = _material(Color("56402b"), 0.87)
	architecture = Node3D.new()
	architecture.name = "GalleryArchitecture"
	add_child(architecture)
	exhibits = Node3D.new()
	exhibits.name = "HangingExhibits"
	add_child(exhibits)
	_build_room()
	_build_suspension_frame()
	var varieties: Array = data.get("varieties", [])
	for index in range(varieties.size()):
		_build_exhibit(varieties[index] as Dictionary, index)
	_build_desktop_hint()
	print("[WineVR][Museum] Loaded %s hanging exhibits; illustrative data=%s" % [exhibit_nodes.size(), data.get("values_are_illustrative", true)])


func _process(delta: float) -> void:
	if _desktop_hint != null:
		_desktop_hint.text = "Αριστερό κλικ: πιάσιμο/σύρσιμο · Δεξί κλικ: περιστροφή · Ροδέλα: zoom · E / Esc: επιστροφή" if is_inspecting() else "WASD κίνηση · Ποντίκι ματιά · E Inspect · Κράτα αριστερό κλικ: πιάσιμο/τράβηγμα · F11 fullscreen · Esc μενού"
		_desktop_hint.visible = controls_enabled and is_visible_in_tree() and not get_viewport().use_xr
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		var width: float = minf(950.0, viewport_size.x - 40.0)
		_desktop_hint.position = Vector2((viewport_size.x - width) * 0.5, viewport_size.y - 52.0)
		_desktop_hint.size = Vector2(width, 48.0)
	if not is_visible_in_tree():
		return


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or not is_visible_in_tree() or selected_id.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT:
			rotate_exhibit(selected_id, -20.0 if event.keycode == KEY_LEFT else 20.0)
			get_viewport().set_input_as_handled()


func configure_environment(environment: Environment) -> void:
	if environment == null:
		return
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("1b211f")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d8dfde")
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = false
	environment.volumetric_fog_enabled = false
	environment.glow_enabled = false


func setup_interaction(winery: WineryInteriorController) -> void:
	physics = (load("res://scripts/winery/museum_physics_controller.gd") as Script).new() as Node3D
	physics.name = "PhysicsInteraction"
	add_child(physics)
	physics.call("setup", self, winery)


func is_inspecting() -> bool:
	return physics != null and not str(physics.get("inspecting_id")).is_empty()


func close_inspection() -> bool:
	if not is_inspecting():
		return false
	selected_id = ""
	return bool(physics.call("close_inspection"))


func inspect_exhibit(variety_id: String) -> void:
	if not exhibit_nodes.has(variety_id) or physics == null:
		return
	if bool(physics.get("_transitioning")):
		return
	selected_id = variety_id
	physics.call("inspect", variety_id)
	(exhibit_nodes[variety_id]["status"] as Label3D).text = "E / Esc επιστροφή · ← → περιστροφή"
	exhibit_inspected.emit(variety_id)
	print("[WineVR][Museum] Inspect: " + variety_id)


func rotate_exhibit(variety_id: String, degrees: float) -> void:
	if not exhibit_nodes.has(variety_id):
		return
	inspect_exhibit(variety_id)
	var body: RigidBody3D = exhibit_nodes[variety_id]["pivot"] as RigidBody3D
	if not body.freeze:
		body.sleeping = false
		body.apply_torque_impulse(Vector3.UP * deg_to_rad(degrees) * 0.055)


func reset_exhibit(variety_id: String) -> void:
	if exhibit_nodes.has(variety_id):
		var body: RigidBody3D = exhibit_nodes[variety_id]["pivot"] as RigidBody3D
		body.freeze = true
		body.angular_velocity = Vector3.ZERO
		body.linear_velocity = Vector3.ZERO
		body.global_basis = (physics.call("camera") as Camera3D).global_basis if is_inspecting() else Basis.IDENTITY
		body.freeze = false


func _build_room() -> void:
	_box(architecture, "LimestoneFloor", Vector3(8.0, 0.16, 8.0), Vector3(0, -0.08, 0), _stone(Color("77756a"), 1.25))
	var wall_material: ShaderMaterial = _stone(Color("4d534b"))
	_box(architecture, "BackWall", Vector3(8.0, 3.45, 0.18), Vector3(0, 1.725, -3.90), wall_material)
	_box(architecture, "LeftWall", Vector3(0.18, 3.45, 8.0), Vector3(-3.90, 1.725, 0), wall_material)
	_box(architecture, "RightWall", Vector3(0.18, 3.45, 8.0), Vector3(3.90, 1.725, 0), wall_material)
	_box(architecture, "FrontWall", Vector3(8.0, 3.45, 0.18), Vector3(0, 1.725, 3.90), wall_material)
	_box(architecture, "Ceiling", Vector3(8.0, 0.12, 8.0), Vector3(0, 3.45, 0), _stone(Color("333a34")))
	for x in [-1.65, 1.65]:
		_box(architecture, "ExhibitAlcove", Vector3(3.0, 2.53, 0.08), Vector3(x, 1.44, -2.72), _mat_dark)
		_box(architecture, "AlcoveGoldHeader", Vector3(3.0, 0.012, 0.018), Vector3(x, 2.71, -2.665), _mat_gold)
		_box(architecture, "AlcoveGoldFooter", Vector3(3.0, 0.012, 0.018), Vector3(x, 0.17, -2.665), _mat_gold)
	for z in [-3.72, 3.72]:
		_box(architecture, "WallSkirting", Vector3(7.6, 0.12, 0.04), Vector3(0, 0.06, z), _mat_dark)
	for x in [-3.72, 3.72]:
		_box(architecture, "WallSkirting", Vector3(0.04, 0.12, 7.5), Vector3(x, 0.06, 0), _mat_dark)
	_box(architecture, "MuseumHeaderPanel", Vector3(6.3, 0.55, 0.07), Vector3(0, 3.04, -2.72), _mat_dark)
	for x in [-2.8, 2.8]:
		_segment(architecture, "HeaderWallFixing", Vector3(x, 3.04, -3.8), Vector3(x, 3.04, -2.75), 0.012, _mat_dark)
	var header: Label3D = _label(architecture, "ΟΙ ΠΟΙΚΙΛΙΕΣ ΤΗΣ ΚΡΗΤΗΣ", Vector3(0, 3.12, -2.675), 58, IVORY)
	header.pixel_size = 0.0034
	var subtitle: Label3D = _label(architecture, "ΣΥΛΛΟΓΗ 01   /   ΤΟ ΣΤΑΦΥΛΙ ΑΠΟ ΚΟΝΤΑ", Vector3(0, 2.91, -2.675), 30, GOLD)
	subtitle.pixel_size = 0.0022
	_label(architecture, "ΠΕΡΠΑΤΗΣΕ · ΠΑΡΑΤΗΡΗΣΕ · ΣΥΓΚΡΙΝΕ", Vector3(0, 0.20, -2.69), 21, MUTED)
	for x in [-1.65, 1.65]:
		_box(architecture, "SuspensionCeilingFixing", Vector3(0.11, 0.035, 0.11), Vector3(x, 3.37, -1.70), _mat_gold)
		_segment(architecture, "CeilingSuspension", Vector3(x, 3.36, -1.70), Vector3(x, 2.48, -1.70), 0.004, _mat_gold)
		_spot(architecture, Vector3(x - 0.65, 3.05, -0.75), Vector3(x, 1.92, -1.7), 2.8, Color("fff1dd"), true)
		_spot(architecture, Vector3(x + 0.65, 2.88, -2.4), Vector3(x, 1.85, -1.7), 1.8, Color("c6d9e8"), false)
	var fill: OmniLight3D = OmniLight3D.new()
	fill.name = "GallerySoftFill"
	fill.position = Vector3(0, 2.8, 1.0)
	fill.light_color = Color("eef3f4")
	fill.light_energy = 1.2
	fill.omni_range = 7.0
	architecture.add_child(fill)
	# Dedicated floor layer matches the existing XR teleport controller.
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "MuseumTeleportFloor"
	body.collision_layer = 8
	body.collision_mask = 0
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(7.4, 0.10, 7.4)
	collision.shape = box
	collision.position.y = -0.05
	body.add_child(collision)
	architecture.add_child(body)


func _build_suspension_frame() -> void:
	# The rail also has its own feet, so it can be reused outside this virtual room.
	_segment(exhibits, "WoodenVineRail", Vector3(-3.04, 2.45, -1.7), Vector3(3.04, 2.45, -1.7), 0.055, _mat_wood)
	for x in [-3.0, 3.0]:
		_segment(exhibits, "RackUpright", Vector3(x, 0.08, -1.7), Vector3(x, 2.45, -1.7), 0.022, _mat_dark)
		_box(exhibits, "RackFoot", Vector3(0.20, 0.035, 0.50), Vector3(x, 0.02, -1.7), _mat_dark)


func _build_exhibit(variety: Dictionary, index: int) -> void:
	var id: String = str(variety.get("id", ""))
	var x: float = -1.65 if index == 0 else 1.65
	var anchor: Vector3 = Vector3(x, 2.28, -1.70)
	_segment(exhibits, "VineAttachment_" + id, Vector3(x, 2.45, -1.70), anchor, 0.008, _mat_wood)
	var wrap: TorusMesh = TorusMesh.new()
	wrap.inner_radius = 0.057
	wrap.outer_radius = 0.062
	wrap.rings = 16
	wrap.ring_segments = 10
	var loop: MeshInstance3D = MeshInstance3D.new()
	loop.name = "SuspensionLoop_" + id
	loop.mesh = wrap
	loop.rotation.z = PI * 0.5
	loop.position = Vector3(x, 2.45, -1.70)
	loop.material_override = _mat_gold
	exhibits.add_child(loop)
	var interactable: Interactable = _interactable(exhibits, "museum_" + id, str(variety.get("name", id)), str(variety.get("description", "")))
	interactable.set_meta("museum_exhibit", id)
	interactable.interacted.connect(func(_item: Interactable) -> void: inspect_exhibit(id))
	var pivot: RigidBody3D = RigidBody3D.new()
	pivot.name = "SuspensionPivot"
	pivot.mass = 0.45
	pivot.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	pivot.center_of_mass = Vector3(0, -0.31, 0)
	pivot.collision_layer = 4
	pivot.collision_mask = 22
	pivot.linear_damp = 0.8
	pivot.angular_damp = 1.2
	pivot.continuous_cd = true
	pivot.position = anchor
	interactable.add_child(pivot)
	var turntable: Node3D = Node3D.new()
	turntable.name = "InspectionRotation"
	pivot.add_child(turntable)
	var packed: PackedScene = load(str(variety.get("model", ""))) as PackedScene
	if packed == null:
		push_error("[WineVR][Museum] Missing model: " + id)
		return
	var model: Node3D = packed.instantiate() as Node3D
	model.name = "AuthoredBunch"
	model.scale = Vector3.ONE * MODEL_SCALE
	turntable.add_child(model)
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = child as MeshInstance3D
		for surface in range(instance.mesh.get_surface_count()):
			var original: StandardMaterial3D = instance.get_active_material(surface) as StandardMaterial3D
			if original != null and "baked skin" in original.resource_name:
				var skin: StandardMaterial3D = original.duplicate() as StandardMaterial3D
				skin.metallic_specular = 0.24
				skin.cull_mode = BaseMaterial3D.CULL_BACK
				instance.set_surface_override_material(surface, skin)
	var physical_shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.115
	capsule.height = 0.64 if id == "liatiko" else 0.56
	physical_shape.shape = capsule
	physical_shape.position = Vector3(0, -0.36, 0)
	pivot.add_child(physical_shape)
	_collision(pivot, Vector3(0, -0.34, 0), Vector3(0.47, 0.85, 0.44))
	var fixed_anchor: StaticBody3D = StaticBody3D.new()
	fixed_anchor.name = "FixedStem_" + id
	fixed_anchor.position = anchor
	fixed_anchor.collision_layer = 0
	fixed_anchor.collision_mask = 0
	exhibits.add_child(fixed_anchor)
	_box(exhibits, "StonePlinth_" + id, Vector3(0.63, 0.78, 0.63), Vector3(x, 0.39, -1.7), _stone(Color("373d37")))
	_box(exhibits, "PlinthInlay_" + id, Vector3(0.635, 0.008, 0.635), Vector3(x, 0.76, -1.7), _mat_gold)
	_label(exhibits, str(variety.get("number", "")) + "   /   " + str(variety.get("latin_name", "")), Vector3(x, 0.52, -1.375), 24, GOLD)
	var panel: Node3D = _build_profile_panel(variety, x + 1.0)
	exhibit_nodes[id] = {"pivot": pivot, "turntable": turntable, "status": panel.get_node("Status"), "panel": panel, "home": pivot.global_transform, "anchor": fixed_anchor, "joint": null}
	panel.visible = false
	for collider in panel.find_children("*", "CollisionObject3D", true, false):
		(collider as CollisionObject3D).collision_layer = 0
	_label(exhibits, str(variety.get("name", id)), Vector3(x, 1.25, -1.70), 34, IVORY)


func _build_profile_panel(variety: Dictionary, x: float) -> Node3D:
	var id: String = str(variety.get("id", ""))
	var panel: Interactable = _interactable(exhibits, "museum_" + id + "_profile", str(variety.get("name", "")) + " · Προφίλ", str(data.get("scale_note", "")))
	panel.position = Vector3(x, 1.58, -1.72)
	panel.set_meta("museum_exhibit", id)
	panel.interacted.connect(func(_item: Interactable) -> void: inspect_exhibit(id))
	_box(panel, "PanelBacking", Vector3(1.02, 1.36, 0.045), Vector3.ZERO, _mat_dark)
	_box(panel, "TopRule", Vector3(0.90, 0.009, 0.006), Vector3(0, 0.615, 0.027), _mat_gold)
	_label(panel, str(variety.get("name", "")), Vector3(-0.44, 0.49, 0.030), 44, IVORY, true)
	_label(panel, str(variety.get("latin_name", "")) + "   /   ΕΡΥΘΡΗ ΠΟΙΚΙΛΙΑ", Vector3(-0.44, 0.385, 0.030), 16, GOLD, true)
	var metrics: Array = data.get("metrics", [])
	var values: Dictionary = variety.get("metrics", {})
	for index in range(metrics.size()):
		var metric: Dictionary = metrics[index] as Dictionary
		var value: float = clampf(float(values.get(str(metric.get("id", "")), 0.0)), 0.0, 100.0)
		var y: float = 0.22 - float(index) * 0.155
		_label(panel, str(metric.get("label", "")), Vector3(-0.44, y + 0.037, 0.032), 22, IVORY, true)
		_label(panel, "%d%%" % roundi(value), Vector3(0.40, y + 0.037, 0.032), 22, Color(str(metric.get("color", "#DBBF78"))), false, true)
		_box(panel, "BarTrack_" + str(index), Vector3(0.88, 0.026, 0.006), Vector3(0, y - 0.020, 0.030), _material(Color("454b44"), 1.0, 0.0, true))
		var width: float = 0.88 * value / 100.0
		_box(panel, "BarValue_" + str(index), Vector3(maxf(0.001, width), 0.026, 0.008), Vector3(-0.44 + width * 0.5, y - 0.020, 0.036), _material(Color(str(metric.get("color", "#DBBF78"))), 1.0, 0.0, true))
	_label(panel, "ΕΝΔΕΙΚΤΙΚΟ ΠΡΟΦΙΛ · ΚΛΙΜΑΚΑ 0–100\nΌχι εργαστηριακή ανάλυση ή % περιεκτικότητας", Vector3(-0.44, -0.425, 0.032), 14, MUTED, true)
	var status: Label3D = _label(panel, "Στόχευσε το τσαμπί · E για επιθεώρηση", Vector3(0, -0.59, 0.033), 16, MUTED)
	status.name = "Status"
	# Controller-ray friendly physical buttons; they also work with the desktop E key.
	for index in range(3):
		var action: Interactable = _interactable(panel, "museum_" + id + "_turn_" + str(index), ["Περιστροφή αριστερά", "Επαναφορά", "Περιστροφή δεξιά"][index], "")
		action.set_meta("museum_action", true)
		action.position = Vector3(-0.28 + float(index) * 0.28, -0.80, 0.0)
		_box(action, "Button", Vector3(0.24, 0.11, 0.045), Vector3.ZERO, _mat_dark)
		_label(action, ["←", "0°", "→"][index], Vector3(0, 0, 0.028), 28, GOLD)
		_collision(action, Vector3.ZERO, Vector3(0.25, 0.12, 0.08))
		if index == 1:
			action.interacted.connect(func(_item: Interactable) -> void: reset_exhibit(id))
		else:
			var degrees: float = -20.0 if index == 0 else 20.0
			action.interacted.connect(func(_item: Interactable) -> void: rotate_exhibit(id, degrees))
	_collision(panel, Vector3.ZERO, Vector3(1.02, 1.36, 0.07))
	return panel


func _interactable(parent: Node3D, id: String, title: String, description: String) -> Interactable:
	var ob: Interactable = Interactable.new()
	ob.name = id
	ob.id = id
	ob.title = title
	ob.description = description
	ob.bypass_guided_lock = true
	ob.hover_scale_multiplier = 1.0
	ob.glow_on_hover = false
	parent.add_child(ob)
	return ob


func _build_desktop_hint() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "MuseumDesktopHint"
	layer.layer = 5
	add_child(layer)
	_desktop_hint = Label.new()
	_desktop_hint.text = "WASD κίνηση · E Inspect/επιστροφή · Αριστερό κλικ: πιάσιμο · Δεξί κλικ: περιστροφή · F11 fullscreen · Esc μενού"
	_desktop_hint.add_theme_font_size_override("font_size", 15)
	_desktop_hint.add_theme_color_override("font_color", IVORY)
	_desktop_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_desktop_hint.add_theme_constant_override("shadow_outline_size", 4)
	_desktop_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desktop_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desktop_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desktop_hint.visible = false
	layer.add_child(_desktop_hint)


func _collision(parent: Node3D, center: Vector3, size: Vector3) -> void:
	var area: Area3D = Area3D.new()
	area.collision_layer = 1
	area.collision_mask = 0
	area.position = center
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	area.add_child(collision)
	parent.add_child(area)


func _box(parent: Node3D, name: String, size: Vector3, center: Vector3, material: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var ob: MeshInstance3D = MeshInstance3D.new()
	ob.name = name
	ob.mesh = mesh
	ob.position = center
	ob.material_override = material
	parent.add_child(ob)
	if name.ends_with("Wall") or name.begins_with("StonePlinth_"):
		var body: StaticBody3D = StaticBody3D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = size
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		ob.add_child(body)
	return ob


func _segment(parent: Node3D, name: String, a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius * 0.92
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 16
	var ob: MeshInstance3D = MeshInstance3D.new()
	ob.name = name
	ob.mesh = mesh
	ob.position = (a + b) * 0.5
	ob.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	ob.material_override = material
	parent.add_child(ob)


func _label(parent: Node3D, text: String, center: Vector3, size: int, color: Color, left: bool = false, right: bool = false) -> Label3D:
	var ob: Label3D = Label3D.new()
	ob.text = text
	ob.position = center
	ob.font_size = size
	ob.pixel_size = 0.0014
	ob.modulate = color
	ob.outline_size = 0
	ob.shaded = false
	ob.no_depth_test = false
	ob.double_sided = true
	ob.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else (HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_CENTER)
	parent.add_child(ob)
	return ob


func _material(color: Color, roughness: float, metallic: float = 0.0, unshaded: bool = false) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


func _stone(color: Color, tiles: float = 0.0) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = STONE_SHADER
	mat.set_shader_parameter("stone_color", color)
	mat.set_shader_parameter("tile_scale", tiles)
	return mat


func _spot(parent: Node3D, center: Vector3, target: Vector3, energy: float, color: Color, shadows: bool) -> void:
	var light: SpotLight3D = SpotLight3D.new()
	light.name = "MuseumSpot"
	light.position = center
	light.light_color = color
	light.light_energy = energy
	light.spot_range = 4.0
	light.spot_angle = 44.0
	light.spot_attenuation = 1.25
	light.shadow_enabled = shadows
	parent.add_child(light)
	light.look_at(target, Vector3.UP)
