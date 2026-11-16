# Earth valley wildlife

Earth is a SolarLandscape expedition, separate from the SpacePlanet home-sector
renderer. Wildlife added to Endor/Hoth/Coruscant therefore did not appear here.

Earth now has nine valley herd/flock areas spanning z = -10,000 to +10,800 m.
Full detail uses 18 large deer and 27 river gulls; reduced detail uses nine of
each. Both detail modes share the same herd locations. Gulls have pale wings,
rounded bodies/heads and amber beaks; deer reuse the existing antlered wildlife
model at adult/juvenile scales 2.4 / 1.9. These are stylised original models.

Placement uses the same triangle-interpolated SolarLandscape.height as rendering
and collision. Deer sites and roaming loops avoid river/ocean water, steep local
slopes and tree-canopy footprints. Bird orbit heights include local terrain and
nearby treetops, with 110 m initial clearance and a bounded 14 m bob. All placement
is cached. Animation updates at up to 30 Hz, with existing ground visibility fade
at 1–1.5 km and bird fade at 2.2–3 km. Hidden animals stop animating; meshes are
shared and no terrain placement searches occur during animation.

UniverseRenderer owns Earth's wildlife lifecycle. It removes the wildlife when
changing expedition/returning to orbit, and rebuilds the prepared population when
the detail setting changes. WorldRenderer now forwards Reduced scenery detail
as well as performance mode to universe scenery. No flight physics, account data,
capabilities or deployment targets changed.

On Earth, Flight Tools now includes Earth wildlife lookout. It uses the current
detail mode's first herd, hovers with zero throttle, and uses an independent
inspection camera with terrain sightline clearance. Moving off/switching cameras
retains the existing inspection release behaviour.

The other real Solar System planets have not received fictional Earth wildlife.

## Checks

Nine focused checks passed, including dry-ground/river/tree avoidance for all
18 deer, ground-triangle following, bird orbit clearance, full/reduced prepared
populations, animation and distance culling. Existing home-sector wildlife and
lookout checks passed with the shared deer renderer refactor.

The first phone UI pass exposed an existing clipped Solar System entry strip:
its accessibility button frame extended outside the scroll area's visible bounds,
so a tap could select a star behind it. The mobile HUD now gives jump, Solar
System entry and solar-surface return controls a fixed intrinsic-height place in
the primary row, replacing the duplicate objective there. Other optional notices
remain scrollable. Mac layout is unchanged by this phone-specific correction.


The corrected phone UI check passed: Solar System jump, Earth entry, immediate
Earth wildlife lookout, visible deer inspection, and return to orbit. Screenshots
confirm the primary entry/return controls are fully visible and the animal is
framed. Mac Catalyst and signed generic iOS Debug builds passed. The Mac app is
installed; physical-device performance/appearance and installation remain untested.

Pictures: [Earth deer](../../Screenshots/EarthWildlife-20261116/earth-deer-lookout.png),
[orbit entry controls](../../Screenshots/EarthWildlife-20261116/solar-orbit-controls.png).
