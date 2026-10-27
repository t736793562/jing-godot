extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string("res://data/night_effect_reference.json"))
	var failed: Array=[];var checks:=0
	for case in reference.tests:
		var model=Model.new();model.state=case.initial.duplicate(true)
		var result=model.resolve_night_event_effects(case.choice);checks+=2
		if not same_json(result,case.result) or not same_json(model.state,case.after):
			if failed.is_empty():
				var f=FileAccess.open("res://../evidence/night_effect_first_diff.json",FileAccess.WRITE)
				f.store_string(JSON.stringify({"id":case.id,"actual":model.state,"expected":case.after,"result":result,"expected_result":case.result}))
			failed.append(case.id)
		result=model.resolve_night_event_effects(case.choice);checks+=2
		if not same_json(result,case.repeated) or not same_json(model.state,case.final):failed.append(case.id+":repeat")
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
