class_name NestCampaignState
extends RefCounted
const SAVE_VERSION=2
const DIFFICULTIES=["Easy","Medium","Hard","Angel"]
const COUNTS=[3,5,6,8,12]
const PHASES=["LOBBY","INTRO","PREPARATION","BOARDING","DEPARTURE","CRASH","CRASH_ORIENTATION","WAVE_1","INTERMISSION_1","WAVE_2","INTERMISSION_2","WAVE_3","INTERMISSION_3","WAVE_4","INTERMISSION_4","WAVE_5","RADIO_READY","ENDING","COMPLETE","DEFEAT","CHAPTER","CHAPTER_COMPLETE"]
var run_id=""
var difficulty="Medium"
var phase="LOBBY"
var revision=0
var completed_waves=0
var bomb="missing"
var enemies={}
var defeated={}
var spawned={}
var completion_count=0
var supplies={}
var equipment={}
var practice={}
var charge_site=0
var mission_index=1
var campaign_entry=1
var chapters_completed=0
var chapter_stage=0
var chapter_stage_count=0
var chapter_expected=0
var chapter_enemies={}
var chapter_spawned={}
var chapter_defeated={}
var chapter_flags={}
var chapter_progress={}
func new_run(selected: String):
 run_id=Crypto.new().generate_random_bytes(16).hex_encode();difficulty=selected if selected in DIFFICULTIES else "Medium";phase="INTRO";revision=1;completed_waves=0;bomb="missing";enemies.clear();defeated.clear();spawned.clear();completion_count=0;supplies.clear();equipment.clear();practice.clear();charge_site=randi_range(0,2)
 mission_index=1;campaign_entry=1;chapters_completed=0;chapter_stage=0;chapter_stage_count=0;chapter_expected=0;chapter_enemies.clear();chapter_spawned.clear();chapter_defeated.clear();chapter_flags.clear();chapter_progress.clear()
func begin_chapter(index: int, stages: int, standalone=false) -> bool:
 if index<2 or index>9 or stages<1 or stages>8:return false
 if not standalone:
  if index!=mission_index+1:return false
  if mission_index==1 and phase!="COMPLETE":return false
  if mission_index>1 and phase!="CHAPTER_COMPLETE":return false
 else:
  campaign_entry=index;chapters_completed=index-1
 mission_index=index;phase="CHAPTER";chapter_stage=0;chapter_stage_count=stages;chapter_expected=0
 chapter_enemies.clear();chapter_spawned.clear();chapter_defeated.clear();chapter_flags.clear();chapter_progress.clear();revision+=1
 return true
func prepare_chapter_stage(expected: int) -> bool:
 if phase!="CHAPTER" or expected<0 or expected>16 or not chapter_enemies.is_empty():return false
 chapter_expected=expected;chapter_enemies.clear();chapter_spawned.clear();chapter_defeated.clear();chapter_flags.clear();chapter_progress.clear();revision+=1
 return true
func register_chapter_enemy(id: int) -> bool:
 if phase!="CHAPTER" or id>=-2000 or chapter_spawned.has(id) or chapter_spawned.size()>=chapter_expected:return false
 chapter_enemies[id]=chapter_stage;chapter_spawned[id]=chapter_stage;revision+=1;return true
func defeat_chapter_enemy(id: int) -> bool:
 if not chapter_enemies.has(id):return false
 chapter_defeated[id]=chapter_stage;chapter_enemies.erase(id);revision+=1;return true
func chapter_clear() -> bool:
 return chapter_enemies.is_empty() and chapter_spawned.size()==chapter_expected and chapter_defeated.size()==chapter_expected
func finish_chapter_stage() -> bool:
 if phase!="CHAPTER" or not chapter_clear() or not chapter_flags.get("objective",false):return false
 if chapter_stage+1<chapter_stage_count:
  chapter_stage+=1;chapter_expected=0;chapter_spawned.clear();chapter_defeated.clear();chapter_flags.clear();chapter_progress.clear()
 else:
  phase="CHAPTER_COMPLETE";chapters_completed=mission_index
 revision+=1;return true
func transition(next: String) -> bool:
 if next not in PHASES or next==phase:return false
 if next!="DEFEAT":
  var allowed={"LOBBY":["INTRO"],"INTRO":["PREPARATION"],"PREPARATION":["BOARDING"],"BOARDING":["DEPARTURE"],"DEPARTURE":["CRASH"],"CRASH":["CRASH_ORIENTATION"],"CRASH_ORIENTATION":["WAVE_1","RADIO_READY"],"WAVE_1":["INTERMISSION_1"],"INTERMISSION_1":["WAVE_2"],"WAVE_2":["INTERMISSION_2"],"INTERMISSION_2":["WAVE_3"],"WAVE_3":["INTERMISSION_3"],"INTERMISSION_3":["WAVE_4"],"WAVE_4":["INTERMISSION_4"],"INTERMISSION_4":["WAVE_5"],"WAVE_5":["CRASH_ORIENTATION","RADIO_READY"],"RADIO_READY":["ENDING"],"ENDING":["COMPLETE"]}
  if not next in allowed.get(phase,[]):return false
 if next.begins_with("WAVE_") and int(next.trim_prefix("WAVE_"))!=completed_waves+1:return false
 if phase.begins_with("WAVE_") and next!="DEFEAT" and (not enemies.is_empty() or wave_kills(wave_index())!=COUNTS[wave_index()]):return false
 if next=="RADIO_READY" and not radio_ready():return false
 if next=="COMPLETE" and phase!="ENDING":return false
 if next.begins_with("INTERMISSION_") and not enemies.is_empty():return false
 if next=="COMPLETE":completion_count=1;chapters_completed=1
 phase=next;revision+=1;return true
func wave_index() -> int:
 return int(phase.trim_prefix("WAVE_"))-1 if phase.begins_with("WAVE_") else -1
func register_enemy(id: int) -> bool:
 var wave=wave_index()
 if wave<0 or id in spawned or enemies.size()+wave_kills(wave)>=COUNTS[wave]:return false
 enemies[id]=wave;spawned[id]=wave;revision+=1;return true
func wave_kills(wave: int) -> int:
 var count=0
 for value in defeated.values():
  if int(value)==wave:count+=1
 return count
func enemy_defeated(id: int) -> bool:
 if not enemies.has(id):return false
 defeated[id]=enemies[id];enemies.erase(id);revision+=1;return true
func finish_wave() -> bool:
 var wave=wave_index()
 if wave<0 or not enemies.is_empty() or wave_kills(wave)!=COUNTS[wave]:return false
 completed_waves=wave+1;revision+=1
 return transition("RADIO_READY" if wave==4 and bomb=="secured" else "CRASH_ORIENTATION" if wave==4 else "INTERMISSION_"+str(wave+1))
func radio_ready() -> bool:return completed_waves==5 and defeated.size()==34 and enemies.is_empty() and bomb=="secured"
func pack() -> Dictionary:
 return {"version":SAVE_VERSION,"mission":"the_last_departure","run":run_id,"difficulty":difficulty,"phase":phase,"revision":revision,"completed_waves":completed_waves,"bomb":bomb,"enemies":enemies.duplicate(),"defeated":defeated.duplicate(),"spawned":spawned.duplicate(),"completion_count":completion_count,"supplies":supplies.duplicate(true),"equipment":equipment.duplicate(true),"practice":practice.duplicate(true),"charge_site":charge_site,"mission_index":mission_index,"campaign_entry":campaign_entry,"chapters_completed":chapters_completed,"chapter_stage":chapter_stage,"chapter_stage_count":chapter_stage_count,"chapter_expected":chapter_expected,"chapter_enemies":chapter_enemies.duplicate(),"chapter_spawned":chapter_spawned.duplicate(),"chapter_defeated":chapter_defeated.duplicate(),"chapter_flags":chapter_flags.duplicate(),"chapter_progress":chapter_progress.duplicate()}
static func valid(data) -> bool:
 if not data is Dictionary or int(data.get("version",0)) not in [1,SAVE_VERSION] or data.get("mission","")!="the_last_departure":return false
 if not data.get("difficulty","") in DIFFICULTIES or not data.get("phase","") in PHASES:return false
 if not valid_chapter(data):return false
 if not data.get("bomb","") in ["missing","carried","secured"]:return false
 if not data.get("run","") is String or data.run.length()!=32 or not data.run.is_valid_hex_number(false):return false
 for name in ["enemies","defeated","spawned","supplies","equipment","practice"]:
  if not data.get(name) is Dictionary:return false
 if data.enemies.size()>12 or data.defeated.size()>34 or data.spawned.size()>34 or data.practice.size()>4 or data.equipment.size()>4 or data.supplies.size()>32:return false
 if not data.get("revision",-1) is float and not data.get("revision",-1) is int:return false
 if data.revision<0 or data.revision>1000000000:return false
 var completed=int(data.get("completed_waves",-1))
 if completed<0 or completed>5 or int(data.get("charge_site",-1)) not in [0,1,2]:return false
 if int(data.get("completion_count",-1)) not in [0,1]:return false
 var counts=[0,0,0,0,0]
 for key in data.spawned:
  var id=str(key);var wave=int(data.spawned[key])
  if not id.is_valid_int() or int(id)>-1000 or wave<0 or wave>4:return false
  counts[wave]+=1
 for i in range(5):
  if counts[i]>COUNTS[i]:return false
 for collection in [data.enemies,data.defeated]:
  for key in collection:
   if not data.spawned.has(key) or int(collection[key])!=int(data.spawned[key]):return false
 for key in data.enemies:
  if data.defeated.has(key):return false
 for i in range(completed):
  var kills=0
  for value in data.defeated.values():
   if int(value)==i:kills+=1
  if kills!=COUNTS[i]:return false
 if data.phase in ["RADIO_READY","ENDING","COMPLETE"] and (completed!=5 or data.defeated.size()!=34 or data.bomb!="secured" or not data.enemies.is_empty()):return false
 if data.phase=="COMPLETE" and int(data.completion_count)!=1:return false
 if data.phase in ["INTRO","PREPARATION","BOARDING","DEPARTURE","CRASH"] and (completed!=0 or not data.spawned.is_empty()):return false
 if str(data.phase).begins_with("WAVE_") and completed!=int(str(data.phase).trim_prefix("WAVE_"))-1:return false
 if str(data.phase).begins_with("INTERMISSION_") and completed!=int(str(data.phase).trim_prefix("INTERMISSION_")):return false
 if data.phase=="CRASH_ORIENTATION" and completed not in [0,5]:return false
 for key in data.supplies:
  var amount=data.supplies[key]
  if (key not in ["ammo0","ammo1","ammo2","weapon","field0","field1","field2","field3","field4"] and not str(key).begins_with("chapter_supply")) or (not amount is int and not amount is float) or not is_finite(float(amount)) or float(amount)<0 or float(amount)>60:return false
 for key in data.equipment:
  var value=data.equipment[key]
  if not str(key).is_valid_int() or int(key)<1 or int(key)>4 or not value is Dictionary:return false
  if not value.get("weapons") is Array or value.weapons.size() not in [2,3]:return false
  for field in ["weapons","ammo","reserve"]:
   if not value.get(field) is Array or value[field].size()!=value.weapons.size():return false
  for i in range(2):
   if not value.weapons[i] is String or value.weapons[i] not in ["rifle","plasma_pistol","plasma_br","plasma_rifle","plasma_auto","plasma_sniper","ak47","sidearm","burst_scoped","shotgun","sniper","rocket","smg","plasma_smg"]:return false
   for field in ["ammo","reserve"]:
    var amount=value[field][i]
    if (not amount is float and not amount is int) or not is_finite(float(amount)) or amount<0 or amount>10000 or float(amount)!=floorf(float(amount)):return false
  if value.weapons.size()==3 and (value.weapons[2]!="plasma_sword" or (typeof(value.ammo[2]) not in [TYPE_INT,TYPE_FLOAT] or (float(value.ammo[2])!=0.0 and float(value.ammo[2])!=1.0)) or value.reserve[2]!=0):return false
  for field in ["health","shield"]:
   var amount=value.get(field)
   if (not amount is float and not amount is int) or not is_finite(float(amount)) or amount<0 or amount>100000:return false
  if int(value.get("slot",-1))<0 or int(value.get("slot",-1))>=value.weapons.size():return false
 for key in data.practice:
  if not str(key).is_valid_int() or int(key)<1 or int(key)>4 or not data.practice[key] is Dictionary or data.practice[key].size()>18:return false
  for field in data.practice[key]:
   if not field in ["look","walk","sprint","jump","crouch","interact","aim","fire","reload","switch","flashlight","shield","calibrating","manifest","boarded"] or not data.practice[key][field] is bool:return false
 return true
static func valid_chapter(value: Dictionary) -> bool:
 var index=int(value.get("mission_index",1));var entry=int(value.get("campaign_entry",1));var completed=int(value.get("chapters_completed",1 if value.get("phase")=="COMPLETE" else 0))
 if index<1 or index>9 or entry<1 or entry>index or completed<entry-1 or completed>index:return false
 if index==1:return value.get("phase") not in ["CHAPTER","CHAPTER_COMPLETE"]
 if int(value.get("version",0))!=SAVE_VERSION or value.get("phase") not in ["CHAPTER","CHAPTER_COMPLETE","DEFEAT"]:return false
 var stage=int(value.get("chapter_stage",-1));var count=int(value.get("chapter_stage_count",0));var expected=int(value.get("chapter_expected",-1))
 if count<1 or count>8 or stage<0 or stage>=count or expected<0 or expected>16:return false
 for key in ["chapter_enemies","chapter_spawned","chapter_defeated","chapter_flags","chapter_progress"]:
  if not value.get(key) is Dictionary:return false
 var spawned=value.chapter_spawned;var defeated_enemies=value.chapter_defeated;var living=value.chapter_enemies
 if spawned.size()>expected or living.size()+defeated_enemies.size()!=spawned.size():return false
 for key in spawned:
  if not str(key).is_valid_int() or int(key)>=-2000 or int(spawned[key])!=stage:return false
 for collection in [living,defeated_enemies]:
  for key in collection:
   if not spawned.has(key) or int(collection[key])!=stage:return false
 for key in living:
  if defeated_enemies.has(key):return false
 if value.chapter_flags.size()>16 or value.chapter_progress.size()>16:return false
 for key in value.chapter_flags:
  if not key is String or key.length()>40 or not value.chapter_flags[key] is bool:return false
 for key in value.chapter_progress:
  var amount=value.chapter_progress[key]
  if not key is String or key.length()>40 or typeof(amount) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(amount)) or float(amount)<0 or float(amount)>1000000:return false
 if value.phase=="CHAPTER_COMPLETE" and (stage!=count-1 or not value.chapter_flags.get("objective",false) or not living.is_empty() or defeated_enemies.size()!=expected or completed!=index):return false
 return true
func restore(data: Dictionary) -> bool:
 if not valid(data):return false
 run_id=data.run;difficulty=data.difficulty;phase=data.phase;revision=int(data.revision);completed_waves=int(data.completed_waves);bomb=data.bomb;completion_count=int(data.completion_count);charge_site=int(data.charge_site)
 mission_index=int(data.get("mission_index",1));campaign_entry=int(data.get("campaign_entry",1));chapters_completed=int(data.get("chapters_completed",1 if phase=="COMPLETE" else 0));chapter_stage=int(data.get("chapter_stage",0));chapter_stage_count=int(data.get("chapter_stage_count",0));chapter_expected=int(data.get("chapter_expected",0))
 chapter_flags=data.get("chapter_flags",{}).duplicate();chapter_progress=data.get("chapter_progress",{}).duplicate();chapter_enemies={};chapter_spawned={};chapter_defeated={}
 for key in data.get("chapter_enemies",{}):chapter_enemies[int(key)]=int(data.chapter_enemies[key])
 for key in data.get("chapter_spawned",{}):chapter_spawned[int(key)]=int(data.chapter_spawned[key])
 for key in data.get("chapter_defeated",{}):chapter_defeated[int(key)]=int(data.chapter_defeated[key])
 enemies={};defeated={};spawned={}
 for key in data.enemies:enemies[int(key)]=int(data.enemies[key])
 for key in data.defeated:defeated[int(key)]=int(data.defeated[key])
 for key in data.spawned:spawned[int(key)]=int(data.spawned[key])
 supplies=data.supplies.duplicate(true);equipment=data.equipment.duplicate(true);practice=data.practice.duplicate(true)
 # Accept historical checkpoints without restoring the retired tutorial mechanic.
 for progress in practice.values():progress.erase("sprint")
 return true
