"""Build Starflight's original Peregrine survey craft and export its static mesh."""
import math
import sys

import bpy

bpy.ops.wm.read_factory_settings(use_empty=True)


def paint(name, color, metallic=0.0, roughness=0.45):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1)
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    return material


alloy = paint("PearlAlloy", (0.55, 0.62, 0.65), 0.35)
dark = paint("Graphite", (0.036, 0.054, 0.073), 0.6)
copper = paint("RescueOrange", (0.85, 0.22, 0.04), 0.15)
glass = paint("Canopy", (0.012, 0.073, 0.105), 0.5, 0.16)
jets = paint("EngineGlow", (0.06, 0.7, 1.0))
brass = paint("Titanium", (0.24, 0.27, 0.30), 0.52)


def finish(obj, name, material, bevel=0.0):
    obj.name = name
    obj.data.materials.append(material)
    bpy.context.view_layer.objects.active = obj
    if bevel:
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        edge = obj.modifiers.new("Machined edges", "BEVEL")
        edge.width = bevel
        edge.segments = 2
        bpy.ops.object.modifier_apply(modifier=edge.name)
        normals = obj.modifiers.new("Panel normals", "WEIGHTED_NORMAL")
        bpy.ops.object.modifier_apply(modifier=normals.name)


def pod(name, loc, radius, depth, material):
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=radius, depth=depth,
                                       location=loc, rotation=(math.pi / 2, 0, 0))
    finish(bpy.context.object, name, material, 0.045)


def panel(name, shape, bottom, top, material, bevel):
    mesh = bpy.data.meshes.new(name)
    count = len(shape)
    vertices = [(x, y, z) for z in (bottom, top) for x, y in shape]
    faces = [list(reversed(range(count))), list(range(count, 2 * count))]
    faces += [(i, (i + 1) % count, (i + 1) % count + count, i + count) for i in range(count)]
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    finish(obj, name, material, bevel)


panel("Ventral centre", [(-1.6,-3.3),(1.6,-3.3),(1.3,2.8),(0,5.0),(-1.3,2.8)], -0.38, 0.56, alloy, 0.23)
panel("Canopy", [(-0.91,-0.45),(0.91,-0.45),(0.69,2.62),(0,3.32),(-0.69,2.62)], 0.45, 1.1, glass, 0.26)
panel("Sensor nose", [(-0.42,3.4),(0.42,3.4),(0,4.85)], 0.34, 0.57, dark, 0.07)
for side in (-1, 1):
    def wing(name, outline, low, high, material, bevel):
        polygon = [(side*x, y) for x, y in outline]
        panel(name, polygon if side == 1 else polygon[::-1], low, high, material, bevel)

    wing("Swept wing", [(1.2,-3.0),(4.9,-3.3),(5.35,-1.92),(1.2,1.95)], -0.27,0.25,alloy,0.12)
    wing("Rescue stripe", [(3.8,-3.0),(4.42,-3.12),(4.85,-2.05),(4.27,-1.57)], 0.23,0.28,copper,0.025)
    wing("Wing brace", [(1.1,-2.7),(2.5,-2.55),(2.65,-1.35),(1.25,-0.05)],0.21,0.38,dark,0.08)
    wing("Wingtip navigation housing", [(4.64,-3.2),(4.95,-3.2),(5.25,-2.13),(4.96,-2.2)],0.17,0.37,dark,0.06)
    for i in range(6):
        y=-0.95-i*0.29
        wing("Cooling grille",[(0.96,y-0.14),(1.49,y-0.14),(1.48,y),(0.96,y)],0.56,0.64,brass,0.018)
    pod("Engine nacelle", (side*2.9,-1.72,0.42), 0.71, 3.84, dark)
    pod("Nacelle armour", (side*2.9,-1.49,0.42), 0.76, 2.41, alloy)
    pod("Thrust collar", (side*2.9,-3.29,0.42), 0.77, 0.44, copper)
    pod("Machined nozzle", (side*2.9,-3.61,0.42), 0.60, 0.44, brass)
    pod("Ion core", (side*2.9,-3.84,0.42), 0.43, 0.04, jets)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.join()
bpy.context.object.name = "SM_Peregrine"
bpy.ops.export_scene.fbx(filepath=sys.argv[-1], use_selection=True, axis_forward="-Y",
                         axis_up="Z", apply_unit_scale=True, add_leaf_bones=False)
