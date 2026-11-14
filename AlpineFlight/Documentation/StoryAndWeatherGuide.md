# How Starflight's story, weather sounds and mist work

The game runs in Swift, SwiftUI and RealityKit. Python is only an offline tool
for preparing the bundled sound files; the installed game does not run Python.

## 1. A story chapter listens for things you actually do

`AlpineFlight/App/StoryCampaign.swift` defines the seven chapters and the saved
`StoryCampaignProgress`. The engine sends it events such as `.mined(1)`,
`.scout(.hoth, 0)` and `.orbit(.hoth)` after the real activity succeeds.

Think of this as a checklist with a bookmark. Collecting a Hoth recording puts its
number in a Set. Repeating the same recording cannot count twice. The final
`.orbit(.hoth)` event completes the chapter only after enough different recordings
have been collected. Returning to the wrong planet's orbit does not complete it.

The first Coruscant chapter now has two steps: complete the passenger job, then
leave for orbit with Mira. The courier chapter similarly requires the bounty and
an escape to orbit. Completed steps are saved, so a retry need not repeat a job
whose evidence has already been secured.

## 2. Your choices change rules, not just text

Before chapter one, choose Rescue first or Fly under the radar. The plan is saved
and locked when the chapter starts. `cargoRequired` returns three or four;
`hothRequired` returns three or two. The flight engine chooses Hoth's snow or mist
from that same plan. The UI and spoken briefing read those same requirements.

On Endor, an open broadcast needs two scouts. An encrypted burst needs three.
The choice also changes the transmission, evidence journal and final epilogue.
These are two approaches to the same seven chapters, not two separate campaigns. Endor arrivals now begin above the canopy so the chase camera can see the forest approach.

Optional new save fields allow older saves to load. Missing choices use the
rescue/broadcast defaults. An older save at an untouched first-chapter or Endor objective can still make its newly introduced choice once before continuing. A completed chapter pays its story reward once; repeated
events cannot pay it again. The existing wallet/cloud archive carries the story.

## 3. Mist is a small collection of reusable shapes

`AlpineFlight/Rendering/FlightAdventureRenderer.swift` prepares one 128×128 image
with white in the centre and transparent edges. RealityKit shares that texture
and one flat mesh across twelve mist banks. Reduced detail enables five banks.
Three large inward-facing haze shells soften the distant view. Mist itself has
no falling rain or snow particles.

Every frame, the bank positions drift gently using sine waves. Each bank faces
the camera, so you see the soft cloud rather than the edge of a flat rectangle.
The camera's position is added through `weatherRoot`, and its orientation turns
the bank's local offset into world space. No meshes or textures are rebuilt here.

This is an inexpensive atmospheric approximation, not a physically simulated
volume. Real volumetric fog requires a more involved rendering pipeline and a
larger GPU budget. The current approach preserves the game's low-poly scenery.

## 4. Sounds fade between weather types

`AlpineFlight/Audio/FlightAudio.swift` loads four looping weather sounds and a
short thunder effect with AVAudioPlayer. `WeatherSoundMix` moves each loop toward
its target volume with:

```swift
let response = 1 - exp(-dt * 2.2)
volume += (target - volume) * response
```

A small `dt` makes a small step; a larger `dt` makes a larger step. This gives
similar fade timing at 30 and 60 frames per second. Entering the cockpit reduces
the target volume to 42 percent. Leaving the atmosphere fades the weather out;
pausing or disabling sound pauses the loops. Rain plays distant thunder after
nineteen seconds of active rain, then repeats on that interval.

`Tools/generate_audio.py --weather-only` creates these WAV assets ahead of time.
It combines filtered random noise (the wind/rain body) with slow volume changes
(gusts), then joins each loop's ends to reduce clicks. The WAV files are bundled
under `AlpineFlight/Resources/Audio`. No microphone permission or download is needed.

## 5. How to experiment

- Change `WeatherSoundMix` targets to change the weather/engine balance.
- Increase the `2.2` fade factor for quicker transitions; reduce it for slower ones.
- Change the mist bank drift multipliers to alter how quickly clouds move.
- Increase a bank's scale for broader mist patches. Keep the pool bounded.
- Edit chapter dialogue and clues in `StoryCampaign.swift`. Keep the on-screen
  requirements, actual event checks and narration driven by the same saved rules.
- Use Navigation & missions → Conditions to try Drifting mist outside the story.

The tests check branch requirements, duplicate scout rejection, orbit order,
old saves, partial milestones, sound-loop decoding and seams, frame-rate-independent
mixing and reusing the same weather entities. Simulator interaction tests check
real chapter launch and branching controls with isolated test progress. These
checks do not replace a complete campaign playthrough or physical-device profiling.
