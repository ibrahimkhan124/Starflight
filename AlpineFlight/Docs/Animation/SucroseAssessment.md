# Sucrose animation assessment — 18 November 2026

Inspected Taiizor/Sucrose at revision
`e35151299ca77ad64d330291536b056577f4bea2`.

Useful reference:
[Alve's Town scene layers](https://github.com/Taiizor/Sucrose/blob/e35151299ca77ad64d330291536b056577f4bea2/src/Bundle/Sucrose.Bundle/Showcase/Alve%27s%20Town-1/assets/scripts/scene.js).
The source separates stars, cloud layers, city lights and scene filters, updates
only relevant layers, interpolates transitions, and offers a static fallback.

Starflight uses that architecture as a reference for independently animating its
existing nebula shell while preserving the positions of all star batches. The
new native implementation is written for RealityKit; no Sucrose JavaScript,
Windows host code, artwork, third-party libraries or shaders are copied into the
app. No new package is added. Sucrose's repository declares GPL-3.0; bundled
wallpapers and libraries can have their own notices. This note does not relicense
any upstream material.

## Applied

- Nebula-only yaw/roll oscillation on a continuous 120-second loop, bounded to
  approximately 1.5 degrees. Star positions and planet transforms are unchanged.
- Cached nebula reference, one transform update, no frame-time mesh/texture
  creation, no per-star entities. Hidden scenes do not advance the effect.
- Reduce Motion and reduced-detail mode restore a static nebula.
- Engine exhaust uses a slower swell plus a smaller fast shimmer instead of one
  fast pulse. Reduce Motion removes shimmer while retaining throttle response.
- Existing throttle smoothing and flight physics remain unchanged.

## Not selected

The Windows wallpaper host, browser engine, online weather requests, fluid
simulation and third-party Three.js postprocessing do not suit this small native
change. Layering full-screen browser effects over gameplay would add work and
could interfere with controls. Atmospheric stars are not made to drift or flash.

## Validation

Mac Catalyst and signed generic iOS builds passed. Three simulator tests passed:
nebula movement without star transforms/entity churn, steady Reduce Motion exhaust
with working throttle response, and bounded/smooth exhaust across the ship roster.
The older four-nozzle assertion was corrected to allow the existing seven-engine
Star Destroyer; other ships retain the four-nozzle bound. The Mac update was
signature-verified and installed.

This is build and behaviour validation, not an end-to-end visual flight review.
The simulator also emitted native renderer pipeline warnings during test-host
startup, so it is not reliable evidence of physical-device appearance. Device
frame time and thermal behaviour must be measured separately; bounded scene work
does not prove unchanged performance on physical iPhones or iPads.
