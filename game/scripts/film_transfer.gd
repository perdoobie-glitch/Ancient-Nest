extends Node
## Match participants only; post-match, rate-bounded, independent reliable channel.
const CHUNK=850
const BYTES_PER_SECOND=262144
var recorder
var offered=false
var incoming={}
var outgoing=[]
var tokens=0.0
var retry_at=0.0
var io: Thread
var io_kind=""
var io_context={}
var completed={}
var host_finished=false
var rate_limit=BYTES_PER_SECOND
var metrics={"upload_bytes":0,"download_bytes":0,"rejected":0}
func game():return recorder.game
func allowed(id: String) -> bool:
	return id==recorder.id and NestFilmArchive.valid_id(id) and recorder.ended and game().network_active
func pending_work() -> bool:
	if not recorder.ended:return false
	if io!=null or not incoming.is_empty() or not outgoing.is_empty() or not recorder.received_queue.is_empty() or not recorder.queue.is_empty() or recorder.worker!=null:return true
	if not offered:return true
	if not game().multiplayer.is_server():return not host_finished
	for peer in game().multiplayer.get_peers():
		var who=recorder.peer_identity(peer)
		if not who.is_empty() and not completed.has(who):return true
	if not host_finished:transfer_done.rpc(recorder.id);host_finished=true
	return false
@rpc("authority","call_remote","reliable",4)
func transfer_done(id: String):
	if allowed(id):host_finished=true
func _process(delta):
	if io!=null and not io.is_alive():
		var result=io.wait_to_finish();io=null
		if io_context.get("id",recorder.id)!=recorder.id:io_context={};return
		if io_kind=="load":
			if result is PackedByteArray and result.size()>0 and result.size()<=NestFilmArchive.MAX_TRACK:
				if game().multiplayer.is_server():relay_bytes(recorder.track_owner,result)
				else:request_upload.rpc_id(1,recorder.id,result.size(),NestFilmArchive.digest(result));outgoing.append({"peer":1,"owner":recorder.track_owner,"bytes":result,"nonce":-1,"offset":0,"index":0})
		elif result is Dictionary and not result.has("error") and result.get("validated",false):
			var who=str(io_context.owner)
			recorder.append_received_track(who,result.blocks);completed[who]=true
			if game().multiplayer.is_server():relay_bytes(who,io_context.bytes)
		else:metrics.rejected+=1
		io_context={}
	if not recorder.ended or not game().network_active:return
	if not game().film_retaining_transport and game().match_session!=recorder.session:return
	if game().multiplayer.multiplayer_peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED:return
	if game().running and not game().finished and not game().replay_active:return
	if not offered and recorder.worker==null and recorder.queue.is_empty() and io==null and game().local_clock()>=retry_at:
			offered=true;io_kind="load";io_context={"id":recorder.id};io=Thread.new();io.start(load_bytes.bind(NestFilmArchive.path(recorder.id,true)))
	for peer in incoming.keys():
		if game().local_clock()-float(incoming[peer].at)>15:incoming.erase(peer);metrics.rejected+=1
	tokens=minf(maxf(CHUNK*2,rate_limit),tokens+delta*rate_limit)
	if outgoing.is_empty():return
	var item: Dictionary=outgoing[0]
	if not game().multiplayer.get_peers().has(int(item.peer)):outgoing.pop_front();return
	if game().matchmaking.hybrid.enabled and not game().matchmaking.can_send(int(item.peer)):return
	if not bool(item.get("ready",false)):
		if game().local_clock()>=float(item.get("offer_at",0)):
			item.offer_at=game().local_clock()+2
			if game().multiplayer.is_server():download_offer.rpc_id(item.peer,recorder.id,item.owner,item.bytes.size(),NestFilmArchive.digest(item.bytes),item.nonce)
			else:request_upload.rpc_id(1,recorder.id,item.bytes.size(),NestFilmArchive.digest(item.bytes))
		return
	if not game().multiplayer.get_peers().has(int(item.peer)):outgoing.pop_front();return
	var sent_this_frame=0
	while tokens>=CHUNK and int(item.offset)<item.bytes.size() and sent_this_frame<8:
		var data: PackedByteArray=item.bytes.slice(item.offset,mini(item.offset+CHUNK,item.bytes.size()))
		if game().multiplayer.is_server():download_chunk.rpc_id(item.peer,recorder.id,item.owner,item.nonce,item.index,data)
		else:upload_chunk.rpc_id(1,recorder.id,item.nonce,item.index,data)
		item.offset+=data.size();item.index+=1;tokens-=data.size();metrics.upload_bytes+=data.size()
		sent_this_frame+=1
	if int(item.offset)>=item.bytes.size():outgoing.pop_front()
static func load_bytes(filename: String) -> PackedByteArray:
	var f=FileAccess.open(filename,FileAccess.READ)
	if f==null or f.get_length()>NestFilmArchive.MAX_TRACK:return PackedByteArray()
	return f.get_buffer(f.get_length())
static func decode_track(bytes: PackedByteArray, stage: String) -> Dictionary:
	var f=FileAccess.open(stage,FileAccess.WRITE)
	if f==null:return {"error":"Cannot stage perspective"}
	f.store_buffer(bytes);f.close()
	var result=NestFilmArchive.read(stage);DirAccess.remove_absolute(stage)
	if result.has("error") or result.tracks.size()!=1:return {"error":"Invalid perspective archive"}
	var samples: Array=result.tracks.values()[0];var events: Array=result.events.values()[0]
	if not valid_views(samples):return {"error":"Invalid perspective samples"}
	var blocks=[];var cursor=0
	for start in range(0,samples.size(),29):
		var selected=samples.slice(start,mini(start+29,samples.size()));var high=float(selected[-1].t)+1.0/29;var selected_events=[]
		while cursor<events.size() and float(events[cursor].t)<high:
			if selected_events.size()<120:selected_events.append(events[cursor])
			cursor+=1
		blocks.append({"views":selected,"events":selected_events})
	return {"validated":true,"blocks":blocks}
func new_incoming(key: String, who: String, size: int, hash: PackedByteArray, nonce: int) -> bool:
	if size<1 or size>NestFilmArchive.MAX_TRACK or hash.size()!=32 or not incoming.is_empty() or io!=null:return false
	if game().multiplayer.is_server() and not outgoing.is_empty():return false
	if not recorder.received_queue.is_empty():return false
	if completed.has(who) or incoming.has(key):return false
	incoming[key]={"owner":who,"size":size,"hash":hash,"nonce":nonce,"bytes":PackedByteArray(),"index":0,"at":game().local_clock()};return true
@rpc("any_peer","call_remote","reliable",4)
func request_upload(id: String, size: int, hash: PackedByteArray):
	if not allowed(id) or not game().multiplayer.is_server():return
	var peer=multiplayer.get_remote_sender_id();var who=recorder.peer_identity(peer)
	if who.is_empty() or not recorder.metadata.roster.has(who):metrics.rejected+=1;return
	if incoming.has(str(peer)):accept_upload.rpc_id(peer,id,int(incoming[str(peer)].nonce));return
	var nonce=randi_range(1,2147483647)
	if new_incoming(str(peer),who,size,hash,nonce):accept_upload.rpc_id(peer,id,nonce)
@rpc("authority","call_remote","reliable",4)
func accept_upload(id: String, nonce: int):
	if not allowed(id) or game().multiplayer.is_server():return
	for item in outgoing:
		if int(item.peer)==1 and int(item.nonce)<0:item.nonce=nonce;item.ready=true;return
@rpc("any_peer","call_remote","reliable",4)
func upload_chunk(id: String, nonce: int, index: int, bytes: PackedByteArray):
	if not allowed(id) or not game().multiplayer.is_server():return
	receive_chunk(str(multiplayer.get_remote_sender_id()),nonce,index,bytes)
func receive_chunk(key: String, nonce: int, index: int, bytes: PackedByteArray):
	if not incoming.has(key):metrics.rejected+=1;return
	var item: Dictionary=incoming[key]
	if nonce!=int(item.nonce) or index!=int(item.index) or bytes.is_empty() or bytes.size()>CHUNK or item.bytes.size()+bytes.size()>int(item.size):incoming.erase(key);metrics.rejected+=1;return
	item.bytes.append_array(bytes);item.index+=1;item.at=game().local_clock();metrics.download_bytes+=bytes.size()
	if item.bytes.size()!=int(item.size):return
	incoming.erase(key)
	if io!=null or NestFilmArchive.digest(item.bytes)!=item.hash:metrics.rejected+=1;return
	io_kind="decode";io_context={"id":recorder.id,"owner":item.owner,"bytes":item.bytes}
	var stage_id=NestFilmArchive.digest((recorder.id+":"+str(item.owner)).to_utf8_buffer()).hex_encode().substr(0,32)
	io=Thread.new();io.start(decode_track.bind(item.bytes,NestFilmArchive.path(stage_id,true)))
func relay_bytes(who: String, bytes: PackedByteArray):
	if bytes.is_empty():return
	for peer in game().multiplayer.get_peers():
		if recorder.peer_identity(peer)==who:continue
		var nonce=randi_range(1,2147483647)
		outgoing.append({"peer":peer,"owner":who,"bytes":bytes,"nonce":nonce,"offset":0,"index":0})
@rpc("authority","call_remote","reliable",4)
func download_offer(id: String, who: String, size: int, hash: PackedByteArray, nonce: int):
	if not allowed(id) or game().multiplayer.is_server() or not recorder.metadata.roster.has(who) or who==recorder.track_owner:return
	if incoming.has(who) or new_incoming(who,who,size,hash,nonce):accept_download.rpc_id(1,id,who,nonce)
@rpc("any_peer","call_remote","reliable",4)
func accept_download(id: String, who: String, nonce: int):
	if not allowed(id) or not game().multiplayer.is_server() or outgoing.is_empty():return
	var item: Dictionary=outgoing[0]
	if int(item.peer)==multiplayer.get_remote_sender_id() and item.owner==who and int(item.nonce)==nonce:item.ready=true
@rpc("authority","call_remote","reliable",4)
func download_chunk(id: String, who: String, nonce: int, index: int, bytes: PackedByteArray):
	if not allowed(id) or game().multiplayer.is_server():return
	receive_chunk(who,nonce,index,bytes)
static func valid_views(samples: Array) -> bool:
	if samples.is_empty() or samples.size()>110000:return false
	var previous=-1.0
	for sample in samples:
		if not sample is Dictionary or not sample.get("camera") is Transform3D or not sample.camera.is_finite() or not sample.get("actor") is Dictionary:return false
		if not sample.get("t") is float or sample.t<previous or sample.t<0 or sample.t>NestFilmArchive.MAX_SECONDS:return false
		if not sample.get("fov") is float or not is_finite(sample.fov) or sample.fov<1 or sample.fov>179:return false
		if not sample.get("weapon_nodes",[]) is Array or sample.get("weapon_nodes",[]).size()>512:return false
		if not sample.get("rendered",[]) is Array or sample.get("rendered",[]).size()>10:return false
		if not sample.get("contacts",[]) is Array or sample.get("contacts",[]).size()>64:return false
		for field in sample.actor:
			if field not in NestFilmRecorder.ACTOR_FIELDS:return false
			var value=sample.actor[field]
			if value is float and not is_finite(value):return false
			if value is Vector2 and not value.is_finite():return false
			if value is Array and value.size()>64:return false
		for pose in sample.get("weapon_nodes",[]):
			if not pose is Dictionary or not pose.get("xf") is Transform3D or not pose.xf.is_finite() or not pose.get("path") is Array or pose.path.size()>16:return false
			for index in pose.path:
				if not index is int or index<0 or index>512:return false
		for rendered in sample.get("rendered",[]):
			if not rendered is Dictionary or not rendered.get("id") is int or not rendered.get("xf") is Transform3D or not rendered.xf.is_finite():return false
		for contact in sample.get("contacts",[]):
			if not contact is Dictionary or not contact.get("pos") is Vector3 or not contact.pos.is_finite() or not contact.get("friend") is bool or not contact.get("seen") is float or not is_finite(contact.seen):return false
		previous=sample.t
	return true
func _exit_tree():
	if io!=null:io.wait_to_finish()
