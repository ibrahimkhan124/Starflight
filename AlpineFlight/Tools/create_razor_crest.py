"""Create the editable Razor Crest fan model and its game-ready USDZ, using Blender."""
from pathlib import Path
import sys, bpy
sys.path.insert(0,str(Path(__file__).resolve().parent))
from create_blender_library_v2 import hull, engine, cockpit, laser, export, preview
from create_blender_asset_library import ROOT, mat, cube
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
root=bpy.data.objects.new('Ship_razorCrest',None); bpy.context.collection.objects.link(root)
silver=mat('Weathered gunship alloy',(.42,.45,.47),.82,.34)
dark=mat('Dark cockpit and vents',(.018,.034,.05),.6,.22)
paint=mat('Amber hull markings',(.65,.37,.065),.7,.4)
accent=mat('Engine steel',(.21,.23,.25),.9,.3)
glow=mat('Blue engine plasma',(.06,.3,1),.2,.2,emission=(.02,.26,1))
m=(silver,dark,paint,accent,glow)
hull('Armored cargo fuselage',[(-12,1.7,1.2,0),(-8,3,2.4,0),(-2,3.3,2.8,0),(6,3.1,2.4,0),(11,2.2,1.8,0)],silver,root)
cockpit(root,-7,2.4,m,width=2,length=3)
for side in (-1,1):
 cube('Engine mounting wing',(side*5.9,0,1.1),(4,2.15,.4),silver,root,.12)
 engine(root,side*9.2,0,1.6,2,14,m,'TwinEngine')
 laser(root,(side*3,-8,-.5),m,'HeavyForwardCannon')
 for i in range(7):cube('Hull panel seam',(side*3.2,-5+i*1.7,0),(.04,.7,1),accent,root,.01)
 cube('PaintStripe',(side*3.25,-1,1.4),(.04,6.5,.09),paint,root,.01)
 cube('Tail stabilizer',(side*2.7,8,2.3),(.12,2.1,1.35),silver,root,.07)
cube('Rear cargo hatch',(0,11,0),(1.9,.12,1.4),accent,root,.05)
source=ROOT/'Art/BlenderLibrary/Ships/Ship_razorCrest.blend'
asset=ROOT/'AlpineFlight/Resources/BlenderAssets/Ships/Ship_razorCrest.usdz'
export(root,source,asset,ship=True)
root.rotation_euler.z=0
preview('Ship_razorCrest',root,extent=34)
print('RAZOR_CREST_EXPORTED',asset,flush=True)
