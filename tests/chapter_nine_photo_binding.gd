extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var model=Model.new();var file=FileAccess.open("res://../evidence/staged_chapter_nine_lifecycle_reference.jsonl",FileAccess.READ);var checks:=0;var failed: Array=[]
	while file.get_position()<file.get_length():
		var line=file.get_line()
		if line.is_empty():continue
		var case=helper.decode_exact(JSON.parse_string(line));model.state=case.afterEnter.duplicate(true);model.contract_error="";model.contract_message="";var focus: Dictionary=model.state.focus
		if "罗瑾" not in focus.plan.targets:continue
		var expected: Dictionary=focus.laterEvents[focus.plan.eventIds["罗瑾"]]
		if not expected.get("photoMid",false) and not expected.get("photoEnd",false):continue
		var node: Variant=expected.get("nodeId");var actual: Dictionary=model.make_bound_chapter_nine_node(focus) if node!=null else model.make_c9_photo_scene(focus);checks+=1
		if not helper.same_json(actual,expected):
			if failed.is_empty():
				var out=FileAccess.open("res://../evidence/chapter_nine_photo_binding_first_diff.json",FileAccess.WRITE);out.store_string(JSON.stringify({"id":case.id,"differences":helper.diff_paths(actual,expected),"error":model.contract_message}))
			failed.append(case.id)
	helper.free();print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false,"main_integrated":true,"visual_test":false}));quit(0 if failed.is_empty() and checks>0 else 1)
