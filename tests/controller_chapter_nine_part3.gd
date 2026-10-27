extends SceneTree
const Controller=preload("res://scripts/game_controller.gd")
const Boundary=preload("res://../tools/chapter_nine_oracle_boundary.gd")
const Journal=preload("res://scripts/native_continuation.gd")
var game
var requested: String=""
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
	var args=OS.get_cmdline_user_args();requested=args[0] if not args.is_empty() else "c9-control-home"
	game=Controller.new();game.autosave_enabled=false;root.add_child(game);game.size=Vector2(1920,1080);await process_frame
	var stream=FileAccess.open("res://../evidence/chapter_nine_disk_cases.jsonl",FileAccess.READ);var cohort: String="";var count:=0
	while stream.get_position()<stream.get_length():
		var line=stream.get_line()
		if line.is_empty():continue
		var case=decode_exact(JSON.parse_string(line));var id: String=case.id.get_slice(":",0)
		if requested!="" and id!=requested:continue
		if id not in ["c9-controlled","c9-home-base","c9-prep","c9-control-home","c9-home-home"]:continue
		if id!=cohort:
			cohort=id
			var aliases: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../evidence/chapter_nine_disk_cases_scope.json")).parent_alias
			var loaded: Dictionary=game.save_store.load_from("user://chapter-eight-promoted-disk-20261026/"+str(aliases[id])+".json",game.model)
			check(loaded.ok,id+":parent-load:"+game.save_store.error)
			if not loaded.ok:break
			game.restore_continuation(game.save_store.decoded_proof.duplicate(true));game.screen="morning";game.render_screen();await process_frame
		print("CASE "+case.id);count+=1
		check(same_json(game.model.state,case.initial),case.id+":boundary")
		await press("morning_next");await press("focus_target_"+case.target);await press("focus_confirm")
		while not game.controls.has("focus_choice_"+str(int(case.choice))) and game.controls.has("focus_choices_next") and not game.controls.focus_choices_next.disabled:await press("focus_choices_next")
		await press("focus_choice_"+str(int(case.choice)));await press("focus_result_next");await press("focus_return_diary");await press("day_open_night")
		await press("night_meal_on" if case.beforeNight.night.meal else "night_meal_off");await press("night_fire_"+str(int(case.beforeNight.night.fire)))
		if case.get("animalChoice")!=null:
			var before: PackedByteArray=var_to_bytes(game.model.state);var proof: PackedByteArray=var_to_bytes(game.continuation.proof())
			await press("animal_encounter_open");check(game.controls.night_confirm.disabled,case.id+":modal-blocks-background")
			await press("animal_back");check(var_to_bytes(game.model.state)==before and var_to_bytes(game.continuation.proof())==proof,case.id+":back-no-mutation")
			await press("animal_encounter_open");await press("animal_accept" if case.animalChoice=="accept" else "animal_decline")
			check(game.screen=="night",case.id+":encounter-returns")
		if case.has("animalChoice"):
			if game.model.state.animals.pet!=null:
				await press("animal_tab_pet")
				if game.model.state.night.feedPet!=case.beforeNight.night.feedPet:await press("night_feed_pet")
		await press("night_confirm")
		if case.response!=null:
			if game.model.state.pendingNightEvent.type=="family":await press("night_family_continue")
			else:
				await press("night_read_next")
				while not game.controls.has("night_choice_"+case.response) and game.controls.has("night_choices_next") and not game.controls.night_choices_next.disabled:await press("night_choices_next")
				await press("night_choice_"+case.response)
		await press("night_finish");check(same_json(game.model.state,Boundary.native_expected(case.afterFinish)),case.id+":source-final")
		if int(game.model.state.day)==49 or game.model.state.ended:
			if not game.model.state.ended:check(false,case.id+":terminal-must-end")
			else:check(game.screen=="end",case.id+":terminal-ui")
			game.save_path="user://chapter-nine-ui-single-"+cohort+".json";check(game.save_current_to(game.save_path),case.id+":save:"+game.save_store.error)
			var restarted=Controller.new();restarted.autosave_enabled=false;restarted.save_path=game.save_path;root.add_child(restarted);restarted.size=Vector2(1920,1080);await process_frame;restarted.continue_saved();restarted.render_screen();await process_frame
			check(var_to_bytes(restarted.model.state)==var_to_bytes(game.model.state),case.id+":new-controller-load");restarted.queue_free();await process_frame
	check(game.load_errors.is_empty(),"resources")
	print(JSON.stringify({"checks":checks,"cases":count,"failed":failed,"visual_test":false,"real_mouse_test":false}));game.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)

func same_json(a: Variant,b: Variant) -> bool:
	if typeof(a) in [TYPE_INT,TYPE_FLOAT] and typeof(b) in [TYPE_INT,TYPE_FLOAT]:return float(a)==float(b)
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size():return false
		for key in a:
			if not b.has(key) or not same_json(a[key],b[key]):return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for i in range(a.size()):
			if not same_json(a[i],b[i]):return false
		return true
	return typeof(a)==typeof(b) and a==b
func decode_exact(value: Variant) -> Variant:
	if value is Dictionary:
		if value.size()==1 and value.has("__float64"):
			var stream:=StreamPeerBuffer.new();stream.big_endian=false;stream.data_array=value.__float64.hex_decode();return stream.get_double()
		var result: Dictionary={}
		for key in value:result[key]=decode_exact(value[key])
		return result
	if value is Array:return value.map(func(x):return decode_exact(x))
	return value
