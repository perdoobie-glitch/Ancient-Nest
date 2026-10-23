"""Refine the existing armored bodies without replacing rigs, clips, weights or textures.
Run once on the v26.0.2 .blend sources with Blender --background --python this_file.
The shape pass is deliberately topology preserving; replaying it compounds the sculpt.
"""
import bpy,math,json,pathlib,hashlib
from mathutils import Vector,kdtree
root=pathlib.Path(__file__).resolve().parent.parent
report={}
def gauss(value,center,width):return math.exp(-((value-center)/width)**2)
def shape(co,bone):
 x,y,z=co;nx,ny=x,y
 if bone in ['pelvis','spine_01','chest']:
  nx=x*(1+.16*gauss(z,.87,.12)-.13*gauss(z,1.055,.11)+.01*gauss(z,1.33,.13))
  ny=y*(1+.09*gauss(z,.88,.13)-.035*gauss(z,1.08,.13)+.04*gauss(z,1.34,.12))
  if y>0:
   ny+=.021*gauss(z,1.335,.085)*(gauss(x,.10,.085)+gauss(x,-.10,.085))*min(1,y/.10)
  else:ny*=1+.035*gauss(z,.87,.12)
 elif bone.startswith('thigh_'):
  side=1 if bone.endswith('_r') else -1;t=max(0,min(1,(.85-z)/.39));center=side*(.11+.02*t)
  nx=center+(x-center)*(1+.17*gauss(z,.69,.14))+side*.012*gauss(z,.82,.12)
  ny=y*(1+.12*gauss(z,.70,.16))
 elif bone.startswith('calf_'):
  side=1 if bone.endswith('_r') else -1;center=side*(.13+.01*max(0,min(1,(.46-z)/.33)))
  nx=center+(x-center)*(1+.08*gauss(z,.32,.105));ny=y*(1+.07*gauss(z,.32,.105))
 elif bone.startswith('upperarm_'):
  side=1 if bone.endswith('_r') else -1;t=max(0,min(1,(1.42-z)/.27));center=side*(.25+.11*t)
  nx=center+(x-center)*(1+.10*gauss(z,1.34,.12));ny=y*(1+.10*gauss(z,1.34,.12))
 elif bone.startswith('forearm_'):
  side=1 if bone.endswith('_r') else -1;t=max(0,min(1,(1.15-z)/.24));center=side*(.36+.06*t)
  nx=center+(x-center)*(1+.06*gauss(z,1.09,.08));ny=y*(1+.06*gauss(z,1.09,.08))
 return Vector((nx,ny,z))
def action_signature():
 data=[]
 for action in sorted(bpy.data.actions,key=lambda a:a.name):
  data.append((action.name,[(f.data_path,f.array_index,[(tuple(k.co),k.interpolation) for k in f.keyframe_points]) for f in action.fcurves]))
 return hashlib.sha256(repr(data).encode()).hexdigest()
for faction in ['Naki','Annu']:
 bpy.ops.wm.open_mainfile(filepath=str(root/'authoring'/f'{faction}.blend'))
 body=bpy.data.objects[faction+'_Body'];rig=bpy.data.objects[faction+'_Rig']
 if body.get('v26_curved_build'):raise RuntimeError('Already sculpted; restore the original blend before running again')
 before_actions=action_signature();bones=[(b.name,b.parent.name if b.parent else '',tuple(v for row in b.matrix_local for v in row)) for b in rig.data.bones]
 old_world=[body.matrix_world@v.co.copy() for v in body.data.vertices]
 before_weights=[[(g.group,g.weight) for g in v.groups] for v in body.data.vertices]
 kd=kdtree.KDTree(len(old_world))
 for i,co in enumerate(old_world):kd.insert(co,i)
 kd.balance()
 dominant=[];eligible=[]
 for v in body.data.vertices:
  group=max(v.groups,key=lambda g:g.weight);bone=body.vertex_groups[group.group].name;dominant.append(bone)
  world=old_world[v.index];v.co=body.matrix_world.inverted()@shape(world,bone)
  if bone in ['pelvis','spine_01','chest'] or bone.startswith(('thigh_','calf_','upperarm_','forearm_')):eligible.append(v.index)
 # Soften broad body panels only; retain hard fasteners, gilding, fingers and helmet details.
 broad=set()
 for poly in body.data.polygons:
  material=body.data.materials[poly.material_index].name.lower()
  if 'undersuit' in material or 'armor' in material:
   broad.update(poly.vertices)
 selected=set(eligible)&broad
 group=body.vertex_groups.new(name='ShapeSoftening');group.add(list(selected),1,'REPLACE')
 active_mods=[(m,m.show_viewport) for m in body.modifiers]
 for m,_ in active_mods:m.show_viewport=False
 bpy.context.view_layer.objects.active=body;body.select_set(True)
 modifier=body.modifiers.new('RoundBroadSurfaces','SMOOTH');modifier.vertex_group=group.name;modifier.factor=.16;modifier.iterations=2
 bpy.ops.object.modifier_apply(modifier=modifier.name)
 for m,enabled in active_mods:m.show_viewport=enabled
 body.vertex_groups.remove(body.vertex_groups['ShapeSoftening'])
 assert before_weights==[[(g.group,g.weight) for g in v.groups] for v in body.data.vertices]
 new_world=[body.matrix_world@v.co.copy() for v in body.data.vertices]
 protected=[i for i,b in enumerate(dominant) if b.startswith(('hand_','finger','head','foot_','toe'))]
 max_protected=max((new_world[i]-old_world[i]).length for i in protected)
 assert max_protected<1e-6
 raw_path=root/'authoring'/f'{faction}_damage_raw.json';raw=json.loads(raw_path.read_text());new_raw={};max_match=0
 for bone,points in raw.items():
  transformed=[]
  for point in points:
   world=Vector((point[0],-point[2],point[1]));_,index,distance=kd.find(world);max_match=max(max_match,distance)
   co=new_world[index] if distance<.0001 else shape(world,bone)
   transformed.append([co.x,co.z,-co.y])
  new_raw[bone]=transformed
 raw_path.write_text(json.dumps(new_raw))
 assert before_actions==action_signature()
 assert bones==[(b.name,b.parent.name if b.parent else '',tuple(v for row in b.matrix_local for v in row)) for b in rig.data.bones]
 body['v26_curved_build']=True
 bpy.ops.wm.save_as_mainfile(filepath=str(root/'authoring'/f'{faction}.blend'))
 bpy.ops.export_scene.gltf(filepath=str(root/'models'/f'{faction}.glb'),export_format='GLB',export_yup=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True,export_apply=False,export_materials='EXPORT')
 report[faction]={'vertices':len(body.data.vertices),'polygons':len(body.data.polygons),'bones':len(bones),'clips':len(bpy.data.actions),'animation_signature':before_actions,'weight_data_unchanged':True,'bone_data_unchanged':True,'protected_hand_head_foot_max_shift':max_protected,'damage_source_match_max_distance':max_match,'damage_fallback_count':sum(1 for pts in raw.values() for p in pts if kd.find(Vector((p[0],-p[2],p[1])))[2]>=.0001)}
 print('SCULPT',faction,json.dumps(report[faction]),flush=True)
(root/'authoring/character_shape_report.json').write_text(json.dumps(report,indent=2))
