extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string("res://data/night_delivery_reference.json"))
	var model=Model.new();var failed: Array=[];var checks:=0
	for case in reference.tests:
		model.state=case.initial.duplicate(true)
		for step in case.steps:
			checks+=1
			if step.name=="promoteNightReading":model.promote_night_reading()
			else:model.deliver_night_reading()
			if not same_json(model.state,step.state):
				if failed.is_empty():
					var f=FileAccess.open("res://../evidence/night_delivery_first_diff.json",FileAccess.WRITE)
					f.store_string(JSON.stringify({"id":case.id,"step":step.name,"actual":model.state,"expected":step.state}))
				failed.append(case.id+":"+step.name)
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
