# Coruscant city career

Version 1.9, build 13 adds eight specialist contracts alongside the four original jobs. Everything runs locally; no new permission, account, connection or paid currency is required.

## Play a contract

1. Choose **Space free roam**, launch, then use **Flight tools → Enter Coruscant**.
2. Open **Flight tools → Coruscant jobs**. Quick-accept buttons start the original jobs. **Compare 3 contracts** opens that role's route catalogue.
3. Preview a route, check its reward, deadline and licence requirement, then choose **Accept and fly**. This closes the planner and resumes flight.
4. Follow the gold skyport beacon. Approach assist slows an inbound ship inside 1.1 km. Press **Dock** inside 450 m along a clear avenue. Docking moves through the actual city; an obstructed approach is rejected.
5. Wait for boarding, transfer or scanning, then press **Depart**. Complete every stop to receive the base reward and any earned bonus.

Coruscant building collisions use a forgiving contact radius at 60% of each ship’s normal body radius. Direct impacts still crash; ground collision, ship appearance and the other planets retain their existing dimensions.

Flight, deadlines, scans and transport ratings pause in the tools, map and contract screens. An unfinished contract ends if you cancel, crash, restart, return to base or leave Coruscant. There is no cancellation fee or partial payment. Active contracts do not resume after quitting; completed work stays saved.

Version 1.10 also adds four faction contracts and separate bounty assignments, documented in [HomesAndFactions.md](HomesAndFactions.md). The original twelve civilian routes below remain unchanged.

## Contract catalogue

| Role | Contract | Stops | Time limit | Base credits | Possible bonus | Jobs needed |
| --- | --- | --- | --- | ---: | ---: | ---: |
| Shuttle | City Shuttle Shift | Spaceport → Market → Senate → Industrial → Market → Medical | Untimed | 120 | — | 0 |
| Shuttle | Spaceport Connection | Spaceport → Market | Untimed | 55 | 10 | 0 |
| Shuttle | Senate Staff Shuttle | Senate → Spaceport → Market → Senate | Untimed | 115 | 20 | 3 |
| Courier | Express Courier | Market → Industrial → Senate | 5 min | 100 | — | 0 |
| Courier | Fragile Technology | Industrial → Senate → Spaceport | 8 min | 125 | 20 | 0 |
| Courier | Medical Supply Run | Medical → Market | 5 min | 90 | 10 | 0 |
| Rescue | Emergency Transfer | Industrial → Medical | 5 min | 150 | — | 0 |
| Rescue | Clinic Evacuation | Industrial → Medical → Market → Medical | 10 min | 190 | 25 | 3 |
| Rescue | Senate Medical Response | Senate → Medical | 8 min | 170 | 20 | 8 |
| Patrol | District Patrol | Spaceport → Market → Senate → Industrial | Untimed | 80 | — | 0 |
| Patrol | Sky Lane Survey | Spaceport → Market → Medical | Untimed | 75 | 10 | 0 |
| Patrol | Deep Sensor Sweep | Senate → Industrial → Medical → Spaceport | Untimed | 120 | 20 | 3 |

Shuttle and rescue stops alternate pickup and drop-off. Courier packages are loaded on acceptance, with one delivery per stop. Standard service takes three active seconds. Sky Lane Survey scans take five; Deep Sensor Sweep scans take eight. Patrols are survey work and do not spawn an enemy attack wave.

## Condition and ratings

The condition percentage is a transport-quality score across the contract. It starts at 100 and falls during harsh flight with passengers, packages or a patient aboard. Medical transfers are more sensitive than ordinary passenger work. Hard banking beyond roughly 37 degrees, steep pitch beyond roughly 24 degrees and abrupt acceleration affect the score. Firing weapons with passengers aboard also reduces comfort.

Empty pickup legs, menus and docked service do not reduce condition. Ordinary gentle manoeuvres keep the score intact. A completed job always pays its advertised base reward; a poor rating never takes saved credits away.

| Condition | Stars |
| --- | --- |
| 95–100% | 5 |
| 85–94% | 4 |
| 70–84% | 3 |
| 50–69% | 2 |
| Below 50% | 1 |

Specialist transport bonuses require at least 95% condition, 20 seconds of actual flight carrying the load, and 1 km of payload flight. A survey bonus requires every scan, at least 20 seconds of flight and at least half the contract's between-stop distance, with a 1 km minimum. Completing stops without flying does not generate a bonus. Standard jobs retain their original fixed rewards.

## Licence progression

| Completed city jobs | Licence |
| ---: | --- |
| 0 | New Recruit |
| 3 | Licensed City Pilot |
| 8 | Senior City Pilot |
| 16 | Elite City Pilot |
| 30 | Coruscant Master |

Every completed city role counts. The career log keeps the last 20 debriefs and lifetime totals for passengers, deliveries, patients, scans and career earnings. Average condition uses transport jobs; patrols show a survey completion instead. Earlier job receipts count towards licences, while detailed ratings start with this version.

Credits and the debrief are stored in the same wallet save with the completion's unique receipt. A repeated claim cannot add money or career totals again. The existing credits, blueprints, ship unlocks, daily wheel and pilot logbook are preserved.

## City map

Open **Flight tools → Coruscant city map**, or **City map** on the job board. North is up, with equal horizontal scale on both axes. The chart shows five real skyports, the ship's position and heading, the active route and structure footprints. All skyports hold ships at 180 m altitude.

Tap a skyport to see its distance and height. Selection only inspects the station; it does not change the active job or skip stops. Use **Show current job destination** to highlight the required stop. Dashed lines show route order and are not a safe autopilot corridor: fly through clear avenues or above obstacles, then descend to the marked approach.
