extends SceneTree
const Model=preload("res://scripts/game_model.gd")
var model=Model.new()
func view() -> Dictionary:
	var status: Dictionary=model.expedition_plan_status();var p=model.state.expedition.plan;var reservation: Variant=null;var risk: Variant=null
	if not model.js_truthy(p) or status.renderNative:
		reservation=model.expedition_reservation()
		if p is Dictionary and model.expedition_rules.routes.has(p.get("name")) and p.get("tools") is Array:risk=model.expedition_risk(p)
	return {"status":status,"reservation":reservation,"risk":risk}
func _initialize() -> void:
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var file=FileAccess.open("res://../evidence/staged_expedition_plan_reference.jsonl",FileAccess.READ);var checks:=0;var failed: Array=[];var cases:=0
	var mapping: Dictionary={"planExpedition":"plan_expedition","toggleExpeditionTool":"toggle_expedition_tool","toggleExpeditionSupply":"toggle_expedition_supply","validateExpeditionPlan":"validate_expedition_plan"}
	while file.get_position()<file.get_length():
		var line=file.get_line()
		if line.is_empty():continue
		var row=helper.decode_exact(JSON.parse_string(line));cases+=1;model.state=row.initial.duplicate(true);var before=var_to_bytes(model.state);var rng=model.rng.state;var actual:=view();checks+=3
		if not helper.same_json(actual,row.initialView) or before!=var_to_bytes(model.state) or model.rng.state!=rng:
			if failed.is_empty():write_diff(row.id,"initial",actual,row.initialView,helper)
			failed.append(row.id+":initial");continue
		for i in range(row.steps.size()):
			var step: Dictionary=row.steps[i];var result=model.callv(mapping[step.method],step.args);var actual_view:=view();checks+=4
			if result!=step.result or not helper.same_json(model.state,step.after) or not helper.same_json(actual_view,step.view) or model.rng.state!=rng:
				if failed.is_empty():write_diff(row.id,step.method+":"+str(i),{"result":result,"state":model.state,"view":actual_view},{"result":step.result,"state":step.after,"view":step.view},helper)
				failed.append(row.id+":"+step.method+":"+str(i));break
	helper.free();print(JSON.stringify({"cases":cases,"checks":checks,"failed":failed,"main_integrated":true,"departure_tested":false,"travel_return_tested":false,"visual_test":false}));quit(0 if failed.is_empty() else 1)
func write_diff(id,step,actual,expected,helper) -> void:
	var f=FileAccess.open("res://../evidence/expedition_plan_first_diff.json",FileAccess.WRITE);f.store_string(JSON.stringify({"id":id,"step":step,"differences":helper.diff_paths(actual,expected),"actual":actual,"expected":expected}))
