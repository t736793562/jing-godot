extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var stream=FileAccess.open("res://data/pre_photo_care_flow_reference.jsonl",FileAccess.READ);var model=Model.new();var failed: Array=[];var checks:=0
	while stream.get_position()<stream.get_length():
		var line=stream.get_line()
		if line.is_empty():continue
		var case=JSON.parse_string(line);model.state=case.initial.duplicate(true)
		for stage in ["resolved","returned"]:
			var result: bool=model.resolve_ordinary_pre_photo_choice(int(case.index)) if stage=="resolved" else (model.settle_ordinary_pre_photo_return() if case.resolved else false)
			var expected: Dictionary=case.afterResolve if stage=="resolved" else case.afterReturn;checks+=2
			if result!=case[stage] or not same_json(model.state,expected):
				if failed.is_empty():
					var file=FileAccess.open("res://../evidence/pre_photo_care_flow_first_diff.json",FileAccess.WRITE);file.store_string(JSON.stringify({"id":case.id,"stage":stage,"result":result,"expected_result":case[stage],"actual":model.state,"expected":expected}))
				failed.append(case.id+":"+stage)
	print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false,"disk_test":false,"visual_test":false}));quit(0 if failed.is_empty() else 1)

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

