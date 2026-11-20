"""Run inside Unreal Editor. Creates the flight scene materials and imports the Peregrine."""
import os
from pathlib import Path
import unreal

ASSETS = unreal.AssetToolsHelpers.get_asset_tools()
EDIT = unreal.MaterialEditingLibrary
FOLDER = "/Game/Starflight/Materials"
unreal.EditorAssetLibrary.make_directory(FOLDER)

NOISE = (Path(__file__).resolve().parent.parent / "Shaders" / "Lighting.ush").read_text()


def material(name, shader=None, blend=None):
    asset = unreal.load_asset(f"{FOLDER}/{name}")
    if asset is not None:
        return None
    asset = ASSETS.create_asset(name, FOLDER, unreal.Material, unreal.MaterialFactoryNew())
    if shader:
        asset.set_editor_property("shading_model", shader)
    if blend:
        asset.set_editor_property("blend_mode", blend)
    return asset


def expression(asset, cls, x, y):
    return EDIT.create_material_expression(asset, cls, x, y)


def constant(asset, prop, number):
    node = expression(asset, unreal.MaterialExpressionConstant, -200, 300)
    node.set_editor_property("r", number)
    EDIT.connect_material_property(node, "", prop)


def vector(asset, prop, color):
    node = expression(asset, unreal.MaterialExpressionConstant3Vector, -200, 100)
    node.set_editor_property("constant", unreal.LinearColor(*color, 1))
    EDIT.connect_material_property(node, "", prop)


def custom(asset, prop, code, nodes, output=unreal.CustomMaterialOutputType.CMOT_FLOAT3):
    node = expression(asset, unreal.MaterialExpressionCustom, -280, 10)
    node.set_editor_property("code", code)
    node.set_editor_property("output_type", output)
    inputs = []
    for name in nodes:
        pin = unreal.CustomInput()
        pin.set_editor_property("input_name", name)
        inputs.append(pin)
    node.set_editor_property("inputs", inputs)
    for y, (name, (cls, pin)) in enumerate(nodes.items()):
        source = expression(asset, cls, -650, y * 170)
        if not EDIT.connect_material_expressions(source, pin, node, name):
            raise RuntimeError(f"Could not connect {pin or 'default output'} to {asset.get_name()}.{name}")
    EDIT.connect_material_property(node, "", prop)


def save(asset):
    EDIT.recompile_material(asset)
    if not unreal.EditorAssetLibrary.save_loaded_asset(asset, only_if_is_dirty=False):
        raise RuntimeError(f"Couldn't save {asset.get_name()}")


P = (unreal.MaterialExpressionWorldPosition, "")
V = (unreal.MaterialExpressionVertexColor, "")
C = (unreal.MaterialExpressionCameraPositionWS, "")
POLY = unreal.MaterialProperty
ground = material("M_PlanetTerrain")
if ground is not None:
    ground.set_editor_property("two_sided", True)
    constant(ground, POLY.MP_ROUGHNESS, 0.91)
    custom(ground, POLY.MP_BASE_COLOR, NOISE + """
    float3 metres = P * 0.01;
    float2 q = metres.xy + metres.z * float2(0.6,0.31);
    float broad = n.Value(q * 0.007);
    float scree = n.Value(q * 0.055);
    float micro = n.Value(q * 0.30);
    float seam = sin(metres.z * 0.31 + broad * 9.0 + scree * 1.4);
    float close = 1.0 - smoothstep(12000.0,120000.0,distance(P,C));
    float shade = 0.72+broad*0.34+scree*0.22 + close*(micro*0.18+seam*0.09);
    return V.rgb * shade;
    """, {"P": P, "V": V, "C": C})
    save(ground)

cloud = material("M_CloudDeck", unreal.MaterialShadingModel.MSM_UNLIT, unreal.BlendMode.BLEND_TRANSLUCENT)
if cloud is not None:
    cloud.set_editor_property("two_sided", True)
    vector(cloud, POLY.MP_EMISSIVE_COLOR, (0.9,0.96,1.05))
    custom(cloud, POLY.MP_OPACITY, NOISE + """
    float2 q = P.xy * 0.000005 + float2(3.85,8.18);
    float mass = n.Value(q) * 0.65 + n.Value(q * 2.14) * 0.24 + n.Value(q * 5.17) * 0.11;
    float edge = 1.0 - smoothstep(500000.0,2200000.0,distance(P,C));
    return smoothstep(0.49,0.78,mass)*edge*0.75;
    """, {"P": P, "C": C}, unreal.CustomMaterialOutputType.CMOT_FLOAT1)
    save(cloud)

facade = material("M_CityFacade")
if facade is not None:
    facade.set_editor_property("used_with_instanced_static_meshes", True)
    vector(facade, POLY.MP_BASE_COLOR, (0.022,0.034,0.056))
    constant(facade, POLY.MP_ROUGHNESS, 0.48)
    custom(facade, POLY.MP_EMISSIVE_COLOR, NOISE + """
    float3 normal = abs(N);
    float2 q=float2(normal.x>normal.y ? P.y : P.x,P.z)*0.01;
    float2 tile=q/float2(9.0,13.0);
    float2 f=frac(tile), cell=floor(tile);
    float seed=n.Hash(cell);
    float edges=step(0.18,f.x)*step(f.x,0.79)*step(0.22,f.y)*step(f.y,0.63);
    float3 cyan=float3(0.09,0.54,1.35), amber=float3(1.16,0.43,0.09), violet=float3(0.54,0.14,1.3);
    float band=1.0-smoothstep(0.07,0.15,frac(q.y/104.0));
    float3 hue=lerp(cyan,amber,step(0.7,seed));
    return (hue*edges*step(0.34,seed)*1.5+violet*band*0.85)*(1.0-normal.z) * 430.0;
    """, {"P": P, "N": (unreal.MaterialExpressionVertexNormalWS, "")})
    save(facade)

for name, color, roughness, metal, glow in [
    ("Ice", (0.22,0.50,0.67), 0.33,0.02,0),
    ("Sandstone", (0.31,0.10,0.036),0.98,0,0),
    ("Bark", (0.11,0.049,0.025),0.95,0,0),
    ("CanopyGreen", (0.042,0.17,0.062),0.98,0,0),
    ("CanopyPine", (0.028,0.095,0.052),0.98,0,0),
    ("PearlAlloy", (0.55,0.62,0.65),0.39,0.34,0),
    ("Graphite", (0.036,0.054,0.073),0.43,0.42,0),
    ("RescueOrange", (0.85,0.22,0.04),0.38,0.23,0),
    ("Canopy", (0.012,0.073,0.105),0.15,0.45,0),
    ("EngineGlow", (0.03,0.42,0.68),0.28,0,1000),
    ("Titanium", (0.24,0.27,0.30),0.42,0.48,0),
]:
    surface = material(f"M_{name}")
    if surface is None:
        continue
    if name in {"Ice", "Sandstone", "Bark", "CanopyGreen", "CanopyPine", "Titanium"}:
        surface.set_editor_property("used_with_instanced_static_meshes", True)
    vector(surface, POLY.MP_BASE_COLOR, color)
    constant(surface, POLY.MP_ROUGHNESS, roughness)
    constant(surface, POLY.MP_METALLIC, metal)
    if glow:
        vector(surface, POLY.MP_EMISSIVE_COLOR, tuple(channel * glow for channel in color))
    save(surface)

night = material("M_CitySky", unreal.MaterialShadingModel.MSM_UNLIT)
if night is not None:
    night.set_editor_property("two_sided", True)
    night.set_editor_property("is_sky", True)
    custom(night, POLY.MP_EMISSIVE_COLOR, """
    float3 dir = normalize(P);
    float horizon = exp(-abs(dir.z)*6.0);
    float haze = 0.68 + 0.32*sin(dir.y*4.0+dir.x*3.0);
    return lerp(float3(0.18,0.23,0.82),float3(2.1,1.02,4.8),horizon*haze)*13.0;
    """, {"P": P})
    save(night)


weather = material("M_Weather", unreal.MaterialShadingModel.MSM_UNLIT, unreal.BlendMode.BLEND_TRANSLUCENT)
if weather is not None:
    weather.set_editor_property("two_sided", True)
    color = expression(weather, unreal.MaterialExpressionVertexColor, -560, -20)
    custom(weather, POLY.MP_EMISSIVE_COLOR, "return Tint.rgb * 8400.0;", {"Tint": V})
    if not EDIT.connect_material_property(color, "A", POLY.MP_OPACITY):
        raise RuntimeError("Couldn't connect precipitation opacity")
    save(weather)


def import_mesh(fbx, name, destination):
    path = f"{destination}/{name}"
    if unreal.EditorAssetLibrary.does_asset_exist(path):
        return unreal.EditorAssetLibrary.load_asset(path)
    if not fbx:
        return None
    unreal.EditorAssetLibrary.make_directory(destination)
    task = unreal.AssetImportTask()
    task.filename = str(fbx)
    task.destination_path = destination
    task.destination_name = name
    task.automated = True
    task.save = False
    options = unreal.FbxImportUI()
    options.import_as_skeletal = False
    options.import_mesh = True
    options.import_materials = False
    options.import_textures = False
    options.static_mesh_import_data.combine_meshes = True
    options.static_mesh_import_data.auto_generate_collision = False
    options.static_mesh_import_data.build_nanite = False
    options.static_mesh_import_data.force_front_x_axis = True
    task.options = options
    ASSETS.import_asset_tasks([task])
    mesh = unreal.load_asset(path)
    if mesh is None:
        raise RuntimeError(f"Missing static mesh {path}: {task.imported_object_paths}")
    return mesh


mesh = import_mesh(os.environ.get("STARFLIGHT_SHIP_FBX"), "SM_Peregrine", "/Game/Starflight/Ships")
if mesh is not None:
    slots = mesh.get_editor_property("static_materials")
    if not slots:
        raise RuntimeError("The Peregrine imported without material slots")
    for index, slot in enumerate(slots):
        name = str(slot.get_editor_property("imported_material_slot_name"))
        paint = unreal.load_asset(f"{FOLDER}/M_{name}")
        if paint is None:
            raise RuntimeError(f"Missing Peregrine paint slot {name}")
        mesh.set_material(index, paint)
    unreal.log(f"Peregrine mesh bounds: {mesh.get_bounding_box()}")
    save_mesh = unreal.EditorAssetLibrary.save_loaded_asset(mesh, only_if_is_dirty=False)
    if not save_mesh:
        raise RuntimeError("Couldn't save the Peregrine")
scenery_fbx = os.environ.get("STARFLIGHT_SCENERY_FBX")
if scenery_fbx:
    for name in ("SM_GlacierRock", "SM_SandstoneMesa", "SM_ForestCrown"):
        mesh = import_mesh(Path(scenery_fbx) / f"{name}.fbx", name, "/Game/Starflight/Scenery")
        body = mesh.get_editor_property("body_setup")
        body.set_editor_property("collision_trace_flag", unreal.CollisionTraceFlag.CTF_USE_COMPLEX_AS_SIMPLE)
        if not unreal.EditorAssetLibrary.save_loaded_asset(mesh, only_if_is_dirty=False):
            raise RuntimeError(f"Couldn't save {name}")

unreal.log("STARFLIGHT_SCENIC_ASSETS_READY")
