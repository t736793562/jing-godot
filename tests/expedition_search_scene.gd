extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var m=Model.new();var helper=load("res://../tests/chapter_seven_choice.gd").new();var file=FileAccess.open("res://../evidence/staged_expedition_search_scene_reference.jsonl",FileAccess.READ);var cases:=0;var checks:=0;var failed: Array=[]
	while file.get_position()<file.get_length():
		var line=file.get_line()
		if line.is_empty():continue
		var row=helper.decode_exact(JSON.parse_string(line));cases+=1;m.state=row.initial.duplicate(true);var f: Dictionary=row.focus.duplicate(true);m.bind_expedition_search(f);checks+=2
		if not helper.same_json(f,row.bound) or not helper.same_json(m.state,row.initial):failed.append(str(row.id)+":bind")
		var e: Dictionary=f.laterEvents[f.plan.eventIds["罗瑾"]];m.lock_expedition_search(f,e,row.choice);checks+=2
		if not helper.same_json(f,row.locked) or not helper.same_json(m.state,row.lockedState):failed.append(str(row.id)+":lock")
		m.state.phase="focusReturn";var result=m.settle_expedition_search(f,e);checks+=3
		if result!=row.result or not helper.same_json(m.state,row.after) or not helper.same_json(f,row.settled):
			if failed.is_empty():
				var out=FileAccess.open("res://../evidence/expedition_search_scene_first_diff.json",FileAccess.WRITE);out.store_string(JSON.stringify({"id":row.id,"differences":helper.diff_paths(m.state,row.after),"focus_differences":helper.diff_paths(f,row.settled),"result":result,"expected_result":row.result}))
			failed.append(str(row.id)+":settle")
	helper.free();print(JSON.stringify({"cases":cases,"checks":checks,"failed":failed,"main_integrated":true,"full_day_plan_tested":false,"visual_test":false}));quit(0 if failed.is_empty() else 1)
