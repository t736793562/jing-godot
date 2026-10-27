extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string("res://data/health_reference.json"))
	var names={"treatmentOptions":"treatment_options","validateTreatment":"validate_treatment","careTarget":"care_target","applyPlannedTreatment":"apply_planned_treatment","applyMedicine":"apply_medicine","progressAilments":"progress_ailments","settleWaterExposure":"settle_water_exposure"}
	var failed: Array=[];var checks:=0
	for case in reference.tests:
		var model=Model.new();model.state=case.initial.duplicate(true)
		for i in range(case.steps.size()):
			var step: Dictionary=case.steps[i];var args: Array=step.args
			if step.name=="settleWaterExposure":args=[model.state.nightCycle]
			var result=model.callv(names[step.name],args);checks+=2
			var id=case.id+":"+str(i)+":"+step.name
			var result_ok=same_json(result,step.result);var state_ok=same_json(model.state,step.state)
			if not result_ok or not state_ok:
				if failed.is_empty():
					var f=FileAccess.open("res://../evidence/health_first_diff.json",FileAccess.WRITE)
					f.store_string(JSON.stringify({"id":id,"actual":model.state,"expected":step.state,"result":result,"expected_result":step.result}))
				failed.append(id+":"+("result" if not result_ok else "state"))
	print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false}));quit(0 if failed.is_empty() else 1)
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
