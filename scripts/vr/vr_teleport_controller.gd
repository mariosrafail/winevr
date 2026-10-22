extends Node3D
class_name VRTeleportController

## Hold the left trigger or push its stick forward to aim; release to move.
## Every rendered arc segment is ray-tested, including solid obstacles.
const MARKER_SCENE: PackedScene = preload("res://scenes/vr/VRTeleportMarker.tscn")
const TELEPORT_ACTION: StringName = &"teleport"
const TELEPORT_COLLISION_MASK: int = 9
const DEFAULT_MAX_DISTANCE: float = 6.0
const BOUNDS_MIN: Vector2 = Vector2(-3.2, -3.2)
const BOUNDS_MAX: Vector2 = Vector2(3.2, 3.2)
const ARC_STEPS: int = 42
const ARC_STEP_SECONDS: float = 0.055
const ARC_SPEED: float = 6.0

var max_distance: float = DEFAULT_MAX_DISTANCE
var bounds_min: Vector2 = BOUNDS_MIN
var bounds_max: Vector2 = BOUNDS_MAX
var _origin: XROrigin3D
var _camera: XRCamera3D
var _left_controller: XRController3D
var _right_controller: XRController3D
var _aim_controller: XRController3D
var _marker: Node3D
var _ray_mesh_instance: MeshInstance3D
var _ray_mesh: ImmediateMesh
var _ray_material: StandardMaterial3D
var _enabled: bool = false
var _aiming: bool = false
var _target_valid: bool = false
var _target_position: Vector3 = Vector3.ZERO
var _trigger_held: bool = false
var _stick_held: bool = false
var _button_held: bool = false
var _button_action: String = ""
var _body_clearance: CapsuleShape3D


func _ready() -> void:
	if not InputMap.has_action(TELEPORT_ACTION):
		InputMap.add_action(TELEPORT_ACTION)
	_body_clearance = CapsuleShape3D.new()
	_body_clearance.radius = 0.22
	_body_clearance.height = 1.4
	_build_ray()
	_marker = MARKER_SCENE.instantiate() as Node3D
	add_child(_marker)
	set_enabled(false)


func setup(origin: XROrigin3D, camera: XRCamera3D, left_controller: XRController3D, right_controller: XRController3D) -> void:
	_origin = origin
	_camera = camera
	_left_controller = left_controller
	_right_controller = right_controller
	for controller: XRController3D in [_left_controller, _right_controller]:
		if controller == null:
			continue
		var pressed: Callable = _on_button_pressed.bind(controller)
		if not controller.button_pressed.is_connected(pressed):
			controller.button_pressed.connect(pressed)
			controller.button_released.connect(_on_button_released.bind(controller))
			controller.input_float_changed.connect(_on_input_float_changed.bind(controller))
			controller.input_vector2_changed.connect(_on_input_vector2_changed.bind(controller))
	_refresh_aim_controller()


func configure_bounds(minimum: Vector2, maximum: Vector2) -> void:
	bounds_min = minimum
	bounds_max = maximum


func set_enabled(enabled: bool) -> void:
	_enabled = enabled and _origin != null and (_left_controller != null or _right_controller != null)
	set_physics_process(_enabled)
	if not _enabled:
		_aiming = false
		_trigger_held = false
		_stick_held = false
		_button_held = false
		_button_action = ""
		_hide_visuals()


func _physics_process(_delta: float) -> void:
	_refresh_aim_controller()
	if not _left_trigger_available() and (_trigger_held or (_button_held and not _is_teleport_button(_button_action))):
		_aiming = false
		_trigger_held = false
		_button_held = false
		_button_action = ""
		_hide_visuals()
	if _aim_controller == null or not _aim_controller.get_has_tracking_data():
		_aiming = false
		_hide_visuals()
		return
	if Input.is_action_just_pressed(TELEPORT_ACTION):
		_set_aiming(true)
	elif Input.is_action_just_released(TELEPORT_ACTION):
		_set_aiming(false)
	if _aiming:
		_update_target()


func _refresh_aim_controller() -> void:
	var tracked: XRController3D = null
	if _left_controller != null and _left_controller.get_has_tracking_data():
		tracked = _left_controller
	elif _right_controller != null and _right_controller.get_has_tracking_data():
		tracked = _right_controller
	if tracked == _aim_controller:
		return
	# Changing or losing the tracked controller cancels, never commits, an arc.
	_aim_controller = tracked
	_aiming = false
	_trigger_held = false
	_stick_held = false
	_button_held = false
	_button_action = ""
	_hide_visuals()


func _accept_input(source: XRController3D) -> bool:
	_refresh_aim_controller()
	return _enabled and _aim_controller != null and (source == null or source == _aim_controller)


func _on_button_pressed(action_name: String, source: XRController3D = null) -> void:
	if not _accept_input(source) or not _is_teleport_button(action_name):
		return
	_button_held = true
	_button_action = action_name
	_sync_aiming()


func _on_button_released(action_name: String, source: XRController3D = null) -> void:
	if not _accept_input(source) or not _is_teleport_button(action_name):
		return
	_button_held = false
	_button_action = ""
	_sync_aiming()


func _on_input_float_changed(action_name: String, value: float, source: XRController3D = null) -> void:
	if not _accept_input(source) or not _left_trigger_available() or action_name != "trigger":
		return
	# Hysteresis avoids repeated teleports from noisy analog triggers.
	if value > 0.72:
		_trigger_held = true
	elif value < 0.25:
		_trigger_held = false
	_sync_aiming()


func _on_input_vector2_changed(action_name: String, value: Vector2, source: XRController3D = null) -> void:
	if not _accept_input(source) or action_name not in ["primary", "thumbstick"]:
		return
	if value.y > 0.72 and absf(value.x) < 0.55:
		_stick_held = true
	elif value.y < 0.3:
		_stick_held = false
	_sync_aiming()


func _is_teleport_button(action_name: String) -> bool:
	if not _left_trigger_available():
		return action_name in ["by_button", "secondary_click"]
	return action_name in ["trigger_click", "select_button", "ax_button", "primary_click"]


func _left_trigger_available() -> bool:
	# The sole tracked hand needs its primary trigger for world selection.
	return _aim_controller == _left_controller and _right_controller != null and _right_controller.get_has_tracking_data()


func _sync_aiming() -> void:
	_set_aiming(_trigger_held or _stick_held or _button_held)


func _set_aiming(aiming: bool) -> void:
	if not _enabled or _aiming == aiming:
		return
	var was_aiming: bool = _aiming
	_aiming = aiming
	if aiming:
		_update_target()
	elif was_aiming:
		_try_teleport()
		_hide_visuals()


func _update_target() -> void:
	_target_valid = false
	_marker.visible = false
	if _aim_controller == null or not _aim_controller.get_has_tracking_data():
		_hide_visuals()
		return
	var start: Vector3 = _aim_controller.global_position
	var velocity: Vector3 = -_aim_controller.global_basis.z.normalized() * ARC_SPEED
	var previous: Vector3 = start
	var points: PackedVector3Array = PackedVector3Array([start])
	for step in range(1, ARC_STEPS + 1):
		var time: float = float(step) * ARC_STEP_SECONDS
		var next: Vector3 = start + velocity * time + Vector3.DOWN * 4.9 * time * time
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(previous, next, TELEPORT_COLLISION_MASK)
		query.collide_with_areas = false
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var hit_position: Vector3 = hit["position"] as Vector3
			points.append(hit_position)
			if _is_valid_floor_hit(hit) and _is_inside_bounds(hit_position) and start.distance_to(hit_position) <= max_distance and _has_clearance(hit_position):
				_target_valid = true
				_target_position = hit_position
				_marker.global_position = hit_position + Vector3.UP * 0.035
				_marker.visible = true
			break
		points.append(next)
		if start.distance_to(next) > max_distance:
			break
		previous = next
	_draw_arc(points)


func _is_valid_floor_hit(hit: Dictionary) -> bool:
	var collider: Node = hit.get("collider") as Node
	var normal: Vector3 = hit.get("normal", Vector3.ZERO) as Vector3
	return collider != null and collider.is_in_group("vr_teleport_floor") and normal.dot(Vector3.UP) > 0.9


func _is_inside_bounds(point: Vector3) -> bool:
	return point.x >= bounds_min.x and point.x <= bounds_max.x and point.z >= bounds_min.y and point.z <= bounds_max.y


func _has_clearance(point: Vector3) -> bool:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = _body_clearance
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * 0.8)
	query.collision_mask = 1
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _try_teleport() -> void:
	if not _enabled or _origin == null or _camera == null:
		return
	_update_target()
	if not _target_valid:
		return
	# Preserve the user's real room-scale head offset and calibrated height.
	var offset: Vector3 = _target_position - _camera.global_position
	_origin.global_position += Vector3(offset.x, 0.0, offset.z)
	_aim_controller.trigger_haptic_pulse("haptic", 0.0, 0.3, 0.045, 0.0)
	print("[WineVR][XR] Teleported to ", _target_position)


func _build_ray() -> void:
	_ray_material = StandardMaterial3D.new()
	_ray_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ray_material.albedo_color = Color(0.88, 0.72, 0.42)
	_ray_mesh = ImmediateMesh.new()
	_ray_mesh_instance = MeshInstance3D.new()
	_ray_mesh_instance.name = "TeleportArc"
	_ray_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ray_mesh_instance.mesh = _ray_mesh
	add_child(_ray_mesh_instance)


func _draw_arc(points: PackedVector3Array) -> void:
	_ray_mesh.clear_surfaces()
	_ray_material.albedo_color = Color(0.88, 0.72, 0.42) if _target_valid else Color(0.62, 0.24, 0.22)
	_ray_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _ray_material)
	for point in points:
		_ray_mesh.surface_add_vertex(to_local(point))
	_ray_mesh.surface_end()
	_ray_mesh_instance.visible = true


func _hide_visuals() -> void:
	_target_valid = false
	if _ray_mesh_instance != null:
		_ray_mesh_instance.visible = false
	if _marker != null:
		_marker.visible = false
