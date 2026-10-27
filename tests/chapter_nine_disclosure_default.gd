extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var model=Model.new();var stream=FileAccess.open("res://../evidence/staged_disclosure_default.jsonl",FileAccess.READ);var failed: Array=[];var checks:=0
	while stream.get_position()<stream.get_length():
		var line=stream.get_line()
		if line.is_empty():continue
		var case=helper.decode_exact(JSON.parse_string(line));model.state=case.initial.duplicate(true);model.contract_error="";model.contract_message="";var focus: Dictionary=model.state.focus;var event: Dictionary=focus.laterEvents[focus.eventId];var eligible: bool=model.later_event_eligible(event,focus.plan);var requirement:=model.ordinary_pre_photo_requirement(event.choices[0]);var cloned:=model.ordinary_pre_photo_requirement(event.choices[0].duplicate(true));var ready:=model.disclosure_default_ready(event,focus.plan);checks+=5
		if eligible!=case.eligible or not helper.same_json(requirement,case.requirement) or not helper.same_json(cloned,case.clonedRequirement) or ready!=case.ready or not helper.same_json(model.state,case.expected):
			if failed.is_empty():
				var file=FileAccess.open("res://../evidence/disclosure_default_first_diff.json",FileAccess.WRITE);file.store_string(JSON.stringify({"id":case.id,"requirement":requirement,"expectedRequirement":case.requirement,"cloned":cloned,"expectedCloned":case.clonedRequirement,"ready":ready,"expectedReady":case.ready,"differences":helper.diff_paths(model.state,case.expected)}))
			failed.append(case.id)
	helper.free();print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false,"visual_test":false,"main_integrated":true}));quit(0 if failed.is_empty() else 1)
