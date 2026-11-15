# Single-row navigation and low-hover pod racing

The home/navigation glass dock now uses one horizontal row with familiar icons,
short visible labels and full accessibility labels. On iPhone 16 Pro landscape
all eleven actions fit with at least 44-point targets. Smaller viewports or
larger accessibility text can scroll horizontally instead of creating another
row. The current selection retains its animated highlight and the dock remains
available in the workspace pages.

Pod racers follow the sampled terrain at 10 m during race simulation. The
initial player spawn is lowered to the flat track's 102 m elevation, and rivals
use the same 10 m clearance at spawning and during movement. Swept terrain
probes ignore track-surface bumps within the road corridor; structure collisions
and off-track terrain collisions remain enabled. The collision system caches
its circuit instead of reconstructing it per swept probe. Rival shove/recovery
behavior is retained.

Validation:
- iPhone 16 Pro simulator UI check passed: eleven hittable actions on one row,
  selected pages, persistent Settings/Shop/Planner navigation and actual launch.
- 14 focused pod tests passed, including rivals' 10 m clearance, low-hover track
  safety versus off-track impact, high-speed laps and rival bump/recovery across
  physics rates. The contact fixture now puts its player at the new hover height.
- Mac Catalyst build passed and was installed locally.
- Generic iOS device compilation passed with signing disabled.
- Physical ZuZu installation is pending: the configured development certificate
  is invalid, and Xcode's normal provisioning refresh reports no signed-in
  account. No certificate was revoked and no application identity was changed.

Screenshot: `Screenshots/ControlsAndLowPods-20261115/iphone-16-pro-single-row.png`.
The screenshot is from the iPhone 16 Pro simulator, not a physical ZuZu run.
