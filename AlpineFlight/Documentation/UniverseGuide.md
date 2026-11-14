# Starflight 2.0.0 — Universe Explorer

Start **Space free roam → Take flight**, then tap the gold **HYPERSPACE** button. On iPhone and iPad it sits at the
upper right, below the instrument bar; on Mac it is in the top toolbar. The same console is available from Space map and Flight
tools → Galaxy map & hyperspace. A planet flight must return to orbit first.

## Travel

The 3D Local Group chart supports drag to orbit, pinch to zoom, and tapping a
marker. The list below it offers the same destinations. Choose Milky Way,
Andromeda, Triangulum, or Large Magellanic Cloud, then **Engage hyperspace**.

Travel takes five seconds of active flight time, with the existing streak tunnel
and a gentle field-of-view expansion (disabled with Reduce Motion). Pause freezes
the countdown. **Cancel jump** restores the departure state and throttle. Arrival
starts at zero throttle in a bounded scene; it does not count fictional travel
across millions of light-years as flown distance, fuel consumption or FLP.

Choose Milky Way to return to the fictional Starflight home sector and its
enterable planets. Home-sector planets, portals, collisions and trade ports are
absent in the remote sectors. Coruscant/Hoth/etc. have no claimed astronomical
positions. Finish your current story, city, bounty or emergency activity before
changing sectors. Hyperspace is blocked within the strong black-hole zone.

## Black holes

**Visit black-hole approach** jumps to a safe position 3.8 km from the fictional
singularity. Increase forward thrust to approach, or use reverse to back away.

- Outside 3.2 km: no gravitational acceleration.
- Inside 3.2 km: drift increases as inverse-square acceleration grows, with a
  smooth outer taper and a bounded acceleration.
- Inside 850 m: extreme-gravity warning; hyperspace is blocked.
- Within the 150 m event horizon (plus ship radius): a swept collision ends flight.

The accretion disc, jets and photon ring are prepared meshes. A lightweight
angular deflection of the background stars provides a stylised lensing effect.
This is a compressed gameplay approximation, not general relativity or the
measured mass/position of an observed black hole. Gravity drift is independent of
engine steering, so turning cannot erase it. Escape early and thrust away.

## Real stars and astronomy

**Astronomy** bundles 3,000 distinct real stars selected from ESA's original
Hipparcos catalogue through NASA HEASARC. Sirius, Rigel, Betelgeuse and Polaris are
included. Search by common name or HIP number, select a bearing, or **Jump near**
a star. **Earth reference sky** returns to the original observer. The overlay
shows the selected star, or a bright star close to the ship's crosshair.

RA/declination are ICRS positions at catalogue epoch J1991.25. Proper motion is
not extrapolated to today's date. Positions are converted to 3D using inverse
parallax: `distance_pc = 1000 / parallax_mas`. The import keeps positive parallaxes
with relative parallax error below 50%; distances remain approximate. Missing
B−V values use neutral colour. Colours and apparent star sizes are stylised.

Observer movement is exaggerated: 20 km of local flight equals one parsec in the
sky model. Close-star perspectives and brightness change with distance; distant
stars change much less. Jump arrival stays 0.03 pc away from the selected star,
rather than placing the camera at a zero-length vector. Actual light-year
readouts accompany star bearings; local waypoint metres are not presented as the
physical distance to a star.

Other galaxies use original procedural survey stars and coloured nebula scenery.
Those fields are explicitly not labelled as measured individual stars. The map
itself is schematic, not a measured 3D map of the Local Group.

## Solar System

The Solar System tab loads a separate flyby sector containing the Sun, Mercury,
Venus, Earth, Mars, Jupiter, Saturn, Uranus, Neptune and Earth's Moon. Select a
body to change your bearing. Body sizes and fixed positions are intentionally
compressed, with simple placeholder surfaces. There are no orbital dynamics or
surface landings here. Globe collisions use swept tests. Return to the Starflight
home sector for enterable terrain and city flight.

## Flight control layout

Steering, throttle, Fire and Camera stay at the bottom of the safe display area.
Short displays use a smaller control layout; warnings and activity panels scroll
within the remaining space above them. The compact throttle has a **0%** button
for Stop / Hover. Hyperspace has a labelled gold button and a touch target at least
44 points high.

## Reverse and hover

Space and planet-surface flight use −100% to +100% throttle. Negative thrust
smoothly brakes and then reverses the ship without turning its nose around.
Zero thrust eases to a stop; **STOP / HOVER · 0%** centres the control. Wind or
black-hole gravity can still cause drift. Keyboard +/− and compatible hand
controls use the same range. Droid voice recognises commands such as “Hey droid,
reverse throttle fifty percent.” Pod racing and ordinary aerodynamic mountain
flight retain their existing throttle range.

## Implementation and performance

- `Flight/UniverseSimulation.swift`: destinations, catalogue coordinates,
  five-second transit, bounded gravity drift, horizon and Solar System collisions.
- `Rendering/UniverseRenderer.swift`: three LowLevelMesh star batches, with vertex
  buffers updated in place. No per-star entities or mesh regeneration in flight.
  Performance Mode draws the 1,000 brightest entries and updates less frequently.
- `UI/UniverseNavigationView.swift`: reusable console, native map gestures, star
  search and detailed source/scale notes.
- `App/GameEngine.swift`: activity guards, real flight integration, normal crash
  flow, no-warp-distance rewards, and one-time arrival records.
- `FlightAdventureProgress`: optional visit sets inside the existing wallet, so
  older saves still decode and visits travel in the existing cloud archive.

Both the catalogue and source/provenance metadata are bundled offline. Regenerate
with `python3 Tools/import_star_catalogue.py`; no API key or account is needed.

## Sources

- ESA Hipparcos, via NASA HEASARC: https://heasarc.gsfc.nasa.gov/w3browse/all/hipparcos.html
- Andromeda distance: https://science.nasa.gov/mission/hubble/science/explore-the-night-sky/hubble-messier-catalog/messier-31/
- Triangulum distance: https://science.nasa.gov/mission/hubble/science/explore-the-night-sky/hubble-messier-catalog/messier-33/
- LMC context: https://science.nasa.gov/earth/earth-observatory/the-galaxy-next-door/
- RealityKit LowLevelMesh: https://developer.apple.com/documentation/realitykit/lowlevelmesh

The source catalogue is credited to ESA and the Hipparcos scientific consortia;
NASA HEASARC supplies this query service. Provenance includes the exact SQL query,
epoch, selection criteria and SHA-256 digest of the bundled subset.
