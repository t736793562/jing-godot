extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var model=Model.new();var file=FileAccess.open("res://../evidence/staged_chapter_nine_ending.jsonl",FileAccess.READ);var checks:=0;var failed: Array=[]
	while file.get_position()<file.get_length():
		var line=file.get_line()
		if line.is_empty():continue
		var case=JSON.parse_string(line);model.state=case.initial.duplicate(true);var before=var_to_bytes(model.state);var result:=model.ending_photo_projection();checks+=2
		if not helper.same_json(result,case.expected) or before!=var_to_bytes(model.state):failed.append({"id":case.id,"actual":result,"expected":case.expected})
	helper.free();print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false,"main_integrated":true,"visual_test":false}));quit(0 if failed.is_empty() else 1)
