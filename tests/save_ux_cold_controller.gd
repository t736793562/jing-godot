extends "res://scripts/game_controller.gd"
var test_mode: String=""
var test_quit_requested:=false
func quit_game_now() -> void:
	test_quit_requested=true
	var reader=SaveStore.new();var actual: Dictionary=reader.read_valid(save_path);var matched: bool=not actual.is_empty() and var_to_bytes(actual)==var_to_bytes(model.state);var phase_ok: bool=model.state.phase==("expeditionRecall" if test_mode=="open" else "morning");var read_ok: bool=model.state.expedition.history[-1].recall.read==(test_mode in ["close","verify"])
	print(JSON.stringify({"mode":test_mode,"passed":matched and phase_ok and read_ok,"phase":model.state.phase,"read":model.state.expedition.history[-1].recall.read,"writes":autosave_writes,"real_disk":true,"programmatic_close_handler":true,"real_os_window_close":false,"visual_test":false,"main_integrated":false}));get_tree().quit(0 if matched and phase_ok and read_ok else 1)
