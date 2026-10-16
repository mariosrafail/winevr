import bpy
import os
import sys
from pathlib import Path


PROJECT_ROOT = Path(bpy.path.abspath("//")).parent
OUT_DIR = PROJECT_ROOT / "assets" / "models" / "grapes_game"
TEX_DIR = OUT_DIR / "textures"
OUT_BLEND = PROJECT_ROOT / "blender_models" / "grapes_game_vr.blend"
OUT_GLB = OUT_DIR / "grapes_game.glb"

OUT_DIR.mkdir(parents=True, exist_ok=True)
TEX_DIR.mkdir(parents=True, exist_ok=True)

TARGETS = {
    "Grape_01 | individual berry": "grape01",
    "Grape_02 | individual berry": "grape02",
    "Grape_03 | individual berry": "grape03",
    "GrapeLeaf_Blade": "leaf",
}

KEEP_NAMES = set(TARGETS.keys()) | {
    "Stem | short natural rachis",
    "Pedicel 01",
    "Stem collar 01",
    "Blossom scar 01",
    "Pedicel 02",
    "Stem collar 02",
    "Blossom scar 02",
    "Pedicel 03",
    "Stem collar 03",
    "Blossom scar 03",
    "Stem | visible cut end",
    "Leaf | short petiole",
}


def log(message: str):
    print(f"[GRAPES_GAME] {message}", flush=True)


def deselect_all():
    for item in bpy.context.view_layer.objects:
        try:
            item.select_set(False)
        except Exception:
            pass


def activate(obj):
    current = bpy.context.view_layer.objects.active
    if current is not None and getattr(current, "mode", "OBJECT") != "OBJECT":
        try:
            bpy.ops.object.mode_set(mode="OBJECT")
        except Exception:
            pass
    deselect_all()
    obj.hide_set(False)
    obj.hide_viewport = False
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def active_principled(mat):
    if not mat or not mat.use_nodes or not mat.node_tree:
        return None
    for node in mat.node_tree.nodes:
        if node.bl_idname == "ShaderNodeBsdfPrincipled":
            return node
    return None


def set_input(node, names, value):
    for name in names:
        socket = node.inputs.get(name)
        if socket is not None:
            socket.default_value = value
            return True
    return False


def ensure_uv(obj):
    if obj.type != "MESH":
        return
    if len(obj.data.uv_layers) > 0:
        return
    activate(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15192, island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)


def bake_image(obj, mat, stem, channel, bake_type, colorspace="sRGB", size=1024):
    image_name = f"{stem}_{channel}"
    image_path = TEX_DIR / f"{image_name}.png"
    if image_path.exists():
        image = bpy.data.images.get(image_name)
        if image is None:
            image = bpy.data.images.load(str(image_path), check_existing=True)
            image.name = image_name
        try:
            image.colorspace_settings.name = colorspace
        except Exception:
            pass
        log(f"Using cached bake: {image_path.name}")
        return image

    image = bpy.data.images.get(image_name)
    if image:
        bpy.data.images.remove(image)
    image = bpy.data.images.new(image_name, width=size, height=size, alpha=False, float_buffer=False)
    image.generated_color = (0.5, 0.5, 0.5, 1.0)
    image.file_format = "PNG"
    image.filepath_raw = str(image_path)
    try:
        image.colorspace_settings.name = colorspace
    except Exception:
        pass

    nodes = mat.node_tree.nodes
    bake_node = nodes.new("ShaderNodeTexImage")
    bake_node.name = f"__BAKE_{channel}"
    bake_node.label = f"BAKE {channel}"
    bake_node.image = image
    nodes.active = bake_node

    activate(obj)

    log(f"Baking {obj.name}: {channel} {size}x{size}")
    if bake_type == "DIFFUSE":
        bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, use_clear=True, margin=12)
    elif bake_type == "NORMAL":
        bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", use_clear=True, margin=12)
    else:
        bpy.ops.object.bake(type=bake_type, use_clear=True, margin=12)

    image.save()
    nodes.remove(bake_node)
    return image


def make_game_material(name, base_img, rough_img, normal_img, is_leaf=False):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (280, 0)
    out.location = (560, 0)
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    tex_base = nodes.new("ShaderNodeTexImage")
    tex_base.image = base_img
    tex_base.label = "Baked Base Color"
    tex_base.location = (-620, 180)
    links.new(tex_base.outputs["Color"], bsdf.inputs["Base Color"])

    tex_rough = nodes.new("ShaderNodeTexImage")
    tex_rough.image = rough_img
    tex_rough.label = "Baked Roughness"
    tex_rough.location = (-620, -40)
    try:
        rough_img.colorspace_settings.name = "Non-Color"
    except Exception:
        pass
    links.new(tex_rough.outputs["Color"], bsdf.inputs["Roughness"])

    tex_norm = nodes.new("ShaderNodeTexImage")
    tex_norm.image = normal_img
    tex_norm.label = "Baked Normal"
    tex_norm.location = (-620, -270)
    try:
        normal_img.colorspace_settings.name = "Non-Color"
    except Exception:
        pass
    normal = nodes.new("ShaderNodeNormalMap")
    normal.location = (-260, -250)
    normal.inputs["Strength"].default_value = 0.72 if not is_leaf else 0.58
    links.new(tex_norm.outputs["Color"], normal.inputs["Color"])
    links.new(normal.outputs["Normal"], bsdf.inputs["Normal"])

    set_input(bsdf, ["IOR"], 1.43 if not is_leaf else 1.46)
    if is_leaf:
        set_input(bsdf, ["Subsurface Weight", "Subsurface"], 0.035)
        set_input(bsdf, ["Coat Weight", "Coat"], 0.02)
    else:
        set_input(bsdf, ["Subsurface Weight", "Subsurface"], 0.075)
        set_input(bsdf, ["Coat Weight", "Coat"], 0.1)
        set_input(bsdf, ["Coat Roughness"], 0.22)
    return mat


def replace_with_simple_material(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def simplify_geometry():
    # The berries are already ~6K polygons each before the render Subdivision.
    # Remove that modifier and keep the authored base surface.
    for name in TARGETS:
        obj = bpy.data.objects.get(name)
        if not obj or obj.type != "MESH":
            continue
        if name.startswith("Grape_"):
            for mod in list(obj.modifiers):
                if mod.type == "SUBSURF":
                    obj.modifiers.remove(mod)
        for poly in obj.data.polygons:
            poly.use_smooth = True

    # The leaf is the largest single mesh (~27.6K polygons before thickness).
    leaf = bpy.data.objects.get("GrapeLeaf_Blade")
    if leaf:
        activate(leaf)

        # Preserve the authored subtle thickness first, then reduce the result.
        for mod in list(leaf.modifiers):
            if mod.type == "SOLIDIFY":
                bpy.ops.object.modifier_apply(modifier=mod.name)

        dec = leaf.modifiers.new(name="VR leaf decimation", type="DECIMATE")
        dec.ratio = 0.065
        dec.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=dec.name)
        for poly in leaf.data.polygons:
            poly.use_smooth = True

    # Small cork scars are over-segmented relative to their on-screen size.
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH":
            continue
        if obj.name.startswith("Stem collar") or obj.name.startswith("Blossom scar") or obj.name == "Stem | visible cut end":
            activate(obj)
            dec = obj.modifiers.new(name="VR tiny detail decimation", type="DECIMATE")
            dec.ratio = 0.35
            dec.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier=dec.name)
            for poly in obj.data.polygons:
                poly.use_smooth = True


def simplify_small_materials():
    # Stem/pedicel materials are tiny in-game; use lightweight Principled values.
    stem_mat = bpy.data.materials.new("Stem_Game_PBR")
    stem_mat.use_nodes = True
    p = active_principled(stem_mat)
    if p:
        p.inputs["Base Color"].default_value = (0.18, 0.245, 0.075, 1.0)
        p.inputs["Roughness"].default_value = 0.72

    cork_mat = bpy.data.materials.new("Cork_Game_PBR")
    cork_mat.use_nodes = True
    p = active_principled(cork_mat)
    if p:
        p.inputs["Base Color"].default_value = (0.23, 0.145, 0.075, 1.0)
        p.inputs["Roughness"].default_value = 0.84

    cut_mat = bpy.data.materials.new("StemCut_Game_PBR")
    cut_mat.use_nodes = True
    p = active_principled(cut_mat)
    if p:
        p.inputs["Base Color"].default_value = (0.45, 0.34, 0.18, 1.0)
        p.inputs["Roughness"].default_value = 0.78

    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        if obj.name in {"Stem | short natural rachis", "Pedicel 01", "Pedicel 02", "Pedicel 03", "Leaf | short petiole"}:
            replace_with_simple_material(obj, stem_mat)
        elif obj.name.startswith("Stem collar") or obj.name.startswith("Blossom scar"):
            replace_with_simple_material(obj, cork_mat)
        elif obj.name == "Stem | visible cut end":
            replace_with_simple_material(obj, cut_mat)


def cleanup_scene():
    for obj in list(bpy.context.scene.objects):
        if obj.name not in KEEP_NAMES:
            bpy.data.objects.remove(obj, do_unlink=True)

    # Remove hidden/non-render mesh objects if any survived by naming accident.
    for obj in list(bpy.context.scene.objects):
        if obj.type == "MESH" and obj.name not in KEEP_NAMES:
            bpy.data.objects.remove(obj, do_unlink=True)

    # Drop unused source-only datablocks (Cycles studio renders, old materials, etc.)
    # so the optimized .blend stays useful as an editable game asset.
    for collection in (
        bpy.data.materials,
        bpy.data.images,
        bpy.data.meshes,
        bpy.data.curves,
        bpy.data.cameras,
        bpy.data.lights,
    ):
        for block in list(collection):
            if block.users == 0:
                collection.remove(block)


def print_stats(label):
    polys = 0
    verts = 0
    meshes = 0
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            meshes += 1
            polys += len(obj.data.polygons)
            verts += len(obj.data.vertices)
    log(f"{label}: meshes={meshes} vertices={verts} polygons={polys}")


scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 16
scene.render.bake.use_clear = True
scene.render.bake.margin = 12

log(f"Source: {bpy.data.filepath}")
print_stats("source base geometry")

# Bake the expensive authored materials before simplifying geometry.
baked = {}
for obj_name, stem in TARGETS.items():
    obj = bpy.data.objects.get(obj_name)
    if not obj or obj.type != "MESH" or not obj.material_slots or not obj.material_slots[0].material:
        raise RuntimeError(f"Missing bake target/material: {obj_name}")
    ensure_uv(obj)
    mat = obj.material_slots[0].material
    baked[obj_name] = {
        "base": bake_image(obj, mat, stem, "basecolor", "DIFFUSE", "sRGB", 1024),
        "rough": bake_image(obj, mat, stem, "roughness", "ROUGHNESS", "Non-Color", 1024),
        "normal": bake_image(obj, mat, stem, "normal", "NORMAL", "Non-Color", 1024),
    }

for obj_name, maps in baked.items():
    obj = bpy.data.objects[obj_name]
    game_mat = make_game_material(
        f"{TARGETS[obj_name]}_Game_PBR",
        maps["base"],
        maps["rough"],
        maps["normal"],
        is_leaf=(obj_name == "GrapeLeaf_Blade"),
    )
    replace_with_simple_material(obj, game_mat)

simplify_geometry()
simplify_small_materials()
cleanup_scene()
print_stats("optimized geometry")

# Normalize selection for export.
deselect_all()
for obj in bpy.context.scene.objects:
    if obj.type == "MESH":
        obj.select_set(True)

bpy.ops.export_scene.gltf(
    filepath=str(OUT_GLB),
    export_format="GLB",
    use_selection=True,
    export_apply=True,
    export_materials="EXPORT",
    export_yup=True,
)
log(f"Exported GLB: {OUT_GLB}")

# Re-import the finished GLB into a clean Blender file. This keeps the editable
# game source free of the original Cycles studio scene and unused datablocks.
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.import_scene.gltf(filepath=str(OUT_GLB))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT_BLEND), check_existing=False)
log(f"Saved clean optimized blend: {OUT_BLEND}")

print_stats("final")
