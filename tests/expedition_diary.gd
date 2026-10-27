extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var m=Model.new();var helper=load("res://../tests/chapter_seven_choice.gd").new();var file=FileAccess.open("res://../evidence/staged_expedition_diary_reference.jsonl",FileAccess.READ);var cases:=0;var checks:=0;var failed: Array=[]
	while file.get_position()<file.get_length():
		var line=file.get_line()
		if line.is_empty():continue
		var row: Dictionary=JSON.parse_string(line);cases+=1;m.state=row.initial.duplicate(true);var f: Dictionary=row.before.duplicate(true);m.finish_expedition_diary(f,{"expeditionSearch":true});checks+=2
		if not helper.same_json(f,row.after) or not helper.same_json(m.state,row.initial):
			if failed.is_empty():
				var out=FileAccess.open("res://../evidence/expedition_diary_first_diff.json",FileAccess.WRITE);out.store_string(JSON.stringify({"case":cases,"differences":helper.diff_paths(f,row.after)}))
			failed.append(cases)
	helper.free();print(JSON.stringify({"cases":cases,"checks":checks,"failed":failed,"main_integrated":true,"visual_test":false}));quit(0 if failed.is_empty() else 1)
