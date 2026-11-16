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

## Earth scenic polish

Flight Tools on Earth now offers Waterfall approach and Coastal overlook. The
first places a hovering ship upstream of the existing falls; the second frames
the ocean from the landward coast. Both use terrain-relative clearances with
extra room for large aircraft. The inspection gaze is independent of flight
pitch. No new economy rewards, physics forces or collision rules were added.

Earth deer now vary their walking pace through a smooth monotonic path phase,
slowing to near-rest periodically. Leg motion eases with that walking energy.
Four local terrain samples add bounded body pitch/bank on slopes. All accepted
placement loops are checked around a full circle, independent of walking speed.
Gulls have tapered segmented wings and tail feathers. Two prepared meadow batches
add stems and low-poly golden flowers near the herd areas; these small decorative
plants have no collision behaviour. The existing waterfall mist gently drifts
and changes native opacity without scaling world-space batch coordinates.

The visual pass found that inspection was being cancelled for any nonzero ship
heading. CameraController now remembers the initial inspection heading and only
releases on an actual turn (with angle-wrap handling), pitch/bank input or forward
movement. This keeps non-north-facing sightseeing views framed while preserving
the existing resume-flight behaviour.


Validation for this polish pass: thirteen distinct focused checks passed across
the wildlife, routes and inspection-camera sets. The final seven-check rerun
covers full deer loops, dry ground and tree avoidance, birds, scene animation,
culling, safe scenic arrivals for three hull radii, monotonic walking/near-rest,
and non-north inspection plus angle-wrap/release behaviour. The complete phone
UI flow passed after the camera correction: Earth entry, wildlife lookout, both
immediately accessible scenic shortcuts, and return to orbit. Final screenshots
show the waterfall framed and the coast looking out over the ocean.

Mac Catalyst and signed generic iOS Debug builds passed. The updated Mac app is
installed. Physical-device frame time, memory and appearance remain unmeasured.
The meadow geometry is batched and decorative; the terrain remains the existing
stylised procedural expedition, not a geographic reconstruction.

Pictures: [coastal overlook](../../Screenshots/EarthScenicPolish-20261116/coastal-overlook.png),
[waterfall approach](../../Screenshots/EarthScenicPolish-20261116/waterfall-approach.png),
[meadow wildlife](../../Screenshots/EarthScenicPolish-20261116/meadow-wildlife.png).
