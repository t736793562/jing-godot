extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://../evidence/staged_chapter_nine_plan_reference.json"));var model=Model.new();var failed: Array=[];var checks:=0
	for case in data.tests:
		model.state=case.initial.duplicate(true);model.contract_error="";model.contract_message=""
		var result=model.make_pre_photo_plan();checks+=2
		if not same_json(result,case.plan) or not same_json(model.state,case.after):
			if failed.is_empty():
				var file=FileAccess.open("res://../evidence/chapter_nine_plan_first_diff.json",FileAccess.WRITE)
				file.store_string(JSON.stringify({"id":case.id,"actual":model.state,"expected":case.after,"result":result,"expected_result":case.plan,"error":model.contract_message}))
			failed.append(case.id)
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

