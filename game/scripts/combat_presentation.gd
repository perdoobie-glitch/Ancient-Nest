class_name NestCombatPresentation
extends RefCounted
# Cosmetic layers only: no camera transforms, ammo changes or collision bodies.
var actor
var skeleton: Skeleton3D
var view_bomb: Node3D
var left_hand: Node3D
var left_forearm: MeshInstance3D
var remote_flash: MeshInstance3D
var view_grenade: MeshInstance3D
var view_nu: Node3D
var remote_nu: Node3D
var view_knife: Node3D
var remote_knife: Node3D
var remote_grenade: MeshInstance3D
var hit_electricity: NestHitElectricity
var locomotion_velocity: Vector3 = Vector3.ZERO
var locomotion_weight: float = 0
var locomotion_life: int = -1
var gait_phase: float = 0
var view_gait_phase: float = 0
var view_speed: float = 0
var bones: Dictionary = {}
var last_weapon: String = ""
const LANDING_SECONDS: float = .34
const SECOND_FOOT_DELAY: float = .10
var landing_age: float = INF
var landing_sequence: int = 0
var first_foot_left: bool = true
var airborne_seconds: float = 0
var landing_life: int = -1
var presentation_clock: float = 0
var last_landing_clock: float = -INF
func _init(owner_actor) -> void:
	actor=owner_actor; skeleton=actor.skeleton
func setup() -> void:
	if skeleton!=null:
		for side in ["l","r"]:
			for part in ["upperarm","forearm","hand","thigh","calf","foot"]: bones[part+"_"+side]=skeleton.find_bone(part+"_"+side)
	var kit=actor.game.arena.kit
	hit_electricity=NestHitElectricity.new(); hit_electricity.actor=actor; actor.add_child(hit_electricity); hit_electricity.scale=Vector3.ONE*NestActor.SIZE
	actor.shield_fx=NestShieldFX.new(); actor.shield_fx.name="ShieldFX"; actor.shield_fx.actor=actor; actor.add_child(actor.shield_fx)
	if actor.weapon_view!=null:
		left_hand=Node3D.new(); left_hand.name="SupportHand"; actor.weapon_view.add_child(left_hand)
		var glove=NestViewArms.create(actor.character,"l","hand");left_hand.add_child(glove)
		left_forearm=NestViewArms.create(actor.character,"l","forearm");actor.weapon_view.add_child(left_forearm)
	if actor.remote_weapon!=null:
		remote_flash=kit.sphere(actor.remote_weapon,Vector3(0,0,-.43),.065,kit.lamp)
		remote_flash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; remote_flash.visible=false
	if left_hand!=null:
		view_bomb=NestBombArt.create(kit);actor.weapon_view.add_child(view_bomb);view_bomb.scale=Vector3.ONE*.55;view_bomb.visible=false
		view_knife=NestPlasmaSwordArt.create(false) if actor.character==0 else NestKnifeArt.create();left_hand.add_child(view_knife);view_knife.rotation=Vector3(PI*.5,0,-.35);view_knife.visible=false
		if actor.character==1:
			view_nu=NestFalconArt.create(true);left_hand.add_child(view_nu);view_nu.position=Vector3(0,.07,-.07);view_nu.visible=false
		view_grenade=kit.sphere(left_hand,Vector3(0,.02,-.05),.055,NestGrenadeArt.material(false));view_grenade.visible=false
	if skeleton!=null:
		var grip=BoneAttachment3D.new();grip.bone_name="hand_l";skeleton.add_child(grip)
		remote_knife=NestPlasmaSwordArt.create(false) if actor.character==0 else NestKnifeArt.create();grip.add_child(remote_knife);remote_knife.visible=false
		remote_knife.transform=skeleton.get_bone_global_rest(skeleton.find_bone("hand_l")).affine_inverse()*Transform3D(Basis.from_euler(Vector3(PI*.5,0,-.35)),Vector3(-.43,.845,-.20))
		if actor.character==1:
			remote_nu=NestFalconArt.create(true);grip.add_child(remote_nu);remote_nu.transform=skeleton.get_bone_global_rest(skeleton.find_bone("hand_l")).affine_inverse()*Transform3D(Basis.IDENTITY,Vector3(-.43,.95,-.20));remote_nu.visible=false
		remote_grenade=kit.sphere(grip,Vector3.ZERO,.075,NestGrenadeArt.material(false));remote_grenade.visible=false
	actor.cache_cloak_meshes();actor.refresh_model_visibility()
func reload_progress() -> float:
	if actor.action_state!="reloading" or actor.weapons.is_empty(): return -1
	return clampf(1.0-(actor.action_until-actor.game.now)/(actor.reload_duration if actor.reload_duration>0 else actor.weapons[actor.slot].reload_seconds),0,1)
func shot_age() -> float:
	return actor.game.now-(actor.flash_until-.15)
func magazine_pull(progress: float) -> float:
	if progress<0: return 0
	if progress<.32: return smoothstep(.04,.14,progress)
	return 1.0-smoothstep(.57,.69,progress)
func update(delta: float) -> void:
	update_landing(delta)
	var speed: float=Vector2(actor.velocity.x,actor.velocity.z).length()
	update_locomotion(delta)
	update_view_weapon(view_speed if actor.local_player else speed)
	update_shield()
func update_view(delta: float) -> void:
	# First-person bob follows render cadence; locomotion, contacts and remote
	# skeleton poses still advance in fixed simulation. Never move the camera.
	var speed: float=Vector2(actor.velocity.x,actor.velocity.z).length()
	if not actor.locomotion_grounded():
		view_speed=0
	else:
		view_speed=move_toward(view_speed,speed,actor.tuning.ground_acceleration*maxf(0,delta))
		view_gait_phase=fposmod(view_gait_phase+maxf(0,delta)*view_speed*2.0,TAU)
	update_view_weapon(view_speed)
func update_landing(delta: float) -> void:
	presentation_clock+=delta
	if landing_life!=actor.life_id or not actor.alive:
		landing_life=actor.life_id; landing_age=INF; airborne_seconds=0; last_landing_clock=-INF
		return
	if is_finite(landing_age):landing_age+=delta
	var grounded=actor.net_grounded if actor.game.is_client() and not actor.local_player else actor.is_on_floor()
	if not grounded:
		landing_age=INF # A new jump cancels the cosmetic landing immediately.
		airborne_seconds+=delta
	elif airborne_seconds>0:
		# Short seam contacts must not repeatedly restart the landing pose.
		if airborne_seconds>=.06 and presentation_clock-last_landing_clock>LANDING_SECONDS:
			landing_age=0; landing_sequence+=1; first_foot_left=sin(gait_phase)>=0; last_landing_clock=presentation_clock
		airborne_seconds=0
func landing_foot_lift(left: bool) -> float:
	if landing_age>=LANDING_SECONDS:return 0.0
	if left==first_foot_left:return 0.0
	return 1.0-smoothstep(SECOND_FOOT_DELAY*.45,SECOND_FOOT_DELAY+.065,landing_age)
func pose_landing() -> void:
	if landing_age>=LANDING_SECONDS or actor.air_duck:return
	var weight=1.0-smoothstep(.20,LANDING_SECONDS,landing_age)
	for side in ["l","r"]:
		var left=side=="l";var lift=landing_foot_lift(left)
		var age=landing_age-(0.0 if left==first_foot_left else SECOND_FOOT_DELAY)
		var compression=sin(PI*clampf(age/.20,0,1)) if age>=0 else 0.0
		for part in ["thigh","calf","foot"]:
			var index: int=bones.get(part+"_"+side,-1)
			if index<0:continue
			var angle=(-.10*compression-.45*lift) if part!="calf" else (.20*compression+.90*lift)
			var rest=skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
			var goal=(skeleton.get_bone_pose_rotation(index) if actor.crouched else rest)*Quaternion(Vector3.RIGHT,angle)
			skeleton.set_bone_pose_rotation(index,skeleton.get_bone_pose_rotation(index).slerp(goal,weight))
func update_view_weapon(speed: float) -> void:
	if actor.weapon_view==null: return
	actor.weapon_view.visible=actor.alive and not actor.game.nu.birds.has(actor.net_id) and not actor.scoped_overlay() and (actor.weapons[actor.slot].kind!="none" or actor.action_state=="melee")
	var knife_active=actor.alive and actor.action_state=="melee"
	if view_bomb!=null:
		view_bomb.visible=actor.bomb_equipped
		view_bomb.position=Vector3(-.07,-.02,-.14)
		if actor.action_state=="bomb_drop":
			var t=clampf(1-(actor.bomb_drop_at-actor.game.now),0,1)
			view_bomb.position=Vector3(-.17,.18,.25).lerp(Vector3(-.07,-.18,-.4),smoothstep(0,1,t))
	for part in actor.view_grip_parts:part.visible=not knife_active and actor.game.now>=actor.cloak_deadline
	if left_forearm!=null:left_forearm.visible=actor.game.now>=actor.cloak_deadline
	if left_hand!=null:
		var glove=left_hand.get_node_or_null("ModelHand_l")
		if glove!=null:glove.visible=actor.game.now>=actor.cloak_deadline
	if view_knife!=null:
		view_knife.visible=knife_active
		if actor.character==0:NestPlasmaSwordArt.activate(view_knife,actor.sword_blade_strength())
	if actor.weapon_art!=null:actor.weapon_art.visible=not knife_active and actor.action_state!="nu_launch" and not actor.bomb_equipped
	if view_nu!=null:view_nu.visible=actor.action_state=="nu_launch" and nu_progress()>.28
	var progress=reload_progress()
	var tilt=pow(maxf(0,sin(PI*progress)),.7) if progress>=0 else 0.0
	var kick=exp(-maxf(0,shot_age())*23.0) if shot_age()>=0 and shot_age()<.35 else 0.0
	var profiles={"rifle":Vector3(.8,.7,.025),"ak47":Vector3(1.15,1.0,.04),"burst":Vector3(.9,.65,-.025),"burst_scoped":Vector3(.7,.6,.015),"sidearm":Vector3(1.2,.65,.07),"sniper":Vector3(1.7,1.45,-.02),"shotgun":Vector3(1.8,1.6,.05),"rocket":Vector3(.65,1.8,-.06),"smg":Vector3(.5,.45,.035),"plasma_pistol":Vector3(.45,.35,-.04),"plasma_br":Vector3(.65,.6,.035),"plasma_auto":Vector3(.4,.45,-.035),"plasma_smg":Vector3(.3,.3,.025),"plasma_sniper":Vector3(1.1,1.1,-.025)}
	var profile=profiles.get(actor.weapons[actor.slot].kind,Vector3.ONE)
	var movement=minf(speed/actor.tuning.ground_speed,1) if actor.locomotion_grounded() else 0.0
	var bob_phase=view_gait_phase if actor.local_player else gait_phase
	var bob=Vector3(sin(bob_phase)*.009,(absf(cos(bob_phase))-.5)*.012,0)*movement
	actor.weapon_view.position=Vector3(.24,-.22,-.48)+bob+Vector3(-.055*tilt,.075*tilt,kick*.046*profile.y+.055*tilt)
	actor.weapon_view.rotation=Vector3(.06*kick*profile.x-.12*tilt,.12*tilt,-.45*tilt+sin(bob_phase)*.014*movement+kick*profile.z)
	if actor.action_state=="switching":
		var duration=.6/actor.melee_speed() if actor.weapons[actor.slot].kind=="plasma_sword" else maxf(.01,float(NestWeaponCatalog.for_kind(actor.weapons[actor.slot].kind).get("switch_seconds",.4)))
		actor.weapon_view.position.y-=smoothstep(0,.75,clampf((actor.action_until-actor.game.now)/duration,0,1))*.26
	if actor.weapons[actor.slot].kind=="plasma_sword":
		NestPlasmaSwordArt.activate(actor.weapon_art,actor.sword_blade_strength())
		actor.weapon_art.rotation=Vector3(.72,0,-.10);actor.weapon_art.position.y=-.09
	if actor.action_state in ["throwing","melee"]: actor.weapon_view.position.y-=.15
	if actor.action_state=="throwing":actor.weapon_view.position+=Vector3(.10,-.08,0)
	if knife_active:actor.weapon_view.position=Vector3(.16,-.18,-.55);actor.weapon_view.rotation=Vector3.ZERO
	if progress>=0 and actor.weapons[actor.slot].kind=="rocket":actor.weapon_view.position.z-=.45*tilt
	var pull=magazine_pull(progress)
	if left_hand!=null:
		var normal=Vector3(-.015,-.025,-.18)
		var grips={"sidearm":Vector3(-.025,-.075,.025),"plasma_pistol":Vector3(-.03,-.045,-.03),"rocket":Vector3(-.07,-.06,-.22),"shotgun":Vector3(-.02,-.035,-.26),"sniper":Vector3(-.025,-.035,-.24),"smg":Vector3(-.025,-.035,-.12)}
		normal=grips.get(actor.weapons[actor.slot].kind,normal)
		var reload_grip=Vector3(.015,-.10-pull*.17,.035)
		var definition=NestWeaponCatalog.for_kind(actor.weapons[actor.slot].kind)
		if progress>=0 and definition.get("per_shell",false):
			var phase=fposmod(progress*actor.reload_duration,actor.reload_interval(float(definition.shell_seconds)))/actor.reload_interval(float(definition.shell_seconds))
			var insert=sin(phase*PI)
			reload_grip=Vector3(-.02,-.11-.08*insert,.07+.06*insert)
		if progress>=0 and actor.weapons[actor.slot].plasma:
			var rise=smoothstep(.32,.63,progress)
			reload_grip=Vector3(-.08,-.43,.22).lerp(Vector3(0,-.10,-.08),rise)
			if progress>.63:reload_grip.y+=sin(clampf((progress-.63)/.10,0,1)*PI)*.045
		left_hand.position=normal.lerp(reload_grip,tilt)
		if progress>=0 and actor.weapons[actor.slot].kind=="rocket":left_hand.position=normal.lerp(NestRocketArt.hand_offset(progress),tilt)
		var throwing=actor.throw_progress()
		if throwing>=0:left_hand.position=throw_hand(throwing)
		if actor.action_state=="nu_launch":left_hand.position=nu_hand(nu_progress())
		if view_grenade!=null:
			view_grenade.visible=throwing>=0 and throwing<(.20/.75)
			view_grenade.material_override=NestGrenadeArt.material(actor.throw_kind==1)
		left_hand.rotation=Vector3(0,0,-.18*tilt)
		if knife_active:
			var swing=knife_swing()
			left_hand.position=Vector3(-.30,.02,.02).lerp(Vector3(.14,-.04,-.34),swing)
			left_hand.rotation=Vector3(-.15,.65-.95*swing,-.6+.9*swing)
			if actor.character==0:
				var elapsed=actor.sword_draw+.7/actor.melee_speed()-(actor.action_until-actor.game.now)
				if elapsed<actor.sword_draw:left_hand.position=Vector3(.06,-.38,.18).lerp(Vector3(-.26,.04,-.08),smoothstep(0,actor.sword_draw,elapsed))
				else:left_hand.position=Vector3(-.26,.04,-.08).lerp(Vector3(.20,-.04,-.45),swing)
				view_knife.rotation=Vector3(.25,.2,1.25)
		if actor.bomb_equipped:
			var t=clampf(1-(actor.bomb_drop_at-actor.game.now),0,1) if actor.action_state=="bomb_drop" else 1.0
			left_hand.position=Vector3(-.12,.16,.2).lerp(Vector3(-.08,-.04,-.2),smoothstep(0,1,t))
		var elbow=Vector3(-.28,-.24,.16 if knife_active else .30)
		var difference=left_hand.position-elbow
		left_forearm.position=(elbow+left_hand.position)*.5
		left_forearm.scale=Vector3(1,difference.length()/.25,1)
		left_forearm.quaternion=Quaternion(Vector3.UP,difference.normalized())
	actor.muzzle_flash.visible=false
	NestGunFeedback.update(actor.weapon_art,actor,shot_age(),true)
	actor.muzzle_flash.scale=Vector3(1.1,.8,1.5)*(1-kick*.25)
	animate_parts(actor.weapon_art,progress)
	NestSniperCycle.update_art(actor.weapon_art,actor,progress)
	NestSniperCycle.update_view_hand(actor,progress)
func knife_swing() -> float:
	if actor.character==0:
		var elapsed=.7-(actor.action_until-actor.game.now)*actor.melee_speed()
		if elapsed<0:return 0
		return smoothstep(0,.35,elapsed)*(1.0-smoothstep(.5,.7,elapsed))
	var duration=maxf(.01,float(actor.game.damage_rules.melee_cooldown_seconds))/1.15
	var elapsed=clampf(1-(actor.action_until-actor.game.now)/duration,0,1)*.66
	if elapsed<.10:return 0.0
	if elapsed<.25:return smoothstep(.10,.25,elapsed)
	return 1.0-smoothstep(.30,minf(duration,.66),elapsed)
func throw_hand(progress: float) -> Vector3:
	if progress<.13:return Vector3(-.015,-.025,-.18).lerp(Vector3(-.25,-.10,.14),smoothstep(0,.13,progress))
	if progress<.267:return Vector3(-.25,-.10,.14).lerp(Vector3(-.10,.18,-.37),smoothstep(.13,.267,progress))
	return Vector3(-.10,.18,-.37).lerp(Vector3(-.015,-.025,-.18),smoothstep(.40,1,progress))
func plasma_cell_offset(progress: float) -> Vector3:
	if progress<0:return Vector3.ZERO
	if progress<.22:return Vector3(0,-.32,.16)*smoothstep(0,.22,progress)
	if progress<.32:return Vector3(-.08,-.35,.20)
	if progress<.63:return Vector3(-.08,-.35,.20).lerp(Vector3.ZERO,smoothstep(.32,.63,progress))
	return Vector3(0,sin(clampf((progress-.63)/.10,0,1)*PI)*.025,0)
func animate_parts(root: Node3D, progress: float) -> void:
	if root==null: return
	var age=shot_age()
	var resting=progress<0 and (age<0 or age>2.0)
	if resting and bool(root.get_meta("parts_at_rest",false)):return
	if bool(root.get_meta("parts_at_rest",false))!=resting:root.set_meta("parts_at_rest",resting)
	NestRocketArt.animate_reload(root,progress)
	if not root.has_meta("motion_parts"):
		var parts=[]
		for node in root.find_children("*","Node3D",true,false):
			if node.name.begins_with("ReloadMagazine") or node.name.begins_with("ChargingHandle") or node.name.begins_with("Pump") or node.name.begins_with("PistolSlide"):
				parts.append({"node":node,"rest":node.transform,"name":String(node.name)})
		root.set_meta("motion_parts",parts)
	var pull=magazine_pull(progress)
	for data in root.get_meta("motion_parts"):
		var node: Node3D=data.node; node.transform=data.rest
		if data.name.begins_with("ReloadMagazine"):
			if actor.weapons[actor.slot].plasma:
				node.position+=plasma_cell_offset(progress)
				node.rotation.z+=-.18*sin(maxf(progress,0)*PI)
				# Old pack drops away, then a fresh gold pack rises from the hip.
				node.visible=not (progress>=.22 and progress<.32)
			else:node.position+=Vector3(.025*pull,-.19*pull,0);node.rotation.z+=.12*pull
		elif data.name.begins_with("ChargingHandle"):
			var bolt=sin(clampf((progress-.83)/.15,0,1)*PI) if progress>=0 else (sin(clampf((age-.1)/.3,0,1)*PI) if actor.weapons[actor.slot].kind=="sniper" else 0.0)
			if progress<0 and actor.weapons[actor.slot].kind=="ak47": bolt=sin(clampf(age/.1,0,1)*PI)
			if actor.weapons[actor.slot].kind=="sniper" and progress<0:
				# Unlock, pull rearward, feed forward, then lock; aim stays untouched.
				var phase=NestSniperCycle.phase(actor,progress)
				var lift=NestSniperCycle.lift(phase)
				var travel=NestSniperCycle.travel(phase)
				node.rotation.z+=lift*1.05;node.position.z+=travel*.12
			else:node.position.z+=bolt*.055
		elif data.name.begins_with("Pump"):
			node.position.z+=sin(clampf((age-.07)/.45,0,1)*PI)*.065
		elif data.name.begins_with("PistolSlide"):
			node.position.z+=maxf(0,1-age/.10)*.048 if age>=0 else 0
func set_global_basis(index: int, basis: Basis) -> void:
	var parent=skeleton.get_bone_parent(index)
	var parent_basis=skeleton.get_bone_global_pose(parent).basis if parent>=0 else Basis.IDENTITY
	var local=parent_basis.inverse()*basis
	skeleton.set_bone_pose_rotation(index,local.orthonormalized().get_rotation_quaternion())
func arm_ik(side: String, goal: Vector3) -> void:
	var upper: int=bones.get("upperarm_"+side,-1)
	var fore: int=bones.get("forearm_"+side,-1)
	var hand: int=bones.get("hand_"+side,-1)
	if upper<0 or fore<0 or hand<0: return
	var shoulder=skeleton.get_bone_global_pose(upper).origin
	var elbow=skeleton.get_bone_global_pose(fore).origin
	var wrist=skeleton.get_bone_global_pose(hand).origin
	var a=shoulder.distance_to(elbow); var b=elbow.distance_to(wrist)
	var direction=(goal-shoulder).normalized()
	var distance=clampf(shoulder.distance_to(goal),absf(a-b)+.012,a+b-.012)
	var pole=Vector3(1 if side=="r" else -1,-.55,.28)
	var bend=(pole-direction*pole.dot(direction)).normalized()
	var cos_angle=clampf((a*a+distance*distance-b*b)/(2*a*distance),-1,1)
	var wanted_elbow=shoulder+direction*a*cos_angle+bend*a*sqrt(maxf(0,1-cos_angle*cos_angle))
	var rotation=Quaternion((elbow-shoulder).normalized(),(wanted_elbow-shoulder).normalized())
	set_global_basis(upper,Basis(rotation)*skeleton.get_bone_global_pose(upper).basis)
	elbow=skeleton.get_bone_global_pose(fore).origin; wrist=skeleton.get_bone_global_pose(hand).origin
	var reachable=shoulder+direction*distance
	rotation=Quaternion((wrist-elbow).normalized(),(reachable-elbow).normalized())
	set_global_basis(fore,Basis(rotation)*skeleton.get_bone_global_pose(fore).basis)
	set_global_basis(hand,skeleton.get_bone_global_rest(hand).basis)
func pose_upper_body() -> void:
	if skeleton==null or not actor.alive: return
	var pitch=clampf(actor.eye.rotation.x,-.65,.65)
	var progress=reload_progress()
	var tilt=sin(PI*progress) if progress>=0 else 0.0
	var kick=exp(-maxf(0,shot_age())*23.0) if shot_age()>=0 and shot_age()<.3 else 0.0
	var basis=Basis.from_euler(Vector3(pitch+.035*kick,.65*tilt if actor.weapons[actor.slot].kind=="rocket" else 0,-.27*tilt))
	var gun=Transform3D(basis,Vector3(.10,1.35,-.24)+Vector3(-.025*tilt,-.025*tilt,kick*.018))
	if actor.action_state=="switching":
		var duration=maxf(.01,float(NestWeaponCatalog.for_kind(actor.weapons[actor.slot].kind).get("switch_seconds",.4)))
		gun.origin.y-=smoothstep(0,.75,clampf((actor.action_until-actor.game.now)/duration,0,1))*.24
	var right=gun*Vector3(0,-.105,.075)
	if actor.weapons[actor.slot].kind=="sniper":right=right.lerp(gun*NestSniperCycle.hand_goal(NestSniperCycle.phase(actor,progress)),NestSniperCycle.hand_weight(NestSniperCycle.phase(actor,progress)))
	var left=gun*Vector3(-.025,-.035,-.145)
	if actor.weapons[actor.slot].kind=="plasma_sword":
		right=gun*Vector3(0,0,.08);left=Vector3(-.25,1.05,-.10);actor.remote_art.rotation=Vector3(.65,0,0)
	if progress>=0: left=left.lerp(gun*Vector3(.005,-.14-magazine_pull(progress)*.17,.03),tilt)
	if actor.action_state=="throwing":
		right=Vector3(.24,1.12,-.18)
		var path=throw_hand(actor.throw_progress());left=Vector3(path.x,1.38+path.y*1.6,path.z*1.8)
	elif actor.action_state=="nu_launch":
		var phase=nu_progress();left=Vector3(-.26,1.75,.14).lerp(Vector3(-.15,1.57,-.55),smoothstep(.4,.9,phase))
		right=Vector3(.22,1.13,-.1)
	elif progress>=0 and actor.weapons[actor.slot].plasma:
		left=gun*Vector3(-.005,-.14,.03)+plasma_cell_offset(progress)
	if progress>=0 and actor.weapons[actor.slot].kind=="rocket":left=gun*Vector3(-.025,-.27,.22).lerp(Vector3(-.025,-.10,.05),NestRocketArt.insertion(progress))
	if remote_grenade!=null:
		remote_grenade.visible=actor.action_state=="throwing" and actor.throw_progress()<(.20/.75)
		remote_grenade.material_override=NestGrenadeArt.material(actor.throw_kind==1)
	var knife_active=actor.action_state=="melee"
	if remote_knife!=null:
		remote_knife.visible=knife_active
		if actor.character==0:NestPlasmaSwordArt.activate(remote_knife,actor.sword_blade_strength())
	if actor.remote_art!=null:actor.remote_art.visible=not knife_active and actor.action_state!="nu_launch"
	if remote_nu!=null:remote_nu.visible=actor.action_state=="nu_launch" and nu_progress()>.28
	if knife_active:
		left=Vector3(-.26,1.39,-.16).lerp(Vector3(.10,1.25,-.56),knife_swing())
		if actor.character==0 and actor.action_until-actor.game.now>.7/actor.melee_speed():left=Vector3(.27,.94,.08).lerp(Vector3(-.26,1.39,-.16),smoothstep(0,.6,1.3-(actor.action_until-actor.game.now)*actor.melee_speed()))
		right=Vector3(.25,1.14,-.12)
	if actor.bomb_equipped:
		left=Vector3(-.2,1.2,-.38);right=Vector3(.2,1.2,-.38)
		if actor.action_state=="bomb_drop":
			var t=clampf(1-(actor.bomb_drop_at-actor.game.now),0,1)
			left=Vector3(-.2,1.5,.28).lerp(Vector3(-.2,1.1,-.4),smoothstep(0,1,t))
	arm_ik("r",right); arm_ik("l",left)
	if actor.remote_art!=null:actor.remote_art.visible=not actor.bomb_equipped
	pose_locomotion()
	if actor.air_duck:
		for side in ["l","r"]:
			var thigh: int=bones["thigh_"+side];var calf: int=bones["calf_"+side]
			if thigh>=0:skeleton.set_bone_pose_rotation(thigh,skeleton.get_bone_rest(thigh).basis.get_rotation_quaternion()*Quaternion(Vector3.RIGHT,-1.15))
			if calf>=0:skeleton.set_bone_pose_rotation(calf,skeleton.get_bone_rest(calf).basis.get_rotation_quaternion()*Quaternion(Vector3.RIGHT,1.95))
	pose_landing()
	if actor.remote_weapon!=null:
		actor.remote_weapon.transform=skeleton.get_bone_global_pose(bones.hand_r).affine_inverse()*gun
		animate_parts(actor.remote_art,progress)
		NestSniperCycle.update_art(actor.remote_art,actor,progress)
	if remote_flash!=null:
		remote_flash.position.z={"plasma_pistol":-.39,"sidearm":-.15,"sniper":-.54,"ak47":-.52,"rocket":-.39}.get(actor.weapons[actor.slot].kind,-.43)
		remote_flash.visible=false
	NestGunFeedback.update(actor.remote_art,actor,shot_age())
# Presentation state is derived from velocity; it never writes to the controller,
# camera, collision shapes, network commands, or movement tuning.
func update_locomotion(delta: float) -> void:
	if locomotion_life!=actor.life_id or not actor.alive:
		locomotion_life=actor.life_id
		locomotion_velocity=Vector3.ZERO;locomotion_weight=0;gait_phase=0
		return
	var dt=maxf(0,delta)
	var target=actor.global_transform.basis.inverse()*Vector3(actor.velocity.x,0,actor.velocity.z)
	var grounded=actor.net_grounded if actor.game.is_client() and not actor.local_player else actor.is_on_floor()
	if not actor.locomotion_grounded():
		locomotion_velocity=Vector3.ZERO;locomotion_weight=0
		return
	var blend=1.0-exp(-dt*14.0)
	locomotion_velocity=locomotion_velocity.lerp(target,blend)
	var speed=Vector2(locomotion_velocity.x,locomotion_velocity.z).length()
	var reference=maxf(.1,actor.tuning.ground_speed)
	var weight=clampf(speed/reference,0,1)
	locomotion_weight=lerpf(locomotion_weight,weight,blend)
	# Distance-driven phase keeps diagonals continuous rather than restarting a
	# clip on every direction change. Freeze the cycle while in the air.
	if grounded:gait_phase=fposmod(gait_phase+dt*speed*2.0,TAU)
func pose_locomotion() -> void:
	if skeleton==null or not actor.alive or actor.air_duck:return
	var grounded=actor.net_grounded if actor.game.is_client() and not actor.local_player else actor.is_on_floor()
	if not grounded or locomotion_weight<.001:return
	var speed=Vector2(locomotion_velocity.x,locomotion_velocity.z).length()
	if speed<.001:return
	var forward=-locomotion_velocity.z/speed
	var sideways=locomotion_velocity.x/speed
	var weight=locomotion_weight
	for side in ["l","r"]:
		var thigh: int=bones.get("thigh_"+side,-1)
		var calf: int=bones.get("calf_"+side,-1)
		var foot: int=bones.get("foot_"+side,-1)
		if thigh<0 or calf<0 or foot<0:continue
		var phase=gait_phase+(PI if side=="r" else 0.0)
		var stride=sin(phase)
		var lift=pow(maxf(0,cos(phase)),2.0)
		if actor.crouched:
			# Keep the authored crouch height and bent-leg pose.
			var base=skeleton.get_bone_global_pose(thigh).basis
			set_global_basis(thigh,Basis.from_euler(Vector3(stride*.16*forward,0,stride*.12*sideways))*base)
			continue
		# Swing from the hip, recover with a bent knee, then roll the ankle
		# into contact. The opposing leg stays in the support phase.
		var hip=stride*.52*forward*weight
		var lateral=stride*.35*sideways*weight
		var knee=(.08+.70*lift)*weight
		var ankle=(-.12*stride*forward+.16*lift)*weight
		var goals=[Basis.from_euler(Vector3(hip,0,lateral))*skeleton.get_bone_global_rest(thigh).basis,
			Basis.from_euler(Vector3(hip-knee,0,lateral*.65))*skeleton.get_bone_global_rest(calf).basis,
			Basis.from_euler(Vector3(ankle,0,lateral*.15))*skeleton.get_bone_global_rest(foot).basis]
		var indices=[thigh,calf,foot]
		# Blend out smoothly to the authored idle instead of snapping legs.
		for i in range(3):
			var current=skeleton.get_bone_global_pose(indices[i]).basis.orthonormalized().get_rotation_quaternion()
			var goal=goals[i].orthonormalized().get_rotation_quaternion()
			set_global_basis(indices[i],Basis(current.slerp(goal,smoothstep(0,.22,weight))))
func update_shield() -> void:
	if hit_electricity!=null: hit_electricity.update_feedback()

func nu_progress() -> float:
	return clampf(1.0-(actor.nu_launch_until-actor.game.now)/1.5,0,1)
func nu_hand(progress: float) -> Vector3:
	if progress<.4:return Vector3(-.1,-.05,-.15).lerp(Vector3(-.34,.46,.25),smoothstep(0,.4,progress))
	return Vector3(-.34,.46,.25).lerp(Vector3(-.13,.14,-.52),smoothstep(.4,1,progress))
