# Your own ships and levels

Open the **My creations** tools button beside Take flight on the main menu.
Built-in aircraft and routes remain available in the existing planner.

## Ships: Blender, AI, or another modeller

1. Create the model in Blender or another tool. An AI model can be a starting
   point; open it in Blender to inspect and repair the geometry.
2. Keep the nose facing **−Z** and the top facing **+Y** in the exported USDZ.
   Blender exports must convert the authoring axes to these game axes. The
   existing scripts author with a −Y nose and rotate/convert during export.
3. Close hull gaps, recalculate outward normals, and give thin wings or panels
   actual thickness. Keep the cockpit canopy opaque unless you have modelled
   an interior. Apply object scale before export.
4. Use simple materials and packed textures. Aim for around 10,000–30,000
   triangles and modest texture sizes for older iPads; this is an authoring
   guideline, not a measured performance guarantee. Avoid hundreds of tiny
   separate objects. The importer limits files to 20 MB and 1,500 entities.
5. Export a **USDZ** archive with materials and textures. A `.blend` source file
   is for editing; the game imports the exported `.usdz`.
6. In My creations, choose a **handling preset**, then **Choose USDZ model**.
   The preset supplies speed, lift, guns, and collision dimensions. The new
   model keeps its proportions and is centred/fitted inside that envelope.
7. Choose the imported entry in **My ships**, close the sheet, inspect it in
   the hangar, and Take flight. Choosing a built-in aircraft clears the custom
   model selection. No Xcode rebuild is needed for imported models.

Imported files are copied into app storage; the original is not modified.
The library persists across app launches. Choose your creation again when
starting a new session; active custom selections are currently session-only.

## Levels: a terrain recipe first

In My creations, enter a name and adjust the seed, mountain height, valley width,
bend strength, and saddle height. **Save and select level** adds an independent
entry under My levels. It uses the beginner mountain route’s length, palette,
and checkpoint pattern with your new landscape.

Rendering, route placement, and collision use the same terrain generator.
The complete region prepares before Take flight becomes available. Custom
routes do not write to built-in route scores.

Use the export button beside a saved level to share its JSON recipe, or import
`MountainLevel.json` beside this guide as an example. Supported version 1 values:

| Field | Meaning | Range |
|---|---|---|
| `name` | Library name | 1–48 characters |
| `seed` | Reproducible noise pattern | Unsigned 32-bit integer |
| `mountainScale` | Ridge height multiplier | 0.25–2 |
| `valleyWidth` | Valley width multiplier | 0.7–2 |
| `bends` | Winding frequency multiplier | 0.5–2 |
| `saddles` | Cross-valley hill multiplier | 0–2 |

The importer accepts small JSON recipes under 64 KB. Missing multipliers default
to 1; name and seed are required. Recipes are data, not executable scripts.

This first version does **not** import full Blender level scenes, arbitrary
collision meshes, custom pod circuits, or a new physics system. Those would
need separate route/checkpoint, spawn, and collision authoring.

## Hangar controls

The ship turns slowly until you first drag it. Drag horizontally to orbit and
vertically to change viewing height. The orbit stays outside the ship. Touch,
mouse dragging, and VoiceOver rotation actions are supported; Reduce Motion
disables the automatic turntable animation.

## How the terrain works

The generator computes one height for each horizontal coordinate. It combines
a winding valley centreline, ridges that grow away from that line, seeded noise,
and saddle hills. A seed changes the noise reproducibly. The renderer samples
the height field into low-poly triangles, while checkpoints and collision probes
sample the same region. Changing a recipe rebuilds the whole region before
flight so the ground never reshapes during play.

Useful references: [Blender USDZ export](https://docs.blender.org/manual/en/4.2/files/import_export/usd.html),
[Blender GLB export for a future browser version](https://docs.blender.org/manual/en/5.1/addons/import_export/scene_gltf2.html).
