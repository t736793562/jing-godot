extends SceneTree
const Controller=preload("res://scripts/game_controller.gd")
var game
var checks:=0
var failed: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failed.append(label)
func frames() -> void:
	await process_frame;await process_frame;await process_frame
func press(id: String) -> void:
	check(game.controls.has(id),"exists:"+id)
	if game.controls.has(id):
		check(not game.controls[id].disabled,"enabled:"+id)
		if not game.controls[id].disabled:game.controls[id].pressed.emit()
	await frames()
func install(s: Dictionary) -> void:
	game.model=game.Model.new();game.model.state=s.duplicate(true);game.screen="night";game.render_screen();await frames()
func run() -> void:
	game=Controller.new();game.autosave_enabled=false;game.settings_path="user://bird-ui-test-settings.cfg";root.add_child(game);await frames()
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var f=FileAccess.open("res://../evidence/staged_pigeon_natural_reference.jsonl",FileAccess.READ);var row=helper.decode_exact(JSON.parse_string(f.get_line()));var send: Dictionary={};var collect: Dictionary={}
	for i in range(1,row.steps.size()):
		var step=row.steps[i]
		if step.op=="pigeon" and step.args[0]=="send":send=row.steps[i-1].state
		if step.op=="pigeon" and step.args[0]=="collect":collect=row.steps[i-1].state
	check(not send.is_empty() and not collect.is_empty(),"natural-fixtures")
	var start: Dictionary={};var choice_index:=0;var expected: Dictionary={}
	for i in range(row.steps.size()):
		var step=row.steps[i]
		if step.op=="select" and step.state.focus.plan.get("key")=="pigeonPickup":start=step.state
		if step.op=="choice" and step.state.focus.plan.get("key")=="pigeonPickup":choice_index=int(step.args[0])
		if step.op=="return" and step.state.focus.plan.get("key")=="pigeonPickup":expected=step.state
	check(not start.is_empty() and not expected.is_empty(),"pickup-fixture")
	game.model=game.Model.new();game.model.state=start.duplicate(true);game.screen="focusEvent";game.render_screen();await frames()
	check(game.controls.has("focus_choice_0") and game.controls.has("focus_choice_1") and game.controls.has("focus_choice_2"),"three-pickup-choices")
	var rice=game.model.state.rice;await press("focus_choice_"+str(choice_index));check(game.screen=="focusResult" and game.model.state.rice==rice,"choice-not-yet-delivered")
	await press("focus_result_next");check(game.screen=="focusReturn" and helper.same_json(game.model.state,expected),"return-source-match")
	await press("focus_return_diary");check(game.native_focus_diary()=="\n\n".join(expected.focus.chapterDiary),"early-pigeon-diary-complete")
	await press("day_open_night");check(game.screen=="night" and game.model.state.phase=="night","diary-back-to-night")
	print(JSON.stringify({"checks":checks,"failed":failed,"main_integrated":true,"visual_test":false,"real_mouse_test":false,"scope":"Actual pickup choice, return, diary and night control signals from a normal-start source snapshot; not mouse/visual acceptance."}));helper.free();game.queue_free();await frames();quit(0 if failed.is_empty() else 1)
