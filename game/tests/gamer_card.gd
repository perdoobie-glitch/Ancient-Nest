extends SceneTree
func _initialize():call_deferred("run")
func run():
 var card=NestGamerCard.new();root.add_child(card)
 var data={"league":"Angel","rank_level":21,"elo":3220,"player_rating":92.0,"rating_grade":"A−","matches":3}
 card.show_profile(data,"PLAYER NAME","3 v 3 Trios")
 assert(card.content.has_node("PlayerRating"));assert(card.content.get_node("PlayerRating").get_child(1).text=="92%  A−")
 assert(card.content.get_node("League").get_child(1).text=="Angel")
 assert(card.content.get_node("Elo").get_child(1).text=="3220")
 for key in ["League","RankLevel","Elo","PlayerRating"]:
  var value=card.content.get_node(key).get_child(1)
  assert(value.autowrap_mode==TextServer.AUTOWRAP_OFF and value.get_minimum_size().x>0)
 for games in [0,1,2]:
  card.show_profile({"league":"Forgebound I","rank_level":1,"elo":1,"player_rating":92.0,"rating_grade":"A−","matches":games},"NEW PLAYER","1 v 1 Loners")
  assert(not card.content.has_node("PlayerRating"),"No rating shown before this playlist has three games, even if a stale value is supplied")
  assert(card.content.has_node("PlacementProgress"))
 card.show_profile({"league":"Forgebound I","rank_level":1,"elo":1,"player_rating":null,"matches":3},"PLAYER","2 v 2 Couples")
 assert(not card.content.has_node("PlayerRating"),"Unavailable server data must not become a fabricated percentage")
 card.show_unavailable();assert(not card.content.has_node("Elo"))
 print("PASS gamer card example, fresh player, three-game visibility gate, stale-rating suppression and disconnected state")
 card.queue_free();await process_frame;quit()
