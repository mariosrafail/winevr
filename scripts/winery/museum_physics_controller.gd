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
var _pointer: Vector2
var _pointer_valid: bool = false

func setup(owner_museum: GrapeMuseum, owner_winery: WineryInteriorController) -> void:
	museum = owner_museum
	winery = owner_winery
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

func _physics_process(delta: float) -> void:
	if museum == null or winery == null:
		return
	var active: bool = museum.controls_enabled and museum.is_visible_in_tree()
	hand.visible = active
	left_hand.visible = active and winery.is_vr_active()
	hand.collision_layer = 16 if active else 0
	left_hand.collision_layer = 16 if left_hand.visible else 0
	if not active:
		end_grab()
		_rotate_mouse = false
		_last_grip = false
		if not museum.is_visible_in_tree():
			close_inspection(true)
		if not inspecting_id.is_empty() and not _transitioning:
			_body(inspecting_id).freeze = true
		return
	var view: Camera3D = camera()
	if view == null:
		return
	var target: Transform3D = view.global_transform * Transform3D(Basis.from_euler(Vector3(0.20, -0.60, -0.20)), Vector3(0.24, -0.23, -0.48))
	if winery.is_vr_active():
		_update_vr_grip()
		if winery.vr_right_controller != null:
			target = winery.vr_right_controller.global_transform
		if winery.vr_left_controller != null:
			left_hand.global_transform = winery.vr_left_controller.global_transform
	if not grabbed_id.is_empty():
		var body: RigidBody3D = _body(grabbed_id)
		var goal: Vector3 = _grab_target()
		var point: Vector3 = body.to_global(_grab_local)
		var center: Vector3 = body.to_global(body.center_of_mass)
		var velocity: Vector3 = body.linear_velocity + body.angular_velocity.cross(point - center)
		var force: Vector3 = ((goal - point) * 24.0 - velocity * 3.0).limit_length(3.5)
		body.sleeping = false
		body.apply_force(force, point - body.global_position)
		if not _vr_grab:
			target = hand.grasp_transform()
		hand.grip_target = 1.0
	else:
		hand.grip_target = 0.0
	hand.global_transform = hand.global_transform.interpolate_with(target, 1.0 - exp(-delta * 22.0))
	if not inspecting_id.is_empty():
		var entry: Dictionary = museum.exhibit_nodes[inspecting_id]
		var panel: Node3D = entry["panel"] as Node3D
		panel.global_transform = view.global_transform * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.58), Vector3(0.53, -0.015, -_inspect_distance))
		if not _transitioning:
			var body: RigidBody3D = _body(inspecting_id)
			body.freeze = false
			var goal: Vector3 = _inspect_transform().origin
			body.apply_central_force(((goal - body.global_position) * 34.0 - body.linear_velocity * 7.0).limit_length(14.0))

func _unhandled_input(event: InputEvent) -> void:
	if museum == null or not museum.controls_enabled or not museum.is_visible_in_tree() or winery.is_vr_active():
		return
	if event is InputEventMouse:
		_pointer = event.position
		_pointer_valid = true
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if not inspecting_id.is_empty() and _click_profile_action():
					get_viewport().set_input_as_handled()
					return
				begin_grab()
			else:
				end_grab()
			if not grabbed_id.is_empty() or not event.pressed:
				get_viewport().set_input_as_handled()
		elif not inspecting_id.is_empty():
			if event.button_index == MOUSE_BUTTON_RIGHT:
				_rotate_mouse = event.pressed
			elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				_inspect_distance = clampf(_inspect_distance + (-0.08 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.08), 0.80, 1.40)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if not grabbed_id.is_empty():
			_drag += event.relative * Vector2(0.0016, -0.0016)
			_drag = _drag.clamp(Vector2(-0.55, -0.40), Vector2(0.55, 0.45))
			get_viewport().set_input_as_handled()
		elif not inspecting_id.is_empty():
			if _rotate_mouse and not _transitioning:
				_body(inspecting_id).apply_torque_impulse(camera().global_basis * Vector3(-event.relative.y, -event.relative.x, 0) * 0.00035)
			get_viewport().set_input_as_handled()

func _inspect_transform() -> Transform3D:
	return camera().global_transform * Transform3D(Basis.IDENTITY, Vector3(-0.24, 0.34, -_inspect_distance))

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
	body.freeze = true
	body.gravity_scale = 0.0
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.linear_damp = 3.0
	body.angular_damp = 3.0
	_set_panel_visible(entry["panel"] as Node3D, true)
	_transitioning = true
	_transition = create_tween()
	_transition.tween_property(body, "global_transform", _inspect_transform(), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transition.finished.connect(func() -> void:
		_transitioning = false
		if inspecting_id == id:
			body.freeze = false
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
	_set_panel_visible(entry["panel"] as Node3D, false)
	var body: RigidBody3D = _body(id)
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
		_transition.tween_property(body, "global_transform", home, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_transition.finished.connect(func() -> void: _finish_return(id))
	return true

func _finish_return(id: String) -> void:
	var body: RigidBody3D = _body(id)
	body.gravity_scale = 1.0
	body.linear_damp = 0.8
	body.angular_damp = 1.2
	_attach_joint(id)
	body.freeze = false
	body.sleeping = false
	_transitioning = false
	if museum.controls_enabled and not winery.is_vr_active() and bool(winery.get("_exploration_mode_active")):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func begin_grab(vr: bool = false) -> bool:
	if not museum.controls_enabled or _transitioning:
		return false
	var id: String = ""
	var point: Vector3
	if vr:
		var best_distance: float = 0.30
		for key in museum.exhibit_nodes:
			var body: RigidBody3D = _body(str(key))
			var center: Vector3 = body.to_global(body.center_of_mass)
			var distance: float = center.distance_to(winery.vr_right_controller.global_position)
			if distance < best_distance:
				best_distance = distance
				id = str(key)
				point = center
	else:
		var hit: Dictionary = _view_ray(4)
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
	grabbed_id = id
	_vr_grab = vr
	_grab_local = _body(id).to_local(point)
	hand.start_grasp(_body(id), _grab_local, camera())
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
	return get_world_3d().direct_space_state.intersect_ray(query)

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
	grabbed_id = ""
	_vr_grab = false
	if hand != null:
		hand.release_grasp()

func _grab_target() -> Vector3:
	if _vr_grab and winery.vr_right_controller != null:
		return winery.vr_right_controller.global_position
	return camera().to_global(Vector3(_drag.x, _drag.y, -_grab_distance))

func _update_vr_grip() -> void:
	var controller: XRController3D = winery.vr_right_controller
	if controller == null or not controller.get_is_active():
		return
	var grip: bool = controller.get_float(&"grip") > 0.55 or controller.get_float(&"squeeze") > 0.55
	if grip and not _last_grip:
		begin_grab(true)
	elif not grip and _last_grip:
		end_grab()
	_last_grip = grip

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
		(node as CollisionObject3D).collision_layer = 1 if showing else 0
