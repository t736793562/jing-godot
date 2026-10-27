extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var model=Model.new();var stream=FileAccess.open("res://../evidence/staged_c8_transfer_delta.jsonl",FileAccess.READ);var failed: Array=[];var checks:=0
	while stream.get_position()<stream.get_length():
		var line=stream.get_line()
		if line.is_empty():continue
		var case=helper.decode_exact(JSON.parse_string(line));model.state=case.initial.duplicate(true);model.contract_error="";model.contract_message="";var result:=model.apply_c8_photo_end_delta(case.fx.value,case.fx);checks+=3
		if result!=(case.error==null) or model.contract_message!=str(case.error if case.error!=null else "") or not helper.same_json(model.state,case.expected):failed.append(case.id)
		if case.error==null:
			model.contract_error="";model.contract_message="";model.apply_c8_photo_end_delta(case.fx.value,case.fx);checks+=2
			if model.contract_message!=str(case.repeatError if case.repeatError!=null else "") or not helper.same_json(model.state,case.afterRepeated):failed.append(case.id+":repeat")
	helper.free();print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false,"visual_test":false}));quit(0 if failed.is_empty() else 1)
