extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var model=Model.new();var stream=FileAccess.open("res://../evidence/staged_uncle_crisis_conditions.jsonl",FileAccess.READ);var failed: Array=[];var checks:=0
	while stream.get_position()<stream.get_length():
		var line=stream.get_line()
		if line.is_empty():continue
		var case=JSON.parse_string(line);model.state=case.initial.duplicate(true);model.contract_error="";model.contract_message="";var result: Variant
		if case.kind=="requirement":result=model.uncle_crisis_requirement(case.choice)
		elif case.kind=="preparation":result=model.uncle_preparation_return_allowed(model.state.focus,case.event)
		else:result=model.person_presence_label("安仁叔叔")
		checks+=2
		if not helper.same_json(result,case.result) or not helper.same_json(model.state,case.expected):
			if failed.is_empty():
				var file=FileAccess.open("res://../evidence/uncle_crisis_conditions_first_diff.json",FileAccess.WRITE);file.store_string(JSON.stringify({"id":case.id,"result":result,"expectedResult":case.result,"error":model.contract_message,"differences":helper.diff_paths(model.state,case.expected)}))
			failed.append(case.id)
		if case.kind=="presence":
			checks+=1
			if model.character_rest_reason("安仁叔叔")!=case.rest:failed.append(case.id+":rest")
	helper.free();print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false,"visual_test":false}));quit(0 if failed.is_empty() else 1)
