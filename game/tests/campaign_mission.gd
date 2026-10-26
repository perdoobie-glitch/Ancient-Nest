extends SceneTree
var game
var failures=0
var checks=0
func check(ok: bool,text: String):
 checks+=1;print(("PASS " if ok else "FAIL ")+text)
 if not ok:failures+=1
func _initialize():call_deferred("run")
func frames(count=3):
 for i in range(count):await physics_frame
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames();game.sandbox_mode=true
 var campaign=game.campaign;campaign.save_store.path="user://campaign-qa-mission-"+Crypto.new().generate_random_bytes(5).hex_encode()+".json"
 campaign.menu();await frames()
 check(game.screen.find_child("CampaignDifficulty",true,false)!=null,"Campaign setup has Difficulty control")
 check(game.screen.find_child("CampaignContinue",true,false).disabled,"Continue is disabled without valid progress")
 campaign.selected_difficulty="Easy";campaign.begin_solo(false);await frames()
 check(campaign.active and game.running and game.player!=null,"New Campaign creates a playable Anki actor")
 check(game.player.weapons[0].kind=="plasma_br" and game.player.weapons[1].kind=="plasma_pistol","Starting plasma carbine and plasma pistol use requested definitions")
 check(campaign.state.phase=="INTRO" and campaign.data.intro_seconds==120,"Introduction uses the exact 120-second timeline")
 campaign.phase_elapsed=119;campaign.tick(.5);check(campaign.state.phase=="INTRO","Intro does not hand off before 120 seconds")
 campaign.tick(.5);await frames();check(campaign.state.phase=="PREPARATION" and game.context=="playing","Normal 120-second handoff restores playable preparation")
 check(not campaign.checkpoint.is_empty() and campaign.checkpoint.difficulty=="Easy","Preparation milestone saves Difficulty offline")
 var actor=game.player
 actor.global_position=campaign.world.locations.service+Vector3(0,0,2);await frames()
 var service=campaign.interaction(actor);check(not service.is_empty() and campaign.interact(actor,service),"Personal equipment check is reachable and interactive")
 actor.global_position=campaign.world.locations.calibration+Vector3(0,0,2);await frames()
 var calibration=campaign.interaction(actor);campaign.interact(actor,calibration)
 check(actor.shield<actor.tuning.shield_capacity and actor.health==actor.tuning.health_capacity,"Calibration loads only shields without lethal damage")
 actor.global_position=Vector3(-5,.1,12);actor.last_damage=game.now-20;actor.shield=actor.tuning.shield_capacity;campaign.observe_practice(actor)
 check(campaign.state.practice["1"].shield,"Own shield recovery behind calibration barrier is tracked")
 # Drive host-observed practice evidence; this fixture checks guards, not human tutorial usability.
 for key in NestCampaign.PRACTICE:campaign.state.practice["1"][key]=true
 campaign.tick(0);check(campaign.state.phase=="BOARDING","Boarding unlocks only after required personal checks")
 actor.global_position=campaign.world.locations.manifest+Vector3(0,0,2);await frames();campaign.interact(actor,campaign.interaction(actor))
 actor.global_position=campaign.world.locations.board+Vector3(0,0,2);await frames();campaign.interact(actor,campaign.interaction(actor));campaign.tick(0)
 check(campaign.state.phase=="DEPARTURE","Cargo confirmation and boarding permit launch")
 campaign.send_action("skip",{});campaign.tick(0);await frames();check(campaign.state.phase=="CRASH" and campaign.world.region=="forest","Departure skip reliably creates the staged forest crash")
 campaign.send_action("skip",{});campaign.tick(0);await frames();check(campaign.state.phase=="CRASH_ORIENTATION" and game.player.alive,"Crash skip restores live players without cinematic damage")
 actor=game.player;actor.global_position=campaign.world.locations.radio+Vector3(0,0,2);await frames()
 check(not campaign.interact(actor,campaign.interaction(actor)) and campaign.state.phase!="ENDING","Radio cannot complete an unfinished mission")
 actor.global_position=campaign.world.locations["charge"+str(campaign.state.charge_site)]+Vector3(0,0,2);await frames();var charge=campaign.interaction(actor)
 check(not charge.is_empty() and campaign.interact(actor,charge) and campaign.state.bomb=="carried","Charge is physically recoverable before combat")
 actor.global_position=campaign.world.locations.secure+Vector3(0,0,2);await frames();campaign.interact(actor,campaign.interaction(actor))
 check(campaign.state.bomb=="secured" and campaign.checkpoint.bomb=="secured","Securing charge merges durable objective into safe checkpoint")
 campaign.phase_elapsed=1000;campaign.tick(0);check(campaign.state.phase=="CRASH_ORIENTATION","Waiting at the ship never starts a timed assault")
 actor.global_position=campaign.world.maze.checkpoints[0];campaign.tick(0);await frames()
 check(campaign.state.phase=="WAVE_1","Reaching Fern Gate begins the first assault")
 for wave in range(5):
  for i in range(NestCampaignState.COUNTS[wave]):
   var id=-1000-wave*100-i
   if campaign.state.register_enemy(id):
    var enemy=campaign.make_actor(id,false,0,"Fixture defender");enemy.global_position=Vector3(-20+i,0,-20)
    enemy.die(game.player,"campaign-test");campaign.update_wave()
  check(campaign.state.completed_waves==wave+1,"Actual actor deaths complete wave "+str(wave+1))
  if wave<4:
   campaign.phase_elapsed=1000;campaign.tick(0);check(campaign.state.phase.begins_with("INTERMISSION_"),"Cleared checkpoint does not retrigger or start next wave on a timer")
   actor.global_position=campaign.world.maze.checkpoints[wave+1];campaign.tick(0)
 check(campaign.state.defeated.size()==34 and campaign.state.radio_ready(),"All exact waves and secured charge enable final radio")
 actor=game.player;actor.global_position=campaign.world.locations.radio+Vector3(0,0,2);await frames();campaign.interact(actor,campaign.interaction(actor))
 check(campaign.state.phase=="ENDING","Shared radio interaction enters ending exactly once")
 campaign.send_action("skip",{});campaign.tick(0);await frames()
 check(campaign.state.phase=="COMPLETE" and campaign.state.completion_count==1,"Ending skip commits completion exactly once")
 check(not game.ranked.eligible and not game.ranked.submitted,"Campaign never enters competitive ranking")
 var path=campaign.save_store.path;campaign.exit_campaign();await frames()
 check(game.arena!=null and not campaign.active and not game.running,"Returning to menu restores the original multiplayer arena")
 for suffix in ["",".bak",".tmp"]:
  if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
 game.queue_free();await frames();print("CAMPAIGN MISSION: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
