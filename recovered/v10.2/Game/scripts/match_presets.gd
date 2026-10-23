class_name NestMatchPresets
extends RefCounted
const MODES=[2,1,3,0,4]
const NAMES=["Team Deathmatch","Iso Deathmatch","Capture the Flag","Extraction","Bomb Defusal"]
static func create(mode: int,map_id: int=0,life: int=1,online: bool=false) -> GameTypeSettings:
 var rules=GameTypeSettings.new();rules.mode=clampi(mode,0,4);rules.map_selection=clampi(map_id,0,NestArena.MAP_NAMES.size()-1)
 rules.game_type_name=NAMES[MODES.find(rules.mode)];rules.description="Official "+rules.game_type_name+" preset · 1x body / 2x head before defenses"
 rules.matchup=3 if mode==0 else (2 if life==2 else 1)
 rules.bots_fill_empty_slots=false;rules.bots_team_0=0;rules.bots_team_1=0
 rules.max_players_per_team=3 if online else 5;rules.max_players=rules.max_players_per_team*2
 rules.teams_enabled=mode!=1;rules.time_limit_seconds=600;rules.score_to_win=42
 rules.health_type=0;rules.character_traits.clear();rules.weapon_damage_percent.clear()
 if mode==1:rules.score_to_win=21
 elif mode==3:rules.score_to_win=3
 elif mode==0:rules.score_to_win=3;rules.time_limit_seconds=300;rules.bag_stock=3
 elif mode==4:rules.score_to_win=11;rules.time_limit_seconds=120;rules.rounds=21;rules.lives_per_round=1;rules.plant_seconds=3.2;rules.defuse_seconds=10;rules.bomb_timer_seconds=40
 if online:rules.team_changing=0;rules.join_in_progress=false
 rules.validate();return rules
