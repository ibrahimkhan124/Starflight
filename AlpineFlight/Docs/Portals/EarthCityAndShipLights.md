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

A prepared 36-building city sits on the east bank at z = -6200 m. Its centre
is 1,450 m east of the river centreline and its western blocks are within 800 m
of that centreline. The plateau is 70 m above the local river level. The plateau blends back into the original mountain recipe outside its
850 m flat core. A 320 m protected river corridor and eased bank mask prevent city grading from
blocking the channel. Forest scenery and herds are excluded from the urban core.
Terrain preparation, visible buildings and swept city contacts
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
HUD. It describes the next action: Lights on while disabled, Lights off while enabled.
Its accessibility value separately reports the current On/Off state. Full detail
uses two forward SpotLightComponents, aimed slightly down and splayed outward;
reduced mode uses one broad central light. Range is 650 m normally and 350 m with
performance/reduced scenery mode. Shared, fading transparent cone meshes provide
a faint beam cue, strongest at night and weaker in daylight. No spotlight shadow
maps are allocated. It works
when the aircraft model is hidden in cockpit view; the lamp housings are hidden
there so they cannot obstruct the pilot's view. Lights stop rendering after a
crash. The switch is session state and does not change physics, fuel or account
storage. It defaults off on a fresh app launch.

The native SDK declarations were checked locally for the SpotLightComponent API.
Existing deployment targets, signing, accounts, package pins and capabilities
are unchanged. Physical-device frame time/memory and appearance still need a
hardware check; compilation and simulator results are not performance evidence.


## Previous validation

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


## Riverside and outward-light follow-up

The city arrival now looks across the river from the west bank, framing both the
water and east-bank buildings. City elevation follows the river instead of using
a fixed 600 m platform. The original plateau area returns to the natural terrain
recipe. No account data, ship handling, package pins or deployment targets change.

The light meshes and gradient are prepared once, with no per-frame mesh creation.
Two full-detail physical lights or one reduced-detail light keep the extra GPU
work bounded. The visual cone is an artistic beam cue rather than a volumetric
atmosphere simulation. Physical-device timing and appearance remain unmeasured.

## Follow-up validation (17 November 2026)

Nine focused checks passed: four city/lighting checks and five Earth wildlife
checks. These cover protected river terrain, city scenery clearance, swept
building collision, outward spotlight directions, cockpit housing visibility and
reduced-detail lighting.

The Earth UI flow passed entering Earth, visiting the river/coast/city, switching
lights on and off, and returning to orbit. Two earlier attempts exposed a missed
Solar System segmented-control tap; a native 44-point segmented control fixed
the touch area, and the same navigation flow then passed. The Coruscant flow
also checks the next-action labels and captures the external lights view.

Final Mac Catalyst and signed generic iOS Debug builds passed. The Mac app signature verified and the update was installed. These checks do not establish physical-device frame rate
or lighting appearance.

The decorative beam cones were narrowed and softened after the first external
view showed overly broad shells. The final external-camera UI check passed after that adjustment.
Actual spotlight reach remains 650 m at full
detail and 350 m at reduced detail.

Pictures: [Riverside city](../../Screenshots/RiversideLights-20261117/earth-riverside-city.png),
[outward headlights](../../Screenshots/RiversideLights-20261117/outward-headlights.png).
