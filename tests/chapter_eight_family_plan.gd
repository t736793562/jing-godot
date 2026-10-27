extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var model=Model.new();var stream=FileAccess.open("res://../evidence/staged_chapter_eight_family_plan.jsonl",FileAccess.READ);var failed: Array=[];var checks:=0
	while stream.get_position()<stream.get_length():
		var line=stream.get_line()
		if line.is_empty():continue
		var case=helper.decode_exact(JSON.parse_string(line));model.state=case.initial.duplicate(true);model.contract_error="";model.contract_message="";var result=model.make_pre_photo_plan();checks+=3
		if model.contract_error!="" or not helper.same_json(model.state,case.after) or not helper.same_json(result,case.plan):
			if failed.is_empty():
				var file=FileAccess.open("res://../evidence/chapter_eight_family_plan_first_diff.json",FileAccess.WRITE);file.store_string(JSON.stringify({"id":case.id,"error":model.contract_message,"differences":helper.diff_paths(model.state,case.after),"planDifferences":helper.diff_paths(result,case.plan)}))
			failed.append(case.id)
	helper.free();print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false,"visual_test":false}));quit(0 if failed.is_empty() else 1)
