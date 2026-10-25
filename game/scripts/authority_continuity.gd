extends Node
## During a master outage, a fresh signed majority can maintain the EXISTING
## epoch. It cannot elect a host, mint join tickets or authorize a new epoch.
var hub
var proofs={}
var keys={}
var next_at=0.0
var serial=0
var scope=""
func _process(_delta):
	if not hub.enabled or not hub.game.running or hub.session.frozen:return
	var current=hub.session.match_id+":"+str(hub.session.epoch)
	if scope!=current:scope=current;proofs.clear();keys.clear();hub.session.continuity_until=0
	var time=hub.server_time()
	if hub.clock()>=next_at and (not hub.master_connected() or hub.session.lease_until-time<10):
		next_at=hub.clock()+1;serial+=1
		var payload={"match":hub.session.match_id,"epoch":hub.session.epoch,"authority":hub.session.authority,"subject":hub.player_id,"issued":time,"expires":time+float(NestControlPolicy.settings().continuity_seconds),"sequence":serial}
		var raw=JSON.stringify(payload).to_utf8_buffer()
		var signature=Crypto.new().sign(HashingContext.HASH_SHA256,hub.sha(raw),hub.identity)
		var token=Marshalls.raw_to_base64(raw)+"."+Marshalls.raw_to_base64(signature)
		if hub.authority:
			if accept(token,hub.player_id):proof.rpc(token)
		elif hub.mm.can_send(1):ack.rpc_id(1,token)
	var deadlines=[]
	for entry in proofs.values():
		if float(entry.expires)>time:deadlines.append(float(entry.expires))
	deadlines.sort();deadlines.reverse()
	var majority=hub.roster.size()/2+1
	if deadlines.size()>=majority:hub.session.continuity_until=float(deadlines[majority-1])
func accept(token: String, wanted: String="") -> bool:
	if token.length()>1100:return false
	var parts=token.split(".")
	if parts.size()!=2:return false
	var raw=Marshalls.base64_to_raw(parts[0]);var value=JSON.parse_string(raw.get_string_from_utf8())
	if not value is Dictionary:return false
	var who=str(value.get("subject",""));var time=hub.server_time()
	if not hub.roster.has(who) or (not wanted.is_empty() and who!=wanted):return false
	if value.get("match","")!=hub.session.match_id or value.get("epoch",-1)!=hub.session.epoch or value.get("authority","")!=hub.session.authority:return false
	for field in ["issued","expires","sequence"]:
		if typeof(value.get(field)) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value[field])):return false
	if value.expires<=time or value.issued>time+2 or value.expires-value.issued>float(NestControlPolicy.settings().continuity_seconds)+.001:return false
	if proofs.has(who) and float(value.sequence)<=float(proofs[who].sequence):return false
	if not keys.has(who):
		var key=CryptoKey.new()
		if key.load_from_string(str(hub.roster[who].public_key),true)!=OK:return false
		keys[who]=key
	if not Crypto.new().verify(HashingContext.HASH_SHA256,hub.sha(raw),Marshalls.base64_to_raw(parts[1]),keys[who]):return false
	proofs[who]=value;return true
@rpc("any_peer","call_remote","unreliable",1)
func ack(token: String):
	if not hub.authority or hub.session.frozen:return
	var peer=multiplayer.get_remote_sender_id();var who=""
	for id in hub.authenticated:
		if int(hub.authenticated[id])==peer:who=str(id);break
	if not who.is_empty() and accept(token,who):proof.rpc(token)
@rpc("authority","call_remote","unreliable",1)
func proof(token: String):
	if not hub.authority and not hub.session.frozen:accept(token)
