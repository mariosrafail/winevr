@tool
extends Node3D
class_name Vial

# Real-world style dimensions in meters.
# Tweak this to control total vial height.
@export_range(0.12, 0.5, 0.001) var vial_height: float = 0.26
# Tweak this to control vial radius.
@export_range(0.008, 0.04, 0.0005) var vial_radius: float = 0.018
# Glass wall thickness.
@export_range(0.0008, 0.006, 0.0001) var glass_thickness: float = 0.0016
@export_range(0.0015, 0.02, 0.0001) var base_thickness: float = 0.0032
@export_range(0.0004, 0.004, 0.0001) var edge_rounding: float = 0.0012

# Liquid fill amount from 0.0 to 1.0 of usable interior height.
@export_range(0.0, 1.0, 0.01) var liquid_fill_amount: float = 0.70
# Tweak this to change the wine tone.
@export var liquid_color: Color = Color(0.28, 0.04, 0.09, 0.98)
@export var cap_color: Color = Color(0.03, 0.03, 0.03, 1.0)
@export_range(0.0, 1.0, 0.01) var liquid_tilt_response: float = 0.42
@export_range(0.0, 1.0, 0.01) var liquid_slosh_response: float = 0.34

@export_range(0.008, 0.05, 0.0005) var cap_height: float = 0.022
@export_range(0.0005, 0.006, 0.0001) var cap_overhang: float = 0.0022
@export_range(32, 192, 1) var radial_segments: int = 96

@export var rebuild_now: bool = false

var _glass_body: MeshInstance3D
var _liquid: MeshInstance3D
var _liquid_surface: MeshInstance3D
var _cap: MeshInstance3D

var _glass_material: StandardMaterial3D
var _liquid_material: StandardMaterial3D
var _liquid_surface_material: StandardMaterial3D
var _cap_material: StandardMaterial3D

var _last_signature: String = ""
var _editor_check_interval: float = 0.25
var _editor_check_accum: float = 0.0
var _surface_tilt: Vector2 = Vector2.ZERO
var _surface_tilt_target: Vector2 = Vector2.ZERO
var _surface_tilt_velocity: Vector2 = Vector2.ZERO


func _ready() -> void:
	_glass_body = get_node_or_null("GlassBody")
	_liquid = get_node_or_null("Liquid")
	_liquid_surface = get_node_or_null("LiquidSurface")
	_cap = get_node_or_null("Cap")

	if _glass_body == null or _liquid == null or _cap == null:
		push_warning("Vial scene requires MeshInstance3D nodes named GlassBody, Liquid, and Cap.")
		return
	if _liquid_surface == null:
		_liquid_surface = MeshInstance3D.new()
		_liquid_surface.name = "LiquidSurface"
		add_child(_liquid_surface)
	_liquid_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_build_materials()
	_rebuild_geometry()


func _process(delta: float) -> void:
	_update_liquid_surface(delta)

	if not Engine.is_editor_hint():
		return
	if _glass_body == null or _liquid == null or _cap == null:
		return

	_editor_check_accum += delta
	if _editor_check_accum < _editor_check_interval and not rebuild_now:
		return
	_editor_check_accum = 0.0

	if rebuild_now:
		rebuild_now = false
		_rebuild_geometry()
		return

	var sig := _build_signature()
	if sig != _last_signature:
		_rebuild_geometry()


func _build_signature() -> String:
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		str(vial_height),
		str(vial_radius),
		str(glass_thickness),
		str(base_thickness),
		str(edge_rounding),
		str(liquid_fill_amount),
		str(liquid_color),
		str(liquid_tilt_response),
		str(liquid_slosh_response),
		str(cap_height),
		str(cap_overhang),
		str(radial_segments) + "|" + str(cap_color)
	]


func _build_materials() -> void:
	_glass_material = StandardMaterial3D.new()
	_glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glass_material.albedo_color = Color(0.92, 0.93, 0.95, 0.1)
	_glass_material.metallic = 0.0
	_glass_material.roughness = 0.035
	_glass_material.specular = 0.95
	_glass_material.rim_enabled = true
	_glass_material.rim = 0.14
	_glass_material.rim_tint = 0.25
	_glass_material.clearcoat_enabled = true
	_glass_material.clearcoat = 1.0
	_glass_material.clearcoat_roughness = 0.02
	_glass_material.refraction_enabled = true
	_glass_material.refraction_scale = 0.018

	_liquid_material = StandardMaterial3D.new()
	_liquid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_liquid_material.cull_mode = BaseMaterial3D.CULL_BACK
	_liquid_material.albedo_color = liquid_color.darkened(0.12)
	_liquid_material.roughness = 0.07
	_liquid_material.specular = 0.96
	_liquid_material.rim_enabled = true
	_liquid_material.rim = 0.08
	_liquid_material.rim_tint = 0.2
	_liquid_material.clearcoat_enabled = true
	_liquid_material.clearcoat = 0.72
	_liquid_material.clearcoat_roughness = 0.02

	_liquid_surface_material = StandardMaterial3D.new()
	_liquid_surface_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_liquid_surface_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_liquid_surface_material.albedo_color = liquid_color.lightened(0.18)
	_liquid_surface_material.roughness = 0.035
	_liquid_surface_material.specular = 1.0
	_liquid_surface_material.rim_enabled = true
	_liquid_surface_material.rim = 0.22
	_liquid_surface_material.rim_tint = 0.36
	_liquid_surface_material.clearcoat_enabled = true
	_liquid_surface_material.clearcoat = 0.9
	_liquid_surface_material.clearcoat_roughness = 0.015

	_cap_material = StandardMaterial3D.new()
	_cap_material.albedo_color = cap_color
	_cap_material.roughness = 0.9
	_cap_material.metallic = 0.0
	_cap_material.specular = 0.12


func rebuild_vial() -> void:
	if _glass_body == null or _liquid == null or _cap == null:
		return
	_rebuild_geometry()


func add_liquid_interaction(relative_motion: Vector2) -> void:
	if _liquid_surface == null:
		return
	var response: float = clampf(liquid_tilt_response, 0.0, 1.0)
	var slosh: float = clampf(liquid_slosh_response, 0.0, 1.0)
	var target: Vector2 = Vector2(
		-relative_motion.y,
		relative_motion.x
	) * response * 0.0018
	target.x = clampf(target.x, deg_to_rad(-7.0), deg_to_rad(7.0))
	target.y = clampf(target.y, deg_to_rad(-7.0), deg_to_rad(7.0))
	_surface_tilt_target = target
	_surface_tilt_velocity += target * (2.8 + slosh * 8.0)


func reset_liquid_motion() -> void:
	_surface_tilt = Vector2.ZERO
	_surface_tilt_target = Vector2.ZERO
	_surface_tilt_velocity = Vector2.ZERO
	if _liquid_surface != null:
		_liquid_surface.rotation = Vector3.ZERO


func _rebuild_geometry() -> void:
	var outer_r: float = vial_radius
	var inner_r: float = max(vial_radius - glass_thickness, vial_radius * 0.55)
	var body_h: float = max(vial_height, 0.12)
	var safe_base: float = clampf(base_thickness, glass_thickness * 1.2, body_h * 0.3)

	var glass_mesh := _build_glass_mesh(outer_r, inner_r, body_h, safe_base, radial_segments)
	_glass_body.mesh = glass_mesh
	_glass_body.set_surface_override_material(0, _glass_material)

	var liquid_mesh_data := _build_liquid_mesh(inner_r, body_h, safe_base)
	_liquid.mesh = liquid_mesh_data["mesh"]
	_liquid.position.y = liquid_mesh_data["center_y"]
	_liquid_material.albedo_color = liquid_color.darkened(0.12)
	_liquid.set_surface_override_material(0, _liquid_material)
	if _liquid_surface != null:
		_liquid_surface.mesh = liquid_mesh_data["surface_mesh"]
		_liquid_surface.position.y = liquid_mesh_data["surface_y"]
		_liquid_surface_material.albedo_color = Color(
			minf(liquid_color.r + 0.14, 1.0),
			minf(liquid_color.g + 0.12, 1.0),
			minf(liquid_color.b + 0.1, 1.0),
			clampf(liquid_color.a, 0.72, 0.98)
		)
		_liquid_surface.set_surface_override_material(0, _liquid_surface_material)

	var cap_mesh := _build_cap_mesh(outer_r + cap_overhang, cap_height, radial_segments)
	_cap.mesh = cap_mesh
	_cap.position.y = body_h + cap_height * 0.5
	_cap_material.albedo_color = cap_color
	_cap.set_surface_override_material(0, _cap_material)

	_last_signature = _build_signature()


func _build_liquid_mesh(inner_r: float, body_h: float, safe_base: float) -> Dictionary:
	var wall_gap: float = max(0.0007, glass_thickness * 0.45)
	var liquid_r: float = max(inner_r - wall_gap, inner_r * 0.82)
	var top_clearance: float = 0.008
	var interior_h: float = max(body_h - safe_base - top_clearance, 0.02)
	var fill: float = clampf(liquid_fill_amount, 0.0, 1.0)
	var liquid_top_y: float = safe_base + interior_h * fill
	var liquid_join_y: float = safe_base + liquid_r
	liquid_top_y = max(liquid_top_y, liquid_join_y + 0.001)

	var liquid_cyl_h: float = max(liquid_top_y - liquid_join_y, 0.001)

	var cylinder := CylinderMesh.new()
	cylinder.top_radius = liquid_r
	cylinder.bottom_radius = liquid_r
	cylinder.height = liquid_cyl_h
	cylinder.radial_segments = radial_segments
	cylinder.rings = 6
	cylinder.cap_top = false
	cylinder.cap_bottom = false

	var hemisphere := SphereMesh.new()
	hemisphere.radius = liquid_r
	hemisphere.height = liquid_r * 2.0
	hemisphere.radial_segments = radial_segments
	hemisphere.rings = maxi(12, int(radial_segments / 3))
	hemisphere.is_hemisphere = true

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(
		cylinder,
		0,
		Transform3D(Basis.IDENTITY, Vector3(0.0, liquid_join_y + liquid_cyl_h * 0.5, 0.0))
	)
	st.append_from(
		hemisphere,
		0,
		Transform3D(Basis.from_euler(Vector3(PI, 0.0, 0.0)), Vector3(0.0, liquid_join_y, 0.0))
	)
	st.generate_normals()
	var mesh := st.commit()

	var surface_mesh := CylinderMesh.new()
	surface_mesh.top_radius = liquid_r * 0.985
	surface_mesh.bottom_radius = liquid_r * 0.985
	surface_mesh.height = 0.0007
	surface_mesh.radial_segments = radial_segments
	surface_mesh.rings = 1
	surface_mesh.cap_top = true
	surface_mesh.cap_bottom = true

	var center_y: float = 0.0
	return {
		"mesh": mesh,
		"center_y": center_y,
		"surface_mesh": surface_mesh,
		"surface_y": liquid_top_y
	}


func _build_glass_mesh(outer_r: float, inner_r: float, body_h: float, safe_base: float, segs: int) -> ArrayMesh:
	var outer_join_y: float = outer_r
	var outer_cyl_h: float = max(body_h - outer_join_y, 0.02)
	var inner_join_y: float = safe_base + inner_r
	var inner_cyl_h: float = max(body_h - inner_join_y, 0.01)

	var outer_cylinder := CylinderMesh.new()
	outer_cylinder.top_radius = outer_r
	outer_cylinder.bottom_radius = outer_r
	outer_cylinder.height = outer_cyl_h
	outer_cylinder.radial_segments = segs
	outer_cylinder.rings = 8
	outer_cylinder.cap_top = false
	outer_cylinder.cap_bottom = false

	var outer_hemisphere := SphereMesh.new()
	outer_hemisphere.radius = outer_r
	outer_hemisphere.height = outer_r * 2.0
	outer_hemisphere.radial_segments = segs
	outer_hemisphere.rings = maxi(12, int(segs / 3))
	outer_hemisphere.is_hemisphere = true

	var inner_cylinder := CylinderMesh.new()
	inner_cylinder.top_radius = inner_r
	inner_cylinder.bottom_radius = inner_r
	inner_cylinder.height = inner_cyl_h
	inner_cylinder.radial_segments = segs
	inner_cylinder.rings = 8
	inner_cylinder.cap_top = false
	inner_cylinder.cap_bottom = false

	var inner_hemisphere := SphereMesh.new()
	inner_hemisphere.radius = inner_r
	inner_hemisphere.height = inner_r * 2.0
	inner_hemisphere.radial_segments = segs
	inner_hemisphere.rings = maxi(12, int(segs / 3))
	inner_hemisphere.is_hemisphere = true

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(
		outer_cylinder,
		0,
		Transform3D(Basis.IDENTITY, Vector3(0.0, outer_join_y + outer_cyl_h * 0.5, 0.0))
	)
	st.append_from(
		outer_hemisphere,
		0,
		Transform3D(Basis.from_euler(Vector3(PI, 0.0, 0.0)), Vector3(0.0, outer_join_y, 0.0))
	)
	st.append_from(
		inner_cylinder,
		0,
		Transform3D(Basis.IDENTITY, Vector3(0.0, inner_join_y + inner_cyl_h * 0.5, 0.0))
	)
	st.append_from(
		inner_hemisphere,
		0,
		Transform3D(Basis.from_euler(Vector3(PI, 0.0, 0.0)), Vector3(0.0, inner_join_y, 0.0))
	)

	# Top rim ring to reveal wall thickness at the opening.
	_add_annulus(st, body_h, outer_r, inner_r, false, segs)

	st.generate_normals()
	return st.commit()


func _build_cap_mesh(cap_r: float, cap_h: float, segs: int) -> ArrayMesh:
	var base := CylinderMesh.new()
	base.top_radius = cap_r
	base.bottom_radius = cap_r * 0.985
	base.height = cap_h
	base.radial_segments = segs
	base.rings = 6
	base.cap_top = true
	base.cap_bottom = true

	var ridge_height: float = cap_h * 0.08
	var ridge_radius: float = cap_r + min(cap_r * 0.045, 0.0015)
	var ridge_count: int = 3
	var ridge_y := PackedFloat32Array([
		-cap_h * 0.22,
		0.0,
		cap_h * 0.22
	])

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(base, 0, Transform3D(Basis.IDENTITY, Vector3.ZERO))

	for i in range(ridge_count):
		var ring := CylinderMesh.new()
		ring.top_radius = ridge_radius
		ring.bottom_radius = ridge_radius
		ring.height = ridge_height
		ring.radial_segments = segs
		ring.rings = 1
		ring.cap_top = false
		ring.cap_bottom = false
		st.append_from(
			ring,
			0,
			Transform3D(Basis.IDENTITY, Vector3(0.0, ridge_y[i], 0.0))
		)

	st.generate_normals()
	return st.commit()


func _add_annulus(st: SurfaceTool, y: float, outer_r: float, inner_r: float, upside_down: bool, segs: int) -> void:
	for i in range(segs):
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)

		var o0 := Vector3(cos(a0) * outer_r, y, sin(a0) * outer_r)
		var o1 := Vector3(cos(a1) * outer_r, y, sin(a1) * outer_r)
		var i0 := Vector3(cos(a0) * inner_r, y, sin(a0) * inner_r)
		var i1 := Vector3(cos(a1) * inner_r, y, sin(a1) * inner_r)

		if inner_r <= 0.000001:
			var c := Vector3(0.0, y, 0.0)
			if upside_down:
				_add_tri(st, c, o1, o0)
			else:
				_add_tri(st, c, o0, o1)
		else:
			if upside_down:
				_add_tri(st, i0, o1, o0)
				_add_tri(st, i0, i1, o1)
			else:
				_add_tri(st, i0, o0, o1)
				_add_tri(st, i0, o1, i1)


func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


func _update_liquid_surface(delta: float) -> void:
	if _liquid_surface == null:
		return
	_surface_tilt_target = _surface_tilt_target.move_toward(Vector2.ZERO, delta * 0.45)
	var spring: float = 26.0
	var damping: float = 4.6
	_surface_tilt_velocity += (_surface_tilt_target - _surface_tilt) * spring * delta
	_surface_tilt_velocity = _surface_tilt_velocity.lerp(Vector2.ZERO, clampf(damping * delta, 0.0, 1.0))
	_surface_tilt += _surface_tilt_velocity * delta
	_surface_tilt.x = clampf(_surface_tilt.x, deg_to_rad(-8.0), deg_to_rad(8.0))
	_surface_tilt.y = clampf(_surface_tilt.y, deg_to_rad(-8.0), deg_to_rad(8.0))
	_liquid_surface.rotation = Vector3(_surface_tilt.x, 0.0, _surface_tilt.y)
