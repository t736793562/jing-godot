extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var file=FileAccess.open("res://../evidence/staged_expedition_binding_reference.jsonl",FileAccess.READ);var cases:=0;var checks:=0;var failed: Array=[]
	while file.get_position()<file.get_length():
		var line=file.get_line()
		if line.is_empty():continue
		var row=helper.decode_exact(JSON.parse_string(line));cases+=1;var m=Model.new();m.state=row.initial.duplicate(true)
		for step in [["enter_day_eleven_twelve_focus",[],"entered","afterEnter"],["select_day_eleven_twelve_focus",["罗瑾"],"selected","afterSelect"]]:
			var result=m.callv(step[0],step[1]);checks+=2
			if result!=row[step[2]] or not helper.same_json(m.state,row[step[3]]):
				if failed.is_empty():
					var out=FileAccess.open("res://../evidence/expedition_binding_first_diff.json",FileAccess.WRITE);out.store_string(JSON.stringify({"id":row.id,"step":step[0],"result":result,"contract_error":m.contract_error,"differences":helper.diff_paths(m.state,row[step[3]]),"actual":m.state,"expected":row[step[3]]}))
				failed.append(str(row.id)+":"+step[0]);break
	helper.free();print(JSON.stringify({"cases":cases,"checks":checks,"failed":failed,"main_integrated":true,"visual_test":false}));quit(0 if failed.is_empty() else 1)
