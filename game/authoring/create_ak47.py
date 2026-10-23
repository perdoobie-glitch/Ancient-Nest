"""Original stylized AK-47 with a curved removable magazine and wooden furniture."""
import bpy,math,pathlib
ROOT=pathlib.Path(__file__).resolve().parent.parent
bpy.ops.wm.read_factory_settings(use_empty=True)
def material(name,color,metal,rough):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough;return m
steel=material('AK_BlackSteel',(.038,.047,.051),.75,.39);wood=material('AK_Wood',(.26,.105,.035),0,.54);grip=material('AK_Grip',(.055,.035,.025),0,.7)
def box(name,pos,size,mat):
 bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.name=name;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
 b=o.modifiers.new('Edges','BEVEL');b.width=.004;b.segments=3;bpy.ops.object.modifier_apply(modifier=b.name);return o
def tube(name,pos,r,length,mat):
 bpy.ops.mesh.primitive_cylinder_add(vertices=20,radius=r,depth=length,location=pos,rotation=(math.pi/2,0,0));o=bpy.context.object;o.name=name;o.data.materials.append(mat);return o
box('Receiver',(0,0,.025),(.094,.36,.09),steel);box('DustCover',(0,-.025,.075),(.084,.30,.02),steel)
box('WoodStock',(0,-.32,.035),(.075,.22,.12),wood).rotation_euler.x=.11
box('ButtPlate',(0,-.434,.03),(.081,.012,.135),steel)
box('PistolGrip',(0,-.086,-.095),(.058,.069,.145),grip).rotation_euler.x=-.24
box('TriggerGuard',(0,.012,-.052),(.038,.105,.015),steel);box('GuardFront',(0,.06,-.042),(.038,.016,.043),steel)
box('LowerHandguard',(0,.245,.005),(.080,.15,.065),wood)
box('UpperHandguard',(0,.245,.070),(.069,.14,.044),wood)
tube('Barrel',(0,.44,.025),.016,.30,steel);tube('GasTube',(0,.355,.083),.013,.18,steel)
box('FrontSightTower',(0,.516,.084),(.032,.035,.085),steel);box('FrontSightTip',(0,.516,.130),(.010,.024,.025),steel)
box('RearSight',(0,.122,.088),(.068,.055,.037),steel)
tube('MuzzleBrake',(0,.602,.025),.020,.047,steel)
box('ChargingHandle',(.059,-.016,.057),(.035,.050,.020),steel)
for i in range(7):
 t=i/6;pos=(0,.02+.086*t*t,-.072-i*.031)
 o=box('MagazineSegment',pos,(.063,.082,.037),steel);o.rotation_euler.x=.12+.30*t
 for side in [-1,1]:box('MagazineRib',(side*.033,pos[1],pos[2]),(.005,.068,.026),steel).rotation_euler.x=o.rotation_euler.x
for y in [-.1,.05]:box('ReceiverRivet',(.049,y,.025),(.004,.008,.008),steel)
groups={}
for o in list(bpy.context.scene.objects):
 if o.type=='MESH':groups.setdefault('ReloadMagazine' if o.name.startswith('Magazine') else 'ChargingHandle' if o.name.startswith('ChargingHandle') else 'Weapon_ak47',[]).append(o)
for name,objects in groups.items():
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0]
 if len(objects)>1:bpy.ops.object.join()
 bpy.context.object.name=name
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'authoring'/'Weapon_ak47.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'models'/'Weapon_ak47.glb'),export_format='GLB',export_yup=True,export_materials='EXPORT')
