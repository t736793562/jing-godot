extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var m=Model.new();var helper=load("res://../tests/chapter_seven_choice.gd").new();var file=FileAccess.open("res://../evidence/staged_expedition_special_reference.jsonl",FileAccess.READ);var cases:=0;var checks:=0;var failed: Array=[]
	while file.get_position()<file.get_length():
		var line=file.get_line()
		if line.is_empty():continue
		var row: Dictionary=JSON.parse_string(line);cases+=1;m.state=row.initial.duplicate(true);var before=var_to_bytes(row.a);var rng=m.rng.state;var special=m.resolve_expedition_special(row.a,row.mode);var recall=m.build_expedition_recall(row.a,row.mode,special);checks+=5
		if not helper.same_json(special,row.special) or not helper.same_json(m.state,row.after) or not helper.same_json(recall,row.recall) or before!=var_to_bytes(row.a) or rng!=m.rng.state:
			if failed.is_empty():
				var out=FileAccess.open("res://../evidence/expedition_special_first_diff.json",FileAccess.WRITE);out.store_string(JSON.stringify({"row":row,"actual":{"special":special,"recall":recall},"differences":helper.diff_paths(recall,row.recall)}))
			failed.append(cases)
	helper.free();print(JSON.stringify({"cases":cases,"checks":checks,"failed":failed,"main_integrated":true,"return_transition_tested":false,"visual_test":false}));quit(0 if failed.is_empty() else 1)
