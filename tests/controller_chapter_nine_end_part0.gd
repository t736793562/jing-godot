extends SceneTree
const Controller=preload("res://scripts/game_controller.gd")
var game
var failed: Array=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failed.append(label)
func press(id: String) -> void:
	check(game.controls.has(id),"control:"+id)
	if game.controls.has(id):game.controls[id].pressed.emit()
	await process_frame;await process_frame
func run() -> void:
	game=Controller.new();game.autosave_enabled=false;root.add_child(game);game.size=Vector2(1920,1080);await process_frame
	var cohort: String=OS.get_environment("JING_C9_UI_COHORT")
	if cohort.is_empty():cohort="c9-controlled"
	game.save_path="user://chapter-nine-candidate-disk-20261027/"+cohort+".json"
	game.continue_saved()
	var loaded: Dictionary={"ok":not game.model.state.is_empty()}
	check(loaded.ok,"terminal-cold-load:"+game.save_store.error)
	if not loaded.ok:print(JSON.stringify({"failed":failed}));quit(1);return
	game.restore_continuation(game.save_store.decoded_proof.duplicate(true));game.screen="end";game.render_screen();await process_frame;await process_frame
	var before=var_to_bytes(game.model.state);var proof=var_to_bytes(game.continuation.proof());var rng=game.model.rng.state
	check(game.controls.has("ending_records"),"normal-ending-entry")
	check(game.state_summary(game.model.state)=="四十九日结束 · 结局","no-day50-summary")
	await press("ending_records");check(game.screen=="photoRecords","record-screen")
	for tab in range(4):
		await press("record_tab_"+str(tab));check(game.photo_record_tab==tab,"tab:"+str(tab))
		var rects: Array=[]
		for i in range(4):
			var id="record_tab_"+str(i);check(game.controls.has(id),"tab-present:"+id)
			if game.controls.has(id):
				var b=game.controls[id];var r=Rect2(b.position,b.size);check(r.size.x>0 and r.size.y>0,"positive-hit:"+id);rects.append(r)
		for i in range(rects.size()):
			for j in range(i+1,rects.size()):check(not rects[i].intersects(rects[j]),"nonoverlap:"+str(tab)+":"+str(i)+":"+str(j))
		check(game.load_errors.is_empty(),"resources:"+str(tab)+":"+str(game.load_errors))
		check(before==var_to_bytes(game.model.state) and proof==var_to_bytes(game.continuation.proof()) and rng==game.model.rng.state,"readonly:"+str(tab))
	await press("records_back");check(game.screen=="end","back-end")
	game.open_reading_settings();game.render_screen();await process_frame
	await press("reading_back");check(game.screen=="end","settings-return-end")
	game.open_saves();game.render_screen();await process_frame
	await press("save_back");check(game.screen=="end","save-return-end")
	await press("ending_menu");check(game.screen=="menu","back-menu")
	check(before==var_to_bytes(game.model.state) and proof==var_to_bytes(game.continuation.proof()),"exit-readonly")
	print(JSON.stringify({"checks":checks,"failed":failed,"visual_test":false,"real_mouse_test":false,"main_integrated":true}));game.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
