class_name NestFilmArchive
extends RefCounted
## Safe primitive-only, independently compressed blocks. Never deserialize objects.
const ROOT="user://films"
const MAGIC="NESTFILM2\n"
const MAX_FILE=256*1024*1024
const MAX_BLOCK=2*1024*1024
const MAX_TRACK=32*1024*1024
const MAX_SECONDS=3600
const SAMPLE_HZ=29.0
const RETENTION_SECONDS=7*86400
const TOTAL_BUDGET=2*1024*1024*1024
static func digest(bytes: PackedByteArray) -> PackedByteArray:
	var context=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes);return context.finish()
static func valid_id(id: String) -> bool:
	return id.length()==32 and id.is_valid_hex_number(false)
static func path(id: String, track: bool=false) -> String:
	return ROOT+"/"+id+(".track" if track else ".nestfilm")
static func write_block(job: Dictionary) -> Dictionary:
	var started=Time.get_ticks_usec()
	if job.get("finalize",false):
		DirAccess.make_dir_recursive_absolute(ROOT)
		var png: PackedByteArray=job.get("preview_png",PackedByteArray())
		if not png.is_empty() and png.size()<1024*1024:
			var picture=FileAccess.open(ROOT+"/"+job.id+".png",FileAccess.WRITE)
			if picture!=null:picture.store_buffer(png);picture.close()
		var summary=FileAccess.open(ROOT+"/"+job.id+".json",FileAccess.WRITE)
		if summary==null:return {"error":"Cannot finalize film listing"}
		summary.store_string(JSON.stringify(job.summary));summary.close()
		return {"bytes":png.size(),"worker_us":Time.get_ticks_usec()-started}
	var raw=var_to_bytes(job.payload)
	if raw.size()>MAX_BLOCK:return {"error":"Recording block exceeds limit"}
	var encoded=raw.compress(FileAccess.COMPRESSION_DEFLATE)
	var filename=path(job.id,bool(job.get("track",false)))
	DirAccess.make_dir_recursive_absolute(ROOT)
	var exists=FileAccess.file_exists(filename)
	if not exists:cleanup(job.id)
	var f=FileAccess.open(filename,FileAccess.READ_WRITE if exists else FileAccess.WRITE_READ)
	if f==null:return {"error":"Cannot write film"}
	if not exists:f.store_buffer(MAGIC.to_utf8_buffer())
	f.seek_end()
	var limit=MAX_TRACK if job.get("track",false) else MAX_FILE
	if f.get_position()+encoded.size()+36>limit:f.close();return {"error":"Film retention size limit reached"}
	f.store_32(encoded.size());f.store_buffer(digest(encoded));f.store_buffer(encoded)
	f.flush();f.close()
	return {"bytes":encoded.size()+36,"raw_bytes":raw.size(),"worker_us":Time.get_ticks_usec()-started}
static func read(filename: String) -> Dictionary:
	var f=FileAccess.open(filename,FileAccess.READ)
	if f==null or f.get_length()>MAX_FILE:return {"error":"Film missing or too large"}
	if f.get_buffer(MAGIC.length()).get_string_from_utf8()!=MAGIC:return {"error":"Unsupported film format"}
	var result={"metadata":{},"frames":[],"tracks":{},"events":{},"bytes":f.get_length()}
	var count=0
	var decoded_total=0
	var end=f.get_length()
	while f.get_position()<end:
		if end-f.get_position()<36:result.partial=true;break
		var length=f.get_32();var digest=f.get_buffer(32)
		if length<1 or length>MAX_BLOCK:return {"error":"Invalid film block length"}
		if length>end-f.get_position():result.partial=true;break
		var encoded=f.get_buffer(length)
		if NestFilmArchive.digest(encoded)!=digest:return {"error":"Damaged film block"}
		var raw=encoded.decompress_dynamic(MAX_BLOCK,FileAccess.COMPRESSION_DEFLATE)
		if raw.is_empty():return {"error":"Invalid compressed film block"}
		decoded_total+=raw.size()
		if decoded_total>512*1024*1024:return {"error":"Decoded film exceeds memory budget"}
		var block=bytes_to_var(raw)
		if not valid_block(block):return {"error":"Invalid film content"}
		if block.has("metadata"):result.metadata=block.metadata
		result.frames.append_array(block.get("frames",[]))
		var owner=str(block.get("owner",""))
		if not owner.is_empty():
			if not result.tracks.has(owner):
				if result.tracks.size()>=10:return {"error":"Too many perspective tracks"}
				result.tracks[owner]=[];result.events[owner]=[]
			result.tracks[owner].append_array(block.get("views",[]));result.events[owner].append_array(block.get("events",[]))
		count+=1
		if count>40000 or result.frames.size()>110000:return {"error":"Film sample limit reached"}
	f.close()
	for owner in result.tracks:
		if result.tracks[owner].size()>110000:return {"error":"Perspective sample limit reached"}
		result.tracks[owner].sort_custom(func(a,b):return float(a.t)<float(b.t))
		result.events[owner].sort_custom(func(a,b):return float(a.t)<float(b.t))
	result.frames.sort_custom(func(a,b):return float(a.t)<float(b.t))
	return result
static func valid_block(block: Variant) -> bool:
	if not block is Dictionary:return false
	for key in ["views","frames","events"]:
		var entries=block.get(key,[])
		if not entries is Array or entries.size()>120:return false
		for entry in entries:
			if not entry is Dictionary or not entry.get("t") is float or not is_finite(entry.t) or entry.t<0 or entry.t>MAX_SECONDS:return false
			if key=="frames" and not valid_frame(entry):return false
	if block.has("metadata"):
		if not block.metadata is Dictionary or not valid_id(str(block.metadata.get("id",""))) or not block.metadata.get("roster",{}) is Dictionary or block.metadata.roster.size()>10:return false
	return str(block.get("owner","")).length()<=128
static func valid_frame(frame: Dictionary) -> bool:
	var state=frame.get("state")
	if not state is Array or state.size()!=2 or not state[0] is Dictionary or not state[1] is Array or state[1].size()>10:return false
	for record in state[1]:
		if not record is Dictionary:return false
		for key in ["id","life","slot"]:
			if not record.get(key) is int:return false
		for key in ["pos","velocity"]:
			if not record.get(key) is Vector3 or not record[key].is_finite():return false
		for key in ["yaw","pitch","health","shield","armor","over","respawn","action_until"]:
			if typeof(record.get(key)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(record[key])):return false
		for key in ["weapons","ammo","reserve","grenades"]:
			if not record.get(key) is Array or record[key].size()>4:return false
		if record.weapons.is_empty() or record.ammo.size()!=record.weapons.size() or record.reserve.size()!=record.weapons.size():return false
	return true
static func events_between(events: Array, from: float, to: float) -> Array:
	var low=0;var high=events.size()
	while low<high:
		var mid=(low+high)/2
		if float(events[mid].t)<=from:low=mid+1
		else:high=mid
	var found=[]
	while low<events.size() and float(events[low].t)<=to:found.append(events[low]);low+=1
	return found
static func sample_pair(samples: Array, time: float) -> Dictionary:
	if samples.is_empty() or time<float(samples[0].t):return {"available":false,"reason":"Player had not joined / recording had not started"}
	var low=0;var high=samples.size()-1
	while low<high:
		var mid=(low+high+1)/2
		if float(samples[mid].t)<=time:low=mid
		else:high=mid-1
	var a: Dictionary=samples[low];var b: Dictionary=samples[mini(low+1,samples.size()-1)]
	if time-float(a.t)>.5:return {"available":false,"reason":"Disconnected or perspective recording gap"}
	var f=clampf((time-float(a.t))/maxf(.00001,float(b.t)-float(a.t)),0,1)
	if float(b.t)-float(a.t)>.25 or a.get("life",0)!=b.get("life",0):f=0
	return {"available":true,"a":a,"b":b,"fraction":f}
static func cleanup(except_id: String="") -> void:
	var dir=DirAccess.open(ROOT)
	if dir==null:return
	var groups={};var total=0
	for name in dir.get_files():
		var id=name.get_basename()
		if not valid_id(id) or name.get_extension() not in ["nestfilm","track","json","png"]:continue
		var filename=ROOT+"/"+name;var f=FileAccess.open(filename,FileAccess.READ)
		if f==null:continue
		var bytes=f.get_length();f.close();total+=bytes
		if not groups.has(id):groups[id]={"id":id,"bytes":0,"at":FileAccess.get_modified_time(filename),"files":[]}
		groups[id].bytes+=bytes;groups[id].files.append(filename)
	var ordered=groups.values();ordered.sort_custom(func(a,b):return a.at<b.at)
	for group in ordered:
		if group.id==except_id:continue
		if Time.get_unix_time_from_system()-float(group.at)<=RETENTION_SECONDS and total<=TOTAL_BUDGET:continue
		for filename in group.files:DirAccess.remove_absolute(filename)
		total-=int(group.bytes)
