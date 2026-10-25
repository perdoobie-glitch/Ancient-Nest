class_name NestCampaignUI
extends RefCounted
static func page(c,title: String) -> VBoxContainer:
 var game=c.game;game.clear_screen();game.shade(.84);game.hud.visible=false;game.current_screen="campaign";game.context="menu";Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 var size=game.get_viewport().get_visible_rect().size;var body=game.center_panel(minf(820,size.x-24),minf(740,size.y-24));game.header(body,"ANCIENT NEST / CAMPAIGN",title);return body
static func menu(c):
 var body=page(c,"THE LAST DEPARTURE");var game=c.game
 body.add_child(game.label("Mission 1 of a planned nine • Connectuct → Old Earth\nSolo offline or 1–4 expedition members. Campaign progress is unranked.",15,game.MUTED))
 body.add_child(game.label("Difficulty",18,game.GOLD));var difficulty=OptionButton.new();difficulty.name="CampaignDifficulty";difficulty.custom_minimum_size.y=42
 for value in NestCampaignState.DIFFICULTIES:difficulty.add_item(value)
 difficulty.select(NestCampaignState.DIFFICULTIES.find(c.selected_difficulty));difficulty.item_selected.connect(func(i):c.selected_difficulty=NestCampaignState.DIFFICULTIES[i]);body.add_child(difficulty)
 var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(scroll);var actions=VBoxContainer.new();actions.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(actions)
 actions.add_child(game.button("New Campaign",func():c.begin_solo(false)))
 var saved=c.save_store.load_checkpoint();var continue_button=game.button("Continue",func():c.begin_solo(true));continue_button.name="CampaignContinue";continue_button.disabled=saved.is_empty();actions.add_child(continue_button)
 actions.add_child(game.button("Host Co-op",func():connection(c,true)))
 actions.add_child(game.button("Join Co-op",func():connection(c,false)))
 if not c.notice.is_empty():actions.add_child(game.label(c.notice,14,game.GOLD))
 game.footer(body,false).add_child(game.button("Back",func():game.show_main()))
static func connection(c,hosting: bool):
 var body=page(c,"HOST CO-OP" if hosting else "JOIN CO-OP");var game=c.game
 var note=game.label("Play on your local network, or use a reachable host address and UDP port.\nJoin before the introduction. Existing members can reconnect to the same host.",14,game.MUTED);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(note)
 var address=LineEdit.new();address.placeholder_text="Host address";address.text="127.0.0.1";address.visible=not hosting;body.add_child(address)
 var port=SpinBox.new();port.min_value=1024;port.max_value=65535;port.value=7779;body.add_child(game.label("UDP port",15));body.add_child(port)
 body.add_child(game.label("Difficulty: "+c.selected_difficulty if hosting else "Difficulty is selected by the host.",18,game.GOLD))
 body.add_child(game.button("Create Expedition" if hosting else "Connect",func():c.open_coop(hosting,address.text.strip_edges(),int(port.value))))
 game.footer(body).add_child(game.button("Back",func():menu(c)))
static func lobby(c):
 var body=page(c,"EXPEDITION READINESS");var game=c.game;game.current_screen="campaign_lobby"
 body.add_child(game.label("Difficulty: "+c.state.difficulty,19,game.GOLD))
 body.add_child(game.label(game.network_status+"\nHost selects Difficulty before creating the expedition. No changes during a mission.",14,game.MUTED))
 for slot in c.members:
  var m=c.members[slot];body.add_child(game.label(str(m.name)+(" • ANKI / HOST" if int(slot)==1 else " • EXPEDITION MEMBER")+(" • READY" if m.get("ready",false) else " • NOT READY")+(" • DISCONNECTED" if not m.get("connected",true) else ""),16))
 if c.members.has(c.local_slot):body.add_child(game.button("Toggle Ready",func():c.send_action("ready",{})))
 if not game.is_client():
  var start=game.button("Launch Introduction",func():c.start_expedition());start.disabled=not c.everyone_ready();body.add_child(start)
 body.add_child(game.label("All connected players must be ready. During cinematics Enter votes to skip; all connected players must agree.",14,game.MUTED))
 game.footer(body).add_child(game.button("Leave Expedition",func():c.exit_campaign()))
static func pause(c):
 var body=page(c,"MISSION PAUSED" if not c.game.network_active else "SQUAD MISSION CONTINUES");var game=c.game;game.current_screen="campaign_pause";game.context="pause"
 body.add_child(game.label("THE LAST DEPARTURE\nDifficulty: "+c.state.difficulty,20,game.GOLD));body.add_child(game.label(c.objective(),15,game.MUTED))
 body.add_child(game.button("Resume",func():c.resume()))
 if c.guide!=null and not c.guide.current.is_empty():
  body.add_child(game.button("Repeat Brutus / Resume",func():c.resume();c.guide.repeat_current()))
  var recorded=ResourceLoader.exists("res://audio/campaign/guide_"+str(c.guide.current.id)+".wav")
  var voice_status="Narration: recorded briefing" if recorded else ("Narration: local system speech" if c.guide.voice_supported else "Voice unavailable on this device; subtitles and control guidance remain available.")
  body.add_child(game.label(voice_status,14,game.MUTED))
 body.add_child(game.button("Settings / Controls",func():game.open_settings("pause")))
 for item in [["Dialogue","campaign_dialogue"],["Music","campaign_music"],["Effects","campaign_effects"]]:
  body.add_child(game.label(item[0],14));var slider=HSlider.new();slider.min_value=0;slider.max_value=1;slider.step=.05;slider.value=float(game.prefs.values.get(item[1],.8));var key=item[1];slider.value_changed.connect(func(v):game.prefs.values[key]=v;game.prefs.save());body.add_child(slider)
 body.add_child(game.label("Flashlight: "+game.prefs.key_label("flashlight")+" • Sprint: "+game.prefs.key_label("sprint")+" • Interact / revive: "+game.prefs.key_label("interact"),14,game.MUTED))
 game.footer(body).add_child(game.button("Save checkpoint / Return to Campaign",func():c.exit_campaign()))
static func defeat(c):
 var body=page(c,"SQUAD DOWN");c.game.current_screen="campaign_defeat"
 body.add_child(c.game.label("Difficulty: "+c.state.difficulty+"\nRetry restores the last safe milestone. Mid-wave retries preserve secured charge progress and replay the current wave.",16,c.game.MUTED))
 if not c.game.is_client():body.add_child(c.game.button("Retry Checkpoint",func():c.retry_checkpoint()))
 else:body.add_child(c.game.label("Waiting for the host to retry the checkpoint.",17))
 c.game.footer(body).add_child(c.game.button("Return to Campaign",func():c.exit_campaign()))
static func complete(c):
 var body=page(c,"MISSION COMPLETE");c.game.current_screen="campaign_complete"
 body.add_child(c.game.title("THE LAST DEPARTURE",26));body.add_child(c.game.label("Difficulty: "+c.state.difficulty+"\n34 Annu defeated • Excavation charge secured • Expedition relay contacted",16,c.game.GOLD))
 body.add_child(c.game.label("Ancient AI: “Your arrival has been recorded.”\nBrutus: “That was not the relay.”",18))
 if not c.game.is_client():body.add_child(c.game.button("Replay Mission",func():c.replay()))
 c.game.footer(body).add_child(c.game.button("Return to Campaign",func():c.exit_campaign()))
