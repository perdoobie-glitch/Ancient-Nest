extends SceneTree
var game
var failures=0
var checks=0
func check(ok: bool,message: String):
 checks+=1;print(("PASS " if ok else "FAIL ")+message)
 if not ok:failures+=1
func _initialize():call_deferred("run")
func frames(n=2):
 for i in range(n):await physics_frame
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames();game.sandbox_mode=true;game.set_physics_process(false)
 var c=game.campaign;c.save_store.path="user://chapter-cinematic-qa.json";c.begin_solo(false);c.set_process(false);c.phase_elapsed=0;game.input_window_focused=true
 check(c.data.intro.size()==6,"Full original Mission 1 narration remains preserved as reference")
 for cues in [NestCampaignCinematic.MISSION_ONE_INTRO,NestCampaignCinematic.MISSION_ONE_ENDING]:
  check(cues.size()==3 and cues.all(func(line):return str(line[1]).split(" ",false).size()<=20),"Condensed Mission 1 story uses three readable five-second cues")
 c.tick(14.99);check(c.state.phase=="INTRO","Mission 1 introduction remains active at 14.99 seconds")
 c.tick(.01);check(c.state.phase=="PREPARATION","Mission 1 introduction ends at 15 seconds")
 for mission in range(2,10):
  c.journey.start_standalone(mission);c.set_process(false);c.phase_elapsed=0
  check(c.state.phase=="CHAPTER_INTRO" and c.frozen_actors() and not c.can_damage(game.player),"Mission %d introduction freezes and protects expedition"%mission)
  var hp=game.player.health+game.player.shield
  check(not game.player.take_damage(500,"torso","heavy",false,null,800000+mission) and game.player.health+game.player.shield==hp,"Mission %d cinematic rejects actual damage"%mission)
  var intro_save=c.checkpoint.duplicate(true)
  check(NestCampaignState.valid(intro_save) and c.save_store.read_valid(c.save_store.path).phase=="CHAPTER_INTRO","Mission %d intro is a valid safe checkpoint"%mission)
  c.restore_checkpoint(intro_save);c.phase_elapsed=0
  check(c.state.phase=="CHAPTER_INTRO" and c.phase_elapsed==0,"Mission %d intro safely resumes from its beginning"%mission)
  var chapter=c.journey.chapter()
  for outro in [false,true]:
   var cues=chapter.ending if outro else chapter.briefing
   check(cues.size()==3 and cues.all(func(line):return str(line[1]).split(" ",false).size()<=16),"Mission %d %s contains three readable story cues"%[mission,"outro" if outro else "intro"])
  for shot in range(3):
   c.cinematic.present(shot*5+.25)
   var expected=str(chapter.briefing[shot][1]);var position=c.cinematic.camera.global_position
   check(c.cinematic.subtitle.text.contains(expected) and position.is_finite() and c.cinematic.camera.current,"Mission %d introduction shot %d has correct story and camera"%[mission,shot+1])
   if str(chapter.briefing[shot][0]).begins_with("Annu"):
    var nearest=INF
    for actor in game.actors:
     if actor.faction==1:nearest=minf(nearest,actor.global_position.distance_to(position))
    check(nearest<13,"Mission %d Annu line frames an actual existing-rig sentry"%mission)
  check(game.player.model.visible and not game.player.camera.visible,"Mission %d cinematic shows the existing hero and hides the first-person gun"%mission)
  if mission in [2,4,6]:
   var first_frame=c.cinematic.chapter_director.shot_frame(c,0,.1,false);var second_frame=c.cinematic.chapter_director.shot_frame(c,1,.1,false)
   check(first_frame.target.distance_to(second_frame.target)>1,"Mission %d guard exchange frames two different existing Annu"%mission)
  c.phase_elapsed=0;c.tick(14.99);check(c.state.phase=="CHAPTER_INTRO","Mission %d intro cannot finish before 15 seconds"%mission)
  c.tick(.01);check(c.state.phase=="CHAPTER" and not c.frozen_actors(),"Mission %d exact introduction handoff restores player control"%mission)
  c.cinematic.present(0)
  check(not game.player.model.visible and game.player.camera.visible,"Mission %d handoff restores first-person presentation"%mission)
  # Isolate presentation from the combat fixture: construct its validated final milestone.
  c.state.chapter_stage=c.state.chapter_stage_count-1;c.state.chapter_expected=0;c.state.chapter_enemies.clear();c.state.chapter_spawned.clear();c.state.chapter_defeated.clear();c.state.chapter_flags={"objective":true};c.state.chapters_completed=mission;c.state.phase="CHAPTER_COMPLETE"
  c.journey._finish_presentation();var outro_save=c.checkpoint.duplicate(true)
  check(c.state.phase=="CHAPTER_OUTRO" and c.frozen_actors() and not c.can_damage(game.player),"Mission %d outro freezes and protects expedition"%mission)
  check(NestCampaignState.valid(outro_save) and c.save_store.read_valid(c.save_store.path).phase=="CHAPTER_OUTRO","Mission %d outro has a valid saved milestone"%mission)
  c.restore_checkpoint(outro_save)
  check(c.state.phase=="CHAPTER_OUTRO" and c.phase_elapsed==0,"Mission %d outro safely resumes from its beginning"%mission)
  for shot in range(3):
   c.cinematic.present(shot*5+.25)
   check(c.cinematic.subtitle.text.contains(str(chapter.ending[shot][1])) and c.cinematic.camera.global_position.is_finite(),"Mission %d outro shot %d has its own readable cue"%[mission,shot+1])
  if mission==9:
   var first_frame=c.cinematic.chapter_director.shot_frame(c,0,.1,true);var second_frame=c.cinematic.chapter_director.shot_frame(c,1,.1,true)
   check(first_frame.target.distance_to(second_frame.target)>1,"Final guard exchange frames two existing Annu after the machinery fight")
   c.cinematic.present(10.0);var start_ship=c.world.ship_root.position
   c.cinematic.present(14.9);var departure=c.world.ship_root.position
   check(start_ship.is_zero_approx() and departure.y>17 and departure.z< -11,"Final five-second shot visibly lifts the existing expedition ship out of the canyon")
   var departure_frame=c.cinematic.chapter_director.shot_frame(c,2,.98,true)
   check(departure_frame.target.distance_to(c.world.ship_position+departure+Vector3.UP*2)<.01,"Final camera follows the actual departing hull")
  c.phase_elapsed=0;c.tick(14.99);check(c.state.phase=="CHAPTER_OUTRO","Mission %d outro cannot finish before 15 seconds"%mission)
  c.tick(.01);check(c.state.phase=="CHAPTER_COMPLETE","Mission %d 15-second outro commits completion"%mission)
 c.journey.start_standalone(3);c.members[2]=c.local_member(2,0,"Existing expedition seat");c.members[2].loaded=c.phase_epoch
 c.apply_action(1,"skip",{});c.tick(0);check(c.state.phase=="CHAPTER_INTRO","One skip vote cannot bypass a connected squad member")
 c.apply_action(2,"skip",{});c.tick(0);check(c.state.phase=="CHAPTER","Unanimous skip vote restores gameplay")
 c.members.erase(2);c.exit_campaign();game.queue_free();await frames()
 print("CHAPTER CINEMATICS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
