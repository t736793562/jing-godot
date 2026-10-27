extends "res://scripts/layout_view.gd"
# Native interactive migration. Only connected routes are exposed as playable.
const SaveStore=preload("res://scripts/native_continuation_store.gd")
const Continuation=preload("res://scripts/native_continuation.gd")
var continuation=Continuation.new()
var focus_choice_page:=0
var animal_tab: String="poultry"
var night_choice_page:=0
var save_store=SaveStore.new()
var save_path: String="user://jing-native-v1.json"
var save_return_screen: String="menu"
var save_text: String=""
var save_preview: Dictionary={}
var save_notice: String=""
var save_editor: TextEdit
const Model=preload("res://scripts/game_model.gd")
var model=Model.new()
var screen: String="menu"
var selected_item: String="rice5"
var pool_row:=0
var transition_pending:=false
var controls: Dictionary={}
var menu_contract: Dictionary
var skin: Dictionary
var night_stage: String="reading"
var morning_tab: String="city"
var focus_target: String=""
var primary_button_states: Dictionary={}
var primary_bindings: Array=[]
var city_chronicle: Array=[]
var reading_font_size:=19
var focused_reading:=false
var settings_path: String="user://reading_settings.cfg"
var settings_return_screen: String="menu"
var settings_focus_control: String="reading_font_18"
var settings_focus_layer
var reading_preferences_error: String=""
func _ready() -> void:
	_save_ux_parent_0__ready();get_tree().auto_accept_quit=false;autosave_expected_sha=save_store.file_fingerprint(save_path);autosave_seen=state_stamp();autosave_ready=true

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE and screen in ["autoSaveFailure","confirmQuit","confirmNewGame"]:screen=close_return_screen if screen=="confirmQuit" else autosave_return_screen;render_screen();get_viewport().set_input_as_handled();return
	_save_ux_parent_0__unhandled_key_input(event)

func native_text(text: String,box: Rect2,font_size:=24) -> Label:
	var label:=Label.new();label.text=text;label.position=box.position;label.size=box.size
	label.add_theme_font_override("font",fonts[FONT_REG+"#2"])
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("372b21"))
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	holder.add_child(label);return label
func hit(id: String,box: Rect2,callback: Callable,title: String="") -> Button:
	var button:=Button.new();button.name=id;button.position=box.position;button.size=box.size
	button.tooltip_text=title;button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for style in ["normal","hover","pressed","disabled"]:button.add_theme_stylebox_override(style,StyleBoxEmpty.new())
	var focus:=StyleBoxFlat.new();focus.bg_color=Color(0,0,0,0);focus.border_color=Color("bc945c");focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus",focus)
	button.pressed.connect(func():
		if transition_pending:return
		transition_pending=true
		callback.call()
		call_deferred("render_screen"))
	holder.add_child(button);controls[id]=button;bind_primary_appearance(button,box);return button
func use_layout(id: String,remove: Array=[]) -> bool:
	for layout in layouts:
		if layout.id==id:
			var copy: Dictionary=layout.duplicate(true);var ops: Array=[]
			for i in range(copy.operations.size()):
				if i in remove:continue
				var operation: Dictionary=copy.operations[i]
				var people_ids: Dictionary={"luo":"罗瑾","mother":"母亲","grandfather":"外祖父","uncle":"安仁叔叔"}
				if not model.state.is_empty() and people_ids.has(operation.get("id")) and not model.present(people_ids[operation.id]):continue
				if focused_reading and screen not in ["settings","menu","save"] and operation.get("type")=="image":
					var box: Array=operation.get("box",[])
					if operation.get("id")=="room" or people_ids.has(operation.get("id")) or (box.size()==4 and box[0]==0 and box[1]==0 and box[2]==copy.canvas[0] and box[3]==copy.canvas[1]):operation.opacity=operation.get("opacity",1.0)*0.32
				ops.append(operation)
			copy.operations=ops;return present_layout(copy)
	load_errors.append("missing route layout: "+id);return false
func image_node(path: String,box: Rect2) -> TextureRect:
	if not textures.has(path):textures[path]=load(path)
	var image:=TextureRect.new();image.texture=textures[path];image.position=box.position;image.size=box.size
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_SCALE;image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	holder.add_child(image);return image
func action(name: String,value: String="",person: String="") -> void:
	model.dispatch(name,value,person);screen=model.state.phase
func render_screen() -> void:
	if screen!="pigeonPlan":_pigeon_ui_parent_0_render_screen();return
	controls.clear();primary_bindings.clear();transition_pending=false;render_night_plan()
	for button in controls.values():button.disabled=true
	var shade:=ColorRect.new();shade.color=Color(0,0,0,0.68);shade.size=Vector2(1920,1080);shade.mouse_filter=Control.MOUSE_FILTER_STOP;holder.add_child(shade)
	var request=model.pigeon_request();var note: bool=bird_note_available();var editable: bool=model.night_plan_editable();var action: String=str(model.state.night.get("pigeonAction","none"));var feed: bool=model.state.night.feedPoultry
	var offset:=Vector2(590,310)-Vector2(760 if note else 10,10)
	var indexes: Array=[5,6,7,8,9,24,26,27,28,29,30,31,32,33,35,36,37,38] if note else [0,1,2,3,4,10,12,13,15,16,17,18,19,20,21,22,23,34]
	if note:
		if action=="collect":indexes.append_array([25,43])
	else:
		if feed:indexes.append_array([11,41])
		if action=="send":indexes.append_array([14,42])
	var ops: Array=[]
	for index in indexes:
		var op: Dictionary=op_from("UI17_supplementary",index).duplicate(true)
		if index==12:op.text=("已准备" if feed else "准备")+"米粮给信鸽"
		if index==19:op.text="米粮 ×1 备5夜；当晚先喂再判。"
		if index==28:op.text="约定截止第"+str(int(request.get("pickupDeadline",0))+1)+"日；当前第"+str(int(model.state.day)+1)+"日。"
		if index==30:op.text=("● " if action=="delay" else "")+"暂不安排取物"
		if index==31:op.text="只取消今晚预选，不清除取物纸条。"
		if index==23:op.text="已选放飞，确认夜晚后执行。" if action=="send" else "预选不等于已经放飞。"
		if op.get("type")=="image" and not textures.has(op.path):textures[op.path]=load(op.path)
		ops.append(op)
	var layer=Layer.new();layer.current={"canvas":[1500,466],"operations":ops};layer.position=offset;layer.size=Vector2(1500,466);layer.textures=textures;layer.fonts=fonts;layer.mouse_filter=Control.MOUSE_FILTER_IGNORE;holder.add_child(layer)
	if note:
		bird_option("collect",Rect2(1080,94,390,115),offset,editable and model.pigeon_action_allowed("collect"))
		bird_option("delay",Rect2(1080,208,390,45),offset,editable and model.pigeon_action_allowed("delay"))
		bird_option("none",Rect2(1090,321,365,59),offset,editable)
	else:
		var b:=hit("pigeon_feed",Rect2(Vector2(330,94)+offset,Vector2(390,96)),func():native_feed_animal("poultry"),"只预选喂养；结算时才扣粮")
		b.disabled=not editable or not(feed or model.feed_plan_status("poultry").valid)
		bird_option("send",Rect2(330,196,390,105),offset,editable and model.pigeon_action_allowed("send"))
		bird_option("none",Rect2(330,302,390,50),offset,editable)
	var status: Dictionary=model.pigeon_plan_status();var reason: String=status.reason if not status.valid else "按夜间实际条件开放；不保证得到送物。"
	if not editable:reason="今晚已经确认，不能修改原安排。"
	elif not note and not model.pigeon_action_allowed("send"):
		reason="当前不能放飞，可取消原安排后返回。"
	prose(reason,Rect2(595,745,725,65),20)
	native_text("返回夜间安排",Rect2(820,820,280,42),23);hit("pigeon_back",Rect2(800,812,320,58),func():screen="night","返回，保留预选")
	observe_autosave()

func begin_game(seed: String="") -> void:
	if autosave_enabled and FileAccess.file_exists(save_path):
		new_game_seed=seed;new_game_expected_sha=save_store.file_fingerprint(save_path);new_game_notice="已有磁盘记录会先另存备份，再开始新记录。当前未保存进度将被替换。";autosave_return_screen=screen;screen="confirmNewGame";return
	start_new_game_now(seed)

func render_menu() -> void:
	_aux_parent_3_render_menu();reconnect_button("menu_5",func():open_native_feedback())

func render_intro() -> void:
	var remove: Array=[6,7]
	for i in range(17,28):remove.append(i)
	use_layout("UI02_05_02_normal",remove)
	var text:=RichTextLabel.new();text.position=Vector2(752,338);text.size=Vector2(640,381);text.bbcode_enabled=false
	text.add_theme_font_override("normal_font",fonts[FONT_REG+"#2"]);text.add_theme_font_size_override("normal_font_size",reading_font_size)
	text.add_theme_color_override("default_color",Color("372b21"));text.add_theme_constant_override("line_separation",5)
	var paras: Array=[]
	for n in ["01","02","03","04","05"]:paras.append(model.opening_copy("pro."+n))
	text.text="\n\n".join(paras);holder.add_child(text)
	hit("intro_next",Rect2(916,773,326,67),func():action("introNext"),"跟上家人")
	hit("menu",Rect2(1315,155,104,55),func():screen="menu","返回主菜单")
func render_tutorial() -> void:
	var page:=int(model.state.tutorialPage)+1
	use_layout("SVG_jing_ui03_reconstruction_20261024_UI03_page"+str(page)+"_reconstruction")
	if page==1:
		hit("tutorial_skip",Rect2(1037,810,263,95),func():action("tutorialSkip"),"直接挑选物资")
		hit("tutorial_next",Rect2(1306,799,261,89),func():action("tutorialNext"),"下一页")
	else:
		hit("tutorial_back",Rect2(504,810,190,60),func():action("tutorialBack"),"上一页")
		hit("tutorial_next",Rect2(1234,769,322,92),func():action("tutorialNext"),"去挑选物资")
func render_loadout() -> void:
	var remove: Array=[9,15,22,28,11,12,17,18,19,24,25,30,31,32,96,97,98,99,100,101,104,105,107,109,111,112,113]
	for i in range(39,94):remove.append(i)
	use_layout("SVG_jing_ui04_reconstruction_20261024_RECONSTRUCTION",remove)
	for p in range(Model.PEOPLE.size()):
		var person: String=Model.PEOPLE[p];var x:=280+p*275;var bag: Array=model.state.loadout.assigned[person]
		native_text(str(bag.size())+"/4格 · 负重 "+str(model.weight(person))+"/"+str(Model.CAPACITY[person]),Rect2(x,273,269,30),20)
		hit("carrier_"+str(p),Rect2(x,166,269,137),func():action("selectCarrier",person),"选择"+person)
		if person==model.state.loadout.carrier:
			var active:=native_text("当前携带人",Rect2(x+72,465,150,24),18);active.modulate=Color("956432")
		for slot in range(bag.size()):
			var id: String=bag[slot];var box:=Rect2(x+48+(slot%2)*98,319+int(slot/2)*74,76,62)
			image_node(skin.items[id],box)
			hit("remove_"+person+"_"+id,box,func():action("removeLoadout",id,person),"取下"+model.item(id).name)
	var pool: Array=model.ensure_pool();pool_row=clampi(pool_row,0,maxi(0,int(ceil(pool.size()/6.0))-2))
	var assigned: Array=model.assigned_ids()
	for visible_index in range(12):
		var idx:=pool_row*6+visible_index
		if idx>=pool.size():break
		var id: String=pool[idx];var x:=268+(visible_index%6)*139;var y:=555+int(visible_index/6)*127
		image_node(skin.pool_tile,Rect2(x,y,134,125))
		var icon:=image_node(skin.items[id],Rect2(x+17,y+5,104,80));icon.modulate.a=0.4 if id in assigned else 1.0
		native_text(model.item(id).name,Rect2(x+8,y+88,125,30),18)
		hit("item_"+id,Rect2(x,y,134,125),func():
			selected_item=id
			if id not in model.assigned_ids():action("addLoadout",id),model.item(id).hint)
	var info: Dictionary=model.item(selected_item)
	native_text(info.name,Rect2(1140,500,250,40),28);image_node(skin.items[selected_item],Rect2(1187,540,142,107))
	var hint:=native_text(info.hint+"\n负重 "+str(info.weight),Rect2(1140,651,245,80),18);hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var totals: Dictionary=model.totals()
	native_text("米粮 "+str(totals.rice)+"    饮水 "+str(totals.waterCap)+"    木料 "+str(totals.wood),Rect2(300,835,750,30),20)
	if model.state.error!=null:native_text(model.state.error,Rect2(285,875,800,35),18)
	hit("pool_up",Rect2(1080,500,45,40),func():pool_row-=1,"上一行")
	hit("pool_down",Rect2(1080,775,45,40),func():pool_row+=1,"下一行")
	hit("review_tutorial",Rect2(280,875,160,45),func():action("backLoadoutTutorial"),"回看教程")
	hit("recommend",Rect2(630,875,200,45),func():model.recommend(false),"一键推荐")
	hit("clear",Rect2(920,875,180,45),func():action("clearLoadout"),"重新挑选")
	var depart:=hit("depart",Rect2(1171,837,250,69),func():model.start_opening();screen=model.state.phase,"确认携带")
	depart.disabled=false
	if model.state.loadout.get("confirmRecommendation",false):render_recommendation_confirmation()
func render_recommendation_confirmation() -> void:
	controls.clear()
	use_layout("SVG_jing_ui04_reconstruction_20261024_CONFIRM_replace")
	hit("recommend_confirm",Rect2(594,677,490,69),func():model.recommend(true),"换成建议装法")
	hit("recommend_cancel",Rect2(604,747,470,57),func():model.state.loadout.confirmRecommendation=false,"保留我的选择")
func render_unconnected() -> void:
	load_errors.append("unconnected route: "+screen)

func prose(text: String,box: Rect2,_design_font_size:=24) -> RichTextLabel:
	var control:=RichTextLabel.new();control.position=box.position;control.size=box.size
	control.bbcode_enabled=false;control.text=text
	control.add_theme_font_override("normal_font",fonts[FONT_REG+"#2"])
	control.add_theme_font_size_override("normal_font_size",reading_font_size)
	control.add_theme_color_override("default_color",Color("372b21"));control.add_theme_constant_override("line_separation",8)
	holder.add_child(control);return control
func render_road() -> void:
	var o: Dictionary=model.state.memory.opening
	if o.choice!=null:
		render_event_result(o.immediate,"走到落脚的地方",func():model.settle_opening_arrival();screen=model.state.phase)
		return
	var available: bool=model.tool_available("rope")
	var id: String="UI02_05_05_rope_available" if available else "UI02_05_05_normal"
	var remove: Array=[8,9,10,11]
	for i in range(28 if available else 29,33 if available else 34):remove.append(i)
	use_layout(id,remove)
	prose("\n\n".join(model.road_text()),Rect2(703,373,625,193),22)
	hit("choice_0",Rect2(702,598,631,98),func():model.choose_opening(0),"先跟上家人")
	var rope:=hit("choice_1",Rect2(702,710,631,92),func():model.choose_opening(1),"用绳索拖出长木")
	rope.disabled=not available
func render_event_result(text: String,label: String,continuation: Callable) -> void:
	use_layout("UI10_main",[9,10,19,21,22,23,24,25,26,28,29,30,31,32,35])
	native_text("第1日 · 1937年12月13日",Rect2(58,48,320,35),24)
	native_text("逃难途中",Rect2(58,86,260,30),20)
	native_text("走过这一处",Rect2(521,282,450,40),26)
	prose(text,Rect2(520,345,670,240),23)
	design_text("UI10_main",35,label)
	hit("result_next",Rect2(989,676,228,67),continuation,label)
func render_arrival() -> void:
	var o: Dictionary=model.state.memory.opening
	render_event_result("\n\n".join(model.opening_arrival_copy())+"\n\n抵达后清点\n"+"\n".join(o.receipt)+"\n米粮 "+str(o.arrived.rice)+"，饮水 "+str(o.arrived.water)+"/"+str(o.arrived.waterCap)+"，木料 "+str(o.arrived.wood),"写下今天",func():screen="diary")
func render_diary() -> void:
	use_layout("SVG_jing_ui12_reconstruction_20261024_UI12_reconstruction_v04",[13,15,16,17])
	native_text("罗瑾的日记 · 第1日",Rect2(578,310,420,40),24)
	prose("\n\n".join(model.state.memory.opening.diary),Rect2(458,433,780,150),23)
	hit("night_plan",Rect2(1013,638,266,85),func():
		if native_open_night():screen="night","安排今晚")
func selection_dot(x: float,y: float) -> void:
	var layer=Layer.new();layer.current={"canvas":current.canvas,"operations":[{"type":"ellipse","box":[x,y,14,14],"color":"#b51f1c","stroke":"none","width":1,"rx":0}]}
	layer.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.size=Vector2(current.canvas[0],current.canvas[1]);holder.add_child(layer)
func center_text(text: String,box: Rect2,font_size:=28) -> Label:
	var label:=native_text(text,box,font_size);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;return label
func date_label() -> String:
	if not model.state.is_empty() and model.state.get("ended",false) and int(model.state.day)==49:return "四十九日结束 · "+str(city_chronicle[48].date)
	return _room_parent_0_date_label()

func op_from(layout_id: String,index: int) -> Dictionary:
	for layout in layouts:
		if layout.id==layout_id:return layout.operations[index]
	return {}
func render_night_plan() -> void:
	var remove: Array=[13,20,22,37,40,59,61,62,63,64,75,84,134,137,140,141,142,143,144,145,149]
	for i in range(38,57):remove.append(i)
	for i in range(73,84):remove.append(i)
	for i in range(85,130):remove.append(i)
	use_layout("UI17_main",remove)
	var n: Dictionary=model.state.night;var preview:=model.preview_night()
	selection_dot(856,133 if n.meal else 168)
	selection_dot(1200,[130,158,186][int(n.fire)])
	hit("night_meal_on",Rect2(844,123,190,37),func():native_night_option("meal",true),"今晚开伙")
	hit("night_meal_off",Rect2(844,160,190,37),func():native_night_option("meal",false),"今晚不开伙")
	var no_fire:=native_text("不生火（开伙时不可选）" if n.meal else "不生火",Rect2(1231,122,230,28),18);no_fire.modulate.a=0.45 if n.meal else 1.0
	for fire in range(3):
		var b:=hit("night_fire_"+str(fire),Rect2(1187,119+fire*28,275,30),func():native_night_option("fire",fire),"火力 "+str(fire))
		b.disabled=fire==0 and n.meal
	render_expedition_night_controls()
	render_animal_card()
	if model.animal_encounter_for_night()!=null:
		native_text("棚边有动物停留 · 查看",Rect2(1035,452,410,24),18)
		hit("animal_encounter_open",Rect2(1030,447,425,30),func():screen="animalEncounter","处理动物遇见；不处理直接确认会错过")
	selection_dot(1040,558) if n.treatment=="none" else null
	hit("night_treatment_none",Rect2(1035,551,430,44),func():native_night_treatment("none"),"本夜不用药")
	var treatments: Array=model.treatment_options()
	if treatments.is_empty():prose("当前没有可安排的病症用药。物品留在家中，不会凭空扣除。",Rect2(1035,630,410,100),20)
	else:
		var scroll:=ScrollContainer.new();scroll.position=Vector2(1035,605);scroll.size=Vector2(430,176);holder.add_child(scroll)
		var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
		for option in treatments:
			var button:=Button.new();button.text=("● " if n.treatment==option.value else "○ ")+option.label;button.custom_minimum_size=Vector2(405,46)
			button.add_theme_font_override("font",fonts[FONT_REG+"#2"]);button.add_theme_font_size_override("font_size",19);button.add_theme_color_override("font_color",Color("372b21"))
			for style in ["normal","hover","pressed","focus","disabled"]:button.add_theme_stylebox_override(style,StyleBoxEmpty.new())
			for color in ["font_hover_color","font_pressed_color","font_focus_color"]:button.add_theme_color_override(color,Color("8a3c29"))
			button.pressed.connect(func():native_night_treatment(option.value);call_deferred("render_screen"));list.add_child(button);controls["night_treatment_"+option.value]=button
	for row in [["rice",367],["water",580],["wood",784]]:
		var amount: int=int(model.state[row[0]]);var cost: int=int(preview.cost[row[0]])
		native_text(str(amount)+" → "+str(amount-cost),Rect2(row[1],878,180,37),26)
	native_text("物资尚未扣除",Rect2(970,844,225,32),21)
	prose("此处是总计，不重复扣减。",Rect2(970,880,220,36),16)
	native_text(date_label(),Rect2(42,20,335,75),22)
	var valid: bool=preview.cost.rice<=model.state.rice and preview.cost.wood<=model.state.wood and (not n.meal or n.fire>=1)
	var probe=Model.new();probe.state=model.state.duplicate(true);valid=valid and probe.validate_expedition_plan()
	var confirm:=hit("night_confirm",Rect2(1205,822,266,80),func():
		if native_confirm_night():night_stage="reading";night_choice_page=0;screen=model.state.phase,"确认今晚")
	confirm.disabled=not valid
	hit("night_back",Rect2(1516,64,155,80),func():screen="diary" if model.state.day==0 else "focusDiary","返回日记，不改变安排")

func render_night_event() -> void:
	var event=model.state.get("pendingNightEvent")
	if event!=null and night_stage=="choices":
		var remove: Array=[9,10,14,15,17,18,20,21,22,28,29,30,33,34,35,36,37,38]
		if event.type=="robbery" and not model.animal_at_home("poultry"):remove.append(19)
		use_layout("UI18_mouse_rope_available",remove)
		native_text(date_label(),Rect2(54,30,550,40),24);native_text(model.current_weather().name+" · 夜间",Rect2(54,68,400,28),18)
		native_text("夜间 · 有限现场",Rect2(775,200,360,35),24)
		center_text(event.title,Rect2(690,260,560,62),31)
		native_text("重读现场正文",Rect2(696,320,544,34),20)
		hit("night_reread",Rect2(696,315,544,40),func():night_stage="reading","重读，不结算")
		var choices=[
			["quiet","先护住人，不追出去","可能失去近手的一份米粮或木料；没有可拿的则不再扣。"],
			["warn","让叔叔隔着棚边出声","需要叔叔在棚且能够应答；他会费些精神，不追赶来人。"],
			["whistle","吹响哨子","需要可用哨子，不消耗它；让近处听见动静。"]]
		if event.type=="robbery":
			choices=[["give","不硬拦，交出米粮或木料","损失按现有家用结算；不会拿不存在的东西抵账。"],["resist","试着阻拦","家人可能遭殴打；留下物资不等于没有损失。"]]
			if model.animal_at_home("poultry"):choices.insert(1,["animalPoultry","交出"+model.animal_name(model.state.animals.poultry),"动物离开家中，不承诺送还，也不知道它后来在哪里。"])
			if model.animal_at_home("pet"):choices.insert(1,["animalPet","交出"+model.animal_name(model.state.animals.pet),"动物离开家中，不承诺送还，也不知道它后来在哪里。"] )
		elif event.type=="mouse":
			choices=[["tidy","搬到身边，清理散米","先收拢眼前的粮袋；是否少粮留到天亮清点。"],["move","用绳索吊好粮袋","需要家里可用的绳索；绳索仍会留下。"],["wait","先休息，天亮再看","当场不清点，天亮按实际结果记账。"]]
		var pages: int=ceili(choices.size()/3.0);night_choice_page=clampi(night_choice_page,0,pages-1)
		if pages>1:
			native_text("上一页     "+str(night_choice_page+1)+" / "+str(pages)+"     下一页",Rect2(780,795,430,35),20)
			hit("night_choices_prev",Rect2(770,790,140,45),func():night_choice_page=maxi(0,night_choice_page-1)).disabled=night_choice_page==0
			hit("night_choices_next",Rect2(1080,790,140,45),func():night_choice_page=mini(pages-1,night_choice_page+1)).disabled=night_choice_page==pages-1
		for i in range(mini(3,choices.size()-night_choice_page*3)):
			var index: int=night_choice_page*3+i
			var row: Array=choices[index];var y: int=447+i*121
			var path: String=op_from("UI18_mouse_rope_available",[14,17,20][i]).path if event.type=="mouse" else (skin.items.rice5 if event.type=="robbery" and i==0 else (skin.items.goose if row[0]=="animalPoultry" else (op_from("UI17_main",47).path if row[0] in ["warn","resist"] else (skin.items.whistle if row[0]=="whistle" else skin.items.bedding))))
			if row[0]=="animalPet":path=op_from("UI17_animal_overview",11 if model.state.animals.pet.type=="cat" else 15).path
			var icon:=image_node(path,Rect2(700,y+12,165,82));icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var title:=native_text(row[1],Rect2(890,y+17,350,35),24)
			var hint:=prose(row[2],Rect2(890,y+56,350,45),17)
			var button:=hit("night_choice_"+row[0],Rect2(682,y,575,108),func():native_night_response(row[0]),row[1])
			button.disabled=not model.night_choice_requirement(row[0])
			if button.disabled:icon.modulate.a=0.45;title.modulate.a=0.45;hint.modulate.a=0.45
		return
	var removed: Array=[11,12,15,16,23,24,25,26,27,28,29]
	if event!=null:removed.append_array([14,30])
	use_layout("UI18_quiet_normal",removed)
	native_text(date_label(),Rect2(54,30,550,40),24);native_text(model.current_weather().name+" · 夜间",Rect2(54,68,400,28),18)
	var record: Dictionary=model.state.nightCycle.get("readingEvent",{})
	var title: String=event.title if event!=null else record.get("title","棚边暂时安静下来")
	center_text(title,Rect2(735,279,490,62),34)
	var status:=native_text(str(model.state.error) if model.state.get("error")!=null else "今晚安排已确认；结算结果仍以清点为准。",Rect2(745,365,465,35),17)
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var body: String=event.text if event!=null else record.get("closure","这一夜还没有过去。")
	if event==null and record.get("receipt","")!="":body+="\n\n"+record.receipt
	prose(body,Rect2(745,404,465,270),23)
	if event!=null and event.type=="family":
		center_text("把这一夜接着过下去",Rect2(805,723,345,45),24).add_theme_color_override("font_color",Color("fff2d8"))
		hit("night_family_continue",Rect2(796,706,356,75),func():native_night_response("continue"),"不新增选择；继续今晚的安排")
	elif event!=null:
		center_text("选择应对",Rect2(820,723,310,45),30).add_theme_color_override("font_color",Color("fff2d8"))
		hit("night_read_next",Rect2(796,706,356,75),func():night_stage="choices","查看应对选项")
	else:
		hit("night_finish",Rect2(796,706,356,75),func():
			if native_finish_night():screen=model.state.phase;morning_tab="city","结算这一夜")
func render_morning() -> void:
	use_layout("UI07_main",[9,10,19,20,25,29,30,32,33,34,35])
	var city: Dictionary=city_chronicle[clampi(int(model.state.day),0,48)]
	native_text(date_label(),Rect2(58,48,450,35),24);native_text(model.current_weather().name+" · 清晨",Rect2(58,86,400,30),20)
	native_text(date_label(),Rect2(642,278,550,40),24);native_text(model.current_weather().name,Rect2(1175,244,90,40),23)
	native_text("昨夜已结算，点击查看昨夜记录与清点。",Rect2(578,410,620,38),21)
	hit("morning_report",Rect2(560,349,645,100),func():morning_tab="night","查看昨夜记录")
	var body: String=""
	var warning: Dictionary=model._object(model.state.memory.get("solitaryHealthWarning"))
	if not warning.is_empty() and warning.get("ackDay")==null:
		native_text("独自生存的警示",Rect2(606,492,570,42),28);native_text("继续前，请先读完这条提醒",Rect2(605,539,570,35),18)
		model.c018_contract();body=model.solitary_contract.warning
	elif morning_tab=="night":
		native_text("昨夜记录",Rect2(606,492,570,42),28);native_text("点击这里返回城里的事",Rect2(605,539,570,35),18)
		var report: Dictionary=model.state.memory.get("nightReadingMorning",{})
		for row in report.get("shown",[]):body+=row.text+"\n\n"
		body+="昨夜清点与状态记录\n"+"\n".join(model.state.morningResults)
	else:
		native_text(str(city.theme),Rect2(606,492,570,42),28);native_text("城里的事",Rect2(605,539,570,35),20)
		body=str(city.quote) if city.quote!=null else str(city.summary)
		body+="\n\n资料与史实边界\n"+str(city.source)+"\n"+str(city.note)
		if city.url!=null:body+="\n"+str(city.url)
	prose(body,Rect2(504,580,730,190),24)
	hit("morning_city",Rect2(580,490,650,80),func():morning_tab="city","返回城里的事")
	var next:=hit("morning_next",Rect2(1361,824,303,69),func():
		if native_enter_focus():screen=model.state.phase,"查看今天各人的去向")
	next.disabled=not first_day_focus_available();next.tooltip_text="查看今日去向" if not next.disabled else "开发候选：此条件的后续白天流程尚未接通"

# Native save controls reuse approved UI23; v1 remains readable, v2 requires bounded replay proof.
func open_saves() -> void:
	save_return_screen=screen;screen="save";save_preview={};save_notice="";save_text=""
func continue_saved() -> void:
	var result: Dictionary=save_store.load_from(save_path,model)
	if not result.ok:save_notice="读取失败，当前进度未改变："+str(result.reason);return
	restore_continuation(save_store.decoded_proof);screen=model.state.phase;night_stage="reading";morning_tab="city"
	autosave_expected_sha=save_store.file_fingerprint(save_path);autosave_seen=state_stamp();autosave_saved=autosave_seen;autosave_paused=result.source=="backup"
	save_notice="已从备用记录恢复；请在存档管理中确认写回主记录，自动保存暂不覆盖损坏文件。" if autosave_paused else "已读取本机记录。"
	autosave_notice=save_notice if autosave_paused else ""
	if autosave_paused and autosave_enabled:autosave_return_screen=screen;screen="autoSaveFailure"

func state_summary(value: Dictionary) -> String:
	if value.is_empty():return "尚未开始游戏"
	if value.get("ended",false):return "四十九日结束 · 结局" if int(value.day)==49 else "第"+str(int(value.day)+1)+"日 · 生涯中断"
	var names={"intro":"序章","tutorial":"教程","loadout":"携带物品","event":"逃难途中","report":"抵达记录","diary":"日记","night":"今晚安排","nightEvent":"夜间现场","morning":"清晨","focus":"今日去向","focusEvent":"现场选择","focusResult":"即时结果","focusReturn":"返家清点","search":"寻找安排","expeditionRecall":"返家口述"}
	return "第"+str(int(value.day)+1)+"日 · "+str(names.get(value.phase,value.phase))

func preview_save_text() -> void:
	save_preview=save_store.decode(save_text)
	save_notice="校验失败："+save_store.error if save_preview.is_empty() else "待恢复："+state_summary(save_preview)+"。确认后替换当前进度。"
func preview_disk_save() -> void:
	var probe=Model.new();var reader=SaveStore.new();var result: Dictionary=reader.load_from(save_path,probe)
	if not result.ok:save_preview={};save_notice="读取失败，当前进度未改变："+str(result.reason);return
	save_text=encode_candidate(probe.state,reader.decoded_proof);preview_save_text()
	if result.source=="backup":save_notice="主记录不可用，预览备用记录。"+save_notice
func restore_preview() -> void:
	var before:=state_stamp();_save_ux_parent_0_restore_preview()
	if state_stamp()!=before:
		autosave_seen="";observe_autosave()

func choose_save_file(exporting: bool) -> void:
	var dialog:=FileDialog.new();dialog.access=FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE if exporting else FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters=PackedStringArray(["*.json ; 京字原生存档"]);dialog.title="导出原生存档" if exporting else "选择原生存档"
	if exporting:dialog.current_file="京字原生存档.json"
	add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		if exporting:
			save_notice="已写入所选文件。" if save_current_to(path) else "导出失败："+save_store.error
		else:
			var candidate: Dictionary=save_store.read_valid(path)
			if candidate.is_empty():save_preview={};save_notice="文件无效："+save_store.error
			else:save_text=encode_candidate(candidate,save_store.decoded_proof);preview_save_text()
		dialog.queue_free();render_screen())
	dialog.canceled.connect(func():dialog.queue_free())
	dialog.popup_centered_ratio(0.7)
func render_saves() -> void:
	use_layout("UI23",[8,13,14,21,24,29,30,31,32,33,36,37,38,39,40,41,42,43])
	native_text("当前本机记录",Rect2(458,254,500,40),27)
	native_text(state_summary(model.state),Rect2(469,303,720,32),21)
	native_text("Godot 本机存档，不是云存档；仅支持当前原生候选。",Rect2(469,335,740,32),20)
	native_text("保存为独立 JSON 文件，不兼容旧 HTML 存档。",Rect2(543,510,680,30),18)
	native_text("先校验，再确认；无效记录不改变当前进度。",Rect2(585,794,650,30),17)
	var notice:=native_text(save_notice,Rect2(689,596,520,42),17);notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	save_editor=TextEdit.new();save_editor.position=Vector2(480,648);save_editor.size=Vector2(738,72)
	save_editor.text=save_text if save_text.length()<=65536 else "";save_editor.placeholder_text=("已载入较大的原生记录，可直接校验/恢复；粘贴新内容会替换它。" if save_text.length()>65536 else "粘贴原生存档文字……");save_editor.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
	save_editor.add_theme_font_override("font",fonts[FONT_REG+"#2"]);save_editor.add_theme_font_size_override("font_size",20)
	for style in ["normal","focus","read_only"]:save_editor.add_theme_stylebox_override(style,StyleBoxEmpty.new())
	save_editor.add_theme_color_override("font_color",Color("372b21"));save_editor.add_theme_color_override("font_placeholder_color",Color("a18b6e"));save_editor.add_theme_color_override("caret_color",Color("8a3c29"));save_editor.add_theme_color_override("selection_color",Color("b89a704d"))
	var bar:=save_editor.get_v_scroll_bar();bar.custom_minimum_size.x=13
	for style in ["scroll","grabber","grabber_highlight","grabber_pressed"]:
		var box:=StyleBoxFlat.new();box.bg_color=Color("f9efd9" if style=="scroll" else ("a59376" if style=="grabber" else "8a7558"));bar.add_theme_stylebox_override(style,box)
	save_editor.text_changed.connect(func():
		save_text=save_editor.text;save_preview={}
		if controls.has("save_restore"):controls.save_restore.disabled=true)
	holder.add_child(save_editor)
	var save:=hit("save_write",Rect2(464,370,150,50),func():
		save_notice="已保存到本机磁盘。" if save_current_to(save_path) else "保存失败："+save_store.error,"保存当前进度")
	save.disabled=model.state.is_empty()
	hit("save_read",Rect2(661,370,150,50),func():preview_disk_save(),"读取并预览，不直接覆盖")
	var export:=hit("save_export",Rect2(472,479,245,53),func():choose_save_file(true),"导出文件")
	export.disabled=model.state.is_empty()
	hit("save_file",Rect2(473,592,210,45),func():choose_save_file(false),"选择原生存档文件")
	hit("save_validate",Rect2(582,737,233,51),func():preview_save_text(),"校验并预览")
	image_node(op_from("UI23",36 if save_preview.is_empty() else 34).path,Rect2(860,737,229,50))
	center_text("确认恢复",Rect2(860,745,229,36),21).add_theme_color_override("font_color",Color("f6ead5"))
	var restore:=hit("save_restore",Rect2(860,737,229,50),func():restore_preview(),"确认覆盖当前进度")
	restore.disabled=save_preview.is_empty()
	hit("save_back",Rect2(1148,195,110,45),func():screen=save_return_screen;save_preview={},"返回，不恢复")

func first_day_focus_available() -> bool:
	return model.state.day>=1 and model.state.day<=48 and model.early_household_supported()
func render_day_focus() -> void:
	use_layout("UI08_main",[9,10,18,29,30,31,32,33,34,35,36,37,41,42,43,44,45,46,47,48])
	native_text(date_label(),Rect2(58,40,600,40),24);native_text(model.current_weather().name+" · 清晨",Rect2(58,78,400,30),20)
	native_text("第"+str(int(model.state.day)+1)+"日",Rect2(1165,204,110,40),26)
	var plan: Dictionary=model.state.focus.plan;var rows: Dictionary=plan.rows
	for entry in [["罗瑾",662,357,598,369],["母亲",1054,378,992,369],["外祖父",659,488,598,494],["安仁叔叔",1054,506,995,494]]:
		var row: Dictionary=rows[entry[0]];var label:=native_text(row.label,Rect2(entry[1],entry[2],215,60),19);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		image_node(op_from("UI08_main",29 if row.type=="water" and row.outside else (31 if row.type=="wood" and row.outside else 30)).path,Rect2(entry[3],entry[4],49,47))
	if focus_target not in plan.targets:focus_target=plan.targets[0]
	for target_index in range(plan.targets.size()):
		var target: String=plan.targets[target_index];var x: int=(530 if target=="罗瑾" else (800 if target=="外祖父" else 1069)) if model.state.day<10 else ([530,1069][target_index] if plan.targets.size()==2 else [530,800,1069][target_index])
		image_node(op_from("UI08_main",41 if target=="罗瑾" else (42 if target=="外祖父" else (43 if target=="home" else 30))).path,Rect2(x,615,84,66))
		center_text("留在棚里" if target=="home" else "跟随"+target,Rect2(x-40,680,180,42),24)
		hit("focus_target_"+target,Rect2(x-40,602,180,120),func():focus_target=target,"选择注视，不派工")
		if focus_target==target:selection_dot(x+90,639)
	hit("focus_confirm",Rect2(1065,745,198,63),func():
		if native_select_focus(focus_target):screen=model.state.phase,"确认注视选择")
	hit("focus_back",Rect2(432,768,130,40),func():
		if native_back_morning():screen="morning","返回晨间记录，不执行选择")
	hit("focus_menu",Rect2(1512,34,151,56),func():open_saves(),"保存与恢复")
func render_day_focus_event() -> void:
	var event: Dictionary=native_focus_event()
	var hidden: Array=[7,14,15,19,20,21,22,23,24,25,26,27,28,30,31,32,33,34,38,39,40,41,42,43,44,45,46]
	focus_choice_page=clampi(focus_choice_page,0,maxi(0,(event.choices.size()-1)/3))
	var page_start: int=focus_choice_page*3;var visible: int=mini(3,event.choices.size()-page_start)
	for i in range(visible,3):hidden.append(35+i)
	if event.choices.size()>3:hidden.append_array([35,36,37])
	use_layout("UI09_main",hidden)
	native_text(date_label()+"   白天事件 · "+("留棚" if model.state.focus.selected=="home" else model.state.focus.selected),Rect2(48,28,1200,40),24)
	image_node(skin.items.bedding if model.state.focus.selected=="home" else op_from("UI09_main",14 if model.state.focus.selected=="罗瑾" else 12).path,Rect2(481,223,60,76));native_text(event.title,Rect2(569,228,535,55),36)
	native_text("完整正文 · 可在纸面内滚动阅读",Rect2(489,303,600,30),17)
	prose(event.intro,Rect2(489,341,706,220),22)
	for row_index in range(visible):
		var i: int=page_start+row_index;var choice: Dictionary=event.choices[i];var y: int=589+row_index*76
		if event.choices.size()>3:design_text("UI09_main",35+row_index,str(i+1))
		image_node((skin.items.bedding if row_index==0 else op_from("UI09_main",32 if row_index==2 else 33).path) if model.state.focus.selected=="home" else op_from("UI09_main",[30,32,33][row_index]).path,Rect2(582,y+5,73,58))
		var label:=native_text(choice.label,Rect2(681,y+3,490,37),22);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var hint:=native_text(choice.hint,Rect2(681,y+40,490,33),17);hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var b:=hit("focus_choice_"+str(i),Rect2(485,y,710,74),func():
			if native_choose_focus(i):screen=model.state.phase,choice.hint)
		b.disabled=not native_choice_requirement(choice).met
	if event.choices.size()>3:
		native_text("上一页",Rect2(489,819,100,28),17)
		var prev:=hit("focus_choices_prev",Rect2(485,817,110,31),func():focus_choice_page-=1,"只翻页，不执行选择");prev.disabled=focus_choice_page==0
		native_text("第 "+str(focus_choice_page+1)+" / "+str(int(ceil(event.choices.size()/3.0)))+" 页",Rect2(771,819,240,28),17)
		native_text("下一页",Rect2(1090,819,105,28),17)
		var next:=hit("focus_choices_next",Rect2(1085,817,110,31),func():focus_choice_page+=1,"只翻页，不执行选择");next.disabled=page_start+visible>=event.choices.size()
	else:native_text("选择后核对决定。",Rect2(771,819,300,28),17)
	hit("focus_event_back",Rect2(1132,237,110,40),func():
		if native_back_focus():screen="focus","返回今日去向，未结算")
	hit("focus_event_menu",Rect2(1512,34,151,56),func():open_saves(),"保存与恢复")
func render_day_focus_result() -> void:
	use_layout("UI10_main",[9,10,19,20,21,22,23,24,25,26,28,29,30,31,32,35])
	native_text(date_label(),Rect2(58,40,600,40),24);native_text("白天 · "+("留棚" if model.state.focus.selected=="home" else model.state.focus.selected),Rect2(58,78,400,30),20)
	native_text(native_focus_event().title,Rect2(521,282,650,40),26)
	prose(model.state.focus.immediateText,Rect2(520,345,670,240),22)
	native_text(model.state.focus.immediateChange if model.state.focus.immediateChange!="" else "本次选择没有额外物资或状态收益。",Rect2(532,610,620,38),19)
	design_text("UI10_main",35,"等到傍晚")
	hit("focus_result_next",Rect2(989,676,228,67),func():
		if native_return_focus():screen=model.state.phase,"等到傍晚，核对家庭记录")
	hit("focus_result_menu",Rect2(1512,34,151,56),func():open_saves(),"保存与恢复")
func render_day_focus_return() -> void:
	use_layout("UI11_main",[16,17,20,21,22,23,24,25])
	prose(model.state.focus.returnText if model.state.focus.returnText!="" else "今天家人都在棚里。没有额外带回的物资，家里的吃用仍以实际库存为准。",Rect2(566,329,540,74),21)
	native_text("米粮 "+str(model.state.rice)+"   饮水 "+str(model.state.water)+"/"+str(model.state.waterCap)+"   木料 "+str(model.state.wood),Rect2(616,488,510,70),23)
	native_text(model.state.focus.returnChange if model.state.focus.returnChange!="" else "清点库存，不重复执行白天选择。",Rect2(638,585,490,42),20)
	hit("focus_return_diary",Rect2(1362,825,305,69),func():screen="focusDiary","读罗瑾的日记")
func render_day_focus_diary() -> void:
	use_layout("SVG_jing_ui12_reconstruction_20261024_UI12_reconstruction_v04",[13,15,16,17])
	native_text("罗瑾的日记 · 第"+str(int(model.state.day)+1)+"日",Rect2(578,310,420,40),24)
	prose(native_focus_diary(),Rect2(458,410,780,200),22)
	hit("day_open_night",Rect2(1013,638,266,85),func():
		if native_open_night():screen="night","安排今晚")

func _process(_delta: float) -> void:
	for binding in primary_bindings:refresh_primary_appearance(binding)
func bind_primary_appearance(button: Button,box: Rect2) -> void:
	for child in holder.get_children():
		if not child is Layer or child.current.operations.size()!=1:continue
		var operation: Dictionary=child.current.operations[0]
		if operation.get("type")!="image" or not primary_button_states.has(operation.get("path")):continue
		var raw: Array=operation.box;var area:=Rect2(raw[0],raw[1],raw[2],raw[3])
		if area.get_area()<3000 or area.intersection(box).get_area()/area.get_area()<0.8:continue
		var binding: Dictionary={"button":weakref(button),"layer":weakref(child),"operation":operation,"normal":operation.path,"cropped":operation.has("region"),"original_region":operation.get("region"),"hover":false,"down":false,"focus":false,"last":""}
		primary_bindings.append(binding);button.set_meta("primary_binding",binding)
		button.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
		button.mouse_entered.connect(func():binding.hover=true;refresh_primary_appearance(binding))
		button.mouse_exited.connect(func():binding.hover=false;binding.down=false;refresh_primary_appearance(binding))
		button.focus_entered.connect(func():binding.focus=true;refresh_primary_appearance(binding))
		button.focus_exited.connect(func():binding.focus=false;refresh_primary_appearance(binding))
		button.button_down.connect(func():binding.down=true;refresh_primary_appearance(binding))
		button.button_up.connect(func():binding.down=false;refresh_primary_appearance(binding))
		refresh_primary_appearance(binding);return
func refresh_primary_appearance(binding: Dictionary) -> void:
	var button=binding.button.get_ref();var layer=binding.layer.get_ref()
	if not is_instance_valid(button) or not is_instance_valid(layer):return
	var state: String="disabled" if button.disabled else ("pressed" if binding.down else ("focus" if binding.focus else ("hover" if binding.hover else "normal")))
	if binding.last==state:return
	var spec: Dictionary=primary_button_states[binding.normal][state]
	if not textures.has(spec.path):textures[spec.path]=load(spec.path)
	binding.operation.path=spec.path
	if binding.cropped:binding.operation.region=binding.original_region if state=="normal" else spec.region
	binding.last=state;layer.queue_redraw()

func design_text(layout_id: String,index: int,text: String) -> Control:
	var operation: Dictionary=op_from(layout_id,index).duplicate(true);operation.text=text
	var layer=Layer.new();layer.current={"canvas":current.canvas,"operations":[operation]};layer.fonts=fonts;layer.textures=textures;layer.size=Vector2(current.canvas[0],current.canvas[1]);layer.mouse_filter=Control.MOUSE_FILTER_IGNORE;holder.add_child(layer);return layer

func render_terminal_failure() -> void:
	var layout_id: String="SVG_jing_ui13_16_reconstruction_20261024_UI16_interrupted_reconstruction_v02"
	use_layout(layout_id,[7,8,9,10,11])
	design_text(layout_id,7,date_label()+" · 记录中断")
	var record: Dictionary=model._object(model.state.memory.get("failureRecord"))
	prose(record.get("closure","这一段记录停在这里。"),Rect2(537,553,600,72),23)
	var photo: Dictionary=model._object(record.get("photo"))
	design_text(layout_id,10,"此前照片记录："+("已解锁" if photo.get("unlocked",false) else "尚未解锁"))
	design_text(layout_id,11,"加印 "+str(int(photo.get("prints",0)))+" · 精选 "+str(int(model._object(photo.get("album")).get("selected",0)))+" · 转移 "+str(int(photo.get("transferCount",0))))
	hit("failure_restart",Rect2(692,760,307,67),func():screen="menu","返回主菜单，选择开始新记录；磁盘存档不变")

func load_reading_preferences() -> void:
	var config:=ConfigFile.new()
	if config.load(settings_path)!=OK:return
	var font=config.get_value("reading","font",19);var focused=config.get_value("reading","focused",false)
	if typeof(font)==TYPE_INT and font in [18,19,22,25,29]:reading_font_size=font
	if focused is bool:focused_reading=focused
func save_reading_preferences() -> bool:
	var config:=ConfigFile.new();config.set_value("reading","font",reading_font_size);config.set_value("reading","focused",focused_reading)
	var error: int=config.save(settings_path)
	reading_preferences_error="" if error==OK else "阅读设置未能保存到磁盘，当前显示仍可使用。"
	return error==OK
func open_reading_settings() -> void:
	if screen!="settings":settings_return_screen=screen
	settings_focus_control="reading_font_18";screen="settings"
func render_reading_settings() -> void:
	var id: String="UI22_selected_"+str(reading_font_size)+"_toggle_on"
	var hidden: Array=[]
	for index in range(17,77):hidden.append(index)
	if not focused_reading:hidden.append(95)
	use_layout(id,hidden)
	settings_focus_layer=Layer.new();settings_focus_layer.current={"canvas":current.canvas,"operations":[]};settings_focus_layer.fonts=fonts;settings_focus_layer.textures=textures;settings_focus_layer.size=Vector2(current.canvas[0],current.canvas[1]);settings_focus_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	holder.add_child(settings_focus_layer)
	var choices: Array=[[18,482,103],[19,610,106],[22,745,137],[25,916,110],[29,1047,143]]
	for entry in choices:
		var value: int=entry[0];var control_id: String="reading_font_"+str(value);var box:=Rect2(entry[1],410,entry[2],44)
		var button:=hit(control_id,box,func():reading_font_size=value;settings_focus_control=control_id;save_reading_preferences(),"选择"+str(value)+"字号，仅改变阅读显示")
		button.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
		button.focus_entered.connect(func():show_reading_focus(box))
		button.focus_exited.connect(func():clear_reading_focus())
	var toggle:=hit("reading_focus_toggle",Rect2(571,606,420,44),func():focused_reading=not focused_reading;settings_focus_control="reading_focus_toggle";save_reading_preferences(),"仅减弱阅读区域外的背景，不推进游戏")
	hit("reading_back",Rect2(1063,650,127,46),func():screen=settings_return_screen,"返回，不推进游戏")
	if reading_preferences_error!="":native_text(reading_preferences_error,Rect2(487,713,675,26),16)
	call_deferred("restore_reading_focus")
func restore_reading_focus() -> void:
	if screen=="settings" and controls.has(settings_focus_control):controls[settings_focus_control].grab_focus()
func clear_reading_focus() -> void:
	if is_instance_valid(settings_focus_layer):settings_focus_layer.current.operations=[];settings_focus_layer.queue_redraw()
func show_reading_focus(box: Rect2) -> void:
	if not is_instance_valid(settings_focus_layer):return
	var operations: Array=[]
	for index in range(17,77):
		var operation: Dictionary=op_from("UI22",index).duplicate(true);var points: Array=operation.points
		for i in [0,2]:points[i]=box.position.x+(points[i]-482)*box.size.x/103.0
		for i in [1,3]:points[i]=box.position.y+(points[i]-410)*box.size.y/43.0
		operations.append(operation)
	settings_focus_layer.current.operations=operations;settings_focus_layer.queue_redraw()

func later_action(op: String,args: Array=[]) -> bool:
	if continuation.anchor.is_empty() and not continuation.start(model):save_notice="当前后续进度缺少可核验的起点，未执行操作。";return false
	var result: bool=continuation.apply(model,op,args)
	if continuation.error!="":save_notice="后续操作尚未执行："+continuation.error
	return result
func native_enter_focus() -> bool:
	return later_action("enter") if int(model.state.day) in range(10,49) else model.enter_first_day_focus()
func native_select_focus(target: String) -> bool:
	var result: bool=later_action("select",[target]) if int(model.state.day) in range(10,49) else model.select_first_day_focus(target)
	if result:focus_choice_page=0
	return result
func native_choose_focus(index: int) -> bool:
	return later_action("choose",[index]) if int(model.state.day) in range(10,49) else model.resolve_first_day_focus_choice(index)
func native_return_focus() -> bool:
	return later_action("return") if int(model.state.day) in range(10,49) else model.settle_first_day_focus_return()
func native_open_night() -> bool:
	if int(model.state.day) in range(10,49):
		return true if model.state.phase=="night" else later_action("open_night")
	model.state.phase="night";return true
func native_back_morning() -> bool:
	if int(model.state.day) in range(10,49):return later_action("back_morning")
	model.state.phase="morning";return true
func native_back_focus() -> bool:
	if int(model.state.day) in range(10,49):return later_action("back_focus")
	model.state.phase="focus";return true
func native_night_option(key: String,value: Variant) -> bool:
	return later_action("night_option",[key,value]) if int(model.state.day) in range(10,49) else model.set_night_option(key,value)
func native_night_treatment(value: String) -> bool:
	return later_action("night_treatment",[value]) if int(model.state.day) in range(10,49) else model.set_night_treatment(value)
func native_feed_animal(slot: String) -> bool:
	return later_action("feed_animal",[slot]) if int(model.state.day) in range(10,49) else model.feed_animal(slot)
func native_confirm_night() -> bool:
	return later_action("confirm_night") if int(model.state.day) in range(10,49) else model.confirm_first_night()
func native_night_response(value: String) -> bool:
	return later_action("night_response",[value]) if int(model.state.day) in range(10,49) else model.resolve_night_event(value)
func native_finish_night() -> bool:
	return later_action("finish_night") if int(model.state.day) in range(10,49) else model.finish_first_night()
func native_focus_event() -> Dictionary:
	return model.current_later_focus_event() if model.state.day>=10 else model.current_first_focus_event()
func native_choice_requirement(choice: Dictionary) -> Dictionary:
	if model.state.day<10:return model.focus_choice_requirement(choice)
	var event:=native_focus_event()
	return model.custody_night_choice_requirement(choice,event) if event.has("custodyNight") else model.ordinary_pre_photo_requirement(choice)
func native_focus_diary() -> String:
	if not model.state.is_empty() and model._object(model.state.focus.get("plan")).get("key")=="pigeonPickup":
		if model.state.ended or not model.state.people["罗瑾"].alive:return ""
		if not model.state.focus.get("diaryAllowed",false):return "这一日没有留下可确认的第一人称记述。"
		return "\n\n".join(model.state.focus.get("chapterDiary",[]).filter(func(text):return text is String and not text.strip_edges().is_empty()))
	return _pigeon_ui_parent_0_native_focus_diary()

func restore_continuation(proof: Dictionary) -> void:
	continuation=Continuation.new()
	if not proof.is_empty():continuation.restore(proof)
	save_store.active_proof=proof.duplicate(true)
func save_current_to(path: String) -> bool:
	var ok: bool=_save_ux_parent_0_save_current_to(path)
	if path==save_path and (ok or save_store.last_write_committed):adopt_primary_if_current()
	return ok

func encode_candidate(candidate: Dictionary,proof: Dictionary) -> String:
	var writer=SaveStore.new();writer.active_proof=proof.duplicate(true)
	return writer.encode(candidate)

func render_animal_card() -> void:
	_pigeon_ui_parent_0_render_animal_card()
	var note: bool=bird_note_available();var bird=model.state.animals.get("poultry");var stale: bool=model.state.night.get("pigeonAction","none")!="none"
	if note and controls.has("animal_tab_poultry"):controls.animal_tab_poultry.disabled=false
	if note or stale or (bird is Dictionary and bird.get("type")=="pigeon"):
		native_text("信鸽求助 / 取物安排",Rect2(1050,520,390,38),21)
		hit("pigeon_open",Rect2(1040,516,410,45),func():screen="pigeonPlan","查看原夜间条件；预选不扣物资")

func render_animal_encounter() -> void:
	render_night_plan()
	var encounter=model.animal_encounter_for_night()
	if encounter==null:screen="night";return
	# Modal uses approved paper/button/image components at their native pixel sizes.
	var shade:=ColorRect.new();shade.color=Color(0,0,0,0.65);shade.size=Vector2(1920,1080);shade.mouse_filter=Control.MOUSE_FILTER_STOP;holder.add_child(shade)
	for control in controls.values():control.disabled=true
	var occupied: bool=model.state.animals.pet!=null
	var offset:=Vector2(522,330);var base: int=12 if occupied else 0
	var source_x: int=847 if occupied else 50
	var indexes: Array=[base,base+1,base+2,base+3,base+6,base+7,base+8,base+9]
	for index in indexes:
		var op: Dictionary=op_from("UI17_animals",index).duplicate(true)
		if index==base+3:op.path=op_from("UI17_animals",3 if encounter.kind=="cat" else 15).path
		if op.get("type")=="image" and not textures.has(op.path):textures[op.path]=load(op.path)
		var layer=Layer.new();layer.current={"canvas":[1672,420],"operations":[op]};layer.position=offset-Vector2(source_x,10);layer.size=Vector2(1672,420);layer.textures=textures;layer.fonts=fonts;layer.mouse_filter=Control.MOUSE_FILTER_IGNORE;holder.add_child(layer)
	prose(encounter.text,Rect2(offset.x+430,offset.y+72,310,70),18)
	prose("已有宠物，不能同时留下。" if occupied else "需要另外按期备粮。",Rect2(offset.x+430,offset.y+287,310,50),18)
	hit("animal_accept",Rect2(offset.x+434,offset.y+153,304,55),func():later_action("animal_encounter",["accept",encounter.kind]);screen="night","把它留下").disabled=occupied
	hit("animal_decline",Rect2(offset.x+434,offset.y+221,304,55),func():later_action("animal_encounter",["decline",encounter.kind]);screen="night","不留下")
	native_text("返回安排（暂不决定）",Rect2(offset.x+120,offset.y+390,440,38),22).add_theme_color_override("font_color",Color.WHITE)
	hit("animal_back",Rect2(offset.x+100,offset.y+385,480,48),func():screen="night","返回，不改变动物状态")

# Approved UI16/UI20 component layouts, not full-page screenshot backgrounds.
var records_return_screen: String="end"
var photo_record_tab:=0
var ending_scroll_offset:=0.0
var ending_view_data: Dictionary={}
var photo_record_data: Dictionary={}
func open_photo_records() -> void:
	if photo_records_visible():_aux_parent_4_open_photo_records()

func render_native_ending() -> void:
	_aux_parent_4_render_native_ending()
	if controls.has("ending_records"):controls.ending_records.disabled=not photo_records_visible()

func ending_scroll_button(id: String,box: Rect2,callback: Callable) -> void:
	var b:=Button.new();b.name=id;b.position=box.position;b.size=box.size
	for style in ["normal","hover","pressed","disabled"]:b.add_theme_stylebox_override(style,StyleBoxEmpty.new())
	b.tooltip_text="滚动后记，不推进游戏";b.pressed.connect(callback);holder.add_child(b);controls[id]=b
func sync_ending_thumb(bar: VScrollBar,thumb: TextureRect) -> void:
	var span: float=maxf(0,bar.max_value-bar.page);thumb.size.y=clampf(180*bar.page/maxf(1,bar.max_value),18,81);thumb.position.y=350+(180-thumb.size.y)*(bar.value/span if span>0 else 0);thumb.visible=span>0
func restore_ending_scroll(body_ref,thumb_ref) -> void:
	await get_tree().process_frame
	var body=body_ref.get_ref();var thumb=thumb_ref.get_ref()
	if not is_instance_valid(body) or not is_instance_valid(thumb):return
	var bar: VScrollBar=body.get_v_scroll_bar();bar.value=ending_scroll_offset;bar.hide();sync_ending_thumb(bar,thumb)
func record_tab_rect(layout_id: String,label: String) -> Rect2:
	var ops: Array=[]
	for layout in layouts:
		if layout.id==layout_id:ops=layout.operations;break
	for i in range(ops.size()):
		if ops[i].get("type")!="text" or ops[i].get("text")!=label:continue
		var edges: Array=[]
		for j in range(i-1,maxi(-1,i-8),-1):
			if ops[j].get("type")=="line":edges.push_front(ops[j].get("points",ops[j].get("box",[])))
			if edges.size()==4:break
		if edges.size()!=4:break
		var lo:=Vector2(INF,INF);var hi:=Vector2(-INF,-INF)
		for edge in edges:
			for k in [0,2]:lo=lo.min(Vector2(edge[k],edge[k+1]));hi=hi.max(Vector2(edge[k],edge[k+1]))
		return Rect2(lo,hi-lo).grow(-1)
	load_errors.append("missing record tab rectangle: "+label);return Rect2()
func record_tabs(layout_id: String) -> void:
	var labels: Array=["手里的材料","已发生的告知","期限与获知","路线与转移"]
	for i in range(labels.size()):
		var index: int=i;hit("record_tab_"+str(index),record_tab_rect(layout_id,labels[i]),func():photo_record_tab=index,labels[i]+"（只读）")
func render_photo_records() -> void:
	photo_record_data=model.native_photo_record_view();var data: Dictionary=photo_record_data
	var suffix: String=["UI20_reconstruction","UI20b_reconstruction","UI20c_reconstruction","UI20d_reconstruction"][photo_record_tab];var id: String="SVG_jing_ui20_24_reconstruction_20261024_"+suffix
	if photo_record_tab==0:
		use_layout(id,[31,35,40,45,50,51,52,56,58]);var short: Dictionary={"完整证据已经转移":"完整证据","核心十六张已经转移":"核心证据","核心十六张已经选出":"核心已选","至少三十张已经加印":"至少三十","已经秘密加印":"已有加印","看见暴行影像":"亲见影像","尚未接触":"尚未接触"}
		design_text(id,31,"已达阶段："+short[data.stage]);design_text(id,35,str(int(data.prints)));design_text(id,40,str(int(data.selected)));design_text(id,45,str(int(data.transferred)))
		design_text(id,50,"身份："+("照相馆帮工" if data.employed else "尚未上工"));design_text(id,51,"熟练："+data.skill);design_text(id,52,"受注意情况："+data.attention)
		design_text(id,56,"这一段记录已收束。" if data.terminal else "这里只核对已发生的记录。")
		design_text(id,58,"这里只核对已留下的材料，不再开始新的照片工作。" if data.terminal else "回到当天实际场景，才能执行可用的照片工作。")
		hit("records_back",Rect2(1086,747,111,49),func():screen=records_return_screen,"回到原页面，不改变日期或知识")
	elif photo_record_tab==1:
		use_layout(id,[37,39,40,41,46,47,48,49]);var d: Dictionary=data.disclosure
		var entries: Array=d.entries;var legacy: Variant=d.legacyPhoto27;var aggregate: Variant=d.legacy;var name: String="暂无可证记录";var day: String="尚未记录";var scope: String="不补写未发生的交谈。";var detail: String="记录只限实际说出的内容。"
		if d.invalid:name="记录待核对";day="未通过校验";scope="不据此判断新增知情。";detail="旧记录另列；不把异常记录扩展为全家知情。"
		elif not entries.is_empty():name=entries[0].recipient;day="第"+str(int(entries[0].day))+"日";scope=entries[0].scopeLabel;detail="来自已确认交谈。未告知数量与藏处，不等于承诺代做。"
		elif legacy!=null:name=legacy.recipient;day="第34日旧记录";scope="曾谈及胶卷、加印与暗室藏处。";detail="只证明母亲当时听过，不推定其他家人或后续承诺。"
		elif aggregate!=null:name=aggregate.recipient;day="旧记录未注明日期";scope=aggregate.scopeLabel;detail="不补写旧记录没有注明的范围、数量或藏处。"
		design_text(id,37,name);design_text(id,39,day);design_text(id,40,scope);prose(detail,Rect2(829,575,480,64),19)
		design_text(id,46,"历史记录边界：")
		prose("\n".join(data.disclosure_lines) if not data.disclosure_lines.is_empty() else "当前没有可证的家人告知记录，不补造一次谈话。",Rect2(390,716,805,96),19)
		design_text(id,49,"只显示实际记录，不扩大知情范围。")
		hit("records_back",Rect2(1191,772,123,55),func():screen=records_return_screen,"回到原页面")
	elif photo_record_tab==2:
		use_layout(id,[36,42,43,46,47,50,51,54,55,61]);var d: Dictionary=data.deadline
		var clocks: Dictionary={"inactive":"店铺期限尚未公布","announced":"店铺期限已公布","urgent":"店铺期限正在临近","final_day":"店铺最后期限已到","resolved":"期限记录已收束","stopped":"记录中断，期限停止"}
		design_text(id,36,"期限记录待核对" if not data.deadline_valid else ("这一段期限已收束" if data.terminal and not d.failure else clocks.get(d.clock,"期限记录待核对")))
		for row in [["罗瑾",42,43],["母亲",46,47],["外祖父",50,51],["安仁叔叔",54,55]]:
			var person: Dictionary=d.people.filter(func(p):return p.name==row[0])[0];var label: String="尚无已获知记录";var why: String="不从系统日期推定此人已经得知。"
			if not data.deadline_valid:label="记录未通过校验";why="暂不据此显示个人获知日期。"
			elif person.known:
				label="已有旧记录，日期未明" if person.acquiredDay==null else "第"+str(int(person.acquiredDay))+"日获知"
				why={"shop_delivery":"当时听到了店铺传来的期限通知。","family_relay":"由已知情家人实际转述期限消息。","observed_deadline_scene":"在实际确认的期限告知现场听清。"}.get(person.sourceKind,"旧记录未注明具体传达来源。")
			design_text(id,row[1],label);design_text(id,row[2],why)
		design_text(id,61,"系统期限与逐人获知分开核对。")
		hit("records_back",Rect2(1195,790,127,58),func():screen=records_return_screen,"回到原页面")
	else:
		use_layout(id,[32,36,41,42,46,47,51,52,56,57,61,65,102,103,106]);var r: Dictionary=data.route
		design_text(id,32,"旧记录未注明逐人接收情况。" if r.legacy else "路线提醒按实际接收者分别记录。")
		design_text(id,36,"逐人接收记录：")
		for row in [["player",41,42],["罗瑾",46,47],["母亲",51,52],["外祖父",56,57],["安仁叔叔",61,-1]]:
			var person: Dictionary=r.people.filter(func(p):return p.name==row[0])[0];var label: String="尚无已接收记录。";var why: String="不从他人知情推定本人已经听过。"
			if not data.route_valid:label="路线记录待核对。";why="未通过校验，不展示个人获知日期。"
			elif person.known:label="第"+str(int(person.acquiredDay))+"日"+("亲见。" if person.mode=="witnessed" else "收到转述。");why="只涉及普通路线，不是照片秘密。"
			elif r.legacy:label="旧记录未注明本人。";why="不将聚合提醒补写成逐人接收。"
			design_text(id,row[1],label)
			if row[2]>=0:design_text(id,row[2],why)
		var receipt: Dictionary=r.receipt;var executed: bool=data.route_valid and receipt.status in ["arrived","retreated"]
		if executed:
			design_text(id,65,"第"+str(int(receipt.day))+"日 · "+("已经到位" if receipt.status=="arrived" else "退回原处"));var amount:=native_text(str(int(receipt.amount))+" 张",Rect2(1108,623,164,61),42);amount.add_theme_color_override("font_color",Color("8c211a"))
			design_text(id,102,"位置："+receipt.location if receipt.status=="arrived" else "本次没有新增转移。")
			design_text(id,103,"只计本次已执行结果。")
		else:
			design_text(id,65,"回执记录待核对。" if receipt.status=="invalid" or not data.route_valid else "尚无可展示的已执行回执。")
			design_text(id,102,"未执行的安排不是成果；");design_text(id,103,"这里不预告成败、数量或藏处。")
		design_text(id,106,"只展示当前可核对的记录。")
		hit("records_back",Rect2(1223,847,121,56),func():screen=records_return_screen,"回到原页面")
	record_tabs(id)

func _aux_parent_0__unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F7 and screen!="menu" and model.state.has("photo"):
		if screen=="photoRecords":screen=records_return_screen
		else:open_photo_records()
		render_screen();get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F5:
		if screen!="save":open_saves();render_screen()
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F6:
		if screen=="settings":screen=settings_return_screen
		else:open_reading_settings()
		render_screen();get_viewport().set_input_as_handled()

func _aux_parent_0_begin_game(seed: String="") -> void:
	model.new_game(seed if not seed.is_empty() else str(int(Time.get_unix_time_from_system()*1000)))
	continuation=Continuation.new();save_store.active_proof={};focus_choice_page=0
	screen="intro"

func _aux_parent_0_render_menu() -> void:
	present_layout({"canvas":[1920,1080],"operations":[]})
	for key in ["m0","title"]:image_node(menu_contract.assets[key].path,Rect2(0,0,1920,1080))
	var titles=["开始游戏","继续游戏","存档管理","设置","玩法说明","反馈"]
	for i in range(titles.size()):
		var b:=hit("menu_"+str(i),Rect2(272,274+i*82,298,73),func():
			if i==0:begin_game()
			elif i==1:continue_saved()
			elif i==2:open_saves()
			elif i==3:open_reading_settings(),titles[i])
		b.text=titles[i];b.add_theme_font_override("font",fonts[FONT_REG+"#2"]);b.add_theme_font_size_override("font_size",30)
		b.add_theme_color_override("font_color",Color("dfc9a0"))
		var bg:=StyleBoxFlat.new();bg.bg_color=Color("211c17dd");bg.border_color=Color("9b805381");bg.set_border_width_all(1);bg.border_width_left=3;bg.set_corner_radius_all(2)
		b.add_theme_stylebox_override("normal",bg)
		var hover:=bg.duplicate();hover.bg_color=Color("d1bb90");b.add_theme_stylebox_override("hover",hover);b.add_theme_color_override("font_hover_color",Color("292118"))
		# Do not wire unimplemented routes to fake dialogs or start a new game.
		if i==1:b.disabled=not FileAccess.file_exists(save_path) and not FileAccess.file_exists(save_path+".bak")
		elif i>3:b.disabled=true;b.tooltip_text="开发候选：此入口尚未接入"
	native_text(save_notice if not save_notice.is_empty() else "原生迁移开发候选 · F5 保存与恢复 · F6 阅读设置 · 未完成入口暂不可用",Rect2(45,1020,1500,40),16)

func _aux_parent_0_render_screen() -> void:
	controls.clear();primary_bindings.clear();transition_pending=false
	match screen:
		"menu":render_menu()
		"save":render_saves()
		"focus":render_day_focus()
		"focusEvent":render_day_focus_event()
		"focusResult":render_day_focus_result()
		"focusReturn":render_day_focus_return()
		"focusDiary":render_day_focus_diary()
		"intro":render_intro()
		"tutorial":render_tutorial()
		"loadout":render_loadout()
		"event":render_road()
		"report":render_arrival()
		"diary":render_diary()
		"night":render_night_plan()
		"animalEncounter":render_animal_encounter()
		"nightEvent":render_night_event()
		"morning":render_morning()
		"end":render_native_ending()
		"photoRecords":render_photo_records()
		"settings":render_reading_settings()
		_:render_unconnected()

var system_return_screen: String=""

var live_return_screen: String=""

func bind_system_toolbar() -> void:
	if screen in ["menu","settings","save","animalEncounter","photoRecords","end","help","feedback","disk","diskConfirm"]:return
	for op in current.get("operations",[]):
		if op.get("type")!="text":continue
		if op.get("text") in ["菜单","菜单 ☰"]:hit("toolbar_system_menu",toolbar_box(op),func():open_system_menu(),"打开系统菜单，不推进游戏")
		elif op.get("text")=="记录":
			var button:=hit("toolbar_record_menu",toolbar_box(op),func():open_record_menu(),"查看公开记录，不推进游戏");button.disabled=not public_home_allowed()

func open_system_menu() -> void:
	if screen!="systemMenu":system_return_screen=screen
	screen="systemMenu"

func render_system_menu() -> void:
	_aux_parent_3_render_system_menu();reconnect_button("system_feedback",func():open_native_feedback());controls.system_feedback.tooltip_text="填写与导出本机反馈；未连接在线提交"

func render_main_menu_confirmation() -> void:
	var id: String="UI25_daytime";use_layout(id,[2,4,9,10,11,14,17])
	design_text(id,2,"返回主菜单");design_text(id,4,"返回菜单不清空本次会话，也不重新开始")
	design_text(id,9,"本次会话仍可返回当前页面。");design_text(id,10,"关闭窗口时会尝试保存；失败会再次确认。");design_text(id,11,"取消会回到系统菜单，不改变当前决定。")
	design_text(id,14,"确认返回主菜单");design_text(id,17,"留在这里")
	var confirm_box:=Rect2(594,677,490,60);var cancel_box:=Rect2(604,747,470,60)
	hit("system_confirm_main",confirm_box,func():live_return_screen=system_return_screen;screen="menu","返回菜单，不清空当前进度")
	hit("system_cancel_main",cancel_box,func():screen="systemMenu","取消返回主菜单")

func rice_count_pending() -> bool:
	if model.state.is_empty():return false
	var s: Dictionary=model.state;var cycle: Dictionary=model._object(s.get("nightCycle"))
	return s.get("phase")=="nightEvent" and cycle.get("readingRevision")=="R3" and cycle.get("status")=="awaiting_event" and s.get("pendingNightEvent")==null and model._object(cycle.get("readingEvent")).get("type")=="mouse"

func public_resource_number(key: String) -> float:
	var value: float=float(model.state.get(key,0))
	if key=="rice" and rice_count_pending():value+=float(model._object(model._object(model.state.get("nightCycle")).get("mouseOutcome")).get("lost",0))
	return value

func public_number(value: float) -> String:return str(int(value)) if value==floor(value) else str(value)

func public_rice_hud() -> String:return public_number(public_resource_number("rice"))+(" 待清点" if rice_count_pending() else " 米粮")

func _aux_parent_1__unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE and screen in ["systemMenu","confirmMainMenu"]:
		screen=system_return_screen if screen=="systemMenu" else "systemMenu";render_screen();get_viewport().set_input_as_handled();return
	_aux_parent_0__unhandled_key_input(event)
# Preserve the source's delayed mouse-loss visibility until the morning count.


func _aux_parent_1_render_menu() -> void:
	_aux_parent_0_render_menu()
	if not model.state.is_empty() and model.state.get("ended",false):live_return_screen="end"
	if live_return_screen.is_empty() or model.state.is_empty():return
	var button:=hit("menu_live_resume",Rect2(1650,999,230,51),func():screen=live_return_screen,"返回当前页面，不读取磁盘")
	button.text="返回当前页面";button.add_theme_font_override("font",fonts[FONT_REG+"#2"]);button.add_theme_font_size_override("font_size",20);button.add_theme_color_override("font_color",Color("ead7b3"))
	var style:=StyleBoxFlat.new();style.bg_color=Color("241e18de");style.border_color=Color("bda47a");style.set_border_width_all(1);button.add_theme_stylebox_override("normal",style)


func _aux_parent_1_render_screen() -> void:
	if screen in ["systemMenu","confirmMainMenu"]:
		controls.clear();primary_bindings.clear();transition_pending=false
		if screen=="systemMenu":render_system_menu()
		else:render_main_menu_confirmation()
	else:
		_aux_parent_0_render_screen()
		bind_system_toolbar()


func _aux_parent_1_render_system_menu() -> void:
	var hidden: Array=[5,6,8,10,12]
	for row in [["母亲",1],["罗瑾",2],["安仁叔叔",3],["外祖父",4]]:
		if not model.present(row[0]):hidden.append(row[1])
	use_layout("UI29_normal",hidden)
	design_text("UI29_normal",5,date_label());design_text("UI29_normal",6,model.current_weather().name+" · 菜单")
	design_text("UI29_normal",8,public_rice_hud());design_text("UI29_normal",10,str(int(model.state.water))+" / "+str(int(model.state.waterCap))+" 饮水");design_text("UI29_normal",12,str(int(model.state.wood))+" 木料")
	hit("system_close",Rect2(1558,131,48,46),func():screen=system_return_screen,"收起菜单，返回原阶段")
	hit("system_resume",Rect2(1257,193,329,83),func():screen=system_return_screen,"继续原页面，不重新读取磁盘")
	hit("system_save",Rect2(1257,282,329,83),func():open_saves(),"打开原生保存与恢复")
	hit("system_reading",Rect2(1257,460,329,83),func():open_reading_settings(),"阅读设置，只改显示")
	hit("system_main_menu",Rect2(1257,727,329,93),func():screen="confirmMainMenu","返回主菜单前确认")
	# Separate approved screens are the next batch, not silently aliased to another page.
	for row in [["disk",371],["help",549],["feedback",638]]:
		var button:=hit("system_"+row[0],Rect2(1257,row[1],329,83),func():pass,"开发候选：此独立页面尚未接线")
		button.disabled=true


var help_page:=0

var help_return_screen: String="menu"

var help_data: Dictionary={}

func reconnect_button(id: String,callback: Callable) -> void:
	var button: Button=controls[id]
	for connection in button.pressed.get_connections():button.pressed.disconnect(connection.callable)
	button.disabled=false
	button.pressed.connect(func():
		if transition_pending:return
		transition_pending=true;callback.call();call_deferred("render_screen"))

func open_native_help() -> void:
	help_return_screen=screen;screen="help"

func render_native_help() -> void:
	if help_data.is_empty():help_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/native_help.json"))
	_save_ux_parent_0_render_native_help()

func add_help_scroll(body: RichTextLabel) -> void:
	var bar:=body.get_v_scroll_bar();bar.hide()
	var thumb:=ColorRect.new();thumb.name="help_scroll_thumb";thumb.color=Color("a59376");thumb.position=Vector2(1373.5,224);thumb.size=Vector2(9,157);thumb.mouse_filter=Control.MOUSE_FILTER_IGNORE;holder.add_child(thumb)
	var track:=Control.new();track.position=Vector2(1368,224);track.size=Vector2(20,484);track.mouse_filter=Control.MOUSE_FILTER_STOP;holder.add_child(track)
	track.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index==MOUSE_BUTTON_WHEEL_UP:bar.value-=45
			elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:bar.value+=45
			elif event.button_index==MOUSE_BUTTON_LEFT:bar.value=clampf((event.position.y-thumb.size.y/2)/maxf(1,484-thumb.size.y),0,1)*maxf(0,bar.max_value-bar.page)
			track.accept_event()
		elif event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:bar.value=clampf((event.position.y-thumb.size.y/2)/maxf(1,484-thumb.size.y),0,1)*maxf(0,bar.max_value-bar.page);track.accept_event())
	bar.value_changed.connect(func(_v):sync_help_scroll(bar,thumb))
	ending_scroll_button("help_scroll_up",Rect2(1364,202,28,22),func():bar.value-=65)
	ending_scroll_button("help_scroll_down",Rect2(1364,704,28,25),func():bar.value+=65)
	call_deferred("initialize_help_scroll",weakref(body),weakref(thumb))

func sync_help_scroll(bar: VScrollBar,thumb: ColorRect) -> void:
	var span: float=maxf(0,bar.max_value-bar.page);thumb.size.y=clampf(484*bar.page/maxf(1,bar.max_value),24,157);thumb.position.y=224+(484-thumb.size.y)*(bar.value/span if span>0 else 0);thumb.visible=span>0

func initialize_help_scroll(body_ref,thumb_ref) -> void:
	await get_tree().process_frame
	var body=body_ref.get_ref();var thumb=thumb_ref.get_ref()
	if not is_instance_valid(body) or not is_instance_valid(thumb):return
	var bar: VScrollBar=body.get_v_scroll_bar();bar.hide();sync_help_scroll(bar,thumb)

func _aux_parent_2__unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE and screen=="help":screen=help_return_screen;render_screen();get_viewport().set_input_as_handled();return
	_aux_parent_1__unhandled_key_input(event)


func _aux_parent_2_render_screen() -> void:
	if screen=="help":
		controls.clear();primary_bindings.clear();transition_pending=false;render_native_help()
	else:_aux_parent_1_render_screen()


func _aux_parent_2_render_system_menu() -> void:
	_aux_parent_1_render_system_menu();reconnect_button("system_help",func():open_native_help())
	controls.system_help.tooltip_text="阅读十一条说明，不推进游戏"


var disk_return_screen: String="systemMenu"

var disk_info: Dictionary={}

var disk_notice: String=""

var disk_action: String=""

var disk_pending_state: PackedByteArray

var disk_pending_proof: PackedByteArray

var disk_pending_fingerprint: String=""

var disk_pending_read_path: String=""

var disk_pending_text: String=""

func open_native_disk() -> void:
	disk_return_screen=screen;screen="disk";disk_notice="";inspect_native_disk()

func inspect_native_disk() -> void:
	var reader=SaveStore.new();var probe=Model.new();var result: Dictionary=reader.load_from(save_path,probe)
	if not result.ok:disk_info={"ok":false,"reason":result.get("reason","UNKNOWN")};return
	var path: String=save_path+(".bak" if result.source=="backup" else "")
	var envelope=JSON.parse_string(FileAccess.get_file_as_string(path))
	disk_info={"ok":true,"source":result.source,"state":probe.state.duplicate(true),"proof":reader.decoded_proof.duplicate(true),"path":path,"fingerprint":reader.file_fingerprint(path),"revision":envelope.get("revision",0)}

func render_native_disk() -> void:
	var hidden: Array=[7,8,12,13,14,15,17,33,34]
	if not disk_info.get("ok",false):hidden.append(16)
	use_layout("UI24",hidden)
	design_text("UI24",7,"已读回并校验本机文件。" if disk_info.get("ok",false) else "尚无可用的本机记录。")
	design_text("UI24",8,"使用已验证的备用文件；主文件不可用。" if disk_info.get("source")=="backup" else "查看与预览均不会自动写盘。")
	design_text("UI24",12,"存档格式");design_text("UI24",13,state_summary(model.state));design_text("UI24",14,state_summary(disk_info.state) if disk_info.get("ok",false) else "没有可恢复记录")
	design_text("UI24",15,"V"+str(int(disk_info.revision)) if disk_info.get("ok",false) else "未校验")
	design_text("UI24",17,disk_notice if not disk_notice.is_empty() else ("文件校验："+str(disk_info.fingerprint).substr(0,12) if disk_info.get("ok",false) else "可先预览写入；无效记录不会覆盖当前进度。"))
	design_text("UI24",33,"本机用户数据目录");design_text("UI24",34,"主文件与 .bak 备用文件分开核对。")
	hit("disk_inspect",Rect2(416,554,257,91),func():disk_notice="";inspect_native_disk(),"只读核对文件，不加载到当前游戏")
	var write:=hit("disk_preview_write",Rect2(687,554,287,91),func():prepare_disk_action("write"),"预览当前进度；确认前不写入");write.disabled=model.state.is_empty()
	var restore:=hit("disk_preview_restore",Rect2(991,554,270,91),func():prepare_disk_action("restore"),"预览磁盘进度；确认前不替换");restore.disabled=not disk_info.get("ok",false)
	hit("disk_back",Rect2(1162,715,111,52),func():screen=disk_return_screen,"返回原菜单")

func prepare_disk_action(action: String) -> void:
	disk_action=action;disk_pending_state=var_to_bytes(model.state);disk_pending_proof=var_to_bytes(continuation.proof());disk_pending_text=""
	var reader=SaveStore.new()
	if action=="write":
		if model.state.is_empty():return
		var proof: Dictionary=continuation.proof() if not continuation.actions.is_empty() else {}
		disk_pending_text=encode_candidate(model.state,proof)
		if disk_pending_text.is_empty():disk_notice="当前进度尚未通过保存校验。";return
		disk_pending_read_path=save_path;disk_pending_fingerprint=reader.file_fingerprint(save_path)
	else:
		inspect_native_disk()
		if not disk_info.get("ok",false):disk_notice="没有可恢复的已校验文件。";return
		disk_pending_read_path=disk_info.path;disk_pending_fingerprint=disk_info.fingerprint;disk_pending_text=FileAccess.get_file_as_string(disk_pending_read_path)
	screen="diskConfirm"

func render_disk_confirmation() -> void:
	var id: String="UI25_daytime";use_layout(id,[2,4,9,10,11,14,17])
	design_text(id,2,"确认写入本机文件" if disk_action=="write" else "确认恢复磁盘记录")
	design_text(id,4,state_summary(model.state) if disk_action=="write" else state_summary(disk_info.get("state",{})))
	design_text(id,9,"写入前再核对当前进度与文件。" if disk_action=="write" else "恢复会替换当前进度，不会合并。")
	design_text(id,10,"旧的有效主文件会保留为备用。" if disk_action=="write" else "替换前先备份当前未保存进度。")
	design_text(id,11,"取消不写盘，也不改变当前游戏。");design_text(id,14,"确认写入" if disk_action=="write" else "确认恢复");design_text(id,17,"取消，返回预览")
	hit("disk_confirm",Rect2(594,677,490,60),func():commit_disk_action(),"确认这一次预览")
	hit("disk_cancel",Rect2(604,747,470,60),func():screen="disk";disk_action="", "取消，不写入或恢复")

func commit_disk_action() -> void:
	_save_ux_parent_0_commit_disk_action();adopt_primary_if_current()

func _aux_parent_3__unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE and screen in ["disk","diskConfirm"]:
		screen=disk_return_screen if screen=="disk" else "disk";disk_action="";render_screen();get_viewport().set_input_as_handled();return
	_aux_parent_2__unhandled_key_input(event)


func _aux_parent_3_render_menu() -> void:
	_aux_parent_1_render_menu();reconnect_button("menu_4",func():open_native_help())


func _aux_parent_3_render_screen() -> void:
	if screen in ["disk","diskConfirm"]:
		controls.clear();primary_bindings.clear();transition_pending=false
		if screen=="disk":render_native_disk()
		else:render_disk_confirmation()
	else:_aux_parent_2_render_screen()


func _aux_parent_3_render_system_menu() -> void:
	_aux_parent_2_render_system_menu();reconnect_button("system_disk",func():open_native_disk());controls.system_disk.tooltip_text="本机磁盘：先预览，再确认写入或恢复"


const FEEDBACK_ISSUES=["不知道下一步","文本重复／矛盾","文本太少","角色不够鲜明","选择没有意义","生存太难","生存太容易","道具用途不清","按钮／界面问题","存档问题"]

var feedback_return_screen: String="menu"

var feedback_view: String="upper"

var feedback_draft_path: String="user://jing-native-feedback-draft.json"

var feedback_draft: Dictionary={}

var feedback_notice: String=""

var feedback_popup: Dictionary={}

var feedback_editor: TextEdit

var feedback_show_context:=false

func feedback_options(key: String) -> Array:
	var values: Array=[]
	match key:
		"category":values=["试玩感受","看不懂／不会操作","剧情与文本问题","程序错误／卡住","其他建议"]
		"module":values=["主线与历史氛围","罗瑾／照相馆","母亲","外祖父","安仁叔叔","棚区邻里","动物","远行与寻找","夜间威胁","生存与疾病","教程／UI／存档","结局"]
		"duration":values=["10分钟内","10—30分钟","30—60分钟","超过1小时"]
		"overall","clarity":return [["","暂不评价／未体验"],["1","1 · 很差／很不清楚"],["2","2 · 较差"],["3","3 · 一般"],["4","4 · 较好"],["5","5 · 很好／很清楚"]]
		"pace":return [["","暂不评价／未体验"],["太简略","太简略，想读更多"],["合适","基本合适"],["拖沓","偏长或拖沓"]]
		"continuePlay":return [["","暂不评价／未体验"],["想","想继续"],["不确定","不确定"],["暂时不想","暂时不想"]]
	var result: Array=[] if key=="category" else [["","暂不评价／未体验"]]
	for value in values:result.append([value,value])
	return result

func feedback_context() -> Dictionary:
	if model.state.is_empty():return {"version":"native-C9-ui-candidate","phase":"menu","day":null,"event":"","seed":""}
	var s: Dictionary=model.state;var f: Dictionary=model._object(s.get("focus"));var event: Dictionary=model._object(f.get("laterEvents")).get(f.get("eventId",""),{});var title: String=event.get("title","") if f.get("day")==s.day else ""
	if s.phase=="nightEvent":title=model._object(s.get("pendingNightEvent")).get("title","夜间事件")
	return {"version":"native-C9-ui-candidate","day":mini(49,int(s.day)+1),"phase":s.phase,"event":title,"seed":s.seed}

func ensure_feedback_draft() -> void:
	if not feedback_draft.is_empty():return
	feedback_draft={"id":"","category":"试玩感受","module":"","overall":"","clarity":"","pace":"","continuePlay":"","duration":"","issues":[],"comment":"","includeContext":true,"consent":false,"context":null}
	if not FileAccess.file_exists(feedback_draft_path):return
	var text: String=FileAccess.get_file_as_string(feedback_draft_path)
	if text.length()>65536:return
	var stored=JSON.parse_string(text)
	if not stored is Dictionary:return
	for key in ["category","module","overall","clarity","pace","continuePlay","duration"]:
		if stored.get(key) is String and feedback_options(key).any(func(row):return row[0]==stored[key]):feedback_draft[key]=stored[key]
	if stored.get("comment") is String:feedback_draft.comment=stored.comment.substr(0,2000)
	for key in ["includeContext","consent"]:
		if stored.get(key) is bool:feedback_draft[key]=stored[key]
	if stored.get("issues") is Array:
		for issue in stored.issues:
			if issue is String and issue in FEEDBACK_ISSUES and issue not in feedback_draft.issues:feedback_draft.issues.append(issue)
	# Retain the original report location, but export only the declared small context.
	if stored.get("context") is Dictionary:
		var c: Dictionary=stored.context;var valid: bool=c.get("day")==null or (typeof(c.get("day")) in [TYPE_INT,TYPE_FLOAT] and c.day>=0 and c.day<=49)
		for key in ["version","phase","event","seed"]:valid=valid and c.get(key) is String
		if valid:feedback_draft.context={"version":c.version.substr(0,80),"day":c.day,"phase":c.phase.substr(0,40),"event":c.event.substr(0,300),"seed":c.seed.substr(0,128)}
	# Do not load arbitrary extra metadata from a draft into an exported context.
	if stored.get("id") is String and stored.id.length()==36:feedback_draft.id=stored.id

func persist_feedback() -> bool:
	var text:=JSON.stringify(feedback_draft);var temp: String=feedback_draft_path+".tmp";var file=FileAccess.open(temp,FileAccess.WRITE)
	if file==null:feedback_notice="草稿仍在当前窗口，尚未保存到本机。";return false
	file.store_string(text);file.flush();var ok: bool=file.get_error()==OK;file.close()
	if not ok or DirAccess.rename_absolute(temp,feedback_draft_path)!=OK:feedback_notice="草稿仍在当前窗口，尚未保存到本机。";return false
	return true

func open_native_feedback() -> void:
	ensure_feedback_draft();feedback_return_screen=screen;screen="feedback";feedback_popup={};feedback_show_context=false
	if feedback_draft.context==null:feedback_draft.context=feedback_context()
	persist_feedback()

func feedback_tick(box: Rect2) -> void:image_node(op_from("UI22_selected_19_toggle_on",95).path,Rect2(box.position+Vector2(4,4),Vector2(22,21)))

func render_native_feedback() -> void:
	ensure_feedback_draft()
	if feedback_view=="upper":render_feedback_upper()
	else:render_feedback_comment()
	if not feedback_popup.is_empty():render_feedback_popup()

func render_feedback_upper() -> void:
	var id: String="UI26_upper";use_layout(id,[13,18,23,28,33,38,44])
	for row in [["category",13,12],["duration",18,17],["clarity",23,22],["continuePlay",28,27],["module",33,32],["overall",38,37],["pace",44,43]]:
		var key: String=row[0];var options: Array=feedback_options(key);var selected: Array=options.filter(func(o):return o[0]==feedback_draft[key]);design_text(id,row[1],selected[0][1] if not selected.is_empty() else "暂不评价／未体验")
		var b: Array=op_from(id,row[2]).box;var box:=Rect2(b[0],b[1],b[2],b[3]);hit("feedback_field_"+key,box,func():feedback_popup={"key":key,"box":box},key)
	for i in range(FEEDBACK_ISSUES.size()):
		var issue: String=FEEDBACK_ISSUES[i];var box:=Rect2(467 if i<5 else 875,631+(i%5)*39,30,30)
		if issue in feedback_draft.issues:feedback_tick(box)
		hit("feedback_issue_"+str(i),Rect2(box.position,Vector2(320,35)),func():
			if issue in feedback_draft.issues:feedback_draft.issues.erase(issue)
			else:feedback_draft.issues.append(issue)
			persist_feedback(),issue)
	hit("feedback_back",Rect2(1105,126,134,60),func():persist_feedback();screen=feedback_return_screen,"返回原页面")
	hit("feedback_lower",Rect2(451,849,785,76),func():feedback_view="comment","查看文字说明与导出")

func render_feedback_popup() -> void:
	for b in controls.values():b.disabled=true
	var shade:=ColorRect.new();shade.size=Vector2(current.canvas[0],current.canvas[1]);shade.color=Color(0,0,0,0.12);shade.mouse_filter=Control.MOUSE_FILTER_STOP;holder.add_child(shade)
	hit("feedback_popup_cancel",Rect2(Vector2.ZERO,shade.size),func():feedback_popup={},"收起选项，不改变选择")
	var options: Array=feedback_options(feedback_popup.key);var box: Rect2=feedback_popup.box;var width: float=maxf(340,box.size.x);var height: float=options.size()*34.0;var origin:=Vector2(minf(box.position.x,current.canvas[0]-width-12),minf(box.end.y+2,current.canvas[1]-height-12))
	var paper:=ColorRect.new();paper.color=Color("f4e7ce");paper.position=origin;paper.size=Vector2(width,height);paper.mouse_filter=Control.MOUSE_FILTER_IGNORE;holder.add_child(paper)
	for i in range(options.size()):
		var value: String=options[i][0];var key: String=feedback_popup.key;native_text(options[i][1],Rect2(origin+Vector2(9,i*34+2),Vector2(width-18,32)),19)
		hit("feedback_option_"+str(i),Rect2(origin+Vector2(0,i*34),Vector2(width,34)),func():feedback_draft[key]=value;feedback_popup={};persist_feedback(),options[i][1])

func render_feedback_comment() -> void:
	var id: String="UI26_normal";use_layout(id,[9,20,27])
	design_text(id,9,"将附带的定位信息（只读）" if feedback_show_context else "最想改的一件事：发生了什么、哪里不明白，或希望怎么改？")
	design_text(id,20,"未配置在线提交");design_text(id,27,feedback_notice if not feedback_notice.is_empty() else "未在线提交。导出文件不会自动发送给制作方。")
	if feedback_show_context:
		prose(JSON.stringify(feedback_draft.context,"  "),Rect2(466,376,745,100),19)
		native_text("更新为当前位置",Rect2(1004,481,202,28),18)
		hit("feedback_refresh_context",Rect2(990,477,220,35),func():feedback_draft.context=feedback_context();persist_feedback(),"只更新这份反馈的定位信息")
	else:
		feedback_editor=TextEdit.new();feedback_editor.name="feedback_comment";feedback_editor.position=Vector2(466,376);feedback_editor.size=Vector2(745,132);feedback_editor.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;feedback_editor.text=feedback_draft.comment;feedback_editor.placeholder_text="请描述实际遇到的问题，不填写个人信息。"
		feedback_editor.add_theme_font_override("font",fonts[FONT_REG+"#2"]);feedback_editor.add_theme_font_size_override("font_size",20);feedback_editor.add_theme_color_override("font_color",Color("372b21"));feedback_editor.add_theme_color_override("font_placeholder_color",Color("8d765c"))
		for style in ["normal","focus","read_only"]:feedback_editor.add_theme_stylebox_override(style,StyleBoxEmpty.new())
		feedback_editor.text_changed.connect(func():
			var text: String=feedback_editor.text.substr(0,2000)
			if feedback_editor.text!=text:feedback_editor.text=text
			feedback_draft.comment=text;persist_feedback())
		holder.add_child(feedback_editor)
	for row in [["includeContext",Rect2(455,574,30,30)],["consent",Rect2(455,617,30,30)]]:
		var key: String=row[0];var box: Rect2=row[1]
		if feedback_draft[key]:feedback_tick(box)
		hit("feedback_"+key,Rect2(box.position,Vector2(585,35)),func():feedback_draft[key]=not feedback_draft[key];persist_feedback(),"切换本项")
	hit("feedback_context",Rect2(1044,574,192,35),func():feedback_show_context=not feedback_show_context,"查看或收起定位信息；不含整份存档")
	var submit:=hit("feedback_submit",Rect2(521,683,253,60),func():pass,"未配置在线提交地址；请导出本机文件");submit.disabled=true
	hit("feedback_export",Rect2(811,683,234,60),func():choose_feedback_export(),"导出本机 JSON，不在线发送")
	hit("feedback_back",Rect2(1083,683,151,60),func():persist_feedback();screen=feedback_return_screen,"保留草稿并返回")
	hit("feedback_upper",Rect2(1068,205,178,42),func():feedback_view="upper","返回上方评价选项")

func feedback_payload() -> Dictionary:
	if feedback_draft.id.is_empty():
		var bytes: PackedByteArray=Crypto.new().generate_random_bytes(16);bytes[6]=(bytes[6]&15)|64;bytes[8]=(bytes[8]&63)|128;var hex: String=bytes.hex_encode();feedback_draft.id=hex.substr(0,8)+"-"+hex.substr(8,4)+"-"+hex.substr(12,4)+"-"+hex.substr(16,4)+"-"+hex.substr(20,12)
	var answers: Dictionary={}
	for key in ["category","module","overall","clarity","pace","continuePlay","duration","issues","comment"]:answers[key]=feedback_draft[key]
	answers.comment=answers.comment.strip_edges()
	return {"schema":1,"id":feedback_draft.id,"answers":answers,"context":feedback_draft.context if feedback_draft.includeContext else null,"consent":feedback_draft.consent,"delivery":"仅导出，未在线提交"}

func write_feedback_file(path: String) -> bool:
	var text:=JSON.stringify(feedback_payload(),"  ");var file=FileAccess.open(path,FileAccess.WRITE)
	if file==null:feedback_notice="未能写入反馈文件，草稿仍保留。";return false
	file.store_string(text);file.flush();var ok: bool=file.get_error()==OK;file.close()
	if not ok or FileAccess.get_file_as_string(path)!=text:feedback_notice="未确认文件写入完成，草稿仍保留。";return false
	feedback_notice="已写入本机反馈文件，未发送给制作方。";persist_feedback();return true

func choose_feedback_export() -> void:
	var dialog:=FileDialog.new();dialog.access=FileDialog.ACCESS_FILESYSTEM;dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE;dialog.filters=PackedStringArray(["*.json ; 京字反馈文件"]);dialog.title="导出本机反馈（不会在线发送）";dialog.current_file="京字反馈.json";add_child(dialog)
	dialog.file_selected.connect(func(path: String):write_feedback_file(path);dialog.queue_free();render_screen());dialog.canceled.connect(func():feedback_notice="已取消导出，草稿仍保留。";dialog.queue_free();render_screen());dialog.popup_centered_ratio(0.7)

func _unhandled_input(event: InputEvent) -> void:
	if screen!="feedback" or not feedback_popup.is_empty() or not event is InputEventMouseButton or not event.pressed:return
	if event.button_index==MOUSE_BUTTON_WHEEL_DOWN and feedback_view=="upper":feedback_view="comment"
	elif event.button_index==MOUSE_BUTTON_WHEEL_UP and feedback_view=="comment":feedback_view="upper"
	else:return
	render_screen();get_viewport().set_input_as_handled()

func _aux_parent_4__unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE and screen=="feedback":
		if not feedback_popup.is_empty():feedback_popup={}
		else:persist_feedback();screen=feedback_return_screen
		render_screen();get_viewport().set_input_as_handled();return
	_aux_parent_3__unhandled_key_input(event)


func _aux_parent_4_open_photo_records() -> void:
	if screen!="photoRecords":records_return_screen=screen
	photo_record_tab=0;screen="photoRecords"

func _aux_parent_4_render_native_ending() -> void:
	if not model.state.people["罗瑾"].alive or model.state.get("endingType")=="luo_death_failure":render_terminal_failure();return
	ending_view_data=model.native_ending_view()
	if not ending_view_data.get("ok",false) or not ending_view_data.normal:load_errors.append("unsupported normal terminal state");return
	var view: Dictionary=ending_view_data
	if view.prints==0 and view.transferred==0:
		var empty_layout: String="SVG_jing_ui13_16_reconstruction_20261024_UI16_no_photo_reconstruction_v02"
		use_layout(empty_layout,[6,9,12]);design_text(empty_layout,6,str(int(view.prints)));design_text(empty_layout,9,str(int(view.selected)));design_text(empty_layout,12,str(int(view.transferred)))
		hit("ending_restart",Rect2(685,750,340,75),func():screen="menu","返回主菜单；现有磁盘存档保留")
		return
	var layout_id: String="SVG_jing_ui13_16_reconstruction_20261024_UI16_reconstruction_v04"
	use_layout(layout_id,[11,21,22,23,33,35,36,37]);design_text(layout_id,33,view.ending.title);design_text(layout_id,35,str(int(view.prints)));design_text(layout_id,36,str(int(view.selected)));design_text(layout_id,37,str(int(view.transferred)))
	var text: String=view.ending.text+"\n\n"+"\n\n".join(view.family)
	var body:=prose(text,Rect2(438,437,790,130),22);body.name="ending_prose";body.scroll_active=true
	var bar:=body.get_v_scroll_bar();bar.hide()
	var operation: Dictionary=op_from(layout_id,11);var thumb:=image_node(operation.path,Rect2(1252,350,10,81));thumb.name="ending_scroll_thumb"
	var track:=Control.new();track.name="ending_scroll_track";track.position=Vector2(1247,350);track.size=Vector2(20,180);track.mouse_filter=Control.MOUSE_FILTER_STOP;track.tooltip_text="拖动或滚轮回看完整后记";holder.add_child(track)
	track.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index==MOUSE_BUTTON_WHEEL_UP:bar.value-=40
			elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:bar.value+=40
			elif event.button_index==MOUSE_BUTTON_LEFT:bar.value=clampf((event.position.y-thumb.size.y/2)/maxf(1,180-thumb.size.y),0,1)*maxf(0,bar.max_value-bar.page)
			track.accept_event()
		elif event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
			bar.value=clampf((event.position.y-thumb.size.y/2)/maxf(1,180-thumb.size.y),0,1)*maxf(0,bar.max_value-bar.page);track.accept_event())
	bar.value_changed.connect(func(_v):ending_scroll_offset=bar.value;sync_ending_thumb(bar,thumb))
	ending_scroll_button("ending_scroll_up",Rect2(1242,327,30,23),func():bar.value-=60)
	ending_scroll_button("ending_scroll_down",Rect2(1242,532,30,23),func():bar.value+=60)
	call_deferred("restore_ending_scroll",weakref(body),weakref(thumb))
	hit("ending_records",Rect2(476,736,333,70),func():open_photo_records(),"只读核对实际照片与逐人获知记录")
	hit("ending_menu",Rect2(1067,737,164,69),func():screen="menu","返回主菜单；不改动结局或磁盘存档")

func _aux_parent_4_render_screen() -> void:
	if screen=="feedback":
		controls.clear();primary_bindings.clear();transition_pending=false;render_native_feedback()
	else:_aux_parent_3_render_screen()


var book_return_screen: String="morning"

var family_return_screen: String="recordMenu"

var family_data: Array=[]

func public_home_allowed() -> bool:
	return not model.state.is_empty() and (int(model.state.day)>0 or model._object(model._object(model.state.get("memory")).get("opening")).get("settled",false))

func photo_records_visible() -> bool:return not model.state.is_empty() and model._object(model.state.get("photo")).get("unlocked",false)==true

func toolbar_box(text_op: Dictionary) -> Rect2:
	var xy: Array=text_op.xy;var fs: float=float(text_op.size);var result:=Rect2(xy[0]-8,xy[1]-fs-8,fs*str(text_op.text).length()+16,fs+20);var nearest: Dictionary={};var distance: float=INF
	for op in current.get("operations",[]):
		if op.get("type")!="image" or not op.has("box"):continue
		var b: Array=op.box
		if b[2]>100 or b[3]>100 or b[0]+b[2]>xy[0]+20 or xy[0]-(b[0]+b[2])>90 or absf(b[1]+b[3]/2.0-(xy[1]-fs/2.0))>50:continue
		var d: float=absf(xy[0]-b[0]-b[2])+absf(xy[1]-fs/2.0-b[1]-b[3]/2.0)
		if d<distance:distance=d;nearest=op
	if not nearest.is_empty():
		var b: Array=nearest.box;result=result.merge(Rect2(b[0]-4,b[1]-4,b[2]+8,b[3]+8))
	return result.intersection(Rect2(Vector2.ZERO,Vector2(current.canvas[0],current.canvas[1])))

func open_record_menu() -> void:
	if not public_home_allowed():return
	book_return_screen=screen;screen="recordMenu"

func open_public_family() -> void:
	if not public_home_allowed():return
	family_return_screen=screen;screen="family"

func add_display_op(operation: Dictionary) -> void:
	var op: Dictionary=operation.duplicate(true)
	if op.get("type")=="image" and not textures.has(op.path):
		var texture=load(op.path)
		if not texture is Texture2D:load_errors.append("missing component: "+str(op.path));return
		textures[op.path]=texture
	var layer = Layer.new()
	layer.current={"canvas":current["canvas"],"operations":[op]}
	layer.textures=textures
	layer.fonts=fonts
	layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.modulate.a=float(op.get("opacity",1))
	if op.has("clip"):
		var clip: Array=op["clip"]
		layer.position=Vector2(clip[0],clip[1])
		layer.size=Vector2(clip[2],clip[3])
		layer.coordinate_origin=layer.position
		layer.clip_contents=true
	else:layer.size=Vector2(current["canvas"][0],current["canvas"][1])
	if op["type"]=="image" and (op.has("fade_start") or op.has("fade_bottom_px") or op.has("fade_edge_px") or op.has("alpha_from_rgb") or op.has("shadow")):
		var shader := load("res://scripts/component_effects.gdshader")
		var mat := ShaderMaterial.new()
		mat.shader=shader
		var texture: Texture2D = textures[op["path"]]
		var region := Vector4(0,0,1,1)
		if op.has("region"):
			var src: Array=op["region"]
			region=Vector4(src[0]/texture.get_width(),src[1]/texture.get_height(),src[2]/texture.get_width(),src[3]/texture.get_height())
		var b: Array=op["box"]
		mat.set_shader_parameter("sample_region",region)
		mat.set_shader_parameter("component_size",Vector2(b[2],b[3]))
		for key in ["fade_start","fade_bottom_px","fade_edge_px"]:
			if op.has(key):mat.set_shader_parameter(key,float(op[key]))
		if op.has("alpha_from_rgb"):
			mat.set_shader_parameter("alpha_from_rgb",true)
			mat.set_shader_parameter("alpha_subtract",float(op["alpha_from_rgb"]["subtract"]))
			mat.set_shader_parameter("alpha_multiply",float(op["alpha_from_rgb"]["multiply"]))
		if op.has("shadow"):
			var effect: Dictionary=op["shadow"]
			var padding:=float(effect["blur"])*3.0
			var rgb: Array=effect["rgb"]
			mat.set_shader_parameter("is_shadow",true)
			mat.set_shader_parameter("padding",padding)
			mat.set_shader_parameter("blur_sigma",float(effect["blur"]))
			mat.set_shader_parameter("output_size",Vector2(b[2]+2*padding,b[3]+2*padding))
			mat.set_shader_parameter("shadow_color",Vector4(rgb[0]/255.0,rgb[1]/255.0,rgb[2]/255.0,float(effect["opacity"])))
		layer.material=mat
	holder.add_child(layer)

func render_record_menu() -> void:
	_expedition_ui_parent_2_render_record_menu()
	if controls.has("book_overview"):reconnect_button("book_overview",func():open_public_overview());controls.book_overview.disabled=not public_home_allowed();controls.book_overview.tooltip_text="查看已公开的家庭与家用总览，不推进日期"

func public_status(value: float,health: bool) -> String:
	if value==10:return "气色很好" if health else "心神安定"
	if value>=8:return "尚好" if health else "尚能安定"
	if value>=6:return "有些不适" if health else "有些紧张"
	if value>=4:return "虚弱" if health else "心神不宁"
	if value>=2:return "病弱" if health else "接近崩溃"
	return "危重" if health else "已经崩溃"

func public_family_projection() -> Array:
	if model.state.is_empty():return []
	var probe=Model.new();probe.state=model.state.duplicate(true);var rows: Array=[]
	for name in Model.PEOPLE:
		var p: Dictionary=probe.state.people[name];var status: String=probe.person_presence_label(name);var here: bool=probe.present(name) and status.is_empty()
		var short: String="在家" if here else ("去世" if not p.alive else ("失散" if p.get("permanentLost",false) else "未归"))
		var health: String="";var spirit: String="";var ailment: String=""
		if here:
			ailment=probe.ailment_text(name);var severe: float=0
			for v in probe.state.ailments[name].values():severe=maxf(severe,float(v))
			health="病重，暂不宜出门" if severe>=3 else ("伤病尚未恢复" if severe>=2 else public_status(p.health,true));spirit=public_status(p.spirit,false)
			if ailment.is_empty():ailment="无当前病症"
		rows.append({"name":name,"here":here,"status":status,"short":short,"health":health,"spirit":spirit,"ailment":ailment})
	return rows

func render_public_family() -> void:
	_room_parent_0_render_public_family()
	if family_return_screen=="room":reconnect_button("family_back",func():screen="recordMenu")

func _aux_parent_5__unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_F7 and screen!="photoRecords" and not photo_records_visible():get_viewport().set_input_as_handled();return
		if event.keycode==KEY_ESCAPE and screen in ["recordMenu","family","photoRecords"]:
			screen=book_return_screen if screen=="recordMenu" else (family_return_screen if screen=="family" else records_return_screen);render_screen();get_viewport().set_input_as_handled();return
	_aux_parent_4__unhandled_key_input(event)


func _aux_parent_5_render_record_menu() -> void:
	var hidden: Array=[5,6,8,10,12,15,16]
	for i in range(18,34):hidden.append(i)
	for row in [["母亲",1],["罗瑾",2],["安仁叔叔",3],["外祖父",4]]:
		if not model.present(row[0]):hidden.append(row[1])
	use_layout("UI29_normal",hidden);design_text("UI29_normal",16,"记录册");design_text("UI29_normal",5,date_label());design_text("UI29_normal",6,"公开记录 · 回看不推进日期")
	design_text("UI29_normal",8,public_rice_hud());design_text("UI29_normal",10,str(int(model.state.water))+" / "+str(int(model.state.waterCap))+" 饮水");design_text("UI29_normal",12,str(int(model.state.wood))+" 木料")
	image_node(op_from("UI29_normal",34).path,Rect2(1234,136,38,36.48))
	var titles: Array=["公开总览","家人近况","家用物件","照片记录","住所主屏","返回当前页面"]
	var icons: Array=[op_from("UI29_normal",34),op_from("UI27_away",5),op_from("UI28_home",6),op_from("SVG_jing_ui20_24_reconstruction_20261024_UI20_reconstruction",3),op_from("UI29_normal",31),op_from("UI29_normal",18)]
	for i in range(titles.size()):
		var op: Dictionary=icons[i];var b: Array=op.box;var scale: float=minf(77/float(b[2]),69/float(b[3]));var size:=Vector2(b[2],b[3])*scale;image_node(op.path,Rect2(Vector2(1268,203+i*89)+(Vector2(77,69)-size)/2,size))
		design_text("UI29_normal",[19,22,24,26,28,30][i],titles[i])
	hit("book_close",Rect2(1558,131,48,46),func():screen=book_return_screen,"返回原页面")
	var overview:=hit("book_overview",Rect2(1257,193,329,83),func():pass,"开发候选：独立公开总览尚未接线");overview.disabled=true
	hit("book_family",Rect2(1257,282,329,83),func():open_public_family(),"查看已公开的家人近况")
	var household:=hit("book_household",Rect2(1257,371,329,83),func():pass,"开发候选：家用页面尚未接线");household.disabled=true
	var photo:=hit("book_photo",Rect2(1257,460,329,83),func():open_photo_records(),"只在照相馆系统已开放时可查看");photo.disabled=not photo_records_visible()
	var room:=hit("book_room",Rect2(1257,549,329,83),func():pass,"开发候选：独立住所主屏尚未接线");room.disabled=true
	hit("book_resume",Rect2(1257,638,329,83),func():screen=book_return_screen,"回到原记录，不推进日期")


func _aux_parent_5_render_screen() -> void:
	if screen in ["recordMenu","family"]:
		controls.clear();primary_bindings.clear();transition_pending=false
		if screen=="recordMenu":render_record_menu()
		else:render_public_family()
	else:_aux_parent_4_render_screen()


var household_return_screen: String="recordMenu"

var household_tab:=0

var household_data: Dictionary={}

var tool_guide_open:=false

var tool_guide_data: Dictionary={}

func open_household() -> void:
	if not public_home_allowed():return
	household_return_screen=screen;household_tab=0;tool_guide_open=false;screen="household"

func pigeon_public_status(a: Dictionary,day: int) -> String:
	if a.get("pickup",false):return "待取物：只留到第"+str(int(a.pickupDeadline)+1)+"日"
	if a.get("sent",false) and not a.get("resolved",false):return "正在传信，不在棚里"
	if a.get("resolved",false):return "信鸽未归，求助没有回应" if a.get("outcome")=="no_reply" else "这一次求助已经结束"
	if day<4:return "还未问清托信门路，第5日起可考虑求助"
	if day>44:return "距最后期限太近，不再放飞求助"
	return ("已备了粮，传信较有把握；" if a.get("remaining",0)>0 else "需要补喂，空腹传信更不稳妥；")+"可在今晚放飞一次"

func public_household_projection() -> Dictionary:
	if model.state.is_empty():return {}
	var probe=Model.new();probe.state=model.state.duplicate(true);var s: Dictionary=probe.state;var active: Dictionary=probe._object(s.expedition.get("active"));var carried: Array=active.get("tools",[]);var tools: Dictionary={}
	for id in Model.TOOL_NAMES:
		tools[id]="远行带走" if id in carried else (("已有" if id=="gooseEgg" else "可用") if probe.tool_available(id) else "暂无")
	var animals: Dictionary={}
	for slot in ["poultry","pet"]:
		var a=probe.night_animal_view(slot)
		if a==null:animals[slot]=null;continue
		animals[slot]={"type":a.type,"name":probe.animal_name(a),"home":probe.animal_at_home(slot),"relation":"一次性求助" if a.type=="pigeon" else ["尚生疏","渐熟悉","亲近","很亲近"][clampi(int(a.get("relation",0)),0,3)],"care":pigeon_public_status(a,int(s.day)) if a.type=="pigeon" else ("需要补喂" if a.get("remaining",0)<=0 else "已备了几夜的粮，暂不必喂")}
	var travel: Dictionary={}
	if not active.is_empty():
		var search: Dictionary=probe._object(active.get("search"));var status: String="已找到，尚在返程" if search.get("mode")=="luo" and search.get("status")=="return_pending" and search.get("outcome")=="found" else ("已逾期，正在等消息" if active.get("announced",false) else "远行中")
		travel={"name":active.get("name","未注明"),"status":status,"route":active.get("route","未注明"),"expected":active.get("expectedDay"),"latest":active.get("latestDay"),"tools":carried.map(func(id):return Model.TOOL_NAMES.get(id,str(id))),"waiting_query":search.get("status")=="waiting"}
	var recall: Dictionary={}
	for i in range(s.expedition.history.size()-1,-1,-1):
		var a: Dictionary=s.expedition.history[i];var r: Dictionary=probe._object(a.get("recall"))
		if r.get("available",false) and not r.get("read",false):recall={"id":a.get("id",""),"name":a.get("name","未注明"),"title":r.get("title","返家口述")};break
	var shelter: float=s.shelter;var shelter_text: String="完好" if shelter>=41 else ("尚可" if shelter>=31 else ("破损" if shelter>=21 else ("残破" if shelter>=11 else ("难以遮蔽" if shelter>0 else "没有遮蔽"))))
	return {"rice":public_resource_number("rice"),"rice_pending":rice_count_pending(),"water":s.water,"waterCap":s.waterCap,"wood":s.wood,"shelter":shelter_text,"weather":probe.current_weather().name,"moisture":["干燥","返潮","潮湿","湿透"][clampi(int(s.moisture),0,3)],"tools":tools,"animals":animals,"travel":travel,"recall":recall,"pigeon_note":("取物纸条约定至第"+str(int(probe._object(s.memory.get("pigeonRequest")).get("pickupDeadline",0))+1)+"日" if s.animals.poultry==null and probe._object(s.memory.get("pigeonRequest")).get("pickup",false) and not probe._object(s.memory.get("pigeonRequest")).get("pickupDone",false) else "")}

func render_household() -> void:
	household_data=public_household_projection()
	if household_tab==0:render_household_home()
	elif household_tab==1:render_household_animals()
	else:render_household_travel()

func household_tabs(compact: bool) -> void:
	for i in range(3):
		var index: int=i;var box:=Rect2(739+i*196,128,177,60) if compact else Rect2(375+i*312,233,280,60)
		hit("household_tab_"+str(i),box,func():household_tab=index;tool_guide_open=false,["家用","动物","远行"][i])

func render_household_home() -> void:
	var id: String="UI28_home";var data: Dictionary=household_data;var hidden: Array=[23,26,29,33,36,38,42,46,51,56,61,65,70,75,80,84,89,94,99,103,111,112,113,114,115]
	for row in [["母亲",1],["罗瑾",2],["安仁叔叔",3],["外祖父",4]]:
		if not model.present(row[0]):hidden.append(row[1])
	if tool_guide_open:
		for i in range(40,106):hidden.append(i)
	use_layout(id,hidden);design_text(id,23,public_number(data.rice));design_text(id,26,public_number(data.water)+" / "+public_number(data.waterCap));design_text(id,29,public_number(data.wood));design_text(id,33,data.shelter);design_text(id,36,data.weather);design_text(id,38,"棚内"+data.moisture)
	if data.rice_pending:native_text("待晨间清点",Rect2(559,327,100,22),14)
	if not tool_guide_open:
		for row in [["axe",42],["shovel",46],["scissors",51],["rope",56],["umbrella",61],["lamp",65],["whistle",70],["pole",75],["bandage",80],["herbs",84],["medkit",89],["canteen",94],["bucket",99],["gooseEgg",103]]:design_text(id,row[1],data.tools[row[0]])
	else:
		if tool_guide_data.is_empty():tool_guide_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/tool_guide.json"))
		var text: String=tool_guide_data.intro+"\n\n"+tool_guide_data.native_note
		for key in tool_guide_data.guide:text+="\n\n"+str(Model.TOOL_NAMES.get(key,key))+" · "+str(data.tools.get(key,"暂无"))+"\n"+str(tool_guide_data.guide[key])
		var body:=prose(text,Rect2(680,263,698,432),19);var bar:=body.get_v_scroll_bar();bar.custom_minimum_size.x=13
		for style in ["scroll","grabber","grabber_highlight","grabber_pressed"]:
			var box:=StyleBoxFlat.new();box.bg_color=Color("f9efd9" if style=="scroll" else ("a59376" if style=="grabber" else "8a7558"));bar.add_theme_stylebox_override(style,box)
	hit("household_tool_guide",Rect2(690,708,665,49),func():tool_guide_open=not tool_guide_open,"展开或收起工具用途，不推进游戏")
	if data.recall.is_empty():design_text(id,112,"暂无可回看的返家口述。")
	else:
		design_text(id,112,data.recall.name+" · 有返家口述");design_text(id,115,"回看尚待接线")
		var button:=hit("household_recall_pending",Rect2(1129,786,244,60),func():pass,"原生返家口述流程尚未接通，不伪造已听完");button.disabled=true
	household_tabs(true);hit("household_close",Rect2(1354,128,43,45),func():screen=household_return_screen,"返回记录册");hit("household_back",Rect2(283,840,220,43),func():screen=household_return_screen,"返回记录册")

func render_household_animals() -> void:
	var id: String="UI28_animals";use_layout(id,[13,14,15,16,17,18,19,20]);household_tabs(false)
	for i in range(2):
		var slot: String=["poultry","pet"][i];var a=household_data.animals[slot];var indices: Array=[14,15,16] if i==0 else [18,19,20]
		if a==null:
			design_text(id,indices[0],"尚无"+("禽类" if i==0 else "宠物"));design_text(id,indices[1],"这一格目前为空");design_text(id,indices[2],household_data.pigeon_note if i==0 and not household_data.pigeon_note.is_empty() else "不展示尚未获得的动物");continue
		var path: String=op_from(id,13 if i==0 else 17).path
		if a.type=="pigeon":path="res://assets/8e61c1b5b108b34d20f48fb2b642733cd4e3b997885f1ef580f19736613eb8bf.png"
		elif a.type=="dog":path="res://assets/9ae470ae9e859a51af94577e2673ce7e2d55d367491c8738cc29f1142d174e8f.png"
		var picture:=image_node(path,Rect2(350+i*516,302,420,265));picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.modulate.a=1.0 if a.home else 0.45
		design_text(id,indices[0],("禽类：" if i==0 else "宠物：")+a.name);design_text(id,indices[1],a.relation)
		var text:=native_text(a.care,Rect2(350+i*516,654,420,67),19);text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	image_node(op_from("UI28_home",116).path,Rect2(1108,180,30,23));native_text("返回记录册",Rect2(1150,176,178,32),20)
	hit("household_back",Rect2(1100,166,230,53),func():screen=household_return_screen,"返回记录册")

func person_record_portrait(name: String,box: Rect2) -> void:
	var index: int=["罗瑾","母亲","外祖父","安仁叔叔"].find(name)
	if index<0:return
	var picture:=image_node(op_from("UI27_away",[8,20,26,38][index]).path,box);picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func render_household_travel() -> void:
	var id: String="UI28_travel";use_layout(id,[13,14,15,16,17,18,19,20,22,23,24,25,26,27,28]);household_tabs(false);var a: Dictionary=household_data.travel;var recall: Dictionary=household_data.recall
	if a.is_empty():
		design_text(id,14,"当前没有进行中的远行。");design_text(id,15,"不会在这里预造一位远行者。");design_text(id,16,"归日与消息以实际记录为准。");design_text(id,17,"家用是否可用，请看家用页。")
	else:
		person_record_portrait(a.name,Rect2(350,325,205,155));design_text(id,14,a.name+"："+a.status)
		design_text(id,15,"约定归日："+("第"+str(int(a.expected)+1)+"日" if a.expected!=null else "未注明"));design_text(id,16,"最晚消息："+("第"+str(int(a.latest)+1)+"日" if a.latest!=null else "未注明"))
		var description:=native_text("带走："+("、".join(a.tools) if not a.tools.is_empty() else "未带家用工具")+"；路线："+str(a.route)+("；托问尚未回话" if a.waiting_query else ""),Rect2(590,451,732,45),18);description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if recall.is_empty():design_text(id,23,"当前没有待回听的返家口述。");design_text(id,24,"不把尚未返回的人写成已经回家。");design_text(id,25,"所得仍须按实际返家记录清点。")
	else:
		person_record_portrait(recall.name,Rect2(350,530,205,155));design_text(id,23,recall.name+"：有返家口述");design_text(id,24,"返家以后讲给罗瑾听的过去。");design_text(id,25,"不会重新选择，也不推进日期。");design_text(id,28,"听他说这几天")
		hit("household_recall",Rect2(1025,583,300,60),func():native_open_recall(recall.id),"回听已经返家的口述")
	image_node(op_from("UI28_home",116).path,Rect2(1108,180,30,23));native_text("返回记录册",Rect2(1150,176,178,32),20)
	hit("household_back",Rect2(1100,166,230,53),func():screen=household_return_screen,"返回记录册")

func _room_parent_0__unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE and screen=="household":screen=household_return_screen;render_screen();get_viewport().set_input_as_handled();return
	_aux_parent_5__unhandled_key_input(event)


func _room_parent_0_begin_game(seed: String="") -> void:
	system_return_screen="";live_return_screen="";_aux_parent_0_begin_game(seed)


func _room_parent_0_date_label() -> String:
	return "第"+str(int(model.state.day)+1)+"日 · "+str(city_chronicle[clampi(int(model.state.day),0,48)].date)

func _room_parent_0_render_public_family() -> void:
	family_data=public_family_projection();var hidden: Array=[50]
	for i in range(8,50):
		if i not in [19,25,37,49]:hidden.append(i)
	for row in [["罗瑾",1],["安仁叔叔",2],["外祖父",3]]:
		if not family_data.any(func(p):return p.name==row[0] and p.here):hidden.append(row[1])
	use_layout("UI27_away",hidden);design_text("UI27_away",50,"缺席状态说明：")
	for i in range(family_data.size()):
		var data: Dictionary=family_data[i];var portrait: Dictionary=op_from("UI27_away",[8,20,26,38][i]).duplicate(true);portrait.opacity=1.0 if data.here else 0.45;add_display_op(portrait)
		var name_op: Dictionary=op_from("UI27_away",[9,21,27,39][i]).duplicate(true);name_op.text=data.name;add_display_op(name_op)
		if data.here:
			for index in [10,11,13,14,16,17]:
				var op: Dictionary=op_from("UI27_away",index).duplicate(true)
				if op.type=="image":op.box[1]+=i*105
				else:op.xy[1]+=i*105
				add_display_op(op)
			for row in [[774,data.health,18],[964,data.spirit,18],[1143,data.ailment,16]]:
				var display: String=str(row[1]).replace("病重，暂不宜出门","病重，暂不出门")
				if row[0]==1143 and "、" in display:display=str(display.split("、").size())+" 项病症"
				var label:=native_text(display,Rect2(row[0],319+i*105,142 if row[0]!=1143 else 104,42),row[2]);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.tooltip_text=row[1];label.mouse_filter=Control.MOUSE_FILTER_PASS
		else:
			var strip: Dictionary=op_from("UI27_away",22).duplicate(true);strip.box[1]=334+i*105;add_display_op(strip)
			center_text(data.short,Rect2(541,334+i*105,85,30),18)
			var label:=native_text(data.status+("（没有确实死讯）" if data.short=="失散" else ""),Rect2(770,308+i*105,465,54),20);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hit("family_close",Rect2(1213,201,44,47),func():screen=family_return_screen,"返回记录册")
	hit("family_back",Rect2(414,770,230,56),func():screen=family_return_screen,"返回记录册，不改变状态")


func _room_parent_0_render_record_menu() -> void:
	_aux_parent_5_render_record_menu();reconnect_button("book_household",func():open_household());controls.book_household.tooltip_text="查看当前家用、动物与已知远行记录"


func _room_parent_0_render_screen() -> void:
	if screen=="household":
		controls.clear();primary_bindings.clear();transition_pending=false;render_household()
	else:_aux_parent_5_render_screen()


var room_return_screen: String="morning"

var room_data: Dictionary={}

var room_bindings: Dictionary={}

func open_public_room() -> void:
	if not public_home_allowed():return
	var target: String=book_return_screen if screen=="recordMenu" else screen
	if target!="room":room_return_screen=target
	screen="room"

func room_projection() -> Dictionary:
	if model.state.is_empty():return {}
	var s: Dictionary=model.state;var focus: Dictionary=model._object(s.get("focus"));var rows: Dictionary=model._object(model._object(focus.get("plan")).get("rows"));var day_out: bool=s.phase in ["focusEvent","focusResult","event"] and focus.get("day")==s.day and public_home_allowed();var people: Dictionary={}
	for p in public_family_projection():
		var outside: bool=day_out and model._object(rows.get(p.name)).get("outside",false);var visible: bool=p.here and not outside;var ill: bool=false
		for text in ["病重","病弱","危重","虚弱","伤病","卧床"]:
			if text in p.health:ill=true
		people[p.name]={"visible":visible,"day_out":outside and p.here,"pose":"ill" if visible and ill else "rest"}
	var shelter_items: Dictionary=model._object(s.get("shelterItems"));var cycle: Dictionary=model._object(s.get("nightCycle"));var poultry: Dictionary=model._object(model._object(s.get("animals")).get("poultry"));var weather: String=model.current_weather().name
	return {"people":people,"night":s.phase in ["night","nightEvent"],"weather":weather,"rain":"雨" in weather,"wet":s.moisture>1,"fire":s.phase=="nightEvent" and model._object(cycle.get("plan")).get("fire",0)>0,"rice":public_resource_number("rice"),"rice_pending":rice_count_pending(),"water":public_resource_number("water"),"wood":public_resource_number("wood"),"oilcloth":shelter_items.get("oilcloth",false),"mat":shelter_items.get("mat",false),"bedding":shelter_items.get("bedding",false),"kettle":public_resource_number("water")>0 and model.tool_available("canteen"),"goose":poultry.get("type")=="goose"}

func render_public_room() -> void:
	room_data=room_projection()
	if room_data.is_empty():screen="menu";render_menu();return
	if room_bindings.is_empty():room_bindings=JSON.parse_string(FileAccess.get_file_as_string("res://data/room_bindings.json"))
	var data: Dictionary=room_data;var operations: Array=[op_from("UI06_night_fire_submitted" if data.night else "UI06_main",0).duplicate(true)]
	if data.wet:operations.append(op_from("UI06_wet",30).duplicate(true))
	for key in ["oilcloth","mat","bedding","food","woodGT2","wood","kettle","goose"]:
		var show: bool=data.rice>0 if key=="food" else (data.wood>2 if key=="woodGT2" else (data.wood>0 if key=="wood" else data[key]))
		if show:operations.append(room_bindings.props[key].duplicate(true))
	if data.fire:operations.append(op_from("UI06_night_fire_submitted",30).duplicate(true))
	var people: Array=["母亲","罗瑾","安仁叔叔","外祖父"]
	for i in range(4):
		if data.people[people[i]].visible:operations.append(op_from("UI06_all_ill" if data.people[people[i]].pose=="ill" else "UI06_main",i+1).duplicate(true))
	if data.rain:operations.append(op_from("UI06_rain",30).duplicate(true))
	for i in range(5,30):
		if i in [9,10,16,18,20,26,29]:continue
		if i in [21,22,23,24] and not data.people[people[i-21]].visible:continue
		operations.append(op_from("UI06_main",i).duplicate(true))
	present_layout({"id":"native_room","canvas":[1672,941],"operations":operations})
	design_text("UI06_main",9,date_label());design_text("UI06_main",10,data.weather+(" · 夜间" if data.night else " · 住所"));design_text("UI06_main",16,public_rice_hud());design_text("UI06_main",18,public_number(data.water)+"/"+public_number(model.state.waterCap)+" 饮水");design_text("UI06_main",20,public_number(data.wood)+" 木料")
	design_text("UI06_main",26,"家人" if data.people.values().any(func(p):return p.visible) else "不在")
	var labels: Dictionary={"morning":"今晨记录","focus":"今日去向","focusEvent":"继续阅读","focusResult":"查看结果","focusReturn":"返家清点","focusDiary":"傍晚日记","diary":"查看日记","report":"查看记录","night":"今晚安排","nightEvent":"夜间记录","end":"回看结局"}
	design_text("UI06_main",29,labels.get(room_return_screen,"当前记录"))
	hit("room_current_record",Rect2(1434,825,232,71),func():screen=room_return_screen,"返回原页面，不执行选择或结算")
	hit("room_family",Rect2(1462,456,106,61),func():open_room_family(),"查看家人近况")
	for i in range(4):
		if not data.people[people[i]].visible:continue
		var box: Array=op_from("UI06_main",21+i).box;hit("room_person_"+str(i),Rect2(box[0]-12,box[1]-12,box[2]+24,box[3]+24),func():open_room_family(),people[i]+"的公开近况")

func open_room_family() -> void:
	book_return_screen="room";open_public_family()

func hide_day_out_background_people() -> void:
	var projection:=room_projection()
	if projection.is_empty():return
	var ids: Dictionary={"full_mother":"母亲","full_luo":"罗瑾","full_uncle":"安仁叔叔","full_grandfather":"外祖父"}
	for child in holder.get_children():
		if child.get_script()!=Layer:continue
		for op in child.current.get("operations",[]):
			if op.get("type")=="image" and ids.has(op.get("id")) and not projection.people[ids[op.id]].visible:child.hide()

func _expedition_ui_parent_0__unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE and screen=="room":screen=room_return_screen;render_screen();get_viewport().set_input_as_handled();return
	_room_parent_0__unhandled_key_input(event)

# Apply the exact same opacity, crop, fade and shadow setup as the layout loader.


func _expedition_ui_parent_0_render_screen() -> void:
	if screen=="room":
		controls.clear();primary_bindings.clear();transition_pending=false;render_public_room();bind_system_toolbar()
	else:
		_room_parent_0_render_screen()
		if screen in ["systemMenu","recordMenu","family","household"]:hide_day_out_background_people()


const SEARCH_LAYOUT="SVG_jing_ui13_16_reconstruction_20261024_UI13_reconstruction_v04"

const SEARCH_EVENT_LAYOUT="SVG_jing_ui13_16_reconstruction_20261024_UI14_reconstruction_v04"

const RECALL_LAYOUT="SVG_jing_ui13_16_reconstruction_20261024_UI15_reconstruction_v04"

var recall_ui_return: String=""

func expedition_search_projection() -> Dictionary:
	var probe=Model.new();probe.state=model.state.duplicate(true);var a: Dictionary=probe._object(probe.state.expedition.get("active"));var d: Dictionary=probe._object(probe.state.expedition.get("decision"));var valid: bool=probe.state.phase=="search" and not a.is_empty() and not d.is_empty() and d.get("day")==probe.state.day and probe.state.day<a.get("latestDay",0) and a.get("lastSearchDay")!=probe.state.day
	return {"valid":valid,"name":a.get("name","家人"),"expected":a.get("expectedDay"),"latest":a.get("latestDay"),"rice":probe.state.get("rice",0),"luo_reason":probe.search_luo_block() if valid else "当前没有待处理的寻找安排。"}

func native_expedition_search(choice: String) -> bool:
	var result:=later_action("expedition_search",[choice])
	if result:screen=model.state.phase
	return result

func render_expedition_search() -> void:
	var data:=expedition_search_projection();use_layout(SEARCH_LAYOUT,[24,28,29,30,42])
	design_text(SEARCH_LAYOUT,24,date_label()+" · 远行逾期");design_text(SEARCH_LAYOUT,28,"本次远行的寻找安排" if data.valid else "当前没有待处理的寻找安排")
	design_text(SEARCH_LAYOUT,29,data.name+"仍没有回来。" if data.valid else "请返回当前流程。")
	design_text(SEARCH_LAYOUT,30,"约定第"+str(int(data.expected)+1)+"日归；第"+str(int(data.latest)+1)+"日给出最终消息。" if data.expected!=null and data.latest!=null else "没有可用的归期记录。")
	var reason: String="缺少米粮，不能托人打听。" if data.rice<1 else ""
	if not data.luo_reason.is_empty():reason+=(" " if not reason.is_empty() else "")+data.luo_reason
	var note:=prose(reason if not reason.is_empty() else "按实际条件选择；不提前清点远行所得。",Rect2(535,802,665,45),18);note.name="search_conditions"
	for row in [["wait",Rect2(475,500,747,82)],["ask",Rect2(475,590,747,91)],["luo",Rect2(475,692,747,99)]]:
		var b:=hit("search_"+row[0],row[1],func():native_expedition_search(row[0]),"选择后继续原流程")
		b.disabled=not data.valid or (row[0]=="ask" and data.rice<1) or (row[0]=="luo" and not data.luo_reason.is_empty())
		if b.disabled:b.tooltip_text=reason
	hit("search_back",Rect2(1134,216,110,50),func():open_public_room(),"查看住所，保留待处理的寻找安排")

func render_expedition_search_event() -> void:
	var event:=native_focus_event();use_layout(SEARCH_EVENT_LAYOUT,[10,20,24,25,26,27,28,29,30,31,32,33,34,35,36,37])
	design_text(SEARCH_EVENT_LAYOUT,20,date_label()+" · 寻找现场");design_text(SEARCH_EVENT_LAYOUT,24,"已安排罗瑾沿约定路线寻找")
	design_text(SEARCH_EVENT_LAYOUT,25,"罗瑾 · 寻找"+str(model._object(model.state.expedition.get("active")).get("name","家人")))
	var body:=prose(str(event.get("intro","")),Rect2(509,368,689,255),22);body.name="expedition_search_prose";add_expedition_scroll(body,Rect2(1210,372,7,248),"search_scene")
	for i in range(mini(2,event.get("choices",[]).size())):
		var choice: Dictionary=event.choices[i];design_text(SEARCH_EVENT_LAYOUT,34 if i==0 else 36,choice.label);design_text(SEARCH_EVENT_LAYOUT,35 if i==0 else 37,choice.hint)
		var b:=hit("search_scene_choice_"+str(i),Rect2(471,656+i*97,749,87),func():
			if native_choose_focus(i):screen=model.state.phase,choice.hint)
		b.disabled=not native_choice_requirement(choice).met
	hit("search_scene_back",Rect2(1146,202,100,50),func():
		if native_back_focus():screen="focus","返回注视页，保留今天寻找的安排")

func native_open_recall(id: String) -> bool:
	var back: String=screen
	var result:=later_action("recall_open",[id])
	if result:recall_ui_return=back;screen="expeditionRecall"
	return result

func native_close_recall() -> bool:
	var result:=later_action("recall_close")
	if result:
		var back: String=recall_ui_return;recall_ui_return=""
		screen=back if back in ["household","overview","photoRecords","recordMenu","room"] else model.state.phase
		if screen=="household":household_data=public_household_projection()
	return result

func render_expedition_recall() -> void:
	use_layout(RECALL_LAYOUT,[13,17,18,19,20,21,22]);var a=model.find_expedition_history(model.state.expedition.get("recallViewing"));var r: Dictionary=model._object(a.get("recall")) if a is Dictionary else {}
	design_text(RECALL_LAYOUT,17,str(r.get("title","这段口述已经找不到了")));design_text(RECALL_LAYOUT,18,str(r.get("subtitle","没有可供回看的记录")))
	var paragraphs: Array=r.get("paragraphs",[]).duplicate()
	if r.get("diary","")!="":paragraphs.append("罗瑾记下的一小段\n"+str(r.diary))
	var body:=prose("\n\n".join(paragraphs),Rect2(453,397,752,207),23);body.name="expedition_recall_prose";add_expedition_scroll(body,Rect2(1217,379,10,210),"recall")
	hit("recall_close",Rect2(944,635,314,67),func():native_close_recall(),"听完并返回；不重新选择，不推进日期")

func add_expedition_scroll(body: RichTextLabel,track_box: Rect2,prefix: String) -> void:
	var bar:=body.get_v_scroll_bar();bar.hide();var thumb:=ColorRect.new();thumb.name=prefix+"_thumb";thumb.color=Color("796650");thumb.position=track_box.position;thumb.size=Vector2(track_box.size.x,45);thumb.mouse_filter=Control.MOUSE_FILTER_IGNORE;holder.add_child(thumb)
	var sync: Callable=func():
		var span: float=maxf(0,bar.max_value-bar.page);thumb.size.y=clampf(track_box.size.y*bar.page/maxf(1,bar.max_value),22,76);thumb.position.y=track_box.position.y+(track_box.size.y-thumb.size.y)*(bar.value/span if span>0 else 0);thumb.visible=span>0
	bar.value_changed.connect(func(_v):sync.call())
	var track:=Control.new();track.position=track_box.position-Vector2(8,0);track.size=track_box.size+Vector2(16,0);track.mouse_filter=Control.MOUSE_FILTER_STOP;holder.add_child(track)
	track.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index==MOUSE_BUTTON_WHEEL_UP:bar.value-=45
			elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:bar.value+=45
			elif event.button_index==MOUSE_BUTTON_LEFT:bar.value=clampf((event.position.y-thumb.size.y/2)/maxf(1,track_box.size.y-thumb.size.y),0,1)*maxf(0,bar.max_value-bar.page)
			track.accept_event()
		elif event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:bar.value=clampf((event.position.y-thumb.size.y/2)/maxf(1,track_box.size.y-thumb.size.y),0,1)*maxf(0,bar.max_value-bar.page);track.accept_event())
	ending_scroll_button(prefix+"_scroll_up",Rect2(track_box.position.x-8,track_box.position.y-22,26,22),func():bar.value-=65)
	ending_scroll_button(prefix+"_scroll_down",Rect2(track_box.position.x-8,track_box.end.y,26,22),func():bar.value+=65)
	call_deferred("initialize_expedition_scroll",weakref(body),weakref(thumb),sync)

func initialize_expedition_scroll(body_ref,thumb_ref,sync: Callable) -> void:
	await get_tree().process_frame
	if body_ref.get_ref()!=null and thumb_ref.get_ref()!=null:body_ref.get_ref().get_v_scroll_bar().hide();sync.call()

func native_expedition_plan(name: String) -> bool:return later_action("expedition_plan",[name])

func native_expedition_tool(id: String) -> bool:return later_action("expedition_tool",[id])

func native_expedition_supply(key: String) -> bool:return later_action("expedition_supply",[key])

func render_expedition_night_controls() -> void:
	var probe=Model.new();probe.state=model.state.duplicate(true);probe.load_expedition_rules();var plan: Dictionary=probe._object(probe.state.expedition.get("plan"));var editable: bool=probe.night_plan_editable();var status: Dictionary=probe.expedition_plan_status()
	design_text("UI17_main",37,"一次一名成年人，确认今晚才出发。再点已选人物可取消。")
	for i in range(3):
		var name: String=["母亲","安仁叔叔","外祖父"][i];var indices: Array=[[38,39,41,42,43,44],[45,46,47,48,49,50],[51,52,53,54,55,56]][i];var reason: String=probe.departure_block(name);var selected: bool=plan.get("name")==name
		for index in indices:
			var op: Dictionary=op_from("UI17_main",index).duplicate(true)
			if index in [39,46,52]:op.stroke="#b51f1c" if selected else "#241e14"
			if index in [43,49,55] and not reason.is_empty():op.text=reason if reason.length()<=27 else reason.left(26)+"…"
			if not reason.is_empty() and not selected:op.opacity=0.48
			add_display_op(op)
		if selected:selection_dot(287,311+i*103)
		var button:=hit("expedition_actor_"+str(i),Rect2(270,282+i*103,709,95),func():native_expedition_plan(name),reason if not reason.is_empty() else "选择远行准备，尚未出发")
		button.disabled=not editable or (not reason.is_empty() and not selected)
	var kit: Array=plan.get("tools",[]) if plan.get("tools") is Array else []
	design_text("UI17_main",85,"随身物品  "+str(kit.size())+"/2")
	var choices: Array=["rope","canteen","umbrella","whistle","bandage","herbs","medkit"]
	if plan.get("name")=="外祖父":choices.append("axe")
	var header: String="未选择远行者；物品留在家中。" if plan.is_empty() else ("横向滚动可查看斧头；最多携带两件。" if choices.size()>7 else ("已选满两件，取消一件后可改选。" if kit.size()>=2 else "仅预选；确认今晚后才出发。"))
	var preview: Dictionary=probe.preview_night()
	if preview.cost.rice>probe.state.rice or preview.cost.wood>probe.state.wood:header="现有粮木不足，请调整开伙、火力和远行粮水。"
	if not status.valid:header=status.reason
	if model.state.get("error")!=null:header=str(model.state.error)
	var notice:=native_text(header,Rect2(493,595,485,39),16);notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.tooltip_text=header

	var scroll:=ScrollContainer.new();scroll.name="expedition_kit_scroll";scroll.position=Vector2(278,635);scroll.size=Vector2(701,110);scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;holder.add_child(scroll)
	var content:=Control.new();content.custom_minimum_size=Vector2(choices.size()*101-7,97);scroll.add_child(content)
	var hbar:=scroll.get_h_scroll_bar()
	for style in ["scroll","grabber","grabber_highlight","grabber_pressed"]:
		var box:=StyleBoxFlat.new();box.bg_color=Color("d9c8a9" if style=="scroll" else "8a7558");hbar.add_theme_stylebox_override(style,box)
	scroll.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:hbar.value+=-101 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 101;scroll.accept_event())
	var icons: Dictionary={"rope":88,"canteen":93,"umbrella":98,"whistle":102,"bandage":106,"herbs":110,"medkit":114}
	for i in range(choices.size()):
		var id: String=choices[i];var selected: bool=id in kit;var available: bool=probe.tool_available(id);var allowed: bool=editable and not plan.is_empty() and (selected or (available and kit.size()<2))
		var b:=Button.new();b.name="expedition_tool_"+id;b.position=Vector2(i*101,0);b.size=Vector2(94,97);b.disabled=not allowed;b.tooltip_text=probe.expedition_rules.tool_names[id]+("：已选择，可取消" if selected else ("：当前不可用" if not available else ("：已选满两件" if kit.size()>=2 else "：选择携带")))
		for style in ["normal","hover","pressed","focus","disabled"]:
			var frame:=StyleBoxFlat.new();frame.bg_color=Color(0,0,0,0);frame.border_color=Color("b4211a" if selected else "b7a181");frame.set_border_width_all(2 if selected else 1);b.add_theme_stylebox_override(style,frame)
		b.pressed.connect(func():
			if transition_pending:return
			transition_pending=true;native_expedition_tool(id);call_deferred("render_screen"));content.add_child(b);controls[b.name]=b
		var texture:=TextureRect.new();texture.texture=load(op_from("UI17_main",icons[id]).path if icons.has(id) else skin.items.axe);texture.position=Vector2(8,8);texture.size=Vector2(77,64);texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;texture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;texture.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(texture)
		var label:=Label.new();label.text=probe.expedition_rules.tool_names[id];label.position=Vector2(0,72);label.size=Vector2(94,25);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.add_theme_font_override("font",fonts[FONT_REG+"#2"]);label.add_theme_font_size_override("font_size",18);label.add_theme_color_override("font_color",Color("372b21"));label.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(label)
		if not available and not selected:texture.modulate.a=0.45;label.modulate.a=0.45
		if selected:
			var circle:=Panel.new();circle.position=Vector2(67,3);circle.size=Vector2(23,23);var circle_style:=StyleBoxFlat.new();circle_style.bg_color=Color("a92720");circle_style.border_color=Color("fff2df");circle_style.set_border_width_all(1);circle_style.set_corner_radius_all(12);circle.add_theme_stylebox_override("panel",circle_style);circle.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(circle)
			var check_icon:=TextureRect.new();check_icon.texture=load(op_from("UI17_main",91).path);check_icon.position=Vector2(70,6);check_icon.size=Vector2(17,17);check_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(check_icon)
	for index in [119,120,121,123,124,125,126,127,128]:add_display_op(op_from("UI17_main",index))
	var box: Dictionary=op_from("UI17_main",117).duplicate(true);box.color="#a92720" if plan.get("rice",0)>0 else "none";add_display_op(box)
	if plan.get("rice",0)>0:add_display_op(op_from("UI17_main",118))
	design_text("UI17_main",122,"携带饮水："+str(int(plan.get("water",0)))+"份")
	var rice:=hit("expedition_supply_rice",Rect2(278,742,195,43),func():native_expedition_supply("rice"),"切换携带一份米粮，确认前不扣除");rice.disabled=not editable or plan.is_empty()
	var water:=hit("expedition_supply_water",Rect2(485,740,295,48),func():native_expedition_supply("water"),"循环选择0至3份饮水；水壶也占一格");water.disabled=not editable or plan.is_empty() or (not probe.tool_available("canteen") and plan.get("water",0)==0)
	design_text("UI17_main",129,"约第"+str(int(model.state.day)+4)+"日归，最晚第"+str(int(model.state.day)+7)+"日有消息。" if not plan.is_empty() else "约定归日以实际出发记录为准。")
	if not status.valid:
		var cancel:=hit("expedition_cancel_invalid",Rect2(490,595,485,35),func():native_expedition_plan("__cancel_unconfirmed_expedition__"),status.reason+" 点击取消原准备");cancel.disabled=not editable

func _expedition_ui_parent_2__unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE and screen=="expeditionRecall":native_close_recall();render_screen();get_viewport().set_input_as_handled();return
	_expedition_ui_parent_0__unhandled_key_input(event)


func _expedition_ui_parent_2_render_record_menu() -> void:
	_room_parent_0_render_record_menu();reconnect_button("book_room",func():open_public_room());controls.book_room.tooltip_text="收起纸页查看住所；不推进游戏"


func _expedition_ui_parent_2_render_screen() -> void:
	if screen in ["search","expeditionRecall"] or (screen=="focusEvent" and native_focus_event().get("expeditionSearch",false)):
		controls.clear();primary_bindings.clear();transition_pending=false
		if screen=="search":render_expedition_search()
		elif screen=="expeditionRecall":render_expedition_recall()
		else:render_expedition_search_event()
		bind_system_toolbar()
	else:_expedition_ui_parent_0_render_screen()


const OVERVIEW_LAYOUT="SVG_jing_ui19_reconstruction_20261024_RECONSTRUCTION"

var overview_return_screen: String="recordMenu"

func open_public_overview() -> void:
	if not public_home_allowed():return
	if screen!="overview":overview_return_screen=screen
	screen="overview"

func overview_household(tab: int) -> void:
	open_household();household_tab=tab

func render_public_overview() -> void:
	var family: Array=public_family_projection();var home: Dictionary=public_household_projection();var photos: bool=photo_records_visible();var removed: Array=[3,23,24,25,26,27,37,38,44,45,51,52,58,59,62,65,68,82]
	for i in range(family.size()):
		if not family[i].here:removed.append_array([[33,35,36],[40,42,43],[47,49,50],[54,56,57]][i])
	use_layout(OVERVIEW_LAYOUT,removed);design_text(OVERVIEW_LAYOUT,3,date_label());design_text(OVERVIEW_LAYOUT,23,"远行")
	for index in [24,25]:
		var op: Dictionary=op_from(OVERVIEW_LAYOUT,index).duplicate(true);op.opacity=1.0 if photos else op.get("opacity",0.5);add_display_op(op)
	var photo_label: Dictionary=op_from(OVERVIEW_LAYOUT,26).duplicate(true)
	if photos:photo_label.opacity=1.0;photo_label.color="#322218"
	add_display_op(photo_label)
	if not photos:add_display_op(op_from(OVERVIEW_LAYOUT,27))
	for i in range(family.size()):
		var row: Dictionary=family[i];var health_index: int=[37,44,51,58][i];var spirit_index: int=[38,45,52,59][i]
		if row.here:
			design_text(OVERVIEW_LAYOUT,health_index,"健康："+row.health);design_text(OVERVIEW_LAYOUT,spirit_index,"精神："+row.spirit)
		else:
			var portrait: Dictionary=op_from(OVERVIEW_LAYOUT,[33,40,47,54][i]).duplicate(true);portrait.opacity=0.45;add_display_op(portrait)
			design_text(OVERVIEW_LAYOUT,health_index,row.status if not row.status.is_empty() else row.short);design_text(OVERVIEW_LAYOUT,spirit_index,"只记已知情况")
		hit("overview_person_"+str(i),Rect2(425,348+i*105,384,85),func():open_public_family(),"查看家人近况")
	design_text(OVERVIEW_LAYOUT,62,str(int(home.rice))+("（待清点）" if home.rice_pending else ""));design_text(OVERVIEW_LAYOUT,65,str(int(home.water))+"/"+str(int(home.waterCap)));design_text(OVERVIEW_LAYOUT,68,str(int(home.wood)))
	design_text(OVERVIEW_LAYOUT,82,"返家口述按实际归来记录开放。")
	hit("overview_family_tab",Rect2(405,187,144,80),func():pass,"公开家庭总览")
	hit("overview_people_tab",Rect2(549,187,144,80),func():open_public_family(),"家人近况")
	hit("overview_items_tab",Rect2(693,187,144,80),func():overview_household(0),"家用物件")
	hit("overview_animals_tab",Rect2(837,187,144,80),func():overview_household(1),"动物记录")
	hit("overview_travel_tab",Rect2(981,187,144,80),func():overview_household(2),"远行与返家口述")
	var photo:=hit("overview_photo_tab",Rect2(1125,187,144,80),func():open_photo_records(),"只查看已解锁的照片记录");photo.disabled=not photos
	hit("overview_family",Rect2(895,560,345,60),func():open_public_family(),"家人详情")
	hit("overview_household",Rect2(895,627,345,58),func():overview_household(0),"家用与随身物件")
	hit("overview_disk",Rect2(895,692,345,58),func():open_native_disk(),"保存与恢复；打开不写入")
	hit("overview_back",Rect2(1510,809,143,64),func():screen=overview_return_screen,"返回原页面，不推进日期")

func _save_ux_parent_0__ready() -> void:
	super._ready()
	load_reading_preferences()
	menu_contract=JSON.parse_string(FileAccess.get_file_as_string("res://data/menu_contract.json"))
	skin=JSON.parse_string(FileAccess.get_file_as_string("res://data/loadout_skin.json"))
	city_chronicle=JSON.parse_string(FileAccess.get_file_as_string("res://data/city_chronicle.json"))
	primary_button_states=JSON.parse_string(FileAccess.get_file_as_string("res://data/primary_button_states.json"))
	render_screen()

func _save_ux_parent_0__unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE and screen=="overview":screen=overview_return_screen;render_screen();get_viewport().set_input_as_handled();return
	_expedition_ui_parent_2__unhandled_key_input(event)


func _save_ux_parent_0_begin_game(seed: String="") -> void:
	room_return_screen="morning";_room_parent_0_begin_game(seed)


func _save_ux_parent_0_commit_disk_action() -> void:
	if disk_pending_state!=var_to_bytes(model.state) or disk_pending_proof!=var_to_bytes(continuation.proof()):disk_notice="当前进度已变化，请重新预览。";screen="disk";return
	var reader=SaveStore.new()
	if reader.file_fingerprint(disk_pending_read_path)!=disk_pending_fingerprint:disk_notice="磁盘文件已变化，请重新核对。";disk_info={"ok":false,"reason":"CHANGED"};screen="disk";return
	if disk_action=="write":
		var writer=SaveStore.new();writer.active_proof=continuation.proof() if not continuation.actions.is_empty() else {}
		var ok: bool=writer.save_to(save_path,model.state,disk_pending_fingerprint)
		disk_notice="已写入并校验本机记录。" if ok else ("文件已提交，但锁释放异常；请先核对。" if writer.last_write_committed else "未写入："+writer.error)
		screen="disk";inspect_native_disk()
	elif disk_action=="restore":
		save_text=disk_pending_text;save_preview=disk_info.state.duplicate(true);restore_preview()
		if screen=="diskConfirm":disk_notice=save_notice;screen="disk"
	disk_action=""


func _save_ux_parent_0_render_native_help() -> void:
	if help_data.is_empty():help_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/native_help.json"))
	var hidden: Array=[17,18,36]
	if help_page>0:
		for i in range(20,34):hidden.append(i)
	use_layout("UI21",hidden);var guides: Array=help_data.guides
	design_text("UI21",18,str(help_page+1)+" / 11 · "+str(guides[help_page][0]))
	var marker: Dictionary=op_from("UI21",17).duplicate(true);marker.box[1]+=42*help_page
	if not textures.has(marker.path):textures[marker.path]=load(marker.path)
	var layer=Layer.new();layer.current={"canvas":current.canvas,"operations":[marker]};layer.textures=textures;layer.fonts=fonts;layer.size=Vector2(current.canvas[0],current.canvas[1]);layer.mouse_filter=Control.MOUSE_FILTER_IGNORE;holder.add_child(layer)
	for i in range(11):
		var index: int=i;hit("help_topic_"+str(i),Rect2(365,270+i*42,250,38),func():help_page=index,str(guides[i][0]))
	if help_page>0:
		var body:=prose(str(guides[help_page][1]),Rect2(631,285,724,435),22);body.name="help_prose";body.scroll_active=true;add_help_scroll(body)
	var previous:=hit("help_previous",Rect2(916,748,115,49),func():help_page=maxi(0,help_page-1),"上一条");previous.disabled=help_page==0
	var next:=hit("help_next",Rect2(1042,752,132,42),func():help_page=mini(10,help_page+1),"下一条");next.disabled=help_page==10
	hit("help_back",Rect2(1220,747,166,51),func():screen=help_return_screen,"返回原页面，不推进游戏")


func _save_ux_parent_0_render_screen() -> void:
	if screen=="overview":controls.clear();primary_bindings.clear();transition_pending=false;render_public_overview()
	else:_expedition_ui_parent_2_render_screen()


func _save_ux_parent_0_restore_preview() -> void:
	# Re-validate the current input, never trust a stale preview of previously pasted text.
	var candidate: Dictionary=save_store.decode(save_text)
	if candidate.is_empty() or candidate!=save_preview:save_preview={};save_notice="输入已变化，请重新校验。";return
	var candidate_proof: Dictionary=save_store.decoded_proof.duplicate(true)
	if not model.state.is_empty():
		# Keep the current unsaved run independently before replacing it.
		if not save_current_to(save_path+".before-restore"):save_notice="未能备份当前进度，已取消恢复："+save_store.error;return
	model.state=candidate;model.rng.state=int(candidate.rngState);restore_continuation(candidate_proof)
	model.contract_error="";model.contract_message="";model.diet_legacy_depth=0
	screen=candidate.phase;night_stage="reading";morning_tab="city";save_preview={}

func _save_ux_parent_0_save_current_to(path: String) -> bool:
	save_store.active_proof=continuation.proof() if not continuation.actions.is_empty() else {}
	return save_store.save_to(path,model.state)

var autosave_enabled: bool=true

var autosave_ready:=false

var autosave_queued:=false

var autosave_paused:=false

var autosave_expected_sha: String=""

var autosave_seen: String=""

var autosave_saved: String=""

var autosave_notice: String=""

var autosave_return_screen: String="menu"

var close_return_screen: String="menu"

var close_message: String=""

var new_game_seed: String=""

var new_game_expected_sha: String=""

var new_game_notice: String=""

var new_game_backup: String=""

var autosave_writes:=0

func state_stamp() -> String:
	return "" if model.state.is_empty() else var_to_bytes(model.state).hex_encode().sha256_text()

func observe_autosave() -> void:
	if not autosave_ready or not autosave_enabled or model.state.is_empty():return
	var stamp:=state_stamp()
	if stamp==autosave_seen:return
	autosave_seen=stamp
	if stamp==autosave_saved or autosave_paused or autosave_queued:return
	autosave_queued=true;call_deferred("flush_autosave",true)

func flush_autosave(show_error: bool=true) -> bool:
	autosave_queued=false
	if model.state.is_empty() or state_stamp()==autosave_saved:return true
	if autosave_paused:return false
	var stamp:=state_stamp();save_store.active_proof=continuation.proof() if not continuation.actions.is_empty() else {}
	var ok: bool=save_store.save_to(save_path,model.state,autosave_expected_sha)
	if ok or save_store.last_write_committed:
		autosave_saved=stamp;autosave_expected_sha=save_store.file_fingerprint(save_path);autosave_writes+=1
	if ok:autosave_notice="";return true
	autosave_paused=true
	autosave_notice=("记录已经写入，但锁释放异常。请到存档管理中核对。" if save_store.last_write_committed else "自动保存未完成，当前游戏仍保留在内存中。"+save_failure_reason(save_store.error)+"请到存档管理中核对，未擅自覆盖其他记录。")
	if show_error and screen not in ["confirmQuit","confirmNewGame"]:
		autosave_return_screen=screen;screen="autoSaveFailure";call_deferred("render_screen")
	return false

func adopt_primary_if_current() -> bool:
	if model.state.is_empty():return false
	var reader=SaveStore.new();var saved: Dictionary=reader.read_valid(save_path)
	if saved.is_empty() or var_to_bytes(saved)!=var_to_bytes(model.state):return false
	autosave_expected_sha=save_store.file_fingerprint(save_path);autosave_saved=state_stamp();autosave_seen=autosave_saved;autosave_paused=false;autosave_notice=""
	if disk_return_screen=="autoSaveFailure":disk_return_screen=autosave_return_screen
	return true

func start_new_game_now(seed: String) -> void:
	autosave_paused=false;autosave_notice="";autosave_saved="";autosave_seen="";autosave_expected_sha=save_store.file_fingerprint(save_path);_save_ux_parent_0_begin_game(seed)

func confirm_new_game() -> bool:
	if save_store.file_fingerprint(save_path)!=new_game_expected_sha:new_game_notice="磁盘记录在确认前已变化。请取消后重新打开确认，不覆盖新变化。";return false
	if FileAccess.file_exists(save_path):
		var data:=FileAccess.get_file_as_bytes(save_path);var path: String=save_path+".before-newgame-"+str(Time.get_ticks_usec())+"-"+new_game_expected_sha.left(8)+".json"
		if FileAccess.file_exists(path):new_game_notice="备份路径已存在，未开始新记录。";return false
		var f=FileAccess.open(path,FileAccess.WRITE)
		if f==null:new_game_notice="无法备份现有记录，未开始新记录。";return false
		f.store_buffer(data);f.close()
		if FileAccess.get_sha256(path)!=new_game_expected_sha:new_game_notice="备份校验未通过，未开始新记录。";return false
		new_game_backup=path
	start_new_game_now(new_game_seed);return true

func request_window_close() -> void:
	if model.state.is_empty() or state_stamp()==autosave_saved:quit_game_now();return
	var old: String=screen
	if flush_autosave(false):quit_game_now();return
	close_return_screen=old;close_message="本次记录已写入，但保存收尾异常。" if state_stamp()==autosave_saved else "当前最新进度尚未保存。直接退出会丢失未保存部分。"
	close_message+=" "+autosave_notice;screen="confirmQuit";render_screen()

func quit_game_now() -> void:get_tree().quit()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST and autosave_ready:request_window_close()

func render_save_ux_confirmation() -> void:
	var id: String="UI25_daytime";use_layout(id,[2,4,9,10,11,14,17]);var title: String;var detail: String;var primary: String;var secondary: String
	if screen=="confirmNewGame":title="开始新记录";detail=new_game_notice;primary="备份旧记录并开始";secondary="取消，保留当前进度"
	elif screen=="confirmQuit":title="确认退出游戏";detail=close_message;primary="仍然退出";secondary="返回游戏，先处理保存"
	else:title="自动保存未完成";detail=autosave_notice;primary="打开存档管理";secondary="返回游戏" if state_stamp()==autosave_saved else "继续游戏（尚未保存）"
	design_text(id,2,title);design_text(id,4,"只操作本机原生记录，不上传或发送存档")
	var body:=prose(detail,Rect2(579,470,530,150),22);body.name="save_ux_message"
	design_text(id,14,primary);design_text(id,17,secondary)
	hit("save_ux_primary",Rect2(594,677,490,60),func():
		if screen=="confirmNewGame":confirm_new_game()
		elif screen=="confirmQuit":quit_game_now()
		else:open_native_disk(),primary)
	hit("save_ux_cancel",Rect2(604,747,470,60),func():screen=close_return_screen if screen=="confirmQuit" else autosave_return_screen,secondary)

func save_failure_reason(reason: String) -> String:
	return {"WRITE_CONFLICT":"磁盘记录已被其他写入改变。","WRITE_LOCKED":"当前存档被另一笔写入占用。","WRITE_TEMP":"临时记录未能写入磁盘。","VERIFY_TEMP":"新记录未通过读取校验。","PRIMARY_RENAME":"新记录未能替换主记录。","CONTINUATION_MISMATCH":"当前进度未通过原生回放校验。","SIZE":"记录超过当前支持的大小。"}.get(reason,"写入未能完整完成。")

func _pigeon_ui_parent_0_native_focus_diary() -> String:
	if model.state.day<10:return model.focus_diary_text()
	if not model.state.focus.get("diaryAllowed",false):return "这一日没有留下可确认的第一人称记述。"
	return "\n\n".join(model.state.focus.get("chapterDiary",[]).filter(func(text):return text is String and not text.strip_edges().is_empty()))

func _pigeon_ui_parent_0_render_animal_card() -> void:
	if model.state.animals.get(animal_tab)==null:
		animal_tab="pet" if model.state.animals.pet!=null else "poultry"
	var animal=model.state.animals.get(animal_tab)
	if animal==null:
		native_text("家中尚无动物",Rect2(1060,320,350,45),28)
		prose("遇见动物时可决定是否留下。",Rect2(1060,375,350,70),21)
	else:
		var path: String=op_from("UI17_main",59).path if animal.type=="goose" else skin.items.pigeon
		if animal_tab=="pet":path=op_from("UI17_animal_overview",11 if animal.type=="cat" else 15).path
		var picture=image_node(path,Rect2(1024,288,210,144));picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var feeding: bool=model.state.night.feedPet if animal_tab=="pet" else model.state.night.feedPoultry
		var label=native_text(("已备粮：" if feeding else "备粮：")+model.animal_name(animal),Rect2(1243,303,215,58),22);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		prose("确认时米粮 ×1，按周期喂养。",Rect2(1243,366,210,60),18)
		var slot: String=animal_tab
		hit("night_feed_"+slot,Rect2(1235,295,223,125),func():native_feed_animal(slot),"切换备粮")
		native_text("两类动物独立备粮；总耗粮见下方。",Rect2(1029,438,425,35),18)
	for i in range(2):
		var slot: String=["poultry","pet"][i];var x: int=1035+i*215
		var label: String=["禽类","宠物"][i];var feeding: bool=model.state.night.feedPoultry if i==0 else model.state.night.feedPet
		native_text(("● " if animal_tab==slot else "○ ")+label+(" · 已备粮" if feeding else ""),Rect2(x,478,210,32),18)
		hit("animal_tab_"+slot,Rect2(x,475,210,35),func():animal_tab=slot).disabled=model.state.animals.get(slot)==null

func _pigeon_ui_parent_0_render_screen() -> void:
	if screen in ["autoSaveFailure","confirmQuit","confirmNewGame"]:
		controls.clear();primary_bindings.clear();transition_pending=false;render_save_ux_confirmation()
	else:_save_ux_parent_0_render_screen()
	observe_autosave()

func native_pigeon_action(value: String) -> bool:
	return later_action("night_pigeon",[value]) if int(model.state.day) in range(10,49) else model.set_pigeon_action(value)

func bird_note_available() -> bool:
	var a=model.pigeon_request()
	return a is Dictionary and a.get("pickup",false) and not a.get("pickupDone",false)

func bird_option(value: String,box: Rect2,offset: Vector2,allowed: bool) -> void:
	var b:=hit("pigeon_"+value,Rect2(box.position+offset,box.size),func():native_pigeon_action(value),"只预选；确认夜晚后执行")
	b.disabled=not allowed
