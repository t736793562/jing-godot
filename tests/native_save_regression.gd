extends SceneTree
const Store=preload("res://scripts/native_save.gd")
const Model=preload("res://scripts/game_model.gd")
var failed: Array=[]
var checks:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failed.append(label)
func same_bits(a: Variant,b: Variant) -> bool:
	return var_to_bytes(a)==var_to_bytes(b)
func decode_exact(value: Variant) -> Variant:
	if value is Dictionary:
		if value.size()==1 and value.has("__float64"):
			var stream:=StreamPeerBuffer.new();stream.big_endian=false;stream.data_array=value.__float64.hex_decode();return stream.get_double()
		var result: Dictionary={}
		for key in value:result[key]=decode_exact(value[key])
		return result
	if value is Array:return value.map(func(x):return decode_exact(x))
	return value
func _initialize() -> void:
	var store=Store.new();var model=Model.new();model.new_game("save-regression")
	var state: Dictionary=model.state.duplicate(true)
	var encoded: String=store.encode(state)
	check(not encoded.is_empty(),"new game encode:"+store.error)
	check(same_bits(state,store.decode(encoded)),"new game exact roundtrip")
	var reference=decode_exact(JSON.parse_string(FileAccess.get_file_as_string("res://data/first_night_reference.json")))
	for case in reference.tests:
		for key in ["initial","afterConfirm","afterResolve","afterFinish"]:
			var original: Dictionary=case[key];var text: String=store.encode(original)
			check(not text.is_empty(),case.id+":"+key+":"+store.error)
			if not text.is_empty():check(same_bits(original,store.decode(text)),case.id+":"+key+":exact:"+store.error)
	# Binary-sensitive decimals, signed zero, integer type and string year keys remain unchanged.
	state.memory.numeric_probe=[0.9+0.04,-0.0,1.0,1,0.0000001,{"2.0":true,"2":false}]
	encoded=store.encode(state)
	check(same_bits(state,store.decode(encoded)),"float bits and key identity")
	if encoded.is_empty():
		print(JSON.stringify({"checks":checks,"failed":failed,"error":store.error}));quit(1);return
	var envelope=JSON.parse_string(encoded);envelope.sha256="0".repeat(64)
	check(store.decode(JSON.stringify(envelope)).is_empty() and store.error=="CHECKSUM","checksum")
	for bad in ["", "{}", "null", "[]", "{", JSON.stringify(state)]:check(store.decode(bad).is_empty(),"reject non-native")
	for entry in [["day",2],["rngState",-1],["rice",-1],["phase","day"],["version","old"],["people",{}],["night",{}],["weatherPlan",[]]]:
		var bad: Dictionary=state.duplicate(true);bad[entry[0]]=entry[1]
		check(store.encode(bad).is_empty(),"bad state "+entry[0])
	for value in [[],"pigeon",{"type":"pigeon"},{"type":"cat"},42]:
		var bad: Dictionary=state.duplicate(true);bad.animals.poultry=value
		check(store.encode(bad).is_empty(),"reject malformed nullable animal")
	for value in [[],"trip",{},42]:
		var bad: Dictionary=state.duplicate(true);bad.expedition.plan=value
		check(store.encode(bad).is_empty(),"reject unsupported expedition plan")
	for key in ["neighbourMessagesWebR5","neighbourCustodyWebR6","neighbourCustodyNightWebR8"]:
		var bad: Dictionary=state.duplicate(true);bad.memory[key]={"revision":"unimplemented"}
		check(store.encode(bad).is_empty(),"reject unsupported future memory:"+key)
	for value in [NAN,INF,Vector2.ONE,RefCounted.new()]:
		var bad: Dictionary=state.duplicate(true);bad.memory.bad=value
		check(store.encode(bad).is_empty(),"reject unsafe value")
	var path: String="user://native-save-regression-"+str(OS.get_process_id())+".json"
	check(store.save_to(path,state),"write primary:"+store.error)
	var second: Dictionary=state.duplicate(true);second.memory.generation=2
	check(store.save_to(path,second),"rotate backup:"+store.error)
	var restored=Model.new();restored.new_game("other")
	check(store.load_from(path,restored).get("source")=="primary" and same_bits(restored.state,second),"load primary")
	store.write_text(path,"truncated")
	check(store.load_from(path,restored).get("source")=="backup" and same_bits(restored.state,state),"fallback backup")
	var backup_bytes:=FileAccess.get_file_as_bytes(path+".bak")
	check(store.save_to(path,second) and FileAccess.get_file_as_bytes(path+".bak")==backup_bytes,"corrupt primary does not poison backup")
	store.write_text(path,"bad");store.write_text(path+".bak","bad")
	var live: Dictionary=restored.state.duplicate(true);var live_rng: int=restored.rng.state
	check(not store.load_from(path,restored).ok and same_bits(restored.state,live) and restored.rng.state==live_rng,"failed load atomic")
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
	print(JSON.stringify({"checks":checks,"failed":failed,"visual_test":false,"scope":"native opening/first-night save candidate"}));quit(0 if failed.is_empty() else 1)
