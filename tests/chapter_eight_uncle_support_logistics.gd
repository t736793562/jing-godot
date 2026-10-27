extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var model=Model.new();var stream=FileAccess.open("res://../evidence/staged_uncle_support_logistics.jsonl",FileAccess.READ);var failed: Array=[];var checks:=0
	while stream.get_position()<stream.get_length():
		var line=stream.get_line()
		if line.is_empty():continue
		var case=JSON.parse_string(line);model.state=case.initial.duplicate(true);model.contract_error="";model.contract_message="";var record: Dictionary=case.record.duplicate(true);var result:=model.advance_uncle_support_logistics(record,case.target);checks+=4
		if case.error==null and result!=case.result or model.contract_message!=str(case.error if case.error!=null else "") or not helper.same_json(model.state,case.expected) or not helper.same_json(record,case.expectedRecord):
			if failed.is_empty():
				var file=FileAccess.open("res://../evidence/uncle_support_logistics_first_diff.json",FileAccess.WRITE);file.store_string(JSON.stringify({"id":case.id,"result":result,"expectedResult":case.result,"error":model.contract_message,"expectedError":case.error,"stateDiff":helper.diff_paths(model.state,case.expected),"recordDiff":helper.diff_paths(record,case.expectedRecord)}))
			failed.append(case.id)
		if case.error==null:
			var repeated:=model.advance_uncle_support_logistics(record,case.target);checks+=4
			if repeated!=case.repeated or model.contract_message!=str(case.repeatError if case.repeatError!=null else "") or not helper.same_json(model.state,case.afterRepeated) or not helper.same_json(record,case.recordAfterRepeated):failed.append(case.id+":repeat")
	helper.free();print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false,"visual_test":false}));quit(0 if failed.is_empty() else 1)
