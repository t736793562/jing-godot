extends SceneTree
const Controller=preload("res://scripts/game_controller.gd")
var game
var failed: Array=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failed.append(label)
func press(id: String) -> void:
	check(game.controls.has(id),"control:"+id)
	if game.controls.has(id):
		check(not game.controls[id].disabled,"enabled:"+id)
		if not game.controls[id].disabled:game.controls[id].pressed.emit()
	await process_frame;await process_frame
func run() -> void:
	game=Controller.new();game.autosave_enabled=false;game.save_path="user://ten-ui-"+str(OS.get_process_id())+".json";root.add_child(game);game.size=Vector2(1920,1080)
	await process_frame;game.begin_game("ui-early-days-v1");game.render_screen();await process_frame
	await press("intro_next");await press("tutorial_skip");await press("recommend")
	if game.controls.has("recommend_confirm"):await press("recommend_confirm")
	await press("depart");await press("choice_0");await press("result_next");await press("result_next")
	for day in range(10):
		if day==0:await press("night_plan")
		else:
			await press("morning_next");await press("focus_target_home");await press("focus_confirm")
			var choice:=0
			if game.controls.has("focus_choice_0") and game.controls.focus_choice_0.disabled:choice=1
			await press("focus_choice_"+str(choice));await press("focus_result_next");await press("focus_return_diary");await press("day_open_night")
		if game.model.state.rice>0 and game.model.state.wood>0:
			await press("night_meal_on");await press("night_fire_1")
		else:await press("night_meal_off");await press("night_fire_0")
		var options: Array=game.model.treatment_options()
		if not options.is_empty():await press("night_treatment_"+options[0].value)
		await press("night_confirm")
		check(game.screen=="nightEvent","night "+str(day)+" confirmed")
		if game.model.state.pendingNightEvent!=null:
			if game.model.state.pendingNightEvent.type=="family":await press("night_family_continue")
			else:
				var kind: String=game.model.state.pendingNightEvent.type
				await press("night_read_next");await press("night_choice_"+{"theft":"quiet","robbery":"give","mouse":"wait"}[kind])
		await press("night_finish")
		check(game.screen=="morning" and game.model.state.day==day+1,"morning "+str(day+1))
		if game.screen!="morning":break
	check(game.model.state.day==10,"eleventh morning reached")
	check(game.controls.get("morning_next")!=null and not game.controls.morning_next.disabled,"eleventh day entry is available")
	game.open_saves();game.render_screen();await process_frame;await press("save_write")
	check(game.save_store.error=="","save eleventh morning")
	var before=var_to_bytes(game.model.state)
	await press("save_read");await press("save_restore")
	check(var_to_bytes(game.model.state)==before,"eleventh morning UI restore exact")
	check(game.load_errors.is_empty(),"resources")
	for suffix in ["",".bak",".tmp",".bak.tmp",".before-restore",".before-restore.bak"]:
		if FileAccess.file_exists(game.save_path+suffix):DirAccess.remove_absolute(game.save_path+suffix)
	print(JSON.stringify({"checks":checks,"failed":failed,"visual_test":false,"full_game":false,"scope":"one actual UI-controller run through ten nights"}));game.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
