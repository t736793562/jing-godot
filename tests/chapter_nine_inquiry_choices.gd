extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var model=Model.new();var f=FileAccess.open("res://../evidence/staged_chapter_nine_inquiry_choices.jsonl",FileAccess.READ);var checks:=0;var failed: Array=[]
	while f.get_position()<f.get_length():
		var line=f.get_line()
		if line.is_empty():continue
		var row=JSON.parse_string(line);model.state=row.initial.duplicate(true);var result:=model.resolve_day_eleven_twelve_choice(int(row.index));checks+=2
		if result!=row.resolved or not helper.same_json(model.state,row.expected):failed.append(row.id+":choice")
		result=model.resolve_day_eleven_twelve_choice(int(row.index));checks+=2
		if result!=row.repeat or not helper.same_json(model.state,row.afterRepeat):failed.append(row.id+":repeat")
	for flag in ["householdInquiryNoted","familyReturnAgreement","testimonyBoundaryRespected"]:
		for value in [false,null,1,"true",{},[]]:
			checks+=1
			if model.ordinary_pre_photo_effect_supported({"type":"flag_set","flag":flag,"value":value}):failed.append("invalid-flag-value:"+flag+":"+str(value))
	checks+=1
	if model.ordinary_pre_photo_effect_supported({"type":"flag_set","flag":"unknown-inquiry","value":true}):failed.append("unknown-flag")
	helper.free();print(JSON.stringify({"checks":checks,"failed":failed,"full_route":false,"main_integrated":true}));quit(0 if failed.is_empty() else 1)
