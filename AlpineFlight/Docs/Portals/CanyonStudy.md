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
| `src/kit/fx.js` (`makeDustDevil`) | Prepared particles and funnel shells, animation by time uniforms | Studied; dedicated dust funnels/shaft effects deferred pending device overdraw budgets |
| `src/kit/fauna.js`, `flora.js`, `water.js` | World imports for birds, vegetation and waterfall/sand effects | Dependency identified; not imported wholesale and not implemented in this first study |

## Current implementation

- `Rendering/AetherWorldDetails.swift`: TatooineCanyon supplies one cached arch,
  origin, passage anchor and conservative geometric contact. The original Aether
  RockArch is an elliptical approximation, not a reproduction of Portals' eroded
  slab/rubble hero. It adds fewer than 1,000 triangles and one model entity.
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
remain intact. Fully sculpted fluted canyon walls, dust shafts, sandfalls and
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
