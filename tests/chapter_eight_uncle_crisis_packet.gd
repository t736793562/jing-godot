extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var model=Model.new();var stream=FileAccess.open("res://../evidence/staged_uncle_crisis_packet.jsonl",FileAccess.READ);var failed: Array=[];var checks:=0
	while stream.get_position()<stream.get_length():
		var line=stream.get_line()
		if line.is_empty():continue
		var case=helper.decode_exact(JSON.parse_string(line));model.state=case.initial.duplicate(true);model.contract_error="";model.contract_message="";var packet: Dictionary=model.state.focus.resultPackets[int(case.packetIndex)]
		if case.outside:packet=packet.duplicate(true)
		var result:=model.apply_uncle_crisis_packet(packet);checks+=3
		if result!=(case.result==true) or model.contract_message!=str(case.error if case.error!=null else "") or not helper.same_json(model.state,case.expected):
			if failed.is_empty():
				var file=FileAccess.open("res://../evidence/uncle_crisis_packet_first_diff.json",FileAccess.WRITE);file.store_string(JSON.stringify({"id":case.id,"error":model.contract_message,"expectedError":case.error,"differences":helper.diff_paths(model.state,case.expected)}))
			failed.append(case.id)
		if case.error==null:
			var repeat=model.apply_uncle_crisis_packet(packet);checks+=2
			if repeat!=case.repeated or not helper.same_json(model.state,case.afterRepeated):failed.append(case.id+":repeat")
	helper.free();print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false,"visual_test":false}));quit(0 if failed.is_empty() else 1)
