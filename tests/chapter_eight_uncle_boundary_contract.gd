extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var model=Model.new();var stream=FileAccess.open("res://../evidence/staged_uncle_boundary_contract.jsonl",FileAccess.READ);var failed: Array=[];var checks:=0
	while stream.get_position()<stream.get_length():
		var line=stream.get_line()
		if line.is_empty():continue
		var case=JSON.parse_string(line);model.state=case.initial.duplicate(true);model.contract_error="";model.contract_message="";var result: Variant=null
		match case.kind:
			"morning":model.process_uncle_boundary_morning()
			"requirement":result=model.uncle_boundary_requirement(case.choice)
			"return":result=model.uncle_boundary_return_allowed(case.packet)
			"diary":model.finish_uncle_boundary_diary(model.state.focus,case.event)
		checks+=3
		if not helper.same_json(model.state,case.expected) or case.has("result") and not helper.same_json(result,case.result) or model.contract_error!="":
			if failed.is_empty():
				var file=FileAccess.open("res://../evidence/uncle_boundary_contract_first_diff.json",FileAccess.WRITE);file.store_string(JSON.stringify({"id":case.id,"result":result,"expectedResult":case.get("result"),"error":model.contract_message,"differences":helper.diff_paths(model.state,case.expected)}))
			failed.append(case.id)
		if case.kind=="morning":
			model.process_uncle_boundary_morning();checks+=1
			if not helper.same_json(model.state,case.afterRepeated):failed.append(case.id+":repeat")
		if case.kind=="return":
			checks+=1
			if model.uncle_boundary_has_returned(model.state.focus)!=case.hasReturned:failed.append(case.id+":has-returned")
	helper.free();print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false,"visual_test":false}));quit(0 if failed.is_empty() else 1)
