"""Original reference-inspired weapon meshes. Run with Blender --background --python."""
import bpy, math
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parents[1]/'models'
def material(name,color,metal=.7,rough=.32,glow=False):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 if glow:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=1.6
 return m
M={}
def vec(p):return Vector((p[0],-p[2],p[1]))
def box(name,p,s,mat,bevel=.008):
 bpy.ops.mesh.primitive_cube_add(size=1,location=vec(p));o=bpy.context.object;o.name=name;o.dimensions=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  mod=o.modifiers.new('Machined bevel','BEVEL');mod.width=min(bevel,min(s)*.3);mod.segments=3
  bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 o.data.materials.append(M[mat]);return o
def cylinder(name,p,r,length,mat,axis='z'):
 bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=r,depth=length,location=vec(p));o=bpy.context.object;o.name=name
 if axis=='z':o.rotation_euler.x=math.pi/2
 elif axis=='x':o.rotation_euler.y=math.pi/2
 o.data.materials.append(M[mat]);mod=o.modifiers.new('Edge bevel','BEVEL');mod.width=.003;mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
 for f in o.data.polygons:f.use_smooth=len(f.vertices)==4
 return o
def ellipsoid(name,p,s,mat):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=10,radius=1,location=vec(p));o=bpy.context.object;o.name=name;o.scale=(s[0],s[2],s[1]);o.data.materials.append(M[mat])
 for f in o.data.polygons:f.use_smooth=True
 return o
def hull(name,sections,mat,side=0):
 vertices=[];faces=[]
 # Eight-corner chamfered cross-section, curved/tapered along the barrel axis.
 for z,width,height,y in sections:
  w=width/2;h=height/2;c=min(w,h)*.3
  for x,dy in [(-w+c,-h),(w-c,-h),(w,-h+c),(w,h-c),(w-c,h),(-w+c,h),(-w,h-c),(-w,-h+c)]:vertices.append(tuple(vec((x+side,y+dy,z))))
 n=len(sections)
 faces.append(tuple(reversed(range(8))));faces.append(tuple((n-1)*8+i for i in range(8)))
 for j in range(n-1):
  for i in range(8):faces.append((j*8+i,j*8+(i+1)%8,(j+1)*8+(i+1)%8,(j+1)*8+i))
 faces=[tuple(reversed(f)) for f in faces]
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.materials.append(M[mat]);o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);return o
for kind in ['smg','plasma_pistol','plasma_br','plasma_auto','plasma_smg','plasma_sniper']:
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 M={'dark':material('Graphite',(0.045,.062,.064)), 'ivory':material('Ivory ceramic',(.68,.74,.68),.4), 'red':material('Annu crimson',(.38,.025,.035),.6), 'gold':material('Antique brass',(.45,.30,.11)), 'green':material('Green energy',(.06,.85,.20),.3,.2,True),'black':material('Grip rubber',(.018,.025,.022),.05,.7)}
 plasma=kind!='smg';compact=kind in ['smg','plasma_smg','plasma_pistol'];sniper=kind=='plasma_sniper';shell='ivory' if plasma else 'red';trim='green' if plasma else 'gold'
 end=-.70 if sniper else -.41 if compact else -.52
 hull('Receiver',[(.16,.105,.11,.035),(.02,.145,.15,.04),(-.20,.14,.13,.05),(end+.12,.09,.095,.035)],'dark')
 # Independent side shells taper around a black exposed core.
 for side in [-1,1]:
  hull('Armor shell',[(.10,.026,.095,.05),(-.04,.045,.14,.065),(-.22,.04,.12,.07),(end+.10,.025,.055,.06)],shell,side*.076)
  box('Energy rail' if plasma else 'Brass receiver inlay',(side*.101,.079,-.14),(.008,.016,.30 if not compact else .20),trim,.003)
  for i in range(4):box('Cooling vent',(side*.103,.02,-.06-i*.043),(.009,.027,.018),'dark',.003)
  for z in [.03,-.24]:cylinder('Fastener',(side*.103,.05,z),.009,.009,'gold' if not plasma else 'dark','x')
 hull('Shoulder stock',[(.31,.085,.095,.04),(.29,.11,.12,.035),(.12,.075,.085,.035)],shell)
 box('Stock pad',(0,.035,.31),(.09,.10,.025),'black')
 grip=box('Grip',(0,-.11,.035),(.065,.17,.085),'black');grip.rotation_euler.x=-.16
 for i in range(4):box('Grip ribs',(0,-.07-i*.027,.081),(.06,.009,.006),shell,.002)
 # The complete magazine is one movable reload group after joining below.
 box('ReloadMagazine_Cell' if plasma else 'ReloadMagazine_SMG',(0,-.14,-.15),(.082,.16,.105),'dark')
 box('ReloadMagazine_Base',(0,-.205,-.15),(.09,.035,.115),shell)
 for i in range(3):box('ReloadMagazine_Light',(0.043,-.10-i*.035,-.15),(.008,.016,.063),trim,.002)
 if plasma:
  for side in [-1,1]:
   hull('Split emitter',[(end+.15,.05,.075,.045),(end+.03,.055,.10,.05),(end-.12,.018,.035,.04)],shell,side*.058)
   hull('Emitter energy',[(end+.05,.013,.028,.045),(end-.12,.009,.018,.04)],trim,side*.042)
  ellipsoid('Exposed energy chamber',(0,.035,end+.13),(.04,.04,.095),'green')
  ellipsoid('Side reactor',(0.106,.04,-.15),(.012,.047,.047),'dark')
  ellipsoid('Side reactor lens',(.119,.04,-.15),(.009,.032,.032),'green')
  for a in range(4):
   angle=a*math.pi/2;box('Reactor clamp',(.126,.04+math.sin(angle)*.039,-.15+math.cos(angle)*.039),(.012,.012,.013),'ivory',.002)
 else:
  cylinder('Barrel',(0,.045,end-.035),.023,.22,'dark');cylinder('Muzzle',(0,.045,end-.14),.032,.06,'dark')
  cylinder('Bore',(0,.045,end-.173),.016,.004,'black')
  box('Top rail',(0,.13,-.12),(.05,.022,.30),'dark')
  for i in range(9):box('Rail tooth',(0,.146,.01-i*.028),(.054,.012,.012),'gold',.002)
 if kind in ['plasma_br','plasma_sniper']:
  box('Scope mount',(0,.14,-.10),(.05,.07,.13),'dark')
  cylinder('Scope',(0,.205,-.16),.044,.24,'dark');cylinder('Scope rim',(0,.205,-.285),.049,.025,'ivory');cylinder('Scope glass',(0,.205,-.30),.035,.006,'green')
 else:
  box('Sight base',(0,.14,-.12),(.05,.04,.09),shell);box('Sight insert',(0,.16,-.12),(.035,.018,.04),trim,.003)
 box('ChargingHandle_Lever',(.115,.09,.02),(.036,.028,.047),shell)
 # Collapse static geometry to one mesh and keep reload/chamber nodes separate.
 groups={'Body':[],'ReloadMagazine_EnergyCell' if plasma else 'ReloadMagazine_SMG':[],'ChargingHandle_Reference':[]}
 for o in list(bpy.context.scene.objects):
  if o.type!='MESH':continue
  key=next(k for k in groups if k.startswith('ReloadMagazine')) if o.name.startswith('ReloadMagazine') else 'ChargingHandle_Reference' if o.name.startswith('ChargingHandle') else 'Body'
  groups[key].append(o)
 for name,objects in groups.items():
  if not objects:continue
  bpy.ops.object.select_all(action='DESELECT')
  for o in objects:o.select_set(True)
  bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();bpy.context.object.name=name
 bpy.ops.export_scene.gltf(filepath=str(OUT/('Reference_'+kind+'.glb')),export_format='GLB',export_yup=True)
 print('EXPORTED',kind)
