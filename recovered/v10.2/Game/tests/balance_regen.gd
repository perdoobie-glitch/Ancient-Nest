extends SceneTree
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error(label)
func close(a: float,b: float) -> bool:return absf(a-b)<.002
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.game_type=NestMatchPresets.create(1);game.mode=1;game.bot_fill=false;game.start_game();game.set_physics_process(false);game.tuning.score_limit=100000
 var a=game.player;a.set_physics_process(false);a.set_character(0);a.refresh_traits();a.respawn()
 check(close(a.tuning.health_capacity,25) and close(a.tuning.shield_capacity,125),"Naki default 125 shields / 25 hidden health")
 game.now=100;a.last_damage=100;a.regen_anchor_damage=-INF;a.shield=25;a.health=5
 game.now=102.99;a.update_regeneration();check(close(a.shield,25) and close(a.health,5),"No regeneration before three seconds")
 game.now=103;a.update_regeneration();check(a.is_regenerating(),"Healing cue begins after three seconds")
 game.now=104.5;a.update_regeneration();check(close(a.shield,75) and close(a.health,15),"Shields and health recover together halfway through three-second refill")
 a.take_damage(10,"torso","bullet",false,null,game.next_event()*16,Vector3.ZERO,"unknown_test",0)
 check(close(a.shield,65) and close(a.health,15),"Hit removes damage from current partially recovered shield")
 game.now=107.49;a.update_regeneration();check(close(a.shield,65) and close(a.health,15),"Hit restarts the full three-second delay")
 game.now=109;a.update_regeneration();check(close(a.shield,95) and close(a.health,20),"Interrupted healing restarts from current shield and health")
 game.now=110.5;a.update_regeneration();check(close(a.shield,125) and close(a.health,25) and not a.is_regenerating(),"Both resources fully recover after three seconds")
 a.set_character(1);a.refresh_traits();a.respawn();check(close(a.health,100) and close(a.armor,100) and close(a.shield,0),"Annu defaults to 100 health / 100 armor / no energy shield")
 a.health=50;game.now+=30;a.update_regeneration();check(close(a.health,50) and not a.traits.health_regeneration,"Annu remains nonregenerating")
 check(not NestWeaponCatalog.data().weapons.any(func(w):return w.id=="battle_rifle"),"Unscoped BR removed from selectable catalog")
 check(NestWeaponCatalog.profile("battle_rifle").kind=="burst_scoped","Old saved BR loadouts migrate to scoped BR")
 var br=NestWeaponCatalog.profile("battle_rifle_scoped");var plasma=NestWeaponCatalog.profile("plasma_br");var ak=NestWeaponCatalog.profile("ak47")
 check(close(br.damage,28) and close(br.interval,.578/.6*.5),"Scoped BR rebalance damage / preserved burst cadence")
 check(int(NestWeaponCatalog.for_kind("plasma_br").burst_count)==5 and close(plasma.speed,1000),"Plasma five-round burst preserved with fast projectiles")
 check(close(ak.interval,.1),"AK restored to original 600 RPM")
 check(close(NestWeaponCatalog.profile("assault_rifle").damage,NestWeaponCatalog.profile("plasma_auto").damage),"Plasma / ballistic assault rifles share damage")
 check(NestWeaponCatalog.profile("assault_rifle").interval!=NestWeaponCatalog.profile("plasma_auto").interval,"Assault rifles retain different firing rates")
 check(NestMigrationState.ACTOR_FIELDS.has("regen_start_shield"),"Migration retains partial-regeneration state")
 game.stop_game();game.queue_free();await create_timer(.3).timeout;print("BALANCE REGEN: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
