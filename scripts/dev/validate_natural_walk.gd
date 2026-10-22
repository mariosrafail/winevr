extends SceneTree

var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error(description)

func _run() -> void:
	var rig: Node3D = Node3D.new()
	root.add_child(rig)
	var pivot: Node3D = Node3D.new()
	rig.add_child(pivot)
	pivot.position.y = 1.6
	var movement: WineryMovementController = WineryMovementController.new()
	movement.setup(rig, pivot, 2.4, 0.005, -75, 75)
	movement.configure_bounds(Vector2(-20, -20), Vector2(20, 20))
	movement.enable_natural_walk()
	movement.set_controls_enabled(true)
	var audio: Node = load("res://scripts/components/footstep_audio.gd").new()
	root.add_child(audio)
	var step_counts: Dictionary = {"steps": 0, "stops": 0}
	movement.footstep.connect(func(strength: float) -> void:
		step_counts["steps"] += 1
		audio.play_step(strength)
	)
	movement.walking_stopped.connect(func() -> void:
		step_counts["stops"] += 1
		audio.stop()
	)
	var distances: Array[float] = []
	for hz in [30, 60, 120]:
		rig.position = Vector3.ZERO
		rig.rotation = Vector3.ZERO
		movement.reset_motion()
		movement.mobile_move_vector = Vector2(0, 1)
		var dt: float = 1.0 / float(hz)
		movement.physics_update(dt)
		var initial_speed: float = movement._walk_velocity.length()
		_check(initial_speed > 0 and initial_speed < 0.25, "Walking starts gently at %s Hz" % hz)
		var peak_sway: float = 0.0
		for tick in range(hz - 1):
			movement.physics_update(dt)
			movement.update_view(dt, true)
			peak_sway = maxf(peak_sway, pivot.position.distance_to(Vector3(0, 1.6, 0)))
		distances.append(-rig.position.z)
		_check(peak_sway > 0.002 and peak_sway < 0.015, "Step sway stays subtle at %s Hz" % hz)
		var stop_start: Vector3 = rig.position
		var steps_before_stop: int = step_counts["steps"]
		_check(steps_before_stop >= 1, "Walking triggers recorded footstep samples")
		movement.mobile_move_vector = Vector2.ZERO
		for tick in range(hz):
			movement.physics_update(dt)
			movement.update_view(dt, true)
		_check(stop_start.distance_to(rig.position) < 0.20 and movement._walk_velocity.is_zero_approx(), "Release brakes promptly without drifting at %s Hz" % hz)
		_check(pivot.position.distance_to(Vector3(0, 1.6, 0)) < 0.0001, "Camera settles after stopping at %s Hz" % hz)
		_check(step_counts["steps"] == steps_before_stop and not audio.player.playing, "Footstep playback stops on key release at %s Hz" % hz)
	_check(absf(distances.max() - distances.min()) < 0.04, "Walking pace is consistent across frame rates")
	movement.configure_bounds(Vector2(-1, -1), Vector2(1, 1))
	rig.position = Vector3(0, 0, -1)
	movement.mobile_move_vector = Vector2(0, 1)
	var blocked_steps: int = step_counts["steps"]
	for tick in range(60):
		movement.physics_update(1.0 / 60.0)
		movement.update_view(1.0 / 60.0, true)
	_check(is_equal_approx(rig.position.z, -1.0) and pivot.position.distance_to(Vector3(0, 1.6, 0)) < 0.0001, "A blocked walk does not produce camera bob")
	_check(step_counts["steps"] == blocked_steps and not audio.player.playing, "A blocked walk stays silent")
	movement.apply_look_drag(Vector2(100, 0))
	movement.update_view(1.0 / 60.0, true)
	_check(absf(rig.rotation.y) > 0 and absf(rig.rotation.y) < 0.26, "Mouse look eases into the requested turn")
	for tick in range(60):
		movement.update_view(1.0 / 60.0, true)
	_check(absf(rig.rotation.y + 0.26) < 0.0001, "Smoothed look preserves the full mouse rotation")
	movement.apply_look_drag(Vector2(30, 30))
	movement.update_view(1.0 / 60.0, false)
	_check(movement._pending_look.is_zero_approx() and movement._walk_velocity.is_zero_approx() and pivot.position.is_equal_approx(Vector3(0, 1.6, 0)), "Inspection or menu clears motion and keeps the camera steady")
	audio.stop()
	rig.queue_free()
	audio.queue_free()
	movement = null
	await process_frame
	await create_timer(0.05).timeout
	print("[NaturalWalkQA] checks=%s failures=%s" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
