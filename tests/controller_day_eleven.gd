extends SceneTree
const Controller=preload("res://scripts/game_controller.gd")
const Continuation=preload("res://scripts/native_continuation.gd")
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
func save_roundtrip(label: String) -> void:
	var before: PackedByteArray=var_to_bytes(game.model.state);var proof: PackedByteArray=var_to_bytes(game.continuation.proof())
	game.open_saves();game.render_screen();await process_frame
	await press("save_write");check(game.save_store.error=="",label+":save:"+game.save_store.error)
	await press("save_read");check(not game.save_preview.is_empty(),label+":preview:"+game.save_notice)
	await press("save_restore");check(var_to_bytes(game.model.state)==before,label+":exact-state");check(var_to_bytes(game.continuation.proof())==proof,label+":exact-proof");print("UI_SAVE "+label+" DONE")
func run() -> void:
	var file=FileAccess.open("res://data/day_eleven_lifecycle_reference.jsonl",FileAccess.READ);var cases: Array=[]
	while file.get_position()<file.get_length():
		var line=file.get_line()
		if line.is_empty():continue
		var case=decode_exact(JSON.parse_string(line))
		if case.id.get_slice(":",0) in ["0","1","4","9","10","14"]:cases.append(case)
	game=Controller.new();game.autosave_enabled=false;root.add_child(game);game.size=Vector2(1920,1080);await process_frame
	for case in cases:
		print("CASE "+case.id+" START")
		game.model.state=case.initial.duplicate(true);game.model.contract_error="";game.model.contract_message="";game.continuation=Continuation.new();game.save_store.active_proof={};game.save_path="user://eleven-ui-"+str(OS.get_process_id())+"-"+case.id.get_slice(":",0)+".json";game.screen="morning";game.render_screen();await process_frame
		await press("morning_next");check(game.screen=="focus",case.id+":focus")
		var targets: Array=game.model.state.focus.plan.targets
		for i in range(targets.size()):
			for j in range(i+1,targets.size()):check(not game.controls["focus_target_"+targets[i]].get_rect().intersects(game.controls["focus_target_"+targets[j]].get_rect()),case.id+":distinct-target-controls")
		await press("focus_target_"+case.target);await press("focus_confirm");check(game.screen=="focusEvent",case.id+":event")
		var choices: Array=game.native_focus_event().choices
		if choices.size()>3:
			var before: PackedByteArray=var_to_bytes(game.model.state);var proof_before: PackedByteArray=var_to_bytes(game.continuation.proof())
			await press("focus_choices_next");check(game.controls.has("focus_choice_3"),case.id+":fourth-choice-reachable");check(not game.controls.has("focus_choice_0"),case.id+":page-hides-old-row")
			check(game.controls.focus_choice_3.get_rect().end.y<=815,case.id+":no-footer-overlap")
			await press("focus_choices_prev");check(var_to_bytes(game.model.state)==before and var_to_bytes(game.continuation.proof())==proof_before,case.id+":paging-read-only")
		await save_roundtrip(case.id+":event-save")
		await press("focus_choice_"+str(int(case.choice)));check(game.screen=="focusResult",case.id+":chosen")
		await press("focus_result_next");check(game.screen=="focusReturn",case.id+":returned")
		await save_roundtrip(case.id+":return-save")
		await press("focus_return_diary");check(not game.native_focus_diary().is_empty(),case.id+":diary")
		await press("day_open_night");await press("night_back");await press("day_open_night")
		await press("night_meal_on" if case.beforeNight.night.meal else "night_meal_off");await press("night_fire_"+str(int(case.beforeNight.night.fire)))
		await press("night_confirm");check(game.screen=="nightEvent",case.id+":night")
		await save_roundtrip(case.id+":confirmed-save")
		if case.response!=null:
			if game.model.state.pendingNightEvent.type=="family":await press("night_family_continue")
			else:await press("night_read_next");await press("night_choice_"+case.response)
		await press("night_finish");check(same_json(game.model.state,case.afterFinish),case.id+":source-final")
		if game.screen=="morning":check(not game.controls.morning_next.disabled,case.id+":D12-chapter-entry-enabled")
		else:check(game.screen=="end",case.id+":approved-terminal")
		await save_roundtrip(case.id+":final-save")
		var restarted=Controller.new();restarted.autosave_enabled=false;restarted.save_path=game.save_path;root.add_child(restarted);restarted.size=Vector2(1920,1080);await process_frame;restarted.continue_saved();restarted.render_screen();await process_frame
		check(var_to_bytes(restarted.model.state)==var_to_bytes(game.model.state),case.id+":new-controller-load");check(var_to_bytes(restarted.continuation.proof())==var_to_bytes(game.continuation.proof()),case.id+":new-controller-proof");restarted.queue_free();await process_frame
	check(game.load_errors.is_empty(),"resources")
	print(JSON.stringify({"checks":checks,"failed":failed,"cases":cases.size(),"visual_test":false,"real_mouse_test":false,"scope":"Headless controller signal calls, option pagination and distinct target hit rectangles, v2 save preview/restore and new-controller loading."}));game.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
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
