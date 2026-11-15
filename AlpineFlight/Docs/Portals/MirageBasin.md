# Mirage Basin — the previously excluded world features

Sources studied: emollick/ai-portals snapshot
210133f4e718acb7b461f2a40c90661a40a2397f, `src/worlds/walking-dune.js`,
`src/parts/walking-dune.js`, `src/worlds/canyon-of-three-airs.js` and its part.
Aether remains pinned at 2a5f844f316228771fbb713017de21c50f6e172d.

## What is now added

- A separate voxel dune mesa on Tatooine at X=4800, Z=-5200, away from the
  original sandstone arch and flight corridor. Sixteen by sixteen solid columns
  form a crescent ridge, with quantised four-metre hopping tops at six ticks/sec.
- Eight prepared repeating snapshots animate the living dune. Three model
  entities swap prepared mesh resources; there is no runtime mesh generation,
  partial region loading or continuously rebuilt collision mesh.
- Three translucent rose, amber and teal interfaces drift vertically and rotate
  gently above/through the dune, inspired by Three Airs. These are visible,
  non-solid atmosphere sheets, not liquids or an actual gas simulation.
- Flight Tools → Visit Mirage Basin takes the player to a level, clear approach.
  It also replaces the final Tatooine survey destination. The six-stop survey
  count and original arrival/arch remain intact.

The old reasons for rejecting these features still apply to the main route.
Isolating the voxel/coloured biome lets the player deliberately explore the
stranger style while the existing canyon remains readable.

## Shared physics/rendering contract

`Flight/MirageBasin.swift` owns the column top/bottom rules, phase clock, mesh
snapshots, per-column sphere/box contact, swept crossing check and surface height.
The columns extend below the sampled original terrain, avoiding floating bases.
Static obstacle generation leaves a stable clearing around this footprint even
when the feature switch is disabled, so cached obstacle bins cannot go stale.

`HyperspaceManager.surfaceTime` advances only with surface-flight simulation and
resets on entering a planet. Renderer snapshots, gas motion, aircraft collision,
HUD clearance, warning audio, crash camera and projectile surface hits use that
same clock. Repeating a time value freezes this basin's animation. No flight
forces, steering settings, throttles or calibration calculations are changed.

`Rendering/MirageBasinRenderer.swift` prepares eight snapshots (3,072 triangles
per visible snapshot), plus three shared-plane atmosphere models. The neutral
MeshData → RealityKit adapter uploads the meshes. Eight full CPU attribute/index
sets would be about 1.9 MiB before native resource overhead; transient MeshData
arrays are released after upload. Native resources have additional overhead.
These arithmetic budgets are not a measured FPS/thermal guarantee.

## Scope and tradeoffs

This is a native, bounded interpretation of the source tick/voxel and coloured
interface techniques. It is not the complete Walking Dune world: there is no
voxel caravan, buried city reveal, sand yacht or camera-driven cinematic. The
dune pulses/hops in a repeating bounded sequence rather than migrating forever.
Three Airs is represented by soft moving sheets, not its full curled gas-wave
hero, fluid density model or full-screen post processing. The original fourteen
ink voxel renderer and camera-driven six-day flower time lapse are not ported.

The new region belongs to Settings → Tatooine canyon study and can also be
excluded at launch with `-portalsMirageEnabled NO` (restart required). Other
planets and the main canyon remain unchanged apart from the final survey target.

## Verification — 2026-11-15

The initial run passed seven focused unit checks and the Flight Tools visit /
14-second crossing UI check. Review showed that its 230-metre-high arrival gave
a poor view of the new region. The final approach is 125 metres above the basin
foundation, with the original-ground approach sampled for foundation clearance
and a stable obstacle clearing along the arrival corridor.

The final four basin checks passed, covering every visible snapshot vertex's
contact, geometry budgets, swept flight/clearance along the whole approach,
actual HyperspaceManager dune impact and clock reset, and repeat-time animation
freeze. The full visit/crossing UI check passed again at the lower approach.
The earlier four arch/wildlife regression checks also passed. Aether's package
tests, Mac Catalyst build and signed generic-iphoneos Debug build passed. The
last build also identifies the local area as Mirage Basin in the navigation
status while preserving the active survey goal.

[Approach screenshot](../../Screenshots/MirageBasin-20261115/approach.png),
[exit screenshot](../../Screenshots/MirageBasin-20261115/exit.png).
These are simulator captures. Physical-device appearance, sustained memory/frame
time and thermal checks remain unverified. No physical installation is claimed.
