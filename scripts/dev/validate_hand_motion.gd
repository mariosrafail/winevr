extends Node

var checks: int = 0
var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error(description)

func _run() -> void:
	var app: Node = load("res://scenes/WineVRExperience.tscn").instantiate()
	get_tree().root.add_child(app)
	await get_tree().create_timer(2.0).timeout
	var winery: WineryInteriorController = app.get_node("WineryInterior")
	var museum: GrapeMuseum = winery.get("_grape_museum")
	var physics: MuseumPhysicsController = museum.physics
	(app.get("_main_menu") as MainMenuOverlayController).museum_button.pressed.emit()
	await get_tree().create_timer(2.0).timeout
	var body: RigidBody3D = physics._body("vidiano")
	var center: Vector3 = body.to_global(body.center_of_mass)
	winery.player_rig.global_position = Vector3(center.x, 0, center.z + 1.1)
	winery.camera.look_at(center, Vector3.UP)
	museum.inspect_exhibit("vidiano")
	await get_tree().create_timer(0.6).timeout
	var hand: MuseumGlove = physics.hand
	# Step the production animation at fixed frame rates, with a stationary
	# grape, so displacement/speed comparisons are independent of test hardware.
	physics.set_process(false)
	physics.set_physics_process(false)
	hand.set_process(false)
	body.freeze = true
	for fps in [30, 60, 144]:
		var dt: float = 1.0 / fps
		physics._hand_motion = "rest"
		physics._desktop_initialized = false
		physics._update_desktop_hand(dt)
		var start: Transform3D = hand.global_transform
		physics._pointer = winery.camera.unproject_position(body.to_global(body.center_of_mass))
		physics._pointer_valid = true
		_check(physics.begin_grab(), str(fps) + "fps: pointer starts the real grasp")
		_check(hand.global_transform.is_equal_approx(start), str(fps) + "fps: click cannot teleport the wrist")
		var goal: Transform3D = hand.grasp_transform()
		var previous: Transform3D = start
		var peak_speed: float = 0.0
		var first_step: float = 0.0
		for frame in range(ceili(physics._motion_duration * fps) + 1):
			physics._update_desktop_hand(dt)
			hand._process(dt)
			var distance: float = hand.global_position.distance_to(previous.origin)
			peak_speed = maxf(peak_speed, distance / dt)
			if frame == 0:
				first_step = distance
			if frame == int(fps * 0.1):
				_check(hand.grip_amount < 0.15, str(fps) + "fps: fingers stay open during early reach")
			previous = hand.global_transform
		_check(first_step < 0.008 and peak_speed < 4.5, str(fps) + "fps: reach starts gently and has bounded speed")
		_check(physics._hand_motion == "hold" and hand.global_position.distance_to(goal.origin) < 0.001, str(fps) + "fps: reach settles exactly on the berry")
		for frame in range(ceili(0.12 * fps)):
			physics._update_desktop_hand(dt)
			hand._process(dt)
		_check(hand.grip_amount > 0.98, str(fps) + "fps: fingers finish closing at contact")
		var release_pose: Transform3D = hand.global_transform
		physics.end_grab()
		_check(hand.global_transform.is_equal_approx(release_pose), str(fps) + "fps: release cannot teleport the wrist")
		for frame in range(floori(0.09 * fps)):
			physics._update_desktop_hand(dt)
			hand._process(dt)
		_check(hand.global_position.distance_to(release_pose.origin) < 0.001 and hand.grip_amount < 0.9, str(fps) + "fps: fingers open before the arm retreats")
		previous = hand.global_transform
		peak_speed = 0.0
		for frame in range(ceili(0.65 * fps)):
			physics._update_desktop_hand(dt)
			hand._process(dt)
			peak_speed = maxf(peak_speed, hand.global_position.distance_to(previous.origin) / dt)
			previous = hand.global_transform
		_check(physics._hand_motion == "rest" and hand.global_position.distance_to(start.origin) < 0.001 and peak_speed < 4.5, str(fps) + "fps: return decelerates into its original resting position")
		_check(hand.grip_amount < 0.01, str(fps) + "fps: resting hand is relaxed")
		physics.begin_grab()
		physics._update_desktop_hand(0.11)
		var interrupted: Transform3D = hand.global_transform
		physics.end_grab()
		_check(hand.global_transform.is_equal_approx(interrupted), str(fps) + "fps: releasing mid-reach preserves the current pose")
		physics._update_desktop_hand(0.02)
		var regrab: Transform3D = hand.global_transform
		physics.begin_grab()
		_check(hand.global_transform.is_equal_approx(regrab), str(fps) + "fps: grabbing again retargets from the current pose")
		physics.end_grab()
		physics._update_desktop_hand(0.7)
		hand._process(0.7)
	app.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("[HandMotionQA] " + JSON.stringify({"checks": checks, "passed": failures.is_empty(), "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
