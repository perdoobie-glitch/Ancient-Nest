extends Node
var hub
var ticket=""
var cancel_pending=false
var pending=false
var next_at=0.0
var attempt=0
var generation=0
var request: HTTPRequest
var metrics={"requests":0,"failures":0,"retries":0,"latency_ms":0.0}
var sent_at=0.0
var sent_generation=0
var operation=""
func accept_ticket(value: String):
	if value==ticket:return
	generation+=1;request.cancel_request();pending=false;ticket=value;cancel_pending=false
func _ready():
	request=HTTPRequest.new();request.use_threads=true;request.timeout=float(NestControlPolicy.settings().request_timeout_seconds);request.body_size_limit=65536;request.max_redirects=0;add_child(request);request.request_completed.connect(completed)
func cancel_queue():
	generation+=1;request.cancel_request();pending=false;cancel_pending=true;next_at=hub.clock()
func _process(_delta):
	if not hub.enabled or hub.game.running or (hub.mm.phase!="queue" and not cancel_pending):
		if pending:request.cancel_request();pending=false;generation+=1
		return
	if hub.master_connected() and not cancel_pending:
		if pending:request.cancel_request();pending=false;generation+=1
		return
	if pending or ticket.is_empty() or hub.clock()<next_at:return
	operation="cancel" if cancel_pending else "status";pending=true;sent_generation=generation;sent_at=hub.clock();metrics.requests+=1
	var url=hub.hub_url.replace("wss://","https://").replace("ws://","http://").get_slice("/v1/",0)+"/v1/queue/status"
	var error=request.request(url,PackedStringArray(["Content-Type: application/json"]),HTTPClient.METHOD_POST,JSON.stringify({"ticket":ticket,"operation":operation}))
	if error!=OK:pending=false;failed(0,0)
func completed(result: int, code: int, headers: PackedStringArray, body: PackedByteArray):
	pending=false
	if sent_generation!=generation or not hub.enabled or hub.game.running:return
	if operation!="cancel" and hub.mm.phase!="queue":return
	metrics.latency_ms=(hub.clock()-sent_at)*1000
	if result!=HTTPRequest.RESULT_SUCCESS or code<200 or code>=300:
		var retry_after=0.0
		for header in headers:
			if header.to_lower().begins_with("retry-after:"):retry_after=parse_retry_after(header.substr(header.find(":")+1).strip_edges())
		failed(code,retry_after);return
	var data=JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary:failed(0,0);return
	attempt=0;next_at=hub.clock()+float(NestControlPolicy.settings().queue_fallback_seconds)
	if data.get("queue_token","") is String and str(data.get("queue_token","")).length()<=8192:ticket=str(data.get("queue_token",ticket))
	if operation=="cancel":cancel_pending=false;ticket="";return
	if data.get("state","")=="assigned":hub.mm.status="Match reserved · restoring secure push connection"
func failed(code: int, retry_after: float):
	metrics.failures+=1
	if code in [400,401,403,404,409,413,422]:ticket="";cancel_pending=false;hub.mm.status="Queue authorization expired · reconnect manually";return
	attempt+=1;metrics.retries+=1
	next_at=hub.clock()+maxf(float(NestControlPolicy.settings().queue_fallback_seconds),NestControlPolicy.retry_delay(attempt,randf(),retry_after))
static func parse_retry_after(value: String) -> float:
	if value.is_valid_float():return maxf(0,float(value))
	var words=value.replace(",","").split(" ",false)
	var months=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
	if words.size()!=6 or months.find(words[2])<0:return 0
	var date="%04d-%02d-%02dT%s"%[int(words[3]),months.find(words[2])+1,int(words[1]),words[4]]
	return maxf(0,Time.get_unix_time_from_datetime_string(date)-Time.get_unix_time_from_system())
