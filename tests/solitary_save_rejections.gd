extends SceneTree
const Store=preload("res://scripts/native_save.gd")
func _initialize() -> void:
	var stream=FileAccess.open("res://data/solitary_lifecycle_reference.jsonl",FileAccess.READ);var state: Dictionary={}
	while stream.get_position()<stream.get_length():
		var row=decode_exact(JSON.parse_string(stream.get_line()))
		if row.afterFinish.ended:state=row.afterFinish;break
	var store=Store.new();var failed: Array=[];var checks:=1
	if state.is_empty() or store.encode(state).is_empty():failed.append("positive-terminal")
	for kind in ["pending","ledger","cause","alive","record","packet_type","fact_type"]:
		var bad: Dictionary=state.duplicate(true);var packet: Dictionary=bad.nightCycle.resultPackets[0]
		match kind:
			"pending":packet.status="pending"
			"ledger":bad.effectLedger.appliedEffectIds.erase(packet.id)
			"cause":packet.effects[0].causeId="invalid"
			"alive":bad.people["罗瑾"].alive=true
			"record":bad.memory.failureRecord.resultPacketId="other"
			"packet_type":bad.nightCycle.resultPackets=1000000000
			"fact_type":bad.knowledgeFacts=1000000000
		checks+=1
		if not store.encode(bad).is_empty():failed.append(kind)
	print(JSON.stringify({"checks":checks,"failed":failed,"visual_test":false}));quit(0 if failed.is_empty() else 1)

func decode_exact(value: Variant) -> Variant:
	if value is Dictionary:
		if value.size()==1 and value.has("__float64"):
			var stream:=StreamPeerBuffer.new();stream.big_endian=false;stream.data_array=value.__float64.hex_decode();return stream.get_double()
		var result: Dictionary={}
		for key in value:result[key]=decode_exact(value[key])
		return result
	if value is Array:return value.map(func(x):return decode_exact(x))
	return value
