class_name NestCloudPeer
extends Node
## Cloudflare coordinates identities and SDP/ICE only. Data channels carry game traffic.
var bridge
var ice_servers: Array=[]
var ice_policy="all"
var round_id=""
var epoch=0
var probing=false
var started=0.0
var reported=false
var probes={}
var probe_payloads: Array[PackedByteArray]=[]
var game_peers={}
var candidate_counts={}
var transport: WebRTCMultiplayerPeer
const CHANNELS=[MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED,MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED,MultiplayerPeer.TRANSFER_MODE_UNRELIABLE,MultiplayerPeer.TRANSFER_MODE_RELIABLE]
func clock() -> float:return Time.get_ticks_usec()/1000000.0
func configure(event: Dictionary) -> void:
 ice_policy=str(event.get("ice_policy",ice_policy));ice_servers=event.get("ice_servers",ice_servers);round_id=str(event.get("round",round_id));epoch=int(event.epoch)
func signal_peer(who: String,purpose: String,kind: String,data: Dictionary) -> void:
 bridge.send({"type":"rtc_signal","epoch":epoch,"round":round_id,"target":who,"purpose":purpose,"kind":kind,"data":data})
func connection(who: String,purpose: String) -> WebRTCPeerConnection:
 var created_epoch=epoch;var created_round=round_id
 var pc=WebRTCPeerConnection.new()
 if pc.initialize({"iceServers":ice_servers})!=OK:
  bridge.fail("Native WebRTC could not initialize. Extract the complete game ZIP including its libraries.");return null
 pc.session_description_created.connect(func(kind,sdp):
  if created_epoch!=epoch or created_round!=round_id:return
  pc.set_local_description(kind,sdp)
  var public_sdp=str(sdp)
  if ice_policy=="relay":
   var lines=PackedStringArray()
   for line in public_sdp.split("\n"):
    if line.begins_with("a=candidate:") and not line.contains(" typ relay"):continue
    lines.append(line)
   public_sdp="\n".join(lines)
  signal_peer(who,purpose,"sdp",{"type":kind,"sdp":public_sdp}))
 pc.ice_candidate_created.connect(func(media,index,candidate):
  if created_epoch!=epoch or created_round!=round_id:return
  var key=who+":"+purpose;candidate_counts[key]=int(candidate_counts.get(key,0))+1
  if ice_policy=="relay" and not str(candidate).contains(" typ relay"):return
  signal_peer(who,purpose,"ice",{"media":media,"index":index,"candidate":candidate}))
 return pc
func begin_probes(event: Dictionary) -> void:
 stop_probes();configure(event);prepare_probe_payloads();probing=true;reported=false;started=clock()
 for who in event.get("members",[]):
  if who==bridge.player_id:continue
  var pc=connection(who,"probe")
  if pc==null:return
  var channel=pc.create_data_channel("nest-probe-v2",{"negotiated":true,"id":41,"ordered":false,"maxRetransmits":0})
  if channel==null:bridge.fail("Unable to create connection measurement channel");return
  probes[who]={"pc":pc,"channel":channel,"open":0.0,"next_send":0.0,"last_send":0.0,"round":-1,"rtts":[],"bytes":0,"first":0.0,"last":0.0,"nonces":{},"seen":{}}
  if bridge.player_id<str(who):pc.create_offer()
func receive(event: Dictionary) -> void:
 if int(event.epoch)!=epoch or str(event.get("round",""))!=round_id:return
 var who=str(event.sender);var purpose=str(event.purpose);var pc: WebRTCPeerConnection
 if purpose=="probe":
  if not probes.has(who):return
  pc=probes[who].pc
 else:
  if transport==null:return
  if bridge.authority and event.kind=="sdp" and event.data.get("type","")=="offer" and game_peers.has(who):
   game_peers[who].close();game_peers.erase(who)
   var old_peer=int(bridge.roster[who].slot)
   if transport.has_peer(old_peer):transport.remove_peer(old_peer)
  if not game_peers.has(who):
   if not bridge.authority:return
   add_game_peer(who,int(bridge.roster[who].slot),false)
  if not game_peers.has(who):return
  pc=game_peers[who]
 var data: Dictionary=event.data
 if event.kind=="sdp":pc.set_remote_description(str(data.type),str(data.sdp))
 elif event.kind=="ice":pc.add_ice_candidate(str(data.media),int(data.index),str(data.candidate))
func start_host(event: Dictionary) -> Error:
 if not bool(bridge.game.prefs.values.get("allow_host",true)):return ERR_UNAUTHORIZED
 close_game();stop_probes();configure(event);transport=WebRTCMultiplayerPeer.new()
 var error=transport.create_server(CHANNELS)
 if error==OK:
  bridge.configure_auth();bridge.game.multiplayer.server_relay=false;bridge.game.multiplayer.multiplayer_peer=transport;bridge.game.network_active=true
 return error
func start_client(event: Dictionary) -> Error:
 close_game();stop_probes();configure(event);transport=WebRTCMultiplayerPeer.new()
 var error=transport.create_client(int(bridge.roster[bridge.player_id].slot),CHANNELS)
 if error!=OK:return error
 bridge.configure_auth();bridge.game.multiplayer.server_relay=false;bridge.game.multiplayer.multiplayer_peer=transport;bridge.game.network_active=true
 add_game_peer(bridge.session.authority,1,true)
 return OK
func add_game_peer(who: String,id: int,offer: bool) -> void:
 var pc=connection(who,"game")
 if pc==null:return
 if transport.add_peer(pc,id,150)!=OK:pc.close();bridge.fail("Unable to add gameplay connection");return
 game_peers[who]=pc
 if offer:pc.create_offer()
func close_game() -> void:
 for pc in game_peers.values():pc.close()
 game_peers.clear()
 if transport!=null:transport.close();transport=null
func stop_probes() -> void:
 probing=false
 for entry in probes.values():entry.pc.close()
 probes.clear()
func stop() -> void:stop_probes();close_game()
func prepare_probe_payloads() -> void:
 if not probe_payloads.is_empty():return
 # Reuse fixed-size binary bandwidth samples; padding needs no JSON parsing.
 # Keep the same packet volume and pacing, so admission thresholds stay real.
 for sequence in range(200):
  var bytes=PackedByteArray();bytes.resize(1188);bytes.fill(0)
  bytes[0]=161;bytes[1]=sequence;probe_payloads.append(bytes)
func record_probe_data(entry: Dictionary,bytes: PackedByteArray,time: float) -> bool:
 if bytes.size()!=1188 or bytes[0]!=161:return false
 var sequence=int(bytes[1])
 if sequence>=200 or entry.seen.has(sequence):return false
 entry.seen[sequence]=true;entry.bytes+=bytes.size()
 if float(entry.first)==0:entry.first=time
 entry.last=time
 return true
func _process(_delta: float) -> void:
 if not probing or reported:return
 var time=clock();var finished=true
 for who in probes:
  var entry=probes[who];var pc: WebRTCPeerConnection=entry.pc;pc.poll()
  var channel: WebRTCDataChannel=entry.channel
  if channel.get_ready_state()!=WebRTCDataChannel.STATE_OPEN:
   finished=false;continue
  if float(entry.open)==0:entry.open=time+.35;entry.next_send=entry.open
  if time<float(entry.open):
   finished=false;continue
  while channel.get_available_packet_count()>0:
   var bytes=channel.get_packet()
   if bytes.is_empty() or bytes.size()>1500:continue
   if bytes[0]==161:
    record_probe_data(entry,bytes,time);continue
   var packet=JSON.parse_string(bytes.get_string_from_utf8())
   if not packet is Dictionary:continue
   var kind=str(packet.get("type",""))
   if kind=="ping":channel.put_packet(JSON.stringify({"type":"echo","nonce":packet.get("nonce","")}).to_utf8_buffer())
   elif kind=="echo":
    var nonce=str(packet.get("nonce",""))
    if entry.nonces.has(nonce):entry.rtts.append((time-float(entry.nonces[nonce]))*1000);entry.nonces.erase(nonce)
  if time>=float(entry.next_send) and int(entry.round)<49:
   var index=int(entry.round)+1;entry.round=index;entry.next_send=time+.03;entry.last_send=time;var nonce=str(Time.get_ticks_usec());entry.nonces[nonce]=time
   channel.put_packet(JSON.stringify({"type":"ping","nonce":nonce}).to_utf8_buffer())
   for i in range(4):channel.put_packet(probe_payloads[index*4+i])
  if int(entry.round)<49 or time-float(entry.last_send)<.35:finished=false
 if not finished and time-started<15:return
 reported=true
 var routes={}
 if OS.has_environment("NEST_QA_VERBOSE"):
  for who in probes:print("RTC_PROBE_QA epoch=",epoch," state=",probes[who].pc.get_connection_state()," gathering=",probes[who].pc.get_gathering_state()," candidates=",candidate_counts.get(str(who)+":probe",0))
 for who in probes:
  var entry=probes[who];routes[who]={"rtts":entry.rtts,"bytes":int(entry.bytes),"seconds":maxf(.1,float(entry.last)-float(entry.first))}
 bridge.send({"type":"telemetry","epoch":epoch,"round":round_id,"routes":routes,"host_capacity":bridge.host_capacity()})
