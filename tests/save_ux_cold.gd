extends SceneTree
const Controller=preload("res://../tests/save_ux_cold_controller.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args=OS.get_cmdline_user_args();var mode: String=args[0];var run_id: String=args[1];var dir: String="user://save-ux-cold-"+run_id;DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir));var game=Controller.new();game.save_path=dir+"/primary.json";game.settings_path=dir+"/settings.cfg";game.test_mode=mode;root.add_child(game);await process_frame;await process_frame
	if mode=="init":
		var reader=game.SaveStore.new();var loaded: Dictionary=reader.load_from("user://expedition-native-disk-20261027-v01/decline-mother.json",game.model)
		if not loaded.ok:print(JSON.stringify({"passed":false,"mode":mode,"error":"source-load"}));quit(1);return
		game.continuation.restore(reader.decoded_proof);game.screen=game.model.state.phase;game.render_screen();await process_frame;await process_frame;await process_frame
	else:
		game.continue_saved()
		if game.model.state.is_empty():print(JSON.stringify({"passed":false,"mode":mode,"error":"cold-load"}));quit(1);return
		if mode=="open" and not game.native_open_recall(game.model.state.expedition.history[-1].id):print(JSON.stringify({"passed":false,"mode":mode,"error":"open"}));quit(1);return
		if mode=="close" and not game.native_close_recall():print(JSON.stringify({"passed":false,"mode":mode,"error":"close"}));quit(1);return
	# Open/close deliberately go directly to the close handler before a render-triggered save.
	game.request_window_close()
	if not game.test_quit_requested:print(JSON.stringify({"passed":false,"mode":mode,"error":"close-not-completed","notice":game.autosave_notice}));quit(1)
