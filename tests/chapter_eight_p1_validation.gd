extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var model=Model.new();var stream=FileAccess.open("res://../evidence/staged_p1_validation.jsonl",FileAccess.READ);var failed: Array=[];var checks:=0
	while stream.get_position()<stream.get_length():
		var line=stream.get_line()
		if line.is_empty():continue
		var case=helper.decode_exact(JSON.parse_string(line));model.state=case.initial.duplicate(true);model.contract_error="";model.contract_message="";var result: bool=model.p1_validate_state();var projections: Array=model.PEOPLE.map(func(n):return model.p1_delivery_projection(n));checks+=4
		if result!=(case.error==null) or model.contract_message!=str(case.error if case.error!=null else "") or not helper.same_json(projections,case.projections) or not helper.same_json(model.state,case.initial):
			if failed.is_empty():
				var file=FileAccess.open("res://../evidence/p1_validation_first_diff.json",FileAccess.WRITE);file.store_string(JSON.stringify({"id":case.id,"result":result,"error":model.contract_message,"expectedError":case.error,"differences":helper.diff_paths(projections,case.projections)}))
			failed.append(case.id)
	helper.free();print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false,"visual_test":false}));quit(0 if failed.is_empty() else 1)
