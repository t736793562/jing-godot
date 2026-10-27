extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var model=Model.new();var file=FileAccess.open("res://../evidence/staged_chapter_nine_lifecycle_reference.jsonl",FileAccess.READ);var checks:=0;var failed: Array=[]
	while file.get_position()<file.get_length():
		var line=file.get_line()
		if line.is_empty():continue
		var case=helper.decode_exact(JSON.parse_string(line));model.state=case.afterSelect.duplicate(true);model.contract_error="";model.contract_message="";var ok:=model.resolve_day_eleven_twelve_choice(int(case.choice));checks+=2
		if not ok or not helper.same_json(model.state,case.afterResolve):
			if failed.is_empty():
				var out=FileAccess.open("res://../evidence/chapter_nine_choice_first_diff.json",FileAccess.WRITE);out.store_string(JSON.stringify({"id":case.id,"differences":helper.diff_paths(model.state,case.afterResolve),"error":model.contract_message}))
			failed.append(case.id)
	helper.free();print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false,"main_integrated":true,"visual_test":false}));quit(0 if failed.is_empty() else 1)
