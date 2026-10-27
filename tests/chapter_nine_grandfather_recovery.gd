extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var model=Model.new();var f=FileAccess.open("res://../evidence/staged_chapter_nine_grandfather_recovery.jsonl",FileAccess.READ);var checks:=0;var failed: Array=[]
	while f.get_position()<f.get_length():
		var line=f.get_line()
		if line.is_empty():continue
		var row=JSON.parse_string(line);model.state=row.initial.duplicate(true);
		for i in range(int(row.get("repeat",1))):model.finish_c9_grandfather_recovery(model.state.focus,row.get("event",{"id":"ordinary"}))
		checks+=1
		if not helper.same_json(model.state,row.expected):
			if failed.is_empty():
				var out=FileAccess.open("res://../evidence/chapter_nine_grandfather_recovery_first_diff.json",FileAccess.WRITE);out.store_string(JSON.stringify({"id":row.id,"diff":helper.diff_paths(model.state,row.expected)}))
			failed.append(row.id)
	helper.free();print(JSON.stringify({"checks":checks,"failed":failed,"controlled":true,"full_route":false,"main_integrated":true}));quit(0 if failed.is_empty() else 1)
