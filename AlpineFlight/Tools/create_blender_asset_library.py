"""Generate the complete Blender-authored ship and level-art library for AlpineFlight."""

from pathlib import Path
import bpy
import math

ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOT = ROOT / "Art" / "BlenderLibrary"
ASSET_ROOT = ROOT / "AlpineFlight" / "Resources" / "BlenderAssets"

SHIPS = [
    "kestrel", "meridian", "falcon", "atlas", "xwing", "tieFighter", "millenniumFalcon",
    "aWing", "yWing", "n1Starfighter", "enterprise", "voyager", "birdOfPrey", "starkJet",
    "novaSkiff", "anakinPodracer", "sebulbaPodracer", "quadinPodracer", "rattsPodracer",
    "nevaKeePodracer", "voltwingPodracer",
]

LEVELS = [
    "alpine", "canyon", "glacier", "endor", "skylands", "volcano", "storm", "deathStar",
    "boontaEve", "sentinelOne", "ordIbanna", "andoPrime", "lantaana", "ordMantell",
    "corellia", "narShaddaa", "freeRoam",
]

PALETTES = {
    "alpine": ((0.55, 0.7, 0.82), (0.86, 0.94, 1.0)),
    "canyon": ((0.48, 0.19, 0.07), (0.94, 0.48, 0.12)),
    "glacier": ((0.45, 0.34, 0.22), (0.82, 0.66, 0.4)),
    "endor": ((0.025, 0.16, 0.055), (0.18, 0.42, 0.12)),
    "skylands": ((0.65, 0.38, 0.17), (1.0, 0.68, 0.26)),
    "volcano": ((0.08, 0.025, 0.015), (1.0, 0.16, 0.015)),
    "storm": ((0.09, 0.025, 0.15), (0.8, 0.08, 0.45)),
    "deathStar": ((0.11, 0.13, 0.16), (0.65, 0.08, 0.04)),
    "boontaEve": ((0.5, 0.25, 0.08), (1.0, 0.58, 0.08)),
    "sentinelOne": ((0.1, 0.025, 0.015), (1.0, 0.2, 0.02)),
    "ordIbanna": ((0.42, 0.21, 0.08), (0.9, 0.42, 0.1)),
    "andoPrime": ((0.28, 0.5, 0.68), (0.82, 0.96, 1.0)),
    "lantaana": ((0.025, 0.17, 0.06), (0.22, 0.62, 0.17)),
    "ordMantell": ((0.15, 0.11, 0.08), (0.8, 0.31, 0.08)),
    "corellia": ((0.12, 0.2, 0.3), (0.22, 0.7, 1.0)),
    "narShaddaa": ((0.07, 0.015, 0.13), (0.95, 0.08, 0.72)),
    "freeRoam": ((0.08, 0.14, 0.25), (0.28, 0.68, 1.0)),
}


def mat(name, color, metallic=0.0, roughness=0.4, emission=None):
    value = bpy.data.materials.new(name)
    value.diffuse_color = (*color, 1)
    value.use_nodes = True
    shader = value.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    if emission:
        shader.inputs["Emission Color"].default_value = (*emission, 1)
        shader.inputs["Emission Strength"].default_value = 5
    return value


def finish(obj, name, material, root, bevel=0.08):
    obj.name = name
    if obj.data:
        obj.data.name = f"{name}Mesh"
        obj.data.materials.append(material)
    obj.parent = root
    if bevel and obj.type == "MESH":
        mod = obj.modifiers.new("Edge bevel", "BEVEL")
        mod.width, mod.segments = bevel, 2
    return obj


def cube(name, pos, scale, material, root, bevel=0.08):
    bpy.ops.mesh.primitive_cube_add(location=pos)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, material, root, bevel)


def sphere(name, pos, scale, material, root, segments=20):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=10, location=pos)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, material, root, 0)


def cylinder(name, pos, radius, depth, material, root, axis="Y", vertices=20):
    rotation = (math.pi / 2, 0, 0) if axis == "Y" else (0, math.pi / 2, 0) if axis == "X" else (0, 0, 0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=pos, rotation=rotation)
    return finish(bpy.context.object, name, material, root, 0.06)


def cone(name, pos, radius, depth, material, root, vertices=8):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=0, depth=depth, location=pos)
    return finish(bpy.context.object, name, material, root, 0.04)


def torus(name, pos, major, minor, material, root, axis="Y"):
    rotation = (math.pi / 2, 0, 0) if axis == "Y" else (0, 0, 0)
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=20,
                                    minor_segments=6, location=pos, rotation=rotation)
    return finish(bpy.context.object, name, material, root, 0)


def tube(name, points, radius, material, root):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions, curve.bevel_depth, curve.bevel_resolution = "3D", radius, 1
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for dst, src in zip(spline.points, points):
        dst.co = (*src, 1)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    curve.materials.append(material)
    obj.parent = root
    return obj


def export_asset(root, source, destination):
    source.parent.mkdir(parents=True, exist_ok=True)
    destination.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    bpy.ops.wm.usd_export(filepath=str(destination), selected_objects_only=True, export_materials=True,
                          generate_preview_surface=True, export_uvmaps=True, export_normals=True,
                          export_textures=True, export_curves=True, convert_orientation=True,
                          export_global_forward_selection="NEGATIVE_Z", export_global_up_selection="Y",
                          root_prim_path=f"/{root.name}")


def build_pod(key, root, paint, metal, dark, glow, accent):
    variants = {
        "anakinPodracer": (11.2, 1.55, 10.5), "sebulbaPodracer": (14.2, 2.2, 11.2),
        "quadinPodracer": (13.0, 1.7, 9.6), "rattsPodracer": (9.3, 1.25, 8.7),
        "nevaKeePodracer": (15.2, 2.3, 11.5), "voltwingPodracer": (11.5, 1.85, 10.8),
    }
    spacing, radius, length = variants[key]
    sphere("CockpitPod", (0, 5, 1.1), (1.25, 2.35, 0.82), paint, root)
    sphere("Canopy", (0, 4.15, 1.75), (0.85, 1.15, 0.38), dark, root)
    cube("TailFin", (0, 6.3, 2), (0.12, 1.1, 0.85), accent, root)
    count = 4 if key == "quadinPodracer" else 2
    engine_xs = [-spacing, spacing] if count == 2 else [-spacing * 1.25, -spacing * .7, spacing * .7, spacing * 1.25]
    for index, x in enumerate(engine_xs):
        cylinder(f"Engine{index + 1}", (x, -2, 1), radius * (0.82 if count == 4 else 1), length, metal, root)
        torus(f"IntakeRing{index + 1}", (x, -2 - length / 2, 1), radius * .82, radius * .12, accent, root)
        sphere(f"ExhaustGlow{index + 1}", (x, -2 + length / 2, 1), (radius * .62, .18, radius * .62), glow, root, 14)
        cube(f"EngineArmor{index + 1}", (x, -1.8, 1 + radius), (radius * 1.15, length * .25, .15), paint, root)
        tube(f"ControlCable{index + 1}", [(0, 3.5, 1), (x * .45, 1.8, 1), (x, -.5, 1)], .1, dark, root)
    points = []
    for i in range(11):
        x = -spacing * .82 + i * spacing * 1.64 / 10
        points.append((x, -3 + (.3 if i % 2 else -.3), 1 + ((i % 3) - 1) * .15))
    tube("podracer_energy_field", points, .12, glow, root)


def build_ship(key):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    root = bpy.data.objects.new(f"Ship_{key}", None)
    bpy.context.collection.objects.link(root)
    hue = (sum(ord(c) for c in key) % 100) / 100
    paint = mat("Hull Paint", (0.06 + hue * .22, 0.18 + (1 - hue) * .2, 0.32 + hue * .28), .72, .28)
    metal = mat("Hull Alloy", (.42, .47, .52), .9, .3)
    dark = mat("Canopy and Carbon", (.015, .025, .04), .6, .18)
    accent = mat("Squadron Marking", (.95, .24 + hue * .3, .025), .25, .32)
    glow = mat("Engine Energy", (.04, .45, 1), .1, .08, (.03, .6, 1))

    if "Podracer" in key:
        build_pod(key, root, paint, metal, dark, glow, accent)
    elif key == "tieFighter":
        sphere("CockpitBall", (0, 0, 0), (2.2, 2.2, 2.2), dark, root)
        for side in (-1, 1):
            cube(f"SolarWing{'L' if side < 0 else 'R'}", (side * 4.5, 0, 0), (.18, 3.8, 3.2), dark, root)
            cube(f"WingFrame{'L' if side < 0 else 'R'}", (side * 4.5, 0, 0), (.25, 4.1, .15), metal, root)
            cylinder(f"Pylon{'L' if side < 0 else 'R'}", (side * 2.7, 0, 0), .28, 3.4, metal, root, "X")
        sphere("Viewport", (0, -2, .15), (1.15, .2, 1.15), glow, root)
    elif key in ("enterprise", "voyager"):
        sphere("PrimarySaucer", (0, -2, 1), (7.8 if key == "enterprise" else 6.3, 5.2, .65), metal, root)
        sphere("Bridge", (0, -2, 1.75), (1.2, 1, .35), glow, root)
        sphere("EngineeringHull", (0, 4, -.6), (2.2, 5.2, 1.45), paint, root)
        for side in (-1, 1):
            cube(f"Pylon{'L' if side < 0 else 'R'}", (side * 3.4, 4, -.3), (3.5, .22, .28), metal, root)
            sphere(f"WarpNacelle{'L' if side < 0 else 'R'}", (side * 6.2, 5.5, 0), (1, 4.7, .75), dark, root)
            cube(f"WarpGlow{'L' if side < 0 else 'R'}", (side * 6.2, 4, .82), (.58, 2.8, .08), glow, root)
    elif key == "millenniumFalcon":
        cylinder("DiscHull", (0, 0, 0), 7.2, 1.5, metal, root, "Z", 32)
        cube("ForwardMandibleL", (-2.8, -6, 0), (1.8, 4.5, .75), metal, root)
        cube("ForwardMandibleR", (2.8, -6, 0), (1.8, 4.5, .75), metal, root)
        sphere("OffsetCockpit", (6.5, -3, .4), (1.2, 3.2, 1), dark, root)
        cube("HyperdriveGlow", (0, 6.9, 0), (4.5, .18, .32), glow, root)
    elif key == "birdOfPrey":
        sphere("CommandPod", (0, -5, .5), (1.6, 3.2, 1.2), dark, root)
        cube("Neck", (0, -1, .3), (1, 3.5, .55), metal, root)
        sphere("MainHull", (0, 3, .4), (3.5, 4.2, 1.2), paint, root)
        for side in (-1, 1):
            wing = cube(f"SweptWing{'L' if side < 0 else 'R'}", (side * 5, 3, -.3), (4.5, 2.5, .18), paint, root)
            wing.rotation_euler[1] = side * .2
            sphere(f"WingCannon{'L' if side < 0 else 'R'}", (side * 9, 1.5, -.2), (.3, 2.2, .3), glow, root)
    else:
        heavy = key in ("meridian", "atlas", "yWing", "falcon")
        body_length = 13 if heavy else 9.5
        sphere("Fuselage", (0, 0, 0), (1.45 if heavy else .9, body_length / 2, 1.05), paint, root)
        sphere("Cockpit", (0, -body_length * .28, 1), (1.05, 2.1, .55), dark, root)
        for side in (-1, 1):
            sweep = 4.8 if heavy else 3.8
            wing = cube(f"Wing{'L' if side < 0 else 'R'}", (side * sweep, .8, 0), (sweep, 2.7, .15), paint, root)
            wing.rotation_euler[2] = side * (-.18 if key in ("aWing", "novaSkiff") else .12)
            sphere(f"Engine{'L' if side < 0 else 'R'}", (side * (3.1 if heavy else 2.2), 3, 0), (.7, 2.5, .7), metal, root)
            sphere(f"EngineGlow{'L' if side < 0 else 'R'}", (side * (3.1 if heavy else 2.2), 5.4, 0), (.45, .2, .45), glow, root, 14)
            cube(f"Laser{'L' if side < 0 else 'R'}", (side * (sweep * 1.8), -1.5, 0), (.12, 3.4, .12), accent, root)
        if key in ("xwing", "starkJet"):
            for side in (-1, 1):
                for upper in (-1, 1):
                    foil = cube(f"SFoil{side}{upper}", (side * 3.6, .5, upper * .65), (3.5, 2.5, .1), paint, root)
                    foil.rotation_euler[1] = side * upper * .12

    export_asset(root, SOURCE_ROOT / "Ships" / f"Ship_{key}.blend", ASSET_ROOT / "Ships" / f"Ship_{key}.usdz")


def build_level(key):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    root = bpy.data.objects.new(f"Level_{key}", None)
    bpy.context.collection.objects.link(root)
    base_color, glow_color = PALETTES[key]
    rock = mat("Environment Surface", base_color, .25 if key in ("deathStar", "corellia") else .05, .72)
    trim = mat("Environment Accent", tuple(min(1, c * 1.35) for c in base_color), .55, .4)
    glow = mat("Environment Energy", glow_color, .15, .1, glow_color)
    forest = key in ("endor", "lantaana")
    industrial = key in ("deathStar", "sentinelOne", "ordMantell", "corellia", "narShaddaa")
    icy = key in ("alpine", "andoPrime")
    for index in range(18):
        side = -1 if index % 2 == 0 else 1
        x = side * (390 + (index % 4) * 55)
        y = -120 - index * 125
        if forest:
            cylinder(f"TreeTrunk{index}", (x, y, 32), 5 + index % 3, 64 + index % 5 * 9, rock, root, "Z", 10)
            cone(f"Canopy{index}", (x, y, 85), 34 + index % 4 * 5, 70, trim, root, 10)
        elif industrial:
            cube(f"Tower{index}", (x, y, 40), (16 + index % 3 * 5, 14, 40 + index % 5 * 12), rock, root)
            cube(f"LightStrip{index}", (x - side * 17, y, 42), (1, 10, 20), glow, root, .02)
            if index % 3 == 0:
                tube(f"Pipe{index}", [(x, y - 35, 15), (x, y, 65), (x, y + 35, 15)], 3, trim, root)
        elif key == "skylands":
            cylinder(f"CloudPlatform{index}", (x, y, 80 + index % 4 * 15), 38, 7, trim, root, "Z", 16)
            sphere(f"Beacon{index}", (x, y, 92 + index % 4 * 15), (3, 3, 3), glow, root, 12)
        else:
            height = 75 + index % 6 * 22
            cone(f"Spire{index}", (x, y, height / 2), 24 + index % 4 * 8, height, rock, root, 7 if icy else 9)
            if index % 3 == 0:
                sphere(f"Marker{index}", (x - side * 28, y, 16), (4, 4, 4), glow, root, 12)
    export_asset(root, SOURCE_ROOT / "Levels" / f"Level_{key}.blend", ASSET_ROOT / "Levels" / f"Level_{key}.usdz")


if __name__ == "__main__":
    raise SystemExit("This basic library is superseded. Run python3 Tools/regenerate_blender_library.py from AlpineFlight to rebuild the detailed assets.")
