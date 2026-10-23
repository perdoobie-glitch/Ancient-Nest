class_name NestNuPerch
extends Area3D
var owner_actor: NestActor
func _ready() -> void:
 collision_layer=8;collision_mask=0;monitoring=false;set_meta("nu",self)
 var body=CapsuleShape3D.new();body.radius=.095;body.height=.34
 var c=CollisionShape3D.new();c.shape=body;c.rotation.x=PI*.5;add_child(c)
 var wings=BoxShape3D.new();wings.size=Vector3(.5,.12,.47)
 c=CollisionShape3D.new();c.shape=wings;c.position=Vector3(0,-.025,.18);add_child(c)
 var head=SphereShape3D.new();head.radius=.055
 c=CollisionShape3D.new();c.shape=head;c.position=Vector3(0,.065,-.16);add_child(c)
 var feet=BoxShape3D.new();feet.size=Vector3(.09,.07,.06)
 c=CollisionShape3D.new();c.shape=feet;c.position=Vector3(0,-.12,.018);add_child(c)
func destroy(_reason: String) -> void:
 var game=owner_actor.game
 if game.is_client() or not owner_actor.alive or owner_actor.character!=1 or owner_actor.nu_used or not game.game_type.nu_enabled:return
 owner_actor.nu_used=true;collision_layer=0
 if owner_actor.perched_nu!=null:owner_actor.perched_nu.visible=false
