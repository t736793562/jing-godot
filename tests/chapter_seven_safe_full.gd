extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var data=JSON.parse_string(FileAccess.get_file_as_string("res://../evidence/chapter_seven_safe_full_reference.json"));var model=Model.new();var failed: Array=[];var checks:=0
	for case in data.cases:
		model.state=case.initial.duplicate(true);model.contract_error="";model.contract_message="";var result:=model.resolve_day_eleven_twelve_choice(int(case.index));checks+=3
		if result!=case.result or not helper.same_json(model.state,case.expected) or model.state.photo.prints!=case.initial.photo.prints:failed.append(case.id)
	helper.free();print(JSON.stringify({"checks":checks,"failed":failed,"visual_test":false}));quit(0 if failed.is_empty() else 1)
