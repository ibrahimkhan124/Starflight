"""Export nozzle coordinates from the editable fleet for runtime exhaust alignment."""
import bpy, json, re
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
source=(ROOT/'AlpineFlight/Flight/AircraftType.swift').read_text().split('var id:')[0]
keys=[key.strip() for line in re.findall(r'^\s*case ([^\n]+)',source,re.M) for key in line.split(',')]
records={}
for key in keys:
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'Art/BlenderLibrary/Ships'/f'Ship_{key}.blend'))
    root=bpy.data.objects['Ship_'+key]
    meshes=[o for o in root.children_recursive if o.type=='MESH']
    points=[o.matrix_world @ Vector(p) for o in meshes for p in o.bound_box]
    width=max(p.x for p in points)-min(p.x for p in points)
    length=max(p.y for p in points)-min(p.y for p in points)
    nozzles=[]
    for obj in meshes:
        if 'plasma' not in obj.name.lower():continue
        corners=[obj.matrix_world @ Vector(p) for p in obj.bound_box]
        center=sum(corners,Vector())/8
        radius=(max(p.x for p in corners)-min(p.x for p in corners))/2
        nozzles.append({'position':[center.x,center.z,-center.y],'radius':radius})
    if nozzles:records[key]={'width':width,'length':length,'nozzles':nozzles[:4]}
path=ROOT/'AlpineFlight/Resources/BlenderAssets/Ships/EngineNozzles.json'
path.write_text(json.dumps(records,indent=2)+'\n')
print('NOZZLE_LAYOUTS',len(records),'ships',flush=True)
