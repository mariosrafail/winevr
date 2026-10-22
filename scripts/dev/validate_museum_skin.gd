extends Node3D

const HAND: PackedScene = preload("res://assets/models/museum_hand/museum_hand.glb")
const SKIN: Script = preload("res://scripts/winery/museum_skin.gd")
var checks: int = 0
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("[MuseumSkinQA] " + message)


func _run() -> void:
	var baseline: Node3D = HAND.instantiate() as Node3D
	var enhanced: Node3D = HAND.instantiate() as Node3D
	add_child(baseline)
	add_child(enhanced)
	var original: MeshInstance3D = baseline.find_child("AnatomicalHandSkin", true, false) as MeshInstance3D
	var enhanced_mesh: MeshInstance3D = enhanced.find_child("AnatomicalHandSkin", true, false) as MeshInstance3D
	_check(original != null and enhanced_mesh != null, "Anatomical mesh exists")
	SKIN.apply_to(enhanced)
	_check(enhanced_mesh.get_active_material(0) is ShaderMaterial, "Skin uses the anatomical shader")
	var source_arrays: Array = original.mesh.surface_get_arrays(0)
	var result_arrays: Array = enhanced_mesh.mesh.surface_get_arrays(0)
	for slot in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS, Mesh.ARRAY_INDEX]:
		if DisplayServer.get_name() == "headless" and slot in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT]:
			# The dummy renderer cannot apply surface_update_vertex_region. Its
			# decoded normals retain one extra packing round; real renderers below
			# require byte-identical values for every stream, including normals.
			var maximum_error: float = 0.0
			for i in range(source_arrays[slot].size()):
				if slot == Mesh.ARRAY_NORMAL:
					maximum_error = maxf(maximum_error, (source_arrays[slot][i] as Vector3).distance_to(result_arrays[slot][i] as Vector3))
				else:
					maximum_error = maxf(maximum_error, absf(float(source_arrays[slot][i]) - float(result_arrays[slot][i])))
			_check(maximum_error < 0.0003, "Dummy renderer packed stream " + str(slot) + " remains within its quantization precision")
		else:
			_check(source_arrays[slot] == result_arrays[slot], "Geometry/rig stream " + str(slot) + " is unchanged")
	_check((result_arrays[Mesh.ARRAY_TEX_UV2] as PackedVector2Array).size() == (source_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), "Every vertex has stable anatomical coordinates")
	_check(enhanced_mesh.mesh.shadow_mesh == original.mesh.shadow_mesh, "Imported shadow mesh remains shared")
	var source_surface: Dictionary = RenderingServer.mesh_get_surface(original.mesh.get_rid(), 0)
	var result_surface: Dictionary = RenderingServer.mesh_get_surface(enhanced_mesh.mesh.get_rid(), 0)
	_check(source_surface.get("lods", []) == result_surface.get("lods", []), "Every imported LOD index buffer is preserved")
	var material: ShaderMaterial = enhanced_mesh.get_active_material(0) as ShaderMaterial
	var old_material: StandardMaterial3D = original.get_active_material(0) as StandardMaterial3D
	_check(material.get_shader_parameter("skin_albedo") == old_material.albedo_texture and material.get_shader_parameter("skin_normal") == old_material.normal_texture, "Original baked texture resources are reused")
	for original_node in baseline.find_children("*", "MeshInstance3D", true, false):
		var before: MeshInstance3D = original_node as MeshInstance3D
		if before.name == "AnatomicalHandSkin":
			continue
		var after: MeshInstance3D = enhanced.find_child(str(before.name), true, false) as MeshInstance3D
		if str(before.name).contains("Nail"):
			var before_arrays: Array = before.mesh.surface_get_arrays(0)
			var after_arrays: Array = after.mesh.surface_get_arrays(0)
			_check(before_arrays[Mesh.ARRAY_BONES] == after_arrays[Mesh.ARRAY_BONES] and before_arrays[Mesh.ARRAY_WEIGHTS] == after_arrays[Mesh.ARRAY_WEIGHTS] and before.skin == after.skin, str(before.name) + " still follows the same distal bone and skin bind")
			var original_points: PackedVector3Array = before_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var fitted_points: PackedVector3Array = after_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var largest_shift: float = 0.0
			var outline_unchanged: bool = true
			for i in range(original_points.size()):
				largest_shift = maxf(largest_shift, absf(original_points[i].y - fitted_points[i].y))
				outline_unchanged = outline_unchanged and original_points[i].x == fitted_points[i].x and original_points[i].z == fitted_points[i].z
			_check(outline_unchanged and largest_shift < 0.005, str(before.name) + " preserves its outline while wrapping the distal-pad surface")
		else:
			_check(before.mesh == after.mesh, str(before.name) + " geometry is unchanged")
		if str(before.name).contains("Museum"):
			_check(before.get_active_material(0) == after.get_active_material(0), "Cuff fabric is unchanged")
	var skeleton: Skeleton3D = enhanced.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_check(skeleton.get_bone_count() == 16, "All sixteen bones remain available")
	var applied_mesh: Mesh = enhanced_mesh.mesh
	SKIN.apply_to(enhanced)
	_check(applied_mesh == enhanced_mesh.mesh, "Repeated application is idempotent")
	var repeated: Node3D = HAND.instantiate() as Node3D
	SKIN.apply_to(repeated)
	_check((repeated.find_child("AnatomicalHandSkin", true, false) as MeshInstance3D).mesh == applied_mesh, "Both hands share one augmented mesh")
	repeated.free()
	if DisplayServer.get_name() != "headless":
		get_tree().root.size = Vector2i(1440, 1040)
		_build_preview(baseline, enhanced)
		await get_tree().create_timer(2.5).timeout
		await RenderingServer.frame_post_draw
		var renderer: String = RenderingServer.get_current_rendering_method()
		get_viewport().get_texture().get_image().save_png("res://work/museum_skin_" + renderer + "_palm.png")
		baseline.rotation.y = PI
		enhanced.rotation.y = PI
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://work/museum_skin_" + renderer + "_dorsal.png")
		baseline.rotation.y = PI + 0.55
		enhanced.rotation.y = PI + 0.55
		for model in [baseline, enhanced]:
			var hand_rig: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			for digit in ["index", "middle", "ring", "little"]:
				for joint in range(3):
					hand_rig.set_bone_pose_rotation(hand_rig.find_bone(digit + "_" + str(joint)), Quaternion(Vector3.RIGHT, [0.22, 0.50, 0.35][joint]))
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://work/museum_skin_" + renderer + "_flexed.png")
	var report: Dictionary = {"passed": failures.is_empty(), "checks": checks, "failures": failures}
	var file: FileAccess = FileAccess.open("res://work/museum_skin_qa.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("[MuseumSkinQA] ", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)


func _build_preview(before: Node3D, after: Node3D) -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.095, 0.12, 0.115)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.76, 0.83, 0.86)
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.32
	camera.position = Vector3(0, 0.006, 1.2)
	add_child(camera)
	camera.make_current()
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-28, -35, 0)
	key.light_energy = 1.05
	key.light_color = Color(1, 0.94, 0.86)
	add_child(key)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(18, 58, 0)
	fill.light_energy = 0.22
	fill.light_color = Color(0.77, 0.86, 1)
	add_child(fill)
	before.position = Vector3(-0.11, 0, 0)
	after.position = Vector3(0.11, 0, 0)
	before.rotation = Vector3(PI * 0.5, 0, 0)
	after.rotation = before.rotation
	var canvas: CanvasLayer = CanvasLayer.new()
	add_child(canvas)
	for item in [["ORIGINAL", 0.25], ["ANATOMICAL SKIN", 0.75]]:
		var label: Label = Label.new()
		label.text = item[0]
		label.position = Vector2(float(item[1]) * 1440 - 130, 20)
		label.size = Vector2(260, 48)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 24)
		canvas.add_child(label)
