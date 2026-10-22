extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("[TerroirQA] " + message)


func _run() -> void:
	var packed: PackedScene = load("res://scenes/VineyardLandscape.tscn") as PackedScene
	_check(packed != null, "Landscape scene loads")
	if packed == null:
		quit(1)
		return
	var landscape: VineyardLandscapeController = packed.instantiate() as VineyardLandscapeController
	root.add_child(landscape)
	await process_frame
	_check(landscape.stations.size() == 4, "Four interpretive stations exist")
	_check(landscape.data.get("sources", []).size() >= 3, "Source attribution accompanies the tour")
	_check(landscape.has_node("VineyardLandscapeVisual"), "Authored vineyard model loads")
	_check(landscape.has_node("CretanRidge_0"), "Modeled Cretan horizon exists")
	var shape: StaticBody3D = landscape.get_node("VineyardTeleportFloor") as StaticBody3D
	_check(shape.collision_layer == 8 and shape.is_in_group("vr_teleport_floor"), "Tour floor supports XR teleport layer and group")
	var spawn: Vector3 = landscape.get_spawn_position()
	_check(spawn.x >= landscape.get_bounds_min().x and spawn.x <= landscape.get_bounds_max().x and spawn.z >= landscape.get_bounds_min().y and spawn.z <= landscape.get_bounds_max().y, "Spawn is inside playable terrace")
	landscape.set_active(false)
	for object: CollisionObject3D in landscape.get("_collision_layers"):
		_check(object.collision_layer == 0, "Hidden landscape removes collisions: " + str(object.name))
	landscape.set_active(true)
	_check(shape.collision_layer == 8, "Returning to the landscape restores teleport collision")
	for key: String in landscape.stations:
		var station: Interactable = landscape.stations[key] as Interactable
		_check(station.bypass_guided_lock, "Station is available outside the tasting sequence")
		station.interact()
	_check(landscape.visited_stations.size() == 4, "Interaction records all distinct tour stations")
	(landscape.stations["dafnes"] as Interactable).interact()
	_check(landscape.visited_stations.size() == 4, "Revisiting a station does not inflate progress")
	var environment_node: WorldEnvironment = WorldEnvironment.new()
	environment_node.environment = Environment.new()
	root.add_child(environment_node)
	landscape.configure_environment(environment_node.environment)
	_check(environment_node.environment.background_mode == Environment.BG_SKY, "Tour uses outdoor sky lighting")
	if "--terroir-capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		root.size = Vector2i(1440, 900)
		root.msaa_3d = Viewport.MSAA_2X
		var camera: Camera3D = Camera3D.new()
		root.add_child(camera)
		camera.position = Vector3(0.0, 1.86, 3.2)
		camera.look_at(Vector3(0.0, 1.4, -12.0))
		camera.current = true
		await create_timer(1.2).timeout
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://work/qa")
		root.get_texture().get_image().save_png("res://work/qa/terroir_overview.png")
		camera.position = Vector3(-6.0, 1.82, 1.25)
		camera.look_at(Vector3(-6.0, 1.20, -0.95))
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://work/qa/terroir_dafnes.png")
	print("[TerroirQA] %s" % ("PASS" if failures.is_empty() else "FAIL: " + str(failures)))
	landscape.queue_free()
	environment_node.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
