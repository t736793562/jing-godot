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
	await press("menu_4");check(game.screen=="help","main-menu-help")
	var before=var_to_bytes(game.model.state);var rng=game.model.rng.state
	for i in range(11):
		await press("help_topic_"+str(i));check(game.help_page==i,"topic:"+str(i));check(game.controls.help_previous.disabled==(i==0),"previous-boundary:"+str(i));check(game.controls.help_next.disabled==(i==10),"next-boundary:"+str(i))
		check(var_to_bytes(game.model.state)==before and game.model.rng.state==rng,"readonly:"+str(i))
		if i>0:check(game.holder.get_node_or_null("help_prose")!=null,"native-prose:"+str(i))
	check(game.help_data.guides.size()==11,"eleven-topics");check("自动保存" in game.help_data.guides[10][1],"native-save-wording")
	await press("help_previous");check(game.help_page==9,"previous-action");await press("help_next");check(game.help_page==10,"next-action")
	await press("help_back");check(game.screen=="menu","back-main")
	var loaded=game.save_store.load_from("user://chapter-eight-promoted-disk-20261026/controlled-rope-decline.json",game.model);check(loaded.ok,"load-parent")
	if loaded.ok:
		game.restore_continuation(game.save_store.decoded_proof);game.screen="morning";game.render_screen();await process_frame
		before=var_to_bytes(game.model.state);rng=game.model.rng.state;var proof=var_to_bytes(game.continuation.proof())
		await press("toolbar_system_menu");await press("system_help");check(game.screen=="help","system-help")
		await press("help_topic_0");await press("help_back");check(game.screen=="systemMenu","back-system")
		await press("system_resume");check(game.screen=="morning","resume-morning")
		check(var_to_bytes(game.model.state)==before and game.model.rng.state==rng and var_to_bytes(game.continuation.proof())==proof,"loaded-state-immutable")
	check(game.load_errors.is_empty(),"resources:"+str(game.load_errors))
	print(JSON.stringify({"checks":checks,"failed":failed,"main_integrated":true,"visual_test":false,"real_mouse_test":false}));game.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
