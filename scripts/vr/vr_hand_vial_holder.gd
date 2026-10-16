extends Node3D
class_name VRHandVialHolder

@onready var hand_anchor: Node3D = get_node_or_null("HandAnchor") as Node3D
@onready var vial_anchor: Node3D = get_node_or_null("VialAnchor") as Node3D

var vial: Vial
var _vial_scene: PackedScene
var _show_tween: Tween
var _logged_visible_mesh_created: bool = false


func _ready() -> void:
	ensure_visible_glove_meshes()
	_apply_hand_materials()
	_disable_shadows_recursive(self)
	set_visible_enabled(false)


func setup(vial_scene: PackedScene) -> void:
	_vial_scene = vial_scene
	_ensure_required_nodes()
	ensure_visible_glove_meshes()
	if vial != null or _vial_scene == null or vial_anchor == null:
		return
	vial = _vial_scene.instantiate() as Vial
	if vial == null:
		return
	vial.name = "HeldVial"
	vial_anchor.add_child(vial)
	vial.position = Vector3.ZERO
	vial.rotation_degrees = Vector3.ZERO
	vial.scale = Vector3.ONE
	_disable_runtime_collision_recursive(vial)
	_disable_shadows_recursive(vial)
	print("[WineVR][VRHand] vial attached to glove")


func apply_vial_profile(source_vial: Vial) -> void:
	if source_vial == null:
		return
	if vial == null:
		setup(_vial_scene)
	if vial == null:
		return
	vial.liquid_fill_amount = source_vial.liquid_fill_amount
	vial.liquid_color = source_vial.liquid_color
	vial.cap_color = source_vial.cap_color
	vial.rebuild_vial()
	print("[WineVR][VRHand] hand vial profile applied")


func apply_client_profile(client_data: Dictionary) -> void:
	if vial != null:
		vial.apply_qr_profile(client_data)


func set_visible_enabled(enabled: bool) -> void:
	visible = enabled
	set_process(enabled)
	if enabled:
		print("[WineVR][VRHand] hand vial holder shown")
	else:
		print("[WineVR][VRHand] hand vial holder hidden")


func count_visible_mesh_instance_nodes(root: Node = null) -> int:
	var count_root: Node = root if root != null else self
	var count: int = 0
	if count_root is MeshInstance3D:
		var mesh_instance: MeshInstance3D = count_root as MeshInstance3D
		if mesh_instance.visible and mesh_instance.mesh != null:
			count += 1
	for child in count_root.get_children():
		count += count_visible_mesh_instance_nodes(child)
	return count


func ensure_visible_glove_meshes() -> void:
	_ensure_required_nodes()
	if count_visible_mesh_instance_nodes() == 0:
		_create_fallback_glove_meshes()
	if count_visible_mesh_instance_nodes() > 0 and not _logged_visible_mesh_created:
		_logged_visible_mesh_created = true
		print("[WineVR][VRHand] visible glove mesh created")


func play_subtle_show_animation() -> void:
	if not visible:
		return
	if _show_tween != null:
		_show_tween.kill()
	scale = Vector3.ONE * 0.92
	_show_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_show_tween.tween_property(self, "scale", Vector3.ONE, 0.25)


func _apply_hand_materials() -> void:
	var glove_material: StandardMaterial3D = _make_material(Color(0.09, 0.035, 0.05, 1.0), 0.78)
	var glove_meshes: Array = [
		get_node_or_null("HandAnchor/Palm"),
		get_node_or_null("HandAnchor/Thumb"),
		get_node_or_null("HandAnchor/FingerIndex"),
		get_node_or_null("HandAnchor/FingerMiddle"),
		get_node_or_null("HandAnchor/FingerRing"),
		get_node_or_null("HandAnchor/WristCuff"),
		get_node_or_null("HandAnchor/FallbackGlove/Palm"),
		get_node_or_null("HandAnchor/FallbackGlove/Thumb"),
		get_node_or_null("HandAnchor/FallbackGlove/FingerIndex"),
		get_node_or_null("HandAnchor/FallbackGlove/FingerMiddle"),
		get_node_or_null("HandAnchor/FallbackGlove/FingerRing"),
		get_node_or_null("HandAnchor/FallbackGlove/WristCuff")
	]
	for mesh in glove_meshes:
		if mesh != null:
			var mesh_instance: MeshInstance3D = mesh as MeshInstance3D
			if mesh_instance != null:
				mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mesh_instance.set_surface_override_material(0, glove_material)

	var gold_material: StandardMaterial3D = _make_material(Color(0.839216, 0.694118, 0.368627, 1.0), 0.42)
	var gold_meshes: Array = [
		get_node_or_null("HandAnchor/CuffGoldTrim"),
		get_node_or_null("VialAnchor/VialAnchorGuide"),
		get_node_or_null("HandAnchor/FallbackGlove/CuffGoldTrim"),
		get_node_or_null("VialAnchor/FallbackVialAnchorGuide")
	]
	for mesh in gold_meshes:
		if mesh != null:
			var mesh_instance: MeshInstance3D = mesh as MeshInstance3D
			if mesh_instance != null:
				mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mesh_instance.set_surface_override_material(0, gold_material)


func _make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _disable_shadows_recursive(root: Node) -> void:
	if root is GeometryInstance3D:
		(root as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in root.get_children():
		_disable_shadows_recursive(child)


func _disable_runtime_collision_recursive(root: Node) -> void:
	if root is CollisionObject3D:
		var collision_object: CollisionObject3D = root as CollisionObject3D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
	if root is CollisionShape3D:
		(root as CollisionShape3D).disabled = true
	for child in root.get_children():
		_disable_runtime_collision_recursive(child)


func _ensure_required_nodes() -> void:
	if hand_anchor == null:
		hand_anchor = get_node_or_null("HandAnchor") as Node3D
	if hand_anchor == null:
		hand_anchor = Node3D.new()
		hand_anchor.name = "HandAnchor"
		add_child(hand_anchor)
	if vial_anchor == null:
		vial_anchor = get_node_or_null("VialAnchor") as Node3D
	if vial_anchor == null:
		vial_anchor = Node3D.new()
		vial_anchor.name = "VialAnchor"
		add_child(vial_anchor)
		vial_anchor.position = Vector3(0.002, -0.005, 0.0)
		vial_anchor.rotation_degrees = Vector3(-3.0, -6.0, 2.0)


func _create_fallback_glove_meshes() -> void:
	if hand_anchor == null or hand_anchor.get_node_or_null("FallbackGlove") != null:
		return
	var fallback_root: Node3D = Node3D.new()
	fallback_root.name = "FallbackGlove"
	hand_anchor.add_child(fallback_root)

	var glove_material: StandardMaterial3D = _make_material(Color(0.075, 0.029, 0.045, 1.0), 0.8)
	var gold_material: StandardMaterial3D = _make_material(Color(0.84, 0.69, 0.37, 1.0), 0.44)

	var palm_mesh: BoxMesh = BoxMesh.new()
	palm_mesh.size = Vector3(0.095, 0.055, 0.07)
	var palm: MeshInstance3D = _make_fallback_mesh("Palm", palm_mesh, glove_material)
	palm.position = Vector3(-0.01, 0.072, -0.061)
	palm.rotation_degrees = Vector3(6.0, -8.0, -4.0)
	fallback_root.add_child(palm)

	var finger_positions: Array = [
		Vector3(-0.033, 0.105, -0.029),
		Vector3(-0.003, 0.111, -0.036),
		Vector3(0.027, 0.101, -0.031)
	]
	var finger_rotations: Array = [
		Vector3(15.0, -18.0, -8.0),
		Vector3(11.0, -8.0, 0.0),
		Vector3(13.0, 4.0, 9.0)
	]
	var finger_names: Array = ["FingerIndex", "FingerMiddle", "FingerRing"]
	for i in range(finger_names.size()):
		var finger_mesh: CylinderMesh = CylinderMesh.new()
		finger_mesh.top_radius = 0.0105
		finger_mesh.bottom_radius = 0.013
		finger_mesh.height = 0.155
		finger_mesh.radial_segments = 10
		finger_mesh.rings = 2
		var finger: MeshInstance3D = _make_fallback_mesh(str(finger_names[i]), finger_mesh, glove_material)
		finger.position = finger_positions[i]
		finger.rotation_degrees = finger_rotations[i]
		fallback_root.add_child(finger)

	var thumb_mesh: CylinderMesh = CylinderMesh.new()
	thumb_mesh.top_radius = 0.012
	thumb_mesh.bottom_radius = 0.015
	thumb_mesh.height = 0.112
	thumb_mesh.radial_segments = 10
	thumb_mesh.rings = 2
	var thumb: MeshInstance3D = _make_fallback_mesh("Thumb", thumb_mesh, glove_material)
	thumb.position = Vector3(-0.053, 0.074, -0.023)
	thumb.rotation_degrees = Vector3(68.0, -18.0, -48.0)
	fallback_root.add_child(thumb)

	var cuff_mesh: BoxMesh = BoxMesh.new()
	cuff_mesh.size = Vector3(0.112, 0.036, 0.078)
	var wrist_cuff: MeshInstance3D = _make_fallback_mesh("WristCuff", cuff_mesh, glove_material)
	wrist_cuff.position = Vector3(-0.012, 0.012, -0.063)
	wrist_cuff.rotation_degrees = Vector3(4.0, -8.0, 0.0)
	fallback_root.add_child(wrist_cuff)

	var trim_mesh: BoxMesh = BoxMesh.new()
	trim_mesh.size = Vector3(0.104, 0.007, 0.084)
	var trim: MeshInstance3D = _make_fallback_mesh("CuffGoldTrim", trim_mesh, gold_material)
	trim.position = Vector3(-0.012, 0.033, -0.063)
	trim.rotation_degrees = Vector3(4.0, -8.0, 0.0)
	fallback_root.add_child(trim)

	if vial_anchor != null and vial_anchor.get_node_or_null("FallbackVialAnchorGuide") == null:
		var anchor_mesh: CylinderMesh = CylinderMesh.new()
		anchor_mesh.top_radius = 0.031
		anchor_mesh.bottom_radius = 0.031
		anchor_mesh.height = 0.006
		anchor_mesh.radial_segments = 18
		var anchor_guide: MeshInstance3D = _make_fallback_mesh("FallbackVialAnchorGuide", anchor_mesh, gold_material)
		anchor_guide.position = Vector3(0.0, 0.082, -0.027)
		anchor_guide.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		vial_anchor.add_child(anchor_guide)


func _make_fallback_mesh(mesh_name: String, mesh: Mesh, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = mesh_name
	mesh_instance.mesh = mesh
	mesh_instance.visible = true
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.set_surface_override_material(0, material)
	return mesh_instance
