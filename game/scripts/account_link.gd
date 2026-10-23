class_name NestAccountLink
extends Node
## Adapter for Ancient Nest's existing game account interface. Gameplay is unchanged.

signal assertion_refreshed(result: bool)
signal playlist_profile_changed(playlist: String)
var playlist_profiles: Dictionary = {}
var service_card: Dictionary = {}
var service_dialog: AcceptDialog
var profile_times: Dictionary = {}
var profile_errors: Dictionary = {}
var profile_loading = false
var busy = false
var game
var identity: CryptoKey
var account_assertion := ""
var assertion_until := 0.0
var state: Dictionary = {}
var refresh_in_progress := false
var status := "Signed in with Discord."


func _ready() -> void:
    game.matchmaking.hybrid.load_identity()
    identity = game.matchmaking.hybrid.identity
    state = AncientNestAuth.current_user.duplicate()
    state["account_id"] = state.get("id", "")


func linked() -> bool:
    return not AncientNestAuth.current_user.is_empty()


func clock() -> float:
    return Time.get_ticks_msec() / 1000.0


func key_hash() -> String:
    return identity.save_to_string(true).sha256_text()


func refresh_session() -> bool:
    if refresh_in_progress:
        return await assertion_refreshed
    if not linked():
        return false
    if not account_assertion.is_empty() and clock() < assertion_until - 30:
        return true
    refresh_in_progress = true
    var user_id: String = AncientNestAuth.current_user.id
    var response: Dictionary = await AncientNestAuth.authenticated_request("/api/game/assertion", HTTPClient.METHOD_POST,
        {"public_key": identity.save_to_string(true)})
    var ok: bool = response.ok and linked() and str(AncientNestAuth.current_user.get("id", "")) == user_id
    if ok:
        var data: Dictionary = response.data
        ok = data.get("account_id") == user_id and data.get("key_hash") == key_hash() and data.get("assertion") is String
        if ok:
            account_assertion = data.assertion
            assertion_until = clock() + minf(600, float(data.get("expires_in", 0)))
            state["username"] = AncientNestAuth.current_user.username
            if is_instance_valid(game.prefs):
                game.prefs.values.username = state.username
                game.prefs.save()
    if not ok:
        account_assertion = ""
        assertion_until = 0
        status = "Account session could not be refreshed. Check your connection or sign in again."
    refresh_in_progress = false
    assertion_refreshed.emit(ok)
    return ok


func _process(_delta: float) -> void:
    if not account_assertion.is_empty() and clock() > assertion_until - 30 and not refresh_in_progress:
        if game.matchmaking.hybrid.enabled:
            _refresh_connected()


func _refresh_connected() -> void:
    if await refresh_session():
        game.matchmaking.hybrid.send({"type": "account_refresh", "account_assertion": account_assertion})


func show_panel() -> void:
    if game.running:
        return
    game.current_screen = "account"
    game.context = "menu"
    game.clear_screen()
    game.shade(0.90)
    game.hud.visible = false
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    var panel = game.center_panel(820, 690)
    game.header(panel, "ANCIENT NEST DISCORD PROFILE", "Account")
    panel.add_child(game.label("Signed in as " + str(AncientNestAuth.current_user.get("username", "Player")), 26, game.GOLD))
    panel.add_child(game.label("Account ID: " + str(AncientNestAuth.current_user.get("id", "")), 13))
    panel.add_child(game.label(status, 15))
    var username := LineEdit.new()
    username.text = str(AncientNestAuth.current_user.get("username", ""))
    username.max_length = 24
    panel.add_child(username)
    panel.add_child(game.button("Save game username", func() -> void:
        var response: Dictionary = await AncientNestAuth.authenticated_request("/profile/username", HTTPClient.METHOD_POST,
            {"username": username.text.strip_edges()})
        if response.ok:
            AncientNestAuth.current_user = response.data.user
            state["username"] = response.data.user.username
            account_assertion = ""
            assertion_until = 0
            game.prefs.values.username = response.data.user.username
            game.prefs.save()
            status = "Game username saved."
        else:
            status = "Choose an available username with 3–24 letters, numbers, _ or -."
        show_panel()))
    panel.add_child(game.label("Team voice uses your Discord sign-in and server-assigned team room.", 15))
    panel.add_child(game.button("Sign out", func() -> void: await AncientNestAuth.sign_out()))
    panel.add_child(game.button("Back to main menu", game.show_main))


func begin_link() -> void:
    show_panel()


func forget_local() -> void:
    await AncientNestAuth.sign_out()


func api(path: String, data: Dictionary) -> Dictionary:
    if busy: return {"_error": "Account request already in progress."}
    busy = true
    var response: Dictionary = await AncientNestAuth.authenticated_request(path, HTTPClient.METHOD_POST, data)
    busy = false
    if not response.ok: return {"_error": "Account service unavailable. Reconnect and try again."}
    return response.data

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
