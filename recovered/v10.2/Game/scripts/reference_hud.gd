class_name NestReferenceHud
extends Control
var game
var left_name: Label
var right_name: Label
var left_score: Label
var right_score: Label
var clock_label: Label
var ammo: Label
var weapon_title: Label
var weapon_status: Label
var left_emblem: NestFactionEmblem
var right_emblem: NestFactionEmblem
var top: PanelContainer
var ammo_box: VBoxContainer
var bullet_marks: Control
var signature=""
const GOLD=Color("ddc773")
class Bullets extends Control:
 var rounds: int=0
 func _ready():mouse_filter=Control.MOUSE_FILTER_IGNORE
 func _draw():
  for i in range(3):
   var x=5+i*11;var color=Color("f2f2e7") if rounds>i else Color(.7,.7,.65,.2)
   draw_rect(Rect2(x,13,7,24),color)
   draw_colored_polygon(PackedVector2Array([Vector2(x,11),Vector2(x+3.5,1),Vector2(x+7,11)]),color)
func label(text: String, pixels: int, serif: bool=false) -> Label:
 var node=Label.new();node.text=text;node.add_theme_font_size_override("font_size",pixels);node.add_theme_font_override("font",load("res://assets/title.ttf" if serif else "res://assets/body.ttf"));node.add_theme_color_override("font_outline_color",Color(0,0,0,.8));node.add_theme_constant_override("outline_size",2);node.mouse_filter=Control.MOUSE_FILTER_IGNORE;node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;node.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;return node
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 top=PanelContainer.new();top.name="ReferenceTopScore";add_child(top);top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP);top.offset_left=-265;top.offset_right=265;top.offset_top=22;top.offset_bottom=64
 var style=StyleBoxFlat.new();style.bg_color=Color(.025,.032,.035,.78);style.border_color=Color(.85,.73,.31,.8);style.border_width_top=1;style.border_width_bottom=1;style.content_margin_left=8;style.content_margin_right=8;top.add_theme_stylebox_override("panel",style)
 var row=HBoxContainer.new();row.add_theme_constant_override("separation",9);top.add_child(row)
 left_emblem=NestFactionEmblem.new();left_emblem.custom_minimum_size=Vector2(28,34);row.add_child(left_emblem)
 left_name=label("",16,true);left_name.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(left_name)
 left_score=label("0",28,true);left_score.custom_minimum_size.x=45;row.add_child(left_score)
 var slash=label("╲",27,true);slash.modulate=GOLD;row.add_child(slash)
 clock_label=label("",21);clock_label.custom_minimum_size.x=90;row.add_child(clock_label)
 slash=label("╱",27,true);slash.modulate=GOLD;row.add_child(slash)
 right_score=label("0",28,true);right_score.custom_minimum_size.x=45;row.add_child(right_score)
 right_name=label("",16,true);right_name.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(right_name)
 right_emblem=NestFactionEmblem.new();right_emblem.custom_minimum_size=Vector2(28,34);row.add_child(right_emblem)
 ammo_box=VBoxContainer.new();ammo_box.name="ReferenceAmmo";ammo_box.add_theme_constant_override("separation",0);add_child(ammo_box);ammo_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT);ammo_box.offset_left=-360;ammo_box.offset_right=-34;ammo_box.offset_top=-118;ammo_box.offset_bottom=-25
 weapon_title=label("",13);weapon_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;weapon_title.modulate=GOLD;ammo_box.add_child(weapon_title)
 var ammo_row=HBoxContainer.new();ammo_row.alignment=BoxContainer.ALIGNMENT_END;ammo_row.add_theme_constant_override("separation",12);ammo_box.add_child(ammo_row)
 ammo=label("",32);ammo.name="LiveAmmoCount";ammo_row.add_child(ammo)
 bullet_marks=Bullets.new();bullet_marks.custom_minimum_size=Vector2(40,40);ammo_row.add_child(bullet_marks)
 weapon_status=label("",12);weapon_status.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;weapon_status.modulate=Color("c7c6b7");ammo_box.add_child(weapon_status)
 resized.connect(layout);layout()
func layout() -> void:
 if not is_instance_valid(top):return
 var width=minf(530*float(game.prefs.values.hud_scale),maxf(330,size.x-32));top.offset_left=-width*.5;top.offset_right=width*.5
 var scale=clampf(width/530,.65,1.35)
 for node in [left_name,right_name]:node.add_theme_font_size_override("font_size",roundi(16*scale))
 for node in [left_score,right_score]:node.add_theme_font_size_override("font_size",roundi(28*scale))
 clock_label.add_theme_font_size_override("font_size",roundi(21*scale))
 ammo.add_theme_font_size_override("font_size",roundi(32*clampf(float(game.prefs.values.hud_scale),.75,1.35)))
func refresh() -> void:
 ammo_box.visible=not is_instance_valid(game.nu.local_bird)
 if not is_instance_valid(game.player) or game.player.weapons.is_empty():return
 var remaining=maxf(0,(float(game.site_states[game.bomb_site].bomb_at) if game.mode==game.MODE_CS and game.cs_planted() else game.deadline)-game.now)
 var clock=("%d:%02d"%[int(remaining)/60,int(remaining)%60]) if is_finite(remaining) else "∞"
 # Resolve the final ISO values before touching controls. Alternating team
 # labels/scores with LEADER/YOU each frame invalidated layout continuously.
 var left_title=game.team_name(0).to_upper();var right_title=game.team_name(1).to_upper()
 var left_value=game.scores[0];var right_value=game.scores[1]
 if game.mode==1:
  left_title="LEADER";right_title="YOU";left_value=0;right_value=game.player.kills
  for actor in game.actors:left_value=maxi(left_value,actor.kills)
 left_name.text=left_title;right_name.text=right_title
 left_score.text=str(left_value);right_score.text=str(right_value);clock_label.text=clock
 var a=game.team_characters[0]==1;var b=game.team_characters[1]==1
 if left_emblem.annu!=a:left_emblem.annu=a;left_emblem.queue_redraw()
 if right_emblem.annu!=b:right_emblem.annu=b;right_emblem.queue_redraw()
 var player=game.player;var weapon=player.weapons[player.slot]
 weapon_title.text=weapon.title.to_upper()
 ammo.text="%s / %s"%["∞" if player.traits.infinite_ammo==2 else str(player.ammo[player.slot]),"∞" if player.traits.infinite_ammo>0 else str(player.reserve[player.slot])]
 var rounds=3 if player.traits.infinite_ammo==2 else player.ammo[player.slot]
 if bullet_marks.rounds!=rounds:bullet_marks.rounds=rounds;bullet_marks.queue_redraw()
 var status="RELOADING" if player.action_state=="reloading" else "ZOOM %d"%player.scope_level if player.is_scoped() else ""
 weapon_status.text=(status+"  ·  " if not status.is_empty() else "")+("STICKY" if player.grenade_kind==1 else "FRAG")+" × "+str(player.grenades[player.grenade_kind])
 bullet_marks.visible=weapon.kind not in ["none","plasma_sword"]
 if weapon.kind=="plasma_sword":ammo.text="∞";weapon_status.text="LMB / F · PLASMA SLASH"
 if weapon.kind=="none":ammo.text="—";weapon_status.text="Knife / grenades available"
func _process(_delta: float) -> void:
 if game.running and visible:refresh()
