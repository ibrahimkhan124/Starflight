# Natural canyon branches, wildlife and low-flight sand

## Changes at the player's request

Mirage Basin is retired from gameplay. Its visit button, survey destination,
rendered region and dynamic collision/clearance effects are disabled, including
for saved defaults that previously enabled it. The final Tatooine survey stop
is Sunset basin again; original scenery in the former experimental footprint
is restored. The unused prototype source remains for reference, not a playable
feature. No additional region meshes are allocated for it in normal play.

Tatooine's existing continuous sandstone valley now has a tree-shaped network:
three main forks (Sunrise, Shaded and Redstone) and six smaller tributaries. Child
routes join their parent's curve. Spatially bucketed curve segments provide one
bounded valley-union mask inside the original height recipe. Aether terrain
preparation and collision read that same recipe and triangle diagonal; there are
no separate decorative road meshes or hidden mountain barriers. Natural spires
are excluded from branch floors. The original route and stone arch remain.

## Animals

- Tatooine: shaggy brown banthas with curved horns.
- Endor: forest deer with branching antlers.
- Hoth: tauntauns with long necks, curled horns and tails.
- The canyon gliders are approximately twice their previous size. Full detail
  has ten gliders; reduced detail has four, with staggered wingbeats.

Each ground herd has four animals (two on reduced detail), with shared prepared
meshes, adult/juvenile scales, articulated gait, head/graze motion and tail sways.
All sites and roaming loops are checked against slope and scenery. Runtime
positions sample the actual terrain triangles; animal transforms update at up
to thirty Hz. Bodies share a smooth-normal 168-triangle round mesh. Curved horns
use Aether ArchitecturalGeometry.moulding. There is no per-frame mesh generation,
new AI combat, breeding or animal/aircraft collision. These are decorative,
procedural approximations rather than imported high-detail Blender creatures.

The motion/terrain-following design is informed by Portals' `src/kit/fauna/land.js`
at snapshot 210133f4e718acb7b461f2a40c90661a40a2397f. Host models and movement are
new Swift/RealityKit composition. Existing Portals/Aether notices are retained.

## Sand wash below 70 metres

Tatooine has a prepared sand-puff emitter beneath the aircraft. Its intensity
fades from zero at 70 metres of actual ground clearance to full at 15 metres.
Two reduced-detail or three full-detail batches expand, rise, swirl and fade,
reusing the native soft-mist texture. Native opacity components avoid another
custom transparent shader. All meshes/entities are prepared once. Above the
threshold, or without an active aircraft position, the emitter is disabled.
This is an artistic low-flight effect; it changes no flight forces or terrain.

## Finding the additions

Space Free Roam → Flight Tools → Wildlife lookout visits the current planet's
herd (Tatooine when used from space). It arrives hovering, with zero throttle and a cockpit inspection camera aimed
at the herd while the aircraft stays level. Moving off or switching cameras
releases that inspection view. Large aircraft receive extra clearance and stand-off.
Enter Endor or Hoth first to inspect those animals. Flight Tools → Explore canyon
forks provides an elevated view of the first Tatooine junction. Regular flying
and normal survey routes remain available.


## Verification — 2026-11-15

Eleven initial focused unit checks passed, including shared terrain/contact
geometry, curve connections, branch centre clearance, retirement of Mirage Basin,
herd placement and terrain following, sand's 70-metre threshold and actual scene
animation. The main arch flight and all three planet wildlife lookouts passed
UI checks. A subsequent camera check confirmed that inspection targets do not
pitch the aircraft and release on resuming flight/reset. The final quick-action
UI check passed with Wildlife lookout and Canyon forks both immediately hittable.

The final Mac Catalyst and signed iphoneos Debug builds passed; Aether package
tests passed at the existing pinned revision. Physical-device frame time, memory
and appearance have not been tested for these additions. No physical installation
is claimed. The prototype wildlife and sand remain stylised approximations.

Pictures: [bantha inspection](../../Screenshots/WildlifeAndCanyon-20261115/bantha-lookout.png),
[canyon forks in the chase view](../../Screenshots/WildlifeAndCanyon-20261115/canyon-forks.png),
[larger gliders](../../Screenshots/WildlifeAndCanyon-20261115/larger-gliders.png).
[Endor](../../Screenshots/WildlifeAndCanyon-20261115/endor-deer-check.png) and
[Hoth](../../Screenshots/WildlifeAndCanyon-20261115/hoth-tauntaun-check.png) were
captured during the preceding camera pass; the final inspection now aims the
camera without pitching the aircraft. The canyon shortcut keeps the tested normal
chase view, rather than pointing directly into the ground.
