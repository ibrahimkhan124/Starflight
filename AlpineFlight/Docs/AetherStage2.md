# Stage two — Hoth terrain pilot

The second migration stage runs one existing world through Aether's TerrainGrid.
Hoth retains the same height recipe, 160×160 cells, 24 km bounds, arrival,
landmarks, scenery, lighting, controls and collision behaviour. Aether Reach and
all other worlds keep their previous paths.

**Settings → Sound & graphics → Aether Hoth terrain pilot** controls this path.
Restart Starflight after changing it; an in-flight scene never swaps its ground.
Diagnostic launches use `-aetherHothTerrainEnabled NO` (legacy) or `YES` (pilot).
The switch defaults on. No package revision or deployment-target changes were
needed beyond stage one.

## Exact contact, shared edges

Aether and Starflight use different diagonals within each terrain square. The
adapter reflects the height field's X coordinate, then reflects positions and
normals back and reverses winding. This preserves the original visible triangles
and interpolation rather than quietly changing collision beneath an aircraft.
Aether's triangle query is compared with Starflight's original ground query at
thousands of interior positions and at all domain corners/edges.

One complete grid supplies area-weighted smooth normals before it is split into
16 fixed 40×40-cell sections. Border vertices and normals come from the same
source entries, so adjacent sections agree exactly. Each section includes 140 m
skirts below its edges. The whole section and its skirts share one material and
one RealityKit entity. UVs retain the existing world-XZ texture scale.

This is fixed prepared terrain, not adaptive LOD or streamed terrain. There are
no coarse/fine transitions. Preparation builds all GPU sections before publishing
any of them; on failure the complete original renderer remains the fallback.
CPU grid and mesh data are immutable and cached once for reuse. Generation and
upload happen during scene preparation, not per flight update.

## Budget and trade-offs

- Original top surface: 102,400 duplicated vertices, 51,200 triangles.
- Pilot including skirts: 37,136 vertices, 56,320 triangles, 16 terrain entities.
- About 64% fewer submitted terrain vertices, with 10% more triangles for skirts
  and more terrain draw groups than the six legacy material batches.
- Scene objects and texture detail still follow existing reduced-detail settings.

These counts are geometry budgets, not a claim of higher frame rate. Physical
phone/tablet frame time, memory and thermal measurements remain a release gate.

## Validation

`AetherHothPilotTests` verifies contact equivalence, counterclockwise winding,
unit normals, exact shared borders, skirt depth, bounded counts, the renderer
switch and stable entity identities during flight. Existing route, scout,
spatial-collision and scenery-budget checks run alongside the stage-one checks.
`testHothAetherTerrainPilotComparison` captures both paths with the same ship,
arrival, camera, lighting and weather, then exercises flight and return to orbit.

Source: `AlpineFlight/Rendering/AetherHothTerrain.swift`. The existing renderer
keeps ownership of all non-terrain Hoth scenery. Package provenance and licence
notices remain in `Docs/ThirdParty/Aether/`.

## Validation — 14 November 2026

Sixteen focused unit checks passed, including the three stage-two tests, the
stage-one integration tests, aircraft route/scout/spatial-collision checks,
scenery budgets and existing Solar System/excluded-world regressions. The full
Hoth scene remained within the existing budget: 116,570 triangles/41 entities in
reduced detail and 126,000 triangles/54 entities in full detail.

Debug builds passed for iPadOS Simulator, arm64 Mac Catalyst and generic iOS
device. The device build disabled signing and was not a physical-device run.

The iPad Simulator UI comparison also passed the complete legacy/pilot flow:
entry into Hoth, moving flight, and return to orbit. Actual screenshots and a
short flight clip are saved under `Screenshots/AetherStage2-20261114`. The updated
signature-verified Mac application was installed; the simulator was shut down
after checking. Physical-device frame-rate/thermal testing remains pending.
