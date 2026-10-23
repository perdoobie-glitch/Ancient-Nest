extends NestActor
var hover_queries: int = 0
var forced_hover: float = 1.0
func query_enemy_hover_multiplier() -> float:
	hover_queries+=1
	return forced_hover
func query_actual() -> float:
	return super.query_enemy_hover_multiplier()
