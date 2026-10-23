extends SceneTree
var rows=[]
var failure_count=0
func _initialize():call_deferred("run")
func length_of(a,start,end):
 var path=a.route(start,end)
 if path.is_empty():return INF
 var d=start.distance_to(path[0])
 for i in range(1,path.size()):d+=path[i-1].distance_to(path[i])
 return d
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.apply_game_type_settings(NestMatchPresets.create(2,2));await physics_frame;await physics_frame
 var a=game.arena
 var targets={"Site A":a.sites[0]+Vector3(3,0,0),"Site B":a.sites[1]+Vector3(-3,0,0),"Mid":Vector3(0,0,-1)*.85,"Terrace":Vector3(8,3.8,10)*.85}
 for i in range(a.pads.size()):targets["Pickup "+a.pad_kinds[i]+" "+str(i)]=a.pads[i]
 for title in targets:
  var distances=[]
  for team in [0,1]:
   var d=0.
   for s in a.spawns[team]:d+=length_of(a,s,targets[title])
   distances.append(d/a.spawns[team].size())
  var row={"target":title,"south_m":distances[0],"north_m":distances[1],"gap_s":absf(distances[0]-distances[1])/game.tuning.ground_speed};rows.append(row);print(JSON.stringify(row))
 var exposed=0
 for s in a.spawns[0]:
  for n in a.spawns[1]:
   var q=PhysicsRayQueryParameters3D.create(s+Vector3.UP*1.6,n+Vector3.UP*1.6,1)
   if game.get_world_3d().direct_space_state.intersect_ray(q).is_empty():exposed+=1
 print("SPAWN LOS ",exposed,"/25")
 if exposed!=0:failure_count+=1
 for row in rows:
  if row.target in ["Site A","Site B","Mid","Pickup sniper 5","Pickup overshield 9"] and row.gap_s>.75:failure_count+=1
 for pair in [[0,1],[2,3],[6,7],[4,8]]:
  var south=length_of(a,a.spawns[0][2],a.pads[pair[0]])
  var north=length_of(a,a.spawns[1][2],a.pads[pair[1]])
  var gap=absf(south-north)/game.tuning.ground_speed
  print("PAIRED PICKUP ",pair," gap_s=",gap)
  if gap>.75:failure_count+=1
 for team in [0,1]:
  var other=1-team
  var perch=Vector3(8,3.8,10) if team==0 else Vector3(-8,3.8,-12)
  for spawn in a.spawns[other]:
   var q=PhysicsRayQueryParameters3D.create(perch*.85+Vector3.UP*1.6,spawn+Vector3.UP*1.6,1)
   if game.get_world_3d().direct_space_state.intersect_ray(q).is_empty():failure_count+=1;print("FAIL terrace sees enemy spawn")
 print("BALANCE ACCEPTANCE failures=",failure_count)
 FileAccess.open("user://savannah-balance.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 game.queue_free();await create_timer(.2).timeout;quit(0 if failure_count==0 else 1)
