extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var model=Model.new();var stream=FileAccess.open("res://../evidence/staged_uncle_boundary_return_packets.jsonl",FileAccess.READ);var failed: Array=[];var checks:=0
	while stream.get_position()<stream.get_length():
		var line=stream.get_line()
		if line.is_empty():continue
		var case=JSON.parse_string(line);model.state=case.initial.duplicate(true);model.contract_error="";model.contract_message="";var packets: Array=model.state.focus.resultPackets.filter(func(p):return p.id==case.packetId);var packet: Dictionary=packets[0];var result:=model.apply_ordinary_pre_photo_packet(packet);checks+=3
		if result!=case.result or not helper.same_json(model.state,case.expected) or model.contract_error!="":
			if failed.is_empty():
				var file=FileAccess.open("res://../evidence/uncle_boundary_return_packets_first_diff.json",FileAccess.WRITE);file.store_string(JSON.stringify({"id":case.id,"result":result,"expectedResult":case.result,"error":model.contract_message,"differences":helper.diff_paths(model.state,case.expected)}))
			failed.append(case.id)
		var repeated:=model.apply_ordinary_pre_photo_packet(packet);checks+=2
		if repeated!=case.repeated or not helper.same_json(model.state,case.afterRepeated):failed.append(case.id+":repeat")
	helper.free();print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false,"visual_test":false}));quit(0 if failed.is_empty() else 1)
