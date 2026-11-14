# Room flight and exploration update

- Creations → Fly in your room uses ARKit's rear camera. Camera permission is checked before creating the AR view. The camera background is explicitly set to the live camera feed; a fresh world-tracking configuration is started after permission and app interruptions. Denied permission opens iOS Settings. Session failures show the system error and a retry action. Camera frames stay on device.
- The room toolbar fits short landscape displays; construction tools scroll horizontally, and unsupported devices show an explanation with a usable Done button.
- Pilot portraits are 200 points with inset accessories and circular clipping.
- Tap a logbook badge to inspect a two-sided SceneKit medallion. Horizontal drag changes yaw only; vertical drag never pitches the medal. VoiceOver adjustable actions turn it too.
- Replay has a compact 360-point maximum timeline with a 44-point close target.
- In the Milky Way's real-star sky, tap within 28 points of a visible catalogue star to pause and show its fact file. Selected stars also have an Info action beside the astronomy readout. Continue flying closes the fact file and resumes flight. Renderer and picking share black-hole ray deflection. Procedural stars in other galaxies are not presented as real objects.
- An ore scan keeps its asteroid ID until another scan, a new flight/sector, or target destruction/recycling. The circle and leader line follow the current rock position. Pausing does not clear the lock.
- Hyperspace → Solar System → travel to orbit. Use Enter planet beside the current target, or choose any planet's entry in the map. Rocky worlds and the Moon have prepared terrain and swept ground collision. Gas/ice giants have cloud expeditions and a deep-atmosphere boundary, not solid surfaces. Return to orbit manually, climb above 3,000 metres, or leave the 11.5 km exploration radius.
- Planet globes use original procedural textures: simplified Earth continents/oceans, polar ice, rock craters and gas-giant bands. Local landscapes are scenic interpretations, not geographic scans. Solar System globe sizes/positions remain compressed for gameplay.
- Settings → Hangar preview chooses the showroom or an orbiting preview of the selected level. Inspection still opens the interactive hangar. The preference uses existing UserDefaults settings persistence.

Star fact sources:
- ESA Hipparcos catalogue bundled with the app: distance, position, magnitude and colour index; see Resources/Astronomy/provenance.json.
- Sirius: https://science.nasa.gov/asset/hubble/the-dog-star-sirius-and-its-tiny-companion/
- Betelgeuse: https://science.nasa.gov/universe/what-is-betelgeuse-inside-the-strange-volatile-star/
- Polaris: https://science.nasa.gov/solar-system/what-is-the-north-star-and-how-do-you-find-it/

Validation must distinguish compilation, simulator flows and physical rear-camera testing. A simulator cannot validate a live AR camera.

## Verification record (10 November 2026)

- 17 focused unit checks passed: all nine planet/moon entries and returns, safe arrival heights, rejected Sun/unknown destinations, cancellation, swept terrain collisions, Earth land/water variation, shared star direction/lensing, hangar persistence, existing universe travel/reverse thrust, and avatar economy.
- iOS and Mac Catalyst compilation passed. Signed iOS build passed.
- The first simulator UI run reproduced a room toolbar overflowing above the landscape screen; the layout was corrected. The subsequent interactive checks were interrupted when the Mac locked. These UI flows are not recorded as passing.
- A live rear-camera check still requires an unlocked physical device. The iOS simulator cannot provide that evidence.
