# Canyon of Light → Tatooine: dependency map and first native study

Source inspected: Ethan Mollick / emollick/ai-portals,
commit 210133f4e718acb7b461f2a40c90661a40a2397f. The local analysis checkout is
`/tmp/starflight-ai-portals-review`; Starflight does not depend on that path.
Adapted concepts remain attributed under CC BY-NC-SA 4.0; see the bundled
Aether/Portals notices. No Three.js runtime or external artwork is bundled.

## World / parts / kit map

| Source | Technique studied | Native disposition |
|---|---|---|
| `src/worlds/canyon-of-light.js` | Continuous sandstone across walls, ground and hero; route clearance; static rock and drifting dust | Same world-space material on Tatooine ground and the new arch; existing free-flight terrain retained |
| `src/parts/canyon-of-light.js` | Hero anchors, open fly-through, stepped normals/bounds preparation, bedding at several scales, pixel-footprint filtering | `TatooineCanyon` anchors/contact and bounded Aether mesh; derivative-filtered bedding in PlanetShaders.metal |
| `src/kit/core.js` | Seeded noise, domain warp, bounded interpolation and route sampling | Existing seeded PlanetExploration terrain and Aether geometry; no duplicate JavaScript RNG implementation |
| `src/kit/sky.js` (`makeSky`, `makeLightRig`) | Match sky, sun and ground-bounce palette; normalize lighting direction | Existing ScenicMaterials / PlanetLighting remain the native shared sky/light system; no camera-follow light rig copied |
| `src/kit/fx.js` (`makeDustDevil`) | Prepared particles and funnel shells, animation by time uniforms | Prepared shader-animated sandfall/ground-dust veils; full funnels/debris deferred pending device overdraw budgets |
| `src/kit/fauna.js`, `flora.js`, `water.js` | World imports for birds, vegetation and waterfall/sand effects | Native gliders added in the later canyon blend; flora/water remain deferred |

## Current implementation

- `Rendering/AetherWorldDetails.swift`: TatooineCanyon supplies one cached arch,
  origin, passage anchor and conservative geometric contact. The original Aether
  RockArch is a sculpted elliptical approximation, not a reproduction of Portals'
  eroded slab/rubble hero. The second pass uses 3,104 triangles and one stone entity.
- `Rendering/PlanetShaders.metal`: world-anchored warped sandstone beds and
  finer laminae, filtered by fragment footprint to limit shimmer. Native PBR
  lighting remains active; the Portals self-lit HDR shader and baked bounce pools
  are not copied into RealityKit.
- `Rendering/ScenicMaterials.swift`: shared adaptation used for ground and arch.
- `Rendering/PlanetSurfaceRenderer.swift`: prepares the arch before visibility.
- `Flight/PlanetExploration.swift`: opening waypoint and stone collision checks.
- Settings → Sound & graphics → Tatooine canyon study; restart after changes.
  `-portalsCanyonEnabled NO` restores the original scene/material/landmark.

To find it: Space free roam → Flight tools → Enter Tatooine, then follow the
fourth survey landmark, Sunlit stone arch. The checkpoint sits within the open
passage. No world geometry is streamed or replaced during flight.

The original terrain height field, contact triangles and existing settlements
remain intact. Fully sculpted fluted canyon walls, volumetric dust shafts and
baked light pools are later work; this first study must not be described as the
complete Portals world or equal visual quality. Other planets are unchanged.

## Validation and pictures

Tests compare the switch, waypoint, actual rendered arch vertices against its
collision envelope, opening clearance, triangle budget, unchanged world contact
and original/adapted moving approaches in the running game. The debug-only
`STARFLIGHT_CANYON_CAPTURE` fixture puts the ship on a repeatable approach using
normal flight afterwards. It does not change ordinary player spawning.

Physical phone timing, graphics quality and thermal validation remain required;
compilation and simulator screenshots do not certify those budgets.

2026-11-15 verification: five focused unit tests and the original/adapted flight
UI comparison passed. After softening the sandstone palette, both canyon unit
tests and the complete comparison were rerun successfully. Final Mac Catalyst
and generic iOS Debug builds passed; the iOS compile used signing disabled and
is not an installable device build. No physical-device performance claim is made.

Actual simulator captures:
- [Adapted arch approach](../../Screenshots/CanyonStudy-20261115/adapted-approach.png)
- [Adapted canyon flight](../../Screenshots/CanyonStudy-20261115/adapted-flight.png)
- [Original approach comparison](../../Screenshots/CanyonStudy-20261115/original-approach.png)
- [Original canyon flight](../../Screenshots/CanyonStudy-20261115/original-flight.png)


## Second pass: sculpted stone and bounded sand effects

The second pass studies the part's `rockDisp` (swells, vertical fluting and
bedding ledges) and the fx kit's prepared, shader-animated veil approach.
Starflight deforms an Aether RockArch once, recomputes area-weighted normals and
welds the repeated radial seam. The result has 3,104 triangles; it remains a
bounded arch approximation rather than Portals' full eroded canyon hero. Contact
uses an enlarged conservative elliptical envelope, tested against every rendered
vertex. The central passage and existing ground triangle field remain clear.

Sand effects use one extra batched entity with at most twelve triangles: two
crossed sandfall veils and four ground-dust veils. Reduced detail uses six
triangles. Animation reads RealityKit's time uniform, with soft opacity at the
edges. There is no per-grain entity, per-frame mesh creation, new real light or
camera-following effect. The veils have no physical collision. Shader failure
omits the effect rather than rendering opaque fallback panels. This is a native
adaptation of preparation/animation techniques, not the kit's full volumetric
funnel, debris or particle-system implementation. Other planets remain outside
this pass.

Second-pass validation (2026-11-15): Aether's Swift package test run passed;
Starflight's two canyon unit checks and the paired original/enhanced flight UI
check passed. The final sandfall placement/material changes passed another two
unit checks and the enhanced flight UI check. Final Mac Catalyst and signed
iphoneos Debug builds passed, including the existing embedded widget validation.
The main navigation labels use a 9-point ScaledMetric, retaining Dynamic Type and
existing button hit areas. No physical device timing or appearance check was run.
The simulator logs existing RealityKit shader pipeline warnings; screenshots
verify the stone geometry, but do not establish physical-device dust quality.

Final captures: [sculpted arch approach](../../Screenshots/CanyonSculpted-20261115/arch-approach.png)
and [continuing flight](../../Screenshots/CanyonSculpted-20261115/canyon-flight.png).

The later animated world blend and its good/bad design assessment are documented
in [CanyonBlend.md](CanyonBlend.md).
