extends SceneTree
const Store=preload("res://scripts/native_save.gd")
func _initialize() -> void:
	var input=FileAccess.open("res://data/missing_family_lifecycle_reference.jsonl",FileAccess.READ)
	var store=Store.new();var failed: Array=[];var checks:=0;var row:=0
	while input.get_position()<input.get_length():
		var line=input.get_line()
		if line.is_empty():continue
		row+=1
		# All actual missing-family samples.
		var case=decode_exact(JSON.parse_string(line))
		for stage in ["initial","afterEnter","afterSelect","afterResolve","afterReturn","afterConfirm","afterNightResolve","afterFinish"]:
			var state: Dictionary=case[stage];var encoded=store.encode(state);checks+=1
			if encoded.is_empty():
				failed.append(case.id+":"+stage+":"+store.error)
				if failed.size()==1:
					var out=FileAccess.open("res://../evidence/missing_family_save_first_diff.json",FileAccess.WRITE);out.store_string(JSON.stringify(state))
				continue
			var decoded=store.decode(encoded);checks+=1
			if var_to_bytes(decoded)!=var_to_bytes(state):failed.append(case.id+":"+stage+":roundtrip")
	print(JSON.stringify({"checks":checks,"failed":failed,"disk_test":false,"visual_test":false}));quit(0 if failed.is_empty() else 1)

func decode_exact(value: Variant) -> Variant:
	if value is Dictionary:
		if value.size()==1 and value.has("__float64"):
			var stream:=StreamPeerBuffer.new();stream.big_endian=false;stream.data_array=value.__float64.hex_decode();return stream.get_double()
		var result: Dictionary={}
		for key in value:result[key]=decode_exact(value[key])
		return result
	if value is Array:return value.map(func(x):return decode_exact(x))
	return value
