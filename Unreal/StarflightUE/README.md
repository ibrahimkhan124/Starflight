# Starflight — Unreal Engine 5 prototype

Starflight runs in Unreal Engine **5.8.4**. The four selectable surfaces come from
the existing Starflight world definitions. Each landscape is prepared as one
region before flight. Terrain visuals, swept collision and altitude above ground
use the same height samples.

## Build and fly on Mac

Build with `Tools/build_editor.sh /Users/ibrahimkhan/Development/UE_5.8`. The Mac
editor target compiles with Xcode 27.2, including the SwiftUI Flight Planner.
Open `StarflightUE.uproject` and press Play in the Entry map, or launch its game
window directly:

```sh
cd "/Users/ibrahimkhan/Development/UE_5.8/Engine/Binaries/Mac"
./UnrealEditor.app/Contents/MacOS/UnrealEditor \
  "/Users/ibrahimkhan/Documents/New project/Unreal/StarflightUE/StarflightUE.uproject" \
  -game -windowed -ResX=1280 -ResY=720
```

Hold **R** to add throttle and **F** to reduce or reverse it. Use **W/S** for
pitch, **A/D** for bank, **Q/E** for yaw, **C** to change camera, **Esc** to pause,
and **Enter** to restart. Press **M** for the SwiftUI Flight Planner, or use
**1–4** or click the planet tabs for Hoth, Tatooine, Endor and Coruscant.
Choose one of the 28 Blender ships in the planner or cycle with **[ / ]**.
**L** visits and cycles the lake lookouts on Endor and Hoth. Hold **Left Shift**
for boost. **V** switches between the native hover handling (including reverse)
and the ported atmospheric model with lift, drag, gravity and stalls.
Pass `-StarflightWorld=Endor -StarflightShip=xwing` to start with those choices.

## Graphics and SwiftUI

- `Private/Apple/StarflightApp.swift` hosts `GameView.swift` as a native SwiftUI
  planner. The Objective-C++ adapter sends player choices to the Unreal game thread.
- `Private/GraphicsEngine/Renderer.cpp` and `Renderer.hpp` configure the sky,
  sun, fog and materials. `Planets.cpp` loads the native world data and constructs
  collidable scenery. `Spaceships.cpp` handles aircraft selection, flight and
  cameras. `Fleet.cpp` connects the Blender meshes to their Swift flight profiles.
  `PlanetWeather.cpp` adds gusts and precipitation. Hoth and Tatooine also have
  boulders that roll downhill, trigger a proximity warning and can hit the hull.
- `Shaders/Lighting.ush` supplies procedural lighting and surface inputs to
  Unreal's material pipeline, which compiles for Metal on Apple platforms.

Weather on Hoth is snow, on Tatooine it is blowing dust, and Endor and
Coruscant have rain. Storm haze rises and falls during flight.

The Unreal prototype covers surface flight. Orbit, jobs, native saves and other
gameplay systems still live in the Swift release.

## Lake and city graphics target

The visual targets from the lake references are readable reflections and ripples
at skimming altitude, grounded shore rocks, overlapping foliage, and sunlit
banks fading into mist. Hoth uses a cold ice palette, fractured lake surfaces
and frozen walker wreckage. Coruscant uses connected road markings, moving
traffic and luminous towers at night. Compare the low-altitude captures in
`Screenshots/LakeAndCity` with the earlier chase views in `Screenshots/Worlds`.
Captures are from Unreal. The references are the quality target for further
material, lighting and foliage passes.

## Recreate assets

Run `Tools/export_home_worlds.sh` to resample the four original Swift world
definitions. Blender runs `Tools/build_survey_ship.py` and
`Tools/build_planet_scenery.py` in background mode to create source FBX files.
The editor's Python commandlet runs `Tools/create_scenic_assets.py` with
`STARFLIGHT_SHIP_FBX` set to the ship FBX and `STARFLIGHT_SCENERY_FBX` set to the
scenery FBX folder. Prepared Unreal assets and world files are included for play.
For the fleet, run `Tools/export_fleet.py` inside Blender with the original ship directory and an
output FBX directory, then run `Tools/export_flight_profiles.sh` to copy the
latest tuning from Swift. Run `Tools/build_shore_tree.py` in Blender with an FBX
output directory. `Tools/create_exploration_assets.py` accepts the exported data
via `STARFLIGHT_FLEET_FBX` and `STARFLIGHT_SHORE_FBX`. It creates the terrain
feature materials even when those variables are absent.

Run `Tools/run_smoke.sh /Users/ibrahimkhan/Development/UE_5.8 Hoth` to check a
planet's terrain collision, movement, cameras, restart and pause. The full Mac tour passed all four planets, including map changes. A hands-on
Mac check opened the SwiftUI planner on Coruscant and selected Tatooine.
Screenshots in `Screenshots/Worlds` are captured directly from Unreal.

Run `Tests/run_native_flight_parity.sh` to compare the C++ aerodynamic model
against the original Swift implementation for three aircraft and wind conditions.

The SwiftUI code type-checks for iOS 26. An iPhone/iPad Unreal build requires the
iOS platform option from Epic Games Launcher and still needs device validation.
