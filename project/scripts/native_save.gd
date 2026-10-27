extends RefCounted
# Native-only envelope. Typed pure-data JSON preserves every float64 bit and dictionary order.
# SHA256 detects corruption, not malicious forgery. Never instantiate serialized objects.
const Model=preload("res://scripts/game_model.gd")
const FORMAT="jing-godot-native"
const REVISION=1
const MAX_BYTES=8388608
const MAX_NODES=200000
var error: String=""
var nodes: int=0
var base_template: Dictionary={}
var focus_content_bank: Dictionary={}
var care_content_bank: Dictionary={}
var week_focus_bank: Dictionary={}
var home_templates: Array=[]
var outdoor_bank: Dictionary={}
var missing_focus_bank: Dictionary={}
var missing_care_bank: Dictionary={}
var missing_home_templates: Array=[]
func fail(reason: String) -> Variant:
	error=reason
	return null
func encode_value(value: Variant,depth: int=0) -> Variant:
	nodes+=1
	if depth>64 or nodes>MAX_NODES:return fail("LIMIT")
	match typeof(value):
		TYPE_NIL:return ["null"]
		TYPE_BOOL:return ["bool",value]
		TYPE_INT:return ["int",str(value)]
		TYPE_FLOAT:
			if not is_finite(value):return fail("NONFINITE")
			var stream:=StreamPeerBuffer.new();stream.big_endian=false;stream.put_double(value)
			return ["float64",stream.data_array.hex_encode()]
		TYPE_STRING:return ["string",value]
		TYPE_STRING_NAME:return ["name",str(value)]
		TYPE_ARRAY:
			var result: Array=[]
			for item in value:result.append(encode_value(item,depth+1))
			return ["array",result]
		TYPE_DICTIONARY:
			var result: Array=[]
			for key in value:
				if typeof(key) not in [TYPE_STRING,TYPE_STRING_NAME]:return fail("KEY_TYPE")
				result.append([encode_value(key,depth+1),encode_value(value[key],depth+1)])
			return ["dict",result]
	return fail("TYPE")
func decode_value(value: Variant,depth: int=0) -> Variant:
	nodes+=1
	if depth>64 or nodes>MAX_NODES:return fail("LIMIT")
	if not value is Array or value.is_empty() or not value[0] is String:return fail("TAG")
	if value[0]=="null":
		if value.size()!=1:return fail("NULL_TAG")
		return null
	if value.size()!=2:return fail("TAG_SIZE")
	var data=value[1]
	match value[0]:
		"bool":
			if data is bool:return data
		"string":
			if data is String:return data
		"name":
			if data is String:return StringName(data)
		"int":
			if data is String and data.is_valid_int() and str(int(data))==data:return int(data)
		"float64":
			if data is String and data.length()==16 and data.to_lower()==data and data.is_valid_hex_number(false):
				var stream:=StreamPeerBuffer.new();stream.big_endian=false;stream.data_array=data.hex_decode()
				var result:=stream.get_double()
				if is_finite(result):return result
		"array":
			if data is Array:
				var result: Array=[]
				for item in data:result.append(decode_value(item,depth+1))
				return result
		"dict":
			if data is Array:
				var result: Dictionary={}
				for pair in data:
					if not pair is Array or pair.size()!=2:return fail("DICT_KEY")
					var key=decode_value(pair[0],depth+1)
					if typeof(key) not in [TYPE_STRING,TYPE_STRING_NAME] or result.has(key):return fail("DICT_KEY")
					result[key]=decode_value(pair[1],depth+1)
				return result
	return fail("TAG_VALUE")
func finite_number(value: Variant,low: float,high: float,whole:=false) -> bool:
	return typeof(value) in [TYPE_FLOAT,TYPE_INT] and is_finite(float(value)) and value>=low and value<=high and (not whole or value==floor(value))
func matches_base(value: Variant,base: Variant) -> bool:
	if base==null:return true
	if typeof(base) in [TYPE_INT,TYPE_FLOAT]:return typeof(value) in [TYPE_INT,TYPE_FLOAT]
	if typeof(value)!=typeof(base):return false
	if base is Dictionary:
		for key in base:
			if not value.has(key) or not matches_base(value[key],base[key]):return false
	return true
func valid_state(state: Variant) -> bool:
	if not state is Dictionary:return false
	if base_template.is_empty():base_template=JSON.parse_string(FileAccess.get_file_as_string("res://data/native_base_state_template.json"))
	var base: Dictionary=base_template
	if not matches_base(state,base):return false
	for key in base:
		if not state.has(key):return false
		if base[key]!=null:
			if typeof(base[key]) in [TYPE_INT,TYPE_FLOAT]:
				if typeof(state[key]) not in [TYPE_INT,TYPE_FLOAT]:return false
			elif typeof(state[key])!=typeof(base[key]):return false
	if state.version!=base.version or state.saveVersion!=base.saveVersion:return false
	if state.seed.is_empty() or not finite_number(state.rngState,0,4294967295,true):return false
	# Restricted to the verified native model window; player UI is gated separately.
	if not finite_number(state.day,0,10,true) or state.phase not in ["intro","tutorial","loadout","event","report","diary","night","nightEvent","morning","focus","focusEvent","focusResult","focusReturn","end"]:return false
	if state.day==0 and state.phase in ["morning","focus","focusEvent","focusResult","focusReturn","end"]:return false
	if state.day>=1 and state.day<=9 and state.phase not in ["morning","focus","focusEvent","focusResult","focusReturn","night","nightEvent","end"]:return false
	if state.day==10 and state.phase!="morning":return false
	for key in ["rice","water","waterCap","wood","shelter","moisture"]:
		if not finite_number(state[key],0,1000000):return false
	if state.people.size()!=4:return false
	for name in Model.PEOPLE:
		if not state.people.get(name) is Dictionary:return false
		var person: Dictionary=state.people[name]
		for key in ["health","spirit","spiritMax"]:
			if not finite_number(person.get(key),0,10):return false
		for key in ["alive","away"]:
			if not person.get(key) is bool:return false
		if not state.ailments.get(name) is Dictionary:return false
		for key in ["cold","wound","nutrition"]:
			if not finite_number(state.ailments[name].get(key),0,10,true):return false
	for category in ["tools","shelterItems"]:
		for key in base[category]:
			if not state[category].get(key) is bool:return false
	for key in ["meal","repair","feedPoultry","feedPet"]:
		if not state.night.get(key) is bool:return false
	if not finite_number(state.night.get("fire"),0,2,true):return false
	if not state.night.get("treatment") is String:return false
	if state.night.treatment!="none":
		var medicine: PackedStringArray=state.night.treatment.split("|")
		if medicine.size()!=2 or medicine[0] not in ["bandage","herbs","medkit","gooseEgg"] or medicine[1] not in Model.PEOPLE:return false
	if not state.loadout.get("assigned") is Dictionary or state.loadout.get("carrier") not in Model.PEOPLE:return false
	for name in Model.PEOPLE:
		if not state.loadout.assigned.get(name) is Array:return false
		for id in state.loadout.assigned[name]:
			if not id is String:return false
	if state.weatherPlan.size()!=50:return false
	for row in state.weatherPlan:
		if not row is Dictionary or not row.get("id") is String or not row.get("name") is String:return false
		for key in ["cold","wet","dry","wind","weight"]:
			if not finite_number(row.get(key),0,100):return false
		if not row.get("damage") is Array or row.damage.size()!=2:return false
		for damage in row.damage:
			if not finite_number(damage,0,100):return false
	if state.has("features") and not state.features is Dictionary:return false
	if state.expedition.get("plan")!=null or state.expedition.get("active")!=null:return false
	for slot in ["poultry","pet"]:
		if not valid_animal_value(state.animals.get(slot),slot):return false
	if not valid_animal_value(state.memory.get("pigeonRequest"),"poultry",true):return false
	var cycle=state.get("nightCycle")
	if cycle!=null:
		if not cycle is Dictionary:return false
		if cycle.has("solitaryHealthEligible") and not cycle.solitaryHealthEligible is bool:return false
		if cycle.has("resultPackets") and (not cycle.resultPackets is Array or cycle.resultPackets.size()>1):return false
		if cycle.has("resultPackets"):
			for packet in cycle.resultPackets:
				if not packet is Dictionary:return false
		if not cycle.get("id") is String or not finite_number(cycle.get("day"),0,9,true):return false
		if cycle.get("status") not in ["awaiting_event","settled"]:return false
		if not matches_base(cycle.get("plan"),base.night):return false
		if not cycle.get("cost") is Dictionary:return false
		for key in ["rice","wood","water"]:
			if not finite_number(cycle.cost.get(key),0,1000000):return false
		if not finite_number(cycle.get("outcomeRng"),0,4294967295,true):return false
		if cycle.status=="awaiting_event" and state.phase!="nightEvent":return false
		if cycle.status=="settled" and state.phase not in ["morning","focus","focusEvent","focusResult","focusReturn","night","end"]:return false
	elif state.phase in ["nightEvent","morning","focus","focusEvent","focusResult","focusReturn","end"]:return false
	if state.phase in ["focus","focusEvent","focusResult","focusReturn"]:
		var focus: Dictionary=state.focus
		if focus.day!=state.day or not focus.plan is Dictionary or not focus.plan.get("rows") is Dictionary or not focus.plan.get("targets") is Array or focus.plan.targets.is_empty():return false
		for target in focus.plan.targets:
			if target not in Model.PEOPLE and target!="home":return false
		for person in Model.PEOPLE:
			if not focus.plan.rows.get(person) is Dictionary or not focus.plan.rows[person].get("label") is String or not focus.plan.rows[person].get("outside") is bool:return false
		if not focus.get("earlyReadingEvents") is Dictionary:return false
		if focus.plan.get("key")=="pigeonPickup" and not valid_pigeon_focus(focus,state):return false
		if focus_content_bank.is_empty():focus_content_bank=JSON.parse_string(FileAccess.get_file_as_string("res://data/early_focus_prose.json"))
		var bank: Dictionary=focus_content_bank
		if state.day>=4:
			if week_focus_bank.is_empty():week_focus_bank=JSON.parse_string(FileAccess.get_file_as_string("res://data/first_week_focus_prose.json"))
			bank=week_focus_bank
			if Model.PEOPLE.any(func(person):return not state.people[person].alive or state.people[person].away):
				if missing_focus_bank.is_empty():missing_focus_bank=JSON.parse_string(FileAccess.get_file_as_string("res://data/first_week_missing_focus_prose.json"))
				bank=missing_focus_bank
		for id in focus.earlyReadingEvents:
			if not bank.events.values().any(func(event):return event.id==id and source_equal(event,focus.earlyReadingEvents[id])):return false
		var current_event: Dictionary={}
		if state.phase!="focus":
			if focus.selected not in focus.plan.targets:return false
			if focus.earlyReadingEvents.has(focus.eventId):current_event=focus.earlyReadingEvents[focus.eventId]
			elif focus.plan.get("key")=="pigeonPickup" and valid_pigeon_focus(focus,state):current_event=focus.laterEvents[focus.eventId]
			elif valid_fallback_event(focus.get("fallback"),state):
				current_event=focus.fallback
				if current_event.id!=focus.eventId or current_event.get("target")!=focus.selected:return false
			else:return false
		if state.phase in ["focusResult","focusReturn"]:
			var event: Dictionary=current_event
			if not finite_number(focus.choiceIndex,0,event.choices.size()-1,true):return false
			if not event.choices[int(focus.choiceIndex)].closures.has(focus.outcomeKey):return false
			if state.phase=="focusReturn" and not focus.settled:return false
	if state.day==10:
		var story_initial=JSON.parse_string(FileAccess.get_file_as_string("res://data/story_initial_state.json"))
		for key in story_initial:
			if key=="knowledgeFacts":
				if not state.get(key) is Array:return false
				for fact in state[key]:
					if not valid_early_warning_fact(fact,state):return false
			elif not source_equal(state.get(key),story_initial[key]):return false
	if state.has("knowledgeFacts") and not state.knowledgeFacts is Array:return false
	var adapter: Dictionary=state.r2DietAdapter
	if adapter.get("firstNewNight")!=null and not finite_number(adapter.firstNewNight,0,0,true):return false
	var model=Model.new();model.state=state.duplicate(true)
	# D11+ neighbour contracts are being migrated but are not yet playable/importable.
	for key in ["neighbourMessagesWebR5","neighbourCustodyWebR6","neighbourCustodyNightWebR8"]:
		if model.js_truthy(state.memory.get(key)):return false
	if state.phase=="end" and not valid_terminal_failure(state,model):return false
	if state.ended and state.phase!="end":return false
	if not model.validate_bags():return false
	if not model.validate_current_diet():return false
	return true
func encode(state: Dictionary) -> String:
	error="";nodes=0
	# Pure-data validation precedes calls to the gameplay validator.
	var tagged=encode_value(state)
	if not error.is_empty():return ""
	if not valid_state(state):error="STATE";return ""
	var payload:=JSON.stringify(tagged)
	var result:=JSON.stringify({"format":FORMAT,"revision":REVISION,"payload":payload,"sha256":payload.sha256_text()})
	if result.to_utf8_buffer().size()>MAX_BYTES:error="SIZE";return ""
	return result
func decode(text: String) -> Dictionary:
	error="";nodes=0
	if text.to_utf8_buffer().size()>MAX_BYTES:error="SIZE";return {}
	var parser:=JSON.new()
	if parser.parse(text)!=OK:error="JSON";return {}
	var envelope=parser.data
	if not envelope is Dictionary or envelope.size()!=4 or envelope.get("format")!=FORMAT or envelope.get("revision")!=REVISION or not envelope.get("payload") is String or not envelope.get("sha256") is String:error="ENVELOPE";return {}
	if envelope.payload.sha256_text()!=envelope.sha256:error="CHECKSUM";return {}
	if parser.parse(envelope.payload)!=OK:error="PAYLOAD_JSON";return {}
	var tagged=parser.data
	var state=decode_value(tagged)
	if not error.is_empty():return {}
	if not valid_state(state):error="STATE";return {}
	return state
func read_valid(path: String) -> Dictionary:
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null:error="OPEN";return {}
	if file.get_length()>MAX_BYTES:file.close();error="SIZE";return {}
	var text:=file.get_as_text();file.close()
	return decode(text)
func write_text(path: String,text: String) -> bool:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:return false
	file.store_string(text);file.flush();var ok:=file.get_error()==OK;file.close();return ok
func replace_file(from: String,to: String) -> Error:
	return DirAccess.rename_absolute(from,to)
var last_write_committed: bool=false
func save_to(path: String,state: Dictionary,expected_previous: Variant=null) -> bool:
	last_write_committed=false
	var text:=encode(state)
	if text.is_empty():return false
	# Cooperative cross-process lock. A crash leaves a visible lock instead of silently
	# stealing another writer's staging file. Stale locks are never deleted automatically.
	var lock_path: String=path+".lock"
	if DirAccess.make_dir_absolute(lock_path)!=OK:error="WRITE_LOCKED";return false
	var ok:=write_locked(path,text,expected_previous)
	if DirAccess.remove_absolute(lock_path)!=OK:
		error="LOCK_RELEASE_AFTER_COMMIT" if last_write_committed else "LOCK_RELEASE";return false
	return ok
func file_fingerprint(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
func write_locked(path: String,text: String,expected_previous: Variant) -> bool:
	var original:=file_fingerprint(path)
	if expected_previous!=null and expected_previous!=original:error="WRITE_CONFLICT";return false
	var temp:=path+".tmp"
	if not write_text(temp,text):error="WRITE_TEMP";return false
	if read_valid(temp).is_empty() or FileAccess.get_file_as_string(temp)!=text:error="VERIFY_TEMP";return false
	# Only a verified old primary may replace the backup. A corrupt primary never poisons it.
	if FileAccess.file_exists(path) and not read_valid(path).is_empty():
		var old:=FileAccess.get_file_as_string(path)
		if not write_text(path+".bak.tmp",old) or read_valid(path+".bak.tmp").is_empty():error="BACKUP_WRITE";return false
		if replace_file(path+".bak.tmp",path+".bak")!=OK:error="BACKUP_RENAME";return false
	if file_fingerprint(path)!=original:error="WRITE_CONFLICT";return false
	if replace_file(temp,path)!=OK:error="PRIMARY_RENAME";return false
	last_write_committed=true;error="";return true
func load_from(path: String,model) -> Dictionary:
	var state:=read_valid(path);var source: String="primary";var primary_error:=error
	if state.is_empty():state=read_valid(path+".bak");source="backup"
	if state.is_empty():return {"ok":false,"reason":error,"primary_error":primary_error}
	# Commit only after full decode/validation; failure never changes live state or RNG.
	model.state=state;model.rng.state=int(state.rngState)
	model.contract_error="";model.contract_message="";model.diet_legacy_depth=0
	error=""
	return {"ok":true,"source":source,"primary_error":primary_error if source=="backup" else ""}

func valid_care_event(value: Variant,state: Dictionary) -> bool:
	if not value is Dictionary or value.get("conditionKind")!="care" or not value.get("choices") is Array or value.choices.size()!=3 or not value.get("earlyDiaryParts") is Dictionary:return false
	var first=value.choices[0]
	if not first is Dictionary or not first.get("immediateEffects") is Array or first.immediateEffects.size()!=2:return false
	var effect=first.immediateEffects[1]
	if not effect is Dictionary or effect.get("target") not in Model.PEOPLE:return false
	var candidate: Dictionary=value.duplicate(true)
	for key in candidate.earlyDiaryParts:
		var part=candidate.earlyDiaryParts[key]
		if not part is Dictionary or not finite_number(part.get("priorCount"),0,9,true):return false
		part.priorCount=0
	var model=Model.new();model.state=state.duplicate(true);var description: String=model.ailment_text(effect.target)
	if description=="":description="身上很不舒服"
	if care_content_bank.is_empty():care_content_bank=JSON.parse_string(FileAccess.get_file_as_string("res://data/early_care_prose.json"))
	var bank: Dictionary=care_content_bank
	if model.household_presence_mask()!=15:
		if missing_care_bank.is_empty():missing_care_bank=JSON.parse_string(FileAccess.get_file_as_string("res://data/missing_care_prose.json"))
		bank=missing_care_bank
	for template in bank.events.values():
		if template.id!=candidate.id:continue
		var expected: Dictionary=model._replace_content_token(template,"§AILMENT_DESCRIPTION§",description)
		if source_equal(expected,candidate):return true
		if int(state.day) in [4,5]:
			var patches=JSON.parse_string(FileAccess.get_file_as_string("res://data/care_reselect_text.json"))
			var patch: Dictionary=patches.pairs[str(int(state.day))]
			if source_equal(model._replace_content_token(expected,patch.fresh,patch.reselected),candidate):return true
	return false

func source_equal(a: Variant,b: Variant) -> bool:
	# Reference JSON numbers are float64; runtime counters may be integers. Compare numeric
	# content semantically here, without changing the typed on-disk codec or live state.
	if typeof(a) in [TYPE_INT,TYPE_FLOAT] and typeof(b) in [TYPE_INT,TYPE_FLOAT]:return a==b
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size():return false
		for key in a:
			if not b.has(key) or not source_equal(a[key],b[key]):return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for i in range(a.size()):
			if not source_equal(a[i],b[i]):return false
		return true
	return typeof(a)==typeof(b) and a==b

func valid_fallback_event(value: Variant,state: Dictionary) -> bool:
	if not value is Dictionary or not value.get("id") is String:return false
	if value.get("conditionKind")=="care":return valid_care_event(value,state)
	if state.day<4:return false
	var model=Model.new();model.state=state.duplicate(true)
	if value.get("conditionKind") in ["water","wood"]:
		if outdoor_bank.is_empty():outdoor_bank=JSON.parse_string(FileAccess.get_file_as_string("res://data/first_week_outdoor_prose.json"))
		var prior: Array=state.history.filter(func(row):return row.get("day",state.day)<state.day and model._object(row.get("readingVariant")).get("group")=="water")
		for template in outdoor_bank.events.values():
			if template.id!=value.id:continue
			var expected: Dictionary=template.duplicate(true)
			if value.conditionKind=="water":
				expected.readingVariant.previous=prior[-1].day if not prior.is_empty() else null
				if prior.size()==1:
					var previous: String=prior[0].get("choice","");var key: String=previous if previous in ["help","pole_help"] else "carry_home"
					for choice in expected.choices:choice.diaries.default+="\n\n"+outdoor_bank.prior_reflections[key]
			if source_equal(expected,value):return true
		return false
	if value.get("conditionKind") not in ["home","weather","neighbourhood","absence"] or not value.get("earlyDiaryParts") is Dictionary:return false
	var templates: Array=home_templates if model.household_presence_mask()==15 else missing_home_templates
	if templates.is_empty():
		var bank_path: String="res://data/first_week_home_prose.json" if model.household_presence_mask()==15 else "res://data/missing_home_prose.json"
		var bank=JSON.parse_string(FileAccess.get_file_as_string(bank_path))
		for encoded in bank.events.values():
			var decoded: Dictionary=model.decode_home_content(encoded,bank)
			for choice in decoded.choices:
				if choice.diaries.default is Dictionary:
					var parts: Dictionary=decoded.earlyDiaryParts[choice.diaries.default["$diary"]]
					choice.diaries.default="\n\n".join([parts.event,parts.family,parts.reflection])
			templates.append(decoded)
	var candidate: Dictionary=value.duplicate(true)
	# Only runtime rotation metadata is normalized; prose, options and effects remain frozen.
	if candidate.has("readingVariant"):
		if not candidate.readingVariant is Dictionary:return false
		if candidate.readingVariant.get("previous")!=null and not finite_number(candidate.readingVariant.previous,0,state.day-1,true):return false
		candidate.readingVariant.previous=null
	for part in candidate.earlyDiaryParts.values():
		if not part is Dictionary or not finite_number(part.get("priorCount"),0,state.day,true):return false
		part.priorCount=0
	for template in templates:
		if template.id!=candidate.id:continue
		var expected: Dictionary=model._replace_content_token(template,"§WEATHER_NAME§",model.current_weather().name)
		if expected.has("readingVariant"):expected.readingVariant.previous=null
		for part in expected.earlyDiaryParts.values():part.priorCount=0
		if source_equal(candidate,expected):return true
	return false

func valid_animal_value(value: Variant,slot: String,request_only:=false) -> bool:
	if value==null:return true
	if not value is Dictionary:return false
	var allowed: Array=["pigeon"] if request_only else (["goose","pigeon"] if slot=="poultry" else ["cat","dog"])
	if value.get("type") not in allowed:return false
	for spec in [["relation",3],["remaining",5],["hunger",100000]]:
		if not finite_number(value.get(spec[0]),0,spec[1],true):return false
	if value.type=="pigeon":
		for key in ["sent","resolved","pickup","pickupDone"]:
			if not value.get(key) is bool:return false
		if not finite_number(value.get("delay"),0,100000,true):return false
		if value.get("feedingContract")!="pigeon-v2":return false
		if value.sent:
			for key in ["sentDay","returnDay"]:
				if not finite_number(value.get(key),0,50,true):return false
			if value.get("outcome") not in ["delivery","stash","no_reply"]:return false
			for key in ["flightChance","flightRoll"]:
				if not finite_number(value.get(key),0,1):return false
		if value.pickup and not finite_number(value.get("pickupDeadline"),0,50,true):return false
		var plan=value.get("pickupPlan")
		if plan!=null:
			if not plan is Dictionary or plan.get("status") not in ["planned","expired","completed","cancelled","return_pending","settled"]:return false
			for key in ["requestedDay","day"]:
				if not finite_number(plan.get(key),0,50,true):return false
			if plan.status in ["return_pending","settled"]:
				if plan.get("choice") not in ["small","full","leave"] or not plan.get("injured") is bool or not plan.get("packetId") is String or plan.packetId.is_empty():return false
				if plan.choice!="full" and plan.injured:return false
	elif value.type=="goose":
		if not finite_number(value.get("feedsAfterEgg"),0,3,true):return false
	elif not value.get("guardTonight") is bool:return false
	return true

func valid_early_warning_fact_legacy(value: Variant,state: Dictionary) -> bool:
	if not value is Dictionary or not finite_number(value.get("day"),1,state.day+1,true):return false
	var contract=JSON.parse_string(FileAccess.get_file_as_string("res://data/c018_contract.json")).contract
	var expected: Dictionary={"id":state.seed+":D"+str(int(value.day))+":c018-solitary-health-warning","contentId":contract.warningContentId,"contractRevision":contract.revision,"day":value.day,"knownBy":["player","罗瑾"],"source":"清晨直接告知","scope":contract.warningScope,"diaryEligible":false}
	return source_equal(value,expected)

func valid_terminal_failure(state: Dictionary,model: RefCounted) -> bool:
	if not state.ended or state.get("endingLocked")!=true or state.get("endingType")!="luo_death_failure" or state.people["罗瑾"].alive or state.people["罗瑾"].health!=0:return false
	var cycle=model._object(state.get("nightCycle"));var record=model._object(state.memory.get("failureRecord"));var death=model._object(state.memory.get("lastDeath"))
	if cycle.get("status")!="settled" or cycle.get("c018Outcome")!="failure" or cycle.get("c018SettlementStage")!="failure_locked":return false
	var packet=model.find_solitary_health_packet()
	if packet==null or not model.validate_solitary_health_packet(packet) or packet.get("status")!="applied" or packet.get("appliedDay")!=state.day:return false
	var contract=model.c018_contract()
	for value in [record,death]:
		if value.get("resultPacketId")!=packet.id or value.get("causeId")!=contract.causeId or value.get("reviewId")!=contract.reviewId or value.get("contractRevision")!=contract.revision:return false
	var applied=state.effectLedger.get("appliedEffectIds",[])
	return packet.id in applied and cycle.id+":dawn" in applied

func valid_pigeon_focus(f: Dictionary,state: Dictionary) -> bool:
	if state.day<6 or state.day>9 or not f.get("laterEvents") is Dictionary or f.laterEvents.size()!=1 or not f.earlyReadingEvents.is_empty():return false
	var id: String="animal.pickup.D"+str(int(state.day)+1)
	if not f.laterEvents.has(id) or not source_equal(f.plan.get("eventIds"),{"罗瑾":id}) or not source_equal(f.plan.targets,["罗瑾"]):return false
	var model=Model.new();model.state=state.duplicate(true);model.load_pigeon_pickup_prose();var recognized:=false
	for key in ["water","dry"]:
		var expected: Dictionary=model.pigeon_pickup_prose.scenes[key].duplicate(true);expected.id=id
		if source_equal(expected,f.laterEvents[id]):recognized=true
	if not recognized:return false
	if state.phase=="focus":return true
	if f.get("eventId")!=id or f.get("selected")!="罗瑾":return false
	if state.phase=="focusEvent":return true
	if not finite_number(f.get("choiceIndex"),0,2,true):return false
	var choice: Dictionary=f.laterEvents[id].choices[int(f.choiceIndex)];var a: Dictionary=model._object(model.pigeon_request());var q: Dictionary=model._object(a.get("pickupPlan"));var r: Dictionary=model._object(f.get("pigeonPickupResult"))
	var expected_id: String=state.seed+":D"+str(int(state.day)+1)+":"+id+":"+choice.id+":return"
	if q.get("packetId")!=expected_id or q.get("choice")!=choice.id or not q.get("injured") is bool or (choice.id!="full" and q.injured):return false
	var effects: Array=choice.get("returnEffects",[]).duplicate(true);effects.append({"type":"character_spirit","target":"罗瑾","amount":-2 if choice.id=="full" else -1})
	if q.injured:effects.append({"type":"character_health","target":"罗瑾","amount":-1})
	var packets: Array=f.resultPackets.filter(func(p):return p is Dictionary and p.get("id")==expected_id)
	if packets.size()!=1 or not source_equal(packets[0].get("effects"),effects):return false
	var status: String="pending" if state.phase=="focusResult" else "settled"
	if q.get("status")!=("return_pending" if state.phase=="focusResult" else "settled"):return false
	return source_equal(r,{"choice":choice.id,"injured":q.injured,"water":effects.any(func(x):return x.get("resource")=="water"),"status":status})
func valid_early_warning_fact(value: Variant,state: Dictionary) -> bool:
	if valid_early_warning_fact_legacy(value,state):return true
	if not value is Dictionary or not finite_number(value.get("day"),7,10,true):return false
	var id: String="animal.pickup.D"+str(int(value.day));var expected: Dictionary={"id":id+":return-knowledge","day":value.day,"source":"罗瑾","knownBy":["罗瑾"],"scope":"选择结果的可转述部分","text":"我按纸条去过，拿了多少、没有拿什么，都要等回家以后照实说清。"}
	if not source_equal(value,expected):return false
	return state.history.any(func(h):return h is Dictionary and h.get("type")=="pigeon-pickup" and h.get("day")==value.day-1 and h.get("choice") in ["small","full","leave"] and h.get("resultPacketId")==state.seed+":D"+str(int(value.day))+":"+id+":"+str(h.get("choice"))+":return")
