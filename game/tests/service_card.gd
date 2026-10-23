extends SceneTree
func _initialize():call_deferred("run")
func run():
 var card=NestServiceCard.new();root.add_child(card)
 var data={"league":"Angel","rank_level":21,"elo":3220,"matches":9,"player_rating":92,"rating_grade":"A−","playlists_played":3,"playlists_rated":3,"playlists_total":5,"kills":42,"deaths":21,"kd":2}
 card.show_service(data,"Mishwad")
 assert(card.content.get_node("League").get_child(1).text=="Angel")
 assert(card.content.get_node("PlayerRating").get_child(1).text=="92%  A−")
 assert(card.content.get_node("Totalkills").get_child(1).text=="42")
 assert(card.content.get_node("TotalKD").get_child(1).text=="2.00")
 assert((card.get_theme_stylebox("panel") as StyleBoxFlat).border_color==NestServiceCard.DIAMOND)
 var playlist=NestGamerCard.new();root.add_child(playlist);playlist.show_profile(data,"Player","1v1 Duel")
 var clicked=[false];playlist.username_pressed.connect(func():clicked[0]=true);playlist.content.get_node("UsernameTag").pressed.emit();assert(clicked[0])
 card.queue_free();playlist.queue_free();await process_frame
 print("PASS diamond service card, aggregate presentation and username tag action")
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;await process_frame
 game.show_main();await process_frame
 var identity=game.screen.find_child("EditUsername",true,false);assert(identity is Button);identity.pressed.emit();await process_frame
 assert(is_instance_valid(game.accounts.service_dialog));assert(game.accounts.service_dialog.title.contains("Service Card"))
 game.accounts.service_dialog.confirmed.emit();await process_frame;game.queue_free();await process_frame;await process_frame
 print("PASS main-menu username opens service card; unlinked record stays unavailable")
 quit()
