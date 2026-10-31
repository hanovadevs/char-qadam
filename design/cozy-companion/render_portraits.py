"""Large static poses for the illustrated headers; animation stays at 192px."""
import sys
from pathlib import Path
import bpy

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE))
from build_character import pose

bpy.ops.wm.open_mainfile(filepath=str(HERE/'stepsy-cozy-companion.blend'))
scene=bpy.context.scene
obj=bpy.data.objects
rig=(scene,obj['CTRL Root'],obj['CTRL Body'],obj['CTRL Head'],
     [obj['CTRL Arm '+s] for s in ['L','R']],
     [obj['CTRL Leg '+s] for s in ['L','R']],
     [obj['Eye '+s] for s in ['L','R']],obj['CTRL Hearts'],obj['CTRL Voucher'])
for item in scene.objects:
    if item.animation_data: item.animation_data_clear()
scene.render.resolution_x=scene.render.resolution_y=512
scene.cycles.samples=24
scene.render.use_persistent_data=True
out=ROOT/'mobile/assets/companion/portraits'
out.mkdir(parents=True,exist_ok=True)
for clip,index in [('rest',0),('walk',6),('wave',12),('peek',12),('letter',12),('sit',12)]:
    pose(rig,clip,index)
    scene.render.filepath=str(out/f'{clip}.png')
    bpy.ops.render.render(write_still=True)
