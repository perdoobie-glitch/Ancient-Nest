"""Original Sanctuary extraction shuttle and ore artwork, in meters."""
import bpy, math, pathlib, random
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parent.parent
def mat(name,color,metal=0,rough=.6,emit=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 if emit:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emit
 return m
def box(name,pos,size,material,bevel=.08):
 bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.name=name;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(material)
 mod=o.modifiers.new('Bevel','BEVEL');mod.width=bevel;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name);mod=o.modifiers.new('Normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=mod.name);return o
def hull(name,rings,material):
 v=[];f=[]
 for y,w,z,h in rings:v += [(-w,y,z-h),(w,y,z-h),(w,y,z+h),(-w,y,z+h)]
 for r in range(len(rings)-1):
  for i in range(4):f.append((r*4+i,r*4+(i+1)%4,(r+1)*4+(i+1)%4,(r+1)*4+i))
 f += [(3,2,1,0),tuple(range((len(rings)-1)*4,len(rings)*4))]
 me=bpy.data.meshes.new(name);me.from_pydata(v,[],f);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);o.data.materials.append(material)
 bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
 mod=o.modifiers.new('Edges','BEVEL');mod.width=.06;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name);o.select_set(False);return o
def export(name):
 bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'authoring'/(name+'.blend')))
 bpy.ops.export_scene.gltf(filepath=str(ROOT/'models'/(name+'.glb')),export_format='GLB',export_yup=True,export_materials='EXPORT')
bpy.ops.wm.read_factory_settings(use_empty=True)
ivory=mat('shuttle_ivory',(.43,.45,.41),.35,.42);metal=mat('shuttle_graphite',(.05,.075,.082),.7,.38);gold=mat('shuttle_brass',(.46,.33,.15),.8,.36);glass=mat('shuttle_glass',(.025,.10,.12),.7,.16);engine=mat('engine_glow',(.17,.55,.69),.2,.3,2)
hull('MainHull',[(-3,.8,.55,.18),(-2.3,1.5,.55,.36),(1.5,1.6,.55,.36),(2.9,1.15,.55,.26)],ivory)
# Cockpit points toward the berth's northern edge, with sloped canopy panels.
hull('CockpitFrame',[(-2.45,.55,1.05,.1),(-1.7,.85,1.35,.45),(-.75,.80,1.25,.30)],metal)
hull('Canopy',[(-2.32,.48,1.13,.09),(-1.70,.74,1.40,.35),(-.87,.69,1.30,.22)],glass)
box('CanopySpine',(0,-1.6,1.74),(.09,1.25,.05),gold,.02)
hull('Wing',[(-1.6,2.65,.64,.10),(.75,3.4,.7,.10),(1.5,2.05,.7,.13)],metal)
for side in [-1,1]:
 box('WingPanel',(side*2.35,.15,.86),(1.15,1.7,.10),ivory,.035)
 box('WingStripe',(side*2.36,.15,.92),(.12,1.6,.025),gold,.008)
 box('EngineHousing',(side*1.33,2.17,.66),(.62,1.1,.56),metal,.12)
 bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=.23,depth=.08,location=(side*1.33,2.77,.66),rotation=(math.pi/2,0,0));bpy.context.object.data.materials.append(engine)
 for j in range(5):box('EngineGrille',(side*1.33-.18+j*.09,2.82,.66),(.025,.03,.39),metal,.009)
 for y in [-1.5,1.8]:
  box('LandingFoot',(side*1.25,y,.10),(.25,.65,.18),metal,.035);box('LandingStrut',(side*1.25,y,.31),(.12,.14,.40),gold,.02)
 for y in [-.25,.35,.95]:box('HullPanelSeam',(side*1.61,y,.57),(.018,.035,.48),metal,.007)
box('CargoDeck',(0,.68,.965),(2.15,2.6,.06),metal,.025)
for j in range(9):box('DeckSlat',(0,-.44+j*.26,1.008),(2.00,.038,.015),gold,.004)
export('Shuttle')

bpy.ops.wm.read_factory_settings(use_empty=True)
rock=mat('ore_schist',(.063,.092,.10),.15,.88);gold=mat('ore_gold',(.60,.40,.095),.85,.31)
rng=random.Random(94)
for j in range(5):
 a=j*2.4;pos=(math.sin(a)*.7,math.cos(a)*.7,.61)
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=.70,location=pos);o=bpy.context.object;o.name='FracturedOre';o.scale=(1,.8,1.45);o.rotation_euler=(rng.random()*.7,rng.random()*.7,rng.random()*3);o.data.materials.append(rock)
 for v in o.data.vertices:v.co*=rng.uniform(.84,1.12)
 for k in range(3):
  phi=k*math.tau/3+a
  p=(pos[0]+math.sin(phi)*.61,pos[1]+math.cos(phi)*.56,1.02+rng.random()*.25)
  bpy.ops.mesh.primitive_cone_add(vertices=5,radius1=.12,radius2=.045,depth=.47,location=p);c=bpy.context.object;c.name='GoldVein';c.rotation_euler=(rng.uniform(-.6,.6),rng.uniform(-.6,.6),rng.random()*3);c.data.materials.append(gold)
bpy.ops.mesh.primitive_cone_add(vertices=6,radius1=.20,radius2=.09,depth=.65,location=(0,0,1.4));bpy.context.object.name='GoldCrown';bpy.context.object.data.materials.append(gold)
export('OreDeposit')
