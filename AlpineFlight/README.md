# Starflight

The Xcode project, scheme and executable retain the name `AlpineFlight`.

All **28 ships**, including the B-wing, Imperial Shuttle and TIE Defender, now have
fitted hull panels and craft-specific engine, canopy, weapon and cooling details.
Editable Blender parts are retained, while exported static parts are combined into
one runtime mesh per ship (two for pods, preserving their animated energy binder).
The fleet audit verifies closed source geometry, outward normals, exported flight
direction and semantic markers. The current maximum is 26,212 triangles per ship.

The 17 prepared regions now include themed forests, ice formations, settlements,
wrecks, refineries, city towers and station machinery. Small shared surface textures
add rock strata and armour plating. The renderer and collision system use the same
new scenery solids; racing lines, checkpoints and portal arrivals remain clear.
Scenery is prepared before launch with the complete region, without streaming props
into view during flight. Space free roam adds a nebula, varied stars, detailed planet
surfaces in orbit and six irregular asteroid shapes. Coruscant, Tatooine, Hoth and
Endor also have richer explorable surface architecture and atmospheric horizons.
Performance mode simplifies planet windows, forest crowns and traffic while keeping
all areas present. Frame rate still needs sustained checks on the intended device.

The main menu now has a rotating hangar preview. Drag with a finger or mouse to
orbit your selected ship. The **My creations** tools button beside Take flight
opens the local USDZ ship library and mountain-level recipe creator. See
[the creator guide](Art/CustomContent/README.md) and
[an example level recipe](Art/CustomContent/MountainLevel.json).

The level creator uses a continuous landscape-variation slider (rounded to a
whole-number seed), avoiding excessive native slider tick views. Terrain sliders
share the recipe validator’s supported ranges. Save feedback appears beside the
button and in a confirmation with a Back to hangar action.

Closed Blender ship meshes have been repaired to face outward, and TIE solar
panels have actual thickness. `Tools/repair_ship_normals.py` repairs existing
editable sources and re-exports the ship library without recreating artwork.

A native, offline SwiftUI + RealityKit flight prototype for iPhone, iPad, and Mac (via Mac Catalyst). Choose from **28 Blender-authored craft, including six unlockable blueprint ships**, **eight Star Wars story routes**, **eight podrace circuits**, and **Outer Rim free flight**. The selection includes six podracers; the Enterprise, Voyager, and Klingon Bird-of-Prey remain available as Star Trek ships. Selectable craft use compact bundled USDZ models, while collision-aligned low-poly terrain is generated efficiently on the device. The detailed fleet restores the original Voltwing and adds separate hull designs, turbine blades, canopy frames, vents, panel seams, and engine lighting. Ship export axes are tested against the game’s −Z flight direction.

## Starflight accounts (service setup pending)

Settings → Starflight account contains the separate email/password account flow.
The app-side implementation includes guided email-link confirmation (with an optional code entry), recovery codes, device-only
Keychain sessions, private save uploads, explicit device/cloud selection, stale-save
conflict protection, and local backups before restore. Imported models and custom
levels travel with the save; controls stay on the device. Transfers resume at the
selected region’s safe spawn rather than an exact mid-flight position.

**The owner’s Supabase project, private saves and account-deletion endpoint are
deployed; an email sender still needs connecting for player registration. Real signup and
cross-device transfers are not verified yet.** Follow [backend setup](Backend/README.md).
Offline play remains available. Never embed a service-role key. Native mocked
checks do not replace the live two-account/two-device checklist.

## Open and run

1. Open `AlpineFlight.xcodeproj` in **Xcode 27 or newer** (iOS 27 SDK or newer).
2. Select the shared **AlpineFlight** scheme and an iPhone or iPad running **iOS/iPadOS 26 or newer**, or **My Mac (Mac Catalyst)** on macOS 15 or newer.
3. Press **⌘R**. On the start screen, tap **Flight planner**, choose the aircraft, level and droid tabs, then choose **Done**. For open-ended exploration, tap **Free roam** or **Space free roam**. Wait for the region to load and tap **Take flight**.
4. For a physical device, select your development team under **Signing & Capabilities** and change the bundle identifier if necessary. Simulator builds do not require a development team.

The app runs in landscape on iPhone and iPad and in a Mac window through Mac Catalyst. Offline play needs no account or network connection, and there are no packages to install. Optional Starflight accounts and cloud saves use the configured Supabase service. Tilt requires a physical iPhone or iPad; the simulator and Mac use touch or keyboard controls. The project intentionally uses Swift 5 language mode and supports the iOS 18 RealityKit material API.

Physical-device builds use automatic Apple Development signing and the original iOS bundle identifier `com.alpineflight.prototype`, so installing updates the existing iPad game rather than consuming another free-development app slot. Mac builds retain `com.ibrahimkhan.alpineflight`. If installation reports a revoked certificate, refresh signing in Xcode Settings → Accounts → Manage Certificates and rebuild with automatic signing enabled. An unsigned or locally ad-hoc-signed Mac/simulator build cannot be installed on a physical iPad.

Performance mode is enabled by default for older hardware. It requests 30 Hz flight updates, prepares the lower-detail fixed terrain set, limits clouds to 12 (16 in storms), and disables HDR and grounding shadows. It also uses one small glow on buttons, panels, and controls instead of three blurred shadows on every changing readout. Nested labels inherit their container's glow rather than adding another stack. Turn performance mode off in Sound & graphics to request 60 Hz flight updates, full cloud density, and the full interface glow. RealityKit controls its own rendering cadence; this setting does not guarantee a measured GPU frame rate. Physics retains its 120 Hz fixed step and the same swept collision tests. A10 Fusion is the oldest OS-compatible target, but A10 frame times have not yet been measured on physical hardware.

The shipping target intentionally excludes the large development terrain and level USDZ folders. Those source assets remain under `Resources/BlenderAssets`, but the app bundle contains only the aircraft pack and generates terrain at runtime for a much smaller iPad download.

### Mac keyboard controls

| Keys | Action |
| --- | --- |
| W / S or ↑ / ↓ | Pitch up / down |
| A / D or ← / → | Bank left / right |
| Q / E | Rudder left / right |
| B (pod races) | Hold to engage repulsor boost |
| Shift (pod races) | Hold while steering to charge a drift; release for a short speed burst |
| + / − | Increase / decrease throttle while held |
| C | Switch camera |
| Space or P | Pause / resume (Space also starts from the title screen) |
| R | Restart the current flight |
| Return | Start or resume |
| Esc | Pause or resume |

Click the game window if keyboard focus moves elsewhere. Mouse controls remain available on Mac.

### Loops, copilot, ore scanner, and racing shortcuts

Hold climb input (W / Up, or the joystick climb direction shown for your Invert Pitch setting) to keep pitching through a
complete loop. Flying ships can pass through vertical and inverted attitudes;
the chase camera follows over the top. Leave plenty of ground clearance.
Podracers keep their flat hover controls.

Flight tools → Droid flight assistance offers Level ship, Hold altitude, and
Follow route. Moving the steering controls takes over immediately. These modes
use the normal flight physics and do not avoid obstacles. Altitude hold is for
atmospheric/planet-surface flight, not open orbit. Voice commands include “Hey
droid, level my ship”, “hold altitude”, “follow my route”, and “scan ore”.

In Space free roam, tap the scanner beside Mining & Trade to identify a nearby
asteroid ahead: material, rarity, distance, and a large-rock warning. The scan is
visible for eight seconds. Mining that asteroid yields its scanned material;
quantity varies and cargo capacity still applies.

Podrace circuits have a narrow alternate path before the first checkpoint,
marked by cyan arches and a dashed cyan minimap line. It offers two extra boost
pads; the wider main track remains available and all checkpoints are required.

### Story campaign: The Last Beacon

Choose **Story** beside Take flight on the home screen. The campaign follows your
pilot, selected droid, engineer Mira Senn and rescue captain Rhea Voss as they
restore a sabotaged rescue network. Seven chapters connect Coruscant's shuttle
jobs, orbital mining and Tatooine trading, Hoth scout recordings, Endor exploration,
a Coruscant bounty, an engine-repair approach and the Death Star trench finale.

Read the briefing and dialogue, then **Launch chapter**. The entire flight region
prepares before launch. Your selected flying ship is used; a podracer selection
uses the starter ship for story flights. Hoth's chapter applies temporary snow-squall or mist
conditions according to your plan and preserves your normal weather setting. **Read briefing aloud** uses
the system voice, follows the game's sound/volume setting and needs no microphone.

The story objective appears during flight. Complete the actual activity to progress:
opening a menu, visiting an unrelated planet or repeating a scout does not complete
a chapter. Mining requires three fresh cargo units for Rescue first, or four for the covert plan, followed by a sale at Tatooine.
Hoth requires three recordings for the rescue plan or two for the covert plan, followed by departure to orbit. Endor offers a broadcast (two scouts) or encrypted burst (three scouts), followed by departure to orbit. Chapter one and the courier bounty also require a safe return to Coruscant orbit after the job. The finale
requires every Death Star checkpoint before the existing station timer expires.

Completed chapters pause and show a debrief. Launching the next chapter starts a
new flight. Crashes and returns to base keep saved campaign objectives, while
Restart chapter flight restarts the activity at its safe spawn. Seven one-time
chapter bonuses total 2,800 credits, in addition to normal job/trade rewards. The
finale offers two saved epilogues and a title displayed in the hangar.

Progress, reward receipts and the chosen ending are stored in the existing wallet
and included in validated cloud-save archives. Existing accounts and older local
wallets remain supported. Actual cross-device transfer still needs live account
acceptance testing. The late-chapter simulator tests use isolated test progress;
player builds unlock chapters through play.

Version 1.21 adds a branching flight plan, an Endor transmission decision, staged
escape-to-orbit objectives, an evidence journal and choice-dependent epilogues.
Choices lock when you launch their chapter; existing saves retain earned chapters
and use the rescue/broadcast defaults if the new fields are absent. Partial job
and recorder milestones survive retries and saved-game reloads.

**Drifting mist** is available in Navigation & missions → Conditions → Weather.
Endor story flights use mist; covert Hoth flights use it too. Rain has patter and
occasional distant thunder, snow has blowing wind, dust has gritty gusts, and mist
has soft wind. Weather beds crossfade and are quieter in the cockpit. Sound
respects the game's sound switch and master volume. Weather is disabled in space,
races, arena duels, the trench and house interiors. Mist uses shared soft-alpha
planes and haze shells rather than expensive volumetric simulation.

See [Story and weather guide](Documentation/StoryAndWeatherGuide.md) for a
walkthrough of the Swift event system, saved choices, sound mixing and mist.

### Adventure tools

Open **Flight tools → Navigation & missions** during a paused flight, or
**Settings → Routes, careers & discoveries** from base. The five tabs are:

- **Missions:** opt-in engine trouble, a fuel-line leak, and a precision repair
  approach. Reach the cyan repair platform, approach within 450 m along a clear
  path, and choose **Dock for repair**. Hold safely for three seconds. Faults stop
  when you finish, cancel, time out, or leave the region. Standard terrain and
  obstacle collisions remain active during the approach. The HUD shows the timer;
  the normal navigation marker supplies bearing and range.
- **Routes:** save up to eight routes of 1–8 planet stops. Follow a saved route
  in Space free roam; visiting the required surface advances the next stop.
  Return to orbit between planets. Droid assistance and the map are here too.
- **Careers:** courier, passenger pilot, explorer and bounty hunter. New activities
  earn Licensed, Veteran and Master promotions at 2, 6 and 12 completions, with
  one-time 100 / 250 / 500 credit bonuses. Courier promotions unlock the fuel-leak
  and precision-repair contracts. Existing city jobs and bounties count; scanning
  or mining a newly identified material advances Explorer.
- **Minerals:** an identified/mined catalogue with rarity colours. Richer mining
  rocks rotate faster and the highest tiers include larger hazards. Cargo and
  the catalogue persist with the existing wallet.
- **Conditions:** clear skies, dust, snow squalls or rain, with a short wind and
  visibility briefing. Weather affects atmospheric and planet-surface flight;
  orbit stays clear. Performance mode uses 28 weather particles instead of 72.

A trade delivery can offer an optional distress-signal diversion after 1.8 km.
Accept it in Missions for a 90-credit rescue rendezvous while keeping the trade
route active. No diversion starts without accepting it.

**Pause → Watch last 15 seconds** plays the recorded flight path with a scrubber.
It leaves live flight state, fuel, scoring and rewards paused. Terrain is unchanged
and moving hazards are frozen; this is a flight-path replay rather than a full
reconstruction of combat. It returns to the pause/crash screen. Region transfers
clear the buffer so playback never switches to the wrong landscape.

Finish a valid pod lap to save its best-lap ghost. A translucent cyan copy follows
that path on subsequent laps and races with the same track, pod and weather.
It has no collision, weapons or slipstream. Faster valid laps replace it. Disable
it in Conditions or Settings. Storage is bounded to 16 records / 24,000 samples.
Career rewards, routes, discoveries and best laps are included in cloud-save
payloads; live account transfer still requires email/login acceptance testing.

Hold left or right input (A/D or joystick) to bank and turn. Bank angle is limited
so holding the control cannot perform a sideways barrel roll. Releasing the control
smoothly levels the wings. Q/E provides direct rudder turning on keyboard.
Vertical loops remain available; podracers continue to hover flat.

### Top flight instruments

The top bar shows altitude above the fictional sea level, **GROUND** (clearance above terrain), airspeed in knots, heading, **CLIMB / SINK** in metres per second (positive is climbing; negative is descending), throttle percentage, and shields when relevant. Ground clearance turns orange below 100 m and red below 50 m, except during pod racing or after a safe landing. Ground reads a dash during space flight and hyperspace. The bar stays on one line and scrolls horizontally on narrow screens.

### Optional camera hand steering

On a physical **iPhone 16 or newer**, **iPad with iPadOS 26 or newer**, or **Mac Catalyst with macOS 15 or newer and a camera**, open **Settings → Camera hand control → Hand steering** and allow camera access. iPhone 15 (including Pro) and older, and simulators cannot enable this mode. Mac uses the system-selected webcam; iPad and iPhone use the front camera. The Mac signing configuration includes the camera entitlement. This is a product restriction, enforced using the physical device model rather than the iOS version.

Put the phone on a stand with the front camera facing you. Switch on hand steering to start a live hand check. Show one hand and hold it still until the green paired confirmation appears (about one second) to establish neutral steering. Move the hand left/right to bank and up/down to climb/descend; the normal sensitivity and inverted-pitch settings apply. Tap the small hand-status button during flight to recenter. Touch steering takes priority; throttle, rudder, and Fire remain touch controls. Hand steering and device tilt are mutually exclusive.

`HandController.swift` uses AVFoundation and Vision to sample one hand at up to 15 Hz on a serial background queue, then applies a small dead zone, a gradual response curve, and adaptive time-based smoothing. Steering allows wider hand travel before full bank, compensates for apparent hand size, and uses the available space to either side of the calibrated center so left and right remain reachable. Low-confidence or missing hands remove steering; stale camera frames cannot hold a steering command. The paired center stays fixed through tracking loss. A palm-size threshold with hysteresis pauses steering when the hand becomes too small to track; bringing it closer resumes the original calibration. This estimates visibility from image size, not distance in metres. Pause, crashes, completion, returning to base, and backgrounding stop capture. A normal pause (including Flight tools) preserves the paired center for resume while stopping the camera; backgrounding, crashing, and returning to base reset it. Tap Recenter if you move the device while paused. Settings runs the camera only during the explicit hand check and stops it when dismissed, retaining a successful check for the next flight. Camera permission is optional (`NSCameraUsageDescription`); no microphone access is required for hand controls. Camera images are processed locally and never recorded or uploaded. Permission refusal or a busy camera leaves touch controls usable.

Automated tests cover device eligibility, calibration, filtering, stale-frame safety, and saved settings. **Live camera tracking and movement directions still require physical checks on a supported iPhone and iPad in both landscape orientations, and a Mac webcam check**; simulator tests cannot validate camera recognition.

```sh
# Run from this directory. Substitute an available simulator name if needed.
xcodebuild -project AlpineFlight.xcodeproj -scheme AlpineFlight \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build

xcodebuild -project AlpineFlight.xcodeproj -scheme AlpineFlight \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO test
```

## Aircraft and levels

Every aircraft and level is available immediately. Selection is saved between launches. Aircraft and route changes happen at base; pause and use **Back to base** to change them during a run. On completing a route, **Next level** opens the next expedition at base with your aircraft still selected.

| Aircraft | Role | Initial cruise | Handling |
| --- | --- | --- | --- |
| T-47 Snowspeeder | Rebel snowspeeder | 121 kt | Low-flying, nimble speeder with twin repulsorlifts and laser cannons. |
| Rebel U-wing | Assault transport | 224 kt | Troop-bay hull, folding wings, twin engines, and heavy forward cannons. |
| ARC-170 Starfighter | Republic fighter | 311 kt | Three-engine heavy fighter with broad wings and a rear turret. |
| LAAT/i Gunship | Republic gunship | 179 kt | Twin repulsorlift pods, troop doors, and a broad low-altitude profile. |
| T-65 X-wing | Rebel starfighter | 321 kt | Fast, balanced controls with open S-foils and four engine glows. |
| TIE fighter | Imperial starfighter | 340 kt | The quickest roll response, twin ion engines, and tall solar wings. |
| Millennium Falcon | Light freighter | 301 kt | A broad saucer hull, offset cockpit, and agile heavy handling. |
| A-wing | Rebel interceptor | 359 kt | A small, fast wedge that turns sharply. |
| Y-wing | Rebel bomber | 252 kt | Sturdy twin-engine ship with steadier controls. |
| Naboo N-1 | Royal starfighter | 330 kt | Sleek twin-pod craft with nimble handling. |
| USS Enterprise | Starfleet explorer | 185 kt | Large saucer-and-nacelle ship with measured turns. |
| USS Voyager | Starfleet science ship | 243 kt | Compact explorer with swept pylons. |
| Klingon Bird-of-Prey | Klingon raider | 282 kt | Winged ship with quick banks. |
| T-70 X-wing | Resistance starfighter | 340 kt | Split S-foils, four laser cannons, and quick handling. |
| Eta-2 Jedi Interceptor | Jedi starfighter | 350 kt | Compact solar-wing interceptor with very sharp turns. |
| Anakin’s Podracer | Podracer | 398 kt | Twin large turbine engines suspended ahead of a light cockpit pod. |
| Sebulba’s Podracer | Podracer | 379 kt | Wide, heavy twin-engine racer with strong weapons. |
| Quadinaros’ Podracer | Podracer | 359 kt | Distinctive four-engine layout and stable steering. |

Every vehicle can fire. Use the **Fire weapons** HUD button on iPhone/iPad or press and hold **F** on Mac. Weapon power, bolt speed, and cooldown are tuned per vehicle; player fire can destroy pursuing TIE fighters in the Death Star run and rival racers during pod races.

The Star Wars and Star Trek vehicles are simplified fan recreations with gameplay-tuned performance, not canon flight specifications. Each vehicle has its own speed, pitch/roll response, rudder authority, camera offsets, collision probes, and gate clearance. Blender supplies the visible meshes and materials; Swift supplies physics and effects.

| Level | Route length | Gates | Conditions |
| --- | --- | --- | --- |
| Hoth: Echo Ridge | 9.05 km | 5 | Easiest story flight: broad frozen ridges and generous checkpoint openings. |
| Tatooine: Beggar’s Canyon | 10.65 km | 5 | Sun-baked sandstone, broad turns, and a small step up in difficulty. |
| Jakku: Wreckage Run | 11.45 km | 6 | Desert ridges, tighter gates, and stronger crosswinds. |
| Endor Moon Run | 12.05 km | 6 | Forest canopy, narrower valleys, and misty ravines. |
| Bespin: Cloud City Approach | 12.35 km | 6 | Narrow high-altitude ridges, orange cloudbanks, and crosswinds. |
| Mustafar: Magma Pass | 12.85 km | 7 | Tall black cliffs, narrow gates, volcanic ash, and glowing lava channels. |
| Exegol: Sith Storm | 14.85 km | 7 | Hardest mountain flight: jagged peaks, tight gates, strong gusts, and low visibility. |
| Death Star Trench Run | 13.45 km | 12 | Timed boss run through a winding trench; wall turrets fire while TIE fighters join after gates 3, 6, and 9. Clear every gate before the Death Star explodes. |
| Boonta Eve Classic | 10.75 km | 6 | The Mos Espa course, with its broadest racing line and longest gates. |
| Sentinel One: Magma Circuit | 12.05 km | 7 | Volcanic ridges, glowing fissures, and rising heat haze. |
| Ord Ibanna: Canyon Dash | 13.25 km | 8 | Steep canyon bends and fast checkpoint spacing. |
| Ando Prime Icebreaker | 14.25 km | 9 | Ice cliffs, low visibility, and rapid turns on Ando Prime. |
| Lantaana Canopy Run | 15.65 km | 10 | A lush jungle circuit with the tightest gates and sharpest hairpins. |
| Outer Rim Free Flight | Unlimited | None | Choose the Asteroid Belt, Crystal Nebula, Comet Storm, or Shattered Moon portal; each has a five-second lightspeed jump and aggressive, weaving asteroid attack waves that can be shot apart. |

The seven normal mountain flights rise steadily in height, valley tightness, wind, visibility, and gate difficulty, followed by the Death Star boss. Then fly eight pod-race circuits that also rise in difficulty from Boonta Eve to Nar Shaddaa, each with its own terrain, palette, sky, weather, named gates, and locally saved best gate count. The expanded rival field and live position badge show your place out of all seven racers. The original Hoth route best score is migrated automatically. Outer Rim free flight prepares a permanent 9.6 km square around its portal hub and shows distance flown instead of gate progress.

## Arena duels

Choose **Arena duels** beside Take flight, select Rookie/Pilot/Ace, then
**Prepare duel → Start duel** (or choose **Trio → Start battle**). A three-second countdown starts a 150-second fight against one TIE rival, or two independently controlled rivals in a three-ship battle. Use the usual joystick, tilt/hand steering,
Fire and camera controls; on Mac hold F to fire. The dedicated HUD shows both
shields, target bearing/elevation, distance, timer and the rival’s current tactic.
Small near misses get gentle arena-only aim assistance and a forgiving hit envelope. The rival flies slower attack runs and takes shorter, less frequent evasive breaks.
The AI predicts incoming shots, chooses evasive breaks or short shield-recovery
runs, leads its shots and steers back from the arena edge. Swept collision tests
catch fast bolts. The holographic boundary turns pilots inward without crashing.
Defeat the rival to win; zero player shields loses; at the time limit the ship with more shields wins (equal shields draw). Results
include confirmed hits and Rematch. Pause freezes the duel. Arena sessions do not
consume fuel or enter normal flight rankings. Victory tokens go to the existing shop-credit wallet, once per match: duels award Rookie 350 / Pilot 700 / Ace 1,400; trios award Rookie 950 / Pilot 1,300 / Ace 2,000. Losses, draws, or leaving early pay nothing. Receipt IDs persist with the wallet to prevent duplicate payouts. In trios both rivals must be defeated; at the time limit your shields are compared with the strongest surviving rival. No multiplayer or
network connection is required. Mountain terrain is not prepared for the arena.

## Play

| Control | Action |
| --- | --- |
| Left joystick: drag down / up | Raise / lower the nose. Release to return to neutral pitch. |
| Left joystick: drag left / right | Bank and turn. Release to level the wings. |
| Two arrow buttons beside joystick | Hold for left / right rudder. |
| Throttle slider | Adjust thrust from idle to full. Starts at 65%. |
| Boost button (pod races) | Hold to spend boost charge for a thrust surge. Collect cyan track pads and clear gates to refill it. Press **B** on Mac. |
| Skid button (pod races) | Hold while steering to charge a drift around a hairpin, then release for a speed burst. Press **Shift** on Mac. |
| Camera button | Switch between smooth third-person chase and cockpit view. |
| Pause button | Resume, restart, open settings, or return to the start screen. |
| Settings → Device tilt | Steer by tilting. Touch input takes priority while dragging. |
| Calibration button (tilt enabled) | Set the current comfortable hold as neutral. Recalibrate after rotating the device. |

On a checkpoint route, fly **north through each amber gate in order**. The HUD arrow is the relative bearing to the next gate; it can point behind you if you miss one. Circle around and approach the missed gate from its south side. Passing outside its opening does not count. Clear every gate to finish. In **Outer Rim Free Flight**, the HUD lists all four colour-coded portals and points toward the nearest one. Flying through a portal starts five seconds of hyperspace lights before loading that destination. The later portal levels use more, faster asteroids and narrower safe space. Incoming rocks drain 34% shield on contact, with a brief recovery window between hits. Reach the return portal to continue free flight in the atmosphere. Plan climbs before each saddle and maintain airspeed. Lower the nose and add throttle during a stall. A terrain warning looks up to three seconds ahead along your velocity.

The HUD reports altitude in **metres above the fictional sea level**, airspeed in **knots**, heading in degrees (north = 000°), throttle percentage, gate distance, and route progress. Larger layouts also show ground clearance and weather conditions. The run starts airborne; a crash offers **Fly again**, which resets the aircraft, gates, controls, and crash effect. Best gate count is saved separately for each level; settings and aircraft selection also persist locally.

## Included

- Twenty-eight Blender-authored vehicle models, vehicle-specific handling and camera framing, jet effects, sounds, and paint schemes.
- Eight Star Wars story routes, eight competitive pod-racing circuits, and free roam with a two-way hyperspace asteroid run, fixed prepared terrain, winding valleys, route-specific architecture, distinct materials, and skies.
- Pod races include six moving rival craft, shootable rivals, a prominent dynamic race-position HUD, limited hold-to-boost, cyan boost pickups, and boost rewards at checkpoints.
- Fixed-step aerodynamic flight with thrust, lift, quadratic drag, gravity, pitch, roll, coordinated yaw, rudder, and stall behavior. Air-relative momentum follows a turn so a ship cannot keep travelling backward after turning around.
- Progressively taller mountains, narrower valleys, gusting crosswind, and increasing distance haze along the route.
- Swept terrain collision probes at the body, nose, tail, and wingtips; look-ahead terrain and stall warnings.
- Impact debris animation, synthesized impact/engine/checkpoint audio, haptic feedback, and a restartable crash state.
- Start, pause, settings, crash, and route-completion screens; automatic pause when the app becomes inactive.
- Whole-region asynchronous terrain preparation, an atomic reveal with no in-flight tile eviction or LOD replacement, skirted seams, and a 10 Hz HUD publication rate.
- Six selectable droid copilots—R2-D2, Chopper, SM-33, BB-8, K-2SO, and BD-1—with 3D ship companions, a cockpit optic feed, optional “Hey droid” voice commands, and synthesized acknowledgements. Commands include throttle, camera, status, turn left/right, climb/descend, fire weapons, cease fire, boost, repair shields, scan for enemies, next checkpoint, pause, cancel assist, and help. Steering assists last 1.5 seconds and yield to manual input; weapons fire for 3 seconds; pod boost runs for 2 seconds using normal charge. Repairs restore 20 shield points and recharge for 45 seconds. Pod altitude is automatic. The complete guide and microphone test are in Settings → Droid copilot / Droid voice commands.

## Code map

| Component | Responsibility |
| --- | --- |
| `App/GameEngine.swift` | State transitions, 120 Hz simulation accumulator, scene lifecycle, progression, 10 Hz HUD snapshots. |
| `App/GameSettings.swift` | Persisted aircraft, level, controls, paint, sound, and graphics preferences. |
| `Flight/AircraftType.swift` | Aircraft catalog, performance tuning, dimensions, camera offsets and collision probes. |
| `Terrain/FlightLevel.swift` | Level catalog, terrain/weather/visual parameters, checkpoints and per-level progress storage. |
| `Flight/FlightPhysics.swift` | Pure Swift/SIMD flight state and aerodynamic integration. |
| `Flight/CollisionSystem.swift` | Swept multi-probe collisions and predictive clearance warnings. |
| `Flight/CheckpointSystem.swift` | Gate placement, ordered plane-crossing validation, route reset. |
| `Flight/CoruscantJobs.swift` | City job routes, active-time deadlines, service stops and completion events. |
| `Flight/CityDocking.swift` | Short-range skyport braking, automatic docking glide and departure. |
| `UI/CityJobsView.swift` | Coruscant job board, rewards, current route and cancellation. |
| `Terrain/TerrainGenerator.swift` | Seeded height field, exact triangle interpolation, near/far mesh data. |
| `Rendering/TerrainRenderer.swift` | Builds the complete selected route off the main thread, reports preparation progress, and reveals the immutable region in one step. |
| `Droids/DroidCrew.swift` | Droid roster and efficient code-native RealityKit models. |
| `Controls/DroidVoiceController.swift` | Optional wake-phrase speech recognition and deterministic flight-command parsing. |
| `UI/DroidVisionView.swift` | Live cockpit optic, navigation cue, telemetry, and voice-control status. |
| `Rendering/WorldRenderer.swift` | Lights, sky, pooled clouds, checkpoints, aircraft animation, and impact debris. |
| `Rendering/AircraftFactory.swift` | Loads and gameplay-scales the Blender USDZ library, with procedural fallbacks. |
| `Rendering/AircraftModels.swift` | Procedural fallback models used if a bundled ship asset cannot load. |
| `UI/FlightPlannerView.swift` | Aircraft hangar and level selection cards. |
| `Rendering/CameraController.swift` | Damped chase and aircraft-relative cockpit cameras. |
| `Rendering/FlightSceneView.swift` | SwiftUI bridge to a non-AR RealityKit view. |
| `Controls/TouchControls.swift` | Virtual joystick, throttle, rudder, camera and calibration controls. |
| `Controls/MotionController.swift` | Optional Core Motion input, landscape mapping, calibration and lifecycle. |
| `UI/` | Responsive flight HUD, cockpit framing, start, pause, settings, and results. |
| `Audio/FlightAudio.swift` | Bundled effects and throttle-dependent looping engine audio. |

## Technical notes

World coordinates are metres, +Y up, north along −Z, and east along +X. Flight integration runs at 120 Hz, with incoming frame time capped at 0.1 seconds to avoid unstable catch-up after a stall or interruption. The camera updates at display frequency, targeting 60 fps. Flight physics is deliberately forgiving and is **not an aviation training model**.

Each region has a stable procedural seed. Checkpoint-route difficulty depends on distance north, so checkpoints never reshape terrain under the aircraft. Before the start button is enabled, every 600 m tile covering the selected route and its surrounding view area is generated at one fixed resolution. The root remains hidden during preparation and is enabled only after the final mesh is installed. No terrain entity is removed, added, or replaced during flight. Normal detail uses 16 divisions per tile; reduced detail uses 10. Free roam prepares a fixed 16×16-tile, 9.6 km square around the portal hub. Collision continues to use the deterministic height field throughout the prepared region.

Collision is an explicit swept height-field solver rather than a duplicate RealityKit rigid-body simulation. It detects terrain contact at seven aircraft-specific probes and stops flight integration immediately. This makes thin-geometry tunnelling and double integration avoidable while keeping terrain collision independent of scene loading. It is an approximation of the aircraft volume, not exact polygon-to-polygon collision.

Atmospheric fog is a lightweight **distance-banded material tint** toward the horizon color, combined with translucent cloud entities and a gradient sky. It is not volumetric scattering. Mesh generation runs off the main actor; RealityKit resource installation runs on the main actor and yields between tiles. There are no per-frame terrain collision meshes or unbounded tile caches. Further production optimization should include on-device Instruments measurements, pooled material palettes, prefetch tuning, and a GPU fog shader if desired. A 60 fps preference is not a measured guarantee.

## Permissions and assets

- `NSMotionUsageDescription` is provided for optional motion controls. Core Motion starts only during active flight when enabled and stops on pause, crash, completion, or backgrounding.
- No camera permission: the view uses RealityKit's [`ARView.CameraMode.nonAR`](https://developer.apple.com/documentation/realitykit/arview/cameramode-swift.enum) with a [`PerspectiveCamera`](https://developer.apple.com/documentation/realitykit/perspectivecamera).
- Microphone and speech-recognition access are requested when the player uses the cockpit microphone or Settings → Droid copilot → Enable droid voice access / Test microphone. macOS does not repeat prompts for access that is already allowed or denied. The settings microphone test shows an input meter and transcript without starting a flight; closing settings stops the test. If the meter stays empty, check System Settings → Sound → Input. Listening also stops when voice control is toggled off, the camera leaves the cockpit, flight pauses or ends, or the app backgrounds. Recognition tries on-device processing when supported, then retries with Apple's speech service if local recognition fails; that fallback may require a network connection. No recognized speech is stored by the app.
- No photo library, location, or tracking access. Flight gameplay works offline; optional speech recognition may use Apple's network service on devices without on-device recognition. Normal game audio uses a playback session that mixes with other audio and follows media volume and the in-game sound controls, including in Silent Mode.
- The 17 original stereo sounds include five engine families, atmospheric wind, pod skids/boost, three weapon types, shield hits, crashes, hyperspace, arrival, checkpoints and droid feedback. Player fire uses pooled voices and engine changes are smoothed. Adjust **Effects volume** in Sound & graphics. Regenerate with `python3 Tools/generate_audio.py`; see [the sound-library notes](Art/Audio/README.md).
- Blender sources live in `Art/BlenderLibrary/Ships` and `Art/BlenderLibrary/Levels`. RealityKit-ready copies live in `AlpineFlight/Resources/BlenderAssets`. Regenerate the complete library with `python3 Tools/regenerate_blender_library.py`. This samples the shared collision surface, builds detailed ships and terrain in Blender, exports both terrain LODs, adds course architecture, and renders previews. The old `create_blender_asset_library.py` supplies primitive helpers only; its obsolete standalone generator is disabled.
- Ships use bundled Blender USDZ models with procedural fallbacks. Playable ground, racing bends, the Death Star trench, arches, and course scenery are generated by Swift and RealityKit from the same deterministic route and height-field data used for collision. The development-only Blender terrain exports under `Resources/BlenderAssets/Terrain` and `Levels` are deliberately excluded from the app target. Clouds, checkpoint indicators, sky, weapons, and gameplay effects are efficient RealityKit entities.
- The icon is an original vector drawing rasterized for the asset catalog. Regenerate on macOS with `swift Tools/generate_icon.swift AlpineFlight/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`.
- The complete project is checked in; no generator is needed to open it. Add or remove Swift files through Xcode. The legacy dependency-free generator does not preserve package references or current project customisations; it now refuses to overwrite this package-based project.

## Tests and prototype scope

`AlpineFlightTests` covers every aircraft cruise model and geometry, larger-wing collision/gate clearance, route terrain and checkpoint validity, per-level progress migration, saved selection and invalid-ID fallback, selection resets, plus the original physics and collision tests. `AlpineFlightUITests` exercises start, both cameras, pause/resume, settings, restart, return to base, and an actual joystick dive into terrain followed by crash restart. UI tests save full-screen screenshots to the Xcode test result.

The current prototype includes 28 vehicles, eight story routes, eight podrace circuits, atmospheric and space free roam, four explorable planets, a blueprint unlock economy and distance-based fuel. Cockpit instruments remain a SwiftUI overlay. The Star Wars and Star Trek names and designs belong to their respective owners; this is an unofficial fan prototype and would need licensing or original replacements before commercial distribution. There is no external geographic data or saved mid-flight session. Physical-device tilt calibration, haptics, audio balance, and sustained performance should be checked on the intended iPhone and iPad hardware before distribution.

On the Death Star route, TIE fighter bolts travel more slowly and fire on a longer cycle so they can be dodged. TIE hits drain the shield gradually, and bolts that have already passed behind the aircraft do not damage it. The HUD scanner reports incoming fighters and their approximate range as they arrive after checkpoints 3, 6, and 9.

### Validation

Validated with Xcode 26.6. The unit suite covers the vehicle and level catalogs, 180° turns without backward airspeed, the Death Star trench, turret fire, pursuer waves, and held-key flight input. A dedicated UI test launches the X-wing and checks the countdown; other UI coverage includes Endor and free roam. Unsigned iOS Simulator and Mac Catalyst Release builds succeed. Use **⌘U** in Xcode to run the full suite. Unit tests use isolated preferences; trainer smoke tests use launch overrides.

Physical-device tilt calibration, haptics, audio balance, and sustained performance have not been measured. Simulator RealityKit rendering diagnostics and the supported synchronous sky-texture API deprecation may appear in build/test logs.

### Detailed Blender library validation

The revised library passed 35 unit tests, including exported ship facing direction, retained dimensions after reset, all 625 near-tile ground vertices matching collision in each of the 17 regions, and periodic free-roam alignment. A dedicated simulator UI test launched and restarted the Falcon in the trench and the original Voltwing on Boonta Eve; screenshots are saved in `Art/BlenderLibrary/GameplayChecks`. iOS Simulator and Mac Catalyst builds passed. `python3 Tools/verify_blender_assets.py` checks all 28 ship archives and 7,696 terrain LOD archives. Rendered asset previews are available in `Art/BlenderLibrary/Previews/index.html`.


Pod circuits now run three laps on closed stadium courses. Both ends contain actual 180-degree semicircular U-turns that reverse the direction of travel. The lap HUD, oriented checkpoint pylons, rivals, contact shoves, and boost pickup resets follow the circuit. All shipping terrain is generated on the device; race terrain uses the same analytic circuit as collision. Development Blender terrain assets remain available outside the shipping bundle.

The Razor Crest is selectable in Aircraft. Its editable source is `Art/BlenderLibrary/Ships/Ship_razorCrest.blend`, the bundled model is `AlpineFlight/Resources/BlenderAssets/Ships/Ship_razorCrest.usdz`, and its reproducible Blender generator is `Tools/create_razor_crest.py`.

## October free-roam update

The instruments form a single horizontal strip; swipe it sideways on narrow screens. Low-flight session points accrue for aircraft moving at least 45 m/s, between 8 m and 60 m above terrain. Flying lower earns more; paused, space, colliding, and pod-racing flight earns none. Restarting resets the score.

Choose **Space free roam** on the start screen, then **Take flight**, or open **Flight tools → Space free roam** during free flight. This is a relaxed starfield with explorable compact planets, space flight physics, weapons, and no incoming asteroid waves. The return portal leads back to the mountain region. The four existing hyperspace challenge portals remain available. Landing Academy, Open Skies, and Mission Outpost controls and scenery are removed from active gameplay.

Pinch inward in the hangar to zoom out and spread fingers to zoom in; Mac Catalyst supports trackpad pinch through UIKit. The visible zoom/reset buttons are removed; pinch zoom and accessibility zoom actions remain available. Launch plays the bundled Canva opening film with a Skip intro button. The square artwork fits inside the screen without cropping, pauses when the app becomes inactive, and skips immediately with Reduce Motion. The original yellow STAR WARS title animation remains a fallback if the movie is missing.

The opening film is `AlpineFlight/Resources/StarflightIntro.mp4` (1080 × 1080, H.264/AAC, approximately 22 seconds). Its editable Canva copy is https://www.canva.com/design/DAHZmh2t_Gs/iv8IkAUDEbhPE700-MyOOw/edit. Original replacement illustrations live in `Art/IntroSources/`; they replace the five premium elements in the copy. To update the intro, export all pages as MP4 from that copy and replace the bundled file, keeping its filename. The native player is in `UI/VideoLaunchIntro.swift`.

Flight Planner now uses its three category tabs without a search field. During free roam, the **Mining & Trade** HUD button opens cargo, markets, and trade routes directly. Opening it pauses the flight; closing the console resumes the flight.

### Space planet travel

In relaxed space, open **Flight tools → Planet destinations** and select **Tatooine, Hoth, Endor, or Coruscant**. Approach within 220 m of the globe's surface to enter its dedicated exploration area, or use **Enter Tatooine / Hoth / Endor / Coruscant** in Flight tools. These areas are separate from the story levels: Coruscant has city towers and open avenues, Tatooine has dunes and rock formations, Hoth has ice fields and peaks, and Endor has hills and low-poly trees. All surface meshes are prepared with the space scene, so entry does not stream terrain. Entry places the ship in a clear corridor at a controlled speed. This is an immediate transition into a compact local surface area, not continuous full-scale spherical flight. Ground and obstacle collision apply. Use **Flight tools → Return to orbit**, climb above **1,400 m on Coruscant or 3,200 m on the mountain planets**, or leave the surface area's boundary to return safely outside the globe. The space return portal still leads back to mountain free roam.

The opening animation now includes an animated starfield, receding gold title, Starflight reveal, and fade into the hangar. Skip and Reduce Motion remain supported.

### Travel polish

Planet selection rows show live distance and the selected destination. Asteroid challenges offer an explicit switch to peaceful free roam before showing planet navigation. Low-flight points reset for a manual restart or return to base. Region preparation hides the hangar and its controls until flight is ready. Space tools no longer report misleading zero ground clearance.

### Raised titles

The hangar title and launch logo use crisp offset shading for a raised 3D appearance. The treatment preserves text layout and accessibility; flight instruments retain their flat, legible styling.

### Expanded planet exploration

Each prepared surface is now **24 km × 24 km** (6.25 times the former area), with a 160 × 160 terrain grid. Coruscant has varied tower districts, cyan window bands, neon street lanes and decorative sky traffic. Tatooine has dunes, winding basins and larger rock spires; Hoth has uneven ice ridges and frozen peaks; Endor has layered forest canopies, hills and lit scout outposts. Each world has its own sky palette. Scenery and lights use a few batched meshes rather than individual shadow-casting lamps. A spatial hash limits obstacle collision work to nearby cells, and ground collision follows the exact visible terrain triangles.

Follow the HUD bearing to **six scout beacons** (no rings), earning 250 points per stop and 750 for the final stop, for 2,000 points per run. Only the next beacon is active; visited beacons turn green. This is optional exploration with no timer. Each visit starts a fresh run. Return to orbit remains available in Flight tools, by climbing above 1,400 m on Coruscant or 3,200 m on the mountain planets, or crossing the map boundary. All scenery is built before entry; there is no terrain streaming during surface flight. Traffic and beacon lights are decorative; terrain, towers, trees, rock formations and outpost buildings use conservative collision bounds.

Coruscant's neon pass adds violet illuminated signs with amber glyph bars, upper-tower cyan windows, magenta/violet vertical edge strips, wider rooftop lights, and three-colour avenue lighting. Tatooine, Hoth and Endor now have kilometre-scale mountain relief, winding valleys and differently coloured high ridges. The central arrival corridor stays low and clear; surface exit altitude rises to 3,200 m on these planets, while Coruscant keeps its 1,400 m exit. Terrain rendering and ground collision still share the same triangle grid.

### Camera ship gestures

On devices eligible for Hand steering, enable it in Settings, allow camera access and complete the existing hand-centre check. Keep the hand visible, with enough light and room around it. Palm movement steers as before. Pinch thumb and index together with another finger extended for at least 0.18 seconds to fire continuously; release to stop gesture firing. Manual Fire remains independent. Hold a peace sign for 0.65 seconds to switch cockpit/chase camera; open the hand for 0.25 seconds before another camera switch. Hold thumbs up/down for 0.5 seconds to adjust throttle at 25 percentage points per second, bounded to 0–100%. Releasing the gesture retains the current throttle. Closed fists do not fire. Tracking loss, stale observations, pause, recenter and leaving flight clear gesture input. Normal palm steering and existing touch/keyboard controls remain available. Gestures use on-device Vision joint observations at the existing camera rate, without recording or uploading images. The existing iPhone 16+ restriction remains; Kitty kat's iPhone SE is not eligible.

### Screen awake during flight

On iPhone and iPad, active gameplay disables the app's idle timer so tilt-only and camera-hand controls do not cause automatic screen dimming or locking. Pause, crash, completion, returning to the menu, backgrounding, or leaving the game view restores normal idle behaviour. The system Auto-Lock setting and screen brightness are not changed. System-controlled thermal or low-power brightness adjustments can still occur.

### Blueprint fleet, supply shop, daily wheel and fuel

The existing 22 aircraft remain available. Six Blender-authored fan models are locked until completed: **B-wing (Rare, 12 blueprints)**, **Imperial Shuttle (Epic, 30)**, **TIE Defender (Legendary, 90)**, **TIE Interceptor (Rare, 18)**, **Slave I (Epic, 40)** and **Scimitar (Legendary, 100)**. They are hidden from Flight planner and custom handling selection until unlocked; their blueprint progress is visible in the Shop. Newly earned low-flight points automatically credit the saved wallet at **1 FLP = 0.25 credits**. Fractional credits are stored as exact integer quarters; carrying score through travel does not award it twice. Progress saves regularly and on pause, crash, completion and leaving flight.

Open **Shop** on the hangar screen. Each card is one independent draw with replacement, using these exact per-card odds:

| Pack | Credits | Cards | Rare pool | Epic pool | Legendary pool |
| --- | ---: | ---: | ---: | ---: | ---: |
| Scout | 400 | 3 | 90% | 9% | 1% |
| Elite | 900 | 6 | 82% | 16% | 2% |
| Ace | 1,400 | 10 | 70% | 25% | 5% |
| Nebula | 2,000 | 15 | 60% | 32% | 8% |

Each rarity pool contains two ships, selected equally within that rarity. For example, a Scout card has a 45% chance of B-wing, 45% TIE Interceptor, 4.5% Shuttle, 4.5% Slave I, 0.5% Defender and 0.5% Scimitar. Every pack displays its exact per-model odds. No pack guarantees a legendary or a full ship. Surplus blueprints for an owned ship are saved separately. In Shop → Blueprints, **Sell extras** sells that model’s spare cards for **50 credits per Rare, 150 per Epic, or 900 per Legendary**. Unlock progress and owned ships are protected; sales and remaining extras persist immediately. Older wallets and unlocked ships are preserved; previously converted duplicate cards are not recreated. Settings → About Starflight displays the bundle version and build (currently **1.13, build 19**, also shown in small text on the hangar home screen). Purchases use earned in-game credits only. The collection offers rotatable/pinch-zoomable **actual 3D model previews**, including locked ships; previews never unlock or select a ship. The shop copies the flight model triangles and colours once into an independent SceneKit viewer; flight rendering remains in RealityKit. Pack purchases and blueprint daily prizes open an original face-down card reveal, with rarity colours, a flip, model preview, and unlock celebration. **Keep all** safely skips the presentation. Rewards are saved before any animation and never rerolled by closing it. Reduce Motion uses a short fade.

Low-flight rewards now require **8–60 m clearance** and **45 m/s** forward speed and earn fewer than **18 FLP/second** even at minimum allowed clearance (previously almost 100). Credit conversion remains **1 FLP = 0.25 credits**. Old saves keep credits, partial blueprints and daily claims; a TIE Defender already completed at the former 60-blueprint threshold stays unlocked. New completions need 90.

The daily wheel is free once per **UTC day**, resets at **00:00 UTC**, and offers eight equally likely rewards: 100/250/500 credits, 2 B-wing blueprints, 2 Shuttle blueprints, 1 Defender blueprint, Scout pack, or Elite pack. The reward and claim day are saved before animation so closing the shop cannot reroll; the last receipt remains visible after reopening. This is an offline local save, not a server-verified economy or cross-device/cloud account. Changing or deleting app data resets it.

Fuel starts at **100% per new flight**, consuming **1 percentage point per 5,000 metres**, for a 500 km full tank. Fractional distance counts; portal and planet teleport offsets are excluded. Fuel carries across travel within a flight. A low-fuel warning appears below 10%. At empty the game pauses; Resume is disabled until Restart flight or Back to base refills for free. No paid refuelling is needed. The flight instrument strip shows fuel and credit balance. Simulator economy UI fixtures exist only in DEBUG builds and are absent from release builds.

### October 2026 ship model refit

The B-wing, Imperial Shuttle and TIE Defender now load detailed Blender USDZ assets through the same aircraft factory as the rest of the fleet. Editable sources are `Art/BlenderLibrary/Ships/Ship_bWing.blend`, `Ship_imperialShuttle.blend`, and `Ship_tieDefender.blend`. The procedural Swift versions remain loading fallbacks. Unlock costs, flight handling, collision envelopes, and saved progress are unchanged by the artwork update.

The original 22 ships received a restrained surface refit, smoother curved parts, capped mesh conduits and repaired outward normals. Original canonical sources, assets and previews are preserved under `Art/BlenderLibrary/Backups/2026-10-20-model-refit`. New blueprint exports batch static detail into one runtime mesh with material sections, while keeping separate editable components in Blender. All 28 ships have a geometry audit in `Art/BlenderLibrary/ship-refit-report.json`; no audited mesh components are open or inward facing, and the current maximum is 26,212 evaluated triangles.

To rebuild ships without regenerating terrain: `/Applications/Blender.app/Contents/MacOS/Blender --background --threads 2 --python-exit-code 1 --python Tools/improve_ship_models.py -- all`. Use `-- blueprints` or `-- legacy` for a smaller pass, optionally followed by ship IDs. Then run `python3 Tools/verify_blender_assets.py` and the Xcode aircraft asset tests. Preview renders are in `Art/BlenderLibrary/Previews`.


### Coruscant tunnel and engine expansion (1.2)

Coruscant includes 40 illuminated S-bend tower passages, each about 966 m long, 150 m wide and 100 m high. Straight mouths lead into smooth, level curves. The visible walls, floor and ceiling share 32 sets of four oriented collision boxes with the spatial hash; nearby towers are cleared from each passage footprint. A scout beacon points to a tunnel near the arrival area. Floor guides, entrance frames and ceiling strips are batched with the existing neon materials; both detail modes retain every passage and its curves.

Animated engine effects reuse a shared sphere mesh with two tiny plume entities per nozzle, at most four nozzles per player ship. Coordinates for 23 existing ships are exported from their Blender plasma meshes in `Ships/EngineNozzles.json`; the new ships use authored nozzle locators. Other craft use compact preset layouts. Throttle changes ease smoothly; boost extends the exhaust and individual nozzles pulse gently. Ion craft use warm red exhaust, racers warm plumes and most other ships blue. Effects follow the player's ship transform and disappear with the aircraft in cockpit view. No particles or additional dynamic lights are created.

The TIE Interceptor, Slave I and Scimitar sources, previews and USDZs use the existing Blender library paths. Each has one batched runtime hull, under 11,000 triangles and at most 10 material sections. Blueprint requirements, weapon tuning, shop previews and rare/epic/legendary sale prices are integrated; existing unlocked ships and wallets are preserved.


### Space map and planet residents (1.3)

In peaceful Space free roam, tap the **Space map** button beside Flight tools. The north-up chart shows all four planets, your ship heading and the return portal from their actual X/Z coordinates. It fits the whole route even when the ship flies far away. Tap a planet to select its bearing; distance and signed height difference explain the vertical part of the journey. **Follow selected course** closes the map and resumes manual flight. The map pauses flying and keeps navigation selection. On a surface, the ship marker uses that planet's orbital location rather than mixing surface coordinates with orbital coordinates.

Endor has groups of hooded Ewoks, Tatooine has Jawas with amber eyes, and Hoth has horned Wampas. They are decorative residents with gentle idle motion, placed on sampled ground near arrival and scout camps. The first scout destinations are named **Ewok village**, **Jawa trading camp** and **Wampa territory**. They do not attack or block aircraft. Resident geometry is batched by material per camp; reduced detail uses fewer camps and the complete scenery still prepares before entry.

### Pilot logbook, achievements and rank reviews (1.4, build 5)

Open **Pilot logbook** from the hangar or the pause/results menu. Tracking starts with this update; no earlier distances or manoeuvres are inferred from old checkpoint scores. The logbook and drafts are local saves under separate `starflight.pilot-*` keys; wallets and ship progress are unchanged.

There are 14 achievements: 20/100/1,000/10,000/20,000 lifetime kilometres, 10/30/100 review flights, 10 safely recovered close shaves, 50 controlled turns, 25 soaring climbs, all four planet surfaces, a ten-flight safe streak, and a northern Hoth return expedition. On Hoth's explorable surface, reach z ≤ −6,000 (14.4 km north of arrival at z = 8,400), then return within 800 m horizontally without leaving the surface. Awards persist once unlocked and show a brief non-interactive notification. Teleports and hyperspace motion add no achievement distance.

Official ranks are reviewed after each block of 30 eligible flights. A non-crash attempt needs 60 active seconds and 1 km, or a completed route taking at least 15 seconds. Every crash counts, including short ones. Pausing, planet changes and the story-to-space transition retain the same flight ID. An outcome is saved once on returning to base, restarting, completing a route or crashing. Interrupted sessions preserve checkpointed distance and achievements, but have unknown outcomes and do not affect rank.

A flight's 0–100 score combines 55 points for avoiding a crash, up to 25 for avoiding stalls (20% stalled time removes all 25), and up to 20 for manoeuvres: 2 per controlled turn, 3 per soaring climb, and 1 per recovered close shave (at most 2 close-shave points). A crash can score at most 45. Rank thresholds are Cadet <40, Wing pilot 40–59, Flight officer 60–74, Squadron leader 75–89, Ace 90–96 and Flight legend 97–100. The full definitions are visible under **How ranking works**.

A controlled turn needs 90° over at least 3 seconds, moderate banking and 60 m clearance; level the wings before another turn. A soaring climb gains 100 m over at least 10 steady seconds without stalling. A close shave requires 0.25 seconds at 8–25 m, followed by a second above 50 m; going below 8 m invalidates the encounter, and valid recoveries have a 20-second cooldown. Pods do not earn aerial manoeuvre events.

The graph offers **Last 30 days**, **Calendar month** and **Calendar year**, with previous/next periods and Today. Mint points show daily averages, or monthly averages in year view. Orange diamonds show dated official 30-flight rank reviews. Missing days/months are not zero scores. Improvement compares the average score in the later half of the period with the earlier half, only when there are at least six eligible flights. All history remains saved for revisiting older periods.

Small active-flight drafts checkpoint every ten active seconds and on pause/background/detach; history is written only on flight completion or an award. Stale drafts recover once as interrupted, with IDs preventing duplicate history. Separate session identifiers preserve drafts belonging to another active window. The DEBUG-only `STARFLIGHT_PILOT_FIXTURE=sample` creates simulator test history; it is absent from release builds. No analytics service, account, network upload or additional device permission is used.

### Faster competitive pod racing (1.5, build 6 history)

The following records the 1.5 racing changes. The 1.6 arcade tuning below supersedes its speed and contact values.

Pod pace is **18–26% faster** across the eight circuits, with progressively greater speed and rival aggression on later tracks. This multiplier applies only to pod races. The six rival types are Anakin's, Sebulba's, Quadinaros', Ratts Tyerell's, Neva Kee's and Voltwing pods. Rivals pull out to overtake, defend their line, use short boosts on straights and commit to timed sideswipes when alongside. Steering and lane changes remain continuous; curve and traffic decisions run at 10 Hz while movement follows the fixed physics step.

Contacts deliver a bounded shove and brief recovery window, so a single overlap does not apply impacts on every physics step. Countersteer to recover, hold **Skid / Shift** through tight bends and use **Boost / B** on exits. An empty boost must recharge to **15%** before restarting, avoiding rapid on/off flicker. Nearby rivals and contact warnings reuse the existing warning space; a smoothly widening camera field of view adds speed sensation without another phone panel.

Rivals have **56 armour**: four standard 14-damage pod bolts defeat one, while other weapons retain their own damage. Shots use swept hit detection and are consumed on impact, so fast bolts register without repeatedly damaging a racer. Restart restores rival armour, the field and boost charge. Touch Boost and Skid expose their held/released state and include VoiceOver toggle actions.

`PodRaceIntensityTests` covers faster race-only pace, all six pods on all eight circuits, three-lap rival runs, boost use, lane changes, contact recovery at 30/60/120 simulation steps per second, heading-independent impacts, vertical separation, boost recharge and swept weapon damage. `testIntensePodRaceControlsAndRestart` exercises the visible Boost, Skid, Fire and Camera controls and restart. Run these through **⌘U** or targeted `xcodebuild test`; sustained device frame rate and human difficulty balance still need playtesting.

Pod circuits start at full throttle. Finished rivals leave the visible racing field while retaining their finishing progress. Ordinary aircraft keep their original flight physics and compatible rival pace; the extra 18–26% applies to pods on racing circuits. The dynamic racing field of view respects Reduce Motion. Racing rules and AI are isolated in `AlpineFlight/Flight/PodRaceManager.swift`.

### Extreme arcade pod racing (1.6, build 7)

Pod circuits use a **2.0–2.4× race speed multiplier**, replacing 1.5's 1.18–1.26× multiplier. Boonta Eve starts at 2.0× and Nar Shaddaa reaches 2.4×. This is a substantial arcade pace increase, with steering and grip tuned for the faster bends. The multiplier applies to pods on racing circuits; ordinary flight and free-roam handling retain their own tuning.

Hold **Boost / B** for **65% more target speed** while boost charge is available. Hold **Skid / Shift** while turning to build a drift, then release for a **1.28× speed burst lasting 0.45–1.25 seconds**, depending on charge. Drift bursts do not spend the normal boost gauge. Follow an active rival's line roughly **25–260 m ahead** to build slipstream, adding up to **12% target speed**; it fades quickly when pulling out to pass. The existing warning area identifies a useful slipstream, with no extra phone panel.

The six rival pods start in a tighter pack and use **1.38× timed boosts** more often. They pull alongside to overtake, defend their line and commit to sideswipes with approximately two-second attack recovery. Stronger contact pushes the player's pod sideways while preserving 98% of forward momentum. A **0.4-second player recovery window**, per-rival contact cooldown and **0.72-second rival steering stagger** keep impacts distinct. Skidding increases the player's counter-shove. A pod pushed past the actual terrain shoulder leaves the race, rather than recovering from far outside the track. Rival decisions remain at 10 Hz and movement follows the fixed physics step; finished rivals keep their finishing progress.

Use drift releases through bends, slipstream on the exit, then manual boost when a straight opens. Automated checks cover the speed separation, drift charge/release, drafting, race completion, rival contact recovery and swept terrain collision; sustained frame rate and the feel of the higher speed still need physical-device playtesting.

Checkpoint pylons use the current gate ID on every lap, so turn guidance stays visible on laps two and three instead of disappearing after the first lap.

Pod weapon bolts inherit launch velocity, so even a fully boosted racer cannot overtake its own shots; other aircraft retain their existing weapon tuning.

### Smooth extreme-speed steering (1.6, build 8)

Pod race steering now has a progressive centre and time-based smoothing for steering, turn rate and banking. Full-lock authority and extreme speed are retained. Countersteering and centring respond faster than turn entry, while engaging/releasing Skid eases the change in turn force. This works for touch, keyboard, tilt and hand inputs because it runs in shared flight physics. Ordinary aircraft and pod flight outside racing circuits keep their prior controls.


### Coruscant city jobs (1.7, build 9)

Choose **Space free roam → Take flight → Flight tools → Enter Coruscant**, then open **Flight tools → Coruscant jobs**. Accept a role, close the board and press **Resume**. The board and other paused tools freeze flight and job timers.

| Job | Route | Deadline | Completed-job reward |
| --- | --- | --- | --- |
| Passenger Shuttle | Three passenger pickup/drop-off pairs, six stops | Untimed | 120 credits |
| Express Courier | Neon Market → Industrial Quarter → Senate District | 5 minutes | 100 credits |
| Medical Rescue | Industrial Quarter pickup → Medical Centre delivery | 5 minutes | 150 credits |
| City Patrol | Four district scans: Spaceport, Market, Senate and Industrial Quarter | Untimed | 80 credits |

Five neon skyports mark the Galactic Spaceport, Neon Market, Senate District, Industrial Quarter and Medical Centre. Idle markers are dim cyan, the current target is gold and the servicing target turns green. Navigation distance includes height: match the skyport's altitude as well as its horizontal position. Within **450 m**, press **Dock** to brake and glide into its hover position; boarding, delivery or scanning takes **three active seconds** once parked. Press **Depart** between stops and fly to the next target. Decks, outlines and beacons are prepared with the city; there are no additional dynamic lights or streamed props.

Only a fully completed job pays. Leaving Coruscant, crashing, cancelling, returning to base or restarting ends unfinished work without a fee or partial reward. Timed jobs must finish servicing before their deadline. Completed rewards are saved once using a receipt ID; the wallet adds an optional receipt field while preserving existing credits, blueprints and unlocked ships. Jobs themselves are flight-session activities rather than saved routes to resume after quitting.

### Job navigation polish (1.7.1, build 10)

Active city jobs now show climb/descent guidance to the 180 m skyport altitude, a short-range Dock prompt, and an estimated arrival time while the ship is actually moving towards its target. Flying away or hovering does not show a misleading ETA. Route progress advances through the three-second boarding, delivery or scan service and appears in both the flight HUD and job board. Planet surface labels now replace deep-space and attack-wave messages while exploring a planet; peaceful orbital free roam shows exploration guidance.

### City flight usability fixes (1.8, build 11)

Skyports have taller gold approach beacons and a 450 m docking window. Inbound city-job approaches automatically ease towards 35 m/s inside 1.1 km while keeping pilot steering; docking checks the actual city obstacle map before taking over, and blocked approaches ask the pilot to line up along a clear avenue. Job flight uses one objective panel and prioritises ground clearance, speed, heading and fuel; full statistics and Controls & Flying Tips remain in Flight tools. The droid display folds during a city job and can be expanded. Coruscant uses a blue dusk sky and brighter nonmetallic building surfaces, plus predictive building warnings.

Keyboard, touch, tilt and hand input appear on the joystick, with actual pitch/bank values below it. Larger pooled laser streaks rotate with shot velocity and have a short muzzle flash. Firing has an aim indicator; hit confirmation appears only after actual rival, asteroid, enemy or surface contact. Swept laser collision handles city structures without inventing enemy waves. Crash records distinguish ground impacts, Coruscant buildings/tunnel walls, surface obstacles, orbital planet collisions, asteroids and enemy fire, with matching advice.

### Dark Coruscant buildings (1.8.1, build 12)

Restores the original dark blue/charcoal and muted rose building palette and metallic district materials. Keeps the clearer blue dusk sky, neon lighting, gold approach beacons and the 1.8 flight usability fixes.

### Coruscant careers and contracts (1.9, build 13)

All four city roles now have three selectable contracts each. Use **Flight tools → Coruscant jobs → Compare 3 contracts** to preview a route and choose **Accept and fly**. The four original quick-accept jobs remain available. The city map shows actual skyport coordinates, your ship, structure footprints and numbered stop order. Dashed route lines are schematic rather than obstacle-free corridors.

Passenger comfort, cargo integrity and patient transport condition respond to harsh banking, pitch and acceleration only while carrying the load in active flight. Passenger comfort also responds to firing weapons. Paused menus, docking and empty pickup legs never reduce condition. Specialist contracts offer modest quality bonuses, while completed base rewards remain guaranteed. Patrol variants use real five- or eight-second scans and require route flight for survey bonuses.

The saved career log contains the latest 20 completed debriefs, work totals and five licence ranks. Completion counts from older saves still unlock contracts; earlier detailed ratings are not invented. Career details and credits commit together with the existing unique completion receipt, so reopening cannot repeat a payout. See [the city career guide](Documentation/CityCareer.md) for the full catalogue and rules.

### Homes, faction work and planet comets (1.10, build 15)

Coruscant has four cleared residential districts with buy-and-build homes (900–6,500 earned credits), a separate Interior Emporium with eight furnishings, and interactive exterior/interior 3D viewers. Ownership, furniture and wallet deductions persist together. The city chart shows the plots; flight tools can transfer you to the clear approach of an owned home when no job is active.

Contacts & bounties adds Republic relief/evacuation, Imperial dispatch/surveillance and two actual ship-disabling bounties. Each side has independent standing. Existing twelve civilian contracts remain available. Comets now appear only over planet surfaces, with fading tails, crossing warnings and occasional twelve-point shield hits; they no longer appear in orbital skies.

Controls, prices, collision rules, assignments and save behavior are documented in [HomesAndFactions.md](Documentation/HomesAndFactions.md).

### Land, enter and arrange your home (1.13, build 19)

Owned Coruscant residences now offer **Land at home** inside 750 m, with a checked climb/align/descend manoeuvre to the actual terrace. **Enter home** opens a first-person furnished room; WASD/arrows or the touch stick walk, and dragging looks around. Returning to the ship preserves its parked state; **Depart** lifts off and exits along the clear avenue. The flight renderer is hidden while indoors and restored on exit.

**Arrange room** lets you drag installed furniture sets on a floor plan, nudge them by half a metre and rotate by 90°. Valid placements save per home, appear in both 3D views and affect walking collision. Walls, furniture overlap and the doorway are protected; ceiling lights remain fixed. See [HomesAndFactions.md](Documentation/HomesAndFactions.md) for the complete flow.

Interiors now measure **40 × 32 m**, with four times the floor space and an 8 m ceiling. The window, walking area, furniture floor plan and preview camera all use the larger footprint. Existing furniture sizes and saved arrangements are preserved.

Rooms now open full-screen. Walking eases into motion, brakes promptly and offers a **Brisk walk** toggle. The furniture editor adds a visible grid, optional half-metre snapping, precise footprints with numbered labels, live placement explanations, and **Undo / Redo** for up to 40 edits per visit. Restores validate the complete layout and preserve credits, ownership and stored furniture. Movement buttons adapt to smaller screens; the 3D preview retains its camera angle after edits.

Walkable rooms include their ceiling and entrance wall; the shop retains a cutaway preview. The orbital map now draws the selected route, shows the scale of its grid, and gives a compass heading with shortest-turn and climb/descend guidance. Guidance is shown in orbit; on a planet, the map still explains that you must return to orbit first. Return-portal navigation uses the same guidance.

The home catalogue now has **22 sets**, including two original framed paintings, reading and dining furniture, a sliding cabinet, desk, floor lamp and pendant, plus six outdoor sets. **Explore → Terrace** opens a walkable patio with its own editor. Outdoor arrangements appear on the actual Coruscant property through batched meshes. Approach furnishings to sit, switch lights/music, open cabinet doors, change charts, water plants, inspect artwork or control a fountain/fire pit. Interaction states and layouts save per home without changing credits. Sound respects the master settings and stops outside the room or in the background. See [HomesAndFactions.md](Documentation/HomesAndFactions.md) for prices and controls.


## Asteroid mining and trade (v1.17)

Open **Space free roam → Take flight → Flight tools → Mining & trade**.
You can also plan licences and read the material guide from **Shop → Mining & trade**.
Open the free **Coruscant ↔ Tatooine** starter route, turn on Mining mode, return
from the console, and Resume. The Fire button becomes **MINE** (keyboard **F**
and hand-trigger firing also work). Aim at a rock within **900 m** to auto-scoop
**1–3 units**. Mild aim assistance applies inside an eight-degree cone. The
26-rock mining pool uses the existing prepared asteroid entities; it drifts slowly
instead of homing in on the ship. It appears only while mining is enabled in
space free roam, and is hidden on planet surfaces. Asteroid challenges retain
their attack behaviour and do not award mining cargo.

The hold carries **120 units**. It cannot overfill. Cargo, discovered materials,
route licences, active run and sales statistics are stored in the existing wallet
and included in the player-save archive. Cargo survives crashes. There are no
paid real-money packs for minerals.

| Rarity | Materials | Chance per collected asteroid |
| --- | --- | --- |
| Common | Iron, Copper, Nickel, Silica, Carbon, Water ice, Aluminium, Sulphur | 50% |
| Uncommon | Titanium, Cobalt, Quartz, Lithium, Ammonia ice, Resinite, Chromium | 28% |
| Rare | Platinum, Iridium, Star sapphire, Deuterium ice, Amberite, Electrum | 14% |
| Epic | Aether crystal, Voidsteel ore, Plasma salt, Lumen pearl | 6% |
| Legendary | Nova diamond, Neutronium, Helios core | 1.8% |
| Exotic | Singularity shard, Primordial stardust | 0.2% |

Members of each tier have equal chances. Base prices range from 6 to 1,000
credits per unit; all prices and tier odds appear in the material guide.
Coruscant pays 50% more for metals, Tatooine for volatile ices, Hoth for crystals,
and Endor for organic materials. Approach within 900 m of a planet's base radius
or enter its surface to use its market. Sales require a route serving that planet.
Selling consumes the cargo and credits the wallet in the same saved transaction;
pressing Sell again cannot pay for the same cargo twice.

| Route | One-time licence cost |
| --- | ---: |
| Coruscant ↔ Tatooine | Free |
| Tatooine ↔ Hoth | 750 credits |
| Coruscant ↔ Endor | 1,500 credits |
| Coruscant ↔ Hoth | 2,200 credits |
| Tatooine ↔ Endor | 3,000 credits |
| Hoth ↔ Endor | 4,500 credits |

At a connected endpoint, choose **Start run**, travel to the opposite endpoint,
and sell cargo for a **20% route bonus** on that sale. Only one run is active at
a time. Market prices are fixed for this prototype; this is not a live multiplayer
exchange. Opening a route never teleports the ship. Set course updates navigation;
return to Flight tools and Resume to fly, or use the existing planet-entry flow.


### Smoother flight and Home Screen widget (v1.18)

Flight presentation interpolates between the fixed 120 Hz simulation updates, so displays above 120 Hz receive continuous ship movement. The chase camera follows the ship's translation before easing its offset and rotation; very fast ships no longer pull the camera far behind. Rudder changes are eased briefly and space acceleration uses a frame-rate-independent response. Collision, checkpoint and reward calculations still use the authoritative simulation state.

Use **Inspect ship** beside Take flight for an unobstructed hangar view. Drag a finger or mouse to orbit, pinch to zoom, or use a trackpad/scroll wheel. Done returns to the menu. The menu's background hangar is removed during inspection so two 3D hangars do not run at once.

The iOS app embeds **StarflightWidgets**, a small/medium WidgetKit launcher for iPhone and iPad running 26 or later. After installing and opening Starflight, long-press an empty Home Screen area, choose **Edit → Add Widget**, and search for Starflight. Small opens the hangar; Medium also links to Flight planner and Space free roam. It shows no live wallet or telemetry and requires no extra permissions. Widget shortcuts never automatically start a flight or spend credits. An existing session stays paused until the player returns to base; the queued shortcut opens there. The URL scheme accepts only `starflight://hangar`, `starflight://planner`, and `starflight://space`. The extension is excluded from Mac Catalyst builds. See `StarflightWidgets/README.md` for integration details.

### Replay the story

Open **Story → Replay story from beginning → Start story again**. You can do this
after finishing or partway through. Confirming returns an active flight to base,
then clears only the campaign chapters, choices, evidence and ending. Your ships,
credits, cargo, homes and other game progress stay. Pick a new opening plan and
launch chapter one. Previously collected chapter bonuses remain paid once across
replays; normal activity payouts still apply. Replay state and bonus receipts are
included in the existing cloud-save wallet. Cancel keeps your current campaign.

### Sound troubleshooting

Settings → **Test sound** plays a short chime and reports the selected output
and device media volume. **Sound effects** and **Sound volume** remain the game
controls. On iPhone/iPad, game audio now uses playback mode so Silent Mode does
not mute it. Stopping the droid microphone restores the same playback setup.
A zero media volume or a connected Bluetooth output can still make the device's
speaker quiet; use the displayed output to check the route. The test requires no
microphone permission. Backgrounding/pausing still suspends flight loops.

### 2.0.0 Universe Explorer

**Space free roam → Take flight → Hyperspace** opens the galaxy map. Travel to
Milky Way, Andromeda, Triangulum or the Large Magellanic Cloud through a five-second
jump. Cancel returns to departure; pause freezes travel. The Astronomy tab has
3,000 real offline Hipparcos stars, observer jumps and light-year readouts. The
Solar System tab offers a schematic Sun/eight-planet/Moon flyby. Fictional black
holes pull the ship, warn of extreme gravity, block nearby jumps and trigger a
restartable event-horizon crash. Signed −100%…+100% throttle allows space and
planet-surface reversing and hovering, with a neutral button. Home-sector planets
remain fictional and are available after returning to the Milky Way home sector.

See [Universe Guide](Documentation/UniverseGuide.md) for controls, scientific
limitations, performance implementation and data credits. Normal star detail uses
three mesh batches drawing 3,000 stars in total; Performance Mode
limits them to the brightest 1,000. Physical-device profiling is still needed.


### Aether Reach integration pilot

A separate experimental planet now uses the pinned Aether Swift package for its
terrain grid, surface masks and rock arch. To try it, start **Space free roam**,
open **Hyperspace**, then choose **Galaxies → Explore Aether Reach**. The complete
region prepares before entry. **Settings → Sound & graphics → Aether experimental
planet** hides or enables new trips. Existing planets keep their original paths.

Open `AlpineFlight.xcodeproj` in Xcode and allow package resolution. The tested
Aether revision is recorded in the shared `Package.resolved`; no local checkout
path is required. See [the integration notes](Docs/AetherIntegration.md) for the
adapter, comparison arguments, tests, bounded resource costs and attribution.

### Stage-two Hoth terrain pilot

Hoth now has an optional Aether terrain path that retains its original mountains,
flight routes and collision heights. Sixteen prepared sections share matching
edge normals and include below-ground skirts. Choose **Settings → Sound & graphics
→ Aether Hoth terrain pilot**, then restart Starflight to compare it with the
original path. This is fixed prepared terrain; it does not stream or reshape
while flying. See [stage-two implementation notes](Docs/AetherStage2.md).

### Stage-three Aether Reach scenery and surface

Aether Reach now adds a repeatable, batched rock field around protected flight
corridors, and a native RealityKit custom-material study using Aether's prepared
surface colours. **Settings → Sound & graphics → Aether Reach surface & scenery**
controls it after restarting. See [stage-three notes](Docs/AetherStage3.md) for
placement limits, renderer boundaries, comparisons and validation.

### Stage-four selective home-world migration

Tatooine and Endor now have independent Aether terrain switches alongside Hoth.
They keep their original planet-expedition routes, collision heights and scenery.
Restart after changing the switches, then visit through **Space free roam → Flight
tools → Enter Tatooine / Enter Endor**. Authored story levels and Solar System
surfaces retain their existing renderers. See [stage-four notes](Docs/AetherStage4.md).

### Stage-five device validation

The local Aether release check can compare original and Aether terrain in one
session on a paired phone, using isolated progress and no account connection.
It records bounded callback/update timing, physical footprint, thermal state,
scene transitions and interruptions. Normal play does not enable diagnostics.
See [stage-five instructions and release decision](Docs/AetherStage5.md) and the
saved [validation evidence](Docs/Validation/AetherStage5-20261114/evidence.json).
Display-link timing is not a measurement of GPU-presented frame rate.
