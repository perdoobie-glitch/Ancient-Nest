class_name NestCampaignSave
extends RefCounted
const DEFAULT_PATH="user://campaign/nine_missions.json"
const LEGACY_PATH="user://campaign/mission1.json"
var path=DEFAULT_PATH
var error=""
const SAFE_PHASES=["PREPARATION","BOARDING","CRASH_ORIENTATION","INTERMISSION_1","INTERMISSION_2","INTERMISSION_3","INTERMISSION_4","RADIO_READY","COMPLETE","CHAPTER_INTRO","CHAPTER","CHAPTER_OUTRO","CHAPTER_COMPLETE"]
func read_valid(file: String) -> Dictionary:
 if not FileAccess.file_exists(file):return {}
 var input=FileAccess.open(file,FileAccess.READ)
 if input==null or input.get_length()>65536:return {}
 var json=JSON.new();var result=json.parse(input.get_as_text());input.close()
 if result!=OK:return {}
 var value=json.data
 return value if NestCampaignState.valid(value) and value.phase in SAFE_PHASES and value.enemies.is_empty() and value.get("chapter_enemies",{}).is_empty() and (value.get("mission_index",1)==1 or value.get("chapter_spawned",{}).is_empty() or value.phase=="CHAPTER_COMPLETE") else {}
func load_checkpoint() -> Dictionary:
 var value=read_valid(path)
 if not value.is_empty():return value
 value=read_valid(path+".bak")
 if not value.is_empty():return value
 # Import an old Mission 1 checkpoint only before this campaign has saved.
 # Preserve the City-Ambush build's original file and avoid silently falling
 # back to old progress after corruption of an existing nine-mission save.
 if path==DEFAULT_PATH and not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".bak"):
  value=read_valid(LEGACY_PATH)
  if int(value.get("mission_index",1))==1:return value
 return {}
func save(data: Dictionary) -> bool:
 error=""
 if not NestCampaignState.valid(data):error="Invalid campaign state";return false
 if data.phase not in SAFE_PHASES or not data.enemies.is_empty() or not data.get("chapter_enemies",{}).is_empty() or (data.get("mission_index",1)>1 and not data.get("chapter_spawned",{}).is_empty() and data.phase!="CHAPTER_COMPLETE"):error="Mid-wave saves are unsupported; use a safe milestone";return false
 var old=load_checkpoint()
 if old.get("run","")==data.run and int(old.get("revision",-1))>int(data.revision):error="Stale checkpoint rejected";return false
 var absolute=ProjectSettings.globalize_path(path)
 if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())!=OK:error="Cannot create campaign save directory";return false
 var output=FileAccess.open(path+".tmp",FileAccess.WRITE)
 if output==null:error="Cannot write campaign checkpoint";return false
 output.store_string(JSON.stringify(data));output.flush();var result=output.get_error();output.close()
 if result!=OK or read_valid(path+".tmp").is_empty():error="Checkpoint verification failed";return false
 # The validated backup also recovers a power loss during Windows replacement.
 if FileAccess.file_exists(path):
  if FileAccess.file_exists(path+".bak"):DirAccess.remove_absolute(absolute+".bak")
  if DirAccess.rename_absolute(absolute,absolute+".bak")!=OK:error="Cannot preserve previous checkpoint";return false
 if DirAccess.rename_absolute(absolute+".tmp",absolute)!=OK:error="Cannot commit checkpoint";return false
 return true
