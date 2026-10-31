"""Render selected named clips, or all 13, from the editable master.

Use -- walk wave cheer gift for an initial movement review. -- review renders just
the midpoint of each clip into review/ without changing the runtime source frames.
"""
import sys
from pathlib import Path
import bpy
FRAMES=60

OUT=Path(__file__).resolve().parent
CLIPS=['rest','walk','wave','point','cheer','ready','wait','reassure','idle','wiggle','love','gift','peek']
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
review='review' in args
selected=[x for x in args if x in CLIPS] or CLIPS
bpy.ops.wm.open_mainfile(filepath=str(OUT/'stepsy-cozy-companion.blend'))
scene=bpy.context.scene
scene.render.resolution_x=scene.render.resolution_y=384
scene.cycles.samples=12
scene.render.use_persistent_data=True
scene.render.threads_mode='FIXED'
scene.render.threads=6
for clip in selected:
    directory=OUT/('review' if review else 'renders')/clip
    directory.mkdir(parents=True,exist_ok=True)
    indices=[FRAMES//2] if review else ([0] if clip=='rest' else range(FRAMES))
    for index in indices:
        scene.frame_set(CLIPS.index(clip)*FRAMES+1+index)
        scene.render.filepath=str(directory/f'{index:02}.png')
        bpy.ops.render.render(write_still=True)
        print(f'COZY_RENDER {clip} {index+1}/{FRAMES}',flush=True)
print('Rendered clips:',selected)
