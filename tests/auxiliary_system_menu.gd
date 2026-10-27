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
	check(game.controls.has(id),"exists:"+id)
	if game.controls.has(id):
		check(not game.controls[id].disabled,"enabled:"+id)
		if not game.controls[id].disabled:game.controls[id].pressed.emit()
	await process_frame;await process_frame
func run() -> void:
	game=Controller.new();game.autosave_enabled=false;root.add_child(game);game.size=Vector2(1920,1080);await process_frame
	var loaded=game.save_store.load_from("user://chapter-eight-promoted-disk-20261026/controlled-rope-decline.json",game.model)
	check(loaded.ok,"load-parent:"+game.save_store.error)
	if not loaded.ok:print(JSON.stringify({"failed":failed}));quit(1);return
	game.restore_continuation(game.save_store.decoded_proof);game.screen="morning";game.render_screen();await process_frame
	var before=var_to_bytes(game.model.state);var proof=var_to_bytes(game.continuation.proof());var rng=game.model.rng.state
	await press("toolbar_system_menu");check(game.screen=="systemMenu","open-menu")
	for id in ["system_disk","system_help","system_feedback"]:check(game.controls.has(id) and not game.controls[id].disabled,"wired-in-top:"+id)
	await press("system_close");check(game.screen=="morning","close-menu")
	await press("toolbar_system_menu");await press("system_resume");check(game.screen=="morning","resume-original")
	await press("toolbar_system_menu");await press("system_reading");check(game.screen=="settings","reading-entry")
	await press("reading_back");check(game.screen=="systemMenu","reading-return")
	await press("system_save");check(game.screen=="save","save-entry")
	await press("save_back");check(game.screen=="systemMenu","save-return")
	await press("system_main_menu");check(game.screen=="confirmMainMenu","confirmation")
	check(game.controls.system_confirm_main.position==Vector2(594,677) and game.controls.system_confirm_main.size==Vector2(490,60),"approved-confirm-hitbox")
	await press("system_cancel_main");check(game.screen=="systemMenu","cancel-main")
	await press("system_main_menu");await press("system_confirm_main");check(game.screen=="menu","main-menu")
	await press("menu_live_resume");check(game.screen=="morning","live-resume-not-disk")
	check(var_to_bytes(game.model.state)==before and var_to_bytes(game.continuation.proof())==proof and game.model.rng.state==rng,"all-navigation-immutable")
	await press("toolbar_system_menu");var key:=InputEventKey.new();key.keycode=KEY_ESCAPE;key.pressed=true;game._unhandled_key_input(key);await process_frame
	check(game.screen=="morning","escape-restores")
	check(game.load_errors.is_empty(),"resource-errors:"+str(game.load_errors))
	print(JSON.stringify({"checks":checks,"failed":failed,"main_integrated":true,"visual_test":false,"real_mouse_test":false,"pending_screens":["disk_UI24","help_UI21","feedback_UI26","records_UI27_UI28"]}));game.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
