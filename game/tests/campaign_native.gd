extends SceneTree
var game
var folder=""
var index=0
var port=17779
var sequence=0
var result={}
var isolate_interactions=false
var last_status=""
func _initialize():call_deferred("run")
func run():
 var args=OS.get_cmdline_user_args();folder=args[0];index=int(args[1]);port=int(args[2])
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.sandbox_mode=true;Engine.max_fps=60
 game.campaign.save_store.path="user://qa-campaign.json"
 while true:
  await create_timer(.1).timeout
  var c=game.campaign;var command_file=folder+"/command-"+str(index)+".json"
  if FileAccess.file_exists(command_file):
   var command=JSON.parse_string(FileAccess.get_file_as_string(command_file))
   if command is Dictionary and int(command.get("sequence",0))>sequence:
    sequence=int(command.sequence)
    match str(command.action):
     "host":c.selected_difficulty="Hard";c.open_coop(true,"",port)
     "join":c.open_coop(false,"127.0.0.1",port)
     "ready":c.send_action("ready",{})
     "start":c.start_expedition()
     "select_mission":c.selected_mission=int(command.get("mission",2))
     "isolate_interactions":isolate_interactions=true
     "chapter":c.journey.start_standalone(int(command.get("mission",3)))
     "at_objective":
      var hero=game.actor_by_id(int(command.get("slot",1)))
      hero.global_position=c.world.locations["objective"+str(c.state.chapter_stage)]+Vector3(0,.25,2)
      hero.controlled=Vector3.ZERO;hero.external=Vector3.ZERO
     "at_cache":
      var cache_key=str(command.get("cache_key",""));var cache_index=int(cache_key.get_slice(":",1));var points=c.world.weapon_cache_points();var hero=game.actor_by_id(int(command.get("slot",2)))
      if hero!=null and cache_index>=0 and cache_index<points.size():
       hero.global_position=points[cache_index]+Vector3(0,.25,1.5);hero.controlled=Vector3.ZERO;hero.external=Vector3.ZERO
     "chapter_clear":
      for enemy in game.actors.duplicate():
       if enemy.faction==1:enemy.die(game.actor_by_id(1),"qa")
      c.tick(0);c.broadcast()
     "skip":c.send_action("skip",{})
     "flashlight":c.send_action("flashlight",{})
     "move":Input.action_press("forward")
     "stop_move":Input.action_release("forward")
     "duck":Input.action_press("crouch")
     "stop_duck":Input.action_release("crouch")
     "fire":Input.action_press("fire")
     "stop_fire":Input.action_release("fire")
     "practice_one":
      c.state.practice["1"]={}
      for key in NestCampaign.PRACTICE:c.state.practice["1"][key]=true
      c.broadcast()
     "practice_all":
      for slot in c.members:
       c.state.practice[str(slot)]={}
       for key in NestCampaign.PRACTICE:c.state.practice[str(slot)][key]=true
      c.tick(0)
     "board_all":
      for slot in c.members:c.state.practice[str(slot)].manifest=true;c.state.practice[str(slot)].boarded=true
      c.tick(0)
     "down":c.down(game.actor_by_id(int(command.get("slot",2))))
     "revive":
      var target=game.actor_by_id(int(command.get("slot",2)));var helper=game.actor_by_id(1);helper.global_position=target.global_position+Vector3(1,0,0);result.revived=c.revive(helper,target.net_id);c.broadcast()
     "charge":
      var actor=game.actor_by_id(1);actor.global_position=c.world.locations["charge"+str(c.state.charge_site)]+Vector3(0,0,2);await physics_frame;var choice=c.interaction(actor);result.charge=c.interact(actor,choice);result.duplicate_charge=c.interact(actor,choice);c.broadcast()
     "secure":
      var actor=game.actor_by_id(1);actor.global_position=c.world.locations.secure+Vector3(0,0,2);await physics_frame;result.secure=c.interact(actor,c.interaction(actor));c.broadcast()
     "drop_bot":
      var enemy=c.make_actor(-9900,false,0,"Loot QA",c.world.locations.exit+Vector3(0,.3,13));enemy.ammo[0]=17;enemy.reserve[0]=40;enemy.die(game.actor_by_id(1),"qa");game.actors.erase(enemy);enemy.queue_free();c.broadcast()
     "place_at_loot":
      if not c.loot.drops.is_empty():
       var drop=c.loot.drops.values()[0];var point=drop.pickup_point();game.actor_by_id(int(command.get("slot",2))).global_position=Vector3(point.x,.25,point.z+1.5);c.broadcast()
     "pickup_hold":Input.action_press("interact")
     "stop_interact":Input.action_release("interact")
     "wave":
       game.actor_by_id(1).global_position=c.world.maze.checkpoints[clampi(c.state.completed_waves,0,4)];c.tick(0)
     "finish_wave":
      var wave=c.state.wave_index()
      if wave>=0:
       for n in range(NestCampaignState.COUNTS[wave]):
        var id=-1000-wave*100-n;var enemy=game.actor_by_id(id)
        if enemy==null and c.state.register_enemy(id):enemy=c.make_actor(id,false,0,"QA Defender")
        if enemy!=null:enemy.die(game.actor_by_id(1),"qa");c.update_wave()
     "radio":
      var actor=game.actor_by_id(1);actor.global_position=c.world.locations.radio+Vector3(0,0,2);await physics_frame;result.radio=c.interact(actor,c.interaction(actor));c.broadcast()
     "disconnect":c.exit_campaign()
     "retry":c.retry_checkpoint()
     "wipe":
      for slot in c.connected_slots():c.down(game.actor_by_id(slot))
      c.tick(0)
     "quit":
      c.exit_campaign();game.queue_free()
      for i in range(4):await process_frame
      quit();return
  if isolate_interactions and not game.is_client():
   for actor in game.actors:
    if actor.faction==1:actor.set_physics_process(false)
  var state={"sequence":sequence,"active":c.active,"phase":c.state.phase,"difficulty":c.state.difficulty,"slot":c.local_slot,"members":c.members.size(),"connected":c.connected_slots().size(),"loaded":c.all_loaded(),"running":game.running,"context":game.context,"actors":game.actors.size(),"practice":c.state.practice,"waves":c.state.completed_waves,"kills":c.state.defeated.size(),"bomb":c.state.bomb,"epoch":c.phase_epoch,"elapsed":c.phase_elapsed,"result":result,"flashlights":c.flashlights,"downed":c.downed.size(),"completion":c.state.completion_count,"input_packets":game.net_stats.get("input_payload_bytes_received",0),"snapshots":game.net_stats.get("snapshots_completed",0),"errors":c.notice,"loot_count":c.loot.drops.size()}
  state["mission"]=c.state.mission_index;state["chapter_stage"]=c.state.chapter_stage
  state["valid_state"]=NestCampaignState.valid(c.state.pack());state["load_deadline"]=c.load_deadline;state["wall_clock"]=game.local_clock()
  var status=str([c.state.phase,c.phase_epoch,c.connected_slots().size(),c.all_loaded(),state.valid_state])
  if status!=last_status:print("NATIVE_STATE ",index," ",Time.get_ticks_msec()," ",status);last_status=status
  if c.state.mission_index>1:state["journey"]=c.journey.pack()
  state["weapon_caches"]=c.state.weapon_caches.duplicate(true);var cache_records=[]
  for body in c.loot.drops.values():
   if is_instance_valid(body) and not body.cache_key.is_empty():cache_records.append({"id":body.drop_id,"cache_key":body.cache_key,"kind":body.kind,"claimed":body.claimed_by,"weapon_slot":1 if NestWeaponCatalog.for_kind(body.kind).get("slot","")=="secondary" else 0})
  state["cache_drops"]=cache_records
  if game.player!=null:state["alive"]=game.player.alive;state["ammo"]=game.player.ammo;state["weapon_kinds"]=game.player.weapons.map(func(weapon):return weapon.kind);state["camera"]=game.get_viewport().get_camera_3d()==game.player.camera
  var positions={};var acknowledgements={};var crouched={}
  for actor in game.actors:
   if actor.faction==0:positions[str(actor.net_id)]=[actor.global_position.x,actor.global_position.y,actor.global_position.z];acknowledgements[str(actor.net_id)]=actor.cmd_last_seq
  for actor in game.actors:
   if actor.faction==0:crouched[str(actor.net_id)]=actor.crouched
  state["crouched"]=crouched
  state["positions"]=positions;state["acknowledgements"]=acknowledgements
  var output=FileAccess.open(folder+"/state-"+str(index)+".json",FileAccess.WRITE);output.store_string(JSON.stringify(state));output.close()
