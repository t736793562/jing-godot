extends SceneTree
const Store=preload("res://scripts/native_save.gd")
const Model=preload("res://scripts/game_model.gd")
class FaultStore extends "res://scripts/native_save.gd":
	var fault: String=""
	func write_text(path: String,text: String) -> bool:
		if fault=="temp_write" and path.ends_with(".json.tmp"):return false
		if fault=="backup_write" and path.ends_with(".bak.tmp"):return false
		if fault=="temp_corrupt" and path.ends_with(".json.tmp"):return super.write_text(path,"broken")
		return super.write_text(path,text)
	func replace_file(from: String,to: String) -> Error:
		if fault=="backup_rename" and to.ends_with(".bak"):return ERR_CANT_CREATE
		if fault=="primary_rename" and to.ends_with(".json"):return ERR_CANT_CREATE
		return super.replace_file(from,to)
func _initialize() -> void:
	var failed: Array=[];var checks:=0;var model=Model.new();model.new_game("fault-tests")
	var primary: Dictionary=model.state.duplicate(true);var replacement: Dictionary=primary.duplicate(true);replacement.memory.generation=2
	for fault in ["temp_write","backup_write","temp_corrupt","backup_rename","primary_rename"]:
		var path: String="user://save-fault-"+str(OS.get_process_id())+"-"+fault+".json"
		var normal=Store.new();normal.save_to(path,primary);normal.save_to(path,primary)
		var original:=FileAccess.get_file_as_bytes(path);var original_backup:=FileAccess.get_file_as_bytes(path+".bak")
		var broken=FaultStore.new();broken.fault=fault
		checks+=1
		if broken.save_to(path,replacement):failed.append(fault+":unexpected_success")
		checks+=1
		if FileAccess.get_file_as_bytes(path)!=original:failed.append(fault+":primary_changed")
		checks+=1
		if FileAccess.get_file_as_bytes(path+".bak")!=original_backup:failed.append(fault+":backup_changed")
		checks+=1
		if normal.read_valid(path).is_empty() or normal.read_valid(path+".bak").is_empty():failed.append(fault+":not_readable")
		for suffix in ["",".bak",".tmp",".bak.tmp"]:
			if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
	var path: String="user://save-lock-"+str(OS.get_process_id())+".json"
	var store=Store.new();store.save_to(path,primary);var fingerprint: String=store.file_fingerprint(path)
	checks+=1
	if store.save_to(path,replacement,"stale") or store.error!="WRITE_CONFLICT" or store.file_fingerprint(path)!=fingerprint:failed.append("stale fingerprint")
	DirAccess.make_dir_absolute(path+".lock")
	checks+=1
	if store.save_to(path,replacement) or store.error!="WRITE_LOCKED" or store.file_fingerprint(path)!=fingerprint:failed.append("live lock bypassed")
	DirAccess.remove_absolute(path+".lock")
	checks+=1
	if not store.save_to(path,replacement,fingerprint) or not store.last_write_committed:failed.append("expected generation commit")
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
	print(JSON.stringify({"checks":checks,"failed":failed,"faults":5,"real_disk":true}));quit(0 if failed.is_empty() else 1)
