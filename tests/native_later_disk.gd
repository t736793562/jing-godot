extends SceneTree
const Model=preload("res://scripts/game_model.gd")
const Journal=preload("res://scripts/native_continuation.gd")
const Store=preload("res://scripts/native_continuation_store.gd")
const ROOT="user://d11-continuation-disk-20261026"
func _initialize() -> void:
	var args=OS.get_cmdline_user_args();var mode: String=args[0] if not args.is_empty() else "verify"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	var source=FileAccess.open("res://data/day_eleven_lifecycle_reference.jsonl",FileAccess.READ);var failed: Array=[];var cases:=0;var store=Store.new()
	while source.get_position()<source.get_length():
		var line=source.get_line()
		if line.is_empty():continue
		var case=decode_exact(JSON.parse_string(line));var path: String=ROOT+"/case-"+str(cases)+".json";var expected_path: String=ROOT+"/case-"+str(cases)+".expected.bin";cases+=1
		var model=Model.new();var journal=Journal.new()
		if mode=="prepare":
			model.state=case.initial.duplicate(true)
			if not journal.start(model):failed.append(case.id+":anchor");continue
			var control=Model.new();control.state=case.initial.duplicate(true);var control_journal=Journal.new();control_journal.start(control)
			for group in ["prepare","select","choose","return","confirm","event","finish"]:
				if not apply_group(control,control_journal,case,group):failed.append(case.id+":control:"+group)
			var file=FileAccess.open(expected_path,FileAccess.WRITE);file.store_buffer(var_to_bytes(control.state));file.close()
		else:
			var loaded: Dictionary=store.load_from(path,model)
			if not loaded.ok or store.decoded_proof.is_empty():failed.append(case.id+":load:"+store.error);continue
			journal.restore(store.decoded_proof)
		if mode=="verify":
			if var_to_bytes(model.state)!=FileAccess.get_file_as_bytes(expected_path):failed.append(case.id+":interrupted-versus-control")
			if not same_json(model.state,case.afterFinish):failed.append(case.id+":source-final")
			var before: PackedByteArray=var_to_bytes(model.state);var proof_before: PackedByteArray=var_to_bytes(journal.proof())
			if journal.apply(model,"finish_night") or journal.apply(model,"confirm_night"):failed.append(case.id+":duplicate-accepted")
			if var_to_bytes(model.state)!=before or var_to_bytes(journal.proof())!=proof_before:failed.append(case.id+":duplicate-mutated")
			continue
		if not apply_group(model,journal,case,mode):failed.append(case.id+":action:"+mode);continue
		store.active_proof=journal.proof()
		if not store.save_to(path,model.state):failed.append(case.id+":save:"+store.error)
	print(JSON.stringify({"mode":mode,"cases":cases,"failed":failed,"passed":failed.is_empty(),"visual_test":false,"independent_process":true}));quit(0 if failed.is_empty() else 1)
func apply_group(model,journal,case: Dictionary,mode: String) -> bool:
	match mode:
		"prepare":return journal.apply(model,"enter")
		"select":return journal.apply(model,"select",[case.target])
		"choose":return journal.apply(model,"choose",[case.choice])
		"return":return journal.apply(model,"return")
		"confirm":return journal.apply(model,"open_night") and journal.apply(model,"night_option",["meal",case.beforeNight.night.meal]) and journal.apply(model,"night_option",["fire",case.beforeNight.night.fire]) and journal.apply(model,"confirm_night")
		"event":return true if case.response==null else journal.apply(model,"night_response",[case.response])
		"finish":return journal.apply(model,"finish_night")
	return false
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
