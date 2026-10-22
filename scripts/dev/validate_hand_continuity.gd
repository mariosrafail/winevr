extends Node

## Exercises the actual museum hand, camera changes and tracked-controller path.
## Simulated tracking does not substitute for acceptance on a physical headset.
var failures: Array[String] = []
var checks: int = 0
var capture: bool = false


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("[HandContinuityQA] " + message)


func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _run() -> void:
	capture = "--hand-capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	get_tree().root.size = Vector2i(1280, 800)
	var app: Node = load("res://scenes/WineVRExperience.tscn").instantiate()
	get_tree().root.add_child(app)
	await get_tree().create_timer(2.0).timeout
	var winery: WineryInteriorController = app.get_node("WineryInterior")
	var museum: GrapeMuseum = winery.get("_grape_museum")
	var physics: MuseumPhysicsController = museum.physics
	var manager: WineVRVRManager = winery.get("_vr_manager")
	var rig: WineVRPlayerRig = winery.vr_player_rig
	(app.get("_main_menu") as MainMenuOverlayController).museum_button.pressed.emit()
	await get_tree().create_timer(2.0).timeout
	var hand: MuseumGlove = physics.hand
	var sleeve: MeshInstance3D = hand.get("_sleeve")
	var cuff: MeshInstance3D = hand.get("_authored_cuff")
	_check(sleeve != null and cuff != null, "Runtime hand has both a continuous sleeve and the original tracked cuff")
	if sleeve == null or cuff == null:
		app.queue_free()
		await _finish()
		return
	_check(sleeve.get_parent() == hand.get("_model"), "Sleeve shares the authored hand's scale and coordinate system")
	var fabric: ShaderMaterial = sleeve.material_override as ShaderMaterial
	var authored_fabric: BaseMaterial3D = cuff.get_active_material(0) as BaseMaterial3D
	_check(fabric != null and authored_fabric != null and (fabric.get_shader_parameter("fabric_color") as Color).is_equal_approx(authored_fabric.albedo_color), "Continuous cloth retains the authored cuff's fabric color")
	_check(sleeve.find_children("*", "CollisionObject3D", true, false).is_empty(), "Visual sleeve adds no collider that could push the held fruit")
	_check(sleeve.is_visible_in_tree() and not cuff.visible, "Desktop shows continuous cloth without overlapping the original cuff")
	_check(not physics.left_hand.is_visible_in_tree(), "Desktop does not leave a disconnected second hand")
	_check_geometry(sleeve, cuff, winery.camera, "idle")
	await _capture("idle")

	var body: RigidBody3D = physics._body("vidiano")
	var center: Vector3 = body.to_global(body.center_of_mass)
	winery.player_rig.global_position = Vector3(center.x, 0, center.z + 1.1)
	winery.player_rig.rotation = Vector3.ZERO
	winery.camera_pivot.rotation = Vector3.ZERO
	winery.camera.look_at(center, Vector3.UP)
	await _settle()
	museum.inspect_exhibit("vidiano")
	await get_tree().create_timer(0.5).timeout
	var pointer: InputEventMouseButton = InputEventMouseButton.new()
	pointer.button_index = MOUSE_BUTTON_LEFT
	pointer.shift_pressed = true
	pointer.pressed = true
	pointer.position = winery.camera.unproject_position(body.to_global(body.center_of_mass))
	physics._unhandled_input(pointer)
	await _settle()
	_check(physics.grabbed_id == "vidiano", "Desktop input grabs the actual grape before checking the arm")
	var drag: InputEventMouseMotion = InputEventMouseMotion.new()
	drag.position = pointer.position + Vector2(110, -50)
	drag.relative = Vector2(110, -50)
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	physics._unhandled_input(drag)
	await get_tree().create_timer(0.65).timeout
	_check(hand.global_position.distance_to(hand.grasp_transform().origin) < 0.015, "Sleeve update preserves the wrist's physical attachment during dragging")
	_check_geometry(sleeve, cuff, winery.camera, "held")
	var skin_material: ShaderMaterial = hand.get("_skin_material")
	_check((skin_material.get_shader_parameter("forearm_bend") as Vector2).is_equal_approx(sleeve.get("forearm_bend")), "Skin and sleeve share exactly the same wrist deformation")
	await _capture("held")
	# Camera/body movement and portrait resize must leave the far arm end outside
	# the visible frame; geometry is checked after the actual process callbacks.
	for size in [Vector2i(390, 844), Vector2i(844, 390), Vector2i(1920, 1080)]:
		get_tree().root.size = size
		winery.camera_pivot.rotation = Vector3(-0.24, 0.31, 0)
		winery.player_rig.position += Vector3(0.06, 0, 0.02)
		await _settle()
		_check_geometry(sleeve, cuff, winery.camera, "held " + str(size))
		if size == Vector2i(390, 844):
			await _capture("portrait")
	pointer.pressed = false
	physics._unhandled_input(pointer)
	await get_tree().create_timer(0.3).timeout
	_check(physics.grabbed_id.is_empty() and hand.grip_amount < 0.05, "Release opens the hand without leaving a held arm state")
	_check_geometry(sleeve, cuff, winery.camera, "released")
	winery.set_desktop_modal_context("hand_qa")
	await _settle()
	_check(not hand.is_visible_in_tree() and not sleeve.is_visible_in_tree(), "Modal focus hides both hand and continuous sleeve")
	winery.set_desktop_modal_context("")
	await _settle()
	_check(hand.is_visible_in_tree() and sleeve.is_visible_in_tree(), "Closing the modal restores the complete desktop arm")
	winery.set_presentation_mode("vineyard")
	await _settle()
	_check(not hand.is_visible_in_tree() and not sleeve.is_visible_in_tree(), "Scene navigation removes the complete arm and its geometry")
	winery.set_presentation_mode("museum")
	await _settle()
	_check(sleeve.is_visible_in_tree(), "Returning to the collection restores continuous cloth")

	get_tree().root.size = Vector2i(1280, 800)
	manager.is_vr_active = true
	manager.active_mode = "vr"
	manager.session_state_changed.emit(true, "vr")
	rig.reset_origin(Vector3.ZERO, Vector3.ZERO)
	rig.xr_camera.position = Vector3(0, 1.65, 1.5)
	var tracked_pose: Transform3D = Transform3D(Basis.from_euler(Vector3(0.2, 0.35, -0.3)), Vector3(0.2, 1.3, -0.4))
	var tracker: XRControllerTracker = XRControllerTracker.new()
	tracker.name = &"right_hand"
	tracker.type = XRServer.TRACKER_CONTROLLER
	tracker.set_pose(&"grip", tracked_pose, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	tracker.set_pose(&"aim", tracked_pose, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	XRServer.add_tracker(tracker)
	await _settle()
	_check(hand.is_visible_in_tree() and not sleeve.visible and cuff.is_visible_in_tree(), "XR restores the finite original cuff instead of attaching an elbow to the headset")
	_check(hand.global_transform.is_equal_approx((rig.get_node("RightGrip") as XRController3D).global_transform), "XR sleeve presentation preserves the exact tracked grip pose")
	_check((skin_material.get_shader_parameter("forearm_bend") as Vector2).is_zero_approx(), "XR restores the authored wrist without desktop forearm deformation")
	var before_head_motion: Transform3D = hand.global_transform
	rig.xr_camera.position += Vector3(0.2, 0.1, -0.05)
	rig.xr_camera.rotation = Vector3(0.2, -0.4, 0)
	await _settle()
	_check(hand.global_transform.is_equal_approx(before_head_motion), "Moving the headset cannot pull the tracked hand or cuff toward a camera anchor")
	await _capture("xr")
	manager._set_focus(false)
	await _settle()
	_check(not hand.is_visible_in_tree() and not sleeve.is_visible_in_tree(), "XR focus loss leaves no floating cloth")
	manager._set_focus(true)
	await _settle()
	_check(cuff.is_visible_in_tree() and not sleeve.visible, "XR focus restoration preserves the tracked cuff treatment")
	XRServer.remove_tracker(tracker)
	await _settle()
	_check(not hand.is_visible_in_tree() and hand.collision_layer == 0, "Tracking loss hides the whole hand and clears its collider")
	manager.end_session()
	await _settle()
	_check(winery.camera.current and not sleeve.is_visible_in_tree(), "Leaving XR restores the desktop camera without a floating arm over the main menu")
	(app.get("_main_menu") as MainMenuOverlayController).museum_button.pressed.emit()
	await _settle()
	_check(sleeve.is_visible_in_tree() and not cuff.visible, "Resuming the collection after XR restores the continuous sleeve")
	_check_geometry(sleeve, cuff, winery.camera, "after XR")
	app.queue_free()
	await _finish()


func _check_geometry(sleeve: MeshInstance3D, cuff: MeshInstance3D, view: Camera3D, context: String) -> void:
	_check(sleeve.mesh != null and sleeve.mesh.get_surface_count() == 1, context + ": sleeve has one rendered surface")
	if sleeve.mesh == null or sleeve.mesh.get_surface_count() != 1:
		return
	var arrays: Array = sleeve.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var sides: int = int(sleeve.get_script().get("SIDES"))
	var finite: bool = not vertices.is_empty() and normals.size() == vertices.size()
	for index in range(vertices.size()):
		finite = finite and vertices[index].is_finite() and normals[index].is_finite() and normals[index].length_squared() > 0.8
	_check(finite, context + ": all cloth vertices and surface normals are finite and usable")
	if sides <= 0 or vertices.size() < sides:
		_check(false, context + ": sleeve has complete cross sections")
		return
	# Compare against the imported reference mesh, not duplicate sleeve constants.
	var reference: PackedVector3Array = cuff.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var cuff_to_sleeve: Transform3D = sleeve.global_transform.affine_inverse() * cuff.global_transform
	var reference_front: float = INF
	for point in reference:
		reference_front = minf(reference_front, (cuff_to_sleeve * point).z)
	var seam_matches: bool = true
	var bend: Vector2 = sleeve.get("forearm_bend")
	var forearm_length: float = float(sleeve.get_script().get("FOREARM_LENGTH"))
	_check(bend.length() <= 0.301, context + ": wrist deformation stays within the gentle anatomical limit")
	for index in range(sides):
		var point: Vector3 = vertices[index]
		var closest_rim: float = INF
		for reference_point in reference:
			var local_reference: Vector3 = cuff_to_sleeve * reference_point
			if local_reference.z < reference_front + 0.001:
				var along: float = maxf(local_reference.z - 0.035, 0.0) * forearm_length
				local_reference.z = 0.035 + along
				local_reference += Vector3(bend.x, bend.y, 0) * along * along / 0.36
				closest_rim = minf(closest_rim, point.distance_to(local_reference))
		seam_matches = seam_matches and absf(point.z - (0.035 + (reference_front - 0.035) * forearm_length)) < 0.001 and closest_rim < 0.009
	_check(seam_matches, context + ": sleeve joins the authored cuff plane with a small cloth overlap")
	var centers: Array[Vector3] = []
	for ring in range(vertices.size() / sides):
		var center: Vector3 = Vector3.ZERO
		for side in range(sides):
			center += vertices[ring * sides + side]
		centers.append(center / sides)
	var maximum_turn: float = 0.0
	for ring in range(1, centers.size() - 1):
		maximum_turn = maxf(maximum_turn, (centers[ring] - centers[ring - 1]).angle_to(centers[ring + 1] - centers[ring]))
	_check(maximum_turn < deg_to_rad(12.0), context + ": arm curvature is distributed without a sharp elbow (" + str(rad_to_deg(maximum_turn)) + " degrees per section)")
	var endpoint_below: bool = true
	var viewport_height: float = view.get_viewport().get_visible_rect().size.y
	for index in range(vertices.size() - sides, vertices.size()):
		var world_point: Vector3 = sleeve.to_global(vertices[index])
		endpoint_below = endpoint_below and not view.is_position_behind(world_point) and view.unproject_position(world_point).y > viewport_height
	_check(endpoint_below, context + ": the complete far rim continues beyond the bottom of the camera frame")


func _capture(label: String) -> void:
	if not capture:
		return
	await RenderingServer.frame_post_draw
	var error: Error = get_viewport().get_texture().get_image().save_png("res://work/hand_continuity_" + label + ".png")
	_check(error == OK, "Captured " + label)


func _finish() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	print("[HandContinuityQA] " + JSON.stringify({"checks": checks, "passed": failures.is_empty(), "failures": failures, "headset_tested": false}))
	get_tree().quit(0 if failures.is_empty() else 1)
