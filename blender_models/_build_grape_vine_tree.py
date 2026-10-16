import bpy
import math
import random
from mathutils import Vector
from pathlib import Path


ROOT = Path(r"C:\Users\mario\Nextcloud\wine-vr")
SOURCE_GRAPES = ROOT / "blender_models" / "grapes_game_vr.blend"
OUT_DIR = ROOT / "assets" / "models" / "grape_vine_tree"
OUT_BLEND = ROOT / "blender_models" / "grape_vine_tree.blend"
OUT_GLB = OUT_DIR / "grape_vine_tree.glb"

OUT_DIR.mkdir(parents=True, exist_ok=True)
random.seed(20261001)


def log(msg):
    print(f"[GRAPE_VINE_TREE] {msg}", flush=True)


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def activate(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.hide_set(False)
    obj.hide_viewport = False
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def simple_material(name, color, roughness, specular=0.32):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    p = mat.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*color, 1.0)
    p.inputs["Roughness"].default_value = roughness
    if p.inputs.get("Specular IOR Level"):
        p.inputs["Specular IOR Level"].default_value = specular
    return mat


def curve_segment(name, points, radii, material, bevel=0.055, resolution=2, bevel_resolution=2):
    curve = bpy.data.curves.new(name + "_Curve", "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = resolution
    curve.bevel_depth = bevel
    curve.bevel_resolution = bevel_resolution
    curve.resolution_u = resolution
    curve.twist_smooth = 4
    curve.materials.append(material)
    spline = curve.splines.new("NURBS")
    spline.points.add(len(points) - 1)
    for i, (p, r) in enumerate(zip(points, radii)):
        spline.points[i].co = (*p, 1.0)
        spline.points[i].radius = r
    spline.order_u = min(4, len(points))
    spline.use_endpoint_u = True
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    return obj


def join_objects(objects, name):
    if not objects:
        return None
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.hide_set(False)
        obj.hide_viewport = False
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    result = bpy.context.active_object
    result.name = name
    return result


def append_leaf_template():
    with bpy.data.libraries.load(str(SOURCE_GRAPES), link=False) as (src, dst):
        if "GrapeLeaf_Blade" not in src.objects:
            raise RuntimeError("GrapeLeaf_Blade missing from grapes_game_vr.blend")
        dst.objects = ["GrapeLeaf_Blade"]
    leaf = dst.objects[0]
    bpy.context.collection.objects.link(leaf)
    leaf.name = "_LeafTemplate"
    activate(leaf)
    # The showcase leaf is intentionally high quality. Collapse it aggressively
    # for the many-leaf canopy while preserving its UVs and baked PBR maps.
    dec = leaf.modifiers.new("Canopy leaf optimization", "DECIMATE")
    dec.ratio = 0.032
    dec.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=dec.name)
    for poly in leaf.data.polygons:
        poly.use_smooth = True
    log(f"leaf template polygons={len(leaf.data.polygons)}")
    return leaf


def create_wood():
    bark = simple_material("VineBark_Game_PBR", (0.105, 0.050, 0.018), 0.86, 0.20)
    twig = simple_material("VineTwig_Game_PBR", (0.16, 0.075, 0.025), 0.80, 0.22)
    pieces = []

    # Gnarled old vine trunk; broad at the base, irregular and forked.
    trunk_points = [
        (0.00, 0.00, 0.00),
        (-0.045, 0.020, 0.28),
        (0.035, -0.030, 0.58),
        (-0.020, 0.015, 0.87),
        (0.060, -0.015, 1.13),
        (0.020, 0.020, 1.38),
    ]
    pieces.append(curve_segment(
        "VineWood_Trunk",
        trunk_points,
        [2.7, 2.45, 2.0, 1.62, 1.28, 0.98],
        bark,
        bevel=0.072,
        resolution=4,
        bevel_resolution=4,
    ))

    # Main cordons/arms, shaped like a mature trained vine but allowed to grow
    # into a tree-like canopy for the exhibit.
    arms = [
        (Vector((0.02, 0.01, 1.30)), Vector((-1.20, 0.05, 1.42)), -0.08),
        (Vector((0.04, 0.00, 1.33)), Vector((1.20, 0.08, 1.46)), 0.10),
        (Vector((0.00, 0.02, 1.12)), Vector((-0.72, -0.52, 1.62)), 0.06),
        (Vector((0.02, 0.00, 1.18)), Vector((0.65, 0.55, 1.73)), -0.05),
    ]
    arm_endpoints = []
    for idx, (start, end, bend) in enumerate(arms):
        delta = end - start
        pts = [
            start,
            start + delta * 0.30 + Vector((0.0, bend, 0.06)),
            start + delta * 0.65 + Vector((0.0, -bend * 0.5, 0.02)),
            end,
        ]
        pieces.append(curve_segment(
            f"VineWood_Arm_{idx:02d}",
            pts,
            [1.10, 0.88, 0.64, 0.42],
            bark,
            bevel=0.050,
            resolution=3,
            bevel_resolution=3,
        ))
        arm_endpoints.append((start, end))

    # Central leader rising through the canopy toward the existing interactive
    # hero bunch in WineryInterior. This visually ties the legacy close-up
    # grapes into the same plant without changing their interaction logic.
    leader_points = [
        Vector((0.025, 0.000, 1.27)),
        Vector((-0.035, 0.018, 1.62)),
        Vector((-0.075, -0.010, 1.98)),
        Vector((-0.055, 0.015, 2.36)),
        Vector((-0.010, 0.000, 2.72)),
    ]
    pieces.append(curve_segment(
        "VineWood_HeroLeader",
        leader_points,
        [0.72, 0.52, 0.34, 0.20, 0.09],
        twig,
        bevel=0.042,
        resolution=3,
        bevel_resolution=3,
    ))

    # Secondary shoots from the cordons. Their tips drive the leaf/bunch layout.
    shoot_tips = []
    shoot_bases = []
    for side in (-1, 1):
        for i in range(5):
            x = side * (0.23 + i * 0.205)
            y = (0.11 if i % 2 == 0 else -0.14) + side * 0.02
            z = 1.36 + 0.045 * i
            start = Vector((x, y, z))
            outward = Vector((side * random.uniform(0.34, 0.52), random.uniform(-0.24, 0.25), random.uniform(0.54, 0.84)))
            end = start + outward
            mid1 = start.lerp(end, 0.36) + Vector((0, random.uniform(-0.08, 0.08), 0.06))
            mid2 = start.lerp(end, 0.72) + Vector((0, random.uniform(-0.06, 0.06), 0.03))
            pieces.append(curve_segment(
                f"VineWood_Shoot_{side}_{i}",
                [start, mid1, mid2, end],
                [0.46, 0.31, 0.20, 0.09],
                twig,
                bevel=0.025,
                resolution=2,
                bevel_resolution=2,
            ))
            shoot_tips.append(end)
            shoot_bases.append(start)

    # A few front/back shoots for depth.
    for i in range(4):
        ysign = -1 if i < 2 else 1
        x = -0.35 if i % 2 == 0 else 0.34
        start = Vector((x, ysign * 0.18, 1.35))
        end = start + Vector((random.uniform(-0.22, 0.22), ysign * random.uniform(0.55, 0.72), random.uniform(0.50, 0.72)))
        pieces.append(curve_segment(
            f"VineWood_DepthShoot_{i}",
            [start, start.lerp(end, .35), start.lerp(end, .72) + Vector((0,0,0.05)), end],
            [0.42, 0.28, 0.17, 0.08],
            twig,
            bevel=0.024,
            resolution=2,
            bevel_resolution=2,
        ))
        shoot_tips.append(end)
        shoot_bases.append(start)

    # Convert before joining.
    converted = []
    for obj in pieces:
        activate(obj)
        bpy.ops.object.convert(target="MESH")
        converted.append(bpy.context.active_object)
    wood = join_objects(converted, "VineWood")
    for p in wood.data.polygons:
        p.use_smooth = True
    log(f"wood polygons={len(wood.data.polygons)}")
    return wood, shoot_bases, shoot_tips


def orient_leaf(obj, direction, roll):
    direction = Vector(direction).normalized()
    obj.rotation_mode = "QUATERNION"
    # Source leaf blade lies on X/Z (Y is its thin normal). Aim that normal
    # out/up so leaves present their broad face instead of appearing edge-on.
    q = direction.to_track_quat("Y", "Z")
    obj.rotation_quaternion = q
    obj.rotation_mode = "XYZ"
    obj.rotation_euler.rotate_axis("Y", roll)


def create_leaves(template, shoot_bases, shoot_tips):
    leaves = []
    # Leaves along every shoot; alternate sides, vary scale and tilt.
    for sidx, (start, end) in enumerate(zip(shoot_bases, shoot_tips)):
        d = (end - start).normalized()
        side = d.cross(Vector((0, 0, 1)))
        if side.length < 0.1:
            side = Vector((1, 0, 0))
        side.normalize()
        for j, t in enumerate((0.17, 0.29, 0.41, 0.53, 0.65, 0.77, 0.89, 0.98)):
            p = start.lerp(end, t)
            flip = -1 if (j + sidx) % 2 else 1
            p += side * flip * random.uniform(0.05, 0.11)
            p += Vector((0, 0, random.uniform(-0.025, 0.07)))
            leaf = template.copy()
            leaf.data = template.data.copy()
            bpy.context.collection.objects.link(leaf)
            leaf.name = f"Leaf_{sidx:02d}_{j:02d}"
            leaf.location = p
            # The source leaf is a close-up hero leaf (~4.5 cm wide). Mature
            # grapevine leaves are commonly ~12-18 cm across, so enlarge the
            # optimized canopy copy rather than adding more geometry.
            scale = random.uniform(3.0, 4.15)
            leaf.scale = Vector((scale, scale, scale))
            face_dir = (side * flip * random.uniform(0.5, 0.95) + Vector((0,0,random.uniform(0.30,0.65))) + d * 0.18).normalized()
            orient_leaf(leaf, face_dir, random.uniform(-0.65, 0.65))
            leaves.append(leaf)

    bpy.data.objects.remove(template, do_unlink=True)

    # Joining bakes placement transforms into one draw-friendly mesh.
    for leaf in leaves:
        activate(leaf)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    joined = join_objects(leaves, "VineLeaves")
    log(f"leaf canopy polygons={len(joined.data.polygons)}")
    return joined


def make_berry_template():
    # Match the ~2.1 cm diameter of the detailed showcase berries while using
    # only 80 faces per berry for the canopy bunches.
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.0125, location=(0,0,0))
    berry = bpy.context.object
    berry.name = "_BerryTemplate"
    berry.scale = Vector((1.0, 1.0, 1.06))
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for p in berry.data.polygons:
        p.use_smooth = True
    berry.data.materials.append(simple_material("GrapeCanopy_Game_PBR", (0.055, 0.018, 0.095), 0.52, 0.34))
    return berry


def create_grape_clusters(shoot_bases, shoot_tips):
    berry_template = make_berry_template()
    berries = []
    stem_mat = simple_material("GrapeStem_Game_PBR", (0.16, 0.22, 0.055), 0.78, 0.20)
    stems = []

    # One bunch per shoot gives a lush but still believable exhibition vine.
    anchors = []
    for start, end in zip(shoot_bases, shoot_tips):
        d = (end - start)
        t = random.uniform(0.45, 0.76)
        anchors.append(start + d * t + Vector((0, 0, -random.uniform(0.13, 0.22))))
    anchors = anchors[:14]

    for ci, anchor in enumerate(anchors):
        # Short peduncle.
        top = anchor + Vector((0,0,0.17))
        stem = curve_segment(
            f"GrapeStem_{ci:02d}",
            [top, top.lerp(anchor, .55) + Vector((0.01 * (-1 if ci%2 else 1), 0, 0)), anchor],
            [0.22, 0.17, 0.11],
            stem_mat,
            bevel=0.017,
            bevel_resolution=1,
        )
        activate(stem)
        bpy.ops.object.convert(target="MESH")
        stems.append(bpy.context.active_object)

        # Compact conical bunch: berries lightly overlap, as real clusters do.
        berry_positions = []
        layer_specs = [
            (0.000, 6, 0.040),
            (-0.034, 6, 0.036),
            (-0.068, 5, 0.030),
            (-0.100, 4, 0.023),
            (-0.130, 2, 0.013),
        ]
        phase = random.uniform(0, math.tau)
        for zoff, count, radius in layer_specs:
            for j in range(count):
                a = phase + (j / count) * math.tau + random.uniform(-0.18,0.18)
                r = radius * random.uniform(0.72, 1.0)
                berry_positions.append(Vector((math.cos(a)*r, math.sin(a)*r, zoff)) + anchor)
        berry_positions.append(anchor + Vector((0,0,-0.155)))

        for bi, p in enumerate(berry_positions):
            b = berry_template.copy()
            b.data = berry_template.data
            bpy.context.collection.objects.link(b)
            b.name = f"Berry_{ci:02d}_{bi:02d}"
            b.location = p + Vector((
                random.uniform(-0.010,0.010),
                random.uniform(-0.010,0.010),
                random.uniform(-0.010,0.010),
            ))
            sc = random.uniform(0.86, 1.08)
            b.scale = Vector((sc, sc, sc * random.uniform(0.94,1.06)))
            berries.append(b)

    bpy.data.objects.remove(berry_template, do_unlink=True)
    berry_mesh = join_objects(berries, "GrapeBerries")
    for p in berry_mesh.data.polygons:
        p.use_smooth = True
    stem_mesh = join_objects(stems, "GrapeStems")
    log(f"berries polygons={len(berry_mesh.data.polygons)} stems={len(stem_mesh.data.polygons)} clusters={len(anchors)}")
    return berry_mesh, stem_mesh


def export_asset(objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.hide_set(False)
        obj.hide_viewport = False
        obj.hide_render = False
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]

    # Save editable source with procedural history already collapsed to compact,
    # game-ready meshes.
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT_BLEND), check_existing=False)

    bpy.ops.export_scene.gltf(
        filepath=str(OUT_GLB),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_materials="EXPORT",
        export_yup=True,
    )
    log(f"saved {OUT_BLEND}")
    log(f"exported {OUT_GLB}")


clear_scene()
leaf_template = append_leaf_template()
wood, shoot_bases, shoot_tips = create_wood()
leaves = create_leaves(leaf_template, shoot_bases, shoot_tips)
berries, stems = create_grape_clusters(shoot_bases, shoot_tips)
export_asset([wood, leaves, berries, stems])

total_polys = sum(len(o.data.polygons) for o in (wood, leaves, berries, stems))
log(f"TOTAL polygons={total_polys} objects=4")
