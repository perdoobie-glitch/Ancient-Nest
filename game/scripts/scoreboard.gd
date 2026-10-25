class_name NestScoreboard
extends PanelContainer
var inspecting=false
var game: Node3D
var content: VBoxContainer
var last_signature: String=""
var next_refresh: float=0
var scale_factor: float=1
var timer: Label
var scroll: ScrollContainer
const GOLD=Color("ddc65e")
class TableRow extends HBoxContainer:
 func _ready() -> void:
  sort_children.connect(queue_redraw)
 func _draw() -> void:
  if has_meta("no_grid"):return
  for i in range(1,get_child_count()):
   var x=get_child(i).position.x
   draw_line(Vector2(x,0),Vector2(x,size.y),Color(.75,.66,.35,.24),1)
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 var style=StyleBoxFlat.new();style.bg_color=Color(.014,.019,.016,.86);style.border_color=GOLD;style.set_border_width_all(1)
 style.content_margin_left=18;style.content_margin_right=18;style.content_margin_top=12;style.content_margin_bottom=10;add_theme_stylebox_override("panel",style)
 scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER;scroll.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(scroll)
 content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",3);scroll.add_child(content)
 resized.connect(func():last_signature="";queue_redraw();if_ready_refresh.call_deferred())
func if_ready_refresh() -> void:
 if is_instance_valid(game) and game.running:refresh(true)
func cell(text: String,weight: float,color: Color=Color("eeede2"),center: bool=true,serif: bool=false,pixels: int=15) -> Label:
 var l=Label.new();l.text=text;l.clip_text=true;l.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;l.size_flags_horizontal=Control.SIZE_EXPAND_FILL;l.size_flags_stretch_ratio=weight;l.custom_minimum_size.y=maxf(16,(pixels+8)*scale_factor)
 l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT;l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;l.add_theme_color_override("font_color",color);l.add_theme_font_override("font",load("res://assets/title.ttf" if serif else "res://assets/body.ttf"));l.add_theme_font_size_override("font_size",roundi(pixels*scale_factor));l.mouse_filter=Control.MOUSE_FILTER_IGNORE;return l
func team_color(faction: int) -> Color:
 if game.team_characters[0]==game.team_characters[1]:return Color("b73535") if faction==0 else Color("65a675")
 return Color("b73535") if game.team_characters[clampi(faction,0,1)]==1 else Color("7da680")
func stats_for(actor: NestActor) -> Array:
 if game.mode==game.MODE_CTF:return [actor.kills,actor.deaths,actor.assists,actor.captures,actor.flag_returns,actor.captures]
 return [actor.kills,actor.deaths,actor.assists,actor.delivered,actor.detonations,actor.delivered+actor.detonations] if game.mode==0 else [actor.kills,actor.deaths,actor.assists,actor.kills]
func role_for(actor: NestActor) -> String:
 if game.network_active and actor.remote_peer==1:return "HOST"
 if actor.local_player:return "YOU"
 return "PLAYER" if actor.remote_peer>1 else "BOT"
func ping_for(actor: NestActor) -> String:
 if role_for(actor)=="BOT":return "—"
 if not game.network_active:return "—"
 if actor.remote_peer==1:return "0 ms" if not game.is_client() else "%d ms"%roundi(float(game.net_stats.get("enet_rtt_ms",0))) if game.net_stats.has("enet_rtt_ms") else "—"
 if game.is_client():return "—"
 if game.multiplayer.multiplayer_peer is ENetMultiplayerPeer:
  var peer=game.multiplayer.multiplayer_peer.get_peer(actor.remote_peer)
  if peer!=null:return "%d ms"%roundi(peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
 return "—"
func line(panel: bool=false) -> HBoxContainer:
 var row=TableRow.new();row.add_theme_constant_override("separation",0)
 if not panel:content.add_child(row)
 return row
func refresh(force: bool=false) -> void:
 if content==null:return
 if last_signature!="" and get_meta("inspection_signature",false)!=inspecting:last_signature=""
 set_meta("inspection_signature",inspecting)
 scale_factor=clampf(size.x/1000,.55,1.1)
 var remaining=maxf(0,(float(game.site_states[game.bomb_site].bomb_at) if game.mode==game.MODE_CS and game.cs_planted() else game.deadline)-game.now)
 var clock=("%d:%02d"%[int(remaining)/60,int(remaining)%60]) if is_finite(remaining) else "NO LIMIT"
 var signature=str([game.mode,game.round_number,game.scores,game.team_characters,game.attacking_faction,roundi(size.x),clock])
 for actor in game.actors:signature+=str([actor.get_instance_id(),actor.username,actor.faction,actor.alive,actor.rank_human,actor.rank_practice,stats_for(actor),ping_for(actor)])
 if not force and signature==last_signature:return
 last_signature=signature
 for child in content.get_children():content.remove_child(child);child.queue_free()
 var title_line=line();title_line.set_meta("no_grid",true);title_line.add_theme_constant_override("separation",10)
 var title=cell("ANCIENT",1,Color("f2ead0"),true,true,38);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;title_line.add_child(title)
 var crest=NestFactionEmblem.new();crest.custom_minimum_size=Vector2(56,54)*scale_factor;title_line.add_child(crest)
 title=cell("NEST",1,Color("f2ead0"),true,true,38);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;title_line.add_child(title)
 content.add_child(cell("◇  S  C  O  R  E  B  O  A  R  D  ◇",1,GOLD,true,true,17))
 var limit=" · FIRST TO %d"%game.tuning.score_limit if game.tuning.score_limit>0 else ""
 content.add_child(cell(game.arena.map_title().to_upper()+" · "+game.MODE_NAMES[game.mode]+limit,1,Color("ddd9c8"),true,true,13))
 timer=cell("ROUND %d  ·  %s REMAINING"%[game.round_number,clock],1,GOLD,true,true,13);content.add_child(timer)
 for faction in ([-1] if game.mode==1 else [0,1]):
  var actors=game.actors.filter(func(a):return faction==-1 or a.faction==faction)
  actors.sort_custom(func(a,b):return stats_for(a).back()>stats_for(b).back() if stats_for(a).back()!=stats_for(b).back() else a.username<b.username)
  var banner=PanelContainer.new();banner.name="TeamBanner%d"%faction;content.add_child(banner)
  var team_ink=team_color(maxi(0,faction));var bs=StyleBoxFlat.new();bs.bg_color=Color(team_ink.r*.19,team_ink.g*.19,team_ink.b*.13,.92);bs.border_color=GOLD;bs.set_border_width_all(1);bs.content_margin_left=8;bs.content_margin_right=8;banner.add_theme_stylebox_override("panel",bs)
  var band=line(true);banner.add_child(band)
  var emblem=NestFactionEmblem.new();emblem.annu=faction>=0 and game.team_characters[faction]==1;emblem.custom_minimum_size=Vector2(42,42)*scale_factor;band.add_child(emblem)
  var heading="ISO DEATHMATCH — STANDINGS" if faction<0 else game.team_name(faction).to_upper()
  if faction>=0 and game.mode in [0,game.MODE_CS]:heading+=" — "+("ATTACKERS" if faction==game.attacking_faction else "DEFENDERS")
  band.add_child(cell(heading,5,Color("f1ead1"),false,true,24))
  band.add_child(cell(str(game.scores[faction]) if faction>=0 else str(actors[0].kills if not actors.is_empty() else 0),1,Color.WHITE,true,true,30))
  if game.mode==0:
   var delivered=0;var bombs=0
   for actor in actors:delivered+=actor.delivered;bombs+=actor.detonations
   band.add_child(cell("GOLD DELIVERED\n%d"%delivered,1.6,GOLD,true,true,12));band.add_child(cell("BOMB DETONATIONS\n%d"%bombs,1.8,GOLD,true,true,12))
  var headings=["PLAYER","KILLS","DEATHS","ASSISTS"]
  if game.mode==0:headings.append_array(["GOLD DELIVERED","BOMB DETONATIONS"])
  elif game.mode==game.MODE_CTF:headings.append_array(["CAPTURES","FLAG RETURNS"])
  headings.append("PING")
  var widths=[3.4,1.0,1.0,1.0,1.5,1.8,1.0] if game.mode==0 else [3.4,1.0,1.0,1.0,1.25,1.25,1.0] if game.mode==game.MODE_CTF else [3.6,1.0,1.0,1.0,1.0]
  var header=line()
  for i in range(headings.size()):header.add_child(cell(headings[i],widths[i],GOLD,i!=0,true,11))
  for actor in actors:
   var panel=PanelContainer.new();panel.set_meta("actor",actor);content.add_child(panel)
   var style=StyleBoxFlat.new();style.bg_color=Color(.32,.25,.06,.52) if actor.local_player else Color(.015,.018,.017,.54);style.border_color=GOLD if actor.local_player else Color(.7,.65,.4,.17);style.border_width_bottom=1
   if actor.local_player:style.border_width_top=1;style.border_width_left=2
   panel.add_theme_stylebox_override("panel",style)
   var row=line(true);panel.add_child(row)
   var player_cell=HBoxContainer.new();player_cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL;player_cell.size_flags_stretch_ratio=widths[0];player_cell.add_theme_constant_override("separation",4);row.add_child(player_cell)
   var points=actor.rank_human if game.ranked.channel=="human" else actor.rank_practice;var rank=NestRatingProfile.rank_for(points)
   var badge=TextureRect.new();badge.name="RankEmblem";badge.texture=NestRankBadge.emblem_for(points);badge.custom_minimum_size=Vector2(24,26)*scale_factor;badge.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;badge.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;player_cell.add_child(badge)
   var role=role_for(actor);var suffix=" [BOT]" if role=="BOT" else " [HOST]" if role=="HOST" else " [YOU]" if role=="YOU" else ""
   var name_label=cell(actor.username+suffix,1,Color("a19e91") if not actor.alive else Color("f3f0df"),false,true,15);name_label.name="PlayerName";player_cell.add_child(name_label)
   var account=str(game.lobby_members.get(actor.net_id,{}).get("account",""))
   if not account.is_empty():
    var tag=Button.new();tag.name="InspectPlayer";tag.text=actor.username;tag.flat=true;tag.disabled=not inspecting;tag.custom_minimum_size.y=32;tag.tooltip_text="Open overall service card";tag.pressed.connect(func():game.accounts.show_service_card(account));player_cell.remove_child(name_label);name_label.queue_free();player_cell.add_child(tag)
   var rank_label=cell("%d/21 · %d"%[rank.number,points],.7,Color("aea58c"),true,false,10);player_cell.add_child(rank_label)
   var values=stats_for(actor);values.pop_back()
   for i in range(values.size()):row.add_child(cell(str(values[i]),widths[i+1],Color("e9e5d9"),true,true,15))
   row.add_child(cell(ping_for(actor),widths.back(),Color("c9c6b9"),true,false,13))
 var footer=cell("◇   HOLD %s TO VIEW  ·  F2 TO INSPECT  ·  ESC TO RETURN   ◇"%game.prefs.key_label("scoreboard"),1,GOLD,true,true,12);content.add_child(footer)
 content.add_child(cell("Online match continues · PgUp/PgDn to scroll." if game.network_active else "Match continues · PgUp/PgDn to scroll.",1,Color("c0bcad"),true,false,11))
 game.make_hud_passthrough(self)
 if inspecting:enable_inspection(self)
func _draw() -> void:
 for corner in [Vector2(4,4),Vector2(size.x-4,4),Vector2(4,size.y-4),size-Vector2(4,4)]:
  var d=Vector2(1 if corner.x<size.x*.5 else -1,1 if corner.y<size.y*.5 else -1)
  draw_polyline(PackedVector2Array([corner+Vector2(0,10*d.y),corner,corner+Vector2(10*d.x,0),corner+Vector2(0,10*d.y)]),GOLD,1,true)
func _unhandled_key_input(event: InputEvent) -> void:
 if not is_visible_in_tree() or game.context!="playing" or not event is InputEventKey or not event.pressed:return
 if event.keycode in [KEY_PAGEUP,KEY_PAGEDOWN]:
  scroll.scroll_vertical+=roundi(scroll.size.y*.7)*(1 if event.keycode==KEY_PAGEDOWN else -1)
  get_viewport().set_input_as_handled()
func _process(_delta: float) -> void:
 if is_visible_in_tree() and is_instance_valid(game) and game.now>=next_refresh:next_refresh=game.now+.2;refresh()

func enable_inspection(node: Node) -> void:
 if node is Control:node.mouse_filter=Control.MOUSE_FILTER_STOP if node is Button else Control.MOUSE_FILTER_PASS
 for child in node.get_children():enable_inspection(child)
func begin_inspection() -> void:
 inspecting=true;game.clear_held_input();game.context="scoreboard";Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;last_signature="";refresh(true)
 var names=find_children("InspectPlayer","Button",true,false)
 if not names.is_empty():names[0].grab_focus()
func end_inspection() -> void:
 inspecting=false;game.clear_held_input();game.context="playing";Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;last_signature=""
