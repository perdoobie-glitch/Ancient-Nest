extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);await physics_frame;await physics_frame
 var scale=game.arena.MAP_SCALE
 var central=game.trace(Vector3(0,16,0)*scale,Vector3(0,55,0)*scale,1)
 # Rafter crossings lie below the ceiling; sample a clear vertical aisle instead.
 central=game.trace(Vector3(5,24,0)*scale,Vector3(5,55,0)*scale,1)
 var side=game.trace(Vector3(25,24,5)*scale,Vector3(25,55,5)*scale,1)
 check(not central.is_empty() and absf((central.position.y/scale-14)/(31.675-14)-2)<.001,"Central ceiling clear height is exactly doubled")
 check(not side.is_empty() and absf((side.position.y/scale-14)/(28.675-14)-2)<.001,"Side ceiling clear height is exactly doubled")
 var windows=game.arena.find_children("SolidStainedGlass","StaticBody3D",true,false)
 check(windows.size()==34,"All 34 side bays have solid church-style glazing")
 for x in [-36,-28,28,36]:
  for sign in [-1,1]:
   var y=28.0
   var hit=game.trace(Vector3(x,y,sign*27)*scale,Vector3(x,y,sign*31)*scale,1)
   check(not hit.is_empty(),"Church window blocks shots at side bay "+str(Vector2(x,sign)))
   for z in [sign*27.75,sign*30.25]:
    var p=Vector3(x,NestChurchWindow.SILL,z)*scale
    var floor=game.trace(p+Vector3.UP*.2,p-Vector3.UP*.4,1)
    check(not floor.is_empty(),"Window ledge has solid support "+str(Vector2(x,z)))
    var q=PhysicsShapeQueryParameters3D.new();var cap=CapsuleShape3D.new();cap.height=NestActor.STAND_HEIGHT;cap.radius=NestActor.BODY_RADIUS;q.shape=cap;q.transform=Transform3D(Basis.IDENTITY,p+Vector3.UP*(NestActor.STAND_CENTER+.06));q.collision_mask=1
    check(game.get_world_3d().direct_space_state.intersect_shape(q).is_empty(),"Standing capsule fits window ledge "+str(Vector2(x,z)))
 print("V16 VAULT: %d checks, %d failures"%[checks,failures]);game.queue_free();await process_frame;quit(1 if failures else 0)
