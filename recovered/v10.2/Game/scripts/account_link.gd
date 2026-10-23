class_name NestAccountLink
extends Node
## Website identity only. Never alters movement, weapons, collision, or match scoring.
const PATH="user://account_link.json"
signal playlist_profile_changed(playlist: String)
var playlist_profiles: Dictionary={}
var service_card: Dictionary={}
var service_dialog: AcceptDialog
var profile_times: Dictionary={}
var profile_errors: Dictionary={}
var profile_loading=false
var game
var website="https://ancientnest.net"
var identity: CryptoKey
var state: Dictionary={}
var account_assertion=""
var assertion_until=0.0
var pending: Dictionary={}
var expires_at=0.0
var poll_at=0.0
var busy=false
var request_node: HTTPRequest
var status="Not linked. Sign in on the website and approve a code from this game."
var status_label: Label
var code_label: Label
var refresh_in_progress=false
func _ready() -> void:
 request_node=HTTPRequest.new();request_node.timeout=12;request_node.body_size_limit=131072;add_child(request_node)
 var cfg=ConfigFile.new()
 if cfg.load("res://data/accounts.cfg")==OK:website=str(cfg.get_value("account","website",website)).trim_suffix("/")
 var local=ConfigFile.new()
 if local.load("user://accounts.cfg")==OK:website=str(local.get_value("account","website",website)).trim_suffix("/")
 game.matchmaking.hybrid.load_identity();identity=game.matchmaking.hybrid.identity
 if FileAccess.file_exists(PATH):
  var file=FileAccess.open(PATH,FileAccess.READ)
  if file!=null and file.get_length()<16384:
   var parsed=JSON.parse_string(file.get_as_text())
   if parsed is Dictionary and parsed.get("website","")==website and parsed.get("key_hash","")==key_hash() and parsed.get("refresh_token","") is String:state=parsed
 if linked():status="Linked account: "+str(state.get("username","Player"))+" · cloud account identity connected."
func clock() -> float:return Time.get_ticks_msec()/1000.0
func sha(value: String) -> PackedByteArray:
 var ctx=HashingContext.new();ctx.start(HashingContext.HASH_SHA256);ctx.update(value.to_utf8_buffer());return ctx.finish()
func key_hash() -> String:return sha(identity.save_to_string(true)).hex_encode()
static func valid_website(value: String) -> bool:
 var re=RegEx.new();re.compile("^https://[A-Za-z0-9.-]+(:[0-9]{1,5})?$")
 if re.search(value)!=null:return true
 re.compile("^http://(127\\.0\\.0\\.1|localhost)(:[0-9]{1,5})?$")
 return re.search(value)!=null
func linked() -> bool:return not str(state.get("refresh_token","")).is_empty()
func note(value: String) -> void:
 status=value
 if is_instance_valid(status_label):status_label.text=value
func signature(value: String) -> String:return Marshalls.raw_to_base64(Crypto.new().sign(HashingContext.HASH_SHA256,sha(value),identity))
func api(path: String,data: Dictionary) -> Dictionary:
 if busy:return {"_error":"Another account request is still running."}
 if not valid_website(website):return {"_error":"Account website must use HTTPS (HTTP is permitted only on loopback)."}
 busy=true
 var error=request_node.request(website+path,PackedStringArray(["Content-Type: application/json"]),HTTPClient.METHOD_POST,JSON.stringify(data))
 if error!=OK:busy=false;return {"_error":"Unable to start account request."}
 var response=await request_node.request_completed;busy=false
 if int(response[0])!=HTTPRequest.RESULT_SUCCESS:return {"_error":"Account service could not be reached. Check the website and connection."}
 var parsed=JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
 if not parsed is Dictionary:return {"_error":"Account service returned an unexpected response."}
 if int(response[1])<200 or int(response[1])>=300:return {"_error":str(parsed.get("error","Account service is unavailable.")).replace("_"," ")}
 return parsed
func begin_link() -> void:
 if busy:return
 note("Requesting a short-lived game connection code…")
 var reply=await api("/api/game/link/start",{"public_key":identity.save_to_string(true)})
 if reply.has("_error"):note(reply._error);return
 if not reply.get("device_secret") is String or not reply.get("challenge") is String or not reply.get("user_code") is String:note("Invalid game-link response.");return
 var code=str(reply.user_code);var regex=RegEx.new();regex.compile("^[A-HJ-NP-Z2-9]{8}$")
 if regex.search(code)==null:note("Invalid connection code from account service.");return
 pending=reply;expires_at=clock()+minf(600,float(reply.get("expires_in",600)));poll_at=clock()+3
 if is_instance_valid(code_label):code_label.text="CODE: "+code+"\nKEY: "+key_hash().substr(0,12)
 note("Sign in on the website and approve this code. Compare the key fingerprint before approving. Code expires in 10 minutes.")
 if DisplayServer.get_name()!="headless":OS.shell_open(website+"/account/?code="+code)
func _process(_delta: float) -> void:
 if not pending.is_empty():
  if clock()>=expires_at:pending.clear();note("Connection code expired. Request a new code.")
  elif not busy and clock()>=poll_at:
   poll_at=clock()+3
   poll_link()
 if linked() and account_assertion!="" and clock()>assertion_until-30 and not busy and not refresh_in_progress and game.matchmaking.hybrid.enabled:
  refresh_connected()
func poll_link() -> void:
 var current=pending.duplicate();var reply=await api("/api/game/link/poll",{"device_secret":current.device_secret,"signature":signature(str(current.challenge))})
 if pending.is_empty() or pending.get("device_secret")!=current.device_secret:return
 if reply.has("_error"):pending.clear();note(reply._error);return
 if reply.get("status")=="pending":return
 if reply.get("status")!="linked" or not reply.get("refresh_token") is String or not reply.get("assertion") is String:pending.clear();note("Invalid account link result.");return
 state={"website":website,"key_hash":key_hash(),"account_id":reply.account_id,"username":reply.username,"device_id":reply.device_id,"refresh_token":reply.refresh_token}
 if not save_state():pending.clear();note("The account linked, but local credentials could not be saved. Link again after fixing folder permissions.");return
 accept_session(reply);pending.clear()
 if is_instance_valid(code_label):code_label.text="LINKED: "+str(state.username)
 note("Connected to "+str(state.username)+". Website and game now share your Ancient Nest account identity.")
func save_state() -> bool:
 var file=FileAccess.open(PATH+".tmp",FileAccess.WRITE)
 if file==null:return false
 file.store_string(JSON.stringify(state));file.flush();var error=file.get_error();file.close()
 return error==OK and DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH+".tmp"),ProjectSettings.globalize_path(PATH))==OK
func accept_session(reply: Dictionary) -> void:
 account_assertion=str(reply.get("assertion",""));assertion_until=clock()+minf(900,float(reply.get("expires_in",900)))-15
 state.username=str(reply.get("username",state.get("username","Player")))
 if is_instance_valid(game.prefs):game.prefs.values.username=state.username;game.prefs.save()
func refresh_session() -> bool:
 if not linked():return false
 if account_assertion!="" and clock()<assertion_until-30:return true
 var issued=int(Time.get_unix_time_from_system());var nonce=Crypto.new().generate_random_bytes(24).hex_encode()
 var token=str(state.refresh_token);var payload="ancient-nest-session-v1\n"+token+"\n"+str(issued)+"\n"+nonce
 var reply=await api("/api/game/session",{"refresh_token":token,"issued_at":issued,"nonce":nonce,"signature":signature(payload)})
 if reply.has("_error"):account_assertion="";note(reply._error);return false
 if not reply.get("assertion") is String or reply.get("account_id")!=state.get("account_id"):account_assertion="";note("Account identity mismatch. Link this game again.");return false
 accept_session(reply);save_state();return true
func refresh_connected() -> void:
 refresh_in_progress=true
 if await refresh_session():game.matchmaking.hybrid.send({"type":"account_refresh","account_assertion":account_assertion})
 refresh_in_progress=false
func forget_local() -> void:
 state.clear();pending.clear();account_assertion="";assertion_until=0
 playlist_profiles.clear();profile_times.clear();profile_errors.clear();service_card.clear();playlist_profile_changed.emit("")
 if is_instance_valid(service_dialog):service_dialog.queue_free()
 if FileAccess.file_exists(PATH):DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
 if is_instance_valid(code_label):code_label.text="No account connected"
 note("Local sign-in forgotten. To release this installation for a different Steam account, unlink it on the website too.")
func show_panel() -> void:
 if game.running:return
 game.current_screen="account";game.context="menu";game.clear_screen();game.shade(.90);game.hud.visible=false;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 var panel=game.center_panel(820,690);game.header(panel,"WEBSITE + GAME IDENTITY","Account")
 panel.add_child(game.label("Steam sign-in happens in your browser. Never enter your Steam password into the game.",15))
 code_label=game.label("Linked: "+str(state.get("username","Player")) if linked() else "No account connected",26,game.GOLD);panel.add_child(code_label)
 status_label=game.label(status,15);status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status_label.custom_minimum_size=Vector2(690,100);panel.add_child(status_label)
 panel.add_child(game.button("Link game / create account",begin_link))
 panel.add_child(game.button("Open account website",func():if valid_website(website):OS.shell_open(website+"/account/")))
 panel.add_child(game.button("Refresh account session",func():if linked():await refresh_session();note("Account session refreshed." if account_assertion!="" else status)))
 panel.add_child(game.button("Forget sign-in on this computer",forget_local))
 panel.add_child(game.label("A link code is single-use. Approve only codes shown by your own game.\nCloud accounts do not import editable local ranks, stats or game settings.",13,game.MUTED))
 panel.add_child(game.button("Back to main menu",game.show_main))

func fetch_playlist_profile(playlist: String,force: bool=false) -> void:
 if playlist not in NestMatchmaking.PLAYLIST_IDS or not linked() or busy or profile_loading:return
 if not force and clock()-float(profile_times.get(playlist,-100))<15:return
 profile_loading=true;profile_times[playlist]=clock()
 if not await refresh_session():
  profile_errors[playlist]="Account session unavailable. Reconnect to refresh stats."
  profile_loading=false;playlist_profile_changed.emit(playlist);return
 var expected_account=str(state.get("account_id",""))
 var reply=await api("/api/game/profile",{"assertion":account_assertion,"key_hash":key_hash(),"playlist":playlist})
 profile_loading=false
 if str(state.get("account_id",""))!=expected_account:return
 if reply.has("_error"):
  profile_errors[playlist]=str(reply._error);playlist_profile_changed.emit(playlist);return
 if reply.get("account_id")!=expected_account or reply.get("selected_playlist")!=playlist or not reply.get("playlists") is Dictionary:
  profile_errors[playlist]="Invalid playlist profile response.";playlist_profile_changed.emit(playlist);return
 if reply.get("service_card") is Dictionary:service_card=reply.service_card.duplicate(true)
 for key in NestMatchmaking.PLAYLIST_IDS:
  var card=reply.playlists.get(key)
  if not card is Dictionary:continue
  if typeof(card.get("elo")) not in [TYPE_INT,TYPE_FLOAT] or typeof(card.get("matches")) not in [TYPE_INT,TYPE_FLOAT]:continue
  if not is_finite(float(card.elo)) or float(card.elo)<1 or int(card.get("rank_level",0))<1 or int(card.get("rank_level",0))>21:continue
  if not card.get("league") is String:continue
  playlist_profiles[key]=card.duplicate(true);profile_errors.erase(key);profile_times[key]=clock()
 playlist_profile_changed.emit(playlist)

func show_service_card(target_account: String="") -> void:
 if is_instance_valid(service_dialog):service_dialog.queue_free()
 var dialog=AcceptDialog.new();service_dialog=dialog;dialog.title="Ancient Nest · Service Card";dialog.ok_button_text="Close";dialog.min_size=Vector2i(360,420)
 game.add_child(dialog);dialog.confirmed.connect(dialog.queue_free);dialog.canceled.connect(dialog.queue_free)
 var scroll=ScrollContainer.new();scroll.custom_minimum_size=Vector2(360,380);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;dialog.add_child(scroll)
 var column=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(column)
 var card=NestServiceCard.new();card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_child(card);card.show_unavailable("Loading verified service record…")
 var own=target_account.is_empty() or target_account==str(state.get("account_id",""))
 if own:
  var manage=Button.new();manage.text="Manage player / account";column.add_child(manage);manage.pressed.connect(func():dialog.queue_free();game.show_player_menu())
 var viewport=game.get_viewport().get_visible_rect().size
 dialog.popup_centered(Vector2i(minf(500,viewport.x-32),minf(720,viewport.y-32)))
 if not linked():card.show_unavailable("Link your account to view server-confirmed service cards.");return
 if busy or profile_loading:card.show_unavailable("Account service is busy. Close and try again shortly.");return
 if not await refresh_session():
  if is_instance_valid(card):card.show_unavailable("Reconnect your account to load service records.")
  return
 var reply=await api("/api/game/service-card",{"assertion":account_assertion,"key_hash":key_hash(),"account_id":target_account if not target_account.is_empty() else str(state.account_id)})
 if not is_instance_valid(card) or not is_instance_valid(dialog):return
 if reply.has("_error"):card.show_unavailable(str(reply._error));return
 var expected=target_account if not target_account.is_empty() else str(state.get("account_id",""))
 if reply.get("account_id")!=expected or not reply.get("service_card") is Dictionary or not reply.get("username") is String:card.show_unavailable("Invalid service card response.");return
 card.show_service(reply.service_card,str(reply.username))
