extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("[CellarQA] " + message)


func _run() -> void:
	var packed: PackedScene = load("res://scenes/CellarTour.tscn") as PackedScene
	_check(packed != null, "Cellar scene loads")
	if packed == null:
		quit(1)
		return
	var cellar: Node3D = packed.instantiate() as Node3D
	root.add_child(cellar)
	await process_frame
	var stations: Dictionary = cellar.get("stations")
	_check(stations.size() == 4, "Four educational stations exist")
	_check(cellar.has_node("ContinuousLimestoneVault"), "Vaulted cellar is modeled")
	var barrels: MultiMeshInstance3D = cellar.get_node("OakBarrelStaves") as MultiMeshInstance3D
	_check(barrels.multimesh.instance_count == 12, "Twelve barrels share one batched stave mesh")
	for id: String in stations:
		(stations[id] as Interactable).interact()
	_check((cellar.get("visited_stations") as Dictionary).size() == 4, "All educational stories are interactable")
	await physics_frame
	for id: String in stations:
		var station: Interactable = stations[id] as Interactable
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(station.global_position + station.global_basis.z * 1.7 + Vector3(0, 0.25, 0), station.global_position, 1)
		query.collide_with_areas = true
		query.collide_with_bodies = false
		var hit: Dictionary = cellar.get_world_3d().direct_space_state.intersect_ray(query)
		_check(not hit.is_empty() and (hit.get("collider") as Node).get_parent() == station, "Real interaction ray reaches " + id + " plaque")
	cellar.call("set_active", false)
	for object: CollisionObject3D in cellar.get("_collision_layers"):
		_check(object.collision_layer == 0, "Hidden cellar disables collision")
	cellar.call("set_active", true)
	var floor_body: StaticBody3D = cellar.get_node("VineyardTeleportFloor") as StaticBody3D
	_check(floor_body.collision_layer == 8, "Cellar floor restores teleport layer")
	var environment_node: WorldEnvironment = WorldEnvironment.new()
	environment_node.environment = Environment.new()
	root.add_child(environment_node)
	cellar.call("configure_environment", environment_node.environment)
	if "--cellar-capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		root.size = Vector2i(1440, 900)
		root.msaa_3d = Viewport.MSAA_2X
		var camera: Camera3D = Camera3D.new()
		root.add_child(camera)
		camera.position = Vector3(0, 1.67, 4.0)
		camera.look_at(Vector3(0, 2.2, -4.0))
		camera.current = true
		await create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://work/qa")
		root.get_texture().get_image().save_png("res://work/qa/cellar_overview.png")
		camera.position = Vector3(-1.3, 1.55, 0.1)
		camera.look_at(Vector3(-3.8, 1.1, 0.5))
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://work/qa/cellar_barrels.png")
		camera.position = Vector3(0, 1.6, -3.9)
		camera.look_at(Vector3(0, 1.27, -5.5))
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://work/qa/cellar_tasting.png")
	print("[CellarQA] %s" % ("PASS" if failures.is_empty() else str(failures)))
	cellar.queue_free()
	environment_node.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
