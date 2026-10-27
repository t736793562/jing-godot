extends SceneTree
const Controller=preload("res://../tests/save_ux_test_controller.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var dir: String="user://backup-notice-probe-"+str(Time.get_ticks_usec());DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir));var game=Controller.new();game.save_path=dir+"/primary.json";game.settings_path=dir+"/settings.cfg";var m=game.Model.new();m.new_game("backup-warning");var writer=game.SaveStore.new()
	if not writer.save_to(game.save_path,m.state) or not writer.save_to(game.save_path,m.state):print(JSON.stringify({"passed":false,"reason":"setup"}));quit(1);return
	var f=FileAccess.open(game.save_path,FileAccess.WRITE);f.store_string("controlled corrupt primary");f.close();var hash:=FileAccess.get_sha256(game.save_path);root.add_child(game);await process_frame;await process_frame;game.continue_saved();game.render_screen();await process_frame;await process_frame
	var visible: bool=game.screen=="autoSaveFailure" and game.controls.has("save_ux_primary");var passed: bool=visible and game.autosave_paused and FileAccess.get_sha256(game.save_path)==hash
	print(JSON.stringify({"passed":passed,"visible_warning":visible,"screen":game.screen,"autosave_paused":game.autosave_paused,"primary_preserved":FileAccess.get_sha256(game.save_path)==hash,"real_disk":true,"visual_test":false,"main_integrated":false}));game.queue_free();await process_frame;quit(0 if passed else 1)
