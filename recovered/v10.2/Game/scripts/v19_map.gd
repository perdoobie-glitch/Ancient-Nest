class_name NestV19Map
extends RefCounted
static func build(a: NestArena) -> void:
 var k=a.kit
 # C3 rises outside both intermediate slabs before reaching the sky garden.
 var route={"name":"C3 · BOTTOM TO SKY GARDEN","start":Vector3(-12,0,21),"end":Vector3(-6,14,8)}
 a.floor_at(-12,0,21,Vector2(4,4))
 var pad=NestManCannon.new();pad.name="C3BottomToTop";pad.position=route.start;pad.destination=route.end;pad.horizontal_drag_compensation=.5;a.add_child(pad)
 k.cylinder(pad,Vector3(0,.05,0),1.15,.1,k.dark);k.ring(pad,Vector3(0,.13,0),.9,k.lamp)
 for side in [-1,1]:k.box(pad,Vector3(side*.9,.3,0),Vector3(.13,.5,1.4),k.gold)
 k.label(pad,Vector3(0,2,0),"C3 · TOP SKY GARDEN ↑",Color("f2db96"),22);a.cannon_routes.append(route)
 # West room: offset doors preserve the north connector and rafter approach.
 for item in [[-25,14,-24.9,3,.5],[-16.25,14,-24.9,8.5,.5],[-26.5,14,-23.6,.5,2.4],[-26.5,14,-17.7,.5,3.4]]:
  NestSanctuaryLayout.wall(a,Vector3(item[0],item[1],item[2]),Vector2(item[3],item[4]),4.2)
 # East room: north/south doors and a western side entry around observatory.
 for item in [[28.5,14,3,7,.5],[36.9,14,3,3.3,.5],[38.5,14,9.2,.5,12.4],[27,14,15.3,4,.5],[35.3,14,15.3,6.6,.5],[25,14,4.25,.5,2.5],[25,14,11.9,.5,6.8]]:
  NestSanctuaryLayout.wall(a,Vector3(item[0],item[1],item[2]),Vector2(item[3],item[4]),4.5)
 # Faction materials stay shared after batching so round-side changes recolor
 # their architecture without rebuilding meshes.
 var palettes=[];var lights=[]
 for side in [-1,1]:
  var frame=k.material(Color.WHITE,.3);var glow=k.material(Color.WHITE,.5);var trim=k.material(Color("efc96c"),.7)
  glow.emission_enabled=true;glow.emission_energy_multiplier=1.8;trim.emission_enabled=true;trim.emission_energy_multiplier=.55
  palettes.append([frame,glow,trim])
  for z in [-12.0,-4.0,4.0,12.0]:
   k.box(a,Vector3(side*35,11.2,z),Vector3(.38,3.1,.55),frame,true)
   k.box(a,Vector3(side*35-side*.21,11.3,z),Vector3(.06,2.4,.16),glow)
   k.box(a,Vector3(side*35,9.08,z),Vector3(4,.06,.12),trim)
  var center=Vector3(-18,14,-21) if side<0 else Vector3(31,14,8)
  for n in range(12):
   var angle=n*TAU/12;var marker=k.box(a,center+Vector3(sin(angle)*3.3,.014,cos(angle)*3.3),Vector3(.18,.025,.7),trim);marker.rotation.y=angle
  var light=OmniLight3D.new();light.position=Vector3(side*32,11.8,1);light.omni_range=7;light.light_energy=.7;light.shadow_enabled=false;a.add_child(light);lights.append(light)
  # Flush courses and corner pilasters enrich the two new upper rooms.
  if side<0:
   for px in [-25.0,-16.0]:
    k.box(a,Vector3(px,16,-24.62),Vector3(2,3.2,.035),frame)
    k.box(a,Vector3(px,16,-24.59),Vector3(.06,2.6,.025),glow)
  else:
   for pz in [4.8,8.5,12.2]:
    k.box(a,Vector3(38.23,16,pz),Vector3(.035,3.2,2.3),frame)
    k.box(a,Vector3(38.20,16,pz),Vector3(.025,2.6,.06),glow)
  var x=-26.23 if side<0 else 38.23
  for z in ([-24,-18] if side<0 else [4,8,12]):
   for y in [14.6,16.7]:k.box(a,Vector3(x,y,z),Vector3(.03,.08,2.2),trim)
 a.set_meta("v19_palettes",palettes);a.set_meta("v19_accent_lights",lights);set_sides(a,0)
 # Floor inlays stay flush and decorative: no new invisible step collisions.
 for origin in [Vector3(0,7.012,2),Vector3(-4,0.012,15),Vector3(6,14.012,8)]:
  k.ring(a,origin,3.0,k.gold)
  for side in [-1,1]:k.box(a,origin+Vector3(side*3.5,.01,0),Vector3(.09,.018,5.5),k.gold)
 # Additional map pickups use the existing Use action and 150-second clock.
 a.pads.append_array([Vector3(-17,14,-23),Vector3(34,14,14)])
 a.pad_names.append_array(["PLASMA SCOPED BR","AUTOMATIC PLASMA"])
 a.pad_kinds.append_array(["plasma_br","plasma_auto"])
static func set_sides(a: NestArena,attacking_faction: int) -> void:
 if not a.has_meta("v19_palettes"):return
 var palettes=a.get_meta("v19_palettes");var lights=a.get_meta("v19_accent_lights")
 for index in range(2):
  var naki=(attacking_faction if index==0 else 1-attacking_faction)==0
  palettes[index][0].albedo_color=Color("f1eee5") if naki else Color("101115")
  palettes[index][1].albedo_color=Color("fff6dd") if naki else Color("f22c29")
  palettes[index][1].emission=palettes[index][1].albedo_color
  palettes[index][2].albedo_color=Color("e9bd55") if naki else Color("c92420")
  palettes[index][2].emission=palettes[index][2].albedo_color
  lights[index].light_color=Color("ffe8ac") if naki else Color("ff5440")
