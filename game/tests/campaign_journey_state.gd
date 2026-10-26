extends SceneTree
var failures=0
var checks=0
func check(ok: bool,text: String):
 checks+=1;print(("PASS " if ok else "FAIL ")+text)
 if not ok:failures+=1
func _initialize():call_deferred("run")
func run():
 var state=NestCampaignState.new();state.new_run("Hard")
 check(not state.begin_chapter(2,6),"Sequential campaign cannot skip unfinished first mission")
 check(not state.begin_chapter(9,4),"Sequential campaign cannot jump to finale")
 check(state.begin_chapter(3,4,true),"Explicit chapter selection starts its own expedition")
 check(state.campaign_entry==3 and state.completed_waves==0 and state.defeated.is_empty(),"Chapter selection does not invent Mission 1 kills")
 check(NestCampaignState.valid(state.pack()),"Selected chapter state validates")
 check(state.prepare_chapter_stage(3),"Stage configures finite authoritative encounter")
 check(not state.finish_chapter_stage(),"Unstarted encounter cannot complete")
 for id in [-23000,-23001,-23002]:check(state.register_chapter_enemy(id),"Register real chapter defender "+str(id))
 check(not state.register_chapter_enemy(-23003) and not state.register_chapter_enemy(-23000),"Overflow and duplicate defenders rejected")
 state.chapter_flags.objective=true
 check(not state.finish_chapter_stage(),"Objective alone cannot skip living defenders")
 for id in state.chapter_enemies.keys():check(state.defeat_chapter_enemy(id),"Actual defender death is counted")
 check(not state.defeat_chapter_enemy(-23000),"Duplicate death cannot inflate stage progress")
 check(state.finish_chapter_stage() and state.chapter_stage==1,"Cleared encounter and objective advance exactly one stage")
 check(not state.finish_chapter_stage(),"New stage cannot inherit prior objective completion")
 for stage in range(1,4):
  state.prepare_chapter_stage(0);state.chapter_flags.objective=true;state.finish_chapter_stage()
 check(state.phase=="CHAPTER_COMPLETE" and state.chapters_completed==3,"All four actual objectives finish chapter")
 check(not state.finish_chapter_stage(),"Chapter completion is idempotent")
 check(not state.begin_chapter(5,4) and state.begin_chapter(4,4),"Next chapter must be sequential")
 state.prepare_chapter_stage(4)
 var packet=JSON.parse_string(JSON.stringify(state.pack()));var restored=NestCampaignState.new()
 check(restored.restore(packet) and restored.mission_index==4 and restored.chapter_expected==4,"Chapter checkpoint survives JSON roundtrip")
 var store=NestCampaignSave.new();store.path="user://qa-journey-"+Crypto.new().generate_random_bytes(6).hex_encode()+".json"
 check(store.save(packet),"Safe stage entrance saved before combat")
 state.register_chapter_enemy(-24000)
 check(not store.save(state.pack()),"Mid-encounter snapshot cannot replace safe checkpoint")
 check(store.load_checkpoint().get("chapter_spawned",{"invalid":true}).is_empty(),"Retry restarts checkpoint with encounter intact")
 var corrupt=packet.duplicate(true);corrupt.chapter_progress={"ride_seconds":INF};check(not NestCampaignState.valid(corrupt),"Nonfinite progression rejected")
 corrupt=packet.duplicate(true);corrupt.chapter_stage=99;check(not NestCampaignState.valid(corrupt),"Out-of-range stage rejected")
 corrupt=packet.duplicate(true);corrupt.phase="CHAPTER_COMPLETE";check(not NestCampaignState.valid(corrupt),"Forged incomplete finale rejected")
 var old=NestCampaignState.new();old.new_run("Easy");old.transition("PREPARATION");var legacy=old.pack();legacy.version=1
 for key in ["mission_index","campaign_entry","chapters_completed","chapter_stage","chapter_stage_count","chapter_expected","chapter_enemies","chapter_spawned","chapter_defeated","chapter_flags","chapter_progress"]:legacy.erase(key)
 check(restored.restore(legacy) and restored.mission_index==1 and restored.phase=="PREPARATION","Version 1 Mission 1 save migrates without changing progress")
 if OS.get_environment("NEST_ISOLATED_QA")=="1":
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://campaign"))
  var legacy_file=FileAccess.open(NestCampaignSave.LEGACY_PATH,FileAccess.WRITE);legacy_file.store_string(JSON.stringify(legacy));legacy_file.close()
  var original_hash=FileAccess.get_sha256(NestCampaignSave.LEGACY_PATH);var migration=NestCampaignSave.new();var imported=migration.load_checkpoint()
  check(not imported.is_empty() and imported.version==1,"New default save reads untouched legacy Mission 1 checkpoint")
  var migrated=NestCampaignState.new();migrated.restore(imported);migrated.revision+=1
  check(migration.save(migrated.pack()) and FileAccess.get_sha256(NestCampaignSave.LEGACY_PATH)==original_hash,"Saving migrated campaign preserves old build's save byte-for-byte")
  var damaged=FileAccess.open(NestCampaignSave.DEFAULT_PATH,FileAccess.WRITE);damaged.store_string("corrupt");damaged.close()
  check(migration.load_checkpoint().is_empty(),"Existing corrupt new save does not silently revert to old progress")
 for suffix in ["",".bak",".tmp"]:
  if FileAccess.file_exists(store.path+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(store.path+suffix))
 print("CAMPAIGN JOURNEY STATE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
