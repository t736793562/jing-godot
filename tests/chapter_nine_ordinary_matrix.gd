extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var model=Model.new();var file=FileAccess.open("res://../evidence/staged_chapter_nine_binding_matrix.jsonl",FileAccess.READ);var checks:=0;var failed: Array=[];var skipped:=0
	while file.get_position()<file.get_length():
		var line=file.get_line()
		if line.is_empty():continue
		var case=helper.decode_exact(JSON.parse_string(line))
		for target in case.expected.focus.plan.targets:
			model.state=case.expected.duplicate(true);var focus: Dictionary=model.state.focus;var expected: Dictionary=focus.laterEvents[focus.plan.eventIds[target]]
			if ["nodeId","motherCare","motherCrisis","uncleCrisis","uncleBoundary","neighbourhood","neighbourParcel","messageThread","custodyHandoff","custodyNight","r18GrandfatherHome","photoEnd","photoMid"].any(func(k):return model.js_truthy(expected.get(k))):skipped+=1;continue
			var actual: Dictionary=model.make_chapter_home_base(focus) if target=="home" else model.make_pre_photo_outdoor_event(focus,target)
			if target=="home" and not actual.is_empty():
				focus.laterEvents[actual.id]=actual;focus.plan.eventIds.home=actual.id;model.apply_chapter_maintenance(focus);actual=focus.laterEvents[focus.plan.eventIds.home]
			if actual.get("conditionKind") in ["care","recovery"]:model.chapter_nine_care_reader.decorate(model,focus,actual)
			if target=="home":model.apply_rope_memory_echo(focus,actual);model.apply_rope_editorial(focus,actual)
			checks+=1
			if not helper.same_json(actual,expected):
				if failed.is_empty():
					var out=FileAccess.open("res://../evidence/chapter_nine_ordinary_matrix_first_diff.json",FileAccess.WRITE);out.store_string(JSON.stringify({"id":case.id,"target":target,"differences":helper.diff_paths(actual,expected),"actual":actual,"expected":expected}))
				failed.append(case.id+":"+target)
	helper.free();print(JSON.stringify({"checks":checks,"skipped_special_events":skipped,"failed":failed,"main_integrated":true,"full_game":false,"visual_test":false}));quit(0 if failed.is_empty() else 1)
