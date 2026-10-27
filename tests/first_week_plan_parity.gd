extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var stream=FileAccess.open("res://data/first_week_plan_reference.jsonl",FileAccess.READ)
	var model=Model.new();var failed: Array=[];var checks:=0
	while stream.get_position()<stream.get_length():
		var line: String=stream.get_line()
		if line.is_empty():continue
		var case=decode_exact(JSON.parse_string(line))
		model.state=case.initial.duplicate(true);model.contract_error="";model.contract_message=""
		checks+=2
		var result=model.ensure_early_focus()
		if not same_json(result,case.result) or not same_json(model.state,case.after):
			if failed.is_empty():
				var f=FileAccess.open("res://../evidence/first_week_plan_first_diff.json",FileAccess.WRITE)
				f.store_string(JSON.stringify({"id":case.id,"actual":result,"expected":case.result,"state":model.state,"expected_state":case.after}))
			failed.append(case.id)
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

func decode_exact(value: Variant) -> Variant:
	if value is Dictionary:
		if value.size()==1 and value.has("__float64"):
			var stream:=StreamPeerBuffer.new();stream.big_endian=false;stream.data_array=value.__float64.hex_decode();return stream.get_double()
		var result: Dictionary={}
		for key in value:result[key]=decode_exact(value[key])
		return result
	if value is Array:return value.map(func(x):return decode_exact(x))
	return value
