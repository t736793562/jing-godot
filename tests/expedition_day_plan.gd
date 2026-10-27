extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var file=FileAccess.open("res://../evidence/staged_expedition_day_plan_reference.jsonl",FileAccess.READ);var cases:=0;var checks:=0;var failed: Array=[]
	while file.get_position()<file.get_length():
		var line=file.get_line()
		if line.is_empty():continue
		var row=helper.decode_exact(JSON.parse_string(line));cases+=1;var m=Model.new();m.state=row.initial.duplicate(true);var plan=m.make_pre_photo_plan();checks+=2
		if row.error!=null or not helper.same_json(plan,row.plan) or not helper.same_json(m.state,row.after):
			if failed.is_empty():
				var out=FileAccess.open("res://../evidence/expedition_day_plan_first_diff.json",FileAccess.WRITE);out.store_string(JSON.stringify({"id":row.id,"source_error":row.error,"contract_error":m.contract_error,"plan_diff":helper.diff_paths(plan,row.plan),"state_diff":helper.diff_paths(m.state,row.after),"actual":plan,"expected":row.plan}))
			failed.append(row.id)
	helper.free();print(JSON.stringify({"cases":cases,"checks":checks,"failed":failed,"main_integrated":true,"full_day_execution_tested":false,"visual_test":false}));quit(0 if failed.is_empty() else 1)
