import bpy, math, pathlib, json
from mathutils import Vector
OUT=pathlib.Path(__file__).resolve().parent.parent/'models'

def mat(name,color,metal=0,rough=.6,emit=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 if emit: p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emit
 return m

def weighted(obj,bone,material):
 obj.data.materials.append(material)
 g=obj.vertex_groups.new(name=bone);g.add(list(range(len(obj.data.vertices))),1,'REPLACE')
 parts.append(obj);return obj

def uv_sphere(name,pos,scale,material,bone,segments=16,rings=10):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=pos)
 o=bpy.context.object;o.name=name;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 for p in o.data.polygons:p.use_smooth=True
 return weighted(o,bone,material)

def bar(name,a,b,radius,material,bone):
 a,b=Vector(a),Vector(b);d=b-a
 bpy.ops.mesh.primitive_cylinder_add(vertices=6 if radius<.004 else 12,radius=radius,depth=d.length,location=(a+b)/2)
 o=bpy.context.object;o.name=name;o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
 if radius>=.004:
  bevel=o.modifiers.new('SoftEdges','BEVEL');bevel.width=min(.008,radius*.35);bevel.segments=2
  bpy.ops.object.modifier_apply(modifier=bevel.name)
 for p in o.data.polygons:p.use_smooth=True
 return weighted(o,bone,material)

def plate(name,contour,y,depth,material,bone,bevel=.008):
 n=len(contour);cx=sum(x for x,z in contour)/n;cz=sum(z for x,z in contour)/n
 curved=any(k in name for k in ['Shoulder','Bicep','Bracer','ThighArmor','Kneepad','Greave','Pectoral','Abdomen','Crown','FaceShell','BootPlate','RearPelvis']) and 'Edge' not in name and 'Trim' not in name
 bulge=.042 if curved else 0
 v=[];faces=[]
 for r in range(4):
  f=1-r*.25
  for x,z in contour:v.append((cx+(x-cx)*f,y+bulge*(1-f*f),cz+(z-cz)*f))
 for r in range(3):
  for i in range(n):faces.append((r*n+i,r*n+(i+1)%n,(r+1)*n+(i+1)%n,(r+1)*n+i))
 v.append((cx,y+bulge,cz));center=len(v)-1
 for i in range(n):faces.append((3*n+i,3*n+(i+1)%n,center))
 back=len(v);v += [(x,y-depth,z) for x,z in contour]
 faces.append(tuple(range(back,back+n)))
 for i in range(n):faces.append((i,(i+1)%n,back+(i+1)%n,back+i))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(v,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
 weighted(o,bone,material)
 bpy.context.view_layer.objects.active=o;o.select_set(True)
 bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
 for p in o.data.polygons:p.use_smooth=curved and p.index<4*n
 mod=o.modifiers.new('MachinedBevel','BEVEL');mod.width=bevel;mod.segments=3;mod.limit_method='ANGLE'
 bpy.ops.object.modifier_apply(modifier=mod.name)
 o.select_set(False);return o

def block(name,pos,size,material,bone,radius=.01):
 bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.name=name;o.scale=size
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 weighted(o,bone,material);mod=o.modifiers.new('RoundedEdges','BEVEL');mod.width=radius;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
 mod=o.modifiers.new('SurfaceNormals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=mod.name)
 return o


def loft(name, rows, material, bone, segments=24):
 # rows are (x,y,z, lateral radius, depth radius), Blender Z-up.
 vertices=[];faces=[]
 for x,y,z,rx,ry in rows:
  for i in range(segments):
   a=i*math.tau/segments;vertices.append((x+rx*math.cos(a),y+ry*math.sin(a),z))
 for r in range(len(rows)-1):
  for i in range(segments):faces.append((r*segments+i,r*segments+(i+1)%segments,(r+1)*segments+(i+1)%segments,(r+1)*segments+i))
 faces.append(tuple(reversed(range(segments))));faces.append(tuple((len(rows)-1)*segments+i for i in range(segments)))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
 ob=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(ob)
 for face in mesh.polygons:face.use_smooth=len(face.vertices)==4
 return weighted(ob,bone,material)

def muscle(name,a,b,radii,material,bone):
 a,b=Vector(a),Vector(b);axis=(b-a).normalized();right=axis.cross(Vector((0,1,0))).normalized();front=right.cross(axis).normalized()
 vertices=[];faces=[];steps=24
 for t,rx,ry in radii:
  c=a.lerp(b,t)
  for i in range(steps):
   angle=i*math.tau/steps;vertices.append(c+right*(rx*math.cos(angle))+front*(ry*math.sin(angle)))
 for r in range(len(radii)-1):
  for i in range(steps):faces.append((r*steps+i,r*steps+(i+1)%steps,(r+1)*steps+(i+1)%steps,(r+1)*steps+i))
 faces.append(tuple(reversed(range(steps))));faces.append(tuple((len(radii)-1)*steps+i for i in range(steps)))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update();ob=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(ob)
 for face in mesh.polygons:face.use_smooth=len(face.vertices)==4
 return weighted(ob,bone,material)

def export_damage_surfaces(faction, rig):
 # Damage geometry derives from the same final authored body, excluding loose cloth,
 # insignia and slender headset hardware. It is split by skeletal segment, not one body hull.
 groups={}
 excluded=('Cape','Laurel','Scarf','HeadsetMic','MicEnd','ChinStrap','ChestStrap','StrapBuckle','BuckleInset','RecessedFastener')
 for ob in parts:
  if ob.name.startswith(excluded):continue
  if len(ob.vertex_groups)!=1:continue
  bone=ob.vertex_groups[0].name
  if bone.startswith('finger'):bone='hand_'+bone[-1]
  if bone.startswith('toe'):bone='foot_'+bone[-1]
  if bone.startswith('cape'):continue
  points=groups.setdefault(bone,[])
  for v in ob.data.vertices:
   co=ob.matrix_world@v.co;points.append([co.x,co.z,-co.y])
 raw=pathlib.Path(__file__).resolve().parent/(faction+'_damage_raw.json');raw.write_text(json.dumps(groups))

def build(faction):
 global parts
 bpy.ops.wm.read_factory_settings(use_empty=True);parts=[]
 naki=faction=='Naki';prefix=faction.lower()
 armor=mat(prefix+'_armor_ivory' if naki else prefix+'_armor_charcoal',(.68,.65,.57) if naki else (.055,.063,.07),.2,.37 if naki else .48)
 suit=mat(prefix+'_undersuit_graphite' if naki else prefix+'_uniform_graphite',(.022,.026,.029),0,.88)
 trim=mat(prefix+'_trim_brass',(.57,.41,.18),.85,.38)
 cloth=mat(prefix+'_cloth_olive' if naki else prefix+'_cloth_crimson',(.11,.125,.042) if naki else (.22,.018,.025),0,.9)
 lens=mat(prefix+'_visor_amber' if naki else prefix+'_glass',(.8,.38,.035) if naki else (.009,.013,.016),.3,.3,.15 if naki else 0)
 skin=mat('annu_face',(.43,.28,.19),0,.78) if not naki else None
 # Actual skinned humanoid rig, stable names, meters, forward Blender +Y -> glTF -Z.
 data=bpy.data.armatures.new(faction+'_Skeleton');rig=bpy.data.objects.new(faction+'_Rig',data);bpy.context.collection.objects.link(rig);bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
 bones={}
 def bone(name,a,b,parent=None):
  bo=data.edit_bones.new(name);bo.head=a;bo.tail=b
  if parent:bo.parent=bones[parent]
  bones[name]=bo
 bone('root',(0,0,0),(0,0,.15))
 bone('pelvis',(0,0,.81),(0,0,.99),'root');bone('spine_01',(0,0,.99),(0,0,1.12),'pelvis');bone('spine_02',(0,0,1.12),(0,0,1.28),'spine_01');bone('chest',(0,0,1.28),(0,0,1.46),'spine_02');bone('neck',(0,0,1.46),(0,0,1.61),'chest');bone('head',(0,0,1.61),(0,0,1.89),'neck')
 for sign,side in [(1,'r'),(-1,'l')]:
  bone('clavicle_'+side,(0,0,1.43),(sign*.24,0,1.43),'chest')
  bone('upperarm_'+side,(sign*.24,0,1.43),(sign*.36,.015,1.15),'clavicle_'+side)
  bone('forearm_'+side,(sign*.36,.015,1.15),(sign*.42,.045,.91),'upperarm_'+side)
  bone('hand_'+side,(sign*.42,.045,.91),(sign*.44,.045,.79),'forearm_'+side)
  bone('thigh_'+side,(sign*.11,0,.83),(sign*.13,0,.46),'pelvis')
  bone('calf_'+side,(sign*.13,0,.46),(sign*.14,0,.13),'thigh_'+side)
  bone('foot_'+side,(sign*.14,0,.13),(sign*.14,.16,.065),'calf_'+side)
  bone('toe_'+side,(sign*.14,.16,.065),(sign*.14,.23,.065),'foot_'+side)
  for f in range(4):
   fx=sign*(.399+f*.021)
   bone('finger%d_%s'%(f,side),(fx,.045,.805),(fx,.075,.725),'hand_'+side)
 for strip in range(3):
  x=(strip-1)*.22
  for row in range(3):
   z=1.5-row*.43
   bone('cape_%d_%d'%(strip,row),(x,-.17-row*.03,z),(x,-.20-row*.03,z-.43),'chest' if row==0 else 'cape_%d_%d'%(strip,row-1))
 bpy.ops.object.mode_set(mode='OBJECT');rig.select_set(False)
 # Continuous graphite body, flexible elbows/knees and neck beneath fitted armor.
 loft('Ribcage_under',[(0,0,1.12,.165,.108),(0,0,1.20,.208,.133),(0,0,1.32,.233,.143),(0,0,1.40,.225,.125),(0,0,1.455,.15,.095)],suit,'chest')
 loft('Waist_under',[(0,0,.985,.172,.119),(0,0,1.045,.148,.104),(0,0,1.12,.165,.108),(0,0,1.165,.184,.122)],suit,'spine_01')
 loft('Cuirass',[(0,-.005,1.19,.18,.128),(0,0,1.255,.218,.157),(0,-.003,1.345,.24,.151),(0,-.008,1.405,.215,.125)],armor,'chest')
 loft('Abdominal_wrap',[(0,0,1.01,.15,.104),(0,0,1.055,.147,.114),(0,0,1.13,.169,.128)],armor,'spine_01')
 loft('Pelvis_under',[(0,0,.79,.135,.10),(0,-.006,.845,.209,.137),(0,-.008,.91,.208,.141),(0,0,.985,.171,.119)],suit,'pelvis')
 bar('NeckSeal',(0,0,1.45),(0,0,1.66),.065,suit,'neck')
 for sign,side in [(1,'r'),(-1,'l')]:
  a=(sign*.25,0,1.42);b=(sign*.36,.015,1.15);c=(sign*.42,.045,.91)
  muscle('UpperSleeve_'+side,a,b,[(0,.076,.075),(.22,.096,.086),(.50,.092,.083),(.78,.074,.068),(1,.064,.061)],suit,'upperarm_'+side)
  muscle('ForeSleeve_'+side,b,c,[(0,.065,.062),(.22,.083,.076),(.52,.079,.070),(1,.048,.047)],suit,'forearm_'+side)
  uv_sphere('Deltoid_'+side,(sign*.265,-.005,1.406),(.105,.097,.108),armor,'upperarm_'+side,24,14)
  muscle('BicepShell_'+side,a,b,[(.18,.094,.079),(.4,.098,.089),(.67,.082,.078),(.83,.071,.067)],armor,'upperarm_'+side)
  muscle('ForearmShell_'+side,b,c,[(.12,.080,.074),(.36,.086,.080),(.66,.070,.066),(.89,.052,.052)],armor,'forearm_'+side)
  uv_sphere('Elbow_'+side,b,(.07,.065,.07),suit,'forearm_'+side)
  muscle('ThighFabric_'+side,(sign*.11,0,.85),(sign*.13,0,.46),[(0,.089,.103),(.22,.111,.119),(.48,.108,.112),(.76,.086,.089),(1,.072,.073)],suit,'thigh_'+side)
  muscle('ThighShell_'+side,(sign*.11,.018,.81),(sign*.13,.012,.49),[(0,.085,.099),(.20,.106,.112),(.48,.102,.105),(.77,.084,.086),(1,.072,.074)],armor,'thigh_'+side)
  muscle('ShinFabric_'+side,(sign*.13,0,.46),(sign*.14,0,.13),[(0,.069,.071),(.30,.081,.087),(.53,.077,.083),(.80,.057,.060),(1,.048,.050)],suit,'calf_'+side)
  muscle('CalfShell_'+side,(sign*.13,.004,.42),(sign*.14,0,.145),[(0,.074,.078),(.26,.083,.091),(.50,.077,.084),(.82,.058,.064),(1,.052,.055)],armor,'calf_'+side)
  uv_sphere('KneeJoint_'+side,(sign*.13,0,.47),(.082,.075,.078),suit,'calf_'+side)
  uv_sphere('Palm_'+side,(sign*.43,.045,.845),(.047,.037,.066),suit,'hand_'+side)
  for f in range(4):
   fx=sign*(.399+f*.021);bar('Finger_'+side+str(f),(fx,.045,.805),(fx,.075,.73),.009,suit,'finger%d_%s'%(f,side))
  # Fitted shoulder, arm, shin and boot armor with bevelled contours.
  plate('Shoulder_'+side,[(sign*.20,1.47),(sign*.31,1.48),(sign*.37,1.37),(sign*.27,1.32),(sign*.22,1.37)],.095,.14,armor,'upperarm_'+side)
  plate('ShoulderEdge_'+side,[(sign*.265,1.335),(sign*.37,1.375),(sign*.37,1.355),(sign*.265,1.315)],.104,.025,trim,'upperarm_'+side,.004)
  plate('BicepPlate_'+side,[(sign*.27,1.34),(sign*.36,1.29),(sign*.38,1.18),(sign*.32,1.19)],.085,.08,armor,'upperarm_'+side)
  plate('Bracer_'+side,[(sign*.345,1.12),(sign*.415,1.10),(sign*.455,.96),(sign*.39,.94)],.11,.1,armor,'forearm_'+side)
  plate('ThighArmor_'+side,[(sign*.055,.79),(sign*.16,.80),(sign*.21,.69),(sign*.18,.51),(sign*.095,.50),(sign*.065,.62)],.09,.11,armor,'thigh_'+side)
  plate('Kneepad_'+side,[(sign*.07,.49),(sign*.14,.51),(sign*.20,.47),(sign*.19,.40),(sign*.13,.375),(sign*.08,.42)],.12,.1,armor,'calf_'+side)
  plate('Greave_'+side,[(sign*.085,.385),(sign*.19,.385),(sign*.185,.18),(sign*.16,.125),(sign*.10,.15)],.09,.1,armor,'calf_'+side)
  plate('GreaveTrim_'+side,[(sign*.135,.35),(sign*.145,.35),(sign*.143,.17),(sign*.133,.17)],.102,.012,trim,'calf_'+side,.002)
  block('BootSole_'+side,(sign*.14,.065,.028),(.16,.29,.048),suit,'foot_'+side,.012)
  block('BootLeather_'+side,(sign*.14,.07,.092),(.15,.27,.10),suit,'foot_'+side,.035)
  plate('BootPlate_'+side,[(sign*.066,.13),(sign*.13,.16),(sign*.208,.13),(sign*.20,.058),(sign*.078,.058)],.195,.065,armor,'foot_'+side)
  for j in range(3):
   block('Instep_'+side,(sign*.14,.07-j*.035,.144+j*.012),(.115,.024,.018),armor if naki else suit,'foot_'+side,.006)
  for z in [.29,.36]:
   bar('GreaveFastener_'+side,(sign*.09,.096,z),(sign*.18,.096,z),.008,trim,'calf_'+side)
  for j in range(3):
   uv_sphere('JointRib_'+side,(sign*.13,.055,.425-j*.012),(.075,.023,.007),suit,'calf_'+side,12,6)
  plate('HandArmor_'+side,[(sign*.393,.89),(sign*.455,.885),(sign*.464,.82),(sign*.398,.80)],.083,.025,armor,'hand_'+side,.004)
 # Sculpted segmented chest plates, belt, lower abdomen, full rear armor.
 for sign in [-1,1]:
  plate('Pectoral',[(sign*.025,1.405),(sign*.155,1.405),(sign*.205,1.335),(sign*.18,1.205),(sign*.065,1.19),(sign*.01,1.26)],.13,.07,armor,'chest')
  plate('Flank',[(sign*.17,1.19),(sign*.09,1.13),(sign*.075,1.02),(sign*.16,1.055)],.10,.07,armor,'spine_01')
  plate('BackShoulder',[(sign*.025,1.405),(sign*.175,1.4),(sign*.18,1.20),(sign*.03,1.23)],-.075,.045,armor,'chest')
 plate('Abdomen',[(0,1.24),(.084,1.17),(.077,1.04),(0,1.005),(-.077,1.04),(-.084,1.17)],.12,.06,armor,'spine_01')
 plate('Belt',[(-.18,.995),(.18,.995),(.17,.94),(-.17,.94)],.135,.24,suit,'pelvis')
 plate('Buckle',[(-.035,.987),(.035,.987),(.035,.945),(-.035,.945)],.151,.012,trim,'pelvis')
 plate('RearPelvis',[(-.16,.99),(.16,.99),(.17,.83),(-.17,.83)],-.085,.035,armor,'pelvis')
 for sign,side in [(1,'r'),(-1,'l')]:
  plate('HipGuard_'+side,[(sign*.13,1.02),(sign*.21,.995),(sign*.22,.9),(sign*.155,.93)],.10,.17,armor,'pelvis')
  for z in [1.13,1.07]:bar('AbdominalSeal',(sign*.085,.11,z),(sign*.155,.105,z+.025),.011,suit,'spine_01')
  for x,z in [(sign*.17,1.35),(sign*.18,.72),(sign*.12,.44)]:
   uv_sphere('RecessedFastener',(x,.132,z),(.005,.004,.005),trim,'chest' if z>1 else 'thigh_'+side if z>.5 else 'calf_'+side,8,6)
 if naki:
  plate('CenterGold',[(0,1.29),(.025,1.255),(0,1.205),(-.025,1.255)],.155,.012,trim,'chest')
  # Closed angular ivory shell, gold Y visor and symmetrical ear hardware.
  uv_sphere('HelmetInner',(0,-.014,1.752),(.116,.099,.142),armor,'head',24,16)
  plate('Crown',[(-.11,1.78),(-.085,1.87),(0,1.905),(.085,1.87),(.11,1.78),(0,1.74)],.118,.16,armor,'head')
  plate('FaceShell',[(-.11,1.765),(0,1.724),(.11,1.765),(.082,1.62),(0,1.60),(-.082,1.62)],.121,.095,armor,'head')
  plate('GoldVisor',[(-.11,1.779),(0,1.742),(.11,1.779),(.104,1.754),(.017,1.718),(.01,1.635),(-.01,1.635),(-.017,1.718),(-.104,1.754)],.135,.012,lens,'head',.002)
  for sign in [-1,1]:
   uv_sphere('Ear',(.126*sign,-.012,1.747),(.019,.058,.060),trim,'head')
   uv_sphere('EarInsert',(.14*sign,-.012,1.747),(.008,.039,.041),suit,'head')
   uv_sphere('EarHub',(.148*sign,-.012,1.747),(.006,.017,.019),trim,'head')
   plate('Cheek',[(sign*.08,1.739),(sign*.114,1.77),(sign*.10,1.65),(sign*.062,1.625)],.116,.09,armor,'head',.003)
   bar('HelmetSeam',(sign*.08,.141,1.855),(sign*.05,.15,1.788),.0018,suit,'head')
 else:
  # Original stylized human face, not a photographed person.
  uv_sphere('HeadFace',(0,.005,1.737),(.108,.096,.137),skin,'head')
  uv_sphere('Jaw',(0,.045,1.658),(.075,.065,.055),skin,'head')
  uv_sphere('Nose',(0,.101,1.732),(.017,.027,.029),skin,'head')
  uv_sphere('Lips',(0,.107,1.677),(.033,.009,.006),skin,'head',16,8)
  bar('MouthLine',(-.028,.116,1.677),(.028,.116,1.677),.0018,suit,'head')
  uv_sphere('Chin',(0,.077,1.647),(.047,.041,.028),skin,'head',16,8)
  plate('Sunglasses',[(-.095,1.775),(.095,1.775),(.089,1.726),(.02,1.723),(0,1.735),(-.02,1.723),(-.089,1.726)],.103,.012,lens,'head',.004)
  uv_sphere('HelmetShell',(0,-.005,1.82),(.124,.11,.08),armor,'head')
  uv_sphere('HelmetBack',(0,-.050,1.77),(.113,.077,.109),armor,'head',24,14)
  plate('HelmetRim',[(-.12,1.805),(.12,1.805),(.116,1.78),(-.116,1.78)],.105,.03,armor,'head')
  block('NVGMount',(0,.117,1.818),(.047,.022,.052),suit,'head',.004)
  block('NVGInsert',(0,.13,1.818),(.025,.008,.028),trim,'head',.002)
  for sign in [-1,1]:
   uv_sphere('Headset',(.127*sign,-.01,1.745),(.027,.045,.061),armor,'head')
   uv_sphere('HeadsetRing',(.149*sign,-.01,1.745),(.008,.031,.043),trim,'head')
   bar('ChinStrap',(sign*.095,.01,1.72),(sign*.065,.057,1.637),.009,suit,'head')
   plate('ChestStrap',[(sign*.12,1.41),(sign*.145,1.40),(sign*.084,1.17),(sign*.06,1.18)],.158,.018,trim,'chest',.003)
   plate('BeltPouch',[(sign*.11,.97),(sign*.19,.97),(sign*.185,.855),(sign*.12,.85)],.165,.07,suit,'pelvis')
   block('PouchFlap',(sign*.15,.177,.943),(.065,.014,.035),armor,'pelvis',.004)
   block('PouchLatch',(sign*.15,.186,.915),(.014,.007,.038),trim,'pelvis',.003)
   block('StrapBuckle',(sign*.127,.183,1.352),(.034,.016,.043),trim,'chest',.004)
   block('BuckleInset',(sign*.127,.193,1.352),(.021,.006,.027),suit,'chest',.002)
   for j in range(3):bar('BootLace', (sign*.10,.13-j*.025,.148+j*.008),(sign*.18,.13-j*.025,.148+j*.008),.003,trim,'foot_'+('r' if sign>0 else 'l'))
  bar('HeadsetMic',(.145,.0,1.708),(.074,.14,1.69),.005,suit,'head')
  uv_sphere('MicEnd',(.074,.14,1.69),(.012,.007,.008),suit,'head',12,6)
 # Wrapped scarf uses a tapered ring mesh and hangs in a central front fold.
 vertices=[];faces=[];steps=48;scarf_rows=9
 for row in range(scarf_rows):
  t=row/(scarf_rows-1);radius=.106+.079*math.sin(t*math.pi*.75);z=1.598-.13*t
  for i in range(steps):
   a=i*math.tau/steps;fold=.008*math.sin(t*math.tau*2+a*.8);vertices.append((math.cos(a)*(radius+fold),math.sin(a)*(radius+fold)*.78,z-.04*t*max(0,math.sin(a))+.006*math.sin(a*3)))
 for row in range(scarf_rows-1):
  for i in range(steps):faces.append(((row+1)*steps+i,(row+1)*steps+(i+1)%steps,row*steps+(i+1)%steps,row*steps+i))
 me=bpy.data.meshes.new('Scarf');me.from_pydata(vertices,[],faces);ob=bpy.data.objects.new('Scarf',me);bpy.context.collection.objects.link(ob);weighted(ob,'neck',cloth)
 for po in ob.data.polygons:po.use_smooth=True
 # Separate full cape, three weighted strips; slit is cut into the lower hem.
 v=[];faces=[];cols=24;rows=36
 def cape_point(u,t):
  width=.205+.22*t;x=(u-.5)*2*width;z=1.49-1.30*t+.013*math.sin(u*math.tau*4)*t
  y=-.155-.25*t+(.012+.037*t)*math.sin(u*math.tau*4+.35)*math.sin(t*math.pi*.6)
  return (x,y,z)
 def cape_weights(obj):
  for vertex in obj.data.vertices:
   x,y,z=obj.matrix_world@vertex.co;t=max(0,min(1,(1.49-z)/1.30));u=max(0,min(1,x/(2*(.205+.22*t))+.5))
   sx=u*2;sy=t*2;weights={}
   for si in range(3):
    for ri in range(3):
     w=max(0,1-abs(si-sx))*max(0,1-abs(ri-sy))
     if w>.0001:
      name='cape_%d_%d'%(si,ri);g=obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name);g.add([vertex.index],w,'REPLACE')
 for r in range(rows):
  t=r/(rows-1)
  for c in range(cols):
   u=c/(cols-1);v.append(cape_point(u,t))
 for r in range(rows-1):
  for c in range(cols-1):
   if r>=28 and c==11:continue
   faces.append((r*cols+c,(r+1)*cols+c,(r+1)*cols+c+1,r*cols+c+1))
 me=bpy.data.meshes.new('CapeMesh');me.from_pydata(v,[],faces);me.update();cape=bpy.data.objects.new('Cape',me);bpy.context.collection.objects.link(cape);cape.data.materials.append(cloth);parts.append(cape)
 cape_weights(cape)
 for po in me.polygons:po.use_smooth=True
 # Botanical motif integrated into the same skinned surface, not damage geometry.
 motif=trim if naki else suit
 def emblem(name,points,faces):
  vertices=[];triangles=[];lookup={}
  def vertex(point):
   x,z=point;key=(round(x,7),round(z,7))
   if key not in lookup:
    t=(1.49-z)/1.30;u=x/(2*(.205+.22*t))+.5;y=cape_point(u,t)[1]-.013
    lookup[key]=len(vertices);vertices.append((x,y,z))
   return lookup[key]
  for face in faces:
   tris=[face] if len(face)==3 else [(face[0],face[1],face[2]),(face[0],face[2],face[3])]
   for tri in tris:
    a,b,c=[Vector(points[index]) for index in tri];n=6
    def point(i,j):return a+(b-a)*(i/n)+(c-a)*(j/n)
    for i in range(n):
     for j in range(n-i):
      triangles.append(tuple(vertex(p) for p in [point(i,j),point(i+1,j),point(i,j+1)]))
      if i+j<n-1:triangles.append(tuple(vertex(p) for p in [point(i+1,j),point(i+1,j+1),point(i,j+1)]))
  mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],triangles);mesh.update();ob=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(ob);ob.data.materials.append(motif);parts.append(ob);cape_weights(ob)
  for po in mesh.polygons:po.use_smooth=True
 stem=[];stem_faces=[]
 for row in range(24):
  z=.25+row*1.07/23;stem.extend([(-.003,z),(.003,z)])
 for row in range(23):stem_faces.append((row*2,(row+1)*2,(row+1)*2+1,row*2+1))
 emblem('LaurelStem',stem,stem_faces)
 for row in range(6):
  z=.40+row*.14;y=-.28+.08*(z-.2)/1.3
  for sign in [-1,1]:
   emblem('LaurelLeaf',[(sign*.006,z),(sign*.075,z+.025),(sign*.14,z+.10),(sign*.07,z+.08)],[(0,1,2),(0,2,3)])
 for sign in [-1,1]:uv_sphere('CapeClasp',(sign*.17,-.178,1.48),(.028,.012,.028),trim,'chest')
 # Sewn hem follows the draped surface, with the same interpolated skin weights.
 for edge in [0,1]:
  for row in range(rows-1):
   a=Vector(cape_point(edge,row/(rows-1)));b=Vector(cape_point(edge,(row+1)/(rows-1)));a.y-=.003;b.y-=.003
   ob=bar('CapeSelvedge',a,b,.0025,trim,'cape_1_1');ob.vertex_groups.clear();cape_weights(ob)
 for c in range(cols-1):
  if c==11:continue
  a=Vector(cape_point(c/(cols-1),1));b=Vector(cape_point((c+1)/(cols-1),1));a.y-=.003;b.y-=.003
  ob=bar('CapeHem',a,b,.0025,trim,'cape_1_2');ob.vertex_groups.clear();cape_weights(ob)
 export_damage_surfaces(faction,rig)
 # Real UVs for all authored mesh parts, consistent material surface catalog.
 for ob in parts:
  bpy.context.view_layer.objects.active=ob;ob.select_set(True)
  bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT');ob.select_set(False)
  mod=ob.modifiers.new('HumanoidSkin','ARMATURE');mod.object=rig;ob.parent=rig
 # Join rigid/flexible body objects into one skinned mesh; cape remains separate.
 body_parts=[p for p in parts if p!=cape]
 for ob in body_parts:ob.select_set(True)
 bpy.context.view_layer.objects.active=body_parts[0];bpy.ops.object.join();body=bpy.context.object;body.name=faction+'_Body';body.select_set(False)
 # Avoid one armature modifier per joined object; only one skin solver is active.
 for m in list(body.modifiers)[1:]:body.modifiers.remove(m)
 # Authored pose animations with real tracks. No root travel or gameplay events.
 clips=['idle','walk_forward','walk_backward','strafe_left','strafe_right','crouch_idle','crouch_forward','crouch_backward','crouch_strafe_left','crouch_strafe_right','jump_takeoff','jump_air','jump_land','aim_upperbody','fire_upperbody','reload','grenade_throw','melee','interact_hold','carry_gold','death']
 scene=bpy.context.scene;scene.render.fps=30;rig.animation_data_create()
 for clip in clips:
  action=bpy.data.actions.new(clip);rig.animation_data.action=action;action.use_fake_user=True
  duration=60 if clip in ['idle','jump_air','crouch_idle'] else 30
  for frame in range(1,duration+1,3):
   t=(frame-1)/duration;phase=t*math.tau
   for pose in rig.pose.bones:pose.rotation_mode='XYZ';pose.rotation_euler=(0,0,0);pose.location=(0,0,0)
   rig.pose.bones['chest'].rotation_euler.x=math.sin(phase)*.018
   moving=clip in ['walk_forward','walk_backward','strafe_left','strafe_right','crouch_forward','crouch_backward','crouch_strafe_left','crouch_strafe_right']
   if moving:
    strength=.33 if clip.startswith('crouch') else .42
    for sign,side in [(1,'l'),(-1,'r')]:
     swing=math.sin(phase)*sign*strength
     rig.pose.bones['thigh_'+side].rotation_euler.x=swing
     rig.pose.bones['calf_'+side].rotation_euler.x=max(0,-swing)*.65
     rig.pose.bones['upperarm_'+side].rotation_euler.x=-swing*.5
   if clip.startswith('crouch'):
    for side in ['l','r']:rig.pose.bones['thigh_'+side].rotation_euler.x=-.35;rig.pose.bones['calf_'+side].rotation_euler.x=.7
   if clip.startswith('jump'):
    for side in ['l','r']:rig.pose.bones['thigh_'+side].rotation_euler.x=-.15;rig.pose.bones['calf_'+side].rotation_euler.x=.35
   if clip in ['aim_upperbody','fire_upperbody','reload','interact_hold','carry_gold','grenade_throw','melee']:
    rig.pose.bones['upperarm_r'].rotation_euler.x=-.9
    rig.pose.bones['forearm_r'].rotation_euler.x=-.4
    rig.pose.bones['upperarm_l'].rotation_euler.x=-.7
    rig.pose.bones['forearm_l'].rotation_euler.x=-.4
   if clip=='reload':rig.pose.bones['forearm_l'].rotation_euler.z=math.sin(phase)*.3
   if clip=='grenade_throw':rig.pose.bones['upperarm_r'].rotation_euler.x=-.4-1.4*math.sin(t*math.pi)
   if clip=='melee':rig.pose.bones['upperarm_r'].rotation_euler.x=-.4-.8*math.sin(t*math.pi)
   if clip=='fire_upperbody':rig.pose.bones['chest'].rotation_euler.x=-.08*max(0,1-t*4)
   if clip=='death':rig.pose.bones['chest'].rotation_euler.x=1.1*t;rig.pose.bones['neck'].rotation_euler.x=.3*t
   for strip in range(3):
    for row in range(3):rig.pose.bones['cape_%d_%d'%(strip,row)].rotation_euler.x=.02*math.sin(phase+strip*.5+row*.8)
   for pose in rig.pose.bones:
    pose.keyframe_insert(data_path='rotation_euler',frame=frame,group=pose.name)
  # NLA tracks produce a discrete named glTF clip per action.
  track=rig.animation_data.nla_tracks.new();track.name=clip;track.strips.new(clip,1,action)
 rig.animation_data.action=None
 scene.frame_set(1)
 for p in rig.pose.bones:p.rotation_euler=(0,0,0)
 scene.frame_end=60
 # Named bone-parent sockets exported as empty nodes.
 for socket,bone_name,offset in [('right_hand_weapon','hand_r',(0,.07,0)),('left_hand_grip','hand_l',(0,.07,0)),('grenade_release','hand_r',(0,.10,0)),('gold_carry','pelvis',(0,-.2,0)),('back_weapon','chest',(0,-.15,0))]:
  o=bpy.data.objects.new(socket,None);bpy.context.collection.objects.link(o);o.parent=rig;o.parent_type='BONE';o.parent_bone=bone_name;o.location=offset
 bpy.ops.wm.save_as_mainfile(filepath=str(pathlib.Path(__file__).resolve().parent/(faction+'.blend')))
 bpy.ops.export_scene.gltf(filepath=str(OUT/(faction+'.glb')),export_format='GLB',export_yup=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True,export_apply=False,export_materials='EXPORT')
 triangles=sum(len(o.data.polygons) for o in [body,cape])
 print('MODEL',faction,'faces',triangles,'bones',len(rig.data.bones),'clips',len(clips))
for faction in ['Naki','Annu']:build(faction)
