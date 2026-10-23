class_name NestSniperCycle
extends RefCounted
## Cosmetic-only post-shot cycles. Fire readiness remains the authoritative cooldown.
static var kit: NestKit
static func phase(actor, reload_progress: float=-1) -> float:
 if actor.weapons.is_empty() or not actor.alive or actor.action_state!="ready" or reload_progress>=0:return -1
 var weapon=actor.weapons[actor.slot]
 if weapon.kind not in ["sniper","plasma_sniper"] or actor.last_shot_kind!=weapon.kind:return -1
 var age=actor.game.now-(actor.flash_until-.15)
 var duration=actor.fire_interval(weapon.interval)
 return clampf(age/duration,0,1) if age>=0 and age<duration else -1
static func lift(p: float) -> float:
 return smoothstep(.10,.23,p)*(1-smoothstep(.80,.96,p)) if p>=0 else 0.0
static func travel(p: float) -> float:
 return smoothstep(.24,.43,p)*(1-smoothstep(.54,.78,p)) if p>=0 else 0.0
static func hand_weight(p: float) -> float:
 return smoothstep(.05,.18,p)*(1-smoothstep(.86,1.0,p)) if p>=0 else 0.0
static func hand_goal(p: float) -> Vector3:
 return Vector3(.14,.045,.035+travel(p)*.12)
static func add_bolt(root: Node3D) -> void:
 if root.has_meta("bolt_cycle_art"):return
 if kit==null:kit=NestKit.new()
 var lever=root.find_child("ChargingHandle*",true,false)
 if lever==null:
  lever=Node3D.new();lever.name="ChargingHandle_BoltAction";root.add_child(lever);lever.position=Vector3(.07,.025,.02)
 var metal=kit.material(Color("343b3d"),.8)
 kit.box(lever,Vector3(.035,0,0),Vector3(.075,.018,.018),metal)
 kit.sphere(lever,Vector3(.073,-.01,0),.022,metal)
 root.set_meta("bolt_cycle_art",true)
static func add_charge(root: Node3D) -> void:
 if root.has_meta("sniper_charge"):return
 if kit==null:kit=NestKit.new()
 var bank=Node3D.new();bank.name="SniperRecharge";root.add_child(bank)
 var lights=[]
 for i in range(5):
  var m=kit.material(Color("52ed72"));m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.emission_enabled=true;m.emission=Color("52ed72")
  var node=kit.box(bank,Vector3(-.112,.06,-.075-i*.042),Vector3(.012,.021,.028),m)
  node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;lights.append(node)
 root.set_meta("sniper_charge",lights)
static func update_art(root: Node3D,actor,reload_progress: float) -> void:
 if root==null or not root.has_meta("sniper_charge"):return
 var p=phase(actor,reload_progress)
 var charge=p if p>=0 else 1.0
 for i in range(5):
  var node: MeshInstance3D=root.get_meta("sniper_charge")[i]
  var strength=clampf(charge*5-i,0,1)
  var m: StandardMaterial3D=node.material_override
  m.albedo_color=Color("091c10").lerp(Color("52ed72"),strength)
  m.emission_energy_multiplier=.04+1.7*strength
  node.scale.y=.3+.7*strength
  var camo=node.get_surface_override_material(0)
  if camo is ShaderMaterial:
   camo.set_shader_parameter("base_color",m.albedo_color);camo.set_shader_parameter("glow",m.emission*m.emission_energy_multiplier)
static func update_view_hand(actor,reload_progress: float) -> void:
 if actor.view_grip_parts.size()<2:return
 var arm: Node3D=actor.view_grip_parts[0];var hand: Node3D=actor.view_grip_parts[1]
 for node in [arm,hand]:
  if not node.has_meta("sniper_hand_rest"):node.set_meta("sniper_hand_rest",node.transform)
  node.transform=node.get_meta("sniper_hand_rest")
 if actor.weapons[actor.slot].kind!="sniper":return
 var p=phase(actor,reload_progress);var weight=hand_weight(p)
 if weight<=0:return
 hand.position=hand.position.lerp(hand_goal(p),weight)
 hand.rotation.z=-lift(p)*.8*weight
 var elbow=Vector3(.09,-.22,.42);var difference=hand.position-elbow
 arm.position=arm.position.lerp((elbow+hand.position)*.5,weight)
 arm.quaternion=arm.quaternion.slerp(Quaternion(Vector3.UP,difference.normalized()),weight)
 arm.scale.y=lerpf(arm.scale.y,difference.length()/.25,weight)
