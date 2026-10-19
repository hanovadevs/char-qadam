"""Blender 5.2 cutout rig. Run with --background --factory-startup --python.

Only creates a new Stepsy scene; never opens or overwrites another project.
Render masters with render_animations.py after reviewing the walk contact sheet.
"""
import bpy
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PALETTE = {'ink':'07565A', 'body':'B8EBD9', 'shade':'92D5C5', 'light':'D9F5E9',
           'shoe':'FFFDF2', 'sole':'087F72', 'eye':'102B32', 'cheek':'FFBE9B', 'tongue':'F8A790'}
CLIPS = ['rest', 'walk', 'wave', 'point', 'cheer', 'ready', 'wait', 'reassure', 'idle']

def material(key):
    value = PALETTE.get(key, key)
    color = [int(value[i:i+2], 16)/255 for i in (0,2,4)]
    linear = [c/12.92 if c <= .04045 else ((c+.055)/1.055)**2.4 for c in color]
    mat = bpy.data.materials.new('Pip / '+key)
    mat.diffuse_color = (*linear,1)
    mat.use_nodes = True
    nodes=mat.node_tree.nodes; nodes.clear()
    out=nodes.new('ShaderNodeOutputMaterial'); emission=nodes.new('ShaderNodeEmission')
    emission.inputs['Color'].default_value=(*linear,1)
    mat.node_tree.links.new(emission.outputs[0],out.inputs['Surface'])
    return mat

def empty(name, parent=None, x=0,y=0,z=0):
    obj=bpy.data.objects.new(name,None); bpy.context.scene.collection.objects.link(obj)
    obj.parent=parent; obj.location=(x,y,z); obj.empty_display_size=.12
    return obj

def shape(name, points, color, z, parent, outline=True, smooth=True):
    curve=bpy.data.curves.new(name,'CURVE'); curve.dimensions='2D'; curve.fill_mode='BOTH'; curve.resolution_u=16
    spline=curve.splines.new('BEZIER'); spline.bezier_points.add(len(points)-1)
    for point,co in zip(spline.bezier_points,points):
        point.co=(*co,0); point.handle_left_type=point.handle_right_type='AUTO' if smooth else 'VECTOR'
    spline.use_cyclic_u=True
    obj=bpy.data.objects.new(name,curve); bpy.context.scene.collection.objects.link(obj)
    obj.parent=parent; obj.location.z=z; obj.data.materials.append(MATS[color])
    if outline:
        edge=curve.copy(); edge.name=name+' contour'; edge.dimensions='3D'; edge.bevel_depth=.025
        edge.bevel_resolution=3; edge.resolution_u=16; edge.materials.clear(); edge.materials.append(MATS['ink'])
        border=bpy.data.objects.new(name+' contour',edge); bpy.context.scene.collection.objects.link(border)
        border.parent=obj; border.location.z=.005
    return obj

def oval(name,x,y,rx,ry,color,z,parent,outline=False):
    return shape(name,[(x+rx*math.cos(i*math.tau/12),y+ry*math.sin(i*math.tau/12)) for i in range(12)],color,z,parent,outline)

def stroke(name,points,color,width,z,parent):
    data=bpy.data.curves.new(name,'CURVE'); data.dimensions='3D'; data.bevel_depth=width; data.bevel_resolution=4
    spline=data.splines.new('BEZIER'); spline.bezier_points.add(len(points)-1)
    for p,co in zip(spline.bezier_points,points):
        p.co=(*co,0); p.handle_left_type=p.handle_right_type='AUTO'
    obj=bpy.data.objects.new(name,data); bpy.context.scene.collection.objects.link(obj)
    obj.parent=parent; obj.location.z=z; obj.data.materials.append(MATS[color]); return obj

def build():
    global MATS
    scene=bpy.data.scenes.new('Stepsy companion / editable 2D rig'); bpy.context.window.scene=scene
    MATS={key:material(key) for key in PALETTE}
    root=empty('CTRL Root'); body=empty('CTRL Body',root)
    arms=[]; feet=[]
    for side,x in [('L',-.62),('R',.62)]:
        foot=empty('CTRL Foot '+side,root,x=x*.65,y=-1.22,z=.05)
        shape('Shoe '+side,[(-.31,-.16),(-.34,.04),(-.19,.20),(.03,.19),(.32,.04),(.36,-.12),(.12,-.20)],'shoe',.05,foot)
        shape('Sole '+side,[(-.32,-.11),(-.08,-.15),(.33,-.09),(.33,-.17),(.01,-.23),(-.28,-.20)],'sole',.07,foot,False)
        stroke('Lace '+side,[(-.09,.1),(.06,.08),(.14,.11)],'ink',.013,.08,foot)
        leg=stroke('Leg '+side,[(x*.55,-.6),(x*.65,-1.13)],'eye',.095,-.02,root)
        feet.append((foot,leg,x))
        arm=empty('CTRL Arm '+side,body,x=x,y=.22,z=.08 if side=='R' else -.02)
        sign=1 if side=='R' else -1
        shape('Arm '+side,[(0,.05),(sign*.35,-.07),(sign*.61,-.31),(sign*.49,-.53),(sign*.25,-.46),(sign*.08,-.22)],'body',0,arm)
        stroke('Palm '+side,[(sign*.43,-.29),(sign*.48,-.35)],'ink',.012,.03,arm)
        arms.append(arm)
    shape('Body',[(-.81,-.58),(-.92,.02),(-.77,.72),(-.38,1.14),(.2,1.2),(.67,.78),(.94,.07),(.75,-.62),(.07,-.83)],'body',.12,body)
    shape('Body flat accent',[(-.84,.13),(-.62,-.42),(-.08,-.64),(.65,-.46),(.7,-.64),(.07,-.79),(-.62,-.65)],'shade',.14,body,False)
    shape('Head tuft',[(-.36,1.04),(-.45,1.35),(-.71,1.44),(-.72,1.59),(-.42,1.62),(-.07,1.47),(.08,1.17)],'body',.15,body)
    eyes=[]
    for side,x in [('L',-.32),('R',.39)]:
        eye=empty('CTRL Eye '+side,body,x=x,y=.45,z=.18)
        oval('Eye '+side,0,0,.14,.22,'eye',0,eye)
        oval('Eye shine '+side,-.045,.075,.044,.065,'shoe',.01,eye)
        stroke('Brow '+side,[(x-.1,.83),(x,.89),(x+.09,.84)],'eye',.028,.2,body)
        oval('Cheek '+side,x*1.65,.03,.11,.09,'cheek',.18,body)
        eyes.append(eye)
    mouth=empty('CTRL Mouth',body,z=.2)
    shape('Happy mouth',[(-.12,.05),(.07,.0),(.24,.08),(.15,-.16),(.01,-.18)],'eye',0,mouth,False)
    shape('Tongue',[(-.005,-.1),(.075,-.08),(.15,-.1),(.09,-.16),(.025,-.16)],'tongue',.01,mouth,False)
    cam_data=bpy.data.cameras.new('Orthographic export camera'); cam=bpy.data.objects.new('Orthographic export camera',cam_data)
    scene.collection.objects.link(cam); cam.location=(0,.04,10); cam_data.type='ORTHO'; cam_data.ortho_scale=4.0; scene.camera=cam
    engines={e.identifier for e in scene.render.bl_rna.properties['engine'].enum_items}
    scene.render.engine='BLENDER_EEVEE' if 'BLENDER_EEVEE' in engines else 'BLENDER_EEVEE_NEXT'
    scene.render.resolution_x=scene.render.resolution_y=256; scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'; scene.render.image_settings.color_mode='RGBA'; scene.render.film_transparent=True
    scene.view_settings.view_transform='Standard'; scene.render.fps=24
    return scene,root,body,arms,feet,eyes

def pose(rig,clip,index):
    scene,root,body,arms,feet,eyes=rig; phase=index/24; t=phase*math.tau
    root.scale=(1,1,1); body.location.y=0; body.rotation_euler.z=0
    for eye in eyes: eye.scale.y=.12 if index in (18,19) and clip in ('idle','wait') else 1
    mouth=bpy.data.objects['CTRL Mouth']; mouth.scale=(1,1,1)
    if clip in ('cheer','ready'): mouth.scale=(1.16,1.2,1)
    if clip in ('reassure','rest'): mouth.scale=(.85,.75,1)
    if clip=='wait': mouth.scale=(.6,.5,1)
    for n,eye in enumerate(eyes):
        if clip=='cheer': eye.scale.y=.65
        if clip=='reassure': eye.scale.y=.85
        brow=bpy.data.objects['Brow '+('L' if n==0 else 'R')]
        brow.location.y=.06 if clip in ('cheer','ready') or (clip=='wait' and n==0) else 0
    for arm in arms: arm.rotation_euler.z=0
    for n,(foot,leg,x) in enumerate(feet):
        p=(phase+n*.5)%1; foot.location.x=x*.65; foot.location.y=-1.22; foot.rotation_euler.z=0
        if clip=='walk':
            if p<.6: offset=.29-.58*p/.6; lift=0
            else: q=(p-.6)/.4; offset=-.29+.58*q; lift=.22*math.sin(q*math.pi)
            foot.location.x+=offset; foot.location.y+=lift
            arms[n].rotation_euler.z=.27*math.sin(t+n*math.pi)
            body.location.y=.035*(1-math.cos(t*2))
        if clip in ('cheer','ready'):
            lift=.15*math.sin(math.pi*phase)**2
            foot.location.y+=lift; body.location.y=lift
        points=leg.data.splines[0].bezier_points
        points[1].co.x=foot.location.x; points[1].co.y=foot.location.y+.1
    envelope=math.sin(math.pi*phase)**2
    if clip=='wave': arms[1].rotation_euler.z=1.6*envelope+.14*math.sin(t*3)*envelope
    if clip in ('point','ready'): arms[1].rotation_euler.z=1.12*envelope
    if clip=='cheer': arms[0].rotation_euler.z=-1.9*envelope; arms[1].rotation_euler.z=1.9*envelope
    if clip=='reassure': body.rotation_euler.z=.045*math.sin(t); arms[1].rotation_euler.z=.5*envelope
    if clip=='wait': body.rotation_euler.z=.025*math.sin(t); eyes[1].scale.y=.8

def bake(rig):
    scene=rig[0]
    for ci,clip in enumerate(CLIPS):
        start=ci*24+1; scene.timeline_markers.new(clip,frame=start)
        for index in range(24):
            pose(rig,clip,index); frame=start+index
            for obj in scene.objects:
                if obj.name.startswith('CTRL'):
                    for prop in ('location','rotation_euler','scale'): obj.keyframe_insert(data_path=prop,frame=frame)
                if obj.name.startswith('Leg '):
                    for p in obj.data.splines[0].bezier_points: p.keyframe_insert(data_path='co',frame=frame)
                if obj.name.startswith('Brow '): obj.keyframe_insert(data_path='location',frame=frame)
    scene.frame_end=len(CLIPS)*24

if __name__=='__main__':
    rig=build(); bake(rig)
    rig[0].frame_set(25)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'design/stepsy-companion/stepsy-companion.blend'),compress=True)
