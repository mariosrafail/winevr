extends XROrigin3D
class_name WineVRPlayerRig

## One interaction ray follows live right/left aim tracking, with a head-gaze
## fallback. The same ray also accepts transient WebXR screen/pinch sources.
signal snap_turned(angle_radians: float)

@export_range(15.0, 60.0, 5.0) var snap_turn_degrees: float = 30.0
@export_range(1.2, 1.9, 0.05) var seated_eye_height: float = 1.65

@onready var xr_camera: XRCamera3D = $XRCamera3D
@onready var left_controller: XRController3D = $LeftController
@onready var right_controller: XRController3D = $RightController
@onready var interaction_ray: RayCast3D = $RightController/InteractionRay
@onready var legacy_pointer: MeshInstance3D = $RightController/Pointer

var _xr_enabled: bool = false
var _input_enabled: bool = false
var _ar_mode: bool = false
var _snap_armed: bool = true
var _reference_height_applied: float = 0.0
var _line: MeshInstance3D
var _line_mesh: ImmediateMesh
var _line_material: StandardMaterial3D
var _reticle: MeshInstance3D
var _navigation: Node3D


func _ready() -> void:
	interaction_ray.top_level = true
	_build_pointer()
	set_xr_enabled(false)


func set_xr_enabled(enabled: bool, ar_mode: bool = false) -> void:
	_xr_enabled = enabled
	_ar_mode = ar_mode
	visible = enabled
	set_physics_process(enabled)
	if enabled and _navigation == null and get_parent().has_method("end_immersive_mode"):
		_navigation = load("res://scripts/vr/xr_navigation.gd").new() as Node3D
		_navigation.name = "XRNavigation"
		add_child(_navigation)
		_navigation.call("setup", get_parent(), xr_camera)
	elif not enabled and _navigation != null:
		_navigation.queue_free()
		_navigation = null
	if not enabled:
		set_input_enabled(false)
		apply_reference_space("local-floor")


func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled and _xr_enabled
	_snap_armed = true
	if interaction_ray != null:
		interaction_ray.enabled = _input_enabled
	if _line != null:
		_line.visible = _input_enabled
	if _reticle != null:
		_reticle.visible = _input_enabled
	if legacy_pointer != null:
		legacy_pointer.visible = false


func apply_reference_space(reference_space: String) -> void:
	# 'local' has its origin at the viewer, unlike the floor-based spaces.
	# Apply one offset to the complete rig, including controllers; reset is
	# idempotent and exiting XR removes the offset again.
	var target_offset: float = seated_eye_height if reference_space == "local" and not _ar_mode else 0.0
	position.y += target_offset - _reference_height_applied
	_reference_height_applied = target_offset


func reset_origin(origin_position: Vector3, origin_rotation: Vector3) -> void:
	position = origin_position + Vector3.UP * _reference_height_applied
	rotation = origin_rotation
	if _navigation != null:
		_navigation.call("recenter")


func get_active_interaction_ray() -> RayCast3D:
	return interaction_ray


func get_interaction_controller() -> XRController3D:
	if right_controller.get_has_tracking_data():
		return right_controller
	if left_controller.get_has_tracking_data():
		return left_controller
	return null


func route_web_selection(manager: WineVRVRManager, input_source_id: int) -> bool:
	if not _input_enabled or manager.webxr_interface == null:
		return false
	var source: XRPositionalTracker = manager.webxr_interface.call("get_input_source_tracker", input_source_id) as XRPositionalTracker
	if source != null:
		var pose: XRPose = source.get_pose(&"aim")
		if pose == null or not pose.has_tracking_data:
			pose = source.get_pose(&"default")
		if pose != null and pose.has_tracking_data:
			interaction_ray.global_transform = global_transform * pose.get_adjusted_transform()
		else:
			interaction_ray.global_transform = xr_camera.global_transform
	else:
		interaction_ray.global_transform = xr_camera.global_transform
	interaction_ray.force_raycast_update()
	return true


func pulse_selection() -> void:
	var controller: XRController3D = get_interaction_controller()
	if controller != null:
		controller.trigger_haptic_pulse("haptic", 0.0, 0.2, 0.035, 0.0)


func _physics_process(_delta: float) -> void:
	legacy_pointer.visible = false
	if not _input_enabled:
		return
	var controller: XRController3D = get_interaction_controller()
	interaction_ray.global_transform = controller.global_transform if controller != null else xr_camera.global_transform
	interaction_ray.force_raycast_update()
	_update_pointer(controller != null)
	if not _ar_mode:
		_update_snap_turn()


func _update_snap_turn() -> void:
	if not right_controller.get_has_tracking_data():
		_snap_armed = true
		return
	var axis: Vector2 = right_controller.get_vector2(&"primary")
	if axis.length_squared() < 0.001:
		axis = right_controller.get_vector2(&"thumbstick")
	if absf(axis.x) < 0.3:
		_snap_armed = true
	elif _snap_armed and absf(axis.x) > 0.72 and absf(axis.y) < 0.55:
		_snap_armed = false
		snap_turn(-signf(axis.x) * deg_to_rad(snap_turn_degrees))


func snap_turn(angle: float) -> void:
	if not _xr_enabled or _ar_mode or xr_camera == null:
		return
	# Rotate around the user's real head position, not the room origin.
	var head_before: Vector3 = xr_camera.global_position
	rotate_y(angle)
	var correction: Vector3 = head_before - xr_camera.global_position
	global_position += Vector3(correction.x, 0.0, correction.z)
	snap_turned.emit(angle)


func _build_pointer() -> void:
	_line_material = StandardMaterial3D.new()
	_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_material.albedo_color = Color(0.88, 0.72, 0.42, 1.0)
	_line_mesh = ImmediateMesh.new()
	_line = MeshInstance3D.new()
	_line.name = "TrackedAimLine"
	_line.mesh = _line_mesh
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)
	_reticle = MeshInstance3D.new()
	_reticle.name = "AimReticle"
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.009
	sphere.height = 0.018
	sphere.radial_segments = 12
	sphere.rings = 6
	_reticle.mesh = sphere
	_reticle.material_override = _line_material
	_reticle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_reticle)


func _update_pointer(show_line: bool) -> void:
	var from: Vector3 = interaction_ray.global_position
	var to: Vector3 = interaction_ray.to_global(interaction_ray.target_position)
	var collided: bool = interaction_ray.is_colliding()
	if collided:
		to = interaction_ray.get_collision_point()
	_line_mesh.clear_surfaces()
	if show_line:
		_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _line_material)
		_line_mesh.surface_add_vertex(to_local(from))
		_line_mesh.surface_add_vertex(to_local(to))
		_line_mesh.surface_end()
	_line.visible = show_line
	_reticle.global_position = to
	_reticle.visible = collided or not show_line
	_reticle.scale = Vector3.ONE * clampf(from.distance_to(to) * 0.6, 0.5, 2.0)
