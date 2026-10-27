extends SceneTree
const Model=preload("res://scripts/game_model.gd")
const Store=preload("res://scripts/native_continuation_store.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var file=FileAccess.open("res://../evidence/staged_pigeon_early_save_reference.jsonl",FileAccess.READ);var checks:=0;var failed: Array=[];var cases:=0;var store=Store.new();var diffs: Dictionary={}
	var mapping={"enter":"enter_first_day_focus","select":"select_first_day_focus","choice":"resolve_first_day_focus_choice","return":"settle_first_day_focus_return","response":"resolve_night_event","dawn":"finish_early_night"}
	while file.get_position()<file.get_length():
		var line=file.get_line()
		if line.is_empty():continue
		var row=helper.decode_exact(JSON.parse_string(line));cases+=1;var m=Model.new();m.state=row.initial.duplicate(true)
		var encoded: String=store.encode(m.state);checks+=1
		if encoded.is_empty():failed.append(row.id+":initial-save:"+store.error)
		for step in row.steps:
			var result: bool
			if step.method=="night":m.state.phase="night";m.set_night_option("meal",row.beforeNight.night.meal);m.set_night_option("fire",row.beforeNight.night.fire);result=m.confirm_early_night()
			else:result=m.callv(mapping[step.method],step.args)
			checks+=2
			if result!=step.result or not helper.same_json(m.state,step.state):
				failed.append(row.id+":"+step.method)
				if not diffs.has(step.method):diffs[step.method]={"id":row.id,"result":result,"error":m.contract_error,"differences":helper.diff_paths(m.state,step.state)}
				break
			encoded=store.encode(m.state);checks+=2
			if encoded.is_empty():failed.append(row.id+":"+step.method+":save:"+store.error);continue
			var decoded: Dictionary=store.decode(encoded)
			if decoded.is_empty() or var_to_bytes(decoded)!=var_to_bytes(m.state):failed.append(row.id+":"+step.method+":roundtrip:"+store.error)
	var summary=FileAccess.open("res://../evidence/pigeon_early_save_diff_summary.json",FileAccess.WRITE);summary.store_string(JSON.stringify(diffs));helper.free();print(JSON.stringify({"cases":cases,"checks":checks,"failed":failed,"main_integrated":true,"real_disk":false,"visual_test":false,"scope":"Model source parity plus strict native typed encode/decode at early checkpoints, including D11 anchors."}));quit(0 if failed.is_empty() else 1)
