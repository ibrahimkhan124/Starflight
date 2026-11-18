# Animated planet entry — 18 November 2026

Solar System flight previously treated every globe as a collision obstacle. Hoth
and the other fictional planets already had proximity entry. Solar bodies now
have a swept approach-shell query: the first planet encountered along the flight
segment starts its existing surface travel path. Crossing a shell at speed cannot
skip the entry trigger. The Sun remains a collision hazard.

Capture clearance is capped at 120 m and shrinks near neighbouring globes. In
particular, the Earth and Moon retain separate approach shells in the compressed
orbital map. Automatic entry keeps its departure point outside the capture shell. Cancelling
a planet approach restores that position, stops the ship at idle, and applies a
three-second simulation-time capture cooldown, allowing the pilot to steer away.
Other hyperspace cancellations retain the existing departure velocity/throttle.
Existing job, fuel and travel restrictions still apply.

## Presentation

The wallpaper reference is the independent scene layers discussed in
[SucroseAssessment.md](SucroseAssessment.md). This is original SwiftUI/RealityKit
integration, not an embedded browser or copied Windows wallpaper engine.

- Solar entry uses the existing five-second approach followed by a three-second
  region reveal. The entry sequence replaces the visible generic hyperspace
  presentation with an approaching globe, streaks and atmosphere-tinted wisps.
- Hoth, Tatooine, Endor and Coruscant get the same three-second entry presentation
  from menu entry or proximity entry.
- Existing bundled orbital maps are used for Earth, Mars, Venus and Jupiter.
  Other bodies use a stylised tinted globe. The sequence is artistic, not a
  geographically continuous descent from orbit.
- Mercury and the Moon skip atmospheric wisps. Gas/ice giants lead to cloud
  expeditions and are explicitly labelled as having no solid surface.
- The live surface is revealed underneath the overlay. During the final reveal,
  ship physics and hazards are held; control resumes after the entry ends.
- Simulation time drives progress, so pause freezes entry. Approaches can be
  cancelled before arrival; Pause is available throughout the approach and reveal.
- No progress bar, loading card or preparation messages are displayed: the
  moving planet, cloud pass and live surface reveal form the transition. A small
  planet caption and Pause/Cancel controls remain.
- Reduce Motion replaces the moving globe and streak/wisp layers with a fade.
- Reduced-detail mode omits the streak/wisp Canvas and its blur.
- Drawing is bounded to one globe, 24 streaks and 16 wisps. There are no new
  RealityKit particle entities, assets or dependencies. The HUD publishes at up
  to 30 Hz during entry and retains its previous 10 Hz rate for normal flight.

## Finding the planets

Open Hyperspace, choose Solar System, and travel there. Navigate towards a globe
to enter automatically, or use its Enter button. The surface Return to orbit
button and existing climb-to-orbit behaviour remain available. The fictional
planet sector continues to contain Hoth, Tatooine, Endor and Coruscant.

Repeated simulator runs exposed missed Solar System tab selections during sheet
presentation. The segmented layout now uses direct SwiftUI selection bindings, full 44-point
targets, selected-state accessibility values, and a pinned header outside the
scrolling scene. UI checks wait for presentation and verify the selected tab
before interacting with its content.

## Validation

Three focused model checks passed, covering swept encounters for every body,
Earth/Moon capture separation, safe arrival and orbit return for all nine
enterable bodies, invalid time steps and paused entry progression.

The final cinematic UI test passed Earth approach, cancel/retry, pause/resume,
surface arrival, orbit return, selecting the Milky Way and Hoth entry. It also
verified the selected navigation tab before interacting with its content. Earlier
runs exposed propagated accessibility identifiers and a pause control that was
only available during the brief reveal; identifiers are now individual and Pause
is available throughout. The progress bar/loading panel were removed following
the user's visual feedback.

Final Mac Catalyst and signed generic iOS builds passed. The Mac app signature
verified and the update was installed. No physical-device install or frame-rate
result is claimed.

Pictures: [Earth approach](../../Screenshots/PlanetEntry-20261118/earth-approach.png),
[Earth surface](../../Screenshots/PlanetEntry-20261118/earth-surface.png),
[Hoth entry](../../Screenshots/PlanetEntry-20261118/hoth-entry.png).
[Actual simulator entry recording](../../Screenshots/PlanetEntry-20261118/hoth-entry.mp4).
