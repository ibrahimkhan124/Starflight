"""Editable, geometry-based fleet finish. No textures or per-part game entities required.

All positions use the authoring convention: nose -Y, up +Z. The common panels
are ray fitted to real hull surfaces, while named hardware follows each craft.
"""
import math
import bpy
from mathutils import Vector
from create_blender_asset_library import mat, cube, cylinder, torus, tube
from create_blender_library_v2 import plate


def bounds(root, objects):
    points = [root.matrix_world.inverted() @ o.matrix_world @ Vector(v)
              for o in objects for v in o.bound_box]
    return (Vector(tuple(min(p[i] for p in points) for i in range(3))),
            Vector(tuple(max(p[i] for p in points) for i in range(3))))


def add_fleet_details(key, root, empty):
    old = bpy.data.objects.get('FleetScenicRefit')
    if old:
        for child in list(old.children_recursive): bpy.data.objects.remove(child, do_unlink=True)
        bpy.data.objects.remove(old, do_unlink=True)
    bpy.context.view_layer.update()
    original = [o for o in root.children_recursive if o.type == 'MESH']
    lo, hi = bounds(root, original)
    span, length = hi.x-lo.x, hi.y-lo.y
    group = empty('FleetScenicRefit', root)
    dark = mat('Refit graphite recess', (.026, .039, .052), .45, .47)
    steel = mat('Refit satin titanium', (.38, .43, .46), .76, .34)
    light = mat('Refit ceramic inspection covers', (.57, .59, .57), .32, .48)
    amber = mat('Refit warning enamel', (.81, .34, .045), .22, .48)
    lamp = mat('Refit instrument and navigation light', (.1, .6, .8), .15, .25, (.04, .42, .7))
    detail_count = 0

    def top(x, y):
        start = root.matrix_world @ Vector((x, y, hi.z+5))
        direction = root.matrix_world.to_3x3() @ Vector((0, 0, -1))
        hits = []
        for obj in original:
            if any(word in obj.name.lower() for word in ('canopy', 'cockpit', 'glass', 'window', 'plasma', 'energy', 'dish', 'solar', 'lamp', 'stripe')):
                continue
            inverse = obj.matrix_world.inverted()
            hit, point, normal, _ = obj.ray_cast(inverse @ start, inverse.to_3x3() @ direction)
            if not hit: continue
            point = root.matrix_world.inverted() @ obj.matrix_world @ point
            normal = root.matrix_world.inverted().to_3x3() @ obj.matrix_world.to_3x3().inverted().transposed() @ normal
            if normal.normalized().z > .55: hits.append((point.z, point, normal.normalized()))
        return max(hits, key=lambda h:h[0])[1:] if hits else None

    def panel(x, y, sx, sy, style=0):
        nonlocal detail_count
        hit = top(x, y)
        if not hit: return
        p, n = hit
        rotation = Vector((0, 0, 1)).rotation_difference(n)
        # Reject tiles crossing a wing edge or a hull step. The complete tile
        # must sit on one continuous supporting surface, rather than float.
        for dx,dy in ((-sx,-sy),(-sx,sy),(sx,-sy),(sx,sy)):
            corner=p+rotation @ Vector((dx,dy,0))
            support=top(corner.x,corner.y)
            if not support or abs(support[0].z-corner.z) > .12 or support[1].dot(n) < .93:
                return
        def piece(name, offset, size, material):
            ob = cube(name, p+n*.025+rotation @ Vector(offset), size, material, group, 0)
            ob.rotation_euler = rotation.to_euler()
            return ob
        piece('Recessed armour panel joint', (0, 0, 0), (sx, sy, .018), dark)
        piece('Raised replaceable armour tile', (0, 0, .026), (sx*.87, sy*.88, .014), steel if style%3 == 0 else light)
        if style%3 == 1:
            for j in range(5):
                piece('Radiator louvre', (0, (j-2)*sy*.28, .047), (sx*.73, sy*.055, .014), dark)
        elif style%3 == 2:
            for sign in (-1, 1):
                piece('Safety stencil bars', (sign*sx*.5, 0, .047), (sx*.07, sy*.6, .009), amber)
            piece('Access latch', (0, sy*.48, .054), (sx*.22, sy*.12, .012), dark)
        else:
            for sign in (-1, 1):
                piece('Inspection cover hinge', (sign*sx*.58, sy*.63, .052), (sx*.1, sy*.12, .012), dark)
        detail_count += 1

    # Panel density scales with the craft, without painting over cockpit glazing.
    # Every tile is a closed solid, lifted only a few centimetres above its host.
    for row in range(7):
        fy = .13+row*.115
        for col in range(7):
            if (row+col)%2: continue
            fx = .14+col*.12
            panel(lo.x+span*fx, lo.y+length*fy,
                  min(span*.022, .38), min(length*.027, .52), row+col//2)

    # Sealed canopy perimeter and segmented structural glazing bars.
    for obj in original:
        if obj.name.split('.')[0] not in ('CanopyGlass', 'Canopy', 'OffsetCockpit'):
            continue
        a, b = bounds(root, [obj]); c = (a+b)*.5; r = (b-a)*.5
        if r.x < .2: continue
        for side in (-1, 1):
            tube('Canopy pressure seal', [(c.x+side*r.x*.72, c.y+t*r.y, c.z+r.z*math.sqrt(max(.03, .48-t*t)))
                 for t in (-.64, -.32, 0, .32, .64)], min(r.x*.045,.06), steel, group)
        for t in (-.5, .5):
            z = c.z+r.z*math.sqrt(1-t*t)
            edge=c.z+r.z*math.sqrt(1-t*t-.49)
            tube('Canopy transverse reinforcement', [(c.x-r.x*.7,c.y+t*r.y,edge+.015),
                 (c.x,c.y+t*r.y,z+.018),(c.x+r.x*.7,c.y+t*r.y,edge+.015)], min(r.x*.03,.045), steel, group)

    # Each engine gets fitted heat shields, coolant conduits and segmented nozzle petals.
    for obj in original:
        if not (obj.name.split('.')[0].endswith('Casing') or obj.name in ('LeftEngine', 'RightEngine')):
            continue
        a, b = bounds(root, [obj]); c=(a+b)*.5; r=(b.x-a.x)*.5; half=(b.y-a.y)*.5
        if half < r*.7: continue
        for i in range(8):
            angle=i*math.tau/8
            radial=Vector((math.cos(angle),0,math.sin(angle)))
            position=c+radial*r*1.015
            shield=cube('Longitudinal engine heat shield', position, (r*.13, half*.45, .028), steel, group, 0)
            shield.rotation_euler.y=math.pi/2-angle
            nozzle=cube('Segmented exhaust nozzle petal', c+Vector((0,half+.17,0))+radial*r*.78,
                        (r*.19,.22,.035), dark, group, 0)
            nozzle.rotation_euler.y=math.pi/2-angle
        for side in (-1,1):
            tube('Engine coolant return pipe', [(c.x+side*r*.9,c.y-half*.65,c.z+r*.48),
                 (c.x+side*r*1.06,c.y-half*.4,c.z+r*.5),
                 (c.x+side*r*1.06,c.y+half*.45,c.z+r*.5),
                 (c.x+side*r*.9,c.y+half*.65,c.z+r*.48)], min(r*.045,.07), amber, group)

    def deck_kit(x, y, sx=.35, sy=.6):
        panel(x,y,sx,sy,1)
        hit=top(x,y)
        if hit:
            p,n=hit
            tube('Exposed reactor hydraulic line', [tuple(p+Vector((-sx,-sy,.1))),
                 tuple(p+Vector((-sx,sy*.3,.1))),tuple(p+Vector((sx,sy,.1)))], .035, steel, group)

    def antenna(x,y,h=.5):
        hit=top(x,y)
        if hit:
            p,n=hit
            cylinder('Sensor mounting flange', p+n*.06,.16,.12,steel,group,'Z',12)
            tube('Comms sensor mast',[tuple(p+n*.1),tuple(p+n*h)],.025,dark,group)

    # Craft-specific equipment makes the surface language follow the silhouette.
    if key in ('xwing','starkJet','falcon'):
        for side in (-1,1):
            for x,y in ((side*3,1.6),(side*4.8,2.1)):
                panel(x,y,.35,.5,2)
            cylinder('Wing actuator pivot',(side*1.05,1.3,0),.32,.4,steel,group,'X',16)
            tube('S-foil hydraulic piston',[(side*1.1,.3,.25),(side*2.8,1.3,.42)],.055,dark,group)
        deck_kit(0,2.4,.3,.65)
        antenna(.5,1.1,.7)
        if key in ('xwing','starkJet'):
            for side in (-1,1):
                for up in (-1,1):
                    tube('Wingtip cannon structural saddle',[(side*5.9,1.65,up*1.36),
                         (side*6,.35,up*1.5)],.12,steel,group)
            astromech=bpy.data.objects.get('Astromech')
            if astromech:
                astromech.data.materials[0]=light
                cylinder('Astromech dome equator',(0,.6,.93),.405,.09,dark,group,'Z',16)
                cube('Astromech optical sensor',(0,.22,1.08),(.10,.035,.08),dark,group,0)
                for side in (-1,1): cube('Astromech dome panel',(side*.24,.48,1.2),(.06,.09,.055),steel,group,0)
    elif key == 'kestrel':
        for side in (-1,1):
            panel(side*2.4,-1,.52,.85,2)
            tube('Cannon power conduit',[(side*2.7,-1.9,.57),(side*2.7,1.7,.57),(side*1.8,2.6,.57)],.045,steel,group)
        cylinder('Rear tow-cable spool',(0,2.6,.6),.42,.28,dark,group,'Y',16)
        tube('Rear harpoon barrel',[(0,2.8,.7),(0,3.5,.7)],.075,steel,group)
    elif key == 'meridian':
        for side in (-1,1):
            cylinder('Swing-wing bearing',(side*2.4,2.5,.24),.5,.14,steel,group,'Z',16)
            for j in range(4): cube('Troop bay floor tread',(side*2.08,-1+j*.65,-.65),(.025,.18,.03),amber,group,0)
            panel(side*4,-2.6,.23,.72,2)
        antenna(0,3,.7)
    elif key == 'atlas':
        for side in (-1,1):
            for j in range(4):
                cylinder('Wing rocket launch tube',(side*(2.4+j*.6),2,1.45),.18,2.1,dark,group,vertices=12)
                torus('Rocket launch tube rim',(side*(2.4+j*.6),.93,1.45),.17,.03,steel,group)
            tube('Ball turret weapon barrel',[(side*5,1.45,.8),(side*5,-.1,.8)],.075,steel,group)
            cube('Troop bay sliding rail',(side*2.03,1,1.1),(.035,1.7,.045),steel,group,0)
        antenna(0,4,.9)
    elif key == 'aWing':
        for side in (-1,1):
            panel(side*1.2,-2.3,.38,.75,2)
            tube('Side cannon power cable',[(side*2.1,-1,.35),(side*1.65,.6,.55)],.045,dark,group)
        deck_kit(0,2.1,.32,.6)
    elif key == 'yWing':
        for side in (-1,1):
            tube('Exposed thrust control plumbing',[(side*.55,-1.7,.65),(side*.8,-.8,.65),
                 (side*.8,2.4,.65),(side*3.5,2.8,.55)],.07,steel,group)
            for j in range(5): cube('Reactor heat exchanger',(side*.6,.1+j*.42,.7),(.13,.12,.12),amber,group,0)
        cylinder('Dorsal ion turret',(0,-3.1,.75),.4,.24,steel,group,'Z',16)
        for side in (-1,1): tube('Twin ion turret gun',[(side*.16,-3.1,.94),(side*.16,-4.6,.94)],.045,dark,group)
    elif key == 'n1Starfighter':
        for side in (-1,1):
            panel(side*2.7,-.2,.4,.25,2)
            tube('Polished engine root trim',[(side*1.3,.3,.18),(side*3.4,-.4,.2),(side*4.2,-1.2,.2)],.045,steel,group)
        antenna(0,2.2,.45)
    elif key == 'novaSkiff':
        for side in (-1,1):
            for j in range(5): cube('Solar wing cell divider',(side*3,-1.2+j*.6,.21),(.62,.018,.018),steel,group,0)
            cylinder('Wing hinge actuator',(side*1.25,0,.17),.18,.9,steel,group,vertices=12)
            panel(side*2.1,-1.4,.33,.35,2)
        antenna(0,1.8,.45)
    elif key in ('enterprise','voyager'):
        rx=7.8 if key=='enterprise' else 6.3
        for i in range(32):
            a=i*math.tau/32
            x,y=math.cos(a)*rx*.78,-3+math.sin(a)*4.4
            panel(x,y,.18,.25,i)
        for side in (-1,1):
            cube('Nacelle lateral warp grille',(side*6.82,5,1.12),(.025,2.9,.16),lamp,group,0)
            for j in range(12): cube('Warp coil side baffle',(side*6.85,2.2+j*.5,1.12),(.035,.06,.17),steel,group,0)
        for row in range(3):
            for j in range(9): cube('Engineering hull porthole',(1.72,2.8+j*.44,-.3-row*.28),(.025,.07,.035),lamp,group,0)
        cube('Shuttle bay doors',(0,8.65,-.45),(.48,.03,.27),dark,group,0)
    elif key == 'birdOfPrey':
        for side in (-1,1):
            for i in range(8):
                x=side*(3.2+i*.7)
                panel(x,3.8+i*.12,.21,.65,2)
                tube('Wing feather armour edge',[(x,3.0+i*.12,-.24),(x,5.2+i*.12,-.24)],.035,dark,group)
        antenna(0,3,.6)
    elif key == 'millenniumFalcon':
        for side in (-1,1):
            for j in range(9):
                a=side*(.25+j*.12)
                x,y=math.cos(a)*6.95,math.sin(a)*6.95
                cube('Recessed circular hull belt machinery',(x,y,0),(.14,.22,.16),steel,group,0)
            deck_kit(side*3.8,.4,.38,.6)
            tube('Dorsal exposed cable run',[(side*1.5,.5,1.03),(side*2,1.6,1.03),(side*3.5,2.2,.98)],.05,dark,group)
        for x in (-.27,.27):
            tube('Dorsal quad cannon lower barrel',[(x,-.2,1.37),(x,-2.4,1.37)],.055,dark,group)
    elif key == 'razorCrest':
        for side in (-1,1):
            for j in range(6):
                cube('Cargo fuselage inset panel',(side*3.05,-4+j*2.25,.1),(.04,.8,.72),dark,group,0)
                cube('Cargo fuselage armour plate',(side*3.1,-4+j*2.25,.1),(.025,.72,.64),steel,group,0)
            tube('Cargo bay overhead pipe',[(side*1.6,-2,2.63),(side*1.6,5,2.47),(side*1.2,7,2.16)],.09,dark,group)
            for j in range(4):cube('Wing root anti-slip walkway',(side*5.4,-1.2+j*.7,1.54),(1.8,.15,.025),dark,group,0)
        for j in range(5): cube('Rear loading ramp tread',(0,11.14,-.85+j*.4),(1.7,.035,.035),steel,group,0)
        antenna(1.3,3.2,.8)
    elif key == 'bWing':
        for sign in (-1,1):
            tube('Cross-foil hydraulic feed',[(2.2,.4,sign*.2),(3.1,.8,sign*2.3)],.065,dark,group)
            cylinder('Cross-foil deployment motor',(2.8,1.3,sign*.6),.24,.65,steel,group,'X',16)
            tube('Cross-foil cannon mounting saddle',[(3.5,.7,sign*2.8),
                 (3.5,-.2,sign*2.9)],.12,steel,group)
        for j in range(6):
            panel(1+j*.9,1.3,.28,.34,j)
        tube('Heavy cannon armoured power bus',[(2.2,1.7,.28),(6.8,1.6,.28),(8.1,.4,.28)],.065,steel,group)
        tube('Heavy blade cannon mounting saddle',[(8.1,1.25,.17),(8.1,.1,.1)],.14,steel,group)
        antenna(-3.4,-1.4,.65)
    elif key == 'imperialShuttle':
        for side in (-1,1):
            for j in range(7):
                cube('Dorsal fin inset armour tile',(side*.27,2.4+j*.42,4.4),(.018,.15,1.05),dark,group,0)
                tube('Wing hinge hydraulic strut',[(side*2.8,-.8,.65),(side*4.7,1,-.55)],.08,steel,group)
            for j in range(5):
                cube('Wing landing stripe',(side*(5.2+j*.85),5.7,.8-(2.7+j*.85)*.6+.15),(.18,.45,.028),dark,group,0)
            panel(side*1.2,1.1,.5,1.1,1)
        for j in range(5): cube('Command deck aft console vent',(0,-4.5+j*.32,1.84),(.8,.08,.03),dark,group,0)
    elif key in ('tieFighter','tieDefender'):
        # Armoured pressure sphere plating and its aft reactor heat exchangers.
        radius=1.9 if key=='tieFighter' else 1.55
        for j in range(8):
            a=j*math.tau/8
            x,z=math.cos(a)*radius*.82,math.sin(a)*radius*.82
            tile=cube('Command sphere armour segment',(x,.95,z),(.21,.045,.24),dark,group,0)
            tile.rotation_euler.y=math.pi/2-a
        cylinder('Aft reactor pressure cover',(0,radius*.95,0),radius*.48,.13,dark,group,vertices=16)
        torus('Aft reactor service rim',(0,radius*1.01,0),radius*.48,.045,steel,group)
        for j in range(7): cube('Aft reactor heat exchanger',((j-3)*radius*.105,radius*1.06,0),(.035,.035,radius*.32),steel,group,0)
        if key=='tieFighter':
            for side in (-1,1):
                for face in (-1,1):
                    for j in range(-6,7):
                        z=j*.5; ylimit=3.8*(1-abs(z)/8)
                        tube('Solar wing back-face bus bar',[(side*3.8+face*.085,-ylimit,z),
                             (side*3.8+face*.085,ylimit,z)],.015,steel,group)
        else:
            for j in range(3):
                a=math.pi/2+j*math.tau/3
                radial=Vector((math.cos(a),0,math.sin(a)))
                cylinder('Defender pylon service boss',radial*2.6,.23,.55,steel,group,vertices=12)
                tube('Defender pylon ion conduit',[tuple(radial*1.7+Vector((0,.45,0))),
                     tuple(radial*3.7+Vector((0,.45,0)))],.055,amber,group)
    elif 'Podracer' in key:
        for side in (-1,1):
            x=side*(9.2 if key=='rattsPodracer' else 11.5)
            for j in range(5):
                cube('Pod heat exchanger louvre',(x,-3.7+j*.74,2.64),(1.6,.09,.045),dark,group,0)
            tube('Pod external fuel feed',[(x+side*1.55,-5.8,1.95),(x+side*1.88,-4.8,2),
                 (x+side*1.88,.4,2),(x+side*1.55,1.5,1.95)],.075,amber,group)
            for j in range(4):
                fin=cube('Pod intake guide vane',(x+side*1.95,-6.6+j*.7,1.15),(.12,.23,.65),steel,group,0)
                fin.rotation_euler.z=side*.18
            cube('Cockpit hand control',(side*.75,3.6,1.7),(.09,.24,.08),dark,group,0)
            tube('Pilot restraint frame',[(side*.65,5.9,1.6),(side*.65,5.9,2.05),
                 (0,6,2.12)],.055,steel,group)
        # Individual racing hardware; the six pods no longer share just a paint finish.
        if key=='anakinPodracer':
            for side in (-1,1):
                plate('Swept yellow intake fairing',[(side*9.6,-6.5),(side*11.5,-7.6),
                      (side*13.4,-6.5),(side*13,-4.4),(side*10,-4.4)],2.43,.18,amber,group)
                cylinder('High velocity intake centre', (side*11.5,-8.1,1.05),.4,.2,steel,group,vertices=16)
        elif key=='sebulbaPodracer':
            for side in (-1,1):
                for j in range(5): cube('Hammerhead intake stacked baffle',(side*12,-9.18,1.1+j*.4),(1.8,.055,.065),steel,group,0)
                tube('Aggressive pod side exhaust',[(side*13.1,.8,1.2),(side*14,1.4,1.4),(side*14,2.7,1.4)],.22,dark,group)
        elif key=='quadinPodracer':
            for side in (-1,1):
                plate('Auxiliary engine armoured saddle',[(side*13,-3),(side*16,-4.4),
                      (side*17,-3),(side*16,1.6),(side*13,1)],1.5,.25,steel,group)
                tube('Four engine synchronisation pipe',[(side*11.8,-1,2.6),(side*13.5,-.4,2.6),(side*16,0,2.35)],.11,amber,group)
        elif key=='rattsPodracer':
            for side in (-1,1):
                plate('Short wheelbase pod airbrake',[(side*8,1),(side*10.4,1),
                      (side*11.2,3),(side*8.5,3)],2.5,.18,steel,group)
                cube('Airbrake yellow warning stripe',(side*9.7,2.1,2.61),(.75,.12,.02),amber,group,0)
        elif key=='nevaKeePodracer':
            for side in (-1,1):
                cube('Integrated bridge cooling channel',(side*5.4,2,1.4),(2.5,.24,.09),dark,group,0)
                for j in range(6): cube('Integrated bridge exposed rib',(side*5.4,1.5+j*.2,1.52),(2.4,.025,.035),steel,group,0)
        else:
            for side in (-1,1):
                plate('Voltwing split rear stabiliser',[(side*.8,6),(side*3.2,7.1),
                      (side*3.6,8),(side*1.1,7.3)],1.1,.16,steel,group)
                for j in range(3): cube('Voltwing energy emitter grille',(side*9.7,-3,1+j*.18),(.04,.3,.035),lamp,group,0)
    root['fleet_detail_panel_count'] = detail_count
    root['fleet_detail_version'] = 2
    return group
