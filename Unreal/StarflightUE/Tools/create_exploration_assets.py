"""Build the fleet, water and surface materials in Unreal Editor."""
import os
from pathlib import Path
import runpy

tools = runpy.run_path(str(Path(__file__).with_name("create_scenic_assets.py")))
unreal = tools["unreal"]
material, custom, constant, vector, save = (tools[key] for key in ("material", "custom", "constant", "vector", "save"))
POLY, P, V, C, NOISE = (tools[key] for key in ("POLY", "P", "V", "C", "NOISE"))
TIME = (unreal.MaterialExpressionTime, "")
FLOAT1 = unreal.CustomMaterialOutputType.CMOT_FLOAT1

paint = material("M_FleetPaint")
if paint:
    custom(paint, POLY.MP_BASE_COLOR, "return Tint.rgb;", {"Tint": V})
    custom(paint, POLY.MP_EMISSIVE_COLOR, "return Tint.rgb * Drive * 1150.0;",
           {"Tint": V, "Drive": (unreal.MaterialExpressionVertexColor, "A")})
    constant(paint, POLY.MP_ROUGHNESS, 0.48)
    constant(paint, POLY.MP_METALLIC, 0.32)
    save(paint)
else:
    paint = unreal.load_asset("/Game/Starflight/Materials/M_FleetPaint")

water = material("M_LakeWater")
if water:
    water.set_editor_property("two_sided", True)
    water.set_editor_property("tangent_space_normal", False)
    custom(water, POLY.MP_BASE_COLOR, """
        float shore = Mask.r;
        float3 eye = normalize(Camera-Point);
        float fresnel = pow(1.0 - saturate(eye.z), 4.0);
        float3 lake = lerp(float3(0.008,0.032,0.040),float3(0.061,0.145,0.084),shore);
        return lerp(lake, float3(0.056,0.115,0.16), fresnel * 0.75);
    """, {"Mask": V, "Camera": C, "Point": P})
    custom(water, POLY.MP_NORMAL, NOISE + """
        float2 xy = Point.xy*0.01;
        float2 wave = xy + float2(n.Value(xy*0.035+4.1),n.Value(xy*0.049-2.5))*7.0;
        float2 swell = float2(sin(dot(wave,float2(0.43,0.65))+Clock*1.15)
                            + sin(dot(wave,float2(-0.31,0.47))-Clock*0.97)*0.54,
                              cos(dot(wave,float2(0.62,-0.27))-Clock*0.87));
        float2 ripple = float2(sin(dot(wave,float2(1.22,-1.19))-Clock*2.0),
                               cos(dot(wave,float2(0.79,2.07))+Clock*2.2));
        float nearWater = 1.0-smoothstep(8500.0,120000.0,distance(Point,Camera));
        return normalize(float3(swell*0.047 + ripple*0.020*nearWater,1));
    """, {"Point": P, "Camera": C, "Clock": TIME})
    constant(water, POLY.MP_ROUGHNESS, 0.16)
    constant(water, POLY.MP_SPECULAR, 0.67)
    constant(water, POLY.MP_METALLIC, 0.28)
    save(water)

ice = material("M_LakeIce")
if ice:
    ice.set_editor_property("two_sided", True)
    custom(ice, POLY.MP_BASE_COLOR, NOISE + """
        float2 q=Pt.xy*0.01;
        float wide=n.Value(q*0.019);
        float2 warp=q+float2(n.Value(q*0.08),n.Value(q*0.07+6))*8.0;
        float2 lines=abs(frac(float2(dot(warp,float2(0.031,0.018)),dot(warp,float2(-0.019,0.046)))+wide*0.13)-0.5);
        float crack=1.0-smoothstep(0.008,0.031,min(lines.x,lines.y));
        float rime=smoothstep(0.44,0.81,wide*0.66+n.Value(q*0.46)*0.34);
        float3 blue=lerp(float3(0.024,0.12,0.20),float3(0.30,0.57,0.71),wide);
        float3 frost=float3(0.66,0.81,0.88);
        return lerp(blue,frost,max(crack*0.68,max(Edge.r,rime)*0.8));
    """, {"Pt": P,"Edge": V})
    constant(ice, POLY.MP_ROUGHNESS, 0.26)
    constant(ice, POLY.MP_SPECULAR, 0.58)
    save(ice)

for name, rgb, metal, rough in [
    ("M_Road", (0.018,0.026,0.04),0.27,0.47),
    ("M_LanePaint", (0.13,0.31,0.37),0.1,0.48),
    ("M_Wreck", (0.15,0.19,0.21),0.52,0.58),
    ("M_WreckFrost", (0.50,0.70,0.77),0.05,0.56),
    ("M_ShoreStone", (0.18,0.22,0.14),0,0.84),
]:
    mat = material(name)
    if mat:
        mat.set_editor_property("used_with_instanced_static_meshes", True)
        vector(mat, POLY.MP_BASE_COLOR, rgb)
        constant(mat, POLY.MP_ROUGHNESS, rough)
        constant(mat, POLY.MP_METALLIC, metal)
        if name == "M_LanePaint":
            vector(mat, POLY.MP_EMISSIVE_COLOR, (12,26,32))
        save(mat)

# Use one material per ship. FBX carries the artwork's original paint as vertex colors.
fleet = os.environ.get("STARFLIGHT_FLEET_FBX")
if fleet:
    destination = "/Game/Starflight/Fleet"
    unreal.EditorAssetLibrary.make_directory(destination)
    for fbx in sorted(Path(fleet).glob("SM_Fleet_*.fbx")):
        path = f"{destination}/{fbx.stem}"
        if unreal.EditorAssetLibrary.does_asset_exist(path):
            mesh = unreal.load_asset(path)
        else:
            task = unreal.AssetImportTask()
            task.filename = str(fbx)
            task.destination_path = destination
            task.destination_name = fbx.stem
            task.automated = True
            task.save = False
            options = unreal.FbxImportUI()
            options.import_mesh = True
            options.import_as_skeletal = False
            options.import_materials = False
            options.import_textures = False
            settings = options.static_mesh_import_data
            settings.vertex_color_import_option = unreal.VertexColorImportOption.REPLACE
            settings.auto_generate_collision = False
            settings.build_nanite = False
            settings.combine_meshes = True
            task.options = options
            unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])
            mesh = unreal.load_asset(path)
        if not isinstance(mesh, unreal.StaticMesh):
            raise RuntimeError(f"Couldn't import {fbx.stem}")
        mesh.set_material(0,paint)
        if not unreal.EditorAssetLibrary.save_loaded_asset(mesh, only_if_is_dirty=False):
            raise RuntimeError(f"Couldn't save {path}")
        unreal.log(f"STARFLIGHT_FLEET_READY {fbx.stem}: {mesh.get_bounding_box()}")
bark = material("M_ShoreBark")
if bark:
    bark.set_editor_property("used_with_instanced_static_meshes", True)
    custom(bark, POLY.MP_BASE_COLOR, NOISE + """
        float3 p=Pt*0.01;
        float grain=n.Value(float2((p.x+p.y)*0.70,p.z*0.071));
        float split=n.Value(float2((p.x-p.y)*1.85,p.z*0.22));
        float moss=smoothstep(0.57,0.82,n.Value(p.xy*0.047+p.z*0.045));
        float3 wood=lerp(float3(0.035,0.022,0.013),float3(0.23,0.16,0.099),
                        smoothstep(0.21,0.88,grain*0.77+split*0.23));
        return lerp(wood,float3(0.052,0.086,0.025),moss*0.83);
    """, {"Pt": P})
    constant(bark,POLY.MP_ROUGHNESS,0.94)
    save(bark)

foliage = material("M_ShoreLeaves")
if foliage:
    foliage.set_editor_property("used_with_instanced_static_meshes", True)
    foliage.set_editor_property("two_sided", True)
    scattering = getattr(unreal.MaterialShadingModel, "MSM_TWO_SIDED_FOLIAGE", None)
    if scattering is not None:
        foliage.set_editor_property("shading_model", scattering)
    custom(foliage,POLY.MP_BASE_COLOR,"return Tint.rgb;",{"Tint": V})
    if scattering is not None:
        custom(foliage,POLY.MP_SUBSURFACE_COLOR,"return Tint.rgb*0.7;",{"Tint": V})
    custom(foliage,POLY.MP_WORLD_POSITION_OFFSET,"""
        float phase=dot(Pt.xy,float2(0.00037,0.00021));
        return float3(sin(phase+Clock*1.8)*13.0, sin(phase*1.7+Clock*1.5)*17.0, 0.0);
    """,{"Pt": P,"Clock": TIME})
    constant(foliage,POLY.MP_ROUGHNESS,0.85)
    save(foliage)

trees = os.environ.get("STARFLIGHT_SHORE_FBX")
if trees:
    for name, mat in (("SM_ShoreBark","M_ShoreBark"),("SM_ShoreLeaves","M_ShoreLeaves")):
        tree = tools["import_mesh"](Path(trees) / (name+".fbx"),name,"/Game/Starflight/Scenery")
        tree.set_material(0,unreal.load_asset("/Game/Starflight/Materials/"+mat))
        if name == "SM_ShoreBark":
            body = tree.get_editor_property("body_setup")
            body.set_editor_property("collision_trace_flag",unreal.CollisionTraceFlag.CTF_USE_COMPLEX_AS_SIMPLE)
        if not unreal.EditorAssetLibrary.save_loaded_asset(tree, only_if_is_dirty=False):
            raise RuntimeError(f"Couldn't write {name}")

unreal.log("STARFLIGHT_EXPLORATION_ASSETS_READY")
