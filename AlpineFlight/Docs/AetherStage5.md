# Stage five — device evidence and rollout decision

This is the release-validation stage of the six-phase migration plan. It does
not migrate more scene families. The comparison covers Hoth, Tatooine, Endor,
and Aether Reach in the existing RealityKit game.

## Reproducible local check

`AetherReleaseValidation.swift` is an explicit developer diagnostic, inactive in
ordinary play. Both `--aether-release-check` and a recognized
`STARFLIGHT_AETHER_VALIDATION` environment value are required. It uses a separate
preferences suite, does not restore an account session, and does not read or
write a cloud save. Real player settings/progression are not reset. No telemetry
is uploaded. Reports contain device model/OS and measurements, not device
identifiers, account information or credentials.

The scenario uses the stock Kestrel, clear weather, identical initial placement,
40% throttle and the normal altitude assist. Physics, collision, scenery and the
HUD all run normally. Each home world is entered, flown and left twice by
default. Flights begin at 2,400 m for a repeatable safe sustained-flight sample;
this is not a substitute for low-altitude collision/gameplay tests. A real
hyperspace jump is cancelled, another reaches Aether Reach, and a final jump
returns to orbit. A completed run pauses the game. A background interruption,
crash or timeout fails the run rather than silently restarting it.

Baseline disables the three home-world terrain adapters and Aether Reach's
custom surface. Candidate enables them. Both retain Reach's identical scatter
geometry to isolate the material comparison. The ordinary per-world switches
and original-terrain fallback remain available.

Build a signed **Release** version for the paired device in Xcode first. Then:

```sh
python3 Tools/run_aether_release_check.py \
  --device 'Kit kat' --variant comparison --seconds 20 --passes 2 \
  --install /path/to/signed/AlpineFlight.app \
  --baseline-output /tmp/kit-kat-baseline.json \
  --output /tmp/kit-kat-candidate.json
```

The paired check is preferred: it runs baseline then candidate inside one app
session, completely rebuilding the scene between them. Original argument-domain
flags are restored afterward; no stored player flags are changed. Immutable CPU
caches can remain warm in the second half, so this is a **warm comparison**, not
a claim of equal cold-launch times. Both reports share a fresh run ID. The
helper waits for unlock before launch and closes only the running Starflight
process when starting a requested test. Diagnostic mode keeps its active scene
awake during preparation and between variants. Close and reopen Starflight
normally after diagnostics to restore normal idle-screen behavior.

Separate cold-process runs are also supported:

```sh
python3 Tools/run_aether_release_check.py \
  --device 'Kit kat' --variant baseline --seconds 45 --passes 2 \
  --install /path/to/signed/AlpineFlight.app \
  --output /tmp/kit-kat-baseline.json
python3 Tools/run_aether_release_check.py \
  --device 'Kit kat' --variant candidate --seconds 45 --passes 2 \
  --output /tmp/kit-kat-candidate.json
```

The helper validates the run ID so an old successful report cannot be mistaken
for a new run. It only copies the diagnostic report, not the app's save files.
Reports are atomically written between measurement windows under
`Documents/AetherValidation`. Use `--quality full` to request the game's existing
60 Hz/full-detail mode, separately from the default 30 Hz/balanced run. Reopen
the app normally to leave diagnostic mode. No special state persists into the
next ordinary launch.

If a flight is interrupted, the report records app activation changes and the
pause call stack. Interrupted windows are retained as failed evidence, not
counted as completed flights or used to diagnose loading performance.

## Measurements and predeclared review budgets

- Normal/balanced target: 30 Hz; review p95 callback spacing above 40 ms, or
  more than 5% of callbacks above 50 ms. Full-detail target: 60 Hz; corresponding
  thresholds are 20 ms and 25 ms. These are review budgets, not assertions that
  the operating system guarantees an exact refresh rate.
- CPU update p95 review budgets: 20 ms balanced / 10 ms full detail.
- Review peak physical footprint above 600 MiB on the oldest supported-device
  class, or more than 50 MiB growth between comparable warm orbit samples.
- No memory warnings, no serious/critical thermal state, no crash, and all
  arrivals/returns/cancellation checks must pass.
- Review region startup above 60 seconds. `worldConstructionSeconds` includes
  CPU work and upload for the existing scene stack; Aether Reach preparation is
  separately timed. `startupUntilReadySeconds` is the parent view's readiness
  wait, which may start after synchronous view attachment. Review the sum of
  construction plus readiness wait as a conservative preparation upper bound
  (the windows can overlap), not as measured total app-launch time. These do not
  include installation time.

The bounded histogram records wall-clock spacing between game display-link
callbacks and CPU time spent in the game update, **not GPU completion or actual
presented frames**. Intervals are measured before the simulation's dt clamp;
large stalls are retained, not hidden. Percentiles round up to 1 ms bins; the
overflow bucket caps at 2,000 ms while exact maximum retains larger values.
Physical footprint and thermal state are sampled once per second and at window
boundaries. Capture/trace activity can perturb a run and must be identified.
An Instruments Game Performance/Metal presentation trace is a separate check;
callback statistics alone cannot certify GPU frame rate.

Apple references: [display-link timestamps](https://developer.apple.com/documentation/quartzcore/cadisplaylink/timestamp),
[preferred frame-rate range](https://developer.apple.com/documentation/quartzcore/cadisplaylink/preferredframeraterange).

## Scope of the decision

This is a private home-project evaluation. The existing Aether revision and
notices stay intact. No App Store/distribution clearance is claimed or required
to perform these local checks. Physical iPhone and iPad measurements are separate
gates; simulator results never substitute for either. Story tiles, Solar System
terrain and full Aether GPU atmosphere remain outside this migration.

## Completed evidence — 14 November 2026

Physical device: **Kit kat, iPhone 12 (iPhone13,2), iOS 27.2**, low-power mode off.
Both halves used the same signed Release binary. The paired session completed
seven flights per variant: two 20-second windows on each home world and one
20-second Aether Reach window. All arrivals, orbit returns and cancelled-jump
guards passed. The 38 measurement windows include entry/return settling periods.
An earlier independent baseline also completed seven 45-second flight windows;
it is saved as supporting evidence from before diagnostic-runner hardening.

| Measurement | Original baseline | Aether candidate |
|---|---:|---:|
| Completed paired flights | 7 | 7 |
| Flight-window callback p95 range | 51–67 ms | 51–67 ms |
| Highest flight-window CPU update p95 | 9 ms | 10 ms |
| Sampled flight-window peak footprint range | 674–705 MiB | 751–754 MiB |
| Peak footprint including entry windows | 771 MiB | 805 MiB |
| First to last warm-orbit footprint change | +5.2 MiB | −1.8 MiB |
| Worst sampled thermal state | Fair | Fair |
| Memory warnings / crashes | 0 / 0 | 0 / 0 |

The callback p95 range covers different worlds, not one aggregated percentile.
Most home-world windows were roughly 65–67 ms; one warm Hoth window and baseline
Aether Reach measured 51 ms.
This describes occasional late game callbacks; it must not be translated into
a claim that the game continuously renders at 15 FPS. CPU update work stayed
within its review budget, but that does not identify the source of the other
main-thread/rendering delays.

The candidate's approximately 50 MiB higher settled footprint in this paired
session includes retained CPU/native graphics caches from the first half.
It is not an independently measured cold-process cost, nor evidence of an
unbounded leak: warm orbit samples stayed within a small range. The conservative
600 MiB older-device review budget was exceeded in both halves. Candidate
preparation's approximately 2.0-second upper bound versus baseline's 5.6 seconds
is a warm-cache observation, not a proven cold-loading speedup.

All **25 Starflight regression/diagnostic tests** and **19 pinned Aether library
tests** passed. The final paired simulator rehearsal also completed both halves;
its figures are kept separate from device measurements. Mac Catalyst Debug,
iOS Simulator build-for-testing and signed iOS Release builds passed. The Mac
build was installed locally for the next launch. The iOS/iPadOS minimum remains
26.0, with the existing signing identities and package revision preserved.

Earlier paused/locked attempts are excluded. A 64-second readiness wait in one
interrupted attempt is not valid evidence of terrain-loading time. The helper
now waits for unlock and explicitly closes the previous app before launch to
avoid CoreDevice's terminate/relaunch race; reports must match its fresh run ID.
The diagnostic logs record app activation changes and pause origin. No usable
GPU flight trace was captured: an earlier profiler attachment referenced an
already-ended process. No GPU frame-rate certification is claimed.

### Decision: REVISE before wider rollout

Keep the current **private experimental preview** and per-world rollback
switches. No additional scene-family migration or public release is approved by
this report. The home-world switches retain their existing enabled defaults in
this home-project build; they are not a hardware certification. To compare the
original path, disable the individual Settings switches and restart normally.

The next optimization work should measure the remaining UI/rendering hitches
and reduce resource retention, then repeat the same comparison. Physical iPad
validation remains open: Xcode could not mount Bullet Pad's developer disk
image, so no tablet frame-time, memory or thermal result is implied. Full-detail
60 Hz mode, GPU-presented frames, long thermal soaks and broader hands-on
low-clearance/control checks also remain open release gates.

Raw reports, binary SHA-256, reproducible comparison table and summaries are in
[Validation/AetherStage5-20261114](Validation/AetherStage5-20261114/Comparison.md).
The report identifies the measured signed build without including a player
account, credentials, device serial/UDID, cloud save or real progression.
