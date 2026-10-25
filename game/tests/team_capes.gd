extends SceneTree
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 print(("PASS: " if ok else "FAIL: ")+message)
 if not ok:failures+=1
func cape(actor):return actor.model.find_children("Cape","MeshInstance3D",true,false)[0].get_active_material(0)
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.set_process(false);game.sandbox_mode=true
 for kind in [0,1]:
  game.team_characters.assign([kind,kind])
  var actors=[]
  for team in [0,1]:
   var actor=NestActor.new();actor.game=game;actor.faction=team;actor.character_choice=kind;game.add_child(actor);actors.append(actor)
  check(cape(actors[0]).albedo_color==Color("a52d35"),"Red cape for mirror character "+str(kind))
  check(cape(actors[1]).albedo_color==Color("36834b"),"Green cape for mirror character "+str(kind))
  check(cape(actors[0])!=cape(actors[1]),"Team cape materials do not affect each other")
  game.team_characters.assign([0,1])
  for actor in actors:actor.refresh_model_visibility()
  check(cape(actors[0]).albedo_color==NestReferenceSkin.finish("olive" if kind==0 else "crimson").albedo_color,"Mixed matchup restores original cloth")
  for actor in actors:actor.queue_free()
  await process_frame
 game.queue_free();await process_frame;quit(1 if failures else 0)
