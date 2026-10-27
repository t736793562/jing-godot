extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var m=Model.new();var helper=load("res://../tests/chapter_seven_choice.gd").new();var file=FileAccess.open("res://../evidence/staged_expedition_morning_reference.jsonl",FileAccess.READ);var cases:=0;var checks:=0;var failed: Array=[]
	while file.get_position()<file.get_length():
		var line=file.get_line()
		if line.is_empty():continue
		var row=helper.decode_exact(JSON.parse_string(line));cases+=1;m.state=row.initial.duplicate(true)
		for i in range(row.steps.size()):
			var step=row.steps[i];var patch=step.fixturePatch
			for key in ["day","phase","ended"]:m.state[key]=patch[key]
			if patch.kill:m.state.people[row.initial.expedition.active.name].alive=false
			if patch.search!=null and m.state.expedition.active!=null:m.state.expedition.active.search=patch.search.duplicate(true)
			checks+=1
			if not helper.same_json(m.state,step.before):failed.append(str(row.id)+":"+str(i)+":continuity")
			var rng=m.rng.state;m.process_expedition_morning();checks+=2
			if not helper.same_json(m.state,step.after) or rng!=m.rng.state:
				if failed.is_empty():
					var out=FileAccess.open("res://../evidence/expedition_morning_first_diff.json",FileAccess.WRITE);out.store_string(JSON.stringify({"id":row.id,"step":i,"differences":helper.diff_paths(m.state,step.after),"actual":m.state,"expected":step.after}))
				failed.append(str(row.id)+":"+str(i))
			m.process_expedition_morning();checks+=1
			if not helper.same_json(m.state,step.afterRepeat):failed.append(str(row.id)+":"+str(i)+":repeat")
	helper.free();print(JSON.stringify({"cases":cases,"checks":checks,"failed":failed,"main_integrated":true,"natural_game_trajectory":false,"visual_test":false}));quit(0 if failed.is_empty() else 1)
