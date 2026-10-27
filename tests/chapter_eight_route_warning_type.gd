extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var model=Model.new();var stream=FileAccess.open("res://../evidence/staged_route_warning_type_cases.jsonl",FileAccess.READ);var failed: Array=[];var checks:=0
	while stream.get_position()<stream.get_length():
		var line=stream.get_line()
		if line.is_empty():continue
		var case=JSON.parse_string(line);model.state=case.initial.duplicate(true);model.contract_error="";model.contract_message="";var result: Variant
		if case.kind=="apply":result=model.route_apply(case.fact)
		elif case.kind=="validate":result=model.route_validate()
		else:result=model.route_project()
		checks+=4
		if (case.error==null and not helper.same_json(result,case.result)) or model.contract_message!=str(case.error if case.error!=null else "") or model.contract_error!=str(case.code if case.code!=null else "") or not helper.same_json(model.state,case.expected):
			if failed.is_empty():
				var file=FileAccess.open("res://../evidence/route_warning_type_first_diff.json",FileAccess.WRITE);file.store_string(JSON.stringify({"id":case.id,"result":result,"expectedResult":case.result,"error":model.contract_message,"expectedError":case.error,"code":model.contract_error,"expectedCode":case.code,"differences":helper.diff_paths(model.state,case.expected)}))
			failed.append(case.id)
		if case.kind=="apply" and case.error==null:
			var repeated:=model.route_apply(case.fact);checks+=3
			if repeated!=case.repeated or model.contract_message!=str(case.repeatError if case.repeatError!=null else "") or not helper.same_json(model.state,case.afterRepeated):failed.append(case.id+":repeat")
	helper.free();print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false,"visual_test":false}));quit(0 if failed.is_empty() else 1)
