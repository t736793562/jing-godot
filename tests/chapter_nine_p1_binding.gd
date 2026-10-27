extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var model=Model.new();var file=FileAccess.open("res://../evidence/staged_chapter_nine_p1_binding.jsonl",FileAccess.READ);var checks:=0;var failed: Array=[]
	while file.get_position()<file.get_length():
		var line=file.get_line()
		if line.is_empty():continue
		var case=JSON.parse_string(line);model.state=case.base.duplicate(true);model.bind_c9_p1_context(model.state.focus);checks+=1
		if not helper.same_json(model.state,case.bound):failed.append(case.id+":bind")
		model.state=case.beforeChoice.duplicate(true);var f: Dictionary=model.state.focus;var e: Dictionary=f.laterEvents[f.eventId];model.prepare_c9_transfer(f,e,e.choices[int(case.index)]);checks+=1
		if not helper.same_json(model.state,case.afterChoice):failed.append(case.id+":choice")
		var previous=var_to_bytes(model.state);model.prepare_c9_transfer(f,e,e.choices[int(case.index)]);checks+=1
		if previous!=var_to_bytes(model.state):failed.append(case.id+":repeat")
	helper.free();print(JSON.stringify({"checks":checks,"failed":failed,"main_integrated":true,"full_game":false,"visual_test":false}));quit(0 if failed.is_empty() else 1)
