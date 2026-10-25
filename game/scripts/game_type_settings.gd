class_name GameTypeSettings
extends Resource

const SCHEMA_VERSION := 1
@export var gun_balance_revision: int = 0
# These require rebuilding match actors/objectives; live Apply preserves them.
const LOBBY_ONLY_KEYS = ["mode","matchup","map_selection","cs_defuse_kits","max_players","max_players_per_team","bots_fill_empty_slots","bots_team_0","bots_team_1"]
@export_enum("Character default", "Naki health", "Annu health") var health_type: int = 0
@export_range(0,1000,5) var armor_strength_percent: float = 100.0
@export_range(0,1000,5) var helmet_strength_percent: float = 100.0
@export_range(0,100,5) var armor_absorption_percent: float = 50.0
@export_range(0,100,5) var helmet_absorption_percent: float = 0.0
@export var cs_defuse_kits: bool = false
@export var character_traits: Dictionary = {}
@export var weapon_damage_percent: Dictionary = {}
@export var sniper_instant_headshots: bool = false
@export var annu_body_health: float = 100.0
@export var annu_head_health: float = 100.0
@export var annu_body_armor: float = 100.0
@export var annu_head_armor: float = 0.0
@export var annu_precision_ignores_helmet: bool = false
@export var naki_shield_capacity: float = 125.0
@export var naki_body_shield_strength: float = 1.0
@export var naki_head_shield_strength: float = 1.0
@export var show_low_health_vignette: bool = true
@export_range(0,30,.25) var health_regen_delay: float = 5.0

@export_group("Identity")
@export var game_type_name: String = "Custom Game"
@export_multiline var description: String = ""
@export_enum("Extraction", "Iso Deathmatch", "Team Deathmatch", "Capture the Flag", "Bomb Defusal") var mode: int = 0

@export_group("Match Rules")
@export_range(1, 500, 1) var score_to_win: int = 50
@export_range(0, 3600, 30) var time_limit_seconds: float = 180.0
@export_range(1, 30, 1) var rounds: int = 1
@export_range(0, 1800, 30) var round_time_limit_seconds: float = 180.0
@export var switch_sides: bool = true
@export var sudden_death: bool = true
@export_range(0, 600, 5) var overtime_seconds: float = 60.0
@export_range(0, 100, 1) var mercy_lead: int = 0
@export_range(0, 30, 1) var pre_match_countdown: float = 3.0
@export_range(0, 30, 1) var post_match_scoreboard_seconds: float = 8.0

@export_group("Teams")
@export_enum("Naki vs Annu", "Naki vs Naki", "Annu vs Annu", "Annu vs Naki") var matchup: int = 0
@export var teams_enabled: bool = true
@export_range(2, 8, 1) var team_count: int = 2
@export_range(1, 16, 1) var max_players_per_team: int = 5
@export_range(2, 16, 1) var max_players: int = 10
@export_enum("Off", "On", "Lobby only") var team_changing: int = 2
@export var auto_balance: bool = true
@export_enum("Off", "On", "Reflect") var friendly_fire_mode: int = 0

@export_group("Respawn")
@export_range(0, 60, 0.25) var respawn_seconds: float = 3.0
@export_range(0, 30, 0.25) var respawn_growth_per_death: float = 0.0
@export_range(0, 30, 0.25) var suicide_penalty_seconds: float = 0.0
@export_range(0, 30, 0.25) var betrayal_penalty_seconds: float = 0.0
@export_range(0, 25, 1) var lives_per_round: int = 0
@export_range(0, 10, 0.25) var spawn_protection_seconds: float = 0.0

@export_group("Player Traits - Movement")
@export_range(25, 400, 1) var movement_speed_percent: float = 110.0
@export_range(25, 400, 1) var walk_speed_percent: float = 100.0
@export_range(25, 400, 1) var crouch_speed_percent: float = 100.0
@export_range(25, 400, 1) var backpedal_speed_percent: float = 100.0
@export_range(25, 400, 1) var strafe_speed_percent: float = 100.0
@export_range(25, 400, 1) var acceleration_percent: float = 100.0
@export_range(25, 400, 1) var deceleration_percent: float = 100.0
@export_range(10, 400, 1) var gravity_percent: float = 145.0
@export_range(0, 500, 1) var jump_height_percent: float = 125.0
@export_range(1, 5, 1) var jump_count: int = 1
@export_range(0, 300, 1) var air_control_percent: float = 115.0
@export_range(0, 10, 1) var wall_kicks: int = 0
@export_range(25, 400, 1) var wall_kick_strength_percent: float = 100.0
@export var ledge_grab: bool = false
@export var prop_vault: bool = false
@export var head_bounce: bool = false
@export var land_roll: bool = false
@export var fall_damage: bool = false
@export_range(0, 500, 1) var explosion_knockback_percent: float = 100.0
@export_range(50, 200, 1) var player_scale_percent: float = 100.0

@export_group("Player Traits - Combat")
@export_range(10, 1000, 5) var max_health_percent: float = 100.0
@export var shields_enabled: bool = true
@export_range(0, 1000, 5) var shield_strength_percent: float = 100.0
@export_range(0, 30, 0.25) var shield_recharge_delay: float = 3.0
@export_range(0, 500, 5) var shield_recharge_rate_percent: float = 100.0
@export var health_regeneration: bool = false
@export_range(0, 1000, 5) var damage_dealt_percent: float = 100.0
@export_range(10, 1000, 5) var damage_resistance_percent: float = 100.0
@export_range(10, 1000, 5) var damage_received_percent: float = 100.0
@export_range(0.1, 10.0, 0.1) var headshot_multiplier: float = 2.0
@export_range(0, 1000, 5) var melee_damage_percent: float = 100.0
@export var one_shot_melee: bool = false
@export_range(0, 1000, 5) var explosive_damage_percent: float = 100.0
@export var self_damage: bool = true
@export_enum("Off", "Infinite reserve", "Bottomless clip") var infinite_ammo: int = 0
@export_range(25, 400, 5) var reload_speed_percent: float = 100.0
@export_range(25, 400, 5) var fire_rate_percent: float = 100.0
@export_range(0, 300, 5) var recoil_percent: float = 100.0
@export_range(0, 300, 5) var spread_percent: float = 100.0
@export var descope_on_damage: bool = true

@export_group("Radar")
@export var radar_enabled: bool = true
@export_range(10, 50, 1) var radar_range: float = 25.0
@export var radar_moving_only: bool = true
@export var radar_edge_clamp: bool = true

@export_group("Weapons & Loadouts")
@export var starting_primary: String = "default"
@export var starting_secondary: String = "default"
@export var weapon_pickups: bool = true
@export var map_weapons: bool = true
@export_range(25, 400, 5) var weapon_respawn_percent: float = 100.0
@export var melee_only: bool = false
@export var drop_weapons_on_death: bool = true
@export var drop_grenades_on_death: bool = false
@export_range(5, 300, 5) var dropped_item_despawn_seconds: float = 60.0
@export_range(1, 256, 1) var max_dropped_items: int = 64

@export_group("Bodies & Effects")
@export_range(0, 60, 1) var body_despawn_seconds: float = 6.0
@export_enum("Low", "Normal", "Silly") var ragdoll_strength: int = 1
@export var blood_impact_effects: bool = true
@export var kill_feed: bool = true
@export var killcam: bool = false

@export_group("Objectives")
@export_range(0, 60, 0.25) var plant_seconds: float = 4.0
@export_range(0, 60, 0.25) var defuse_seconds: float = 6.0
@export_range(1, 120, 1) var bomb_timer_seconds: float = 15.0
@export_range(1, 120, 1) var drill_seconds: float = 45.0
@export_range(1, 60, 1) var bag_load_seconds: float = 5.0
@export_range(1, 20, 1) var bag_stock: int = 3

@export_group("Map & World")
@export_enum("Sanctuary", "Crossroads", "Savannah", "Connectuct", "Qaytal", "Temple") var map_selection: int=0
@export var map_name: String = "Sanctuary"
@export var map_variant: String = "Default"
@export_enum("Default", "Day", "Dusk", "Night") var lighting_preset: int = 0
@export_enum("Off", "Light", "Heavy") var weather: int = 0
@export var launch_pads: bool = true
@export var lifts: bool = true
@export var ladders: bool = true
@export var swim_zones: bool = true

@export_group("Bots")
@export_range(0, 15, 1) var bot_count: int = 0
@export_enum("Easy", "Normal", "Hard", "Insane") var bot_difficulty: int = 1
@export var bots_fill_empty_slots: bool = true
@export_range(-1,16,1) var bots_team_0: int = -1
@export_range(-1,16,1) var bots_team_1: int = -1
@export var bots_play_objectives: bool = true
@export var bots_stand_still: bool = false
@export var bots_dont_shoot: bool = false
@export var bullet_impact_debug: bool = false
@export var nu_enabled: bool = true

@export_group("Lobby")
@export_enum("Public", "Friends only", "Invite only", "Password") var lobby_privacy: int = 2
@export var ready_up_required: bool = false
@export var join_in_progress: bool = true
@export var spectators_allowed: bool = true
@export_range(0, 16, 1) var max_spectators: int = 2
@export var lobby_chat: bool = true
@export var vote_next: bool = false

@export_group("HUD")
@export_enum("Full", "Minimal", "Off") var hud_mode: int = 0
@export var crosshair: bool = true
@export var hit_markers: bool = true
@export var damage_numbers: bool = false
@export var scoreboard_always_visible: bool = false

func duplicate_settings() -> GameTypeSettings:
	return duplicate(true) as GameTypeSettings

func to_network_dict() -> Dictionary:
	var out := {"schema": SCHEMA_VERSION}
	for p in get_property_list():
		if int(p.usage) & PROPERTY_USAGE_STORAGE and not String(p.name).begins_with("resource_") and p.name not in ["resource_local_to_scene", "resource_name", "script"]:
			out[p.name] = get(p.name)
	return out

func apply_network_dict(data: Dictionary) -> void:
	var allowed=GameTypeSettings.new().to_network_dict()
	for key in data:
		if key=="schema" or not allowed.has(key):continue
		var value=data[key];var expected=typeof(allowed[key])
		if expected in [TYPE_FLOAT,TYPE_INT]:
			if typeof(value) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value)):continue
			set(key,int(value) if expected==TYPE_INT else float(value))
		elif typeof(value)==expected:set(key,value)
	validate()
func validate() -> void:
	if starting_primary=="battle_rifle":starting_primary="battle_rifle_scoped"
	if starting_secondary=="battle_rifle":starting_secondary="battle_rifle_scoped"
	# One-time migration of historical shipped defaults, not arbitrary custom values.
	if gun_balance_revision<1:
		if is_equal_approx(naki_body_shield_strength,1.7):naki_body_shield_strength=1.0
		if is_equal_approx(naki_head_shield_strength,1.35):naki_head_shield_strength=1.0
		sniper_instant_headshots=false;annu_precision_ignores_helmet=false
		gun_balance_revision=1
	if gun_balance_revision<2:
		if is_equal_approx(naki_shield_capacity,100.0):naki_shield_capacity=125.0
		if is_equal_approx(shield_recharge_delay,5.0):shield_recharge_delay=3.0
		gun_balance_revision=2
	for definition in definitions():
		var key=String(definition.key)
		if definition.type=="number":
			var value=float(get(key))
			if not is_finite(value):value=float(GameTypeSettings.new().get(key))
			value=clampf(value,float(definition.min),float(definition.max))
			set(key,int(round(value)) if typeof(get(key))==TYPE_INT else value)
		elif definition.type=="choice":set(key,clampi(int(get(key)),0,definition.options.size()-1))
		elif definition.type=="weapon":
			var weapon=String(get(key))
			var valid=weapon in ["default","none"]
			for option in NestWeaponCatalog.choices("primary" if key=="starting_primary" else "secondary"):
				if option.id==weapon:valid=true
			if not valid:set(key,"default")
	map_name=NestArena.MAP_NAMES[map_selection]
	game_type_name=game_type_name.strip_edges().substr(0,48)
	if game_type_name.is_empty():game_type_name="Custom Game"
	if mode==4:
		time_limit_seconds=clampf(time_limit_seconds,1,120);round_time_limit_seconds=time_limit_seconds;lives_per_round=1
	max_players=max_players_per_team*2
	validate_character_traits()
	validate_weapon_damage()

func validate_weapon_damage() -> void:
	var clean={}
	for entry in NestWeaponCatalog.data().weapons:
		var kind=String(entry.get("kind",""))
		if entry.get("slot","") not in ["primary","secondary","grenade"] or not weapon_damage_percent.has(kind):continue
		var value=weapon_damage_percent[kind]
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)):continue
		value=clampf(float(value),0,1000)
		if not is_equal_approx(value,100):clean[kind]=value
	weapon_damage_percent=clean
func weapon_damage_scale(kind: String) -> float:
	return float(weapon_damage_percent.get(kind,100.0))/100.0
func _has_property(key: StringName) -> bool:
	for p in get_property_list():
		if p.name == key: return true
	return false

func export_share_code() -> String:
	var bytes := JSON.stringify(to_network_dict()).to_utf8_buffer()
	return Marshalls.raw_to_base64(bytes.compress(FileAccess.COMPRESSION_DEFLATE))

func import_share_code(code: String) -> bool:
	var packed := Marshalls.base64_to_raw(code.strip_edges())
	if packed.is_empty(): return false
	var raw := packed.decompress_dynamic(2 * 1024 * 1024, FileAccess.COMPRESSION_DEFLATE)
	if raw.is_empty(): return false
	var parsed = JSON.parse_string(raw.get_string_from_utf8())
	if not parsed is Dictionary: return false
	apply_network_dict(parsed)
	return true

static func definitions() -> Array[Dictionary]:
	# Every exposed option has a gameplay consumer and a finite validation range.
	return [
  {"key":"map_selection","category":"Map","label":"Map","type":"choice","options":["Sanctuary · Wide arena","Crossroads · Two-site tactical","Savannah · Desert excavation","Connectuct · Dying world","Qaytal · Garden of life","Temple · Reclaimed sanctuary"],"description":"Map changes apply in the lobby or on a full round restart, not individual respawns. All six maps support Bomb Defusal and faction rules."},
  {"key":"nu_enabled","category":"Combat","label":"Enable Nu (Annu only)","type":"bool","description":"One falcon flight per life. Q launches or recalls; body stays vulnerable. Sightings require Nu line of sight."},
  {"key":"bots_stand_still","category":"Bots","label":"Bots stand still","type":"bool","description":"Stops bot navigation and objectives for bullet testing. Gravity and damage remain active."},
  {"key":"bots_dont_shoot","category":"Bots","label":"Bots do not shoot","type":"bool","description":"Disables bot gunfire independently of movement."},
  {"key":"bullet_impact_debug","category":"Weapons","label":"First bullet impact · red block","type":"bool","description":"Shows a tiny red block for 5 seconds at the first surface or target hit. Limited to 128 active markers."},
  {
    "key": "cs_defuse_kits",
    "category": "Match",
    "label": "Defender defuse kits",
    "type": "bool",
    "section": "Bomb Defusal",
    "description": "Bomb mode only: everyone defending has a kit (5s defuse); without kits, 10s. One life; 120s round, 3.2s plant, 40s fuse. Sides swap after 15 rounds."
  },
  {
    "key": "health_type",
    "category": "Player",
    "label": "Health type",
    "type": "choice",
    "section": "Health",
    "options": [
      "Character default",
      "Naki health",
      "Annu health"
    ],
    "description": "Choose the protection system independently of the character artwork. Character default uses each character\u2019s own rules."
  },
  {
    "key": "mode",
    "category": "Match",
    "label": "Game mode",
    "type": "choice",
    "options": [
      "Extraction",
      "Iso Deathmatch",
      "Team Deathmatch",
      "Capture the Flag",
      "Bomb Defusal"
    ],
    "section": "Scoring & Time"
  },
  {
    "key": "score_to_win",
    "category": "Match",
    "label": "Score to win",
    "type": "number",
    "min": 1,
    "max": 500,
    "step": 1,
    "unit": "",
    "description": ""
  },
  {
    "key": "time_limit_seconds",
    "category": "Match",
    "label": "Time limit",
    "type": "number",
    "min": 0,
    "max": 3600,
    "step": 30,
    "unit": "s",
    "description": "0 means no time limit."
  },
  {
    "key": "max_players_per_team",
    "category": "Match",
    "label": "Players per team",
    "type": "number",
    "min": 1,
    "max": 8,
    "step": 1,
    "unit": "",
    "description": "",
    "section": "Teams"
  },
  {
    "key": "matchup",
    "category": "Match",
    "label": "Faction matchup",
    "type": "choice",
    "options": [
      "Naki vs Annu",
      "Naki vs Naki",
      "Annu vs Annu",
      "Annu vs Naki"
    ]
  },
  {
    "key": "friendly_fire_mode",
    "category": "Match",
    "label": "Friendly fire",
    "type": "choice",
    "options": [
      "Off",
      "On"
    ]
  },
  {
    "key": "bag_stock",
    "category": "Match",
    "label": "Gold bags per round",
    "type": "number",
    "min": 1,
    "max": 20,
    "step": 1,
    "unit": "",
    "description": "Used in Extraction only.",
    "section": "Extraction"
  },
  {
    "key": "max_health_percent",
    "category": "Player",
    "label": "Maximum health",
    "type": "number",
    "min": 10,
    "max": 1000,
    "step": 5,
    "unit": "%",
    "description": "Applies to both factions. Uses the selected health type.",
    "section": "Health"
  },
  {
    "key": "health_regeneration",
    "category": "Player",
    "label": "Regenerate health",
    "type": "bool",
    "description": "Restores 20% of maximum health per second after the shield recharge delay."
  },
  {
    "key": "health_regen_delay",
    "category": "Player",
    "label": "Health regeneration delay",
    "type": "number",
    "min": 0,
    "max": 30,
    "step": 0.25,
    "unit": "s"
  },
  {
    "key": "show_low_health_vignette",
    "category": "Player",
    "label": "Red screen edges",
    "type": "bool",
    "description": "Character default: off for Annu. Override per character to customize."
  },
  {
    "key": "damage_resistance_percent",
    "category": "Player",
    "label": "Damage resistance",
    "type": "number",
    "min": 10,
    "max": 1000,
    "step": 5,
    "unit": "%",
    "description": "100% is normal; 200% takes half damage. Exposed-head finishing rules still apply."
  },
  {
    "key": "armor_strength_percent",
    "category": "Annu Health",
    "label": "Annu body armor strength",
    "type": "number",
    "min": 0,
    "max": 1000,
    "step": 5,
    "unit": "%",
    "description": "Annu health only. Strength controls armor durability; absorption controls the share of damage stopped."
  },
  {
    "key": "helmet_strength_percent",
    "category": "Annu Health",
    "label": "Annu helmet strength",
    "type": "number",
    "min": 0,
    "max": 1000,
    "step": 5,
    "unit": "%",
    "description": "Annu health only. Strength controls armor durability; absorption controls the share of damage stopped."
  },
  {
    "key": "armor_absorption_percent",
    "category": "Annu Health",
    "label": "Annu body armor absorption",
    "type": "number",
    "min": 0,
    "max": 100,
    "step": 5,
    "unit": "%",
    "description": "Annu health only. Strength controls armor durability; absorption controls the share of damage stopped."
  },
  {
    "key": "helmet_absorption_percent",
    "category": "Annu Health",
    "label": "Annu helmet absorption",
    "type": "number",
    "min": 0,
    "max": 100,
    "step": 5,
    "unit": "%",
    "description": "Annu health only. Strength controls armor durability; absorption controls the share of damage stopped."
  }
,
  {
    "key": "shields_enabled",
    "category": "Naki Shields",
    "label": "Enable Naki shields",
    "type": "bool",
    "description": "",
    "section": "Naki Shields"
  },
  {
    "key": "shield_strength_percent",
    "category": "Naki Shields",
    "label": "Shield strength",
    "type": "number",
    "min": 0,
    "max": 1000,
    "step": 5,
    "unit": "%",
    "description": "Applies when Naki health is selected."
  },
  {
    "key": "shield_recharge_delay",
    "category": "Naki Shields",
    "label": "Shield recharge delay",
    "type": "number",
    "min": 0,
    "max": 30,
    "step": 0.25,
    "unit": "s",
    "description": "Time without damage before recharge starts."
  },
  {
    "key": "shield_recharge_rate_percent",
    "category": "Naki Shields",
    "label": "Shield recharge speed",
    "type": "number",
    "min": 0,
    "max": 500,
    "step": 5,
    "unit": "%",
    "description": "0 disables shield recharge."
  },
  {
    "key": "respawn_seconds",
    "category": "Player",
    "label": "Respawn delay",
    "type": "number",
    "min": 0,
    "max": 60,
    "step": 0.25,
    "unit": "s",
    "description": "",
    "section": "Respawn"
  },
  {
    "key": "movement_speed_percent",
    "category": "Movement",
    "label": "Movement speed",
    "type": "number",
    "min": 25,
    "max": 400,
    "step": 5,
    "unit": "%",
    "description": ""
  },
  {
    "key": "crouch_speed_percent",
    "category": "Movement",
    "label": "Crouch speed",
    "type": "number",
    "min": 25,
    "max": 400,
    "step": 5,
    "unit": "%",
    "description": ""
  },
  {
    "key": "acceleration_percent",
    "category": "Movement",
    "label": "Acceleration",
    "type": "number",
    "min": 25,
    "max": 400,
    "step": 5,
    "unit": "%",
    "description": ""
  },
  {
    "key": "deceleration_percent",
    "category": "Movement",
    "label": "Braking",
    "type": "number",
    "min": 25,
    "max": 400,
    "step": 5,
    "unit": "%",
    "description": ""
  },
  {
    "key": "gravity_percent",
    "category": "Movement",
    "label": "Gravity",
    "type": "number",
    "min": 10,
    "max": 400,
    "step": 5,
    "unit": "%",
    "description": ""
  },
  {
    "key": "jump_height_percent",
    "category": "Movement",
    "label": "Jump height",
    "type": "number",
    "min": 0,
    "max": 500,
    "step": 5,
    "unit": "%",
    "description": ""
  },
  {
    "key": "air_control_percent",
    "category": "Movement",
    "label": "Air control",
    "type": "number",
    "min": 0,
    "max": 300,
    "step": 5,
    "unit": "%",
    "description": ""
  },
  {
    "key": "explosion_knockback_percent",
    "category": "Movement",
    "label": "Explosion knockback",
    "type": "number",
    "min": 0,
    "max": 500,
    "step": 5,
    "unit": "%",
    "description": ""
  },
  {
    "key": "damage_dealt_percent",
    "category": "Combat",
    "label": "Player damage",
    "type": "number",
    "min": 0,
    "max": 1000,
    "step": 5,
    "unit": "%",
    "description": ""
  },
  {
    "key": "melee_damage_percent",
    "category": "Combat",
    "label": "Melee damage",
    "type": "number",
    "min": 0,
    "max": 1000,
    "step": 5,
    "unit": "%",
    "description": ""
  },
  {
    "key": "explosive_damage_percent",
    "category": "Combat",
    "label": "Explosion damage",
    "type": "number",
    "min": 0,
    "max": 1000,
    "step": 5,
    "unit": "%",
    "description": ""
  },
  {
    "key": "self_damage",
    "category": "Combat",
    "label": "Self damage",
    "type": "bool",
    "description": ""
  },
  {
    "key": "descope_on_damage",
    "category": "Combat",
    "label": "Damage cancels zoom",
    "type": "bool",
    "description": ""
  },
  {
    "key": "starting_primary",
    "category": "Weapons",
    "label": "Starting primary",
    "type": "weapon",
    "section": "Starting Loadout"
  },
  {
    "key": "starting_secondary",
    "category": "Weapons",
    "label": "Starting secondary",
    "type": "weapon"
  },
  {
    "key": "infinite_ammo",
    "category": "Weapons",
    "label": "Ammunition",
    "type": "choice",
    "options": [
      "Normal",
      "Infinite reserve",
      "Bottomless clip"
    ],
    "section": "Weapon Handling"
  },
  {
    "key": "fire_rate_percent",
    "category": "Weapons",
    "label": "Fire rate",
    "type": "number",
    "min": 25,
    "max": 400,
    "step": 5,
    "unit": "%",
    "description": ""
  },
  {
    "key": "reload_speed_percent",
    "category": "Weapons",
    "label": "Reload speed",
    "type": "number",
    "min": 25,
    "max": 400,
    "step": 5,
    "unit": "%",
    "description": ""
  },
  {
    "key": "recoil_percent",
    "category": "Weapons",
    "label": "Recoil",
    "type": "number",
    "min": 0,
    "max": 300,
    "step": 5,
    "unit": "%",
    "description": ""
  },
  {
    "key": "spread_percent",
    "category": "Weapons",
    "label": "Weapon spread",
    "type": "number",
    "min": 0,
    "max": 300,
    "step": 5,
    "unit": "%",
    "description": ""
  },
  {
    "key": "weapon_respawn_percent",
    "category": "Weapons",
    "label": "Map weapon respawn time",
    "type": "number",
    "min": 25,
    "max": 400,
    "step": 5,
    "unit": "%",
    "description": ""
  },
  {
    "key": "weapon_pickups",
    "category": "Weapons",
    "label": "Allow weapon pickups",
    "type": "bool",
    "description": ""
  },
  {
    "key": "map_weapons",
    "category": "Weapons",
    "label": "Spawn weapons on map",
    "type": "bool",
    "description": ""
  },
  {
    "key": "radar_enabled",
    "category": "Radar",
    "label": "Enable radar",
    "type": "bool",
    "description": ""
  },
  {
    "key": "radar_range",
    "category": "Radar",
    "label": "Naki radar range",
    "type": "number",
    "min": 10,
    "max": 50,
    "step": 1,
    "unit": "m",
    "description": ""
  },
  {
    "key": "radar_moving_only",
    "category": "Radar",
    "label": "Naki radar: moving enemies only",
    "type": "bool",
    "description": ""
  },
  {
    "key": "radar_edge_clamp",
    "category": "Radar",
    "label": "Naki radar: clamp contacts at edge",
    "type": "bool",
    "description": ""
  },
  {
    "key": "bot_difficulty",
    "category": "Bots",
    "label": "Bot difficulty",
    "type": "choice",
    "options": [
      "Easy",
      "Normal",
      "Hard"
    ]
  },
  {
    "key": "bots_fill_empty_slots",
    "category": "Bots",
    "label": "Fill empty slots with bots",
    "type": "bool",
    "description": ""
  },
  {"key":"bots_team_0","category":"Bots","label":"Team 1 bots (-1 = fill)","type":"number","min":-1,"max":16,"step":1,"description":"Exact bot count, limited by available team slots. Zero removes this team's bots at restart."},
  {"key":"bots_team_1","category":"Bots","label":"Team 2 bots (-1 = fill)","type":"number","min":-1,"max":16,"step":1,"description":"Exact bot count, limited by available team slots. Zero removes this team's bots at restart."},
  {
    "key": "bots_play_objectives",
    "category": "Bots",
    "label": "Bots play objectives",
    "type": "bool",
    "description": ""
  },
  {
    "key": "annu_body_health",
    "category": "Annu Health",
    "label": "Body health",
    "type": "number",
    "min": 10,
    "max": 1000,
    "step": 5,
    "unit": "HP",
    "description": "Shared health pool. Global maximum-health traits multiply this value."
  },
  {
    "key": "annu_head_health",
    "category": "Annu Health",
    "label": "Head health / durability",
    "type": "number",
    "min": 10,
    "max": 1000,
    "step": 5,
    "unit": "HP",
    "description": "Effective head durability, using the same health pool. Higher values reduce head health damage. Damage to the body also weakens the head."
  },
  {
    "key": "annu_body_armor",
    "category": "Annu Health",
    "label": "Body armour",
    "type": "number",
    "min": 0,
    "max": 1000,
    "step": 5,
    "unit": "HP",
    "description": "Body armour capacity; existing armour strength traits multiply this value."
  },
  {
    "key": "annu_head_armor",
    "category": "Annu Health",
    "label": "Head armour / helmet",
    "type": "number",
    "min": 0,
    "max": 1000,
    "step": 1,
    "unit": "HP",
    "description": "Helmet capacity; existing helmet strength traits multiply this value."
  },
  {
    "key": "annu_precision_ignores_helmet",
    "category": "Annu Health",
    "label": "Precision headshots bypass helmet",
    "type": "bool",
    "description": "Default preserves current battle-rifle/plasma precision rules. Disable to let helmet armour absorb those hits."
  },
  {
    "key": "naki_shield_capacity",
    "category": "Naki Shields",
    "label": "Base shield capacity",
    "type": "number",
    "min": 0,
    "max": 1000,
    "step": 5,
    "unit": "HP",
    "description": "One regenerating shield pool. The shared shield-strength percentage multiplies this capacity."
  },
  {
    "key": "naki_body_shield_strength",
    "category": "Naki Shields",
    "label": "Body bullet shield strength",
    "type": "number",
    "min": 0.1,
    "max": 20,
    "step": 0.05,
    "unit": "\u00d7",
    "description": "Incoming body gun damage is divided by this number. Default 1.00\u00d7. Also applies to Naki Shield pickups."
  },
  {
    "key": "naki_head_shield_strength",
    "category": "Naki Shields",
    "label": "Head bullet shield strength",
    "type": "number",
    "min": 0.1,
    "max": 20,
    "step": 0.05,
    "unit": "\u00d7",
    "description": "Incoming head gun damage is divided by this number. Default 1.00\u00d7. Raw headshot damage is 2x before this explicit trait."
  },
  {
    "key": "sniper_instant_headshots",
    "category": "Weapon Damage",
    "label": "Sniper instant headshot kills",
    "type": "bool",
    "description": "Default preserves the sniper finisher. Turn off to balance sniper head damage numerically. Exposed Naki headshot finishers remain part of Naki health rules."
  }
]

func validate_character_traits() -> void:
	var clean={};var ranges={}
	for definition in definitions():ranges[definition.key]=definition
	for character in NestCharacterCatalog.all():
		var input=character_traits.get(character.id,{})
		if not input is Dictionary:continue
		var traits={}
		for key in input:
			if not key is String or not NestCharacterTraits.is_trait(key):continue
			var sample=get(key);var value=input[key]
			if typeof(sample) in [TYPE_INT,TYPE_FLOAT]:
				if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)):continue
				var definition=ranges.get(key,{})
				if definition.get("type","")=="choice":value=clampi(int(value),0,definition.options.size()-1)
				else:value=clampf(float(value),float(definition.get("min",0)),float(definition.get("max",1000)))
				traits[key]=int(round(value)) if typeof(sample)==TYPE_INT else float(value)
			elif typeof(value)==typeof(sample):
				if ranges.get(key,{}).get("type","")=="weapon" and value not in ["none","default"]:
					var choices=NestWeaponCatalog.choices("primary" if key=="starting_primary" else "secondary")
					if not choices.any(func(option):return option.id==value):continue
				traits[key]=value
		if not traits.is_empty():clean[character.id]=traits
	character_traits=clean
