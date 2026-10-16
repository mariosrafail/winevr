extends Node3D
class_name VRTeleportController

const MARKER_SCENE: PackedScene = preload("res://scenes/vr/VRTeleportMarker.tscn")
const TELEPORT_ACTION: StringName = &"teleport"
const TELEPORT_COLLISION_MASK: int = 8
const DEFAULT_MAX_DISTANCE: float = 6.0
const BOUNDS_MIN: Vector2 = Vector2(-3.2, -3.2)
const BOUNDS_MAX: Vector2 = Vector2(3.2, 3.2)

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
var _enabled: bool = false
var _target_valid: bool = false
var _target_position: Vector3 = Vector3.ZERO
var _last_valid_state: bool = false
var _teleport_axis_was_pressed: bool = false


func _ready() -> void:
	_ensure_input_action()
	_build_ray()
	_build_marker()
	set_enabled(false)


func setup(origin: XROrigin3D, camera: XRCamera3D, left_controller: XRController3D, right_controller: XRController3D) -> void:
	_origin = origin
	_camera = camera
	_left_controller = left_controller
	_right_controller = right_controller
	_aim_controller = _left_controller if _left_controller != null else _right_controller
	_connect_controller_input()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled and _origin != null and _aim_controller != null
	set_physics_process(_enabled)
	if not _enabled:
		_hide_visuals()


func configure_bounds(minimum: Vector2, maximum: Vector2) -> void:
	bounds_min = minimum
	bounds_max = maximum


func _physics_process(_delta: float) -> void:
	if not _enabled:
		return
	_update_target()
	if InputMap.has_action(TELEPORT_ACTION) and Input.is_action_just_pressed(TELEPORT_ACTION):
		_try_teleport()


func _ensure_input_action() -> void:
	if not InputMap.has_action(TELEPORT_ACTION):
		InputMap.add_action(TELEPORT_ACTION)


func _connect_controller_input() -> void:
	if _aim_controller == null:
		return
	var button_callable: Callable = Callable(self, "_on_controller_button_pressed")
	if not _aim_controller.button_pressed.is_connected(button_callable):
		_aim_controller.button_pressed.connect(_on_controller_button_pressed)
	var float_callable: Callable = Callable(self, "_on_controller_input_float_changed")
	if not _aim_controller.input_float_changed.is_connected(float_callable):
		_aim_controller.input_float_changed.connect(_on_controller_input_float_changed)


func _on_controller_button_pressed(button_name: Variant) -> void:
	if not _enabled:
		return
	if _is_teleport_button(button_name):
		_try_teleport()


func _on_controller_input_float_changed(input_name: Variant, value: float) -> void:
	if not _enabled or not _is_teleport_axis(input_name):
		return
	var pressed: bool = value >= 0.72
	if pressed and not _teleport_axis_was_pressed:
		_try_teleport()
	_teleport_axis_was_pressed = pressed


func _is_teleport_button(button_name: Variant) -> bool:
	var normalized: String = String(button_name).to_lower()
	if _aim_controller == _right_controller:
		return normalized.find("thumbstick") >= 0 or normalized.find("menu") >= 0 or normalized == "by_button" or normalized == "secondary_click"
	return normalized.find("trigger") >= 0 or normalized == "ax_button" or normalized == "primary_click" or normalized.find("thumbstick") >= 0


func _is_teleport_axis(input_name: Variant) -> bool:
	if _aim_controller == _right_controller:
		return false
	var normalized: String = String(input_name).to_lower()
	return normalized.find("trigger") >= 0


func _update_target() -> void:
	if _aim_controller == null:
		_set_target_invalid()
		return

	var origin_position: Vector3 = _aim_controller.global_position
	var direction: Vector3 = -_aim_controller.global_transform.basis.z.normalized()
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin_position, origin_position + direction * max_distance)
	query.collision_mask = TELEPORT_COLLISION_MASK
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not _is_valid_floor_hit(hit):
		_set_target_invalid()
		_draw_ray(origin_position, origin_position + direction * minf(max_distance, 2.6), false)
		return

	var hit_position: Vector3 = hit.get("position", Vector3.ZERO) as Vector3
	if not _is_inside_bounds(hit_position):
		_set_target_invalid()
		_draw_ray(origin_position, hit_position, false)
		return

	_target_valid = true
	_target_position = hit_position
	_draw_ray(origin_position, _target_position, true)
	_show_marker(_target_position)
	if not _last_valid_state:
		print("[WineVR][VR] Teleport target valid: %s" % str(_target_position))
	_last_valid_state = true


func _is_valid_floor_hit(hit: Dictionary) -> bool:
	var collider: Object = hit.get("collider", null)
	return collider is Node and (collider as Node).is_in_group("vr_teleport_floor")


func _is_inside_bounds(position: Vector3) -> bool:
	return position.x >= bounds_min.x and position.x <= bounds_max.x and position.z >= bounds_min.y and position.z <= bounds_max.y


func _set_target_invalid() -> void:
	_target_valid = false
	if _marker != null:
		_marker.visible = false
	if _last_valid_state:
		print("[WineVR][VR] Teleport target invalid")
	_last_valid_state = false


func _try_teleport() -> void:
	if not _enabled:
		return
	_update_target()
	if not _target_valid or _origin == null or _camera == null:
		print("[WineVR][VR] Teleport target invalid")
		return
	var camera_floor_position: Vector3 = Vector3(_camera.global_position.x, _target_position.y, _camera.global_position.z)
	var offset: Vector3 = _target_position - camera_floor_position
	_origin.global_position += Vector3(offset.x, 0.0, offset.z)
	print("[WineVR][VR] Teleported to: %s" % str(_target_position))
	_hide_visuals()


func _build_ray() -> void:
	if _ray_mesh_instance != null:
		return
	_ray_mesh = ImmediateMesh.new()
	_ray_mesh_instance = MeshInstance3D.new()
	_ray_mesh_instance.name = "VRTeleportRay"
	_ray_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ray_mesh_instance.mesh = _ray_mesh
	_ray_mesh_instance.set_surface_override_material(0, _make_gold_material(0.72))
	add_child(_ray_mesh_instance)


func _build_marker() -> void:
	if _marker != null:
		return
	_marker = MARKER_SCENE.instantiate() as Node3D
	if _marker == null:
		push_warning("[WineVR][VR] Teleport marker unavailable")
		return
	add_child(_marker)
	_marker.visible = false


func _draw_ray(from: Vector3, to: Vector3, valid: bool) -> void:
	if _ray_mesh == null or _ray_mesh_instance == null:
		return
	_ray_mesh.clear_surfaces()
	_ray_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var arc_height: float = 0.18 if valid else 0.0
	for index in range(12):
		var t: float = float(index) / 11.0
		var point: Vector3 = from.lerp(to, t)
		point.y += sin(t * PI) * arc_height
		_ray_mesh.surface_add_vertex(to_local(point))
	_ray_mesh.surface_end()
	_ray_mesh_instance.visible = true


func _show_marker(position: Vector3) -> void:
	if _marker == null:
		return
	_marker.global_position = position + Vector3(0.0, 0.035, 0.0)
	_marker.visible = true


func _hide_visuals() -> void:
	_target_valid = false
	_last_valid_state = false
	if _ray_mesh_instance != null:
		_ray_mesh_instance.visible = false
	if _marker != null:
		_marker.visible = false


func _make_gold_material(alpha: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.839216, 0.694118, 0.368627, alpha)
	return material
