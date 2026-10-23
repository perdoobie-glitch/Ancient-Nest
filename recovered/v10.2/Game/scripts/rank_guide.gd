class_name NestRankGuide
extends RefCounted
static func show(game) -> void:
 if game.current_screen=="matchmaking_ranks" and game.screen.has_node("RankGuide"):return
 game.current_screen="matchmaking_ranks";game.context="menu";game.clear_screen();game.shade(.92);game.hud.visible=false;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 var marker=Node.new();marker.name="RankGuide";game.screen.add_child(marker)
 var size=game.get_viewport().get_visible_rect().size
 var body=game.center_panel(minf(1160,size.x-32),minf(820,size.y-32))
 game.header(body,"MATCHMAKING", "RANKS & RATING")
 var tabs=HBoxContainer.new();body.add_child(tabs)
 tabs.add_child(game.button("Playlists",func():game.set_meta("rank_guide",false);game.show_matchmaking()))
 var selected=game.button("Ranks & rating",func():pass);selected.disabled=true;tabs.add_child(selected)
 var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(scroll)
 var content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",14);scroll.add_child(content)
 var info=game.label("21 numbered stages · Independent stats for each playlist\nStart at Forgebound I, rank 1 and Elo 1. A new stage begins every 150 Elo. Rank level 21 is Angel; Elo can continue rising without a ceiling.",16);info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;content.add_child(info)
 var grid=GridContainer.new();grid.columns=3 if size.x>=1050 else 2 if size.x>=720 else 1;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_theme_constant_override("h_separation",14);grid.add_theme_constant_override("v_separation",14);content.add_child(grid)
 var descriptions=["Your first foothold in the Nest.","A focused competitor learning to strike.","A reliable presence holding the line.","A proven fighter leading the advance.","An elite guardian of the battlefield.","A commanding veteran of the Nest.","The highest competitive rank."]
 for group in range(7):
  var panel=PanelContainer.new();panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_child(panel)
  var card=VBoxContainer.new();card.add_theme_constant_override("separation",8);panel.add_child(card)
  card.add_child(game.label(NestRatingProfile.NAMES[group].to_upper(),18,game.IVORY))
  var description=game.label(descriptions[group],13,game.MUTED);description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;card.add_child(description)
  var tiers=HBoxContainer.new();tiers.alignment=BoxContainer.ALIGNMENT_CENTER;card.add_child(tiers)
  for tier in range(3):
   var stage=group*3+tier;var tile=VBoxContainer.new();tile.name="RankGuideStage%02d"%(stage+1);tiers.add_child(tile)
   var emblem=TextureRect.new();emblem.texture=NestRankBadge.emblem_for(stage*150);emblem.custom_minimum_size=Vector2(62,68);emblem.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;emblem.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;tile.add_child(emblem)
   var band="3000+" if stage==20 else "%d–%d"%[maxi(1,stage*150),(stage+1)*150-1]
   var title="Angel" if stage==20 else ["I","II","III"][tier]
   var caption=game.label("%s · #%d\n%s"%[title,stage+1,band],12,game.IVORY);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;tile.add_child(caption)
 var rules=game.label("HOW RATINGS WORK\nMatchmaking rating uses the match result and the strength of the opposing team. Beating stronger opposition rewards more points; losses can reduce points and move you down a tier. Elo has a floor of 1 and no upper ceiling. K=32; team outcome and opponent strength determine the change.\n\nOnly completed matchmaking games affect ranking. Custom games and bot practice are unranked. The website/account service owns online match results. Local bot practice does not prove an online rank. The Account screen must be linked for account-required matchmaking.\n\nPlayer Rating out of 100 is a separate performance measure. It uses your latest five completed games in that playlist, starting with three. Grades: A+97+, A93+, A−90+, B+87+, B83+, B−80+, C+77+, C73+, C−70+, D+67+, D63+, D−60+, F below60. The current account service displays it after three completed matchmaking games in the selected playlist. Opening this guide does not cancel your search or change your rating.",14,game.MUTED)
 rules.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;content.add_child(rules)
 body.add_child(game.button("Back to matchmaking",func():game.set_meta("rank_guide",false);game.show_matchmaking()))
