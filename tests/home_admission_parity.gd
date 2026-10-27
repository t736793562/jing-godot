extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/home_admission_reference.json"));var model=Model.new();var failed: Array=[];var checks:=0
	for case in data.tests:
		model.state=case.initial.duplicate(true);var f: Dictionary=model.state.focus
		var actual: Dictionary={"context":model.home_reception_status(f),"witnesses":{"rope":model.neighbour_reception_witnesses("rope",model.state.memory.get("neighbourRopeR2a")),"parcel":model.neighbour_reception_witnesses("parcel",model.state.memory.get("neighbourParcelR2b"))},"admissions":{}}
		for requested in ["day","rope","parcel"]:actual.admissions[requested]=model.home_neighbour_admission(f,requested)
		for key in ["context","witnesses","admissions"]:
			checks+=1
			if not same_json(actual[key],case[key]):
				if failed.is_empty():
					var out=FileAccess.open("res://../evidence/home_admission_first_diff.json",FileAccess.WRITE);out.store_string(JSON.stringify({"id":case.id,"key":key,"actual":actual[key],"expected":case[key]}))
				failed.append(case.id+":"+key)
		checks+=1
		if not same_json(model.state,case.after):failed.append(case.id+":mutation")
	print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false,"read_only_projection":true}));quit(0 if failed.is_empty() else 1)

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

