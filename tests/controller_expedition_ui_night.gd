extends SceneTree
const Controller=preload("res://scripts/game_controller.gd")
const Journal=preload("res://scripts/native_continuation.gd")
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
	game=Controller.new();game.autosave_enabled=false;game.settings_path="user://expedition-ui-test-settings.cfg";root.add_child(game);await process_frame;await process_frame
	var parent="user://expedition-native-disk-20261027-v01/decline-mother.json";var source_sha:=FileAccess.get_sha256(parent);var reader=game.SaveStore.new();var loaded: Dictionary=reader.load_from(parent,game.model);check(loaded.ok,"parent-proof-load");var proof: Dictionary=reader.decoded_proof;var model=game.Model.new();model.state=proof.anchor.duplicate(true);var journal=Journal.new();journal.restore({"revision":proof.revision,"anchor":proof.anchor,"actions":[]});var found:=false
	for a in proof.actions:
		var result: bool=journal.apply(model,a.op,a.args)
		if result!=a.ok:check(false,"proof-prefix");break
		if a.op=="expedition_plan":found=true;break
	check(found,"actual-prepared-night");game.model=model;game.continuation=journal;game.screen="night";var before=var_to_bytes(model.state);var old_rng=model.rng.state;game.render_screen();await process_frame;await process_frame
	check(before==var_to_bytes(model.state) and old_rng==model.rng.state,"night-render-readonly");check(game.current.id=="UI17_main","approved-ui17");var rice=model.state.rice;var water=model.state.water;var wood=model.state.wood
	await press("expedition_actor_0");check(model.state.expedition.plan==null,"second-click-cancels-draft");check(model.state.rice==rice and model.state.water==water and model.state.wood==wood,"cancel-no-refund-or-charge")
	await press("expedition_actor_2");check(model.state.expedition.plan.name=="外祖父","grandfather-selected");check(game.controls.has("expedition_tool_axe"),"eighth-tool-present");var scroll=game.holder.find_child("expedition_kit_scroll",true,false);check(scroll!=null and scroll.get_h_scroll_bar().max_value>scroll.get_h_scroll_bar().page,"eighth-tool-scrollable")
	await press("expedition_tool_rope");await press("expedition_tool_canteen");check(model.state.expedition.plan.tools.size()==2,"two-items-selected");check(game.controls.expedition_tool_umbrella.disabled,"third-item-disabled")
	await press("expedition_supply_water");await press("expedition_supply_rice");check(model.state.expedition.plan.water==1 and model.state.expedition.plan.rice==1,"supplies-draft");check(model.state.rice==rice and model.state.water==water and model.state.wood==wood,"preparation-not-charged")
	var cost: Dictionary=model.preview_night().cost.duplicate(true);await press("night_confirm");check(model.state.phase=="nightEvent" and model.state.expedition.plan==null and model.state.expedition.active.name=="外祖父" and model.state.people["外祖父"].away,"confirmed-departure");check(model.state.rice==rice-cost.rice and model.state.water==water-cost.water and model.state.wood==wood-cost.wood,"night-cost-once")
	before=var_to_bytes(model.state);check(not game.native_confirm_night() and var_to_bytes(model.state)==before,"reconfirm-no-double-charge");check(FileAccess.get_sha256(parent)==source_sha,"parent-save-untouched");check(game.load_errors.is_empty(),"resources:"+str(game.load_errors))
	print(JSON.stringify({"checks":checks,"failed":failed,"main_integrated":true,"visual_test":false,"real_mouse_test":false,"scope":"Approved UI17 native control signals with real D11-anchored proof; no screenshot or mouse acceptance."}));game.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
