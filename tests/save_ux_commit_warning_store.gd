extends "res://scripts/native_continuation_store.gd"
# Test double: actual successful write followed by a simulated cleanup warning.
func save_to(path: String,state: Dictionary,expected_previous: Variant=null) -> bool:
	var ok: bool=super.save_to(path,state,expected_previous)
	if ok:error="LOCK_RELEASE_AFTER_COMMIT";return false
	return ok
