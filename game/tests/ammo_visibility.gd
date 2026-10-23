extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g);g.lobby_network.set_process(false);g.lobby_network=null;await process_frame;g.bot_fill=false;g.mode=1;g.start_game();g.set_physics_process(false);var p=g.player;p.set_physics_process(false);p.set_process(false);var failed=0
 for k in ["rifle","ak47","burst","burst_scoped","sidearm","sniper","shotgun","rocket","plasma_br","plasma_auto"]:
  p.weapons.assign([NestWeaponCatalog.profile(k)]);p.ammo.assign([30]);p.reserve.assign([100]);p.slot=0;p.art_kind="";p.update_weapon_art();p.presentation.update_view_weapon(0)
  var tag=p.weapon_art.get_meta("gun_feedback").ammo;var screen=p.camera.unproject_position(tag.global_position);var depth=-p.camera.to_local(tag.global_position).z;var ok=depth>p.camera.near and p.camera.get_viewport().get_visible_rect().has_point(screen)
  if not ok:failed+=1
  print("COUNTER ",k," depth=",depth," screen=",screen," PASS=",ok)
 print("COUNTER FRUSTUM: 10 checks, ",failed," failures");g.stop_game();g.queue_free();await process_frame;quit(1 if failed else 0)
