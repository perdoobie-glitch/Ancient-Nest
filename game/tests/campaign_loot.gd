extends SceneTree
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 print(("PASS " if ok else "FAIL ")+message)
 if not ok:failures+=1
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.sandbox_mode=true
 var c=game.campaign;c.save_store.path="user://loot-qa.json";c.begin_solo(false);c.state.phase="CRASH";c.set_world("forest");c.rebuild_heroes();c.set_phase("CRASH_ORIENTATION");c.state.phase="WAVE_1"
 game.set_physics_process(false);c.set_process(false);game.player.set_physics_process(false)
 var enemy=c.make_actor(-1000,false,0,"Loot fixture",Vector3(0,.25,40));enemy.set_physics_process(false);enemy.ammo[0]=17;enemy.reserve[0]=40;enemy.slot=0
 enemy.die(game.player,"bullet");check(c.loot.drops.size()==1,"Actual campaign bot death releases its held weapon")
 c.loot.release(enemy);check(c.loot.drops.size()==1,"Duplicate death/release cannot duplicate loot")
 var body: NestCampaignDrop=c.loot.drops.values()[0];var height=body.global_position.y;var initial=body.global_basis
 check(body is RigidBody3D and body.angular_velocity.length()>1 and body.kind=="ak47","Dropped AK-47 is a tumbling physical weapon")
 for i in range(180):game.now+=1./60.;await physics_frame
 check(body.global_position.y<height-.3 and body.linear_velocity.length()<.5,"Weapon falls under gravity, collides with the floor and settles")
 check(not body.global_basis.is_equal_approx(initial),"Release animation includes actual physical rotation")
 check(not c.loot.take(game.player,body.drop_id),"Distant players cannot claim dropped guns")
 var p=body.pickup_point();game.player.global_position=Vector3(p.x,.25,p.z+1.5);await physics_frame
 var choice=c.interaction(game.player);check(choice.get("key","").begins_with("campaign:loot:"),"Nearby dropped gun exposes an interaction prompt")
 check(c.interact(game.player,choice),"Player can pick up the dropped weapon")
 check(game.player.weapons[0].kind=="ak47" and game.player.ammo[0]==17 and game.player.reserve[0]==40 and game.player.weapons[2].kind=="plasma_sword","Pickup preserves the bot's ammo and the player's sidearm/blade slots")
 check(not c.loot.take(game.player,body.drop_id) and body.claimed_by==1,"A shared drop can be claimed only once")
 for i in range(18):game.now+=1./60.;await physics_frame
 check(body.visual.scale.length()<.2,"Claimed weapon animates into the hand and shrinks away")
 c.state.phase="CRASH_ORIENTATION";c.state.completed_waves=0;c.checkpoint_now()
 check(not c.save_store.read_valid(c.save_store.path).is_empty(),"Looted Annu weapon survives safe checkpoint JSON readback")
 check(is_equal_approx(c.world.station_signs.radio.pixel_size,.0055) and is_equal_approx(c.world.station_signs.radio.modulate.a,.75),"Floating world labels are half size with 75-percent opacity")
 var carbine=NestWeaponCatalog.profile("plasma_br");check(carbine.speed==2000,"Plasma carbine projectile speed is doubled from 1000 to 2000")
 var bullet=load("res://scripts/bullet.gd").new();bullet.game=game;bullet.owner_actor=game.player;bullet.profile=carbine;bullet.direction=Vector3.FORWARD;bullet.round_id=game.round_number;bullet.cosmetic=true;game.add_child(bullet);bullet.global_position=Vector3(500,50,500);bullet.set_physics_process(false);bullet._physics_process(1./60.)
 check(absf(bullet.traveled-2000./60.)<.001,"Actual carbine projectile travels twice the former distance per physics tick")
 bullet.queue_free()
 var wall=StaticBody3D.new();var wall_shape=CollisionShape3D.new();var wall_box=BoxShape3D.new();wall_box.size=Vector3(4,4,.2);wall_shape.shape=wall_box;wall.add_child(wall_shape);game.add_child(wall);wall.position=Vector3(500,50,480);await physics_frame
 var fast=load("res://scripts/bullet.gd").new();fast.game=game;fast.owner_actor=game.player;fast.profile=carbine;fast.direction=Vector3.FORWARD;fast.round_id=game.round_number;fast.cosmetic=true;game.add_child(fast);fast.global_position=Vector3(500,50,500);fast.set_physics_process(false);fast._physics_process(1./60.)
 check(fast.is_queued_for_deletion() and absf(fast.hit_position.z-480.1)<.2,"Doubled-speed carbine still hits cover through a swept collision test")
 wall.queue_free();c.exit_campaign();check(c.loot.drops.is_empty(),"Campaign exit clears physical loot")
 game.queue_free();await process_frame;quit(1 if failures else 0)
