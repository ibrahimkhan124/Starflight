"""Detailed ships and actual streamed Blender terrain. Run in Blender 4.3+.
First compile/run export_level_surfaces.swift against the game's terrain sources.
Options after --: ships, levels, or all (default); optional asset names.
Authoring axes: ship noses -Y, up +Z. Export rotates ships to game forward -Z.
Level coordinates use (game X, -game Z, game Y) before the Y-up USD conversion.
"""
import sys, math, json, random
from pathlib import Path
import bpy
from mathutils import Vector
sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_blender_asset_library import (ROOT, SHIPS, LEVELS, PALETTES, mat, cube, sphere, cylinder, torus, tube, cone)
SOURCE = ROOT / 'Art/BlenderLibrary'
ASSETS = ROOT / 'AlpineFlight/Resources/BlenderAssets'
PREVIEWS = SOURCE / 'Previews'
PREVIEWS.mkdir(parents=True, exist_ok=True)


def mesh(name, vertices, faces, material, root):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.materials.append(material)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.parent = root
    return obj


def plate(name, outline, z, thick, material, root):
    n = len(outline)
    verts = [(x,y,z-thick/2) for x,y in outline] + [(x,y,z+thick/2) for x,y in outline]
    faces = [tuple(reversed(range(n))), tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    if sum(outline[i][0]*outline[(i+1)%n][1]-outline[(i+1)%n][0]*outline[i][1] for i in range(n)) < 0:
        faces = [tuple(reversed(face)) for face in faces]
    ob = mesh(name,verts,faces,material,root)
    bevel=ob.modifiers.new('Machined edge','BEVEL'); bevel.width=.04; bevel.segments=2
    return ob


def hull(name, stations, material, root):
    # Cross-sections form an actual tapered hull rather than a stretched sphere.
    verts=[]
    for y,w,h,z in stations:
        for a in range(8):
            angle=(a+.5)*math.tau/8
            verts.append((math.cos(angle)*w,y,z+math.sin(angle)*h))
    faces=[tuple(reversed(range(8)))]
    for row in range(len(stations)-1):
        for a in range(8):
            b=row*8+a; c=row*8+(a+1)%8
            faces.append((b,c,c+8,b+8))
    faces.append(tuple(range((len(stations)-1)*8,len(stations)*8)))
    # Rings run counterclockwise in X/Z while stations advance along +Y.
    # Reverse every face so the closed hull faces outward in RealityKit.
    return mesh(name,verts,[tuple(reversed(face)) for face in faces],material,root)


def engine(root,x,y,z,r,length,m,tag):
    silver,dark,paint,accent,glow=m
    cylinder(tag+'Casing',(x,y,z),r,length,silver,root,vertices=24)
    for j in range(4): torus(tag+f'Band{j}',(x,y-length*.35+j*length*.23,z),r*1.01,.045,dark,root)
    cylinder(tag+'Intake',(x,y-length*.5-.06,z),r*.92,.17,dark,root)
    torus(tag+'Lip',(x,y-length*.5-.15,z),r*.9,.085,silver,root)
    cylinder(tag+'Hub',(x,y-length*.5-.2,z),r*.23,.18,accent,root)
    for j in range(10):
        a=j*math.tau/10
        ob=cube(tag+f'TurbineBlade{j}',(x+math.cos(a)*r*.53,y-length*.5-.19,z+math.sin(a)*r*.53),(r*.32,.035,r*.07),silver,root,.012)
        ob.rotation_euler.y=-a
    cylinder(tag+'Nozzle',(x,y+length*.5,z),r*.84,.38,dark,root)
    torus(tag+'ExhaustRim',(x,y+length*.5+.18,z),r*.77,.07,silver,root)
    cylinder(tag+'Plasma',(x,y+length*.5+.2,z),r*.66,.035,glow,root)
    for j in range(5):
        cube(tag+f'CoolingVent{j}',(x,y-length*.2+j*.23,z+r*.99),(r*.4,.06,.025),dark,root,.008)


def laser(root,pos,m,name='Laser'):
    silver,dark,paint,accent,glow=m
    x,y,z=pos
    cylinder(name+'Breech',(x,y+.5,z),.19,1.1,dark,root)
    cylinder(name+'Barrel',(x,y-.7,z),.08,1.8,silver,root)
    torus(name+'Muzzle',(x,y-1.6,z),.09,.025,glow,root)


def cockpit(root,y,z,m,width=.7,length=1.8):
    silver,dark,paint,accent,glow=m
    sphere('CanopyGlass',(0,y,z),(width,length,.48),dark,root,32)
    for side in (-1,1):
        tube('CanopyFrame',[(side*width*.8,y-length*.8,z),(side*width*.85,y,z+.35),(side*width*.75,y+length*.8,z)],.045,silver,root)
    for delta in (-.6,.4):
        tube('CanopyCrossRail',[(-width*.78,y+delta,z+.15),(0,y+delta,z+.48),(width*.78,y+delta,z+.15)],.04,silver,root)


def preview(key, root, target=(0,0,0), extent=25, level=False):
    # Camera/lights are preview-only and never exported.
    bpy.ops.object.camera_add(location=Vector(target)+Vector((extent*.8,-extent*.95,extent*.7)))
    camera=bpy.context.object
    camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO'; camera.data.ortho_scale=extent*1.3
    camera.data.clip_end=100000
    scene=bpy.context.scene; scene.camera=camera
    for loc,power,size in [((.4,-.4,1.2),1800,12), ((-.8,.3,.6),1400,10)]:
        bpy.ops.object.light_add(type='AREA',location=Vector(target)+Vector(loc)*extent)
        light=bpy.context.object; light.data.energy=power*(extent/25)**2; light.data.size=size*extent/25
        light.rotation_euler=(Vector(target)-light.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.light_add(type='SUN',location=(0,0,100))
    bpy.context.object.rotation_euler=(.4,-.3,-.5); bpy.context.object.data.energy=2
    scene.world=bpy.data.worlds.new('Studio'); scene.world.color=(.055,.07,.1)
    scene.render.engine='BLENDER_EEVEE_NEXT'; scene.eevee.taa_render_samples=24
    scene.render.resolution_x=720; scene.render.resolution_y=520; scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'; scene.render.filepath=str(PREVIEWS/(key+'.png'))
    bpy.ops.render.render(write_still=True)


def export(root,source,destination,ship=False):
    source.parent.mkdir(parents=True,exist_ok=True); destination.parent.mkdir(parents=True,exist_ok=True)
    if ship:
        # Blender's Y-forward -> -Z export makes an authored -Y nose face +Z.
        # Rotate the artwork once here, not the physics/camera parent in Swift.
        root.rotation_euler.z=math.pi
        front=bpy.data.objects.new('FlightForward',None); bpy.context.collection.objects.link(front); front.parent=root; front.location=(0,-20,0)
        rear=bpy.data.objects.new('FlightRear',None); bpy.context.collection.objects.link(rear); rear.parent=root; rear.location=(0,20,0)
    bpy.ops.object.select_all(action='DESELECT'); root.select_set(True)
    for child in root.children_recursive: child.select_set(True)
    bpy.context.view_layer.objects.active=root
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    usd(destination)


def usd(destination):
    bpy.ops.wm.usd_export(filepath=str(destination), selected_objects_only=True, export_materials=True,
        generate_preview_surface=True, export_textures=True, export_normals=True, export_curves=True,
        convert_orientation=True, export_global_forward_selection='NEGATIVE_Z',export_global_up_selection='Y')


def build_ship(key):
    if 'Podracer' in key:
        bpy.ops.wm.open_mainfile(filepath=str(ROOT/'Art/Blender/VoltwingPodracer.blend'))
        root=bpy.data.objects.get('VoltwingPodracer'); root.name='Ship_'+key
        colors={'anakinPodracer':(.95,.64,.04),'sebulbaPodracer':(.65,.18,.025),'quadinPodracer':(.35,.62,.12),'rattsPodracer':(.15,.55,.72),'nevaKeePodracer':(.7,.12,.08),'voltwingPodracer':(.035,.18,.42)}
        paint=bpy.data.materials.get('Voltwing Blue'); paint.diffuse_color=(*colors[key],1); paint.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(*colors[key],1)
        silver=bpy.data.materials.get('Brushed Beskar Alloy'); dark=bpy.data.materials.get('Carbon Armor'); accent=bpy.data.materials.get('Racing Stripe'); glow=bpy.data.materials.get('Energy Binder')
        m=(silver,dark,paint,accent,glow)
        if key=='quadinPodracer':
            for side in (-1,1): engine(root,side*16,-2,1,1.3,9,m,'AuxiliaryEngine')
        if key=='sebulbaPodracer':
            for side in (-1,1):
                plate('HammerheadIntake',[(side*9,-9),(side*15,-9),(side*16,-6),(side*9,-6)],2.3,.6,paint,root)
                for i in range(5): cube('IntakeGrille',(side*12,-9.1,1+i*.4),(2,.1,.09),dark,root)
        if key=='nevaKeePodracer':
            cube('IntegratedBridge',(0,2,1),(10,.6,.35),paint,root)
            for side in (-1,1): engine(root,side*3,3,1,.75,5,m,'PodThruster')
        if key=='rattsPodracer':
            for ob in root.children:
                if abs(ob.location.x)>5: ob.location.x*=.8
            plate('SplitTail',[(-3,4),(-3,8),(-1,7),(0,5)],1,.2,accent,root)
        # Preserve the original Voltwing detailing; other racers inherit its turbine/armor finish.
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        root=bpy.data.objects.new('Ship_'+key,None); bpy.context.collection.objects.link(root)
        silver=mat('Weathered alloy',(.46,.48,.5),.7,.36)
        paint=mat('Ceramic hull',(.67,.68,.65),.45,.35)
        dark=mat('Recesses and glass',(.018,.03,.045),.65,.2)
        accent=mat('Squadron markings',(.65,.06,.025),.3,.38)
        glow=mat('Drive plasma',(.12,.6,1),.2,.15,(.08,.45,1))
        m=(silver,dark,paint,accent,glow)
        if key=='millenniumFalcon':
            # Stepped saucer, recessed edge belt, long separated mandibles, starboard cockpit.
            cylinder('HullBelt',(0,0,0),7,.65,dark,root,'Z',64)
            sphere('UpperSaucer',(0,0,.3),(7,7,.8),paint,root,64)
            sphere('LowerSaucer',(0,0,-.3),(6.8,6.8,.7),silver,root,48)
            for side in (-1,1):
                plate('ForwardMandible',[(side*1,-3),(side*1,-10),(side*3.4,-9.6),(side*5,-3)],0,1.2,paint,root)
                for j in range(5): cube('MandibleInset',(side*2.5,-5-j*.8,.67),(.65,.25,.035),dark,root,.015)
            for i in range(28):
                a=i*math.tau/28
                tube('RadialPanelSeam',[(math.cos(a)*2,math.sin(a)*2,1.06),(math.cos(a)*4.8,math.sin(a)*4.8,.87),(math.cos(a)*6.4,math.sin(a)*6.4,.62)],.026,dark,root)
                if i%3==0: cube('HullServicePanel',(math.cos(a)*4.8,math.sin(a)*4.8,.9),(.38,.28,.05),silver,root,.02)
            for x in (-3.1,0,3.1):
                for y in (2.7,4.3):
                    cylinder('ExhaustVent',(x,y,.98),.57,.13,dark,root,'Z',24)
                    for i in range(5): cube('VentSlat',(x+(i-2)*.18,y,1.07),(.035,.43,.03),silver,root,.008)
            tube('StarboardAccessTube',[(-4,-1,.2),(-6,-2,.2),(-7,-4,.2)],.65,paint,root)
            cylinder('CockpitTunnel',(-7,-4.2,.2),.85,2.3,paint,root)
            sphere('OffsetCockpit',(-7,-5.5,.25),(.75,1.1,.65),dark,root)
            for s in (-1,1): tube('CockpitRib',[(-7+s*.5,-6,.6),(-7+s*.6,-5,.85),(-7+s*.6,-4.6,.6)],.06,silver,root)
            for j in range(19):
                a=math.pi*.15+j*math.pi*.7/18
                sphere('RearEngineStrip',(6.94*math.cos(a),6.94*math.sin(a),0),(.3,.2,.23),glow,root,12)
            cylinder('DorsalTurret',(0,0,1.25),.85,.4,silver,root,'Z')
            for x in (-.3,.3): laser(root,(x,-.8,1.5),m,'QuadCannon')
            cylinder('SensorDishStem',(2,-1.4,1.5),.13,1,silver,root,'Z')
            dish=sphere('SensorDish',(2,-1.4,2),(1,.9,.13),silver,root); dish.rotation_euler.x=.4
        elif key in ('xwing','starkJet'):
            hull('Fuselage',[(-8,.2,.25,0),(-3,.7,.6,0),(1,1,.7,0),(4,.8,.6,0)],paint,root)
            cockpit(root,-1.7,.8,m,.65,1.4)
            for side in (-1,1):
                for up in (-1,1):
                    z=up*1.5
                    ob=plate('SFoil',[(side*.9,0),(side*6,1.3),(side*6,3),(side*1,3.3)],0,.16,paint,root)
                    ob.rotation_euler.y=-side*up*.23
                    engine(root,side*1.6,2,up*.6,.55,3.8,m,'IonEngine')
                    laser(root,(side*6,-.1,z),m,'WingtipCannon')
                    cube('PaintStripe',(side*4,1.9,z*.65),(1.1,.18,.05),accent,root)
            sphere('Astromech',(0,.6,.95),(.4,.4,.45),glow,root)
        elif key=='tieFighter':
            sphere('CockpitBall',(0,0,0),(1.9,1.9,1.9),silver,root,32)
            cylinder('Viewport',(0,-1.8,0),1.1,.16,dark,root)
            torus('ViewportRim',(0,-1.92,0),1.06,.1,silver,root)
            for i in range(8):
                a=i*math.tau/8; tube('WindowSpoke',[(0,-2,0),(math.cos(a),-2,math.sin(a))],.045,silver,root)
            for side in (-1,1):
                cylinder('WingPylon',(side*2.6,0,0),.35,2,silver,root,'X')
                pts=[(side*3.8,math.cos(i*math.tau/6)*3.9,math.sin(i*math.tau/6)*4.5) for i in range(6)]
                vertices=[(x-.06,y,z) for x,y,z in pts]+[(x+.06,y,z) for x,y,z in pts]
                faces=[tuple(reversed(range(6))),tuple(range(6,12))]
                faces += [(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)]
                mesh('HexagonalSolarPanel',vertices,faces,dark,root)
                for i in range(6):
                    tube('SolarWingFrame',[pts[i],pts[(i+1)%6]],.13,silver,root)
                    tube('SolarWingSpar',[(side*3.8,0,0),pts[i]],.08,silver,root)
                for i in range(-7,8): tube('SolarCellLine',[(side*3.82,-2,i*.42),(side*3.82,2,i*.42)],.018,silver,root)
                laser(root,(side*.7,-1.4,-.9),m)
                sphere('IonExhaust',(side*.8,1.8,0),(.3,.1,.3),glow,root)
        elif key in ('enterprise','voyager'):
            rx=7.8 if key=='enterprise' else 6.3
            sphere('Saucer',(0,-3,1),(rx,5.5,.6),paint,root,64)
            for r in (2,3.5,4.8): torus('SaucerPanelRing',(0,-3,1.48),r,.018,silver,root,'Z')
            sphere('Bridge',(0,-3,1.7),(1.2,1,.35),silver,root)
            hull('EngineeringHull',[(0,1,.7,-.8),(3,2,1.3,-.8),(7,1.3,1,-.8),(9,.5,.5,-.8)],paint,root)
            cube('Neck',(0,.7,.1),(.5,1.2,1),silver,root)
            cylinder('Deflector',(0,.0,-1),.75,.3,glow,root)
            for side in (-1,1):
                plate('NacellePylon',[(side*.8,3),(side*6,4),(side*6,5.2),(side*.8,4.5)],.5,.25,silver,root)
                sphere('WarpNacelle',(side*6,5,1.1),(.85,4.4,.75),paint,root)
                sphere('BussardCollector',(side*6,.8,1.1),(.7,.5,.6),accent,root)
                cube('WarpGrille',(side*6,5,1.8),(.3,3,.08),glow,root)
                for j in range(18): cube('NacelleGrilleSlat',(side*6,2+j*.34,1.9),(.32,.035,.025),silver,root,.008)
            for j in range(54):
                a=j*math.tau/54
                sphere('SaucerWindow',(math.cos(a)*rx*.93,-3+math.sin(a)*5.1,1.05),(.055,.055,.07),glow,root,8)
        elif key=='birdOfPrey':
            paint=mat('Klingon armor',(.16,.3,.14),.65,.4);m=(silver,dark,paint,accent,glow)
            hull('MainHull',[(-7,.6,.6,0),(-4,1.3,1,0),(0,.7,.5,0),(3,3,1.2,0),(6,2,.6,0)],paint,root)
            for side in (-1,1):
                plate('SweptWing',[(side*2,1),(side*9,3),(side*10,6),(side*3,5)],-.4,.25,paint,root)
                for i in range(7): cube('FeatherArmor',(side*(3+i*.85),3+i*.17,-.15),(.3,1.2,.12),silver,root)
                laser(root,(side*9,1,-.3),m)
                engine(root,side*1.7,4,0,.65,3,m,'AftDrive')
            cockpit(root,-5,.8,m)
        else:
            # Distinct silhouettes for each remaining vehicle.
            if key=='aWing':
                hull('Fuselage',[(-5,.5,.3,0),(-2,2,.7,0),(2,2.4,.65,0),(4,1.7,.5,0)],paint,root)
                cockpit(root,0,.8,m)
                for side in (-1,1):
                    engine(root,side*1.8,2,0,.6,4,m,'Drive')
                    fin=cube('TailFin',(side*1.8,3,1),(.1,1,1),accent,root)
                    laser(root,(side*2.5,-1,0),m)
            elif key=='yWing':
                hull('CockpitHead',[(-7,.7,.35,0),(-5,1.5,.6,0),(-2,1,.5,0),(3,.6,.4,0)],paint,root)
                cockpit(root,-5,.65,m)
                for side in (-1,1):
                    cube('EnginePylon',(side*2,0,0),(2,.35,.2),silver,root)
                    engine(root,side*3.5,0,0,.9,8,m,'Engine')
                    for sign in (-1,1): tube('ExposedSpar',[(side*3.5+sign*.8,2,.0),(side*3.5+sign*.8,7,0)],.1,silver,root)
                    torus('AftStabilizer',(side*3.5,7,0),.85,.1,silver,root)
                for i in range(8): cube('ExposedReactor',(0,-1+i*.5,.6),(.55,.16,.17),dark,root)
            elif key=='n1Starfighter':
                paint=mat('Naboo yellow',(.95,.64,.025),.75,.25);m=(silver,dark,paint,accent,glow)
                hull('Fuselage',[(-6,.12,.2,0),(-2,.8,.5,0),(1,.9,.6,0),(6,.05,.1,0)],paint,root)
                cockpit(root,-.6,.7,m,.55,1.2)
                plate('SweptWing',[(-5,0),(-3,-2),(0,-1),(3,-2),(5,0),(0,2)],0,.18,paint,root)
                for side in (-1,1):
                    engine(root,side*4.5,-1,0,.65,4,m,'NeedleEngine')
                    cylinder('EngineNeedle',(side*4.5,3,0),.08,5,silver,root)
            elif key=='novaSkiff':
                hull('Fuselage',[(-3,.4,.3,0),(0,1,.55,0),(3,.8,.5,0)],paint,root);cockpit(root,0,.6,m)
                for side in (-1,1):
                    plate('InterceptorWing',[(side*1,-2),(side*4,-3),(side*4,2),(side*1,2)],0,.2,accent,root)
                    cube('SolarInset',(side*3,0,.15),(.65,1.6,.04),dark,root)
                    engine(root,side*1.2,2,0,.45,2,m,'Drive');laser(root,(side*3.6,-2,.1),m)
            elif key=='meridian':
                hull('TroopBay',[(-6,1,.7,0),(-3,2,1,0),(4,2,1,0),(6,1,.7,0)],paint,root);cockpit(root,-4,1,m,1,1.3)
                for side in (-1,1):
                    plate('ForwardSwingWing',[(side*1,2),(side*7,-7),(side*8,-6),(side*3,4)],0,.22,paint,root)
                    for j in range(2): engine(root,side*(2.2+j*1.1),4,.5,.5,4,m,'TransportEngine')
                    cube('TroopDoor',(side*2.01,0,0),(.04,1.7,.8),dark,root)
                    for j in range(4): cube('DoorRail',(side*2.06,-1.4+j*.8,0),(.035,.035,.75),silver,root)
            elif key=='atlas':
                hull('GunshipHull',[(-7,.8,.5,0),(-3,1.8,1.5,0),(3,2,1.6,0),(6,1,.5,0)],paint,root)
                cockpit(root,-5,1,m,.8,1);cockpit(root,-2.8,1.6,m,.8,1)
                for side in (-1,1):
                    plate('GunshipWing',[(side*1,0),(side*7,2),(side*6,4),(side*1,2)],1.6,.25,paint,root)
                    engine(root,side*1.2,2,2.4,.55,6,m,'TopEngine')
                    sphere('BallTurret',(side*5,2,.8),(.75,.75,.75),dark,root)
                    cube('OpenTroopBay',(side*1.96,1,0),(.05,1.8,.9),dark,root)
                    laser(root,(side*1.3,-5,-.6),m)
            elif key=='falcon':
                hull('Fuselage',[(-7,.3,.4,0),(-3,.9,.8,0),(4,1,.65,0)],paint,root)
                for j in range(3): cockpit(root,-3+j*1.6,.85,m,.65,.65)
                for side in (-1,1):
                    plate('BroadWing',[(side*1,0),(side*7,1),(side*6,4),(side*1,3)],0,.2,paint,root)
                    engine(root,side*2.3,2,0,.85,5,m,'MainEngine');laser(root,(side*6.4,0,0),m)
                    for up in (-1,1):
                        foil=plate('AttackFoil',[(side*2,1),(side*6,1.5),(side*5,3),(side*2,3)],0,.12,accent,root);foil.rotation_euler.y=side*up*.22
                engine(root,0,3,-.5,.45,3,m,'RearEngine')
            else: # T-47: low triangular armor, twin side cannons and rear cooling grilles.
                plate('SnowspeederHull',[(-.7,-5),(-4,-1),(-4,3),(4,3),(4,-1),(.7,-5)],0,.9,paint,root)
                cockpit(root,0,.8,m,.9,1.7)
                for side in (-1,1):
                    laser(root,(side*3.5,-2,.35),m)
                    engine(root,side*1.6,2,-.3,.45,2,m,'Repulsor')
                    for j in range(8): cube('CoolingGrille',(side*2,1+j*.2,.52),(.8,.04,.045),dark,root)
        # Small service panels, warning markings and navigation lamps common to the finish.
        for side in (-1,1):
            for j in range(5): cube('HullPanel',(side*.72,-2+j*.8,.65),(.12,.24,.035),silver,root,.015)
            sphere('NavigationLamp',(side*1.1,1,.8),(.065,.065,.065),glow,root,12)
    export(root,SOURCE/'Ships'/f'Ship_{key}.blend',ASSETS/'Ships'/f'Ship_{key}.usdz',ship=True)
    # Undo export yaw only for the authoring preview camera.
    root.rotation_euler.z=0
    extent=38 if 'Podracer' in key else 23
    preview('Ship_'+key,root,(0,0,0),extent)
    print('FINISHED SHIP',key,flush=True)


def build_level(key):
    data=json.loads((ROOT/'Art/LevelSurfaces'/f'{key}.json').read_text())
    bpy.ops.wm.read_factory_settings(use_empty=True)
    root=bpy.data.objects.new('Level_'+key,None);bpy.context.collection.objects.link(root)
    materials=[mat('Ground'+str(i),tuple(c),.45 if key=='deathStar' else .04,.8) for i,c in enumerate(data['palette'])]
    rock=materials[2]; dark=mat('Recess',(.025,.035,.045),.45,.5)
    metal=mat('Structure',(.31,.33,.35),.65,.4)
    glow=mat('Energy',PALETTES[key][1],.1,.25,PALETTES[key][1])
    road=mat('RaceSurface',tuple(c*.65 for c in PALETTES[key][0]),.1,.85)
    all_sections=[]
    dest=ASSETS/'Terrain'/key;dest.mkdir(parents=True,exist_ok=True)
    for tile in data['tiles']:
        tx,tz=tile['x'],tile['z']; heights=tile['heights']
        for divisions in (24,8):
            step=24//divisions
            verts=[];faces=[]
            for j in range(divisions+1):
                for i in range(divisions+1): verts.append((i*600/divisions,-j*600/divisions,heights[j*step*25+i*step]))
            for j in range(divisions):
                for i in range(divisions):
                    a=j*(divisions+1)+i;b=a+1;c=a+divisions+1;d=c+1
                    faces.extend([(a,c,b),(b,c,d)])
            # Vertical skirts hide boundaries between near and far LODs.
            for side in ([i for i in range(divisions+1)], [i*(divisions+1)+divisions for i in range(divisions+1)], [divisions*(divisions+1)+i for i in range(divisions+1)], [i*(divisions+1) for i in range(divisions+1)]):
                for a,b in zip(side,side[1:]):
                    n=len(verts);verts.extend([(verts[a][0],verts[a][1],verts[a][2]-160),(verts[b][0],verts[b][1],verts[b][2]-160)])
                    faces.extend([(a,b,n),(b,n+1,n)])
            ob=mesh(f'Terrain_{tx}_{tz}_{divisions}',verts,faces,materials[0],root)
            for material in materials[1:]: ob.data.materials.append(material)
            for face in ob.data.polygons:
                h=face.center.z
                face.material_index=4 if h>data['snowLine'] else 3 if face.normal.z<.65 else 2 if h>570 else 1 if h>240 else 0
            # Detail groups are authored on this exact tile, not floating repeated scenery.
            before=set(root.children)
            rng=random.Random(key+str(tx)+str(tz))
            for j in range(2):
                ix=rng.randint(3,21);iz=rng.randint(3,21)
                x=ix*25;z=iz*25;h=heights[iz*25+ix]
                wz=tz*600+z;wx=tx*600+x
                ci=(tz-data['minZ'])*24+iz
                center=data['centers'][ci]
                if abs(wx-center)<data['width']*.85: continue
                if key in ('endor','lantaana'):
                    cylinder('Tree',(x,-z,h+28),4,56,rock,root,'Z',8)
                    for k in range(3): cone('Canopy',(x,-z,h+60+k*15),27-k*5,40,materials[1],root,10)
                elif key in ('deathStar','corellia','narShaddaa','ordMantell','sentinelOne','glacier'):
                    towerHeight=22 if key=='deathStar' else 55+j*40
                    cube('Tower',(x,-z,h+towerHeight/2),(18,24,towerHeight/2),metal,root,.3)
                    for k in range(5): cube('WindowBand',(x,-z,h+8+k*towerHeight/6),(18.1,24.1,.6),glow,root,.01)
                    for k in range(3): cube('RoofVent',(x-9+k*9,-z,h+towerHeight+1),(2,12,1),dark,root,.1)
                elif key=='skylands':
                    cylinder('FloatingPlatform',(x,-z,h+80),40,8,metal,root,'Z',24)
                    sphere('CityDome',(x,-z,h+86),(26,26,14),materials[4],root)
                else:
                    cone('RockSpire',(x,-z,h+35),16,70,rock,root,7)
                    if key in ('volcano','storm'): tube('EnergyFissure',[(x-12,-z,h+2),(x,-z+15,h+4),(x+14,-z,h+1)],1.2,glow,root)
            # Race track surface markings follow the sampled hairpins, with no raised rings.
            if data['race'] or key=='deathStar':
                for j in range(0,24,4):
                    c=data['centers'][(tz-data['minZ'])*24+j]
                    for side in (-1,1):
                        wx=c+side*(data['width']*.68 if data['race'] else 250)
                        x=wx-tx*600
                        if 5<x<595:
                            ix=min(24,max(0,round(x/25)));h=heights[j*25+ix]
                            cube('TrackEdgeBeacon',(x,-j*25,h+2),(2,14,2),glow,root,.03)
            props=[p for p in root.children if p not in before]
            bpy.ops.object.select_all(action='DESELECT');ob.select_set(True)
            for p in props:p.select_set(True)
            bpy.context.view_layer.objects.active=ob
            bpy.ops.object.convert(target='MESH')
            bpy.ops.object.join()
            ob.name=f'Terrain_{tx}_{tz}_{divisions}'
            usd(dest/f'{tx}_{tz}_{divisions}.usdz')
            # Retain full terrain in the editable .blend; far LOD only lives in USDZ.
            if divisions==8: bpy.data.objects.remove(ob,do_unlink=True)
            else:
                ob.location=(tx*600,-tz*600,0);all_sections.append(ob)
        if tx==3: print('TERRAIN',key,'row',tz,flush=True)
    (SOURCE/'Levels').mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'Levels'/f'Level_{key}.blend'))
    # Overview exported as the level asset as well; gameplay streams the individual tiles.
    # Use a nearby subset for a useful preview and a compact planner overview asset.
    bpy.ops.object.select_all(action='DESELECT')
    for ob in all_sections:
        visible=abs(ob.location.x)<1201 and -600<=ob.location.y<=1800
        ob.hide_render=not visible
        ob.select_set(visible)
    usd(ASSETS/'Levels'/f'Level_{key}.usdz')
    preview('Level_'+key,root,(0,500,180),2200,True)
    print('FINISHED LEVEL',key,flush=True)

if __name__ == '__main__':
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['all']
    mode=args[0] if args else 'all'; selected=args[1:]
    if mode in ('all','ships'):
        for key in SHIPS:
            if not selected or key in selected:build_ship(key)
    if mode in ('all','levels'):
        for key in LEVELS:
            if not selected or key in selected:build_level(key)
