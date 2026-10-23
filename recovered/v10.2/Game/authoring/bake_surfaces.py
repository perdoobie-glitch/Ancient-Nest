"""Bake authored fabric/paint/metal surfaces to portable 2K PBR atlases.
Run in Blender after the geometry generator. No photographed textures required.
"""
import bpy, pathlib
ROOT=pathlib.Path(__file__).resolve().parent.parent
TEX=ROOT/'assets'/'characters'/'textures';TEX.mkdir(exist_ok=True)

def procedural(material):
 n=material.node_tree.nodes;l=material.node_tree.links;p=n.get('Principled BSDF')
 base=tuple(p.inputs['Base Color'].default_value);rough=p.inputs['Roughness'].default_value
 cloth='cloth' in material.name;soft=cloth or 'suit' in material.name or 'uniform' in material.name
 coord=n.new('ShaderNodeTexCoord')
 noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=75 if soft else 145;noise.inputs['Detail'].default_value=2
 l.new(coord.outputs['Object'],noise.inputs['Vector'])
 ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.18;ramp.color_ramp.elements[1].position=.82
 for element,factor in zip(ramp.color_ramp.elements,[.72 if soft else .9,1.12 if soft else 1.025]):element.color=tuple(min(1,c*factor) for c in base[:3])+(1,)
 l.new(noise.outputs['Fac'],ramp.inputs['Fac']);l.new(ramp.outputs['Color'],p.inputs['Base Color'])
 variation=n.new('ShaderNodeMapRange');variation.inputs['To Min'].default_value=max(.05,rough-.09);variation.inputs['To Max'].default_value=min(1,rough+.07)
 l.new(noise.outputs['Fac'],variation.inputs['Value']);l.new(variation.outputs['Result'],p.inputs['Roughness'])
 micro=n.new('ShaderNodeTexNoise');micro.inputs['Scale'].default_value=520 if soft else 240;micro.inputs['Detail'].default_value=1
 l.new(coord.outputs['Object'],micro.inputs['Vector'])
 bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.24 if soft else .10;bump.inputs['Distance'].default_value=.0015 if soft else .00035
 l.new(micro.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs['Normal'],p.inputs['Normal'])
 if cloth:
  weave=n.new('ShaderNodeTexWave');weave.wave_type='BANDS';weave.bands_direction='X';weave.inputs['Scale'].default_value=210;weave.inputs['Distortion'].default_value=1.3
  l.new(coord.outputs['Object'],weave.inputs['Vector']);l.new(weave.outputs['Color'],bump.inputs['Height'])

def bake(obj,faction):
 bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
 bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=.9,island_margin=.003);bpy.ops.object.mode_set(mode='OBJECT')
 mats=list(obj.data.materials);targets={}
 for kind in ['albedo','roughness','normal']:
  img=bpy.data.images.new(faction+'_'+obj.name+'_'+kind,width=2048,height=2048,alpha=False)
  if kind!='albedo':img.colorspace_settings.name='Non-Color'
  targets[kind]=img
  outputs=[]
  for material in mats:
   nodes=material.node_tree.nodes;links=material.node_tree.links;p=nodes.get('Principled BSDF');out=nodes.get('Material Output')
   tex=nodes.new('ShaderNodeTexImage');tex.image=img;nodes.active=tex
   if kind!='normal':
    e=nodes.new('ShaderNodeEmission');inp=p.inputs['Base Color' if kind=='albedo' else 'Roughness']
    if inp.is_linked:links.new(inp.links[0].from_socket,e.inputs['Color'])
    elif kind=='albedo':e.inputs['Color'].default_value=inp.default_value
    else:e.inputs['Color'].default_value=(inp.default_value,)*3+(1,)
    links.new(e.outputs[0],out.inputs['Surface']);outputs.append((material,e))
  bpy.ops.object.bake(type='NORMAL' if kind=='normal' else 'EMIT',margin=12)
  img.filepath_raw=str(TEX/(img.name+'.png'));img.file_format='PNG';img.save();img.pack()
  for material,e in outputs:
   material.node_tree.links.new(material.node_tree.nodes.get('Principled BSDF').outputs['BSDF'],material.node_tree.nodes.get('Material Output').inputs['Surface']);material.node_tree.nodes.remove(e)
 for material in mats:
  # Shared materials must be copied for each mesh because their UV atlases differ.
  copy=material.copy();slot=list(obj.data.materials).index(material);obj.data.materials[slot]=copy
  nodes=copy.node_tree.nodes;links=copy.node_tree.links;p=nodes.get('Principled BSDF')
  for kind,socket in [('albedo','Base Color'),('roughness','Roughness')]:
   tex=nodes.new('ShaderNodeTexImage');tex.image=targets[kind];links.new(tex.outputs['Color'],p.inputs[socket])
  normal=nodes.new('ShaderNodeNormalMap');tex=nodes.new('ShaderNodeTexImage');tex.image=targets['normal'];links.new(tex.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],p.inputs['Normal'])
  p.inputs['Base Color'].default_value=(1,1,1,1);p.inputs['Roughness'].default_value=1

for faction in ['Naki','Annu']:
 bpy.ops.wm.open_mainfile(filepath=str(ROOT/'authoring'/(faction+'.blend')))
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=4;scene.render.bake.use_clear=True
 meshes=[o for o in scene.objects if o.type=='MESH']
 for material in bpy.data.materials:procedural(material)
 for obj in meshes:
  for other in meshes:other.hide_render=other!=obj
  bake(obj,faction)
 for obj in meshes:obj.hide_render=False
 bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'authoring'/(faction+'.blend')))
 bpy.ops.export_scene.gltf(filepath=str(ROOT/'models'/(faction+'.glb')),export_format='GLB',export_yup=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True,export_apply=False,export_materials='EXPORT')
 print('BAKED',faction,flush=True)
