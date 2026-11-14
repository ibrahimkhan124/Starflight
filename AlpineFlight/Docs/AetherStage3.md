# Stage three — protected scenery and a native surface study

This stage stays on Aether Reach. Existing planets, Hoth's stage-two pilot,
flight physics, camera and controls are unchanged.

## Deterministic placement

ProceduralPlacement is added at the existing pinned Aether revision. A host-owned
SurfaceQuery wraps TerrainGrid.sample and rejects protected spaces before
TerrainScatter accepts a candidate. These are the wide central valley, arrival,
arch terrace/approach and region edge. Aether Reach has no city plots, racing
tracks or mission checkpoints; those systems are not being migrated here.

The request is bounded to 420 rocks, 9,000 attempts, 210 m spacing, surface
normal-Y ≥ 0.68 and altitude 180–1,850 m. Results expose attempts and underfill;
no retry-until-full loop exists. Rock positions come from the rendered triangles,
not a second continuous height query. A fixed seed reproduces placements.

All rocks are uploaded as one prepared mesh, with fewer than 60,000 triangles.
The entire expedition has four direct scenery entities: terrain, arch, sky and
rocks. Collisions use conservative ellipsoid contact from the same seeded layout,
with a broad-phase rejection per rock. This is not exact triangle-mesh contact.

Settings → Sound & graphics → Aether Reach surface & scenery controls the new
scenery and material study. Restart after changing it. The active value is frozen
per app session, keeping visible rocks and collision in agreement throughout a
flight. CPU placement is cached with the immutable prepared region. There is no
scatter or mesh generation in a flight update.

## RealityKit material adapter

The enhanced terrain uses a real CustomMaterial entry point,
`starflight_aether_surface`, compiled into the app's existing Metal library.
It consumes the reflectance texture prepared with Aether TerrainSurface weights
and adds app-owned derivative-filtered grain, tangent-space normal detail and
roughness. RealityKit supplies lighting. Albedo is not tone-mapped or lit during
preparation; the sRGB map is decoded by the renderer.

This is a focused CPU-map-to-CustomMaterial adapter, not a port of Aether's
`aetherSurface` fragment function, a generic seven-float4 recipe binding, or a
replacement renderer. ProceduralMetal is not imported. Full Aether GPU material
parity and atmosphere remain later work. Attribution and CC BY-NC-SA notices are
preserved under Docs/ThirdParty/Aether.

## Comparisons and tests

`-aetherSurfaceEnabled NO` selects the prepared CPU colour material; `YES`
selects CustomMaterial. Both runs retain identical geometry, rocks, camera,
lighting, weather and collision. `-aetherWorldDetailEnabled NO` disables this
stage's rocks and custom surface on the next app launch.

AetherWorldDetailTests checks repeatability, grounding, protected spaces, bounded
attempts, hit/clear passes, custom shader binding, one-batch scenery, triangle
budget and outward winding. Earlier integration, Hoth, route, scenery-budget and
Solar System regressions run alongside them. The existing Aether flight UI test
captures both material paths and exercises moving flight and return to orbit.

Physical-device frame time, memory and thermal measurements remain pending;
compile checks and Simulator captures do not establish those results.

The comparison flag decoder now accepts both stored Bool values and Xcode launch
argument strings such as YES/NO. A regression test covers this. The custom shader
also applies RealityKit's colour-texture V convention explicitly so the prepared
surface map stays aligned with the original material.

## Validation — 14 November 2026

Nineteen focused unit checks passed, including the corrected argument decoder,
material types, collision and placement checks, Hoth joins and earlier route/
Solar System regressions. The repeated Simulator comparison passed original and
custom material entry, moving flight and return. Captures under
`Screenshots/AetherStage3-20261114` are from that corrected comparison.
Simulator, arm64 Mac Catalyst and generic iOS device builds passed. The latter
was unsigned compile validation, not a device installation. The final verified
Mac app was installed locally. Physical-device performance remains unmeasured.
