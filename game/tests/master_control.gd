extends SceneTree
class FakeSocket extends RefCounted:
	var packets=[]
	func get_ready_state():return WebSocketPeer.STATE_OPEN
	func send_text(value):packets.append(value)
	func close(_code=1000,_reason=""):pass
class FakeGame extends RefCounted:
	var running=true
	var finished=false
	var network_active=true
	var scores=[0,0]
	var now=0.0
	var messages=[]
class FakeMM extends RefCounted:
	var phase="playing"
	var party={}
	func party_leader():return true
	func changed():pass
	func custom_match():return false
class FakeHub extends RefCounted:
	var enabled=true
	var authority=true
	var master_authenticated=true
	var master_last_reply=0.0
	var control_deadline=0.0
	var failure_reason=""
	var player_id="host"
	var time=0.0
	var records=[]
	var ws=FakeSocket.new()
	var game=FakeGame.new()
	var mm=FakeMM.new()
	var session=NestHybridSession.new()
	var authenticated={"host":1,"peer":2}
	var roster={"host":{},"peer":{}}
	func _init():session.match_id="match";session.epoch=1;session.authority="host"
	func clock():return time
	func server_time():return time
	func send(packet):records.append(packet.duplicate(true))
	func master_connected():return master_authenticated
	func sha(bytes):return NestFilmArchive.digest(bytes)
var failures=0
var checks=0
func check(ok: bool,message: String):
	checks+=1;print(("PASS " if ok else "FAIL ")+message)
	if not ok:failures+=1
func _initialize():call_deferred("run")
func run():
	var hub=FakeHub.new();var scheduler=load("res://scripts/master_scheduler.gd").new();scheduler.hub=hub;scheduler.reset();scheduler.host_grant="fixture-grant";scheduler.next_heartbeat=20
	for tick in range(601):
		hub.time=float(tick)/10;hub.master_last_reply=hub.time;scheduler._process(.1)
		if scheduler.in_flight>0:scheduler.acknowledge(scheduler.in_flight)
	check(scheduler.metrics.heartbeats==3,"Fake clock: one host emits three periodic heartbeats per minute")
	check(scheduler.metrics.status_updates==1,"Initial availability is sent promptly, independently of periodic cadence")
	var before=int(scheduler.metrics.status_updates)
	for tick in range(610,616):
		hub.time=float(tick)/10;hub.master_last_reply=hub.time
		if tick<613:hub.authenticated[str(tick)]=tick
		scheduler._process(.1)
		if scheduler.in_flight>0:scheduler.acknowledge(scheduler.in_flight)
	check(int(scheduler.metrics.status_updates)==before+1,"Burst occupancy changes coalesce into one status update")
	var peer=FakeHub.new();peer.authority=false
	var joining=load("res://scripts/master_scheduler.gd").new();joining.hub=peer;joining.reset()
	for tick in range(601):peer.time=float(tick)/10;peer.master_last_reply=peer.time;joining._process(.1)
	check(joining.metrics.heartbeats==0 and peer.records.is_empty(),"Joining clients do not duplicate match heartbeats")
	check(peer.ws.packets.size()<=4,"Non-host keepalive remains bounded and separate")
	var failed=FakeHub.new();var retry=load("res://scripts/master_scheduler.gd").new();retry.hub=failed;retry.reset();retry.host_grant="fixture"
	for tick in range(1201):failed.time=float(tick)/10;failed.master_last_reply=failed.time;retry._process(.1)
	check(failed.records.size()<16,"Missing acknowledgements do not create per-frame request storms")
	check(NestControlPolicy.retry_delay(99,1)==30 and NestControlPolicy.retry_delay(99,0)<=30,"Backoff cap remains thirty seconds")
	check(load("res://scripts/queue_fallback.gd").parse_retry_after("120")==120,"Retry-After can exceed the normal jitter cap")
	var result_store=load("res://scripts/pending_results.gd").new();result_store.hub=hub;result_store.storage_path="user://qa_results_"+Crypto.new().generate_random_bytes(8).hex_encode()+".json";root.add_child(result_store)
	var report={"type":"result_report","epoch":1,"players":[],"winner_team":null}
	result_store.enqueue(report);result_store.enqueue(report)
	check(result_store.entries.size()==1,"Repeated end-of-match reports occupy one durable queue entry")
	var receipt=str(result_store.entries[0].digest);result_store.acknowledge("match",receipt);result_store.enqueue(report)
	check(result_store.entries.is_empty(),"Acknowledged results are not re-enqueued every second")
	var reopened=load("res://scripts/pending_results.gd").new();reopened.hub=hub;reopened.storage_path=result_store.storage_path;root.add_child(reopened);reopened.enqueue(report)
	check(reopened.entries.is_empty(),"Result idempotency survives reopening the local journal")
	DirAccess.remove_absolute(result_store.storage_path);result_store.free();reopened.free()
	var quorum=load("res://scripts/authority_continuity.gd").new();quorum.hub=hub;quorum.scope="match:1";quorum.next_at=INF
	hub.time=100;hub.roster={};var private_keys={}
	for who in ["host","peer","third"]:
		var key=Crypto.new().generate_rsa(2048);private_keys[who]=key;hub.roster[who]={"public_key":key.save_to_string(true)}
	hub.session.frozen=false;hub.session.lease_until=99;hub.session.master_clock=hub.server_time;hub.session.last_host_packet=Time.get_ticks_msec()/1000.0
	for who in ["host","peer"]:
		var raw=JSON.stringify({"match":"match","epoch":1,"authority":"host","subject":who,"issued":100.0,"expires":105.0,"sequence":1}).to_utf8_buffer()
		var token=Marshalls.raw_to_base64(raw)+"."+Marshalls.raw_to_base64(Crypto.new().sign(HashingContext.HASH_SHA256,hub.sha(raw),private_keys[who]))
		check(quorum.accept(token,who),"Continuity proof verifies participant signature: "+who)
		check(not quorum.accept(token,who),"Duplicate continuity proof is rejected")
	quorum._process(0)
	check(hub.session.accepts_gameplay("match",1,"host"),"Signed majority preserves existing gameplay after master lease expiry")
	check(not hub.session.accepts_gameplay("other",1,"host") and not hub.session.accepts_gameplay("match",2,"host"),"Continuity cannot authorize another match or new epoch")
	hub.time=106;hub.session._process(0)
	check(hub.session.frozen,"Expired majority continuity cannot keep an isolated host active")
	for object in [scheduler,joining,retry,quorum,hub.session,peer.session,failed.session]:object.free()
	print("MASTER CONTROL: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
