# Starflight sound library

The game uses 17 original synthesized stereo PCM effects at 44.1 kHz. Regenerate
them with `python3 Tools/generate_audio.py`; no third-party recordings or Python
packages are required. Existing engine/jet/impact/checkpoint/laser resources stay
at their original bundle paths. The additional sounds live in `Resources/Audio`.

Engine families:

- Fighters: turbine body, electrical whine and filtered exhaust.
- Freighters, transports and shuttle: deeper drive rumble and staggered harmonics.
- TIE craft: pulsing ion drive.
- Trek craft: layered warp hum.
- Pods: rougher twin-engine pulse, plus boost and skid layers.

Thrust and pitch follow smoothed throttle/speed values. Atmospheric wind rises
with speed and proximity to the ground, fades in the cockpit, and is absent in
open space. Player shots trigger on actual projectile emissions and use pooled
voices so rapid fire retains its tails. Heavy guns and ion weapons have separate
effects; enemy shots are quieter. Shield hits and destroyed asteroids use smaller
effects than crashes, without stopping the engine. Hyperspace launch and arrival
have dedicated cues. Checkpoints and droid acknowledgements have new tones.

Effects volume is saved in Settings → Sound & graphics. Pause, app suspension,
and mute stop active playback. Crash and checkpoint tails can finish when a flight
ends. Normal gameplay retains the ambient audio session and mixes with music;
optional droid microphone sessions are managed separately by the voice controller.

`sound-audit.json` records generated peak/RMS levels, sizes and loop seams.
`SoundPreview.wav` is an offline demonstration mixed at the default game's gain:
0–2 s fighter and shots; 2–4 s pod/boost/skid; 4 s checkpoint; 5–10 s hyperspace;
10 s arrival. It is a demonstration mix rather than a gameplay recording.

Focused tests decode every bundled file and check peak headroom, finite samples,
loop joins, voice-family mapping, frame-rate-independent smoothing, absence of
wind in space, projectile sound events, and saved volume bounds. The UI check
exercises Fire, cockpit view, volume adjustment, pause/resume and restart.
