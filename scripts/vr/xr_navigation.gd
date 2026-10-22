extends Node3D
class_name WineVRNavigation

## World-space navigation remains usable without desktop CanvasLayer UI.
## It stays still while the visitor looks at it, including gaze-only input.
var _winery: Node3D
var _camera: Camera3D
var _buttons: Array[Interactable] = []
var _title: Label3D
var _is_ar: bool = false


func setup(winery: Node3D, camera: Camera3D) -> void:
	_winery = winery
	_camera = camera
	_is_ar = bool(winery.call("is_ar_active"))
	_title = Label3D.new()
	_title.text = "GRAPES OF CRETE  ·  " + ("ΣΥΛΛΟΓΗ AR" if _is_ar else "ΚΡΗΤΗ")
	_title.font_size = 24
	_title.pixel_size = 0.001
	_title.position = Vector3(0, 0.075 if _is_ar else 0.15, 0)
	_title.modulate = Color(0.93, 0.84, 0.63)
	_title.outline_size = 4
	add_child(_title)
	if _is_ar:
		_add_button("museum", "Συλλογή", Vector2(-0.25, 0.0))
		_add_button("recenter", "Μετακίνηση", Vector2.ZERO)
		_add_button("exit", "Έξοδος XR", Vector2(0.25, 0.0))
	else:
		_add_button("museum", "Συλλογή", Vector2(-0.125, 0.055))
		_add_button("vineyard", "Αμπελώνας", Vector2(0.125, 0.055))
		_add_button("cellar", "Οινοποιείο", Vector2(-0.125, -0.055))
		_add_button("exit", "Έξοδος XR", Vector2(0.125, -0.055))
	recenter()


func recenter() -> void:
	if _camera == null:
		return
	var forward: Vector3 = -_camera.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	# Keep controls in front of the inspected fruit rather than occluded by it.
	global_position = _camera.global_position + forward * 0.78 + Vector3.DOWN * 0.32
	look_at(_camera.global_position, Vector3.UP, true)


func _process(_delta: float) -> void:
	if _camera == null or not is_visible_in_tree():
		return
	var offset: Vector3 = global_position - _camera.global_position
	# Reappear after walking away or turning completely around; do not chase
	# the eyes while a visitor is trying to select a button by gaze.
	if offset.length() > 1.8 or (-_camera.global_basis.z).dot(offset.normalized()) < -0.35:
		recenter()


func _add_button(action: String, caption: String, offset: Vector2) -> void:
	var button: Interactable = Interactable.new()
	button.name = "XR_" + action
	button.id = "xr_navigation_" + action
	button.title = caption
	button.bypass_guided_lock = true
	button.glow_on_hover = true
	button.hover_scale_multiplier = 1.06
	button.position = Vector3(offset.x, offset.y, 0.0)
	button.set_meta("navigation_action", action)
	button.set_meta("museum_action", "navigation")
	add_child(button)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.225, 0.088, 0.015)
	mesh.mesh = box
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.14, 0.07, 0.08) if action == "exit" else Color(0.035, 0.055, 0.06)
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	button.add_child(mesh)
	var label: Label3D = Label3D.new()
	label.text = caption
	label.position.z = 0.009
	label.font_size = 24
	label.pixel_size = 0.001
	label.modulate = Color(0.97, 0.93, 0.84)
	label.outline_size = 2
	button.add_child(label)
	var area: Area3D = Area3D.new()
	area.collision_layer = 1
	area.collision_mask = 0
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(0.225, 0.088, 0.035)
	collision.shape = shape
	area.add_child(collision)
	button.add_child(area)
	button.interacted.connect(func(_target: Interactable) -> void: _activate(action))
	_buttons.append(button)


func _activate(action: String) -> void:
	if _winery == null:
		return
	match action:
		"exit":
			_winery.call("end_immersive_mode")
		"recenter":
			recenter()
		"museum", "vineyard", "cellar":
			_winery.call("set_presentation_mode", action)
			recenter()
