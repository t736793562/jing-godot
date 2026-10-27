extends SceneTree
class FaultModel:
	extends "res://scripts/game_model.gd"
	var fault: String=""
	func prepare_chapter_seven_photo_choice(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
		var result:=super.prepare_chapter_seven_photo_choice(focus,event,choice)
		if result and fault=="after_rng":fail_contract("INJECTED","测试注入：抽签后中断");return false
		return result
	func apply_ordinary_pre_photo_packet(packet: Dictionary) -> bool:
		var result:=super.apply_ordinary_pre_photo_packet(packet)
		if result and fault=="after_effects":fail_contract("INJECTED","测试注入：结算后中断");return false
		return result
	func attach_deadline_scene_knowledge(packet: Dictionary,event: Dictionary) -> bool:
		var result:=super.attach_deadline_scene_knowledge(packet,event)
		if result and fault=="packet_queued":fail_contract("INJECTED","测试注入：建包后中断");return false
		return result
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new()
	var stream=FileAccess.open("res://../evidence/staged_chapter_seven_choice_reference.jsonl",FileAccess.READ)
	var case=helper.decode_exact(JSON.parse_string(stream.get_line()));var checks:=0;var failed: Array=[]
	for fault in ["after_rng","packet_queued","after_effects"]:
		var model=FaultModel.new();model.state=case.initial.duplicate(true);model.fault=fault
		var result:=model.resolve_chapter_seven_photo_choice(int(case.index));var expected: Dictionary=case.initial.duplicate(true);expected.error=model.state.error;checks+=3
		if result or not helper.same_json(model.state,expected) or not str(model.state.error).begins_with("这次选择尚未结算：测试注入："):failed.append(fault)
		model.fault="";model.contract_error="";model.contract_message="";var retried:=model.resolve_chapter_seven_photo_choice(int(case.index));checks+=2
		if not retried or not helper.same_json(model.state,case.expected):failed.append(fault+":retry")
		model=null
	for index in [-1,999]:
		var model=FaultModel.new();model.state=case.initial.duplicate(true);checks+=2
		if model.resolve_chapter_seven_photo_choice(index) or not helper.same_json(model.state,case.initial):failed.append("invalid_index:"+str(index))
		model=null
	helper.free();print(JSON.stringify({"checks":checks,"failed":failed,"scope":"Injected candidate faults prove state/RNG/packet rollback and retry only; not observed source failures or GUI."}));quit(0 if failed.is_empty() else 1)
