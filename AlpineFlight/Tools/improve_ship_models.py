"""Blender-authored fleet, detailed editable sources and batched game exports.

Run Blender --background --threads 2 --python-exit-code 1 --python
Tools/improve_ship_models.py -- [blueprints|legacy|all] [optional ship IDs].
Sources and exported assets are backed up before the first change. Canonical
filenames are explicit, so Finder/iCloud ' 2' copies are never overwritten.
"""
import bpy
import bmesh
import json
import math
import shutil
import sys
from pathlib import Path
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_blender_asset_library import ROOT, SHIPS, mat, cube, sphere, cylinder, torus, tube
from create_blender_library_v2 import hull, plate, laser, export, usd
from fleet_surface_details import add_fleet_details

SOURCES = ROOT / 'Art/BlenderLibrary/Ships'
ASSETS = ROOT / 'AlpineFlight/Resources/BlenderAssets/Ships'
PREVIEWS = ROOT / 'Art/BlenderLibrary/Previews'
BACKUP = ROOT / 'Art/BlenderLibrary/Backups/2026-10-20-scenic-fleet'
NEW_SHIPS = ['bWing', 'imperialShuttle', 'tieDefender', 'tieInterceptor', 'slaveI', 'scimitar']
LEGACY = SHIPS + ['razorCrest']
REPORT = ROOT / 'Art/BlenderLibrary/ship-refit-report.json'


def backup(key):
    for folder, suffix in [(SOURCES, '.blend'), (ASSETS, '.usdz'), (PREVIEWS, '.png')]:
        source = folder / ('Ship_' + key + suffix)
        destination = BACKUP / folder.name / source.name
        if source.exists() and not destination.exists():
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)


def empty(name, root, position=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = root
    obj.location = position
    return obj


def extrude(name, points, thickness, material, root):
    offset = Vector(thickness) * .5
    points = [Vector(p) for p in points]
    n = len(points)
    vertices = [tuple(p-offset) for p in points] + [tuple(p+offset) for p in points]
    faces = [tuple(reversed(range(n))), tuple(range(n, n*2))]
    faces += [(i, (i+1) % n, (i+1) % n+n, i+n) for i in range(n)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent = root
    bevel = obj.modifiers.new('Machined edges', 'BEVEL')
    bevel.width = .035
    bevel.segments = 1
    return obj


def compact_engine(root, x, y, z, r, length, materials, name):
    alloy, dark, paint, accent, glow = materials
    cylinder(name+'Casing', (x, y, z), r, length, alloy, root, vertices=20)
    cylinder(name+'Intake', (x, y-length/2-.02, z), r*.84, .09, dark, root, vertices=20)
    torus(name+'IntakeLip', (x, y-length/2-.1, z), r*.9, .065, paint, root)
    cylinder(name+'TurbineHub', (x, y-length/2-.11, z), r*.2, .1, alloy, root, vertices=12)
    for i in range(8):
        a = i*math.tau/8
        blade = cube(name+'TurbineVane', (x+math.cos(a)*r*.5, y-length/2-.1, z+math.sin(a)*r*.5),
                     (r*.27, .025, .035), alloy, root, 0)
        blade.rotation_euler.y = -a
    cylinder(name+'Nozzle', (x, y+length/2, z), r*.86, .3, dark, root, vertices=20)
    torus(name+'NozzleRim', (x, y+length/2+.15, z), r*.8, .055, alloy, root)
    cylinder(name+'Plasma', (x, y+length/2+.18, z), r*.66, .035, glow, root, vertices=20)
    marker = empty('EngineNozzle_'+name, root, (x, y+length/2+.20, z))
    marker.scale = (r*.66,)*3
    for dy in (-.22, .22):
        torus(name+'ServiceBand', (x, y+dy*length, z), r*1.01, .035, dark, root)


def viewport(root, center, radius, materials, name):
    alloy, dark, paint, accent, glow = materials
    x, y, z = center
    cylinder(name+'Glass', (x, y, z), radius, .1, dark, root, vertices=16)
    torus(name+'Rim', (x, y-.07, z), radius, .055, alloy, root)
    for i in range(8):
        angle = i*math.tau/8
        tube(name+'GlazingBar', [(x, y-.14, z),
             (x+math.cos(angle)*radius*.95, y-.14, z+math.sin(angle)*radius*.95)], .023, alloy, root)


def b_wing(root, m):
    alloy, dark, paint, accent, glow = m
    # Horizontal flight attitude: offset gyroscopic cockpit and a long tapered blade.
    plate('AsymmetricWingBlade', [(-5, -2.3), (7.8, -.2), (8.8, 1.5), (5.6, 2.4), (-5, 1.1)],
          0, .32, paint, root)
    hull('EngineCore', [(-4.8, .6, .5, 0), (-2.5, 1.2, .85, 0), (1, 1.15, .8, 0), (4, .85, .65, 0)],
         paint, empty('EngineCoreMount', root, (-3.5, 0, 0)))
    tube('BladeLeadingSpar', [(-4.8, -2.45, .02), (4.8, -.9, .02), (8.6, 1.35, .02)], .105, alloy, root)
    for sign in (-1, 1):
        extrude('DeployedCrossFoil', [(2.1, -.4, 0), (3.5, -.1, sign*3),
                (3.7, 2.6, sign*2.7), (2.2, 2.1, 0)], (.13, 0, 0), paint, root)
        laser(root, (3.5, -.7, sign*2.9), m, 'CrossFoilCannon')
    gyro = empty('GyroscopicCockpit', root, (-6.7, -2.3, 0))
    sphere('GyroCockpitHousing', (0, 0, 0), (1.15, 1.6, 1.0), alloy, gyro, 24)
    viewport(gyro, (0, -1.4, 0), .77, m, 'CockpitViewport')
    torus('GyroBearing', (0, .5, 0), 1.02, .14, dark, gyro)
    cylinder('ArmouredGyroMount', (-5, -1.5, 0), .4, 3.1, alloy, root, 'X', 20)
    cylinder('CockpitAccessHatch', (0, .5, .96), .48, .12, paint, gyro, 'Z', 16)
    for x in (-4.1, -2.85):
        for z in (-.55, .55):
            compact_engine(root, x, 2.4, z, .49, 3.7, m, 'QuadIonDrive')
    laser(root, (8.1, -.3, .1), m, 'HeavyBladeCannon')
    for i in range(8):
        x = -1.4+i*.95
        cube('BladeRecess', (x, .55, .18), (.28, .28, .025), dark, root, .02)
        cube('BladeServiceCover', (x, .55, .22), (.21, .22, .018), alloy, root, .01)
    for side in (-1, 1):
        cube('SquadronBladeMarking', (4.8, .5, side*.19), (1, .14, .015), accent, root, .01)
    tube('ReactorCoolantLine', [(-2.7, -.8, .8), (-1.6, -.3, .55), (1.7, .15, .3)], .07, alloy, root)


def shuttle(root, m):
    alloy, dark, paint, accent, glow = m
    hull('ArmouredShuttleHull', [(-9.5, 1, .55, .1), (-7, 2.4, .9, .2),
         (-3, 3, 1.8, .1), (4.5, 3, 1.9, .1), (7.5, 2.2, 1.25, .1)], paint, root)
    hull('FacetedCommandGlazing', [(-9.7, .92, .32, .65), (-7.2, 2.2, .65, 1),
         (-5.5, 2.15, .5, 1.1)], dark, root)
    for side in (-1, 1):
        tube('BridgeGlazingFrame', [(side*.8, -9.78, .88), (side*2, -7, 1.75), (side*2.1, -5.5, 1.6)], .07, alloy, root)
    tube('BridgeCentreRail', [(0, -9.8, .92), (0, -7.2, 1.82), (0, -5.5, 1.65)], .06, alloy, root)
    fin = [(0, -1, 1.8), (0, 1.2, 10), (0, 5.8, 9), (0, 7.7, 1.8)]
    extrude('TallDorsalFin', fin, (.48, 0, 0), paint, root)
    for side in (-1, 1):
        extrude('DorsalFinInset', [(side*.255, 1, 3), (side*.255, 2, 8.7),
                (side*.255, 5.2, 8), (side*.255, 6.5, 3)], (.02, 0, 0), alloy, root)
        wing = [(side*2.5, -2, .8), (side*11.7, .3, -4.7),
                (side*10.6, 7.8, -4.2), (side*2.6, 5.8, .8)]
        extrude('SweptFoldingWing', wing, (.08, 0, .18), paint, root)
        tube('WingLeadingArmour', [wing[0], wing[1], wing[2]], .095, alloy, root)
        cylinder('FoldingWingHinge', (side*2.65, 1.6, .95), .36, 5.7, alloy, root, vertices=16)
        for i in range(4):
            x = side*(4.5+i*1.45)
            z = .8-(abs(x)-2.5)*.6
            tube('WingPanelSeam', [(x, -.4+i*.15, z+.14), (x, 5.9, z+.14)], .027, dark, root)
        laser(root, (side*2.8, -5.3, -.8), m, 'ForwardLaser')
        compact_engine(root, side*1.35, 5.5, -.1, .75, 3.6, m, 'TwinShuttleDrive')
        for i in range(5):
            cube('ShuttleSideVent', (side*2.95, -1.8+i*.9, .35), (.035, .21, .24), dark, root, .01)
    cube('RearBoardingRamp', (0, 7.65, -.15), (1.55, .1, .95), dark, root, .05)
    for i in range(6):
        cube('BoardingRampRib', (0, 7.78, -.8+i*.27), (1.4, .045, .025), alloy, root, .01)
    cylinder('DorsalSensor', (0, -2, 2), .45, .23, alloy, root, 'Z', 16)


def defender(root, m):
    alloy, dark, paint, accent, glow = m
    solar = mat('Blue black photovoltaic cells', (.018, .035, .07), .38, .45)
    cell_edge = mat('Photovoltaic bus bars', (.13, .20, .28), .65, .4)
    sphere('DefenderCommandSphere', (0, 0, 0), (1.55, 1.75, 1.55), alloy, root, 24)
    viewport(root, (0, -1.65, 0), 1.04, m, 'OctagonalPilotViewport')
    cylinder('CockpitDorsalHatch', (0, 0, 1.51), .68, .14, dark, root, 'Z', 16)
    torus('DorsalHatchRim', (0, 0, 1.6), .68, .06, alloy, root, 'Z')
    for i in range(3):
        a = math.pi/2+i*math.tau/3
        radial = Vector((math.cos(a), 0, math.sin(a)))
        tangent = Vector((-math.sin(a), 0, math.cos(a)))
        def point(t, y, surface=.0):
            return radial*(4.5+abs(t)*.24+surface)+tangent*t+Vector((0, y, 0))
        tube('RadialWingPylon', [tuple(radial*1.25), tuple(radial*4.5)], .29, alloy, root)
        for offset in (-.38, .38):
            tube('PylonPowerLine', [tuple(radial*1.5+Vector((0, offset, 0))),
                 tuple(radial*4.5+Vector((0, offset, 0)))], .06, dark, root)
        for side in (-1, 1):
            outline = [point(0, -4), point(side*2.8, -2.3), point(side*2.8, 2.3), point(0, 4)]
            extrude('CantedSolarWing', outline, radial*.12, solar, root)
            for k in range(4):
                tube('SolarWingFrame', [tuple(outline[k]), tuple(outline[(k+1) % 4])], .10, alloy, root)
            for j in range(1, 7):
                t = side*j*.4
                limit = 4-abs(t)*1.7/2.8
                for face in (-1, 1):
                    tube('SolarCellGrid', [tuple(point(t, -limit, face*.075)), tuple(point(t, limit, face*.075))], .017, cell_edge, root)
            for y in (-2, -1, 0, 1, 2):
                for face in (-1, 1):
                    tube('SolarCellCrossBus', [tuple(point(0, y, face*.075)), tuple(point(side*2.7, y, face*.075))], .017, cell_edge, root)
        for offset in (-.55, .55):
            p = radial*1.4+tangent*offset
            laser(root, (p.x, -1.6, p.z), m, 'SixForwardCannons')
    for x in (-.58, .58):
        cylinder('TwinIonExhaust', (x, 1.65, 0), .3, .12, glow, root, vertices=16)


def interceptor(root, m):
    alloy, dark, paint, accent, glow = m
    sphere('InterceptorCommandSphere',(0,0,0),(1.45,1.65,1.45),alloy,root,24)
    viewport(root,(0,-1.56,0),.95,m,'InterceptorViewport')
    for side in (-1,1):
        cylinder('WingPylon',(side*2.4,0,0),.26,3.4,alloy,root,'X',16)
        for up in (-1,1):
            outline=[(side*3.9,-5.8,up*2.8),(side*4.5,-1.5,up*.45),
                     (side*4.5,3.0,up*.45),(side*3.9,2.0,up*3.0)]
            extrude('DaggerSolarWing',outline,(.12,0,0),dark,root)
            for k in range(4):
                tube('DaggerArmourFrame',[outline[k],outline[(k+1)%4]],.10,alloy,root)
            for line in range(1,8):
                y=-1.4+line*.48
                tube('PhotovoltaicGrid',[(side*3.82,y,up*2.55),(side*4.58,y,up*.65)],.022,paint,root)
            laser(root,(side*3.9,-5.2,up*2.65),m,'WingTipLaser')
    for x in (-.5,.5):
        compact_engine(root,x,1.1,0,.30,1.3,m,'TwinIonDrive')
    cylinder('PilotHatch',(0,.2,1.4),.55,.15,paint,root,'Z',16)


def slave_one(root, m):
    alloy, dark, paint, accent, glow = m
    green = mat('Weathered patrol olive',(.18,.25,.13),.4,.58)
    red = mat('Patrol maroon armour',(.36,.075,.045),.35,.55)
    sphere('ArmouredOvalHull',(0,1,0),(3.5,5.9,2.6),red,root,24)
    hull('RaisedPatrolSpine',[(-5.5,1.0,.7,1.4),(-3.0,2.2,1.8,2.1),(1,2.3,2.2,2),(5.8,1.2,1.1,1.2)],green,root)
    hull('LongCockpitCanopy',[(-5.7,.7,.35,1.8),(-4,1.35,.8,2.8),(-1,1.45,.8,3.5),(1.2,1.1,.4,3.8)],dark,root)
    for side in (-1,1):
        tube('CanopyArmourRail',[(side*.65,-5.8,2.0),(side*1.4,-2,4.1),(side*1.1,1.2,4.2)],.07,alloy,root)
        plate('RotatingStabiliser',[(side*2,-1),(side*6,-1),(side*6,2.2),(side*2,3)],-.2,.25,green,root)
        cylinder('StabiliserPivot',(side*3.6,1.5,0),.5,.35,alloy,root,'X',20)
        compact_engine(root,side*1.0,4.8,-1.2,.55,2.0,m,'PatrolDrive')
        laser(root,(side*.8,-5.4,-1.0),m,'TwinHeavyCannon')
        for i in range(5):
            cube('SideCoolingVent',(side*3.05,-1+i*.85,.1),(.045,.28,.45),dark,root,.01)
    for y in (-2,0,2):
        tube('CanopyCrossFrame',[(-1.4,y,3.7),(0,y,4.1),(1.4,y,3.7)],.045,alloy,root)
    cube('CargoRamp',(0,5.6,-.4),(1.6,.18,1.0),dark,root,.08)


def infiltrator(root, m):
    alloy, dark, paint, accent, glow = m
    hull('LongDaggerHull',[(-10,.14,.14,0),(-7,.85,.45,0),(-1,1.4,.65,0),(4,2.3,1.0,0),(7,1.3,.65,0)],paint,root)
    sphere('SithCommandPod',(0,4.8,.5),(2.0,2.3,1.8),alloy,root,24)
    viewport(root,(0,2.7,.8),1.2,m,'SithViewport')
    for side in (-1,1):
        wing=[(side*1.8,1,0),(side*6.7,-1.5,0),(side*7.1,5.5,0),(side*2,6.4,0)]
        extrude('FoldingSolarWing',wing,(0,0,.18),dark,root)
        for k in range(4):tube('SolarWingArmour',[wing[k],wing[(k+1)%4]],.1,alloy,root)
        for i in range(7):
            x=side*(2.4+i*.58)
            tube('SolarGrid',[(x,.4,.12),(x,5.5,.12)],.024,paint,root)
        compact_engine(root,side*1.0,5.5,0,.5,2.6,m,'SithIonDrive')
        laser(root,(side*.9,-4.0,-.1),m,'ConcealedCannon')
        for i in range(9):
            cube('DaggerServicePanel',(side*.42,-7+i*.85,.48),(.28,.34,.035),alloy,root,.01)
    tube('DorsalCentreSpine',[(0,-8,.28),(0,-1,.7),(0,3,1.5)],.065,alloy,root)
    cylinder('CommandHatch',(0,5.2,2.2),.65,.12,dark,root,'Z',16)


def finish_geometry(root):
    # Real mesh tubes with caps render consistently in RealityKit and the shop viewer.
    for obj in list(root.children_recursive):
        if obj.type == 'CURVE':
            obj.data.use_fill_caps = True
            bpy.ops.object.select_all(action='DESELECT')
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.convert(target='MESH')
    for obj in root.children_recursive:
        if obj.type != 'MESH':
            continue
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-5)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        if bm.faces and all(edge.is_manifold for edge in bm.edges) and bm.calc_volume(signed=True) < 0:
            bmesh.ops.reverse_faces(bm, faces=list(bm.faces))
        bm.to_mesh(obj.data)
        bm.free()
        # Round the turbine rings and canopies without smoothing flat armour panels.
        if len(obj.data.vertices) > 80 and all(len(p.vertices) <= 4 for p in obj.data.polygons):
            for p in obj.data.polygons:
                p.use_smooth = True
        for modifier in obj.modifiers:
            if modifier.type == 'BEVEL':
                modifier.harden_normals = True
                modifier.segments = min(modifier.segments, 2)
        obj.data.update()


def statistics(root):
    deps = bpy.context.evaluated_depsgraph_get()
    triangles = 0
    meshes = 0
    open_meshes = []
    inward = []
    for obj in root.children_recursive:
        if obj.type != 'MESH':
            continue
        meshes += 1
        evaluated = obj.evaluated_get(deps)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        triangles += len(mesh.loop_triangles)
        bm = bmesh.new(); bm.from_mesh(mesh)
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-5)
        if not all(e.is_manifold for e in bm.edges):
            open_meshes.append(obj.name)
        elif bm.calc_volume(signed=True) < -1e-6:
            inward.append(obj.name)
        bm.free(); evaluated.to_mesh_clear()
    return {'triangles': triangles, 'mesh_parts': meshes, 'open_meshes': open_meshes, 'inward_meshes': inward}


def optimized_export(key, root):
    """Bake static parts once; retain the animated pod binder and semantic locators."""
    deps = bpy.context.evaluated_depsgraph_get()
    runtime = empty('Runtime_'+key, None)
    parts = []
    animated = []
    for obj in list(root.children_recursive):
        if obj.type != 'MESH': continue
        mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(deps))
        is_animated = obj.name == 'podracer energy field'
        part = bpy.data.objects.new('RuntimePart', mesh)
        bpy.context.collection.objects.link(part)
        part.parent = runtime; part.matrix_world = obj.matrix_world.copy()
        if is_animated:
            obj.name = 'Authoring energy field'
            part.name = 'podracer energy field'
            animated.append(part)
        else:
            parts.append(part)
    bpy.ops.object.select_all(action='DESELECT')
    for part in parts: part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    combined = bpy.context.object; combined.name = 'DetailedHull'
    # Empty locators retain semantic model features without separate draw calls.
    for name in ['FlightForward', 'FlightRear', 'GyroscopicCockpit', 'TallDorsalFin', 'DefenderCommandSphere',
                 'CockpitPod', 'LeftEngine', 'RightEngine', 'OffsetCockpit']:
        source = bpy.data.objects.get(name)
        if source:
            locator = empty(name+'_Locator', runtime)
            locator.matrix_world = source.matrix_world.copy()
            source.name = name+'_Authoring'
            locator.name = name
    for source in list(root.children_recursive):
        if source.type == 'EMPTY' and source.name.startswith('EngineNozzle_'):
            name = source.name
            locator = empty(name+'_Locator', runtime)
            locator.matrix_world = source.matrix_world.copy()
            source.name = name+'_Authoring'
            locator.name = name
    bpy.ops.object.select_all(action='DESELECT'); runtime.select_set(True)
    for child in runtime.children_recursive: child.select_set(True)
    bpy.context.view_layer.objects.active = runtime
    usd(ASSETS / ('Ship_'+key+'.usdz'))
    for child in list(runtime.children_recursive): bpy.data.objects.remove(child, do_unlink=True)
    bpy.data.objects.remove(runtime, do_unlink=True)


def render(key, root):
    # A tighter, common studio framing makes silhouette comparisons useful.
    bpy.context.view_layer.update()
    points = [root.matrix_world.inverted() @ obj.matrix_world @ Vector(v)
              for obj in root.children_recursive if obj.type == 'MESH' for v in obj.bound_box]
    minimum = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    maximum = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    center = (minimum+maximum)/2
    extent = max(maximum-minimum)
    for obj in list(bpy.data.objects):
        if obj.type in ('LIGHT', 'CAMERA'):
            bpy.data.objects.remove(obj, do_unlink=True)
    target = root.matrix_world @ center
    bpy.ops.object.camera_add(location=target+Vector((.8, -1.1, .68))*extent)
    camera = bpy.context.object
    camera.rotation_euler = (target-camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera.data.type = 'ORTHO'; camera.data.ortho_scale = extent*(1.7 if key in ('tieDefender','tieInterceptor') else 1.3)
    camera.data.clip_end = 10000
    scene = bpy.context.scene; scene.camera = camera
    for direction, power in [((.7, -1, 1.4), 1700), ((-1, -.2, .6), 1300), ((.4, 1, .8), 2000)]:
        bpy.ops.object.light_add(type='AREA', location=target+Vector(direction)*extent)
        light = bpy.context.object; light.data.energy = power*(extent/20)**2; light.data.size = extent*.6
        light.rotation_euler = (target-light.location).to_track_quat('-Z', 'Y').to_euler()
    scene.world = bpy.data.worlds.new('Refit studio'); scene.world.color = (.045, .06, .085)
    scene.render.engine = 'BLENDER_EEVEE_NEXT'; scene.eevee.taa_render_samples = 24
    scene.render.resolution_x = 1000; scene.render.resolution_y = 760; scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.filepath = str(PREVIEWS / ('Ship_'+key+'.png'))
    bpy.ops.render.render(write_still=True)


def save(key, root, new=False):
    # Detailed editable meshes are retained in .blend. Runtime static geometry is
    # joined after saving, so adding detail does not add per-part RealityKit work.
    add_fleet_details(key, root, empty)
    finish_geometry(root)
    root['starflight_refit_version'] = 2
    stats = statistics(root)
    if stats['inward_meshes']:
        raise RuntimeError(f'Inward faces after repair: {key}: {stats}')
    if stats['open_meshes'] or stats['triangles'] > 40000:
        raise RuntimeError(f'Fleet model failed its closed-mesh/mobile budget: {key}: {stats}')
    bpy.context.preferences.filepaths.save_version = 0
    if new:
        export(root, SOURCES / ('Ship_'+key+'.blend'), ASSETS / ('Ship_'+key+'.usdz'), ship=True)
        optimized_export(key, root)
    else:
        bpy.ops.object.select_all(action='DESELECT'); root.select_set(True)
        for child in root.children_recursive: child.select_set(True)
        bpy.context.view_layer.objects.active = root
        bpy.ops.wm.save_as_mainfile(filepath=str(SOURCES / ('Ship_'+key+'.blend')))
        optimized_export(key, root)
    # Authoring preview faces the nose; the saved source keeps the export yaw.
    root.rotation_euler.z = 0
    render(key, root)
    stats['asset_bytes'] = (ASSETS / ('Ship_'+key+'.usdz')).stat().st_size
    stats['runtime_mesh_parts'] = 2 if 'Podracer' in key else 1
    stats['fitted_armour_panels'] = root.get('fleet_detail_panel_count', 0)
    stats['detail_version'] = 2
    print('REFIT', key, json.dumps(stats), flush=True)
    return stats


def build_blueprint(key):
    backup(key)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    root = empty('Ship_'+key, None)
    alloy = mat('Brushed structural alloy', (.32, .36, .4), .65, .36)
    dark = mat('Cockpit glazing and recesses', (.012, .022, .035), .35, .23)
    paint = mat('Ceramic armour', (.68, .70, .69), .35, .42)
    accent = mat('Ochre squadron markings', (.62, .16, .04), .2, .5)
    glow = mat('Ion drive glow', (.12, .45, 1), .1, .3, (.05, .32, 1))
    if key in ('tieDefender','tieInterceptor','scimitar'):
        paint.diffuse_color = (.36, .4, .44, 1)
        paint.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = paint.diffuse_color
        glow = mat('Twin ion engine glow', (.8, .08, .025), .1, .3, (1, .035, .01))
    {'bWing': b_wing, 'imperialShuttle': shuttle, 'tieDefender': defender, 'tieInterceptor': interceptor, 'slaveI': slave_one, 'scimitar': infiltrator}[key](root, (alloy, dark, paint, accent, glow))
    return save(key, root, new=True)


def refit_legacy(key):
    backup(key)
    bpy.ops.wm.open_mainfile(filepath=str(SOURCES / ('Ship_'+key+'.blend')))
    root = bpy.data.objects['Ship_'+key]
    # Rebuild only this pass's detail groups; the authored craft stays editable.
    # Remove the older hatch pass before fitting new panels to the true hull.
    for name in ('RefitServiceDetails', 'FleetScenicRefit'):
        previous = bpy.data.objects.get(name)
        if previous:
            for child in list(previous.children_recursive): bpy.data.objects.remove(child, do_unlink=True)
            bpy.data.objects.remove(previous, do_unlink=True)
    return save(key, root)


if __name__ == '__main__':
    args = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['all']
    mode = args[0] if args else 'all'; selected = args[1:]
    results = json.loads(REPORT.read_text()) if REPORT.exists() else {}
    for key in NEW_SHIPS if mode in ('blueprints', 'all') else []:
        if not selected or key in selected:
            results[key] = build_blueprint(key)
            REPORT.write_text(json.dumps(results, indent=2))
    for key in LEGACY if mode in ('legacy', 'all') else []:
        if not selected or key in selected:
            results[key] = refit_legacy(key)
            REPORT.write_text(json.dumps(results, indent=2))
