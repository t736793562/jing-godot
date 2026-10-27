extends SceneTree
const Model=preload("res://scripts/game_model.gd")
const Journal=preload("res://scripts/native_continuation.gd")
const Store=preload("res://scripts/native_continuation_store.gd")
var failed: Array=[]
var checks:=0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failed.append(label)
func _initialize() -> void:
	var f=FileAccess.open("res://data/day_eleven_lifecycle_reference.jsonl",FileAccess.READ);var case=JSON.parse_string(f.get_line());var model=Model.new();model.state=case.initial.duplicate(true);var journal=Journal.new();check(journal.start(model),"anchor")
	for bad in [["exec",[]],["choose",[-1]],["choose",[16]],["choose",[0.5]],["choose",[INF]],["choose",[NAN]],["select",["unknown"]],["night_option",["fire",3]],["night_option",["meal",1]],["animal_encounter",["accept","unknown"]]]:check(not Journal.valid_arguments(bad[0],bad[1]),"argument:"+str(bad))
	for i in range(Journal.MAX_ACTIONS):
		if not journal.apply(model,"enter" if i%2==0 else "back_morning"):failed.append("capacity:"+str(i));break
	check(journal.actions.size()==1024,"bounded-capacity")
	var before: PackedByteArray=var_to_bytes(model.state);var proof: PackedByteArray=var_to_bytes(journal.proof());check(not journal.apply(model,"enter"),"overflow-refused");check(var_to_bytes(model.state)==before and var_to_bytes(journal.proof())==proof,"overflow-no-mutation")
	var replayed: Dictionary=Journal.replay(journal.proof());check(replayed.ok and var_to_bytes(replayed.state)==before,"full-capacity-replay")
	var too_many: Dictionary=journal.proof();too_many.actions.append({"op":"enter","args":[],"ok":true});check(not Journal.replay(too_many).ok,"oversized-proof-rejected")
	var malformed: Dictionary=journal.proof();malformed.actions[0].op="exec";check(not Journal.replay(malformed).ok,"unknown-op-rejected")
	var store=Store.new();store.active_proof=journal.proof();var encoded: String=store.encode(model.state);check(not encoded.is_empty(),"capacity-encode:"+store.error);var restored: Dictionary=store.decode(encoded);check(not restored.is_empty() and var_to_bytes(restored)==before,"capacity-decode:"+store.error)
	print(JSON.stringify({"checks":checks,"failed":failed,"max_actions":Journal.MAX_ACTIONS,"encoded_bytes":encoded.to_utf8_buffer().size(),"scope":"Controlled menu-return journal capacity, not full 49-day play or autosave performance acceptance."}));quit(0 if failed.is_empty() else 1)
