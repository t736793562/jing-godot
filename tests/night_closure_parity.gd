extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string("res://data/night_closure_reference.json"))
	var model=Model.new();var failed: Array=[];var checks:=0
	for case in reference.tests:
		model.state=case.initial.duplicate(true);checks+=2
		var ok=model.lock_night_reading(case.event.duplicate(true),case.choice,model.state.nightCycle,case.before.duplicate(true),case.eventLines.duplicate())
		if not ok or not same_json(model.state,case.expected):
			if failed.is_empty():
				var f=FileAccess.open("res://../evidence/night_closure_first_diff.json",FileAccess.WRITE)
				f.store_string(JSON.stringify({"key":case.key,"actual":model.state,"expected":case.expected}))
			failed.append(case.key)
	print(JSON.stringify({"checks":checks,"failed":failed,"variants":reference.tests.size(),"full_game":false}));quit(0 if failed.is_empty() else 1)
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
