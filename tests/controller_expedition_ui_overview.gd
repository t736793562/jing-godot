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
	game=Controller.new();game.autosave_enabled=false;game.settings_path="user://expedition-ui-test-settings.cfg";root.add_child(game);await process_frame;await process_frame
	var parent: String="user://expedition-native-disk-20261027-v01/decline-mother.json";var loaded: Dictionary=game.save_store.load_from(parent,game.model);check(loaded.ok,"real-native-state");game.continuation.restore(game.save_store.decoded_proof);var before=var_to_bytes(game.model.state);var proof=var_to_bytes(game.continuation.proof());var rng=game.model.rng.state
	game.book_return_screen="morning";game.screen="recordMenu";game.render_screen();await process_frame;await press("book_overview");check(game.screen=="overview" and game.current.id==game.OVERVIEW_LAYOUT,"approved-ui19")
	await press("overview_family");check(game.screen=="family","family-route");await press("family_back");check(game.screen=="overview","family-back")
	for row in [["overview_items_tab",0],["overview_animals_tab",1],["overview_travel_tab",2]]:
		await press(row[0]);check(game.screen=="household" and game.household_tab==row[1],"tab:"+row[0]);await press("household_back");check(game.screen=="overview","tab-back:"+row[0])
	await press("overview_disk");check(game.screen=="disk","disk-route");await press("disk_back");check(game.screen=="overview","disk-back")
	check(before==var_to_bytes(game.model.state) and proof==var_to_bytes(game.continuation.proof()) and rng==game.model.rng.state,"all-navigation-readonly")
	var base: Dictionary=game.model.state.duplicate(true);game.model.state.people["母亲"].away=true;game.model.state.people["母亲"].health=1;game.model.state.people["母亲"].spirit=1;var projection=var_to_bytes(game.public_family_projection());game.model.state.people["母亲"].health=9;game.model.state.people["母亲"].spirit=9;check(projection==var_to_bytes(game.public_family_projection()),"absence-hides-health-spirit");game.render_screen();await process_frame
	game.model.state=base.duplicate(true);game.model.state.photo.unlocked=false;game.render_screen();await process_frame;check(game.controls.overview_photo_tab.disabled,"photo-locked");game.model.state=base;game.render_screen();await process_frame
	await press("overview_back");check(game.screen=="recordMenu","overview-return");check(game.load_errors.is_empty(),"resources:"+str(game.load_errors));print(JSON.stringify({"checks":checks,"failed":failed,"main_integrated":true,"visual_test":false,"real_mouse_test":false,"controlled_absence_probe":true}));game.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
