extends SceneTree
const Prose=preload("res://scripts/family_prose.gd")
func _initialize() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string("res://data/family_prose_reference.json"))
	var care=JSON.parse_string(FileAccess.get_file_as_string("res://data/family_care_prose.json"))
	var failed: Array=[];var checks:=0
	for case in reference.tests:
		var values={"text":Prose.text(case.scene,case.p.context,case.p.bucket,case.place,care),"summary":Prose.summary(case.p),"closure":Prose.closure(case.p),"diary":Prose.diary(case.p,case.scene)}
		for key in values:
			checks+=1
			if values[key]!=case[key]:
				if failed.is_empty():
					var f=FileAccess.open("res://../evidence/family_prose_first_diff.json",FileAccess.WRITE);f.store_string(JSON.stringify({"id":case.id,"key":key,"actual":values[key],"expected":case[key],"p":case.p}))
				failed.append(case.id+":"+key)
	print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false}));quit(0 if failed.is_empty() else 1)
