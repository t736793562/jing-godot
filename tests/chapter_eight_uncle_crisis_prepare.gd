extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var model=Model.new();var stream=FileAccess.open("res://../evidence/staged_uncle_crisis_prepare.jsonl",FileAccess.READ);var failed: Array=[];var checks:=0
	while stream.get_position()<stream.get_length():
		var line=stream.get_line()
		if line.is_empty():continue
		var case=helper.decode_exact(JSON.parse_string(line));model.state=case.initial.duplicate(true);model.contract_error="";model.contract_message="";var focus: Dictionary=model.state.focus;var event: Dictionary=focus.laterEvents[focus.eventId];var choice: Dictionary=event.choices[int(case.index)];var result:=model.prepare_uncle_crisis_choice(focus,event,choice);checks+=4
		if result!=(case.error==null) or model.contract_message!=str(case.error if case.error!=null else "") or not helper.same_json(model.state,case.expected) or model.state.rngState!=case.initial.rngState:
			if failed.is_empty():
				var file=FileAccess.open("res://../evidence/uncle_crisis_prepare_first_diff.json",FileAccess.WRITE);file.store_string(JSON.stringify({"id":case.id,"result":result,"error":model.contract_message,"expectedError":case.error,"differences":helper.diff_paths(model.state,case.expected)}))
			failed.append(case.id)
		if case.error==null:
			model.prepare_uncle_crisis_choice(focus,event,choice);checks+=2
			if model.contract_message!=str(case.repeatedError if case.repeatedError!=null else "") or not helper.same_json(model.state,case.afterRepeated):failed.append(case.id+":repeat")
	helper.free();print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false,"visual_test":false}));quit(0 if failed.is_empty() else 1)
