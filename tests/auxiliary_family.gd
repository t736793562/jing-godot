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
	game.begin_game("family-gates");check(not game.public_home_allowed() and not game.photo_records_visible(),"opening-gates")
	var screen_before: String=game.screen;game.open_record_menu();check(game.screen==screen_before,"opening-no-record-access")
	var key:=InputEventKey.new();key.keycode=KEY_F7;key.pressed=true;game._unhandled_key_input(key);check(game.screen==screen_before,"hidden-photo-hotkey-blocked")
	var loaded=game.save_store.load_from("user://chapter-eight-promoted-disk-20261026/controlled-rope-decline.json",game.model);check(loaded.ok,"load-parent")
	if not loaded.ok:print(JSON.stringify({"failed":failed}));quit(1);return
	game.restore_continuation(game.save_store.decoded_proof);game.screen="morning";game.render_screen();await process_frame
	var before=var_to_bytes(game.model.state);var rng=game.model.rng.state;var proof=var_to_bytes(game.continuation.proof())
	await press("toolbar_record_menu");check(game.screen=="recordMenu","book-menu")
	await press("book_family");check(game.screen=="family" and game.family_data.size()==4,"family-panel")
	await press("family_back");check(game.screen=="recordMenu","family-back")
	await press("book_photo");check(game.screen=="photoRecords","photo-revealed-entry");await press("records_back");check(game.screen=="recordMenu","photo-back-book")
	await press("book_resume");check(game.screen=="morning","book-back-game")
	check(var_to_bytes(game.model.state)==before and var_to_bytes(game.continuation.proof())==proof and game.model.rng.state==rng,"navigation-immutable")
	# Controlled public-state projection cases, not naturally reached deaths/missing states.
	var base: Dictionary=game.model.state.duplicate(true)
	for status in ["present","away","lost","dead","detained","pending"]:
		game.model.state=base.duplicate(true);var p: Dictionary=game.model.state.people["安仁叔叔"];p.alive=true;p.away=false;p.permanentLost=false;p.detainedUntil=null;game.model.state.memory.erase("uncleCrisisR4b")
		if status=="away":p.away=true
		elif status=="lost":p.permanentLost=true
		elif status=="dead":p.alive=false
		elif status=="detained":p.detainedUntil=48
		elif status=="pending":game.model.state.memory.uncleCrisisR4b={"status":"pending","settled":true}
		for h in [0,1,2,4,6,8,10]:
			p.health=h;p.spirit=h;var snap=var_to_bytes(game.model.state);var rows: Array=game.public_family_projection();var row: Dictionary=rows.filter(func(x):return x.name=="安仁叔叔")[0]
			check(var_to_bytes(game.model.state)==snap,"projection-immutable:"+status+":"+str(h))
			if status=="present":check(row.here and row.spirit==game.public_status(h,false),"public-status:"+str(h))
			else:check(not row.here and row.health=="" and row.spirit=="" and row.ailment=="","no-absent-hidden-health:"+status)
			if status=="lost":check(row.short=="失散" and "死亡" not in row.status,"lost-not-dead")
		game.screen="family";game.render_screen();await process_frame
	game.model.state=base;game.model.rng.state=rng
	check(game.load_errors.is_empty(),"resources:"+str(game.load_errors))
	print(JSON.stringify({"checks":checks,"failed":failed,"controlled_projection":true,"main_integrated":true,"visual_test":false,"real_mouse_test":false}));game.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
