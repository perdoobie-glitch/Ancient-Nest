class_name NestGameTypeLibrary
extends RefCounted
# Named rules are local data files, separate from the automatically saved lobby.
const DIRECTORY="user://gametypes/saved"
const FORMAT="ancient_nest_game_type"
const VERSION=1
const MAX_FILE_BYTES=262144
static func valid_id(id: String) -> bool:
 return id.length()==24 and id.is_valid_hex_number(false)
static func read_entry(id: String) -> Dictionary:
 if not valid_id(id):return {}
 var file=FileAccess.open(DIRECTORY+"/"+id+".json",FileAccess.READ)
 if file==null or file.get_length()>MAX_FILE_BYTES:return {}
 var json=JSON.new()
 if json.parse(file.get_as_text())!=OK:return {}
 var parsed=json.data
 if not parsed is Dictionary or parsed.get("format","")!=FORMAT or parsed.get("version",0)!=VERSION or not parsed.get("settings") is Dictionary:return {}
 var name=parsed.settings.get("game_type_name","")
 if not name is String or name.strip_edges().is_empty() or name.length()>48:return {}
 return {"id":id,"name":name,"settings":parsed.settings}
static func list_saved() -> Array[Dictionary]:
 var result: Array[Dictionary]=[]
 var directory=DirAccess.open(DIRECTORY)
 if directory==null:return result
 for name in directory.get_files():
  if name.get_extension()!="json":continue
  var entry=read_entry(name.get_basename())
  if not entry.is_empty():result.append(entry)
 result.sort_custom(func(a,b):return String(a.name).naturalnocasecmp_to(String(b.name))<0)
 return result
static func save_new(settings: GameTypeSettings, proposed_name: String) -> Dictionary:
 var name=proposed_name.strip_edges()
 if name.is_empty():return {"ok":false,"message":"Enter a name for the new game type."}
 if name.length()>48:return {"ok":false,"message":"Use a name with 48 characters or fewer."}
 for entry in list_saved():
  if String(entry.name).nocasecmp_to(name)==0:return {"ok":false,"message":"That name is already saved. Choose a different name to create a new game type."}
 var error=DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
 if error!=OK:return {"ok":false,"message":"Couldn't create the saved game types folder."}
 var id=Crypto.new().generate_random_bytes(12).hex_encode()
 var path=DIRECTORY+"/"+id+".json"
 while FileAccess.file_exists(path):
  id=Crypto.new().generate_random_bytes(12).hex_encode();path=DIRECTORY+"/"+id+".json"
 var saved=settings.duplicate_settings();saved.game_type_name=name;saved.validate()
 var file=FileAccess.open(path,FileAccess.WRITE)
 if file==null:return {"ok":false,"message":"Couldn't save this game type. Check available storage and file permissions."}
 file.store_string(JSON.stringify({"format":FORMAT,"version":VERSION,"settings":saved.to_network_dict()},"  "));file.flush()
 var write_error=file.get_error();file.close()
 if write_error!=OK:
  DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
  return {"ok":false,"message":"The game type couldn't be saved completely. Please try again."}
 return {"ok":true,"id":id,"name":name}
static func load_saved(id: String) -> GameTypeSettings:
 var entry=read_entry(id)
 if entry.is_empty():return null
 var settings=GameTypeSettings.new();settings.apply_network_dict(entry.settings)
 return settings

static func templates() -> Array[Dictionary]:
 var result: Array[Dictionary]=[]
 for i in range(5):result.append({"id":"builtin:"+str(i),"name":["Extraction","Slayer","Team Deathmatch","Capture the Flag","Bomb Defusal"][i]})
 return result
static func load_type(id: String) -> GameTypeSettings:
 if not id.begins_with("builtin:"):return load_saved(id)
 var index=int(id.trim_prefix("builtin:"))
 if index<0 or index>=5:return null
 var rules=GameTypeSettings.new();rules.mode=index;rules.game_type_name=templates()[index].name
 if index==1:rules.score_to_win=21
 if index==2:rules.score_to_win=42
 if index==3:rules.score_to_win=3;rules.time_limit_seconds=600
 if index==4:
  rules.score_to_win=11;rules.rounds=21;rules.time_limit_seconds=120;rules.round_time_limit_seconds=120
  rules.plant_seconds=3.2;rules.defuse_seconds=10;rules.bomb_timer_seconds=40;rules.lives_per_round=1
 rules.validate();return rules
