extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var file=FileAccess.open("res://../evidence/staged_expedition_continuous_reference.jsonl",FileAccess.READ);var m=Model.new();var cases:=0;var checks:=0;var failed: Array=[];var route: String="";var stopped:=false;var starts:=0
	var methods={"enter":"enter_day_eleven_twelve_focus","select":"select_day_eleven_twelve_focus","choice":"resolve_day_eleven_twelve_choice","return":"settle_day_eleven_twelve_return","response":"resolve_night_event","dawn":"finish_early_night"}
	while file.get_position()<file.get_length():
		var line=file.get_line()
		if line.is_empty():continue
		var row=helper.decode_exact(JSON.parse_string(line))
		if not OS.get_environment("EXPEDITION_ROUTE_FILTER").is_empty() and row.id not in OS.get_environment("EXPEDITION_ROUTE_FILTER").split(","):continue
		if row.id!=route:route=row.id;starts+=1;m=Model.new();m.state=row.initial.duplicate(true);stopped=false
		elif stopped:continue
		checks+=1
		if not helper.same_json(m.state,row.initial):failed.append(route+":boundary");stopped=true;continue
		cases+=1
		for step in row.steps:
			var result: bool
			if step.method=="search":
				# Source routing probes the Luo eligibility guard before choosing a fallback.
				if row.policy=="luo":m.search_luo_block()
				result=m.resolve_search(step.args[0])
				if result:m.state.phase="morning"
			elif step.method=="night":
				m.state.phase="night";m.set_night_option("meal",step.args[0].meal);m.set_night_option("fire",step.args[0].fire);result=m.confirm_early_night()
			else:result=m.callv(methods[step.method],step.args)
			checks+=2
			if result!=step.result or not helper.same_json(m.state,step.state):
				if failed.is_empty():
					var out=FileAccess.open("res://../evidence/expedition_continuous_first_diff.json",FileAccess.WRITE);out.store_string(JSON.stringify({"id":row.id,"day":row.day,"step":step.method,"result":result,"contract_error":m.contract_error,"differences":helper.diff_paths(m.state,step.state),"actual":m.state,"expected":step.state}))
				failed.append(route+":"+str(row.day)+":"+step.method);stopped=true;break
	helper.free();print(JSON.stringify({"starts":starts,"frames":cases,"checks":checks,"failed":failed,"main_integrated":true,"visual_test":false,"new_game_to_end":false}));quit(0 if failed.is_empty() else 1)
