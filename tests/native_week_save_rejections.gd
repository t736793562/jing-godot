extends SceneTree
const Store=preload("res://scripts/native_save.gd")
func _initialize() -> void:
	var stream=FileAccess.open("res://data/first_week_lifecycle_reference.jsonl",FileAccess.READ)
	var store=Store.new();var seen: Dictionary={};var failed: Array=[];var checks:=0
	while stream.get_position()<stream.get_length():
		var line=stream.get_line()
		if line.is_empty():continue
		var case=decode_exact(JSON.parse_string(line));var state: Dictionary=case.afterSelect;var f: Dictionary=state.focus
		var primary: bool=f.earlyReadingEvents.has(f.eventId)
		var event: Dictionary=f.earlyReadingEvents[f.eventId] if primary else f.fallback
		var kind: String="primary" if primary else event.conditionKind
		if seen.has(kind):continue
		seen[kind]=true;checks+=1
		if store.encode(state).is_empty():failed.append(kind+":positive:"+store.error);continue
		for mutation in ["title","choice","effect"]:
			var bad: Dictionary=state.duplicate(true);var changed: Dictionary=bad.focus.earlyReadingEvents[f.eventId] if primary else bad.focus.fallback
			if mutation=="title":changed.title+="未批准的正文"
			elif mutation=="choice":changed.choices.remove_at(0)
			else:
				if not changed.choices[0].has("immediateEffects"):changed.choices[0].immediateEffects=[]
				changed.choices[0].immediateEffects.append({"type":"resource","resource":"rice","amount":99999})
			checks+=1
			if not store.encode(bad).is_empty():failed.append(kind+":"+mutation+":accepted")
	print(JSON.stringify({"checks":checks,"kinds":seen.keys(),"failed":failed,"visual_test":false}));quit(0 if failed.is_empty() else 1)

func decode_exact(value: Variant) -> Variant:
	if value is Dictionary:
		if value.size()==1 and value.has("__float64"):
			var stream:=StreamPeerBuffer.new();stream.big_endian=false;stream.data_array=value.__float64.hex_decode();return stream.get_double()
		var result: Dictionary={}
		for key in value:result[key]=decode_exact(value[key])
		return result
	if value is Array:return value.map(func(x):return decode_exact(x))
	return value
