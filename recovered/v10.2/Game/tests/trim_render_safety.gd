extends SceneTree
func _initialize():call_deferred("run")
func details(actor:NestActor)->Array[MeshInstance3D]:
 var nodes:Array[MeshInstance3D]=[]
 for attachment in actor.skeleton.get_children():
  if attachment is BoneAttachment3D and attachment.get_child_count()>0 and attachment.get_child(0).has_meta("skin_bone"):
   for node in attachment.get_child(0).find_children("*","MeshInstance3D",true,false):nodes.append(node)
 return nodes
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.bot_fill=false;game.start_game();game.process_mode=Node.PROCESS_MODE_DISABLED;game.now=100
 var count=0
 for character in [0,1]:
  var first=NestActor.new();first.game=game;first.character=character;game.add_child(first);game.actors.append(first)
  var second=NestActor.new();second.game=game;second.character=character;game.add_child(second);game.actors.append(second)
  first.global_position=Vector3(100,0,100);second.global_position=Vector3(104,0,100)
  var a=details(first);var b=details(second);assert(a.size()==(9 if character==0 else 4));assert(a.size()==b.size())
  for i in a.size():
   assert(a[i]!=b[i] and a[i].mesh==b[i].mesh,"Geometry shared, node state independent")
   assert(a[i].cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
  var bone_names={}
  for attachment in first.skeleton.get_children():
   if attachment is BoneAttachment3D and String(attachment.name).begins_with("CoverSkin_"):
    assert(not bone_names.has(attachment.bone_name));bone_names[attachment.bone_name]=true
  var templates=NestReferenceSkin.detail_templates.size()
  first.cloak_deadline=200;first.refresh_model_visibility();second.cloak_deadline=0;second.refresh_model_visibility()
  for node in a:assert(node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
  for node in b:assert(node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
  assert(first.camo_renderer.body_count==17 and first.camo_renderer.originals.size()>0)
  first.cloak_deadline=0;first.refresh_model_visibility();assert(first.camo_renderer.originals.is_empty())
  for node in a:assert(node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
  for actor in [first,second]:
   assert(actor.hitboxes.size()==17 and actor.skeleton.get_bone_count()==40)
   for kind in ["ak47","burst_scoped","smg","sidearm","sniper","shotgun","rocket","plasma_br","plasma_auto","plasma_smg","plasma_pistol","plasma_sniper"]:
    actor.weapons[0]=NestWeaponCatalog.profile(kind);actor.slot=0;actor.action_state="ready";actor.update_weapon_art()
    for state in ["ready","reloading","melee","throwing"]:
     actor.action_state=state;actor.action_until=game.now+.3;actor.throw_started=game.now-.15;actor.flash_until=game.now+.1;actor.update_visual(1./60.)
     for area in actor.hitboxes:assert(area.global_transform.origin.is_finite())
     count+=1
  assert(NestReferenceSkin.detail_templates.size()==templates,"Cache bounded by faction, not actor/weapon/action")
 print("PASS trim geometry shares resources but isolates cloak/shadows; one attachment per bone; 17 hitboxes/40 bones; ",count," weapon-action poses; bounded faction cache")
 game.stop_game();game.queue_free();await create_timer(.3).timeout;quit()
