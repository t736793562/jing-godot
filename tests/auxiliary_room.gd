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
	var loaded=game.save_store.load_from("user://chapter-eight-promoted-disk-20261026/controlled-rope-decline.json",game.model);check(loaded.ok,"load-parent")
	if not loaded.ok:print(JSON.stringify({"failed":failed}));quit(1);return
	game.restore_continuation(game.save_store.decoded_proof);game.screen="morning";game.render_screen();await process_frame
	var before=var_to_bytes(game.model.state);var rng=game.model.rng.state;var proof=var_to_bytes(game.continuation.proof())
	await press("toolbar_record_menu");await press("book_room");check(game.screen=="room" and game.room_return_screen=="morning","room-entry")
	await press("room_family");check(game.screen=="family","room-family");await press("family_close");check(game.screen=="room","family-close-room")
	await press("room_family");await press("family_back");check(game.screen=="recordMenu" and game.book_return_screen=="room","family-footer-book");await press("book_resume");check(game.screen=="room","book-back-room")
	await press("toolbar_system_menu");await press("system_resume");check(game.screen=="room","menu-back-room")
	await press("room_current_record");check(game.screen=="morning","room-current-record")
	check(var_to_bytes(game.model.state)==before and game.model.rng.state==rng and var_to_bytes(game.continuation.proof())==proof,"navigation-readonly")
	var base: Dictionary=game.model.state.duplicate(true)
	for phase in ["morning","focusEvent","focusResult","focusReturn","night","nightEvent"]:
		game.model.state=base.duplicate(true);game.model.state.phase=phase;game.model.state.focus.day=game.model.state.day;game.model.state.focus.plan={"rows":{"母亲":{"outside":true},"罗瑾":{"outside":false},"安仁叔叔":{"outside":false},"外祖父":{"outside":false}}}
		game.model.state.people["母亲"].alive=true;game.model.state.people["母亲"].away=false;game.model.state.people["母亲"].permanentLost=false;game.model.state.people["母亲"].detainedUntil=null
		game.model.state.shelterItems={"oilcloth":true,"mat":true,"bedding":true};game.model.state.tools.canteen=true;game.model.state.water=3;game.model.state.wood=3;game.model.state.moisture=2
		game.model.state.nightCycle={"readingRevision":"R3","status":"awaiting_event","plan":{"fire":1},"readingEvent":{"type":"mouse"},"mouseOutcome":{"lost":1}};game.model.state.pendingNightEvent=null;game.model.state.rice=0
		var snapshot=var_to_bytes(game.model.state);var p: Dictionary=game.room_projection();check(p.people["母亲"].visible==(phase not in ["focusEvent","focusResult"]),"ordinary-day-out:"+phase);check(p.fire==(phase=="nightEvent"),"committed-fire:"+phase);check(p.rice==(1 if phase=="nightEvent" else 0),"masked-stock:"+phase);check(p.oilcloth and p.mat and p.bedding and p.kettle and p.wet,"material-flags:"+phase)
		game.screen="room";game.render_screen();await process_frame;check(var_to_bytes(game.model.state)==snapshot,"room-render-readonly:"+phase)
		if phase=="nightEvent":check(game.current.operations.any(func(o):return o.get("id")=="room_food"),"unannounced-last-rice-still-present")
		if phase=="focusEvent":
			game.screen="systemMenu";game.render_screen();await process_frame
			for child in game.holder.get_children():
				if child.get_script()!=game.Layer:continue
				for op in child.current.get("operations",[]):
					if op.get("id")=="full_mother":check(not child.visible,"day-out-hidden-in-menu")
	game.model.state=base.duplicate(true);game.model.state.people["母亲"].away=true;game.screen="family";game.render_screen();await process_frame
	var found:=false
	for child in game.holder.get_children():
		if child.get_script()!=game.Layer:continue
		for op in child.current.get("operations",[]):
			if op.get("id")=="portrait_mother":found=true;check(is_equal_approx(child.modulate.a,0.45),"absent-portrait-opacity");check(child.material!=null and child.material.get_shader_parameter("fade_bottom_px")==20,"portrait-fade-preserved")
	check(found,"portrait-found");game.model.state=base;game.model.rng.state=rng;check(game.load_errors.is_empty(),"resources:"+str(game.load_errors))
	print(JSON.stringify({"checks":checks,"failed":failed,"controlled_projection":true,"main_integrated":true,"visual_test":false,"real_mouse_test":false,"raw_assets_modified":false}));game.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
