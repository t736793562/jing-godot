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
	await install(send);var rice=game.model.state.rice;var snapshot=var_to_bytes(game.model.state)
	await press("pigeon_open");check(game.screen=="pigeonPlan" and var_to_bytes(game.model.state)==snapshot,"open-readonly");await press("pigeon_send");check(game.model.state.night.pigeonAction=="send" and game.model.state.rice==rice,"send-preselection-no-charge");await press("pigeon_none");check(game.model.state.night.pigeonAction=="none","clear-send");await press("pigeon_back");check(game.screen=="night","back-night")
	await install(collect);rice=game.model.state.rice;await press("pigeon_open");await press("pigeon_collect");check(game.model.state.night.pigeonAction=="collect" and game.model.state.rice==rice,"collect-preselection-no-charge");await press("pigeon_delay");check(game.model.state.night.pigeonAction=="delay","delay-selected");await press("pigeon_none");check(game.model.state.night.pigeonAction=="none","clear-collect");await press("pigeon_back")
	# Explicit UI edge fixture: physical bird is gone; its verified note survives.
	game.model.state.memory.pigeonRequest=game.model.pigeon_request().duplicate(true);game.model.state.animals.poultry=null;game.render_screen();await frames();check(not game.controls.animal_tab_poultry.disabled,"paper-only-tab-enabled");await press("pigeon_open");check(game.controls.has("pigeon_collect"),"paper-only-pickup-card");await press("pigeon_collect");check(game.model.state.night.pigeonAction=="collect","paper-only-collect")
	# Explicit stale fixture; no resources may be deducted, cancellation remains possible.
	game.model.state.memory.erase("pigeonRequest");game.render_screen();await frames();check(game.controls.pigeon_send.disabled,"stale-send-disabled");await press("pigeon_none");check(game.model.state.night.pigeonAction=="none" and game.model.state.rice==rice,"stale-clear-no-charge");await press("pigeon_back")
	await install(send);game.model.state.day=3;game.screen="pigeonPlan";game.render_screen();await frames();check(game.controls.pigeon_send.disabled,"before-d5-disabled")
	game.model.state.day=4;game.model.state.nightCycle={"day":4};game.render_screen();await frames();check(game.controls.pigeon_send.disabled and game.controls.pigeon_none.disabled,"confirmed-night-locked");await press("pigeon_back");check(game.load_errors.is_empty(),"resources:"+str(game.load_errors))
	print(JSON.stringify({"checks":checks,"failed":failed,"main_integrated":true,"visual_test":false,"real_mouse_test":false,"scope":"Approved supplementary art components and actual control signals; normal-start night snapshots plus labelled paper-only/stale/locked UI edge fixtures."}));helper.free();game.queue_free();await frames();quit(0 if failed.is_empty() else 1)
