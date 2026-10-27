extends SceneTree
const Controller=preload("res://scripts/game_controller.gd")
var game
var checks:=0
var failed: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failed.append(label)
func press(id: String) -> void:
	check(game.controls.has(id),"exists:"+id)
	if game.controls.has(id):
		check(not game.controls[id].disabled,"enabled:"+id)
		if not game.controls[id].disabled:game.controls[id].pressed.emit()
	await process_frame;await process_frame
func run() -> void:
	game=Controller.new();game.autosave_enabled=false;root.add_child(game);game.size=Vector2(1920,1080);await process_frame
	var loaded=game.save_store.load_from("user://chapter-eight-promoted-disk-20261026/controlled-rope-decline.json",game.model);check(loaded.ok,"load-parent")
	if not loaded.ok:print(JSON.stringify({"failed":failed}));quit(1);return
	game.restore_continuation(game.save_store.decoded_proof);game.screen="morning";game.render_screen();await process_frame
	var before=var_to_bytes(game.model.state);var rng=game.model.rng.state;var proof=var_to_bytes(game.continuation.proof())
	await press("toolbar_record_menu");await press("book_household");check(game.screen=="household","household-entry")
	check(game.household_data.tools.size()==14 and game.household_data.rice==game.model.state.rice,"actual-inventory")
	await press("household_tool_guide");check(game.tool_guide_open and game.tool_guide_data.guide.size()==13,"source-tool-guide");await press("household_tool_guide")
	for tab in [1,2,0]:await press("household_tab_"+str(tab));check(game.household_tab==tab,"tab:"+str(tab))
	check(game.household_data.recall.is_empty() and not game.controls.has("household_recall_pending"),"no-invented-recall")
	await press("household_back");check(game.screen=="recordMenu","back-book");await press("book_resume");check(game.screen=="morning","back-game")
	check(var_to_bytes(game.model.state)==before and game.model.rng.state==rng and var_to_bytes(game.continuation.proof())==proof,"navigation-readonly")
	var base: Dictionary=game.model.state.duplicate(true)
	for type in ["goose","pigeon","cat","dog"]:
		game.model.state=base.duplicate(true);game.model.state.animals={"poultry":null,"pet":null};var slot: String="poultry" if type in ["goose","pigeon"] else "pet";check(game.model.add_animal(slot,type),"controlled-animal:"+type)
		var snapshot=var_to_bytes(game.model.state);var data: Dictionary=game.public_household_projection();check(data.animals[slot].type==type and var_to_bytes(game.model.state)==snapshot,"animal-projection:"+type)
		if type=="pigeon":
			game.model.state.animals.poultry.sent=true;game.model.state.animals.poultry.resolved=false;game.model.state.animals.poultry.outcome="delivery";game.model.state.animals.poultry.flightRoll=0.1;var first=var_to_bytes(game.public_household_projection())
			game.model.state.animals.poultry.outcome="no_reply";game.model.state.animals.poultry.flightRoll=0.9;check(first==var_to_bytes(game.public_household_projection()),"no-hidden-pigeon-outcome")
		game.household_tab=1;game.screen="household";game.render_screen();await process_frame
	game.model.state=base.duplicate(true);game.model.state.expedition.active={"name":"母亲","route":"约定的普通路线","expectedDay":45,"latestDay":47,"tools":["rope","canteen"],"outcomeId":"safe","roll":0.1,"search":{"mode":"luo","status":"waiting","outcome":"found"}}
	var first=var_to_bytes(game.public_household_projection());game.model.state.expedition.active.outcomeId="lost";game.model.state.expedition.active.roll=0.99;game.model.state.expedition.active.search.outcome="lost"
	check(first==var_to_bytes(game.public_household_projection()),"no-hidden-expedition-outcome");check(game.public_household_projection().tools.rope=="远行带走","carried-not-available")
	game.household_tab=2;game.render_screen();await process_frame
	game.model.state=base.duplicate(true);game.model.state.animals.poultry=null;game.model.state.memory.pigeonRequest={"pickup":true,"pickupDone":false,"pickupDeadline":46};check(game.public_household_projection().pigeon_note=="取物纸条约定至第47日","paper-persists-without-bird")
	game.model.state=base;game.model.rng.state=rng;check(game.load_errors.is_empty(),"resources:"+str(game.load_errors))
	print(JSON.stringify({"checks":checks,"failed":failed,"controlled_projection":true,"main_integrated":true,"visual_test":false,"real_mouse_test":false,"recall_action_implemented":false,"expedition_gameplay_implemented":false}));game.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
