extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var file=FileAccess.open("res://../evidence/staged_expedition_recall_reference.jsonl",FileAccess.READ);var cases:=0;var checks:=0;var failed: Array=[]
	while file.get_position()<file.get_length():
		var line=file.get_line()
		if line.is_empty():continue
		var row=helper.decode_exact(JSON.parse_string(line));cases+=1;var m=Model.new();m.state=row.initial.duplicate(true);var before=var_to_bytes(m.state);checks+=2
		if not helper.same_json(m.unread_expedition_recall(),row.unread) or before!=var_to_bytes(m.state):failed.append(row.id+":query")
		var unknown=m.open_expedition_recall("not-a-real-trip");checks+=2
		if unknown!=row.unknown or not helper.same_json(m.state,row.afterUnknown):failed.append(row.id+":missing")
		var opened=m.open_expedition_recall(m.state.expedition.history[-1].id);checks+=2
		if opened!=row.opened or not helper.same_json(m.state,row.afterOpen):failed.append(row.id+":open")
		var closed=m.close_expedition_recall();checks+=3
		if closed!=row.closed or not helper.same_json(m.state,row.afterClose) or not helper.same_json(m.unread_expedition_recall(),row.unreadAfter):
			if failed.is_empty():
				var out=FileAccess.open("res://../evidence/expedition_recall_first_diff.json",FileAccess.WRITE);out.store_string(JSON.stringify({"id":row.id,"differences":helper.diff_paths(m.state,row.afterClose)}))
			failed.append(row.id+":close")
	helper.free();print(JSON.stringify({"cases":cases,"checks":checks,"failed":failed,"main_integrated":true,"visual_test":false}));quit(0 if failed.is_empty() else 1)
