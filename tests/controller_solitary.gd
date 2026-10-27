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
	game=Controller.new();game.autosave_enabled=false;root.add_child(game);game.size=Vector2(1920,1080);await process_frame
	var stream=FileAccess.open("res://data/solitary_lifecycle_reference.jsonl",FileAccess.READ);var seen: Dictionary={}
	while stream.get_position()<stream.get_length():
		var line=stream.get_line()
		if line.is_empty():continue
		var case=decode_exact(JSON.parse_string(line));game.model.state=case.initial.duplicate(true)
		var mask: int=1 if case.afterFinish.ended else 2
		if seen.has(mask):continue
		seen[mask]=true;game.screen="morning";game.render_screen();await process_frame
		await press("morning_next");await press("focus_target_"+case.target);await press("focus_confirm")
		await press("focus_choice_"+str(int(case.choice)));await press("focus_result_next");await press("focus_return_diary");await press("day_open_night")
		await press("night_meal_on" if case.beforeNight.night.meal else "night_meal_off");await press("night_fire_"+str(int(case.beforeNight.night.fire)))
		await press("night_confirm")
		if game.model.state.pendingNightEvent!=null:
			if game.model.state.pendingNightEvent.type=="family":await press("night_family_continue")
			else:
				await press("night_read_next");await press("night_choice_"+case.response)
		await press("night_finish")
		check(game.screen==case.afterFinish.phase,"terminal or morning:"+case.id)
		if case.afterFinish.ended:check(game.controls.has("failure_restart"),"approved interruption page controls")
		check(game.save_store.source_equal(game.model.state,case.afterFinish),"source state:"+case.id)
		if case.afterFinish.ended:
			var frozen: PackedByteArray=var_to_bytes(game.model.state)
			game.save_path="user://solo-ui-"+str(OS.get_process_id())+".json"
			game.open_saves();game.render_screen();await process_frame
			await press("save_write");await press("save_read");await press("save_restore")
			check(game.screen=="end" and var_to_bytes(game.model.state)==frozen,"terminal UI restore exact")
			await press("failure_restart")
			check(game.screen=="menu" and var_to_bytes(game.model.state)==frozen,"restart returns to menu without altering old record")
			for suffix in ["",".bak",".tmp",".bak.tmp",".before-restore",".before-restore.bak"]:
				if FileAccess.file_exists(game.save_path+suffix):DirAccess.remove_absolute(game.save_path+suffix)

	check(seen.size()==2,"both solo survival and terminal outcomes")
	check(game.load_errors.is_empty(),"resources")
	print(JSON.stringify({"checks":checks,"failed":failed,"outcomes":seen.size(),"visual_test":false,"full_game":false}));game.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)

func decode_exact(value: Variant) -> Variant:
	if value is Dictionary:
		if value.size()==1 and value.has("__float64"):
			var stream:=StreamPeerBuffer.new();stream.big_endian=false;stream.data_array=value.__float64.hex_decode();return stream.get_double()
		var result: Dictionary={}
		for key in value:result[key]=decode_exact(value[key])
		return result
	if value is Array:return value.map(func(x):return decode_exact(x))
	return value
