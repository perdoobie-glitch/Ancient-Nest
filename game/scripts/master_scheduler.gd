extends Node
var hub
var reconnecting=false
var permanent=false
var retry_at=0.0
var attempt=0
var next_ping=0.0
var next_heartbeat=0.0
var revision=0
var in_flight=0
var deadline=0.0
var status_signature=""
var status_due=0.0
var host_grant=""
var metrics={"heartbeats":0,"status_updates":0,"retries":0,"timeouts":0,"master_latency_ms":0.0}
var sent_at=0.0
func reset():
	reconnecting=false;permanent=false;retry_at=0;attempt=0;in_flight=0;host_grant="";status_signature="";status_due=0
	next_ping=hub.clock()+randf()*float(NestControlPolicy.settings().socket_keepalive_seconds)
	next_heartbeat=hub.clock()+randf()*float(NestControlPolicy.settings().host_heartbeat_seconds)
func lost(fatal: bool=false):
	if permanent:return
	permanent=fatal;hub.master_authenticated=false;hub.control_deadline=0
	if not reconnecting:
		reconnecting=true;hub.mm.status="Master offline · gameplay continues" if hub.game.running else "Master offline · reconnecting"
		if hub.game.running:hub.game.messages.append(hub.mm.status)
		else:hub.mm.phase="error";hub.mm.changed()
	if not fatal and retry_at<=0:
		retry_at=hub.clock()+NestControlPolicy.retry_delay(attempt,randf());attempt+=1
	if fatal:hub.mm.status="Master request rejected · sign in or reconnect manually";retry_at=0
func restored():
	reconnecting=false;permanent=false;retry_at=0;attempt=0;in_flight=0;hub.failure_reason=""
	next_ping=hub.clock()+float(NestControlPolicy.settings().socket_keepalive_seconds)
	status_due=hub.clock()
func _process(_delta):
	if not hub.enabled:return
	var at=hub.clock();var config=NestControlPolicy.settings()
	if hub.master_authenticated and at-hub.master_last_reply>float(config.socket_keepalive_seconds)+float(config.request_timeout_seconds):lost();hub.ws.close(4000,"Control timeout")
	if retry_at>0 and at>=retry_at and not permanent:
		retry_at=0;metrics.retries+=1
		hub.ws.close(4000,"Control reconnect");hub.ws=WebSocketPeer.new();hub.ws.inbound_buffer_size=2097152;hub.ws.outbound_buffer_size=2097152;hub.ws.max_queued_packets=128
		hub.hello_sent=false;hub.account_preflight=false;hub.control_deadline=at+float(config.request_timeout_seconds)
		if hub.ws.connect_to_url(hub.hub_url)!=OK:lost()
	if not hub.master_authenticated or hub.ws.get_ready_state()!=WebSocketPeer.STATE_OPEN:return
	var hosting=hub.authority and not hub.session.match_id.is_empty() and hub.mm.phase in ["playing","results"]
	var advertising=not hub.game.running and hub.mm.party.has("custom") and hub.mm.party_leader()
	var signature=str([hub.session.match_id,hub.session.epoch,hosting,advertising,hub.game.running,hub.game.finished,hub.authenticated.size(),hub.roster.size(),hub.mm.party.get("members",[]).size(),hub.mm.party.get("code","")])
	if signature!=status_signature:
		status_signature=signature;status_due=at+.2
	if in_flight>0 and at>=deadline:
		in_flight=0;metrics.timeouts+=1
		next_heartbeat=at+NestControlPolicy.retry_delay(attempt,randf());attempt+=1
	if (hosting or advertising) and in_flight==0 and (at>=next_heartbeat or (status_due>0 and at>=status_due)):
		if hosting and host_grant.is_empty():return
		revision=maxi(revision,int(hub.mm.party.get("revision",0)))+1;in_flight=revision;deadline=at+float(config.request_timeout_seconds);sent_at=at
		var periodic=at>=next_heartbeat
		if periodic:metrics.heartbeats+=1
		else:metrics.status_updates+=1
		var payload={"type":"heartbeat" if hosting else "lobby_heartbeat","revision":revision}
		if hosting:
			payload.merge({"match":hub.session.match_id,"epoch":hub.session.epoch,"grant":host_grant,"status":"finished" if hub.game.finished else "running","occupancy":hub.authenticated.size(),"capacity":hub.roster.size(),"live":{"scores":hub.game.scores,"elapsed":minf(10800,hub.game.now)}})
		hub.send(payload)
		if periodic:next_heartbeat=at+float(config.host_heartbeat_seconds)
		status_due=0
	elif not hosting and not advertising and at>=next_ping:
		next_ping=at+float(config.socket_keepalive_seconds);hub.ws.send_text("nest-ping")
func acknowledge(value: int):
	if value!=in_flight:return
	metrics.master_latency_ms=(hub.clock()-sent_at)*1000;in_flight=0;attempt=0
