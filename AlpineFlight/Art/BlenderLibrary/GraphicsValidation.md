# Fleet and scenery validation — 20 October 2026

All 25 canonical Blender ships were refitted and re-exported. The B-wing,
Imperial Shuttle and TIE Defender are included. The saved sources retain editable
parts; the game exports combine static geometry while preserving animated pod
energy binders and semantic locators. Previous files are preserved under
`Backups/2026-10-20-scenic-fleet`.

The source and USDZ reimport audits passed for all ships: closed source meshes,
outward normals, correct forward markers, retained pod features, and no duplicate
runtime material slots. Maximum runtime geometry is 26,212 triangles and 13
material sections. Ships use one static mesh; pods use two meshes in total.

The final Mac Catalyst Debug and signed iOS Release builds passed. The final
simulator run passed 11 focused unit checks and two UI checks, with no failures.
These cover all ship dimensions/facing/batching, retained pod features, terrain
triangle/collision alignment, continuous finite terrain normals, scenery collision,
clear checkpoints and racing lines, planet routes, asteroid collision bounds,
and planet detail budgets. The restored Falcon cockpit marker is included.

The UI checks captured four terrain scenes plus space free roam and all four
planet surfaces. Earlier interaction checks also passed on eight additional
region selections and the Falcon/Voltwing flight-and-restart flow. Current
captures are linked in `Previews/index.html`; development Blender terrain previews
are labelled separately from the shipping procedural scenery.

The new region scenery uses seven material batches. It is prepared before terrain
readiness is published, and the collision spatial hash uses the same tapered solids.
An independent corridor check sampled all eight race circuits every 20 metres
across 25 lateral positions and found no new scenery in otherwise flyable track.
Reduced planet detail keeps the complete map but simplifies windows, crowns and
traffic. Measured mesh budgets in the tests range from 155,832 to 374,488 triangles
in reduced mode, and 164,352 to 550,584 in full detail. These are geometry counts,
not sustained hardware frame-rate measurements.

Final test result:
`/tmp/Starflight-Planet-Final/Logs/Test/Test-AlpineFlight-2026.10.20_19-25-08-+0100.xcresult`

Build logs:
`/tmp/starflight-scenic-mac-shading.log`
`/tmp/starflight-scenic-ios-shading.log`

Fleet evidence: `ship-refit-report.json` and `Tools/audit_ship_runtime.py`.
