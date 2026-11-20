"""Export the project's canonical Blender ships as single-draw mesh sources."""
import math
import re
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

source, output = map(Path, sys.argv[-2:])
output.mkdir(parents=True, exist_ok=True)


def surface_color(material):
    if not material:
        return (0.42, 0.47, 0.53, 0)
    shader = next((node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED"), None) if material.node_tree else None
    color = shader.inputs["Base Color"].default_value if shader else material.diffuse_color
    if shader and shader.inputs["Emission Strength"].default_value > 0.15:
        color = shader.inputs["Emission Color"].default_value
        if max(color[:3]) > 0.05:
            return (*color[:3], 1)
    return (*color[:3], 0)


for path in sorted(source.glob("Ship_*.blend")):
    if not re.fullmatch(r"Ship_[A-Za-z0-9]+", path.stem):
        continue  # Finder copies and Blender autosaves are outside the fleet.
    bpy.ops.wm.open_mainfile(filepath=str(path), load_ui=False, use_scripts=False)
    bpy.context.view_layer.update()
    front = bpy.data.objects.get("FlightForward")
    rear = bpy.data.objects.get("FlightRear")
    heading = front.matrix_world.translation - rear.matrix_world.translation if front and rear else Vector((0, 1, 0))
    align = Matrix.Rotation(math.pi / 2 - math.atan2(heading.y, heading.x), 4, "Z")
    depsgraph = bpy.context.evaluated_depsgraph_get()
    positions, faces, colors = [], [], []
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH" or obj.hide_render or obj.name.startswith(("Collision", "Proxy")):
            continue
        baked = obj.evaluated_get(depsgraph)
        mesh = baked.to_mesh()
        if mesh is None:
            continue
        base = len(positions)
        transform = align @ obj.matrix_world
        positions.extend(transform @ vert.co for vert in mesh.vertices)
        reverse = transform.to_3x3().determinant() < 0
        for polygon in mesh.polygons:
            face = [base + index for index in polygon.vertices]
            faces.append(face[::-1] if reverse else face)
            material = mesh.materials[polygon.material_index] if polygon.material_index < len(mesh.materials) else None
            colors.append(surface_color(material))
        baked.to_mesh_clear()

    if not faces:
        raise RuntimeError(f"{path.name} has no visible geometry")
    name = path.stem.replace("Ship_", "SM_Fleet_", 1)
    joined = bpy.data.meshes.new(name)
    joined.from_pydata(positions, [], faces)
    joined.update()
    tint = joined.color_attributes.new(name="FleetPaint", type="FLOAT_COLOR", domain="CORNER")
    for polygon, color in zip(joined.polygons, colors, strict=True):
        for index in polygon.loop_indices:
            tint.data[index].color = color
    obj = bpy.data.objects.new(name, joined)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    joined.materials.append(bpy.data.materials.new("FleetPaint"))
    bpy.ops.export_scene.fbx(filepath=str(output / f"{name}.fbx"), use_selection=True,
                             axis_forward="-Y", axis_up="Z", apply_unit_scale=True,
                             mesh_smooth_type="FACE", colors_type="LINEAR", add_leaf_bones=False)
    print(f"STARFLIGHT_FLEET_EXPORT {name} {len(positions)} vertices {len(faces)} faces", flush=True)
