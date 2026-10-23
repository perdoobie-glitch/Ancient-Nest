extends SceneTree
var failed=false
func _initialize():call_deferred("run")
func run():
 var args=OS.get_cmdline_user_args()
 if args.size()!=1:quit(1);return
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.set_physics_process(false);game.accounts.website=args[0]
 var account=game.accounts
 await account.begin_link()
 if account.pending.is_empty():push_error(account.status);quit(1);return
 print("NATIVE_LINK_READY "+JSON.stringify({"code":account.pending.user_code,"fingerprint":account.key_hash().substr(0,12)}))
 var deadline=Time.get_ticks_msec()+20000
 while not account.linked() and Time.get_ticks_msec()<deadline:await create_timer(.1).timeout
 if not account.linked():push_error(account.status);quit(1);return
 if game.current_username()!="NativeTester":push_error("Verified account username did not reach game preferences");quit(1);return
 account.account_assertion="";account.assertion_until=0
 if not await account.refresh_session():push_error(account.status);quit(1);return
 await account.fetch_playlist_profile("tactical_3v3",true)
 var card: Dictionary=account.playlist_profiles.get("tactical_3v3",{})
 if card.get("elo")!=1 or card.get("league")!="Forgebound I" or card.get("player_rating")!=null:
  push_error("Native game did not load authenticated fresh playlist card");quit(1);return
 print("NATIVE_PLAYLIST_CARD_SUCCESS")
 await account.show_service_card()
 var service=account.service_dialog.find_child("ServiceCard",true,false)
 if service==null or not service.content.has_node("League") or service.content.get_node("Elo").get_child(1).text!="1":
  push_error("Native service card did not show authenticated aggregate record");quit(1);return
 account.service_dialog.confirmed.emit();await process_frame
 print("NATIVE_SERVICE_CARD_SUCCESS")
 var path=ProjectSettings.globalize_path("user://native-account-test.json")
 var file=FileAccess.open(path,FileAccess.WRITE)
 file.store_string(JSON.stringify({"assertion":account.account_assertion,"key_hash":account.key_hash(),"account_id":account.state.account_id}));file.close()
 print("NATIVE_LINK_SUCCESS "+JSON.stringify({"path":path,"account_id":account.state.account_id,"username":game.current_username()}))
 game.queue_free();await process_frame;await process_frame;quit()
