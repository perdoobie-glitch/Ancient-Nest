class_name NestWeaponAccuracy
extends RefCounted
# Cone angle controls how wide the shot distribution becomes as distance grows.
# Family-specific intrinsic pellet spread is separate from aim-axis accuracy.
const CONES={"A":0.0,"B":0.15,"C":0.35,"D":0.75}
static func cone(config: Dictionary) -> float:
 var grade=str(config.get("accuracy_grade",""))
 if not CONES.has(grade):return float(config.get("spread_half_angle_deg",config.get("spread_degrees",0.0)))
 return float(CONES[grade])*maxf(0.,float(config.get("accuracy_scale",1.)))+maxf(0.,float(config.get("pattern_spread_half_angle_deg",0.)))
