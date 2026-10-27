extends SceneTree
# Real pickup/save lifecycle regression. Run only through the isolated campaign runner.
var game
var failures=0
var checks=0
func check(ok: bool,message: String):
 checks+=1;print(("PASS " if ok else "FAIL ")+message)
 if not ok:failures+=1
func _initialize():call_deferred("run")
func frames(count=2):
 for i in range(count):await physics_frame
func caches(c) -> Array:
 var result=[]
 for body in c.loot.drops.values():
  if is_instance_valid(body) and not body.cache_key.is_empty():result.append(body)
 return result
func freeze_actors():
 for actor in game.actors:actor.set_physics_process(false)
func cache_for(c,key: String):
 for body in caches(c):
  if body.cache_key==key and body.claimed_by==0:return body
 return null
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames();game.sandbox_mode=true
 var c=game.campaign;c.save_store.path="user://cache-qa-"+Crypto.new().generate_random_bytes(6).hex_encode()+".json";c.selected_difficulty="Easy";c.begin_solo(false);c.journey.start_standalone(3);c.journey.finish_cinematic()
 game.set_physics_process(false);c.set_process(false);c.journey.tick(0);freeze_actors();game.input_window_focused=true
 var anchors=c.world.weapon_cache_points();var bodies=caches(c)
 check(not anchors.is_empty() and bodies.size()==anchors.size(),"Every authored cache anchor receives one physical gun")
 check(c.state.weapon_caches.size()==anchors.size(),"Host records one chosen existing weapon for each anchor")
 var signatures=c.state.weapon_caches.duplicate(true)
 var kinds={}
 for record in signatures.values():kinds[record.kind]=true
 check(kinds.size()==signatures.size(),"Shuffled cache bag gives distinct guns across this mission's anchors")
 var legacy=JSON.parse_string(JSON.stringify(c.state.pack()));legacy.version=2;legacy.erase("weapon_caches");var migrated=NestCampaignState.new()
 check(NestCampaignState.valid(legacy) and migrated.restore(legacy) and migrated.weapon_caches.is_empty(),"Version 2 chapter save without cache ledger remains compatible")
 var malformed=c.state.pack();malformed.weapon_caches[signatures.keys()[0]].kind="invented_gun"
 check(not NestCampaignState.valid(malformed),"Unknown cache weapon kind is rejected on restore")
 malformed=c.state.pack();malformed.weapon_caches[signatures.keys()[0]].claimed_by=5
 check(not NestCampaignState.valid(malformed),"Cache claim outside the four existing seats is rejected")
 malformed=c.state.pack();malformed.weapon_caches[signatures.keys()[0]].claimed_by=1.5
 check(not NestCampaignState.valid(malformed),"Fractional cache claimant cannot enter saved state")
 var first=bodies[0];var key=first.cache_key;var kind=first.kind;var id=first.drop_id;var initial_y=first.global_position.y
 check(first is RigidBody3D and id>=100000 and key.begins_with("3:"),"Cache uses physical drop and chapter-specific stable identity")
 for body in bodies:check(NestWeaponCatalog.for_kind(body.kind).get("slot","") in ["primary","secondary"],"Cache choice is an existing firearm: "+body.kind)
 for i in range(120):await physics_frame
 check(first.global_position.y<=initial_y+.05 and first.linear_velocity.length()<.6,"Physical cache gun remains supported and settles at its authored location")
 game.player.global_position=Vector3(500,.25,500)
 check(not c.loot.take(game.player,id),"Distant player cannot claim cache")
 c.loot.ensure_weapon_caches()
 check(c.state.weapon_caches==signatures and caches(c).size()==anchors.size(),"Repeated cache creation neither rerolls choices nor duplicates guns")
 var packet=c.loot.pack();var replicated=false
 for record in packet:
  if int(record.id)==id:replicated=record.kind==kind and record.get("cache_key","")==key
 check(replicated,"Replicated physical drop includes exact selected weapon and persistent cache key")
 var actor=game.player;var slot=1 if NestWeaponCatalog.for_kind(kind).get("slot","")=="secondary" else 0
 var other_kind=actor.weapons[1-slot].kind;var old_health=float(c.checkpoint.equipment["1"].health);var old_shield=float(c.checkpoint.equipment["1"].shield)
 var anchor: Vector3=anchors[int(key.get_slice(":",1))];actor.global_position=anchor+Vector3(0,.25,1.5);actor.health=23;actor.shield=11;await frames()
 var choice=c.interaction(actor)
 check(choice.get("key","")=="campaign:loot:"+str(id),"Grounded cache exposes the ordinary nearby pickup interaction")
 check(c.interact(actor,choice),"Physical cache can be picked up through campaign interaction")
 check(actor.weapons[slot].kind==kind and actor.weapons[1-slot].kind==other_kind and actor.weapons[2].kind=="plasma_sword","Cache equips the chosen gun without replacing other weapon slots")
 check(int(c.state.weapon_caches[key].claimed_by)==1 and not c.loot.take(actor,id),"Cache claim is recorded exactly once")
 var persisted=c.save_store.load_checkpoint()
 check(not persisted.is_empty() and int(persisted.weapon_caches[key].claimed_by)==1,"Mid-encounter pickup persists consumption to the safe checkpoint")
 check(persisted.equipment["1"].weapons[slot]==kind and float(persisted.equipment["1"].health)==old_health and float(persisted.equipment["1"].shield)==old_shield,"Durable pickup preserves gun and prior checkpoint health/shield")
 check(persisted.chapter_spawned.is_empty() and persisted.chapter_enemies.is_empty() and c.state.chapter_enemies.size()>0,"Durable pickup keeps encounter replay semantics while live enemies remain")
 var unclaimed=bodies[1] if bodies.size()>1 else null
 game.now+=NestCampaignLoot.LIFETIME+1;c.loot._process(0)
 check(unclaimed!=null and c.loot.drops.has(unclaimed.drop_id),"Unclaimed authored caches do not expire with corpse loot")
 var corpse_source=c.make_actor(-99001,false,0,"Loot fixture",Vector3(0,.25,26));corpse_source.set_physics_process(false)
 for life in range(NestCampaignLoot.LIMIT+3):
  corpse_source.life_id=life;c.loot.release(corpse_source)
 check(unclaimed!=null and c.loot.drops.has(unclaimed.drop_id),"Corpse-drop pressure cannot evict authored gun caches")
 c.set_phase("DEFEAT");c.retry_checkpoint();freeze_actors();await frames()
 check(c.state.chapter_stage==0 and game.player.weapons[slot].kind==kind and int(c.state.weapon_caches[key].claimed_by)==1,"Retry restores acquired weapon and consumed cache ledger")
 check(cache_for(c,key)==null and caches(c).size()==anchors.size()-1,"Retry does not respawn already consumed cache")
 c.journey.tick(0);freeze_actors()
 for enemy_id in c.state.chapter_enemies.keys():game.actor_by_id(enemy_id).die(game.player,"cache-fixture")
 c.journey.tick(0)
 actor=game.player;actor.global_position=c.world.locations.objective0+Vector3(0,.25,2);await frames()
 check(c.journey.interact(actor,"journey:objective") and c.state.chapter_stage==1,"Real encounter clear and objective advance to next stage")
 freeze_actors();check(int(c.state.weapon_caches[key].claimed_by)==1 and cache_for(c,key)==null,"Stage advance preserves consumed cache and original choices")
 var remaining={}
 for cache_key in c.state.weapon_caches:remaining[cache_key]=c.state.weapon_caches[cache_key].kind
 c.exit_campaign();await frames();c.begin_solo(true);game.set_physics_process(false);c.set_process(false);freeze_actors();await frames()
 check(c.state.mission_index==3 and c.state.chapter_stage==1 and game.player.weapons[slot].kind==kind,"Initial Continue preserves acquired gun and latest safe stage")
 var restored_choices={}
 for cache_key in c.state.weapon_caches:restored_choices[cache_key]=c.state.weapon_caches[cache_key].kind
 check(restored_choices==remaining and cache_for(c,key)==null,"Save/Continue preserves selections without consumed-cache duplication")
 c.journey.start_standalone(4);freeze_actors();await frames()
 var only_current=true
 for body in caches(c):
  if not body.cache_key.begins_with("4:"):only_current=false
 for cache_key in c.state.weapon_caches:
  if not str(cache_key).begins_with("4:"):only_current=false
 check(only_current and not c.loot.drops.has(id),"New chapter removes previous chapter cache bodies and identities")
 check(not c.loot.take(game.player,id),"Stale previous-chapter pickup ID cannot claim a new gun")
 c.exit_campaign();game.queue_free();await frames()
 print("CAMPAIGN WEAPON CACHES: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
