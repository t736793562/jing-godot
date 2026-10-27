extends SceneTree
const Controller=preload("res://../tests/save_ux_test_controller.gd")
const WarningStore=preload("res://../tests/save_ux_commit_warning_store.gd")
var checks:=0
var failed: Array=[]
var game
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failed.append(label)
func frames() -> void:
	await process_frame;await process_frame;await process_frame;await process_frame
func press(id: String) -> void:
	check(game.controls.has(id),"exists:"+id)
	if game.controls.has(id):game.controls[id].pressed.emit()
	await frames()
func run() -> void:
	var directory: String="user://save-ux-edges-"+str(Time.get_ticks_usec());DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory));game=Controller.new();game.save_path=directory+"/primary.json";game.settings_path=directory+"/settings.cfg";root.add_child(game);await frames()
	game.begin_game("pending-close");game.render_screen();check(game.autosave_queued,"write-queued");game.request_window_close();check(game.quit_observed,"pending-close-flushes");await frames();check(game.autosave_writes==1,"pending-deferred-no-double-write")
	game.quit_observed=false;var old=var_to_bytes(game.model.state);game.screen="menu";game.begin_game("should-not-start");game.render_screen();await frames();check(game.screen=="confirmNewGame","newgame-confirmation")
	var external=game.Model.new();external.new_game("external-during-confirmation");var writer=game.SaveStore.new();check(writer.save_to(game.save_path,external.state),"external-change");var sha:=FileAccess.get_sha256(game.save_path);await press("save_ux_primary");check(game.screen=="confirmNewGame" and game.new_game_notice.contains("变化") and old==var_to_bytes(game.model.state) and FileAccess.get_sha256(game.save_path)==sha,"newgame-cas-no-overwrite")
	await press("save_ux_cancel");check(game.save_current_to(game.save_path),"explicit-recovery");game.autosave_enabled=false;game.save_store=WarningStore.new();game.action("introNext");game.request_window_close();await frames();check(not game.quit_observed and game.screen=="confirmQuit","commit-warning-confirmation");check(game.close_message.contains("已写入") and not game.close_message.contains("尚未保存"),"committed-not-misreported-lost")
	var read=game.SaveStore.new();check(var_to_bytes(read.read_valid(game.save_path))==var_to_bytes(game.model.state),"warning-write-really-persisted");await press("save_ux_cancel");game.request_window_close();check(game.quit_observed,"already-persisted-close")
	game.screen="help";game.help_page=10;game.render_screen();await frames();check(game.help_data.guides[10][1].contains("自动保存") and not game.help_data.guides[10][1].contains("本版本使用手动保存"),"help-matches-implementation")
	for phase in ["focus","focusEvent","focusResult","focusReturn","search","expeditionRecall"]:
		var state: Dictionary=game.model.state.duplicate(true);state.phase=phase;check(not game.state_summary(state).contains(phase),"localized-summary:"+phase)
	check(game.load_errors.is_empty(),"resources:"+str(game.load_errors));print(JSON.stringify({"checks":checks,"failed":failed,"real_disk":true,"simulated_cleanup_warning":true,"real_window_close":false,"main_integrated":false,"visual_test":false}));game.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
