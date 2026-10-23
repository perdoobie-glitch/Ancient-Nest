extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool, message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error(message)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 game.lobby_network.set_process(false);game.lobby_network=null
 game.prefs.values.graphics_quality=0;game.prefs.apply();NestGraphicsQuality.apply_arena(game.arena,game.prefs.values)
 check(not game.arena.sun.shadow_enabled and root.msaa_3d==Viewport.MSAA_DISABLED,"Low mode disables shadow passes and MSAA")
 check(Engine.physics_ticks_per_second==60 and not Input.use_accumulated_input,"Low mode preserves simulation timing and immediate input")
 var settings=GameTypeSettings.new();settings.mode=2;settings.max_players_per_team=1;settings.bots_fill_empty_slots=true;game.apply_game_type_settings(settings);game.clear_screen();game.start_game();game.set_physics_process(false)
 for a in game.actors:a.set_physics_process(false)
 var enemy=game.actors.filter(func(a):return a!=game.player)[0]
 enemy.set_character(0);enemy.respawn();enemy.set_physics_process(false)
 var fx=enemy.shield_fx
 for i in range(4):await process_frame
 check(fx.overlay_meshes.size()==1 and not fx.overlay_enabled,"Idle shield overlay removes transparent passes and excludes cape/equipment")
 enemy.shield_flash_at=game.now;enemy.shield_flash_strength=.8;fx._process(.016)
 check(fx.overlay_enabled and fx.overlay_meshes[0].material_overlay==fx.overlay,"Shield impact immediately restores the body ripple")
 game.now+=3;fx._process(.016)
 check(not fx.overlay_enabled and fx.overlay_meshes[0].material_overlay==null,"Expired shield ripple releases its render pass")
 enemy.shield_break_at=game.now;fx._process(.016)
 check(fx.break_count==1 and fx.shards.amount==12,"Low-mode shield break retains feedback with fewer shards")
 var blast=NestBlastFX.new();game.effects.add_child(blast)
 check(blast.smoke.size()==3 and blast.fragments.size()==5 and blast.smoke_seconds==1,"Low mode keeps one-second smoke and halves decorative fragments")
 blast.queue_free()
 var hits=enemy.hitboxes.size()
 for level in [1,2,0]:
  game.prefs.values.graphics_quality=level;game.prefs.apply();NestGraphicsQuality.apply_arena(game.arena,game.prefs.values)
  check(game.arena.sun.shadow_enabled==(level>0 and game.prefs.values.shadows),"Quality %d applies its shadow policy"%level)
 check(enemy.hitboxes.size()==hits and Engine.physics_ticks_per_second==60,"Quality switching preserves damage hulls and multiplayer physics")
 game.open_settings("pause");game.settings_tab="Video";game.show_settings()
 var choices=game.screen.find_children("GraphicsQuality","OptionButton",true,false)
 check(choices.size()==1 and choices[0].item_count==3,"Video settings exposes Low, Balanced and High")
 for character in [0,1]:
  game.show_character(character)
  var models=game.screen.find_children("*","Skeleton3D",true,false)
  check(models.size()>0 and models[0].get_parent().get_parent().has_meta("reference_skin_details"),"Character viewer applies the current faction skin %d"%character)
 game.stop_game();game.open_forge();game.start_forge_session();await process_frame
 check(not game.arena.sun.shadow_enabled,"Nest Forge rebuild keeps Low-mode shadow policy")
 var forge=game.forge_session.model;var added=forge.create_item({"type":"light","kind":"spot"})
 forge.set_light(added,{"color":[1,1,1],"energy":1,"range":10,"angle":45,"shadows":true})
 check(not forge.records[added].node.shadow_enabled and forge.light_data(forge.records[added].node).shadows,"Low-mode Nest Forge lights retain saved shadow preference without drawing shadows")
 game.forge_session.clear();game.stop_game();game.queue_free();await process_frame;await process_frame
 print("V33 POLISH: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
