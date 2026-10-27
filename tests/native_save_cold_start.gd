extends SceneTree
const Store=preload("res://scripts/native_save.gd")
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var args=OS.get_cmdline_user_args();var errors: Array=[];var store=Store.new()
	if args.size()!=2:quit(2);return
	var mode: String=args[0];var folder: String=args[1]
	for i in range(12):
		var model=Model.new();var path:=folder+"/case-"+str(i)+".json"
		if mode=="prepare":
			model.new_game("cold-start-"+str(i));model.dispatch("tutorialSkip")
			if i%2:model.recommend(true)
			if not model.start_opening() or not model.choose_opening(0):errors.append("opening:"+str(i));continue
			model.settle_opening_arrival()
			model.state.phase="night"
			if i%2==0:model.set_night_option("meal",false);model.set_night_option("fire",0)
			if not model.confirm_first_night():errors.append("confirm:"+str(i));continue
			if not store.save_to(path,model.state):errors.append("save:"+str(i)+":"+store.error);continue
			model.resolve_night_event("quiet");model.finish_first_night()
			store.write_text(folder+"/expected-"+str(i)+".json",store.encode(model.state))
			if not day_two(model,i):errors.append("expected_day_two:"+str(i));continue
			model.settle_first_day_focus_return();model.state.phase="night";model.set_night_option("meal",false);model.set_night_option("fire",0)
			if not model.confirm_early_night():errors.append("expected_second_confirm:"+str(i));continue
			if model.state.pendingNightEvent!=null:model.resolve_night_event(response(model))
			if not model.finish_early_night():errors.append("expected_second_finish:"+str(i));continue
			store.write_text(folder+"/expected-second-"+str(i)+".json",store.encode(model.state))
			for night in [3,4]:
				if not day_two(model,i) or not model.settle_first_day_focus_return():errors.append("expected_long_day:"+str(i)+":"+str(night));break
				if not confirm_next(model):errors.append("expected_long_confirm:"+str(i)+":"+str(night));break
				if model.state.pendingNightEvent!=null:model.resolve_night_event(response(model))
				if not model.finish_early_night():errors.append("expected_long_finish:"+str(i)+":"+str(night));break
				store.write_text(folder+"/expected-night"+str(night)+"-"+str(i)+".json",store.encode(model.state))
		elif mode=="choice":
			if not store.load_from(path,model).ok:errors.append("load:"+str(i)+":"+store.error);continue
			if model.confirm_first_night():errors.append("repeat_confirm:"+str(i))
			model.resolve_night_event("quiet")
			if not store.save_to(path,model.state):errors.append("resave:"+str(i)+":"+store.error)
		elif mode=="finish":
			if not store.load_from(path,model).ok or not model.finish_first_night():errors.append("finish:"+str(i));continue
			if not store.save_to(path,model.state):errors.append("dawn_save:"+str(i)+":"+store.error)
		elif mode=="verify":
			if not store.load_from(path,model).ok:errors.append("verify_load:"+str(i));continue
			var expected:=store.read_valid(folder+"/expected-"+str(i)+".json")
			if var_to_bytes(expected)!=var_to_bytes(model.state):errors.append("different_state:"+str(i))
			var before=var_to_bytes(model.state)
			if model.finish_first_night() or var_to_bytes(model.state)!=before:errors.append("repeat_dawn:"+str(i))
		elif mode=="day_two":
			if not store.load_from(path,model).ok or not day_two(model,i):errors.append("day_two:"+str(i));continue
			if not store.save_to(path,model.state):errors.append("day_two_save:"+str(i)+":"+store.error)
		elif mode=="second_confirm":
			if not store.load_from(path,model).ok or not model.settle_first_day_focus_return():errors.append("second_return:"+str(i));continue
			model.state.phase="night";model.set_night_option("meal",false);model.set_night_option("fire",0)
			if not model.confirm_early_night() or not store.save_to(path,model.state):errors.append("second_confirm:"+str(i)+":"+store.error)
		elif mode=="second_event":
			if not store.load_from(path,model).ok:errors.append("second_event_load:"+str(i)+":"+store.error);continue
			if model.state.pendingNightEvent!=null and not model.resolve_night_event(response(model)):errors.append("second_event:"+str(i));continue
			if not store.save_to(path,model.state):errors.append("second_event_save:"+str(i)+":"+store.error)
		elif mode=="second_finish":
			if not store.load_from(path,model).ok or not model.finish_early_night():errors.append("second_finish:"+str(i));continue
			if not store.save_to(path,model.state):errors.append("second_finish_save:"+str(i)+":"+store.error)
		elif mode=="second_verify":
			if not store.load_from(path,model).ok:errors.append("second_verify_load:"+str(i));continue
			var expected:=store.read_valid(folder+"/expected-second-"+str(i)+".json")
			if expected.is_empty() or var_to_bytes(expected)!=var_to_bytes(model.state):errors.append("second_different_state:"+str(i)+":"+store.error)
		elif mode.begins_with("long_"):
			var parts:=mode.split("_");var night: int=int(parts[1]);var stage: String=parts[2]
			if not store.load_from(path,model).ok:errors.append(mode+":load:"+str(i)+":"+store.error);continue
			if stage=="day":
				if not day_two(model,i):errors.append(mode+":day:"+str(i));continue
			elif stage=="confirm":
				if not model.settle_first_day_focus_return() or not confirm_next(model):errors.append(mode+":confirm:"+str(i));continue
			elif stage=="event":
				if model.state.pendingNightEvent!=null and not model.resolve_night_event(response(model)):errors.append(mode+":event:"+str(i));continue
			elif stage=="finish":
				if not model.finish_early_night():errors.append(mode+":finish:"+str(i));continue
			elif stage=="verify":
				var expected:=store.read_valid(folder+"/expected-night"+str(night)+"-"+str(i)+".json")
				if expected.is_empty() or var_to_bytes(expected)!=var_to_bytes(model.state):errors.append(mode+":different_state:"+str(i)+":"+store.error)
				continue
			else:errors.append("unknown long stage");break
			if not store.save_to(path,model.state):
				var evidence=FileAccess.open("res://../evidence/native_save_failed_state.bin",FileAccess.WRITE);evidence.store_buffer(var_to_bytes(model.state));evidence.close()
				errors.append(mode+":save:"+str(i)+":"+store.error)
		else:errors.append("unknown mode");break
	print(JSON.stringify({"mode":mode,"cases":12,"failed":errors,"passed":errors.is_empty()}));quit(0 if errors.is_empty() else 1)

func day_two(model,index: int) -> bool:
	if not model.enter_first_day_focus() or not model.select_first_day_focus("home"):return false
	var choices: Array=model.current_first_focus_event().choices;var available: Array=[]
	for i in range(choices.size()):
		if model.focus_choice_requirement(choices[i]).met:available.append(i)
	return not available.is_empty() and model.resolve_first_day_focus_choice(available[index%available.size()])
func response(model) -> String:
	for choice in ["quiet","give","wait","continue"]:
		if model.night_choice_requirement(choice):return choice
	return ""

func confirm_next(model) -> bool:
	model.state.phase="night";model.set_night_option("meal",model.state.rice>0 and model.state.wood>0);model.set_night_option("fire",1 if model.state.night.meal else 0)
	var treatments: Array=model.treatment_options()
	if not treatments.is_empty():model.set_night_treatment(treatments[0].value)
	return model.confirm_early_night()
