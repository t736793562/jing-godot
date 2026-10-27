extends SceneTree
const Controller=preload("res://../tests/save_ux_test_controller.gd")
var game
var checks:=0
var failed: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failed.append(label)
func frames() -> void:
	await process_frame;await process_frame;await process_frame;await process_frame
func press(id: String) -> void:
	check(game.controls.has(id),"exists:"+id)
	if game.controls.has(id) and not game.controls[id].disabled:game.controls[id].pressed.emit()
	await frames()
func run() -> void:
	var directory: String="user://save-ux-tests-"+str(Time.get_ticks_usec());DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory));game=Controller.new();game.save_path=directory+"/primary.json";game.settings_path=directory+"/settings.cfg";root.add_child(game);await frames()
	check(not FileAccess.file_exists(game.save_path),"no-startup-write");game.begin_game("save-ux-a");game.render_screen();await frames();check(FileAccess.file_exists(game.save_path) and game.autosave_writes==1,"first-autosave")
	var reader=game.SaveStore.new();var loaded: Dictionary=reader.read_valid(game.save_path);check(var_to_bytes(loaded)==var_to_bytes(game.model.state),"autosave-typed-match")
	var count: int=game.autosave_writes;game.screen="menu";game.render_screen();await frames();check(game.autosave_writes==count,"navigation-no-write");game.screen=game.model.state.phase
	game.action("introNext");game.render_screen();game.action("tutorialNext");game.render_screen();await frames();check(game.autosave_writes==count+1 and reader.read_valid(game.save_path).tutorialPage==1,"coalesced-latest-action")
	var other=game.Model.new();other.new_game("foreign-write");var writer=game.SaveStore.new();check(writer.save_to(game.save_path,other.state),"controlled-external-write");var foreign_sha:=FileAccess.get_sha256(game.save_path)
	game.action("tutorialNext");game.render_screen();var live=var_to_bytes(game.model.state);await frames();check(game.autosave_paused and game.screen=="autoSaveFailure","conflict-disclosed");check(FileAccess.get_sha256(game.save_path)==foreign_sha,"conflict-no-clobber");check(live==var_to_bytes(game.model.state),"conflict-no-state-loss")
	await press("save_ux_cancel");check(game.screen==game.model.state.phase and game.autosave_paused,"continue-explicitly-unsaved")
	game.request_window_close();await frames();check(game.screen=="confirmQuit" and not game.quit_observed,"dirty-close-blocked");await press("save_ux_cancel");check(not game.quit_observed,"cancel-close-stays-open")
	game.request_window_close();await frames();await press("save_ux_primary");check(game.quit_observed,"only-confirmed-discard-quits");game.quit_observed=false;game.screen=game.model.state.phase
	check(game.save_current_to(game.save_path) and not game.autosave_paused and game.state_stamp()==game.autosave_saved,"explicit-manual-save-rearms");game.request_window_close();check(game.quit_observed,"saved-close-quits");game.quit_observed=false
	var old_sha:=FileAccess.get_sha256(game.save_path);var old_state=var_to_bytes(game.model.state);game.screen="menu";game.begin_game("save-ux-b");game.render_screen();await frames();check(game.screen=="confirmNewGame" and old_state==var_to_bytes(game.model.state) and old_sha==FileAccess.get_sha256(game.save_path),"newgame-awaits-confirmation");await press("save_ux_cancel");check(game.screen=="menu" and old_state==var_to_bytes(game.model.state),"newgame-cancel-preserves")
	game.begin_game("save-ux-b");game.render_screen();await frames();await press("save_ux_primary");check(game.model.state.seed=="save-ux-b" and game.screen=="intro","newgame-confirmed");check(FileAccess.file_exists(game.new_game_backup) and FileAccess.get_sha256(game.new_game_backup)==old_sha,"old-primary-byte-backup");check(reader.read_valid(game.save_path).seed=="save-ux-b","newgame-autosaved-after-backup")
	check(DirAccess.make_dir_absolute(game.save_path+".lock")==OK,"controlled-lock-created");old_sha=FileAccess.get_sha256(game.save_path);game.action("introNext");game.render_screen();await frames();check(game.autosave_paused and game.screen=="autoSaveFailure" and FileAccess.get_sha256(game.save_path)==old_sha,"lock-failure-preserves-primary");check(DirAccess.remove_absolute(game.save_path+".lock")==OK,"remove-own-test-lock");await press("save_ux_cancel");check(game.save_current_to(game.save_path),"manual-recovery-after-lock")
	var file=FileAccess.open(game.save_path,FileAccess.WRITE);file.store_string("controlled corrupt primary");file.close();var corrupt_sha:=FileAccess.get_sha256(game.save_path);game.continue_saved();game.render_screen();await frames();check(game.autosave_paused and FileAccess.get_sha256(game.save_path)==corrupt_sha and game.save_notice.contains("备用"),"backup-load-not-silent-repair");check(game.save_current_to(game.save_path) and not game.autosave_paused,"explicit-backup-repair")
	var native_reader=game.SaveStore.new();var model=game.Model.new();check(native_reader.load_from("user://expedition-native-disk-20261027-v01/decline-mother.json",model).ok,"v2-source-load");game.model=model;game.continuation.restore(native_reader.decoded_proof);game.screen=model.state.phase;game.render_screen();await frames();loaded=reader.read_valid(game.save_path);check(var_to_bytes(loaded)==var_to_bytes(model.state) and not reader.decoded_proof.is_empty(),"v2-proof-autosave")
	check(game.native_open_recall(model.state.expedition.history[-1].id),"journal-recall-open");game.render_screen();await frames();loaded=reader.read_valid(game.save_path);check(loaded.phase=="expeditionRecall" and loaded.expedition.recallReturnPhase=="morning","recall-phase-autosaved")
	check(game.native_close_recall(),"journal-recall-close");game.render_screen();await frames();loaded=reader.read_valid(game.save_path);check(loaded.phase=="morning" and loaded.expedition.history[-1].recall.read,"read-flag-autosaved")
	game.request_window_close();check(game.quit_observed,"v2-clean-close");check(game.load_errors.is_empty(),"resources:"+str(game.load_errors));print(JSON.stringify({"checks":checks,"failed":failed,"real_disk":true,"main_integrated":false,"visual_test":false,"real_window_close":false,"scope":"Real isolated writes/reads and control-signal confirmations; close callback tested with quit intercepted, not OS GUI."}));game.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
