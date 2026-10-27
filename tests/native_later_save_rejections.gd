extends SceneTree
const Model=preload("res://scripts/game_model.gd")
const Journal=preload("res://scripts/native_continuation.gd")
const Store=preload("res://scripts/native_continuation_store.gd")
func _initialize() -> void:
	var input=FileAccess.open("res://data/day_eleven_lifecycle_reference.jsonl",FileAccess.READ);var case=decode_exact(JSON.parse_string(input.get_line()));var model=Model.new();model.state=case.initial.duplicate(true);var journal=Journal.new();var store=Store.new();var failed: Array=[];var checks:=0
	if not journal.start(model):quit(1);return
	for step in [["enter",[]],["select",[case.target]],["choose",[case.choice]],["return",[]]]:
		if not journal.apply(model,step[0],step[1]):quit(1);return
	var pristine: Dictionary=model.state.duplicate(true);var proof: Dictionary=journal.proof();store.active_proof=proof;var text:=store.encode(pristine);checks+=1
	if text.is_empty():failed.append("control")
	var values: Array=[]
	var value: Dictionary={"state":pristine.duplicate(true),"proof":proof.duplicate(true)};value.state.rice+=1;values.append(["changed-inventory",value])
	value={"state":pristine.duplicate(true),"proof":proof.duplicate(true)};value.state.focus.laterEvents[value.state.focus.eventId].choices[0].diaries.default="伪造正文";values.append(["changed-frozen-prose",value])
	value={"state":pristine.duplicate(true),"proof":proof.duplicate(true)};value.proof.actions[0].op="exec";values.append(["unknown-operation",value])
	value={"state":pristine.duplicate(true),"proof":proof.duplicate(true)};value.proof.actions[0].ok=false;values.append(["wrong-result-receipt",value])
	value={"state":pristine.duplicate(true),"proof":proof.duplicate(true)};value.proof.actions.pop_back();values.append(["missing-return",value])
	value={"state":pristine.duplicate(true),"proof":proof.duplicate(true)};value.proof.anchor.day=11;values.append(["unsupported-anchor",value])
	value={"state":pristine.duplicate(true),"proof":proof.duplicate(true)};value.proof.actions[2].args=[true];values.append(["boolean-choice-index",value])
	value={"state":pristine.duplicate(true),"proof":proof.duplicate(true)};value.proof.actions[2].args=[0.5];values.append(["fractional-choice-index",value])
	value={"state":pristine.duplicate(true),"proof":proof.duplicate(true)};value.proof.actions=[{"op":"enter","args":[],"ok":true,"extra":"not-allowed"}];values.append(["extra-action-field",value])
	value={"state":pristine.duplicate(true),"proof":proof.duplicate(true)};value.proof.actions=[];values.append(["empty-proof",value])
	for pair in values:
		store.error="";store.nodes=0;var payload:=JSON.stringify(store.encode_value(pair[1]));var envelope:=JSON.stringify({"format":store.FORMAT,"revision":2,"payload":payload,"sha256":payload.sha256_text()});var before:=var_to_bytes(model.state);checks+=3
		if not store.decode(envelope).is_empty():failed.append(pair[0]+":accepted")
		if var_to_bytes(model.state)!=before:failed.append(pair[0]+":mutated-live-state")
		if not store.decoded_proof.is_empty():failed.append(pair[0]+":stale-proof-leaked")
	checks+=2;store.active_proof=proof
	if not store.encode(pristine).is_empty() and not store.decode(text).is_empty():pass
	else:failed.append("valid-after-rejections")
	if var_to_bytes(model.state)!=var_to_bytes(pristine):failed.append("live-state-changed")
	print(JSON.stringify({"checks":checks,"failed":failed,"tamper_cases":values.size(),"recomputed_checksums":true,"visual_test":false,"disk_test":false}));quit(0 if failed.is_empty() else 1)
func decode_exact(value: Variant) -> Variant:
	if value is Dictionary:
		if value.size()==1 and value.has("__float64"):
			var stream:=StreamPeerBuffer.new();stream.big_endian=false;stream.data_array=value.__float64.hex_decode();return stream.get_double()
		var result: Dictionary={}
		for key in value:result[key]=decode_exact(value[key])
		return result
	if value is Array:return value.map(func(x):return decode_exact(x))
	return value
