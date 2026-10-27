extends RefCounted
# Bounded native replay proof. No dynamic method names, scripts, objects or OS actions.
const Model=preload("res://scripts/game_model.gd")
const BaseStore=preload("res://scripts/native_save.gd")
const REV="d11-native-action-replay-v1"
const MAX_ACTIONS=1024
var anchor: Dictionary={}
var actions: Array=[]
var error: String=""
func start(model) -> bool:
	error=""
	if not valid_anchor(model.state):error="ANCHOR";return false
	anchor=model.state.duplicate(true);actions=[];return true
static func valid_anchor(state: Variant) -> bool:
	if not state is Dictionary or state.get("day")!=10 or state.get("phase")!="morning" or state.get("ended")!=false:return false
	var store=BaseStore.new()
	return store.valid_state(state)
static func valid_arguments(op: Variant,args: Variant) -> bool:
	if not op is String or not args is Array:return false
	match op:
		"recall_open":return args.size()==1 and args[0] is String and not args[0].is_empty() and args[0].length()<=256
		"recall_close":return args.is_empty()
		"expedition_plan":return args.size()==1 and args[0] is String and args[0] in ["母亲","安仁叔叔","外祖父","__cancel_unconfirmed_expedition__"]
		"expedition_tool":return args.size()==1 and args[0] is String and args[0] in ["rope","umbrella","whistle","axe","bandage","herbs","medkit","canteen"]
		"expedition_supply":return args.size()==1 and args[0] is String and args[0] in ["rice","water"]
		"expedition_search":return args.size()==1 and args[0] is String and args[0] in ["wait","ask","luo"]
		"enter","return","back_morning","back_focus","open_night","confirm_night","finish_night":return args.is_empty()
		"select":return args.size()==1 and args[0] is String and args[0] in Model.PEOPLE+["home"]
		"choose":return args.size()==1 and typeof(args[0]) in [TYPE_INT,TYPE_FLOAT] and args[0]>=0 and args[0]<=15 and args[0]==floor(args[0])
		"night_option":
			if args.size()!=2 or not args[0] is String:return false
			if args[0] in ["meal","feedPoultry","feedPet"]:return args[1] is bool
			return args[0]=="fire" and typeof(args[1]) in [TYPE_INT,TYPE_FLOAT] and args[1]>=0 and args[1]<=2 and args[1]==floor(args[1])
		"night_treatment":return args.size()==1 and args[0] is String and args[0].length()<=80
		"night_pigeon":return args.size()==1 and args[0] is String and args[0] in ["none","send","collect","delay"]
		"animal_encounter":return args.size()==2 and args[0] is String and args[0] in ["accept","decline"] and args[1] is String and args[1] in ["cat","dog"]
		"feed_animal":return args.size()==1 and args[0] is String and args[0] in ["poultry","pet"]
		"night_response":return args.size()==1 and args[0] is String and args[0] in ["quiet","warn","whistle","give","resist","animalPoultry","animalPet","wait","tidy","move","continue"]
	return false
static func apply_once(model,op: String,args: Array) -> Dictionary:
	if not valid_arguments(op,args):return {"executed":false,"result":false}
	# D49 is the last playable day; terminal day index49 is not actionable; D11 remains the anchor.
	if int(model.state.day) < 10 or int(model.state.day) > 49 or ((model.state.ended or int(model.state.day)>48) and op not in ["recall_open","recall_close"]):return {"executed":false,"result":false}
	var result: bool=false
	match op:
		"recall_open":
			if model.state.phase not in ["morning","focus","focusEvent","focusResult","focusReturn","event","report","night","nightEvent","search","end"]:return {"executed":false,"result":false}
			result=model.open_expedition_recall(args[0])
		"recall_close":
			if model.state.phase!="expeditionRecall":return {"executed":false,"result":false}
			result=model.close_expedition_recall()
		"expedition_plan":
			if model.state.phase!="night":return {"executed":false,"result":false}
			result=model.plan_expedition(args[0])
		"expedition_tool":
			if model.state.phase!="night":return {"executed":false,"result":false}
			result=model.toggle_expedition_tool(args[0])
		"expedition_supply":
			if model.state.phase!="night":return {"executed":false,"result":false}
			result=model.toggle_expedition_supply(args[0])
		"expedition_search":
			if model.state.phase!="search":return {"executed":false,"result":false}
			result=model.resolve_search(args[0])
			if result:model.state.phase="morning"
		"enter":
			if model.state.phase not in ["morning","focus"]:return {"executed":false,"result":false}
			result=model.enter_day_eleven_twelve_focus()
		"select":result=model.select_day_eleven_twelve_focus(args[0])
		"choose":result=model.resolve_day_eleven_twelve_choice(int(args[0]))
		"return":result=model.settle_day_eleven_twelve_return()
		"back_morning":
			if model.state.phase!="focus" or model.state.focus.get("choiceIndex")!=null:return {"executed":false,"result":false}
			model.state.phase="morning";result=true
		"back_focus":
			if model.state.phase!="focusEvent" or model.state.focus.get("choiceIndex")!=null:return {"executed":false,"result":false}
			model.state.phase="focus";result=true
		"open_night":
			if model.state.phase!="focusReturn" or not model.state.focus.get("settled",false):return {"executed":false,"result":false}
			model.state.phase="night";result=true
		"night_option":
			if model.state.phase!="night":return {"executed":false,"result":false}
			result=model.set_night_option(args[0],args[1])
		"night_treatment":
			if model.state.phase!="night":return {"executed":false,"result":false}
			result=model.set_night_treatment(args[0])
		"night_pigeon":
			if model.state.phase!="night":return {"executed":false,"result":false}
			result=model.set_pigeon_action(args[0])
		"feed_animal":
			if model.state.phase!="night":return {"executed":false,"result":false}
			result=model.feed_animal(args[0])
		"animal_encounter":
			if model.state.phase!="night":return {"executed":false,"result":false}
			result=model.resolve_animal_encounter(args[0],args[1])
		"confirm_night":
			if model.state.day>10 and model.state.phase!="night":return {"executed":false,"result":false}
			result=model.confirm_early_night()
		"night_response":result=model.resolve_night_event(args[0])
		"finish_night":
			if model.state.day>10 and model.state.phase!="nightEvent":return {"executed":false,"result":false}
			result=model.finish_early_night()
	return {"executed":true,"result":result}
func apply(model,op: String,args: Array=[]) -> bool:
	error=""
	if anchor.is_empty() or actions.size()>=MAX_ACTIONS:error="JOURNAL_LIMIT_OR_EMPTY";return false
	var answer:=apply_once(model,op,args)
	if not answer.executed:error="ACTION_NOT_ALLOWED";return false
	actions.append({"op":op,"args":args.duplicate(true),"ok":answer.result})
	return answer.result
func proof() -> Dictionary:
	return {"revision":REV,"anchor":anchor.duplicate(true),"actions":actions.duplicate(true)}
func restore(proof_value: Dictionary) -> void:
	anchor=proof_value.anchor.duplicate(true);actions=proof_value.actions.duplicate(true);error=""
static func replay(proof_value: Variant,reuse_model: Variant=null) -> Dictionary:
	if not proof_value is Dictionary or proof_value.size()!=3 or proof_value.get("revision")!=REV or not valid_anchor(proof_value.get("anchor")) or not proof_value.get("actions") is Array or proof_value.actions.is_empty() or proof_value.actions.size()>MAX_ACTIONS:return {"ok":false,"reason":"PROOF"}
	var model=Model.new() if reuse_model==null else reuse_model;model.state=proof_value.anchor.duplicate(true);model.contract_error="";model.contract_message="";model.diet_legacy_depth=0;model.rng.state=int(model.state.rngState)
	for action in proof_value.actions:
		if not action is Dictionary or action.size()!=3 or not action.get("ok") is bool or not valid_arguments(action.get("op"),action.get("args")):return {"ok":false,"reason":"ACTION"}
		var answer:=apply_once(model,action.op,action.args)
		if not answer.executed or answer.result!=action.ok:return {"ok":false,"reason":"REPLAY_RESULT"}
	return {"ok":true,"state":model.state}
