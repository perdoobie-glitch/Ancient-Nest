class_name NestCampaignCinematic
extends Node
var campaign
var camera: Camera3D
var voice: AudioStreamPlayer
var music: AudioStreamPlayer
var effects: AudioStreamPlayer
var overlay: Control
var subtitle: Label
var title: Label
var last_slot=""
var subtitle_override=""
var speech_cue=""
var speaking_os=false
var last_volumes={}
func _ready():
 camera=Camera3D.new();camera.name="CampaignCamera";camera.near=.1;camera.fov=62;camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;add_child(camera)
 for bus in ["Campaign_Dialogue","Campaign_Music","Campaign_Effects"]:
  if AudioServer.get_bus_index(bus)<0:AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
 voice=AudioStreamPlayer.new();voice.bus="Campaign_Dialogue";add_child(voice)
 music=AudioStreamPlayer.new();music.bus="Campaign_Music";music.stream=load("res://audio/music/menu_theme.ogg");music.volume_db=-19;add_child(music)
 effects=AudioStreamPlayer.new();effects.bus="Campaign_Effects";effects.volume_db=-20;add_child(effects)
 effects.stream=engine_track()
 var game=campaign.game
 overlay=Control.new();overlay.name="CampaignOverlay";overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;game.canvas.add_child(overlay);overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var top=ColorRect.new();top.color=Color(0,0,0,.85);top.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.add_child(top);top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);top.offset_bottom=65
 title=game.label("",20,Color("e1cc90"));top.add_child(title);title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 var back=PanelContainer.new();back.name="SubtitleBacking";overlay.add_child(back);back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);back.offset_left=25;back.offset_right=-25;back.offset_top=-150;back.offset_bottom=-25;back.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var style=StyleBoxFlat.new();style.bg_color=Color(0,0,0,.86);style.content_margin_left=18;style.content_margin_right=18;style.content_margin_top=10;style.content_margin_bottom=10;back.add_theme_stylebox_override("panel",style)
 subtitle=game.label("",20,Color("f4f5e7"));subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;subtitle.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;back.add_child(subtitle)
func active() -> bool:return campaign.state.phase in ["INTRO","DEPARTURE","CRASH","ENDING"]
func engine_track() -> AudioStreamWAV:
 var bytes=PackedByteArray();bytes.resize(22050*2)
 for i in range(22050):
  var t=i/22050.0;var sample=sin(t*TAU*55)*.22+sin(t*TAU*110)*.08+sin(t*TAU*1375)*.015
  bytes.encode_s16(i*2,int(sample*32767))
 var stream=AudioStreamWAV.new();stream.mix_rate=22050;stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.data=bytes;stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_end=22050;return stream
func stop_tracks():
 voice.stop();music.stop();effects.stop();last_slot="";speech_cue=""
 if speaking_os:DisplayServer.tts_stop();speaking_os=false
func apply_volumes():
 for pair in [["Campaign_Dialogue","campaign_dialogue"],["Campaign_Music","campaign_music"],["Campaign_Effects","campaign_effects"]]:
  var volume=float(campaign.game.prefs.values.get(pair[1],.8))
  if last_volumes.get(pair[0],-1.0)!=volume:
   AudioServer.set_bus_volume_db(AudioServer.get_bus_index(pair[0]),linear_to_db(maxf(.001,volume)));AudioServer.set_bus_mute(AudioServer.get_bus_index(pair[0]),volume<=0);last_volumes[pair[0]]=volume
 if speaking_os and (float(campaign.game.prefs.values.campaign_dialogue)<=0 or float(campaign.game.prefs.values.master)<=0):DisplayServer.tts_stop();speaking_os=false
func present(elapsed: float):
 apply_volumes()
 if not active():
  overlay.visible=false;camera.current=false
  if not last_slot.is_empty() or voice.playing or music.playing or effects.playing:stop_tracks()
  return
 var game=campaign.game;var phase=campaign.state.phase;overlay.visible=game.current_screen!="campaign_pause" and game.current_screen!="settings";game.hud.visible=false;camera.current=true
 if not music.playing and DisplayServer.get_name()!="headless":music.play()
 if not effects.playing and DisplayServer.get_name()!="headless":effects.play()
 effects.volume_db=-34 if phase=="INTRO" else -24
 if phase=="INTRO":
  var index=clampi(int(elapsed/20),0,5);var u=clampf(fmod(elapsed,20)/20,0,1);var cue=campaign.data.intro[index]
  var starts=[Vector3(44,30,38),Vector3(-39,4,4),Vector3(4,26,36),Vector3(29,13,-4),Vector3(-16,5,-5),Vector3(19,7,21)]
  var ends=[Vector3(34,38,14),Vector3(-30,4,0),Vector3(-6,23,27),Vector3(-25,11,-3),Vector3(-8,4,-9),Vector3(8,5,10)]
  var aims=[Vector3(0,12,-38),Vector3(-34,1,-7),Vector3(0,3,-26),Vector3(-34,2,-7),Vector3(-7,2,-8),Vector3(-2,2,-17)]
  camera.position=starts[index].lerp(ends[index],smoothstep(0,1,u));camera.look_at(aims[index]);title.text="THE WORLD WE BUILT • CONNECTUCT"
  if index==2:camera.look_at(Vector3(0,48,-90))
  # Short, complete phrases replace a single unreadable paragraph at the bottom.
  var phrases=str(cue.text).split("\n\n",false);var part=phrase_index(phrases,u)
  subtitle.text="NARRATOR: "+phrases[part]
  if campaign.all_loaded():
   play_slot("intro_"+str(index),str(cue.audio),elapsed-index*20)
   if not ResourceLoader.exists(str(cue.audio)) and not ResourceLoader.exists(str(cue.audio).get_basename()+".wav"):speak_fallback("intro_%d_%d"%[index,part],phrases[part],.84)
 elif phase=="DEPARTURE":
  campaign.world.ship_root.position=Vector3(0,maxf(0,elapsed-3)*2.6,-maxf(0,elapsed-5)*1.1)
  var u=clampf(elapsed/20,0,1);camera.position=Vector3(4+u*30,6+u*32,5+u*23);camera.look_at(Vector3(-2,1,-17));title.text="DEPARTURE • CONNECTUCT"
  subtitle.text=dialogue_line("departure",elapsed,10)
  speak_dialogue("departure",elapsed,10)
 elif phase=="CRASH":
  var crash_progress=clampf(elapsed/24,0,1);campaign.world.ship_root.position=Vector3(-12*(1-crash_progress),25*(1-crash_progress),-15*(1-crash_progress));campaign.world.ship_root.rotation.z=sin(crash_progress*PI)*.14
  var u=clampf(elapsed/24,0,1);camera.position=Vector3(-17+u*18,31*(1-u)+2,43*(1-u)+13);camera.look_at(Vector3(0,2,6));camera.rotation.z=sin(u*PI)*.12
  title.text="OLD EARTH • EXPEDITION DAY 46";subtitle.text=dialogue_line("crash",elapsed,6)
  speak_dialogue("crash",elapsed,6)
 else:
  var relay=campaign.world.locations.radio;camera.position=relay+Vector3(-5+sin(elapsed*.07)*2,4,9);camera.look_at(relay+Vector3.UP*1.5);title.text="THE LAST DEPARTURE • EXPEDITION RELAY";subtitle.text=dialogue_line("ending",elapsed,5)
  speak_dialogue("ending",elapsed,5)
 var votes=campaign.skip_votes.size();var people=campaign.connected_slots().size()
 title.text+="   •   ENTER: SKIP %d/%d"%[votes,people]
 if not campaign.all_loaded():subtitle.text="Waiting for connected squad members to finish loading…"
 var paused=campaign.paused() or not campaign.all_loaded()
 voice.stream_paused=paused;music.stream_paused=paused;effects.stream_paused=paused
 if speaking_os:
  if paused:DisplayServer.tts_pause()
  else:DisplayServer.tts_resume()
func phrase_index(phrases: PackedStringArray,u: float) -> int:
 var weights=[];var total=0.0
 for phrase in phrases:
  var weight=str(phrase).split(" ",false).size()+2;weights.append(weight);total+=weight
 var position=0.0
 for i in range(weights.size()):
  position+=weights[i]/total
  if u<position:return i
 return phrases.size()-1
func speak_fallback(id: String,text: String,pitch=1.0):
 if speech_cue==id or campaign.paused() or not campaign.all_loaded():return
 speech_cue=id
 var guide=campaign.guide;var gain=float(campaign.game.prefs.values.campaign_dialogue)*float(campaign.game.prefs.values.master)
 if guide!=null and guide.voice_supported and gain>0 and DisplayServer.get_name()!="headless":
  DisplayServer.tts_speak(text,guide.voice_id,roundi(gain*100),pitch,.98,100000+id.hash()%10000,true);speaking_os=true
func speak_dialogue(key: String,elapsed: float,seconds: float):
 var cues=campaign.data.dialogue[key];var i=clampi(int(elapsed/seconds),0,cues.size()-1);var speaker=str(cues[i][0]);var path="res://audio/campaign/"+key+"_%02d.wav"%(i+1)
 if speaker.is_empty():return
 if ResourceLoader.exists(path):play_slot(key+"_"+str(i),path,fmod(elapsed,seconds))
 else:speak_fallback(key+"_"+str(i),str(cues[i][1]),.9 if speaker=="Brutus" else 1.0)
func dialogue_line(key: String,elapsed: float,seconds: float) -> String:
 var cues=campaign.data.dialogue[key];var i=clampi(int(elapsed/seconds),0,cues.size()-1)
 return str(cues[i][0]).to_upper()+": "+str(cues[i][1]) if str(cues[i][0])!="" else str(cues[i][1])
func play_slot(id: String,path: String,offset: float):
 if last_slot==id:return
 voice.stop();last_slot=id
 if not ResourceLoader.exists(path):path=path.get_basename()+".wav"
 if ResourceLoader.exists(path):
  voice.stream=load(path)
  if DisplayServer.get_name()!="headless":voice.play(offset)
func _exit_tree():
 stop_tracks()
 if is_instance_valid(overlay):overlay.queue_free()
