extends Node3D
class_name MuseumPhysicsController

const GLOVE_SCRIPT: Script = preload("res://scripts/winery/museum_glove.gd")
var museum: GrapeMuseum
var winery: WineryInteriorController
var hand: MuseumGlove
var left_hand: MuseumGlove
var inspecting_id: String = ""
var grabbed_id: String = ""
var _grab_local: Vector3
var _drag: Vector2 = Vector2.ZERO
var _grab_distance: float = 0.8
var _inspect_distance: float = 1.1
var _transition: Tween
var _transitioning: bool = false
var _rotate_mouse: bool = false
var _vr_grab: bool = false
var _last_grip: bool = false
var _vr_grip_controller: XRController3D
var _vr_grab_controller: XRController3D
var _vr_grab_offset: Vector3 = Vector3.ZERO
var _grasp_hand: MuseumGlove
var _pointer: Vector2
var _pointer_valid: bool = false
var _hand_motion: String = "rest"
var _motion_time: float = 0.0
var _motion_duration: float = 0.45
var _motion_from: Transform3D
var _desktop_initialized: bool = false
var _berry_owner: Node3D
var _berry_index: int = -1
var _loose_berry: RigidBody3D
var _berry_pull_time: float = 0.0
var berry_tension: float = 0.0
var _berry_drag_origin: Vector3
var _berry_rotate_mouse: bool = false
var _berry_rotation_pending: Vector2 = Vector2.ZERO
var _berry_hold_goal: Vector3
var _berry_has_hold_goal: bool = false
var room_demo: bool = false
var demo_turn: float = 0.0
var _demo_yaw_target: float = 0.0
var _demo_yaw_speed: float = 0.0
var _demo_yaw: float = 0.0
var _demo_bounds: AABB
var demo_returning_id: String = ""
var demo_panel_reveal: float = 0.0
var _demo_zoom: float = 1.0
var _demo_zoom_target: float = 1.0

func demo_zoom(factor: float) -> void:
	if room_demo and not inspecting_id.is_empty() and not _transitioning:
		_demo_zoom_target = clampf(_demo_zoom_target * factor, 0.75, 1.60)

func _animate_demo_flight(body: RigidBody3D, target: Transform3D, opening: bool) -> void:
	var start: Transform3D = body.global_transform
	_transition.set_parallel(true)
	_transition.tween_method(func(progress: float) -> void:
		var pose: Transform3D = start.interpolate_with(target, progress)
		pose.origin += camera().global_basis.y * sin(progress * PI) * 0.06
		body.global_transform = pose
	, 0.0, 1.0, 0.65).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	_transition.tween_property(self, "demo_panel_reveal", 1.0 if opening else 0.0, 0.32).set_delay(0.20 if opening else 0.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func demo_rotate(degrees: float) -> void:
	if room_demo and not inspecting_id.is_empty() and not _transitioning:
		_demo_yaw_target += deg_to_rad(degrees)

func _update_room_demo(delta: float) -> void:
	if inspecting_id.is_empty() or _transitioning:
		return
	if not museum.controls_enabled:
		_body(inspecting_id).angular_velocity = Vector3.ZERO
		_demo_yaw_speed = 0.0
		return
	var body: RigidBody3D = _body(inspecting_id)
	body.freeze = true
	_demo_zoom = lerpf(_demo_zoom, _demo_zoom_target, 1.0 - exp(-14.0 * delta))
	_demo_yaw_target += demo_turn * delta * 1.1
	var error: float = wrapf(_demo_yaw_target - _demo_yaw, -PI, PI)
	_demo_yaw_speed = move_toward(_demo_yaw_speed, clampf(error * 8.0, -1.4, 1.4), delta * 5.0)
	_demo_yaw += _demo_yaw_speed * delta
	body.angular_velocity = camera().global_basis.y * _demo_yaw_speed
	body.global_transform = _inspect_transform()

func _measure_demo_bounds(body: Node3D) -> AABB:
	var bounds: AABB
	var initialized: bool = false
	for node in body.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		var local: Transform3D = body.global_transform.affine_inverse() * mesh.global_transform
		for index in range(8):
			var point: Vector3 = local * mesh.get_aabb().get_endpoint(index)
			bounds = bounds.expand(point) if initialized else AABB(point, Vector3.ZERO)
			initialized = true
	return bounds

func is_holding_berry() -> bool:
	return _berry_owner != null or is_instance_valid(_loose_berry)

func _begin_berry_grab(hit: Dictionary) -> bool:
	var hit_body: RigidBody3D = hit.get("collider") as RigidBody3D
	if hit_body == null or camera().global_position.distance_to(hit.get("position", camera().global_position)) > 1.7:
		return false
	var springs: Node3D = hit_body.get_node_or_null("BerryPhysics")
	var index: int = springs.berry_for_shape(int(hit["shape"])) if springs != null else -1
	if index < 0 and not hit_body.has_meta("detached_berry"):
		return false
	end_grab()
	var point: Vector3 = hit_body.global_position
	if index >= 0:
		_berry_owner = springs
		_berry_index = index
		point = springs.berry_position(index)
	else:
		_loose_berry = hit_body
	var local: Vector3 = camera().to_local(point)
	_drag = Vector2(local.x, local.y)
	_grab_distance = clampf(-local.z, 0.20, 1.7)
	_berry_drag_origin = Vector3(_drag.x, _drag.y, -_grab_distance)
	_berry_pull_time = 0.0
	berry_tension = 0.0
	if index >= 0:
		var axis: Vector3 = (camera().global_basis * Basis.from_euler(Vector3(0.90, -0.15, -0.35))).x
		var radii: Vector2 = springs.pinch_radii(index, axis)
		hand.start_pinch(radii.x, radii.y)
		hand.set_pinch_surface(springs.pinch_mesh(index), springs.pinch_mesh_transform(index))
	else:
		hand.start_pinch((hit_body.get_child(0) as CollisionShape3D).shape.radius)
		var mesh: MeshInstance3D = hit_body.get_child(1) as MeshInstance3D
		hand.set_pinch_surface(mesh.mesh, mesh.global_transform)
		hit_body.angular_damp = 12.0
	_hand_motion = "reach"
	_motion_time = 0.0
	_motion_from = camera().global_transform.affine_inverse() * hand.global_transform
	_motion_duration = clampf(hand.global_position.distance_to(point) / 2.2, 0.30, 0.50)
	hand.grip_target = 0.0
	return true

func _update_berry_grab(delta: float) -> void:
	if not is_holding_berry():
		return
	var goal: Vector3 = camera().to_global(Vector3(_drag.x, _drag.y, -_grab_distance))
	# The fingers must reach and close before they can pull the pedicel.
	if _hand_motion == "reach" or hand.grip_amount < 0.95:
		return
	if _berry_owner != null:
		var travel: Vector3 = Vector3(_drag.x, _drag.y, -_grab_distance) - _berry_drag_origin
		var rest: Vector3 = _berry_owner.body.to_global(_berry_owner.berries[_berry_index]["rest"])
		goal = rest + camera().global_basis * travel
		var extension: float = _berry_owner.pull_berry(_berry_index, goal, delta)
		var radius: float = _berry_owner.berries[_berry_index]["radius"]
		var threshold: float = maxf(0.045, radius * 1.8)
		if extension > threshold and travel.length() > threshold:
			_berry_pull_time += delta
		else:
			_berry_pull_time = maxf(0.0, _berry_pull_time - delta * 3.0)
		berry_tension = clampf(_berry_pull_time / 0.30, 0.0, 1.0)
		if _berry_pull_time >= 0.30:
			_loose_berry = _berry_owner.detach_berry(_berry_index)
			_loose_berry.angular_damp = 12.0
			_berry_owner = null
			_berry_index = -1
	if is_instance_valid(_loose_berry):
		if not _berry_has_hold_goal:
			_berry_hold_goal = camera().to_local(_loose_berry.global_position)
			_berry_has_hold_goal = true
		var requested: Vector3 = Vector3(_drag.x, _drag.y, -_grab_distance)
		_berry_hold_goal = _berry_hold_goal.lerp(requested, 1.0 - exp(-delta * 9.0))
		goal = camera().to_global(_berry_hold_goal)
		var spin: Vector3 = camera().global_basis * Vector3(-_berry_rotation_pending.y, -_berry_rotation_pending.x, 0.0) * 0.010 / maxf(delta, 0.001)
		_loose_berry.angular_velocity = _loose_berry.angular_velocity.lerp(spin.limit_length(3.5), 1.0 - exp(-delta * 18.0))
		_berry_rotation_pending = Vector2.ZERO
		var stiffness: float = 12.0
		var damping: float = 1.8 * sqrt(stiffness * _loose_berry.mass)
		var force: Vector3 = (goal - _loose_berry.global_position) * stiffness - _loose_berry.linear_velocity * damping
		_loose_berry.sleeping = false
		_loose_berry.apply_central_force(force.limit_length(1.5) + Vector3.UP * _loose_berry.mass * 9.81)

func setup(owner_museum: GrapeMuseum, owner_winery: WineryInteriorController) -> void:
	museum = owner_museum
	winery = owner_winery
	room_demo = bool(winery.get_meta("room_demo", false))
	if room_demo:
		for id in museum.exhibit_nodes:
			_attach_joint(str(id))
		return
	hand = GLOVE_SCRIPT.new() as MuseumGlove
	hand.name = "MuseumRightHand"
	add_child(hand)
	left_hand = GLOVE_SCRIPT.new() as MuseumGlove
	left_hand.name = "MuseumLeftHand"
	left_hand.is_left = true
	add_child(left_hand)
	for id in museum.exhibit_nodes:
		_attach_joint(str(id))
		hand.prepare_grasp(_body(str(id)))

func camera() -> Camera3D:
	return winery.vr_camera if winery.is_vr_active() else winery.camera

func _tracked_grip(side: String) -> XRController3D:
	if winery.vr_player_rig == null:
		return null
	var grip: XRController3D = winery.vr_player_rig.get_node_or_null(side + "Grip") as XRController3D
	if grip != null and grip.get_has_tracking_data():
		return grip
	var aim: XRController3D = winery.vr_right_controller if side == "Right" else winery.vr_left_controller
	return aim if aim != null and aim.get_has_tracking_data() else null

func _preferred_grip() -> XRController3D:
	var right: XRController3D = _tracked_grip("Right")
	return right if right != null else _tracked_grip("Left")

func _glove_for_controller(controller: XRController3D) -> MuseumGlove:
	return hand if controller == _tracked_grip("Right") else left_hand

func _process(delta: float) -> void:
	if hand != null and winery != null and hand.visible and not winery.is_vr_active():
		if _berry_owner != null:
			hand.pinch_surface_transform = _berry_owner.pinch_mesh_transform(_berry_index)
		elif is_instance_valid(_loose_berry):
			hand.pinch_surface_transform = (_loose_berry.get_child(1) as MeshInstance3D).global_transform
		_update_desktop_hand(delta)
	if hand != null and winery != null:
		if winery.is_vr_active():
			_desktop_initialized = false
			_hand_motion = "rest"
			_motion_time = 0.0
		hand.update_arm(camera(), winery.is_vr_active())
		left_hand.update_arm(camera(), winery.is_vr_active())

func _ease_motion(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * t * (t * (6.0 * t - 15.0) + 10.0)

func _update_desktop_hand(delta: float) -> void:
	var view: Camera3D = camera()
	var rest: Transform3D = Transform3D(Basis.from_euler(Vector3(0.20, -0.60, -0.20)), Vector3(0.24, -0.23, -0.48))
	hand.sync_to_physics = false
	if not _desktop_initialized:
		hand.global_transform = view.global_transform * rest
		_desktop_initialized = true
	var local_target: Transform3D = rest
	if is_holding_berry():
		var point: Vector3 = _berry_owner.berry_position(_berry_index) if _berry_owner != null else _loose_berry.global_position
		local_target = view.global_transform.affine_inverse() * hand.pinch_transform(point, view)
	elif not grabbed_id.is_empty():
		local_target = view.global_transform.affine_inverse() * hand.grasp_transform()
	_motion_time += delta
	if _hand_motion == "reach" or _hand_motion == "return":
		var t: float = clampf(_motion_time / _motion_duration, 0.0, 1.0)
		var progress: float = _ease_motion(t)
		# On release the pads open before the arm retreats. The path and wrist
		# rotation start and end at zero speed, including an interrupted reach.
		if _hand_motion == "return":
			progress = _ease_motion((_motion_time - 0.10) / (_motion_duration - 0.10))
		var pose: Transform3D = _motion_from.interpolate_with(local_target, progress)
		pose.origin.z += 0.035 * 16.0 * progress * progress * (1.0 - progress) * (1.0 - progress)
		hand.global_transform = view.global_transform * pose
		hand.grip_target = smoothstep(0.55, 0.94, t) if _hand_motion == "reach" else 0.0
		if t >= 1.0:
			_hand_motion = "hold" if is_holding_berry() or not grabbed_id.is_empty() else "rest"
	elif _hand_motion == "hold" and (is_holding_berry() or not grabbed_id.is_empty()):
		hand.global_transform = view.global_transform * local_target
		hand.grip_target = 1.0
	else:
		hand.global_transform = hand.global_transform.interpolate_with(view.global_transform * rest, 1.0 - exp(-delta * 9.0))
		hand.grip_target = 0.0

func _physics_process(delta: float) -> void:
	if museum == null or winery == null:
		return
	if room_demo:
		_update_room_demo(delta)
		return
	var active: bool = museum.controls_enabled and museum.is_visible_in_tree()
	var right_grip: XRController3D = _tracked_grip("Right") if winery.is_vr_active() else null
	var left_grip: XRController3D = _tracked_grip("Left") if winery.is_vr_active() else null
	hand.visible = active and (not winery.is_vr_active() or right_grip != null)
	left_hand.visible = active and winery.is_vr_active() and left_grip != null
	hand.collision_layer = 16 if hand.visible else 0
	if not winery.is_vr_active() and (_hand_motion in ["reach", "return"] or is_holding_berry()):
		hand.collision_layer = 0
	hand.collision_mask = 4 if hand.collision_layer != 0 else 0
	left_hand.collision_layer = 16 if left_hand.visible else 0
	if not active:
		end_grab()
		_rotate_mouse = false
		_last_grip = false
		_vr_grip_controller = null
		if not museum.is_visible_in_tree():
			close_inspection(true)
		if not inspecting_id.is_empty() and not _transitioning:
			_body(inspecting_id).freeze = true
		return
	var view: Camera3D = camera()
	if view == null:
		return
	_update_berry_grab(delta)
	var target: Transform3D = view.global_transform * Transform3D(Basis.from_euler(Vector3(0.20, -0.60, -0.20)), Vector3(0.24, -0.23, -0.48))
	if winery.is_vr_active():
		_update_vr_grip()
		if right_grip != null:
			target = right_grip.global_transform
		if left_grip != null:
			left_hand.global_transform = left_grip.global_transform
	if not grabbed_id.is_empty():
		var body: RigidBody3D = _body(grabbed_id)
		var goal: Vector3 = _grab_target()
		var point: Vector3 = body.to_global(_grab_local)
		var center: Vector3 = body.to_global(body.center_of_mass)
		var velocity: Vector3 = body.linear_velocity + body.angular_velocity.cross(point - center)
		var force: Vector3 = ((goal - point) * 24.0 - velocity * 3.0).limit_length(3.5)
		if not _vr_grab and _hand_motion == "reach":
			force *= smoothstep(0.85, 1.0, _motion_time / _motion_duration)
		body.sleeping = false
		body.apply_force(force, point - body.global_position)
		var berry_physics: Node3D = body.get_node_or_null("BerryPhysics")
		if berry_physics != null:
			berry_physics.apply_contact_force(point, force)
		if not _vr_grab:
			target = hand.grasp_transform()
	if winery.is_vr_active():
		hand.grip_target = 1.0 if not grabbed_id.is_empty() and _grasp_hand == hand else 0.0
	left_hand.grip_target = 1.0 if not grabbed_id.is_empty() and _grasp_hand == left_hand else 0.0
	if winery.is_vr_active():
		hand.global_transform = target
	if not inspecting_id.is_empty():
		var entry: Dictionary = museum.exhibit_nodes[inspecting_id]
		var panel: Node3D = entry["panel"] as Node3D
		var show_world_panel: bool = not uses_portrait_inspector()
		if panel.visible != show_world_panel:
			_set_panel_visible(panel, show_world_panel)
		panel.global_transform = view.global_transform * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.58), Vector3(0.53, -0.015, -_inspect_distance))
		if not _transitioning:
			var body: RigidBody3D = _body(inspecting_id)
			body.freeze = false
			var goal: Vector3 = _inspect_transform().origin
			body.apply_central_force(((goal - body.global_position) * 34.0 - body.linear_velocity * 7.0).limit_length(14.0))

func _unhandled_input(event: InputEvent) -> void:
	if room_demo:
		return
	if museum == null or not museum.controls_enabled or not museum.is_visible_in_tree() or winery.is_vr_active():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		end_grab()
		for entry: Dictionary in museum.exhibit_nodes.values():
			(entry["pivot"] as RigidBody3D).get_node("BerryPhysics").restore_berries()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouse:
		_pointer = event.position
		_pointer_valid = true
	if event is InputEventMouseButton:
		if is_holding_berry() and event.button_index == MOUSE_BUTTON_RIGHT:
			_berry_rotate_mouse = event.pressed and is_instance_valid(_loose_berry)
			get_viewport().set_input_as_handled()
			return
		if is_holding_berry() and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if is_instance_valid(_loose_berry):
				var old_distance: float = _grab_distance
				_grab_distance = clampf(old_distance * (0.85 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 0.85), 0.28, 1.7)
				# Preserve the berry's screen position as it comes towards the eye.
				_drag *= _grab_distance / maxf(old_distance, 0.01)
			else:
				_grab_distance = clampf(_grab_distance + (-0.06 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.06), 0.20, 1.7)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if not inspecting_id.is_empty() and _click_profile_action():
					get_viewport().set_input_as_handled()
					return
				begin_grab(false, not event.shift_pressed)
			else:
				end_grab()
			if is_holding_berry() or not grabbed_id.is_empty() or not event.pressed:
				get_viewport().set_input_as_handled()
		elif not inspecting_id.is_empty():
			if event.button_index == MOUSE_BUTTON_RIGHT:
				_rotate_mouse = event.pressed
			elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				_inspect_distance = clampf(_inspect_distance + (-0.08 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.08), 0.80, 1.40)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if is_holding_berry():
			if _berry_rotate_mouse and is_instance_valid(_loose_berry):
				_berry_rotation_pending += event.relative
			else:
				var sensitivity: float = 0.0016 * minf(1.0, _grab_distance) if is_instance_valid(_loose_berry) else 0.0016
				_drag += event.relative * Vector2(sensitivity, -sensitivity)
				_drag = _drag.clamp(Vector2(-1.2, -0.9), Vector2(1.2, 0.9))
			get_viewport().set_input_as_handled()
		elif not grabbed_id.is_empty():
			_drag += event.relative * Vector2(0.0016, -0.0016)
			_drag = _drag.clamp(Vector2(-0.55, -0.40), Vector2(0.55, 0.45))
			get_viewport().set_input_as_handled()
		elif not inspecting_id.is_empty():
			if _rotate_mouse and not _transitioning:
				_body(inspecting_id).apply_torque_impulse(camera().global_basis * Vector3(-event.relative.y, -event.relative.x, 0) * 0.00035)
			get_viewport().set_input_as_handled()

func _inspect_transform() -> Transform3D:
	if room_demo:
		# Frame the mesh center, rather than its stem/suspension origin.
		var size: Vector2 = get_viewport().get_visible_rect().size
		var span: float = camera().project_position(Vector2(size.x * 0.33, size.y * 0.16), 1.0).distance_to(camera().project_position(Vector2(size.x * 0.33, size.y * 0.84), 1.0))
		var distance: float = maxf(0.72, (_demo_bounds.size.y / maxf(span, 0.01) + _demo_bounds.size.length() * 0.25) / 1.18)
		var basis: Basis = camera().global_basis * Basis(Vector3.UP, _demo_yaw)
		var center: Vector3 = camera().project_position(Vector2(size.x * 0.33, size.y * 0.50), distance / _demo_zoom)
		return Transform3D(basis, center - basis * _demo_bounds.get_center())
	if uses_portrait_inspector():
		var size: Vector2 = get_viewport().get_visible_rect().size
		var panel_top: float = size.y - 152 - minf(360.0, size.y * 0.43)
		var center_pixel: Vector2 = Vector2(size.x * 0.5, (90 + panel_top) * 0.5)
		var body: RigidBody3D = _body(inspecting_id)
		if not body.has_meta("portrait_model_bounds"):
			var bounds: AABB
			var has_bounds: bool = false
			for node in body.find_children("*", "MeshInstance3D", true, false):
				var mesh: MeshInstance3D = node as MeshInstance3D
				var local_transform: Transform3D = body.global_transform.affine_inverse() * mesh.global_transform
				for index in range(8):
					var point: Vector3 = local_transform * mesh.get_aabb().get_endpoint(index)
					if not has_bounds:
						bounds = AABB(point, Vector3.ZERO)
						has_bounds = true
					else:
						bounds = bounds.expand(point)
			body.set_meta("portrait_model_bounds", bounds)
		var bounds: AABB = body.get_meta("portrait_model_bounds") as AABB
		# Fit the complete bunch and leaf into the actual gap on short phones.
		# project_position respects the active camera's aspect/FOV convention.
		var top_ray: Vector3 = camera().project_position(Vector2(size.x * 0.5, 96), 1.0)
		var bottom_ray: Vector3 = camera().project_position(Vector2(size.x * 0.5, maxf(104, panel_top - 6)), 1.0)
		var vertical_span: float = maxf(0.02, top_ray.distance_to(bottom_ray))
		var distance: float = maxf(1.85, bounds.size.y / vertical_span + bounds.size.z * 0.5)
		var target: Vector3 = camera().project_position(center_pixel, distance)
		return Transform3D(camera().global_basis, target - camera().global_basis * bounds.get_center())
	return camera().global_transform * Transform3D(Basis.IDENTITY, Vector3(-0.24, 0.34, -_inspect_distance))


func uses_portrait_inspector() -> bool:
	if winery == null or winery.is_vr_active():
		return false
	var size: Vector2 = get_viewport().get_visible_rect().size
	return size.x < 720 and size.y > size.x and (DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or "--touch-ui" in OS.get_cmdline_user_args())

func inspect(id: String) -> void:
	if id == inspecting_id:
		return
	if not inspecting_id.is_empty():
		close_inspection(true)
	end_grab()
	inspecting_id = id
	if not winery.is_vr_active():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_inspect_distance = 1.1
	var entry: Dictionary = museum.exhibit_nodes[id]
	var body: RigidBody3D = _body(id)
	_detach_joint(id)
	if room_demo:
		winery._movement.reset_motion()
		var demo_panel: Node3D = entry["panel"]
		for index in range(3):
			(demo_panel.get_node("museum_" + id + "_turn_" + str(index)) as Node3D).hide()
		_demo_bounds = _measure_demo_bounds(body)
		_demo_yaw = 0.0
		_demo_yaw_target = 0.0
		_demo_zoom = 1.0
		_demo_zoom_target = 1.0
		body.set_meta("demo_inspection", true)
		_demo_yaw_speed = 0.0
		demo_turn = 0.0
		body.axis_lock_angular_x = true
		body.axis_lock_angular_z = true
	body.freeze = true
	body.gravity_scale = 0.0
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.linear_damp = 3.0
	body.angular_damp = 3.0
	_set_panel_visible(entry["panel"] as Node3D, true)
	_transitioning = true
	_transition = create_tween()
	if room_demo:
		demo_panel_reveal = 0.0
		_animate_demo_flight(body, _inspect_transform(), true)
	else:
		_transition.tween_property(body, "global_transform", _inspect_transform(), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transition.finished.connect(func() -> void:
		_transitioning = false
		if inspecting_id == id:
			body.freeze = room_demo
	)

func close_inspection(immediate: bool = false) -> bool:
	if inspecting_id.is_empty():
		return false
	var id: String = inspecting_id
	inspecting_id = ""
	end_grab()
	_rotate_mouse = false
	if _transition != null and _transition.is_valid():
		_transition.kill()
	var entry: Dictionary = museum.exhibit_nodes[id]
	if room_demo and not immediate:
		demo_returning_id = id
		for collider in (entry["panel"] as Node3D).find_children("*", "CollisionObject3D", true, false):
			collider.collision_layer = 0
	else:
		_set_panel_visible(entry["panel"] as Node3D, false)
	var body: RigidBody3D = _body(id)
	body.set_meta("demo_inspection", false)
	body.freeze = true
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	var home: Transform3D = entry["home"]
	_transitioning = true
	if immediate:
		body.global_transform = home
		_finish_return(id)
	else:
		_transition = create_tween()
		if room_demo:
			_animate_demo_flight(body, home, false)
		else:
			_transition.tween_property(body, "global_transform", home, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_transition.finished.connect(func() -> void: _finish_return(id))
	return true

func _finish_return(id: String) -> void:
	var body: RigidBody3D = _body(id)
	if room_demo:
		demo_returning_id = ""
		demo_panel_reveal = 0.0
		_set_panel_visible(museum.exhibit_nodes[id]["panel"], false)
		body.axis_lock_angular_x = false
		body.axis_lock_angular_z = false
		demo_turn = 0.0
		_demo_yaw_speed = 0.0
	body.gravity_scale = 1.0
	body.linear_damp = 0.8
	body.angular_damp = 1.2
	_attach_joint(id)
	body.freeze = false
	body.sleeping = false
	_transitioning = false
	if museum.controls_enabled and not winery.is_vr_active() and bool(winery.get("_exploration_mode_active")):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func begin_grab(vr: bool = false, individual: bool = false) -> bool:
	if room_demo or not museum.controls_enabled or _transitioning:
		return false
	var id: String = ""
	var point: Vector3
	var controller: XRController3D
	if vr:
		var grip: XRController3D = _preferred_grip()
		if grip == null:
			return false
		controller = grip
		var best_distance: float = 0.30
		for key in museum.exhibit_nodes:
			var body: RigidBody3D = _body(str(key))
			var center: Vector3 = body.to_global(body.center_of_mass)
			var distance: float = center.distance_to(grip.global_position)
			if distance < best_distance:
				best_distance = distance
				id = str(key)
				point = center
	else:
		var hit: Dictionary = _view_ray(4)
		if individual:
			return _begin_berry_grab(hit)
		var collider: Node = hit.get("collider") as Node
		while collider != null:
			if collider.has_meta("museum_exhibit"):
				id = str(collider.get_meta("museum_exhibit"))
				break
			collider = collider.get_parent()
		if not id.is_empty():
			point = hit["position"]
			if camera().global_position.distance_to(point) > 1.7:
				return false
	if id.is_empty():
		return false
	end_grab()
	grabbed_id = id
	_vr_grab = vr
	_vr_grab_controller = controller
	_grasp_hand = _glove_for_controller(controller) if vr else hand
	_grasp_hand.sync_to_physics = vr
	if vr:
		# Preserve the real contact offset instead of pulling the bunch's center
		# into the tracked palm on the first squeeze.
		_grasp_hand.global_transform = controller.global_transform
		_vr_grab_offset = controller.to_local(point)
	_grab_local = _body(id).to_local(point)
	_grasp_hand.start_grasp(_body(id), _grab_local, camera(), vr)
	if not vr:
		_hand_motion = "reach"
		_motion_time = 0.0
		_motion_from = camera().global_transform.affine_inverse() * hand.global_transform
		_motion_duration = clampf(hand.global_position.distance_to(hand.grasp_transform().origin) / 1.9, 0.34, 0.52)
		hand.grip_target = 0.0
	var local: Vector3 = camera().to_local(point)
	_grab_distance = clampf(-local.z, 0.35, 1.7)
	_drag = Vector2(local.x, local.y)
	return true

func _view_ray(mask: int) -> Dictionary:
	var view: Camera3D = camera()
	var pixel: Vector2 = get_viewport().get_visible_rect().size * 0.5 if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else (_pointer if _pointer_valid else get_viewport().get_mouse_position())
	var origin: Vector3 = view.project_ray_origin(pixel)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + view.project_ray_normal(pixel) * 2.5, mask)
	query.collide_with_areas = mask == 1
	query.collide_with_bodies = mask == 4
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if mask != 4 or not hit.is_empty():
		return hit
	# Small falling fruit can travel more than its radius between an input
	# event and the next physics sync. Pick its displayed transform as well.
	var direction: Vector3 = view.project_ray_normal(pixel)
	var nearest: float = 2.5
	for entry: Dictionary in museum.exhibit_nodes.values():
		var springs: Node3D = (entry["pivot"] as RigidBody3D).get_node("BerryPhysics")
		for berry: Dictionary in springs.berries:
			var loose: RigidBody3D = berry["loose_body"] as RigidBody3D
			if not is_instance_valid(loose) or not loose.is_visible_in_tree():
				continue
			var along: float = direction.dot(loose.global_position - origin)
			if along > 0.0 and along < nearest and (origin + direction * along).distance_to(loose.global_position) <= float(berry["radius"]) * 1.25:
				nearest = along
				hit = {"collider": loose, "position": loose.global_position, "shape": 0}
	return hit

func _click_profile_action() -> bool:
	var hit: Dictionary = _view_ray(1)
	var node: Node = hit.get("collider") as Node
	while node != null:
		if node is Interactable and node.has_meta("museum_action"):
			(node as Interactable).interact()
			return true
		node = node.get_parent()
	return false

func end_grab() -> void:
	var was_holding_berry: bool = is_holding_berry()
	if is_instance_valid(_loose_berry):
		_loose_berry.angular_damp = 0.4
	if _berry_owner != null:
		_berry_owner.release_berry(_berry_index)
	_berry_owner = null
	_berry_index = -1
	_loose_berry = null
	_berry_pull_time = 0.0
	berry_tension = 0.0
	_berry_rotate_mouse = false
	_berry_rotation_pending = Vector2.ZERO
	_berry_has_hold_goal = false
	_rotate_mouse = false
	if (was_holding_berry or not grabbed_id.is_empty()) and not _vr_grab and hand != null:
		_hand_motion = "return"
		_motion_time = 0.0
		_motion_duration = 0.56
		_motion_from = camera().global_transform.affine_inverse() * hand.global_transform
	grabbed_id = ""
	_vr_grab = false
	_vr_grab_controller = null
	_vr_grab_offset = Vector3.ZERO
	_grasp_hand = null
	for glove: MuseumGlove in [hand, left_hand]:
		if glove != null:
			glove.release_grasp()
			glove.sync_to_physics = winery.is_vr_active()

func _grab_target() -> Vector3:
	if _vr_grab:
		if _vr_grab_controller != null and _vr_grab_controller.get_has_tracking_data():
			return _vr_grab_controller.to_global(_vr_grab_offset)
		return _body(grabbed_id).to_global(_grab_local)
	return camera().to_global(Vector3(_drag.x, _drag.y, -_grab_distance))

func _update_vr_grip() -> void:
	var controller: XRController3D = _preferred_grip()
	if controller != _vr_grip_controller:
		if _vr_grab:
			end_grab()
		_vr_grip_controller = controller
		# A handover is a release, never a transfer of the fruit to a new hand.
		# Require a fresh squeeze if tracking starts with an already-held grip.
		_last_grip = _grip_pressed(controller, false) if controller != null else false
		return
	if controller == null:
		if _vr_grab:
			end_grab()
		_last_grip = false
		return
	var grip: bool = _grip_pressed(controller, _last_grip)
	if grip and not _last_grip:
		begin_grab(true)
	elif not grip and _last_grip:
		end_grab()
	_last_grip = grip

func _grip_pressed(controller: XRController3D, was_pressed: bool) -> bool:
	var squeeze: float = maxf(controller.get_float(&"grip"), controller.get_float(&"squeeze"))
	return squeeze > (0.2 if was_pressed else 0.55) or controller.is_button_pressed(&"grip_click") or controller.is_button_pressed(&"squeeze_click")

func _body(id: String) -> RigidBody3D:
	return museum.exhibit_nodes[id]["pivot"] as RigidBody3D

func _attach_joint(id: String) -> void:
	var entry: Dictionary = museum.exhibit_nodes[id]
	var body: RigidBody3D = _body(id)
	var anchor: StaticBody3D = entry["anchor"] as StaticBody3D
	var joint: PinJoint3D = PinJoint3D.new()
	joint.name = "StemPin_" + id
	add_child(joint)
	joint.global_position = anchor.global_position
	joint.node_a = joint.get_path_to(anchor)
	joint.node_b = joint.get_path_to(body)
	joint.exclude_nodes_from_collision = true
	entry["joint"] = joint

func _detach_joint(id: String) -> void:
	var entry: Dictionary = museum.exhibit_nodes[id]
	var joint: PinJoint3D = entry.get("joint") as PinJoint3D
	if is_instance_valid(joint):
		joint.node_a = NodePath()
		joint.node_b = NodePath()
		joint.queue_free()
	entry["joint"] = null

func _set_panel_visible(panel: Node3D, showing: bool) -> void:
	panel.visible = showing
	for node in panel.find_children("*", "CollisionObject3D", true, false):
		(node as CollisionObject3D).collision_layer = 1 if showing and (node as Node3D).is_visible_in_tree() else 0
