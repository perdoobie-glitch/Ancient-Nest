extends SceneTree
func _initialize():call_deferred("run")
func run():
 var baseline=JSON.parse_string(FileAccess.get_file_as_string(get_script().resource_path.get_base_dir()+"/tier_cadence_baseline.json"))
 var changed=["assault_rifle","ak47","battle_rifle_scoped","plasma_br","plasma_auto","falcon_smg","viper_pulse_smg","magnum","plasma_pistol"]
 var count=0
 for old in baseline:
  var current=NestWeaponCatalog.definition(old.id)
  if old.id not in changed:
   if old.id=="rocket_launcher":
    var expected=old.duplicate(true);expected.splash_damage_max=200.;expected.splash_radius_m=7.;expected.projectile_visual_note=current.projectile_visual_note
    assert(current==expected,"Rocket changed beyond requested splash settings")
   else:assert(current==old,"Protected weapon changed: "+old.id)
   continue
  count+=1
  var factor=.6 if old.id=="plasma_br" else .5
  for key in old:
   if key in ["interval","burst_interval","burst_delay"]:assert(is_equal_approx(current[key],old[key]*factor))
   elif key=="fire_rate_rpm":assert(is_equal_approx(current[key],old[key]/factor))
   elif key!="balance_ttk_reference":assert(current[key]==old[key],"Unexpected change: "+old.id+" "+key)
  var interval=float(old.burst_delay)+float(old.burst_interval)*(int(old.burst_count)-1) if int(old.burst_count)>1 else 60.0/float(old.fire_rate_rpm)
  assert(is_equal_approx(NestWeaponCatalog.profile(old.id).interval,interval*factor))
  # Shot timelines: 50% reduction (plasma burst preserved) for all multi-shot counts, including partial bursts.
  for shots in range(2,31):
   var burst=int(old.burst_count)
   var gaps=shots-1
   var delay_gaps=gaps/burst if burst>1 else 0
   var old_time=(gaps-delay_gaps)*float(old.burst_interval)+delay_gaps*float(old.get("burst_delay",0)) if burst>1 else gaps*interval
   var new_time=(gaps-delay_gaps)*float(current.burst_interval)+delay_gaps*float(current.get("burst_delay",0)) if burst>1 else gaps*NestWeaponCatalog.profile(old.id).interval
   assert(is_equal_approx(new_time,old_time*factor))
 assert(count==9)
 print("PASS: nine tier 2–4 weapons; 50% shorter firing timelines, plasma burst unchanged; tier 1 cadence/grenades unchanged; rocket splash is 200/7m")
 quit()
