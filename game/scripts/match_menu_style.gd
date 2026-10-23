class_name NestMatchMenuStyle
extends RefCounted
static func create(base: Theme) -> Theme:
 var theme=base.duplicate() as Theme if base!=null else Theme.new()
 theme.default_font=load("res://assets/body.ttf");theme.default_font_size=15
 var gold=Color("d9bd80")
 var panel=NestMenuSurface.surface();panel.set_content_margin_all(14)
 theme.set_stylebox("panel","PanelContainer",panel)
 theme.set_stylebox("panel","TabContainer",panel)
 for state in ["normal","hover","pressed","focus","disabled"]:
  var style=NestMenuSurface.surface(true,state in ["hover","pressed"]);style.content_margin_left=12;style.content_margin_right=12;style.content_margin_top=7;style.content_margin_bottom=7
  theme.set_stylebox(state,"Button",style)
 theme.set_color("font_color","Label",Color("e6ede7"))
 for type in ["Button","OptionButton","CheckButton","TabContainer"]:theme.set_color("font_color",type,Color("126b32"))
 theme.set_color("font_selected_color","TabContainer",gold)
 return theme
