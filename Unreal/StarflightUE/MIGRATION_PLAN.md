# Starflight Unreal migration plan

Decision recorded 19 November 2026: Unreal Engine 5, with iPhone, iPad and Mac
support retained. The existing working Swift/RealityKit game remains the release
and feature reference while a separate Unreal vertical slice is validated.

## Architecture decision

UE owns its 3D world, rendering, cameras, collision and frame loop. C++ implements
shared game systems and Blueprint-editable interfaces; Unreal's native UI can
provide the runtime HUD. Swift may still serve Apple-only integration features,
but the current SwiftUI app is not assumed to be a drop-in Unreal host.
Embedding Unreal inside SwiftUI is a separate feasibility gate, not a promised
supported replacement for RealityKit's ARView.

Unreal uses Metal internally on Apple platforms. This migration changes which
engine manages the graphics; it does not remove Metal from Apple rendering.
The shared chat discussed both Unreal and a different custom C++/Metal path.
The user's explicit Unreal decision takes precedence over that recommendation.

## Stage 1 — foundation (Mac engine checks passed, input/device gates open)

- Isolated `.uproject`, runtime module, Mac/iOS targets and build helper.
- App-owned Swift `advanceSpace` and alpine height recipe ported to a portable
  C++ core. This is the hover/space handling model, not a port of atmospheric lift,
  pod racing, wind, gameplay difficulty or all planets.
- Explicit coordinate conversion from metres/Y-up/−Z-forward to Unreal's
  centimetres/Z-up/+X-forward. No implicit model-scale assumptions.
- A whole bounded mountain mesh, chase/cockpit camera, touch/keyboard bindings,
  HUD and restartable swept-collision crash flow in the Unreal adapter source.
- Portable core tests pass, including 11 Swift reference samples and sanitizer
  checks. The UE adapter compiled against installed UE 5.8.4 and Xcode 27.2;
  the terrain material was generated using the real editor commandlet.

Gate: install/locate engine; confirm toolchain compatibility; compile; play;
confirm winding, camera rotation sign, input, pause, restart, visible terrain and
mesh collision; run one Mac build and one real iPhone/iPad development build.
The 5.8.4 editor module now builds, and a graphical Mac run passed eight engine
integration checks with a captured frame. Hands-on keyboard/touch acceptance,
packaged Mac builds and iOS device testing remain open. The attempted iOS build
requires installing Epic Launcher's optional iOS engine component first.

## Stage 2 — one visually convincing world and actual ship

Import `../../AlpineFlight/Art/BlenderLibrary/Ships/Ship_xwing.blend` via an
editor-verified Blender → FBX/glTF pipeline, preserving metres and hull thickness.
Create PBR material assets, terrain layers, atmosphere, clouds, shadows and engine
FX in Unreal. Replace the placeholder ship and author a small scenic route.
Use reference images and matching camera shots to judge the improvement rather
than assuming a C++ rewrite automatically raises graphics quality.

Gate: measured frame time/memory on the target Mac and an older supported iPhone
or iPad; equivalent route/input checks; shader/asset preparation without visible
terrain reshaping. Do not promise desktop effects on the mobile renderer.

## Stage 3 — planets, space and travel

Port planet definitions and deterministic placement; build terrain at matching
collision resolution; add orbit/surface entry, real-star sky, hyperspace and
black-hole hazards. Preserve seeds, world identifiers and route coordinates in a
versioned content manifest. Add bounded caches, LOD transitions and preparation
states before expanding region size.

Gate: every planet can be entered/exited safely, pause/cancel preserves state,
flight controls remain consistent, and measured resource budgets are met.

## Stage 4 — gameplay parity

Port combat, pod races, duels, story, jobs, mining/trade, housing and achievements
one subsystem at a time. Use the Swift game as behavioural reference and retain
its saved identifiers. Build a parity checklist with tests and actual device
sessions; do not call a graphics prototype a complete game migration.

## Stage 5 — persistence and Apple integration

Define a versioned, reversible save export/import format. Preserve cloud-save
ownership rules and account identity. No credentials or production saves are
copied into this prototype. Validate sign-in, cloud conflicts, offline play,
existing purchases/unlocks and input permissions before replacing any release.
Assess Swift bridges only where needed for Core Motion, hand tracking, audio,
widgets and other Apple features. Do not assume those systems transfer with assets.

## Stage 6 — release gate

Profile mobile and Mac separately. Set the chosen UE version's supported Apple
SDK/toolchain, explicit iOS deployment floor and a separate prototype bundle ID.
Keep the working release's account, capabilities and signing unchanged. Test
packaged builds, not just editor previews. Only replace a release after feature
parity, save migration and rollback have passed on actual devices.

## Sources checked

- User's shared discussion: https://chatgpt.com/share/6aff563f-ec28-83ed-a37c-66c2c5a899f2
- Epic's C++ architecture: https://dev.epicgames.com/documentation/en-us/unreal-engine/programming-with-cpp-in-unreal-engine
- Mac requirements: https://dev.epicgames.com/documentation/en-us/unreal-engine/macos-development-requirements-for-unreal-engine
- Mobile rendering feature matrix: https://dev.epicgames.com/documentation/en-us/unreal-engine/rendering-features-reference
- iOS requirements: https://dev.epicgames.com/documentation/en-us/unreal-engine/ios-ipados-and-tvos-development-requirements-for-unreal-engine

The current official mobile feature matrix lists Nanite and Lumen as unavailable
in its standard mobile rendering paths. Epic's desktop-on-mobile path is a
separate beta option; it is not the baseline for this iPhone/iPad-compatible slice.
