extends SceneTree
const Model=preload("res://scripts/game_model.gd")
const Journal=preload("res://scripts/native_continuation.gd")
const Store=preload("res://scripts/native_continuation_store.gd")
const ROOT="user://chapter-five-promoted-disk-20261026"
func _initialize() -> void:
	var args=OS.get_cmdline_user_args();var mode: String=args[0];var day: int=int(args[1]) if args.size()>1 else 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	var stream=FileAccess.open("res://../evidence/chapter_five_disk_cases.jsonl",FileAccess.READ)
	var cohorts: Dictionary={};var failed: Array=[];var count:=0;var store=Store.new()
	while stream.get_position()<stream.get_length():
		var line=stream.get_line()
		if line.is_empty():continue
		var case=decode_exact(JSON.parse_string(line));var id: String=case.id.get_slice(":",0)
		if not cohorts.has(id):cohorts[id]=[]
		cohorts[id].append(case)
	for id in cohorts:
		var frames: Array=cohorts[id];var path: String=ROOT+"/"+id+".json";var expected: String=ROOT+"/"+id+".bin"
		var model=Model.new();var journal=Journal.new()
		if mode=="prepare":
			var parent_id: String=id.trim_prefix("home-")
			var loaded: Dictionary=store.load_from("user://chapter-four-promoted-disk-20261026/"+parent_id+".json",model)
			if not loaded.ok or store.decoded_proof.is_empty():failed.append(id+":parent-load:"+store.error);continue
			if not same_json(model.state,frames[0].initial):failed.append(id+":parent-source-boundary");continue
			var anchor_state: Dictionary=model.state.duplicate(true);var parent_proof: Dictionary=store.decoded_proof.duplicate(true);journal.restore(parent_proof)
			for frame in frames:
				if not apply_half(model,journal,frame,"am") or not apply_half(model,journal,frame,"pm"):failed.append(frame.id+":control-action");break
				if not same_json(model.state,frame.afterFinish):failed.append(frame.id+":control-source");break
			var f=FileAccess.open(expected,FileAccess.WRITE);f.store_buffer(var_to_bytes(model.state));f.close()
			model=Model.new();model.state=anchor_state;journal=Journal.new();journal.restore(parent_proof);store.active_proof=journal.proof()
		else:
			if mode!="verify" and day>=frames.size():continue
			var loaded: Dictionary=store.load_from(path,model)
			if not loaded.ok:failed.append(id+":load:"+store.error);continue
			if store.decoded_proof.is_empty():
				if not journal.start(model):failed.append(id+":loaded-anchor");continue
			else:journal.restore(store.decoded_proof)
			if mode=="verify":
				if var_to_bytes(model.state)!=FileAccess.get_file_as_bytes(expected):failed.append(id+":cold-vs-continuous")
				if not same_json(model.state,frames[-1].afterFinish):failed.append(id+":source-final")
				count+=1;continue
			if not apply_half(model,journal,frames[day],mode):failed.append(frames[day].id+":action:"+mode);continue
			var target: Dictionary=frames[day].afterResolve if mode=="am" else frames[day].afterFinish
			if not same_json(model.state,target):failed.append(frames[day].id+":source:"+mode);continue
			store.active_proof=journal.proof()
		if not store.save_to(path,model.state):failed.append(id+":save:"+store.error)
		count+=1
	print(JSON.stringify({"mode":mode,"day_index":day,"cases":count,"failed":failed,"passed":failed.is_empty(),"visual_test":false}));quit(0 if failed.is_empty() else 1)
func apply_half(model,journal,case: Dictionary,mode: String) -> bool:
	if mode=="am":return journal.apply(model,"enter") and journal.apply(model,"select",[case.target]) and journal.apply(model,"choose",[case.choice])
	if not journal.apply(model,"return") or not journal.apply(model,"open_night"):return false
	if not journal.apply(model,"night_option",["meal",case.beforeNight.night.meal]) or not journal.apply(model,"night_option",["fire",case.beforeNight.night.fire]):return false
	if case.get("animalChoice")!=null and not journal.apply(model,"animal_encounter",[case.animalChoice,case.animalKind]):return false
	if case.has("animalChoice") and not journal.apply(model,"night_option",["feedPet",case.beforeNight.night.feedPet]):return false
	if not journal.apply(model,"confirm_night"):return false
	if case.response!=null and not journal.apply(model,"night_response",[case.response]):return false
	return journal.apply(model,"finish_night")

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
