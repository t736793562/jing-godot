extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var model=Model.new();var stream=FileAccess.open("res://../evidence/staged_r18_family_return.jsonl",FileAccess.READ);var failed: Array=[];var checks:=0
	while stream.get_position()<stream.get_length():
		var line=stream.get_line()
		if line.is_empty():continue
		var case=helper.decode_exact(JSON.parse_string(line));model.state=case.initial.duplicate(true);model.contract_error="";model.contract_message="";model.finish_r18_family_return(model.state.focus,case.before);checks+=2
		if model.contract_error!="" or not helper.same_json(model.state,case.expected):
			if failed.is_empty():
				var file=FileAccess.open("res://../evidence/r18_family_return_first_diff.json",FileAccess.WRITE);file.store_string(JSON.stringify({"id":case.id,"error":model.contract_message,"differences":helper.diff_paths(model.state,case.expected)}))
			failed.append(case.id)
		model.finish_r18_family_return(model.state.focus,model._object(model.state.memory.get("grandfatherHomeR18")).duplicate(true));checks+=1
		if not helper.same_json(model.state,case.afterRepeated):failed.append(case.id+":repeat")
	helper.free();print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false,"visual_test":false}));quit(0 if failed.is_empty() else 1)
