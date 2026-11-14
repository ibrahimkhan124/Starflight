# Aether Reach — first integration pilot

Aether Reach is an optional fictional destination, reached through **Space free
roam → Hyperspace → Galaxies → Explore Aether Reach**. Return to orbit uses the
existing Solar System transit hub. It is deliberately separate from the real
Solar System planet list and all existing fictional planet surfaces.

Settings → Sound & graphics → Aether experimental planet enables new trips.
Turning it off leaves an expedition already in flight intact. Preparation must
finish before the entry button becomes enabled. Generation failures are shown
beside the button. Restarting the app retries an interrupted application session.

## Dependency and ownership

Xcode resolves `https://github.com/zuhayrkhan/Aether.git` at exact revision
`2a5f844f316228771fbb713017de21c50f6e172d`. The shared workspace
`Package.resolved` is committed. Only ProceduralCore, ProceduralGeometry,
ProceduralTerrain and ProceduralSurface are linked. There is no `import Aether`,
no copied library implementation, and no replacement game engine.

The website's Phase 01 is the neutral-geometry bridge; this pilot also includes
one small terrain destination to make that bridge playable, as requested. It
uses current public APIs rather than the historical assessment sketches.

- `Rendering/AetherPlanet.swift`: app-owned seeded height recipe, one immutable
  TerrainGrid, RockArch, and a baked CPU TerrainSurface colour study.
- `Rendering/AetherPlanetRenderer.swift`: MeshData → MeshResource conversion,
  UVs, PBR material, prepared sky and three bounded RealityKit entities.
- `UniverseRenderer`: asynchronous preparation and retained scene reuse.
- `SolarLandscape`: Aether's actual grid triangles supply ground heights.
- `UniverseFlight`: existing five-second travel, zero-speed arrival and return.

Aether generates CPU assets once on a detached preparation task. The owner checks
cancellation before publishing the RealityKit scene; shared immutable CPU results
are retained for reuse. No generation or texture baking runs per flight tick.
The fixed 192×192 terrain has 37,249 vertices and 73,728 triangles. The colour map
is 512×512 RGBA with mipmaps; a single capped arch adds under 1,000 triangles.
Existing Performance Mode remains available. This pilot does not implement
adaptive terrain LOD, streaming, tile seams or erosion.

## Geometry, materials and collision

Coordinates are metres, Y-up, right-handed, with the library's original winding
and smooth normals. The terrain adapter maps world XZ into UVs. CPU surface
weights blend linear ground/rock/snow reflectance, encode it to an sRGB colour
map once, and leave illumination to RealityKit. Lighting is not baked into the
map. This is a CPU material adapter, not an integration of Aether's direct-Metal
surface or atmosphere functions.

The continuous height recipe is used to construct the grid. Physics queries
TerrainGrid.sample on the rendered triangles, including the outer edge. The arch
has conservative rounded contact around its centreline; the central opening is
clear. It is not exact per-triangle swept collision for the arch. Existing flight
physics, controls, camera, checkpoints, ships and planets are unchanged.

## Reproducible comparisons

Launch with `-aetherPlanetEnabled YES -aetherSurfaceEnabled NO` for the baseline
material, or `-aetherSurfaceEnabled YES` for the Aether colour study. Both use the
same terrain, arch, camera, light and collision. These are diagnostic launch
arguments; the player-facing switch controls whether the destination is offered.

`AetherPlanetIntegrationTests` checks rendered-grid contact, safe entry and
return, disabled travel, arch contacts/opening, mesh counts, UVs and normals.
`FlightUITests.testAetherReachEntryFlightAndReturnWithBaseline` exercises the
actual menu, both material states, moving flight and return to orbit.

Physical iPhone/iPad frame-time, memory and thermal measurements are still a
separate release gate. A successful Simulator or Mac build is not that evidence.

## Attribution

Aether, by zuhayrkhan, is a noncommercial experiment under CC BY-NC-SA 4.0.
Portals / Ethan Mollick is credited for the adapted terrain-mask concepts.
The licence, provenance and third-party notices are preserved verbatim under
`Docs/ThirdParty/Aether/`. This private home-project pilot makes no App Store or
commercial-distribution clearance claim.

## Validation — 14 November 2026

- Aether's `swift test` suites passed at the pinned local revision.
- Nine focused Starflight unit checks passed, including all three new Aether
  checks and the existing Solar System/excluded-world regression checks.
- The UI comparison passed entry, moving flight and return for both baseline and
  enhanced materials on the iPad Air 13-inch (M4), iPadOS 26.5 Simulator.
- Debug builds passed for that Simulator, arm64 Mac Catalyst and generic iOS
  device. The generic device build disabled signing; it is compile evidence, not
  an installation or physical-device performance result.
- The updated, signature-verified Mac application was installed locally.
- Actual captures are in `Screenshots/AetherPhase1-20261114`: entry, baseline,
  enhanced arrival, moving flight and a short flight video. The simulator was
  shut down after the checks.
