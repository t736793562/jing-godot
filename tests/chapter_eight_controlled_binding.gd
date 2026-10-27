extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var model=Model.new();var failed: Array=[];var checks:=0;var stream=FileAccess.open("res://../evidence/staged_chapter_eight_controlled_binding.jsonl",FileAccess.READ);var differences=FileAccess.open("res://../evidence/chapter_eight_controlled_binding_all_diffs.jsonl",FileAccess.WRITE)
	while stream.get_position()<stream.get_length():
		var line=stream.get_line()
		if line.is_empty():continue
		var case=decode_exact(JSON.parse_string(line));model.state=case.initial.duplicate(true);model.contract_error="";model.contract_message=""
		var result: bool=model.bind_day_eleven_twelve(model.state.focus);checks+=2
		if not result or not same_json(model.state,case.expected):
			differences.store_line(JSON.stringify({"id":case.id,"result":result,"error":model.contract_message,"differences":diff_paths(model.state,case.expected)}));failed.append(case.id)
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


func diff_paths(a: Variant,b: Variant,path: String="") -> Array:
	if same_json(a,b):return []
	var result: Array=[]
	if a is Dictionary and b is Dictionary:
		for key in a:
			if b.has(key):result.append_array(diff_paths(a[key],b[key],path+"/"+str(key)))
			else:result.append({"path":path+"/"+str(key),"missing":"expected"})
		for key in b:
			if not a.has(key):result.append({"path":path+"/"+str(key),"missing":"actual"})
	elif a is Array and b is Array:
		for i in range(mini(a.size(),b.size())):result.append_array(diff_paths(a[i],b[i],path+"/"+str(i)))
		if a.size()!=b.size():result.append({"path":path,"length_a":a.size(),"length_b":b.size()})
	else:result.append({"path":path,"type_a":typeof(a),"type_b":typeof(b),"a":a,"b":b,"bytes_a":var_to_bytes(a).hex_encode(),"bytes_b":var_to_bytes(b).hex_encode()})
	return result

func decode_exact(value: Variant) -> Variant:
	if value is Dictionary:
		if value.size()==1 and value.has("__float64"):
			var stream:=StreamPeerBuffer.new();stream.big_endian=false;stream.data_array=value.__float64.hex_decode();return stream.get_double()
		var result: Dictionary={}
		for key in value:result[key]=decode_exact(value[key])
		return result
	if value is Array:return value.map(func(x):return decode_exact(x))
	return value
