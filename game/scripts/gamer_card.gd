class_name NestGamerCard
extends PanelContainer
## Presentation only. Values come from the authenticated per-playlist profile API.
## This component never grants Elo or computes a rank from editable local saves.
signal username_pressed
const INK=Color("183b2d")
const GOLD=Color("b69243")
const MUTED=Color("626b64")
var content: VBoxContainer
func _init() -> void:
 name="GamerCard";custom_minimum_size=Vector2(320,0)
 var frame=StyleBoxFlat.new();frame.bg_color=Color("f4f3ed");frame.border_color=GOLD
 frame.set_border_width_all(2);frame.set_corner_radius_all(10)
 frame.content_margin_left=24;frame.content_margin_right=24;frame.content_margin_top=22;frame.content_margin_bottom=22
 frame.shadow_color=Color(0,0,0,.15);frame.shadow_size=8;add_theme_stylebox_override("panel",frame)
 content=VBoxContainer.new();content.add_theme_constant_override("separation",12);add_child(content)
func text(value: String,size: int=16,color: Color=INK) -> Label:
 var item=Label.new();item.text=value;item.add_theme_font_size_override("font_size",size);item.add_theme_color_override("font_color",color)
 item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;return item
func row(title: String,value: String,key: String) -> void:
 var line=HBoxContainer.new();line.name=key;line.add_theme_constant_override("separation",16);content.add_child(line)
 var label=text(title,15,MUTED);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;line.add_child(label)
 var number=text(value,21);number.autowrap_mode=TextServer.AUTOWRAP_OFF;number.size_flags_horizontal=Control.SIZE_SHRINK_END;number.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;line.add_child(number)
func clear_content() -> void:
 for child in content.get_children():content.remove_child(child);child.queue_free()
func show_unavailable(message: String="Connect your account to load this playlist’s gamer card.") -> void:
 clear_content();content.add_child(text("ANCIENT NEST  /  GAMER CARD",13,GOLD));content.add_child(text(message,16,MUTED))
func show_profile(profile: Dictionary,username: String,playlist: String) -> void:
 clear_content();content.add_child(text("ANCIENT NEST  /  GAMER CARD",13,GOLD))
 var tag=Button.new();tag.name="UsernameTag";tag.text=username;tag.flat=true;tag.alignment=HORIZONTAL_ALIGNMENT_LEFT;tag.add_theme_font_size_override("font_size",28);tag.add_theme_color_override("font_color",INK);tag.tooltip_text="Open overall service card";tag.pressed.connect(func():username_pressed.emit());content.add_child(tag)
 content.add_child(text(playlist.to_upper(),13,MUTED))
 var divider=ColorRect.new();divider.color=GOLD;divider.custom_minimum_size.y=1;content.add_child(divider)
 row("League",str(profile.league),"League")
 row("Rank Level",str(int(profile.rank_level)),"RankLevel")
 row("Elo",str(int(profile.elo)),"Elo")
 var games=int(profile.get("matches",0));var rating=profile.get("player_rating")
 if games>=3 and typeof(rating) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(rating)):
  # Grade is returned by the server; no local grade table or fabricated 0%.
  var grade=str(profile.get("rating_grade")) if profile.get("rating_grade") is String else ""
  row("Player Rating","%d%%%s"%[roundi(rating),("  "+grade) if not grade.is_empty() else ""],"PlayerRating")
 elif games<3:
  var placement=text("Placement matches: %d / 3\nPlayer Rating appears after three completed matches in this playlist."%maxi(0,games),13,MUTED)
  placement.name="PlacementProgress";content.add_child(placement)
 else:content.add_child(text("Player Rating is temporarily unavailable.",13,MUTED))
 var note=text("Independent matchmaking record for this playlist.",12,MUTED);content.add_child(note)
