"""Render baked clips to transparent 256px masters. Optional -- walk for first review."""
import bpy
import json
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
CLIPS=['rest','walk','wave','point','cheer','ready','wait','reassure','idle','wiggle','love','gift','peek']
selected=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else CLIPS
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'design/stepsy-companion/stepsy-companion.blend'))
scene=bpy.data.scenes['Stepsy companion / editable 2D rig']; bpy.context.window.scene=scene
for clip in selected:
    directory=ROOT/'design/stepsy-companion/renders'/clip; directory.mkdir(parents=True,exist_ok=True)
    count=1 if clip=='rest' else 24
    for index in range(count):
        scene.frame_set(CLIPS.index(clip)*24+1+index)
        scene.render.filepath=str(directory/f'{index:02}.png')
        bpy.ops.render.render(write_still=True)
print('Rendered clips:',selected)
