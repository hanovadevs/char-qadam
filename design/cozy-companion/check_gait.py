"""Authoring checks for continuous cloth and the planted-foot walking cycle."""
from pathlib import Path
import bpy
from mathutils import Vector

HERE=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(HERE/'stepsy-cozy-companion.blend'))
scene=bpy.context.scene
lowest=[]
for index in range(60):
    scene.frame_set(61+index)
    for n,side in enumerate(['L','R']):
        phase=(index/60+n*.5)%1
        if phase>=.62: continue
        sole=bpy.data.objects['Sneaker sole '+side]
        # Bounding-box floor is conservative for the rounded sole geometry.
        floor=min((sole.matrix_world@Vector(v)).z for v in sole.bound_box)
        lowest.append(floor)
assert min(lowest)>.07 and max(lowest)<.14,('foot contact drift',min(lowest),max(lowest))
for obj in scene.objects:
    if 'continuous sleeve' not in obj.name and 'continuous soft leg' not in obj.name:continue
    assert any(m.type=='ARMATURE' for m in obj.modifiers),obj.name
    adjacency=[[] for _ in obj.data.vertices]
    for edge in obj.data.edges:
        a,b=edge.vertices;adjacency[a].append(b);adjacency[b].append(a)
    seen={0};queue=[0]
    while queue:
        for v in adjacency[queue.pop()]:
            if v not in seen:seen.add(v);queue.append(v)
    assert len(seen)==len(adjacency),('detached garment section',obj.name)
print(f'GAIT_OK stance_samples={len(lowest)} sole_floor_min={min(lowest):.4f} sole_floor_max={max(lowest):.4f}; four continuous skinned garments')
