extends SceneTree
const Model=preload("res://scripts/game_model.gd")
const Journal=preload("res://scripts/native_continuation.gd")
const Store=preload("res://scripts/native_continuation_store.gd")
func _initialize() -> void:
	var source=FileAccess.open("res://data/day_eleven_lifecycle_reference.jsonl",FileAccess.READ);var failed: Array=[];var checks:=0;var cases:=0
	while source.get_position()<source.get_length():
		var line=source.get_line()
		if line.is_empty():continue
		var case=decode_exact(JSON.parse_string(line));var model=Model.new();model.state=case.initial.duplicate(true);var journal=Journal.new();var store=Store.new();cases+=1;checks+=1
		if not journal.start(model):failed.append(case.id+":anchor");continue
		var steps: Array=[["enter",[]],["select",[case.target]],["choose",[case.choice]],["return",[]],["open_night",[]],["night_option",["meal",case.beforeNight.night.meal]],["night_option",["fire",case.beforeNight.night.fire]],["confirm_night",[]]]
		if case.response!=null:steps.append(["night_response",[case.response]])
		steps.append(["finish_night",[]])
		for step in steps:
			checks+=3
			if not journal.apply(model,step[0],step[1]):failed.append(case.id+":"+step[0]+":action");break
			store.active_proof=journal.proof();var before: PackedByteArray=var_to_bytes(model.state);var text: String=store.encode(model.state)
			if text.is_empty():failed.append(case.id+":"+step[0]+":encode:"+store.error);break
			var restored: Dictionary=store.decode(text)
			if restored.is_empty() or var_to_bytes(restored)!=before or var_to_bytes(model.state)!=before:failed.append(case.id+":"+step[0]+":roundtrip:"+store.error);break
	print(JSON.stringify({"cases":cases,"checks":checks,"failed":failed,"visual_test":false,"disk_test":false,"scope":"Staged v2 deterministic replay proof, exact typed round-trip per D11 action; native v1 unchanged."}));quit(0 if failed.is_empty() else 1)
func decode_exact(value: Variant) -> Variant:
	if value is Dictionary:
		if value.size()==1 and value.has("__float64"):
			var stream:=StreamPeerBuffer.new();stream.big_endian=false;stream.data_array=value.__float64.hex_decode();return stream.get_double()
		var result: Dictionary={}
		for key in value:result[key]=decode_exact(value[key])
		return result
	if value is Array:return value.map(func(x):return decode_exact(x))
	return value
