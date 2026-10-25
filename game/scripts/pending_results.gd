extends Node
const PATH="user://pending_match_results.json"
const LIMIT=16
var hub
var storage_path=PATH
var entries=[]
var completed={}
var next_at=0.0
func _ready():
	if FileAccess.file_exists(storage_path):
		var saved=FileAccess.get_file_as_string(storage_path)
		if saved.length()<=131072:
			var parsed=JSON.parse_string(saved)
			if parsed is Dictionary:
				if parsed.get("completed") is Dictionary and parsed.completed.size()<=32:completed=parsed.completed
				parsed=parsed.get("pending",[])
			if parsed is Array:
				for entry in parsed:
					if entry is Dictionary and entry.get("report") is Dictionary and entry.get("match") is String and entry.get("digest") is String and entry.get("created",0)>Time.get_unix_time_from_system()-86400:entries.append(entry)
	entries=entries.slice(maxi(0,entries.size()-LIMIT));next_at=hub.clock()+1
func enqueue(report: Dictionary):
	if hub.mm.custom_match():return
	var id=hub.session.match_id
	if id.is_empty():return
	if completed.has(hub.player_id+":"+id+":"+str(int(report.epoch))):return
	var digest=JSON.stringify(report).sha256_text()
	for entry in entries:
		if entry.get("owner","")==hub.player_id and entry.match==id and int(entry.report.epoch)==int(report.epoch):return
	entries.push_front({"owner":hub.player_id,"match":id,"digest":digest,"report":report,"created":Time.get_unix_time_from_system(),"attempts":0})
	if entries.size()>LIMIT:entries.pop_back()
	persist();next_at=hub.clock()
func _process(_delta):
	if entries.is_empty() or not hub.enabled or not hub.master_connected() or hub.clock()<next_at:return
	var eligible=entries.filter(func(e):return e.get("owner","")==hub.player_id)
	if eligible.is_empty():return
	var entry: Dictionary=eligible[0]
	var packet: Dictionary=entry.report.duplicate();packet.match_id=entry.match;packet.receipt=entry.digest
	hub.send(packet);entry.attempts=int(entry.get("attempts",0))+1
	next_at=hub.clock()+maxf(5,NestControlPolicy.retry_delay(int(entry.attempts),randf()))
func acknowledge(id: String, receipt: String):
	for entry in entries:
		if entry.get("owner","")==hub.player_id and entry.match==id and entry.digest==receipt:completed[hub.player_id+":"+id+":"+str(int(entry.report.epoch))]=Time.get_unix_time_from_system()
	while completed.size()>32:completed.erase(completed.keys()[0])
	entries=entries.filter(func(e):return not (e.get("owner","")==hub.player_id and e.match==id and e.digest==receipt));persist();next_at=hub.clock()+1
func persist():
	var file=FileAccess.open(storage_path+".tmp",FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify({"pending":entries,"completed":completed}));file.close();DirAccess.rename_absolute(storage_path+".tmp",storage_path)
