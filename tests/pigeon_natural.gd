extends SceneTree
const Model=preload("res://scripts/game_model.gd")
const Store=preload("res://scripts/native_continuation_store.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var file=FileAccess.open("res://../evidence/staged_pigeon_natural_reference.jsonl",FileAccess.READ);var checks:=0;var failed: Array=[];var cases:=0;var steps_count:=0;var store=Store.new()
	while file.get_position()<file.get_length():
		var line=file.get_line()
		if line.is_empty():continue
		var row=helper.decode_exact(JSON.parse_string(line));cases+=1;var m=Model.new();m.new_game(row.seed);m.dispatch("introNext");m.dispatch("tutorialSkip")
		for name in row.pack:
			for id in row.pack[name]:
				checks+=1
				if not m.add_loadout(id,name):failed.append(row.id+":pack")
		var setup: bool=m.start_opening() and m.choose_opening(0) and m.settle_opening_arrival();checks+=2
		if not setup or not helper.same_json(m.state,row.initial):failed.append(row.id+":setup");continue
		for step in row.steps:
			var result: bool=false
			match step.op:
				"enter":result=m.enter_first_day_focus()
				"select":result=m.select_first_day_focus(step.args[0])
				"choice":result=m.resolve_first_day_focus_choice(int(step.args[0]))
				"return":result=m.settle_first_day_focus_return()
				"open_night":m.state.phase="night";result=m.set_night_option("meal",step.args[0].meal) and m.set_night_option("fire",step.args[0].fire)
				"feed":result=m.feed_animal(step.args[0])
				"pigeon":result=m.set_pigeon_action(step.args[0])
				"night":result=m.confirm_early_night()
				"response":result=m.resolve_night_event(step.args[0])
				"dawn":result=m.finish_early_night()
			checks+=2;steps_count+=1
			if result!=step.result or not helper.same_json(m.state,step.state):
				if failed.is_empty():
					var out=FileAccess.open("res://../evidence/pigeon_natural_first_diff.json",FileAccess.WRITE);out.store_string(JSON.stringify({"id":row.id,"day":m.state.day,"op":step.op,"result":result,"contract_error":m.contract_error,"differences":helper.diff_paths(m.state,step.state),"actual":m.state,"expected":step.state}))
				failed.append(row.id+":"+step.op);break
			if m.state.phase in ["focusResult","focusReturn","nightEvent","morning"]:
				var encoded: String=store.encode(m.state);checks+=1
				if encoded.is_empty():failed.append(row.id+":save:"+str(m.state.day)+":"+m.state.phase+":"+store.error);break
	helper.free();print(JSON.stringify({"cases":cases,"steps":steps_count,"checks":checks,"failed":failed,"main_integrated":true,"visual_test":false,"real_disk":false,"normal_start_to_d11":true}));quit(0 if failed.is_empty() and cases>0 else 1)
