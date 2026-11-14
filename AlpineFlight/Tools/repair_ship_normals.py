"""Repair the existing editable ships and re-export, without regenerating artwork.
Run with Blender --background --python Tools/repair_ship_normals.py.
Only closed mesh components are reoriented; authored open surfaces are retained.
"""
from pathlib import Path
import sys
import bpy
import bmesh

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'Tools'))
from create_blender_library_v2 import usd

for source in sorted((ROOT / 'Art/BlenderLibrary/Ships').glob('Ship_*.blend')):
    bpy.ops.wm.open_mainfile(filepath=str(source))
    root = bpy.data.objects.get(source.stem)
    if root is None:
        raise RuntimeError(f'Missing ship root: {source.stem}')
    fixed = 0
    for obj in root.children_recursive:
        if obj.type != 'MESH':
            continue
        # The original TIE panels were coincident sheets with no side walls.
        if obj.name.startswith('HexagonalSolarPanel') and len(obj.data.vertices) == 6:
            points = [tuple(vertex.co) for vertex in obj.data.vertices]
            vertices = [(x-.06,y,z) for x,y,z in points] + [(x+.06,y,z) for x,y,z in points]
            faces = [tuple(reversed(range(6))), tuple(range(6,12))]
            faces += [(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)]
            obj.data.clear_geometry()
            obj.data.from_pydata(vertices, [], faces)
            obj.data.update()
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        if bm.faces and all(edge.is_manifold for edge in bm.edges):
            before = bm.calc_volume(signed=True)
            if abs(before) < 1e-7:
                bm.free()
                continue
            bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
            if bm.calc_volume(signed=True) < 0:
                bmesh.ops.reverse_faces(bm, faces=list(bm.faces))
            after = bm.calc_volume(signed=True)
            if after <= 0:
                raise RuntimeError(f'Invalid closed mesh: {source.stem}/{obj.name}')
            if before < 0:
                fixed += 1
            bm.to_mesh(obj.data)
            obj.data.update()
        bm.free()
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    for obj in root.children_recursive:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    destination = ROOT / 'AlpineFlight/Resources/BlenderAssets/Ships' / (source.stem + '.usdz')
    usd(destination)
    print(f'REPAIRED {source.stem}: {fixed} inward mesh components', flush=True)
