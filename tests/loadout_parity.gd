extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string("res://data/loadout_reference.json"))
	var failed: Array=[]
	var checks:=0
	for case in reference.tests:
		var model=Model.new();model.new_game(case.seed,false);model.state.phase="loadout"
		checks+=1
		if model.ensure_pool()!=case.pool:failed.append(case.seed+":pool")
		for i in range(case.steps.size()):
			var step: Dictionary=case.steps[i]
			var result: bool=model.add_loadout(step.id,step.person) if step.kind=="add" else model.remove_loadout(step.person,step.id)
			checks+=2
			if result!=step.result:failed.append(case.seed+":result:"+str(i))
			if not same_json(model.state,step.state):
				failed.append(case.seed+":state:"+str(i))
				if case.seed=="0" and i==0:
					var f=FileAccess.open("res://../evidence/loadout_first_diff.json",FileAccess.WRITE)
					f.store_string(JSON.stringify({"actual":model.state,"expected":step.state}))
	print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false}))
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
