"""Bake the authored Blender fruit shaders and export compact, anchored glTF assets.

Run with Blender 5.x --background --factory-startup --python this_file.py.
The source .blend files stay editable; only the game copies are optimized.
"""
import bpy, os, json, math, shutil, sys
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCES = r'C:\Users\mario\Documents\Codex\2026-10-15\new-chat\outputs'
DEST = os.path.join(ROOT, 'assets', 'models', 'grape_museum')
os.makedirs(DEST, exist_ok=True)
reports = []
REBAKE = '--rebake' in sys.argv

def image_bake(ob, material, channel, filename, size=512):
    cached=os.path.join(DEST,filename+'.png')
    if os.path.exists(cached) and not REBAKE:
        image=bpy.data.images.load(cached,check_existing=False)
        image.colorspace_settings.name='sRGB' if channel=='COLOR' else 'Non-Color'
        return image
    ob.hide_render=False
    nodes=material.node_tree.nodes; links=material.node_tree.links
    bs=next(n for n in nodes if n.type=='BSDF_PRINCIPLED')
    output=next(n for n in nodes if n.type=='OUTPUT_MATERIAL')
    image=bpy.data.images.new(filename, width=size, height=size, alpha=False)
    image.colorspace_settings.name='sRGB' if channel=='COLOR' else 'Non-Color'
    target=nodes.new('ShaderNodeTexImage');target.image=image
    for n in nodes:n.select=False
    target.select=True;nodes.active=target
    surface=output.inputs['Surface'].links[0].from_socket
    if channel in ['COLOR','ROUGHNESS']:
        emit=nodes.new('ShaderNodeEmission')
        inp=bs.inputs['Base Color' if channel=='COLOR' else 'Roughness']
        if inp.is_linked:links.new(inp.links[0].from_socket,emit.inputs[0])
        else:emit.inputs[0].default_value=inp.default_value if channel=='COLOR' else (inp.default_value,)*3+(1,)
        links.new(emit.outputs[0],output.inputs['Surface'])
    bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
    bpy.ops.object.bake(type='NORMAL' if channel=='NORMAL' else 'EMIT',margin=8,use_clear=True)
    if channel in ['COLOR','ROUGHNESS']:
        links.new(surface,output.inputs['Surface']);nodes.remove(emit)
    image.filepath_raw=os.path.join(DEST,filename+'.png');image.file_format='PNG';image.save()
    nodes.remove(target)
    ob.hide_render=True
    return image

def pbr(name, color, rough, normal):
    mat=bpy.data.materials.new(name);mat.use_nodes=True
    nodes=mat.node_tree.nodes;links=mat.node_tree.links;bs=nodes.get('Principled BSDF')
    for image,socket in [(color,'Base Color'),(rough,'Roughness')]:
        tex=nodes.new('ShaderNodeTexImage');tex.image=image;links.new(tex.outputs[0],bs.inputs[socket])
    tex=nodes.new('ShaderNodeTexImage');tex.image=normal
    n=nodes.new('ShaderNodeNormalMap');links.new(tex.outputs[0],n.inputs['Color']);links.new(n.outputs[0],bs.inputs['Normal'])
    bs.inputs['IOR'].default_value=1.42;bs.inputs['Specular IOR Level'].default_value=.28
    return mat

for variety,title in [('liatiko','Liatiko'),('kotsifali','Kotsifali')]:
    source_copy=os.path.join(ROOT,'blender_models',variety+'_bunch.blend')
    if not os.path.exists(source_copy):shutil.copy2(os.path.join(SOURCES,variety+'_bunch.blend'),source_copy)
    source=source_copy
    bpy.ops.wm.open_mainfile(filepath=source)
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.device='CPU'
    scene.cycles.samples=4;scene.cycles.use_denoising=False
    scene.render.bake.use_selected_to_active=False
    for obj in scene.objects:obj.hide_render=True
    model=bpy.data.collections[title.upper()+' | editable botanical model']
    berries=sorted([o for o in model.objects if o.name.startswith(title+' berry')],key=lambda o:o.name)
    variants=[]
    for i in range(6):
        ob=berries[i*max(1,len(berries)//6)]
        original=ob.data.materials[0]
        # Shared sphere meshes need temporary per-object materials during baking.
        ob.material_slots[0].link='OBJECT';mat=original.copy();ob.material_slots[0].material=mat
        color=image_bake(ob,mat,'COLOR',f'{variety}_skin_{i}_albedo')
        rough=image_bake(ob,mat,'ROUGHNESS',f'{variety}_skin_{i}_roughness')
        normal=image_bake(ob,mat,'NORMAL',f'{variety}_skin_{i}_normal')
        variants.append(pbr(f'{title} | baked skin {i}',color,rough,normal))
        ob.material_slots[0].material=original
        print('BAKED',variety,i,flush=True)
    for i,ob in enumerate(berries):
        ob.data=ob.data.copy();ob.data.materials.clear();ob.data.materials.append(variants[(i*7+i//6)%len(variants)])
        if ob.material_slots:ob.material_slots[0].link='DATA'
        ob.modifiers.clear()
        dec=ob.modifiers.new('Game silhouette budget','DECIMATE');dec.ratio=.34
    # The authored leaf maps are already packed. Connect them to exportable glTF PBR sockets.
    leaf=next(o for o in model.objects if 'five-lobed upper leaf' in o.name)
    old=leaf.data.materials[0];ns=old.node_tree.nodes
    for mod in leaf.modifiers:mod.show_render=False;mod.show_viewport=False
    color=image_bake(leaf,old,'COLOR',variety+'_leaf_albedo',1024)
    normal=image_bake(leaf,old,'NORMAL',variety+'_leaf_normal',1024)
    lm=bpy.data.materials.new(title+' | double-sided leaf');lm.use_nodes=True
    bs=lm.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.72
    tex=lm.node_tree.nodes.new('ShaderNodeTexImage');tex.image=color
    lm.node_tree.links.new(tex.outputs[0],bs.inputs['Base Color']);lm.use_backface_culling=False
    tex=lm.node_tree.nodes.new('ShaderNodeTexImage');tex.image=normal
    norm=lm.node_tree.nodes.new('ShaderNodeNormalMap')
    lm.node_tree.links.new(tex.outputs[0],norm.inputs[1]);lm.node_tree.links.new(norm.outputs[0],bs.inputs['Normal'])
    leaf.data.materials.clear();leaf.data.materials.append(lm)
    leaf.modifiers.clear()
    # Joined meshes must share the same UV layer name or the leaf lands on an empty UV0.
    leaf.data.uv_layers.active.name='UVMap'
    dec=leaf.modifiers.new('Game leaf silhouette','DECIMATE');dec.ratio=.32
    # Stem shader has millimetre fibres. Use a quiet olive PBR surface in the game.
    stem=next(m for m in bpy.data.materials if title.upper()+' | olive rachis' in m.name)
    stem.node_tree.nodes.clear();bs=stem.node_tree.nodes.new('ShaderNodeBsdfPrincipled')
    bs.inputs['Base Color'].default_value=(.075,.105,.018,1);bs.inputs['Roughness'].default_value=.67
    oo=stem.node_tree.nodes.new('ShaderNodeOutputMaterial');stem.node_tree.links.new(bs.outputs[0],oo.inputs[0])
    objects=[o for o in model.objects if o.type in {'MESH','CURVE'}]
    rachis=bpy.data.objects['Rachis | continuous tapered central stem']
    anchor=rachis.matrix_world@rachis.data.splines[0].bezier_points[0].co
    for ob in objects:
        ob.hide_render=False
        if ob.type=='CURVE':ob.data.resolution_u=4;ob.data.bevel_resolution=1;ob.data.use_fill_caps=True
    # Join into one object with a small number of material surfaces, reducing XR draw calls.
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objects:ob.select_set(True)
    bpy.context.view_layer.objects.active=berries[0]
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.join()
    joined=bpy.context.object;joined.name=title+'_MuseumBunch'
    # Bake transforms and put the suspension cut point precisely at the root origin.
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    world=joined.matrix_world.copy()
    for vert in joined.data.vertices:vert.co=world@vert.co-anchor
    joined.matrix_world.identity()
    # Remove duplicate material slots after joining shared materials.
    bpy.ops.object.material_slot_remove_unused()
    joined.data.calc_loop_triangles();triangles=len(joined.data.loop_triangles)
    joined['suspension_anchor']='Root origin at the central peduncle cut face; Blender Z-up, glTF Y-up.'
    joined['source']=variety+'_bunch.blend; corrected stem connections, 2026-10-15'
    path=os.path.join(DEST,variety+'_bunch.glb')
    bpy.ops.export_scene.gltf(filepath=path,export_format='GLB',use_selection=True,
        export_apply=True,export_yup=True,export_materials='EXPORT',export_cameras=False,
        export_lights=False,export_extras=True,export_image_format='AUTO')
    reports.append({'variety':variety,'berries':len(berries),'triangles':triangles,
        'material_surfaces':len(joined.data.materials),'bytes':os.path.getsize(path),
        'source':source_copy,'anchor_blender':list(anchor)})
    print('EXPORTED',json.dumps(reports[-1]),flush=True)
with open(os.path.join(DEST,'asset_report.json'),'w') as f:json.dump(reports,f,indent=2)
