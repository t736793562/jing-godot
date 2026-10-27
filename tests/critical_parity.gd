extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var reference=decode_exact(JSON.parse_string(FileAccess.get_file_as_string("res://data/critical_reference.json")))
	var model=Model.new();var failed: Array=[];var checks:=0
	for case in reference.tests:
		model.state=case.initial.duplicate(true);model.contract_error="";model.contract_message=""
		for key in ["after","afterRepeat"]:
			model.check_early_critical();checks+=1
			if not same_json(model.state,case[key]):
				if failed.is_empty():
					var f=FileAccess.open("res://../evidence/critical_first_diff.json",FileAccess.WRITE);f.store_string(JSON.stringify({"id":case.id,"step":key,"actual":model.state,"expected":case[key]}))
				failed.append(case.id+":"+key)
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
