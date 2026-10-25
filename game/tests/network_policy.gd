extends SceneTree
var failures=0
func check(ok: bool, message: String):
	print(("PASS " if ok else "FAIL ")+message)
	if not ok:failures+=1
func _initialize():
	var policy=preload("res://scripts/network_policy.gd").new()
	check(policy.rewind_age(2)==0,"Unmeasured peers receive no rewind")
	for i in range(3):
		var nonce=policy.start_probe(2,float(i))
		check(not policy.finish_probe(3,nonce,float(i)+.1),"Probe sender is bound")
		check(not policy.finish_probe(2,nonce+1,float(i)+.1),"Probe nonce is bound")
		check(policy.finish_probe(2,nonce,float(i)+.1),"Host accepts matched round trip")
		check(not policy.finish_probe(2,nonce,float(i)+.2),"Duplicate probe rejected")
	check(absf(policy.rewind_age(2)-.125)<.00001,"Rewind uses host RTT and interpolation floor")
	var n=policy.start_probe(2,10)
	policy.finish_probe(2,n,10.9)
	check(absf(policy.rewind_age(2)-.125)<.00001,"Delayed reply cannot enlarge minimum RTT budget")
	policy.maximum_rewind=.05
	check(policy.rewind_age(2)==.05,"Configured rewind ceiling enforced")
	check(policy.admit(2,"action",0,2,2) and policy.admit(2,"action",0,2,2),"Burst admitted")
	check(not policy.admit(2,"action",0,2,2),"Flood rejected")
	check(policy.admit(2,"action",.5,2,2),"Budget refills at configured rate")
	check(policy.admit(3,"action",0,2,2),"Peer budgets are isolated")
	check(policy.accept_action(2,"switch",9,"life1"),"New action admitted")
	check(not policy.accept_action(2,"switch",9,"life1"),"Duplicate action rejected")
	check(not policy.accept_action(2,"switch",8,"life1"),"Out of order action rejected")
	check(policy.accept_action(2,"switch",1,"life2"),"New life permits fresh sequence")
	print("NETWORK POLICY failures="+str(failures))
	quit(1 if failures else 0)
