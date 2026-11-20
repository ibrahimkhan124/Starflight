"""Author the reusable broadleaf tree used around Endor's lakes."""
import math
from pathlib import Path
import random
import sys

import bpy
from mathutils import Vector

out = Path(sys.argv[-1])
out.mkdir(exist_ok=True, parents=True)
rng = random.Random(24417)
bpy.ops.wm.read_factory_settings(use_empty=True)


def write_mesh(name, vertices, polygons, tints=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], polygons)
    mesh.update()
    if tints is not None:
        colors = mesh.color_attributes.new(name="LeafPalette", type="FLOAT_COLOR", domain="CORNER")
        for face, tint in zip(mesh.polygons, tints, strict=True):
            for corner in face.loop_indices:
                colors.data[corner].color = tint
    else:
        for face in mesh.polygons:
            face.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.fbx(filepath=str(out / (name+".fbx")), use_selection=True, axis_forward="-Y",
                             axis_up="Z", mesh_smooth_type="FACE", colors_type="LINEAR")


wood, bark_faces, leaves, leaf_faces, palette = [], [], [], [], []


def wooden_path(points, radii, sides):
    base = len(wood)
    for i, p in enumerate(points):
        direction = (points[min(i+1, len(points)-1)]-points[max(0, i-1)]).normalized()
        right = direction.cross(Vector((0, 1, 0))).normalized()
        across = direction.cross(right).normalized()
        for j in range(sides):
            theta = math.tau*j/sides
            offset = (math.cos(theta)*right+math.sin(theta)*across)*radii[i]
            wood.append(p+offset*rng.uniform(0.87, 1.13))
    for row in range(len(points)-1):
        for j in range(sides):
            a, b = base+row*sides+j, base+row*sides+(j+1)%sides
            bark_faces.append((a,b,b+sides,a+sides))
    bark_faces.append(tuple(reversed(range(base,base+sides))))
    bark_faces.append(tuple(range(len(wood)-sides,len(wood))))


def foliage(centre, width, count):
    for _ in range(count):
        theta = rng.uniform(0,math.tau)
        elev = rng.uniform(-1,1)
        radial = rng.uniform(0.34,1.0) ** (1/3)
        spread=math.sqrt(1-elev*elev)
        point=centre+width*radial*Vector((spread*math.cos(theta),spread*math.sin(theta),elev*0.57))
        direction=Vector((math.sin(theta),math.cos(theta),rng.uniform(-0.64,0.64))).normalized()
        across=direction.cross(Vector((0,0,1))).normalized()
        size=rng.uniform(0.29,0.78)
        tip=direction*size
        edge=across*size*0.42
        base=len(leaves)
        leaves.extend((point-tip,point-edge,point+tip,point+edge))
        leaf_faces.append((base,base+1,base+2,base+3))
        tint=rng.uniform(0.66,1.28)
        sun=rng.uniform(0.45,1.0)
        palette.append((0.021*tint*sun,0.105*tint,0.023*tint,1))

points=[Vector(p) for p in [(0,0,-0.5),(0.06,-0.1,1.2),(0.25,0.07,4),(0.20,0.32,9),(-0.36,0.42,13.8)]]
wooden_path(points,[0.87,0.62,0.5,0.33,0.045],10)
for i in range(7):
    angle=i*2.39996
    radial=Vector((math.cos(angle),math.sin(angle),0))
    foot=radial*rng.uniform(1.2,2.2)
    wooden_path([Vector((0,0,0.7)),foot*0.55+Vector((0,0,0.25)),foot],[0.33,0.23,0.035],6)

for i in range(12):
    angle=i*2.39996
    radial=Vector((math.cos(angle),math.sin(angle),0))
    h=5.3+(i%8)*0.83
    reach=rng.uniform(2.25,5.0)*(1-0.20*(h-5.3)/6)
    centre=Vector((0.20,0.23,h))
    outer=centre+reach*radial+Vector((0,0,rng.uniform(1.2,3.1)))
    joint=centre.lerp(outer,0.56)-Vector((0,0,0.37))
    wooden_path([centre,joint,outer],[0.28,0.16,0.027],7)
    foliage(outer,2.15,110)
    side=Vector((-radial.y,radial.x,0))*rng.choice([-1,1])
    sprig=joint+side*rng.uniform(1.0,1.7)+Vector((0,0,1.27))
    wooden_path([joint,joint.lerp(sprig,0.52),sprig],[0.111,0.071,0.016],6)
    foliage(sprig,1.58,74)
foliage(Vector((0.03,0.25,13.55)),2.56,170)
write_mesh("SM_ShoreBark",wood,bark_faces)
write_mesh("SM_ShoreLeaves",leaves,leaf_faces,palette)
