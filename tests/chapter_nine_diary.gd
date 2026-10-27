extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var model=Model.new();var file=FileAccess.open("res://../evidence/staged_chapter_nine_diary.jsonl",FileAccess.READ);var checks:=0;var failed: Array=[]
	while file.get_position()<file.get_length():
		var line=file.get_line()
		if line.is_empty():continue
		var case=JSON.parse_string(line);model.state=case.initial.duplicate(true);var focus: Dictionary=model.state.focus;var event: Dictionary=focus.laterEvents[focus.eventId];var ok:=model.finish_chapter_nine_diary(focus,event,event.choices[int(focus.choiceIndex)]);checks+=2
		if not ok or not helper.same_json(model.state,case.expected):
			if failed.is_empty():
				var out=FileAccess.open("res://../evidence/chapter_nine_diary_first_diff.json",FileAccess.WRITE);out.store_string(JSON.stringify({"id":case.id,"differences":helper.diff_paths(model.state,case.expected),"error":model.contract_message}))
			failed.append(case.id)
	helper.free();print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false,"main_integrated":true,"visual_test":false}));quit(0 if failed.is_empty() else 1)
