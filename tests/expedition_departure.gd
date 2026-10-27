extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var m=Model.new();var helper=load("res://../tests/chapter_seven_choice.gd").new();var file=FileAccess.open("res://../evidence/staged_expedition_departure_reference.jsonl",FileAccess.READ);var cases:=0;var checks:=0;var failed: Array=[]
	while file.get_position()<file.get_length():
		var line=file.get_line()
		if line.is_empty():continue
		var row=helper.decode_exact(JSON.parse_string(line));cases+=1;m.state=row.initial.duplicate(true);var before=var_to_bytes(m.state);var rng=m.rng.state;var candidates=m.expedition_special_candidates(m.state.expedition.plan);checks+=3
		if not helper.same_json(candidates,row.candidates) or before!=var_to_bytes(m.state) or rng!=m.rng.state:failed.append(str(row.id)+":query")
		var result=m.commit_expedition();checks+=2
		if result!=row.result or not helper.same_json(m.state,row.after):
			if failed.is_empty():
				var out=FileAccess.open("res://../evidence/expedition_departure_first_diff.json",FileAccess.WRITE);out.store_string(JSON.stringify({"id":row.id,"result":result,"expected_result":row.result,"differences":helper.diff_paths(m.state,row.after),"actual":m.state,"expected":row.after}))
			failed.append(str(row.id)+":departure")
		var repeated=m.commit_expedition();checks+=2
		if repeated!=row.repeat or not helper.same_json(m.state,row.afterRepeat):failed.append(str(row.id)+":repeat")
	helper.free();print(JSON.stringify({"cases":cases,"checks":checks,"failed":failed,"main_integrated":true,"night_transition_tested":false,"visual_test":false}));quit(0 if failed.is_empty() else 1)
