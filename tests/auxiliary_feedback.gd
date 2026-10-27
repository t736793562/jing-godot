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
	var directory: String="user://ui-feedback-tests-"+str(Time.get_ticks_usec());DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	game=Controller.new();game.autosave_enabled=false;game.feedback_draft_path=directory+"/draft.json";root.add_child(game);game.size=Vector2(1920,1080);await process_frame
	game.begin_game("feedback-state-A");game.open_system_menu();game.render_screen();await process_frame
	var before=var_to_bytes(game.model.state);var rng=game.model.rng.state;var proof=var_to_bytes(game.continuation.proof())
	await press("system_feedback");check(game.screen=="feedback","system-entry")
	for key in ["category","module","duration","overall","clarity","pace","continuePlay"]:
		await press("feedback_field_"+key);check(not game.feedback_popup.is_empty(),"popup:"+key);check(game.controls.feedback_back.disabled,"popup-blocks-background:"+key)
		await press("feedback_option_1");check(game.feedback_draft[key]==game.feedback_options(key)[1][0],"selection:"+key)
	await press("feedback_issue_0");await press("feedback_issue_9");check(game.feedback_draft.issues==["不知道下一步","存档问题"],"multi-select")
	var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true;game._unhandled_input(wheel);await process_frame;check(game.feedback_view=="comment","wheel-lower")
	wheel.button_index=MOUSE_BUTTON_WHEEL_UP;game._unhandled_input(wheel);await process_frame;check(game.feedback_view=="upper","wheel-upper")
	await press("feedback_lower");check(game.controls.feedback_submit.disabled,"no-online-submit")
	game.feedback_editor.text="测试反馈，不含个人信息。";game.feedback_editor.text_changed.emit();check(game.feedback_draft.comment=="测试反馈，不含个人信息。","text-sync")
	game.feedback_editor.text="字".repeat(2001);game.feedback_editor.text_changed.emit();check(game.feedback_draft.comment.length()==2000 and game.feedback_editor.text.length()==2000,"limit-2000")
	await press("feedback_context");check(game.feedback_show_context,"context-preview");var ctx: Dictionary=game.feedback_draft.context;check(ctx.keys().size()==5 and not ctx.has("state") and ctx.seed=="feedback-state-A","context-minimal")
	await press("feedback_includeContext");var payload: Dictionary=game.feedback_payload();check(payload.context==null and payload.consent==false,"opt-out-consent-honest")
	check(game.write_feedback_file(directory+"/export.json"),"file-export")
	var exported=JSON.parse_string(FileAccess.get_file_as_string(directory+"/export.json"));check(exported.delivery=="仅导出，未在线提交" and exported.context==null and exported.consent==false and exported.id.length()==36,"offline-export-boundary")
	check(var_to_bytes(game.model.state)==before and game.model.rng.state==rng and var_to_bytes(game.continuation.proof())==proof,"game-immutable-including-export-id")
	await press("feedback_back");check(game.screen=="systemMenu","back-system")
	var reloaded=Controller.new();reloaded.autosave_enabled=false;reloaded.feedback_draft_path=game.feedback_draft_path;reloaded.ensure_feedback_draft();check(reloaded.feedback_draft.comment.length()==2000 and reloaded.feedback_draft.issues==game.feedback_draft.issues and reloaded.feedback_draft.context.seed=="feedback-state-A","draft-reload");reloaded.free()
	game.screen="menu";game.render_screen();await process_frame;await press("menu_5");check(game.screen=="feedback","main-menu-entry");await press("feedback_back");check(game.screen=="menu","back-main")
	check(game.load_errors.is_empty(),"resources:"+str(game.load_errors))
	print(JSON.stringify({"checks":checks,"failed":failed,"isolated_directory":directory,"online_submission_implemented":false,"main_integrated":true,"visual_test":false,"real_mouse_test":false}));game.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
