extends SceneTree
const Model=preload("res://scripts/game_model.gd")
var helper
var failed: Array=[]
var checks:=0
func compare(id: String,model,expected: Dictionary) -> void:
	checks+=2
	if model.contract_error!="" or not helper.same_json(model.state,expected):
		if failed.is_empty():
			var file=FileAccess.open("res://../evidence/uncle_crisis_lifecycle_first_diff.json",FileAccess.WRITE);file.store_string(JSON.stringify({"id":id,"error":model.contract_message,"differences":helper.diff_paths(model.state,expected)}))
		failed.append(id)
func _initialize() -> void:
	helper=load("res://../tests/chapter_seven_choice.gd").new();var model=Model.new();var stream=FileAccess.open("res://../evidence/staged_uncle_crisis_lifecycle.jsonl",FileAccess.READ)
	while stream.get_position()<stream.get_length():
		var line=stream.get_line()
		if line.is_empty():continue
		var case=helper.decode_exact(JSON.parse_string(line));model.state=case.initial.duplicate(true);model.contract_error="";model.contract_message="";var s: Dictionary=model.state;var focus: Dictionary=s.focus;var event: Dictionary=focus.laterEvents[focus.eventId];var choice: Dictionary=event.choices[int(case.index)]
		model.prepare_uncle_crisis_choice(focus,event,choice);compare(case.id+":prepare",model,case.prepared)
		var packet: Dictionary={"id":s.seed+":D"+str(int(s.day)+1)+":"+event.id+":"+choice.id+":immediate","status":"pending","timing":"immediate","subjectId":event.actor,"effects":choice.immediateEffects.duplicate(true)};focus.resultPackets=[packet]
		model.apply_uncle_crisis_packet(packet);compare(case.id+":commit",model,case.committed)
		focus.choiceIndex=case.index;s.history.append({"type":"later-choice","day":s.day,"event":event.id,"choice":choice.id});model.before_uncle_crisis_return(focus,event);compare(case.id+":return",model,case.returned)
		s.history.append({"type":"later-return","day":s.day,"event":event.id})
		for day in range(42,49):
			s.day=day;s.phase="morning";s.morningResults=[];s.people["罗瑾"].spirit=0 if int(case.id)%4==0 and day<46 else 8;model.process_uncle_crisis_morning();compare(case.id+":D"+str(day+1),model,case.mornings[day-42])
	helper.free();print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false,"visual_test":false,"disk_process_test":false}));quit(0 if failed.is_empty() else 1)
