extends SceneTree
const RNG=preload("res://scripts/native_rng.gd")
func _initialize() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string("res://data/rng_reference.json"))
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/weather_catalog.json"))
	var failures: Array=[]
	var assertions:=0
	for case in reference["cases"]:
		var rng=RNG.new()
		rng.seed_with(case["seed"])
		assertions+=1
		if rng.state!=int(case["hash"]):failures.append(case["seed"]+":hash")
		for i in range(case["samples"].size()):
			assertions+=1
			if rng.next_float()!=float(case["samples"][i]):failures.append(case["seed"]+":random:"+str(i))
		assertions+=1
		if rng.state!=int(case["final_rng"]):failures.append(case["seed"]+":final_rng")
		var plan=RNG.weather_plan(case["seed"],catalog)
		for i in range(50):
			assertions+=1
			if plan[i]["id"]!=case["weather"][i]:failures.append(case["seed"]+":weather:"+str(i))
	print(JSON.stringify({"assertions":assertions,"failures":failures,"full_game_test":false}))
	quit(0 if failures.is_empty() else 1)
