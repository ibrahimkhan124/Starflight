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
- The canyon gliders use 3.5–3.9 model scale, spread across eight flocks along
  the canyon. Full detail has 24 gliders; reduced detail has eight.

Ground herds are distributed along eight valley locations, plus three canyon
branch locations on Tatooine. Safe placement can skip an obstructed location. Each
location has two animals (one on reduced detail): 22 / 11 on Tatooine and
16 / 8 on Endor and Hoth. They use 2.4 adult / 1.9 juvenile
model scale, shared prepared meshes, articulated gait, head/graze motion and tail sways.
All sites and roaming loops are checked against slope and scenery. Runtime
positions sample the actual terrain triangles; animal transforms update at up
to thirty Hz. Ground animals fade between 1,000 and 1,500 metres horizontally;
farther animals stop animating. Birds fade between 2,200 and 3,000 metres. Shared
placement results are cached; no terrain searches run each frame for hidden herds.
Bodies share a smooth-normal 168-triangle round mesh. Curved horns
use Aether ArchitecturalGeometry.moulding. There is no per-frame mesh generation,
new AI combat, breeding or animal/aircraft collision. These are decorative,
procedural approximations rather than imported high-detail Blender creatures.

The motion/terrain-following design is informed by Portals' `src/kit/fauna/land.js`
at snapshot 210133f4e718acb7b461f2a40c90661a40a2397f. Host models and movement are
new Swift/RealityKit composition. Existing Portals/Aether notices are retained.

## Sand wash below 150 metres

Tatooine has a prepared sand-puff emitter beneath the aircraft. Its intensity
fades from zero at 150 metres of actual ground clearance to full at 15 metres.
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


## Wildlife visibility update — 2026-11-16

Six focused checks passed: enlarged species roam safely on actual terrain triangles,
each planet's ground wildlife spans over 12 km, eight bird flocks span over 14 km,
all sampled bird orbits retain terrain clearance, prepared birds animate in full
and reduced detail, ground animals hide/reappear with viewer distance, and sand
activates below 150 m (including 100 m) and disables above it. Branch connections
and independent inspection-camera behaviour remain covered.

Both UI checks passed: the normal sculpted-canyon flight and the immediately
accessible wildlife/canyon shortcuts. The first combined run used an obsolete
camera location in the bird animation check; the corrected focused rerun passed
all six checks. Simulator captures show the larger bantha and wildlife alongside
the normal flight route. Existing simulator custom-material pipeline warnings
remain; these wildlife bodies and sand use native materials.

Mac Catalyst and signed generic iOS Debug builds passed. Aether package tests
passed at the existing pinned revision. The installed Mac application was updated.
Physical-device frame time, memory, touch handling and appearance are unmeasured.

Pictures: [larger bantha](../../Screenshots/WildlifeSpread-20261116/larger-bantha.png),
[wildlife along a normal flight](../../Screenshots/WildlifeSpread-20261116/wildlife-along-flight-route.png),
[canyon branches](../../Screenshots/WildlifeSpread-20261116/canyon-branches.png).


## Other planet skies — 2026-11-16

The shared prepared bird renderer now covers Endor, Hoth and Coruscant as well as
Tatooine. Endor has rust-coloured forest gliders, Hoth pale blue ice gliders, and
Coruscant muted violet rooftop gliders. Each uses eight distributed flock homes,
24 birds at full detail or eight at reduced detail. Existing large deer/tauntaun
herds stay in place; Coruscant receives airborne wildlife rather than ground
herds in the traffic lanes.

Non-desert flock homes are prepared from terrain triangle heights plus nearby
scenery tops, leaving 110 m above the highest sampled canopy or rooftop. Bounded
orbits, staggered wingbeats and the existing 2.2–3 km visibility fade are shared
across planets. No new meshes or terrain searches are created during animation.
Coruscant's Wildlife Lookout now stays on Coruscant and frames a rooftop flock.
These are original stylised gliders, not claims about canon animal species.


### Lookout corrections and validation

The visual pass exposed a reduced-detail mismatch on Endor. Lookout placement now
selects the herd from the active detail mode, and a 32-sample terrain sightline
keeps intervening hills below the inspection gaze. The corrected reduced-detail
Endor capture visibly includes its deer; Hoth's tauntaun inspection was also
checked. Coruscant uses the current rendered bird position and follows that bird
while the existing inspection camera is active. Moving off or switching cameras
still releases inspection normally.

Eight focused checks passed, including all three added planet flock routes,
canopy/building collision margins, full/reduced scene counts, animation, distance
culling, and lookout sightlines on the three ground-wildlife planets. The
three-planet lookout flow and the dedicated Endor reduced-detail flow passed.
Mac Catalyst and signed generic iOS Debug builds passed. Physical-device frame
time, memory and appearance remain unmeasured; simulator captures are visual
checks, not device-performance evidence.


The final Coruscant follow-camera UI check passed and its screenshot visibly
shows the glider above the skyline after the achievement message has cleared.
The updated Mac app is installed; no physical iPhone/iPad installation is claimed.

Pictures: [Endor deer](../../Screenshots/OtherPlanetWildlife-20261116/endor-deer-lookout.png),
[Hoth tauntaun](../../Screenshots/OtherPlanetWildlife-20261116/hoth-tauntaun-lookout.png),
[Coruscant glider](../../Screenshots/OtherPlanetWildlife-20261116/coruscant-rooftop-glider.png).
