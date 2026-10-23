extends SceneTree
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool, message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func run():
 var old=ConfigFile.new();old.set_value("meta","schema",2);old.set_value("personal","hover_sensitivity_multiplier",.75);old.save(NestPreferences.PATH)
 var prefs=NestPreferences.new();prefs.load_saved();check(is_equal_approx(prefs.values.hover_sensitivity_multiplier,.7125),"Existing hover setting receives relative five-percent reduction")
 prefs.save();prefs=NestPreferences.new();prefs.load_saved();check(is_equal_approx(prefs.values.hover_sensitivity_multiplier,.7125),"Saved current settings do not receive a second reduction")
 old=ConfigFile.new();old.set_value("meta","schema",2);old.save(NestPreferences.PATH);prefs=NestPreferences.new();prefs.load_saved()
 check(is_equal_approx(prefs.values.hover_sensitivity_multiplier,.7125),"Missing legacy hover setting uses the new default exactly once")
 old=ConfigFile.new();old.set_value("meta","schema",2);old.set_value("personal","hover_sensitivity_multiplier",.4);old.save(NestPreferences.PATH);prefs=NestPreferences.new();prefs.load_saved()
 check(is_equal_approx(prefs.values.hover_sensitivity_multiplier,.38),"Custom legacy hover setting is reduced proportionally")
 print("V16 PREFERENCES: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
