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
	check(game.controls.has(id),"control:"+id)
	if game.controls.has(id):
		check(not game.controls[id].disabled,"enabled:"+id)
		game.controls[id].pressed.emit()
	await process_frame;await process_frame
func run() -> void:
	var path: String="user://reading-test-"+str(OS.get_process_id())+".cfg"
	game=Controller.new();game.autosave_enabled=false;game.settings_path=path;root.add_child(game);game.size=Vector2(1920,1080);await process_frame
	check(game.reading_font_size==19 and not game.focused_reading,"source defaults")
	await press("menu_3");check(game.screen=="settings" and game.model.state.is_empty(),"menu settings does not start game")
	await press("reading_back");check(game.screen=="menu","back to original menu")
	game.begin_game("settings-state-proof");game.render_screen();await process_frame
	var frozen: PackedByteArray=var_to_bytes(game.model.state);var rng_state: int=game.model.rng.state
	game.open_reading_settings();game.render_screen();await process_frame;await process_frame
	for size in [18,19,22,25,29]:
		await press("reading_font_"+str(size))
		check(game.reading_font_size==size,"font preference:"+str(size))
		check(game.current.id=="UI22_selected_"+str(size)+"_toggle_on","approved selected layout:"+str(size))
		check(game.current.operations.any(func(op):return op.get("type")=="text" and op.get("text")=="当下的故事，慢慢读。" and op.size==size),"preview size:"+str(size))
		check(game.settings_focus_layer.current.operations.size()==60,"authored keyboard focus strokes")
		check(var_to_bytes(game.model.state)==frozen and game.model.rng.state==rng_state,"settings do not mutate gameplay:"+str(size))
	await press("reading_focus_toggle")
	check(game.focused_reading and game.current.operations.any(func(op):return op.get("id")=="focus_reading_enabled"),"toggle reflected by approved check image")
	await press("reading_back");check(game.screen=="intro","return to original reading page")
	check(game.holder.get_children().any(func(child):return child is RichTextLabel and child.get_theme_font_size("normal_font_size")==29),"actual narrative font changes")
	check(game.current.operations.any(func(op):return op.get("type")=="image" and op.get("box",[]).size()==4 and op.box[0]==0 and op.box[1]==0 and is_equal_approx(op.get("opacity",1),0.32)),"focus mode dims background only")
	check(var_to_bytes(game.model.state)==frozen and game.model.rng.state==rng_state,"display-only changes")
	var another=Controller.new();another.autosave_enabled=false;another.settings_path=path;root.add_child(another);await process_frame
	check(another.reading_font_size==29 and another.focused_reading,"preferences reloaded from disk")
	check(another.model.state.is_empty(),"preference reload does not load/start gameplay")
	another.queue_free();await process_frame
	var config:=ConfigFile.new();config.set_value("reading","font",99);config.set_value("reading","focused","yes");config.save(path)
	another=Controller.new();another.autosave_enabled=false;another.settings_path=path;root.add_child(another);await process_frame
	check(another.reading_font_size==19 and not another.focused_reading,"invalid preferences use safe defaults")
	another.queue_free();game.queue_free();await process_frame
	DirAccess.remove_absolute(path)
	print(JSON.stringify({"checks":checks,"failed":failed,"visual_test":false,"gameplay_mutated":false}));quit(0 if failed.is_empty() else 1)
