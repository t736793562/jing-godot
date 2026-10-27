extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize() -> void:
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/custody_record_reference.json"));var model=Model.new();var failed: Array=[];var checks:=0
	for case in data.tests:
		var before: PackedByteArray=var_to_bytes(case.record)
		checks+=3
		if model.custody_night_record_valid(case.record)!=case.valid:failed.append(case.id+":valid")
		if model.custody_night_held(case.record)!=case.held:failed.append(case.id+":held")
		if var_to_bytes(case.record)!=before:failed.append(case.id+":mutation")
	print(JSON.stringify({"checks":checks,"failed":failed,"read_only_projection":true,"full_game":false}));quit(0 if failed.is_empty() else 1)
