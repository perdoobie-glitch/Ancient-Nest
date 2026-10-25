class_name NestCampaignGuide
extends Node
# Presentation follows local authoritative progress; it never advances objectives.
var campaign
var panel: PanelContainer
var heading: Label
var instruction: Label
var controls: Label
var marker: Label
var narration: Label
var player: AudioStreamPlayer
var current={}
var last_step=""
var spoken_step=""
var voice_id=""
var voice_supported=false
var utterance=0
var spoken_at=-100.0
var spoken_until=0.0
var welcome_until=0.0
var last_phase=""
var spoken_text=""
var next_update=0.0
var pause_since=-1.0
var os_speaking=false
func _ready():
 player=AudioStreamPlayer.new();player.bus="Campaign_Dialogue";add_child(player)
 if OS.get_environment("NEST_ISOLATED_QA")!="1" and DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
  var voices=DisplayServer.tts_get_voices()
  for candidate in voices:
   if str(candidate.get("language","")).begins_with("en"):
    if voice_id.is_empty() or str(candidate.name).to_lower().contains("david"):voice_id=str(candidate.id)
  voice_supported=not voice_id.is_empty()
func cue(id: String,title: String,text: String,keys: String,voice: String,target="") -> Dictionary:
 return {"id":id,"title":title,"text":text,"keys":keys,"voice":voice,"target":target}
func binding(action: String) -> String:return campaign.game.prefs.key_label(action)
func next_step() -> Dictionary:
 var c=campaign;var progress=c.state.practice.get(str(c.local_slot),{})
 if c.state.phase=="PREPARATION":
  if not progress.get("look",false):return cue("look","01 / ORIENT YOURSELF","Move the mouse to look around the departure deck.","LOOK  Mouse  •  PAUSE / CONTROLS  "+binding("pause"),"Anki. Brutus here. Before we leave Connectuct, verify your suit and weapons. Start by looking around the departure deck.")
  if not progress.get("walk",false):return cue("walk","02 / MOVE TO THE EQUIPMENT TERMINAL","Walk toward the cyan equipment marker.","MOVE  "+binding("forward")+" / "+binding("left")+" / "+binding("backward")+" / "+binding("right"),"Walk toward the marked equipment terminal. Your movement controls are on screen.","service")
  if not progress.get("sprint",false):return cue("sprint","03 / TEST YOUR SPRINT","Hold Sprint while moving on the deck.","SPRINT  "+binding("sprint")+" + movement","Hold the highlighted sprint control while moving.","service")
  if not progress.get("jump",false):return cue("jump","04 / CHECK YOUR MOBILITY","Jump once on the open deck.","JUMP  "+binding("jump"),"Test your jump on the open deck.","service")
  if not progress.get("interact",false):return cue("service","05 / VERIFY YOUR EQUIPMENT","Approach terminal 01. Hold Interact until the check completes.","HOLD  "+binding("interact")+"  near the terminal","Hold interact at the equipment terminal until the suit check completes.","service")
  if not progress.get("calibrating",false):return cue("calibrate","06 / LOAD YOUR SHIELD","Go to terminal 02 and hold Interact. This safely drains your shield.","HOLD  "+binding("interact"),"Go to the shield calibration terminal. The test drains your shield, not your health.","calibration")
  if not progress.get("shield",false):return cue("recover","07 / TAKE COVER AND RECHARGE","Move behind the marked barrier. Wait there until your shield is full.","MOVE to cover  •  wait for the shield bar","Take cover behind the calibration barrier. Break contact and wait for your shield to recharge.","shield_cover")
  if not progress.get("aim",false):return cue("aim","08 / AIM AT THE FIRING TARGETS","Use the safe firing bay ahead. Aim down your weapon sights.","AIM  Right mouse  /  "+binding("zoom"),"Proceed to the safe firing bay. Aim down your sights at the gold targets.","range")
  if not progress.get("fire",false):return cue("fire","09 / FIRE YOUR CARBINE","Fire a short burst at a gold practice target.","FIRE  Left mouse","Fire a short burst at a practice target. These checks do not consume mission progress.","range")
  if not progress.get("reload",false):return cue("reload","10 / RELOAD","Reload after firing. Let the reload animation finish.","RELOAD  "+binding("reload"),"Reload your weapon after firing.","range")
  if not progress.get("switch",false):return cue("switch","11 / CHECK YOUR SIDEARM","Draw your secondary weapon, then return to your carbine.","PRIMARY  "+binding("primary_weapon")+"  •  SECONDARY  "+binding("secondary_weapon")+"  •  CYCLE  "+binding("switch_weapon"),"Draw your sidearm. The weapon selection controls are highlighted.","range")
  if not progress.get("crouch",false):return cue("crouch","12 / ENTER THE SERVICE PASSAGE","Approach passage 04. Crouch beneath its low beam.","CROUCH  "+binding("crouch"),"Enter the service passage. Crouch beneath the low beam.","inspection")
  if not progress.get("flashlight",false):return cue("flashlight","13 / TEST YOUR LIGHT","Switch on your flashlight in the dark service passage.","FLASHLIGHT  "+binding("flashlight"),"Switch on your flashlight. You will need it on Old Earth.","inspection")
  return cue("wait","PERSONAL CHECKS COMPLETE","Your suit is ready. Wait for the rest of the expedition.","REPEAT GUIDANCE  "+binding("campaign_hint"),"Personal checks complete. Waiting for the rest of the expedition.","manifest")
 if c.state.phase=="BOARDING":
  if not progress.get("manifest",false):return cue("manifest","14 / CONFIRM THE CARGO","Hold Interact at terminal 05 beside the ship. Confirm the sealed excavation charge.","HOLD  "+binding("interact"),"Readiness complete. Inspect the sealed excavation charge at the cargo terminal beside the ship.","manifest")
  if not progress.get("boarded",false):return cue("board","15 / ENTER THE EXPEDITION SHIP","Walk through the open hatch into the cabin. Hold Interact at the marked boarding position.","MOVE into the ship  •  HOLD  "+binding("interact"),"The charge is isolated and secured. Enter the ship through the open hatch. Hold interact inside to secure your position.","board")
  return cue("boarded","ABOARD / WAITING FOR SQUAD","You are aboard. Departure begins when every connected member has boarded.","PAUSE  "+binding("pause"),"You are aboard. Departure begins when the whole expedition is secured.","board")
 if c.world!=null and c.world.region=="forest" and c.state.bomb=="carried":return cue("secure","SECURE THE RECOVERED CHARGE","Bring the case to the surviving cargo locker. Hold Interact beside it.","HOLD  "+binding("interact"),"Bring the charge to the marked cargo locker and hold interact to secure it.","secure")
 if c.state.phase in ["CRASH_ORIENTATION","WAVE_1"] and c.state.completed_waves==0 and (c.state.phase=="CRASH_ORIENTATION" or c.phase_elapsed<12) and c.state.bomb!="secured":
  if c.game.player!=null and c.game.player.global_position.z>21:
   var charge="charge"+str(c.state.charge_site);var close=c.game.player.global_position.distance_to(c.world.locations[charge])<18
   return cue("charge","LOCATE THE EXCAVATION CHARGE","You are clear of the wreck. Search beside the hull; the equipment locator appears within 18 metres. Hold Interact at the case.","HOLD  "+binding("interact")+" at the charge  •  FLASHLIGHT  "+binding("flashlight"),"You are clear of the wreck. Locate the excavation charge beside the hull. The short-range locator will help you find it.",charge if close else "")
  return cue("crash","OLD EARTH / GET CLEAR OF THE WRECK","Exit through the open hatch. Recover the missing charge, confirm it is safe, and secure it in the cargo locker.","MOVE  "+binding("forward")+" / "+binding("left")+" / "+binding("backward")+" / "+binding("right")+"  •  FLASHLIGHT  "+binding("flashlight"),"Anki, get clear of the wreck. Locate the excavation charge, confirm it is isolated, and secure it in the surviving cargo locker.","exit")
 if c.state.phase=="RADIO_READY":return cue("radio","CONTACT THE EXPEDITION RELAY","Return to the ship's emergency radio. Hold Interact to transmit your position.","HOLD  "+binding("interact"),"The perimeter is clear and the charge is secured. Return to the emergency radio and transmit our position.","radio")
 return {}
func build_ui():
 var game=campaign.game
 panel=PanelContainer.new();panel.name="CampaignGuidance";panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;game.hud.add_child(panel)
 var style=StyleBoxFlat.new();style.bg_color=Color(.025,.055,.075,.94);style.border_color=Color("4fbaab");style.border_width_left=4;style.content_margin_left=14;style.content_margin_right=14;style.content_margin_top=10;style.content_margin_bottom=10;panel.add_theme_stylebox_override("panel",style)
 var body=VBoxContainer.new();panel.add_child(body)
 heading=game.label("",17,Color("91e8d1"));heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(heading)
 instruction=game.label("",16,Color("f1ece0"));instruction.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(instruction)
 controls=game.label("",14,Color("e8c482"));controls.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(controls)
 marker=game.label("",17,Color("93f5db"));marker.name="CampaignWaypoint";marker.mouse_filter=Control.MOUSE_FILTER_IGNORE;marker.add_theme_color_override("font_outline_color",Color.BLACK);marker.add_theme_constant_override("outline_size",5);game.hud.add_child(marker)
 narration=game.label("",17,Color("f0f0db"));narration.name="CampaignGuideSubtitles";narration.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;narration.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;narration.mouse_filter=Control.MOUSE_FILTER_IGNORE;narration.add_theme_color_override("font_outline_color",Color.BLACK);narration.add_theme_constant_override("outline_size",5);game.hud.add_child(narration)
func stop_voice():
 player.stop()
 if voice_supported and not spoken_step.is_empty():DisplayServer.tts_stop()
 os_speaking=false
 spoken_until=0
func speak(step: Dictionary,repeat=false):
 if step.is_empty():return
 stop_voice();spoken_step=str(step.id);spoken_text=str(step.voice);spoken_at=campaign.game.local_clock();utterance+=1
 var path="res://audio/campaign/guide_"+str(step.id)+".wav"
 var gain=float(campaign.game.prefs.values.campaign_dialogue)
 if ResourceLoader.exists(path):
  player.stream=load(path);spoken_until=spoken_at+player.stream.get_length()
  if DisplayServer.get_name()!="headless" and gain>0:player.play()
 elif voice_supported and gain>0 and float(campaign.game.prefs.values.master)>0 and DisplayServer.get_name()!="headless":
  # OS speech is a fallback, not an actor recording. Never synthesizes over HTTP.
  DisplayServer.tts_speak(str(step.voice),voice_id,roundi(gain*float(campaign.game.prefs.values.master)*100),.88,.95,utterance,true)
  os_speaking=true
  spoken_until=spoken_at+maxf(3,str(step.voice).split(" ").size()*.42)
 else:spoken_until=spoken_at+maxf(3,str(step.voice).split(" ").size()*.42)
 if step.id=="look" and not repeat:welcome_until=spoken_until
func repeat_current():
 if not current.is_empty():speak(current,true)
func update(force=false):
 var c=campaign;var game=c.game
 var now=game.local_clock()
 if not force and is_instance_valid(panel) and last_phase==c.state.phase and now<next_update:return
 next_update=now+.1
 current=next_step()
 if not is_instance_valid(panel):build_ui()
 var visible=not current.is_empty() and game.context=="playing" and game.player!=null and game.player.alive and not c.paused()
 panel.visible=visible;marker.visible=false;narration.visible=false
 if is_instance_valid(c.radio_subtitle):c.radio_subtitle.visible=true
 if not visible:
  if last_phase!=c.state.phase:stop_voice();spoken_step="";last_step="";welcome_until=0
  last_phase=c.state.phase
  player.stream_paused=c.paused()
  if c.paused():
   if pause_since<0:pause_since=now
   if voice_supported:DisplayServer.tts_pause()
  return
 if pause_since>=0:
  var delay=now-pause_since;spoken_until+=delay;spoken_at+=delay;welcome_until+=delay;pause_since=-1
 player.stream_paused=false
 if voice_supported:DisplayServer.tts_resume()
 if os_speaking and (float(game.prefs.values.campaign_dialogue)<=0 or float(game.prefs.values.master)<=0):DisplayServer.tts_stop();os_speaking=false
 var size=game.get_viewport().get_visible_rect().size
 panel.position=Vector2(22,178 if size.y>600 else 95);panel.size=Vector2(minf(490,size.x-44),0)
 heading.text=current.title;instruction.text=current.text;controls.text=current.keys+"\nREPEAT BRUTUS  "+binding("campaign_hint")
 for id in c.world.station_signs:
  c.world.station_signs[id].visible=str(current.target)==id or game.player.global_position.distance_squared_to(c.world.locations[id])<36
 if last_phase!="PREPARATION" and c.state.phase=="PREPARATION":
  speak(cue("look","","","","Anki. Brutus here. Before we leave Connectuct, verify your suit and weapons. Start by looking around the departure deck."))
 if str(current.id)!=spoken_step and (spoken_step.is_empty() or (now>=welcome_until and now-spoken_at>2.2)):
  # Let existing story dialogue finish before the post-crash gameplay briefing.
  if c.state.phase!="CRASH_ORIENTATION" or c.phase_elapsed>=24:speak(current)
 last_step=str(current.id);last_phase=c.state.phase
 narration.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);narration.offset_left=30;narration.offset_right=-30;narration.offset_top=-140;narration.offset_bottom=-65
 narration.visible=now<spoken_until;narration.text="BRUTUS: "+spoken_text
 if is_instance_valid(c.radio_subtitle):c.radio_subtitle.visible=not narration.visible
 if str(current.target).is_empty() or not c.world.locations.has(current.target):return
 var target=c.world.locations[current.target]+Vector3.UP*1.8;var camera=game.player.camera;var distance=game.player.global_position.distance_to(target)
 var point=camera.unproject_position(target) if not camera.is_position_behind(target) else Vector2(size.x-150,size.y*.55)
 var upper=minf(panel.position.y+panel.size.y+18,size.y-170);var lower=maxf(upper,size.y-240 if size.y>600 else size.y-155)
 point.x=clampf(point.x,28,size.x-220);point.y=clampf(point.y,upper,lower)
 marker.position=point;marker.text="◈ "+str(current.target).replace("_"," ").to_upper()+"  %d m"%roundi(distance);marker.visible=true
func _exit_tree():
 stop_voice()
 for node in [panel,marker,narration]:
  if is_instance_valid(node):node.queue_free()
