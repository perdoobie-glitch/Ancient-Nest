class_name NestCrossroadsLayout
extends RefCounted
# Original two-site layout: long / palace / mid / tunnels, not a copied map.
const ROOMS=[[8,18,24,34],[-8,8,22,34],[-30,30,18,26],[-36,-26,-24,24],[-36,-12,-30,-12],[-22,-14,-4,20],[-18,-4,-12,-4],[-6,6,-30,22],[4,26,-20,-12],[24,34,-18,22],[14,36,-30,-10],[-24,26,-34,-26],[-8,8,-36,-26]]
static func build(a: NestArena) -> void:
 var k=a.kit
 a.bounds=Vector2(44,39);a.sites.assign([Vector3(-23,0,-21),Vector3(25,0,-21)])
 a.ship_position=Vector3(13,0,29)
 a.pads.assign([Vector3(-31,0,6),Vector3(30,0,12),Vector3(0,0,-8),Vector3(-16.5,1.2,-19),Vector3(20,0,-18),Vector3(0,0,25),Vector3(-30,0,-17),Vector3(30,0,-17)])
 a.pad_kinds=["ak47","burst","sniper","shotgun","plasma_br","sidearm","rifle","plasma_auto"]
 a.pad_names=["AK-47","BATTLE RIFLE","SNIPER","SHOTGUN","PLASMA SCOPED BR","MAGNUM","AUTOMATIC RIFLE","AUTOMATIC PLASMA"]
 # A grid union gives continuous floors with perimeter collision only at exposed edges.
 var cells={}
 for room in ROOMS:
  a.floor_at((room[0]+room[1])*.5,0,(room[2]+room[3])*.5,Vector2(room[1]-room[0],room[3]-room[2]))
  for x in range(room[0],room[1],2):
   for z in range(room[2],room[3],2):cells[Vector2i(x,z)]=true
 var edges={}
 for cell in cells:
  for step in [Vector2i(2,0),Vector2i(-2,0),Vector2i(0,2),Vector2i(0,-2)]:
   if cells.has(cell+step):continue
   var along_x=step.y!=0
   var fixed=cell.y+(2 if step.y>0 else 0) if along_x else cell.x+(2 if step.x>0 else 0)
   var key=str(int(along_x))+":"+str(fixed)
   if not edges.has(key):edges[key]=[]
   if not NestCrossroadsDetails.wall_opening(along_x,fixed,cell.x if along_x else cell.y):edges[key].append(cell.x if along_x else cell.y)
 for key in edges:
  var values=edges[key]
  if values.is_empty():continue
  values.sort();var first=int(values[0]);var last=first
  for index in range(1,values.size()+1):
   if index<values.size() and int(values[index])==last+2:last=int(values[index]);continue
   var along_x=key.begins_with("1:");var fixed=float(key.get_slice(":",1));var center=(first+last+2)*.5;var length=last-first+2
   var pos=Vector3(center,0,fixed) if along_x else Vector3(fixed,0,center)
   NestSanctuaryLayout.wall(a,pos,Vector2(length,.6) if along_x else Vector2(.6,length),9.6)
   # Flush cornice, no invisible protruding collision.
   if index<values.size():first=int(values[index]);last=first
 # Long sightlines break on visible, solid cover; wide entries remain traversable.
 for item in [[-3,20,6,.7,4.6],[3,-24,6,.7,4.6],[0,2,4,.7,4.6],[-29,-22,3.6,4,2.6],[-18,-26,4,2.4,2.4],[29,-18,3.4,4,2.8],[19,-26,4,2.4,2.4],[28,8,.7,9,4.5],[-31,10,2.5,2,1.25],[2,-9,2.6,1.5,1.3],[-18,10,2.0,3,1.25]]:
  NestSanctuaryLayout.wall(a,Vector3(item[0],0,item[1]),Vector2(item[2],item[3]),item[4])
 # A short balcony offers an alternate angle, with an ordinary ramp, not a mandatory jump.
 a.floor_at(-16.5,1.2,-19,Vector2(5,6))
 a.floor_cover.append({"pos":Vector3(-16.5,0,-19),"size":Vector2(5,6)})
 a.floor_cover.append({"pos":Vector3(-16.5,0,-13),"size":Vector2(3.2,6)})
 a.up_route("PALACE BALCONY",Vector3(-16.5,0,-10),Vector3(-16.5,1.2,-16),3.2)
 k.box(a,Vector3(29,4.9,10),Vector3(10,.3,16),k.stone,true)
 for z in [4,12,18]:
  k.box(a,Vector3(25,3.0,z),Vector3(.12,.5,.25),k.lamp)
 for p in [Vector3(-34,0,-27),Vector3(34,0,-28),Vector3(-6,0,33),Vector3(6,0,-35)]:
  k.planter(a,p,true);a.floor_cover.append({"pos":p,"size":Vector2(2.1,2.1)})
 for p in [Vector3(-30,0,-6),Vector3(-20,0,18),Vector3(26,0,-10)]:
  k.arch(a,p,0,5.8)
  for side in [-1,1]:a.floor_cover.append({"pos":p+Vector3(side*2.9,0,0),"size":Vector2(1.5,1.5)})
 for site in range(2):
  var pos=a.sites[site];k.ring(a,pos+Vector3.UP*.025,3.2,k.gold)
  k.label(a,pos+Vector3.UP*4.3,"A · SUN COURT" if site==0 else "B · MOON COURT",Color("dfc890"),32)
 for item in [[Vector3(0,2,27),"ATTACKER SPAWN"],[Vector3(0,2,-32),"DEFENDER SPAWN"],[Vector3(-31,2,5),"LONG → A"],[Vector3(-18,2,9),"PALACE → A"],[Vector3(0,3,12),"MID · CONNECTORS"],[Vector3(29,2,15),"TUNNELS → B"]]:k.label(a,item[0],item[1],Color("dfc890"),24)
 # Faction presentation and objective positions share the same geometry on both peers.
 for team in [0,1]:
  var z=30 if team==0 else -32
  for x in [-5,-2,2,5]:a.spawns[team].append(Vector3(x,.08,z))
  a.flag_labels.append(k.label(a,Vector3(0,4,z),"NAKI" if team==0 else "ANNU",Color("dfc890")))
  a.flag_meshes.append(k.banner(a,Vector3(7,0,z),k.green if team==0 else k.red))
 NestCrossroadsDetails.build(a)
 a.set_meta("crossroads_rooms",ROOMS)
