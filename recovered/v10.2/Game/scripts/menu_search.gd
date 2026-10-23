class_name NestMenuSearch
extends RefCounted
# Search presentation only: never recreate controls or mutate their draft values.
static func normalized(value: String) -> String:
 return value.to_lower().replace("armour","armor").replace("health points","health").replace("game type","gametype").replace("gametypes","gametype").replace("bots","bot").replace("shields","shield").replace("weapons","weapon").replace("settings","setting").replace("minimap","radar")
static func matches(query: String, value: String) -> bool:
 var haystack=normalized(value)
 for token in normalized(query).split(" ",false):
  if not haystack.contains(token):return false
 return true
static func content(node: Node) -> String:
 var result=String(node.get_meta("search_terms",""))
 if node is Label or node is BaseButton:result+=" "+node.text
 if node is OptionButton:
  for index in range(node.item_count):result+=" "+node.get_item_text(index)
 for child in node.get_children():result+=" "+content(child)
 return result
static func filter_group(group: Control, query: String, category: String) -> int:
 var count=0
 for child in group.get_children():
  if not child is Control:continue
  if child is GridContainer:
   var grid_count=filter_group(child,query,category)
   child.visible=grid_count>0;count+=grid_count
  else:
   child.visible=matches(query,category+" "+content(child))
   if child.visible:count+=1
 return count
