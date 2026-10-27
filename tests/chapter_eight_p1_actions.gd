extends SceneTree
const Model=preload("res://scripts/game_model.gd")
var helper
var failed: Array=[]
var checks:=0
func compare(id: String,model,expected: Dictionary) -> void:
	checks+=1
	if not helper.same_json(model.state,expected):
		if failed.is_empty():
			var file=FileAccess.open("res://../evidence/p1_actions_first_diff.json",FileAccess.WRITE);file.store_string(JSON.stringify({"id":id,"error":model.contract_message,"differences":helper.diff_paths(model.state,expected)}))
		failed.append(id)
func _initialize() -> void:
	helper=load("res://../tests/chapter_seven_choice.gd").new();var model=Model.new();var stream=FileAccess.open("res://../evidence/staged_p1_actions.jsonl",FileAccess.READ)
	while stream.get_position()<stream.get_length():
		var line=stream.get_line()
		if line.is_empty():continue
		var case=helper.decode_exact(JSON.parse_string(line));model.state=case.initial.duplicate(true);model.contract_error="";model.contract_message="";var focus: Dictionary=model.state.focus;var event: Dictionary=focus.laterEvents[case.event];var choice: Dictionary=event.choices[int(case.index)]
		var ready: bool=model.prepare_p1_choice(focus,event,choice);checks+=2
		if ready!=(case.prepareError==null) or model.contract_message!=str(case.prepareError if case.prepareError!=null else ""):failed.append(case.id+":prepare-status")
		compare(case.id+":prepare",model,case.prepared)
		if case.afterScene==null:continue
		var base=model.queue_focus_packet(choice.immediateEffects,event.id+":"+choice.id+":immediate","immediate",event.actor);model.apply_ordinary_pre_photo_packet(base)
		if case.mode==7:model.state.people[event.actor].health=1
		var completed: bool=model.complete_p1_scene(focus,event,choice);checks+=1
		if completed!=case.completed:failed.append(case.id+":scene-status")
		compare(case.id+":scene",model,case.afterScene)
		if not case.completed:continue
		focus.choiceIndex=case.index;model.state.phase="focusResult"
		if case.mode==8:model.state.people["罗瑾"].spirit=0
		if case.mode==9:
			for person in model.PEOPLE:
				if person!=event.actor:model.state.people[person].spirit=0
		var found: Array=focus.resultPackets.filter(func(p):return p.id==focus.workPackets["母亲"]);var lines: Array=[];var work: bool=model.apply_p1_work(focus,event,focus.plan.rows["母亲"],found[0],lines);checks+=2
		if work!=case.workResult or not helper.same_json(lines,case.lines):failed.append(case.id+":work-result")
		compare(case.id+":work",model,case.afterWork)
		model.contract_error="";model.contract_message="";model.complete_p1_return(focus,event);checks+=2
		if model.contract_message!=str(case.tellError if case.tellError!=null else "") or model.p1_return_knowledge_allowed(focus,event)!=case.allowed:failed.append(case.id+":tell-status")
		compare(case.id+":tell",model,case.expected)
	helper.free();print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false,"visual_test":false}));quit(0 if failed.is_empty() else 1)
