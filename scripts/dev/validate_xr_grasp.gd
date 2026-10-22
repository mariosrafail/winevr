extends Node

var failures: Array[String] = []
var checks: int = 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("[XRGraspQA] " + message)


func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame


func _run() -> void:
	var app: Node = load("res://scenes/WineVRExperience.tscn").instantiate()
	get_tree().root.add_child(app)
	await get_tree().create_timer(0.6).timeout
	var winery: WineryInteriorController = app.get_node("WineryInterior")
	var museum: GrapeMuseum = winery.get("_grape_museum")
	var physics: MuseumPhysicsController = museum.physics
	var manager: WineVRVRManager = winery.get("_vr_manager")
	var rig: WineVRPlayerRig = winery.vr_player_rig
	(app.get("_main_menu") as MainMenuOverlayController).museum_button.pressed.emit()
	await get_tree().create_timer(0.6).timeout
	manager.is_vr_active = true
	manager.active_mode = "vr"
	manager.session_state_changed.emit(true, "vr")
	rig.reset_origin(Vector3.ZERO, Vector3.ZERO)
	rig.xr_camera.position = Vector3(0, 1.65, 1.5)
	var body: RigidBody3D = physics._body("vidiano")
	var center: Vector3 = body.to_global(body.center_of_mass)
	var left: XRControllerTracker = _tracker("left_hand", center)
	await _settle()
	_check(physics.left_hand.visible and not physics.hand.visible, "Only the tracked left glove is visible")
	_check(physics._preferred_grip() == rig.get_node("LeftGrip"), "Physical grasp prefers the tracked grip pose over distant aim")
	left.set_input(&"grip", 0.8)
	await _settle()
	_check(physics.grabbed_id == "vidiano", "A left squeeze physically grabs the nearby grape")
	_check(physics._grasp_hand == physics.left_hand, "The left glove owns the left-controller grasp")
	_check(physics.left_hand.get("_fruit") == body and physics.hand.get("_fruit") == null, "Only one anatomical hand holds the fruit")
	_check(physics.left_hand.get_collision_exceptions().has(body), "Grasp prevents the selected glove from pushing through its held grape")
	_check(physics.left_hand.global_transform.is_equal_approx((rig.get_node("LeftGrip") as XRController3D).global_transform), "Left glove follows the real tracked grip transform")
	var initial_left_target: Vector3 = physics._grab_target()
	_set_pose(left, center + Vector3(0.09, 0, 0))
	await _settle()
	_check(physics._grab_target().distance_to(initial_left_target + Vector3(0.09, 0, 0)) < 0.001, "Dragging uses the holding left grip while retaining the initial contact offset")
	left.set_input(&"grip", 0.3)
	await _settle()
	_check(not physics.grabbed_id.is_empty(), "Grip hysteresis retains a partially held left squeeze")
	left.set_input(&"grip", 0.1)
	await _settle()
	_check(physics.grabbed_id.is_empty() and physics.left_hand.grip_target == 0.0, "Releasing the left squeeze opens the correct hand")
	_check(not physics.left_hand.get_collision_exceptions().has(body), "Left release restores physical contact")
	_set_pose(left, body.to_global(body.center_of_mass))
	left.set_input(&"grip", 0.8)
	await _settle()
	_check(physics.grabbed_id == "vidiano", "Left controller can grab again after release")
	var right: XRControllerTracker = _tracker("right_hand", body.to_global(body.center_of_mass))
	await _settle()
	_check(physics.grabbed_id.is_empty() and physics.left_hand.get("_fruit") == null, "Restoring the preferred right controller releases the old left grasp")
	_check(physics._preferred_grip() == rig.get_node("RightGrip"), "Right grip is preferred while both controllers track")
	left.set_input(&"grip", 0.0)
	await _settle()
	left.set_input(&"grip", 0.8)
	await _settle()
	_check(physics.grabbed_id.is_empty(), "Left squeeze cannot start a simultaneous grab while right tracking owns grasping")
	_set_pose(right, body.to_global(body.center_of_mass))
	right.set_input(&"grip", 0.8)
	await _settle()
	_check(physics.grabbed_id == "vidiano" and physics._grasp_hand == physics.hand, "Preferred right controller still physically grabs")
	XRServer.remove_tracker(right)
	await _settle()
	_check(physics.grabbed_id.is_empty(), "Losing the holding right controller releases without transferring into the squeezed left hand")
	left.set_input(&"grip", 0.0)
	await _settle()
	_set_pose(left, body.to_global(body.center_of_mass))
	left.set_input(&"grip", 0.8)
	await _settle()
	_check(physics.grabbed_id == "vidiano" and physics._grasp_hand == physics.left_hand, "A fresh left squeeze works after tracking handover")
	XRServer.remove_tracker(left)
	await _settle()
	_check(physics.grabbed_id.is_empty() and physics.left_hand.get("_fruit") == null, "Losing all tracking releases the physical grasp")
	_check(not physics.left_hand.visible and physics.left_hand.collision_layer == 0, "Lost left tracking hides the glove and removes stale collisions")
	# Start at a reachable wrist pose around the berries, with the same physical
	# controller orientation as the visible anatomical hand, not at fruit center.
	body.freeze = true
	physics.hand.sync_to_physics = false
	physics.hand.start_grasp(body, body.center_of_mass, rig.xr_camera)
	var fitted_wrist: Transform3D = physics.hand.grasp_transform()
	physics.hand.release_grasp()
	physics.hand.sync_to_physics = true
	var fixture_pose: Transform3D = rig.global_transform.affine_inverse() * fitted_wrist
	var contact_tracker: XRControllerTracker = _tracker("right_hand", fixture_pose.origin)
	_set_transform(contact_tracker, fixture_pose)
	await _settle()
	var initial_contact_point: Vector3 = body.to_global(body.center_of_mass)
	contact_tracker.set_input(&"grip", 0.8)
	await _settle()
	_check(physics.grabbed_id == "vidiano", "A realistically positioned tracked hand can grab the berry surface")
	_check(physics._vr_grab_offset.length() > 0.04, "Tracked grasp retains a nonzero wrist-to-fruit contact offset")
	_check(physics._grab_target().distance_to(initial_contact_point) < 0.005, "First squeeze does not pull the fruit center into the tracked palm")
	_check(physics.hand.global_transform.is_equal_approx((rig.get_node("RightGrip") as XRController3D).global_transform), "Contact fitting never snaps the tracked wrist to a camera-derived pose")
	await get_tree().create_timer(0.15).timeout
	var visible_relative: Transform3D = body.global_transform.affine_inverse() * physics.hand.global_transform * (physics.hand.get("_model") as Node3D).transform
	_check((physics.hand.get("_model_to_fruit") as Transform3D).origin.distance_to(visible_relative.origin) < 0.005, "Finger contact fitting uses the actual visible tracked hand position")
	var local_offset: Vector3 = physics._vr_grab_offset
	var moved_pose: Transform3D = fixture_pose
	moved_pose.origin += Vector3(0.09, 0.015, 0)
	moved_pose.basis = Basis(Vector3.UP, 0.22) * moved_pose.basis
	_set_transform(contact_tracker, moved_pose)
	await _settle()
	var grip_node: XRController3D = rig.get_node("RightGrip") as XRController3D
	_check(physics._grab_target().distance_to(grip_node.to_global(local_offset)) < 0.001, "Turning and moving the controller transforms the stored contact offset")
	_check(physics.hand.global_transform.is_equal_approx(grip_node.global_transform), "Moving a held grape preserves the exact tracked wrist transform")
	# The fixture's bunch remains still so a newly integrated swing cannot move
	# between the throttled fit and the query itself.
	await get_tree().create_timer(0.20).timeout
	visible_relative = body.global_transform.affine_inverse() * physics.hand.global_transform * (physics.hand.get("_model") as Node3D).transform
	var fitted_relative: Transform3D = physics.hand.get("_model_to_fruit")
	_check(fitted_relative.origin.distance_to(visible_relative.origin) < 0.008, "Contact fitting refreshes after relative hand-to-fruit movement")
	_check(fitted_relative.basis.orthonormalized().get_rotation_quaternion().angle_to(visible_relative.basis.orthonormalized().get_rotation_quaternion()) < deg_to_rad(2.5), "Contact fitting uses the visible controller orientation within its refresh threshold")
	body.freeze = false
	XRServer.remove_tracker(contact_tracker)
	await _settle()
	_check(physics.grabbed_id.is_empty() and physics._vr_grab_offset == Vector3.ZERO, "Tracking loss clears both the grasp and stored contact offset")
	manager.end_session()
	app.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("[XRGraspQA] " + JSON.stringify({"checks": checks, "passed": failures.is_empty(), "failures": failures, "headset_tested": false}))
	get_tree().quit(0 if failures.is_empty() else 1)


func _tracker(tracker_name: String, at: Vector3) -> XRControllerTracker:
	var tracker: XRControllerTracker = XRControllerTracker.new()
	tracker.name = StringName(tracker_name)
	tracker.type = XRServer.TRACKER_CONTROLLER
	tracker.set_input(&"grip", 0.0)
	_set_pose(tracker, at)
	XRServer.add_tracker(tracker)
	return tracker


func _set_pose(tracker: XRControllerTracker, at: Vector3) -> void:
	tracker.set_pose(&"grip", Transform3D(Basis.IDENTITY, at), Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	tracker.set_pose(&"aim", Transform3D(Basis.IDENTITY, at + Vector3(1.4, 0, 0)), Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)


func _set_transform(tracker: XRControllerTracker, pose: Transform3D) -> void:
	tracker.set_pose(&"grip", pose, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	tracker.set_pose(&"aim", pose, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
