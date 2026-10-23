class_name NestSanctuaryFlow
extends RefCounted
static func build(a: NestArena) -> void:
 # Connect west service / center / east vault below the existing ascent.
 # This stays below the ramp with standing clearance instead of roofing its exit.
 a.floor_at(0,0,-10,Vector2(44,6))
 for x in [-14,14]:NestSanctuaryLayout.cover(a,Vector3(x,0,-10.5),Vector2(3,1.0))
 a.kit.label(a,Vector3(0,2,-12),"NORTH CONCOURSE · WEST ↔ EAST",Color("dfc890"),25)
 # A second rafter access avoids a single narrow entrance controlling all high ground.
 var pad=NestManCannon.new();pad.name="C4_GardenToRafters";pad.position=Vector3(30,14,14.8);pad.destination=Vector3(24,22.8,12);pad.flight_seconds=2.2;a.add_child(pad)
 a.kit.cylinder(pad,Vector3(0,.05,0),1.15,.1,a.kit.dark)
 a.kit.ring(pad,Vector3(0,.13,0),.85,a.kit.gold)
 a.kit.label(pad,Vector3(0,2,0),"RAFTER RETURN ↑",Color("77cbd8"),22)
 a.cannon_routes.append({"name":"C4 · GARDEN TO RAFTERS","start":pad.position,"end":pad.destination})
