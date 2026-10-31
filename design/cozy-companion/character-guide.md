# Stepsy’s cozy companion

The active character is a **true editable 3D model rendered into 2D assets**. The user’s 31 October references replace the earlier mint Pip direction. The original cutout source remains in `../stepsy-companion/` for history. The Stepsy logo is retained separately.

The user-supplied [character reference](reference/character.jpeg), [five-screen board](reference/five-screen-reference.png) and [authentication board](reference/authentication-reference.png) are retained as art references. They are not runtime screenshots.

## Editable source

Open [stepsy-cozy-companion.blend](stepsy-cozy-companion.blend) in Blender 5.2.1 LTS. Geometry, materials, lighting, orthographic camera, jacket panels, pockets, buttons, hair silhouette, backpack, sneakers, hands and reward/envelope props are editable. The face uses procedural soft blush rather than an external texture. Named `CTRL` objects control body, head, arms, forearms, thighs, knees and props. Thirteen labeled 60-frame timeline ranges retain the existing app events. This is a stylized reconstruction from a single reference, rather than a recovered original mesh or an assertion of pixel-identical geometry.

The character keeps the oversized brown hair, tiny quiet face, peach skin, sage jacket, cream clothes, tan sneakers and blue-grey backpack from the supplied character image. Additional seated and envelope-holding static poses support Points and authentication.

## Rebuild

Run from the repository root with Blender on PATH:

```powershell
blender --background --factory-startup --python design/cozy-companion/build_character.py
blender --background --factory-startup --python design/cozy-companion/render_portraits.py
blender --background --factory-startup --python design/cozy-companion/render_animations.py
python design/cozy-companion/pack_assets.py
```

The packer needs Pillow. The backend development virtual environment already includes it on the authoring computer. Use a separate art virtual environment elsewhere if preferred. Render outputs and `.blend1` backups are ignored; the scripts, compressed `.blend`, rest render, contact sheet and app assets are versioned. Scripts create or open only this companion’s scene. To review a few midpoint poses before a full render:

```powershell
blender --background --factory-startup --python design/cozy-companion/render_animations.py -- review walk wave cheer gift peek
```

## Runtime

The phone runs no Blender or 3D engine. Twelve 60-frame atlases at **192 × 192** per frame are packed **6 × 10**. Each decoded RGBA atlas occupies **8,847,360 bytes (8.4375 MiB)**; only a currently playing clip is decoded per widget and released when hidden/replaced/disposed. The static fallback occupies 147,456 decoded bytes. Larger static portraits are 512 × 512 and use Flutter’s shared image cache. PNG sizes are recorded separately from decoded memory in `mobile/assets/companion/manifest.json`.

Live sensor deltas still drive walking, independently of server sync. Walking continues while steps arrive and rests after three seconds without a new step. Goal celebration, explicit taps and successful reward purchase retain their existing events. Hidden tabs, system reduced motion and the in-app animation preference stop clip playback. A screen illustration does not represent a measured walk or a successful purchase.

## Soft clothing and movement refinement

Sleeves and trousers are continuous connected meshes with armature skinning through elbows and knees. They replace the original stacked primitive sections. Jacket fronts use curved fabric surfaces, rolled hems and subtle animated fold shape keys. The independent foot controls counter-rotate the shoes during a stride; the walk solver alternates a planted stance with a lifted swing. The character faces along the horizontal foreground trail rather than facing the viewer during the walk.

Reactions play 60 frames over **2.5 seconds** (24 frames/second), with eased entry/exit and a held central pose. Walking plays 60 frames over **1.2 seconds** (50 frames/second), repeats only while live movement is recent, and still rests after three seconds without a new step. The Blender authoring timeline is 24 FPS; the exported manifest records the faster walk playback rate. Static portraits now use the same softened model.

Run `blender --background --factory-startup --python design/cozy-companion/check_gait.py` to check all 60 walk samples. The check verifies four connected skinned garments and 76 stance samples whose conservative sole bounds stay between 0.0948 and 0.0979 in scene units. These are authoring invariants, not phone FPS measurements or medical gait measurements. [Walking preview](walk-preview.gif), [longer wave reaction](reaction-preview.gif) and [six-pose contact sheet](walk-contact-sheet.png) show the revised stride.

The additional atlas memory pays for denser, longer motion. It remains lazy and releases on hiding/replacement. The revised APK was installed without clearing data; the owner accepted the refined model and live walking on the Redmi. Automated playback-log collection timed out, so measured device frame timings remain unavailable.

## Artwork generation

Welcome uses a separate three-quarter stride, [render_welcome.py](render_welcome.py), exported at 640px to `mobile/assets/companion/portraits/welcome.png`. The body turns 48 degrees and the head -15 degrees for a friendlier view on the park path. This uses the existing editable model and leaves the horizontal walking atlas intact. `CozyScene(arrival: true)` composes the crop, scale, wordmark fade and contact shadow.

`mobile/assets/illustrations/cozy-park.png` was generated with the built-in image-generation tool using the supplied authentication board as a **style reference**, then copied into the project. The editable 3D character itself is authored by `build_character.py`, not generated by that image tool. Prompt:

> Use case: illustration-story. Asset type: production background illustration for a Flutter mobile app, NOT a mockup or phone screenshot. Input image is a STYLE REFERENCE only: extract the soft cozy park environment behind the characters. Create one vertical 2:3 illustration of this park, WITHOUT any person, mascot, UI, lettering, logo, phone, border or watermark. Warm ivory/cream sky (#FFF4E4) across upper half, small buttery apricot sun upper right, pale peach distant rolling hills, tiny very subtle cream city silhouettes, gently winding sandy footpath from the lower center into the middle distance, layered rounded sage trees, olive green shrubs and leafy plants framing lower left and right, a few tiny ivory daisies, warm soft light. Muted light green, sage, skin-peach, creme palette exactly like the reference. Soft rounded clay / illustrated paper diorama look with subtle depth and soft gradients, no outlines, no saturated teal, no blue sky, no photorealism. Keep the middle lower path open and clear so a separately rendered character can be placed there. Fill the whole canvas with the illustration.

The bundled Nunito variable font comes from [Google Fonts](https://github.com/google/fonts/tree/main/ofl/nunito); its OFL license is included with the font. UI reference boards guide layout and color, not production balances, dates, merchant partnerships or reward inventory.


### Horizontal trail artwork

`mobile/assets/illustrations/cozy-walking-track.png` was generated with the built-in image-generation tool, using the supplied five-screen board as its style reference. It replaces only the Steps walking backdrop; authentication retains the original park illustration. Prompt:

> Use case: illustration-story. Create ONE landscape 16:9 environment artwork ONLY, no UI, text, mascot, people, phone, lettering or watermark. Style reference: the warm soft rounded illustrated park behind the walking character in the FIRST phone of the supplied board. This is a production background for a character walking SIDEWAYS LEFT TO RIGHT. Critical geometry: a continuous clear gently curved but essentially HORIZONTAL sandy cream walking trail across the ENTIRE lower 25 percent of the canvas, from the left edge to the right edge. Its front edge runs along the canvas bottom. Keep this foreground trail empty, evenly lit and unobstructed at both ends, with no plants intruding over the walking surface. Feet will stand at y=90 percent of the image along this horizontal ground plane. Above it: cozy layered rounded sage bushes and pale olive trees, cream daisies, distant pale peach hills and subtle warm city silhouettes, ivory sky #FEF8EC and a small apricot sun. Soft paper/clay illustration, warm ambient light and feathered shading, muted sage, cream and apricot only. No winding path leading toward the camera, no perspective vanishing track, no steps, no obstacles. The scene must support a walking character positioned anywhere across its width.
