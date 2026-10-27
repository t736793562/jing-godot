extends SceneTree
const Model=preload("res://scripts/game_model.gd")
var failed: Array=[]
var checks:=0
var model
func compare(case: Dictionary,label: String,result: Variant,expected: Variant,state_key: String) -> void:
	checks+=2
	if not same_json(result,expected) or not same_json(model.state,case[state_key]):
		if failed.is_empty():
			var file=FileAccess.open("res://../evidence/solitary_packet_first_diff.json",FileAccess.WRITE)
			file.store_string(JSON.stringify({"id":case.id,"stage":label,"actual":model.state,"expected":case[state_key],"result":result,"expected_result":expected}))
		failed.append(case.id+":"+label)
func _initialize() -> void:
	var stream=FileAccess.open("res://data/solitary_packet_reference.jsonl",FileAccess.READ)
	model=Model.new()
	while stream.get_position()<stream.get_length():
		var line=stream.get_line()
		if line.is_empty():continue
		var case=JSON.parse_string(line);model.state=case.initial.duplicate(true);model.contract_error="";model.contract_message=""
		compare(case,"prepare",model.prepare_solitary_warning(),case.prepared,"afterPrepared")
		compare(case,"acknowledge",model.acknowledge_solitary_warning(),case.acknowledged,"afterAcknowledged")
		model.state=case.beforeEligibility.duplicate(true)
		var eligible: bool=model.solitary_health_night_eligible()
		compare(case,"eligible",eligible,case.eligible,"afterEligibility")
		model.state.nightCycle.solitaryHealthEligible=eligible
		var queued=model.queue_solitary_health_packet()
		compare(case,"queue",null if queued==null else queued.id,case.queued,"afterQueued")
		queued=model.queue_solitary_health_packet()
		compare(case,"repeat_queue",null if queued==null else queued.id,case.queuedAgain,"afterQueuedAgain")
		model.state=case.beforeReady.duplicate(true)
		compare(case,"ready",model.solitary_health_fatal_ready(),case.ready,"afterReady")
		model.check_early_critical();checks+=1
		if not same_json(model.state,case.afterCritical):failed.append(case.id+":critical")
		model.state.nightCycle.c018SettlementStage="post_critical"
		compare(case,"apply",model.resolve_solitary_health_failure(),case.applied,"afterApply")
		compare(case,"repeat_apply",model.resolve_solitary_health_failure(),case.again,"afterAgain")
	print(JSON.stringify({"checks":checks,"failed":failed,"full_game":false,"visual_test":false}));quit(0 if failed.is_empty() else 1)

func same_json(a: Variant,b: Variant) -> bool:
	if typeof(a) in [TYPE_INT,TYPE_FLOAT] and typeof(b) in [TYPE_INT,TYPE_FLOAT]:return float(a)==float(b)
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size():return false
		for key in a:
			if not b.has(key) or not same_json(a[key],b[key]):return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for i in range(a.size()):
			if not same_json(a[i],b[i]):return false
		return true
	return typeof(a)==typeof(b) and a==b

