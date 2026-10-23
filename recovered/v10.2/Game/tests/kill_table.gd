extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.game_type=NestMatchPresets.create(1);game.mode=1;game.bot_fill=false;game.start_game();game.set_physics_process(false);game.tuning.score_limit=100000
 var a=game.player;a.set_physics_process(false)
 var v=NestActor.new();v.game=game;v.faction=1;v.net_id=44;game.add_child(v);game.actors.append(v);v.set_physics_process(false)
 var rows=[]
 for entry in NestWeaponCatalog.data().weapons:
  if entry.get("slot","") not in ["primary","secondary"]:continue
  var config=NestWeaponCatalog.definition(entry.id);var w=NestWeaponCatalog.profile(entry.id)
  var row={"id":entry.id,"name":config.title,"kind":config.kind,"damage":w.damage,"interval":w.interval,"burst":int(config.get("burst_count",1)),"burst_interval":float(config.get("burst_interval",.06)),"magazine":w.magazine,"reload":w.reload_seconds,"speed":w.speed,"range":config.get("falloff_start_m",0),"pellets":w.pellets}
  for character in [0,1]:
   v.set_character(character)
   for region in ["torso","head"]:
    v.alive=true;v.health=v.tuning.health_capacity;v.shield=v.tuning.shield_capacity if character==0 else 0;v.armor=v.tuning.armor_capacity;v.helmet_hp=float(v.traits.settings.annu_head_armor);v.overshield=0;v.action_state="ready";v.placement_retry_at=0;game.finished=false;game.break_until=0
    var rounds=0;var hits=0
    while v.alive and rounds<200:
     rounds+=1
     for pellet in range(w.pellets):
      if not v.alive:break
      hits+=1
      v.take_damage(float(config.damage_direct) if w.explosive else w.damage,region,"heavy" if w.explosive else "bullet",w.precision,a,game.next_event()*16,a.eye.global_position,w.kind,0)
    row[("naki_" if character==0 else "annu_")+region]={"shots":rounds,"hits":hits}
  rows.append(row)
 var file=FileAccess.open("/workspace/work/v6-range/table.json",FileAccess.WRITE);file.store_string(JSON.stringify(rows,"  "));file.close()
 game.stop_game();game.queue_free();await create_timer(.3).timeout;quit()
