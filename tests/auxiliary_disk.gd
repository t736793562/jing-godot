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
	var directory: String="user://ui-disk-tests-"+str(Time.get_ticks_usec());DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory));game.save_path=directory+"/slot.json"
	game.begin_game("ui-disk-A");game.open_system_menu();game.render_screen();await process_frame
	var a=var_to_bytes(game.model.state);var rng=game.model.rng.state
	await press("system_disk");check(game.screen=="disk","disk-entry");check(not game.disk_info.ok,"missing-file-not-success");check(game.controls.disk_preview_restore.disabled,"missing-file-no-restore")
	await press("disk_preview_write");check(game.screen=="diskConfirm","write-preview");check(not FileAccess.file_exists(game.save_path),"preview-no-file")
	await press("disk_cancel");check(var_to_bytes(game.model.state)==a and not FileAccess.file_exists(game.save_path),"cancel-no-write")
	await press("disk_preview_write");await press("disk_confirm");check(game.screen=="disk" and game.disk_info.ok,"write-verified");check(var_to_bytes(game.disk_info.state)==a,"disk-state-exact")
	var fingerprint:=FileAccess.get_sha256(game.save_path)
	await press("disk_inspect");check(var_to_bytes(game.model.state)==a and game.model.rng.state==rng and FileAccess.get_sha256(game.save_path)==fingerprint,"inspect-readonly")
	await press("disk_preview_write");game.model.state.error="changed while previewing";await press("disk_confirm");check(game.screen=="disk" and "当前进度已变化" in game.disk_notice and FileAccess.get_sha256(game.save_path)==fingerprint,"stale-live-rejected")
	game.model.state=bytes_to_var(a);game.model.rng.state=int(game.model.state.rngState)
	await press("disk_preview_write");var other=game.Model.new();other.new_game("ui-disk-external");var writer=game.SaveStore.new();check(writer.save_to(game.save_path,other.state),"test-external-save")
	var external:=FileAccess.get_sha256(game.save_path);await press("disk_confirm");check(game.screen=="disk" and "磁盘文件已变化" in game.disk_notice and FileAccess.get_sha256(game.save_path)==external and var_to_bytes(game.model.state)==a,"stale-file-rejected")
	await press("disk_inspect");var target=var_to_bytes(game.disk_info.state);await press("disk_preview_restore");await press("disk_cancel");check(var_to_bytes(game.model.state)==a,"cancel-restore-readonly")
	await press("disk_preview_restore");await press("disk_confirm");check(var_to_bytes(game.model.state)==target and game.screen==game.model.state.phase,"restore-confirmed")
	var backup_probe=game.Model.new();var backup_reader=game.SaveStore.new();var backup_result=backup_reader.load_from(game.save_path+".before-restore",backup_probe);check(backup_result.ok and var_to_bytes(backup_probe.state)==a,"unsaved-before-restore-backup")
	# Corrupt only this test's primary; retain its verified backup as a separate source.
	var file=FileAccess.open(game.save_path,FileAccess.WRITE);file.store_string("invalid test file");file.close()
	game.open_system_menu();game.render_screen();await process_frame;await press("system_disk");check(game.disk_info.ok and game.disk_info.source=="backup","backup-fallback-disclosed")
	check(var_to_bytes(game.model.state)==target,"fallback-not-auto-restore")
	await press("disk_back");check(game.screen=="systemMenu","disk-back-menu")
	check(game.load_errors.is_empty(),"resources:"+str(game.load_errors))
	print(JSON.stringify({"checks":checks,"failed":failed,"isolated_directory":directory,"main_integrated":true,"visual_test":false,"real_mouse_test":false}));game.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
