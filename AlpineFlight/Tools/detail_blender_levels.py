"""Add course-specific architecture to terrain source files and refresh both LODs/previews."""
import sys,json,math
from pathlib import Path
import bpy
sys.path.insert(0,str(Path(__file__).resolve().parent))
from create_blender_library_v2 import ROOT,SOURCE,ASSETS,LEVELS,PALETTES,mat,cube,tube,cylinder,sphere,plate,usd,preview

def detail(key):
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE/'Levels'/f'Level_{key}.blend'))
    bpy.context.preferences.filepaths.save_version=0
    root=bpy.data.objects['Level_'+key]
    data=json.loads((ROOT/'Art/LevelSurfaces'/f'{key}.json').read_text())
    metal=mat('Landmark alloy',(.26,.28,.3),.75,.4)
    rock=mat('Landmark stone',PALETTES[key][0],.06,.75)
    dark=mat('Recessed joints',(.025,.027,.03),.4,.6)
    light=mat('Navigation strips',PALETTES[key][1],.1,.3,PALETTES[key][1])
    tiles={(t['x'],t['z']):t for t in data['tiles']}
    # Source .blend already includes all ground tiles. Architecture is merged into local tile meshes.
    for tz in range(data['minZ']+1,1):
        ci=(tz-data['minZ'])*24+12
        center=data['centers'][ci]; tx=math.floor(center/600)
        tile=tiles.get((tx,tz))
        if tile is None:continue
        name=f'Terrain_{tx}_{tz}_24';ob=bpy.data.objects.get(name)
        if ob is None:continue
        original=ob.location.copy();ob.location=(0,0,0)
        x=center-tx*600; y=-300
        index=max(0,min(24,round(x/25)));h=tile['heights'][12*25+index]
        before=set(root.children)
        if data['race'] and tz%2==0:
            half=data['width']*.8
            height=350
            # Broad arch clearance: above the 204 m hover plane, supports outside the racing line.
            for side in (-1,1):
                cube('ArchPylon',(x+side*half,y,h+height/2),(10,18,height/2),rock,root,.5)
                cube('ArchInset',(x+side*(half-10.5),y,h+height*.6),(1,12,55),light,root,.05)
                for k in range(4): cube('ArchJoint',(x+side*half,y,h+35+k*70),(10.2,18.2,1),dark,root,.05)
            tube('OverheadArch',[(x-half,y,h+height),(x-half*.7,y,h+height+45),(x+half*.7,y,h+height+45),(x+half,y,h+height)],12,rock,root)
            for side in (-1,1):
                for k in range(3):
                    # Directional chevrons on pylon faces.
                    tube('TurnChevron',[(x+side*(half-2),y-20,h+170+k*25),(x+side*(half-15),y-20,h+182+k*25),(x+side*(half-2),y-20,h+194+k*25)],2,light,root)
        elif key=='deathStar':
            # Recessed floor plates and conduits follow every trench bend.
            for side in (-1,1):
                for j in range(5):
                    localZ=100+j*95
                    c=data['centers'][(tz-data['minZ'])*24+min(24,round(localZ/25))]-tx*600
                    cube('TrenchFloorPlate',(c+side*52,-localZ,h+.3),(43,39,.25),metal,root,.1)
                    cube('TrenchFloorSeam',(c+side*52,-localZ,h+.65),(37,.5,.08),dark,root,.02)
                tube('WallPowerConduit',[(x+side*250,-50,340),(x+side*260,-300,365),(x+side*230,-550,340)],4,metal,root)
                for j in range(5): cube('WallPanel',(x+side*245,-80-j*100,330),(8,32,35),metal,root,.2)
            if tz%4==0: cube('OverheadServiceBridge',(x,y,560),(360,20,10),metal,root,.5)
        elif not data['race'] and tz%3==0:
            side=-1 if tz%2 else 1
            offset=data['width']*.95
            px=x+side*offset
            # Query the sampled neighboring tile so each landmark is planted in the ground.
            wx=center+side*offset; ix=math.floor(wx/600)
            nt=tiles.get((ix,tz),tile)
            nh=nt['heights'][12*25+max(0,min(24,round((wx-ix*600)/25)))]
            if key in ('alpine','andoPrime'):
                sphere('IceHangar',(px,y,nh),(70,55,38),rock,root)
                cube('HangarDoor',(px,y-51,nh+15),(32,2,15),dark,root,.5)
                tube('HangarLight',[ (px-35,y-54,nh),(px-35,y-54,nh+33),(px+35,y-54,nh+33),(px+35,y-54,nh)],1.5,light,root)
            elif key=='glacier':
                wreck=plate('BuriedDestroyer',[(px-90,y+80),(px,y-130),(px+90,y+80)],nh+15,18,metal,root)
                for j in range(5):cube('WreckDeck',(px,y+j*15,nh+27),(30-j*4,6,2),dark,root)
            elif key in ('endor','lantaana'):
                cylinder('ForestPlatform',(px,y,nh+65),38,7,rock,root,'Z',16)
                for j in range(8):
                    a=j*math.tau/8
                    cylinder('HutPillar',(px+math.cos(a)*24,y+math.sin(a)*24,nh+81),2,30,metal,root,'Z',8)
                sphere('VillageRoof',(px,y,nh+98),(34,34,12),rock,root)
            elif key=='skylands':
                cylinder('CloudCityBase',(px,y,nh+180),95,12,metal,root,'Z',48)
                sphere('CloudCityDome',(px,y,nh+196),(76,76,30),rock,root,32)
                for j in range(6):cylinder('CitySpire',(px-45+j*18,y,nh+226),5,60+j%3*15,metal,root,'Z',12)
            elif key=='volcano':
                cylinder('MiningPlatform',(px,y,nh+15),70,9,metal,root,'Z',16)
                for j in range(4):cube('SmelterTower',(px-40+j*25,y,nh+45),(8,10,25),metal,root,.3)
                tube('LavaConduit',[(px-60,y,nh+7),(px,y-40,nh+7),(px+65,y,nh+7)],4,light,root)
            elif key=='storm':
                for j in range(5):cube('SithMonolith',(px-50+j*25,y,nh+50+j%3*20),(7,7,50+j%3*20),dark,root,.2)
                tube('LightningFork',[(px,y,nh+210),(px-25,y,nh+170),(px+15,y,nh+130),(px,y,nh+90)],1.3,light,root)
            else:
                cylinder('BeaconTower',(px,y,nh+50),12,100,metal,root,'Z',12)
                sphere('Beacon',(px,y,nh+110),(9,9,9),light,root)
        additions=[p for p in root.children if p not in before]
        if additions:
            bpy.ops.object.select_all(action='DESELECT');ob.select_set(True)
            for p in additions:p.select_set(True)
            bpy.context.view_layer.objects.active=ob;bpy.ops.object.convert(target='MESH');bpy.ops.object.join()
            ob.name=name
            usd(ASSETS/'Terrain'/key/f'{tx}_{tz}_24.usdz')
            # Far LOD decimates the authored model, including landmarks. Near collision mesh is unchanged.
            duplicate=ob.copy();duplicate.data=ob.data.copy();bpy.context.collection.objects.link(duplicate)
            bpy.ops.object.select_all(action='DESELECT');duplicate.select_set(True);bpy.context.view_layer.objects.active=duplicate
            mod=duplicate.modifiers.new('Far LOD','DECIMATE');mod.ratio=.18
            usd(ASSETS/'Terrain'/key/f'{tx}_{tz}_8.usdz')
            bpy.data.objects.remove(duplicate,do_unlink=True)
        ob.location=original
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'Levels'/f'Level_{key}.blend'))
    bpy.ops.object.select_all(action='DESELECT')
    for ob in root.children:
        visible=abs(ob.location.x)<1201 and 0<=ob.location.y<=2400
        ob.hide_render=not visible;ob.select_set(visible)
    usd(ASSETS/'Levels'/f'Level_{key}.usdz')
    preview('Level_'+key,root,(0,1000,150),2500,True)
    print('DETAILED LEVEL',key,flush=True)

selected=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else LEVELS
for key in selected:detail(key)
