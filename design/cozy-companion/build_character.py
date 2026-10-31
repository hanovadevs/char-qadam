"""Editable reference-inspired 3D companion; no external textures or add-ons.

blender --background --factory-startup --python design/cozy-companion/build_character.py
All dimensions are local design units. Front is -Y, up is Z. Original Pip is retained.
"""
import math
from pathlib import Path
import bpy
from mathutils import Vector, Quaternion

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
CLIPS = ['rest', 'walk', 'wave', 'point', 'cheer', 'ready', 'wait', 'reassure',
         'idle', 'wiggle', 'love', 'gift', 'peek']
PALETTE = dict(skin='F2CDB4', blush='E6A598', nose='DC927E', hair='4D3325',
               hair_light='654832', eye='30241E', sage='9DAF8C', sage_dark='879C78',
               seam='81926F', cream='F4F0DF', trouser='DAD7C5', cuff='E7E4D3',
               shoe='FCFAEF', sole='E6E6DC', tan='C99770', backpack='536D6E',
               strap='526B6C', stitch='829592', button='B5996E', peach='E2A18B',
               paper='FFF6E6', leaf='4D6748')
MATS = {}


def material(key):
    value = PALETTE[key]
    rgb = [int(value[i:i+2], 16) / 255 for i in (0, 2, 4)]
    linear = [c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in rgb]
    mat = bpy.data.materials.new('Cozy / ' + key)
    mat.diffuse_color = (*linear, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*linear, 1)
    shader.inputs['Roughness'].default_value = .68 if key != 'eye' else .4
    shader.inputs['Specular IOR Level'].default_value = .25
    if key in ('skin', 'nose', 'blush'):
        shader.inputs['Subsurface Weight'].default_value = .08
        shader.inputs['Subsurface Radius'].default_value = (1, .45, .25)
    return mat


def empty(name, loc=(0, 0, 0), parent=None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    obj.location = loc
    obj.empty_display_size = .13
    return obj


def finish(obj, name, mat, parent):
    obj.name = name
    obj.parent = parent
    obj.data.materials.append(MATS[mat])
    for face in obj.data.polygons:
        face.use_smooth = True
    return obj


def oval(name, loc, scale, mat, parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=40, ring_count=24, location=loc)
    obj = finish(bpy.context.object, name, mat, parent)
    obj.scale = scale
    return obj


def box(name, loc, dims, radius, mat, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = finish(bpy.context.object, name, mat, parent)
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel = obj.modifiers.new('Soft sewn edges', 'BEVEL')
    bevel.width = radius
    bevel.segments = 5
    normal = obj.modifiers.new('Weighted surface normals', 'WEIGHTED_NORMAL')
    normal.keep_sharp = True
    return obj


def line(name, points, radius, mat, parent=None):
    curve = bpy.data.curves.new(name, 'CURVE')
    curve.dimensions = '3D'
    curve.resolution_u = 16
    curve.bevel_depth = radius
    curve.bevel_resolution = 4
    spline = curve.splines.new('BEZIER')
    spline.bezier_points.add(len(points) - 1)
    for point, xyz in zip(spline.bezier_points, points):
        point.co = xyz
        point.handle_left_type = point.handle_right_type = 'AUTO'
    obj = bpy.data.objects.new(name, curve)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    obj.data.materials.append(MATS[mat])
    return obj


def panel(name, outline, depth, mat, parent=None, bevel=.05):
    verts = [(x, y, z) for x, y, z in outline]
    verts += [(x, y + depth, z) for x, y, z in outline]
    n = len(outline)
    faces = [tuple(reversed(range(n))), tuple(range(n, n * 2))]
    faces += [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    finish(obj, name, mat, parent)
    mod = obj.modifiers.new('Rounded fabric edges', 'BEVEL')
    mod.width = bevel
    mod.segments = 4
    obj.modifiers.new('Tailored normals', 'WEIGHTED_NORMAL')
    return obj


def hair_cap(head):
    verts, faces = [], []
    columns, rows = 64, 32
    for row in range(rows + 1):
        for col in range(columns):
            phi = col / columns * math.tau
            # Short at the forehead, full around the ears and nape.
            if math.sin(phi) < 0:
                x = math.cos(phi)
                edge = [(-1,4.46),(-.86,4.80),(-.67,4.94),(-.22,4.79),
                        (-.07,4.81),(.04,5.20),(.20,4.98),(.55,4.80),
                        (.73,4.75),(.90,4.49),(1,4.44)]
                for (a,za),(b,zb) in zip(edge,edge[1:]):
                    if a <= x <= b:
                        q=(x-a)/(b-a)
                        q=q*q*(3-2*q)
                        z=za+(zb-za)*q
                        break
                theta_end=math.acos((z-5.08)/1.03)
            else:
                theta_end = 2.32
            theta = .0001 + row / rows * theta_end
            verts.append((1.19 * math.sin(theta) * math.cos(phi),
                          .96 * math.sin(theta) * math.sin(phi) + .06,
                          5.08 + 1.03 * math.cos(theta)))
    for row in range(rows):
        for col in range(columns):
            a = row * columns + col
            b = row * columns + (col + 1) % columns
            faces.append((a, b, b + columns, a + columns))
    mesh = bpy.data.meshes.new('Sculpted continuous hair cap')
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new('Hair / rounded silhouette', mesh)
    bpy.context.scene.collection.objects.link(obj)
    finish(obj, obj.name, 'hair', head)
    solid = obj.modifiers.new('Hair shell', 'SOLIDIFY')
    solid.thickness = .12
    bevel=obj.modifiers.new('Soft rounded fringe edge','BEVEL')
    bevel.width=.045
    bevel.segments=3
    return obj


def lock(name, points, width, depth, parent, mat='hair'):
    # A tapered swept lock instead of disconnected spherical hair blobs.
    verts, faces = [], []
    p0, p1, p2, p3 = [Vector(p) for p in points]
    rows, sides = 24, 24
    for i in range(rows + 1):
        t = i / rows
        pos = (1-t)**3*p0 + 3*(1-t)**2*t*p1 + 3*(1-t)*t*t*p2 + t**3*p3
        taper = max(.003, math.sin(math.pi * t) ** .65)
        for j in range(sides):
            angle = j / sides * math.tau
            verts.append(tuple(pos + Vector((width * taper * math.cos(angle),
                                             depth * taper * math.sin(angle), 0))))
    for i in range(rows):
        for j in range(sides):
            a = i * sides + j
            b = i * sides + (j+1) % sides
            faces.append((a, b, b+sides, a+sides))
    faces += [tuple(reversed(range(sides))), tuple(range(rows*sides, (rows+1)*sides))]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    finish(obj, name, mat, parent)


def light(name, loc, energy, size, color, target=(0, 0, 3)):
    data = bpy.data.lights.new(name, 'AREA')
    data.energy, data.shape, data.size, data.color = energy, 'DISK', size, color
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = loc
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()


def build():
    global MATS
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    scene = bpy.context.scene
    scene.name = 'Stepsy / cozy 3D companion'
    MATS = {key: material(key) for key in PALETTE}
    root = empty('CTRL Root')
    body = empty('CTRL Body', parent=root)
    head = empty('CTRL Head', parent=body)
    face=oval('Face / soft peach', (0, -.04, 4.72), (.99, .83, .99), 'skin', head)
    # Smooth blush belongs to the face material, not raised pink cheek disks.
    face_mat=MATS['skin'].copy()
    face_mat.name='Cozy / skin with soft blush'
    face.data.materials[0]=face_mat
    nodes=face_mat.node_tree.nodes
    links=face_mat.node_tree.links
    coord=nodes.new('ShaderNodeTexCoord')
    weights=[]
    for x in (.24,.76):
        distance=nodes.new('ShaderNodeVectorMath'); distance.operation='DISTANCE'
        links.new(coord.outputs['Generated'],distance.inputs[0])
        distance.inputs[1].default_value=(x,.06,.33)
        ramp=nodes.new('ShaderNodeMapRange'); ramp.interpolation_type='SMOOTHERSTEP'
        links.new(distance.outputs['Value'],ramp.inputs['Value'])
        ramp.inputs['From Min'].default_value=.02
        ramp.inputs['From Max'].default_value=.21
        ramp.inputs['To Min'].default_value=.5
        ramp.inputs['To Max'].default_value=0
        weights.append(ramp)
    add=nodes.new('ShaderNodeMath'); add.operation='ADD'
    for i,weight in enumerate(weights): links.new(weight.outputs['Result'],add.inputs[i])
    mix=nodes.new('ShaderNodeMixRGB')
    mix.inputs[1].default_value=MATS['skin'].diffuse_color
    mix.inputs[2].default_value=MATS['blush'].diffuse_color
    links.new(add.outputs[0],mix.inputs[0])
    links.new(mix.outputs[0],nodes.get('Principled BSDF').inputs['Base Color'])
    for side, sign in [('L', -1), ('R', 1)]:
        oval('Ear ' + side, (sign*.95, -.02, 4.46), (.22, .19, .28), 'skin', head)
        oval('Ear inset ' + side, (sign*1.00, -.185, 4.46), (.12, .045, .17), 'blush', head)
    hair_cap(head)
    lock('Hair / tiny crown tuft', [(-.06,.0,6.04),(-.09,-.02,6.18),(-.22,-.03,6.25),(-.27,-.02,6.19)], .055,.045,head,'hair_light')
    eyes = []
    for side, x in [('L', -.29), ('R', .29)]:
        y = -.04 - .83 * math.sqrt(1-(x/.99)**2-((4.58-4.72)/.99)**2)
        eye = oval('Eye '+side, (x,y-.008,4.59), (.046,.026,.073), 'eye', head)
        eyes.append(eye)
        line('Brow '+side, [(x-.045,y+.014,4.81),(x,y-.005,4.83),(x+.04,y+.014,4.815)], .014,'hair',head)
    oval('Tiny nose', (0,-.887,4.47), (.085,.062,.049), 'nose', head)
    # The reference's tiny, quiet face has no drawn mouth.
    oval('Neck', (0,0,3.71), (.245,.23,.30), 'skin', body)
    box('Cream T-shirt', (0,-.01,2.85), (1.16,.73,1.68), .22,'cream',body)
    oval('Soft ribbed collar', (0,-.11,3.60), (.31,.31,.09), 'cream',body)
    box('Waistband / warm canvas', (0,-.395,2.26), (.65,.055,.19), .018,'tan',body)
    box('Jacket / rounded back', (0,.28,2.82), (1.59,.64,1.62), .29,'sage',body)
    for side, sign in [('L',-1),('R',1)]:
        panel('Jacket front '+side, [(sign*.28,-.49,3.57),(sign*.76,-.27,3.38),
              (sign*.81,-.36,2.03),(sign*.22,-.49,1.99)], .19,'sage',body,.075)
        panel('Folded collar '+side, [(sign*.28,-.52,3.58),(sign*.10,-.54,3.18),
              (sign*.35,-.60,3.29),(sign*.56,-.53,3.18)], .07,'sage_dark',body,.035)
        pocket = box('Patch pocket '+side, (sign*.54,-.535,2.33),(.43,.075,.46),.08,'sage_dark',body)
        panel('Pocket flap '+side, [(sign*.33,-.59,2.57),(sign*.76,-.59,2.57),
              (sign*.64,-.62,2.44),(sign*.40,-.62,2.47)],.035,'sage',body,.022)
        line('Front seam '+side, [(sign*.265,-.596,2.06),(sign*.265,-.596,2.73),
              (sign*.34,-.54,3.22)],.007,'seam',body)
        if side == 'L':
            for i in range(4):
                oval('Wood button '+str(i),(sign*.29,-.608,2.18+i*.27),(.027,.015,.038),'button',body)
    box('Backpack / canvas body', (0,.77,2.92),(1.42,.62,1.55),.28,'backpack',body)
    box('Backpack / front pocket',(0,1.09,2.65),(1.01,.16,.65),.14,'strap',body)
    line('Backpack top handle',[(-.18,.72,3.62),(-.16,.75,3.88),(.16,.75,3.88),(.18,.72,3.62)],.065,'strap',body)
    for side,sign in [('L',-1),('R',1)]:
        # Wide straps wrap over the shoulders, not painted onto the jacket.
        line('Backpack strap '+side,[(sign*.55,.67,3.55),(sign*.61,-.12,3.62),
              (sign*.65,-.56,3.41),(sign*.66,-.64,2.83)],.105,'strap',body)
        for i in range(10):
            z=2.88+i*.055
            line('Strap stitch '+side+str(i),[(sign*.70,-.724,z),(sign*.70,-.724,z+.022)],.004,'stitch',body)
    arms, legs = [], []
    for side, sign in [('L',-1),('R',1)]:
        arm = empty('CTRL Arm '+side,(sign*.74,0,3.38),body)
        sleeve = oval('Jacket upper sleeve '+side,(sign*.10,-.005,-.32),(.31,.35,.52),'sage',arm)
        sleeve.rotation_euler.y=-sign*.12
        forearm=empty('CTRL Forearm '+side,(sign*.20,0,-.70),arm)
        oval('Jacket elbow '+side,(0,0,0),(.28,.33,.24),'sage',forearm)
        sleeve=oval('Jacket fore sleeve '+side,(sign*.06,-.015,-.27),(.29,.33,.43),'sage',forearm)
        sleeve.rotation_euler.y=-sign*.12
        box('Sleeve cuff '+side,(sign*.12,-.04,-.60),(.52,.60,.16),.065,'sage_dark',forearm)
        oval('Hand '+side,(sign*.12,-.04,-.77),(.155,.18,.19),'skin',forearm)
        oval('Thumb '+side,(0,-.17,-.73),(.075,.08,.115),'skin',forearm)
        arms.append(arm)
        leg=empty('CTRL Leg '+side,(sign*.37,0,2.04),root)
        box('Trouser thigh '+side,(0,0,-.39),(.68,.76,.96),.16,'trouser',leg)
        knee=empty('CTRL Knee '+side,(0,0,-.85),leg)
        oval('Soft knee fold '+side,(0,0,0),(.34,.38,.18),'trouser',knee)
        box('Trouser shin '+side,(0,0,-.39),(.68,.76,.98),.15,'trouser',knee)
        box('Trouser cuff '+side,(0,-.005,-.68),(.73,.80,.14),.045,'cuff',knee)
        box('Sneaker sole '+side,(0,-.16,-1.03),(.75,1.10,.13),.06,'sole',knee)
        oval('Sneaker upper '+side,(0,-.12,-.90),(.35,.53,.19),'shoe',knee)
        oval('Sneaker canvas '+side,(0,-.14,-.81),(.31,.40,.15),'tan',knee)
        oval('Sneaker toe cap '+side,(0,-.49,-.92),(.34,.24,.12),'shoe',knee)
        for i in range(3):
            line('Cotton lace '+side+str(i),[(-.19,-.24-i*.07,-.70),
                 (0,-.28-i*.07,-.67),(.19,-.24-i*.07,-.70)],.018,'shoe',knee)
        legs.append(leg)
    hearts=empty('CTRL Hearts',parent=root)
    for i,(x,z,s) in enumerate([(-1.35,4.9,.12),(1.24,5.2,.14),(.7,6.45,.09)]):
        points=[]
        for n in range(48):
            t=n/48*math.tau
            points.append((x+s*16*math.sin(t)**3/16,-.40,
                           z+s*(13*math.cos(t)-5*math.cos(2*t)-2*math.cos(3*t)-math.cos(4*t))/16))
        panel('Little heart '+str(i),points,.07,'peach',hearts,.025)
    gift=empty('CTRL Voucher',(0,-.90,2.78),root)
    box('Reward card',(0,0,0),(1.34,.09,.77),.10,'paper',gift)
    line('Reward card fold',[(.32,-.06,-.27),(.32,-.06,.27)],.012,'sage_dark',gift)
    oval('Reward card seal',(-.23,-.065,0),(.15,.025,.15),'sage',gift)
    line('Reward card check',[(-.29,-.10,0),(-.24,-.10,-.05),(-.16,-.10,.06)],.016,'leaf',gift)
    for sign in [-1,1]:
        oval('Holding hand '+str(sign),(sign*.66,-.05,-.05),(.12,.13,.15),'skin',gift)
    envelope=empty('CTRL Envelope',(0,-.96,3.05),root)
    box('Envelope / cream paper',(0,0,0),(1.38,.11,.89),.075,'paper',envelope)
    line('Envelope / folded flap',[(-.60,-.067,.33),(0,-.083,-.08),(.60,-.067,.33)],.013,'tan',envelope)
    for sign in [-1,1]:
        oval('Envelope holding hand '+str(sign),(sign*.66,-.08,-.10),(.12,.13,.17),'skin',envelope)
    cam_data=bpy.data.cameras.new('Orthographic sprite camera')
    camera=bpy.data.objects.new(cam_data.name,cam_data)
    scene.collection.objects.link(camera)
    camera.location=(6.6,-24,9.4)
    camera.rotation_euler=(Vector((0,0,3.15))-camera.location).to_track_quat('-Z','Y').to_euler()
    cam_data.type='ORTHO'
    cam_data.ortho_scale=7.45
    scene.camera=camera
    light('Large warm window',(-5,-7,10),1050,7,(1,.88,.73))
    light('Soft cream bounce',(5,-3,6),550,6,(1,.96,.86))
    light('Warm rim',(-3,4,8),1000,5,(1,.88,.70))
    light('Low soft fill',(0,-7,2),110,5,(1,.94,.86))
    head.location.z=3.75
    for child in list(head.children): child.location.z-=3.75
    scene.world.color=(.26,.26,.26)
    scene.render.engine='CYCLES'
    scene.cycles.samples=24
    scene.cycles.use_denoising=True
    scene.render.resolution_x=scene.render.resolution_y=512
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'
    scene.render.image_settings.color_mode='RGBA'
    scene.render.film_transparent=True
    scene.render.fps=24
    scene.view_settings.view_transform='AgX'
    scene.view_settings.look='AgX - Medium High Contrast'
    scene.render.image_settings.color_depth='8'
    return scene,root,body,head,arms,legs,eyes,hearts,gift


def pose(rig,clip,index):
    scene,root,body,head,arms,legs,eyes,hearts,gift=rig
    phase=index/24
    t=phase*math.tau
    envelope=math.sin(math.pi*phase)**2
    root.location=(0,0,0)
    root.rotation_euler=(0,0,0)
    body.rotation_euler=(0,0,0)
    head.rotation_euler=(0,0,0)
    head.location=(0,0,3.75)
    hearts.scale=(0,0,0)
    gift.scale=(0,0,0)
    envelope_prop=bpy.data.objects['CTRL Envelope']
    envelope_prop.scale=(0,0,0)
    for eye in eyes: eye.scale.z=.073
    for arm in arms: arm.rotation_euler=(0,0,0)
    forearms=[bpy.data.objects['CTRL Forearm '+side] for side in ['L','R']]
    for arm in forearms: arm.rotation_euler=(0,0,0)
    for leg in legs:
        leg.rotation_euler=(0,0,0)
        leg.location.z=2.04
    for side in ['L','R']: bpy.data.objects['CTRL Knee '+side].rotation_euler=(0,0,0)
    if clip=='walk':
        root.location.z=.035*(1-math.cos(t*2))
        body.rotation_euler.z=.035*math.sin(t)
        head.rotation_euler.z=-.012*math.sin(t)
        for n,leg in enumerate(legs):
            leg.rotation_euler.x=.29*math.sin(t+n*math.pi)
            leg.location.z+=.07*max(0,math.cos(t+n*math.pi))
            arms[n].rotation_euler.x=-.28*math.sin(t+n*math.pi)
    if clip in ('wave','point','ready','reassure'):
        arms[1].rotation_euler.y=-1.8*envelope if clip=='wave' else -.95*envelope
        arms[1].rotation_euler.x=-.25*envelope
        forearms[1].rotation_euler.y=-.8*envelope if clip=='wave' else -.15*envelope
        forearms[1].rotation_euler.z=.22*math.sin(t*3)*envelope
        head.rotation_euler.y=-.03*envelope
    if clip in ('cheer','wiggle'):
        root.location.z=.22*math.sin(t*1.5)**2*envelope
        body.rotation_euler.y=.035*math.sin(t*2)*envelope
        for n,arm in enumerate(arms):
            arm.rotation_euler.y=(1 if n==0 else -1)*1.9*envelope
        for eye in eyes: eye.scale.z=.073*(1-.65*envelope)
    if clip in ('wait','idle'):
        head.rotation_euler.z=.02*math.sin(t)
        if index in (16,17):
            for eye in eyes: eye.scale.z=.009
    if clip=='love':
        hearts.scale=(envelope,)*3
        head.rotation_euler.y=.04*math.sin(t)*envelope
        arms[0].rotation_euler.y=.5*envelope
        arms[1].rotation_euler.y=-.5*envelope
        eyes[1].scale.z=.073*(1-.85*envelope)
    if clip=='gift':
        gift.scale=(envelope,)*3
        for arm in arms: arm.rotation_euler.x=-.7*envelope
        for arm in forearms: arm.rotation_euler.x=-1.0*envelope
        head.rotation_euler.x=.025*envelope
    if clip=='letter':
        envelope_prop.scale=(1,1,1)
        for arm in arms: arm.rotation_euler.x=-.8
        for arm in forearms: arm.rotation_euler.x=-1.2
    if clip=='sit':
        root.location.z=-.72
        for n,leg in enumerate(legs):
            leg.rotation_euler.x=-1.25
            leg.rotation_euler.z=(-1 if n==0 else 1)*.13
            bpy.data.objects['CTRL Knee '+('L' if n==0 else 'R')].rotation_euler.x=1.25
            arms[n].rotation_euler.x=-.42
            forearms[n].rotation_euler.x=-.55
    if clip=='peek':
        for n,arm in enumerate(arms):
            sign=-1 if n==0 else 1
            shoulder=Vector((sign*.74,0,3.38))
            elbow=Vector((sign*.99,-.53,3.80))
            hand=Vector((sign*.55,-1.02,4.43))
            turn=Vector((sign*.20,0,-.70)).rotation_difference(elbow-shoulder)
            arm.rotation_euler=Quaternion().slerp(turn,envelope).to_euler()
            local_target=turn.inverted()@(hand-elbow)
            bend=Vector((sign*.12,-.04,-.77)).rotation_difference(local_target)
            forearms[n].rotation_euler=Quaternion().slerp(bend,envelope).to_euler()
        head.rotation_euler.y=.05*envelope
        eyes[1].scale.z=.073*(1-.8*envelope)


def bake(rig):
    scene=rig[0]
    controls=[obj for obj in scene.objects if obj.name.startswith('CTRL ') or obj.name.startswith('Eye ')]
    for ci,clip in enumerate(CLIPS):
        start=ci*24+1
        scene.timeline_markers.new(clip,frame=start)
        for index in range(24):
            pose(rig,clip,index)
            for obj in controls:
                for prop in ('location','rotation_euler','scale'):
                    obj.keyframe_insert(data_path=prop,frame=start+index)
    scene.frame_end=len(CLIPS)*24
    scene.frame_set(1)


if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True)
    rig=build()
    bake(rig)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'stepsy-cozy-companion.blend'),compress=True)
    rig[0].render.filepath=str(OUT/'rest-preview.png')
    bpy.ops.render.render(write_still=True)
