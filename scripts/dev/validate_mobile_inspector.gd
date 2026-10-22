extends Node

var checks: int = 0
var failures: Array[String] = []
var capture: bool = false


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("[MobileInspectorQA] " + message)


func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	var app: Node = (load("res://scenes/WineVRExperience.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(app)
	await get_tree().create_timer(1.7).timeout
	app.call("_navigate_section", "museum")
	await get_tree().create_timer(0.8).timeout
	var winery: WineryInteriorController = app.get_node("WineryInterior") as WineryInteriorController
	var museum: GrapeMuseum = winery.get("_grape_museum") as GrapeMuseum
	var inspector: MobileGrapeInspector = app.get_node("MobileGrapeInspectorController") as MobileGrapeInspector
	for size in [Vector2i(320, 568), Vector2i(360, 640)]:
		get_tree().root.size = size
		await get_tree().create_timer(0.3).timeout
		museum.inspect_exhibit("vidiano")
		await get_tree().create_timer(0.8).timeout
		_check(inspector.panel.visible and get_viewport().get_visible_rect().encloses(inspector.panel.get_global_rect()), str(size) + " inspector fits")
		var world_panel: Node3D = museum.exhibit_nodes["vidiano"]["panel"] as Node3D
		for collider in world_panel.find_children("*", "CollisionObject3D", true, false):
			_check((collider as CollisionObject3D).collision_layer == 0, "Hidden world panel does not intercept touch")
		var model: Node3D = (museum.exhibit_nodes["vidiano"]["turntable"] as Node3D).get_node("AuthoredBunch")
		var berry_rect: Rect2 = _project_bounds(model, winery.camera)
		print("[MobileInspectorQA] fruit_bounds=", berry_rect, " safe_y=90..", inspector.panel.position.y)
		_check(berry_rect.position.y >= 86 and berry_rect.end.y <= inspector.panel.position.y + 3, str(size) + " whole bunch fits between navigation and card")
		var tab_rect: Rect2 = inspector.tabs.get_tab_rect(1)
		await _tap(inspector.tabs.global_position + tab_rect.get_center())
		_check(int(world_panel.get_meta("profile_page")) == 1, "Actual touch selects the learning tab")
		for repetition in range(3):
			museum.set_profile_page("vidiano", 3)
			await get_tree().create_timer(0.15).timeout
			var preview: SubViewport = inspector.get("_anatomy_view") as SubViewport
			var previous: WeakRef = weakref(preview)
			_check(inspector.content.find_children("*", "SubViewport", true, false).size() == 1, "Only one preview viewport exists")
			if repetition == 0:
				var parts: Array[Node] = inspector.content.find_children("*", "Button", true, false)
				var seeds: Button = parts[2] as Button
				inspector.scroll.ensure_control_visible(seeds)
				await get_tree().process_frame
				await _tap(seeds.get_global_rect().get_center())
				_check(str((inspector.get("_anatomy") as Node).get("selected_part")) == "seeds", "Actual touch selects seeds after scrolling")
				if capture:
					await _capture("mobile_inspector_" + str(size.x))
				(app.get("_main_menu") as MainMenuOverlayController).show_menu()
				await get_tree().create_timer(0.08).timeout
				_check(not inspector.panel.visible and preview.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Menu hides and pauses the anatomy preview")
				app.call("_on_main_menu_resume_requested")
				await get_tree().create_timer(0.2).timeout
				_check(inspector.panel.visible and preview.render_target_update_mode != SubViewport.UPDATE_DISABLED, "Resume restores the existing preview")
			museum.set_profile_page("vidiano", 0)
			await get_tree().process_frame
			await get_tree().process_frame
			_check(previous.get_ref() == null, "Changing tabs frees the old preview viewport")
		museum.close_inspection()
		await get_tree().create_timer(0.5).timeout
		_check(not inspector.panel.visible, "Returning fruit hides native inspector")
		museum.set_profile_page("vidiano", 0)
	museum.inspect_exhibit("vidiano")
	await get_tree().create_timer(0.4).timeout
	museum.set_profile_page("vidiano", 3)
	await get_tree().create_timer(0.15).timeout
	var leaving_preview: SubViewport = inspector.get("_anatomy_view") as SubViewport
	var preview_lifetime: WeakRef = weakref(leaving_preview)
	app.call("_navigate_section", "cellar")
	await get_tree().create_timer(0.4).timeout
	_check(not inspector.panel.visible, "Inspector does not follow into cellar")
	_check(leaving_preview.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Leaving with anatomy open stops preview rendering")
	app.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(preview_lifetime.get_ref() == null, "Scene teardown frees its isolated viewport and world")
	var report: Dictionary = {"passed": failures.is_empty(), "checks": checks, "failures": failures, "native_touch_events": true}
	var file: FileAccess = FileAccess.open("res://work/mobile_inspector_qa.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("[MobileInspectorQA] " + JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)


func _tap(position: Vector2) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.position = position
	event.index = 0
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	event = event.duplicate() as InputEventScreenTouch
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().create_timer(0.1).timeout


func _project_bounds(model: Node3D, camera: Camera3D) -> Rect2:
	var rect: Rect2
	var initialized: bool = false
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		for index in range(8):
			var point: Vector2 = camera.unproject_position(mesh.global_transform * mesh.get_aabb().get_endpoint(index))
			if not initialized:
				rect = Rect2(point, Vector2.ZERO)
				initialized = true
			else:
				rect = rect.expand(point)
	return rect


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://work/" + name + ".png")
