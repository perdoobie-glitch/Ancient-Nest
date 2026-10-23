extends SceneTree
var game
var checks=0
var failures=0
var events=[]
func _initialize():call_deferred("run")
func check(ok: bool, message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func frames(n=3):
 for i in range(n):await process_frame
func count_event(id: String) -> int:return events.filter(func(e):return e.id==id).size()
func capture(name):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/work/feedback-traits/"+name+".png")
func choose(editor,index):editor.character_selector.select(index);editor.character_selector.item_selected.emit(index)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await frames()
 game.bot_fill=false;game.team_size=1;game.matchup=1;game.show_lobby();await frames()
 check(game.lobby_preview.characters==[0,0] and game.lobby_preview.viewport.own_world_3d,"Naki matchup shows two display models in an isolated world")
 check(game.lobby_preview.pivots.all(func(p):return p.find_children("*","CollisionObject3D",true,false).is_empty()),"Preview models contain no gameplay collision objects")
 var right=InputEventKey.new();right.keycode=KEY_RIGHT;right.physical_keycode=KEY_RIGHT;right.pressed=true
 Input.parse_input_event(right.duplicate());game.lobby_preview._process(.1)
 check(game.lobby_preview.pivots[0].rotation.y>.1 and is_equal_approx(game.lobby_preview.pivots[0].rotation.y,game.lobby_preview.pivots[1].rotation.y),"Arrow keys rotate both preview models together")
 right.pressed=false;Input.parse_input_event(right.duplicate())
 var text=LineEdit.new();game.screen.add_child(text);text.grab_focus();await frames();var angle=game.lobby_preview.pivots[0].rotation.y
 right.pressed=true;Input.parse_input_event(right.duplicate());game.lobby_preview._process(.1)
 check(is_equal_approx(angle,game.lobby_preview.pivots[0].rotation.y),"Typing focus prevents preview rotation")
 right.pressed=false;Input.parse_input_event(right.duplicate());text.queue_free()
 await create_timer(.3).timeout;await capture("naki-preview")
 game.matchup=2;game.show_lobby();await frames();check(game.lobby_preview.characters==[1,1],"Annu matchup replaces both display models")
 await create_timer(.3).timeout;await capture("annu-preview")
 game.open_game_type_settings();await frames();var editor=game.game_type_editor
 check(editor.character_selector.item_count==NestCharacterCatalog.all().size()+1,"Traits selector is built from the character catalog plus shared Default")
 choose(editor,1);editor.controls.max_health_percent.value=80;editor.controls.movement_speed_percent.value=125;editor.controls.health_regeneration.button_pressed=true;editor.controls.health_regen_delay.value=1;editor.controls.damage_resistance_percent.value=200
 check(editor.draft.character_traits.naki.max_health_percent==80 and not editor.draft.character_traits.has("annu") and editor.draft.max_health_percent==100,"Naki edits leave Annu and shared Default unchanged")
 choose(editor,2);check(editor.controls.max_health_percent.value==100 and not editor.controls.show_low_health_vignette.button_pressed,"Annu starts with its own red-edge default and inherited base health")
 editor.controls.max_health_percent.value=150;editor.controls.damage_dealt_percent.value=200;editor.controls.starting_primary.select(6)
 editor.set_draft_value("starting_primary","sniper_rifle")
 check(editor.character_selector.get_item_text(2).contains("Edited") and editor.controls.mode.disabled,"Edited characters are marked and shared match rules stay disabled in character scope")
 await capture("character-traits")
 editor.copy_character_traits(2)
 check(editor.controls.max_health_percent.value==80,"Copy traits transfers the donor character's settings")
 editor.reset_character_traits();check(editor.controls.max_health_percent.value==100 and not editor.controls.show_low_health_vignette.button_pressed,"Reset This Character restores its own defaults")
 editor.controls.max_health_percent.value=150;editor.controls.movement_speed_percent.value=60;editor.controls.damage_dealt_percent.value=200;editor.set_draft_value("starting_primary","sniper_rifle")
 var saved=NestGameTypeLibrary.save_new(editor.draft,"Character Duel");var loaded=NestGameTypeLibrary.load_saved(saved.id)
 check(saved.ok and loaded.character_traits.naki.max_health_percent==80 and loaded.character_traits.annu.max_health_percent==150,"Named game types retain independent character traits")
 var unsafe=GameTypeSettings.new();unsafe.apply_network_dict({"character_traits":{"naki":{"max_health_percent":999999,"gravity_percent":NAN,"mode":3,"starting_primary":"frag_grenade"},"unknown":{"max_health_percent":1}}})
 check(unsafe.character_traits.naki.max_health_percent==1000 and not unsafe.character_traits.naki.has("gravity_percent") and not unsafe.character_traits.naki.has("mode") and not unsafe.character_traits.naki.has("starting_primary") and not unsafe.character_traits.has("unknown"),"Malformed trait tables cannot inject match rules or invalid characters")
 var old=GameTypeSettings.new();old.apply_network_dict({"max_health_percent":120});check(old.character_traits.is_empty() and NestCharacterTraits.value(old,"naki","max_health_percent")==120 and NestCharacterTraits.value(old,"annu","max_health_percent")==120,"Older shared presets become the Default traits for both characters")
 editor.apply_changes();await frames();game.selected_character=1;game.bot_fill=false;game.start_game();game.set_physics_process(false);game.context="playing"
 var p=game.player;p.set_physics_process(false);p.set_process(false);p.global_position=Vector3(100,50,100);p.apply_aim_rotation()
 var floor_body=StaticBody3D.new();var floor_shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(60,1,60);floor_shape.shape=box;floor_body.add_child(floor_shape);game.add_child(floor_body);floor_body.position=Vector3(100,49.5,100)
 var naki=NestActor.new();naki.game=game;naki.character_choice=0;naki.faction=1;game.add_child(naki);game.actors.append(naki);naki.respawn();naki.set_physics_process(false);naki.set_process(false);naki.global_position=Vector3(100,50,94);await physics_frame
 check(p.character==1 and p.health==150 and p.shield==0 and naki.character==0 and naki.health==80 and naki.shield==100,"Spawn applies selected characters and their individual health/protection")
 check(p.weapons[0].kind=="sniper" and naki.traits.movement_speed_percent==125,"Per-character loadout and movement traits reach actual actors")
 game.create_hud();p.health=1;p.shield=0;p.health_flash_at=game.now;p.health_flash_strength=1;game.hurt_overlay._process(.016)
 check(not game.hurt_overlay.visible and not p.traits.show_low_health_vignette,"Annu has no red screen edges even during a low-health damage flash")
 p.set_character(0);p.respawn();p.shield=0;game.hurt_overlay._process(.016)
 check(p.traits.show_low_health_vignette and game.hurt_overlay.visible,"Switching back to Naki restores red shieldless edges")
 p.set_character(1);p.respawn();p.health=150;naki.shield=100;var before=naki.shield
 naki.take_damage(10,"torso","bullet",false,p,99001)
 check(is_equal_approx(before-naki.shield,10),"Outgoing Annu damage and incoming Naki resistance combine on the server")
 naki.health=20;naki.last_damage=0;game.now=2;naki._physics_process(1.0/60)
 check(naki.health>20,"Per-character regeneration delay and enable flag affect actual recovery")
 naki.health=1;naki.respawn();check(naki.health==80,"Respawn reapplies the character traits")
 p.global_position=Vector3(100,50.05,100);naki.global_position=Vector3(100,50.05,94)
 for actor in [p,naki]:
  actor.controlled=Vector3.ZERO;actor.external=Vector3.ZERO
  for i in range(65):actor.movement_step(Vector2(0,-1),false,0,0,1.0/60)
 check(is_equal_approx(Vector2(p.velocity.x,p.velocity.z).length(),p.tuning.ground_speed*.6) and is_equal_approx(Vector2(naki.velocity.x,naki.velocity.z).length(),naki.tuning.ground_speed*1.25),"Shared movement simulation applies different real speeds to each character")
 game.audio.playback_enabled=true;game.audio.sound_started.connect(func(id,path,voice):events.append({"id":id,"path":path,"voice":voice}))
 var profiles=[]
 for item in NestWeaponCatalog.data().weapons:
  if item.get("slot","") not in ["primary","secondary"]:continue
  var profile=NestWeaponCatalog.profile(item.id);profiles.append(profile)
  check(profile.shot_sounds.size()==3 and profile.distant_sound!=null and profile.reload_sound!=null and profile.dry_fire_sound!=null,"Complete distinct sound set: "+String(item.title))
  var previous="";var repeats=false
  for i in range(5):
   game.audio.play_weapon(profile,p.eye.global_position,true,"test:"+item.id)
   var path=events[-1].path
   if path==previous:repeats=true
   previous=path
  check(not repeats,"Shot variants do not repeat consecutively: "+String(item.title))
 check(profiles.size()==8,"All eight guns are covered; grenades keep their existing effects")
 var fired=0
 for profile in profiles:
  p.weapons[0]=profile;p.ammo[0]=profile.magazine;p.reserve[0]=profile.reserve;p.action_state="ready";p.cooldown=0;p.burst_left=0;p.combat_audio.equipped();game.now+=1
  var accepted=p.accepted_shots
  if p.fire_trigger() and p.accepted_shots==accepted+1:fired+=1
  await frames(2)
 check(fired==8,"Every actual gun controller fires an eligible round with its new local feedback")
 game.clear_effects();p.burst_left=0
 game.audio.stop_all();events.clear();p.camera.current=true;p.apply_aim_rotation();var listener=p.camera.global_position
 var voices=game.audio.play_weapon(profiles[0],listener,true,"local-test")
 check(voices.size()==1 and voices[0] is AudioStreamPlayer and not voices[0] is AudioStreamPlayer3D,"Local firing uses one non-positional voice")
 voices=game.audio.play_weapon(profiles[0],listener+Vector3(5,0,0),false,"remote-test")
 check(voices.size()==1 and voices[0] is AudioStreamPlayer3D and events[-1].path.contains("shot_"),"Nearby remote firing is positional")
 game.audio.play_weapon(profiles[0],listener+Vector3(50,0,0),false,"remote-test")
 check(events[-1].path.ends_with("shot_distant.ogg"),"Remote shots beyond 40 metres select the distant report")
 var key=game.audio.prepare_weapon(profiles[0]);game.audio.stop_all()
 for i in range(8):game.audio.play_weapon(profiles[0],listener,true,"pool-test")
 check(game.audio.pool.active_count(key)==6,"Rapid shots retain overlapping playback with a six-voice weapon limit")
 var fallback=NestWeaponCatalog.feedback_stream("res://audio/missing_test_report.ogg",profiles[0].shot_sounds[0].resource_path)
 check(fallback!=null,"Missing weapon recordings fall back safely")
 p.weapons[0]=profiles[0];p.combat_audio.equipped();p.ammo[0]=1;p.reserve[0]=50;p.action_state="ready";p.reload_weapon();events.clear();p.combat_audio.emit_reload_stage(0)
 check(not events.is_empty() and events[-1].path.ends_with("reload.ogg") and events[-1].voice is AudioStreamPlayer,"Reload stage uses the weapon resource's local reload recording")
 p.action_state="ready";p.combat_audio.stop_reload()
 var tracer=NestTracer.new();tracer.game=game;game.effects.add_child(tracer);tracer.setup(Vector3(100,55,100),Vector3(100,55,90))
 check(is_equal_approx(tracer.material.albedo_color.a,.10) and tracer.material.blend_mode==BaseMaterial3D.BLEND_MODE_ADD,"Tracer uses 10 percent alpha and additive unshaded material")
 var first=tracer.global_position;tracer.update_streak(.01)
 check(tracer.global_position.distance_to(first)>1 and tracer.scale.z<=NestTracer.LENGTH+.0001 and tracer.expires-game.now<=.5,"Tracer travels as a short bounded streak rather than a static full line")
 events.clear();p.global_position=Vector3(100,50,100);naki.global_position=Vector3(100,50,94);p.reset_damage_visual();await physics_frame
 var head=p.eye.global_position;var weapon=profiles[0]
 game.launch_bullet(naki,weapon,head+Vector3(-4,.8,0),Vector3.RIGHT,0,false,99101)
 check(count_event("bullet_flyby")==1,"Hitscan near misses now produce a listener-only fly-by")
 game.launch_bullet(p,weapon,head+Vector3(-4,.8,0),Vector3.RIGHT,0,false,99102)
 check(count_event("bullet_flyby")==1,"The shooter's own bullets never create fly-by audio")
 await physics_frame
 var old_health=p.health;var old_helmet=p.helmet_hp
 game.launch_bullet(naki,weapon,head+Vector3(-4,0,0),Vector3.RIGHT,0,false,99103)
 check((p.health<old_health or p.helmet_hp<old_helmet) and count_event("bullet_flyby")==1,"A direct hit does not also play a near-miss sound")
 var projectile=load("res://scripts/bullet.gd").new();projectile.game=game;projectile.owner_actor=naki;projectile.profile=NestWeaponCatalog.profile("rocket_launcher");projectile.direction=Vector3.RIGHT;projectile.round_id=game.round_number;game.effects.add_child(projectile)
 check(projectile.trail!=null and projectile.trail.projectile_trail,"Fast projectiles retain swept hit detection and gain a cosmetic trail")
 game.now+=1;tracer._process(.016);await frames();check(not is_instance_valid(tracer),"Expired hitscan tracers are removed")
 game.stop_game();game.queue_free();await frames(5)
 print("TRAITS AND FEEDBACK: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
