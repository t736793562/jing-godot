extends SceneTree
const Controller=preload("res://scripts/game_controller.gd")
var game
var failed: Array=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failed.append(label)
func run() -> void:
	game=Controller.new();game.autosave_enabled=false;root.add_child(game);game.size=Vector2(1920,1080);await process_frame
	var stream=FileAccess.open("res://../evidence/staged_animal_encounter_reference.jsonl",FileAccess.READ);var cases:=0
	while stream.get_position()<stream.get_length():
		var line=stream.get_line()
		if line.is_empty():continue
		var case=JSON.parse_string(line)
		if case.encounter==null:continue
		game.model.state=case.initial.duplicate(true);game.screen="animalEncounter";game.render_screen();await process_frame;cases+=1
		var before: PackedByteArray=var_to_bytes(game.model.state)
		check(game.controls.animal_accept.disabled==(game.model.state.animals.pet!=null),case.id+":occupancy")
		check(not game.controls.animal_accept.get_rect().intersects(game.controls.animal_decline.get_rect()),case.id+":separate-hitboxes")
		check(game.controls.night_confirm.disabled,case.id+":underlay-disabled")
		game.controls.animal_back.pressed.emit();await process_frame;await process_frame
		check(var_to_bytes(game.model.state)==before,case.id+":back-unchanged")
		if cases>=12:break
	# Constructed rendering edge: all four robbery responses, not a reached-play claim.
	game.model.add_animal("poultry","goose");game.model.add_animal("pet","cat")
	game.model.state.pendingNightEvent={"type":"robbery","title":"Test rendering edge"};game.screen="nightEvent";game.night_stage="choices";game.night_choice_page=0;game.render_screen();await process_frame
	check(game.controls.has("night_choices_next"),"four-response-pagination")
	var before: PackedByteArray=var_to_bytes(game.model.state)
	game.controls.night_choices_next.pressed.emit();await process_frame;await process_frame
	check(game.controls.has("night_choice_resist"),"fourth-response-reachable")
	check(game.controls.night_choice_resist.get_rect().end.y<790,"fourth-response-no-footer-overlap")
	check(var_to_bytes(game.model.state)==before,"pagination-state-unchanged")
	check(game.load_errors.is_empty(),"resources")
	print(JSON.stringify({"cases":cases,"checks":checks,"failed":failed,"visual_test":false,"real_mouse_test":false,"constructed_rendering_cases":true}));game.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
