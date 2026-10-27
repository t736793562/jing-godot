extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var stream=FileAccess.open("res://data/day_eleven_twelve_reference.jsonl",FileAccess.READ);var model=Model.new();var failed: Array=[];var checks:=0
	while stream.get_position()<stream.get_length():
		var line=stream.get_line()
		if line.is_empty():continue
		var case=JSON.parse_string(line);model.state=case.initial.duplicate(true)
		for stage in ["entered","selected"]:
			var result: bool=model.enter_day_eleven_twelve_focus() if stage=="entered" else (model.select_day_eleven_twelve_focus(case.target) if case.target!=null else false)
			var expected: Dictionary=case.afterEnter if stage=="entered" else case.afterSelect;checks+=2
			if result!=case[stage] or not same_json(model.state,expected):
				if failed.is_empty():
					var file=FileAccess.open("res://../evidence/day_eleven_twelve_first_diff.json",FileAccess.WRITE);file.store_string(JSON.stringify({"id":case.id,"stage":stage,"result":result,"expected_result":case[stage],"actual":model.state,"expected":expected,"differences":diff_paths(model.state,expected)}))
				failed.append(case.id+":"+stage)
	print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false,"disk_test":false,"visual_test":false}));quit(0 if failed.is_empty() else 1)

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
