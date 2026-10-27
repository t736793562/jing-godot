extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func stripped(s: Dictionary) -> Dictionary:
	var result: Dictionary=s.duplicate(true)
	for event in result.focus.laterEvents.values():
		for choice in event.choices:choice.erase("closures");choice.erase("diaries")
	return result
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var model=Model.new();var file=FileAccess.open("res://../evidence/staged_chapter_nine_transfer_numbers.jsonl",FileAccess.READ);var checks:=0;var failed: Array=[]
	while file.get_position()<file.get_length():
		var line=file.get_line()
		if line.is_empty():continue
		var case=helper.decode_exact(JSON.parse_string(line));model.state=case.initial.duplicate(true);model.contract_error="";model.contract_message="";var focus: Dictionary=model.state.focus;var event: Dictionary=focus.laterEvents[focus.plan.eventIds["罗瑾"]];var requirement:=model.photo_transfer_requirement();var ok:=model.prepare_c9_transfer(focus,event,event.choices[int(case.index)]);checks+=3
		if not helper.same_json(requirement,case.requirement) or ok!=(case.error==null) or not helper.same_json(model.state,case.expected):
			if failed.is_empty():
				var out=FileAccess.open("res://../evidence/chapter_nine_transfer_first_diff.json",FileAccess.WRITE);out.store_string(JSON.stringify({"id":case.id,"actualError":model.contract_message,"expectedError":case.error,"differences":helper.diff_paths(model.state,case.expected)}))
			failed.append(case.id)
	helper.free();print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false,"main_integrated":true,"visual_test":false,"result_prose_tested":true}));quit(0 if failed.is_empty() else 1)
