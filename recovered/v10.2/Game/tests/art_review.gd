extends SceneTree
var game
var checks=0
var failures=0
var output_dir=""
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	checks+=1
	if ok: print("PASS: "+message)
	else: failures+=1; push_error("FAIL: "+message)
func frames(count=8):
	for i in range(count): await process_frame
func snap(name):
	await frames(12)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output_dir.path_join(name+".png"))
func run():
	output_dir=OS.get_environment("AN_ART_OUTPUT")
	if output_dir.is_empty(): output_dir="user://art-review"
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size=Vector2i(1440,900)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game); await frames()
	for faction in [0,1]:
		game.show_character(faction); await frames()
		var viewport=game.screen.find_children("*","SubViewport",true,false)[0]
		var stage=viewport.get_child(0)
		var hero=stage.get_child(3)
		# Find imported skeleton root without depending on the studio's child order.
		for child in stage.get_children():
			if not child.find_children("*","Skeleton3D",true,false).is_empty(): hero=child
		var skeletons=hero.find_children("*","Skeleton3D",true,false)
		check(skeletons.size()==1 and skeletons[0].get_bone_count()==40,"Character has the original 40-bone rig")
		var textured=0
		for mesh in hero.find_children("*","MeshInstance3D",true,false):
			for i in range(mesh.mesh.get_surface_count()):
				var mat=mesh.mesh.surface_get_material(i)
				if mat is StandardMaterial3D and mat.albedo_texture!=null and mat.normal_texture!=null and mat.roughness_texture!=null: textured+=1
		check(textured>=5,"Baked color, roughness, and normal maps survive Godot import")
		await snap("art_"+("naki" if faction==0 else "annu")+"_front")
		hero.rotation.y=PI; await snap("art_"+("naki" if faction==0 else "annu")+"_back")
	if "characters-only" in OS.get_cmdline_user_args():
		print("CHARACTER ART REVIEW: ",checks," checks; ",failures," failures")
		quit(1 if failures else 0); return
	game.bot_fill=false; game.start_game(); game.clear_screen();game.create_hud();game.hud.visible=true;game.context="pause"
	var p=game.player
	p.global_position=Vector3(-13,7.1,0);p.rotation.y=-PI/2;p.eye.rotation.x=0
	for kind in ["rifle","burst","sidearm","sniper","rocket","shotgun"]:
		var resource=load("res://resources/"+kind+".tres")
		p.weapons[0]=resource;p.slot=0;p.update_weapon_art();await frames()
		check(p.weapon_art!=null and p.art_kind==kind,"Weapon artwork switches to "+kind)
		await snap("art_weapon_"+kind)
	p.weapons[0]=load("res://resources/rifle.tres");p.update_weapon_art()
	p.global_position=Vector3(-29,9.1,7);p.rotation.y=PI/2;p.eye.rotation.x=-.10;await snap("art_ship")
	p.global_position=Vector3(10,7.1,0);p.rotation.y=-PI/2;p.eye.rotation.x=-.04;await snap("art_ore")
	game.site_states[0].stage="drilling"; game.site_states[0].work=0
	await snap("art_drill")
	check(game.arena.deposits[0].get_node("Opened").visible,"Drilling state displays the mechanical drill")
	check(game.arena.flag_meshes[0].mesh is ArrayMesh,"Faction banner is a deformable cloth mesh")
	check(game.player.hitboxes.size()==11,"Decorative artwork adds no damage targets")
	print("ART REVIEW: ",checks," checks; ",failures," failures")
	quit(1 if failures else 0)
