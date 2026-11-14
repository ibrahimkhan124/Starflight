"""Reimport every exported ship and verify the actual game-delivery hierarchy.

Run with Blender --background --threads 2 --python-exit-code 1 --python
Tools/audit_ship_runtime.py. The JSON report covers the editable geometry and
the separately reimported runtime assets, rather than trusting exporter inputs.
"""
import bpy
import json
import sys
import subprocess
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_blender_asset_library import ROOT, SHIPS

report_path = ROOT / 'Art/BlenderLibrary/ship-refit-report.json'
report = json.loads(report_path.read_text())
keys = SHIPS + ['razorCrest', 'bWing', 'imperialShuttle', 'tieDefender', 'tieInterceptor', 'slaveI', 'scimitar']
for key in keys:
    path = ROOT / 'AlpineFlight/Resources/BlenderAssets/Ships' / ('Ship_'+key+'.usdz')
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.wm.usd_import(filepath=str(path))
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    expected = 2 if 'Podracer' in key else 1
    assert len(meshes) == expected, (key, 'runtime parts', len(meshes))
    # Blender collapses a single-mesh Xform when importing. Verify its actual
    # USD prim name as well, because RealityKit retains that semantic parent.
    stage = subprocess.run(['xcrun', 'usdcat', str(path), '--flatten'], capture_output=True, text=True, check=True).stdout
    assert 'def Xform "DetailedHull"' in stage, (key, 'missing static hull')
    front = bpy.data.objects.get('FlightForward')
    rear = bpy.data.objects.get('FlightRear')
    # USD Y-up is reimported into Blender Z-up here. Forward -Z in the game
    # therefore becomes +Y in Blender, which is the exported root's yaw.
    assert front and rear and front.matrix_world.translation.y > 0 and rear.matrix_world.translation.y < 0, (key, 'flight direction')
    if 'Podracer' in key:
        assert all(bpy.data.objects.get(name) for name in ('CockpitPod', 'LeftEngine', 'RightEngine')), (key, 'pod locators')
        assert any(o.name.startswith('podracer_energy_field') for o in bpy.data.objects), (key, 'animated binder')
    if key == 'millenniumFalcon':
        cockpit = bpy.data.objects.get('OffsetCockpit')
        assert cockpit and cockpit.matrix_world.translation.y > 0, (key, 'forward offset cockpit locator')
    triangles = 0
    sections = 0
    for mesh in meshes:
        mesh.data.calc_loop_triangles()
        triangles += len(mesh.data.loop_triangles)
        sections += len(mesh.data.materials)
        # Joining shared Blender materials deduplicates slots. Retaining a
        # repeated slot here would needlessly split RealityKit material work.
        materials = list(mesh.data.materials)
        assert len({m.as_pointer() for m in materials}) == len(materials), (key, 'duplicate material sections')
    assert triangles <= 40000 and sections <= 16, (key, triangles, sections)
    assert not report[key]['open_meshes'] and not report[key]['inward_meshes'], (key, 'source geometry')
    report[key].update(runtime_mesh_parts=len(meshes), runtime_material_sections=sections,
                       runtime_triangles=triangles, runtime_orientation_verified=True,
                       semantic_markers_verified=True, asset_bytes=path.stat().st_size)
    print('RUNTIME_AUDIT', key, triangles, 'triangles', len(meshes), 'meshes', sections, 'material sections', flush=True)
report_path.write_text(json.dumps(report, indent=2)+'\n')
print('All 28 exported ships passed runtime hierarchy, geometry-budget and marker checks.', flush=True)
