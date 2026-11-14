# Planet rendering

Starflight's planet graphics use Swift, RealityKit and a small set of Metal surface shaders. The implementation combines prepared flight geometry, shared surface textures, a directional sun, cached sky lighting and inexpensive atmospheric effects. This document describes the implementation in the source; it does not certify a build, a test result or a measured frame rate.

The upgraded destinations are Coruscant, Tatooine, Hoth, Endor, Mercury, Venus, Earth, Mars and Jupiter. Saturn, Uranus, Neptune and the Moon retain their existing terrain and rendering paths. The new orbital materials, atmosphere shells and globe mesh detail selection are restricted to Mercury, Venus, Earth, Mars and Jupiter.

## Where each part lives

| File | Responsibility |
| --- | --- |
| `AlpineFlight/Flight/PlanetExploration.swift` | Original terrain heights, arrival points, landmarks, obstacle volumes and spatial collision lookup for the four fictional planets. |
| `AlpineFlight/Flight/UniverseSimulation.swift` | `SolarLandscape`: original Solar System flight geography and the matching ground-contact sampling. |
| `AlpineFlight/Rendering/PlanetSurfaceRenderer.swift` | Prepared fictional-planet terrain, city/forest scenery and weather batches. |
| `AlpineFlight/Rendering/UniverseRenderer.swift` | Orbital artwork loading and Solar System expedition meshes, water, clouds and landmarks. |
| `AlpineFlight/Rendering/ScenicMaterials.swift` | Shared procedural albedo/normal maps, physically based materials and Metal shader bindings. |
| `AlpineFlight/Rendering/PlanetShaders.metal` | Ground detail, water, cloud, orbital globe and atmosphere surface shaders. |
| `AlpineFlight/Rendering/PlanetOrbitDetail.swift` | Prepared orbital globe meshes, detail selection and atmosphere/cloud shells. |
| `AlpineFlight/Rendering/PlanetLighting.swift` | Cached, original HDR sky probes for image-based lighting. |
| `AlpineFlight/Rendering/WorldRenderer.swift` | Selection of the sun, local shadow range and image-based light receiver for the current destination. |

## Terrain and collision stay together

Flight regions use fixed prepared meshes. The fictional planets use a 160-by-160 ground grid over a 24 km wide region. The upgraded solid Solar System destinations use a 192-by-192 grid over a 28 km wide region. The collision queries interpolate the same triangle split and vertex heights that the corresponding renderer uses. Smoothed shading normals change how light crosses the slopes; they do not move the vertices or alter ground contact.

Broad terrain comes from deterministic, domain-warped value noise and ridged relief. Warping offsets the sampling coordinates before evaluating the ridges, reducing visible alignment with the noise lattice. The individual flight landscapes add recognizable structures:

- Tatooine has a winding canyon, rounded sandstone terraces and dunes.
- Hoth has a broad glacier corridor, branching blue crevasses and irregular mountain shoulders.
- Endor has forest foothills, distant ridges and giant redwoods around cleared arrivals and landmarks.
- Coruscant keeps flat ground and its existing city tunnels, jobs and property clearances.
- Mercury has irregularly placed crater bowls, raised rims, ejecta aprons and some central peaks.
- Venus has a volcanic cone, caldera depression and warped basalt ridges.
- Earth has an inland river valley, waterfalls, irregular coast and an estuary that reaches sea level.
- Mars has a winding dry basin, eroded escarpments and smaller dunes.
- Jupiter is a fictional cloud-flight environment rather than a solid planetary surface.

These are **original artistic flight regions**, designed for readable and enjoyable flying. They are not measured terrain surveys, and entering a planet does not reproduce the geographic location shown under the orbital spacecraft. The NASA imagery described below supplies the distant globe appearance, not the collision terrain or a height map.

There is no terrain tile streaming, runtime terrain subdivision or progressive reshaping during a flight. Detail is prepared when a destination scene is constructed. Weather batches, cloud drift and Jupiter's cyclone animate using existing geometry and bounded transforms. Shader surface detail adds apparent texture without adding solid obstacles.

## Materials and detail as you approach

`ScenicMaterials` creates and caches seamless 256-pixel albedo and normal maps for rock, sand, snow, moss and bark. Endor foliage uses a cached 512-by-1024 branch/needle cutout texture with alpha clipping on crossed planes, rather than a separate entity for every leaf. Static scenery is grouped into material batches.

The ground shader uses world position, height, slope and a small number of noise octaves to vary material colour continuously. It blends grass, rock and snow on Earth, blue ice and snow on Hoth, and strata on Tatooine. Close normal-map detail fades with both distance and screen-space derivatives. This avoids retaining strong sub-pixel grain at the horizon. Reduced-detail mode lowers the contribution and uses fewer noise octaves.

Orbit has a separate geometry detail system. `PlanetOrbitDetail` prepares all three globe meshes up front: 32, 64 or 128 longitude divisions, approximately 960, 3,968 or 16,128 triangles. It chooses an existing mesh using the ratio of globe radius to camera distance, with separate enter/leave thresholds to prevent repeated swaps near a boundary. This is an angular-size heuristic, not a measured per-pixel error solver. Reduced mode uses only the two smaller meshes. Mercury, Venus and Mars receive subtle original geometric relief; this is not elevation recovered from the NASA colour maps.

The orbital material adds derivative-filtered fine shading while the bundled colour textures use RealityKit texture resources and their mip chains. The Metal samplers use linear filtering between mip levels. Geometry detail, shader detail and texture mipmaps therefore address different costs: the silhouette, close surface shading and distant texture sampling. The flight terrain itself is not swapped for a different mesh as the ship approaches it.

## Sun, shadows, atmosphere and water

The world uses one directional sun with a consistent direction shared by the shaders and the generated lighting probes. Surface profiles choose its colour, brightness and a bounded local shadow distance. Reduced/performance mode disables these local sun shadows.

`PlanetLighting` generates a small 128-by-64 floating-point equirectangular sky probe for each upgraded destination. It includes a coloured horizon, sky/ground fill and an HDR sun highlight. The probes are prepared asynchronously and cached, then installed as RealityKit image-based lighting when available. They are original synthetic environments, not scene captures. They supply stable diffuse fill and specular illumination without recapturing the scene every frame.

Atmosphere uses **mobile-oriented Rayleigh/Mie approximations**. The shader evaluates a Rayleigh-like angular term, a forward-scattering Mie phase approximation and an exponential distance-fog term. The orbit shell adds a view-dependent limb glow and sun-facing attenuation. These are bounded-cost surface-shader approximations with artistic planet-specific colours and density values. They are not a spectral atmospheric simulation or volumetric ray marching.

Clouds use prepared translucent geometry and animated procedural coverage. Venus receives an optically thick pale orbital cloud layer so its underlying orange radar map does not read as an exposed rocky surface. Mercury has no atmosphere or cloud shell. The sky is a continuous prepared gradient rather than stacked opaque horizon bands.

Water combines RealityKit physically based specular response and the cached environment lighting with an **analytic sky reflection**. Animated wave normals, a Fresnel term and a directional sun glint give it movement and changing highlights. It does not render a mirrored copy of nearby buildings, aircraft or terrain. There are no full volumetrics, screen-space scene reflections or ray-traced reflections in this implementation.

If the bundled Metal library or a named custom shader is unavailable, `ScenicMaterials` returns its base RealityKit material. That preserves a renderable fallback, but the added procedural shading, scattering and analytic reflection are absent. Treat an unexpectedly plain appearance as a shader/toolchain diagnostic, not evidence that the full visual path has been checked.

## Orbital image sources and credits

The four bundled measured orbital maps are documented in [`PlanetTextureSources.json`](PlanetTextureSources.json). That manifest records the exact source page and download URL, original dimensions, runtime derivation, checksums, credits and usage-policy links.

| Globe | Runtime artwork | Credit / qualification |
| --- | --- | --- |
| Earth | NASA Blue Marble, 2048-by-1024 land/ocean/ice map | NASA/Goddard Space Flight Center Scientific Visualization Studio; Blue Marble data courtesy of Reto Stockli (NASA/GSFC) and NASA Earth Observatory. Clouds are a separate game effect. |
| Jupiter | Cassini cylindrical map, reduced to 2048-by-1024 | NASA/JPL/Space Science Institute. The original is retained in the source record; the runtime image has only been downsampled. |
| Mars | 1440-by-720 Viking surface map | NASA/Jet Propulsion Laboratory & Caltech; Viking imagery processed at USGS. |
| Venus | 1440-by-720 colourized Magellan radar surface map | NASA/JPL-Caltech; Magellan imagery from the JPL/Caltech planetary map database. This is radar terrain, not an optical cloud-top photograph. |

Mercury retains procedural orbital artwork. The inspected NASA Mercury candidates had coverage gaps, prominent seams or model-specific UV layouts and were not bundled as globe textures. The game loads the four selected maps from its asset catalog; it does not download planetary imagery during play.

The NASA 3D resource hub describes its assets as free to download and use subject to the [NASA Images and Media Usage Guidelines](https://www.nasa.gov/nasa-brand-center/images-and-media/). JPL's [Image Use Policy](https://www.jpl.nasa.gov/jpl-image-use-policy/) also requires acknowledgement and prohibits implied endorsement, with separate restrictions for protected identifiers and marked third-party material. Preserve the manifest and full credits when redistributing these assets. The project does not include NASA or JPL logos in this artwork and does not claim NASA endorsement.

## Xcode setup and validation boundaries

`PlanetShaders.metal` must belong to the app target so Xcode compiles its visible RealityKit shader functions into the app's default Metal library. A clean Xcode installation may also need Apple's separately downloaded Metal Toolchain. With the intended Xcode selected, install that component using:

```sh
xcodebuild -downloadComponent MetalToolchain
```

Use the project's existing deployment targets and normal signing configuration. No online imagery service, texture-server credential or extra runtime network permission is needed for these maps.

Compilation, collider/renderer agreement, arrival safety, excluded-world regression, render budgets and visual inspection are separate checks. A triangle or entity budget alone does not establish smooth play on a physical iPhone or iPad. Any release claim about frame rate, thermals, battery use or loading time should come from a recorded run on the intended device; this document makes no such measurement claim.
