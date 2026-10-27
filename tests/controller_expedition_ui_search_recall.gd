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
	var parent: String="user://expedition-native-disk-20261027-v01/decline-mother.json";var original_sha:=FileAccess.get_sha256(parent);var loaded: Dictionary=game.save_store.load_from(parent,game.model);check(loaded.ok,"real-parent-load");game.continuation.restore(game.save_store.decoded_proof)
	game.household_tab=2;game.household_return_screen="recordMenu";game.household_data=game.public_household_projection();game.screen="household";var before=var_to_bytes(game.model.state);var day=game.model.state.day;var actions=game.continuation.actions.size();game.render_screen();await process_frame
	check(before==var_to_bytes(game.model.state),"household-render-readonly");await press("household_recall");check(game.screen=="expeditionRecall" and game.model.state.phase=="expeditionRecall","recall-open");check(game.model.state.day==day,"recall-no-date-change")
	var body=game.holder.find_child("expedition_recall_prose",true,false);check(body!=null and body.text.contains(game.model.state.expedition.history[-1].recall.paragraphs[0]),"full-real-recall-text")
	await press("recall_scroll_down");await press("recall_close");check(game.screen=="household" and game.model.state.phase=="morning","recall-original-phase");check(game.model.state.expedition.history[-1].recall.read and game.model.state.day==day and game.continuation.actions.size()==actions+2,"read-recorded-once");check(original_sha==FileAccess.get_sha256(parent),"parent-file-untouched")
	var reader=game.SaveStore.new();var m=game.Model.new();check(reader.load_from("user://expedition-native-disk-20261027-v01/lend-mother.json",m).ok,"search-proof-load");var proof: Dictionary=reader.decoded_proof;var replay=game.Model.new();replay.state=proof.anchor.duplicate(true);var journal=Journal.new();journal.restore({"revision":proof.revision,"anchor":proof.anchor,"actions":[]});var found:=false
	for a in proof.actions:
		var result: bool=journal.apply(replay,a.op,a.args)
		if result!=a.ok:check(false,"prefix-replay");break
		if replay.state.phase=="search":found=true;break
	check(found,"real-search-checkpoint")
	if found:
		game.model=replay;game.continuation=journal;game.screen="search";before=var_to_bytes(replay.state);var saved=replay.state.duplicate(true);var saved_proof=journal.proof();var rng=replay.rng.state;var projection=game.expedition_search_projection();game.render_screen();await process_frame
		check(before==var_to_bytes(replay.state) and rng==replay.rng.state and var_to_bytes(saved_proof)==var_to_bytes(journal.proof()),"search-render-readonly");check(game.current.id==game.SEARCH_LAYOUT,"approved-ui13");check(game.controls.search_luo.disabled==not projection.luo_reason.is_empty(),"luo-actual-gate")
		await press("search_back");check(game.screen=="room" and replay.state.phase=="search","back-keeps-pending-search");game.screen="search";game.render_screen();await process_frame
		var rice=replay.state.rice;await press("search_wait");check(replay.state.phase=="morning" and replay.state.rice==rice and replay.state.day==saved.day,"wait-no-cost-no-date");replay.state=saved.duplicate(true);journal.restore(saved_proof);game.screen="search";game.render_screen();await process_frame
		await press("search_ask");check(replay.state.rice==rice-1 and replay.state.expedition.active.search.status=="waiting" and replay.state.phase=="morning","ask-pay-once-wait-result")
	var helper=load("res://../tests/chapter_seven_choice.gd").new();var f=FileAccess.open("res://../evidence/staged_expedition_binding_reference.jsonl",FileAccess.READ);var row=helper.decode_exact(JSON.parse_string(f.get_line()));helper.free();game.model.state=row.afterSelect.duplicate(true);game.screen="focusEvent";before=var_to_bytes(game.model.state);game.render_screen();await process_frame;await process_frame
	check(game.current.id==game.SEARCH_EVENT_LAYOUT,"approved-ui14");body=game.holder.find_child("expedition_search_prose",true,false);check(body!=null and body.text==game.native_focus_event().intro,"full-search-scene-text");check(game.controls.has("search_scene_choice_0") and game.controls.has("search_scene_choice_1") and game.controls.has("search_scene_back"),"scene-controls-wired");await press("search_scene_scroll_down");check(before==var_to_bytes(game.model.state),"scene-scroll-readonly")
	check(game.load_errors.is_empty(),"resources:"+str(game.load_errors));print(JSON.stringify({"checks":checks,"failed":failed,"main_integrated":true,"visual_test":false,"real_mouse_test":false,"scope":"Control signals and real native-proof recall/search actions; UI14 render/scroll only, not mouse/visual acceptance."}));game.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
