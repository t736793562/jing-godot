extends SceneTree
const Store=preload("res://scripts/native_save.gd")
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var args=OS.get_cmdline_user_args()
	if args.size()!=2:quit(2);return
	var mode: String=args[0];var folder: String=args[1]
	var source=FileAccess.open("res://data/missing_family_lifecycle_reference.jsonl",FileAccess.READ)
	var store=Store.new();var failed: Array=[];var cases:=0;var row:=0
	while source.get_position()<source.get_length():
		var line=source.get_line()
		if line.is_empty():continue
		row+=1
		# Test every available real missing-family sample.
		cases+=1;var case=decode_exact(JSON.parse_string(line));var model=Model.new()
		var path=folder+"/"+case.id.replace(":","-")+".json";var expected_path=path+".expected"
		if mode=="prepare":
			model.state=case.initial.duplicate(true)
			if not model.enter_first_day_focus() or not model.select_first_day_focus(case.target):failed.append(case.id+":prepare");continue
			if not store.save_to(path,model.state):failed.append(case.id+":save:"+store.error);continue
			for stage in ["choose","confirm","event","finish"]:
				if not advance(model,stage,case):failed.append(case.id+":expected:"+stage);break
			if not store.source_equal(model.state,case.afterFinish):failed.append(case.id+":source")
			if not store.save_to(expected_path,model.state):failed.append(case.id+":expected-save:"+store.error)
		else:
			if not store.load_from(path,model).ok:failed.append(case.id+":load:"+store.error);continue
			if mode=="verify":
				var expected=store.read_valid(expected_path)
				if expected.is_empty() or var_to_bytes(expected)!=var_to_bytes(model.state):failed.append(case.id+":uninterrupted-difference")
				if not store.source_equal(model.state,case.afterFinish):failed.append(case.id+":source-difference")
			else:
				if not advance(model,mode,case):failed.append(case.id+":"+mode);continue
				if not store.save_to(path,model.state):failed.append(case.id+":resave:"+store.error)
	print(JSON.stringify({"cases":cases,"mode":mode,"failed":failed,"passed":failed.is_empty(),"visual_test":false}));quit(0 if failed.is_empty() else 1)
func advance(model: RefCounted,stage: String,case: Dictionary) -> bool:
	match stage:
		"choose":return model.resolve_first_day_focus_choice(int(case.choice))
		"confirm":
			if not model.settle_first_day_focus_return():return false
			model.state.phase="night";model.set_night_option("meal",case.beforeNight.night.meal);model.set_night_option("fire",case.beforeNight.night.fire)
			return model.confirm_early_night()
		"event":return true if case.response==null else model.resolve_night_event(case.response)
		"finish":return model.finish_early_night()
	return false

func decode_exact(value: Variant) -> Variant:
	if value is Dictionary:
		if value.size()==1 and value.has("__float64"):
			var stream:=StreamPeerBuffer.new();stream.big_endian=false;stream.data_array=value.__float64.hex_decode();return stream.get_double()
		var result: Dictionary={}
		for key in value:result[key]=decode_exact(value[key])
		return result
	if value is Array:return value.map(func(x):return decode_exact(x))
	return value
