"""Author a seamless anatomical, skinned hand for WineVR. No external assets.

Blender 5.x --background --factory-startup --python tools/build_museum_hand.py
The coordinates in the construction data are Godot coordinates, metres.
"""
import bpy, bmesh, math, os, json
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(ROOT, 'assets', 'models', 'museum_hand')
os.makedirs(DEST, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 8
scene.cycles.bake_type = 'EMIT'

def B(p): return Vector((p[0], -p[2], p[1]))
def G(p): return Vector((p.x, p.z, -p.y))
skin_parts = []
def ellipsoid(name, p, radii, parts=skin_parts):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, location=B(p))
    ob = bpy.context.object; ob.name = name
    ob.scale = (radii[0], radii[2], radii[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if parts is not None: parts.append(ob)
    return ob

# Palm silhouette, padded thenar/hypothenar masses, narrower wrist and forearm.
ellipsoid('Wrist', (0, -.001, .064), (.027, .017, .031))
ellipsoid('Thenar', (-.025, .007, .029), (.022, .009, .033))
ellipsoid('Hypothenar', (.025, .004, .022), (.018, .008, .039))

digits = []
for name, x, z, lengths, radius in [
    ('index', -.030, -.037, [.041, .025, .019], .0092),
    ('middle', -.009, -.043, [.046, .028, .020], .0096),
    ('ring', .013, -.039, [.043, .026, .019], .0090),
    ('little', .032, -.028, [.033, .021, .017], .0077),
]:
    points = [Vector((x, 0, z))]
    for length in lengths: points.append(points[-1] + Vector((0, 0, -length)))
    digits.append(dict(name=name, points=points, radius=radius))
digits.append(dict(name='thumb', points=[Vector(p) for p in [
    (-.033, .001, .025), (-.056, .001, .006),
    (-.073, .001, -.017), (-.083, .001, -.040)]], radius=.0105))

def tube(name, a, b, r0, r1, depth_ratio=.87):
    a, b = Vector(a), Vector(b)
    d = (b-a).normalized()
    axis = Vector((0, 1, 0))
    side = d.cross(axis).normalized()
    vertices, faces = [], []
    for k in range(9):
        t = k/8; c = a.lerp(b, t)
        r = (r0*(1-t)+r1*t) * (1 + .035*math.sin(t*math.pi*2))
        for j in range(20):
            angle = 2*math.pi*j/20
            v = c + side * (r*math.cos(angle)) + axis*(r*depth_ratio*math.sin(angle))
            vertices.append(B(v))
    for k in range(8):
        for j in range(20):
            n = k*20+j; n1 = k*20+(j+1)%20
            faces.append((n, n+20, n1+20, n1))
    faces += [tuple(range(20)), tuple(reversed(range(160,180)))]
    mesh = bpy.data.meshes.new(name); mesh.from_pydata(vertices, [], faces); mesh.update()
    ob = bpy.data.objects.new(name, mesh); scene.collection.objects.link(ob)
    skin_parts.append(ob)

# A palm is broad through the knuckles, rather than an ellipsoid with four
# spherical bumps attached at its narrow end. Loft its rounded cross-sections.
vertices, faces = [], []
sections = [(.073,.025,.015),(.050,.033,.0155),(.012,.042,.014),(-.020,.043,.012),(-.038,.039,.010),(-.047,.032,.008)]
for z, width, depth in sections:
    for j in range(32):
        a=j*2*math.pi/32
        vertices.append(B((width*math.cos(a),depth*math.sin(a),z)))
for k in range(len(sections)-1):
    for j in range(32):
        a=k*32+j;b=k*32+(j+1)%32;faces.append((a,b,b+32,a+32))
faces += [tuple(reversed(range(32))),tuple(range((len(sections)-1)*32,len(sections)*32))]
mesh=bpy.data.meshes.new('Palm loft');mesh.from_pydata(vertices,[],faces);mesh.update()
ob=bpy.data.objects.new('Anatomical palm',mesh);scene.collection.objects.link(ob);skin_parts.append(ob)
tube('Continuous forearm', (0,-.002,.020),(.004,-.003,.275),.020,.040,.70)
for digit in digits:
    points, radius = digit['points'], digit['radius']
    for i in range(3):
        r0 = radius * [1.02,.87,.77][i]
        r1 = radius * [.88,.78,.65][i]
        tube(digit['name'] + str(i), points[i], points[i+1], r0, r1)
        ellipsoid('Knuckle', points[i], (r0*1.06, r0*.91, r0*1.08))
    ellipsoid('FingerPad', points[-1], (radius*.66, radius*.63, radius*.69))

bpy.ops.object.select_all(action='DESELECT')
for ob in skin_parts: ob.select_set(True)
bpy.context.view_layer.objects.active = skin_parts[0]
bpy.ops.object.join()
hand = bpy.context.object; hand.name = 'AnatomicalHandSkin'
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bm=bmesh.new();bm.from_mesh(hand.data)
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(hand.data);bm.free()
remesh = hand.modifiers.new('Seamless sculpt union', 'REMESH')
remesh.mode = 'VOXEL'; remesh.voxel_size = .00095; remesh.use_smooth_shade = True
bpy.ops.object.modifier_apply(modifier=remesh.name)
smooth = hand.modifiers.new('Organic surface relaxation', 'SMOOTH'); smooth.factor=.65; smooth.iterations=8
bpy.ops.object.modifier_apply(modifier=smooth.name)
decimate = hand.modifiers.new('Game mesh', 'DECIMATE'); decimate.ratio=.42
bpy.ops.object.modifier_apply(modifier=decimate.name)

# Fine folds around finger joints, raised dorsal knuckles and palm flexion lines.
for vertex in hand.data.vertices:
    p = G(vertex.co)
    for digit in digits[:4]:
        x, root_z = digit['points'][0].x, digit['points'][0].z
        if abs(p.x-x) < digit['radius']*1.15 and p.z < root_z+.004:
            for j in [1,2]:
                dz = p.z-digit['points'][j].z
                fold = math.exp(-(dz/.0012)**2)
                if p.y > .002: p.y -= .00065 * fold
                elif p.y < -.002:
                    p.y += .00035 * (fold + .6*math.exp(-((dz-.0026)/.001)**2))
    if p.y > .008 and -.025 < p.z < .052:
        for z0 in [-.018 + p.x*.20, .012 - p.x*.42]:
            p.y -= .00055*math.exp(-((p.z-z0)/.0013)**2)
    vertex.co = B(p)
for face in hand.data.polygons: face.use_smooth = True

def material(name, color, roughness):
    mat = bpy.data.materials.new(name); mat.use_nodes = True
    bs = mat.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = color
    bs.inputs['Roughness'].default_value = roughness
    return mat, bs

skin, bs = material('Warm natural skin', (.49,.26,.17,1), .62)
nodes, links = skin.node_tree.nodes, skin.node_tree.links
coord = nodes.new('ShaderNodeTexCoord')
noise = nodes.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value=90; noise.inputs['Detail'].default_value=3
links.new(coord.outputs['Object'], noise.inputs['Vector'])
ramp = nodes.new('ShaderNodeValToRGB')
ramp.color_ramp.elements[0].position=.18; ramp.color_ramp.elements[0].color=(.46,.235,.155,1)
ramp.color_ramp.elements[1].position=.82; ramp.color_ramp.elements[1].color=(.53,.285,.195,1)
links.new(noise.outputs['Fac'], ramp.inputs[0]); links.new(ramp.outputs[0], bs.inputs['Base Color'])
pores = nodes.new('ShaderNodeTexNoise'); pores.inputs['Scale'].default_value=3500; pores.inputs['Detail'].default_value=2
links.new(coord.outputs['Object'], pores.inputs['Vector'])
bump = nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value=.12; bump.inputs['Distance'].default_value=.00005
links.new(pores.outputs['Fac'], bump.inputs['Height']); links.new(bump.outputs[0], bs.inputs['Normal'])
bs.inputs['Subsurface Weight'].default_value=.09
hand.data.materials.append(skin)
bpy.context.view_layer.objects.active=hand
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=1.1, island_margin=.008)
bpy.ops.object.mode_set(mode='OBJECT')

def bake(channel):
    im = bpy.data.images.new('hand_skin_'+channel, width=2048, height=2048, alpha=False)
    im.colorspace_settings.name = 'sRGB' if channel=='albedo' else 'Non-Color'
    target = nodes.new('ShaderNodeTexImage'); target.image=im
    nodes.active=target
    output = nodes.get('Material Output'); old_surface=output.inputs[0].links[0].from_socket
    if channel=='albedo':
        emission=nodes.new('ShaderNodeEmission'); links.new(ramp.outputs[0],emission.inputs[0]); links.new(emission.outputs[0],output.inputs[0])
    bpy.ops.object.bake(type='EMIT' if channel=='albedo' else 'NORMAL', margin=10)
    if channel=='albedo': links.new(old_surface,output.inputs[0]);nodes.remove(emission)
    im.filepath_raw=os.path.join(DEST,'hand_skin_'+channel+'.png'); im.file_format='PNG'; im.save()
    nodes.remove(target)
    return im
albedo, normal = bake('albedo'), bake('normal')
game_skin, game_bs = material('Skin — pores and natural pigmentation', (.49,.26,.17,1), .62)
gn, gl = game_skin.node_tree.nodes, game_skin.node_tree.links
tex=gn.new('ShaderNodeTexImage');tex.image=albedo;gl.new(tex.outputs[0],game_bs.inputs['Base Color'])
tex=gn.new('ShaderNodeTexImage');tex.image=normal
nm=gn.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.35
gl.new(tex.outputs[0],nm.inputs['Color']);gl.new(nm.outputs[0],game_bs.inputs['Normal'])
hand.data.materials.clear();hand.data.materials.append(game_skin)

# Rig data also drives the contact solver. Separate nail meshes follow distal bones.
arm_data=bpy.data.armatures.new('MuseumHandRig'); arm=bpy.data.objects.new('MuseumHandRig',arm_data);scene.collection.objects.link(arm)
bpy.ops.object.select_all(action='DESELECT');arm.select_set(True);bpy.context.view_layer.objects.active=arm
bpy.ops.object.mode_set(mode='EDIT')
root=arm_data.edit_bones.new('palm');root.head=B((0,0,.065));root.tail=B((0,0,-.025))
for digit in digits:
    parent=root
    for i in range(3):
        bone=arm_data.edit_bones.new(digit['name']+'_'+str(i))
        bone.head=B(digit['points'][i]);bone.tail=B(digit['points'][i+1]);bone.parent=parent;parent=bone
bpy.ops.object.mode_set(mode='OBJECT')
groups={b.name:hand.vertex_groups.new(name=b.name) for b in arm_data.bones}
def segment_distance(p,a,b):
    t=max(0,min(1,(p-a).dot(b-a)/(b-a).length_squared))
    return (p-a.lerp(b,t)).length
for vertex in hand.data.vertices:
    p=G(vertex.co); choices=[]
    for digit in digits:
        points=digit['points'];dist=min(segment_distance(p,points[i],points[i+1]) for i in range(3))
        eligible = p.z < points[0].z+.008 if digit['name']!='thumb' else p.x < -.034
        if eligible: choices.append((dist,digit))
    if not choices: groups['palm'].add([vertex.index],1,'REPLACE');continue
    distance,digit=min(choices,key=lambda pair:pair[0])
    if distance > digit['radius']*1.6: groups['palm'].add([vertex.index],1,'REPLACE');continue
    points=digit['points']; centres=[points[i].lerp(points[i+1],.50) for i in range(3)]
    weights=[1/max(.002,(p-c).length)**4 for c in centres]
    weights=sorted(enumerate(weights),key=lambda q:q[1],reverse=True)[:2]
    palm_weight=0
    if digit['name']!='thumb': palm_weight=max(0,min(1,(p.z-points[0].z+.008)/.016))
    else: palm_weight=max(0,min(1,(p.x+.052)/.018))
    total=sum(w for _,w in weights)
    for i,w in weights: groups[digit['name']+'_'+str(i)].add([vertex.index],w/total*(1-palm_weight),'REPLACE')
    if palm_weight:groups['palm'].add([vertex.index],palm_weight,'REPLACE')
modifier=hand.modifiers.new('Articulated fingers','ARMATURE');modifier.object=arm;hand.parent=arm

nail_mat,nail_bs=material('Natural translucent nail bed',(.42,.26,.21,1),.38)
tip_mat,_=material('Short ivory free nail edge',(.49,.44,.36,1),.42)
for digit in digits:
    tip=digit['points'][-1]; direction=(digit['points'][-1]-digit['points'][-2]).normalized()
    center=tip-direction*.009+Vector((0,-digit['radius']*.64,0))
    nail=ellipsoid('Nail_'+digit['name'],center,(digit['radius']*.62,.0013,.008),None)
    # Thumb nail follows its splayed distal direction.
    angle=math.atan2(-direction.x,-direction.z)
    nail.rotation_euler.z=angle
    nail.data.materials.append(nail_mat)
    for p in nail.data.polygons:p.use_smooth=True
    group=nail.vertex_groups.new(name=digit['name']+'_2');group.add(list(range(len(nail.data.vertices))),1,'REPLACE')
    mod=nail.modifiers.new('Nail follows fingertip','ARMATURE');mod.object=arm;nail.parent=arm
    edge=ellipsoid('NailEdge_'+digit['name'],center+direction*.006,(digit['radius']*.56,.001,.0016),None)
    edge.rotation_euler.z=angle;edge.data.materials.append(tip_mat)
    for p in edge.data.polygons:p.use_smooth=True
    group=edge.vertex_groups.new(name=digit['name']+'_2');group.add(list(range(len(edge.data.vertices))),1,'REPLACE')
    mod=edge.modifiers.new('Nail edge follows fingertip','ARMATURE');mod.object=arm;edge.parent=arm

# Sleeve is an open tapered cuff, so the forearm does not end in a floating ball.
vertices,faces=[],[]
for k in range(7):
    z=.208+k*.024
    for j in range(32):
        a=j*2*math.pi/32;ripple=1+.012*math.sin(j*5+k)
        vertices.append(B((math.cos(a)*(.035+k*.0014)*ripple,math.sin(a)*(.027+k*.0011)*ripple-.003,z)))
for k in range(6):
    for j in range(32):
        a=k*32+j;b=k*32+(j+1)%32;faces.append((a,b,b+32,a+32))
mesh=bpy.data.meshes.new('Tailored cuff');mesh.from_pydata(vertices,[],faces);mesh.update()
sleeve=bpy.data.objects.new('Museum jacket cuff',mesh);scene.collection.objects.link(sleeve)
mat,_=material('Museum jacket — dark olive cotton',(.025,.040,.032,1),.91);mesh.materials.append(mat)
for p in mesh.polygons:p.use_smooth=True
solid=sleeve.modifiers.new('Cuff thickness','SOLIDIFY');solid.thickness=.0016
bpy.context.view_layer.objects.active=sleeve;bpy.ops.object.modifier_apply(modifier=solid.name)
group=sleeve.vertex_groups.new(name='palm');group.add(list(range(len(mesh.vertices))),1,'REPLACE')
mod=sleeve.modifiers.new('Wrist attachment','ARMATURE');mod.object=arm;sleeve.parent=arm

metadata={'authorship':'Procedurally authored for WineVR; no external hand assets',
          'units':'metres', 'palm_normal':[0,1,0], 'digits':[]}
for d in digits:
    metadata['digits'].append({'name':d['name'],'points':[list(p) for p in d['points']],'radius':d['radius']})
with open(os.path.join(DEST,'hand_rig.json'),'w',encoding='utf8') as f:json.dump(metadata,f,indent=2)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'blender_models','museum_hand.blend'))
bpy.ops.export_scene.gltf(filepath=os.path.join(DEST,'museum_hand.glb'),export_format='GLB',export_animations=False,export_skins=True,export_yup=True,export_apply=False)
print('HAND_ASSET_COMPLETE',len(hand.data.vertices),'vertices',len(arm_data.bones),'bones')
