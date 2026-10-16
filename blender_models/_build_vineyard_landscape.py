import bpy
import math
import random
from pathlib import Path
from mathutils import Vector, Quaternion


ROOT = Path(r"C:\Users\mario\Nextcloud\wine-vr")
SOURCE_GRAPES = ROOT / "blender_models" / "grapes_game_vr.blend"
OUT_DIR = ROOT / "assets" / "models" / "vineyard_landscape"
OUT_BLEND = ROOT / "blender_models" / "vineyard_landscape.blend"
OUT_GLB = OUT_DIR / "vineyard_landscape.glb"
OUT_PREVIEW = ROOT / "blender_models" / "vineyard_landscape_preview.png"

OUT_DIR.mkdir(parents=True, exist_ok=True)
random.seed(2601001)


def log(msg):
    print(f"[VINEYARD] {msg}", flush=True)


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat_principled(name, color, roughness=0.75, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    p = mat.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*color, 1.0)
    p.inputs["Roughness"].default_value = roughness
    p.inputs["Metallic"].default_value = metallic
    if p.inputs.get("Specular IOR Level"):
        p.inputs["Specular IOR Level"].default_value = 0.28
    return mat


def mat_emissive(name, color, strength=3.0):
    mat = mat_principled(name, color, 1.0, 0.0)
    p = mat.node_tree.nodes.get("Principled BSDF")
    if p.inputs.get("Emission Color"):
        p.inputs["Emission Color"].default_value = (*color, 1.0)
    elif p.inputs.get("Emission"):
        p.inputs["Emission"].default_value = (*color, 1.0)
    if p.inputs.get("Emission Strength"):
        p.inputs["Emission Strength"].default_value = strength
    return mat


def activate(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def join(objects, name):
    if not objects:
        return None
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    out = bpy.context.active_object
    out.name = name
    return out


def add_box(name, location, scale, material, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    if bevel > 0.0:
        mod = obj.modifiers.new("Soft edges", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        activate(obj)
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def add_cylinder(name, location, radius, depth, material, vertices=12, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


def curve_branch(name, points, radii, material, bevel=0.12, resolution=2, bevel_resolution=2):
    curve = bpy.data.curves.new(name + "_Curve", "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = resolution
    curve.bevel_depth = bevel
    curve.bevel_resolution = bevel_resolution
    curve.materials.append(material)
    sp = curve.splines.new("NURBS")
    sp.points.add(len(points) - 1)
    for i, (p, r) in enumerate(zip(points, radii)):
        sp.points[i].co = (*p, 1)
        sp.points[i].radius = r
    sp.order_u = min(4, len(points))
    sp.use_endpoint_u = True
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    return obj


def append_grape_leaf_template():
    with bpy.data.libraries.load(str(SOURCE_GRAPES), link=False) as (src, dst):
        if "GrapeLeaf_Blade" not in src.objects:
            raise RuntimeError("GrapeLeaf_Blade missing from grapes_game_vr.blend")
        dst.objects = ["GrapeLeaf_Blade"]
    leaf = dst.objects[0]
    bpy.context.collection.objects.link(leaf)
    leaf.name = "_LandscapeGrapeLeafTemplate"
    activate(leaf)
    # Preserve the authored grape-leaf silhouette and UVs, but reduce it to a
    # very small background asset before copying it hundreds of times.
    dec = leaf.modifiers.new("Landscape leaf optimization", "DECIMATE")
    dec.ratio = 0.0065
    dec.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=dec.name)
    for poly in leaf.data.polygons:
        poly.use_smooth = True
    log(f"grape leaf template polygons={len(leaf.data.polygons)}")
    return leaf


def append_template_geometry(template, center, normal, scale, spin, verts, faces, uvs):
    normal = Vector(normal).normalized()
    q = normal.to_track_quat("Y", "Z")
    spin_q = Quaternion(normal, spin)
    base = len(verts)
    for v in template.data.vertices:
        p = spin_q @ (q @ (v.co * scale))
        verts.append(tuple(Vector(center) + p))
    uv_layer = template.data.uv_layers.active
    for poly in template.data.polygons:
        faces.append(tuple(base + idx for idx in poly.vertices))
        for loop_index in poly.loop_indices:
            if uv_layer is not None:
                uv = uv_layer.data[loop_index].uv
                uvs.append((float(uv.x), float(uv.y)))
            else:
                uvs.append((0.5, 0.5))


def finish_uv_mesh(name, verts, faces, uvs, material):
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    mesh.materials.append(material)
    uv_layer = mesh.uv_layers.new(name="UVMap")
    for i, uv in enumerate(uvs):
        if i < len(uv_layer.data):
            uv_layer.data[i].uv = uv
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for poly in mesh.polygons:
        poly.use_smooth = True
    return obj


def build_terrain():
    grass = mat_principled("Landscape_GrassSoil_PBR", (0.16, 0.20, 0.055), 0.92)
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=26, y_subdivisions=34, size=2.0, location=(0, 20, 0))
    terrain = bpy.context.object
    terrain.name = "LandscapeTerrain"
    terrain.scale = Vector((24.0, 36.0, 1.0))
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for v in terrain.data.vertices:
        x, y = v.co.x, v.co.y
        # Broad vineyard slope + slight natural undulation.
        v.co.z = (
            0.035 * y
            + 0.30 * math.sin(x * 0.12 + y * 0.035)
            + 0.12 * math.sin(y * 0.18)
            + 0.07 * math.sin(x * 0.31 + y * 0.15)
        )
    terrain.data.materials.append(grass)
    return terrain


def build_hills():
    hill_mat = mat_principled("DistantHill_PBR", (0.17, 0.19, 0.075), 0.96)
    hills = []
    for h in range(3):
        y = 50 + h * 7
        verts = []
        faces = []
        width = 62
        segs = 30
        for i in range(segs + 1):
            x = -width * 0.5 + width * i / segs
            top = 7.2 + h * 1.1 + 1.4 * math.sin(i * 0.42 + h) + 0.7 * math.sin(i * 0.17 + h * 0.6)
            verts.append((x, y, -2.0))
            verts.append((x, y, top))
        for i in range(segs):
            a = i * 2
            faces.append((a, a + 1, a + 3, a + 2))
        mesh = bpy.data.meshes.new(f"HillMesh_{h}")
        mesh.from_pydata(verts, [], faces)
        mesh.materials.append(hill_mat)
        obj = bpy.data.objects.new(f"DistantHill_{h}", mesh)
        bpy.context.collection.objects.link(obj)
        hills.append(obj)
    return join(hills, "DistantHills")


def build_vineyard_rows(leaf_template):
    vine_mat = leaf_template.data.materials[0] if leaf_template.data.materials else mat_principled("VineyardFoliage_PBR", (0.055, 0.15, 0.018), 0.80)
    post_mat = mat_principled("VineyardPost_PBR", (0.095, 0.060, 0.030), 0.88)
    soil_mat = mat_principled("RowSoil_PBR", (0.19, 0.105, 0.035), 0.95)
    vine_wood_mat = mat_principled("VineWoodRows_PBR", (0.095, 0.045, 0.014), 0.88)
    grape_mat = mat_principled("BackgroundGrapes_PBR", (0.045, 0.010, 0.075), 0.50)

    foliage_verts = []
    foliage_faces = []
    foliage_uvs = []
    posts = []
    vine_wood = []
    grape_berries = []
    row_soil = []

    row_xs = [-18.0, -15.6, -13.2, -10.8, -8.4, -6.0, -3.6, -1.2, 1.2, 3.6, 6.0, 8.4, 10.8, 13.2, 15.6, 18.0]
    for ri, x in enumerate(row_xs):
        # Slight fan to reinforce perspective and match the reference.
        far_shift = x * 0.18
        angle = math.atan2(far_shift - x, 48.0)
        mid_x = (x + far_shift) * 0.5
        y_mid = 27.0

        strip = add_box(
            f"RowSoil_{ri:02d}",
            (mid_x, y_mid, 0.25 + 0.035 * y_mid),
            (0.31, 22.0, 0.08),
            soil_mat,
        )
        strip.rotation_euler.z = -angle
        row_soil.append(strip)

        y_positions = [5.0 + i * 1.58 for i in range(29)]
        for j, y in enumerate(y_positions):
            t = y / 48.0
            px = x * (1.0 - t) + far_shift * t + random.uniform(-0.08, 0.08)
            pz = 0.30 + 0.035 * y + 0.30 * math.sin(px * 0.12 + y * 0.035)
            # Trellis post every other vine.
            if j % 4 == 0:
                post = add_cylinder(
                    f"Post_{ri}_{j}",
                    (px, y, pz + 0.46),
                    0.035 if y < 25 else 0.026,
                    0.95 if y < 25 else 0.72,
                    post_mat,
                    vertices=6,
                )
                posts.append(post)

            # Woody trunk/canes on alternating plants: enough visible structure
            # without spending geometry on every far-away plant.
            if j % 2 == 0:
                trunk = add_cylinder(
                    f"VineTrunk_{ri}_{j}",
                    (px, y, pz + 0.31),
                    0.024 if y < 29 else 0.017,
                    0.62 if y < 29 else 0.48,
                    vine_wood_mat,
                    vertices=6,
                )
                vine_wood.append(trunk)
                arm_width = 0.33 if y < 29 else 0.23
                for side in (-1, 1):
                    arm = add_cylinder(
                        f"VineArm_{ri}_{j}_{side}",
                        (px + side * arm_width * 0.48, y, pz + 0.60),
                        0.013 if y < 29 else 0.010,
                        arm_width,
                        vine_wood_mat,
                        vertices=6,
                        rotation=(0, math.radians(90), 0),
                    )
                    vine_wood.append(arm)

            # Copies of the authored grape leaf: real silhouette, real baked PBR
            # maps, aggressively simplified and joined into one mesh.
            leaf_count = 5 if y < 29 else 3
            for k in range(leaf_count):
                c = Vector((
                    px + random.uniform(-0.38, 0.38),
                    y + random.uniform(-0.13, 0.13),
                    pz + random.uniform(0.52, 0.98),
                ))
                normal = Vector((
                    random.uniform(-0.45, 0.45),
                    random.uniform(-1.0, -0.38),
                    random.uniform(0.12, 0.62),
                )).normalized()
                spin = random.uniform(0, math.tau)
                leaf_scale = (4.35 if y < 29 else 3.45) * random.uniform(0.82, 1.18)
                append_template_geometry(
                    leaf_template,
                    c,
                    normal,
                    leaf_scale,
                    spin,
                    foliage_verts,
                    foliage_faces,
                    foliage_uvs,
                )

            # A few tiny dark bunches only on the near vines; these read as fruit
            # without turning the distant rows into expensive hero assets.
            if y <= 14 and ri % 2 == 0 and j % 2 == 0:
                bunch_center = Vector((px + random.uniform(-0.10, 0.10), y - 0.03, pz + 0.48))
                for gi in range(8):
                    a = (gi % 4) * (math.tau / 4.0) + random.uniform(-0.2, 0.2)
                    layer = gi // 4
                    rr = 0.052 if layer == 0 else 0.034
                    bpy.ops.mesh.primitive_ico_sphere_add(
                        subdivisions=1,
                        radius=0.028,
                        location=bunch_center + Vector((math.cos(a) * rr, math.sin(a) * rr * 0.55, -layer * 0.048)),
                    )
                    berry = bpy.context.object
                    berry.data.materials.append(grape_mat)
                    for poly in berry.data.polygons:
                        poly.use_smooth = True
                    grape_berries.append(berry)

    foliage = finish_uv_mesh("VineyardFoliage", foliage_verts, foliage_faces, foliage_uvs, vine_mat)
    bpy.data.objects.remove(leaf_template, do_unlink=True)

    return (
        join(row_soil, "VineyardRowSoil"),
        join(posts, "VineyardPosts"),
        foliage,
        join(vine_wood, "VineyardWood"),
        join(grape_berries, "VineyardGrapes"),
    )


def build_fence():
    post_mat = mat_principled("FenceWood_PBR", (0.10, 0.055, 0.024), 0.88)
    fence = []
    fence_y = 4.25
    for x in range(-22, 23, 2):
        fence.append(add_cylinder("FencePost", (x, fence_y, 0.78), 0.045, 1.22, post_mat, vertices=6))
    # Two horizontal rails along the field edge.
    fence.append(add_box("FenceRailLow", (0, fence_y, 0.57), (22.0, 0.035, 0.035), post_mat))
    fence.append(add_box("FenceRailHigh", (0, fence_y, 0.91), (22.0, 0.032, 0.032), post_mat))
    return join(fence, "VineyardFence")


def build_vineyard_canopy_mass():
    canopy_mat = mat_principled("VineyardCanopyMass_PBR", (0.045, 0.135, 0.018), 0.86)
    verts = []
    faces = []
    row_xs = [-18.0, -15.6, -13.2, -10.8, -8.4, -6.0, -3.6, -1.2, 1.2, 3.6, 6.0, 8.4, 10.8, 13.2, 15.6, 18.0]
    segs = 24
    for ri, x in enumerate(row_xs):
        far_shift = x * 0.18
        rings = []
        for si in range(segs + 1):
            y = 5.0 + (44.0 * si / segs)
            t = y / 48.0
            px = x * (1.0 - t) + far_shift * t
            pz = 0.30 + 0.035 * y + 0.30 * math.sin(px * 0.12 + y * 0.035)
            half_width = 0.28 * (0.90 + 0.12 * math.sin(si * 0.83 + ri))
            top = pz + 0.74 + 0.08 * math.sin(si * 0.71 + ri * 0.4)
            ring = []
            for vx, vz in (
                (px - half_width, top + 0.02 * math.sin(si * 1.3 + ri)),
                (px + half_width, top - 0.02 * math.cos(si * 1.1 + ri)),
            ):
                ring.append(len(verts))
                verts.append((vx, y, vz))
            rings.append(ring)
        for si in range(segs):
            a = rings[si]
            b = rings[si + 1]
            faces.append((a[0], a[1], b[1], b[0]))

    mesh = bpy.data.meshes.new("VineyardCanopyMassMesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    mesh.materials.append(canopy_mat)
    obj = bpy.data.objects.new("VineyardCanopyMass", mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def build_road():
    road_mat = mat_principled("GravelRoad_PBR", (0.16, 0.135, 0.105), 0.97)
    road = add_box("GravelRoad", (0, 2.30, 0.17), (24.0, 1.45, 0.055), road_mat)
    return road


def create_barrel_body(name, location, yaw_degrees, material):
    radial = 28
    xs = [-0.875, -0.73, -0.52, -0.28, 0.0, 0.28, 0.52, 0.73, 0.875]
    radii = [0.665, 0.725, 0.775, 0.812, 0.825, 0.812, 0.775, 0.725, 0.665]
    verts = []
    faces = []
    uv_per_loop = []
    for i, x in enumerate(xs):
        r = radii[i]
        for j in range(radial):
            a = (j / radial) * math.tau
            verts.append((x, math.cos(a) * r, math.sin(a) * r))
    for i in range(len(xs) - 1):
        for j in range(radial):
            nj = (j + 1) % radial
            a = i * radial + j
            b = i * radial + nj
            c = (i + 1) * radial + nj
            d = (i + 1) * radial + j
            faces.append((a, b, c, d))
            u0 = j / radial
            u1 = (j + 1) / radial
            v0 = i / (len(xs) - 1)
            v1 = (i + 1) / (len(xs) - 1)
            uv_per_loop.extend([(u0, v0), (u1, v0), (u1, v1), (u0, v1)])

    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    mesh.materials.append(material)
    uv_layer = mesh.uv_layers.new(name="UVMap")
    for i, uv in enumerate(uv_per_loop):
        if i < len(uv_layer.data):
            uv_layer.data[i].uv = uv
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler.z = math.radians(yaw_degrees)
    for poly in mesh.polygons:
        poly.use_smooth = True
    return obj


def build_barrels_and_racks():
    wood = mat_principled("BarrelWood_PBR", (0.22, 0.105, 0.040), 0.78)
    wood_light = mat_principled("BarrelWoodHighlight_PBR", (0.33, 0.17, 0.065), 0.72)
    metal = mat_principled("BarrelBandsMetal_PBR", (0.18, 0.20, 0.20), 0.36, metallic=0.78)
    rack_mat = mat_principled("RackMetal_PBR", (0.055, 0.060, 0.058), 0.48, metallic=0.65)

    barrel_wood = []
    bands = []
    racks = []

    positions = [
        (-7.6, -1.6, 0.95, -7),
        (-4.9, -0.7, 1.00, -4),
        (-2.2, 0.2, 1.06, 2),
        (0.6, 0.9, 1.11, 5),
    ]
    for bi, (x, y, z, yaw) in enumerate(positions):
        main = create_barrel_body(
            f"BarrelWood_{bi}",
            (x, y, z),
            yaw,
            wood if bi % 2 == 0 else wood_light,
        )
        barrel_wood.append(main)

        # Five hoops follow the bulging barrel profile.
        for band_i, xo in enumerate((-0.72, -0.38, 0.0, 0.38, 0.72)):
            local = Vector((xo, 0, 0))
            rot = math.radians(yaw)
            local_rot = Vector((
                local.x * math.cos(rot) - local.y * math.sin(rot),
                local.x * math.sin(rot) + local.y * math.cos(rot),
                0,
            ))
            t = (xo + 0.875) / 1.75
            band_radius = 0.665 + (0.825 - 0.665) * (math.sin(math.pi * t) ** 0.72)
            band = add_cylinder(
                f"BarrelBand_{bi}_{band_i}",
                Vector((x, y, z)) + local_rot,
                band_radius + 0.018,
                0.055,
                metal,
                vertices=28,
                rotation=(0, math.radians(90), math.radians(yaw)),
            )
            bands.append(band)

        # Inset wooden end caps.
        for side in (-1, 1):
            local = Vector((side * 0.884, 0, 0))
            rot = math.radians(yaw)
            local_rot = Vector((
                local.x * math.cos(rot) - local.y * math.sin(rot),
                local.x * math.sin(rot) + local.y * math.cos(rot),
                0,
            ))
            cap = add_cylinder(
                f"BarrelCap_{bi}_{side}",
                Vector((x, y, z)) + local_rot,
                0.642,
                0.036,
                wood if bi % 2 == 0 else wood_light,
                vertices=28,
                rotation=(0, math.radians(90), math.radians(yaw)),
            )
            barrel_wood.append(cap)

        # Simple black metal cradle.
        rack_y = y
        for sy in (-0.50, 0.50):
            racks.append(add_box(
                f"RackLeg_{bi}",
                (x - 0.45, rack_y + sy, 0.32),
                (0.055, 0.055, 0.42),
                rack_mat,
            ))
            racks.append(add_box(
                f"RackLeg_{bi}",
                (x + 0.45, rack_y + sy, 0.32),
                (0.055, 0.055, 0.42),
                rack_mat,
            ))
        racks.append(add_box(f"RackBase_{bi}", (x, rack_y - 0.50, 0.12), (0.70, 0.055, 0.055), rack_mat))
        racks.append(add_box(f"RackBase_{bi}", (x, rack_y + 0.50, 0.12), (0.70, 0.055, 0.055), rack_mat))

    return join(barrel_wood, "BarrelWood"), join(bands, "BarrelBands"), join(racks, "BarrelRacks")


def build_framing_tree():
    bark = mat_principled("LandscapeTreeBark_PBR", (0.075, 0.033, 0.012), 0.90)
    leaf_dark = mat_principled("LandscapeTreeLeaf_PBR", (0.030, 0.105, 0.014), 0.78)
    leaf_warm = mat_principled("LandscapeTreeLeafWarm_PBR", (0.065, 0.14, 0.018), 0.82)

    branches = []
    trunk = [
        Vector((15.0, 0.0, 0.0)),
        Vector((14.6, 0.5, 2.8)),
        Vector((14.2, 1.1, 5.5)),
        Vector((13.4, 2.0, 8.0)),
    ]
    branches.append(curve_branch("FrameTreeTrunk", trunk, [2.3, 1.8, 1.25, 0.72], bark, bevel=0.20, resolution=3, bevel_resolution=3))

    branch_specs = [
        (trunk[-1], Vector((7.0, 5.2, 11.2))),
        (trunk[-1], Vector((2.5, 5.8, 12.0))),
        (Vector((14.0, 1.7, 6.8)), Vector((10.5, 4.2, 10.8))),
        (Vector((13.8, 1.9, 7.2)), Vector((5.5, 3.4, 10.2))),
        (Vector((13.2, 2.0, 8.0)), Vector((-1.0, 2.8, 10.8))),
    ]
    tips = []
    for i, (start, end) in enumerate(branch_specs):
        mid = start.lerp(end, 0.52) + Vector((0, random.uniform(-0.7, 0.7), random.uniform(0.2, 0.8)))
        branches.append(curve_branch(f"FrameTreeBranch_{i}", [start, mid, end], [0.75, 0.45, 0.16], bark, bevel=0.15, resolution=2, bevel_resolution=2))
        tips.append(end)

    for b in branches:
        activate(b)
        bpy.ops.object.convert(target="MESH")
    wood = join(branches, "LandscapeTreeWood")

    foliage_verts = []
    foliage_faces = []
    foliage_mat_ids = []
    centers = [
        (13.0, 2.4, 9.8), (10.7, 3.0, 10.5), (8.2, 3.5, 10.7),
        (5.5, 4.0, 11.1), (2.7, 4.4, 11.2), (-0.2, 3.7, 10.9),
        (15.0, 3.0, 10.1), (12.0, 4.6, 11.4), (8.7, 5.0, 11.8),
        (4.8, 5.4, 12.0), (1.4, 5.0, 11.7),
    ]
    for ci, center in enumerate(centers):
        for k in range(78):
            c = Vector((
                center[0] + random.gauss(0.0, 1.35),
                center[1] + random.gauss(0.0, 0.85),
                center[2] + random.gauss(0.0, 0.58),
            ))
            # Individual broad leaves with randomized orientation.
            angle = random.uniform(0, math.tau)
            normal = Vector((
                math.cos(angle) * random.uniform(0.10, 0.52),
                random.uniform(-1.0, -0.28),
                random.uniform(0.14, 0.78),
            )).normalized()
            ref = Vector((0, 0, 1))
            if abs(normal.dot(ref)) > 0.88:
                ref = Vector((1, 0, 0))
            tangent = normal.cross(ref).normalized()
            bitangent = normal.cross(tangent).normalized()
            spin = random.uniform(0, math.tau)
            t2 = tangent * math.cos(spin) + bitangent * math.sin(spin)
            b2 = normal.cross(t2).normalized()

            length = random.uniform(0.30, 0.52)
            width = length * random.uniform(0.30, 0.45)
            fold = normal * random.uniform(0.008, 0.025)
            local = [
                c - t2 * length * 0.52,
                c - t2 * length * 0.12 + b2 * width * 0.50,
                c + t2 * length * 0.27 + b2 * width * 0.38 + fold,
                c + t2 * length * 0.52,
                c + t2 * length * 0.27 - b2 * width * 0.38 + fold,
                c - t2 * length * 0.12 - b2 * width * 0.50,
                c + fold * 1.5,
            ]
            base = len(foliage_verts)
            foliage_verts.extend([tuple(p) for p in local])
            fs = [(6,0,1),(6,1,2),(6,2,3),(6,3,4),(6,4,5),(6,5,0)]
            foliage_faces.extend([(base+a, base+b, base+cidx) for a,b,cidx in fs])
            mat_id = 1 if (ci + k) % 5 == 0 else 0
            foliage_mat_ids.extend([mat_id] * len(fs))

    mesh = bpy.data.meshes.new("LandscapeTreeLeafCardsMesh")
    mesh.from_pydata(foliage_verts, [], foliage_faces)
    mesh.update()
    mesh.materials.append(leaf_dark)
    mesh.materials.append(leaf_warm)
    foliage = bpy.data.objects.new("LandscapeTreeFoliage", mesh)
    bpy.context.collection.objects.link(foliage)
    for poly, mat_id in zip(mesh.polygons, foliage_mat_ids):
        poly.material_index = mat_id
        poly.use_smooth = True
    return wood, foliage


def build_hay():
    hay_mat = mat_principled("DryHay_PBR", (0.37, 0.245, 0.055), 0.96)
    pieces = []
    for i in range(70):
        x = random.uniform(3.0, 12.0)
        y = random.uniform(-2.5, 3.5)
        z = random.uniform(0.06, 0.14)
        length = random.uniform(0.45, 1.35)
        angle = random.uniform(-0.55, 0.55)
        piece = add_box(
            f"Hay_{i}",
            (x, y, z),
            (length * 0.5, 0.018, 0.015),
            hay_mat,
        )
        piece.rotation_euler.z = angle
        pieces.append(piece)
    return join(pieces, "DryHay")


def build_sunset_sun():
    sun_mat = mat_emissive("SunsetDisc_Emissive", (1.0, 0.48, 0.13), 4.5)
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=20,
        ring_count=10,
        radius=1.65,
        location=(-7.5, 60.0, 10.8),
    )
    sun = bpy.context.object
    sun.name = "SunsetDisc"
    sun.data.materials.append(sun_mat)
    return sun


def setup_preview(objects):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 960
    scene.render.resolution_y = 540
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(OUT_PREVIEW)

    # warm sunset world
    world = bpy.data.worlds.new("SunsetWorld")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.30, 0.12, 0.045, 1.0)
    bg.inputs["Strength"].default_value = 0.42

    bpy.ops.object.light_add(type="SUN", location=(-10, -8, 14))
    sun = bpy.context.object
    sun.name = "PreviewSun"
    sun.rotation_euler = (math.radians(58), 0, math.radians(-32))
    sun.data.energy = 2.3
    sun.data.color = (1.0, 0.62, 0.32)
    sun.data.angle = math.radians(3.5)

    bpy.ops.object.light_add(type="AREA", location=(-7, -5, 8))
    fill = bpy.context.object
    fill.name = "PreviewFill"
    fill.data.energy = 650
    fill.data.shape = "DISK"
    fill.data.size = 8
    direction = Vector((0, 12, 4)) - fill.location
    fill.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    bpy.ops.object.camera_add(location=(0.0, -17.5, 6.0))
    cam = bpy.context.object
    cam.name = "PreviewCamera"
    cam.data.lens = 42
    target = Vector((0, 19, 3.2))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    bpy.ops.wm.save_as_mainfile(filepath=str(OUT_BLEND), check_existing=False)
    bpy.ops.render.render(write_still=True)


def export(objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(
        filepath=str(OUT_GLB),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_materials="EXPORT",
        export_yup=True,
    )
    log(f"exported {OUT_GLB}")


clear_scene()
leaf_template = append_grape_leaf_template()
terrain = build_terrain()
hills = build_hills()
row_soil, posts, vines, vine_wood, vine_grapes = build_vineyard_rows(leaf_template)
vine_canopy = build_vineyard_canopy_mass()
fence = build_fence()
road = build_road()
barrel_wood, barrel_bands, barrel_racks = build_barrels_and_racks()
tree_wood, tree_foliage = build_framing_tree()
hay = build_hay()
sun_disc = build_sunset_sun()

game_objects = [
    terrain, hills, row_soil, posts, vines, vine_canopy, vine_wood, vine_grapes, fence, road,
    barrel_wood, barrel_bands, barrel_racks,
    tree_wood, tree_foliage, hay, sun_disc,
]
export(game_objects)
setup_preview(game_objects)

polys = sum(len(o.data.polygons) for o in game_objects if o and o.type == "MESH")
log(f"TOTAL polygons={polys} meshes={len(game_objects)}")
log(f"saved {OUT_BLEND}")
log(f"preview {OUT_PREVIEW}")
