extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var model=Model.new();var stream=FileAccess.open("res://../evidence/staged_route_warning_packets.jsonl",FileAccess.READ);var failed: Array=[];var checks:=0
	while stream.get_position()<stream.get_length():
		var line=stream.get_line()
		if line.is_empty():continue
		var case=JSON.parse_string(line);model.state=case.initial.duplicate(true);model.contract_error="";model.contract_message="";var packet: Dictionary=case.packet.duplicate(true);var result: Variant=null
		if case.kind=="witness":model.attach_route_warning_witness(packet,case.event)
		elif case.kind=="mark":model.mark_route_warning_return(packet,case.event)
		else:result=model.complete_route_warning_return(packet)
		checks+=4
		if case.error==null and not helper.same_json(result,case.result) or model.contract_message!=str(case.error if case.error!=null else "") or not helper.same_json(model.state,case.expected) or not helper.same_json(packet,case.expectedPacket):
			if failed.is_empty():
				var file=FileAccess.open("res://../evidence/route_warning_packets_first_diff.json",FileAccess.WRITE);file.store_string(JSON.stringify({"id":case.id,"result":result,"expectedResult":case.result,"error":model.contract_message,"expectedError":case.error,"stateDiff":helper.diff_paths(model.state,case.expected),"packetDiff":helper.diff_paths(packet,case.expectedPacket)}))
			failed.append(case.id)
	helper.free();print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false,"visual_test":false}));quit(0 if failed.is_empty() else 1)
