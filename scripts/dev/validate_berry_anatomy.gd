extends Node

var checks: int = 0
var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("[AnatomyQA] " + message)

func _click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event, true)

func _run() -> void:
	var demo: Node3D = load("res://scenes/GrapeRoomDemo.tscn").instantiate()
	get_tree().root.add_child(demo)
	await get_tree().create_timer(1.0).timeout
	demo.settings.close()
	demo._started = true
	demo._pause(false)
	var museum: GrapeMuseum = demo.museum
	var camera: Camera3D = demo.winery.camera
	for id: String in museum.exhibit_nodes:
		museum.inspect_exhibit(id)
		await get_tree().create_timer(0.65).timeout
		var panel: Node3D = museum.exhibit_nodes[id]["panel"]
		var tab: Node3D = panel.get_node("museum_" + id + "_page_3")
		_click(camera.unproject_position(tab.global_position))
		await get_tree().process_frame
		var anatomy: BerryAnatomy = panel.get_node("AnatomyPage")
		_check(anatomy.active and anatomy.visible, id + " actual fourth-tab mouse click opens anatomy")
		_check(anatomy.model.find_children("Seed_*", "MeshInstance3D", true, false).size() == 2, id + " longitudinal example shows two embedded pear-shaped seeds")
		var pulp: MeshInstance3D = anatomy.model.get_node("JuicyPulp")
		_check(pulp.get_aabb().size.z > 0.008, id + " cut flesh contains real recessed seed locules")
		var skin: StandardMaterial3D = anatomy._part_materials["skin"]
		_check(skin.albedo_texture != null and id in skin.albedo_texture.resource_path, id + " cutaway uses the variety's actual skin texture")
		for part in ["skin", "pulp", "seeds"]:
			var button: Node3D = anatomy.get_node("Anatomy_" + part)
			_click(camera.unproject_position(button.global_position))
			await get_tree().process_frame
			_check(anatomy.selected_part == part, id + " actual pointer click selects " + part)
			_check(not anatomy._description.text.is_empty(), id + " selected part has readable explanation")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://work/anatomy-" + id + ".png")
		museum.set_profile_page(id, 0)
		await get_tree().process_frame
		_check(not anatomy.active and not anatomy.visible, id + " leaving tab hides geometry and disables its controls")
		museum.close_inspection()
		await get_tree().create_timer(0.5).timeout
	print("[AnatomyQA] checks=%s failures=%s" % [checks, failures.size()])
	demo.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
