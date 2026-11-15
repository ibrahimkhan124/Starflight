# Provenance and distribution terms

Aether is a noncommercial Swift graphics experiment. This repository, including
adapted material, is distributed under CC BY-NC-SA 4.0; see [LICENSE](LICENSE).
This is not an MIT-licensed toolkit. Preserve this notice and the licence when
sharing adaptations. No commercial-use or App Store distribution clearance is claimed.

## Portals adaptation

Credit: **Portals — Ethan Mollick / emollick/ai-portals**.
Snapshot: `210133f4e718acb7b461f2a40c90661a40a2397f`.
Original: [terrain/material.js](https://github.com/emollick/ai-portals/blob/210133f4e718acb7b461f2a40c90661a40a2397f/src/kit/terrain/material.js).
Original licence: [CC BY-NC-SA 4.0](https://github.com/emollick/ai-portals/blob/210133f4e718acb7b461f2a40c90661a40a2397f/LICENSE).

| Aether component | Origin and changes |
|---|---|
| `TerrainSurface.weights` and `aetherWeights` | Adapted `FRAG_TERRAIN` rock/snow transitions: normal-Y rock exposure, macro perturbation and altitude/slope snow overlay. Removed mid/fine texture edge perturbations. Normalized final ground/rock/snow weights; new validated Swift inputs and explicit float4 ABI. |
| `TerrainSurfaceRecipe` defaults | Rock/snow slope defaults, snow blend and roughness values informed by `makeTerrainMaterial` and `FRAG_ROUGH`; new colours and narrower scope. |
| `aetherSurface` | Newly authored small composition around adapted masks; integer-lattice value detail/gradient and warped sinusoidal strata bands replace Portals textures, cellular kit and geology table. Not a translation of its full material. |
| Core validation, Metal diagnostic runner, demo meshes/camera/lighting, tests | Newly authored for Aether. No Three.js, Portals world meshes/textures, Portals RNG/hash functions, GLSL noise helpers or art copied. SeededRandom uses the separately verified SplitMix64 recurrence; see THIRD-PARTY-NOTICES.md. |
| `docs/assessment` | Original Phase 1 assessment, copied unchanged from Lifecycle commit `88c04236c4110930029b652ebedb19425fb5aacb`. Historical proposals and limits; current implementation status is in the root README. |

New implementation changes dated 2026-11-13: Swift CPU reference, MSL adaptation,
original fixtures and diagnostic host. The full Portals licence is included
verbatim. Upstream third-party code with unresolved provenance is excluded.

Engineering assessment only: licence boundaries and distribution packaging still
need review before any public toolkit/game release. See the Phase 1 licensing
assessment for the source audit and unresolved issues.

## Native world milestone (2026-11-14)

TerrainGrid, ValueNoise, FractalHeightField, TerrainScatter, RockArch,
AtmosphereRecipe and the AppKit/MetalKit host are newly authored Aether work.
Alpine Dawn, Ember Gorge and Jade Highlands are original compositions, not
copies of particular Portals worlds. Their meshes and screenshots are generated
by this repository. No external art or textures are used. The new surface detail
field replaces the initial periodic wave fixture; the Portals-derived mask
provenance and repository terms remain in force.

## Hall of Light (2026-11-14)

Reference inspected at the same pinned Portals commit above:
[src/parts/million-mirrors.js](https://github.com/emollick/ai-portals/blob/210133f4e718acb7b461f2a40c90661a40a2397f/src/parts/million-mirrors.js) and
[src/worlds/million-mirrors.js](https://github.com/emollick/ai-portals/blob/210133f4e718acb7b461f2a40c90661a40a2397f/src/worlds/million-mirrors.js).
Credit Ethan Mollick / Portals for the mirror-hall concept and the shared
analytical-room, tilted-facet, coloured-window and chandelier reflection strategy.
Aether's Architecture.swift, OpticalMaterial.swift, Optics.metal, Bloom.metal
and HallScene.swift are newly authored Swift/MSL implementations, with different
geometry, patterns and layout; no line-for-line GLSL translation or source assets.
Treat this inspiration/adaptation conservatively under the repository's existing
CC BY-NC-SA 4.0 terms. No Three.js code, fauna, fonts, textures, noise helpers or
other transitively imported Portals dependencies are bundled. No new external
runtime dependencies. Standard Schlick/filmic formulae are newly expressed here;
no third-party implementation is copied. This does not resolve the broader
upstream provenance questions recorded in the licensing assessment.

## Starflight Canyon of Light study (2026-11-15)

Starflight's optional Tatooine canyon study was informed by Portals
`src/worlds/canyon-of-light.js`, `src/parts/canyon-of-light.js`, and the core,
sky and effect kit contracts at the same snapshot above. Credit Ethan Mollick /
Portals. Shared world-space sandstone bedding, derivative filtering and hero
anchors are newly expressed in Swift/Metal for RealityKit; the arch geometry is
Aether's existing original RockArch approximation. This is not a translation of
the complete self-lit shader, sculpted mesh, sandfalls or fauna. See
`Docs/Portals/CanyonStudy.md` for the dependency map and explicit scope. Preserve
these adaptation credits under the existing CC BY-NC-SA 4.0 terms.


The second Tatooine study additionally references `rockDisp` in the same
`src/parts/canyon-of-light.js` snapshot and the prepared veil/time-uniform design
in `src/kit/fx.js`. Starflight's bounded Swift deformation, normal reconstruction
and Metal dust composition are native adaptations, not a Three.js runtime port.
They remain covered by the existing Portals attribution and adaptation terms.


Native canyon blend: references `src/worlds/the-desert-opens.js`, its soaring
fauna composition and `src/kit/fauna/birds.js` (phase-offset travel, gliding and
wingbeats), plus the existing `src/kit/fx.js` dust-funnel study at Portals snapshot
210133f4e718acb7b461f2a40c90661a40a2397f. New Swift bounded paths, entity animation
and Aether lathe composition retain the same adaptation attribution/terms.
`walking-dune.js` and `canyon-of-three-airs.js` were assessed and rejected for
this region; no claim is made that those worlds have been implemented.

Mirage Basin adapts the six-Hz quantised voxel-motion design from
`src/parts/walking-dune.js` / its world and the three moving coloured interfaces
from `src/worlds/canyon-of-three-airs.js` / its part, at the same Portals snapshot.
Native prepared mesh snapshots, sphere/column collision, clock integration and
soft alpha materials are newly authored host implementations under the existing
adaptation terms. These are bounded feature interpretations, not full world ports.

Natural wildlife/canyon follow-up: land-fauna terrain-following, staggered gait
and grazing concepts studied in `src/kit/fauna/land.js` at the same Portals
snapshot. New native bantha/deer/tauntaun approximations share host-generated
round meshes and Aether curved mouldings; the tree-shaped canyon mask and
clearance-driven rising sand batches are app-owned implementations. Mirage
Basin is no longer active in normal gameplay at the player's request.
