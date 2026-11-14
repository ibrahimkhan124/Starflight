#!/usr/bin/env python3
"""Rebuild Blender sources, preview renders and bundled USDZ assets. Requires Xcode + Blender."""
import subprocess
from pathlib import Path
import tempfile
import sys
ROOT=Path(__file__).resolve().parents[1]
BLENDER='/Applications/Blender.app/Contents/MacOS/Blender'
LEVELS='alpine canyon glacier endor skylands volcano storm deathStar boontaEve sentinelOne ordIbanna andoPrime lantaana ordMantell corellia narShaddaa freeRoam'.split()
def run(*args): subprocess.run(args,cwd=ROOT,check=True)
with tempfile.TemporaryDirectory(prefix='alpine-surfaces-') as scratch:
    binary=str(Path(scratch)/'export')
    run('swiftc','AlpineFlight/Terrain/FlightLevel.swift','AlpineFlight/Terrain/CustomLevelDefinition.swift','AlpineFlight/Terrain/TerrainGenerator.swift','Tools/export_level_surfaces.swift','-o',binary)
    run(binary,'Art/LevelSurfaces')
run(BLENDER,'--background','--threads','2','--python-exit-code','1','--python','Tools/create_blender_library_v2.py','--','ships')
run(BLENDER,'--background','--threads','2','--python-exit-code','1','--python','Tools/create_razor_crest.py')
run(BLENDER,'--background','--threads','2','--python-exit-code','1','--python','Tools/improve_ship_models.py','--','all')
run(BLENDER,'--background','--threads','2','--python-exit-code','1','--python','Tools/audit_ship_runtime.py')
# Separate processes avoid accumulating Blender render/dependency-graph state across regions.
for level in LEVELS:
    run(BLENDER,'--background','--threads','2','--python-exit-code','1','--python','Tools/create_blender_library_v2.py','--','levels',level)
    run(BLENDER,'--background','--threads','2','--python-exit-code','1','--python','Tools/detail_blender_levels.py','--',level)
run(BLENDER,'--background','--threads','2','--python-exit-code','1','--python','Tools/export_engine_nozzles.py')
run(sys.executable,'Tools/verify_blender_assets.py')
print('Blender library rebuilt. Run the Xcode asset/collision tests before distributing.')
