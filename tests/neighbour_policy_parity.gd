extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var stream=FileAccess.open("res://data/neighbour_policy_reference.jsonl",FileAccess.READ);var model=Model.new();var failed: Array=[];var checks:=0
	while stream.get_position()<stream.get_length():
		var line=stream.get_line()
		if line.is_empty():continue
		var case=JSON.parse_string(line);model.state=case.initial.duplicate(true);var focus: Dictionary=model.state.focus
		var actual: Dictionary={"d5":model.d5_bundle_evidence(),"acquaintance":{},"message":model.message_thread_admission(focus),"handoff":model.custody_handoff_admission(focus),"night":model.custody_night_admission(focus)}
		for person in Model.PEOPLE:actual.acquaintance[person]=model.custody_acquaintance(person)
		for key in actual:
			checks+=1
			if not same_json(actual[key],case[key]):
				if failed.is_empty():
					var file=FileAccess.open("res://../evidence/neighbour_policy_first_diff.json",FileAccess.WRITE);file.store_string(JSON.stringify({"id":case.id,"key":key,"actual":actual[key],"expected":case[key]}))
				failed.append(case.id+":"+key)
		checks+=1
		if not same_json(model.state,case.after):failed.append(case.id+":mutation")
	print(JSON.stringify({"checks":checks,"failed":failed,"read_only_projection":true,"full_game":false}));quit(0 if failed.is_empty() else 1)

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

