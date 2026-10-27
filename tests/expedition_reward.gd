extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var m=Model.new();var helper=load("res://../tests/chapter_seven_choice.gd").new();var file=FileAccess.open("res://../evidence/staged_expedition_reward_reference.jsonl",FileAccess.READ);var cases:=0;var checks:=0;var failed: Array=[]
	while file.get_position()<file.get_length():
		var line=file.get_line()
		if line.is_empty():continue
		var row: Dictionary=JSON.parse_string(line);cases+=1;var before=var_to_bytes(row.a);var state_before=var_to_bytes(m.state);var rng=m.rng.state;var result=m.build_expedition_reward(row.a,row.mode);checks+=4
		if not helper.same_json(result,row.result) or before!=var_to_bytes(row.a) or state_before!=var_to_bytes(m.state) or rng!=m.rng.state:
			failed.append(cases)
			if failed.size()==1:
				var out=FileAccess.open("res://../evidence/expedition_reward_first_diff.json",FileAccess.WRITE);out.store_string(JSON.stringify({"row":row,"actual":result,"differences":helper.diff_paths(result,row.result)}))
		for key in row.hashes:
			checks+=1
			if m.expedition_roll(row.a,key)!=float(row.hashes[key])/4294967296.0:failed.append(str(cases)+":"+key)
	helper.free();print(JSON.stringify({"cases":cases,"checks":checks,"failed":failed,"main_integrated":true,"return_transition_tested":false,"visual_test":false}));quit(0 if failed.is_empty() else 1)
