class_name NestPlaylistRanks
extends RefCounted
## Mirrors server thresholds for labels only; never awards or saves online Elo.
const LEAGUES=["Forgebound","Striker","Sentinel","Vanguard","Praetorian","War Marshal","Ascendant"]
static func rank_for(elo: int) -> Dictionary:
 var level=mini(21,maxi(0,elo)/150+1)
 return {"number":level,"name":"Angel" if level==21 else LEAGUES[(level-1)/3],"roman":"" if level==21 else ["I","II","III"][(level-1)%3]}
