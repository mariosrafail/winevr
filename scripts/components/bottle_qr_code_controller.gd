extends Node
class_name BottleQRCodeController

const FALLBACK_QR_IMAGE: String = "res://assets/qr/demo_winery_qr.png"

var vial: Node3D
var display_root: Interactable
var qr_mesh: MeshInstance3D
var qr_material: StandardMaterial3D
var current_organization_id: String = ""
var current_organization_name: String = ""
var current_target_url: String = ""


func setup(parent_vial: Node3D) -> void:
	vial = parent_vial
	_ensure_display_nodes()
	_update_display_transform()


func apply_selected_profile() -> void:
	if not AppState.selected_profile_data.is_empty():
		apply_profile(AppState.selected_profile_data)
		return
	if not AppState.selected_profile_id.is_empty():
		apply_profile(WineDatabase.get_profile_by_id(AppState.selected_profile_id))
		return
	apply_profile(WineDatabase.get_default_profile())


func apply_profile(profile_data: Dictionary) -> void:
	if vial == null:
		return
	_ensure_display_nodes()
	_update_display_transform()

	current_organization_id = str(profile_data.get("organization_id", profile_data.get("qr_id", profile_data.get("client_id", "demo_winery"))))
	current_organization_name = str(profile_data.get("organization_name", profile_data.get("winery_name", profile_data.get("winery", "Demo Winery"))))
	current_target_url = str(profile_data.get("qr_target_url", ""))
	var qr_path: String = str(profile_data.get("qr_code_image", _default_qr_for_key(current_organization_id)))

	var texture: Texture2D = _load_qr_texture(qr_path)
	var fallback_used: bool = false
	if texture == null and qr_path != FALLBACK_QR_IMAGE:
		fallback_used = true
		texture = _load_qr_texture(FALLBACK_QR_IMAGE)
	if texture == null:
		fallback_used = true
		texture = _make_generated_fallback_texture()

	qr_material.albedo_texture = texture
	_update_interactable_text()
	print("[WineVR][BottleQR] organization_id=%s qr_code_image=%s loaded=%s fallback=%s" % [
		current_organization_id,
		qr_path,
		str(texture != null),
		str(fallback_used)
	])


func refresh_transform() -> void:
	_update_display_transform()


func _ensure_display_nodes() -> void:
	if display_root == null:
		display_root = vial.get_node_or_null("BottleQRCodeDisplay") as Interactable
	if display_root == null:
		display_root = Interactable.new()
		display_root.name = "BottleQRCodeDisplay"
		display_root.id = "bottle_qr_code"
		display_root.title = "Winery QR"
		display_root.type = "generic"
		display_root.glow_on_hover = true
		vial.add_child(display_root)

	if qr_mesh == null:
		qr_mesh = display_root.get_node_or_null("QRCodeQuad") as MeshInstance3D
	if qr_mesh == null:
		qr_mesh = MeshInstance3D.new()
		qr_mesh.name = "QRCodeQuad"
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(0.026, 0.026)
		qr_mesh.mesh = quad
		qr_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		display_root.add_child(qr_mesh)

	if display_root.get_node_or_null("QRCodeBody") == null:
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "QRCodeBody"
		body.collision_layer = 0
		body.collision_mask = 0
		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.name = "QRCodeCollision"
		shape.disabled = true
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(0.03, 0.03, 0.004)
		shape.shape = box
		body.add_child(shape)
		display_root.add_child(body)

	if qr_material == null:
		qr_material = StandardMaterial3D.new()
		qr_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		qr_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		qr_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		qr_material.albedo_color = Color.WHITE
	qr_mesh.set_surface_override_material(0, qr_material)


func _update_display_transform() -> void:
	if vial == null or display_root == null:
		return
	var raw_height: Variant = vial.get("vial_height")
	var raw_radius: Variant = vial.get("vial_radius")
	var vial_height_value: float = float(raw_height) if raw_height != null else 0.26
	var vial_radius_value: float = float(raw_radius) if raw_radius != null else 0.018
	display_root.position = Vector3(0.0, vial_height_value * 0.47, vial_radius_value + 0.0016)
	display_root.rotation = Vector3.ZERO
	display_root.scale = Vector3.ONE


func _update_interactable_text() -> void:
	if display_root == null:
		return
	display_root.title = "Winery QR"
	display_root.description = "Scan this QR to learn more about %s\n%s" % [
		current_organization_name,
		current_target_url
	]


func _load_qr_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return null
	var resource: Resource = load(path)
	return resource as Texture2D


func _default_qr_for_key(key: String) -> String:
	var normalized: String = key.to_lower()
	if normalized.contains("naousa") or normalized.contains("naoussa") or normalized.contains("xinomavro"):
		return "res://assets/qr/naousa_cellar_qr.png"
	if normalized.contains("santorini") or normalized.contains("nemea") or normalized.contains("agiorgitiko"):
		return "res://assets/qr/santorini_estate_qr.png"
	return FALLBACK_QR_IMAGE


func _make_generated_fallback_texture() -> Texture2D:
	var image: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	for y in range(32):
		for x in range(32):
			var edge: bool = x < 2 or y < 2 or x > 29 or y > 29
			var pattern: bool = ((x * 13 + y * 7) % 5) == 0
			if edge or pattern:
				image.set_pixel(x, y, Color.BLACK)
	return ImageTexture.create_from_image(image)
