extends SceneTree
# Impaired-network netcode test. Run host and client as separate processes,
# usually with authoring/udp_impair.py between them (see netcode_matrix.py):
#   godot --headless -s tests/network_netcode.gd -- host <host_port> <host_port> <out.json> <label>
#   godot --headless -s tests/network_netcode.gd -- client <host_port> <relay_port> <out.json> <label>
# Phases: A client movement prediction/reconciliation and jumps; B remote
# interpolation against host ground truth; C moving-target hits with lag
# compensation on and off; E rewind bound; D full-auto cadence.
class Gate:
	extends Node
	var marks={}
	@rpc("any_peer","call_remote","reliable")
	func mark(key: String, value: Variant=true): marks[key]=value
var game
var gate: Gate
var role=""
var checks=0
var failures=0
var results={}
var out_path=""
const PLATFORM=Vector3(400,100,400)
const CLIENT_A=Vector3(15,.05,8)
const CLIENT_SPOT=Vector3(0,.05,8)
const HOST_SPOT=Vector3(0,.05,-8)
const SHOTS_PER_MODE=24
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	checks+=1
	results["checks_detail"].append({"ok":ok,"message":message})
	if ok: print("PASS "+role+": "+message)
	else: failures+=1; push_error("FAIL "+role+": "+message)
func phase(name: String, timeout_ms: int=30000) -> bool:
	var until=Time.get_ticks_msec()+timeout_ms
	while not gate.marks.has(name) and Time.get_ticks_msec()<until and game.network_active: await process_frame
	return gate.marks.has(name)
func stat(key: String) -> float:
	return float(game.net_stats.get(key,0.0))
func add_platform():
	var body=StaticBody3D.new(); body.collision_layer=1; body.collision_mask=0
	var shape=CollisionShape3D.new(); var box=BoxShape3D.new(); box.size=Vector3(80,1,80); shape.shape=box; body.add_child(shape)
	game.add_child(body); body.global_position=PLATFORM-Vector3(0,.5,0)
func zero_spread(actor: NestActor):
	for i in range(actor.weapons.size()):
		actor.weapons[i]=actor.weapons[i].duplicate(); actor.weapons[i].spread_degrees=0
func place(actor: NestActor, offset: Vector3, yaw: float):
	actor.global_position=PLATFORM+offset; actor.rotation.y=yaw; actor.controlled=Vector3.ZERO; actor.external=Vector3.ZERO; actor.velocity=Vector3.ZERO; actor.reset_physics_interpolation()
func release_all():
	for action in ["left","right","forward","backward","jump","crouch","fire"]: Input.action_release(action)
func run():
	var args=OS.get_cmdline_user_args()
	role=args[0]; var host_port=int(args[1]); var connect_port=int(args[2]); out_path=args[3]
	results={"label":args[4] if args.size()>4 else "","role":role,"checks_detail":[]}
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.lobby_network.set_process(false);game.lobby_network=null; await process_frame
	game.bot_fill=false; game.team_size=1; game.mode=2; game.fair_playing_field=false
	game.starting_primary="magnum"; game.starting_secondary="assault_rifle"
	gate=Gate.new(); gate.name="NetcodeGate"; game.add_child(gate)
	add_platform()
	var error=game.host_direct(host_port,"NetHost",0) if role=="host" else game.join_direct("127.0.0.1",connect_port,"NetClient",1)
	check(error==OK,"Direct session opens")
	var until=Time.get_ticks_msec()+30000
	while game.lobby_members.size()!=2 and Time.get_ticks_msec()<until: await process_frame
	check(game.lobby_members.size()==2,"Both peers join through the impaired link")
	if game.lobby_members.size()==2:
		if role=="host": await host_run()
		else: await client_run()
	results["checks"]=checks; results["failures"]=failures; results["stats"]=game.net_stats.duplicate()
	var file=FileAccess.open(out_path,FileAccess.WRITE); file.store_string(JSON.stringify(results)); file.close()
	print("NETCODE "+role+": %d checks, %d failures"%[checks,failures])
	release_all(); game.stop_game(); game.close_connection(); game.queue_free(); await create_timer(.4).timeout; quit(1 if failures else 0)
# ---------------------------------------------------------------- host
func host_run():
	game.start_game(); game.context="playing"
	await physics_frame
	var me: NestActor=game.player
	var remote: NestActor=game.actors.filter(func(a): return a.remote_peer>1)[0]
	var peer=remote.remote_peer
	place(me,HOST_SPOT,PI); place(remote,CLIENT_A,0.0)
	zero_spread(remote); zero_spread(me)
	gate.mark.rpc_id(peer,"placed")
	# A: movement prediction. Count jumps the host actually performs.
	if not await phase("A_start"): check(false,"Client starts movement phase"); return
	if not await phase("A_done",40000): check(false,"Client finishes movement phase"); return
	var report: Dictionary=gate.marks["A_done"]
	# Count by command sequence, not by when the reliable phase marks arrived.
	var host_jumps=remote.host_jump_seqs.filter(func(seq): return seq>=int(report.first_seq) and seq<=int(report.last_seq)).size()
	results["A"]={"client_jumps":report.jumps,"host_jumps":host_jumps,"final_error_m":remote.global_position.distance_to(report.pos)}
	check(host_jumps==int(report.jumps) and int(report.jumps)>=3,"Every client-predicted jump is performed once by the host (%d client / %d host)"%[report.jumps,host_jumps])
	check(remote.global_position.distance_to(report.pos)<.03,"Client prediction converges to the host state after input stops (%.4f m)"%remote.global_position.distance_to(report.pos))
	# A2: disturbances the client cannot predict: host knockback, then a
	# client command stall during which the client changes direction.
	place(remote,CLIENT_A,0.0)
	gate.mark.rpc_id(peer,"A2_ready")
	if not await phase("A2_moving"): check(false,"Client starts disturbance phase"); return
	var fillers0=stat("filler_commands")
	await create_timer(.4).timeout
	# A full-strength blast push using the game's own impulse rules, aimed
	# toward the platform centre and away from the host player.
	var push=Vector3(-.7071,0,.7071)*float(game.damage_rules.blast_impulse)+Vector3.UP*float(game.damage_rules.blast_up_impulse)
	remote.external=(remote.external+push).limit_length(float(game.damage_rules.max_blast_impulse))
	if not await phase("A2_done",30000): check(false,"Client finishes disturbance phase"); return
	var report2: Dictionary=gate.marks["A2_done"]
	results["A2"]={"filler_commands":int(stat("filler_commands")-fillers0),"final_error_m":remote.global_position.distance_to(report2.pos)}
	check(stat("filler_commands")-fillers0>=1,"Host keeps simulating a stalled client with stand-in commands")
	check(remote.global_position.distance_to(report2.pos)<.03,"Client converges after unpredicted knockback and a command stall (%.4f m)"%remote.global_position.distance_to(report2.pos))
	# L: ride the time-driven lift. The client runs the lift on the host's
	# timeline shifted by its prediction offset, so riding should predict.
	var lift=game.lift_node()
	lift.clock=0.0
	var lift_top=Vector3(lift.shaft_position.x,0.12,lift.shaft_position.y)
	remote.global_position=lift_top; remote.controlled=Vector3.ZERO; remote.external=Vector3.ZERO; remote.reset_physics_interpolation()
	var two0=stat("host_ticks_with_2_commands"); var three0=stat("host_ticks_with_3_commands"); var one0=stat("host_ticks_with_1_commands"); var zero0=stat("host_ticks_with_0_commands")
	gate.mark.rpc_id(peer,"L_ready",lift_top)
	if not await phase("L_done",40000): check(false,"Client finishes lift ride"); return
	var report_l: Dictionary=gate.marks["L_done"]
	results["L"]={"final_error_m":remote.global_position.distance_to(report_l.pos),"host_y":remote.global_position.y,"client_y":report_l.pos.y,
		"host_ticks_0":int(stat("host_ticks_with_0_commands")-zero0),"host_ticks_1":int(stat("host_ticks_with_1_commands")-one0),"host_ticks_2":int(stat("host_ticks_with_2_commands")-two0),"host_ticks_3plus":int(stat("host_ticks_with_3_commands")-three0)}
	check(remote.global_position.y>7 and report_l.pos.y>7,"Client and host both carry the rider to the top floor")
	check(remote.global_position.distance_to(report_l.pos)<.03,"Lift rider converges with the host at the top (%.4f m)"%remote.global_position.distance_to(report_l.pos))
	# B: the host's own player moves; the client renders it. Record truth.
	place(remote,CLIENT_SPOT,0.0); place(me,HOST_SPOT,PI)
	gate.mark.rpc_id(peer,"B_ready")
	if not await phase("B_go"): check(false,"Client ready to observe"); return
	var truth=[]
	var start=Time.get_ticks_msec()
	var schedule=[["left",.7],["right",.7],["left",.5],["forward",.4],["right",.9],["backward",.4],["left",.6]]
	var index=0; var segment_start=start
	Input.action_press(schedule[0][0])
	while index<schedule.size():
		await physics_frame
		truth.append([game.now,me.global_position.x,me.global_position.y,me.global_position.z])
		if Time.get_ticks_msec()-segment_start>=schedule[index][1]*1000:
			Input.action_release(schedule[index][0]); index+=1; segment_start=Time.get_ticks_msec()
			if index<schedule.size(): Input.action_press(schedule[index][0])
			if index==3: Input.action_press("jump")
			if index==4: Input.action_release("jump")
	release_all()
	# Keep logging past the end so the client's delayed view stays covered.
	for i in range(40):
		await physics_frame
		truth.append([game.now,me.global_position.x,me.global_position.y,me.global_position.z])
	results["B_truth"]=truth
	gate.mark.rpc_id(peer,"B_end")
	# C: strafing target, client shoots. Lag compensation on, then off.
	results["C"]={}
	for comp in [true,false]:
		place(me,HOST_SPOT,PI)
		game.lag_compensation_enabled=comp
		var fx0=me.damage_fx_seq; var accepted0=stat("shots_accepted"); var rewinds0=stat("rewinds"); var rewind_ms0=stat("rewind_ms_sum")
		gate.mark.rpc_id(peer,"C_go_"+str(comp))
		var direction="left"; var switch_at=Time.get_ticks_msec()+600
		Input.action_press(direction)
		while not gate.marks.has("C_end_"+str(comp)) and game.network_active:
			await physics_frame
			# Fixture: keep the target alive and the shooter supplied.
			me.shield=me.tuning.shield_capacity; me.health=me.tuning.health_capacity; me.overshield=0
			remote.ammo[0]=remote.weapons[0].magazine; remote.reserve[0]=60
			if Time.get_ticks_msec()>=switch_at:
				Input.action_release(direction); direction="right" if direction=="left" else "left"; Input.action_press(direction); switch_at=Time.get_ticks_msec()+600
		release_all()
		var fired=int(gate.marks.get("C_end_"+str(comp),0))
		var hits=me.damage_fx_seq-fx0
		var accepted=int(stat("shots_accepted")-accepted0)
		var rewinds=int(stat("rewinds")-rewinds0)
		results["C"][str(comp)]={"fired":fired,"accepted":accepted,"hits":hits,"rewinds":rewinds,"mean_rewind_ms":(stat("rewind_ms_sum")-rewind_ms0)/maxf(1,rewinds)}
		check(accepted==fired,"Host accepts every client magnum shot with compensation %s (%d/%d)"%["on" if comp else "off",accepted,fired])
		if comp: check(hits>=int(ceil(fired*.9)),"Lag-compensated shots at the displayed strafing target hit (%d/%d)"%[hits,fired])
		await create_timer(.3).timeout
	game.lag_compensation_enabled=true
	# E: a forged, very old view time is clamped to the rewind bound.
	var clamped0=stat("shot_time_hints_ignored")
	gate.mark.rpc_id(peer,"E_go")
	if not await phase("E_done"): check(false,"Client sends forged view time"); return
	await create_timer(.4).timeout
	check(stat("shot_time_hints_ignored")-clamped0>=1 and stat("rewind_ms_max")<=game.LAG_COMP_MAX_REWIND*1000+.001,"Forged old timestamps cannot enlarge the host-measured rewind budget")
	# D: full-auto rifle under jitter: no false cadence rejections.
	var accepted_d0=stat("shots_accepted"); var cadence0=stat("shots_rejected_cadence")
	gate.mark.rpc_id(peer,"D_go")
	while not gate.marks.has("D_done") and game.network_active:
		await physics_frame
		remote.ammo[1]=remote.weapons[1].magazine if remote.weapons.size()>1 else 0
	await create_timer(.6).timeout
	var fired_d=int(gate.marks.get("D_done",0)); var accepted_d=int(stat("shots_accepted")-accepted_d0)
	results["D"]={"fired":fired_d,"accepted":accepted_d,"rejected_cadence":int(stat("shots_rejected_cadence")-cadence0)}
	check(fired_d>=15 and accepted_d==fired_d,"Full-auto rifle: every client shot accepted under jitter (%d/%d)"%[accepted_d,fired_d])
	gate.mark.rpc_id(peer,"finish"); await create_timer(.4).timeout
# ---------------------------------------------------------------- client
func client_run():
	var until=Time.get_ticks_msec()+30000
	while (not game.running or not is_instance_valid(game.player)) and Time.get_ticks_msec()<until: await process_frame
	check(game.running and is_instance_valid(game.player),"Client enters the match")
	if not game.running: return
	game.context="playing"
	var p: NestActor=game.player
	var target: NestActor=game.actor_by_id(1)
	if not await phase("placed"): check(false,"Host placed players"); return
	check(await settle_at(CLIENT_A),"Host placement reaches the predicted client")
	zero_spread(p)
	# A: scripted movement with turning, strafing, crouching and jumps.
	var corrections0=stat("corrections"); var jumps0=stat("client_jumps"); var first_seq=game.command_sequence+1
	gate.mark.rpc_id(1,"A_start")
	var max_view_correction=0.0; var max_view_step=0.0; var last_cam=p.camera.global_position
	var start=Time.get_ticks_msec()
	var holding={}
	var jump_times=[600,2100,3600,5100] # 1.5 s apart: a jump lasts ~1.33 s
	var jumped_at={}
	var last_frame=Time.get_ticks_usec()
	while Time.get_ticks_msec()-start<6000:
		await process_frame
		var frame_delta=(Time.get_ticks_usec()-last_frame)/1000000.0; last_frame=Time.get_ticks_usec()
		var t=Time.get_ticks_msec()-start
		var want={"forward":t<2000 or (t>=4000 and t<5000),"right":t>=1000 and t<2000,"left":t>=2000 and t<3000,"backward":t>=3000 and t<4000,"crouch":t>=3200 and t<3800}
		for action in want:
			if want[action] and not holding.get(action,false): Input.action_press(action)
			elif not want[action] and holding.get(action,false): Input.action_release(action)
			holding[action]=want[action]
		for jt in jump_times:
			if t>=jt and not jumped_at.has(jt): jumped_at[jt]=Time.get_ticks_msec(); Input.action_press("jump")
			elif jumped_at.has(jt) and Time.get_ticks_msec()-jumped_at[jt]>50 and Time.get_ticks_msec()-jumped_at[jt]<200: Input.action_release("jump")
		if t>=4000 and t<5000: p.rotation.y=wrapf(p.rotation.y+1.5*frame_delta,-PI,PI); p.apply_aim_rotation()
		max_view_correction=maxf(max_view_correction,p.view_correction.length())
		# Horizontal only: crouching deliberately drops the eye 0.6 m at once.
		var step=p.camera.global_position-last_cam
		max_view_step=maxf(max_view_step,Vector2(step.x,step.z).length()); last_cam=p.camera.global_position
	release_all()
	await create_timer(1.5).timeout
	var client_jumps=int(stat("client_jumps")-jumps0)
	results["A"]={"corrections":int(stat("corrections")-corrections0),"max_view_correction_m":max_view_correction,"max_view_step_horizontal_m":max_view_step,"max_correction_m":stat("max_correction_m"),"replayed_ticks":stat("replayed_ticks"),"jumps":client_jumps}
	gate.mark.rpc_id(1,"A_done",{"jumps":client_jumps,"pos":p.global_position,"first_seq":first_seq,"last_seq":game.command_sequence})
	if not await phase("A2_ready"): check(false,"Host ready for disturbance phase"); return
	check(await settle_at(CLIENT_A),"Disturbance placement reaches the client")
	var corrections2=stat("corrections"); var view2=0.0
	p.rotation.y=0.0; p.eye.rotation.x=0.0; p.apply_aim_rotation()
	await physics_frame
	Input.action_press("forward")
	gate.mark.rpc_id(1,"A2_moving")
	var t2=Time.get_ticks_msec()
	var stalled=false; var resumed=false
	while Time.get_ticks_msec()-t2<2600:
		await process_frame
		var e=Time.get_ticks_msec()-t2
		if e>=1200 and not stalled:
			stalled=true; game.command_send_paused=true; Input.action_release("forward"); Input.action_press("right")
		if e>=1600 and not resumed:
			resumed=true; game.command_send_paused=false
		if e>=2100: Input.action_release("right")
		view2=maxf(view2,p.view_correction.length())
	release_all()
	# The knockback launches the body upward; compare only once it has landed
	# and stopped (a moving client is ahead of the host by the latency).
	var rest_until=Time.get_ticks_msec()+8000
	while not (p.is_on_floor() and p.velocity.length()<.02) and Time.get_ticks_msec()<rest_until: await physics_frame
	await create_timer(.8).timeout
	results["A2"]={"corrections":int(stat("corrections")-corrections2),"max_view_correction_m":view2,"max_correction_m":stat("max_correction_m")}
	check(stat("corrections")-corrections2>=1,"Unpredicted host changes are reconciled by replay (%d corrections)"%int(stat("corrections")-corrections2))
	gate.mark.rpc_id(1,"A2_done",{"pos":p.global_position})
	if not await phase("L_ready"): check(false,"Host ready for lift ride"); return
	var lift_spot: Vector3=gate.marks["L_ready"]
	var lift_until=Time.get_ticks_msec()+8000
	while Time.get_ticks_msec()<lift_until:
		await physics_frame
		if Vector2(p.global_position.x-lift_spot.x,p.global_position.z-lift_spot.z).length()<.1 and p.is_on_floor(): break
	var lift=game.lift_node()
	var corrections_l=stat("corrections"); var view_l=0.0; var replay_l=stat("replayed_ticks")
	# Ride through the 5 s ascent into the top hold (lift phase 8-11 s).
	var ride_until=Time.get_ticks_msec()+15000
	while Time.get_ticks_msec()<ride_until:
		await process_frame
		view_l=maxf(view_l,p.view_correction.length())
		if fmod(lift.clock,16.0)>=9.2 and fmod(lift.clock,16.0)<10.5 and p.is_on_floor() and p.velocity.length()<.05: break
	await create_timer(.4).timeout
	results["L"]={"corrections":int(stat("corrections")-corrections_l),"replayed_ticks":int(stat("replayed_ticks")-replay_l),"max_view_correction_m":view_l,"lift_synced":game.lift_sync_ready and game.prediction_ready}
	check(game.lift_sync_ready and game.prediction_ready,"Client lift runs on the host timeline")
	gate.mark.rpc_id(1,"L_done",{"pos":p.global_position})
	# B: render the host player; log (view time, rendered position).
	if not await phase("B_ready"): check(false,"Host ready for interpolation phase"); return
	check(await settle_at(CLIENT_SPOT),"Second host placement reaches the client")
	var interp0=stat("interp_ticks"); var extrap0=stat("extrapolated_ticks"); var under0=stat("interp_underflow_ticks")
	gate.mark.rpc_id(1,"B_go")
	var samples=[]
	while not gate.marks.has("B_end") and game.network_active:
		await physics_frame
		samples.append([game.remote_view_time,target.global_position.x,target.global_position.y,target.global_position.z])
	results["B_samples"]=samples
	results["B"]={"interp_ticks":int(stat("interp_ticks")-interp0),"extrapolated_ticks":int(stat("extrapolated_ticks")-extrap0),"underflow_ticks":int(stat("interp_underflow_ticks")-under0),"interp_delay_ms":stat("interp_delay_ms")}
	# C: aim at the displayed chest of the strafing target and fire.
	results["C"]={}
	for comp in [true,false]:
		if not await phase("C_go_"+str(comp)): check(false,"Host starts target phase"); return
		await create_timer(.8).timeout
		var fired=0
		var confirmed0=game.hit_until
		for shot in range(SHOTS_PER_MODE):
			await create_timer(.42).timeout
			await physics_frame
			# At physics_frame the rendered target, its hitboxes and the physics
			# broadphase all reflect the same (previous) tick and view time.
			p.aim_punch=Vector2.ZERO; p.accuracy_penalty=0
			var aim_point=target.hitboxes[1].global_position
			var offset=aim_point-p.camera.global_position
			p.rotation.y=atan2(-offset.x,-offset.z); p.eye.rotation.x=atan2(offset.y,Vector2(offset.x,offset.z).length()); p.apply_aim_rotation()
			if p.ammo[0]<=0: await create_timer(.2).timeout
			if p.fire_trigger(): fired+=1
		await create_timer(.6).timeout
		results["C"][str(comp)]={"fired":fired}
		gate.mark.rpc_id(1,"C_end_"+str(comp),fired)
	# E: forged old view time.
	if not await phase("E_go"): check(false,"Host ready for rewind bound"); return
	await create_timer(.5).timeout
	var aim=p.resolve_shot_aim(100.0)
	game.authorize_shot.rpc_id(1,game.next_event()*16,p.life_id,game.round_number,"sidearm",aim.origin,aim.direction,game.match_session,0,game.command_sequence,game.remote_view_time-1.0)
	gate.mark.rpc_id(1,"E_done")
	# D: switch to the rifle and hold the trigger at the sky for two seconds.
	if not await phase("D_go"): check(false,"Host ready for cadence phase"); return
	await create_timer(.5).timeout
	p.switch_weapon(); await create_timer(1.2).timeout
	check(p.weapons[p.slot].kind=="rifle","Weapon switch reaches the rifle")
	var fired_d=[0]
	var counter=func(_id,_t,_o,_d): fired_d[0]+=1
	p.shot_fired.connect(counter)
	p.eye.rotation.x=1.2; p.aim_punch=Vector2.ZERO; p.apply_aim_rotation()
	Input.action_press("fire")
	await create_timer(2.0).timeout
	Input.action_release("fire"); p.shot_fired.disconnect(counter)
	results["D"]={"fired":fired_d[0]}
	await create_timer(.2).timeout
	gate.mark.rpc_id(1,"D_done",fired_d[0])
	await phase("finish")
func settle_at(offset: Vector3) -> bool:
	var target=PLATFORM+offset
	var until=Time.get_ticks_msec()+8000
	while Time.get_ticks_msec()<until:
		await physics_frame
		var p=game.player
		if Vector2(p.global_position.x-target.x,p.global_position.z-target.z).length()<.1 and p.is_on_floor() and p.velocity.length()<.05:
			await create_timer(.3).timeout
			return true
	return false
