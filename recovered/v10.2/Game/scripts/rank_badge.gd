class_name NestRankBadge
extends HBoxContainer
const EMBLEMS=[preload("res://assets/ranks/tier_01.tres"),preload("res://assets/ranks/tier_02.tres"),preload("res://assets/ranks/tier_03.tres"),preload("res://assets/ranks/tier_04.tres"),preload("res://assets/ranks/tier_05.tres"),preload("res://assets/ranks/tier_06.tres"),preload("res://assets/ranks/tier_07.tres"),preload("res://assets/ranks/tier_08.tres"),preload("res://assets/ranks/tier_09.tres"),preload("res://assets/ranks/tier_10.tres"),preload("res://assets/ranks/tier_11.tres"),preload("res://assets/ranks/tier_12.tres"),preload("res://assets/ranks/tier_13.tres"),preload("res://assets/ranks/tier_14.tres"),preload("res://assets/ranks/tier_15.tres"),preload("res://assets/ranks/tier_16.tres"),preload("res://assets/ranks/tier_17.tres"),preload("res://assets/ranks/tier_18.tres"),preload("res://assets/ranks/tier_19.tres"),preload("res://assets/ranks/tier_20.tres"),preload("res://assets/ranks/tier_21.tres")]
static func emblem_for(elo: int) -> Texture2D:return EMBLEMS[NestRatingProfile.rank_for(elo).number-1]
const COLORS=[Color("afe8a8"),Color("cd8b45"),Color("d5dce3"),Color("a4dbff"),Color("ff555b"),Color("c28aff"),Color("71ab7b")]
const ACCENTS=[Color("afe8a8"),Color("e2ac6c"),Color("f0f3f6"),Color("b9e5ff"),Color("ff555b"),Color("f2f1ff"),Color("d8b75e")]
static func color_for(elo: int) -> Color:return COLORS[NestRatingProfile.rank_for(elo).group]
var emblem: TextureRect
var text: Label
var tier: Label
var last_signature=""
var light_theme=false
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE;add_theme_constant_override("separation",10)
 emblem=TextureRect.new();emblem.custom_minimum_size=Vector2(52,52);emblem.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;emblem.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;emblem.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(emblem)
 var column=VBoxContainer.new();column.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(column)
 text=Label.new();text.add_theme_font_size_override("font_size",14);column.add_child(text)
 tier=Label.new();tier.add_theme_font_size_override("font_size",12);tier.add_theme_color_override("font_color",Color("cbb481"));column.add_child(tier)
func update_rating(elo: int,channel: String,kills: int,deaths: int,unrated=false) -> void:
 var signature=str([elo,channel,kills,deaths,unrated])
 if signature==last_signature or emblem==null:return
 last_signature=signature;var rank=NestRatingProfile.rank_for(elo)
 var online_rank=NestPlaylistRanks.rank_for(elo)
 rank.name=online_rank.name;rank.roman=online_rank.roman
 emblem.texture=emblem_for(elo)
 text.add_theme_color_override("font_color",Color("126b32") if light_theme else COLORS[rank.group]);tier.add_theme_color_override("font_color",Color("4c6252") if light_theme else ACCENTS[rank.group])
 emblem.tooltip_text="%s %s · Rank %d/21"%[rank.name,rank.roman,rank.number]
 text.text="%s %s · %d/21\n%d Elo · %s"%[rank.name,rank.roman,rank.number,elo,"MATCHMAKING" if not unrated else "CUSTOM"]
 tier.text="●".repeat(rank.tier)+"○".repeat(3-rank.tier)+" · "+("KD —" if kills+deaths==0 else "Match K/D %.2f"%(float(kills)/maxi(1,deaths)))+" · "+("UNRANKED" if unrated else "SERVER ELO")
