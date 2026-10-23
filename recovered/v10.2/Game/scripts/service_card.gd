class_name NestServiceCard
extends NestGamerCard
const DIAMOND=Color("8ebacb")
func _init() -> void:
 super()
 name="ServiceCard"
 var frame=get_theme_stylebox("panel").duplicate() as StyleBoxFlat
 frame.bg_color=Color("edf6fa");frame.border_color=DIAMOND;frame.shadow_color=Color(.3,.65,.85,.2);add_theme_stylebox_override("panel",frame)
func show_service(data: Dictionary,username: String) -> void:
 show_profile(data,username,"Overall service record")
 content.get_child(0).text="◇  ANCIENT NEST  /  SERVICE CARD"
 content.get_child(0).add_theme_color_override("font_color",Color("365b70"))
 var tag=content.get_node("UsernameTag") as Button;tag.disabled=true;tag.tooltip_text="";tag.add_theme_color_override("font_disabled_color",Color("23495f"))
 for child in content.get_children():
  if child is ColorRect:child.color=DIAMOND
 if content.has_node("PlacementProgress"):
  var old=content.get_node("PlacementProgress");content.remove_child(old);old.queue_free()
  content.add_child(text("Player Rating unlocks separately after three games in each playlist.",13,MUTED))
 for child in content.get_children():
  if child is Label and child.text=="Independent matchmaking record for this playlist.":child.text=""
  if child is Label and child.text=="Player Rating is temporarily unavailable.":child.text="Player Rating unlocks separately after three games in each playlist."
 content.add_child(text("Match-weighted playlist average · %d / %d played · %d rated"%[int(data.get("playlists_played",0)),int(data.get("playlists_total",5)),int(data.get("playlists_rated",0))],13,MUTED))
 for stat in [["Matches","matches"],["Wins","wins"],["Kills","kills"],["Deaths","deaths"],["Assists","assists"]]:row(stat[0],str(data.get(stat[1],0)),"Total"+stat[1])
 row("K/D","—" if data.get("kd")==null else "%.2f"%float(data.kd),"TotalKD")
 content.add_child(text("Elo is weighted by completed matches. Player Rating averages rated playlists. Combat statistics are combined totals. Unrated playlists do not count as a 0% Player Rating.",12,MUTED))

func row(title: String,value: String,key: String) -> void:
 super.row(title,value,key)
 content.get_node(key).get_child(1).add_theme_color_override("font_color",Color("23495f"))
