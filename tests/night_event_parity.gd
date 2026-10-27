extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string("res://data/night_event_reference.json"))
	var names={"minorNightBlocked":"minor_night_blocked","familyNightKind":"family_night_kind","prepareNightEvent":"prepare_night_event","nightResponseActors":"night_response_actors","nightChoiceRequirement":"night_choice_requirement"}
	var failed: Array=[];var checks:=0
	for case in reference.tests:
		var model=Model.new();model.state=case.initial.duplicate(true)
		for i in range(case.steps.size()):
			var step: Dictionary=case.steps[i];var args: Array=step.args
			if step.name=="fixturePending":
				model.state.pendingNightEvent=model.prepare_night_event();continue
			var result=model.callv(names[step.name],args);checks+=2
			var id=case.id+":"+str(i)+":"+step.name
			var expected_result=decode_exact(step.result)
			var result_ok=same_json(result,expected_result);var state_ok=same_json(model.state,step.state)
			if not result_ok or not state_ok:
				if failed.is_empty():
					var f=FileAccess.open("res://../evidence/night_event_first_diff.json",FileAccess.WRITE)
					f.store_string(JSON.stringify({"id":id,"actual":model.state,"expected":step.state,"result":result,"expected_result":step.result}))
				failed.append(id+":"+("result" if not result_ok else "state"))
	print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false}));quit(0 if failed.is_empty() else 1)
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
