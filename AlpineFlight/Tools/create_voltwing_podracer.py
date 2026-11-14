"""Build the original Voltwing Podracer and export it for RealityKit.

Run with:
  /Applications/Blender.app/Contents/MacOS/Blender --background --python Tools/create_voltwing_podracer.py
"""

from pathlib import Path
import bpy
import math
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
BLEND_PATH = ROOT / "Art" / "Blender" / "VoltwingPodracer.blend"
USDZ_PATH = ROOT / "AlpineFlight" / "Resources" / "Models" / "VoltwingPodracer.usdz"
PREVIEW_PATH = ROOT / "Art" / "Blender" / "VoltwingPodracer-preview.png"


def material(name, color, metallic=0.0, roughness=0.4, emission=None):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 7.0
    return mat


def finish(obj, name, mat, parent, bevel=0.12):
    obj.name = name
    obj.data.name = f"{name}Mesh"
    obj.data.materials.append(mat)
    obj.parent = parent
    if bevel:
        modifier = obj.modifiers.new("Soft industrial edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    return obj


def cube(name, location, scale, mat, parent, bevel=0.12):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, parent, bevel)


def sphere(name, location, scale, mat, parent, segments=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=12, location=location)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, parent, 0)


def cylinder(name, location, radius, depth, mat, parent, vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location,
                                       rotation=(math.pi / 2, 0, 0))
    return finish(bpy.context.object, name, mat, parent, 0.1)


def cone(name, location, radius1, radius2, depth, mat, parent, vertices=24):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius1, radius2=radius2, depth=depth,
                                   location=location, rotation=(math.pi / 2, 0, 0))
    return finish(bpy.context.object, name, mat, parent, 0.06)


def torus(name, location, major_radius, minor_radius, mat, parent):
    bpy.ops.mesh.primitive_torus_add(major_radius=major_radius, minor_radius=minor_radius,
                                    major_segments=24, minor_segments=8, location=location,
                                    rotation=(math.pi / 2, 0, 0))
    return finish(bpy.context.object, name, mat, parent, 0)


def tube(name, points, radius, mat, parent):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, coordinate in zip(spline.points, points):
        point.co = (*coordinate, 1.0)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    curve.materials.append(mat)
    obj.parent = parent
    return obj


bpy.ops.wm.read_factory_settings(use_empty=True)

root = bpy.data.objects.new("VoltwingPodracer", None)
bpy.context.collection.objects.link(root)

blue = material("Voltwing Blue", (0.035, 0.18, 0.42), metallic=0.82, roughness=0.23)
silver = material("Brushed Beskar Alloy", (0.42, 0.48, 0.53), metallic=0.94, roughness=0.28)
dark = material("Carbon Armor", (0.018, 0.025, 0.038), metallic=0.62, roughness=0.2)
orange = material("Racing Stripe", (0.95, 0.24, 0.035), metallic=0.25, roughness=0.3)
cyan = material("Energy Binder", (0.04, 0.45, 1.0), roughness=0.08, emission=(0.05, 0.62, 1.0))
hot = material("Engine Plasma", (1.0, 0.24, 0.025), roughness=0.1, emission=(1.0, 0.12, 0.01))
amber = material("Warning Lamps", (1.0, 0.62, 0.04), roughness=0.1, emission=(1.0, 0.35, 0.01))

# Rear control pod and exposed frame.
sphere("CockpitPod", (0, 5.0, 1.15), (1.45, 2.5, 0.85), blue, root)
sphere("Canopy", (0, 4.25, 1.85), (1.0, 1.25, 0.43), dark, root)
for side in (-1, 1):
    tube(f"CanopyRail{'L' if side < 0 else 'R'}",
         [(side * 0.82, 3.35, 1.75), (side * 0.95, 4.3, 2.2), (side * 0.75, 5.25, 1.8)],
         0.07, silver, root)
cube("NoseBlade", (0, 2.6, 0.95), (0.55, 1.9, 0.24), orange, root)
cube("TailFin", (0, 6.5, 2.1), (0.12, 1.15, 0.9), orange, root)
cube("PilotSeat", (0, 5.2, 1.3), (0.65, 0.72, 0.55), dark, root)
cube("LeftCockpitWing", (-1.75, 5.2, 0.95), (1.2, 1.65, 0.12), blue, root)
cube("RightCockpitWing", (1.75, 5.2, 0.95), (1.2, 1.65, 0.12), blue, root)
for index, x in enumerate((-0.55, 0, 0.55)):
    sphere(f"DashLamp{index + 1}", (x, 3.55, 1.72), (0.09, 0.09, 0.09), amber, root, 12)

# Twin turbines. Asymmetrical armor makes the Blender asset easy to distinguish.
for side in (-1, 1):
    x = side * 11.5
    cylinder(f"{'Left' if side < 0 else 'Right'}Engine", (x, -2.2, 1.05), 1.85, 10.8, silver, root, 20)
    cylinder(f"{'Left' if side < 0 else 'Right'}Intake", (x, -7.65, 1.05), 2.08, 0.55, dark, root, 20)
    torus(f"{'Left' if side < 0 else 'Right'}IntakeRing", (x, -7.98, 1.05), 1.72, 0.22, orange, root)
    cylinder(f"{'Left' if side < 0 else 'Right'}FanHub", (x, -8.02, 1.05), 0.35, 0.3, silver, root, 16)
    for blade_index in range(8):
        angle = blade_index * math.pi / 4
        blade = cube(f"{'Left' if side < 0 else 'Right'}FanBlade{blade_index + 1}",
                     (x + math.cos(angle) * 0.95, -8.05, 1.05 + math.sin(angle) * 0.95),
                     (0.72, 0.06, 0.13), dark, root, 0.025)
        blade.rotation_euler[1] = -angle
    cylinder(f"{'Left' if side < 0 else 'Right'}Exhaust", (x, 3.25, 1.05), 1.35, 0.5, hot, root, 20)
    cone(f"{'Left' if side < 0 else 'Right'}ExhaustNozzle", (x, 3.65, 1.05), 1.58, 1.15, 1.1, dark, root, 20)
    sphere(f"{'Left' if side < 0 else 'Right'}PlasmaCore", (x, 4.18, 1.05), (1.05, 0.18, 1.05), hot, root, 16)
    cube(f"{'Left' if side < 0 else 'Right'}Armor", (x, -1.8, 2.35), (2.25, 3.1, 0.23), blue, root)
    cube(f"{'Left' if side < 0 else 'Right'}Stripe", (x, -2.4, 2.61), (0.38, 2.8, 0.05), orange, root, 0.03)
    for panel_index, y in enumerate((-5.5, -3.4, -0.9, 1.0)):
        torus(f"{'Left' if side < 0 else 'Right'}EngineBand{panel_index + 1}",
              (x, y, 1.05), 1.87, 0.08, dark, root)
    cube(f"{'Left' if side < 0 else 'Right'}CoolingFin", (x + side * 2.05, -1.1, 1.15),
         (0.1, 2.65, 1.35), orange, root, 0.05)
    for greeble_index, y in enumerate((-4.6, -2.7, -0.6, 1.4)):
        cube(f"{'Left' if side < 0 else 'Right'}ServiceBlock{greeble_index + 1}",
             (x - side * 1.72, y, 1.0), (0.18, 0.38, 0.3), dark, root, 0.03)
    tube(f"{'Left' if side < 0 else 'Right'}ControlCable",
         [(0, 3.7, 1.0), (side * 3.5, 2.0, 1.0), (side * 7.2, 0.2, 1.0), (x, -0.8, 1.0)],
         0.12, dark, root)

# Jagged energy binder between the engines.
arc = []
for index in range(13):
    x = -9.5 + index * (19.0 / 12.0)
    y = -3.0 + (0.38 if index % 2 == 0 else -0.38)
    z = 1.1 + ((index % 3) - 1) * 0.2
    arc.append((x, y, z))
tube("podracer energy field", arc, 0.14, cyan, root)
arc_lower = [(x, y + 0.15, z - 0.55) for x, y, z in reversed(arc)]
tube("EnergyFieldLower", arc_lower, 0.075, cyan, root)
for side in (-1, 1):
    sphere(f"EnergyEmitter{'L' if side < 0 else 'R'}", (side * 9.65, -3.0, 1.08),
           (0.45, 0.45, 0.45), cyan, root, 16)

# Repulsor emitters underneath the craft.
for side in (-1, 1):
    sphere(f"RepulsorGlow{'L' if side < 0 else 'R'}", (side * 4.0, 3.9, 0.15), (1.5, 1.8, 0.12), cyan, root, 16)

# Apply transforms so exported dimensions and hierarchy are predictable.
bpy.context.view_layer.objects.active = root
root.select_set(True)
for obj in bpy.context.scene.objects:
    obj.select_set(True)

BLEND_PATH.parent.mkdir(parents=True, exist_ok=True)
USDZ_PATH.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
bpy.ops.wm.usd_export(
    filepath=str(USDZ_PATH),
    selected_objects_only=True,
    export_materials=True,
    generate_preview_surface=True,
    export_uvmaps=True,
    export_normals=True,
    export_textures=True,
    convert_orientation=True,
    export_global_forward_selection="NEGATIVE_Z",
    export_global_up_selection="Y",
    root_prim_path="/VoltwingPodracer",
)

print(f"Saved Blender source: {BLEND_PATH}")
print(f"Exported RealityKit asset: {USDZ_PATH}")

# Render a deterministic QA preview after export; camera and lights are not included in the game asset.
floor_mat = material("Preview Floor", (0.012, 0.016, 0.026), metallic=0.15, roughness=0.32)
bpy.ops.mesh.primitive_plane_add(size=90, location=(0, 0, -0.15))
floor = bpy.context.object
floor.data.materials.append(floor_mat)

bpy.ops.object.light_add(type="AREA", location=(8, 10, 24))
key = bpy.context.object
key.data.energy = 1800
key.data.shape = "DISK"
key.data.size = 12
bpy.ops.object.light_add(type="AREA", location=(-20, -8, 10))
fill = bpy.context.object
fill.data.energy = 1300
fill.data.color = (0.08, 0.32, 1.0)
fill.data.size = 10
bpy.ops.object.light_add(type="AREA", location=(20, 1, 5))
rim = bpy.context.object
rim.data.energy = 1000
rim.data.color = (1.0, 0.18, 0.03)
rim.data.size = 8

bpy.ops.object.camera_add(location=(30, 28, 19))
camera = bpy.context.object
camera.data.lens = 52
camera.rotation_euler = (Vector((0, -1.2, 1.0)) - camera.location).to_track_quat("-Z", "Y").to_euler()
bpy.context.scene.camera = camera
bpy.context.scene.render.engine = "BLENDER_EEVEE_NEXT"
bpy.context.scene.render.resolution_x = 1000
bpy.context.scene.render.resolution_y = 700
bpy.context.scene.render.resolution_percentage = 100
bpy.context.scene.render.image_settings.file_format = "PNG"
bpy.context.scene.render.filepath = str(PREVIEW_PATH)
if bpy.context.scene.world is None:
    bpy.context.scene.world = bpy.data.worlds.new("Preview World")
bpy.context.scene.world.color = (0.004, 0.006, 0.015)
bpy.context.scene.render.film_transparent = False
bpy.ops.render.render(write_still=True)
print(f"Rendered QA preview: {PREVIEW_PATH}")
