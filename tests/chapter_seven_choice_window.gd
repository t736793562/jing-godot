extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://../evidence/staged_chapter_seven_choice_window.json"));var model=Model.new();var failed: Array=[];var checks:=0
	for case in data.cases:
		model.state=case.initial.duplicate(true);var before=var_to_bytes(model.state);checks+=2
		if model.later_event_eligible(case.event,case.plan)!=case.eligible or var_to_bytes(model.state)!=before:failed.append(case.id)
	print(JSON.stringify({"checks":checks,"failed":failed,"visual_test":false}));quit(0 if failed.is_empty() else 1)
