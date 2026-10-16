extends Node3D
class_name WineVRInfoPanel

const AUTO_HIDE_SECONDS: float = 6.0
const PANEL_LOCAL_POSITION: Vector3 = Vector3(0.0, -0.18, -1.4)
const PANEL_WIDTH: float = 1.08
const PANEL_HEIGHT: float = 0.62
const TEXT_PIXEL_SIZE: float = 0.0022
const SHOW_SCALE: Vector3 = Vector3.ONE
const HIDDEN_SCALE: Vector3 = Vector3(0.94, 0.94, 0.94)
const GOLD: Color = Color(0.839216, 0.694118, 0.368627, 1.0)
const TITLE_COLOR: Color = Color(0.976471, 0.968627, 0.941176, 1.0)
const BODY_COLOR: Color = Color(0.851, 0.82, 0.753, 1.0)
const MUTED_COLOR: Color = Color(0.67, 0.62, 0.52, 1.0)

@onready var background: MeshInstance3D = $Background
@onready var title_label: Label3D = $Title
@onready var body_label: Label3D = $Body
@onready var hint_label: Label3D = $Hint

var _follow_camera: Camera3D
var _hide_token: int = 0
var _fade_tween: Tween


func _ready() -> void:
	position = PANEL_LOCAL_POSITION
	scale = HIDDEN_SCALE
	visible = false
	_apply_materials()
	_configure_text()
	_set_visual_alpha(0.0)


func _process(_delta: float) -> void:
	if visible and _follow_camera != null:
		_update_follow_transform()


func set_follow_camera(camera: Camera3D) -> void:
	_follow_camera = camera
	_update_follow_transform()


func show_info(title: String, body: String) -> void:
	_hide_token += 1
	title_label.text = _fit_title(title)
	body_label.text = _wrap_text(body, 42, 7)
	hint_label.text = "Look away or continue exploring"
	_update_follow_transform()
	visible = true
	_animate_visibility(true)
	var token: int = _hide_token
	await get_tree().create_timer(AUTO_HIDE_SECONDS).timeout
	if token == _hide_token:
		hide_panel()


func hide_panel() -> void:
	_hide_token += 1
	if not visible:
		return
	print("[WineVR][VR] Hiding VR info panel")
	_animate_visibility(false)


func _apply_materials() -> void:
	background.set_surface_override_material(0, _make_panel_material(Color(0.035, 0.032, 0.028, 0.86)))
	for child in get_children():
		var mesh_instance: MeshInstance3D = child as MeshInstance3D
		if mesh_instance != null and mesh_instance != background:
			mesh_instance.set_surface_override_material(0, _make_panel_material(Color(GOLD.r, GOLD.g, GOLD.b, 0.72)))


func _make_panel_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	return material


func _configure_text() -> void:
	for label in [title_label, body_label, hint_label]:
		label.pixel_size = TEXT_PIXEL_SIZE
		label.no_depth_test = true
		label.fixed_size = false
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label.outline_size = 4
		label.outline_modulate = Color(0.0, 0.0, 0.0, 0.72)
	title_label.font_size = 42
	title_label.modulate = TITLE_COLOR
	body_label.font_size = 27
	body_label.modulate = BODY_COLOR
	hint_label.font_size = 20
	hint_label.modulate = MUTED_COLOR


func _update_follow_transform() -> void:
	if _follow_camera == null:
		position = PANEL_LOCAL_POSITION
		rotation = Vector3.ZERO
		return
	global_transform = _follow_camera.global_transform
	global_position = _follow_camera.global_transform * PANEL_LOCAL_POSITION


func _animate_visibility(showing: bool) -> void:
	if _fade_tween != null:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_method(_set_visual_alpha, _get_visual_alpha(), 1.0 if showing else 0.0, 0.18)
	_fade_tween.tween_property(self, "scale", SHOW_SCALE if showing else HIDDEN_SCALE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if not showing:
		await _fade_tween.finished
		visible = false


func _set_visual_alpha(alpha: float) -> void:
	_set_mesh_alpha(background, 0.86 * alpha)
	for child in get_children():
		var mesh_instance: MeshInstance3D = child as MeshInstance3D
		if mesh_instance != null and mesh_instance != background:
			_set_mesh_alpha(mesh_instance, 0.72 * alpha)
	title_label.modulate = Color(TITLE_COLOR.r, TITLE_COLOR.g, TITLE_COLOR.b, TITLE_COLOR.a * alpha)
	body_label.modulate = Color(BODY_COLOR.r, BODY_COLOR.g, BODY_COLOR.b, BODY_COLOR.a * alpha)
	hint_label.modulate = Color(MUTED_COLOR.r, MUTED_COLOR.g, MUTED_COLOR.b, MUTED_COLOR.a * alpha)


func _get_visual_alpha() -> float:
	return title_label.modulate.a / TITLE_COLOR.a if TITLE_COLOR.a > 0.0 else 1.0


func _set_mesh_alpha(mesh_instance: MeshInstance3D, alpha: float) -> void:
	if mesh_instance == null:
		return
	var material: StandardMaterial3D = mesh_instance.get_surface_override_material(0) as StandardMaterial3D
	if material == null:
		return
	var color: Color = material.albedo_color
	color.a = alpha
	material.albedo_color = color


func _fit_title(value: String) -> String:
	var clean: String = value.strip_edges()
	if clean.is_empty():
		return "Winery Detail"
	if clean.length() <= 34:
		return clean
	return clean.substr(0, 31).strip_edges() + "..."


func _wrap_text(value: String, max_chars: int, max_lines: int) -> String:
	var words: PackedStringArray = value.strip_edges().split(" ", false)
	var lines: Array[String] = []
	var current: String = ""
	for word in words:
		var candidate: String = word if current.is_empty() else current + " " + word
		if candidate.length() > max_chars and not current.is_empty():
			lines.append(current)
			current = word
			if lines.size() >= max_lines:
				break
		else:
			current = candidate
	if lines.size() < max_lines and not current.is_empty():
		lines.append(current)
	if lines.is_empty():
		lines.append("No details available.")
	if lines.size() > max_lines:
		lines = lines.slice(0, max_lines)
	if lines.size() == max_lines and words.size() > 0:
		var last_index: int = lines.size() - 1
		if lines[last_index].length() > 3:
			lines[last_index] = lines[last_index].substr(0, max_chars - 3).strip_edges() + "..."
	return "\n".join(lines)
