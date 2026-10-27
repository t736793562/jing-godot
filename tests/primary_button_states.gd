extends SceneTree
const Controller=preload("res://scripts/game_controller.gd")
var failed: Array=[]
var checks:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failed.append(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game=Controller.new();game.autosave_enabled=false;root.add_child(game);game.size=Vector2(1920,1080);await process_frame
	game.model.new_game("button-style");game.model.dispatch("tutorialSkip");game.model.start_opening();game.model.choose_opening(0);game.model.settle_opening_arrival();game.model.state.phase="night";game.model.set_night_option("meal",false);game.model.set_night_option("fire",0);game.model.confirm_early_night()
	game.screen="nightEvent";game.render_screen();await process_frame
	var before:=var_to_bytes(game.model.state);var button: Button=game.controls.night_read_next
	check(button.has_meta("primary_binding"),"approved primary asset bound")
	if button.has_meta("primary_binding"):
		var binding: Dictionary=button.get_meta("primary_binding")
		check(binding.last=="normal","normal")
		for row in [["mouse_entered","hover"],["focus_entered","focus"],["button_down","pressed"],["button_up","focus"],["focus_exited","hover"],["mouse_exited","normal"]]:
			button.emit_signal(row[0]);await process_frame
			check(binding.last==row[1],row[0]+":state")
			check(binding.operation.path==game.primary_button_states[binding.normal][row[1]].path,row[0]+":approved asset")
		button.disabled=true;await process_frame;check(binding.last=="disabled","disabled visual")
		button.disabled=false;await process_frame;check(binding.last=="normal","reenabled")
	var captions=game.holder.get_children().filter(func(node):return node is Label and node.text=="选择应对")
	check(captions.size()==1 and captions[0].get_theme_color("font_color")==Color("fff2d8"),"approved light button caption")
	check(var_to_bytes(game.model.state)==before,"visual states do not alter gameplay")
	game.render_screen();await process_frame;check(game.load_errors.is_empty(),"no resource failures on rebuild")
	print(JSON.stringify({"checks":checks,"failed":failed,"visual_acceptance":"NOT_RUN","scope":"signal-to-approved-asset bindings and caption color"}));game.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
