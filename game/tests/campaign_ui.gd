extends SceneTree
var failures=0
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.sandbox_mode=true;var c=game.campaign;c.save_store.path="user://no-campaign-ui-qa-checkpoint.json"
 for dimensions in [Vector2i(1920,1080),Vector2i(1280,800),Vector2i(640,480)]:
  root.size=dimensions;root.content_scale_size=dimensions;c.menu()
  for i in range(4):await process_frame
  var picker=game.screen.find_child("CampaignDifficulty",true,false);var good=picker!=null and picker.item_count==4 and picker.get_item_text(0)=="Easy" and picker.get_item_text(1)=="Medium" and picker.get_item_text(2)=="Hard" and picker.get_item_text(3)=="Angel"
  print(("PASS " if good else "FAIL ")+"Difficulty choices at "+str(dimensions));if not good:failures+=1
  var buttons=game.screen.find_children("*","Button",true,false);var back=buttons.filter(func(b):return b.text=="Back")
  good=back.size()==1 and back[0].get_global_rect().end.y<=dimensions.y and back[0].get_global_rect().position.x>=0
  print(("PASS " if good else "FAIL ")+"Campaign Back navigation fits "+str(dimensions));if not good:failures+=1
  var labels=game.screen.find_children("*","Label",true,false)
  good=labels.any(func(label):return label.text=="Difficulty") and not labels.any(func(label):return label.text.contains("Bot Difficulty"))
  print(("PASS " if good else "FAIL ")+"Campaign uses Difficulty label");if not good:failures+=1
 game.queue_free();await process_frame;print("CAMPAIGN UI failures=",failures);quit(1 if failures else 0)
