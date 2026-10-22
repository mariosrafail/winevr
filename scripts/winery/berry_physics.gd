extends Node3D

## Small, damped stem springs. Skinning preserves the authored vertices, UVs,
## materials and surface count; each disconnected berry gets one rigid bone.
var body: RigidBody3D
var berries: Array[Dictionary] = []
var _previous_velocity: Vector3
var _previous_angular_velocity: Vector3
var _previous_position: Vector3
var _initialized: bool = false
var _contacts: Array[Dictionary] = []
var _pull_stem: MeshInstance3D
var secondary_rotation: bool = false
var _neighbors: Array[Dictionary] = []

func configure_neighbor_contacts() -> void:
	_neighbors.clear()
	for a in range(berries.size()):
		for b in range(a + 1, berries.size()):
			var distance: float = Vector3(berries[a]["rest"]).distance_to(berries[b]["rest"])
			var strict: bool = berries[a].has("visual_basis") and berries[b].has("visual_basis")
			var radii: float = float(berries[a].get("contact_radius", berries[a]["radius"])) + float(berries[b].get("contact_radius", berries[b]["radius"]))
			if distance < radii + 0.018:
				# All packed grape models collide against ellipsoids enclosing
				# their actual skins, including each berry's stem bending.
				_neighbors.append({"a": a, "b": b, "strict": strict, "distance": minf(distance, radii * 0.98)})

func _refresh_contact_shape(berry: Dictionary) -> void:
	var mesh_to_body: Transform3D = berry["transform"]
	berry["contact_basis"] = (mesh_to_body.basis * Basis(berry.get("contact_rotation", Quaternion.IDENTITY)) * Basis(berry["visual_basis"])).transposed()

func _contact_extent(berry: Dictionary, normal: Vector3) -> float:
	return (Basis(berry["contact_basis"]) * normal).length()

func _bend_rotation(berry: Dictionary) -> Quaternion:
	if not secondary_rotation:
		return Quaternion.IDENTITY
	var offset: Vector3 = berry["offset"]
	var transform: Transform3D = berry["transform"]
	var rotation: Vector3 = transform.basis.orthonormalized().inverse() * Vector3(-offset.z, 0, offset.x) * 0.45 / maxf(0.004, float(berry["radius"]))
	return Quaternion(rotation.normalized(), rotation.length()) if rotation.length_squared() > 0.0000001 else Quaternion.IDENTITY

func _solve_neighbor_contacts() -> void:
	var strict_contacts: bool = not berries.is_empty() and berries[0].has("visual_basis")
	for berry: Dictionary in berries:
		if berry.has("visual_basis"):
			berry["contact_rotation"] = _bend_rotation(berry)
			_refresh_contact_shape(berry)
	for iteration in range(10 if strict_contacts else 2):
		var corrected: bool = false
		for pair: Dictionary in _neighbors:
			var a: Dictionary = berries[int(pair["a"])]
			var b: Dictionary = berries[int(pair["b"])]
			if bool(a["detached"]) or bool(b["detached"]) or bool(a["held"]) or bool(b["held"]):
				continue
			var separation: Vector3 = Vector3(b["rest"]) + Vector3(b["offset"]) - Vector3(a["rest"]) - Vector3(a["offset"])
			if separation.length_squared() < 0.00000001:
				continue
			var normal: Vector3 = separation.normalized()
			var required: float = _contact_extent(a, normal) + _contact_extent(b, normal) + 0.0004 if bool(pair["strict"]) else float(pair["distance"])
			var penetration: float = required - separation.length()
			if penetration <= 0.00000001:
				continue
			corrected = true
			var correction: Vector3 = normal * penetration * (0.501 if bool(pair["strict"]) else 0.35)
			a["offset"] = (Vector3(a["offset"]) - correction).limit_length(minf(0.008, float(a["radius"]) * 0.18))
			b["offset"] = (Vector3(b["offset"]) + correction).limit_length(minf(0.008, float(b["radius"]) * 0.18))
			var approach: float = (Vector3(b["velocity"]) - Vector3(a["velocity"])).dot(normal)
			if approach < 0.0:
				a["velocity"] = Vector3(a["velocity"]) + normal * approach * 0.50
				b["velocity"] = Vector3(b["velocity"]) - normal * approach * 0.50
		if not corrected:
			break

func _show_stem_stretch(berry: Dictionary) -> void:
	if _pull_stem == null:
		_pull_stem = MeshInstance3D.new()
		_pull_stem.name = "StretchingPedicel"
		var cylinder: CylinderMesh = CylinderMesh.new()
		cylinder.top_radius = 0.0009
		cylinder.bottom_radius = 0.0011
		cylinder.radial_segments = 6
		_pull_stem.mesh = cylinder
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color("797343")
		material.roughness = 0.85
		_pull_stem.material_override = material
		add_child(_pull_stem)
	var offset: Vector3 = berry["offset"]
	_pull_stem.visible = offset.length() > 0.002
	if _pull_stem.visible:
		(_pull_stem.mesh as CylinderMesh).height = offset.length()
		_pull_stem.position = Vector3(berry["rest"]) + Vector3.UP * float(berry["radius"]) * 0.85 + offset * 0.5
		_pull_stem.quaternion = Quaternion(Vector3.UP, offset.normalized())

func apply_contact_force(point: Vector3, force: Vector3) -> void:
	_contacts.append({"point": body.to_local(point), "force": body.global_basis.inverse() * force})

func setup(owner_body: RigidBody3D, model: Node3D) -> void:
	body = owner_body
	for node in model.find_children("*", "MeshInstance3D", true, false):
		_rig_mesh(node as MeshInstance3D)
	if not berries.is_empty() and berries[0].has("visual_basis"):
		configure_neighbor_contacts()

func _root(parents: PackedInt32Array, index: int) -> int:
	while parents[index] != index:
		index = parents[index]
	return index

func _rig_mesh(instance: MeshInstance3D) -> void:
	var source: Mesh = instance.mesh
	var skeleton: Skeleton3D = Skeleton3D.new()
	skeleton.name = "BerryStemSprings"
	instance.add_child(skeleton)
	skeleton.add_bone("Stem")
	var skin: Skin = Skin.new()
	skin.add_bind(0, Transform3D.IDENTITY)
	var result: ArrayMesh = ArrayMesh.new()
	var mesh_to_body: Transform3D = body.global_transform.affine_inverse() * instance.global_transform
	var original_count: int = berries.size()
	for surface in range(source.get_surface_count()):
		var arrays: Array = source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var material: Material = instance.get_active_material(surface)
		var is_fruit: bool = (material != null and "baked skin" in material.resource_name) or instance.name == "VidianoBerries"
		var bones: PackedInt32Array = PackedInt32Array()
		var weights: PackedFloat32Array = PackedFloat32Array()
		bones.resize(vertices.size() * 4)
		weights.resize(vertices.size() * 4)
		for index in range(vertices.size()):
			weights[index * 4] = 1.0
		if is_fruit:
			var parents: PackedInt32Array = PackedInt32Array()
			parents.resize(vertices.size())
			var welded: Dictionary = {}
			for index in range(vertices.size()):
				parents[index] = index
				# UV seams duplicate vertices. Weld only for connectivity, never
				# modify the actual render geometry or its normals/tangents.
				var key: Vector3i = Vector3i((vertices[index] * 100000.0).round())
				if welded.has(key):
					parents[index] = int(welded[key])
				else:
					welded[key] = index
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			for triangle in range(0, indices.size() if not indices.is_empty() else vertices.size(), 3):
				var a: int = _root(parents, indices[triangle] if not indices.is_empty() else triangle)
				for corner in [1, 2]:
					var b: int = _root(parents, indices[triangle + corner] if not indices.is_empty() else triangle + corner)
					parents[b] = a
			var groups: Dictionary = {}
			for index in range(vertices.size()):
				var key: int = _root(parents, index)
				if not groups.has(key):
					groups[key] = []
				groups[key].append(index)
			for group: Array in groups.values():
				if group.size() < 12:
					continue
				var bounds: AABB = AABB(vertices[group[0]], Vector3.ZERO)
				for index: int in group:
					bounds = bounds.expand(vertices[index])
				var center: Vector3 = bounds.get_center()
				var world_size: Vector3 = bounds.size * mesh_to_body.basis.get_scale().abs()
				var radius: float = minf(world_size.x, minf(world_size.y, world_size.z)) * 0.48
				if radius < 0.004:
					continue
				var bone: int = skeleton.get_bone_count()
				skeleton.add_bone("Berry_%s" % bone)
				skeleton.set_bone_rest(bone, Transform3D(Basis.IDENTITY, center))
				skeleton.set_bone_pose_position(bone, center)
				skin.add_bind(bone, Transform3D(Basis.IDENTITY, -center))
				for index: int in group:
					bones[index * 4] = bone
				var collider: CollisionShape3D = CollisionShape3D.new()
				var sphere: SphereShape3D = SphereShape3D.new()
				sphere.radius = radius
				collider.shape = sphere
				body.add_child(collider)
				collider.position = mesh_to_body * center
				collider.set_meta("berry_index", berries.size())
				var visual_shapes: Array = instance.get_meta("berry_shapes", [])
				var visual_index: int = berries.size() - original_count
				berries.append({"skeleton": skeleton, "bone": bone, "center": center,
					"source_arrays": arrays.duplicate(), "vertices": PackedInt32Array(group), "material": material,
					"held": false, "detached": false, "loose_body": null,
					"transform": mesh_to_body, "rest": collider.position, "collider": collider,
					"radius": radius, "offset": Vector3.ZERO, "velocity": Vector3.ZERO,
					"frequency": lerpf(33.0, 24.0, clampf(radius / 0.05, 0.0, 1.0))})
				if visual_index < visual_shapes.size():
					var shape: Transform3D = visual_shapes[visual_index]
					berries.back()["visual_basis"] = shape.basis
					var axes: Vector3 = (mesh_to_body.basis * shape.basis).get_scale().abs()
					berries.back()["contact_radius"] = maxf(axes.x, maxf(axes.y, axes.z))
					berries.back()["contact_rotation"] = Quaternion.IDENTITY
					_refresh_contact_shape(berries.back())

		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(surface, material)
	if berries.size() == original_count:
		skeleton.queue_free()
		return
	instance.mesh = result
	instance.skin = skin
	instance.skeleton = instance.get_path_to(skeleton)
	instance.custom_aabb = source.get_aabb().grow(0.02 / maxf(0.01, mesh_to_body.basis.get_scale().x))

func reset_motion() -> void:
	_initialized = false
	_contacts.clear()
	for berry: Dictionary in berries:
		if bool(berry["detached"]) or bool(berry["held"]):
			continue
		berry["offset"] = Vector3.ZERO
		berry["velocity"] = Vector3.ZERO
		if berry.has("visual_basis"):
			berry["contact_rotation"] = Quaternion.IDENTITY
			_refresh_contact_shape(berry)
		_apply_pose(berry)

func _physics_process(delta: float) -> void:
	if body == null:
		return
	if not is_visible_in_tree() or (body.freeze and not body.get_meta("demo_inspection", false)):
		if _initialized:
			reset_motion()
		_contacts.clear()
		return
	var dt: float = minf(delta, 1.0 / 30.0)
	if not _initialized or body.global_position.distance_to(_previous_position) > 0.25:
		_previous_velocity = body.linear_velocity
		_previous_angular_velocity = body.angular_velocity
		_initialized = true
	var acceleration: Vector3 = ((body.linear_velocity - _previous_velocity) / maxf(delta, 0.0001)).limit_length(45.0)
	var angular_acceleration: Vector3 = ((body.angular_velocity - _previous_angular_velocity) / maxf(delta, 0.0001)).limit_length(60.0)
	_previous_position = body.global_position
	_previous_velocity = body.linear_velocity
	_previous_angular_velocity = body.angular_velocity
	var inverse: Basis = body.global_basis.inverse()
	for berry: Dictionary in berries:
		if bool(berry["detached"]) or bool(berry["held"]):
			continue
		var lever: Vector3 = body.global_basis * (Vector3(berry["rest"]) - body.center_of_mass)
		var inertial: Vector3 = -acceleration - angular_acceleration.cross(lever) - body.angular_velocity.cross(body.angular_velocity.cross(lever))
		# Rest geometry already includes the weight of hanging fruit. Changing
		# orientation bends the short pedicels relative to that resting pose.
		var gravity: Vector3 = inverse * Vector3.DOWN * 9.81 - Vector3.DOWN * 9.81
		var forcing: Vector3 = (inverse * inertial + gravity).limit_length(50.0)
		for contact: Dictionary in _contacts:
			var distance: float = Vector3(berry["rest"]).distance_to(contact["point"])
			var influence: float = 1.0 - smoothstep(float(berry["radius"]), float(berry["radius"]) * 3.0, distance)
			# A palm distributes the load across nearby berries; the flexible
			# pedicels transmit the remaining force to the suspended bunch.
			forcing += Vector3(contact["force"]) * influence * 12.0
		forcing = forcing.limit_length(50.0)
		var offset: Vector3 = berry["offset"]
		var velocity: Vector3 = berry["velocity"]
		var frequency: float = berry["frequency"]
		# Substeps keep the springs stable at both 30 Hz and high frame rates.
		var steps: int = maxi(1, ceili(dt / (1.0 / 120.0)))
		var step: float = dt / steps
		var limit: float = minf(0.008, float(berry["radius"]) * 0.18)
		for substep in range(steps):
			velocity += (forcing - offset * frequency * frequency - velocity * frequency * 0.9) * step
			offset += velocity * step
			if offset.length() > limit:
				offset = offset.limit_length(limit)
				var outward: Vector3 = offset.normalized()
				velocity -= outward * maxf(0.0, velocity.dot(outward))
		berry["offset"] = offset
		berry["velocity"] = velocity
		if _neighbors.is_empty():
			_apply_pose(berry)
	if not _neighbors.is_empty():
		_solve_neighbor_contacts()
		for berry: Dictionary in berries:
			if not bool(berry["detached"]):
				_apply_pose(berry)
	_contacts.clear()

func _apply_pose(berry: Dictionary) -> void:
	var offset: Vector3 = berry["offset"]
	var transform: Transform3D = berry["transform"]
	(berry["skeleton"] as Skeleton3D).set_bone_pose_position(int(berry["bone"]), Vector3(berry["center"]) + transform.basis.inverse() * offset)
	if secondary_rotation:
		var rotation: Quaternion = berry.get("contact_rotation", _bend_rotation(berry)) if berry.has("visual_basis") else _bend_rotation(berry)
		(berry["skeleton"] as Skeleton3D).set_bone_pose_rotation(int(berry["bone"]), rotation)
	var collider: CollisionShape3D = berry["collider"]
	var target: Vector3 = Vector3(berry["rest"]) + offset
	if not collider.position.is_equal_approx(target):
		collider.position = target

func berry_for_shape(shape_index: int) -> int:
	var owner_id: int = body.shape_find_owner(shape_index)
	var shape: Object = body.shape_owner_get_owner(owner_id)
	return int(shape.get_meta("berry_index", -1)) if shape != null else -1

func berry_position(index: int) -> Vector3:
	var berry: Dictionary = berries[index]
	return body.to_global(Vector3(berry["rest"]) + Vector3(berry["offset"]))

func pinch_radii(index: int, axis: Vector3) -> Vector2:
	var berry: Dictionary = berries[index]
	var faces: PackedVector3Array = _berry_mesh(berry).get_faces()
	var basis: Basis = body.global_basis * (berry["transform"] as Transform3D).basis
	for vertex in range(faces.size()):
		faces[vertex] = basis * faces[vertex] * 32.0
	var triangles: TriangleMesh = TriangleMesh.new()
	triangles.create_from_faces(faces)
	var radii: Vector2 = Vector2.ONE * float(berry["radius"])
	for side in range(2):
		var hit: Dictionary = triangles.intersect_segment(axis * (6.4 if side == 0 else -6.4), Vector3.ZERO)
		if not hit.is_empty():
			radii[side] = Vector3(hit["position"]).length() / 32.0
	return radii

func pinch_mesh(index: int) -> Mesh:
	return _berry_mesh(berries[index])

func pinch_mesh_transform(index: int) -> Transform3D:
	return Transform3D(body.global_basis * (berries[index]["transform"] as Transform3D).basis, berry_position(index))

func pull_berry(index: int, goal: Vector3, delta: float) -> float:
	var berry: Dictionary = berries[index]
	var extension: Vector3 = body.to_local(goal) - Vector3(berry["rest"])
	berry["held"] = true
	# The pedicel initially yields, then stiffens. Extra mouse travel loads the
	# stem rather than teleporting the fruit straight to the pointer.
	var stretch: float = 0.026 * (1.0 - exp(-extension.length() / 0.050))
	var target_offset: Vector3 = extension.normalized() * stretch
	berry["offset"] = Vector3(berry["offset"]).lerp(target_offset, 1.0 - exp(-delta * 11.0))
	berry["velocity"] = Vector3.ZERO
	_apply_pose(berry)
	_show_stem_stretch(berry)
	body.sleeping = false
	body.apply_force((body.global_basis * extension * 5.0).limit_length(0.45), berry_position(index) - body.global_position)
	return extension.length()

func release_berry(index: int) -> void:
	if _pull_stem != null:
		_pull_stem.visible = false
	if index >= 0 and index < berries.size():
		berries[index]["held"] = false

func detach_berry(index: int) -> RigidBody3D:
	if _pull_stem != null:
		_pull_stem.visible = false
	var berry: Dictionary = berries[index]
	if bool(berry["detached"]):
		return berry["loose_body"] as RigidBody3D
	var loose: RigidBody3D = RigidBody3D.new()
	loose.name = "DetachedBerry_%s" % index
	loose.mass = clampf(0.004 * pow(float(berry["radius"]) / 0.02, 3.0), 0.002, 0.03)
	loose.collision_layer = 4
	loose.collision_mask = 6
	loose.continuous_cd = true
	loose.linear_damp = 0.35
	loose.angular_damp = 0.4
	loose.physics_material_override = body.physics_material_override
	# Keep loose fruit under the museum branch, never under the moving bunch.
	var museum_root: Node3D = body.get_parent().get_parent() as Node3D
	museum_root.add_child(loose)
	loose.global_transform = Transform3D(body.global_basis, berry_position(index))
	loose.set_meta("detached_berry", true)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = (berry["collider"] as CollisionShape3D).shape
	loose.add_child(shape)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = _berry_mesh(berry)
	mesh.basis = (berry["transform"] as Transform3D).basis
	loose.add_child(mesh)
	loose.linear_velocity = body.linear_velocity + body.angular_velocity.cross(loose.global_position - body.to_global(body.center_of_mass))
	loose.angular_velocity = body.angular_velocity
	# The old skin collapses only this berry's triangles; the new body uses
	# their exact authored geometry, UVs, normals and original material.
	(berry["skeleton"] as Skeleton3D).set_bone_pose_scale(int(berry["bone"]), Vector3.ZERO)
	(berry["collider"] as CollisionShape3D).disabled = true
	berry["detached"] = true
	berry["held"] = false
	berry["loose_body"] = loose
	return loose

func _berry_mesh(berry: Dictionary) -> ArrayMesh:
	if berry.has("pick_mesh"):
		return berry["pick_mesh"] as ArrayMesh
	var source: Array = berry["source_arrays"]
	var selected: PackedInt32Array = berry["vertices"]
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var remap: Dictionary = {}
	for index in range(selected.size()):
		remap[selected[index]] = index
	for slot in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		if source[slot] == null:
			continue
		var values: Variant = source[slot].duplicate()
		values.resize(0)
		for index in selected:
			if slot == Mesh.ARRAY_TANGENT:
				for component in range(4):
					values.append(source[slot][index * 4 + component])
			else:
				values.append(source[slot][index] - Vector3(berry["center"]) if slot == Mesh.ARRAY_VERTEX else source[slot][index])
		arrays[slot] = values
	var indices: PackedInt32Array = PackedInt32Array()
	var original: PackedInt32Array = source[Mesh.ARRAY_INDEX] if source[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	for triangle in range(0, original.size() if not original.is_empty() else source[Mesh.ARRAY_VERTEX].size(), 3):
		var first: int = original[triangle] if not original.is_empty() else triangle
		if remap.has(first):
			for corner in range(3):
				indices.append(int(remap[original[triangle + corner] if not original.is_empty() else triangle + corner]))
	arrays[Mesh.ARRAY_INDEX] = indices
	var result: ArrayMesh = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	result.surface_set_material(0, berry["material"])
	berry["pick_mesh"] = result
	return result

func restore_berries() -> void:
	for berry: Dictionary in berries:
		var loose: RigidBody3D = berry["loose_body"] as RigidBody3D
		if is_instance_valid(loose):
			loose.queue_free()
		berry["loose_body"] = null
		berry["detached"] = false
		berry["held"] = false
		(berry["skeleton"] as Skeleton3D).set_bone_pose_scale(int(berry["bone"]), Vector3.ONE)
		(berry["collider"] as CollisionShape3D).disabled = false
	reset_motion()
