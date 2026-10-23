extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.bot_fill=false;game.start_game();game.set_physics_process(false)
 var actor=game.player;actor.set_physics_process(false)
 for kind in ["ak47","shotgun","sniper","rocket","plasma_br","sidearm"]:
  actor.weapons[0]=NestWeaponCatalog.profile(kind);actor.slot=0;actor.action_state="ready";actor.update_weapon_art();game.now=100;actor.flash_until=95
  var art=actor.weapon_art;var presentation=actor.presentation
  presentation.animate_parts(art,-1);assert(bool(art.get_meta("parts_at_rest",false)))
  presentation.animate_parts(art,-1);assert(bool(art.get_meta("parts_at_rest",false)))
  presentation.animate_parts(art,.4);assert(not bool(art.get_meta("parts_at_rest",true)))
  presentation.animate_parts(art,-1);assert(bool(art.get_meta("parts_at_rest",false)))
  actor.flash_until=100.15;presentation.animate_parts(art,-1);assert(not bool(art.get_meta("parts_at_rest",true)))
  actor.flash_render_pending=true;NestGunFeedback.update(art,actor,0,true);assert(art.get_meta("gun_feedback").flash.visible)
  actor.flash_render_pending=false;NestGunFeedback.update(art,actor,3,true);assert(not art.get_meta("gun_feedback").flash.visible)
  var xf=art.get_meta("gun_feedback").flash.transform;NestGunFeedback.update(art,actor,4,true);assert(xf==art.get_meta("gun_feedback").flash.transform)
  print("PASS cosmetic rest/reload/fire transition ",kind)
 game.queue_free();await create_timer(.3).timeout;quit()
