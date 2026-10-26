class_name NestCampaignUI
extends RefCounted
static func page(c,title: String) -> VBoxContainer:
 var game=c.game;game.clear_screen();game.shade(.84);game.hud.visible=false;game.current_screen="campaign";game.context="menu";Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 var size=game.get_viewport().get_visible_rect().size;var body=game.center_panel(minf(820,size.x-24),minf(740,size.y-24));game.header(body,"ANCIENT NEST / CAMPAIGN",title);return body
static func menu(c):
 var body=page(c,"TAKE BACK HOME");var game=c.game
 body.add_child(game.label("Nine missions • Connectuct → Old Earth → Home\nSolo offline or 1–4 expedition members. Campaign progress is unranked.",15,game.MUTED))
 body.add_child(game.label("Difficulty",18,game.GOLD));var difficulty=OptionButton.new();difficulty.name="CampaignDifficulty";difficulty.custom_minimum_size.y=42
 for value in NestCampaignState.DIFFICULTIES:difficulty.add_item(value)
 difficulty.select(NestCampaignState.DIFFICULTIES.find(c.selected_difficulty));difficulty.item_selected.connect(func(i):c.selected_difficulty=NestCampaignState.DIFFICULTIES[i]);body.add_child(difficulty)
 var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(scroll);var actions=VBoxContainer.new();actions.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(actions)
 actions.add_child(game.button("New Campaign / Begin at Mission 1",func():c.selected_mission=1;c.begin_solo(false)))
 var saved=c.save_store.load_checkpoint();var continue_button=game.button("Continue",func():c.begin_solo(true));continue_button.name="CampaignContinue";continue_button.disabled=saved.is_empty();actions.add_child(continue_button)
 actions.add_child(game.button("Host Co-op",func():c.selected_mission=1;connection(c,true)))
 actions.add_child(game.button("Join Co-op",func():connection(c,false)))
 actions.add_child(game.button("Mission Select / Play Levels 2–9",func():mission_select(c)))
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
  var start=game.button("Launch Introduction" if c.selected_mission==1 else "Launch Mission "+str(c.selected_mission),func():c.start_expedition());start.disabled=not c.everyone_ready();body.add_child(start)
 body.add_child(game.label("All connected players must be ready. During cinematics Enter votes to skip; all connected players must agree.",14,game.MUTED))
 game.footer(body).add_child(game.button("Leave Expedition",func():c.exit_campaign()))
static func pause(c):
 var body=page(c,"MISSION PAUSED" if not c.game.network_active else "SQUAD MISSION CONTINUES");var game=c.game;game.current_screen="campaign_pause";game.context="pause"
 body.add_child(game.label((c.journey.title() if c.state.mission_index>1 else "THE LAST DEPARTURE")+"\nDifficulty: "+c.state.difficulty,20,game.GOLD));body.add_child(game.label(c.objective(),15,game.MUTED))
 body.add_child(game.button("Resume",func():c.resume()))
 if c.guide!=null and not c.guide.current.is_empty():
  body.add_child(game.button("Repeat Brutus / Resume",func():c.resume();c.guide.repeat_current()))
  var recorded=ResourceLoader.exists("res://audio/campaign/guide_"+str(c.guide.current.id)+".wav")
  var voice_status="Narration: recorded briefing" if recorded else ("Narration: local system speech" if c.guide.voice_supported else "Voice unavailable on this device; subtitles and control guidance remain available.")
  body.add_child(game.label(voice_status,14,game.MUTED))
 body.add_child(game.button("Settings / Controls",func():game.open_settings("pause")))
 for item in [["Dialogue","campaign_dialogue"],["Music","campaign_music"],["Effects","campaign_effects"]]:
  body.add_child(game.label(item[0],14));var slider=HSlider.new();slider.min_value=0;slider.max_value=1;slider.step=.05;slider.value=float(game.prefs.values.get(item[1],.8));var key=item[1];slider.value_changed.connect(func(v):game.prefs.values[key]=v;game.prefs.save());body.add_child(slider)
 body.add_child(game.label("Flashlight: "+game.prefs.key_label("flashlight")+" • Interact / revive: "+game.prefs.key_label("interact"),14,game.MUTED))
 game.footer(body).add_child(game.button("Save checkpoint / Return to Campaign",func():c.exit_campaign()))
static func defeat(c):
 var body=page(c,"SQUAD DOWN");c.game.current_screen="campaign_defeat"
 body.add_child(c.game.label("Difficulty: "+c.state.difficulty+"\nRetry restores the last safe milestone. Mid-wave retries preserve secured charge progress and replay the current wave.",16,c.game.MUTED))
 if not c.game.is_client():body.add_child(c.game.button("Retry Checkpoint",func():c.retry_checkpoint()))
 else:body.add_child(c.game.label("Waiting for the host to retry the checkpoint.",17))
 c.game.footer(body).add_child(c.game.button("Return to Campaign",func():c.exit_campaign()))
static func complete(c):
 if c.state.mission_index>1:
  chapter_complete(c);return
 var body=page(c,"MISSION COMPLETE");c.game.current_screen="campaign_complete"
 body.add_child(c.game.title("THE LAST DEPARTURE",26));body.add_child(c.game.label("Difficulty: "+c.state.difficulty+"\n34 Annu defeated • Excavation charge secured • Expedition relay contacted",16,c.game.GOLD))
 body.add_child(c.game.label("Ancient AI: “Your arrival has been recorded.”\nBrutus: “That was not the relay.”",18))
 if not c.game.is_client():
  body.add_child(c.game.button("Continue / Mission 2 — Broken Canopy",func():c.journey.start_mission(2)))
  body.add_child(c.game.button("Replay Mission",func():c.replay()))
 c.game.footer(body).add_child(c.game.button("Return to Campaign",func():c.exit_campaign()))

static func mission_select(c):
 var body=page(c,"MISSION SELECT");var game=c.game
 body.add_child(game.label("Start a new expedition at any chapter. Continue resumes your most recent checkpoint.\nDifficulty: "+c.selected_difficulty,15,game.MUTED))
 var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(scroll)
 var list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
 for mission in c.journey.catalog():
  var index=int(mission.index)
  list.add_child(game.button("%02d  /  %s"%[index,str(mission.title)],func():c.selected_mission=index;mission_launch(c)))
 game.footer(body).add_child(game.button("Back",func():menu(c)))

static func mission_launch(c):
 var body=page(c,c.journey.mission_title(c.selected_mission));var game=c.game
 var description="Four expedition motorcycles. Accelerate, dodge the trees, control your landing and keep moving past the Annu positions." if c.selected_mission==2 else "Follow the marked route, use cover and restore the next part of Old Earth's ancient infrastructure."
 var label=game.label(description+"\n\nDifficulty: "+c.selected_difficulty+"\nStarting this mission creates a new campaign checkpoint.",17,game.MUTED);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(label)
 body.add_child(game.button("Start Selected Mission / Solo",func():c.begin_solo(false)))
 body.add_child(game.button("Host Selected Mission / Co-op",func():connection(c,true)))
 game.footer(body).add_child(game.button("Back",func():mission_select(c)))

static func chapter_complete(c):
 var final_mission=c.state.mission_index==9;var body=page(c,"CONNECTUCT HAS A FUTURE" if final_mission else "MISSION COMPLETE");var game=c.game;game.current_screen="campaign_complete"
 body.add_child(game.title(c.journey.title(),26))
 var ending=game.label(c.journey.ending_text(),18,game.GOLD);ending.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(ending)
 if final_mission:
  var epilogue=game.label("Reclaimed gold and the custodial archive leave Old Earth together.\nThe living systems remain online. Connectuct can begin its repairs.\n\nANKI: We brought a future home. We left one here, too.",18,game.MUTED);epilogue.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(epilogue)
 if not game.is_client():
  if not final_mission:body.add_child(game.button("Continue / "+c.journey.mission_title(c.state.mission_index+1),func():c.journey.start_mission(c.state.mission_index+1)))
  body.add_child(game.button("Replay This Mission",func():c.journey.start_standalone(c.state.mission_index)))
 else:body.add_child(game.label("Waiting for the host to continue the expedition.",16,game.MUTED))
 game.footer(body).add_child(game.button("Return to Campaign",func():c.exit_campaign()))
