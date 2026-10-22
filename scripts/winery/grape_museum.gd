extends Node3D
class_name GrapeMuseum

signal exhibit_inspected(variety_id: String)

const DATA_PATH: String = "res://data/grape_museum.json"
const STONE_SHADER: Shader = preload("res://assets/shaders/museum_stone.gdshader")
const GOLD: Color = Color("d8bd7b")
const IVORY: Color = Color("f2e9d8")
const MUTED: Color = Color("aaa393")
const MODEL_SCALE: float = 2.5
const VIDIANO_BUILDER: Script = preload("res://scripts/winery/vidiano_bunch_builder.gd")
const BERRY_ANATOMY: Script = preload("res://scripts/winery/berry_anatomy.gd")
const RED_SKIN_SHADER: Shader = preload("res://assets/shaders/red_grape_skin.gdshader")
const BERRY_PHYSICS: Script = preload("res://scripts/winery/berry_physics.gd")

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
var _passthrough_mode: bool = false


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
	visibility_changed.connect(func() -> void:
		if _desktop_hint != null and not is_visible_in_tree():
			_desktop_hint.visible = false
		_sync_anatomy_visibility()
	)
	print("[WineVR][Museum] Loaded %s hanging exhibits; illustrative data=%s" % [exhibit_nodes.size(), data.get("values_are_illustrative", true)])


func _process(delta: float) -> void:
	_sync_anatomy_visibility()
	if _desktop_hint != null:
		_desktop_hint.text = "Κλικ + τράβηγμα: κόψε μία ρώγα · Shift + κλικ: τσαμπί · T: επαναφορά ρωγών · E / Esc: επιστροφή" if is_inspecting() else "WASD κίνηση · E: εξέταση · Κλικ + τράβηγμα: κόψε ρώγα · Shift + κλικ: τσαμπί · T: επαναφορά · Esc μενού"
		if physics != null and is_instance_valid(physics.get("_loose_berry")):
			_desktop_hint.text = "Κράτα αριστερό: κράτημα ρώγας · Δεξί + σύρσιμο: περιστροφή · Ροδέλα: κοντά / μακριά · T: επαναφορά"
		_desktop_hint.visible = controls_enabled and is_visible_in_tree() and not get_viewport().use_xr and not DisplayServer.is_touchscreen_available() and not OS.has_feature("mobile") and not "--touch-ui" in OS.get_cmdline_user_args()
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
		elif event.keycode == KEY_C and is_inspecting():
			var panel: Node3D = exhibit_nodes[selected_id]["panel"] as Node3D
			set_profile_page(selected_id, (int(panel.get_meta("profile_page", 0)) + 1) % int(panel.get_meta("page_count", 4)))
			get_viewport().set_input_as_handled()


func set_passthrough_mode(enabled: bool) -> void:
	_passthrough_mode = enabled
	if architecture == null or exhibits == null:
		return
	architecture.visible = not enabled
	for child in exhibits.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = not enabled
	# Invisible room solids must not remain physical obstacles in passthrough.
	for root in [architecture, exhibits]:
		for collider in root.find_children("*", "StaticBody3D", true, false):
			var body: StaticBody3D = collider as StaticBody3D
			if not body.has_meta("museum_original_layer"):
				body.set_meta("museum_original_layer", body.collision_layer)
			body.collision_layer = 0 if enabled else int(body.get_meta("museum_original_layer"))


func _exhibit_x(index: int) -> float:
	var count: int = (data.get("varieties", []) as Array).size()
	if count <= 1:
		return 0.0
	var span: float = 1.65 if count == 2 else 2.20
	return lerpf(-span, span, float(index) / float(count - 1))


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
	var closed: bool = bool(physics.call("close_inspection"))
	_sync_anatomy_visibility()
	return closed


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
	if bool(physics.get("room_demo")):
		physics.call("demo_rotate", degrees)
		return
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
	var count: int = (data.get("varieties", []) as Array).size()
	var alcove_width: float = 3.0 if count <= 2 else 2.04
	for index in range(count):
		var x: float = _exhibit_x(index)
		_box(architecture, "ExhibitAlcove", Vector3(alcove_width, 2.53, 0.08), Vector3(x, 1.44, -2.72), _mat_dark)
		_box(architecture, "AlcoveGoldHeader", Vector3(alcove_width, 0.012, 0.018), Vector3(x, 2.71, -2.665), _mat_gold)
		_box(architecture, "AlcoveGoldFooter", Vector3(alcove_width, 0.012, 0.018), Vector3(x, 0.17, -2.665), _mat_gold)
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
	for index in range(count):
		var x: float = _exhibit_x(index)
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
	var x: float = _exhibit_x(index)
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
	var model: Node3D
	if str(variety.get("generator", "")) == "vidiano":
		model = VIDIANO_BUILDER.build()
	else:
		var packed: PackedScene = load(str(variety.get("model", ""))) as PackedScene
		if packed == null:
			push_error("[WineVR][Museum] Missing model: " + id)
			return
		model = packed.instantiate() as Node3D
		model.name = "AuthoredBunch"
		model.scale = Vector3.ONE * MODEL_SCALE
	turntable.add_child(model)
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = child as MeshInstance3D
		for surface in range(instance.mesh.get_surface_count()):
			var original: StandardMaterial3D = instance.get_active_material(surface) as StandardMaterial3D
			if original != null and "baked skin" in original.resource_name:
				var skin: ShaderMaterial = ShaderMaterial.new()
				skin.shader = RED_SKIN_SHADER
				# The spring rig identifies these original fruit surfaces by name.
				skin.resource_name = original.resource_name + " | natural skin"
				skin.set_shader_parameter("skin_albedo", load("res://assets/textures/grape_museum/" + id + "_skin_albedo.png"))
				skin.set_shader_parameter("texture_offset", Vector2(fposmod(float(surface) * 0.6180339, 1.0), fposmod(float(surface) * 0.4142136, 1.0)))
				skin.set_shader_parameter("skin_base", Vector3(0.12, 0.065, 0.09) if id == "liatiko" else Vector3(0.065, 0.055, 0.09))
				var shade: float = 0.94 + float(surface % 6) * 0.022
				skin.set_shader_parameter("skin_tint", Vector3(shade * (1.02 if id == "liatiko" else 0.98), shade, shade * (0.98 if id == "liatiko" else 1.03)))
				instance.set_surface_override_material(surface, skin)
	var berry_physics: Node3D = BERRY_PHYSICS.new()
	berry_physics.name = "BerryPhysics"
	pivot.add_child(berry_physics)
	berry_physics.setup(pivot, model)
	var fruit_material: PhysicsMaterial = PhysicsMaterial.new()
	fruit_material.friction = 0.65
	fruit_material.bounce = 0.04
	pivot.physics_material_override = fruit_material
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
	_label(exhibits, str(variety.get("origin_note", "ΚΡΗΤΗ")), Vector3(x, 1.13, -1.70), 14, GOLD)


func _build_profile_panel(variety: Dictionary, x: float) -> Node3D:
	var id: String = str(variety.get("id", ""))
	var room_demo: bool = get_parent().get_meta("room_demo", false)
	var panel: Interactable = _interactable(exhibits, "museum_" + id + "_profile", str(variety.get("name", "")) + " · Προφίλ", str(data.get("scale_note", "")))
	panel.position = Vector3(x, 1.58, -1.72)
	panel.set_meta("museum_exhibit", id)
	panel.interacted.connect(func(_item: Interactable) -> void: inspect_exhibit(id))
	_box(panel, "PanelBacking", Vector3(1.02, 1.36, 0.045), Vector3.ZERO, _material(Color("202723"), 1.0, 0.0, true) if room_demo else _mat_dark)
	_box(panel, "TopRule", Vector3(0.90, 0.009, 0.006), Vector3(0, 0.615, 0.027), _mat_gold)
	_label(panel, str(variety.get("name", "")), Vector3(-0.44, 0.51, 0.030), 44, IVORY, true)
	_label(panel, str(variety.get("latin_name", "")) + "   /   " + str(variety.get("color_type", "")), Vector3(-0.44, 0.42, 0.030), 16, GOLD, true)
	var profile: Node3D = Node3D.new()
	profile.name = "ProfilePage"
	panel.add_child(profile)
	panel.set_meta("profile_page", 0)
	var metrics: Array = data.get("metrics", [])
	var values: Dictionary = variety.get("metrics", {})
	for index in range(metrics.size()):
		var metric: Dictionary = metrics[index] as Dictionary
		var value: float = clampf(float(values.get(str(metric.get("id", "")), 0.0)), 0.0, 100.0)
		var y: float = 0.16 - float(index) * 0.125
		_label(profile, str(metric.get("label", "")), Vector3(-0.44, y + 0.037, 0.032), 22, IVORY, true)
		var score: Label3D = _label(profile, "%d / 100" % roundi(value), Vector3(0.43, y + 0.037, 0.032), 18, Color(str(metric.get("color", "#DBBF78"))), false, true)
		score.name = "Score_" + str(metric.get("id", ""))
		_box(profile, "BarTrack_" + str(index), Vector3(0.88, 0.026, 0.006), Vector3(0, y - 0.020, 0.030), _material(Color("454b44"), 1.0, 0.0, true))
		var width: float = 0.88 * value / 100.0
		_box(profile, "BarValue_" + str(index), Vector3(maxf(0.001, width), 0.026, 0.008), Vector3(-0.44 + width * 0.5, y - 0.020, 0.036), _material(Color(str(metric.get("color", "#DBBF78"))), 1.0, 0.0, true))
	_label(profile, "ΕΝΔΕΙΚΤΙΚΗ ΣΥΓΚΡΙΣΗ · ΚΛΙΜΑΚΑ 0–100\nΌχι μέτρηση ή ποσοστό περιεκτικότητας", Vector3(-0.44, -0.465, 0.032), 15, MUTED, true)
	_build_learning_pages(panel, variety)
	var page_count: int = 3 if get_parent().get_meta("room_demo", false) else 4
	panel.set_meta("page_count", page_count)
	if page_count == 4:
		var anatomy: Node3D = BERRY_ANATOMY.new() as Node3D
		panel.add_child(anatomy)
		anatomy.call("build", variety)
	var tab_width: float = 0.92 / float(page_count)
	for index in range(page_count):
		var tab: Interactable = _interactable(panel, "museum_" + id + "_page_" + str(index), ["Συγκριτικό προφίλ", "Μέσα στη ρώγα", "Ωρίμανση και προέλευση", "Τρισδιάστατη τομή ρώγας"][index], "")
		tab.set_meta("museum_action", true)
		tab.position = Vector3(-0.46 + (float(index) + 0.5) * tab_width, 0.31, 0.045)
		_box(tab, "TabBacking", Vector3(tab_width - 0.015, 0.10 if room_demo else 0.08, 0.022), Vector3.ZERO, _material(Color("303b33") if room_demo else Color("394039"), 0.8, 0.0, room_demo))
		var tab_label: Label3D = _label(tab, ["ΠΡΟΦΙΛ", "Η ΡΩΓΑ", "ΩΡΙΜΑΝΣΗ", "ΡΩΓΑ 3D"][index], Vector3(0, 0, 0.014), 21 if room_demo else 13, GOLD if index == 0 else MUTED)
		tab_label.name = "TabLabel"
		if room_demo:
			_box(tab, "ActiveRule", Vector3(tab_width - 0.04, 0.006, 0.006), Vector3(0, -0.047, 0.016), _material(GOLD, 1.0, 0.0, true))
			style_demo_button(tab, false, index == 0)
		_collision(tab, Vector3.ZERO, Vector3(tab_width - 0.01, 0.09, 0.05))
		var page_index: int = index
		tab.interacted.connect(func(_item: Interactable) -> void: set_profile_page(id, page_index))
	var status: Label3D = _label(panel, "Στόχευσε το τσαμπί · E για επιθεώρηση", Vector3(0, -0.59, 0.033), 16, MUTED)
	status.name = "Status"
	if room_demo:
		status.hide()
		var back: Interactable = _interactable(panel, "museum_" + id + "_close", "Επιστροφή στην αίθουσα", "")
		back.set_meta("museum_action", true)
		back.position = Vector3(0, -0.59, 0.045)
		_box(back, "TabBacking", Vector3(0.90, 0.10, 0.022), Vector3.ZERO, _material(Color("303b33"), 1.0, 0.0, true))
		var back_label: Label3D = _label(back, "ΕΠΙΣΤΡΟΦΗ   ·   E / Esc", Vector3(0, 0, 0.014), 20, IVORY)
		back_label.name = "TabLabel"
		_collision(back, Vector3.ZERO, Vector3(0.90, 0.10, 0.05))
		back.interacted.connect(func(_item: Interactable) -> void: close_inspection())
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
	if room_demo:
		for node in panel.find_children("*", "Label3D", true, false):
			var label: Label3D = node as Label3D
			var text_factor: float = 1.40
			if label.get_parent().name in ["BerryPage", "RipeningPage"]:
				text_factor = 1.55
			elif label.font_size >= 40:
				text_factor = 1.10
			elif label.name == "TabLabel":
				text_factor = 1.32
			label.font_size = roundi(label.font_size * text_factor)
	return panel


func _build_learning_pages(panel: Node3D, variety: Dictionary) -> void:
	var berry: Node3D = Node3D.new()
	berry.name = "BerryPage"
	panel.add_child(berry)
	var cards: Array = data.get("learning_cards", [])
	for index in range(cards.size()):
		var card: Dictionary = cards[index] as Dictionary
		var y: float = 0.17 - float(index) * 0.21
		_label(berry, str(card.get("title", "")), Vector3(-0.44, y, 0.032), 20, GOLD, true)
		_label(berry, str(card.get("text", "")), Vector3(-0.44, y - 0.085, 0.032), 17, IVORY, true)
	_label(berry, "Η ολική οξύτητα μετριέται σε g/L · δεν είναι pH.\nΗ πικράδα αξιολογείται αισθητηριακά.", Vector3(-0.44, -0.485, 0.032), 15, MUTED, true)
	berry.visible = false
	var ripening: Node3D = Node3D.new()
	ripening.name = "RipeningPage"
	panel.add_child(ripening)
	_label(ripening, "ΠΟΙΚΙΛΙΑ ΚΑΙ ΤΟΠΟΣ", Vector3(-0.44, 0.18, 0.032), 20, GOLD, true)
	_label(ripening, str(variety.get("identity", "")), Vector3(-0.44, 0.075, 0.032), 18, IVORY, true)
	_label(ripening, "ΠΟΤΕ ΩΡΙΜΑΖΕΙ;", Vector3(-0.44, -0.10, 0.032), 20, GOLD, true)
	_label(ripening, str(variety.get("ripening_note", "")), Vector3(-0.44, -0.215, 0.032), 18, IVORY, true)
	_label(ripening, "Αμπελώνας, χρονιά και οινοποίηση αλλάζουν\nτο αποτέλεσμα. Δεν μετράμε το εικονικό τσαμπί.", Vector3(-0.44, -0.385, 0.032), 16, MUTED, true)
	var source_text: String = "Πηγές: Wines of Greece · AWRI" if str(variety.get("id", "")) == "liatiko" else "Πηγές: Plants 11 (2022), 3547 · AWRI"
	if str(variety.get("id", "")) == "vidiano":
		source_text = "Πηγές: Wines of Crete · Plants 11 (2022), 3547"
	_label(ripening, source_text, Vector3(-0.44, -0.50, 0.032), 12, GOLD, true)
	ripening.visible = false


func set_profile_page(variety_id: String, page_index: int) -> void:
	if not exhibit_nodes.has(variety_id):
		return
	var panel: Node3D = exhibit_nodes[variety_id]["panel"] as Node3D
	var page_count: int = int(panel.get_meta("page_count", 4))
	var selected: int = clampi(page_index, 0, page_count - 1)
	var page_names: Array[String] = ["ProfilePage", "BerryPage", "RipeningPage", "AnatomyPage"]
	for index in range(page_count):
		(panel.get_node(page_names[index]) as Node3D).visible = index == selected
		var tab_label: Label3D = panel.get_node("museum_" + variety_id + "_page_" + str(index) + "/TabLabel") as Label3D
		tab_label.modulate = GOLD if index == selected else MUTED
	panel.set_meta("profile_page", selected)
	if page_count == 3:
		var page: Node3D = panel.get_node(page_names[selected])
		if panel.has_meta("page_tween"):
			(panel.get_meta("page_tween") as Tween).kill()
		for page_name in page_names.slice(0, page_count):
			(panel.get_node(page_name) as Node3D).position = Vector3.ZERO
		page.position.x = 0.035
		var tween: Tween = create_tween()
		panel.set_meta("page_tween", tween)
		tween.tween_property(page, "position:x", 0.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		for index in range(page_count):
			style_demo_button(panel.get_node("museum_" + variety_id + "_page_" + str(index)), false, index == selected)
	_sync_anatomy_visibility()

func style_demo_button(button: Node3D, hovered: bool, selected: bool) -> void:
	var state: int = int(hovered) + int(selected) * 2
	if int(button.get_meta("style_state", -1)) == state:
		return
	button.set_meta("style_state", state)
	if button.has_meta("style_tween"):
		(button.get_meta("style_tween") as Tween).kill()
	var backing: MeshInstance3D = button.get_node("TabBacking")
	var material: StandardMaterial3D = backing.material_override as StandardMaterial3D
	var label: Label3D = button.get_node("TabLabel")
	var tween: Tween = create_tween().set_parallel(true)
	button.set_meta("style_tween", tween)
	tween.tween_property(material, "albedo_color", Color("705e36") if selected else (Color("465545") if hovered else Color("303b33")), 0.18)
	tween.tween_property(label, "modulate", Color("fff2cc") if selected or hovered else IVORY, 0.18)
	tween.tween_property(button, "scale", Vector3.ONE * (1.035 if hovered else 1.0), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var rule: Node3D = button.get_node_or_null("ActiveRule")
	if rule != null:
		rule.visible = selected
		rule.scale.x = 0.12 if selected else 1.0
		if selected:
			tween.tween_property(rule, "scale:x", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func press_demo_button(button: Node3D) -> void:
	if button.has_meta("press_tween"):
		(button.get_meta("press_tween") as Tween).kill()
	# Press depth does not disturb the button's hit area or horizontal layout.
	var tween: Tween = create_tween()
	button.set_meta("press_tween", tween)
	button.position.z = 0.036
	tween.tween_property(button, "position:z", 0.045, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _sync_anatomy_visibility() -> void:
	var inspecting_id: String = str(physics.get("inspecting_id")) if physics != null else ""
	for id in exhibit_nodes:
		var panel: Node3D = exhibit_nodes[id]["panel"] as Node3D
		var anatomy: Node3D = panel.get_node_or_null("AnatomyPage") as Node3D
		if anatomy != null:
			anatomy.call("set_active", is_visible_in_tree() and panel.visible and inspecting_id == id and int(panel.get_meta("profile_page", 0)) == 3)


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
