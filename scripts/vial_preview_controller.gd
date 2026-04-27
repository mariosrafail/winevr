extends Node3D
class_name VialPreviewController

@export var drag_rotate_speed: float = 0.01
@export var idle_rotate_speed: float = 0.45
@export var vertical_drag_ratio: float = 0.35
@export var min_tilt_degrees: float = -20.0
@export var max_tilt_degrees: float = 20.0

@export var zoom_step: float = 0.05
@export var min_camera_z: float = 0.28
@export var max_camera_z: float = 0.95

@onready var vial: Vial = $Vial
@onready var camera: Camera3D = $Camera3D

var _is_dragging: bool = false
var _interaction_enabled: bool = true
var _idle_rotation_paused: bool = false
var _touch_points: Dictionary = {}
var _last_pinch_distance: float = 0.0
var _presentation_root: Node3D
var _pedestal_material: StandardMaterial3D
var _accent_material: StandardMaterial3D


func _ready() -> void:
	_build_presentation()
	apply_client_profile(ClientProfileLoader.get_active_client_data())


func _process(delta: float) -> void:
	if vial != null and not _is_dragging and not _idle_rotation_paused:
		vial.rotate_y(delta * idle_rotate_speed)


func _unhandled_input(event: InputEvent) -> void:
	if not _interaction_enabled:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_points[event.index] = event.position
		else:
			_touch_points.erase(event.index)
			if _touch_points.size() < 2:
				_last_pinch_distance = 0.0
		return

	if event is InputEventScreenDrag:
		_touch_points[event.index] = event.position
		if _touch_points.size() == 1:
			_rotate_vial(event.relative)
		elif _touch_points.size() >= 2:
			_update_pinch_zoom()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = event.pressed
			return
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.position.z = maxf(min_camera_z, camera.position.z - zoom_step)
			return
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.position.z = minf(max_camera_z, camera.position.z + zoom_step)
			return

	if event is InputEventMouseMotion and _is_dragging:
		_rotate_vial(event.relative)


func apply_client_profile(client_data: Dictionary) -> void:
	if client_data.is_empty():
		return
	if vial == null:
		return

	var vial_settings: Dictionary = _dict_value(client_data.get("vial_settings", {}))
	vial.liquid_fill_amount = float(vial_settings.get("liquid_fill_amount", vial.liquid_fill_amount))
	vial.liquid_color = _parse_color(vial_settings.get("liquid_color", vial.liquid_color))
	vial.cap_color = _parse_color(vial_settings.get("cap_color", vial.cap_color))
	vial.liquid_tilt_response = float(vial_settings.get("liquid_tilt_response", vial.liquid_tilt_response))
	vial.liquid_slosh_response = float(vial_settings.get("liquid_slosh_response", vial.liquid_slosh_response))
	vial.rebuild_vial()

	var environment_settings: Dictionary = _dict_value(client_data.get("environment_settings", {}))
	var accent_color: Color = _parse_color(environment_settings.get("accent_color", vial.cap_color), vial.cap_color)
	_apply_presentation_style(accent_color, _normalize_quality(str(environment_settings.get("visual_quality", "medium"))))


func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	if not enabled:
		_is_dragging = false
		_touch_points.clear()
		_last_pinch_distance = 0.0


func set_camera_active(active: bool) -> void:
	camera.current = active


func set_idle_rotation_paused(paused: bool) -> void:
	_idle_rotation_paused = paused


func reset_view() -> void:
	if vial != null:
		vial.rotation = Vector3.ZERO
		vial.reset_liquid_motion()
	if camera != null:
		camera.position.z = 0.62


func zoom_in() -> void:
	if camera == null:
		return
	camera.position.z = maxf(min_camera_z, camera.position.z - zoom_step)


func zoom_out() -> void:
	if camera == null:
		return
	camera.position.z = minf(max_camera_z, camera.position.z + zoom_step)


func _rotate_vial(relative_motion: Vector2) -> void:
	vial.rotate_y(relative_motion.x * drag_rotate_speed)
	vial.rotate_x(relative_motion.y * drag_rotate_speed * vertical_drag_ratio)
	vial.rotation.x = clampf(vial.rotation.x, deg_to_rad(min_tilt_degrees), deg_to_rad(max_tilt_degrees))
	vial.add_liquid_interaction(relative_motion)


func _update_pinch_zoom() -> void:
	var points: Array = _touch_points.values()
	if points.size() < 2:
		return

	var distance: float = (points[0] as Vector2).distance_to(points[1] as Vector2)
	if _last_pinch_distance > 0.0:
		var delta_distance: float = distance - _last_pinch_distance
		camera.position.z = clampf(camera.position.z - delta_distance * 0.0012, min_camera_z, max_camera_z)
	_last_pinch_distance = distance


func _parse_color(value, default_color: Color = Color.WHITE) -> Color:
	if value is Color:
		return value
	if value is String:
		var color_text: String = value
		if color_text.is_valid_html_color():
			return Color.from_string(color_text, default_color)
	return default_color


func _build_presentation() -> void:
	if _presentation_root != null:
		return
	_presentation_root = Node3D.new()
	_presentation_root.name = "VialStudioPresentation"
	add_child(_presentation_root)
	move_child(_presentation_root, 0)

	_pedestal_material = StandardMaterial3D.new()
	_pedestal_material.albedo_color = Color(0.12, 0.11, 0.1, 1.0)
	_pedestal_material.roughness = 0.68
	_pedestal_material.metallic = 0.12

	var pedestal_mesh: CylinderMesh = CylinderMesh.new()
	pedestal_mesh.top_radius = 0.105
	pedestal_mesh.bottom_radius = 0.14
	pedestal_mesh.height = 0.035
	pedestal_mesh.radial_segments = 48
	var pedestal: MeshInstance3D = MeshInstance3D.new()
	pedestal.name = "StudioPedestal"
	pedestal.mesh = pedestal_mesh
	pedestal.position = Vector3(0.0, -0.145, 0.0)
	pedestal.set_surface_override_material(0, _pedestal_material)
	_presentation_root.add_child(pedestal)

	_accent_material = StandardMaterial3D.new()
	_accent_material.albedo_color = Color(0.8, 0.62, 0.32, 0.35)
	_accent_material.emission_enabled = true
	_accent_material.emission = Color(0.8, 0.62, 0.32, 1.0)
	_accent_material.emission_energy_multiplier = 0.18
	_accent_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_accent_material.roughness = 0.5

	var accent_mesh: PlaneMesh = PlaneMesh.new()
	accent_mesh.size = Vector2(0.42, 0.5)
	var accent_card: MeshInstance3D = MeshInstance3D.new()
	accent_card.name = "AccentReflectionCard"
	accent_card.mesh = accent_mesh
	accent_card.position = Vector3(-0.18, 0.16, -0.34)
	accent_card.rotation_degrees = Vector3(0.0, 18.0, 0.0)
	accent_card.set_surface_override_material(0, _accent_material)
	_presentation_root.add_child(accent_card)


func _apply_presentation_style(accent_color: Color, quality: String) -> void:
	if _accent_material != null:
		_accent_material.albedo_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.32)
		_accent_material.emission = accent_color
		_accent_material.emission_energy_multiplier = 0.1 if quality == "low" else 0.2
	if _presentation_root != null:
		_presentation_root.visible = quality != "low"


func _dict_value(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value as Dictionary
	return {}


func _normalize_quality(value: String) -> String:
	if ["low", "medium", "high"].has(value):
		return value
	return "medium"
