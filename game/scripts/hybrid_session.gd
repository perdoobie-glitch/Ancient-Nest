class_name NestHybridSession
extends Node
## Transport adapter boundary: TLS control plane calls on_control(); ENet never does.
## Signals must be connected to the game's full save/restore and listen-server adapters.
signal freeze_simulation(reason: String)
signal start_authority(epoch: int,offer: String,checkpoint: String)
signal handoff_requested(endpoint: Dictionary,grant: String,as_host: bool,checkpoint: String)
signal resume_simulation(epoch: int)
signal report_unhealthy(epoch: int)
signal return_to_queue(reason: String)
var match_id=""
var local_player=""
var epoch=0
var authority=""
var frozen=true
var lease_until=0.0
var continuity_until=0.0
var pending_resume=false
var last_host_packet=0.0
var master_clock: Callable
var public_key=CryptoKey.new()
func configure(id: String,player: String,pem: String,clock: Callable) -> Error:
 var fresh=CryptoKey.new()
 var error=fresh.load_from_string(pem,true)
 if error!=OK:return error
 public_key=fresh
 match_id=id;local_player=player;master_clock=clock
 return OK
func verify_grant(token: String,kind: String,wanted_epoch: int,subject: String,host: String) -> Dictionary:
 if token.length()>8192 or not master_clock.is_valid():return {}
 var parts=token.split(".")
 if parts.size()!=2:return {}
 var raw=Marshalls.base64_to_raw(parts[0]);var signature=Marshalls.base64_to_raw(parts[1])
 var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(raw)
 if not Crypto.new().verify(HashingContext.HASH_SHA256,hash.finish(),signature,public_key):return {}
 var parser=JSON.new()
 if parser.parse(raw.get_string_from_utf8())!=OK or not parser.data is Dictionary:return {}
 var value: Dictionary=parser.data
 if value.get("v",-1)!=1 or value.get("kind","")!=kind or value.get("match","")!=match_id or value.get("subject","")!=subject or value.get("authority","")!=host:return {}
 if typeof(value.get("epoch")) not in [TYPE_INT,TYPE_FLOAT] or float(value.epoch)!=float(wanted_epoch):return {}
 for field in ["issued","expires"]:
  if typeof(value.get(field)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value[field])):return {}
 var now=float(master_clock.call())
 if now<float(value.issued)-2 or now>=float(value.expires) or float(value.expires)-float(value.issued)>60:return {}
 return value
func on_control(event: Dictionary) -> void:
 # Caller MUST authenticate the coordinator TLS/WSS channel before this method.
 var revision=int(event.get("epoch",-1))
 match str(event.get("type","")):
  "freeze":
   if revision<=epoch:return
   epoch=revision;lease_until=0;continuity_until=0;pending_resume=false;freeze("Host migration")
  "host_offer":
   if revision<epoch:return
   var grant=str(event.get("grant",""));var proof=verify_grant(grant,"host_offer",revision,local_player,local_player)
   if proof.is_empty():return
   epoch=revision;authority=local_player;pending_resume=false;lease_until=0;freeze("Preparing player host")
   start_authority.emit(epoch,grant,str(event.get("restore","")))
  "connect":
   if revision<epoch:return
   var host=str(event.get("authority",""));var grant=str(event.get("grant",""));var proof=verify_grant(grant,"join",revision,local_player,host)
   if proof.is_empty() or not proof.get("extra") is Dictionary or not proof.extra.get("endpoint") is Dictionary:return
   epoch=revision;authority=host;pending_resume=false;lease_until=0;freeze("Connecting session")
   var checkpoint=proof.extra.get("checkpoint")
   handoff_requested.emit(proof.extra.endpoint,grant,local_player==authority,"" if checkpoint==null else str(checkpoint))
  "authority_lease":accept_lease(str(event.get("grant","")))
  "resume":
   if revision!=epoch:return
   pending_resume=true;try_resume()
  "failed":
   if revision<epoch:return
   epoch=revision;freeze("Match unavailable");return_to_queue.emit(str(event.get("reason","Match unavailable")))
func accept_lease(token: String) -> bool:
 var proof=verify_grant(token,"authority",epoch,authority,authority)
 if proof.is_empty():return false
 lease_until=maxf(lease_until,float(proof.expires));try_resume();return true
func try_resume() -> void:
 if pending_resume and float(master_clock.call())<lease_until:
  pending_resume=false;frozen=false;last_host_packet=Time.get_ticks_msec()/1000.0;resume_simulation.emit(epoch)
func accepts_gameplay(id: String,revision: int,principal: String) -> bool:
 return not frozen and id==match_id and revision==epoch and principal==authority and float(master_clock.call())<maxf(lease_until,continuity_until)
func observed_host_packet(id: String,revision: int,principal: String) -> bool:
 if not accepts_gameplay(id,revision,principal):return false
 last_host_packet=Time.get_ticks_msec()/1000.0;return true
func freeze(reason: String) -> void:
 frozen=true;freeze_simulation.emit(reason)
func _process(_delta: float) -> void:
 if frozen or not master_clock.is_valid():return
 var missing=local_player!=authority and Time.get_ticks_msec()/1000.0-last_host_packet>3
 if float(master_clock.call())>=maxf(lease_until,continuity_until) or missing:
  freeze("Waiting for session authority");report_unhealthy.emit(epoch)
