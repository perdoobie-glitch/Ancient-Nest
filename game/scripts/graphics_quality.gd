class_name NestGraphicsQuality
extends RefCounted
const LABELS = ["Low", "Balanced", "High"]
static func level(values: Dictionary) -> int:
 return clampi(int(values.get("graphics_quality",0)),0,2)
static func apply_viewport(viewport: Viewport, values: Dictionary) -> void:
 var quality=level(values)
 viewport.msaa_3d=[Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X][quality]
 var aa=int(values.get("antialiasing",0))
 if aa>0:viewport.msaa_3d=[Viewport.MSAA_DISABLED,Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X,Viewport.MSAA_8X][aa]
 viewport.mesh_lod_threshold=[3.0,1.5,1.0][quality]
 viewport.positional_shadow_atlas_size=[1024,2048,4096][quality]
static func shadows_enabled(values: Dictionary) -> bool:
 return level(values)>0 and bool(values.shadows)
static func apply_arena(arena: NestArena, values: Dictionary) -> void:
 if not is_instance_valid(arena):return
 arena.set_shadows_enabled(shadows_enabled(values))
 if arena.kit.stone is ShaderMaterial:arena.kit.stone.set_shader_parameter("low_detail",level(values)==0)
static func effect_count(game: Node, full_count: int) -> int:
 return maxi(1,ceili(full_count*.5)) if level(game.prefs.values)==0 else full_count
