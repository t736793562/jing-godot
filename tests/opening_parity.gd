extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string("res://data/opening_reference.json"))
	var failed: Array=[]
	var checks:=0
	var names={"addLoadout":"add_loadout","recommendLoadout":"recommend","openingLoadRisk":"load_risk","startOpening":"start_opening","openingRoadText":"road_text","settleOpeningArrival":"settle_opening_arrival","chooseOpening":"choose_opening"}
	for case in reference.tests:
		var model=Model.new();model.new_game(case.seed,false);model.state.phase="loadout";model.ensure_pool()
		for i in range(case.steps.size()):
			var step: Dictionary=case.steps[i]
			var result=model.callv(names[step.name],step.args)
			checks+=2
			var id=case.seed+":"+case.mode+":"+str(case.choice)+":"+str(i)+":"+step.name
			if not same_json(result,step.result):failed.append(id+":result")
			if not same_json(model.state,step.state):
				if failed.is_empty():
					var f=FileAccess.open("res://../evidence/opening_first_diff.json",FileAccess.WRITE)
					f.store_string(JSON.stringify({"id":id,"actual":model.state,"expected":step.state}))
				failed.append(id+":state")
	print(JSON.stringify({"checks":checks,"failed":failed,"coverage":reference.coverage,"full_game":false}))
	quit(0 if failed.is_empty() else 1)

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
