class_name NestAnnuTacticalMap
extends RefCounted
const MEMORY_SECONDS: float=10.0
var radar: Control
var game: NestMatch
var footprints: Array[Dictionary]=[]
var world_rect=Rect2(-42,-29,84,58)
var geometry_key=""
var contact_epoch=""
func _init(owner):radar=owner;game=owner.game
func refresh_geometry() -> void:
 var forge=game.forge_session
 var key=str([game.arena.get_instance_id(),forge.revision,game.match_session])
 if geometry_key==key:return
 geometry_key=key;footprints.clear()
 world_rect=Rect2(-game.arena.bounds,game.arena.bounds*2)
 if forge.model!=null:
  for record in forge.model.records.values():
   if record.kind in ["pickup","light","mechanism"] or record.templates.is_empty() or not record.get("enabled",true):continue
   var box: AABB=record.node.global_transform*record.bounds
   if box.size.x<.15 or box.size.z<.15:continue
   var rect=Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))
   footprints.append({"rect":rect,"y":box.position.y,"cover":box.size.y>1.5})
   world_rect=world_rect.merge(rect)
 else:
  for floor in game.arena.floor_surfaces:
   var rect=Rect2(Vector2(floor.pos.x,floor.pos.z)-floor.size*.5,floor.size)
   footprints.append({"rect":rect,"y":floor.pos.y,"cover":false});world_rect=world_rect.merge(rect)
  for cover in game.arena.floor_cover:
   var rect=Rect2(Vector2(cover.pos.x,cover.pos.z)-cover.size*.5,cover.size)
   footprints.append({"rect":rect,"y":cover.pos.y,"cover":true});world_rect=world_rect.merge(rect)
 world_rect=world_rect.grow(2)
func camera_sees(actor: NestActor, camera: Camera3D) -> bool:
 if camera==null or not actor.alive or actor.cloak_deadline>game.now or game.context not in ["playing","chat"]:return false
 var screen=game.get_viewport().get_visible_rect()
 var height=NestActor.CROUCH_HEIGHT if actor.crouched and not actor.air_duck else NestActor.STAND_HEIGHT
 for part in [.90,.62,.38]:
  var point=actor.global_position+Vector3.UP*height*part
  if camera.is_position_behind(point) or not screen.has_point(camera.unproject_position(point)):continue
  if camera.global_position.distance_to(point)>camera.far:continue
  if game.vision_clear(camera.global_position,point):return true
 return false
func refresh() -> void:
 var player=game.player
 var epoch=str([game.match_session,game.round_number,player.character,player.faction])
 if epoch!=contact_epoch:contact_epoch=epoch;radar.contacts.clear()
 refresh_geometry()
 var camera=game.get_viewport().get_camera_3d()
 for actor in game.actors:
  if actor==player or not actor.alive:continue
  var id=actor.get_instance_id();var friend=actor.faction==player.faction and game.mode!=1
  var seen=friend or camera_sees(actor,camera)
  var source="view";var observed=game.now;var position=actor.global_position
  if not seen and game.mode!=1:
   var report=game.nu_sightings[player.faction].get(actor.net_id,{})
   if not report.is_empty() and int(report.life)==actor.life_id and int(report.round)==game.round_number and game.now-float(report.at)<=MEMORY_SECONDS:
    observed=float(report.at);position=report.pos;source="nu"
    # A recent server sighting is current; older sightings remain frozen memory.
    seen=game.now-observed<.2 and actor.net_id in game.nu.visible_enemy_ids(player)
    var old=radar.contacts.get(id,{})
    if old.is_empty() or observed>float(old.seen):radar.contacts[id]={"actor":actor,"pos":position,"friend":false,"seen":observed,"life":actor.life_id,"live":seen,"source":source}
  if seen:
   # Never replace a Nu timestamp with a fresh local clock after losing sight.
   radar.contacts[id]={"actor":actor,"pos":position,"friend":friend,"seen":observed,"life":actor.life_id,"live":true,"source":source}
  elif radar.contacts.has(id):radar.contacts[id].live=false
 for id in radar.contacts.keys():
  var c=radar.contacts[id]
  if not is_instance_valid(c.actor) or not c.actor.alive or int(c.life)!=c.actor.life_id or game.now-float(c.seen)>MEMORY_SECONDS:radar.contacts.erase(id)
func inner_rect() -> Rect2:
 return Rect2(Vector2(8,24),Vector2(maxf(20,radar.size.x-16),maxf(20,radar.size.y-47)))
func map_point(position: Vector3) -> Vector2:
 var area=inner_rect();var scale=minf(area.size.x/world_rect.size.x,area.size.y/world_rect.size.y)
 return area.get_center()+(Vector2(position.x,position.z)-world_rect.get_center())*scale
func floor_rect(rect: Rect2) -> Rect2:
 var a=map_point(Vector3(rect.position.x,0,rect.position.y));var b=map_point(Vector3(rect.end.x,0,rect.end.y));return Rect2(a,b-a)
func text(point: Vector2,value: String,pixels: int,color: Color) -> void:
 radar.draw_string_outline(ThemeDB.fallback_font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,3,Color(0,0,0,.95))
 radar.draw_string(ThemeDB.fallback_font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,color)
func draw() -> void:
 refresh_geometry()
 var gold=Color("dbc47e");radar.draw_rect(Rect2(Vector2.ZERO,radar.size),Color(.025,.028,.025,float(game.prefs.values.radar_background_opacity)))
 radar.draw_rect(Rect2(Vector2.ZERO,radar.size),gold,false,1.5)
 var level=0 if radar.preview else game.arena.level_at(game.player.global_position.y)
 text(Vector2(8,16),"ANNU · TACTICAL MAP",10,gold)
 text(Vector2(radar.size.x-17,16),"N",10,gold)
 for f in footprints:
  var on_level=game.arena.level_at(float(f.y))==level
  var color=Color(.60,.65,.58,.70 if on_level else .14) if f.cover else Color(.22,.29,.24,.60 if on_level else .14)
  var rect=floor_rect(f.rect)
  radar.draw_rect(rect,color)
  if not f.cover:radar.draw_rect(rect,Color(.65,.69,.58,.45 if on_level else .10),false,.6)
 for i in range(game.arena.sites.size()):
  if game.mode not in [0,game.MODE_CS]:break
  text(map_point(game.arena.sites[i])+Vector2(-3,3),"A" if i==0 else "B",11,gold)
 if radar.preview:
  radar.draw_circle(map_point(Vector3(12,0,-8)),3.2,Color("ff5a62"));radar.draw_arc(map_point(Vector3(-15,0,12)),3.5,0,TAU,16,Color("da947c"),1.2,true)
 for id in radar.contacts:
  var c=radar.contacts[id];var point=map_point(c.pos)
  # Contacts outside the actual map are clipped, rather than pinned as false positions.
  if not inner_rect().grow(2).has_point(point):continue
  var live=bool(c.live);var color=Color("69c5ff") if c.friend else Color("ff5a62") if live else Color("da947c")
  if game.prefs.values.radar_colorblind:color=Color("67d5b5") if c.friend else Color("ffd166")
  if live:radar.draw_circle(point,3.2,color)
  else:
   radar.draw_arc(point,3.5,0,TAU,16,color,1.2,true)
   text(point+Vector2(5,3),"%ds"%mini(10,maxi(1,int(ceil(game.now-float(c.seen))))),9,color)
  var difference=game.arena.level_at(c.pos.y)-level
  if difference!=0:text(point+Vector2(-3,-5),"+" if difference>0 else "−",9,color)
 var me=map_point(Vector3.ZERO if radar.preview else game.player.global_position)
 var rotation=0.0 if radar.preview else game.player.rotation.y
 var forward=Vector2(-sin(rotation),-cos(rotation));var side=Vector2(-forward.y,forward.x)
 radar.draw_colored_polygon(PackedVector2Array([me+forward*5,me-forward*3+side*3,me-forward*3-side*3]),Color.WHITE)
 text(Vector2(8,radar.size.y-8),["BOTTOM","MIDDLE","TOP"][level]+" · HOLLOW = LAST SEEN",9,gold)
