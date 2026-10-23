extends SceneTree
func _initialize():call_deferred("run")
func run():
 Engine.max_fps=30
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 for i in range(10):await process_frame
 game.prefs.values.fullscreen=false;game.prefs.values.aspect_ratio=0;game.prefs.values.resolution_width=1280;game.prefs.values.resolution_height=720;NestDisplaySettings.apply(game.prefs.values)
 var mm=game.matchmaking;mm.active=true;mm.party_mode=true;mm.phase="party";mm.hybrid.player_id="me";mm.playlist="tactical_3v3"
 mm.party={"code":"ABCD123456","leader":"me","members":[{"user":"me","name":"Perdoobie","leader":true,"rating":0},{"user":"friend","name":"Mishwad","leader":false,"rating":0}],"playlist":"tactical_3v3"}
 mm.status="Invite friends or search solo. Your party stays on the same team.";game.show_matchmaking()
 for dimensions in [Vector2i(1280,720),Vector2i(640,360)]:
  root.size=dimensions
  for i in range(12):await process_frame
  print("VISUAL size ",root.size," logical ",root.get_visible_rect().size)
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("/workspace/work/party-matchmaking-update/party-%dx%d.png"%[dimensions.x,dimensions.y])
 game.queue_free()
 for i in range(4):await process_frame
 quit()
