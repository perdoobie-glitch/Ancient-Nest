class_name NestNetworkPolicy
extends RefCounted
## Authority-side admission and timing; independent of input devices/rendering.
const SIMULATION_HZ = 60
const MAX_REWIND = .150
const INTERPOLATION_MIN = .075
const INTERPOLATION_MAX = .200
const MAX_PENDING_ACTIONS = 32
const MAX_COMMAND_LEAD = 120
var buckets: Dictionary = {}
var probes: Dictionary = {}
var round_trips: Dictionary = {}
var actions: Dictionary = {}
var maximum_rewind: float = MAX_REWIND
var view_delays: Dictionary = {}
func accept_action(peer: int, category: String, sequence: int, scope: String) -> bool:
	if sequence<=0:return true # Legacy arrival-time path, still rate/cooldown limited.
	var key=str(peer)+":"+category
	var previous: Dictionary=actions.get(key,{"scope":"","sequence":-1})
	if previous.scope==scope and sequence<=int(previous.sequence):return false
	actions[key]={"scope":scope,"sequence":sequence}
	return true
func admit(peer: int, category: String, time: float, rate: float, burst: float) -> bool:
	var key = str(peer)+":"+category
	var bucket: Dictionary = buckets.get(key,{"time":time,"tokens":burst})
	bucket.tokens=minf(burst,float(bucket.tokens)+maxf(0,time-float(bucket.time))*rate)
	bucket.time=time
	var accepted: bool = bucket.tokens>=1
	if accepted: bucket.tokens-=1
	buckets[key]=bucket
	return accepted
func start_probe(peer: int, time: float) -> int:
	var nonce=int(Crypto.new().generate_random_bytes(4).decode_u32(0)&0x7fffffff)
	probes[peer]={"nonce":nonce,"time":time}
	return nonce
func finish_probe(peer: int, nonce: int, time: float, view_delay: float=INTERPOLATION_MIN) -> bool:
	if not probes.has(peer) or int(probes[peer].nonce)!=nonce:return false
	var elapsed=time-float(probes[peer].time)
	probes.erase(peer)
	if elapsed<0 or elapsed>1:return false
	var samples: Array=round_trips.get(peer,[])
	samples.append(elapsed)
	if samples.size()>20:samples.pop_front()
	round_trips[peer]=samples
	var sorted=samples.duplicate();sorted.sort()
	var jitter=float(sorted[-1])-float(sorted[0])
	# Interpolation is a declared rendering policy, never a shot timestamp.
	# Bound it using measured jitter as well as the global policy ceiling.
	if is_finite(view_delay):view_delays[peer]=clampf(view_delay,INTERPOLATION_MIN,minf(INTERPOLATION_MAX,.100+jitter*.5))
	return true
func rewind_age(peer: int) -> float:
	var samples: Array=round_trips.get(peer,[])
	# No clock sample means no rewind. Minimum observed RTT limits delayed-pong
	# manipulation; timestamps supplied by a shooter never enlarge this budget.
	if samples.size()<3:return 0
	return minf(clampf(maximum_rewind,0,MAX_REWIND),float(samples.min())*.5+float(view_delays.get(peer,INTERPOLATION_MIN)))
func one_way(peer: int) -> float:
	var samples: Array=round_trips.get(peer,[])
	return float(samples.min())*.5 if samples.size()>=3 else 0
