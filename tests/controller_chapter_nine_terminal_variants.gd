extends SceneTree
const Controller=preload("res://scripts/game_controller.gd")
var failed: Array=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failed.append(label)
func run() -> void:
	var game=Controller.new();game.autosave_enabled=false;root.add_child(game);game.size=Vector2(1920,1080);await process_frame
	var file=FileAccess.open("res://../evidence/staged_chapter_nine_terminal_view.jsonl",FileAccess.READ);var source: Dictionary={}
	while file.get_position()<file.get_length():
		var line=file.get_line()
		if line.is_empty():continue
		var row=JSON.parse_string(line)
		if not row.initial.people["罗瑾"].alive:source=row.initial;break
	check(not source.is_empty(),"source-failure-fixture")
	if not source.is_empty():
		game.model.state=source.duplicate(true);var before=var_to_bytes(game.model.state);game.screen="end";game.render_screen();await process_frame
		check(game.load_errors.is_empty(),"failure-resources");check(var_to_bytes(game.model.state)==before,"failure-readonly")
		check(not game.controls.has("ending_records"),"failure-not-normal")
	# Controlled presentation boundary, not a naturally reached no-photo playthrough.
	var lines=FileAccess.get_file_as_string("res://../evidence/staged_chapter_nine_terminal_view.jsonl").split("\n",false)
	game.model.state=JSON.parse_string(lines[0]).initial.duplicate(true);game.model.state.photo.prints=0;game.model.state.photo.transferCount=0;game.model.state.photo.album.selected=0
	var before=var_to_bytes(game.model.state);game.screen="end";game.render_screen();await process_frame
	check(game.controls.has("ending_restart"),"no-photo-restart");check(not game.controls.has("ending_records"),"no-photo-distinct-layout")
	if game.controls.has("ending_restart"):game.controls.ending_restart.pressed.emit()
	await process_frame;await process_frame
	check(game.screen=="menu","no-photo-back-menu");check(var_to_bytes(game.model.state)==before,"no-photo-readonly");check(game.load_errors.is_empty(),"no-photo-resources")
	print(JSON.stringify({"checks":checks,"failed":failed,"controlled_no_photo_fixture":true,"visual_test":false,"real_mouse_test":false,"main_integrated":true}));game.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
