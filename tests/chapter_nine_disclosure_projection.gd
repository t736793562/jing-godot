extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var model=Model.new();var stream=FileAccess.open("res://../evidence/staged_disclosure_projection.jsonl",FileAccess.READ);var failed: Array=[];var checks:=0
	while stream.get_position()<stream.get_length():
		var line=stream.get_line()
		if line.is_empty():continue
		var case=helper.decode_exact(JSON.parse_string(line));model.state=case.initial.duplicate(true);model.contract_error="preserve";model.contract_message="previous";var projection:=model.disclosure_projection();var epilogue:=model.disclosure_epilogue(case.hasEvidence);checks+=4
		if not helper.same_json(projection,case.projection) or not helper.same_json(epilogue,case.epilogue) or not helper.same_json(model.state,case.expected) or model.contract_error!="preserve" or model.contract_message!="previous":
			if failed.is_empty():
				var file=FileAccess.open("res://../evidence/disclosure_projection_first_diff.json",FileAccess.WRITE);file.store_string(JSON.stringify({"id":case.id,"projection":helper.diff_paths(projection,case.projection),"epilogue":helper.diff_paths(epilogue,case.epilogue)}))
			failed.append(case.id)
	helper.free();print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false,"visual_test":false,"main_integrated":true}));quit(0 if failed.is_empty() else 1)
