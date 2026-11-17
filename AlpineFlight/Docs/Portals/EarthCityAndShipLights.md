# Earth city, river cleanup and flight lighting — 2026-11-17

## Waterfall fallback

The request allowed removing Earth's waterfall if a convincing result was not
practical. A finer cascade and soft-spray prototype was visually checked, but
still looked artificial in this stylised renderer. That prototype was removed.
Earth now has a gradual winding river: the two sharp height transitions are
spread over several kilometres, all river vertices remain above the actual
terrain triangles, and the flat curtain, white stripes and spray entities are
gone. River valley replaces Waterfall approach in Flight Tools. Existing historical
screenshots/notes describe older builds and are not current waterfall behaviour.

## Earth city

A prepared 36-building city sits on a cleared plateau at (4200, -6200), foundation
600 m. The plateau blends back into the original mountain recipe outside its
850 m flat core. Terrain preparation, visible buildings and swept city contacts
share EarthCity data. Wide central avenues remain open; collision reports identify
Earth city buildings. The first arrival check found insufficient large-hull
clearance over the surrounding hillside; arrival now uses local ground height and
extra clearance above the skyline. Earth → Flight Tools → Earth city visits it.

The city uses a handful of combined native material batches: buildings, stepped
roofs, blue glass, streets and roof lights. Windows face out on all four sides.
It has no independent real light or entity per building/window.

## Coruscant

The original dark building colours remain. Full-detail facades have twelve lit
floor bands instead of ten, fewer dark window gaps, and every third roof has a
pink/violet luminous perimeter. Reduced detail keeps four facade bands, with the
same prepared roof markers. These are luminous meshes, not hundreds of lights.

## Ship lights

The Lights on/off button is visible on the mobile auxiliary row and in the Mac
HUD. It controls one forward SpotLightComponent plus two small lamp housings.
The light's pose follows the ship; its range is 450 m normally and 280 m with
performance/reduced scenery mode. No spotlight shadow map is allocated. It works
when the aircraft model is hidden in cockpit view; the lamp housings are hidden
there so they cannot obstruct the pilot's view. Lights stop rendering after a
crash. The switch is session state and does not change physics, fuel or account
storage. It defaults off on a fresh app launch.

The native SDK declarations were checked locally for the SpotLightComponent API.
Existing deployment targets, signing, accounts, package pins and capabilities
are unchanged. Physical-device frame time/memory and appearance still need a
hardware check; compilation and simulator results are not performance evidence.


## Final validation

Ten focused checks passed: the plateau/building geometry and high-speed swept
contacts, central avenue clearance, gradual river surface above terrain, spotlight
pose/on-off/range/cockpit housing behaviour, dry-ground wildlife placement, bird
clearance, animation/culling, small/large scenic arrivals, walking pauses, and
inspection camera heading/release behaviour. The initial large-hull arrival
failure is fixed in the final passing run.

Both phone UI flows passed. The Earth flow entered the planet, immediately opened
its wildlife and river/coast/city shortcuts, toggled lights on/off, and returned to
orbit. The Coruscant flow visited the rooftop lookout and enabled ship lights.
The final visual pass confirms the cockpit is clear of lamp housings, the new
city is visible, roof lights are present, and the artificial waterfall is absent.
These simulator checks do not measure hardware lighting appearance or frame time.

Final Mac Catalyst and signed generic iOS Debug builds passed. The Mac copy is
installed. No physical device installation is claimed.

Pictures: [Earth city](../../Screenshots/CityRiverLights-20261117/earth-city.png),
[Coruscant and lights control](../../Screenshots/CityRiverLights-20261117/coruscant-and-ship-lights.png),
[Earth river](../../Screenshots/CityRiverLights-20261117/earth-river.png).
