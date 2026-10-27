extends SceneTree
const Model=preload("res://scripts/game_model.gd")
var helper
var failed: Array=[]
var checks:=0
func compare(id: String,model,expected: Dictionary) -> void:
	checks+=1
	if not helper.same_json(model.state,expected):
		if failed.is_empty():
			var file=FileAccess.open("res://../evidence/disclosure_contract_first_diff.json",FileAccess.WRITE);file.store_string(JSON.stringify({"id":id,"error":model.contract_message,"differences":helper.diff_paths(model.state,expected)}))
		failed.append(id)
func _initialize() -> void:
	helper=load("res://../tests/chapter_seven_choice.gd").new();var model=Model.new();var stream=FileAccess.open("res://../evidence/staged_disclosure_contract.jsonl",FileAccess.READ)
	while stream.get_position()<stream.get_length():
		var line=stream.get_line()
		if line.is_empty():continue
		var case=helper.decode_exact(JSON.parse_string(line));model.state=case.initial.duplicate(true);model.contract_error="";model.contract_message=""
		if case.kind=="fact":
			var result: bool=model.disclosure_apply(case.fact);checks+=2
			if result!=(case.result==true) or model.contract_message!=str(case.error if case.error!=null else ""):failed.append(case.id+":apply")
			compare(case.id+":state",model,case.expected);model.contract_error="";model.contract_message="";result=model.disclosure_apply(case.fact);checks+=2
			if result!=(case.repeatResult==true) or model.contract_message!=str(case.repeatError if case.repeatError!=null else ""):failed.append(case.id+":repeat")
			compare(case.id+":repeated-state",model,case.afterRepeated)
		elif case.kind=="state":
			var result: bool=model.disclosure_validate();checks+=2
			if result!=(case.result==true) or model.contract_message!=str(case.error if case.error!=null else ""):failed.append(case.id+":validation:"+model.contract_message)
			compare(case.id+":readonly",model,case.initial)
		else:
			var availability: Dictionary=model.disclosure_availability(case.event,model.state.focus.plan);var result: bool=model.attach_disclosure_knowledge(model.state.focus.resultPackets[0],case.event,case.choice,"observed");checks+=3
			if not helper.same_json(availability,case.availability) or result!=(case.error==null) or model.contract_message!=str(case.error if case.error!=null else ""):failed.append(case.id+":attachment")
			compare(case.id+":attach-state",model,case.expected)
	helper.free();print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false,"visual_test":false,"main_integrated":true}));quit(0 if failed.is_empty() else 1)
