# Stage four — selective fictional-world expansion

The roadmap calls for scene-by-scene migration, not a simultaneous replacement
of the fictional planets, authored story meshes and Solar System landscapes.
This stage expands the tested home-planet terrain family to Tatooine and Endor.
Coruscant, story levels and Solar System surfaces retain their existing paths.
Aether Reach keeps its stage-three composition.

## Independent adoption

Settings → Sound & graphics offers separate Aether Tatooine terrain, Aether
Endor terrain and Aether Hoth terrain pilot switches. Defaults are enabled;
restart Starflight after changing them. Diagnostic launch keys are
`aetherTatooineTerrainEnabled`, `aetherEndorTerrainEnabled` and
`aetherHothTerrainEnabled`, accepting YES/NO as well as stored Bool values.

To visit these surface worlds: Space free roam → Flight tools → Enter Tatooine
or Enter Endor. These switches apply to planet expeditions, not similarly named
Flight Planner levels that use authored Blender terrain.

## Shared implementation, distinct recipes

AetherHomeTerrain reuses the stage-two triangle-preserving adapter and accepts
each planet's existing PlanetExploration.vertexHeight recipe. Separate lazy
immutable caches avoid mixing terrain between worlds. The AetherHothTerrain
facade remains for the existing stage-two fixtures and call sites.

Each region retains its 160×160 cells and 24 km bounds. Reflecting X adapts
Aether's diagonal to the game's contact convention. Sixteen prepared sections
share source normals and positions and include below-ground skirts. Every GPU
section must prepare successfully before the new ground is published; otherwise
the complete original terrain remains the fallback. Nothing streams or changes
terrain detail while the player flies.

Only the terrain branch changes. Tatooine's buildings/twin suns and Endor's
forest, all landmarks, obstacle geometry, skyports and inhabitants remain under
the existing renderer. Materials keep the original sand/moss/snow families,
world texture scale and native lighting. Flight physics, controls, jobs,
checkpoints, authored levels and saves are unchanged.

## Budgets and limits

Each pilot ground has 37,136 vertices and 56,320 triangles including skirts,
versus 102,400 vertices/51,200 triangles in the original duplicated ground.
There are 16 terrain entities instead of up to six material batches. Fewer
vertices do not by themselves prove faster frame time: draw groups and CPU cache
memory also cost resources. Separate per-world switches allow rollback without
changing other worlds. Physical-device memory, loading and thermal measurements
remain part of the next release decision.

The story-tile and Solar System families are deliberately not migrated in this
stage: they use different authored geometry and contact conventions. A broader
rollout requires separate adapters and its own visual/gameplay/device evidence.
No adaptive LOD, full Aether atmosphere or new renderer is implied.

## Checks

AetherSelectiveMigrationTests compares thousands of contact positions and every
landmark with each original recipe, verifies cached geometry, independent flags,
remaining scenery and stable entities over flight updates. Hoth seam/winding
checks and existing route, collision, scenery-budget and Solar System regression
checks run alongside these. testSelectiveAetherWorldFlights performs legacy and
pilot entry, moving flight, capture and return for both worlds.

The Aether dependency revision and third-party notices remain unchanged from
stages one through three. Implementation lives in AetherHothTerrain.swift
(shared CPU adapter), AetherPlanetRenderer.swift (RealityKit conversion), and
PlanetSurfaceRenderer.swift (per-world selection and scenery composition).

## Validation — 14 November 2026

- Simulator build-for-testing, Mac Catalyst build and generic iOS device build
  passed. The device build used signing disabled; no physical install is implied.
- All 22 selected unit/regression tests passed with zero failures.
- The UI comparison passed four actual entry/flight/return cycles: original and
  Aether terrain on Tatooine and Endor. Each run moved the throttle and captured
  the scene before and during flight. These are short smoke flights, not full
  expedition completions or frame-rate benchmarks.
- Full-detail scenery budgets: Tatooine 206,332 triangles / 63 entities; Endor
  321,038 / 57. Reduced-detail budgets: Tatooine 144,659 / 47; Endor 157,307 / 44.
  Existing Hoth and Coruscant budget checks also passed.
- Both Aether terrain captures were visually inspected for complete ground,
  retained scenery and visible ship/HUD. Original-path comparison captures are
  included beside them. Media lives in `Screenshots/AetherStage4-20261114/`;
  the two MP4s are approximately 5.77 seconds of recorded simulator flight each.
- The updated Mac app is installed at
  `/Users/ibrahimkhan/Applications/Starflight.app`; restart it to load this build.
  The test simulator was shut down after capture.

Physical iPhone/iPad memory, thermal behavior, loading times and sustained frame
rates remain unmeasured. The migration preserves geometry/contact and prepares
complete regions; it does not claim a visual redesign or proven speed increase.
