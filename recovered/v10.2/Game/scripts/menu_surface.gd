class_name NestMenuSurface
extends RefCounted
# Small cached textures: static gradients, no full-screen shader or per-frame noise.
static var textures: Dictionary={}
static func surface(light: bool=false,active: bool=false) -> StyleBoxTexture:
 var key=str([light,active])
 if not textures.has(key):
  var image=Image.create(128,128,false,Image.FORMAT_RGBA8)
  var top=Color("f2f0e9") if light else Color("42494b")
  var bottom=Color("aeb6b5") if light else Color("171f23")
  var border=Color("59d99b") if active else Color("bca16a")
  for y in range(128):
   for x in range(128):
    var color=top.lerp(bottom,float(y)/127.)
    if x==0 or y==0 or x==127 or y==127:color=border
    image.set_pixel(x,y,color)
  textures[key]=ImageTexture.create_from_image(image)
 var box=StyleBoxTexture.new();box.texture=textures[key]
 box.set_texture_margin_all(1);box.set_content_margin_all(16)
 return box
static func backdrop() -> GradientTexture2D:
 var gradient=Gradient.new();gradient.colors=PackedColorArray([Color(.06,.09,.11,.35),Color(.12,.16,.18,.88),Color(.03,.06,.08,.98)]);gradient.offsets=PackedFloat32Array([0.,.55,1.])
 var texture=GradientTexture2D.new();texture.gradient=gradient;texture.width=8;texture.height=256;texture.fill_from=Vector2(.5,0);texture.fill_to=Vector2(.5,1)
 return texture
static func artwork() -> AtlasTexture:
 var texture=load("res://assets/menu_sanctuary.jpg") as Texture2D
 var atlas=AtlasTexture.new();atlas.atlas=texture
 # Exclude the old baked-in navigation strip; navigation is live UI.
 atlas.region=Rect2(0,0,texture.get_width(),texture.get_height()*.73)
 return atlas

# Main-menu-only pearl finish; generated once and reused across controls.
static func glossy_white(active: bool=false,pressed: bool=false) -> StyleBoxTexture:
 var key="main_gloss_"+str(active)+str(pressed)
 if not textures.has(key):
  var image=Image.create(128,128,false,Image.FORMAT_RGBA8)
  var border=Color("f4cf32") if active else Color("d9b323")
  for y in range(128):
   for x in range(128):
    var height=float(y)/127.
    var base=Color("f7fcf9") if height<.48 else Color("eef8f1").lerp(Color.WHITE,(height-.48)/.52)
    var shine=pow(maxf(0.,1.-absf(float(x)*.18+float(y)-30.)/28.),2.)*.30
    var color=base.lerp(Color.WHITE,shine)
    if active:color=color.lerp(Color("d9ffe9"),.12 if not pressed else .24)
    if x<2 or y<2 or x>125 or y>125:color=border
    image.set_pixel(x,y,color)
  textures[key]=ImageTexture.create_from_image(image)
 var box=StyleBoxTexture.new();box.texture=textures[key]
 box.set_texture_margin_all(2);box.set_content_margin_all(16)
 return box
static func plasma_lettering(control:Control,size:int=0)->void:
 control.add_theme_color_override("font_color",Color("008b3e"))
 control.add_theme_color_override("font_hover_color",Color("007c35"))
 control.add_theme_color_override("font_focus_color",Color("007c35"))
 control.add_theme_color_override("font_pressed_color",Color("006f2f"))
 control.add_theme_color_override("font_outline_color",Color("f1c827"))
 control.add_theme_constant_override("outline_size",1)
 if size>0:control.add_theme_font_size_override("font_size",size)
static func main_button(control:Button)->void:
 plasma_lettering(control,19)
 for state in ["normal","hover","pressed","focus","disabled"]:
  control.add_theme_stylebox_override(state,glossy_white(state in ["hover","pressed","focus"],state=="pressed"))
