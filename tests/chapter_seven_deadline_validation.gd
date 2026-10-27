extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var model=Model.new();var failed: Array=[];var checks:=0;var data=JSON.parse_string(FileAccess.get_file_as_string("res://../evidence/staged_deadline_validation_reference.json"))
	for case in data.cases:
		model.state=case.initial.duplicate(true);model.contract_error="";model.contract_message="";var result: bool;var ok: bool
		if case.kind=="validate":result=model.deadline_validate();ok=result==(case.result if case.error==null else false)
		else:
			var packet: Dictionary=case.beforePacket.duplicate(true);result=model.attach_deadline_scene_knowledge(packet,case.event);ok=result==(case.error==null) and same_json(packet,case.expectedPacket);checks+=1
		ok=ok and model.contract_message==str(case.error if case.error!=null else "") and same_json(model.state,case.expected);checks+=3
		if not ok:failed.append(case.id)
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

