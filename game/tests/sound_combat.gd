extends SceneTree
var game
var checks=0
var failures=0
var heard: Array[String]=[]
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	checks+=1
	if ok: print("PASS: "+message)
	else: failures+=1; push_error("FAIL: "+message)
func ticks(count=3):
	for i in range(count): await physics_frame
func reset_target(target):
	target.respawn(); target.set_physics_process(false); target.global_position=Vector3(80,25,70); target.update_visual(.016)
func equip(actor,kind):
	actor.weapons.assign([NestWeaponCatalog.profile(kind)]); actor.ammo.assign([actor.weapons[0].magazine]); actor.reserve.assign([actor.weapons[0].reserve]); actor.slot=0; actor.action_state="ready"; actor.action_until=0; actor.cooldown=0; actor.burst_left=0; actor.accuracy_penalty=0; actor.update_visual(.016)
func run():
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); await process_frame
	game.bot_fill=false; game.mode=2; game.fair_playing_field=false; game.starting_primary="default"; game.starting_secondary="default"; game.selected_faction=1; game.start_game(); game.clear_screen(); game.create_hud(); game.hud.visible=true
	await ticks(); game.set_physics_process(false)
	game.audio.sound_started.connect(func(id,_file,_voice): heard.append(id))
	var player=game.player; player.set_physics_process(false); player.global_position=Vector3(80,25,80); player.reset_physics_interpolation()
	var target=NestActor.new(); target.game=game; target.faction=0; game.add_child(target); game.actors.append(target); reset_target(target); await ticks()
	check(player.damage_model()=="annu" and target.damage_model()=="naki","Disabled Fair Playing Field preserves faction-specific protection")
	game.fair_playing_field=true; game.fair_health_type="naki"; player.respawn(); target.respawn()
	check(player.damage_model()=="naki" and target.damage_model()=="naki" and player.shield==100 and target.shield==100,"Enabled Naki setting gives both factions full shields")
	game.fair_health_type="annu"; player.respawn(); target.respawn()
	check(player.damage_model()=="annu" and target.damage_model()=="annu" and player.shield==0 and target.shield==0,"Enabled Annu setting removes base shields from both factions")
	check(player.armor==100 and target.armor==100 and player.helmet_hp==100,"Annu protection includes separate armor and helmet pools")
	game.mode=0
	check(player.damage_model()=="annu" and target.damage_model()=="naki","Extraction ignores Fair Playing Field and keeps faction rules")
	game.mode=2; game.fair_playing_field=false; reset_target(target)
	target.take_damage(1,"head","bullet",false,player,91001,Vector3.INF,"burst",0)
	check(target.shield==80 and target.health==100,"Battle rifle head hit has no bonus against full shields")
	reset_target(target); target.take_damage(1,"torso","bullet",false,player,91002,Vector3.INF,"burst",0)
	check(target.shield==80 and target.health==100,"Battle rifle body hit drains the same shield amount")
	game.now=target.last_damage+5.1; target._physics_process(.7) # v0.12: half the rate, same 3 s full refill
	check(target.shield==100,"Partially damaged shields recharge after the configured delay")
	reset_target(target)
	for i in range(5): target.take_damage(1,"torso","bullet",false,player,91100+i,Vector3.INF,"burst",0)
	check(target.shield==0 and target.health==100 and target.body_phase,"Five close battle-rifle hits enter body phase without bullet spillover (v0.12: 100 shields)")
	check(target.hit_stun_until>game.now,"Shield break starts the brief data-driven firing stun")
	game.now+=20; target._physics_process(.5)
	check(target.shield>0 and not target.body_phase,"Broken shields can recharge after the five-second delay")
	target.shield=0; target.body_phase=true
	for i in range(9): target.take_damage(1,"torso","bullet",false,player,91200+i,Vector3.INF,"burst",0)
	check(target.alive and target.health==10,"Nine battle-rifle body hits after shield break leave Naki alive")
	target.take_damage(1,"torso","bullet",false,player,91210,Vector3.INF,"burst",0)
	check(not target.alive,"Tenth battle-rifle body hit after shield break eliminates Naki")
	reset_target(target); target.shield=0; target.body_phase=true
	for i in range(5): target.take_damage(1,"arm","bullet",false,player,91220+i,Vector3.INF,"ak47",0)
	check(target.alive and is_equal_approx(target.health,100.0/6.0),"Five exposed AK limb hits leave Naki alive with one-third body damage")
	target.take_damage(1,"leg","bullet",false,player,91226,Vector3.INF,"ak47",0)
	check(not target.alive,"Sixth close AK body bullet eliminates shieldless Naki")
	for kind in ["burst","ak47"]:
		reset_target(target); target.shield=0; target.body_phase=true
		target.take_damage(1,"head","bullet",false,player,game.next_event(),Vector3.INF,kind,0)
		check(not target.alive,"Exposed "+kind+" headshot bypasses Naki body resistance")
	reset_target(target); target.shield=0; target.body_phase=true
	target.take_damage(30,"torso","explosion",false,player,game.next_event())
	check(target.health==70,"Naki body bullet resistance leaves explosion damage unchanged")
	game.fair_playing_field=true; game.fair_health_type="naki"; target.faction=1; reset_target(target); target.shield=0; target.body_phase=true
	game.mode=1; target.take_damage(1,"torso","bullet",false,player,game.next_event(),Vector3.INF,"burst",0)
	check(target.health==90,"Shared Naki health type receives body bullet resistance on an Annu character")
	game.fair_playing_field=false; game.mode=2; target.faction=0
	reset_target(target); target.shield=0; target.body_phase=true
	target.take_damage(1,"head","bullet",false,player,91301,Vector3.INF,"sidearm",0)
	check(not target.alive,"An exposed Naki headshot is instantly lethal even with a pistol")
	reset_target(target)
	check(not target.body_phase and target.shield==100,"Respawn restores a full shield cycle")
	target.take_damage(1,"head","bullet",true,player,91302,Vector3.INF,"sniper",0)
	check(not target.alive,"Sniper headshot kills through full Naki shields")
	reset_target(target); target.faction=1; game.mode=1; target.shield=0; target.overshield=100
	target.take_damage(1,"head","bullet",true,player,91303,Vector3.INF,"sniper",0)
	check(not target.alive,"Sniper headshot kills through Annu armor, helmet and overshield")
	target.faction=0; game.mode=2; reset_target(target)
	target.take_damage(1,"head","bullet",true,player,91304,Vector3.INF,"burst_scoped",0)
	check(target.alive and target.shield==80,"Scoped battle rifle does not gain sniper instant kills")
	target.faction=1; game.mode=1; reset_target(target)
	target.take_damage(1,"torso","bullet",false,player,91401,Vector3.INF,"sidearm",0)
	check(is_equal_approx(target.health,77.5) and is_equal_approx(target.armor,77.5),"Annu torso armor absorbs half of Magnum body damage")
	reset_target(target); target.take_damage(1,"head","bullet",false,player,91402,Vector3.INF,"sidearm",0)
	check(target.health==73 and target.helmet_hp==82 and target.armor==100,"Helmet absorption consumes helmet protection separately")
	reset_target(target); target.helmet_hp=0; target.take_damage(1,"head","bullet",false,player,91403,Vector3.INF,"sidearm",0)
	check(not target.alive,"Unhelmeted Annu headshot uses the weapon head multiplier")
	reset_target(target); game.mode=2; target.faction=1
	var friendly=target.take_damage(500,"head","bullet",true,player,91404,Vector3.INF,"sniper",0)
	check(not friendly and target.alive,"Friendly fire protection still blocks even sniper headshots")
	target.faction=0; reset_target(target)
	var br=NestWeaponCatalog.definition("battle_rifle"); var scoped=NestWeaponCatalog.definition("battle_rifle_scoped")
	check(br.damage_shield==scoped.damage_shield and br.damage_body==scoped.damage_body and br.burst_count==scoped.burst_count,"Scoped battle rifle inherits all damage and fire fields")
	check(scoped.max_effective_range_m==180 and br.max_effective_range_m==120,"Scoped rifle has only its specified extended range")
	check(is_equal_approx(game.weapon_falloff(br,20),1) and is_equal_approx(game.weapon_falloff(br,40),.75),"Falloff starts at full damage and interpolates linearly")
	check(is_equal_approx(game.weapon_falloff(br,120),.5) and game.weapon_falloff(br,121)==0,"Falloff minimum and hard maximum range are enforced")
	equip(player,"burst"); player.accuracy_penalty=0; player.velocity=Vector3.ZERO
	var spread=player.current_spread_degrees(); player.velocity=Vector3(5,3,1)
	check(is_equal_approx(spread,player.current_spread_degrees()),"Explicit no movement or jumping accuracy penalty is preserved")
	player.action_state="ready"; player.velocity=Vector3.ZERO; heard.clear(); game.now+=1
	player.fire_trigger()
	for i in range(3):
		await process_frame;await process_frame;game.now=player.burst_next+.001;player._physics_process(.001)
	check(player.ammo[0]==32 and player.burst_left==0,"One battle-rifle trigger fires exactly four rounds")
	check(heard.count("battle_rifle_fire_crack")==4 and heard.count("battle_rifle_fire_tail_open")==1,"Four-round burst has four cracks and one shared tail")
	await process_frame
	player.ammo[0]=0; player.cooldown=0; player.burst_left=0; player.action_state="ready"; heard.clear(); player.fire_trigger()
	check(heard.has("battle_rifle_dry_fire") and player.action_state=="ready","Empty trigger plays the weapon's dry click")
	equip(player,"ak47"); player.ammo[0]=20; heard.clear(); player.reload_weapon()
	for ratio in [.11,.69,.88]: game.now=player.action_until-player.reload_duration*(1-ratio); player.update_visual(.016)
	check(heard.has("ak47_reload_magout") and heard.has("ak47_reload_magin") and not heard.has("ak47_reload_chamber"),"Tactical reload uses separate animation-track cues without empty-only chamber")
	check(player.ammo[0]==20,"Magazine reload audio cannot grant early ammo")
	player.action_state="ready"; player.ammo[0]=0; heard.clear(); player.reload_weapon(); game.now=player.action_until-player.reload_duration*.1; player.update_visual(.016)
	check(heard.has("ak47_reload_chamber"),"Empty AK reload includes its chamber stage")
	player.switch_weapon(); check(player.action_state=="switching" and player.combat_audio.reload_key.is_empty(),"Weapon swap cancels an unfinished reload immediately")
	equip(player,"shotgun"); player.ammo[0]=3; var reserve=player.reserve[0]; heard.clear(); player.reload_weapon()
	var start=game.now
	for i in range(3): game.now=start+(.5+i)*.42+.01;player.advance_weapon_timers();player.update_visual(.016)
	check(player.ammo[0]==6 and player.reserve[0]==reserve-3,"Shotgun inserts exactly the missing shells")
	check(heard.count("shotgun_reload_shell_insert")==3,"Shotgun sound count equals the number of loaded shells")
	player.action_state="ready"; game.starting_primary="battle_rifle_scoped"; game.starting_secondary="magnum"; player.reset_loadout()
	check(player.weapons.size()==2 and player.weapons[0].kind=="burst_scoped" and player.weapons[1].kind=="sidearm","Custom starting primary and secondary are assigned in order")
	player.respawn(); check(player.weapons[0].kind=="burst_scoped" and player.ammo[0]==36,"Custom starting weapons return with full ammo on respawn")
	game.starting_primary="ak47"; game.starting_secondary="battle_rifle"; player.reset_loadout()
	check(player.weapons.size()==2 and player.weapons[1].kind=="burst","Secondary slot accepts another primary weapon")
	check(NestWeaponCatalog.choices("secondary").any(func(d): return d.id=="ak47"),"Lobby secondary choices include primary rifles")
	game.starting_secondary="ak47"; player.reset_loadout(); player.ammo[0]-=3
	check(player.weapons.size()==2 and player.weapons[0].kind=="ak47" and player.weapons[1].kind=="ak47" and player.ammo[1]==30,"Duplicate primary choices occupy separate slots with independent ammunition")
	game.starting_primary="none"; game.starting_secondary="none"; player.reset_loadout()
	check(player.weapons[0].kind=="none" and player.ammo[0]==0,"None / None creates a valid unarmed player")
	player.fire_trigger(); player.reload_weapon(); player.update_visual(.016)
	check(not player.weapon_view.visible,"Unarmed player shows no phantom gun")
	game.fair_playing_field=true; game.fair_health_type="annu"; game.save_custom_preset(); game.starting_primary="default"; game.fair_playing_field=false; game.load_custom_preset()
	check(game.starting_primary=="none" and game.fair_playing_field and game.fair_health_type=="annu","Starting weapon and Fair Playing Field choices persist in the custom preset")
	game.starting_primary="default"; game.starting_secondary="default"; game.fair_playing_field=false
	var files_exist=true; var formats=true
	for entry in game.audio.manifest.sounds.values():
		for path in entry.get("files",[]):
			if not ResourceLoader.exists(path): files_exist=false
			if not path.ends_with(".ogg"): formats=false
	check(files_exist and formats,"All declared recordings exist as imported Ogg assets")
	check(game.audio.reported_missing.is_empty(),"Gameplay cues use declared sound IDs")
	check(AudioServer.get_bus_effect_count(0)>0,"Master mix has a limiter for simultaneous combat")
	print("SOUND COMBAT: %d checks, %d failures"%[checks,failures])
	game.stop_game(); game.queue_free(); await create_timer(.75).timeout; quit(1 if failures else 0)
