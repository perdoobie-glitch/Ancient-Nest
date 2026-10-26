class_name NestCampaignLoot
extends Node
const LIMIT=24
const LIFETIME=120.0
var campaign
var drops={}
var released={}
var sequence=0
func clear():
 for body in drops.values():
  if is_instance_valid(body):body.queue_free()
 drops.clear();released.clear();sequence=0
func release(actor: NestActor):
 if campaign.game.is_client() or not campaign.active or actor.faction!=1 or (campaign.world.region!="forest" and campaign.state.mission_index<2) or actor.weapons.is_empty():return
 var source=str(actor.net_id)+":"+str(actor.life_id)
 if released.has(source):return
 released[source]=true
 var weapon=actor.weapons[actor.slot];var definition=NestWeaponCatalog.for_kind(weapon.kind)
 if definition.get("slot","") not in ["primary","secondary"]:return
 if drops.size()>=LIMIT:
  var oldest=drops.keys()[0];drops[oldest].queue_free();drops.erase(oldest)
 sequence+=1
 var body=NestCampaignDrop.new();body.campaign=campaign;body.drop_id=sequence;body.kind=weapon.kind;body.rounds=actor.ammo[actor.slot];body.reserve=actor.reserve[actor.slot];body.born=campaign.game.now;add_child(body)
 body.global_transform=actor.remote_weapon.global_transform.orthonormalized() if is_instance_valid(actor.remote_weapon) else Transform3D(actor.global_basis,actor.global_position+Vector3.UP*1.3)
 body.linear_velocity=actor.velocity.limit_length(12)+actor.global_basis.x*(1.1 if posmod(actor.net_id,2)==0 else -1.1)+Vector3.UP*1.6
 body.angular_velocity=Vector3(2.8,1.2,-2.2);body.reset_physics_interpolation();drops[sequence]=body
func closest(actor: NestActor) -> NestCampaignDrop:
 if not actor.alive or not campaign.can_damage(actor):return null
 var best: NestCampaignDrop;var distance=2.7
 for body in drops.values():
  if not is_instance_valid(body) or body.claimed_by>0:continue
  var d=actor.global_position.distance_to(body.pickup_point())
  var clear=campaign.game.trace(actor.eye.global_position,body.pickup_point(),1).is_empty()
  var visible=d<1.0 or not campaign.world.smoke_blocks(actor.eye.global_position,body.pickup_point())
  if d<distance and clear and visible:best=body;distance=d
 return best
func take(actor: NestActor,id: int) -> bool:
 if campaign.game.is_client() or not drops.has(id) or closest(actor)!=drops[id]:return false
 var body: NestCampaignDrop=drops[id]
 if body.claimed_by>0:return false
 var definition=NestWeaponCatalog.for_kind(body.kind);var index=1 if definition.get("slot","")=="secondary" else 0
 var weapon=NestWeaponCatalog.profile(body.kind).duplicate()
 if actor.weapons[index].kind==body.kind:actor.reserve[index]=clampi(actor.reserve[index]+body.rounds+body.reserve,0,weapon.reserve*4)
 else:actor.weapons[index]=weapon;actor.ammo[index]=clampi(body.rounds,0,weapon.magazine);actor.reserve[index]=clampi(body.reserve,0,weapon.reserve*4)
 actor.slot=index
 actor.reset_aim();actor.burst_left=0;actor.auto_reload_at=INF;actor.auto_reload_slot=-1;actor.shell_remaining=0;actor.shell_next=INF;actor.action_state="switching";actor.action_until=campaign.game.now+.45;actor.cooldown=actor.action_until;campaign.game.remote_shot_clocks.erase(actor.remote_peer)
 if actor.combat_audio!=null:actor.combat_audio.stop_reload()
 actor.update_weapon_art();body.animate_pickup(actor.net_id);campaign.game.sound("weapon_pickup",actor.global_position,actor.local_player);return true
func pack() -> Array:
 var result=[]
 for body in drops.values():
  if is_instance_valid(body):result.append(body.pack())
 return result
func receive(records: Array):
 if records.size()>LIMIT:return
 var kept=[]
 for record in records:
  if not record is Dictionary or not record.get("xf") is Transform3D or not record.xf.is_finite() or not record.get("v") is Vector3 or not record.v.is_finite():continue
  if not record.get("id") is int or int(record.id)<1 or not record.get("kind") is String or NestWeaponCatalog.for_kind(record.kind).get("slot","") not in ["primary","secondary"]:continue
  var id=int(record.id);kept.append(id)
  if not drops.has(id):
   var node=NestCampaignDrop.new();node.campaign=campaign;node.drop_id=id;node.kind=record.kind;node.rounds=int(record.get("rounds",0));node.reserve=int(record.get("reserve",0));node.born=float(record.get("born",0));add_child(node);node.global_transform=record.xf;node.reset_physics_interpolation();drops[id]=node
  var body: NestCampaignDrop=drops[id];body.target=record.xf;body.target_velocity=record.v.limit_length(20);body.received_at=Time.get_ticks_msec()/1000.0
  if int(record.get("claimed",0))>0:body.animate_pickup(int(record.claimed))
 for id in drops.keys():
  if id not in kept:drops[id].queue_free();drops.erase(id)
func _process(_delta):
 if not campaign.active or campaign.game.is_client() or campaign.paused():return
 for id in drops.keys():
  var body: NestCampaignDrop=drops[id]
  if (body.claimed_by>0 and campaign.game.now-body.claimed_at>.6) or campaign.game.now-body.born>LIFETIME or body.global_position.y< -10:body.queue_free();drops.erase(id)
