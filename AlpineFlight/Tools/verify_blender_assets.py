#!/usr/bin/env python3
"""Check every ship and both LODs of every sampled Blender terrain tile before a build."""
from pathlib import Path
import json,zipfile,re
ROOT=Path(__file__).resolve().parents[1]
assets=ROOT/'AlpineFlight/Resources/BlenderAssets'
errors=[];count=0
for sample in sorted((ROOT/'Art/LevelSurfaces').glob('*.json')):
    level=json.loads(sample.read_text())
    for tile in level['tiles']:
        for divisions in (24,8):
            path=assets/'Terrain'/level['level']/f"{tile['x']}_{tile['z']}_{divisions}.usdz"
            if not path.exists() or not zipfile.is_zipfile(path):errors.append(str(path))
            count+=1
    if not (ROOT/'Art/BlenderLibrary/Levels'/f"Level_{level['level']}.blend").exists():errors.append(sample.stem+' source')
ships=list((assets/'Ships').glob('*.usdz'))
swift=(ROOT/'AlpineFlight/Flight/AircraftType.swift').read_text().split('var id:')[0]
expected={name.strip() for group in re.findall(r'^\s*case ([^\n]+)',swift,re.M) for name in group.split(',')}
actual={path.stem.removeprefix('Ship_') for path in ships}
if actual!=expected:errors.append(f'Ship fleet mismatch: missing={sorted(expected-actual)} extra={sorted(actual-expected)}')
for path in ships:
    if not zipfile.is_zipfile(path):errors.append(str(path))
    if not (ROOT/'Art/BlenderLibrary/Ships'/(path.stem+'.blend')).exists():errors.append(path.stem+' source')
report_path=ROOT/'Art/BlenderLibrary/ship-refit-report.json'
if report_path.exists():
    report=json.loads(report_path.read_text())
    for key in expected:
        audit=report.get(key,{})
        path=assets/'Ships'/('Ship_'+key+'.usdz')
        if (audit.get('detail_version') != 2 or audit.get('open_meshes') or audit.get('inward_meshes')
            or not audit.get('runtime_orientation_verified') or not audit.get('semantic_markers_verified')
            or audit.get('runtime_triangles',40001)>40000 or audit.get('runtime_material_sections',17)>16
            or audit.get('runtime_mesh_parts') != (2 if 'Podracer' in key else 1)
            or path.exists() and audit.get('asset_bytes') != path.stat().st_size):
            errors.append(key+' missing or stale fleet runtime audit; run Tools/audit_ship_runtime.py in Blender')
if errors:raise SystemExit('Missing or invalid assets:\n'+'\n'.join(errors[:30])+f'\n{len(errors)} total')
print(f'Validated {len(ships)} ships and {count} terrain LOD assets across 17 Blender levels.')
