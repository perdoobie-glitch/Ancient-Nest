class_name NestGameTypeEditor
extends Window
# Edits a private draft; only the host may apply it, including live traits.
var game
var draft: GameTypeSettings
var controls: Dictionary = {}
var tabs: TabContainer
var apply_button: Button
var notice: Label
var name_edit: LineEdit
var editable: bool=false
var saved_types: OptionButton
var load_button: Button
var save_new_button: Button
var name_dialog: ConfirmationDialog
var saved_name_input: LineEdit
var save_error: Label
var extraction_heading: Label
var trait_scope: String=""
var character_selector: OptionButton
var reset_character: Button
var weapon_controls: Dictionary={}
var category_picker: OptionButton
var search_box: LineEdit
var search_status: Label
var category_list: ItemList
var search_rows: Array[Dictionary]=[]
var preferred_category: int=0
var preset_selection: String=""
var last_query: String=""
var copy_traits: OptionButton
func _ready() -> void:
 if not game.can_edit_match_traits():queue_free();return
 title="Match Settings" if game.running else "Edit Game Type Settings";min_size=Vector2i(820,500);transient=true;exclusive=true
 theme=NestMatchMenuStyle.create(game.screen.get_parent().theme)
 editable=not game.is_client()
 game.sync_legacy_to_game_type();draft=(game.pending_game_type if game.pending_game_type!=null else game.game_type).duplicate_settings()
 var panel=PanelContainer.new();add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var body=VBoxContainer.new();body.add_theme_constant_override("separation",10);panel.add_child(body)
 var heading_row=HBoxContainer.new();body.add_child(heading_row)
 var intro=Label.new();intro.text="ANCIENT NEST · MATCH SETTINGS" if game.running else "EDIT GAME TYPE SETTINGS";intro.add_theme_font_size_override("font_size",23);intro.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading_row.add_child(intro)
 category_picker=OptionButton.new();category_picker.name="SettingsTabPicker";category_picker.custom_minimum_size.x=205;category_picker.visible=false;category_picker.fit_to_longest_item=false;heading_row.add_child(category_picker)
 category_picker.item_selected.connect(func(index):jump_to_category(String(category_picker.get_item_metadata(index))))
 notice=Label.new();notice.text="Guns: 1x body / 2x head before defenses. 100% = standard rules." if editable else "Only the host can edit rules. You can view the current settings here."
 notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(notice)
 var search_row=HBoxContainer.new();body.add_child(search_row)
 search_box=LineEdit.new();search_box.name="MatchSettingsSearch";search_box.placeholder_text="Search rules or game types · damage, bots, gravity…";search_box.clear_button_enabled=true;search_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;search_row.add_child(search_box)
 search_status=Label.new();search_status.add_theme_font_size_override("font_size",12);body.add_child(search_status)
 search_box.text_changed.connect(func(_text):refresh_context();refresh_saved_types())
 var identity=HBoxContainer.new();body.add_child(identity)
 var name_label=Label.new();name_label.text="Game type name";name_label.custom_minimum_size.x=180;identity.add_child(name_label)
 name_edit=LineEdit.new();name_edit.max_length=48;name_edit.text=draft.game_type_name;name_edit.editable=editable;name_edit.size_flags_horizontal=Control.SIZE_EXPAND_FILL;identity.add_child(name_edit)
 name_edit.text_changed.connect(func(value):draft.game_type_name=value)
 var library_row=HBoxContainer.new();library_row.add_theme_constant_override("separation",10);body.add_child(library_row)
 var library_label=Label.new();library_label.text="Start from game type";library_label.custom_minimum_size.x=180;library_row.add_child(library_label)
 saved_types=OptionButton.new();saved_types.name="SavedGameTypes";saved_types.clip_text=true;saved_types.fit_to_longest_item=false;saved_types.custom_minimum_size.x=180;saved_types.size_flags_horizontal=Control.SIZE_EXPAND_FILL;library_row.add_child(saved_types)
 load_button=Button.new();load_button.text="Load";load_button.name="LoadGameType";library_row.add_child(load_button);load_button.pressed.connect(load_selected_preset)
 saved_types.item_selected.connect(func(_index):preset_selection=String(saved_types.get_selected_metadata());load_button.disabled=not editable or saved_types.selected<=0)
 save_new_button=Button.new();save_new_button.text="Save as New Game Type";save_new_button.name="SaveAsNewGameType";library_row.add_child(save_new_button);save_new_button.pressed.connect(open_save_prompt)
 refresh_saved_types()
 var scope_row=HBoxContainer.new();scope_row.add_theme_constant_override("separation",10);body.add_child(scope_row)
 var scope_label=Label.new();scope_label.text="Player traits for";scope_row.add_child(scope_label)
 character_selector=OptionButton.new();character_selector.name="TraitCharacter";character_selector.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scope_row.add_child(character_selector)
 character_selector.add_item("Default (shared)");character_selector.set_item_metadata(0,"")
 copy_traits=OptionButton.new();copy_traits.name="CopyTraitsFrom";copy_traits.add_item("Copy traits from…");copy_traits.add_item("Default");copy_traits.set_item_metadata(1,"")
 for character in NestCharacterCatalog.all():
  character_selector.add_item(character.name);character_selector.set_item_metadata(character_selector.item_count-1,character.id)
  copy_traits.add_item(character.name);copy_traits.set_item_metadata(copy_traits.item_count-1,character.id)
 reset_character=Button.new();reset_character.text="Reset This Character";scope_row.add_child(reset_character);scope_row.add_child(copy_traits)
 character_selector.item_selected.connect(func(index):trait_scope=String(character_selector.get_item_metadata(index));sync_draft_controls())
 reset_character.pressed.connect(reset_character_traits);copy_traits.item_selected.connect(copy_character_traits)
 var workspace=HBoxContainer.new();workspace.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(workspace)
 category_list=ItemList.new();category_list.name="RulesCategories";category_list.add_theme_color_override("font_selected_color",Color("126b32"));category_list.add_theme_stylebox_override("selected",theme.get_stylebox("pressed","Button"));category_list.add_theme_constant_override("v_separation",5);category_list.custom_minimum_size.x=190;category_list.size_flags_vertical=Control.SIZE_EXPAND_FILL;workspace.add_child(category_list)
 category_list.item_selected.connect(func(index):
  var target=int(category_list.get_item_metadata(index));tabs.current_tab=target;preferred_category=target)
 tabs=TabContainer.new();tabs.tabs_visible=false;tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;tabs.size_flags_horizontal=Control.SIZE_EXPAND_FILL;workspace.add_child(tabs)
 var categories={}
 for definition in GameTypeSettings.definitions():
  if definition.key in ["sniper_instant_headshots","annu_precision_ignores_helmet"]:continue
  var category=String(definition.category)
  if not categories.has(category):
   var scroll=ScrollContainer.new();scroll.name=category.replace(" / "," & ");scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;tabs.add_child(scroll)
   var content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",10);scroll.add_child(content);categories[category]=content
  if definition.has("section"):
   var heading=Label.new();heading.text=String(definition.section).to_upper();heading.add_theme_font_size_override("font_size",13);heading.add_theme_color_override("font_color",Color("896617"));categories[category].add_child(heading);heading.set_meta("setting_key",String(definition.key))
   if definition.key=="bag_stock":extraction_heading=heading
  add_setting(categories[category],definition)
 for category in {"Annu Health":["annu_body_health","annu_head_health","annu_body_armor","annu_head_armor"],"Naki Shields":["shields_enabled","naki_shield_capacity","naki_body_shield_strength","naki_head_shield_strength"]}:
  var order=["annu_body_health","annu_head_health","annu_body_armor","annu_head_armor"] if category=="Annu Health" else ["shields_enabled","naki_shield_capacity","naki_body_shield_strength","naki_head_shield_strength"]
  for index in range(order.size()):categories[category].move_child(controls[order[index]].get_parent(),index)
 if not categories.has("Weapon Damage"):
  var damage_scroll=ScrollContainer.new();damage_scroll.name="Weapon Damage";damage_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;tabs.add_child(damage_scroll)
  var damage_content=VBoxContainer.new();damage_content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;damage_content.add_theme_constant_override("separation",10);damage_scroll.add_child(damage_content);categories["Weapon Damage"]=damage_content
 add_weapon_damage_controls(categories["Weapon Damage"])
 for category in ["Annu Health","Naki Shields"]:
  var explanation=Label.new();explanation.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  explanation.text="Shared Annu health rules. Body health is the common pool; head health adjusts its headshot durability. Gun hits use 1x body / 2x head before these explicit defense traits." if category=="Annu Health" else "One regenerating shield pool. Body/head strength divide incoming gun damage, including Naki Shield pickups. Capacity and strength traits multiply; recharge timing stays configurable below."
  categories[category].add_child(explanation);categories[category].move_child(explanation,0)
 var category_order=["Match","Map","Bots","Player","Movement","Annu Health","Naki Shields","Weapons","Weapon Damage","Combat","Radar"]
 for index in range(category_order.size()):
  var page=tabs.get_node_or_null(category_order[index])
  if page!=null:tabs.move_child(page,index)
 for index in range(tabs.get_tab_count()):category_picker.add_item(tabs.get_tab_title(index));category_picker.set_item_metadata(index,tabs.get_tab_title(index))
 tabs.tab_changed.connect(func(index):category_picker.select(index);select_category_row(index))
 var footer=HBoxContainer.new();footer.add_theme_constant_override("separation",12);body.add_child(footer)
 var reset=Button.new();reset.text="Restore Defaults";reset.disabled=not editable;footer.add_child(reset);reset.pressed.connect(restore_defaults)
 var space=Control.new();space.size_flags_horizontal=Control.SIZE_EXPAND_FILL;footer.add_child(space)
 var cancel=Button.new();cancel.text="Cancel" if editable else "Close";footer.add_child(cancel);cancel.pressed.connect(close_editor)
 apply_button=Button.new();apply_button.text="Save Pending Changes" if game.running else "Apply & Save";apply_button.disabled=not editable;footer.add_child(apply_button);apply_button.pressed.connect(apply_changes)
 if game.running:
  var restart=Button.new();restart.name="ApplyMatchRestart";restart.text="Apply & Restart Round";restart.disabled=not editable;footer.add_child(restart)
  restart.pressed.connect(apply_and_restart)
 controls.mode.item_selected.connect(func(_index):refresh_context())
 sync_draft_controls()
 close_requested.connect(close_editor)
func add_setting(parent: Control, definition: Dictionary) -> void:
 var line=HBoxContainer.new();line.add_theme_constant_override("separation",18);parent.add_child(line)
 var text=Label.new();text.text=definition.label;text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;text.tooltip_text=definition.get("description","");line.add_child(text)
 var key=String(definition.key)
 var control: Control
 if definition.type=="bool":
  var toggle=CheckButton.new();toggle.button_pressed=bool(draft.get(key));toggle.disabled=not editable;toggle.toggled.connect(func(value):set_draft_value(key,value));control=toggle
 elif definition.type in ["choice","weapon"]:
  var choice=OptionButton.new();choice.disabled=not editable
  if definition.type=="weapon":
   choice.add_item("Faction default");choice.set_item_metadata(0,"default");choice.add_item("None");choice.set_item_metadata(1,"none")
   for weapon in NestWeaponCatalog.choices("primary" if key=="starting_primary" else "secondary"):
    choice.add_item(weapon.title);choice.set_item_metadata(choice.item_count-1,weapon.id)
   for i in range(choice.item_count):
    if choice.get_item_metadata(i)==draft.get(key):choice.select(i)
   choice.item_selected.connect(func(index):set_draft_value(key,choice.get_item_metadata(index)))
  else:
   for option in definition.options:choice.add_item(option)
   choice.select(int(draft.get(key)));choice.item_selected.connect(func(index):set_draft_value(key,index))
  control=choice
 else:
  var number=SpinBox.new();number.min_value=definition.min;number.max_value=definition.max;number.step=definition.step;number.value=float(draft.get(key));number.suffix=definition.get("unit","");number.editable=editable
  number.value_changed.connect(func(value):set_draft_value(key,int(round(value)) if typeof(draft.get(key))==TYPE_INT else value));control=number
 search_rows.append({"row":line,"key":key,"category":String(definition.category),"terms":String(definition.label)+" "+key.replace("_"," ")+" "+String(definition.get("description",""))+" "+str(definition.get("options",[]))})
 control.name=key;control.custom_minimum_size=Vector2(235,36);control.tooltip_text=definition.get("description","");line.add_child(control);controls[key]=control
func sync_draft_controls() -> void:
 name_edit.text=draft.game_type_name
 for definition in GameTypeSettings.definitions():
  if not controls.has(definition.key):continue
  var control=controls[definition.key];var value=get_draft_value(String(definition.key))
  var can_edit=editable and (trait_scope.is_empty() or NestCharacterTraits.is_trait(String(definition.key)))
  if control is SpinBox:control.editable=can_edit
  else:control.disabled=not can_edit
  if control is SpinBox:
   if definition.key=="time_limit_seconds":control.max_value=120 if draft.mode==4 else 3600
   control.set_value_no_signal(float(value))
  elif control is CheckButton:control.set_pressed_no_signal(bool(value))
  elif definition.type=="weapon":
   for i in range(control.item_count):
    if control.get_item_metadata(i)==value:control.select(i)
  elif control is OptionButton:control.select(int(value))
 for index in range(tabs.get_tab_count()):
  tabs.set_tab_hidden(index,not trait_scope.is_empty() and tabs.get_tab_title(index) in ["Match","Map","Radar","Bots","Weapon Damage"])
 if tabs.is_tab_hidden(tabs.current_tab):
  for index in range(tabs.get_tab_count()):
   if not tabs.is_tab_hidden(index):tabs.current_tab=index;break
 for key in controls:controls[key].get_parent().visible=trait_scope.is_empty() or NestCharacterTraits.is_trait(key)
 for kind in weapon_controls:weapon_controls[kind].set_value_no_signal(float(draft.weapon_damage_percent.get(kind,100.0)))
 category_picker.select(tabs.current_tab)
 refresh_scope_labels();refresh_context()
func refresh_context() -> void:
 # Rebuild applicability first; searching must never reveal an inapplicable trait.
 for key in controls:controls[key].get_parent().visible=trait_scope.is_empty() or NestCharacterTraits.is_trait(key)
 # Extraction-only settings stay out of other modes without discarding values.
 controls.cs_defuse_kits.get_parent().visible=draft.mode==4 and trait_scope.is_empty()
 controls.bag_stock.get_parent().visible=draft.mode==0 and trait_scope.is_empty()
 extraction_heading.visible=draft.mode==0 and trait_scope.is_empty()
 var health=int(get_draft_value("health_type"))
 var model="both" if health==0 and trait_scope.is_empty() else (String(NestCharacterCatalog.by_id(trait_scope).get("damage_model","naki")) if health==0 else "naki" if health==1 else "annu")
 for key in ["shields_enabled","shield_strength_percent","shield_recharge_delay","shield_recharge_rate_percent"]:controls[key].get_parent().visible=model in ["naki","both"]
 for key in ["armor_strength_percent","helmet_strength_percent","armor_absorption_percent","helmet_absorption_percent"]:controls[key].get_parent().visible=model in ["annu","both"]
 controls.max_health_percent.get_parent().get_child(0).text=("Maximum health" if model=="both" else model.capitalize()+" health")
 controls.damage_resistance_percent.get_parent().get_child(0).text=("Damage resistance" if model=="both" else model.capitalize()+" damage resistance")
 controls.respawn_seconds.get_parent().visible=draft.mode!=4
 controls.time_limit_seconds.max_value=120 if draft.mode==4 else 3600
 controls.time_limit_seconds.get_parent().get_child(0).text="Round time (max 2 minutes)" if draft.mode==4 else "Time limit"
 for heading in tabs.find_children("*","Label",true,false):
  if heading.has_meta("setting_key"):heading.visible=controls[String(heading.get_meta("setting_key"))].get_parent().visible
 for key in controls:
  controls[key].get_parent().visible=controls[key].get_parent().visible and (trait_scope.is_empty() or NestCharacterTraits.is_trait(key))
 apply_search()
func restore_defaults() -> void:
 if not editable:return
 draft=GameTypeSettings.new();sync_draft_controls()
func commit_numbers() -> void:
 for control in controls.values()+weapon_controls.values():
  if control is SpinBox and control.get_line_edit().has_focus():control.apply()
 draft.validate()
func refresh_saved_types(selected_id: String="") -> void:
 if not selected_id.is_empty():preset_selection=selected_id
 saved_types.clear();saved_types.add_item("Choose a template or saved type");saved_types.set_item_metadata(0,"")
 var query=search_box.text if is_instance_valid(search_box) else ""
 for entry in NestGameTypeLibrary.templates()+NestGameTypeLibrary.list_saved():
  if not NestMenuSearch.matches(query,String(entry.name)+" game type template saved preset"):continue
  saved_types.add_item(entry.name);var index=saved_types.item_count-1;saved_types.set_item_metadata(index,entry.id)
  if entry.id==preset_selection:saved_types.select(index)
 load_button.disabled=not editable or saved_types.selected<=0
func open_save_prompt() -> void:
 commit_numbers()
 if not is_instance_valid(name_dialog):
  name_dialog=ConfirmationDialog.new();name_dialog.title="Save as New Game Type";name_dialog.dialog_hide_on_ok=false;name_dialog.get_ok_button().text="Save New Game Type";add_child(name_dialog)
  var form=VBoxContainer.new();form.add_theme_constant_override("separation",12);name_dialog.add_child(form)
  var instructions=Label.new();instructions.text="Name this game type to keep a separate copy.\nSaving a copy does not change the current match rules.";form.add_child(instructions)
  saved_name_input=LineEdit.new();saved_name_input.name="NewGameTypeName";saved_name_input.max_length=48;form.add_child(saved_name_input)
  save_error=Label.new();save_error.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;save_error.custom_minimum_size.x=440;save_error.add_theme_color_override("font_color",Color("a52929"));form.add_child(save_error)
  name_dialog.confirmed.connect(save_named_preset);saved_name_input.text_submitted.connect(func(_value):save_named_preset())
 save_error.text="";saved_name_input.text=draft.game_type_name;name_dialog.popup_centered(Vector2i(530,220));saved_name_input.grab_focus();saved_name_input.select_all()
func save_named_preset() -> void:
 var result=NestGameTypeLibrary.save_new(draft,saved_name_input.text)
 if not result.ok:save_error.text=result.message;return
 if editable:draft.game_type_name=result.name;name_edit.text=result.name
 refresh_saved_types(result.id);notice.text='Saved "%s". Load it here any time; Apply & Save selects these rules.'%result.name if editable else 'Saved a local copy of "%s". The host rules stay active.'%result.name
 name_dialog.hide()
func load_selected_preset() -> void:
 if not editable or saved_types.selected<=0:return
 var loaded=NestGameTypeLibrary.load_type(String(saved_types.get_selected_metadata()))
 if loaded==null:notice.text="This saved game type couldn't be loaded.";refresh_saved_types();return
 draft=loaded;sync_draft_controls();notice.text='Loaded "%s" into the editor. Save the draft to use these rules.'%draft.game_type_name
func dismiss_back() -> void:
 if not search_box.text.is_empty() and not (is_instance_valid(name_dialog) and name_dialog.visible):search_box.clear();refresh_context();refresh_saved_types();return
 if is_instance_valid(name_dialog) and name_dialog.visible:name_dialog.hide()
 else:close_editor()
func apply_changes() -> void:
 if not game.can_edit_match_traits():close_editor();return
 # SpinBox commits a typed value when focus leaves its LineEdit; commit explicitly
 # before reading the draft so the last edited number is never silently lost.
 commit_numbers()
 if not game.apply_game_type_settings(draft):notice.text="Only the host can apply rules.";return
 hide();game.call_deferred("show_pause" if game.running else "show_lobby");queue_free()
func close_editor() -> void:
 hide();game.call_deferred("show_pause" if game.running else "show_lobby");queue_free()
func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and event.keycode==KEY_F and (event.ctrl_pressed or event.meta_pressed):
  search_box.grab_focus();search_box.select_all();get_viewport().set_input_as_handled()
 elif event.is_action_pressed("ui_cancel"):
  dismiss_back();get_viewport().set_input_as_handled()

func get_draft_value(key: String):
 return NestCharacterTraits.value(draft,trait_scope,key) if not trait_scope.is_empty() and NestCharacterTraits.is_trait(key) else draft.get(key)
func set_draft_value(key: String, value) -> void:
 if not editable:return
 if trait_scope.is_empty():
  draft.set(key,value)
  if key in ["bots_team_0","bots_team_1"] and int(value)!=0:
   draft.bots_fill_empty_slots=true;controls.bots_fill_empty_slots.set_pressed_no_signal(true)
  if key=="mode" and int(value)==4:
   draft.time_limit_seconds=120;draft.plant_seconds=3.2;draft.defuse_seconds=10;draft.bomb_timer_seconds=40;draft.lives_per_round=1;draft.score_to_win=11;draft.rounds=21
   sync_draft_controls()
 elif NestCharacterTraits.is_trait(key):
  var overrides: Dictionary=draft.character_traits.get(trait_scope,{})
  var baseline=draft.duplicate_settings();baseline.character_traits.erase(trait_scope)
  if value==NestCharacterTraits.value(baseline,trait_scope,key):overrides.erase(key)
  else:overrides[key]=value
  if overrides.is_empty():draft.character_traits.erase(trait_scope)
  else:draft.character_traits[trait_scope]=overrides
 refresh_scope_labels();refresh_context()
func refresh_scope_labels() -> void:
 reset_character.disabled=not editable or trait_scope.is_empty();copy_traits.disabled=not editable or trait_scope.is_empty()
 for index in range(1,character_selector.item_count):
  var id=String(character_selector.get_item_metadata(index));var character=NestCharacterCatalog.by_id(id)
  character_selector.set_item_text(index,character.name+(" · Edited" if not draft.character_traits.get(id,{}).is_empty() else ""))
 notice.text=("Host only · View character traits and save a local copy." if not editable else "Guns: 1x body / 2x head before defenses. Select a character for individual traits." if trait_scope.is_empty() else "Editing "+String(NestCharacterCatalog.by_id(trait_scope).name)+" only. Match rules stay shared. Apply & Save commits the draft.")
 if game.running and editable:notice.text="Save queues your changes. Player traits and loadouts apply on respawn; Restart Round applies all rules, teams and bot settings. Match score is kept."
func reset_character_traits() -> void:
 if not editable or trait_scope.is_empty():return
 draft.character_traits.erase(trait_scope);sync_draft_controls()
func copy_character_traits(index: int) -> void:
 if not editable or trait_scope.is_empty() or index<=0:return
 var source=String(copy_traits.get_item_metadata(index));var values={}
 for definition in GameTypeSettings.definitions():
  var key=String(definition.key)
  if NestCharacterTraits.is_trait(key):values[key]=draft.get(key) if source.is_empty() else NestCharacterTraits.value(draft,source,key)
 draft.character_traits[trait_scope]=values;draft.validate();copy_traits.select(0);sync_draft_controls()

func jump_to_category(category: String) -> void:
 search_box.clear();refresh_context();refresh_saved_types()
 if category in ["Match","Map","Bots","Radar","Annu Health","Naki Shields","Weapon Damage"] and not trait_scope.is_empty():
  trait_scope="";character_selector.select(0);sync_draft_controls()
 for index in range(tabs.get_tab_count()):
  if tabs.get_tab_title(index)==category:tabs.current_tab=index;preferred_category=index;return
func add_weapon_damage_controls(parent: Control) -> void:
 var help=Label.new();help.text="Each weapon has its own damage scale: 100% keeps the current balance, 50% halves damage, 200% doubles it. Applies to bullets, plasma, rocket direct hits, rocket explosions and grenades; sniper and exposed-Naki headshot finishers still apply (the sniper toggle can disable its finisher). Changes take effect at round reset. Values below are before faction protection and falloff.";help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(help);parent.move_child(help,0)
 for weapon in NestWeaponCatalog.data().weapons:
  if weapon.get("slot","") not in ["primary","secondary","grenade"]:continue
  var kind=String(weapon.kind);var config=NestWeaponCatalog.for_kind(kind)
  var row=HBoxContainer.new();row.add_theme_constant_override("separation",12);parent.add_child(row)
  var label=Label.new();label.text=String(weapon.title);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(label)
  var number=SpinBox.new();number.name="WeaponDamage_"+kind;number.min_value=0;number.max_value=1000;number.step=5;number.suffix="%";number.custom_minimum_size=Vector2(170,36);number.editable=editable;row.add_child(number);weapon_controls[kind]=number
  number.value_changed.connect(func(value):
   if not editable:return
   if is_equal_approx(value,100):draft.weapon_damage_percent.erase(kind)
   else:draft.weapon_damage_percent[kind]=value)
  var detail=Label.new();detail.add_theme_font_size_override("font_size",12)
  detail.text=("Base direct %.1f · splash %.1f"%[float(config.get("damage_direct",0)),float(config.get("splash_damage_max",config.get("damage_explosion",0)))]) if config.get("explosive",false) or config.get("slot","")=="grenade" else ("Body %.2f · head %.2f · before defenses"%[float(config.get("damage_body",0)),float(config.get("damage_body",0))*2.0])
  parent.add_child(detail)
  search_rows.append({"row":row,"detail":detail,"key":"","category":"Weapon Damage","terms":String(weapon.title)+" "+kind+" damage bullet plasma grenade rocket"})

func select_category_row(index: int) -> void:
 if not is_instance_valid(category_list):return
 for row in range(category_list.item_count):
  if int(category_list.get_item_metadata(row))==index:category_list.select(row);return
func apply_search() -> void:
 if not is_instance_valid(search_box) or not is_instance_valid(category_list):return
 var query=search_box.text.strip_edges()
 var counts={};var total=0;var best_category="";var best_score=-1
 for entry in search_rows:
  var applicable=entry.row.visible if not String(entry.key).is_empty() else trait_scope.is_empty()
  var shown=applicable and NestMenuSearch.matches(query,String(entry.category)+" "+String(entry.terms))
  entry.row.visible=shown
  if entry.has("detail"):entry.detail.visible=shown
  if shown:
   counts[entry.category]=int(counts.get(entry.category,0))+1;total+=1
   var score=4 if NestMenuSearch.normalized(String(entry.terms)).begins_with(NestMenuSearch.normalized(query)) else 2 if NestMenuSearch.matches(query,String(entry.category)) else 0
   if score>best_score:best_score=score;best_category=String(entry.category)
 category_list.clear()
 var first=-1
 for index in range(tabs.get_tab_count()):
  var category=tabs.get_tab_title(index)
  var count=int(counts.get(category,0))
  tabs.set_tab_hidden(index,count==0)
  if count==0:continue
  if first<0:first=index
  category_list.add_item(category+("  · %d"%count if not query.is_empty() else ""));category_list.set_item_metadata(category_list.item_count-1,index)
  # Explanatory blocks stay out of filtered results; section titles follow their row.
  var content=tabs.get_tab_control(index).get_child(0)
  for child in content.get_children():
   if child is Label:child.visible=query.is_empty() if not child.has_meta("setting_key") else controls[String(child.get_meta("setting_key"))].get_parent().visible
 if first>=0:
  var target=preferred_category if query.is_empty() and not tabs.is_tab_hidden(preferred_category) else tabs.current_tab
  if not query.is_empty() and query!=last_query:
   for index in range(tabs.get_tab_count()):
    if tabs.get_tab_title(index)==best_category:target=index;break
  if target<0 or tabs.is_tab_hidden(target):target=first
  tabs.current_tab=target;select_category_row(target)
 last_query=query
 tabs.visible=first>=0
 search_status.text=("%d matching rules · choose a category on the left. Templates and saved types are filtered above too."%total if total>0 else "No matching rules. Check the game type list above, try another term, or clear search.") if not query.is_empty() else "Choose a category on the left. Search covers every applicable category and saved game type."

func apply_and_restart() -> void:
 if not editable or not game.running:return
 commit_numbers()
 if not game.apply_game_type_settings(draft):return
 if not game.restart_round_in_match():notice.text="Restart unavailable; changes remain pending.";return
 hide();queue_free()
