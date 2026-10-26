class_name NestCampaignBase
extends RefCounted
var w
var stats={"landing_pads":0,"buildings":0,"props":0}
func _init(world):w=world
func build():
 var deck=w.surface("465c65","80928b",1,.25);var copper=w.kit.material(Color("b88753"),.65)
 var p=Vector3(-2,0,-20)
 w.kit.cylinder(w.scene_root,p+Vector3.UP*.012,23,.035,deck)
 for i in range(48):
  var a=i*TAU/48;var mark=w.block(p+Vector3(cos(a)*21,.04,sin(a)*21),Vector3(1.5,.025,.2),w.kit.gold,false);mark.rotation.y=-a
  if i%4==0:
   var lamp=w.block(p+Vector3(cos(a)*22,.09,sin(a)*22),Vector3(.55,.12,.4),w.kit.lamp,false);lamp.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 for x in [-6,6]:w.block(p+Vector3(x,.045,0),Vector3(.4,.025,18),w.kit.gold,false)
 w.block(p+Vector3(0,.045,0),Vector3(12,.025,.4),w.kit.gold,false)
 stats.landing_pads=1;w.locations["landing_pad"]=p
 # Perimeter buildings occupy previously empty corners, away from tutorial stations.
 for item in [[Vector3(-53,0,-48),Color("527b79")],[Vector3(48,0,-53),Color("90735b")],[Vector3(53,0,42),Color("5f708f")],[Vector3(-53,0,52),Color("6c7c62")]]:
  building(item[0],w.kit.material(item[1],.25),copper)
 for i in range(12):
  var pos=Vector3(40+(i%3)*3,0,15+floori(i/3.0)*3)
  w.block(pos+Vector3.UP*.65,Vector3(2.2,1.3,2.2),w.palette.tower_copper)
  for x in [-.85,.85]:w.block(pos+Vector3(x,.65,1.12),Vector3(.1,1.3,.06),w.kit.gold,false)
  stats.props+=1
 for side in [-1,1]:
  for i in range(4):
   var pos=Vector3(side*65,0,-28+i*19)
   w.kit.cylinder(w.scene_root,pos+Vector3.UP*4,.18,8,w.kit.dark)
   w.block(pos+Vector3(0,7.9,0),Vector3(1.7,.2,1),w.kit.lamp,false)
   w.block(pos+Vector3(-side*2,.3,0),Vector3(2,.6,3),w.palette.hull)
   for j in range(3):w.kit.sphere(w.scene_root,pos+Vector3(-side*2,.9,-.8+j*.8),.65,w.palette.leaf)
   stats.props+=1
 for x in [-63,64]:
  for z in [-57,64]:
   w.kit.cylinder(w.scene_root,Vector3(x,2,z),2,4,deck,true)
   for h in [1.2,2.5,3.8]:w.block(Vector3(x,h,z+2.02),Vector3(2,.15,.08),copper,false)
   stats.props+=1
 # Flush service lanes and protected docking equipment provide scale without new barriers.
 for x in [-45,38]:
  w.block(Vector3(x,.035,1),Vector3(.18,.025,110),w.kit.gold,false)
  for z in range(-48,60,8):w.block(Vector3(x+1,.035,z),Vector3(1.5,.025,.15),copper,false)
 for side in [-1,1]:
  var pos=p+Vector3(side*27,0,-1)
  w.block(pos+Vector3.UP*.7,Vector3(2,1.4,4),deck)
  for j in range(4):w.kit.cylinder(w.scene_root,pos+Vector3(-.6+j*.4,1.48,0),.12,.2,copper)
 # Solar maintenance garden and parked service transports fill the outer apron.
 var solar=w.kit.material(Color("254f68"),.45)
 for x in range(3):
  for z in range(4):
   var pos=Vector3(-58+x*4,0,-7+z*4)
   w.block(pos+Vector3.UP*.6,Vector3(.25,1.2,2.2),w.kit.dark)
   var panel=w.block(pos+Vector3.UP*1.25,Vector3(3.4,.13,3),solar,false);panel.rotation.x=-.18
   for j in [-1,0,1]:w.block(pos+Vector3(j,.15+1.25,0),Vector3(.025,.025,2.8),copper,false)
   stats.props+=1
 for item in [[Vector3(-39,0,48),w.palette.tower_teal],[Vector3(38,0,52),w.palette.tower_copper]]:
  var pos=item[0];var paint=item[1]
  w.block(pos+Vector3.UP*.9,Vector3(6,1.15,3),paint)
  w.block(pos+Vector3(-1.6,2,0),Vector3(2.5,1.3,2.8),w.palette.hull)
  w.block(pos+Vector3(-2.87,2.05,0),Vector3(.06,.8,2.3),solar,false)
  for side in [-1,1]:
   for axle in [-2,2]:
    var wheel=w.kit.cylinder(w.scene_root,pos+Vector3(axle,.5,side*1.6),.65,.3,w.kit.dark);wheel.rotation.x=PI*.5
   w.block(pos+Vector3(2.95,1,side),Vector3(.07,.2,.3),w.kit.lamp,false)
  stats.props+=1
 var mast=Vector3(28,0,51)
 w.block(mast+Vector3.UP*.6,Vector3(3,1.2,3),w.palette.hull)
 w.kit.cylinder(w.scene_root,mast+Vector3.UP*5,.22,10,copper)
 for h in [3,6,9]:
  w.block(mast+Vector3(0,h,0),Vector3(3,.15,.3),w.kit.dark,false)
  for side in [-1,1]:w.block(mast+Vector3(side*1.5,h,.05),Vector3(.15,.35,.2),w.kit.lamp,false)
 stats.props+=1
 military_district(deck,copper,solar)
 w.set_meta("base_stats",stats)
func building(p: Vector3,material: Material,trim: Material):
 w.block(p+Vector3(0,3,-1),Vector3(17,6,12),material)
 w.block(p+Vector3(0,6.2,-1),Vector3(18,.4,13),w.palette.hull)
 w.block(p+Vector3(0,2.2,5.05),Vector3(7,4.4,.08),w.kit.dark,false)
 for x in [-4.1,4.1]:w.block(p+Vector3(x,2.7,5.15),Vector3(.28,5.4,.16),trim,false)
 for x in [-6.2,6.2]:
  w.block(p+Vector3(x,3.8,5.12),Vector3(2.3,1.2,.08),w.kit.dark,false)
  w.block(p+Vector3(x,3.1,5.2),Vector3(2.3,.1,.12),w.kit.gold,false)
 for x in [-5,0,5]:
  var vent=w.kit.cylinder(w.scene_root,p+Vector3(x,6.7,-1),1,.6,trim)
  w.block(p+Vector3(x,6.95,-1),Vector3(.15,.15,1.6),w.kit.dark,false)
 w.block(p+Vector3(0,.04,9),Vector3(12,.08,6),w.palette.panel)
 for x in [-5,5]:
  w.block(p+Vector3(x,.55,10),Vector3(.35,1.1,.35),trim)
  w.block(p+Vector3(x,1.2,10),Vector3(.45,.15,.45),w.kit.lamp,false)
 stats.buildings+=1

func military_district(deck: Material,trim: Material,glass: Material):
 # Perimeter skyline and service yards leave the tutorial and boarding lanes open.
 for side in [-1,1]:
  for i in range(7):
   var p=Vector3(side*(86+(i%2)*15),0,-65+i*22);var h=16+(i%4)*8
   w.block(p+Vector3.UP*h*.5,Vector3(12,h,15),w.palette.tower_slate,false)
   w.block(p+Vector3.UP*(h+.3),Vector3(13,.6,16),deck,false)
   for floor_index in range(2,int(h/3)):
    for col in [-3,0,3]:w.block(p+Vector3(-side*6.03,floor_index*3, col),Vector3(.08,1.2,1.5),glass,false)
   stats.buildings+=1
  for z in [-64,66]:
   var p=Vector3(side*65,0,z)
   w.block(p+Vector3.UP*5,Vector3(5,1,5),deck)
   for x in [-2,2]:
    for dz in [-2,2]:w.block(p+Vector3(x,2.5,dz),Vector3(.3,5,.3),trim)
   w.block(p+Vector3.UP*7,Vector3(5.8,.25,5.8),w.palette.hull,false)
   for dz in [-2.5,2.5]:w.block(p+Vector3(0,5.8,dz),Vector3(5,.9,.16),deck)
   stats.props+=1
 # Barracks equipment, concrete barriers, fuel drums and evacuation signage.
 for side in [-1,1]:
  for i in range(5):
   var p=Vector3(side*(45+i*4),0,-67)
   w.block(p+Vector3.UP*.55,Vector3(3,1.1,.8),deck)
   for j in [-1,1]:
    var stripe=w.block(p+Vector3(j*.7,.6,.42),Vector3(.35,.8,.04),w.kit.gold,false);stripe.rotation.z=.35
  for i in range(6):
   var p=Vector3(side*(49+i%3*2),0,62+floori(i/3.0)*2)
   w.kit.cylinder(w.scene_root,p+Vector3.UP*.65,.55,1.3,trim,true)
   for y in [.2,1.1]:w.kit.cylinder(w.scene_root,p+Vector3.UP*y,.57,.08,w.kit.dark)
   stats.props+=1
 for x in [-30,27]:
  w.block(Vector3(x,2.5,-42),Vector3(.18,5,.18),trim)
  w.block(Vector3(x,4,-42),Vector3(4,1.5,.18),w.palette.tower_teal,false)
  w.kit.label(w.scene_root,Vector3(x,4,-41.85),"EVAC / PAD 01",w.kit.gold.albedo_color,26)
