class_name NestRatingProfile
extends RefCounted
const PATH="user://player_rating.json"
const NAMES=["Forgebound","Striker","Sentinel","Vanguard","Praetorian","War Marshal","Ascendant"]
const INITIAL=0
const MAX_ELO=3200
const K=32
var data={}
var last_result={}
func _init():
 data={"version":1,"human":fresh(),"practice":fresh(),"processed":[]}
static func fresh() -> Dictionary:return {"elo":INITIAL,"games":0,"wins":0,"losses":0,"draws":0,"kills":0,"deaths":0}
static func kd_percent(kills: int,deaths: int) -> float:
 return 100.0*maxi(kills,0)/maxi(1,maxi(kills,0)+maxi(deaths,0))
static func rank_for(elo: float) -> Dictionary:
 var points=clampi(roundi(elo),0,MAX_ELO);var index=mini(20,points/150);var group=index/3;var tier=index%3+1
 var low=index*150;var high=(index+1)*150 if index<20 else MAX_ELO
 return {"name":NAMES[group],"group":group,"tier":tier,"roman":["I","II","III"][tier-1],"number":index+1,"elo":points,"low":low,"high":high,"progress":clampf(float(points-low)/maxi(1,high-low),0,1)}
static func expected(own: float,opponent: float) -> float:return 1.0/(1.0+pow(10.0,(opponent-own)/400.0))
static func elo_after(own: float,opponent: float,result: float) -> int:
 var points=clampi(roundi(own+K*(clampf(result,0,1)-expected(own,opponent))),0,MAX_ELO)
 # Keep decisive results meaningful after rounding; bounds still take priority.
 if points==roundi(own):
  if is_equal_approx(result,1):points=mini(MAX_ELO,points+1)
  elif is_equal_approx(result,0):points=maxi(0,points-1)
 return points
static func clean_summary(input) -> Dictionary:
 var result={"human":INITIAL,"practice":INITIAL}
 if not input is Dictionary:return result
 for key in result:
  var value=input.get(key,INITIAL)
  if typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)):result[key]=clampi(roundi(value),0,MAX_ELO)
 return result
func summary() -> Dictionary:return {"human":int(data.human.elo),"practice":int(data.practice.elo)}
func load_data() -> void:
 if not FileAccess.file_exists(PATH):return
 var f=FileAccess.open(PATH,FileAccess.READ)
 if f==null or f.get_length()>128000:return
 var parser=JSON.new()
 if parser.parse(f.get_as_text())!=OK or not parser.data is Dictionary:return
 var input=parser.data
 if input.get("version")!=1:return
 for channel in ["human","practice"]:
  var source=input.get(channel,{})
  if not source is Dictionary:continue
  for key in fresh():
   var value=source.get(key,data[channel][key])
   if typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)):data[channel][key]=clampi(roundi(value),0,MAX_ELO if key=="elo" else 100000000)
 var tokens=input.get("processed",[])
 if tokens is Array:
  for value in tokens.slice(maxi(0,tokens.size()-64)):
   if value is String and value.length()<=96:data.processed.append(value)
func save_data() -> bool:
 var f=FileAccess.open(PATH+".tmp",FileAccess.WRITE)
 if f==null:return false
 f.store_string(JSON.stringify(data));f.flush();var error=f.get_error();f.close()
 return error==OK and DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH+".tmp"),ProjectSettings.globalize_path(PATH))==OK
func apply_result(token: String,channel: String,row: Dictionary) -> bool:
 if token.is_empty() or token.length()>96 or channel not in ["human","practice"] or token in data.processed:return false
 for key in ["before","after","kills","deaths","score"]:
  if typeof(row.get(key)) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(row[key])):return false
 if int(data[channel].elo)!=roundi(row.before) or row.after<0 or row.after>MAX_ELO or absf(row.after-row.before)>K or row.kills<0 or row.deaths<0 or row.kills>100000 or row.deaths>100000 or row.score<0 or row.score>1:return false
 var before=data.duplicate(true);var record=data[channel];record.elo=roundi(row.after);record.games+=1;record.kills+=roundi(row.kills);record.deaths+=roundi(row.deaths)
 if row.score>.5:record.wins+=1
 elif row.score<.5:record.losses+=1
 else:record.draws+=1
 data.processed.append(token)
 if data.processed.size()>64:data.processed.pop_front()
 if not save_data():data=before;return false
 last_result={"channel":channel,"before":roundi(row.before),"after":roundi(row.after),"delta":roundi(row.after-row.before),"score":float(row.score),"kills":roundi(row.kills),"deaths":roundi(row.deaths)}
 return true
