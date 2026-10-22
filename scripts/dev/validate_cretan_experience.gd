extends Node

var failures: Array[String] = []
var checks: int = 0
var capture: bool = false


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("[CretanQA] " + message)


func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	var app: Node = (load("res://scenes/WineVRExperience.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(app)
	await get_tree().create_timer(1.8).timeout
	var winery: WineryInteriorController = app.get_node("WineryInterior") as WineryInteriorController
	var museum: GrapeMuseum = winery.get("_grape_museum") as GrapeMuseum
	var menu: MainMenuOverlayController = app.get("_main_menu") as MainMenuOverlayController
	var catalog: QRScreenController = app.get("_qr_screen") as QRScreenController
	if capture:
		DisplayServer.window_set_size(Vector2i(1440, 900))
		await get_tree().create_timer(0.4).timeout
		await _capture("cretan_menu")
	_check(menu.is_open(), "Main menu opens")
	_check(museum.exhibit_nodes.size() == 3, "All three varieties load")
	menu.museum_button.pressed.emit()
	await get_tree().create_timer(1.0).timeout
	_check(winery.presentation_mode == "museum" and winery.visible, "Menu enters museum")
	_check(museum.controls_enabled and winery.camera.current, "Museum has controls and camera")
	if capture:
		await _capture("cretan_collection")
	# Switching during inspection must return the body, stop hand grabs, and
	# remove hidden museum colliders from the playable outdoor terrace.
	museum.inspect_exhibit("vidiano")
	await get_tree().create_timer(0.5).timeout
	app.call("_navigate_section", "vineyard")
	await get_tree().create_timer(0.5).timeout
	var vineyard: VineyardLandscapeController = winery.get("_vineyard") as VineyardLandscapeController
	_check(vineyard != null and vineyard.visible, "Vineyard is reachable from actual app")
	_check(not museum.visible and not museum.is_inspecting(), "Museum inspection ends when leaving")
	_check(not museum.controls_enabled, "Hidden collection cannot grab")
	_check(winery.player_rig.position.is_equal_approx(vineyard.get_spawn_position()), "Vineyard spawn is on terrace")
	_check((winery.get("_movement") as WineryMovementController).bounds_min.x < -8, "Outdoor walking bounds are applied")
	_check(vineyard.stations.size() == 4, "Four source-backed tour stations")
	if capture:
		await _capture("cretan_dafnes")
	for station: Interactable in vineyard.stations.values():
		# Same Interactable signal path as a desktop ray / XR trigger.
		station.interact()
	_check((app.get("_visited_stations") as Dictionary).size() == 4, "Station progress reaches 4/4")
	app.call("_navigate_section", "museum")
	await get_tree().create_timer(0.3).timeout
	_check(museum.visible and not vineyard.visible, "Museum returns without landscape duplication")
	_check((winery.get("_movement") as WineryMovementController).bounds_min == Vector2(-2.6, -2.8), "Museum bounds restored")
	var vineyard_instance: int = vineyard.get_instance_id()
	app.call("_navigate_section", "vineyard")
	app.call("_navigate_section", "museum")
	_check((winery.get("_vineyard") as Node).get_instance_id() == vineyard_instance, "Repeated navigation reuses scene")
	app.call("_navigate_section", "cellar")
	await get_tree().create_timer(0.3).timeout
	var cellar: Node3D = winery.get("_cellar") as Node3D
	_check(cellar != null and cellar.visible and not museum.visible and not vineyard.visible, "Cellar is a separate reachable space")
	_check((cellar.get("stations") as Dictionary).size() == 4, "Cellar offers four educational stations")
	if capture:
		await _capture("cretan_cellar")
	app.call("_navigate_section", "museum")
	_check(not cellar.visible and museum.visible, "Leaving cellar restores museum")
	# Independent touch buttons must not cancel another finger's held input.
	var movement: WineryMovementController = winery.get("_movement") as WineryMovementController
	movement.set_mobile_move_axis("left", true)
	movement.set_mobile_move_axis("right", true)
	movement.set_mobile_move_axis("right", false)
	_check(movement.mobile_move_vector.x == -1, "Touch release preserves opposite held direction")
	movement.set_mobile_move_axis("left", false)
	app.call("_open_tasting_catalog")
	await get_tree().create_timer(0.3).timeout
	_check(catalog.screen.visible and not winery.visible, "Catalog navigation uses the tasting screen")
	for id in ["liatiko_dafnes_demo", "kotsifali_crete_demo", "vidiano_crete_demo"]:
		_check(not WineDatabase.get_profile_by_id(id).is_empty(), "Bundled Cretan profile: " + id)
	catalog.region_filter.select(1)
	catalog.region_filter.item_selected.emit(1)
	_check(catalog.button_box.get_child_count() == 3, "Crete filter has three wines")
	catalog.search_field.text = "βιδιανο"
	catalog.search_field.text_changed.emit("βιδιανο")
	_check(catalog.button_box.get_child_count() == 1 and catalog.button_box.get_child(0) is Button, "Greek search is accent-insensitive")
	if capture:
		await _capture("cretan_catalog")
	catalog.search_field.text = "does-not-exist"
	catalog.search_field.text_changed.emit("does-not-exist")
	_check(catalog.button_box.get_child(0) is Label, "Empty search provides recovery text")
	catalog.search_field.clear()
	catalog.search_field.text_changed.emit("")
	# Reject unsupported XR without losing the desktop scene or camera.
	if DisplayServer.get_name() == "headless":
		var initialized: bool = await winery.request_immersive_mode("ar")
		_check(not initialized and not winery.is_vr_active(), "Unsupported AR safely rejects")
		_check(not get_viewport().use_xr, "No false XR activation")
	if capture:
		DisplayServer.window_set_size(Vector2i(390, 844))
		menu.show_menu()
		await get_tree().create_timer(0.4).timeout
		_check(menu.panel.size.x <= get_viewport().get_visible_rect().size.x, "Mobile menu fits width")
		await _capture("cretan_mobile_menu")
		app.call("_navigate_section", "museum")
		await get_tree().create_timer(1.0).timeout
		await _capture("cretan_mobile_collection")
		_check((app.get("_section_bar") as Control).get_global_rect().end.x <= 390, "All navigation actions fit portrait width")
		museum.inspect_exhibit("vidiano")
		await get_tree().create_timer(0.65).timeout
		var mobile_inspector: Node = app.get_node("MobileGrapeInspectorController")
		var inspector_panel: Control = mobile_inspector.get("panel") as Control
		_check(inspector_panel.visible, "Portrait touch inspection has readable native controls")
		_check(inspector_panel.get_global_rect().end.x <= 390 and inspector_panel.get_global_rect().end.y < 710, "Inspector fits above touch actions")
		_check(not (museum.exhibit_nodes["vidiano"]["panel"] as Node3D).visible, "Portrait avoids offscreen world panel")
		await _capture("cretan_mobile_inspector")
		museum.set_profile_page("vidiano", 3)
		await get_tree().create_timer(0.4).timeout
		var anatomy: Node3D = mobile_inspector.get("_anatomy") as Node3D
		_check(anatomy != null and anatomy.visible, "Portrait has isolated 3D berry cutaway")
		anatomy.call("select_part", "seeds")
		_check(str(anatomy.get("selected_part")) == "seeds", "Portrait cutaway selects seeds")
		await _capture("cretan_mobile_anatomy")
		DisplayServer.window_set_size(Vector2i(844, 390))
		await get_tree().create_timer(0.3).timeout
		_check(not inspector_panel.visible and (museum.exhibit_nodes["vidiano"]["panel"] as Node3D).visible, "Rotating phone restores world inspector")
		museum.close_inspection()
		app.call("_navigate_section", "cellar")
		await get_tree().create_timer(0.3).timeout
		_check(not inspector_panel.visible, "Portrait inspector does not leak into cellar")
	var report: Dictionary = {"passed": failures.is_empty(), "checks": checks, "failures": failures, "headset_tested": false}
	var output: FileAccess = FileAccess.open("res://work/cretan_qa.json", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "  "))
	print("[CretanQA] " + JSON.stringify(report))
	app.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)


func _capture(filename: String) -> void:
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://work/" + filename + ".png")
