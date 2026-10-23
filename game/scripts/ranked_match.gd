class_name NestRankedMatch
extends RefCounted
var game
var profile=NestRatingProfile.new()
var token=""
var channel="practice"
var roster={}
var eligible=false
var submitted=false
var last_packet={}
func _init(owner):game=owner;profile.load_data()
func bot_rating() -> int:return {"easy":800,"normal":1200,"hard":1800}.get(game.bot_difficulty,1200)
func is_human(actor) -> bool:return (game.matchmaking.active and game.lobby_members.has(actor.net_id)) or actor.local_player or (game.network_active and actor.remote_peer>0)
func actor_summary(actor) -> Dictionary:
 if game.matchmaking.active:
  var verified: Dictionary=game.lobby_members.get(actor.net_id,{}).get("rating",{})
  return {"human":maxi(1,int(verified.get("human",1))),"practice":0}
 if actor.local_player:return profile.summary()
 if game.network_active and (actor.remote_peer>0 or game.matchmaking.active):return NestRatingProfile.clean_summary(game.lobby_members.get(actor.net_id,{}).get("rating",{}))
 return {"human":bot_rating(),"practice":bot_rating()}
func begin() -> void:
 roster.clear();submitted=false;last_packet={};profile.last_result={}
 if not game.is_client():token="%x-%x-%x"%[int(Time.get_unix_time_from_system()),randi(),randi()]
 channel="practice" if game.actors.any(func(a):return not is_human(a)) else "human"
 for actor in game.actors:
  var ratings=actor_summary(actor);actor.rank_human=ratings.human;actor.rank_practice=ratings.practice
  roster[actor.net_id]={"id":actor.net_id,"human":is_human(actor),"team":actor.faction,"before":ratings[channel],"kills":0,"deaths":0}
 # Matchmaking ratings are server-owned. Custom and practice games never award ranks.
 eligible=false
func clear() -> void:token="";roster.clear();eligible=false;submitted=false
func remember(actor) -> void:
 if roster.has(actor.net_id):roster[actor.net_id].kills=actor.kills;roster[actor.net_id].deaths=actor.deaths
func build_results() -> Dictionary:
 return {"token":token,"channel":channel,"eligible":false,"rows":[]}
func complete() -> void:
 # The master/account result pipeline owns ranked completion, not game RPCs.
 submitted=true
func accept(_packet: Dictionary) -> bool:
 # Ignore legacy local/host awards, including packets claiming eligibility.
 return false
func result_text() -> String:
 if game.matchmaking.active:return "MATCHMAKING · Playlist stats are confirmed by the account server. Return to matchmaking to refresh your gamer card."
 return "CUSTOM GAME · UNRANKED · No Elo, rank, Player Rating or ranked statistics changes."
