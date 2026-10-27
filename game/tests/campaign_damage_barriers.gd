extends SceneTree
var game
var failures=0
var sequence=971000
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 print(("PASS " if ok else "FAIL ")+message)
 if not ok:failures+=1
func energy(actor) -> float:return actor.health+actor.shield+actor.overshield
func blast(victim,attacker):
 sequence+=1;game.explode(victim.global_position+Vector3.UP*NestActor.STAND_CENTER,attacker,sequence,20.0,false,"frag_grenade")
func run():
 if OS.get_environment("NEST_ISOLATED_QA")!="1":quit(1);return
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.sandbox_mode=true
 var c=game.campaign;c.save_store.path="user://damage-barrier-test.json";c.selected_mission=3;c.begin_solo(false);c.journey.finish_cinematic()
 game.set_physics_process(false);c.set_process(false);game.context="playing";game.input_window_focused=true
 c.journey.tick(0)
 var actor=game.player;var enemy
 for entity in game.actors:
  entity.set_physics_process(false)
  if entity.faction==1 and enemy==null:enemy=entity
 check(enemy!=null,"A live Annu from the traversal encounter provides the blast source")
 if enemy==null:c.exit_campaign();game.queue_free();quit(1);return
 actor.global_position=c.world.locations.objective0+Vector3(0,.25,2.2)
 enemy.global_position=actor.global_position+Vector3(6,0,0)
 c.members[2]=c.local_member(2,0,"Existing expedition seat");c.members[2].loaded=c.phase_epoch
 await physics_frame
 check(c.journey.interact(actor,"journey:objective") and c.state.chapter_stage==1,"Real traversal objective advances while the nearby Annu remains alive")
 check(game.actors.has(enemy) and enemy.alive and not c.all_loaded() and c.frozen_actors(),"Next-stage acknowledgement freezes the squad with a preserved hostile present")
 var before=energy(actor);actor.external=Vector3.ZERO;blast(actor,enemy)
 check(energy(actor)==before and actor.external.is_zero_approx(),"An actual explosion causes neither damage nor knockback while a member is loading")
 c.members[2].loaded=c.phase_epoch;blast(actor,enemy)
 check(c.all_loaded() and energy(actor)<before and actor.external.length()>.01,"Explosion damage and knockback resume after the final member acknowledges")
 c.members.erase(2);game.context="pause";before=energy(actor);actor.external=Vector3.ZERO;blast(actor,enemy)
 check(c.paused() and energy(actor)==before and actor.external.is_zero_approx(),"Solo pause rejects the actual explosion damage path and its impulse")
 game.context="playing";blast(actor,enemy)
 check(not c.paused() and energy(actor)<before,"Solo resume restores ordinary explosion damage")
 game.input_window_focused=false;before=energy(actor);actor.external=Vector3.ZERO;blast(actor,enemy)
 check(energy(actor)==before and actor.external.is_zero_approx(),"Lost window focus applies the same solo protection")
 game.input_window_focused=true;blast(actor,enemy)
 check(energy(actor)<before,"Returning focus restores ordinary damage without leaving immunity enabled")
 c.exit_campaign();game.queue_free();await process_frame;quit(1 if failures else 0)
