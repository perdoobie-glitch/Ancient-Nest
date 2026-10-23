"""Original beveled weapon artwork. Blender +Y points toward the muzzle."""
import bpy, math, pathlib, sys
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parent.parent

def material(name,color,metal,rough):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough;return m

def block(name,pos,size,mat,bevel=.005):
 bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.name=name;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
 m=o.modifiers.new('MachinedEdges','BEVEL');m.width=bevel;m.segments=3;bpy.ops.object.modifier_apply(modifier=m.name)
 m=o.modifiers.new('WeightedNormals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=m.name);return o

def tube(name,pos,radius,length,mat):
 bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=radius,depth=length,location=pos,rotation=(math.pi/2,0,0));o=bpy.context.object;o.name=name;o.data.materials.append(mat)
 m=o.modifiers.new('MilledEdges','BEVEL');m.width=.003;m.segments=2;bpy.ops.object.modifier_apply(modifier=m.name)
 for p in o.data.polygons:p.use_smooth=True
 return o

selected=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
for kind in ['rifle','burst','burst_scoped','sidearm','sniper','rocket','shotgun']:
 if selected and kind not in selected:continue
 bpy.ops.wm.read_factory_settings(use_empty=True)
 shell=material('weapon_shell',(.24,.31,.35) if kind=='sniper' else (.26,.34,.27) if kind=='burst_scoped' else (.47,.46,.40),.3,.38);steel=material('weapon_steel',(.045,.057,.062),.8,.32);brass=material('weapon_brass',(.42,.30,.12),.8,.3);rubber=material('weapon_grip',(.018,.022,.025),0,.85);glass=material('weapon_optics',(.018,.055,.066),.5,.2)
 if kind=='rocket':
  tube('LauncherTube',(0,.01,0),.085,.65,steel);tube('FrontCollar',(0,.33,0),.092,.055,shell);tube('Bore',(0,.36,0),.070,.015,rubber)
  tube('RearCollar',(0,-.32,0),.09,.05,brass);block('ShoulderPad',(0,-.27,-.095),(.15,.14,.075),rubber)
  block('Sight',(.082,.12,.095),(.035,.15,.075),shell);block('SightGlass',(.082,.17,.098),(.022,.012,.034),glass)
 else:
  pistol=kind=='sidearm';length=.23 if pistol else .36
  block('Receiver',(0,0,.015),(.102,length,.105),shell,.009)
  block('LowerReceiver',(0,-.04,-.037),(.075,.21,.052),steel)
  block('Grip',(0,-.075,-.135),(.065,.074,.16),rubber,.009).rotation_euler.x=-.25
  block('TriggerGuard',(0,.013,-.079),(.042,.10,.02),brass,.004)
  block('GuardUpright',(0,.058,-.062),(.042,.02,.052),steel)
  if not pistol:
   block('Magazine',(0,.035,-.145),(.066,.09,.18),steel,.007).rotation_euler.x=.12
   for j in range(3):block('MagazineRib',(0,.034,-.087-j*.035),(.070,.094,.008),brass,.002)
   tube('StockLink',(0,-.245,-.006),.023,.17,steel);block('Stock',(0,-.34,.012),(.085,.13,.095),shell,.008);block('ButtPad',(0,-.411,.012),(.09,.015,.105),rubber,.003)
   block('Handguard',(0,.24,.017),(.094,.14,.09),shell,.006)
   for side in [-1,1]:
    for j in range(5):block('CoolingSlot',(side*.049,.18+j*.025,.025),(.009,.012,.039),steel,.002)
   barrel_length=.40 if kind=='sniper' else .19 if kind=='burst_scoped' else .12 if kind=='burst' else .15
   tube('Barrel',(0,.32+barrel_length/2,.006),.018,barrel_length,steel)
   tube('MuzzleBrake',(0,.34+barrel_length,.006),.027,.045,brass);tube('Bore',(0,.365+barrel_length,.006),.012,.004,rubber)
   for j in range(14):block('RailTooth',(0,-.13+j*.030,.081),(.062,.016,.009),steel,.002)
   block('ChargingHandle',(.064,-.09,.028),(.04,.04,.017),steel,.003)
  else:
   block('Magazine',(0,-.073,-.211),(.048,.055,.065),steel,.004)
   tube('PistolBarrel',(0,.145,.015),.023,.07,steel);block('SlideTop',(0,.015,.075),(.088,.235,.020),steel,.003)
   for j in range(5):block('SlideGroove',(.054,-.055+j*.012,.023),(.009,.004,.065),steel,.001)
  if kind in ['sniper','burst_scoped']:
   radius=.052 if kind=='sniper' else .041
   scope_length=.32 if kind=='sniper' else .23
   tube('Scope',(0,-.025,.18),radius,scope_length,steel)
   tube('ScopeObjective',(0,-.025+scope_length/2,.18),radius*1.23,.045,steel)
   tube('ObjectiveLens',(0,scope_length/2,.18),radius*1.12,.008,glass)
   for y in [-.10,.05]:block('ScopeMount',(0,y,.125),(.062,.028,.073),brass,.003)
   tube('ElevationTurret',(0,-.03,.245),.023,.036,steel).rotation_euler=(0,0,0)
   if kind=='sniper':
    for side in [-1,1]:
     block('FoldedBipod',(side*.063,.285,-.061),(.023,.24,.027),steel,.004)
    block('CheekRest',(0,-.32,.089),(.086,.13,.045),rubber,.008)
    for side in [-1,1]:block('SniperReceiverPanel',(side*.055,-.02,.014),(.015,.22,.066),steel,.003)
   else:
    for side in [-1,1]:block('ScopedBRIdentifier',(side*.054,.045,.014),(.008,.08,.027),glass,.002)
  elif not pistol:
   block('SightFrame',(0,-.085,.116),(.066,.04,.05),steel,.004);block('SightLens',(0,-.061,.117),(.045,.008,.029),glass,.002)
   block('FrontSight',(0,.275,.099),(.020,.026,.052),steel,.003)
  if kind=='shotgun':
   tube('MagazineTube',(0,.31,-.032),.022,.29,steel);block('Pump',(0,.26,-.053),(.088,.15,.067),rubber,.007)
   for j in range(6):block('PumpRib',(0,.20+j*.022,-.062),(.095,.007,.050),brass,.002)
 for side in [-1,1]:
  for y in [-.12,.06]:tube('ReceiverPin',(side*.054,y,.035),.006,.003,brass).rotation_euler=(0,math.pi/2,0)
 # Keep moving mechanisms as named rigid parts for gameplay reload/fire motion.
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];groups={}
 for o in meshes:
  group='Weapon_'+kind
  if o.name.startswith('Magazine') and not o.name.startswith('MagazineTube'):group='ReloadMagazine'
  elif o.name.startswith('ChargingHandle'):group='ChargingHandle'
  elif o.name.startswith('Pump'):group='Pump'
  elif o.name.startswith('SlideTop') or o.name.startswith('SlideGroove'):group='PistolSlide'
  groups.setdefault(group,[]).append(o)
 for name,objects in groups.items():
  bpy.ops.object.select_all(action='DESELECT')
  for o in objects:o.select_set(True)
  bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();bpy.context.object.name=name
 bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'authoring'/('Weapon_'+kind+'.blend')))
 bpy.ops.export_scene.gltf(filepath=str(ROOT/'models'/('Weapon_'+kind+'.glb')),export_format='GLB',export_yup=True,export_materials='EXPORT')
