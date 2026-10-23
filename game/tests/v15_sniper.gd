extends SceneTree
var game
var failures=0
var checks=0
func _initialize():call_deferred("run")
func check(ok,message):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;game.bot_fill=false;game.mode=1;game.start_game();game.clear_screen();var p=game.player;p.set_physics_process(false);p.set_process(false);game.set_physics_process(false)
 p.weapons.assign([NestWeaponCatalog.profile("sniper")]);p.ammo.assign([4]);p.reserve.assign([20]);p.slot=0;p.update_visual(.016);p.combat_audio.update(0)
 for faction in [0,1]:
  var art=NestWeaponArt.create("sniper",faction);game.add_child(art);var orange=0
  for mesh in art.find_children("*","MeshInstance3D",true,false):
   for i in mesh.mesh.get_surface_count():
    var mat=mesh.get_surface_override_material(i)
    if mat is StandardMaterial3D and mat.albedo_color.is_equal_approx(Color("ef751e")):orange+=1
  check(orange>0,"Sniper has orange shell for faction "+str(faction));art.queue_free()
 var parts=p.weapon_art.find_children("ChargingHandle*","Node3D",true,false);check(not parts.is_empty(),"Sniper has independent bolt handle")
 var cam=p.camera.global_basis;var ammo=p.ammo[0];var handle=parts[0]
 game.now=10;p.flash_until=game.now+.15;p.presentation.animate_parts(p.weapon_art,-1);var rest=handle.transform
 for entry in [[.18,false],[.42,true],[.60,true]]:
  game.now=10+entry[0];p.presentation.animate_parts(p.weapon_art,-1);check(not handle.transform.is_equal_approx(rest),"Bolt visibly moves at "+str(entry[0]))
 game.now=10.95;p.presentation.animate_parts(p.weapon_art,-1);check(handle.transform.is_equal_approx(rest),"Bolt locks back to rest before next shot")
 check(p.camera.global_basis.is_equal_approx(cam) and p.ammo[0]==ammo,"Bolt animation never changes aim or ammo")
 var events=[];game.audio.playback_enabled=false;game.audio.sound_started.connect(func(id,_path,_voice):events.append(id));p.combat_audio.on_fire(true)
 check(events.size()==1 and str(events[0]).begins_with("weapon_profile_"),"One shot emits exactly one fire sound event")
 check(p.combat_audio.shell_cues.is_empty() and not is_finite(p.combat_audio.handle_at),"No delayed casing or bolt sound is scheduled")
 var bullet=Node3D.new();bullet.set_script(load("res://scripts/bullet.gd"));bullet.game=game;bullet.check_flyby(Vector3.ZERO,Vector3.ONE);check(events.size()==1,"Bullet fly-by emits no sound");bullet.free()
 check(absf(p.combat_audio.jump_gain-.2)<.001 and absf(p.combat_audio.landing_gain-.2)<.001,"Jump and landing gains default to 20%")
 check(ResourceLoader.exists("res://audio/music/menu_theme.ogg"),"New intense menu song is available")
 print("V15 SNIPER: %d checks, %d failures"%[checks,failures]);game.stop_game();game.queue_free();await process_frame;quit(1 if failures else 0)
