extends SceneTree
const Controller=preload("res://scripts/game_controller.gd")
func _initialize() -> void:
	var game=Controller.new();game.autosave_enabled=false;game.model.new_game("visibility");var checks:=0;var failed: Array=[]
	for lost in [0,1]:
		game.model.state.phase="nightEvent";game.model.state.rice=6-lost;game.model.state.pendingNightEvent=null;game.model.state.nightCycle={"readingRevision":"R3","status":"awaiting_event","readingEvent":{"type":"mouse"},"mouseOutcome":{"lost":lost}}
		var before=var_to_bytes(game.model.state);var rng=game.model.rng.state;checks+=3
		if not game.rice_count_pending() or game.public_resource_number("rice")!=6 or game.public_rice_hud()!="6 待清点":failed.append("masked:"+str(lost))
		if var_to_bytes(game.model.state)!=before or game.model.rng.state!=rng:failed.append("readonly:"+str(lost))
		game.model.state.phase="morning";checks+=1
		if game.rice_count_pending() or game.public_resource_number("rice")!=6-lost:failed.append("morning:"+str(lost))
		game.model.state.phase="nightEvent";game.model.state.pendingNightEvent={"type":"mouse"};checks+=1
		if game.rice_count_pending():failed.append("unresolved:"+str(lost))
	game.free();print(JSON.stringify({"checks":checks,"failed":failed,"main_integrated":true,"visual_test":false}));quit(0 if failed.is_empty() else 1)
