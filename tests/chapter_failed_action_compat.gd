extends SceneTree
const OldModel=preload("res://../tools/staged_day_twelve_model.gd")
const OldJournal=preload("res://../tools/staged_day_twelve_journal.gd")
const OldStore=preload("res://../tools/staged_day_twelve_store.gd")
const Store=preload("res://scripts/native_continuation_store.gd")
func _initialize() -> void:
	var input=FileAccess.open("res://data/day_eleven_lifecycle_reference.jsonl",FileAccess.READ);var case=decode_exact(JSON.parse_string(input.get_line()));var rows: Array=[]
	for op in ["confirm_night","finish_night"]:
		var model=OldModel.new();model.state=case.initial.duplicate(true);var journal=OldJournal.new();journal.start(model);journal.apply(model,"enter");var attempted: bool=journal.apply(model,op)
		var old=OldStore.new();old.active_proof=journal.proof();var encoded: String=old.encode(model.state);var current=Store.new();var restored: Dictionary=current.decode(encoded)
		rows.append({"op":op,"attempted_result":attempted,"old_valid":not encoded.is_empty(),"new_valid":not restored.is_empty(),"error":current.error,"exact":var_to_bytes(restored)==var_to_bytes(model.state)})
	var passed: bool=rows.all(func(row):return row.old_valid and row.new_valid and row.exact and not row.attempted_result)
	print(JSON.stringify({"rows":rows,"passed":passed,"visual_test":false}));quit(0 if passed else 1)

func decode_exact(value: Variant) -> Variant:
	if value is Dictionary:
		if value.size()==1 and value.has("__float64"):
			var stream:=StreamPeerBuffer.new();stream.big_endian=false;stream.data_array=value.__float64.hex_decode();return stream.get_double()
		var result: Dictionary={}
		for key in value:result[key]=decode_exact(value[key])
		return result
	if value is Array:return value.map(func(x):return decode_exact(x))
	return value
