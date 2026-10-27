extends SceneTree
const Boundary=preload("res://../tools/chapter_nine_oracle_boundary.gd")
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var stream=FileAccess.open("res://../evidence/staged_chapter_nine_late_recovery_reference.jsonl",FileAccess.READ);var model=Model.new();var failed: Array=[];var checks:=0;var frames:=0;var source_terminal_errors: Array=[];var starts:=0;var cohort: String="";var stopped:=false
	while stream.get_position()<stream.get_length():
		var line=stream.get_line()
		if line.is_empty():continue
		var case=decode_exact(JSON.parse_string(line));var id: String=case.id.get_slice(":",0)
		if id!=cohort:starts+=1;model=Model.new();model.state=case.initial.duplicate(true);cohort=id;stopped=false
		elif stopped:continue
		elif not same_json(model.state,case.initial):failed.append(case.id+":boundary");stopped=true;continue
		frames+=1
		for step in [["enter_day_eleven_twelve_focus",[],"afterEnter"],["select_day_eleven_twelve_focus",[case.target],"afterSelect"],["resolve_day_eleven_twelve_choice",[case.choice],"afterResolve"],["settle_day_eleven_twelve_return",[],"afterReturn"],["confirm_early_night",[],"afterConfirm"],["resolve_night_event",[case.response],"afterNightResolve"],["finish_early_night",[],"afterFinish"]]:
			if step[0]=="confirm_early_night":
				model.state.phase="night";model.set_night_option("meal",case.beforeNight.night.meal);model.set_night_option("fire",case.beforeNight.night.fire)
				if case.animalChoice!=null:model.resolve_animal_encounter(case.animalChoice,case.animalKind)
				model.set_night_option("feedPet",case.beforeNight.night.feedPet)
			if step[0]=="resolve_night_event" and case.response==null:continue
			var result: bool=model.callv(step[0],step[1]);checks+=2
			var expected: Dictionary=case[step[2]]
			if step[2]=="afterFinish" and Boundary.source_terminal_save_failed(expected):source_terminal_errors.append(case.id);expected=Boundary.native_expected(expected)
			if not result or not same_json(model.state,expected):
				if failed.is_empty():
					var f=FileAccess.open("res://../evidence/chapter_nine_late_recovery_first_diff.json",FileAccess.WRITE);f.store_string(JSON.stringify({"id":case.id,"step":step[0],"result":result,"actual":model.state,"expected":expected}))
				failed.append(case.id+":"+step[0]);stopped=true;break
	print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false,"frames":frames,"starts":starts,"visual_test":false,"source_terminal_save_errors":source_terminal_errors,"native_terminal_persistence_tested":false}));quit(0 if failed.is_empty() else 1)

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
