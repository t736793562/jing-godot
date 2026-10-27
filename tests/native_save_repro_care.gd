extends SceneTree
const Store=preload("res://scripts/native_save.gd")
func _initialize() -> void:
	# Internal generated failure checkpoint only; native save loading never calls bytes_to_var.
	print("starting saved fixture decode")
	var state=bytes_to_var(FileAccess.get_file_as_bytes("res://../evidence/native_save_failed_state.bin"))
	print("decoded state ",typeof(state))
	var store=Store.new();var text: String=store.encode(state)
	print("encoded ",text.length()," ",store.error)
	var restored: Dictionary=store.decode(text) if text!="" else {}
	print("restored state ",restored.size())
	var passed: bool=not text.is_empty() and var_to_bytes(restored)==var_to_bytes(state)
	print(JSON.stringify({"passed":passed,"reason":store.error,"case":"fourth-day care save, integer priorCount versus JSON float","visual_test":false}));quit(0 if passed else 1)
