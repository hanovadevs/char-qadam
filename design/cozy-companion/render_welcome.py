"""A welcoming three-quarter stride, independent of the side-view trail cycle."""
import math
import sys
from pathlib import Path
import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from build_character import pose, recover_cloth

bpy.ops.wm.open_mainfile(filepath=str(HERE / 'stepsy-cozy-companion.blend'))
scene = bpy.context.scene
obj = bpy.data.objects
recover_cloth()
for item in scene.objects:
    if item.animation_data:
        item.animation_data_clear()
    if item.type == 'ARMATURE' and item.data.animation_data:
        item.data.animation_data_clear()
    if item.type == 'MESH' and item.data.shape_keys and item.data.shape_keys.animation_data:
        item.data.shape_keys.animation_data_clear()
rig = (scene, obj['CTRL Root'], obj['CTRL Body'], obj['CTRL Head'],
       [obj['CTRL Arm ' + s] for s in ['L', 'R']],
       [obj['CTRL Leg ' + s] for s in ['L', 'R']],
       [obj['Eye ' + s] for s in ['L', 'R']], obj['CTRL Hearts'], obj['CTRL Voucher'])
pose(rig, 'walk', 4)
obj['CTRL Root'].rotation_euler.z = math.radians(48)
obj['CTRL Head'].rotation_euler.z = math.radians(-15)
scene.render.resolution_x = scene.render.resolution_y = 640
scene.cycles.samples = 48
scene.render.filepath = str(HERE.parents[1] / 'mobile/assets/companion/portraits/welcome.png')
bpy.ops.render.render(write_still=True)
