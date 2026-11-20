"""Bake small faceted scenery meshes for Starflight's Unreal planets."""
import math
from pathlib import Path
import random
import sys

import bpy

output = Path(sys.argv[-1])
output.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)


def export(obj, name):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    obj.name = name
    bpy.ops.export_scene.fbx(filepath=str(output / (name + ".fbx")),
                             use_selection=True, axis_forward="-Y", axis_up="Z")


def rock(name, layers, seed):
    randomizer = random.Random(seed)
    sides = 9
    angles = [(i + randomizer.uniform(-0.23, 0.23)) * math.tau / sides for i in range(sides)]
    vertices = []
    for height, radius, offset in layers:
        for angle in angles:
            size = radius * randomizer.uniform(0.76, 1.19)
            vertices.append((offset + math.cos(angle) * size,
                             math.sin(angle) * size,
                             height + randomizer.uniform(-0.08, 0.08)))
    faces = [list(reversed(range(sides)))]
    for ring in range(len(layers)-1):
        for i in range(sides):
            j = (i+1) % sides
            a, b = ring*sides+i, ring*sides+j
            c, d = a+sides, b+sides
            faces.extend(((a,b,c),(b,d,c)))
    faces.append(list(range(len(vertices)-sides, len(vertices))))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    export(obj, name)


rock("SM_GlacierRock", [(-0.49,0.44,-0.10),(-0.14,0.50,0.00),(0.24,0.35,0.10),(0.51,0.10,0.16)], 17)
rock("SM_SandstoneMesa", [(-0.50,0.52,0.00),(-0.12,0.35,-0.03),(0.08,0.42,-0.08),(0.51,0.29,-0.12)], 29)
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.5)
crown = bpy.context.object
for vertex in crown.data.vertices:
    p = vertex.co
    scale = 1.0 + math.sin(p.x*41+p.y*29)*math.cos(p.z*31-p.x*17)*0.19
    vertex.co = (p.x*scale,p.y*scale,p.z*scale)
export(crown, "SM_ForestCrown")
