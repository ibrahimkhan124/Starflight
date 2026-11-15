# Native canyon world blend and design review

Source snapshot: emollick/ai-portals 210133f4e718acb7b461f2a40c90661a40a2397f.
Aether stays pinned at 2a5f844f316228771fbb713017de21c50f6e172d.

## Composition

| Layer | Source studied | Starflight adaptation |
|---|---|---|
| World | Canyon of Light | Existing sandstone canyon, sculpted arch, clear survey passage and sandfall |
| World | The Desert Opens | Soaring wildlife as a scale cue, with long glides and brief wingbeats; no hyperlapse camera/day-cycle copied |
| Part / kit | canyon-of-light part, fx.js makeDustDevil | Two bounded rotating funnel shells, prepared geometry, a shared noise map and soft edges |
| Kit | fauna/birds.js, exported by fauna.js | Phase-offset orbital flight, heading tangent, bank and independent wing movement; five ambient gliders, two on reduced detail |
| Core / native adapter | Aether ArchitecturalGeometry.lathe + existing terrain triangle query | Reusable 160-triangle funnel mesh, ground-anchored at preparation; shared bird body and wing meshes |

All additions are part of the existing Tatooine canyon switch and prepared before
the region is shown. No imported JavaScript runtime, new texture downloads or
flight-physics changes are introduced. Source techniques are adapted, not full
world/kit implementations.

## What works well

- Sandstone, warm dust and dark gliding silhouettes share a dry desert setting.
- Wildlife and rotating wind forms communicate scale and movement without
  moving the ground underneath the player.
- Birds stay more than 300 metres to the side of the central passage. Their
  orbit ceiling is prepared above the sampled ground, rather than attached to
  the camera. Funnels are also outside that passage.
- Bird and funnel transforms use the existing world clock. Meshes and entities
  are created once, not spawned every frame. The existing sandfall shader uses
  RealityKit rendering time, so its subtle flow can continue in a paused background.
- Aether supplies neutral geometry; RealityKit retains camera/material/scene
  ownership. The app keeps its original terrain and contact map.

## What was rejected, and why

- Walking Dune's six-ticks-per-second hopping voxel ground would conflict with
  Starflight's continuous sandstone and make stable collision/clearance harder.
  Its moving-dune reveal and caravan were studied but not implemented here.
- Canyon of Three Airs' three saturated gas surfaces are visually strong, but
  would obscure nearby rock and weaken Tatooine's existing identity. Those
  coloured layers are not blended into this flight region.
- The Desert Opens' six-days-in-forty-seconds time lapse and camera-driven
  scripted events do not suit a player who may stop, reverse or revisit a place.
- Thousands of flock instances, dust grains, translucent shells or real lights
  could add overdraw/CPU costs. This prototype deliberately uses a small fixed
  population. The source's full shader-driven instanced fauna is not ported.

## Limits / resource budget

Full detail adds two 160-triangle funnel models and five birds (each one shared
12-triangle body plus two 2-triangle wings). Reduced detail uses one funnel and
two birds. These are arithmetic geometry budgets, not measured frame timings.
Each full-detail bird has one root and three model children; no shadow casting
or collision is added for the ambient wildlife or dust. Bird bodies are simple
silhouettes; they will not stand up to close inspection as detailed creatures.
Funnels use a native unlit transparent material and one shared 128 x 256 RGBA
noise texture (128 KiB before any platform mip/compression overhead), avoiding
custom surface shader dependencies for these new objects. A continuous U=0/U=1
seam wraps that texture around each lathe. Rotating transparent shells approximate
wind; this is not fluid simulation or physically
accurate volumetric scattering. Existing simulator shader warnings mean device
appearance/thermal/frame-time validation remains a separate gate.

## Verification — 2026-11-15

- Aether Swift package tests passed at the pinned revision.
- Four focused unit checks passed: arch/contact budget, feature-switch scene,
  bounded life/ground clearance/UV seam, and actual prepared scene animation.
- The complete launch → Space Free Roam → Flight tools → Enter Tatooine →
  moving arch passage UI check passed with the native wind material.
- Mac Catalyst and signed generic-iphoneos Debug builds passed. No physical
  device installation, sustained timing or thermal test was performed.
- An earlier custom shader funnel was too faint to assess in the simulator.
  The final version uses the native alpha texture; wind shells and glider
  silhouettes are visible in the final recording. This is still stylised,
  low-detail ambient scenery, not full Portals fauna or volumetric fluid effects.

[Approach](../../Screenshots/CanyonBlend-20261115/approach.png),
[continuing flight](../../Screenshots/CanyonBlend-20261115/flight.png),
[actual simulator motion clip](../../Screenshots/CanyonBlend-20261115/canyon-motion.mp4).
The preceding stone-only capture at
[the same scripted approach](../../Screenshots/CanyonSculpted-20261115/arch-approach.png)
provides the before view: the stone, flight fixture and lighting are unchanged.

## Follow-up: previously excluded features

At the user's request, the voxel dune and coloured atmosphere ideas are now
implemented in an isolated area, not discarded. See [MirageBasin.md](MirageBasin.md)
for the prepared snapshot/collision design, direct visit control, limitations
and verification. The earlier rejection section records the original design
tradeoff; it no longer describes the full implemented feature set.

Mirage Basin has since been retired at the player's request. Current additions are
[natural branching canyons, ground animals and low-flight sand](WildlifeAndCanyon.md).
The glider flock is now ten at full detail or four at reduced detail, around twice
its original scale; previous budgets above describe the earlier implementation.
