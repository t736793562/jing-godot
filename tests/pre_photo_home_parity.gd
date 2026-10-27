extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var stream=FileAccess.open("res://data/pre_photo_choice_reference.jsonl",FileAccess.READ);var model=Model.new();var failed: Array=[];var seen: Dictionary={};var checks:=0
	while stream.get_position()<stream.get_length():
		var line=stream.get_line()
		if line.is_empty():continue
		var case=JSON.parse_string(line);model.state=case.initial.duplicate(true);var focus: Dictionary=model.state.focus
		if focus.selected!="home":continue
		var event: Dictionary=focus.laterEvents[focus.eventId]
		if event.has("conditionKind") or event.has("familyFollowup"):continue
		var signature: String=case.id.get_slice(":",0)
		if seen.has(signature):continue
		seen[signature]=true
		var before: Dictionary=model.state.duplicate(true);var result: Dictionary=model.pre_photo_authored_home_layer(focus);var expected: Dictionary={};checks+=2
		for key in ["title","intro","choices","actor","participants","homeParticipants","historyClass","chapter4Revision","chapter"]:expected[key]=event[key]
		if not same_json(result,expected) or not same_json(before,model.state):
			if failed.is_empty():
				var file=FileAccess.open("res://../evidence/pre_photo_home_layer_first_diff.json",FileAccess.WRITE);file.store_string(JSON.stringify({"id":case.id,"actual":result,"expected":expected}))
			failed.append(case.id)
	print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false,"visual_test":false}));quit(0 if failed.is_empty() else 1)
func same_json(a: Variant,b: Variant) -> bool:
	if typeof(a) in [TYPE_INT,TYPE_FLOAT] and typeof(b) in [TYPE_INT,TYPE_FLOAT]:return float(a)==float(b)
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size():return false
		for key in a:
			if not b.has(key) or not same_json(a[key],b[key]):return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for i in range(a.size()):
			if not same_json(a[i],b[i]):return false
		return true
	return typeof(a)==typeof(b) and a==b
