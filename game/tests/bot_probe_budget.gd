extends SceneTree
class Clock extends Node3D:
 var now=0.0
class Probe extends NestBotMovement:
 var wanted=Vector3.FORWARD
 var pattern=0
 var calls=0
 func _init(owner:NestActor):super(owner)
 func clear_direction(direction:Vector3,distance:float=1.25)->bool:
  calls+=1
  if direction.is_equal_approx(wanted):return bool(pattern&1)
  var index=1
  for angle in [35,65,95,125,155,180]:
   for side in [recovery_side,-recovery_side]:
    if direction.is_equal_approx(wanted.rotated(Vector3.UP,deg_to_rad(angle*side))):return bool(pattern&(1<<index))
    index+=1
  return false
 func full_search()->Vector3:
  if wanted.length_squared()<.001:return Vector3.ZERO
  if clear_direction(wanted):return wanted
  var best=Vector3.ZERO;var score=-INF
  for angle in [35,65,95,125,155,180]:
   for side in [recovery_side,-recovery_side]:
    var candidate=wanted.rotated(Vector3.UP,deg_to_rad(angle*side))
    if not clear_direction(candidate):continue
    var value=candidate.dot(wanted)+(.08 if side==recovery_side else 0.0)
    if value>score:score=value;best=candidate
  return best
func _initialize():call_deferred("run")
func run():
 var clock=Clock.new();var actor=NestActor.new();actor.game=clock;var probe=Probe.new(actor);var rng=RandomNumberGenerator.new();rng.seed=100101
 var checks=0;var previous_calls=0;var bounded_calls=0
 for magnitude in [.04,.1,.5,1.,2.]:
  for vertical in [0.,.1,.6]:
   for side in [-1,1]:
    for sample in range(300):
     probe.wanted=Vector3.FORWARD.rotated(Vector3.UP,rng.randf_range(-PI,PI))*magnitude;probe.wanted.y=vertical*magnitude
     probe.pattern=rng.randi_range(0,8191);probe.recovery_side=side;probe.calls=0
     var expected=probe.full_search();previous_calls+=probe.calls;probe.calls=0
     var actual=probe.choose_direction(probe.wanted);bounded_calls+=probe.calls
     assert(actual.is_equal_approx(expected),"Probe bound changed selected escape direction")
     checks+=1
 assert(bounded_calls<previous_calls*.8,"Bound must save probes without changing the result")
 print("PROBE BUDGET: ",checks," equivalence cases; old sweeps=",previous_calls," bounded sweeps=",bounded_calls)
 actor.free();clock.free();call_deferred("quit")
