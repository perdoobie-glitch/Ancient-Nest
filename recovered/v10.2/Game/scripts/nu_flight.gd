class_name NestNuFlight
extends Node
var game
var birds: Dictionary={}
var camera: Camera3D
var local_bird: NestNuFalcon
var send_at: float=0
var sequence: int=0
var pending_until: float=-INF
var hint: Label
var hint_panel: PanelContainer
func _ready() -> void:
 camera=Camera3D.new();camera.name="NuCamera";camera.fov=90;camera.near=.06;camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;add_child(camera)
func blocked(actor: NestActor) -> bool:
 return actor.action_state=="nu_launch" or birds.has(actor.net_id)
func toggle(actor: NestActor) -> void:
 if game.is_client():game.request_remote_action("nu");return
 if birds.has(actor.net_id):birds[actor.net_id].destroy("recalled");return
 if actor.action_state=="nu_launch":actor.action_state="ready";actor.action_until=game.now;return
 if not game.game_type.nu_enabled or actor.character!=1 or not actor.alive or actor.nu_used or actor.action_state!="ready" or actor.cooldown>game.now or game.is_interacting(actor):return
 actor.nu_used=true;actor.refresh_model_visibility();actor.cancel_scope();actor.clear_local_input();actor.burst_left=0;actor.nu_launch_until=game.now+1.5;actor.action_state="nu_launch";actor.action_until=actor.nu_launch_until
func _physics_process(_delta: float) -> void:
 if game.matchmaking.blocks_simulation():return
 if not game.running:
  clear();return
 if game.is_client():return
 for actor in game.actors:
  if actor.action_state!="nu_launch":continue
  if not actor.alive or not game.game_type.nu_enabled:actor.action_state="ready";continue
  if game.now+.000001<actor.nu_launch_until:continue
  actor.action_state="ready";launch(actor)
func launch(actor: NestActor) -> void:
 var start=actor.eye.global_position
 var pos=start+actor.aim_direction()*1.25+Vector3.UP*.22
 if not game.trace(start,pos,1,actor.ray_exclusions()).is_empty():finish(actor);return
 var bird=spawn(actor,pos,actor.rotation.y,actor.eye.rotation.x)
 bird.velocity=actor.aim_direction()*10+Vector3.UP*2
func spawn(actor: NestActor, pos: Vector3, yaw: float, pitch: float) -> NestNuFalcon:
 var bird=NestNuFalcon.new();bird.game=game;bird.owner_actor=actor;bird.flight=self;bird.position=pos;bird.yaw=yaw;bird.pitch=pitch
 birds[actor.net_id]=bird;add_child(bird);bird.reset_physics_interpolation()
 if actor.local_player:take_camera(bird)
 return bird
func finish(actor: NestActor) -> void:
 if birds.has(actor.net_id):
  var bird=birds[actor.net_id];birds.erase(actor.net_id)
  if is_instance_valid(bird):bird.dead=true;bird.queue_free()
 if actor.local_player:return_camera()
func clear() -> void:
 for bird in birds.values():
  if is_instance_valid(bird):bird.queue_free()
 birds.clear();return_camera()
func take_camera(bird: NestNuFalcon) -> void:
 local_bird=bird;bird.visual.visible=false;bird.owner_actor.refresh_model_visibility();bird.owner_actor.clear_local_input();camera.global_transform=Transform3D(Basis.from_euler(Vector3(bird.pitch,bird.yaw,0)),bird.global_position);camera.current=true
 if hint==null:
  var layer=CanvasLayer.new();layer.layer=15;add_child(layer)
  hint_panel=PanelContainer.new();hint_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(hint_panel)
  hint_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
  var style=StyleBoxFlat.new();style.bg_color=Color(.015,.023,.019,.83);style.border_color=Color("a79357");style.set_border_width_all(1);style.content_margin_left=12;style.content_margin_right=12;style.content_margin_top=8;style.content_margin_bottom=8;hint_panel.add_theme_stylebox_override("panel",style)
  hint=Label.new();hint.mouse_filter=Control.MOUSE_FILTER_IGNORE;hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hint.add_theme_font_size_override("font_size",13);hint.add_theme_color_override("font_color",Color("ead691"));hint.add_theme_color_override("font_outline_color",Color(.02,.02,.015,.95));hint.add_theme_constant_override("outline_size",2);hint_panel.add_child(hint)
 update_flight_hud()
 hint.visible=true;hint_panel.visible=true

func return_camera() -> void:
 if local_bird==null:return
 local_bird=null;camera.current=false
 if is_instance_valid(game.player) and game.player.camera!=null:game.player.camera.current=true;game.player.refresh_model_visibility();game.player.clear_local_input()
 if hint_panel!=null:hint_panel.visible=false
func _process(delta: float) -> void:
 if not is_instance_valid(local_bird):return
 camera.global_position=local_bird.get_global_transform_interpolated().origin+local_bird.visual_error
 local_bird.visual_error*=exp(-delta*15)
 camera.rotation=Vector3(local_bird.pitch,local_bird.yaw,0)
 camera.current=true
 if hint_panel!=null:hint_panel.visible=game.context=="playing";update_flight_hud()
func _input(event: InputEvent) -> void:
 if not game.running or not is_instance_valid(game.player) or not game.input_window_focused or game.context!="playing":return
 if event is InputEventKey and event.echo:return
 if event.is_action_pressed("nu"):
  if not game.player.input_captured():return
  toggle(game.player);get_viewport().set_input_as_handled();return
 if not is_instance_valid(local_bird) or not game.player.input_captured():return
 if event is InputEventMouseMotion:
  var motion=event.screen_relative if event.screen_relative!=Vector2.ZERO else event.relative
  var scale=deg_to_rad(.022*game.prefs.values.nu_sensitivity)
  local_bird.yaw=wrapf(local_bird.yaw-motion.x*scale,-PI,PI)
  local_bird.pitch=clampf(local_bird.pitch-motion.y*scale*(-1 if game.prefs.values.invert_y else 1),deg_to_rad(-80),deg_to_rad(80))
  camera.rotation=Vector3(local_bird.pitch,local_bird.yaw,0)
  get_viewport().set_input_as_handled()
func read_controls(bird: NestNuFalcon) -> void:
 var active=game.context=="playing" and game.input_window_focused and game.player.input_captured()
 bird.assist_enabled=game.prefs.values.nu_flight_assist
 bird.boost_active=active and game.player.gameplay_held("nu_boost")
 bird.controls=Vector3(float(game.player.gameplay_held("forward"))-float(game.player.gameplay_held("backward")),float(game.player.gameplay_held("right"))-float(game.player.gameplay_held("left")),float(game.player.gameplay_held("jump"))-float(game.player.gameplay_held("crouch"))) if active else Vector3.ZERO
 # Bank turns flight heading with keyboard as well as mouse look.
 bird.yaw=wrapf(bird.yaw-bird.controls.y*.9/60.0,-PI,PI)
 if game.is_client() and game.now>=send_at:
  sequence+=1;send_at=game.now+.05;submit_controls.rpc_id(1,sequence,bird.life,game.round_number,game.match_session,bird.yaw,bird.pitch,bird.controls,bird.boost_active,bird.assist_enabled)
@rpc("any_peer","call_remote","unreliable_ordered",3)
func submit_controls(seq: int, life: int, round_id: int, session: int, yaw: float, pitch: float, controls: Vector3, boost: bool=false, assist: bool=true) -> void:
 if not game.multiplayer.is_server() or not game.running or game.finished or round_id!=game.round_number or session!=game.match_session:return
 var sender=game.multiplayer.get_remote_sender_id()
 var actor=game.actor_for_peer(sender)
 if actor==null or not birds.has(actor.net_id):return
 var bird=birds[actor.net_id]
 if life!=bird.life or seq<=bird.last_seq or not is_finite(yaw) or not is_finite(pitch) or not controls.is_finite():return
 bird.assist_enabled=assist;bird.boost_active=boost;bird.last_seq=seq;bird.yaw=wrapf(yaw,-PI,PI);bird.pitch=clampf(pitch,deg_to_rad(-80),deg_to_rad(80));bird.controls=controls.clamp(Vector3(-1,-1,-1),Vector3.ONE);bird.control_at=game.now
func snapshot() -> Dictionary:
 var state={}
 for id in birds:
  var bird=birds[id]
  if not is_instance_valid(bird) or bird.dead:continue
  state[id]={"pos":bird.global_position,"vel":bird.velocity,"yaw":bird.yaw,"pitch":bird.pitch,"life":bird.life,"spots":bird.spots,"assist":bird.assist_enabled,"boost":bird.boost_active,"ack":bird.last_seq}
 return state
func receive(state: Dictionary) -> void:
 for id in birds.keys():
  if not state.has(id):finish(birds[id].owner_actor)
 for id in state:
  var actor=game.actor_by_id(id);var s=state[id]
  if actor==null or not actor.alive or actor.life_id!=s.life:continue
  var bird=birds.get(id)
  if not is_instance_valid(bird):bird=spawn(actor,s.pos,s.yaw,s.pitch);bird.velocity=s.vel
  bird.spots.assign(s.spots);bird.target_position=s.pos;bird.target_velocity=s.vel
  if actor.local_player:
   # Reconcile current server pose with a bounded transit estimate. View angle
   # remains local and immediate, never replaced by an acknowledged rotation.
   var estimated=s.pos+s.vel*clampf(game.now-game.network_clock,0,.1)
   var old=bird.global_position;bird.global_position=estimated;bird.velocity=s.vel;bird.previous_boost=3.0 if bool(s.get("boost",false)) else 1.0;bird.visual_error+=(old-estimated)
  else:bird.assist_enabled=bool(s.get("assist",true));bird.boost_active=bool(s.get("boost",false));bird.yaw=s.yaw;bird.pitch=s.pitch
func visible_enemy_ids(viewer: NestActor) -> Array[int]:
 var result: Array[int]=[]
 if game.mode==1:return result
 for bird in birds.values():
  if not is_instance_valid(bird) or bird.owner_actor.faction!=viewer.faction:continue
  for id in bird.spots:
   var target=game.actor_by_id(id)
   if target==null or not target.alive:continue
   # Recheck cover locally between snapshots; no persistent wall reveal.
   var point=target.global_position+Vector3.UP*NestActor.EYE_HEIGHT
   if game.vision_clear(bird.global_position,point) and id not in result:result.append(id)
 return result

func update_flight_hud() -> void:
 if hint==null or not is_instance_valid(local_bird):return
 var half=minf(320,game.get_viewport().get_visible_rect().size.x*.47)
 hint_panel.offset_left=-half;hint_panel.offset_right=half;hint_panel.offset_top=-104;hint_panel.offset_bottom=-30
 hint.text="NU · %s · %.0f m/s · ASSIST %s\nMouse steer · W/S thrust/brake · A/D bank · Space flap · Ctrl dive\nHold %s: 3× speed · %s: return · Body vulnerable"%["3× BOOST" if local_bird.boost_active else "1× FLIGHT",local_bird.velocity.length(),"ON" if local_bird.assist_enabled else "OFF",game.prefs.key_label("nu_boost"),game.prefs.key_label("nu")]
