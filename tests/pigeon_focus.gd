extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var file=FileAccess.open("res://../evidence/staged_pigeon_focus_reference.jsonl",FileAccess.READ);var cases:=0;var checks:=0;var failed: Array=[];var diffs: Dictionary={}
	while file.get_position()<file.get_length():
		var line=file.get_line()
		if line.is_empty():continue
		var row=helper.decode_exact(JSON.parse_string(line));cases+=1;var m=Model.new();m.state=row.initial.duplicate(true);var steps: Array=[["enter_first_day_focus" if row.day<10 else "enter_day_eleven_twelve_focus",[],"entered","afterEnter"]]
		if row.isPickup:steps.append_array([["select_first_day_focus" if row.day<10 else "select_day_eleven_twelve_focus",["罗瑾"],"selected","afterSelect"],["resolve_first_day_focus_choice" if row.day<10 else "resolve_day_eleven_twelve_choice",[row.choice],"resolved","afterResolve"],["settle_first_day_focus_return" if row.day<10 else "settle_day_eleven_twelve_return",[],"returned","afterReturn"],["settle_first_day_focus_return" if row.day<10 else "settle_day_eleven_twelve_return",[],"repeated","afterRepeat"]])
		for step in steps:
			var result=m.callv(step[0],step[1]);checks+=2
			if result!=row[step[2]] or not helper.same_json(m.state,row[step[3]]):
				if failed.is_empty():
					var out=FileAccess.open("res://../evidence/pigeon_focus_first_diff.json",FileAccess.WRITE);out.store_string(JSON.stringify({"id":row.id,"day":row.day,"step":step[0],"result":result,"contract_error":m.contract_error,"differences":helper.diff_paths(m.state,row[step[3]]),"actual":m.state,"expected":row[step[3]]}))
				var key: String=str(row.day)+":"+step[0]
				if not diffs.has(key):diffs[key]={"id":row.id,"result":result,"contract_error":m.contract_error,"differences":helper.diff_paths(m.state,row[step[3]])}
				failed.append(str(row.id)+":"+step[0]);break
	var summary=FileAccess.open("res://../evidence/pigeon_focus_diff_summary.json",FileAccess.WRITE);summary.store_string(JSON.stringify(diffs));helper.free();print(JSON.stringify({"cases":cases,"checks":checks,"failed":failed,"main_integrated":true,"visual_test":false,"natural_acquisition_tested":false}));quit(0 if failed.is_empty() else 1)
