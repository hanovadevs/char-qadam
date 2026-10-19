# Stepsy companion: editable first implementation

The working name is Pip. This is an original flat cutout interpretation of the supplied concept, with an editable Blender 5.2.1 LTS scene. The official Stepsy logo is separate and unchanged.

## Rebuild and export

From the repository root, use the installed Blender executable with:

```
blender --background --factory-startup --python design/stepsy-companion/build_character.py
blender --background --factory-startup --python design/stepsy-companion/render_animations.py -- walk rest
```

Inspect the walk, then render the remaining clips (omit `-- walk rest` to render all). Run `python design/stepsy-companion/pack_assets.py` with Pillow installed to pack runtime atlases and update the contact sheet/manifest. The backend's local Python environment includes Pillow. Scripts create a new scene; they do not open or replace an unrelated Blender file. All source and asset paths are relative to the repo.

## Rig and palette

The fixed orthographic camera sees XY cutouts from +Z. Named root/body/arms/feet/eyes/mouth controls, shoe and palm shapes, separate contours, brows and cheeks remain editable. A single baked timeline has labeled 24-frame clip ranges. Clip names, frame counts and source frame paths are in `mobile/assets/companion/manifest.json`.

Mint body `#B8EBD9`, shade `#92D5C5`, contour `#07565A`, ink `#102B32`, creamy shoe `#FFFDF2`, teal sole `#087F72`, peach cheeks `#FFBE9B`. Shapes use emission materials for flat unlit color, with transparent PNG output and a Standard view transform.

Master canvas: 256×256. Shared foot anchor: approximately (128,223), no trimming/crop offset. All rendered bounds are checked by the packer so limbs do not touch the canvas edge. Walk alternates a stationary-height stance with a lifted return; 24 samples cover a full cycle, excluding the duplicate endpoint. These are decorative animation frames, not sensor data.

## Runtime budget and behavior

Runtime frames are 128×128, packed six columns by four rows per clip. Flutter explicitly renders one frame with `Canvas.drawImageRect`; Blender is not shipped as a runtime dependency. One decoded atlas costs **1,572,864 bytes** (1.5 MiB), regardless of PNG compression. Static fallback: 65,536 decoded bytes at 128×128. The app lazily decodes a clip per playing slot and releases it on replacement, disposal or hiding. There is no all-states texture, perpetual walk loop, audio, AI service or health-data transmission.

Home displays persisted sensor steps live; point earnings remain server-confirmed. A positive live delta starts a walking cycle, and subsequent steps extend its bounded movement window without restarting or decoding the atlas again. After three seconds without another step, the companion rests. Background syncing does not replace walking with a wait clip. Initial loading, downward corrections, day/goal changes and first opening do not replay a whole day's walk. Goal-completion IDs are stored per account/day/goal on this phone. System reduced motion, hidden tabs and the in-app animation control stop playback and use the static fallback. Tips occupy their own layout space and can be dismissed or disabled.

This is the first integration, not final character art approval. Dedicated front/three-quarter/left/right turnarounds, stronger pose differentiation and further expression/stance polish remain part of the blueprint's next art review. On-device texture memory/frame timing and recorded phone walkthroughs must be measured separately; a successful Flutter render is not a phone benchmark.
