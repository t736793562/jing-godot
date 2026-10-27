extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var model=Model.new();var failed: Array=[];var checks:=0
	for category in ["requirements","deltas"]:
		var data=JSON.parse_string(FileAccess.get_file_as_string("res://../evidence/staged_photo_mid_"+category+".json"))
		for case in data.cases:
			model.state=case.initial.duplicate(true);model.contract_error="";model.contract_message=""
			var ok: bool
			if category=="requirements":
				ok=same_json(model.photo_batch_requirement("print"),case.requirements.print) and same_json(model.photo_batch_requirement("sort"),case.requirements.sort) and same_json(model.photo_opportunity(model.state.focus.plan),case.opportunity) and same_json(model.state,case.expected);checks+=4
			else:
				var result: bool=model.apply_photo_mid_delta(case.op,case.value,case.effect);ok=result==(case.error==null) and model.contract_message==str(case.error if case.error!=null else "") and same_json(model.state,case.expected);checks+=3
				model.contract_error="";model.contract_message="";result=model.apply_photo_mid_delta(case.op,case.value,case.effect);ok=ok and result==(case.repeatError==null) and model.contract_message==str(case.repeatError if case.repeatError!=null else "") and same_json(model.state,case.afterRepeated);checks+=3
			if not ok:
				if failed.is_empty():
					var file=FileAccess.open("res://../evidence/photo_mid_contract_first_diff.json",FileAccess.WRITE);file.store_string(JSON.stringify({"category":category,"id":case.id,"actual":model.state,"expected":case.expected,"error":model.contract_message}))
				failed.append(category+":"+case.id)
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

