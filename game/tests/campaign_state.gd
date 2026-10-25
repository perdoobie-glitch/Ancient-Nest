extends SceneTree
var failures=0
var checks=0
func check(ok: bool,text: String):
 checks+=1;print(("PASS " if ok else "FAIL ")+text)
 if not ok:failures+=1
func _initialize():call_deferred("run")
func run():
 var state=NestCampaignState.new();state.new_run("Angel")
 check(state.difficulty=="Angel" and state.phase=="INTRO","New run preserves selected Difficulty")
 check(NestCampaignState.valid(state.pack()),"Initial save validates")
 check(not state.transition("RADIO_READY"),"Radio refuses an unfinished mission")
 check(not state.transition("WAVE_5"),"A premature future-wave transition is rejected")
 for phase in ["PREPARATION","BOARDING","DEPARTURE","CRASH","CRASH_ORIENTATION"]:state.transition(phase)
 for wave in range(5):
  state.transition("WAVE_"+str(wave+1))
  for i in range(NestCampaignState.COUNTS[wave]):
   var id=-1000-wave*100-i
   check(state.register_enemy(id),"Stable enemy registration "+str(id))
   check(not state.register_enemy(id),"Repeated registration rejected "+str(id))
  check(not state.finish_wave(),"A living enemy blocks wave completion")
  for id in state.enemies.keys():
   state.enemy_defeated(id)
   check(not state.enemy_defeated(id),"Simultaneous duplicate kill is ignored "+str(id))
  check(state.finish_wave(),"Exact cleared wave advances "+str(wave+1))
 check(state.defeated.size()==34 and state.completed_waves==5,"Exact mission total is thirty-four")
 check(not state.radio_ready(),"Unsecured charge blocks radio after all five waves")
 state.bomb="secured";check(state.transition("RADIO_READY"),"Secured charge unlocks radio after exact wave totals")
 state.transition("ENDING");check(state.transition("COMPLETE") and not state.transition("COMPLETE") and state.completion_count==1,"Ending completion is idempotent")
 var decoded=JSON.parse_string(JSON.stringify(state.pack()));var restored=NestCampaignState.new()
 check(restored.restore(decoded) and restored.radio_ready() and restored.difficulty=="Angel","Primitive JSON roundtrip preserves difficulty and objectives")
 var corrupt=decoded.duplicate(true);corrupt.difficulty="Impossible";check(not NestCampaignState.valid(corrupt),"Unknown Difficulty is rejected")
 corrupt=decoded.duplicate(true);corrupt.defeated.clear();check(not NestCampaignState.valid(corrupt),"Forged completion without thirty-four kills is rejected")
 var store=NestCampaignSave.new();store.path="user://qa-campaign-"+Crypto.new().generate_random_bytes(6).hex_encode()+".json"
 check(store.save(decoded),"Atomic checkpoint write validates before commit")
 check(store.load_checkpoint().difficulty=="Angel","Offline checkpoint restores selected Difficulty")
 var older=decoded.duplicate(true);older.revision-=1;check(not store.save(older),"Older save cannot replace newer progress")
 var newer=decoded.duplicate(true);newer.revision+=1;check(store.save(newer),"Newer checkpoint commits with a recovery backup")
 var file=FileAccess.open(store.path,FileAccess.WRITE);file.store_string("corrupt");file.close()
 check(not store.load_checkpoint().is_empty(),"Validated backup recovers interrupted or corrupt primary save")
 for suffix in ["",".bak",".tmp"]:
  if FileAccess.file_exists(store.path+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(store.path+suffix))
 print("CAMPAIGN STATE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
