extends RefCounted
const FamilyProse=preload("res://scripts/family_prose.gd")
var family_care_prose: Dictionary={}
const RNG=preload("res://scripts/native_rng.gd")
const PEOPLE=["罗瑾","母亲","外祖父","安仁叔叔"]
const CAPACITY={"罗瑾":5,"母亲":7,"外祖父":6,"安仁叔叔":9}
var state: Dictionary={}
var catalog: Array=[]
var weather: Array=[]
var rng=RNG.new()
func _init() -> void:
	catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/loadout_catalog.json"))
	weather=JSON.parse_string(FileAccess.get_file_as_string("res://data/weather_catalog.json"))
func new_game(seed_value: String,active_contract:=true) -> Dictionary:
	contract_error="";contract_message="";diet_legacy_depth=0
	state=JSON.parse_string(FileAccess.get_file_as_string("res://data/native_base_state_template.json" if active_contract else "res://data/base_state_template.json"))
	state.seed=seed_value
	rng.seed_with(seed_value)
	state.weatherPlan=RNG.weather_plan(seed_value,weather)
	for person in PEOPLE:
		state.people[person].health=rng.integer(7 if person=="外祖父" else 8,9)
		state.people[person].spirit=rng.integer(7 if person=="罗瑾" else 8,9)
	state.rngState=rng.state
	return state
func item(id: String) -> Dictionary:
	for row in catalog:
		if row.id==id:return row
	return {}
func ensure_pool() -> Array:
	if state.loadout.pool.is_empty():
		state.loadout.pool=["rice5","rice3","rice2a","rice1","wood5","wood3","wood2a","wood1","canteen","bucket","bedding","oilcloth","scissors","rope","bandage","herbs","goose","pigeon"]
		rng.state=int(state.rngState)
		for options in [["mat","medkit"],["axe","shovel"],["whistle","umbrella"],["rice2b","wood2b"]]:
			state.loadout.pool.append(options[int(floor(rng.next_float()*options.size()))])
		state.rngState=rng.state
	var pool: Array=state.loadout.pool.duplicate()
	if state.get("features",{}).get("animals",true)==false:
		pool.erase("goose");pool.erase("pigeon")
	return pool
func weight(person: String) -> float:
	var result:=0.0
	for id in state.loadout.assigned[person]:result+=float(item(id).get("weight",0))
	return result
func assigned_ids() -> Array:
	var result: Array=[]
	for person in PEOPLE:result.append_array(state.loadout.assigned[person])
	return result
func add_loadout(id: String,person: String="") -> bool:
	if person.is_empty():person=state.loadout.carrier
	var info:=item(id)
	if state.phase!="loadout" or person not in PEOPLE or info.is_empty():return false
	if id not in ensure_pool() or id in assigned_ids():return false
	if state.loadout.assigned[person].size()>=4 or weight(person)+float(info.weight)>float(CAPACITY[person]):
		state.error=person+"已经没有足够背包格或负重。"
		return false
	if id in ["goose","pigeon"]:
		for old in assigned_ids():
			if old in ["goose","pigeon"]:
				state.error="禽类格只能带母鹅或信鸽中的一种。"
				return false
	state.loadout.assigned[person].append(id)
	state.loadout.confirmRecommendation=false
	state.error=null
	return true
func remove_loadout(person: String,id: String) -> bool:
	if state.phase!="loadout" or person not in PEOPLE:return false
	var filtered: Array=[]
	for old in state.loadout.assigned[person]:
		if old!=id:filtered.append(old)
	state.loadout.assigned[person]=filtered
	state.loadout.confirmRecommendation=false
	state.error=null
	return true
func totals() -> Dictionary:
	var result={"rice":0,"wood":0,"waterCap":4,"items":[]}
	for id in assigned_ids():
		var info:=item(id)
		if info.is_empty():continue
		result.items.append(info.duplicate(true))
		if info.kind=="rice":result.rice+=int(info.amount)
		elif info.kind=="wood":result.wood+=int(info.amount)
		elif info.kind=="container":result.waterCap+=int(info.amount)
	return result
func dispatch(action: String,value: String="",person: String="") -> Dictionary:
	match action:
		"introNext":
			if state.phase!="intro":return {"ok":false,"reason":"phase"}
			state.phase="tutorial";state.tutorialPage=0
		"tutorialNext":
			if state.phase!="tutorial":return {"ok":false,"reason":"phase"}
			if int(state.tutorialPage)==0:state.tutorialPage=1
			else:state.phase="loadout"
		"tutorialBack":state.tutorialPage=0
		"tutorialSkip":state.phase="loadout"
		"selectCarrier":
			if value not in PEOPLE:return {"ok":false,"reason":"person"}
			state.loadout.carrier=value
		"addLoadout":return {"ok":add_loadout(value,person)}
		"removeLoadout":return {"ok":remove_loadout(person,value)}
		"clearLoadout":
			if state.phase!="loadout":return {"ok":false,"reason":"phase"}
			for name in PEOPLE:state.loadout.assigned[name]=[]
			state.loadout.confirmRecommendation=false;state.error=null
		"backLoadoutTutorial":state.phase="tutorial";state.tutorialPage=1
		_:return {"ok":false,"reason":"NOT_MIGRATED","action":action}
	return {"ok":true}

const PERSON_SUFFIX={"罗瑾":"luo","母亲":"mother","外祖父":"grandfather","安仁叔叔":"anren"}
var opening_text: Dictionary={}
func opening_copy(key: String) -> String:
	if opening_text.is_empty():opening_text=JSON.parse_string(FileAccess.get_file_as_string("res://data/opening_text.json"))
	return str(opening_text.get("a1.a."+key,""))
func random_value() -> float:
	rng.state=int(state.rngState)
	var value: float=rng.next_float()
	state.rngState=rng.state
	return value
func pick(values: Array) -> Variant:
	return values[int(floor(random_value()*values.size()))]
func change_spirit(person: String,amount: float) -> float:
	var p: Dictionary=state.people.get(person,{})
	if p.is_empty():return 0
	p.spirit=clampf(float(p.spirit)+amount,0,float(p.get("spiritMax",10)))
	return p.spirit
func tool_available(id: String) -> bool:
	var active=state.expedition.get("active")
	return bool(state.tools.get(id,false)) and (active==null or id not in active.get("tools",[]))
func load_risk(bags: Dictionary={}) -> Dictionary:
	if bags.is_empty():bags=state.loadout.assigned
	var weights: Dictionary={};var ratios: Dictionary={};var average:=0.0;var strained: Array=[];var spare:=true;var empty:=true
	for person in PEOPLE:
		var total:=0.0
		for id in bags[person]:total+=float(item(id).weight)
		weights[person]=total;ratios[person]=total/float(CAPACITY[person]);average+=ratios[person]
		if ratios[person]>=0.75:strained.append(person)
		if total>float(CAPACITY[person])-1:spare=false
		if total!=0:empty=false
	average/=4.0
	return {"weights":weights,"ratios":ratios,"average":average,"strained":strained,"hasOneWeightSpare":spare,"lossChance":minf(0.22,0.06+average*0.16),"injuryChance":minf(0.24,0.08+average*0.15) if not strained.is_empty() else 0,"tier":"empty" if empty else ("light" if strained.is_empty() else ("moderate" if spare and strained.size()<=2 else "high"))}
func _pack_search(ordered: Array,index: int,bags: Dictionary,weights: Dictionary,dead: Dictionary) -> bool:
	if index==ordered.size():return true
	var key:=str(index)+":"
	for person in PEOPLE:key+=str(weights[person])+","+str(bags[person].size())+";"
	if dead.has(key):return false
	var info: Dictionary=ordered[index]
	var names: Array=PEOPLE.duplicate()
	names.sort_custom(func(a,b):
		var ra=(float(weights[a])+float(info.weight))/float(CAPACITY[a]);var rb=(float(weights[b])+float(info.weight))/float(CAPACITY[b])
		return PEOPLE.find(a)<PEOPLE.find(b) if ra==rb else ra<rb)
	for person in names:
		if bags[person].size()==4 or float(weights[person])+float(info.weight)>float(CAPACITY[person]):continue
		bags[person].append(info.id);weights[person]+=int(info.weight)
		if _pack_search(ordered,index+1,bags,weights,dead):return true
		bags[person].pop_back();weights[person]-=int(info.weight)
	dead[key]=true
	return false
func _pack_items(ids: Array,pinned: Array,pool: Array) -> Variant:
	var bags: Dictionary={};var weights: Dictionary={};var ordered: Array=[]
	for person in PEOPLE:bags[person]=[];weights[person]=0
	for entry in pinned:
		if entry.id not in pool:return null
		bags[entry.person].append(entry.id);weights[entry.person]+=int(item(entry.id).weight)
	for id in ids:ordered.append(item(id))
	ordered.sort_custom(func(a,b):return str(a.id)<str(b.id) if a.weight==b.weight else a.weight>b.weight)
	return bags if _pack_search(ordered,0,bags,weights,{}) else null
func suggested_pack() -> Variant:
	var pool:=ensure_pool();var pinned: Array=[]
	for person in PEOPLE:
		for id in state.loadout.assigned[person]:
			if id in ["goose","pigeon"]:pinned.append({"id":id,"person":person})
	var accepted: Array=["rice5","rice2a","wood5","canteen","bedding","oilcloth","rope","bandage"]
	for id in accepted:
		if id not in pool:return null
	var result=_pack_items(accepted,pinned,pool)
	if result==null:return null
	var risk:=load_risk(result)
	if not risk.hasOneWeightSpare or risk.strained.size()>2:return null
	for id in ["rice3","herbs","wood3","scissors","mat","umbrella","axe","shovel","medkit","bucket","rice1","wood1","whistle","rice2b","wood2a","wood2b"]:
		if id not in pool:continue
		var candidate: Array=accepted.duplicate();candidate.append(id)
		var next=_pack_items(candidate,pinned,pool)
		if next!=null:
			var next_risk:=load_risk(next)
			if next_risk.hasOneWeightSpare and next_risk.strained.size()<=2:accepted=candidate;result=next
	return result
func recommend(confirmed:=false) -> bool:
	if state.phase!="loadout":return false
	if not confirmed and not assigned_ids().is_empty():state.loadout.confirmRecommendation=true;return false
	var result=suggested_pack()
	if result==null:state.error="这次无法生成合适的建议装法，请手动调整。";return false
	state.loadout.assigned=result;state.loadout.confirmRecommendation=false;state.error=null
	return true
func validate_bags() -> bool:
	var pool:=ensure_pool();var seen: Dictionary={};var birds:=0
	for person in PEOPLE:
		var bag=state.loadout.assigned[person]
		if not bag is Array or bag.size()>4:return false
		for id in bag:
			if id not in pool or item(id).is_empty() or seen.has(id):return false
			seen[id]=true
			if id in ["goose","pigeon"]:birds+=1
		if weight(person)>float(CAPACITY[person]):return false
	return birds<=1
func start_opening() -> bool:
	if state.phase!="loadout" or state.memory.get("opening")!=null:return false
	if not validate_bags():state.error="请检查背包：物品不能重复，每人最多四件且不能超重，禽类只能带一种。";return false
	var tally:=totals();var ids:=assigned_ids();var bags: Dictionary=state.loadout.assigned.duplicate(true)
	state.rice=tally.rice;state.wood=tally.wood;state.waterCap=tally.waterCap;state.water=tally.waterCap
	for id in state.tools:state.tools[id]=false
	state.shelterItems={"oilcloth":false,"mat":false,"bedding":false}
	for info in tally.items:
		if info.kind in ["tool","container"]:state.tools[info.id]=true
		elif info.kind=="shelter":state.shelterItems[info.id]=true
	state.animals={"poultry":null,"pet":null};state.memory.loadout={"bags":bags.duplicate(true),"items":ids.duplicate()}
	state.memory.opening={"format":1,"readingRevision":"A2-WebM1-v1","stage":"road","bags":bags,"items":ids.duplicate(),"choice":null,"settled":false,"loss":null,"gain":null,"injury":null,"receipt":[],"diary":null}
	state.phase="event";state.error=null;state.eventResult=null;state.eventChange=null;state.selectedChoice=null
	return true
func opening_active() -> bool:
	return int(state.day)==0 and state.memory.get("opening",{}).get("format")==1
func opening_bird(o: Dictionary) -> Variant:
	var id: Variant="goose" if "goose" in o.items else ("pigeon" if "pigeon" in o.items else null)
	if id==null:return null
	for person in PEOPLE:
		if id in o.bags[person]:return {"id":id,"carrier":person,"suffix":PERSON_SUFFIX[person]}
	return null
func road_text() -> Array:
	var o: Dictionary=state.memory.opening;var bird=opening_bird(o);var paragraphs: Array=[opening_copy("pack.02")]
	for n in ["01","02","03","04","05","06"]:paragraphs.append(opening_copy("road."+n))
	if bird!=null:paragraphs.append(opening_copy("road.bird."+bird.id+"."+bird.suffix))
	for n in ["07","08","09","10"]:paragraphs.append(opening_copy("road."+n))
	return paragraphs.filter(func(x):return not str(x).is_empty())
func choose_opening(index: int) -> bool:
	if not opening_active() or state.phase!="event" or index not in [0,1]:return false
	var o: Dictionary=state.memory.opening
	if o.stage!="road" or o.choice!=null:return false
	if index==1 and not tool_available("rope"):state.error="背包里没有可用的绳索。";return false
	o.choice=index;o.stage="leaving";state.selectedChoice=index;state.error=null
	var bird=opening_bird(o);var parts: Array=[]
	if index==0:
		for n in ["01","02","03"]:parts.append(opening_copy("close.0."+n))
	else:
		if bird!=null:parts.append(opening_copy("close.1.bird.before."+bird.suffix))
		for n in ["01","02","03"]:parts.append(opening_copy("close.1."+n))
		if bird!=null:parts.append(opening_copy("close.1.bird.after."+bird.suffix))
		parts.append(opening_copy("close.1.04"))
	o.immediate="\n\n".join(parts.filter(func(x):return not str(x).is_empty()))
	state.eventResult=o.immediate;state.eventChange=null;state.history.append({"day":0,"type":"opening-choice","choice":index})
	return true
func remove_starting_item(id: String) -> String:
	var info:=item(id)
	if info.is_empty():return ""
	if info.kind=="rice":state.rice=maxf(0,float(state.rice)-float(info.amount))
	elif info.kind=="wood":state.wood=maxf(0,float(state.wood)-float(info.amount))
	elif info.kind=="container":state.tools[id]=false;state.waterCap=maxf(4,float(state.waterCap)-float(info.amount));state.water=minf(state.water,state.waterCap)
	elif info.kind=="shelter":state.shelterItems[id]=false
	elif info.kind=="poultry":state.animals.poultry=null
	elif state.tools.has(id):state.tools[id]=false
	for person in PEOPLE:state.loadout.assigned[person]=state.loadout.assigned[person].filter(func(x):return x!=id)
	return info.name
func add_animal(slot: String,type: String) -> bool:
	if state.get("features",{}).get("animals",true)==false or slot not in ["poultry","pet"] or state.animals[slot]!=null:return false
	if slot=="poultry" and type not in ["goose","pigeon"]:return false
	if slot=="pet" and type not in ["cat","dog"]:return false
	var animal={"type":type,"relation":1,"remaining":0,"hunger":0}
	if type=="pigeon":animal.merge({"sent":false,"resolved":false,"pickup":false,"pickupDone":false,"delay":0,"feedingContract":"pigeon-v2"})
	elif type=="goose":animal.feedsAfterEgg=0
	else:animal.guardTonight=false
	state.animals[slot]=animal
	return true
func settle_opening_arrival() -> bool:
	if not opening_active():return false
	var o: Dictionary=state.memory.opening
	if o.choice==null or o.settled:return false
	var risk:=load_risk(o.bags);var containers: Array=o.items.filter(func(id):return item(id).kind=="container")
	var eligible: Array=o.items.filter(func(id):return id not in ["goose","pigeon"] and not (item(id).kind=="container" and containers.size()<=1))
	var roll:=random_value()
	if not eligible.is_empty() and roll<float(risk.lossChance):
		var id: String=pick(eligible);var owner: String=""
		for person in PEOPLE:
			if id in o.bags[person]:owner=person;break
		o.loss={"id":id,"name":remove_starting_item(id),"owner":owner};o.receipt.append("途中失去"+o.loss.name+"×1")
	elif roll<float(risk.lossChance)+0.14:
		var key: String="rice" if random_value()<0.55 else "wood";state[key]+=1;o.gain=key;o.receipt.append(("米粮" if key=="rice" else "木料")+"＋1（途中拾得）")
	var strained: Array=risk.strained.duplicate()
	if not strained.is_empty() and random_value()<float(risk.injuryChance):
		strained.sort_custom(func(a,b):return PEOPLE.find(a)<PEOPLE.find(b) if risk.ratios[a]==risk.ratios[b] else risk.ratios[a]>risk.ratios[b])
		var person: String=strained[int(floor(random_value()*mini(2,strained.size())))];var type: String="health" if random_value()<0.6 else "spirit"
		if type=="health":state.people[person].health=clampf(float(state.people[person].health)-1,0,10)
		else:change_spirit(person,-1)
		o.injury={"name":person,"type":type}
	state.shelter=clampf(float(state.shelter)+(-2 if int(o.choice)==0 else 3),0,50)
	if int(o.choice)==1:change_spirit("罗瑾",-1)
	state.memory.escape="people" if int(o.choice)==0 else "supplies"
	for id in o.items:
		if id not in ["goose","pigeon"]:continue
		add_animal("poultry",id)
		if state.animals.poultry!=null:
			var carrier: String=""
			for person in PEOPLE:
				if id in o.bags[person]:carrier=person;break
			state.animals.poultry.merge({"openingCarrierId":carrier,"openingSlotCost":1,"openingWeightCost":item(id).weight,"transferredFromLoadout":true})
		for person in PEOPLE:state.loadout.assigned[person]=state.loadout.assigned[person].filter(func(x):return x!=id)
	o.arrived={"rice":state.rice,"wood":state.wood,"water":state.water,"waterCap":state.waterCap,"tools":state.tools.duplicate(true),"shelterItems":state.shelterItems.duplicate(true),"poultry":state.animals.poultry.type if state.animals.poultry!=null else null}
	o.settled=true;o.stage="arrived"
	o.receipt.append("搭棚时少了一根长支撑，棚架更加简陋。" if int(o.choice)==0 else "取来的长木用作支撑，棚架更稳一些；罗瑾仍没从街上的惊惧中缓过来。")
	if o.injury!=null:o.receipt.append(o.injury.name+("途中有了擦撞伤。" if o.injury.type=="health" else "一路受惊，难以安定。"))
	o.diary=build_opening_diary();state.phase="report"
	return true
func build_opening_diary() -> Array:
	var o: Dictionary=state.memory.opening;var a: Dictionary=o.arrived;var lines: Array=[opening_copy("diary.01"),opening_copy("diary.02"),opening_copy("diary.beam."+str(int(o.choice)))]
	if o.loss!=null:lines.append(opening_copy("diary.assets.loss_rope" if o.loss.id=="rope" and int(o.choice)==1 else "diary.assets.loss"))
	elif o.gain in ["rice","wood"]:lines.append(opening_copy("diary.assets."+o.gain))
	else:lines.append(opening_copy("diary.assets."+("unchanged" if not o.items.is_empty() else "empty")))
	lines.append(opening_copy("diary.roof."+("oilcloth" if a.shelterItems.oilcloth else "other")))
	var floor: String="both" if a.shelterItems.mat and a.shelterItems.bedding else ("bedding" if a.shelterItems.bedding else ("mat" if a.shelterItems.mat else "none"))
	lines.append(opening_copy("diary.floor."+floor))
	var luo_shock: bool=int(o.choice)==1 and o.injury!=null and o.injury.name=="罗瑾" and o.injury.type=="spirit"
	if o.injury!=null:
		var suffix: String=PERSON_SUFFIX[o.injury.name]
		lines.append(opening_copy("diary.injury.health."+suffix if o.injury.type=="health" else ("diary.injury.spirit.luo.beam" if luo_shock else "diary.injury.spirit."+suffix)))
	if int(o.choice)==1 and not luo_shock:lines.append(opening_copy("diary.rope_shock"))
	var meal: String=("food_wood" if a.wood>0 else "food_no_wood") if a.rice>0 else ("no_food_wood" if a.wood>0 else "no_food_no_wood")
	lines.append(opening_copy("diary.meal."+meal))
	var vessel: String="both" if a.tools.bucket and a.tools.canteen else ("bucket" if a.tools.bucket else ("canteen" if a.tools.canteen else "pot_only"))
	lines.append(opening_copy("diary.vessel."+vessel))
	if a.water>0:lines.append(opening_copy("diary.water.some"))
	var bird=opening_bird(o)
	if a.poultry!=null and bird!=null:lines.append(opening_copy("diary.bird."+bird.id+"."+bird.suffix))
	for key in ["news","shoe","end"]:lines.append(opening_copy("diary."+key))
	return lines.filter(func(x):return not str(x).is_empty())
func opening_asset_copy(prefix: String="count.assets") -> String:
	var o: Dictionary=state.memory.opening
	if o.loss!=null:
		return opening_copy(prefix+(".loss_rope." if o.loss.id=="rope" else ".loss.")+PERSON_SUFFIX[o.loss.owner])
	if o.gain in ["rice","wood"]:return opening_copy(prefix+"."+o.gain)
	return opening_copy(prefix+(".unchanged" if not o.items.is_empty() else ".empty"))
func opening_arrival_copy() -> Array:
	return [opening_copy("arrive.01"),opening_copy("count.wood."+str(int(state.memory.opening.choice))),opening_asset_copy(),opening_copy("count.end")].filter(func(x):return not str(x).is_empty())

# Health and treatment rules, ported from src/systems/health.js.
const AILMENT_TYPES=["cold","wound","nutrition"]
const AILMENT_LABELS={"cold":"受寒","wound":"外伤","nutrition":"营养虚弱"}
const MEDICINE_NAMES={"bandage":"绷带","herbs":"草药","medkit":"常备药包","gooseEgg":"鹅蛋"}
func present(person: String) -> bool:
	var p: Dictionary=state.people.get(person,{})
	return p.get("alive",false) and not p.get("away",false) and not p.get("permanentLost",false) and p.get("detainedUntil")==null
func ensure_ailments() -> Dictionary:
	if not state.has("ailments"):state.ailments={}
	if not state.has("ailmentMeta"):state.ailmentMeta={}
	for person in PEOPLE:
		if not state.ailments.has(person):state.ailments[person]={}
		if not state.ailmentMeta.has(person):state.ailmentMeta[person]={}
		for type in AILMENT_TYPES:state.ailments[person][type]=clampf(float(state.ailments[person].get(type,0)),0,3)
	return state.ailments
func change_ailment(person: String,type: String,amount: float) -> Variant:
	if person not in PEOPLE or type not in AILMENT_TYPES or not present(person):return false
	var ailments: Dictionary=ensure_ailments()[person];var before: float=ailments[type]
	ailments[type]=clampf(before+amount,0,3)
	if ailments[type]!=before:
		var source: String=state.phase
		if state.phase in ["night","nightEvent"]:source=_object(state.get("nightCycle")).get("id",state.phase)
		elif state.phase in ["event","focusEvent"]:source=str(state.focus.eventId) if state.focus.eventId!=null and str(state.focus.eventId)!="" else state.phase
		state.ailmentMeta[person][type]={"lastChangedDay":state.day,"sourceEventId":source,"resolved":ailments[type]==0}
	return ailments[type]
func care_target() -> String:
	var people: Array=PEOPLE.filter(func(p):return present(p))
	people.sort_custom(func(a,b):return PEOPLE.find(a)<PEOPLE.find(b) if state.people[a].health==state.people[b].health else state.people[a].health<state.people[b].health)
	return people[0] if not people.is_empty() else "罗瑾"
func treatment_options() -> Array:
	var rows: Array=[]
	for person in PEOPLE:
		if not present(person):continue
		var a: Dictionary=ensure_ailments()[person]
		if a.wound>0 and tool_available("bandage"):rows.append({"value":"bandage|"+person,"label":"用绷带处理"+person+"的外伤"})
		if a.cold>0 and tool_available("herbs"):rows.append({"value":"herbs|"+person,"label":"用草药处理"+person+"的受寒"})
		if a.nutrition>0 and tool_available("gooseEgg"):rows.append({"value":"gooseEgg|"+person,"label":"把鹅蛋给"+person+"调养营养病症"})
		if AILMENT_TYPES.any(func(t):return a[t]>0) and tool_available("medkit"):rows.append({"value":"medkit|"+person,"label":"用常备药包处理"+person})
	if tool_available("gooseEgg") and not rows.any(func(x):return x.value.begins_with("gooseEgg|")):
		var people: Array=PEOPLE.filter(func(p):return present(p) and state.people[p].health<10)
		people.sort_custom(func(a,b):return PEOPLE.find(a)<PEOPLE.find(b) if state.people[a].health==state.people[b].health else state.people[a].health<state.people[b].health)
		if not people.is_empty():rows.append({"value":"gooseEgg|"+people[0],"label":"把鹅蛋给"+people[0]+"补养身体"})
	return rows
func set_night_treatment(value: Variant) -> bool:
	if uses_current_diet():
		if not night_plan_editable():state.error="现在不能改动今晚用药；已确认的夜晚保留原安排。";return false
		if not value is String or (value!="none" and not treatment_options().any(func(option):return option.value==value)):
			state.error="这个用药选项已经不可用，原安排未被替换；请取消原安排或重新选择。";return false
	state.night.treatment=value if value is String and treatment_options().any(func(x):return x.value==value) else "none"
	if uses_current_diet():state.error=null
	return true
func validate_treatment() -> bool:
	var value: String=state.night.get("treatment","none")
	if value=="" or value=="none":return true
	if not treatment_options().any(func(x):return x.value==value):state.error="原先准备的治疗已经不再可用，请重新选择。";return false
	return true
func apply_medicine(id: String,person: String,reserved:=false) -> bool:
	var c: Dictionary=_object(state.get("nightCycle"))
	var paid: bool=reserved and c.get("status")=="settling" and c.get("treatment")==id+"|"+person
	if (reserved and not paid) or (paid and (c.get("treatmentSettled",false) not in [false,null,""])) or (not paid and not tool_available(id)) or not present(person):return false
	var a: Dictionary=ensure_ailments()[person];var before: Dictionary=a.duplicate();var health: float=state.people[person].health
	match id:
		"bandage":
			if a.wound==0:return false
			change_ailment(person,"wound",-1)
		"herbs":
			if a.cold==0:return false
			change_ailment(person,"cold",-1)
		"gooseEgg":
			if a.nutrition==0 and health>=10:return false
			if a.nutrition>0:change_ailment(person,"nutrition",-1)
			state.people[person].health=clampf(health+1,0,10)
		"medkit":
			if not AILMENT_TYPES.any(func(t):return a[t]>0):return false
			for type in AILMENT_TYPES:change_ailment(person,type,-2)
			state.people[person].health=clampf(health+1,0,10)
		_:return false
	if not paid:state.tools[id]=false
	else:c.treatmentSettled="used"
	var results: Array=[]
	for type in AILMENT_TYPES:
		if a[type]<before[type]:results.append(AILMENT_LABELS[type]+("症状消退" if a[type]==0 else "有所减轻"))
	if state.people[person].health>health:results.append("身体也恢复了一些")
	state.nightResults.append(person+"用过"+MEDICINE_NAMES[id]+"，今晨"+"，".join(results)+"。")
	return true
func apply_planned_treatment(reserved:=false) -> bool:
	var value: String=state.night.get("treatment","none")
	if value=="" or value=="none":return false
	var parts:=value.split("|");var id: String=parts[0];var person: String=parts[1] if parts.size()>1 else ""
	var done:=apply_medicine(id,person,reserved);var c: Dictionary=_object(state.get("nightCycle"))
	if not done and reserved and c.get("status")=="settling" and not (c.get("treatmentSettled",false) not in [false,null,""]):
		c.treatmentSettled="returned"
		if state.tools.get(id,false):
			state.rice+=1;state.nightResults.append("预留给"+person+"的"+MEDICINE_NAMES[id]+"未用上；同类物品已经补回，这一份按多余物品规则换成米粮×1。")
		else:
			state.tools[id]=true;state.nightResults.append("预留给"+person+"的"+MEDICINE_NAMES[id]+"未用上，物品已放回，没有产生治疗效果。")
	state.night.treatment="none"
	return done
func progress_ailments() -> void:
	ensure_ailments()
	for person in PEOPLE:
		if not present(person):continue
		var a: Dictionary=state.ailments[person];var p: Dictionary=state.people[person];var care: Dictionary=_object(state.get("nightCycle")).get("survivalCare",{})
		if state.balanceVersion=="I2f" and care.get("water",false) and person in care.get("fed",[]) and care.get("pressure",2)<=1 and a.cold==1 and state.ailmentMeta[person].get("cold",{}).get("lastChangedDay",-1)!=state.day and random_value()<0.35:
			change_ailment(person,"cold",-1);state.nightResults.append(person+"这一夜吃过饭、没有再受寒，轻微的受寒症状缓了下来。")
		var eligible: Array=AILMENT_TYPES.filter(func(t):return a[t]>0 and a[t]<3 and state.ailmentMeta[person].get(t,{}).get("lastChangedDay",-1)!=state.day)
		if not eligible.is_empty() and random_value()<(0.20 if p.health<=5 else 0.10):
			var type: String=pick(eligible);change_ailment(person,type,1);state.nightResults.append(person+"的"+AILMENT_LABELS[type]+"又重了一些"+("，暂时不能出工" if a[type]==3 else "")+"。")
		var burden: float=a.cold+a.wound+a.nutrition
		var established: Array=AILMENT_TYPES.filter(func(t):return a[t]>=3 and state.ailmentMeta[person].get(t,{}).get("lastChangedDay",-1)!=state.day)
		if burden>=4 or (not established.is_empty() and random_value()<0.30):
			p.health=clampf(float(p.health)-1,0,10);state.nightResults.append(person+"的伤病仍在拖累身体，今晨更显虚弱。")
		if a.cold>=3 and random_value()<0.35:change_spirit(person,-1);state.nightResults.append(person+"受寒严重，难受得没能睡安稳。")
func settle_water_exposure(c: Dictionary) -> void:
	var e: Dictionary=c.get("waterExposure",{}) if c.get("waterExposure")!=null else {}
	if e.is_empty() or e.day!=c.day or c.get("waterExposureSettled",false):return
	c.waterExposureSettled=true
	if not c.get("householdWater",c.cost.water):state.nightResults.append("没有喝到白天留下的那份水；这次不判饮水后的不适，缺水仍按实际情况结算。");return
	var affected: Array=[]
	for person in PEOPLE:
		if not present(person):continue
		var chance: float=(0.05 if e.mode=="boiled" else 0.25)+(0.10 if state.people[person].health<=5 else 0.0)
		if random_value()<chance:state.people[person].health=clampf(float(state.people[person].health)-1,0,10);affected.append(person)
	state.nightResults.append("、".join(affected)+"喝过白天留下的水后，今晨腹部不适，身体虚弱了一些。家人仍说不准水中究竟有什么。" if not affected.is_empty() else "喝过白天留下的那份水后，今晨暂时没有人诉说新的不适；这并不能证明它一直安全。")
	state.history.append({"day":c.day,"type":"water-exposure","id":c.id+":water","mode":e.mode,"affected":affected})

const HUNGER_REVISION="A3c-person-v1"
const SHELTER_MAINTENANCE_REVISION="A3c-day-maintenance-v1"
const HUNGER_RISK_TABLE={"安仁叔叔":[0,0.15,0.40,0.75],"母亲":[0,0.25,0.55,0.85],"罗瑾":[0,0.35,0.70,0.95],"外祖父":[0.05,0.45,0.80,1]}
func current_weather(offset:=0) -> Dictionary:
	return state.weatherPlan[clampi(int(state.day)+offset,0,49)]
func shelter_cold_mod(value: float=-1) -> int:
	if value<0:value=state.shelter
	return -1 if value>=41 else (0 if value>=31 else (1 if value>=21 else (2 if value>=11 else (3 if value>0 else 4))))
func hunger_records(revision: String="") -> Dictionary:
	if revision=="":revision=current_hunger_revision()
	if uses_current_diet() and revision=="A1":return ensure_current_diet().get("records",{})
	var key: String="hungerA1" if revision=="A1" else "hungerA3cPersonV1"
	if not state.memory.has(key):state.memory[key]={}
	return state.memory[key]
func hunger_previous(person: String,revision: String="") -> Variant:
	if revision=="":revision=current_hunger_revision()
	if uses_current_diet() and revision=="A1":return diet_previous(person)
	var records:=hunger_records(revision)
	if records.has(person):return records[person]
	if revision!="A1":
		var legacy: Dictionary=state.memory.get("hungerA1",{}).get(person,{})
		if legacy.get("day",-100)==state.day-1:return legacy
	return null
func hunger_risk(person: String,count: int,revision: String="") -> float:
	if revision=="":revision=current_hunger_revision()
	if count==0:return 0
	var row: Array=[0.5,0.75,0.9,1] if revision=="A1" else HUNGER_RISK_TABLE.get(person,[0,0.25,0.55,0.85])
	return float(row[mini(count,4)-1])
func hunger_roll(person: String,revision: String="") -> float:
	if revision=="":revision=current_hunger_revision()
	return float(RNG.hash_seed(state.seed+":hunger:"+revision+":"+str(int(state.day))+":"+person))/4294967296.0
func settle_hunger(hungry: Array,revision: String="") -> Array:
	if revision=="":revision=current_hunger_revision()
	if uses_current_diet() and revision=="A1":return settle_current_hunger(hungry)
	var records:=hunger_records(revision);var lines: Array=[]
	for person in PEOPLE:
		if not present(person):continue
		if records.get(person,{}).get("day",-100)==state.day:continue
		var old=hunger_previous(person,revision);var missed: bool=person in hungry
		var count: int=(int(old.count)+1 if old!=null and old.day==state.day-1 else 1) if missed else 0
		var risk:=hunger_risk(person,count,revision);var hurt: bool=missed and hunger_roll(person,revision)<risk
		records[person]={"day":state.day,"count":count,"risk":risk,"hurt":hurt,"revision":revision}
		if hurt:
			state.people[person].health=clampf(float(state.people[person].health)-1,0,10)
			lines.append(person+("又" if count>1 else "")+"空着肚子过了一夜，身体更虚弱了。")
	return lines
func project_shelter_night(gain: float,damage: float) -> Dictionary:
	var n: Dictionary=state.night;var w:=current_weather(1);var repaired:=clampf(float(state.shelter)+gain,0,50)
	var influx: float=w.wet-w.dry
	if w.wet>0 and repaired>=41:influx-=1
	if w.wet>0 and repaired<20:influx+=1
	if w.wet>0 and state.shelterItems.oilcloth:influx-=1
	var moisture:=clampf(float(state.moisture)+influx-(1 if n.fire>=2 or (n.fire==1 and w.wet==0) else 0),0,3)
	var shelter:=clampf(repaired-damage,0,50)
	var pressure: float=w.cold+w.wind+shelter_cold_mod(shelter)+(2 if moisture>=3 else (1 if moisture>=2 else 0))-(1 if state.shelterItems.bedding else 0)-(1 if state.shelterItems.mat and moisture>=2 else 0)-n.fire
	return {"weather":w,"moisture":moisture,"shelter":shelter,"pressure":pressure}
func cooking_chance() -> float:
	var n: Dictionary=state.night;var w:=current_weather(1)
	if not n.meal or n.fire<1:return 0
	var chance:=0.9
	if state.moisture>=2:chance-=0.12
	if state.moisture>=3:chance-=0.1
	if w.wet>=2:chance-=0.1
	if n.fire>=2:chance+=0.08
	if state.shelter>=41:chance+=0.04
	return clampf(chance,0.45,0.98)
func formal_repair_gain(day: int=-1,actor: String="family") -> int:
	if day<0:day=int(state.day)
	return 10 if float(RNG.hash_seed(state.seed+":day-repair:"+SHELTER_MAINTENANCE_REVISION+":"+str(day)+":"+actor))/4294967296.0<0.25 else 8
func spirit_book() -> Dictionary:
	if not state.memory.has("a3cT3"):state.memory.a3cT3={"revision":"A3c-T3-v1","knowledge":[],"spirit":[],"death":{}}
	return state.memory.a3cT3
func knows_fact(person: String,fact_id: String,scope: String="") -> bool:
	return spirit_book().knowledge.any(func(x):return x.person==person and x.factId==fact_id and (scope=="" or x.scope==scope))
func apply_spirit_fact(effect: Dictionary) -> bool:
	var fact_id: String=effect.get("factId","");var person: String=effect.get("person","");var source: String=effect.get("source","")
	var domain: String=effect.get("domain","spirit");var subfact: String=effect.get("subfact","primary")
	var amount: float=float(effect.get("amount",NAN));var cap_loss: float=float(effect.get("capLoss",0))
	if fact_id=="" or source=="" or person not in PEOPLE or not is_finite(amount) or not is_finite(cap_loss) or cap_loss<0:
		push_error("精神事实合同不完整");return false
	var book:=spirit_book();var key:=JSON.stringify([fact_id,person,domain,subfact])
	if book.spirit.any(func(x):return x.key==key) or not state.people[person].alive or state.people[person].get("permanentLost",false):return false
	if effect.get("requiresKnowledge",false) and not knows_fact(person,fact_id,effect.get("knowledgeScope","")):return false
	var p: Dictionary=state.people[person];var before={"spirit":p.spirit,"spiritMax":p.get("spiritMax",10)}
	p.spiritMax=maxf(1,float(p.get("spiritMax",10))-cap_loss);change_spirit(person,amount)
	book.spirit.append({"key":key,"factId":fact_id,"person":person,"domain":domain,"subfact":subfact,"source":source,"amount":amount,"capLoss":cap_loss,"before":before,"after":{"spirit":p.spirit,"spiritMax":p.spiritMax},"day":state.day+1,"phase":state.phase})
	return true

func expedition_window(person: String) -> String:
	var opportunity: Dictionary=_object(state.memory.get("expeditionOpportunity"))
	if state.day>42:return "closed"
	if state.day>=27:return "stable"
	if state.day>=21 and opportunity.get("name")==person and not js_truthy(opportunity.get("used")) and opportunity.get("expiresDay",-1)>=state.day and js_truthy(opportunity.get("sourceEventId")):return "temporary"
	return "locked"

func character_rest_reason(person: String) -> String:
	if person=="母亲" and _object(state.memory.get("motherCrisisR4a")).get("restUntil",-1)>=state.day+1:return "母亲今天留棚恢复，暂不承担出工或远行"
	if person=="安仁叔叔" and _object(state.memory.get("uncleCrisisR4b")).get("restUntil",-1)>=state.day+1:return "叔叔今天留棚养伤，暂不出工或远行"
	return ""
func departure_block(person: String) -> String:
	if person not in ["母亲","安仁叔叔","外祖父"]:return "罗瑾不参加基础远行；他的后期主要行动仍在照相馆与既有剧情里。"
	var window:=expedition_window(person)
	if window=="locked":return "普通远行从第28日起开放；更早须有已发生的临时机会。"
	if window=="closed":return "已过第43日；新的七日远行链来不及在终局前结束。"
	if state.expedition.active!=null:return "已有一名家人远行未归。"
	if not present(person):return "本人当前不在家。"
	var reason:=character_rest_reason(person)
	if reason!="":return reason
	var p: Dictionary=state.people[person]
	if p.health<=3 or p.spirit<=1 or state.ailments.get(person,{}).values().any(func(x):return x>=3):return "身体或精神已难以支撑远行，先处理伤病与休息。"
	if current_weather(1).id in ["blizzard","hail"]:return "即将遇到的极端天气不宜出发，今晚暂不远行。"
	return ""
func night_people() -> Array:
	var plan: Dictionary=state.expedition.plan if state.expedition.plan!=null else {}
	return PEOPLE.filter(func(person):return present(person) and not (plan.get("name")==person and departure_block(person)==""))
func meal_recipients() -> Array:
	return night_people().filter(func(person):return state.memory.get("ateOutsideDay",{}).get(person,-1)!=state.day)
func expedition_reservation() -> Dictionary:
	var p=state.expedition.plan
	if p==null or departure_block(p.name)!="":return {"rice":0,"water":0,"spill":0,"capacityDrop":0}
	var rice: int=1 if p.rice==1 else 0
	var water_amount: float=clampf(float(p.water),0,3) if typeof(p.water) in [TYPE_FLOAT,TYPE_INT] and is_finite(float(p.water)) and floor(float(p.water))==float(p.water) else 0
	var drop: float=minf(3,maxf(0,float(state.waterCap)-4)) if "canteen" in p.tools else 0
	var home_water: int=1 if state.water>water_amount else 0
	return {"rice":rice,"water":water_amount,"capacityDrop":drop,"spill":maxf(0,float(state.water)-water_amount-home_water-(float(state.waterCap)-drop))}
func repair_plan(legacy:=false) -> Dictionary:
	var people:=night_people()
	var enabled: bool=legacy and state.night.repair and state.shelter<50 and not people.is_empty()
	var result={"enabled":enabled,"wood":1 if enabled and state.wood>state.night.fire else 0}
	# JavaScript omits undefined actor from JSON when nobody is present.
	if not people.is_empty():result.actor="外祖父" if "外祖父" in people else people[0]
	return result
func preview_night() -> Dictionary:
	var w:=current_weather(1);var repair:=repair_plan(false);var shield: int=2 if state.shelterItems.oilcloth and w.wet>0 else 0
	var low:=project_shelter_night(0,maxf(0,float(w.damage[1])-shield));var high:=project_shelter_night(0,maxf(0,float(w.damage[0])-shield))
	var expedition:=expedition_reservation();var household_water: int=1 if state.water>expedition.water else 0
	var feed_cost: int=(1 if state.night.feedPoultry else 0)+(1 if state.night.feedPet else 0)
	low.merge({"shelterRange":[low.shelter,high.shelter],"pressureRange":[high.pressure,low.pressure],"moistureRange":[high.moisture,low.moisture],"repair":repair,"expedition":expedition,"householdWater":household_water,"cost":{"rice":(1 if state.night.meal else 0)+feed_cost+expedition.rice,"water":household_water+expedition.water+expedition.spill,"wood":state.night.fire+repair.wood}})
	return low
func validate_night_plan() -> bool:
	if uses_current_diet():
		var pigeon:=pigeon_plan_status()
		if night_plan_editable() and pigeon.selected and not pigeon.valid:state.error=pigeon.reason+"请先取消原求助或取物安排；未扣除物资。";return false
		for slot in ["poultry","pet"]:
			var feed:=feed_plan_status(slot)
			if feed.selected and not feed.valid:state.error=feed.reason+"请先取消原补喂安排；未扣除物资。";return false
	var n: Dictionary=state.night;var p:=preview_night()
	if n.meal and n.fire==0:state.error="开伙需要至少生一份火；也可以只生火而不开伙。";return false
	if p.cost.rice>state.rice:state.error="今晚需要米粮"+str(int(p.cost.rice))+"份，但家里只剩"+str(int(state.rice))+"份。";return false
	if p.cost.wood>state.wood and n.fire>state.wood:state.error="生火需要木料"+str(int(n.fire))+"份，但家里只剩"+str(int(state.wood))+"份。";return false
	if not validate_treatment():return false
	var tool: String=n.treatment.split("|")[0] if n.get("treatment","none") not in ["","none"] else ""
	if tool!="" and state.expedition.plan!=null and tool in state.expedition.plan.tools:
		state.error=MEDICINE_NAMES.get(tool,tool)+"不能同时带去远行并留在家里治疗。";return false
	state.error=null
	return true
func random_int(minimum: int,maximum: int) -> int:
	return minimum+int(floor(random_value()*(maximum-minimum+1)))
func _survival_spend(key: String,amount: float,prepaid: Variant) -> void:
	if prepaid!=null:return
	state[key]=maxf(0,float(state[key])-amount);state.deltas[key]-=amount
func _survival_spirit(person: String,kind: String,amount: float,domain: String) -> void:
	apply_spirit_fact({"factId":state.seed+":night:"+str(int(state.day))+":"+kind,"person":person,"amount":amount,"source":"survival:"+kind,"domain":domain})
func _settle_survival_core(prepaid: Variant=null) -> Array:
	var n: Dictionary=state.night;var w:=current_weather(1);var lines: Array=[];var hungry: Array=[]
	if prepaid==null:state.deltas={"rice":0,"water":0,"wood":0}
	var revision: String=prepaid.get("hungerRevision",current_hunger_revision()) if prepaid!=null else current_hunger_revision()
	var modern: bool=revision in ["A1",HUNGER_REVISION]
	if n.meal:
		_survival_spend("rice",1,prepaid)
		var roll:=random_value();var chance:=cooking_chance();var recipients:=meal_recipients()
		if roll<chance:
			var recovery: int=2 if recipients.size()<4 else 1
			for person in recipients:_survival_spirit(person,"meal",recovery,"bodily-recovery")
			lines.append("家里开了伙，今晚需要用饭的家人吃到了热饭"+("；人少以后，同样一份粮让每个人都吃得更实在" if recipients.size()<4 else "")+"。")
		elif roll<minf(0.98,chance+0.22):lines.append("柴和米都用上了，但潮气使火候断断续续；这顿饭勉强做熟，没有带来额外恢复。")
		else:
			hungry.append_array(recipients)
			if not modern:
				for person in recipients:state.people[person].health=clampf(float(state.people[person].health)-1,0,10)
			lines.append("火被潮气压灭了几次，米已经用掉，饭却没有真正做成。" if modern else "火被潮气压灭了几次，米已经用掉，饭却没有真正做成；留在棚里的人健康下降。")
	else:
		hungry.append_array(meal_recipients())
		if not modern:
			for person in meal_recipients():state.people[person].health=clampf(float(state.people[person].health)-1,0,10)
		lines.append("家里没有开伙，没有在外吃过饭的家人饿着肚子过了夜。" if modern else "家里没有开伙，没有在外吃过饭的家人饿着肚子过了夜，身体更虚弱了。")
	if modern:lines.append_array(settle_hunger(hungry,revision))
	var water_available: bool=prepaid.get("householdWater",prepaid.cost.water)>0 if prepaid!=null else state.water>0
	if water_available:_survival_spend("water",1,prepaid)
	else:
		for person in PEOPLE:
			if not present(person):continue
			state.people[person].health=clampf(float(state.people[person].health)-1,0,10);_survival_spirit(person,"water",-1,"bodily-shortage")
		lines.append("饮水已经见底，留在棚里的人健康和精神都受到影响。")
	var fire: float=n.fire
	if fire>0:
		_survival_spend("wood",fire,prepaid)
		lines.append("家里多烧了一份木料，尽量抵住这一夜的寒意。" if fire==2 else ("做饭以后，余火仍留在棚中取暖。" if n.meal else "家里没有做饭，只把火生起来取暖和驱潮。"))
	var legacy_repair: bool=prepaid!=null and prepaid.get("shelterMaintenanceRevision")!=SHELTER_MAINTENANCE_REVISION
	var repair: Dictionary=prepaid.get("repair",repair_plan(true)) if legacy_repair else repair_plan(false)
	var gain:=0
	if legacy_repair and n.repair and state.shelter<50 and not night_people().is_empty():
		if repair.wood>0:
			gain=10 if random_value()<0.25 else 8;lines.append(repair.actor+"加固了草棚，用去木料×1。")
		else:
			gain=3 if random_value()<0.35 else 2;lines.append(repair.actor+"重新压紧现有支撑；没有添木料，草棚只略微加固。")
	var damage: int=maxi(0,random_int(int(w.damage[0]),int(w.damage[1]))-(2 if state.shelterItems.oilcloth and w.wet>0 else 0)) if w.damage[1]>0 else 0
	var projected:=project_shelter_night(gain,damage);state.shelter=projected.shelter;state.moisture=projected.moisture
	if damage>0:lines.append("恶劣天气使草棚受损"+("（耐久－"+str(damage)+"）" if state.test else "")+"。")
	var pressure: float=projected.pressure
	if prepaid!=null:prepaid.survivalCare={"pressure":pressure,"fed":meal_recipients().filter(func(person):return person not in hungry),"water":prepaid.get("householdWater",0)>0}
	if pressure<=0 and not _object(state.get("nightCycle")).get("disturbed",false):
		var candidates: Array=PEOPLE.filter(func(person):return present(person) and state.people[person].spirit<state.people[person].get("spiritMax",10))
		if not candidates.is_empty():
			var person: String=pick(candidates);_survival_spirit(person,"sleep",1,"bodily-recovery");lines.append(person+"这一夜睡得很沉，醒来时状态好了一些。")
	elif pressure>=2:
		for person in PEOPLE:
			if not present(person):continue
			var chance: float=(0.10 if pressure==2 else (0.20 if pressure==3 else 0.35)) if state.balanceVersion=="I2f" else (0.2 if pressure==2 else (0.35 if pressure==3 else 0.6))
			if state.people[person].health<=5:chance+=0.08 if state.balanceVersion=="I2f" else 0.15
			if random_value()<chance:
				change_ailment(person,"cold",1)
				if pressure>=4:state.people[person].health=clampf(float(state.people[person].health)-1,0,10)
				lines.append(person+"在"+("寒冷和潮湿" if state.moisture>=2 else "寒冷")+"中受了寒。")
	if state.day>=7:
		for person in hungry:
			var rec: Dictionary=hunger_records(revision).get(person,{})
			var count: int=int(rec.get("count",0)) if rec.get("day",-1)==state.day else 0
			var existing: bool=state.ailments[person].nutrition>0
			if state.people[person].health<=5 and state.ailments[person].nutrition<3 and (revision=="A1" or existing or count>=2) and random_value()<0.15:
				change_ailment(person,"nutrition",1);lines.append(person+"原本已经虚弱，这次又没吃上东西，营养虚弱的症状"+("加重" if state.ailments[person].nutrition>1 else "开始显现")+"。")
	return lines

const FEED_CYCLE={"cat":5,"dog":3,"goose":4,"pigeon":5}
func animal_name(animal: Variant) -> String:
	return {"cat":"猫","dog":"狗","goose":"母鹅","pigeon":"信鸽"}.get(animal.get("type","") if animal!=null else "","")
func animal_at_home(slot: String) -> bool:
	var a=state.animals.get(slot)
	return a!=null and not (a.type=="pigeon" and a.sent and (not a.resolved or a.get("outcome")=="no_reply"))
func pigeon_request() -> Variant:
	var a=state.animals.poultry
	return a if a!=null and a.type=="pigeon" else state.memory.get("pigeonRequest")
func lose_animal(slot: String,reason: String) -> bool:
	if not animal_at_home(slot):return false
	var a: Dictionary=state.animals[slot]
	if a.type=="pigeon" and a.resolved and a.pickup and not a.pickupDone:state.memory.pigeonRequest=a.duplicate(true)
	if not state.memory.has("animalLosses"):state.memory.animalLosses=[]
	state.memory.animalLosses.append({"type":a.type,"day":state.day,"reason":reason});state.animals[slot]=null
	return true
func needs_animal_care(slot: String) -> bool:
	return state.animals.get(slot)!=null and animal_at_home(slot) and state.animals[slot].get("remaining",0)<=0
func feed_animal(slot: Variant) -> bool:
	if uses_current_diet():
		if not night_plan_editable():state.error="现在不能改动补喂安排；已确认的夜晚保留原安排。";return false
		if not slot is String or slot not in ["poultry","pet"]:state.error="无法识别补喂对象，未改变安排。";return false
		var flag: String="feedPoultry" if slot=="poultry" else "feedPet"
		if state.night[flag]:state.night[flag]=false;state.error=null;return true
		var view:=feed_plan_status(slot)
		if not view.valid:state.error=view.reason+"未新增补喂安排。";return false
	if not slot is String or state.phase!="night" or state.animals.get(slot)==null or not needs_animal_care(slot):return false
	var key: String="feedPoultry" if slot=="poultry" else "feedPet"
	state.night[key]=not state.night[key];state.error=null;return true
func pigeon_action_allowed(value: String) -> bool:
	var a=pigeon_request()
	if state.phase!="night" or state.get("features",{}).get("animals",true)==false or a==null or a.type!="pigeon":return false
	if value=="send":return not a.sent and state.day>=4 and state.day<=44
	return a.pickup and not a.pickupDone and state.day<a.pickupDeadline and value in ["collect","delay"]
func set_pigeon_action(value: Variant) -> bool:
	if uses_current_diet():
		if not night_plan_editable():state.error="现在不能修改求助或取物安排；已经确认的夜晚保留原结果。";return false
		if value is String and (value=="none" or (value in ["send","collect","delay"] and state.night.pigeonAction==value)):
			state.night.pigeonAction="none";state.error=null;return true
		if not value is String or value not in ["send","collect","delay"] or not pigeon_action_allowed(value):
			state.error="这项求助或取物选择目前不可用，原安排未被替换；可以先取消原安排。";return false
	if not value is String or not pigeon_action_allowed(value):return false
	state.night.pigeonAction="none" if state.night.pigeonAction==value else value;return true
func pigeon_chance(a: Dictionary) -> float:
	return 0.90 if a.get("remaining",0)>0 else (0.65 if a.get("hunger",0)<=1 else 0.40)
func settle_pigeon_care(flag: bool,lines: Array,prepaid:=false) -> void:
	var a=state.animals.poultry
	if a==null or a.type!="pigeon" or not animal_at_home("poultry"):return
	var feed: bool=flag and a.get("remaining",0)<=0
	if feed:
		if not prepaid:
			if state.rice<1:return
			state.rice-=1;state.deltas.rice-=1
		a.remaining=FEED_CYCLE.pigeon;a.hunger=0
		lines.append("给信鸽喂过，又另包好几夜的米粮。它低头啄食，家里没有将吃过这一回当作传信一定能成的保证。")
	elif a.get("remaining",0)<=0:a.hunger=a.get("hunger",0)+1
func finish_pigeon_care_night() -> void:
	var a=state.animals.poultry
	if a!=null and a.type=="pigeon" and animal_at_home("poultry") and a.get("remaining",0)>0:a.remaining-=1
func settle_one_animal(slot: String,flag: bool,lines: Array,prepaid:=false) -> void:
	var a=state.animals.get(slot)
	if a==null or not animal_at_home(slot):return
	if a.type=="pigeon":
		if _object(state.get("nightCycle")).get("pigeonCareDone",false):return
		settle_pigeon_care(flag,lines,prepaid);return
	var feed: bool=flag and a.get("remaining",0)<=0
	if feed and not prepaid and state.rice<1:return
	var fed: bool=feed or a.get("remaining",0)>0;var old_relation: float=a.relation
	if feed:
		if not prepaid:state.rice-=1;state.deltas.rice-=1
		a.remaining=FEED_CYCLE[a.type]-1;a.hunger=0;a.relation=clampf(float(a.relation)+1,0,3)
		lines.append(animal_name(a)+"吃过了，余下的粮另包好，接下来几夜不必再喂。")
	elif a.remaining>0:a.remaining-=1;a.hunger=0
	else:
		a.hunger=a.get("hunger",0)+1
		if int(a.hunger)%2==0:a.relation=clampf(float(a.relation)-1,0,3)
	if a.relation<old_relation:lines.append(animal_name(a)+"这几夜没吃到东西，渐渐不肯靠近了。")
	if a.type=="goose":
		if feed and a.relation>=2 and not state.tools.gooseEgg:
			a.feedsAfterEgg=a.get("feedsAfterEgg",0)+1
			if a.feedsAfterEgg>=(2 if a.relation>=3 else 3):
				a.feedsAfterEgg=0;state.tools.gooseEgg=true;lines.append("母鹅产下一枚鹅蛋；家里只能保存一枚。")
		return
	if a.type=="cat" and random_value()<[0,0.10,0.20,0.30][int(a.relation)]*(1.0 if fed else 0.5):
		var candidates: Array=PEOPLE.filter(func(person):return present(person) and state.people[person].spirit<state.people[person].spiritMax)
		candidates.sort_custom(func(x,y):return PEOPLE.find(x)<PEOPLE.find(y) if state.people[x].spirit==state.people[y].spirit else state.people[x].spirit<state.people[y].spirit)
		if not candidates.is_empty():
			var person: String=candidates[0];change_spirit(person,1);lines.append("猫在"+person+"身边伏了一阵，那人伸手摸了摸它，神色稍缓。")
	a.guardTonight=a.type=="dog" and a.relation>0
func pet_effect_strength(a: Variant) -> float:
	if a==null:return 0
	return 1.0 if a.get("fedTonight",a.get("remaining",0)>0) else 0.5
func night_animal_view(slot: String) -> Variant:
	var a=state.animals.get(slot)
	if a==null:return null
	var c: Dictionary=_object(state.get("nightCycle"))
	if c.is_empty() or c.day!=state.day or c.status=="settled":return a
	var fed: bool=c.plan.feedPet if slot=="pet" else c.plan.feedPoultry
	var relation:=clampf(float(a.relation)+(1 if fed and a.type!="pigeon" else 0),0,3)
	var result: Dictionary=a.duplicate(true)
	result.merge({"relation":relation,"remaining":FEED_CYCLE[a.type]-1 if fed and a.type!="pigeon" else a.get("remaining",0),"fedTonight":fed or a.remaining>0,"guardTonight":a.type=="dog" and relation>0},true)
	return result
func mouse_chance() -> float:
	var a=night_animal_view("pet");var strength:=pet_effect_strength(a)
	var relation: int=clampi(int(a.get("relation",0)),0,3) if a!=null else 0
	var reduction: float=([0,0.25,0.60,0.95][relation] if a.type=="cat" else ([0,0.05,0.10,0.20][relation] if a.type=="dog" else 0)) if a!=null else 0
	return 0.10*(1-reduction*strength)
func commit_pigeon_send() -> void:
	var a=state.animals.poultry
	if state.night.pigeonAction!="send" or a==null or a.type!="pigeon" or a.sent:return
	state.memory.pigeonRouteKnown=true;a.sent=true;a.sentDay=state.day;a.returnDay=state.day+2;a.flightChance=pigeon_chance(a);a.flightRoll=random_value()
	a.outcome=("delivery" if random_value()<0.5 else "stash") if a.flightRoll<a.flightChance else "no_reply"
	state.nightResults.append("天黑以前，家里把信鸽放向熟悉的旧巢。简短的求助已经带走，眼下并没有物资送到；只能等那边是否有人能接上消息。")
func settle_pigeon(lines: Array) -> void:
	var a=pigeon_request();var action: String=state.night.pigeonAction
	if a==null or a.type!="pigeon" or not a.pickup or a.pickupDone:return
	if action=="collect" and state.day<a.pickupDeadline:
		a.pickupPlan={"requestedDay":state.day,"day":state.day+1,"status":"planned"}
		lines.append("昨夜又核对过纸条上的位置，暂定今日由罗瑾去取。能否成行，以今天的实际去向为准；物资尚未取回。")
	elif action=="delay":
		a.pickupPlan=null;lines.append("家里暂未安排取物。纸条仍留着，但对方说过，只能把东西留到第"+str(int(a.pickupDeadline)+1)+"日。")
func settle_animals(prepaid:=false) -> void:
	var lines: Array=[]
	settle_one_animal("poultry",state.night.feedPoultry,lines,prepaid);settle_one_animal("pet",state.night.feedPet,lines,prepaid);settle_pigeon(lines)
	state.nightResults.append_array(lines)

const NIGHT_RESPONSE_REVISION="WebR10-response-v1"
func night_roll(tag: String) -> float:
	return float(RNG.hash_seed(state.seed+":night:"+str(int(state.day))+":"+tag))/4294967296.0
func minor_night_blocked() -> bool:
	var search: Dictionary=_object(_object(state.expedition.get("active")).get("search"))
	return state.ended or state.memory.get("irreversibleTonight",false)==true or state.memory.get("criticalNight",false)==true or int(state.day) in [32,33,34,35,42,43,44,46,47,48] or (search.get("mode")=="luo" and search.get("day")==state.day) or state.focus.get("expeditionSearchResult")!=null

func night_threat_chance() -> Dictionary:
	var dog=night_animal_view("pet");var strength: float=pet_effect_strength(dog) if dog!=null and dog.type=="dog" else 0
	return {"theft":(0.15 if state.day<8 else 0.08)*(1-0.16*(float(dog.relation) if dog!=null else 0)*strength),"robbery":0.08 if state.day<5 else 0.035}
func family_night_kind() -> Variant:
	var history: Array=state.memory.get("nightReadingHistory",[]);var candidates: Array=[];var people: Array=PEOPLE.filter(func(person):return present(person))
	if people.any(func(person):return state.people[person].health<=3 or state.ailments.get(person,{}).values().any(func(v):return v>=3)):candidates.append("care")
	if PEOPLE.any(func(person):return state.people[person].alive and not state.people[person].get("permanentLost",false) and (state.people[person].away or state.people[person].get("detainedUntil")!=null)):candidates.append("absence")
	if state.moisture>=2:candidates.append("damp")
	var prior_hunger:=false
	for person in people:
		var h=hunger_previous(person)
		if h!=null and h.day==state.day-1 and h.count>0:prior_hunger=true;break
	if (not state.night.meal and not meal_recipients().is_empty()) or prior_hunger:candidates.append("hunger")
	for kind in candidates:
		var recent:=false
		for i in range(history.size()-1,-1,-1):
			var row: Dictionary=history[i];var row_kind: String=row.get("familyKind","") if row.get("familyKind")!=null and row.get("familyKind")!="" else row.get("type","")
			if row_kind==kind:recent=state.day-row.day<=3;break
		if not recent:return kind
	return null
func prepare_night_event() -> Variant:
	if state.day==0:return {"type":"theft","title":"棚外有人摸近","text":"脚步在棚外停了下来，有人试着拖动最外侧的粮袋。"}
	if minor_night_blocked():return null
	var chance:=night_threat_chance();var roll:=night_roll("intrusion")
	if roll<chance.robbery:return {"type":"robbery","title":"日本兵进棚翻抢","text":"几名日本兵没有掩饰脚步，直接掀开棚边寻找钱粮。一人的枪口仍朝着棚内。家人无法靠这层棚架挡住他们，硬拦可能招来殴打。"}
	if roll<chance.robbery+chance.theft:return {"type":"theft","title":"黑暗里的手","text":"有人趁棚区安静时摸向粮袋。现在出声，也可能把危险引得更近。"}
	if state.day>=14 and state.rice>0 and state.day-state.memory.get("lastMouseDay",-100)>3 and night_roll("mouse")<mouse_chance():
		state.memory.lastMouseDay=state.day;var first: bool=not state.memory.get("mouseIntroduced",false);state.memory.mouseIntroduced=true
		return {"type":"mouse","contract":"mouse-care-v1","lossRoll":night_roll("mouse-loss"),"title":"粮袋边的新咬痕" if first else "粮袋旁又有动静","text":"粮袋底下落了几粒米，袋角新添了一道细口。把袋子提起来时，棚脚传来一阵急促的窸窣声。好不容易存下的粮，放在身边也还不能全然放心。现在还没有清点出损失；把散米收起、另找地方安放，或许来得及。只是夜已经深了，家里的人也需要歇一歇。" if first else "刚躺下，棚脚便有细碎的抓挠声。粮袋还在原处，贴地的一角有些松了。有人坐起身，把手伸到袋底试了试，随后叫醒身旁的人。把粮挪过来并不难，难的是困得厉害时，还要仔细收好每一粒散米。谁也不能保证，先睡一夜就一定会少东西。"}
	var kind=family_night_kind()
	return {"type":"family","familyKind":kind,"title":"棚里这一夜还有话没有说完","text":""} if kind!=null else null
func strict_night_response() -> bool:
	return _object(state.get("nightCycle")).get("responseRevision")==NIGHT_RESPONSE_REVISION
func night_response_actors() -> Array:
	return PEOPLE.filter(func(person):return present(person) and (not strict_night_response() or state.people[person].health>1))
func night_choice_requirement(choice: String) -> bool:
	var e=state.get("pendingNightEvent")
	if e==null:return false
	var actors:=night_response_actors()
	match e.type:
		"theft":return choice in ["quiet","warn","whistle"] and (choice!="warn" or "安仁叔叔" in actors) and (choice!="whistle" or tool_available("whistle"))
		"robbery":return choice in ["give","resist","animalPoultry","animalPet"] and (choice!="resist" or not strict_night_response() or not actors.is_empty()) and (choice!="animalPoultry" or animal_at_home("poultry")) and (choice!="animalPet" or animal_at_home("pet"))
		"mouse":return choice in ["wait","tidy","move"] and (choice!="move" or tool_available("rope")) and (choice=="wait" or not actors.is_empty())
		"family":return choice=="continue"
	return false

# Mechanical effect stage. R3 narrative capture/locking is wired separately before UI exposure.
func resolve_night_event_effects(choice: String) -> bool:
	var e=state.get("pendingNightEvent");var c=state.get("nightCycle")
	if state.phase!="nightEvent" or e==null or c==null or c.day!=state.day or c.status!="awaiting_event" or not night_choice_requirement(choice):
		state.error="这项夜间应对当前不可用。";return false
	if e.type=="theft":
		if choice=="warn":change_spirit("安仁叔叔",-1);state.nightResults.append("安仁叔叔隔着棚布出声，外面的人最终退开了。")
		elif choice=="whistle":state.nightResults.append("哨声惊醒附近的人，偷偷摸近者立刻离开。")
		else:
			var key: String="rice" if state.rice>0 else "wood"
			if state[key]>0:
				state[key]-=1;state.nightResults.append("夜里有人摸走了"+("米粮" if key=="rice" else "木料")+"×1。")
			else:state.nightResults.append("来人翻动了棚边的东西，没有找到能够拿走的米粮或木料。")
	elif e.type=="robbery":
		if choice=="give":
			var dog=night_animal_view("pet")
			var reduced: bool=dog!=null and dog.type=="dog" and night_roll("dog-loss")<0.04*float(dog.relation)*pet_effect_strength(dog)
			var limit: int=1 if reduced else 2;var rice:=minf(limit,float(state.rice));var wood:=minf(limit-rice,float(state.wood))
			if reduced:state.nightResults.append("狗先低叫了一声，家里来得及把近手的一小包东西挪开；来人仍闯进了棚边。")
			state.rice-=rice;state.wood-=wood;var lost: Array=[]
			if rice>0:lost.append("米粮×"+str(int(rice)))
			if wood>0:lost.append("木料×"+str(int(wood)))
			state.nightResults.append("家里没有硬拦，来人拿走了"+"、".join(lost)+"。" if not lost.is_empty() else "来人翻找了一阵，没有拿到已经见底的米粮和木料。")
		elif choice in ["animalPoultry","animalPet"]:
			var slot: String="poultry" if choice=="animalPoultry" else "pet";var name:=animal_name(state.animals[slot]);lose_animal(slot,"robbery_surrender")
			state.nightResults.append("家里交出了"+name+"，来人才没有继续翻找别的东西。")
		else:
			var actors:=night_response_actors();var target: String="安仁叔叔" if "安仁叔叔" in actors else (actors[0] if not actors.is_empty() else "")
			if target!="":
				if strict_night_response():c.robberyActor=target
				state.people[target].health=clampf(float(state.people[target].health)-2,0,10);change_ailment(target,"wound",1)
				state.nightResults.append(target+"试图阻拦，没有交出物资，却受了伤。")
	elif e.type=="mouse":
		var actors:=night_response_actors()
		actors.sort_custom(func(x,y):return PEOPLE.find(x)<PEOPLE.find(y) if state.people[x].spirit==state.people[y].spirit else state.people[x].spirit>state.people[y].spirit)
		var actor: String=actors[0] if not actors.is_empty() else ""
		var roll: float=e.get("lossRoll",night_roll("mouse-loss"));var lost:=false
		if choice=="move":state.nightResults.append("家里用绳索把粮袋吊到棚架上，又把地上的散米收起。天亮清点，粮没有少，绳索也留在家中。")
		elif choice=="tidy":
			if actor!="":change_spirit(actor,-1)
			lost=state.rice>0 and roll<0.10
			state.nightResults.append((actor if actor!="" else "家里人")+"把粮袋搬到睡处旁，俯身收拾散米，折腾到半夜才躺下。"+("天亮再看，袋底还是被咬开了，清点少了米粮×1。" if lost else "天亮清点，粮袋还好，没有少粮。"))
		else:
			lost=state.rice>0 and roll<0.40
			state.nightResults.append("家里没有起身搬动粮袋。天亮才发现袋底被咬破，清点少了米粮×1。" if lost else "家里先歇下了。天亮提起粮袋仔细查看，袋角虽有咬痕，米粮并没有少。")
		if lost and state.rice>0:state.rice-=1;state.deltas.rice=state.deltas.get("rice",0)-1
		c.mouseOutcome={"choice":choice,"lost":1 if lost else 0,"actor":actor if choice=="tidy" else null}
	elif e.type=="family":c.familyNight={"kind":e.familyKind,"day":state.day}
	c.disturbed=e.type!="family";c.eventChoice=choice;c.eventType=e.type
	state.effectLedger.appliedEffectIds.append(c.id+":event");state.pendingNightEvent=null;state.error=null
	return true

var night_reading_bank: Dictionary={}
func capture_night_reading() -> Dictionary:
	var animals: Dictionary={}
	for slot in ["pet","poultry"]:animals[slot]=animal_name(state.animals[slot]) if animal_at_home(slot) else null
	return {"rice":state.rice,"wood":state.wood,"water":state.water,"shelter":state.shelter,"moisture":state.moisture,"people":state.people.duplicate(true),"ailments":state.ailments.duplicate(true),"present":PEOPLE.filter(func(person):return present(person)),"animals":animals}
func prepare_night_reading(event: Variant,cycle: Dictionary) -> bool:
	if event==null or cycle.get("readingRevision")!="R3":return false
	if uses_current_diet() and event.get("reading")!=null:return true
	if night_reading_bank.is_empty():night_reading_bank=JSON.parse_string(FileAccess.get_file_as_string("res://data/night_reading_bank.json"))
	var now:=capture_night_reading();var history_key: String=event.familyKind if event.type=="family" else event.type;var prior:=0
	for row in state.memory.get("nightReadingHistory",[]):
		var kind: String=row.familyKind if row.get("familyKind")!=null and row.get("familyKind")!="" else row.type
		if kind==history_key:prior+=1
	var responders: Array=night_response_actors() if strict_night_response() and event.type in ["robbery","mouse"] else now.present.duplicate()
	var actor: String=""
	if event.type=="robbery":actor="安仁叔叔" if "安仁叔叔" in responders else (responders[0] if not responders.is_empty() else "")
	else:
		responders.sort_custom(func(a,b):return PEOPLE.find(a)<PEOPLE.find(b) if state.people[a].spirit==state.people[b].spirit else state.people[a].spirit>state.people[b].spirit)
		if not responders.is_empty():actor=responders[0]
	if actor=="":actor=now.present[0] if not now.present.is_empty() else "棚里的人"
	var alone: bool=now.present.size()==1
	var titles={"theft":"棚边的动静","robbery":"日本兵翻过的地方","mouse":"粮袋旁的一夜","family":"棚里这一夜"}
	event.reading={"revision":"R3","type":event.type,"familyKind":event.get("familyKind"),"actor":actor,"present":now.present,"prior":prior,"alone":alone,"title":titles[event.type]}
	var stock: String="rice" if state.rice>0 else ("wood" if state.wood>0 else "empty")
	var key: Array=[]
	match event.type:
		"theft":key=["theft",actor,alone,state.day==0,prior>0,stock,present("安仁叔叔"),tool_available("whistle")]
		"robbery":key=["robbery",actor,alone,prior>0,stock,animal_at_home("pet") or animal_at_home("poultry"),present("安仁叔叔")]
		"mouse":key=["mouse",actor,alone,prior>0,tool_available("rope"),now.animals.pet if now.animals.pet!=null else ""]
		"family":
			var people: Array=now.present.duplicate();var ill: String="";var away: String=""
			people.sort_custom(func(a,b):return PEOPLE.find(a)<PEOPLE.find(b) if state.people[a].health==state.people[b].health else state.people[a].health<state.people[b].health)
			for person in people:
				if state.people[person].health<=3 or state.ailments.get(person,{}).values().any(func(v):return v>=3):ill=person;break
			for person in PEOPLE:
				var p: Dictionary=state.people[person]
				if p.alive and not p.get("permanentLost",false) and (p.away or p.get("detainedUntil")!=null):away=person;break
			key=["family",event.familyKind,actor,alone,ill if event.familyKind=="care" else (away if event.familyKind=="absence" else "")]
	var encoded:=JSON.stringify(key)
	if not night_reading_bank.prepare.has(encoded):push_error("Uncompiled R3 prose discriminator: "+encoded);return false
	var prose: Dictionary=night_reading_bank.prepare[encoded]
	event.title=prose.title;event.text=prose.text
	return apply_current_night_prose(event,cycle) if uses_current_diet() else true
func lock_night_reading(event: Dictionary,choice: String,cycle: Dictionary,before: Dictionary,event_lines: Array) -> bool:
	if cycle.get("readingRevision")!="R3" or before.is_empty():return false
	if night_reading_bank.is_empty():night_reading_bank=JSON.parse_string(FileAccess.get_file_as_string("res://data/night_reading_bank.json"))
	var after:=capture_night_reading();var lost: Array=[]
	for pair in [["rice","米粮"],["wood","木料"]]:
		if before[pair[0]]>after[pair[0]]:lost.append(pair[1]+"×"+str(int(before[pair[0]]-after[pair[0]])))
	var slot: String="pet" if choice=="animalPet" else ("poultry" if choice=="animalPoultry" else "")
	var animal: Variant=before.animals[slot] if slot!="" else null
	if animal!=null and animal!="" and after.animals[slot]==null:lost.append(animal+"×1")
	var actor: Variant=cycle.get("mouseOutcome",{}).get("actor")
	if actor==null or actor=="":actor=cycle.get("robberyActor") if strict_night_response() else null
	if actor==null or actor=="":
		if choice=="resist":actor="安仁叔叔" if "安仁叔叔" in before.present else (before.present[0] if not before.present.is_empty() else null)
		else:actor=event.get("reading",{}).get("actor")
	if actor==null or actor=="":actor=before.present[0] if not before.present.is_empty() else null
	var titles={"theft":"棚边的动静","robbery":"日本兵翻过的地方","mouse":"粮袋旁的一夜","family":"棚里这一夜"}
	var r={"id":cycle.id,"day":cycle.day,"type":event.type,"familyKind":event.get("familyKind"),"choice":choice,"animal":animal,"present":before.present,"luoWitness":"罗瑾" in before.present and before.people["罗瑾"].health>1,"title":event.get("title",titles[event.type]),"eventLines":event_lines.duplicate(true),"receipt":"事件损失："+"、".join(lost)+"。" if not lost.is_empty() else "","lost":before.rice>after.rice,"closure":"","diary":"","summary":""}
	if actor!=null:r.actor=actor
	var key: Array=[]
	match event.type:
		"family":key=["family",event.familyKind]
		"theft":key=["theft",choice,not lost.is_empty()]
		"robbery":
			if choice=="give":key=["robbery","give",not lost.is_empty(),event_lines.any(func(x):return str(x).begins_with("狗先"))]
			elif animal!=null and animal!="":key=["robbery","animal",animal]
			else:key=["robbery","resist",actor]
		"mouse":key=["mouse",choice,actor,cycle.get("mouseOutcome",{}).get("lost",0)!=0]
	var encoded:=JSON.stringify(key)
	if not night_reading_bank.closure.has(encoded):push_error("Uncompiled R3 closure discriminator: "+encoded);return false
	r.merge(night_reading_bank.closure[encoded],true);cycle.readingEvent=r
	if not state.memory.has("nightReadingHistory"):state.memory.nightReadingHistory=[]
	if not state.memory.nightReadingHistory.any(func(x):return x.id==r.id):state.memory.nightReadingHistory.append({"id":r.id,"day":r.day,"type":r.type,"familyKind":r.familyKind,"choice":choice})
	return apply_current_night_closure(event,choice,cycle) if uses_current_diet() else true
func resolve_night_event(choice: String) -> bool:
	var event=state.get("pendingNightEvent");var cycle=state.get("nightCycle")
	var use_reading: bool=event!=null and cycle!=null and cycle.get("readingRevision")=="R3"
	var backup: Dictionary=state.duplicate(true) if use_reading else {}
	var before:=capture_night_reading() if use_reading else {};var start: int=state.nightResults.size()
	if not resolve_night_event_effects(choice):return false
	if use_reading and not lock_night_reading(event,choice,cycle,before,state.nightResults.slice(start)):
		state=backup;state.error="夜间正文尚未完成迁移，状态未结算。";return false
	return true
func understands(person: String) -> bool:
	return present(person) and state.people[person].health>1
func build_night_reading_dawn(cycle: Dictionary) -> bool:
	if cycle.get("readingRevision")!="R3":return false
	if night_reading_bank.is_empty():night_reading_bank=JSON.parse_string(FileAccess.get_file_as_string("res://data/night_reading_bank.json"))
	var before: Dictionary=cycle.readingStart;var after:=capture_night_reading()
	var r: Dictionary=cycle.readingEvent.duplicate(true) if cycle.get("readingEvent")!=null else {"id":cycle.id,"day":cycle.day,"present":before.present,"luoWitness":"罗瑾" in before.present and before.people["罗瑾"].health>1,"diary":"","summary":"","receipt":"","eventLines":[]}
	var losses: Array=before.present.filter(func(person):return before.people[person].alive and not after.people[person].alive)
	var critical: Array=before.present.filter(func(person):return after.people[person].alive and ((after.people[person].health<=2 and before.people[person].health>2) or after.ailments[person].keys().any(func(type):return after.ailments[person][type]>=3 and before.ailments[person][type]<3)))
	var data: Dictionary=night_reading_bank.dawn
	if r.get("type")=="robbery" and r.get("choice")=="resist" and r.get("actor")!=null and after.people.get(r.actor,{}).get("alive",false) and after.ailments[r.actor].wound==0 and after.people[r.actor].health>2:r.diary=data.treated[r.actor]
	if not losses.is_empty():
		var key:=JSON.stringify(losses)
		if not data.losses.has(key):push_error("Uncompiled dawn loss order: "+key);return false
		r.diary=(r.summary+"\n\n" if r.summary!="" else "")+data.losses[key].diary;r.summary+=data.losses[key].summary
	if not critical.is_empty():
		r.diary+=("\n\n" if r.diary!="" else "")+"".join(critical.map(func(person):return data.critical[person]))
		r.summary+=" 今晨"+"、".join(critical)+"已出现明显危重或严重病症，需要照料。"
	if r.diary=="" and before.moisture<3 and after.moisture==3:r.diary=data.wet.diary;r.summary=data.wet.summary
	r.losses=losses;r.critical=critical;r.eventLines=cycle.get("readingEvent",{}).get("eventLines",[]) if cycle.get("readingEvent")!=null else []
	r.dawnDay=state.day+1;r.availableAfter=state.day+1;r.survivors=before.present.filter(func(person):return understands(person));cycle.readingDawn=r
	if uses_current_diet():apply_current_night_dawn(cycle)
	return true
func promote_night_reading() -> void:
	var c=state.get("nightCycle")
	if c==null or c.get("readingRevision")!="R3" or c.day!=state.day-1:return
	state.memory.nightReadingMorning={"day":state.day,"carried":state.morningResults.duplicate(true),"shown":[],"record":c.readingDawn.duplicate(true) if c.get("readingDawn")!=null else null}
	if c.get("readingDawn")!=null and c.readingDawn.get("diary","")!="":
		if not state.memory.has("nightReadingQueue"):state.memory.nightReadingQueue=[]
		if not state.memory.nightReadingQueue.any(func(row):return row.id==c.id):state.memory.nightReadingQueue.append(c.readingDawn.duplicate(true))
func deliver_night_reading() -> void:
	var morning=state.memory.get("nightReadingMorning")
	if morning==null or morning.day!=state.day or state.ended or not understands("罗瑾"):return
	if night_reading_bank.is_empty():night_reading_bank=JSON.parse_string(FileAccess.get_file_as_string("res://data/night_reading_bank.json"))
	for r in state.memory.get("nightReadingQueue",[]):
		if r.get("deliveredDay")!=null or r.availableAfter>state.day:continue
		var source: String=""
		for person in r.present:
			if person!="罗瑾" and understands(person):source=person;break
		if not r.luoWitness and source=="":continue
		r.deliveredDay=state.day;var immediate: bool=r.day==state.day-1;var text: String=""
		if r.luoWitness:
			text=r.diary if immediate else str(night_reading_bank.dawn.witness_late_prefix).replace("{day}",str(int(r.day)+1))+str(r.diary).replace("今早","那次清晨").replace("昨夜","那一夜")
		else:
			var parts: Dictionary=night_reading_bank.dawn.delivery[JSON.stringify([source,immediate])]
			text=str(parts.prefix).replace("{day}",str(int(r.day)+1))+r.summary+parts.suffix
		morning.shown.append({"id":r.id,"title":"昨夜记录" if immediate else "补记先前的一夜","text":text,"receipt":r.receipt})

func _object(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}

const JS_JSON=preload("res://scripts/js_json.gd")
const DIET_SIGN="ui-real-r2-diet-adapter-v1"
var diet_legacy_depth:=0
var contract_error: String=""
var contract_message: String=""
func fail_contract(code: String,message: String) -> void:
	contract_error=code;contract_message=message
func uses_current_diet() -> bool:
	return diet_legacy_depth==0 and state.get("r2DietAdapter")!=null
func current_hunger_revision() -> String:
	return "A1" if uses_current_diet() else HUNGER_REVISION
func ensure_current_diet() -> Dictionary:
	if state.get("r2DietAdapter")!=null and state.r2DietAdapter.get("adapter")!=DIET_SIGN:
		fail_contract("DIET_ADAPTER_UNSUPPORTED","不支持这份饮食适配记录。");return {}
	if state.get("r2DietAdapter")==null:state.r2DietAdapter={"adapter":DIET_SIGN,"ruleSource":"02_饮食与精神合同.md","records":{},"firstNewNight":null}
	return state.r2DietAdapter
func _whole_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_FLOAT,TYPE_INT] and is_finite(float(value)) and floor(float(value))==float(value)
func valid_diet_record(record: Variant) -> bool:
	return record is Dictionary and _whole_number(record.get("day")) and _whole_number(record.get("count")) and record.count>=0 and record.count<=49
func diet_previous(person: String) -> Variant:
	var own=_object(state.get("r2DietAdapter")).get("records",{}).get(person)
	if own!=null:
		if not valid_diet_record(own):fail_contract("DIET_RECORD_INVALID","连续进食记录损坏，未重算旧日。");return null
		return own
	var candidates: Array=[]
	for key in ["hungerA1","hungerA3cPersonV1"]:
		var record=_object(state.memory.get(key)).get(person)
		if record!=null and record.get("day")==state.day-1:candidates.append(record)
	if candidates.any(func(record):return not valid_diet_record(record)):fail_contract("DIET_RECORD_INVALID","旧连续进食记录损坏。");return null
	if candidates.size()>1 and candidates[0].count!=candidates[1].count:fail_contract("DIET_RECORD_CONFLICT","两份旧进食记录相互矛盾，须回原版本核对。");return null
	return candidates[0] if not candidates.is_empty() else null
func is_current_diet_cycle(cycle: Variant) -> bool:
	return cycle is Dictionary and _object(cycle.get("r2Diet")).get("adapter")==DIET_SIGN
func lock_current_diet(cycle: Dictionary) -> bool:
	var adapter:=ensure_current_diet()
	if contract_error!="":return false
	if adapter.firstNewNight==null:adapter.firstNewNight=state.day
	var inputs: Dictionary={};var packets: Array=[]
	for person in PEOPLE:
		if not present(person):continue
		var previous=diet_previous(person)
		if contract_error!="":return false
		var count: int=int(previous.count)+1 if previous!=null and previous.day==state.day-1 else 1
		var risk:=hunger_risk(person,count,"A1");var roll:=hunger_roll(person,"A1");var id: String=PERSON_SUFFIX[person]
		inputs[person]={"count":count,"risk":risk,"roll":roll,"previousDay":previous.day if previous!=null else null,"previousCount":previous.count if previous!=null else null}
		packets.append({"id":cycle.id+":diet-a1:"+id,"sourceEventInstanceId":cycle.id,"timing":"on_condition","subjectId":id,"effects":[{"type":"character_health","targetCharacterId":id,"amount":-1}] if roll<risk else [],"proseId":"donor-survival-hunger-line","revealTo":[],"knowledgeFactIds":[],"scheduledDay":null,"condition":"night_confirmed && meal_outcome_resolved && subject_present && subject_not_fed","status":"pending"})
	cycle.r2Diet={"adapter":DIET_SIGN,"day":state.day,"choiceId":str(RNG.hash_seed(JS_JSON.encode(cycle.plan))),"inputs":inputs,"lockHash":str(RNG.hash_seed(JS_JSON.encode(inputs))),"packets":packets}
	return true
func settle_current_hunger(hungry: Array) -> Array:
	var cycle=state.get("nightCycle")
	if not is_current_diet_cycle(cycle) or cycle.status!="settling":fail_contract("DIET_NOT_CONFIRMED","饥饿效果只能在已确认的夜间结算中执行。");return []
	var records: Dictionary=ensure_current_diet().get("records",{});var lines: Array=[]
	if contract_error!="":return lines
	if state.get("effectLedger")==null:state.effectLedger={"appliedEffectIds":[]}
	for packet in cycle.r2Diet.packets:
		if packet.status!="pending":continue
		var person: String=""
		for name in PEOPLE:
			if PERSON_SUFFIX[name]==packet.subjectId:person=name;break
		var input: Dictionary=cycle.r2Diet.inputs[person]
		if packet.id in state.effectLedger.appliedEffectIds:fail_contract("DIET_LEDGER_CONFLICT","效果账本与包状态矛盾，停止重放。");return lines
		if _object(records.get(person)).get("day")==state.day:fail_contract("DIET_DUPLICATE_DAY","同一人物同一夜已有进食结算，未重复执行。");return lines
		if not present(person):packet.status="cancelled";packet.cancelReason="结算时已不在家庭现场，不追记家庭饥饿";continue
		var missed: bool=person in hungry;var count: int=int(input.count) if missed else 0;var hurt: bool=missed and not packet.effects.is_empty()
		records[person]={"day":state.day,"count":count,"risk":input.risk if missed else 0,"hurt":hurt,"revision":"A1","packetId":packet.id}
		if not missed:packet.status="cancelled";packet.cancelReason="实际吃上饭或在外已进食；连续计数归零";continue
		if hurt:
			state.people[person].health=clampf(float(state.people[person].health)-1,0,10);lines.append(person+("又" if count>1 else "")+"空着肚子过了一夜，身体更虚弱了。")
		packet.status="applied";state.effectLedger.appliedEffectIds.append(packet.id)
	return lines
func settle_survival(prepaid: Variant=null) -> Array:
	if not uses_current_diet():return _settle_survival_core(prepaid)
	if prepaid!=null and not is_current_diet_cycle(prepaid):
		diet_legacy_depth+=1;var result:=_settle_survival_core(prepaid);diet_legacy_depth-=1;return result
	if not is_current_diet_cycle(prepaid):fail_contract("DIET_NOT_CONFIRMED","不能在未锁定夜间结果时直接结算。");return []
	return _settle_survival_core(prepaid)
func validate_current_diet() -> bool:
	contract_error="";contract_message=""
	var cycle: Dictionary=_object(state.get("nightCycle"));var adapter: Dictionary=_object(state.get("r2DietAdapter"))
	var locked: bool=not cycle.is_empty() and cycle.get("day")==state.day and cycle.get("status")=="awaiting_event"
	if cycle.get("repairPacket")!=null or str(cycle.get("shelterMaintenanceRevision","")).begins_with("night-contract:"):
		fail_contract("SAVE_REPAIR_EXPERIMENTAL","记录含已退出生产路径的夜间修棚试验包。请保留原文件并回生成它的候选版核对，本版不重算、不清除该包。");return false
	if locked and (_object(cycle.get("plan")).get("repair",false) or state.night.repair):
		fail_contract("SAVE_REPAIR_CONTRACT","新确认夜不允许普通修棚；不能把本候选记录降格为旧夜。");return false
	if not locked and state.phase=="night" and state.night.repair:
		fail_contract("SAVE_REPAIR_DRAFT","未确认草稿包含已停用的夜间修棚。请回原版本取消该未确认选项再导出，不改写已完成的决定。");return false
	if adapter.is_empty() or adapter.get("adapter")!=DIET_SIGN:fail_contract("DIET_ADAPTER_UNSUPPORTED","饮食适配版本不兼容。");return false
	if not adapter.get("records") is Dictionary:
		fail_contract("DIET_RECORD_INVALID","进食记录结构不完整。");return false
	for person in adapter.records:
		if person not in PEOPLE or not valid_diet_record(adapter.records[person]):fail_contract("DIET_RECORD_INVALID","进食记录结构不完整。");return false
	if cycle.get("status")=="settling":fail_contract("DIET_PARTIAL_SETTLEMENT","此记录停在结算中间，须恢复最近完整检查点，不能重放。");return false
	if locked:
		if cycle.get("r2Diet")==null and adapter.get("firstNewNight")!=null and cycle.day>=adapter.firstNewNight:fail_contract("DIET_PACKET_MISSING","本候选已确认夜的饮食合同丢失，禁止降格为旧合同。");return false
		if cycle.get("r2Diet")!=null and not is_current_diet_cycle(cycle):fail_contract("DIET_LOCK_UNSUPPORTED","夜间适配合同无法识别。");return false
		if not is_current_diet_cycle(cycle):fail_contract("R4_SAVE_LEGACY_NIGHT","这份已确认夜晚使用旧合同，本候选不承接其结算。请保留原文件并回生成版本继续，或另开新周目。");return false
		var diet: Dictionary=cycle.r2Diet
		if cycle.get("hungerRevision")!="A1" or diet.get("day")!=state.day or not _whole_number(cycle.get("outcomeRng")):
			fail_contract("DIET_LOCK_INVALID","夜间合同缺失或与日期不一致。");return false
		if not diet.get("packets") is Array or not diet.get("inputs") is Dictionary:fail_contract("DIET_PACKET_MISSING","夜间结果包缺失。");return false
		if diet.get("lockHash")!=str(RNG.hash_seed(JS_JSON.encode(diet.inputs))):fail_contract("DIET_LOCK_DAMAGED","夜间已锁输入校验失败。");return false
		var seen: Array=[]
		for packet in diet.packets:
			if not packet is Dictionary:fail_contract("DIET_PACKET_INVALID","夜间结果包身份、时点或状态损坏。");return false
			var person: String=""
			for name in PEOPLE:
				if PERSON_SUFFIX[name]==packet.get("subjectId"):person=name;break
			var input: Dictionary=_object(diet.inputs.get(person))
			if person=="" or input.is_empty() or packet.get("id") in seen or packet.get("id")!=cycle.id+":diet-a1:"+PERSON_SUFFIX[person] or packet.get("timing")!="on_condition" or packet.get("status") not in ["pending","applied","cancelled"] or not packet.get("effects") is Array:
				fail_contract("DIET_PACKET_INVALID","夜间结果包身份、时点或状态损坏。");return false
			if not _whole_number(input.get("count")) or input.count<1 or input.count>49:fail_contract("DIET_OUTCOME_INVALID","已锁饥饿结果不完整；禁止读档重抽。");return false
			var roll:=hunger_roll(person,"A1");var risk:=hunger_risk(person,int(input.count),"A1")
			var expected: Array=[{"type":"character_health","targetCharacterId":PERSON_SUFFIX[person],"amount":-1}] if roll<risk else []
			if input.get("roll")!=roll or input.get("risk")!=risk or JS_JSON.encode(packet.effects)!=JS_JSON.encode(expected):fail_contract("DIET_OUTCOME_INVALID","已锁饥饿结果不完整；禁止读档重抽。");return false
			seen.append(packet.id)
		if diet.packets.size()!=diet.inputs.size():fail_contract("DIET_PACKET_MISSING","夜间人物结果包不齐。");return false
	if state.saveVersion!=24:fail_contract("R4_SAVE_SCHEMA","本候选仅支持当前schema24记录；未迁移或改写原文件。");return false
	if _object(state.get("r3PhotoContract")).get("revision")!="r3-photo-33-34-observed-v1":fail_contract("R4_SAVE_LEGACY_CONTRACT","这份记录不属于当前饮食与照片合同，不在本次支持范围内。请保留原文件并回生成版本继续，或另开新周目。");return false
	if state.get("features",{}).get("animals",true)==false:
		var q: Dictionary=_object(state.memory.get("pigeonRequest"));var plan: Dictionary=_object(cycle.get("plan"))
		if state.animals.poultry!=null or state.animals.pet!=null or (q.get("type")=="pigeon" and ((q.get("sent")==true and q.get("resolved")!=true) or (q.get("pickup")==true and q.get("pickupDone")!=true) or (q.get("pickupDone")!=true and _object(q.get("pickupPlan")).get("status")=="planned"))) or (locked and (plan.get("feedPoultry")==true or plan.get("feedPet")==true or plan.get("pigeonAction") in ["send","collect","delay"])):
			fail_contract("R4_SAVE_DISABLED_ANIMALS","动物功能关闭，但记录中仍有动物或未结束的动物事务。此组合不在支持范围内；未删除动物、撤销事务或改写原文件。请回生成版本继续，或另开新周目。");return false
	return true

# Integration gate for the reachable opening night only. Later days stay closed until ported.
func _opening_night_supported() -> bool:
	if int(state.day) not in range(0,49) or not _object(state.memory.get("opening")).get("settled",false):return false
	if state.day>0 and (state.focus.get("day")!=state.day or not state.focus.get("settled",false) or (current_first_focus_event().is_empty() if state.day<10 else current_later_focus_event().is_empty())):return false
	if not early_household_supported():return false
	for person in PEOPLE:
		if not present(person):
			if state.day<4:return false
			continue
		if state.day==0 and (state.people[person].health<6 or state.ailments[person].values().any(func(x):return x!=0)):return false
	return true

func set_night_option(key: String,value: Variant) -> bool:
	if key=="repair" and value and uses_current_diet():state.error="普通修棚在白天家中注视中安排。今晚不接受长期修棚；未扣除物资。";return false
	if key in ["meal","repair","feedPoultry","feedPet"]:state.night[key]=not value in [false,null,0,""]
	elif key=="fire":state.night.fire=clampf(float(value),0,2)
	else:return false
	return true
func confirm_first_night() -> bool:
	return confirm_early_night()
func confirm_early_night() -> bool:
	var record: Dictionary=_object(state.memory.get(CUSTODY_NIGHT_KEY))
	if record.is_empty() or not custody_night_record_valid(record) or not custody_night_held(record) or state.ended or state.phase!="night" or state.day+1<record.dueDay or _object(state.get("nightCycle")).get("day")==state.day:return confirm_chapter_night_core()
	var backup:=state.duplicate(true);record.status="awaiting";add_custody_action(record,"due-passed","night-plan:D"+str(int(state.day)+1),"household","household",{"dueDay":record.dueDay})
	var result: bool=confirm_chapter_night_core()
	if not result:
		var reason=state.error;state=backup;state.error=reason
	return result

func normalize_people() -> void:
	for person in PEOPLE:
		var p: Dictionary=state.people[person]
		p.spiritMax=clampf(float(p.get("spiritMax",10)),1,10);p.health=clampf(float(p.health),0,10);p.spirit=clampf(float(p.spirit),0,float(p.spiritMax))
		p.alive=p.get("alive",true)!=false;p.away=p.get("away",false) or p.get("permanentLost",false) or p.get("detainedUntil")!=null
func capture_r24_day_snapshot(reason: String="day_end") -> Dictionary:
	var people: Dictionary={}
	for person in PEOPLE:
		var p: Dictionary=state.people[person];var a: Dictionary=state.ailments.get(person,{})
		people[person]={"alive":p.get("alive",true)!=false,"health":p.get("health",0),"spirit":p.get("spirit",0),"away":p.get("away",false),"ailments":{"wound":a.get("wound",0),"cold":a.get("cold",0),"nutrition":a.get("nutrition",0),"illness":a.get("illness",0)}}
	var snapshot={"day":state.day+1,"reason":reason,"rice":state.rice,"water":state.water,"wood":state.wood,"shelter":state.shelter,"weather":current_weather().name,"people":people}
	if not state.memory.has("r24DaySnapshots"):state.memory.r24DaySnapshots=[]
	var rows: Array=state.memory.r24DaySnapshots;var replaced:=false
	for i in range(rows.size()):
		if rows[i].day==snapshot.day:rows[i]=snapshot;replaced=true;break
	if not replaced:rows.append(snapshot)
	rows.sort_custom(func(a,b):return a.day<b.day)
	while rows.size()>7:rows.pop_front()
	return snapshot
func finish_first_night() -> bool:
	return finish_early_night()
func finish_early_night() -> bool:
	var cycle=state.get("nightCycle")
	if state.ended or int(state.day) not in range(0,49) or cycle==null or cycle.day!=state.day or cycle.status!="awaiting_event" or state.get("pendingNightEvent")!=null:return false
	if not _opening_night_supported():state.error="当前开发候选尚未接通这一阶段的夜间流程。";return false
	if not validate_current_diet():state.error="未执行夜间结果："+contract_message;return false
	var backup:=state.duplicate(true)
	cycle.status="settling";state.phase="night";state.night=cycle.plan.duplicate(true);state.rngState=cycle.outcomeRng
	state.nightResults.append_array(settle_survival(cycle))
	if contract_error!="":state=backup;state.error="这一夜尚未结算完成，状态已保留："+contract_message;return false
	settle_water_exposure(cycle);apply_planned_treatment(true);settle_animals(true);finish_pigeon_care_night();progress_ailments();normalize_people()
	if cycle.get("solitaryHealthEligible",false):cycle.c018SettlementStage="post_survival"
	if not check_early_critical():state=backup;state.error="当前危重分支仍待接入，未提交这一夜。";return false
	if cycle.get("solitaryHealthEligible",false):cycle.c018SettlementStage="post_critical"
	var spent: Array=[]
	for pair in [["rice","米粮"],["water","饮水"],["wood","木料"]]:
		if cycle.cost[pair[0]]>0:spent.append(pair[1]+"×"+str(int(cycle.cost[pair[0]])))
	if not spent.is_empty():state.nightResults.append("这一夜安排用去："+"、".join(spent)+"。")
	var terminal_failure: bool=resolve_solitary_health_failure()
	if contract_error!="":state=backup;state.error="这一夜尚未结算完成，状态已保留："+contract_message;return false
	if cycle.get("solitaryHealthEligible",false):cycle.c018SettlementStage="failure_locked" if terminal_failure else "resolved"
	cycle.status="settled";cycle.settledDay=state.day;state.effectLedger.appliedEffectIds.append(cycle.id+":dawn")
	state.history.append({"day":state.day,"type":"night-settlement","id":cycle.id,"cost":cycle.cost,"disturbed":cycle.disturbed})
	if terminal_failure:
		# Source terminal save validation normalizes closed arcs with this stable reason.
		# Mirror that pure-state normalization; native disk persistence remains explicit.
		cancel_person_pending("罗瑾","死亡存档恢复");return true
	if not build_night_reading_dawn(cycle):state=backup;state.error="这一夜尚未结算完成，状态已保留：晨间正文未接通。";return false
	capture_r24_day_snapshot("dawn");state.day+=1
	if state.day>=49:
		state.phase="end";state.ended=true;state.photo.deadline.final=true;return true
	state.morningResults=state.nightResults.map(func(line):return str(line).replace("今晚","昨夜"));state.nightResults=[];state.eventResult=null;state.eventChange=null;state.selectedChoice=null
	state.night={"meal":true,"fire":1,"repair":false,"feedPoultry":false,"feedPet":false,"treatment":"none","pigeonAction":"none"}
	promote_night_reading();state.phase="morning"
	process_expedition_morning()
	process_animal_morning()
	if not (initialize_day_eleven_story() if state.day<=10 else process_pre_photo_story_morning()):state=backup;state.error="后续剧情晨间尚未满足原生候选的条件，未提交这一夜。";return false
	if not check_early_critical():state=backup;return false
	deliver_night_reading()
	state.phase="end" if state.ended else ("search" if js_truthy(state.expedition.get("decision")) else "morning")
	return true

var current_night_prose: Dictionary={}
const NIGHT_PROSE_REV="WebR9-night-prose-v1"
const NIGHT_PROSE_REVIEW="WebR10-ReviewA-D1D14-v1"
func _load_current_night_prose() -> void:
	if current_night_prose.is_empty():current_night_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/current_night_prose.json"))
func night_prose_context(event: Dictionary,cycle: Dictionary) -> Dictionary:
	var people: Array=PEOPLE.filter(func(person):return present(person));var talk: Array=people.filter(func(person):return understands(person))
	var patient: Variant=null;var helper: Variant=null;var absent: Variant=null
	for person in people:
		if state.people[person].health<=3 or state.ailments.get(person,{}).values().any(func(value):return value>=3):patient=person;break
	for person in talk:
		if person!=patient:helper=person;break
	var recipients: Array=people.filter(func(person):return _object(state.memory.get("ateOutsideDay")).get(person)!=state.day)
	var actor: Variant=event.get("reading",{}).get("actor")
	if event.type=="family":
		if event.familyKind=="care":actor=helper if helper!=null else patient
		elif event.familyKind=="hunger":
			actor=null
			for person in recipients:
				if person in talk:actor=person;break
			if actor==null:actor=talk[0] if not talk.is_empty() else (people[0] if not people.is_empty() else null)
		else:actor=talk[0] if not talk.is_empty() else (people[0] if not people.is_empty() else null)
	if actor==null:actor=people[0] if not people.is_empty() else null
	var prior: Array=[]
	for person in people:
		var old=_object(state.memory.get("hungerA3cPersonV1")).get(person)
		if old==null:
			var candidate=_object(state.memory.get("hungerA1")).get(person)
			old=candidate if candidate!=null and candidate.get("day")==state.day-1 else null
		if old!=null and old.get("day")==state.day-1 and old.get("count",0)>0:prior.append(person)
	for person in PEOPLE:
		var p: Dictionary=state.people[person]
		if p.alive and not p.get("permanentLost",false) and (p.away or p.get("detainedUntil")!=null):absent=person;break
	var animals: Dictionary={}
	for slot in ["pet","poultry"]:animals[slot]=animal_name(state.animals[slot]) if animal_at_home(slot) else null
	return {"day":state.day,"people":people,"talk":talk,"patient":patient,"helper":helper,"actor":actor,"alone":people.size()==1,"patientCanReply":patient!=null and understands(patient),"recipients":recipients,"ateOutside":people.filter(func(person):return _object(state.memory.get("ateOutsideDay")).get(person)==state.day),"priorHungry":prior,"absent":absent,"rice":state.rice,"wood":state.wood,"water":state.water,"moisture":state.moisture,"meal":cycle.plan.meal,"fire":cycle.plan.fire,"treatment":cycle.get("treatment","none"),"rope":tool_available("rope"),"whistle":tool_available("whistle"),"animals":animals}
func select_night_prose_scene(event: Dictionary) -> Dictionary:
	_load_current_night_prose()
	var bucket: String=event.familyKind if event.type=="family" else event.type
	if event.type=="theft" and state.day==0:return {"bucket":"first","index":0,"scene":current_night_prose.scenes.first[0]}
	var list: Array=current_night_prose.scenes.get(bucket,[])
	if list.is_empty():return {}
	var history: Array=[]
	for row in state.memory.get("nightReadingHistory",[]):
		var kind: String=row.familyKind if row.get("familyKind")!=null and row.get("familyKind")!="" else row.type
		if kind==bucket:history.append(row)
	var offset: int=RNG.hash_seed(state.seed+"|"+NIGHT_PROSE_REV+"|"+bucket)%list.size()
	var index: int=(offset+history.size())%list.size();var recent: Array=[]
	for row in history:
		var id=_object(row.get("nightProse")).get("id")
		if state.day-row.day<5 and id!=null and id!="" and id not in recent:recent.append(id)
	for step in range(list.size()):
		var candidate: int=(index+step)%list.size()
		if list[candidate].id not in recent:index=candidate;break
	return {"bucket":bucket,"index":index,"scene":list[index]}
func _prose_paragraphs(lines: Array) -> String:
	return "\n\n".join(lines.filter(func(text):return text!=null and text!=""))
func current_threat_text(scene: Dictionary,context: Dictionary,bucket: String) -> String:
	var people: Array=context.people;var talk: Array=context.talk
	var place_key: Array=["empty"] if people.is_empty() else (["alone",people[0]] if context.alone else (["unresponsive"] if talk.is_empty() else ["multi","安仁叔叔" in people]))
	var responders: Array=talk if strict_night_response() else people;var option_key: Array=[]
	if bucket in ["first","theft"]:option_key=["theft","安仁叔叔" in responders,"安仁叔叔" in people,context.whistle]
	elif bucket=="robbery":option_key=["robbery",context.animals.poultry,context.animals.pet,"安仁叔叔" if "安仁叔叔" in responders else (responders[0] if not responders.is_empty() else null)]
	else:option_key=["mouse",not responders.is_empty(),context.rope,context.animals.pet]
	var stock: String="rice" if context.rice>0 else ("wood" if context.wood>0 else "empty")
	return _prose_paragraphs([scene.body[0],current_night_prose.places[JSON.stringify(place_key)],scene.body[1],current_night_prose.mouseUncounted if bucket=="mouse" else current_night_prose.stocks[stock],scene.body[2],current_night_prose.options[JSON.stringify(option_key)]])
func apply_current_night_prose(event: Dictionary,cycle: Dictionary) -> bool:
	var chosen:=select_night_prose_scene(event)
	if chosen.is_empty():return true
	var context:=night_prose_context(event,cycle)
	var p={"revision":NIGHT_PROSE_REV,"bucket":chosen.bucket,"id":chosen.scene.id,"index":chosen.index,"context":context}
	if state.day>=0 and state.day<14:p.editorialRevision=NIGHT_PROSE_REVIEW
	if event.type=="family":
		var prior_people: Array=PEOPLE.filter(func(person):return present(person));var patient: Variant=null;var absent: Variant=null
		for person in prior_people:
			if state.people[person].health<=3 or state.ailments[person].values().any(func(x):return x>=3):patient=person;break
		for person in PEOPLE:
			var person_state: Dictionary=state.people[person]
			if person_state.alive and not person_state.get("permanentLost",false) and (person_state.away or person_state.get("detainedUntil")!=null):absent=person;break
		var legacy_context: Dictionary={"kind":event.familyKind,"people":prior_people,"patientCanReply":patient!=null and understands(patient),"priorHungry":prior_people.filter(func(person):
			var previous=diet_previous(person)
			return previous!=null and previous.day==state.day-1 and previous.count>0),"actor":event.reading.actor,"alone":prior_people.size()==1,"meal":cycle.plan.meal,"moisture":state.moisture,"prior":event.reading.prior}
		if patient!=null:legacy_context.patient=patient
		if absent!=null:legacy_context.absent=absent
		event.reading.fullReviewRevision="WebR1-family-prose-v1";event.reading.familyProseContext=legacy_context
	event.reading.nightProse=p;event.title=chosen.scene.title
	if event.type=="family":
		if family_care_prose.is_empty():family_care_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/family_care_prose.json"))
		var people: Array=context.people;var talk: Array=context.talk
		var place_key: Array=["empty"] if people.is_empty() else (["alone",people[0]] if context.alone else (["unresponsive"] if talk.is_empty() else ["multi","安仁叔叔" in people]))
		event.text=FamilyProse.text(chosen.scene,context,chosen.bucket,current_night_prose.places[JSON.stringify(place_key)],family_care_prose)
	else:event.text=current_threat_text(chosen.scene,context,chosen.bucket)
	return true
func _night_scene(prose: Dictionary) -> Dictionary:
	_load_current_night_prose()
	for scene in current_night_prose.scenes.get(prose.bucket,[]):
		if scene.id==prose.id:return scene
	return {}
func _person_label(person: Variant) -> String:
	return "娘" if person=="母亲" else ("叔叔" if person=="安仁叔叔" else str(person))
func apply_current_night_closure(event: Dictionary,choice: String,cycle: Dictionary) -> bool:
	var p=_object(event.get("reading")).get("nightProse")
	if p==null or p.get("revision")!=NIGHT_PROSE_REV:return true
	var r: Dictionary=cycle.readingEvent;var scene:=_night_scene(p)
	if scene.is_empty():fail_contract("NIGHT_PROSE_MISSING","已锁夜间场景正文缺失。");return false
	r.nightProse=p.duplicate(true)
	if event.type=="family":
		r.fullReviewRevision=event.reading.fullReviewRevision;r.familyProseContext=event.reading.familyProseContext.duplicate(true)
		r.closure=FamilyProse.closure(p);r.diary=FamilyProse.diary(p,scene);r.summary=FamilyProse.summary(p)
	else:
		r.closure=_prose_paragraphs([r.closure,"这一阵先到这里。粮袋仍按刚才选的办法放着，最后清点留到天亮。" if event.type=="mouse" else scene.after])
		if event.type=="mouse":
			r.diary="昨夜粮袋旁有了动静，眼前只先做完选定的那一步，还没作天亮后的清点。"
			r.summary="昨夜粮袋旁有抓挠声与咬痕，"+("用绳索吊起。" if choice=="move" else ("挪近并收拾了散米。" if choice=="tidy" else "先留在原处歇息。"))+"当场尚不知道最后有没有少粮。"
		else:
			if event.type=="theft":
				r.diary="昨夜叔叔隔着棚边出声，摸近的人退开。他没有追出去，我也没有看清那个人的脸。" if choice=="warn" else ("昨夜家里吹响哨子，摸近的人退开，哨子仍留在家中。声音停下以后，还等了一会儿才躺稳。" if choice=="whistle" else ("昨夜没有追出去，近手的一点粮木被拿走。先护住睡处是当时的选择，少掉的东西却仍要照实面对。" if r.receipt!="" else "昨夜来人翻了翻，没有拿到已经见底的米粮和木料。没有再少东西，那点庆幸里仍压着原先就空着的家用。"))
			elif choice=="give":r.diary="昨夜日本兵进棚翻找，家里没有硬拦。"+("他们拿走了一部分家用，我没有把这种退让说成情愿送给他们。" if r.receipt!="" else "他们没有拿到已经见底的粮木，留下的空处却也不是足够过日子的东西。")
			elif r.animal!=null:r.diary="昨夜日本兵带走了"+r.animal+"，没有继续翻找粮木。原来留给它的位置空着，没有送还的约定，也不知道它后来到了哪里。"
			else:r.diary="昨夜"+("我" if r.get("actor")=="罗瑾" else _person_label(r.get("actor")))+"试着阻拦，被日本兵殴打。这一次没有交出家用，却不能把人受的伤说成没有损失。"
			if p.get("editorialRevision")==NIGHT_PROSE_REVIEW and event.type=="theft" and choice=="warn":r.diary=current_night_prose.earlyWarn.get(p.id,r.diary)
			r.diary=_prose_paragraphs([r.diary,scene.hook])
	for row in state.memory.get("nightReadingHistory",[]):
		if row.id==r.id:row.nightProse={"revision":NIGHT_PROSE_REV,"id":p.id,"bucket":p.bucket};break
	return true

# First-week autonomous work forecast. No focus choice or reward is executed here.
func person_presence_label(person: String) -> String:
	var record:=uncle_crisis_record()
	if person=="安仁叔叔" and chapter_json_equal(record.get("status"),"pending") and js_truthy(record.get("settled")) and state.people[person].alive:return "这次出工未归，尚无确切下落"
	return _chapter7_parent_5_person_presence_label(person)

func plan_pigeon_pickup(day: int,node_id: Variant=null,search_active:=false) -> bool:
	var a: Dictionary=_object(pigeon_request());var q: Dictionary=_object(a.get("pickupPlan"))
	if not a.get("pickup",false) or a.get("pickupDone",false) or q.is_empty() or q.get("status")!="planned" or q.day>day or day>a.pickupDeadline or day>=48:return false
	var p: Dictionary=state.people["罗瑾"]
	var can_work: bool=present("罗瑾") and p.health>3 and not state.ailments["罗瑾"].values().any(func(x):return x>=3)
	var reason: String="今天有不能被取物挤开的剧情事情" if node_id!=null and node_id!="" else ("今天先处理寻找家人的安排" if search_active else ("罗瑾的身体或精神还不适合走这段路" if not can_work or p.spirit<=2 else ("天气太恶劣，不宜按纸条赶路" if current_weather().get("severe",false) else "")))
	if reason!="":
		if q.get("lastNoticeDay")!=day:
			state.morningResults.append(reason+"，取物暂未成行。"+("今天已是约定的最后一天。" if day==a.pickupDeadline else "若期限内条件合适，再接着安排。"));q.lastNoticeDay=day
		q.day=day+1;return false
	q.day=day;return true
func _work_row(name: String,label: String,type: String="home",outside:=false,base: Dictionary={}) -> Dictionary:
	return {"name":name,"label":label,"type":type,"outside":outside,"base":base}
func make_first_week_plan(day: int=-1) -> Dictionary:
	if day<0:day=int(state.day)
	if day<1 or day>=10:fail_contract("DAY_PLAN_PENDING","后续日期的白天计划尚未迁移。");return {}
	var rows: Dictionary={}
	for person in PEOPLE:rows[person]=_work_row(person,"留在棚区")
	if day==1:
		for pair in [["罗瑾","留在棚里继续安顿"],["母亲","留在棚里整理家用物"],["外祖父","留在棚里整理家用，查看支架"],["安仁叔叔","留在棚里照应家人"]]:rows[pair[0]].label=pair[1]
	elif day==2 or day==3:
		rows["罗瑾"]=_work_row("罗瑾","到近处取水" if day==2 else "按昨天认过的路再去取水","water",true,{"water":2})
		rows["母亲"].label="留在棚里整理家事" if day==2 else "留在棚里照看家事"
		rows["外祖父"].label="留在棚里整理家用，查看支架"
		rows["安仁叔叔"].label="留在棚里照应家人" if day==2 else "留在棚区照应家里"
		if day==3:rows["外祖父"]=_work_row("外祖父","到附近寻找能用的木料","wood",true,{"wood":2})
	else:
		if day==4:rows["母亲"]=_work_row("母亲","去已打听到的救济点排队","relief",true,{"rice":2})
		if day in [5,9]:rows["安仁叔叔"]=_work_row("安仁叔叔","去委员会问过的地方做杂务","committee",true,{"rice":2})
		if day==6:rows["外祖父"]=_work_row("外祖父","到附近收拢可以烧的旧木料","wood",true,{"wood":5 if state.balanceVersion=="I2f" else 3})
	if day>=4 and day!=8:
		var needs: Array=[]
		if state.water<=2 and state.waterCap>state.water and not rows["罗瑾"].outside:needs.append({"name":"罗瑾","key":"water","amount":2,"label":"家里存水不多，去认过的近处取水"})
		if state.wood<=3 and not rows["外祖父"].outside:needs.append({"name":"外祖父","key":"wood","amount":4 if state.balanceVersion=="I2f" else 2,"label":"烧火的木料不多，到附近再找一找"})
		needs=needs.filter(func(n):return present(n.name) and state.people[n.name].health>3)
		# JavaScript stable sort keeps water before wood on a tied resource pressure.
		if needs.size()==2 and float(state[needs[0].key])/(2 if needs[0].key=="water" else 3)>float(state[needs[1].key])/(2 if needs[1].key=="water" else 3):needs.reverse()
		if not needs.is_empty() and float(RNG.hash_seed(state.seed+":nearby:"+str(day)))/4294967296.0<0.8:
			var n: Dictionary=needs[0];rows[n.name]=_work_row(n.name,n.label,n.key,true,{n.key:n.amount});rows[n.name].reason="resource-need"
	for person in PEOPLE:
		var p: Dictionary=state.people[person];var row: Dictionary=rows[person]
		if not p.get("alive",false):row.inactive=true;row.outside=false;row.base={};row.label="已经死亡"
		elif p.get("away",false) or p.get("permanentLost",false) or p.get("detainedUntil")!=null:row.inactive=true;row.outside=false;row.base={};row.label=person_presence_label(person)
		elif row.outside and (p.health<=3 or state.ailments[person].values().any(func(x):return x>=3)):row.outside=false;row.type="home";row.base={};row.label="身体撑不住，今天留在棚里"
		elif row.outside and current_weather().get("severe",false) and (not tool_available("umbrella") or current_weather().id in ["blizzard","hail"]):row.outside=false;row.type="home";row.base={};row.label="天气恶劣，今天暂不出门"
	var pickup: bool=day>=6 and plan_pigeon_pickup(day,"first-week-story" if day==8 else null,false)
	if pickup:rows["罗瑾"]=_work_row("罗瑾","按核对过的纸条取物，今天不做普通差事","pigeonPickup",true,{})
	var targets: Array=[]
	for person in PEOPLE:
		if rows[person].outside and not rows[person].get("inactive",false):targets.append(person)
	if PEOPLE.any(func(person):return not rows[person].outside and not rows[person].get("inactive",false)):targets.append("home")
	var result: Dictionary={"day":day,"rows":rows,"targets":["罗瑾"] if pickup else targets}
	if pickup:result.key="pigeonPickup";result.primary="罗瑾"
	return result

const TOOL_NAMES={"axe":"斧头","shovel":"铲子","scissors":"剪刀","rope":"绳索","umbrella":"雨伞","lamp":"煤油灯","whistle":"哨子","pole":"扁担","bandage":"绷带","herbs":"草药","medkit":"常备药包","canteen":"水壶","bucket":"水桶","gooseEgg":"鹅蛋"}
func queue_focus_packet(effects: Array,key: String,timing: String,subject: String="family") -> Dictionary:
	var f: Dictionary=state.focus;var id: String=state.seed+":D"+str(int(state.day)+1)+":"+key
	if not f.has("resultPackets"):f.resultPackets=[]
	for packet in f.resultPackets:
		if packet.id==id:return packet
	var packet: Dictionary={"id":id,"sourceEventInstanceId":"D"+str(int(state.day)+1)+":"+key.split(":")[0],"timing":timing,"subjectId":"family" if subject=="home" else subject,"effects":effects.duplicate(true),"proseId":key,"revealTo":["player"],"knowledgeFactIds":[],"scheduledDay":state.day,"condition":null,"cancelReason":null,"status":"pending"}
	f.resultPackets.append(packet);return packet
func apply_packet_spirit(packet: Dictionary,effect: Dictionary,index: int) -> bool:
	var metadata: Dictionary=_object(effect.get("spiritFact"))
	return apply_spirit_fact({"factId":metadata.get("factId",packet.id),"person":effect.target,"domain":metadata.get("domain","spirit"),"subfact":metadata.get("subfact","effect-"+str(index)),"amount":effect.amount,"source":packet.id,"requiresKnowledge":metadata.get("requiresKnowledge",false),"knowledgeScope":metadata.get("knowledgeScope","")})
func apply_focus_effects(effects: Array,key: String,timing: String="immediate",subject: String="family") -> Array:
	var notes: Array=[];var packet:=queue_focus_packet(effects,key,timing,subject)
	if not state.has("effectLedger"):state.effectLedger={"appliedEffectIds":[]}
	if packet.status!="pending" or packet.id in state.effectLedger.appliedEffectIds:return notes
	if packet.subjectId in PEOPLE and not present(packet.subjectId):packet.status="cancelled";packet.cancelReason="人物已经死亡或未返家";return notes
	for i in range(packet.effects.size()):
		var effect: Dictionary=packet.effects[i]
		match effect.type:
			"resource_delta":state[effect.resource]=maxf(0,minf(state.waterCap if effect.resource=="water" else INF,state[effect.resource]+effect.amount))
			"shelter_delta":state.shelter=clampf(state.shelter+effect.amount,0,50)
			"character_health":state.people[effect.target].health=clampf(state.people[effect.target].health+effect.amount,0,10)
			"character_spirit":apply_packet_spirit(packet,effect,i)
			"ailment_reduce":
				if present(effect.target):change_ailment(effect.target,effect.ailment,-effect.amount)
			"flag_set":state.memory[effect.flag]=effect.value
			"item_consume":state.tools[effect.item]=false
			"item_gain":
				var shelf: bool=effect.item in ["oilcloth","mat","bedding"]
				var target: Dictionary=state.shelterItems if shelf else state.tools
				var name: String={"oilcloth":"油布","mat":"芦席","bedding":"被褥"}.get(effect.item,TOOL_NAMES.get(effect.item,""))
				if target.get(effect.item,false):
					var reward: String="rice" if effect.item=="whistle" else "wood";state[reward]+=1
					notes.append("家里已有"+name+"，这件多出来的换成了"+("米粮" if reward=="rice" else "木料")+"×1。")
				else:
					target[effect.item]=true
					if shelf:notes.append("带回"+name+"×1。")
	packet.status="applied";state.effectLedger.appliedEffectIds.append(packet.id)
	return notes

# Fresh day-2 authored home scene only. Conditional/late focus generation is a separate port.
var first_focus_events: Dictionary={}
var early_focus_prose: Dictionary={}
var first_week_focus_prose: Dictionary={}
var focus_source_events: Array=[]
var focus_narrative_fragments: Dictionary={}
func ensure_first_day_focus() -> Dictionary:
	return ensure_early_focus()
func ensure_early_focus() -> Dictionary:
	if state.ended or state.day<1 or state.day>9 or not present("罗瑾"):return {}
	if state.focus.get("day")==state.day and state.focus.get("plan")!=null:return state.focus
	if not early_household_supported():
		fail_contract("CONDITIONAL_FOCUS_PENDING","条件白天事件尚未完成迁移。");return {}
	var template=JSON.parse_string(FileAccess.get_file_as_string("res://data/native_base_state_template.json"))
	state.focus=template.focus.duplicate(true);var f: Dictionary=state.focus;f.day=state.day
	f.grandfatherRecoveryRevision="R4c";f.characterRevision="R4a";f.uncleRevision="R4b";f.neighbourhoodRevision="R2b";f.integrationReadingRevision="FINAL-INTEGRATION";f.earlyReadingRevision="I3e-4b1";f.earlyDiaryRevision="R1"
	f.plan=make_first_week_plan();f.knowledge={"player":[],"luo":[]};f.resultPackets=[]
	if f.plan.get("key")=="pigeonPickup":
		bind_pigeon_pickup(f);f.earlyReadingEvents={};queue_pigeon_focus_work(f);apply_pigeon_public_snapshot(f);return f
	var ids: Dictionary={1:{"home":"evt.d01.home.arrival_passage.v1"},2:{"罗瑾":"evt.d02.luo.first_water.v1","home":"evt.d02.home.store_belongings.v1"},3:{"罗瑾":"evt.d03.luo.water_rumor.v1","外祖父":"evt.d03.grandfather.unstable_timbers.v1","home":"evt.d03.home.clear_passage.v1"}}
	f.plan.eventIds={}
	for target in f.plan.targets:f.plan.eventIds[target]=ids[int(state.day)].get(target) if state.day<4 else week_event_id(target,f.plan)
	if state.day<4:
		if early_focus_prose.is_empty():early_focus_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/early_focus_prose.json"))
		var presence:=0
		for i in range(PEOPLE.size()):
			if present(PEOPLE[i]):presence|=1<<i
		var outside: int=(1 if f.plan.rows["罗瑾"].outside else 0)+(2 if f.plan.rows["外祖父"].outside else 0)
		var assets: int=(1 if tool_available("whistle") else 0)+(2 if tool_available("rope") else 0)+(4 if state.wood==0 else 0)
		var key:=JSON.stringify([int(state.day),presence,outside,assets,1 if f.plan.rows["罗瑾"].get("reason")=="resource-need" else 0])
		f.earlyReadingEvents={}
		for id in f.plan.eventIds.values():
			if id!=null:f.earlyReadingEvents[id]=early_focus_prose.events[early_focus_prose.variants[key][id]].duplicate(true)
	else:
		if first_week_focus_prose.is_empty():first_week_focus_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/first_week_focus_prose.json"))
		var outside:=0;var talk:=0
		for i in range(PEOPLE.size()):
			if f.plan.rows[PEOPLE[i]].outside:outside|=1<<i
			if understands(PEOPLE[i]):talk|=1<<i
		var assets: int=(1 if tool_available("whistle") else 0)+(2 if tool_available("rope") else 0)+(4 if state.wood==0 else 0)
		var key:=JSON.stringify([int(state.day),outside,assets,1 if f.plan.rows["罗瑾"].get("reason")=="resource-need" else 0,talk if state.day>=8 else 15])
		var bank: Dictionary=first_week_focus_prose
		if household_presence_mask()!=15:
			if missing_focus_prose.is_empty():missing_focus_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/first_week_missing_focus_prose.json"))
			bank=missing_focus_prose
			key=JSON.stringify([int(state.day),household_presence_mask(),outside,assets,1 if f.plan.rows["罗瑾"].get("reason")=="resource-need" else 0,talk if state.day>=8 else household_presence_mask()])
		f.earlyReadingEvents={}
		for id in f.plan.eventIds.values():
			if id!=null:f.earlyReadingEvents[id]=bank.events[bank.variants[key][id]].duplicate(true)
	f.workPackets={}
	for row in f.plan.rows.values():
		if not row.get("inactive",false) and not row.base.is_empty():
			var effects: Array=[]
			for resource in row.base:effects.append({"type":"shelter_delta","amount":row.base[resource]} if resource=="shelter" else {"type":"resource_delta","resource":resource,"amount":row.base[resource]})
			f.workPackets[row.name]=queue_focus_packet(effects,"work:"+row.name,"on_return",row.name).id
	if state.day>=4:
		var family_bank: Dictionary=first_week_focus_prose if household_presence_mask()==15 else missing_focus_prose
		var family_key: String=str(int(state.day)) if household_presence_mask()==15 else JSON.stringify([int(state.day),household_presence_mask()])
		if family_bank.public_family.has(family_key):f.r4v3PublicFamilyText=family_bank.public_family[family_key].duplicate(true)
	return f

func enter_first_day_focus() -> bool:
	if not acknowledge_solitary_warning():return false
	if ensure_first_day_focus().is_empty():return false
	state.phase="focus";return true
func select_first_day_focus(target: String) -> bool:
	var f:=ensure_early_focus()
	if _object(f.get("plan")).get("key")=="pigeonPickup":return select_day_eleven_twelve_focus(target)
	return _pigeon_parent_1_select_first_day_focus(target)

func current_first_focus_event() -> Dictionary:
	if _object(state.focus.get("plan")).get("key")=="pigeonPickup":return current_later_focus_event()
	return _pigeon_parent_1_current_first_focus_event()

func focus_choice_requirement(choice: Variant) -> Dictionary:
	if choice is Dictionary and choice.get("later",false) and current_first_focus_event().get("pigeonPickup",false):return ordinary_pre_photo_requirement(choice)
	return _pigeon_parent_1_focus_choice_requirement(choice)

func resolve_first_day_focus_choice(index: int) -> bool:
	if current_first_focus_event().get("pigeonPickup",false):return commit_pigeon_choice_core(index)
	return _pigeon_parent_1_resolve_first_day_focus_choice(index)

func apply_early_focus_base_work() -> Array:
	var f: Dictionary=state.focus;var lines: Array=[]
	for person in PEOPLE:
		var row: Dictionary=f.plan.rows[person];var p: Dictionary=state.people[person];var packet: Dictionary={}
		for candidate in f.resultPackets:
			if candidate.id==f.workPackets.get(person):packet=candidate;break
		if row.get("inactive",false) or not p.alive or p.away:
			if packet.get("status")=="pending":packet.status="cancelled";packet.cancelReason="人物已经死亡或未返家"
			continue
		if f.cancelWork==person:
			if not packet.is_empty():packet.status="cancelled";packet.cancelReason="白天事件完全打断工作"
			lines.append("罗瑾空着容器回到棚里；今天这趟水没有增加家里的存水。" if person=="罗瑾" else person+"没有完成原定的日常工作。");continue
		var before:=focus_snapshot()
		if not packet.is_empty():
			if f.partialWork==person:
				packet.status="cancelled";packet.cancelReason="白天事件部分打断工作";var reduced: Array=packet.effects.duplicate(true)
				for effect in reduced:effect.amount=maxf(1,effect.amount-1)
				apply_focus_effects(reduced,"work:"+person+":partial","on_return",person)
			else:apply_focus_effects(packet.effects,"work:"+person,"on_return",person)
		if row.type=="water":lines.append("罗瑾把水带了回来。" if state.water>before.water else "罗瑾把水带回棚里，但现有容器已经装满，没能多储水。")
		elif row.type=="wood":lines.append("外祖父在天黑前把木料带回棚边。")
		elif row.type in ["relief","committee"]:
			lines.append("母亲把领到的米交给家里收好。" if row.type=="relief" else "安仁叔叔带回做杂务换来的米。")
			if row.type=="committee":apply_focus_effects([{"type":"flag_set","flag":"committeeWorkSeen","value":true}],"work:"+person+":known-desk","on_return",person)
	return lines
func settle_first_day_focus_return() -> bool:
	if current_first_focus_event().get("pigeonPickup",false):return settle_pigeon_focus_return()
	return _pigeon_parent_1_settle_first_day_focus_return()

func focus_snapshot() -> Dictionary:
	return {"rice":state.rice,"water":state.water,"wood":state.wood,"shelter":state.shelter,"moisture":state.moisture,"people":state.people.duplicate(true),"tools":state.tools.duplicate(),"shelterItems":state.shelterItems.duplicate(),"animals":state.animals.duplicate(true),"photo":{"skill":state.photo.skill,"prints":state.photo.prints,"selected":state.photo.album.selected,"transferred":state.photo.transferCount}}
func describe_focus_change(before: Dictionary) -> String:
	var base: String=_chapter5_parent_10_describe_focus_change(before)
	if state.day<24:return base
	var parts: Array=[] if base.is_empty() else [base]
	if before.photo.get("skill")!=null and photo_skill_label(before.photo.skill)!=photo_skill_label(state.photo.skill):parts.append("罗瑾帮工熟练："+photo_skill_label(state.photo.skill))
	for pair in [["prints","加印照片",state.photo.prints],["selected","选定照片",state.photo.album.selected],["transferred","转移照片",state.photo.transferCount]]:
		var delta: float=float(pair[2])-float(before.photo[pair[0]])
		if delta!=0:parts.append(pair[1]+("＋" if delta>0 else "－")+JS_JSON.encode(absf(delta)))
	return "，".join(parts)

func apply_current_night_dawn(cycle: Dictionary) -> void:
	var r: Dictionary=_object(cycle.get("readingDawn"));var p: Dictionary=_object(r.get("nightProse"))
	if p.get("revision")!=NIGHT_PROSE_REV or not r.get("losses",[]).is_empty():return
	var v: Dictionary=p.context;var scene:=_night_scene(p)
	if r.type=="family":
		r.diary=FamilyProse.diary(p,scene);r.summary=FamilyProse.summary(p)
		if p.bucket=="hunger":
			var key: String="hungerA1" if cycle.hungerRevision=="A1" else "hungerA3cPersonV1"
			var h: Dictionary=_object(_object(state.memory.get(key)).get("罗瑾"));var fed: bool="罗瑾" in _object(cycle.get("survivalCare")).get("fed",[])
			var tail: String="我当天在外吃过的那一顿仍算数，没有跟着家里再饿一次。" if "罗瑾" in v.ateOutside else ("后来这一顿确实吃上了，等在锅边的工夫终于有了真正的收束。" if fed else ("这一顿最终没有吃上，今早的身体还要照眼前的样子顾着。" if h.get("day")==cycle.day and h.get("count",0)>0 else ""))
			if r.luoWitness and tail!="":r.diary=_prose_paragraphs([r.diary,tail])
		elif p.bucket=="care":r.diary=_prose_paragraphs([r.diary,"今早再看，昨夜歇稳的那一会儿还记得，眼下仍需要怎样照料，却得看现在的身体，不能只照昨夜说过的话办。"])
		elif p.bucket=="damp":r.diary=_prose_paragraphs([r.diary,"到了天亮，才重新看清哪里仍潮、哪里需要白天找木料处理。昨夜那番挪动只是挪动，没有添过新的支撑。"])
	elif r.type=="mouse":
		var lost: bool=_object(cycle.get("mouseOutcome")).get("lost",0)!=0
		var lead: String="今早提起昨夜吊好的粮袋，清点没有少粮，绳索也还在。" if r.choice=="move" else ("昨夜"+("我" if r.actor=="罗瑾" else _person_label(r.actor))+"将粮袋挪近，收起散米；今早清点，"+("还是少了一份米粮。" if lost else "没有少粮。") if r.choice=="tidy" else "昨夜先歇下，今早才提起粮袋细看，"+("袋角有咬口，也确实少了一份米粮。" if lost else "有咬痕，米粮却没有少。"))
		r.diary=_prose_paragraphs([lead,scene.hook,scene.after]);r.summary="昨夜用绳索吊好粮袋，今晨清点未少粮，绳索仍在。" if r.choice=="move" else ("昨夜粮袋旁有动静，今晨清点确认少了一份米粮。" if lost else "昨夜粮袋旁有动静，今晨清点没有少粮。")
	elif r.type=="robbery" and r.choice=="resist":
		var who: String="我" if r.actor=="罗瑾" else _person_label(r.actor);var person: Dictionary=state.people[r.actor]
		var resolved: bool=person.get("alive",false) and state.ailments[r.actor].get("wound",0)==0 and person.health>2
		r.diary=_prose_paragraphs(["昨夜"+who+"试着阻拦，被日本兵殴打。这一次没有交出物资，仍不该拿东西留下了去抵掉人挨的打。",scene.hook,"后来原先安排的照料处理了伤处。今早的样子与刚挨打时不同，我不把夜里的伤再当成今晨新受的一次。" if resolved else ("到了清晨，仍要看"+("自己" if r.actor=="罗瑾" else "这位家人")+"眼下的伤与需要，不能因为东西还在便催着照常做事。" if person.get("alive",false) else "")])
	if not r.get("critical",[]).is_empty() and (r.type in ["family","mouse"] or (r.type=="robbery" and r.choice=="resist")):
		r.diary=_prose_paragraphs([r.diary,"".join(r.critical.map(func(person):return "今早我自己的身体已经很难支撑，昨天勉强做过的事，今天不能照样答应。" if person=="罗瑾" else _person_label(person)+"今早病弱得很重，眼下还需要照料。"))])

func check_early_critical() -> bool:
	if state.ended:return true
	if not state.memory.has("criticalWarnings"):state.memory.criticalWarnings={}
	var notices: Array=state.nightResults if state.phase in ["night","nightEvent"] else state.morningResults
	for person in PEOPLE:
		if not present(person):continue
		var p: Dictionary=state.people[person];var warning=state.memory.criticalWarnings.get(person)
		if p.health>2:state.memory.criticalWarnings.erase(person);continue
		if p.health<=0 and person!="罗瑾" and warning!=null and warning<state.day:
			var outcome:=kill_health_warning(person)
			if outcome.text!="":notices.append(outcome.text)
			continue
		if p.health<=0 and not (person=="罗瑾" and solitary_health_fatal_ready()):p.health=1
		if warning==null:
			state.memory.criticalWarnings[person]=state.day
			notices.append("罗瑾已经危重，日常的事也难以支撑。请尽快处理缺水、挨饿、受寒或伤病，不能继续靠他勉强承担风险。" if person=="罗瑾" else person+"已经危重；若继续缺水、挨饿、受寒或伤病恶化，可能撑不过下一夜。请留意照料、可用药物与保暖。")
	prepare_solitary_warning()
	return true

func deliver_fact(fact: Dictionary) -> Array:
	var book:=spirit_book();var accepted: Array=[];var visited: Array=[]
	for person in fact.recipients:
		if person in visited:continue
		visited.append(person)
		if person not in PEOPLE or not understands(person):continue
		var existing: Dictionary={}
		for row in book.knowledge:
			if row.get("factId")==fact.factId and row.get("person")==person and row.get("scope")==fact.scope:existing=row;break
		var delivery: Dictionary={"source":fact.source,"mode":fact.get("mode","told"),"day":state.day+1,"phase":state.phase}
		if existing.is_empty():book.knowledge.append({"factId":fact.factId,"person":person,"scope":fact.scope,"source":delivery.source,"mode":delivery.mode,"day":delivery.day,"phase":delivery.phase,"sources":[delivery]})
		else:
			if not js_truthy(existing.get("sources")):
				var prior: Dictionary={}
				for key in ["source","mode","day","phase"]:
					if existing.has(key):prior[key]=existing[key]
				existing.sources=[prior]
			if not existing.sources.any(func(row):return row.get("source")==fact.source):existing.sources.append(delivery)
		accepted.append(person)
	return accepted
func apply_death_shock(id: String,cap: float=1,spirit: float=2) -> bool:
	var book:=spirit_book()
	if not state.memory.has("lossShockIds"):state.memory.lossShockIds=[]
	if id in state.memory.lossShockIds and not book.death.has(id):return false
	if not book.death.has(id):book.death[id]={"cap":cap,"spirit":spirit,"recipients":[]}
	var record: Dictionary=book.death[id];var changed:=false
	for person in PEOPLE:
		if not knows_fact(person,id,"confirmed-death"):continue
		if apply_spirit_fact({"factId":id,"person":person,"domain":"death-shock","amount":-record.spirit,"capLoss":record.cap,"source":id,"requiresKnowledge":true,"knowledgeScope":"confirmed-death"}):record.recipients.append(person);changed=true
	if id not in state.memory.lossShockIds:state.memory.lossShockIds.append(id)
	return changed
func cancel_person_pending(person: String,cause: String) -> void:
	for packets in [state.focus.get("resultPackets",[]),state.get("pendingMorningPackets",[]),state.get("storySystemPackets",[])]:
		for packet in packets:
			if packet.status=="pending" and (person=="罗瑾" or packet.subjectId==person):packet.status="cancelled";packet.cancelReason=cause
	if state.focus.has("carriedAssets"):state.focus.carriedAssets=state.focus.carriedAssets.filter(func(asset):return person!="罗瑾" and asset.owner!=person)
	if _object(state.expedition.plan).get("name")==person:state.expedition.plan=null
	var expedition: Dictionary=_object(state.expedition.active)
	if expedition.get("name")==person:
		for id in expedition.get("tools",[]):state.tools[id]=false
		var archived: Dictionary=expedition.duplicate(true);archived.status="permanent_lost" if state.people[person].get("permanentLost",false) else "cancelled_by_death";archived.returnDay=null;archived.lossCause=cause
		state.expedition.history.append(archived);state.expedition.active=null;state.expedition.decision=null
	if not state.memory.has("closedCharacterArcs"):state.memory.closedCharacterArcs={}
	state.memory.closedCharacterArcs[person]={"day":state.day,"cause":cause}
	var plan: Dictionary=_object(state.focus.get("plan"));var row: Dictionary=_object(_object(plan.get("rows")).get(person))
	if not row.is_empty():row.inactive=true;row.outside=false;row.base={};row.label=person_presence_label(person)
	if plan.has("targets"):plan.targets=plan.targets.filter(func(name):return name!=person)
	if person=="罗瑾":
		state.focus.diaryAllowed=false;state.focus.chapterDiary=[];state.focus.knowledge={"player":[],"luo":[]}
		for node in state.get("fixedNodeStates",{}).values():
			if node.status not in ["resolved","skipped"]:node.status="closed_by_loss";node.fallback="罗瑾死亡，主线终止"
		state.pendingNightEvent=null;state.expedition.plan=null;state.expedition.decision=null
func kill_health_warning(person: String,cause: String="此前已告急的健康继续耗尽") -> Dictionary:
	var p: Dictionary=state.people.get(person,{})
	if not p.get("alive",false) or p.get("permanentLost",false):return {"kind":"none","text":""}
	var warning=_object(state.memory.get("criticalWarnings")).get(person)
	if person=="罗瑾" or not present(person) or p.health>0 or warning==null or warning>=state.day:return {"kind":"blocked","text":""}
	p.alive=false;p.away=false;p.health=0;p.erase("detainedUntil")
	var id: String=state.seed+":loss:"+person+":"+str(int(state.day))
	deliver_fact({"factId":id,"recipients":PEOPLE.filter(func(name):return understands(name)),"source":"在棚内守候并发现死亡","scope":"confirmed-death","mode":"witnessed"})
	apply_death_shock(id);state.memory.lastDeath={"name":person,"cause":cause,"day":state.day,"reviewId":"health-warning-v1"};cancel_person_pending(person,cause)
	state.history.append({"type":"person-loss","day":state.day,"name":person,"kind":"death","cause":cause,"reviewId":"health-warning-v1"})
	return {"kind":"death","text":{"母亲":"母亲没有撑过这一夜。她先前要留给家里用的东西还在原处，没有人再催着将它们搬开。","外祖父":"外祖父没有撑过这一夜。家里人守过他身边，天亮以后，仍给原来的位置留着空处。","安仁叔叔":"安仁叔叔没有撑过这一夜。他先前交代的往返还有人记得，天亮时却再也等不到他起身。"}[person]}
var solitary_contract: Dictionary={}
func ensure_solitary_warning_fact(warning: Dictionary) -> Dictionary:
	if solitary_contract.is_empty():solitary_contract=JSON.parse_string(FileAccess.get_file_as_string("res://data/c018_contract.json"))
	var contract: Dictionary=solitary_contract.contract
	if warning.get("rule")!=contract.rule or not _whole_number(warning.get("day")):return {}
	warning.contractRevision=contract.revision;warning.reviewId=contract.reviewId;warning.factId=warning.get("factId") if warning.get("factId")!=null and warning.get("factId")!="" else state.seed+":D"+str(int(warning.day)+1)+":c018-solitary-health-warning"
	if not state.has("knowledgeFacts"):state.knowledgeFacts=[]
	for fact in state.knowledgeFacts:
		if fact.id==warning.factId:
			fact.contentId=contract.warningContentId;fact.contractRevision=contract.revision;fact.day=warning.day+1
			var recipients: Array=[]
			for prior in (fact.knownBy if fact.get("knownBy") is Array else []):
				if prior not in recipients:recipients.append(prior)
			for person in ["player","罗瑾"]:
				if person not in recipients:recipients.append(person)
			fact.knownBy=recipients;fact.source=fact.get("source") if fact.get("source")!=null and fact.get("source")!="" else "清晨直接告知";fact.scope=contract.warningScope;fact.diaryEligible=false;return fact
	var fact: Dictionary={"id":warning.factId,"contentId":contract.warningContentId,"contractRevision":contract.revision,"day":warning.day+1,"knownBy":["player","罗瑾"],"source":"清晨直接告知","scope":contract.warningScope,"diaryEligible":false}
	state.knowledgeFacts.append(fact);return fact
func prepare_solitary_warning() -> bool:
	if state.ended or not present("罗瑾"):return false
	if PEOPLE.slice(1).any(func(person):return state.people[person].alive and not state.people[person].get("permanentLost",false)) or state.people["罗瑾"].health>2:state.memory.erase("solitaryHealthWarning");return false
	var existing: Dictionary=_object(state.memory.get("solitaryHealthWarning"))
	if not existing.is_empty():ensure_solitary_warning_fact(existing);return false
	if state.phase!="morning":return false
	if solitary_contract.is_empty():solitary_contract=JSON.parse_string(FileAccess.get_file_as_string("res://data/c018_contract.json"))
	var contract: Dictionary=solitary_contract.contract
	var warning: Dictionary={"day":state.day,"ackDay":null,"rule":contract.rule,"contractRevision":contract.revision,"reviewId":contract.reviewId}
	state.memory.solitaryHealthWarning=warning;ensure_solitary_warning_fact(warning);state.morningResults.append(solitary_contract.warning);return true

var early_care_prose: Dictionary={}
func focus_fit(person: String) -> bool:
	return state.people[person].health>3 and not state.ailments[person].values().any(func(value):return value>=3)
func ailment_text(person: String) -> String:
	var ailments: Dictionary=ensure_ailments()[person];var parts: Array=[]
	for type in AILMENT_TYPES:
		if ailments[type]!=0:parts.append(AILMENT_LABELS[type]+["","轻微","较重","严重"][int(ailments[type])])
	return "、".join(parts)
func _replace_content_token(value: Variant,token: String,replacement: String) -> Variant:
	if value is String:return value.replace(token,replacement)
	if value is Array:return value.map(func(item):return _replace_content_token(item,token,replacement))
	if value is Dictionary:
		var result: Dictionary={}
		for key in value:result[key]=_replace_content_token(value[key],token,replacement)
		return result
	return value
func make_early_care_event(focus: Dictionary) -> Dictionary:
	var unfit:=0;var home: Array=[]
	for i in range(PEOPLE.size()):
		if not present(PEOPLE[i]) or not focus_fit(PEOPLE[i]):unfit|=1<<i
		if present(PEOPLE[i]) and not focus.plan.rows[PEOPLE[i]].outside:home.append(PEOPLE[i])
	home.sort_custom(func(a,b):return PEOPLE.find(a)<PEOPLE.find(b) if state.people[a].health==state.people[b].health else state.people[a].health<state.people[b].health)
	var patient: String=""
	for person in home:
		if not focus_fit(person):patient=person;break
	if patient=="":return {}
	var outside: int=(1 if focus.plan.rows["罗瑾"].outside else 0)+(2 if focus.plan.rows["外祖父"].outside else 0)
	if state.day>=4:
		outside=0
		for i in range(PEOPLE.size()):
			if focus.plan.rows[PEOPLE[i]].outside:outside|=1<<i
	var key:=JSON.stringify([int(state.day),unfit,outside,PEOPLE.find(patient),1 if state.water>0 else 0])
	if early_care_prose.is_empty():early_care_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/early_care_prose.json"))
	var bank: Dictionary=early_care_prose
	if household_presence_mask()!=15:
		if missing_care_prose.is_empty():missing_care_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/missing_care_prose.json"))
		bank=missing_care_prose;key=JSON.stringify([int(state.day),household_presence_mask(),unfit,outside,PEOPLE.find(patient),1 if state.water>0 else 0])
	if not bank.variants.has(key):fail_contract("CARE_CONTENT_PENDING","当前照料正文条件尚未编译。");return {}
	var description:=ailment_text(patient)
	var event: Dictionary=_replace_content_token(bank.events[bank.variants[key]],"§AILMENT_DESCRIPTION§",description if description!="" else "身上很不舒服")
	var prior: int=state.history.filter(func(row):return row.day<state.day and row.type=="focus-event" and (_object(row.get("readingVariant")).get("kind")=="care" or str(row.get("event","")).ends_with(".care"))).size()
	for parts in event.earlyDiaryParts.values():parts.priorCount=prior
	# The authoritative source applies its D5/D6 wording edits only on a fresh selection.
	# Returning before choosing regenerates the care fallback without those fresh-only edits.
	if int(state.day) in [4,5] and (focus.get("selected")!=null or focus.get("eventId")!=null):
		var patches=JSON.parse_string(FileAccess.get_file_as_string("res://data/care_reselect_text.json"))
		var patch: Dictionary=patches.pairs[str(int(state.day))]
		event=_replace_content_token(event,patch.fresh,patch.reselected)
	return event

func source_focus_event(id: String) -> Dictionary:
	if focus_source_events.is_empty():focus_source_events=JSON.parse_string(FileAccess.get_file_as_string("res://data/focus_events.json"))
	for event in focus_source_events:
		if event.id==id:return event
	return {}
func focus_event_eligible(event: Dictionary,plan: Dictionary) -> bool:
	if event.is_empty() or event.get("later",false):return false
	for person in event.get("participants",PEOPLE):
		if not present(person):return false
	for person in event.get("homeParticipants",[]):
		if _object(plan.rows.get(person)).get("outside",false):return false
	var required_out: Array={"evt.d05.home.entrusted_bundle.v1":["母亲"],"evt.d06.home.salvage.v1":["安仁叔叔"],"evt.d07.home.care.v1":["外祖父"],"evt.d10.home.names.v1":["安仁叔叔"]}.get(event.id,[])
	return required_out.all(func(person):return _object(plan.rows.get(person)).get("outside",false))
func week_event_id(target: String,plan: Dictionary) -> Variant:
	if target=="home" and state.day==8:return "r21.d09.home.lusu-arrival"
	if target=="home" and state.day==9:return "r21.d10.home.lusu-sources"
	if focus_source_events.is_empty():focus_source_events=JSON.parse_string(FileAccess.get_file_as_string("res://data/focus_events.json"))
	var candidates: Array=focus_source_events.filter(func(event):return event.get("day")==state.day+1 and event.get("target")==target and focus_event_eligible(event,plan))
	return candidates[0].id if not candidates.is_empty() else null
func focus_narrative(text: String) -> String:
	if focus_narrative_fragments.is_empty():focus_narrative_fragments=JSON.parse_string(FileAccess.get_file_as_string("res://data/focus_narrative_fragments.json"))
	var owned: Dictionary=state.focus.get("textContext",state.shelterItems)
	for token in focus_narrative_fragments.tokens:
		var key: String="oilcloth" if token.begins_with("oilcloth") else ("mat" if token.begins_with("mat") else "whistle")
		text=text.replace("{{"+token+"}}",focus_narrative_fragments.tokens[token]["true" if owned.get(key,false) else "false"])
	return text
func focus_choice_text(choice: Dictionary,field: String,outcome: String) -> String:
	var text:=focus_narrative(str(_object(choice.get(field)).get(outcome,_object(choice.get(field)).get("default",""))))
	var f: Dictionary=state.focus
	if f.get("fullReviewSalvageRevision")=="WebR1-family-prose-v1" and f.eventId=="evt.d06.home.salvage.v1" and field=="diaries":
		for patch in focus_narrative_fragments.salvage:
			if choice.id==patch.choice and text==patch.before:return patch.after
	return text

const EARLY_KNOWLEDGE_REV="r4v3-d10-survivors-knowledge-v1"
const EARLY_KNOWLEDGE_EVENT="r21.d10.home.lusu-sources"
const EARLY_KNOWLEDGE_SCOPE="heard-lusu-survivors-account"
func early_knowledge_applies(event: Dictionary,choice: Dictionary) -> bool:
	return state.day==9 and state.focus.day==9 and event.get("id")==EARLY_KNOWLEDGE_EVENT and choice.get("id")=="survivors" and choice.get("r4v3KnowledgeRevision")==EARLY_KNOWLEDGE_REV
func early_knowledge_receipt(event: Dictionary,choice: Dictionary) -> Dictionary:
	var receipt: Dictionary=_object(state.focus.get("r4v3KnowledgeReceipt"))
	return receipt if early_knowledge_applies(event,choice) and receipt.get("revision")==EARLY_KNOWLEDGE_REV else {}
func early_at_scene(person: String) -> bool:
	var row: Dictionary=_object(state.focus.plan.rows.get(person))
	return understands(person) and not row.is_empty() and not row.get("outside",false) and not row.get("inactive",false)
func cancel_early_knowledge(packet: Dictionary,receipt: Dictionary,reason: String) -> void:
	if packet.get("status")=="pending":packet.status="cancelled";packet.cancelReason=reason;receipt.status="cancelled";receipt.cancelReason=reason
func apply_early_knowledge(packet: Dictionary,receipt: Dictionary) -> void:
	apply_focus_effects(packet.effects,receipt.packetKey,packet.timing,"罗瑾");receipt.status=packet.status
func prepare_early_knowledge_choice(event: Dictionary,choice: Dictionary) -> void:
	var f: Dictionary=state.focus
	if not early_knowledge_applies(event,choice) or f.get("r4v3KnowledgeReceipt")!=null:return
	if state.ended or state.phase!="focusEvent" or f.selected!="home" or f.choiceIndex!=null:return
	var direct:=early_at_scene("罗瑾");var reporter: Variant="罗瑾" if direct else null
	if not direct:
		for person in ["母亲","安仁叔叔","外祖父"]:
			if early_at_scene(person):reporter=person;break
	var key: String=EARLY_KNOWLEDGE_EVENT+":survivors:knowledge-spirit-v1";var fact: String=state.seed+":D10:"+EARLY_KNOWLEDGE_EVENT+":survivors:heard-account"
	var timing: String="immediate" if direct else "on_return"
	var effect: Dictionary={"type":"character_spirit","target":"罗瑾","amount":-1,"spiritFact":{"factId":fact,"domain":"spirit","subfact":"heard-account","requiresKnowledge":true,"knowledgeScope":EARLY_KNOWLEDGE_SCOPE}}
	var packet:=queue_focus_packet([effect],key,timing,"罗瑾");packet.contractRevision=EARLY_KNOWLEDGE_REV;packet.knowledgeFactIds=[fact];packet.revealTo=["player","罗瑾"];packet.condition={"contractRevision":EARLY_KNOWLEDGE_REV,"requiresActualKnowledge":true,"reporter":reporter,"scope":EARLY_KNOWLEDGE_SCOPE}
	var receipt: Dictionary={"revision":EARLY_KNOWLEDGE_REV,"eventId":EARLY_KNOWLEDGE_EVENT,"choiceId":"survivors","day":10,"reporter":reporter,"mode":"direct" if direct else "on_return","factId":fact,"scope":EARLY_KNOWLEDGE_SCOPE,"packetId":packet.id,"packetKey":key,"status":"pending","cancelReason":null};f.r4v3KnowledgeReceipt=receipt
	if reporter==null:cancel_early_knowledge(packet,receipt,"no_conscious_scene_listener");return
	var delivered:=deliver_fact({"factId":fact,"recipients":[reporter],"scope":EARLY_KNOWLEDGE_SCOPE,"source":packet.id+":scene","mode":"witnessed"})
	if reporter not in delivered:cancel_early_knowledge(packet,receipt,"scene_account_not_received");return
	if direct:
		if not knows_fact("罗瑾",fact,EARLY_KNOWLEDGE_SCOPE):cancel_early_knowledge(packet,receipt,"direct_account_not_received");return
		apply_early_knowledge(packet,receipt)
func early_knowledge_missing(event: Dictionary,choice: Dictionary) -> bool:
	var receipt:=early_knowledge_receipt(event,choice)
	return not receipt.is_empty() and (not knows_fact("罗瑾",receipt.factId,EARLY_KNOWLEDGE_SCOPE) or not understands("罗瑾"))
func settle_early_knowledge_return(event: Dictionary,choice: Dictionary) -> Dictionary:
	var receipt:=early_knowledge_receipt(event,choice)
	if receipt.is_empty():return {}
	var f: Dictionary=state.focus;var packet: Dictionary={}
	for candidate in f.resultPackets:
		if candidate.id==receipt.packetId:packet=candidate;break
	if packet.is_empty() or packet.get("contractRevision")!=EARLY_KNOWLEDGE_REV:fail_contract("KNOWLEDGE_PACKET_MISSING","D10 知情结果包缺失。");return {"canReport":false,"luoKnown":false}
	if packet.status=="pending":
		var reason: String=""
		if state.ended or state.phase!="focusResult" or f.settled:reason="not_actual_return_settlement"
		elif not understands("罗瑾") or f.plan.rows["罗瑾"].get("inactive",false):reason="recipient_unavailable_or_unable_to_understand"
		elif receipt.reporter==null or receipt.reporter=="罗瑾" or not understands(receipt.reporter) or not knows_fact(receipt.reporter,receipt.factId,EARLY_KNOWLEDGE_SCOPE):reason="original_scene_listener_unavailable"
		elif not focus_event_eligible(event,f.plan):reason="existing_event_return_gate_not_met"
		if reason!="":cancel_early_knowledge(packet,receipt,reason)
		else:
			var delivered:=deliver_fact({"factId":receipt.factId,"recipients":["罗瑾"],"scope":EARLY_KNOWLEDGE_SCOPE,"source":packet.id,"mode":"told"})
			if "罗瑾" in delivered and knows_fact("罗瑾",receipt.factId,EARLY_KNOWLEDGE_SCOPE):apply_early_knowledge(packet,receipt)
			else:cancel_early_knowledge(packet,receipt,"return_account_not_received")
	var known:=knows_fact("罗瑾",receipt.factId,EARLY_KNOWLEDGE_SCOPE)
	return {"canReport":known,"luoKnown":known and understands("罗瑾")}
func focus_diary_text() -> String:
	if state.ended or not state.people["罗瑾"].alive:return ""
	var event:=current_first_focus_event();var f: Dictionary=state.focus
	if event.is_empty() or f.choiceIndex==null:return ""
	var choice: Dictionary=event.choices[f.choiceIndex]
	if not present("罗瑾") or not focus_event_eligible(event,f.plan) or early_knowledge_missing(event,choice):return "这一页没有留下能够确认的返家转述。"
	var composed: Dictionary=_object(_object(event.get("earlyDiaryParts")).get(choice.id))
	if not composed.is_empty():return _prose_paragraphs([composed.event]+f.get("unseen",[])+[composed.family,composed.reflection])
	var parts: Array=[];var diary:=focus_choice_text(choice,"diaries",f.outcomeKey)
	if diary!="":parts.append(diary)
	if not f.get("unseen",[]).is_empty() and not parts.is_empty():
		if f.selected!="home":parts=f.unseen.duplicate()+parts
		else:
			for text in f.unseen:
				for pair in [["娘回来后说","把棚里的事讲完，娘也说起自己的那一趟"],["叔叔说","说过棚里的旧物，叔叔又提起"],["外祖父回来说","外祖父歇过以后，也说起"]]:
					if text.begins_with(pair[0]):text=pair[1]+text.substr(pair[0].length())
				parts.append(text)
	return _prose_paragraphs(parts)

var first_week_outdoor_prose: Dictionary={}
func make_first_week_outdoor_event(target: String) -> Dictionary:
	if state.day<1 or state.day>9 or target not in ["罗瑾","外祖父"]:return {}
	var row: Dictionary=state.focus.plan.rows[target]
	if row.type!=("water" if target=="罗瑾" else "wood") or not row.outside:return {}
	if first_week_outdoor_prose.is_empty():first_week_outdoor_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/first_week_outdoor_prose.json"))
	if target=="外祖父":return first_week_outdoor_prose.events[JSON.stringify([int(state.day),target,tool_available("axe")])].duplicate(true)
	var prior: Array=state.history.filter(func(history):return history.get("day",state.day)<state.day and _object(history.get("readingVariant")).get("group")=="water")
	var index: int=(RNG.hash_seed(state.seed+":condition-story:water")+prior.size())%3
	var event: Dictionary=first_week_outdoor_prose.events[JSON.stringify([int(state.day),target,index,state.water>=2])].duplicate(true)
	event.readingVariant.previous=prior[-1].day if not prior.is_empty() else null
	if prior.size()==1:
		var previous: String=prior[0].get("choice","");var key: String=previous if previous in ["help","pole_help"] else "carry_home"
		for choice in event.choices:choice.diaries.default+="\n\n"+first_week_outdoor_prose.prior_reflections[key]
	return event

var first_week_home_prose: Dictionary={}
func decode_home_content(value: Variant,bank: Dictionary={}) -> Variant:
	if bank.is_empty():bank=first_week_home_prose
	if value is Dictionary:
		if value.size()==1 and value.has("$s"):return bank.strings[int(value["$s"])]
		var result: Dictionary={}
		for key in value:result[key]=decode_home_content(value[key],bank)
		return result
	if value is Array:return value.map(func(item):return decode_home_content(item,bank))
	return value
func make_first_week_home_event(focus: Dictionary) -> Dictionary:
	if state.day<4 or state.day>9 or PEOPLE.filter(func(person):return present(person)).is_empty():return {}
	var outside:=0
	for i in range(PEOPLE.size()):
		if not present(PEOPLE[i]):continue
		if focus.plan.rows[PEOPLE[i]].outside:outside|=1<<i
		elif not focus_fit(PEOPLE[i]) or character_rest_reason(PEOPLE[i])!="":return {}
	if outside==15:return {}
	if first_week_home_prose.is_empty():first_week_home_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/first_week_home_prose.json"))
	var bank: Dictionary=first_week_home_prose
	if household_presence_mask()!=15:
		if missing_home_prose.is_empty():missing_home_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/missing_home_prose.json"))
		bank=missing_home_prose
	var kind: String="weather" if current_weather().get("severe",false) else ("home" if household_presence_mask()==15 else "absence")
	var prior: Array=[];var index:=0;var stock:=0;var reflected:=false
	if kind=="weather":
		prior=state.history.filter(func(row):return row.get("day",state.day)<state.day and _object(row.get("readingVariant")).get("revision")==bank.weather_revision and row.readingVariant.kind=="weather")
		var last: Dictionary={}
		for row in prior:last[int(row.readingVariant.index)]=row.day
		var offset: int=RNG.hash_seed(state.seed+"|"+bank.weather_revision+"|weather")%3;index=-1
		for step in range(3):
			var candidate: int=(offset+step)%3
			if not last.has(candidate):index=candidate;break
		if index<0:
			var candidates: Array=[0,1,2];candidates.sort_custom(func(a,b):return a<b if last[a]==last[b] else last[a]<last[b]);index=candidates[0]
		stock=(1 if state.wood>=1 else 0)+(2 if state.shelter>=50 else 0)+(4 if state.shelterItems.oilcloth else 0)
		reflected=state.history.any(func(row):return row.get("day",state.day)<state.day and row.get("type")=="focus-event" and (_object(row.get("readingVariant")).get("kind")=="weather" or str(row.get("event","")).ends_with(".weather")))
	else:
		prior=state.history.filter(func(row):return row.get("day",state.day)<state.day and _object(row.get("readingVariant")).get("group")=="shelter")
		index=(RNG.hash_seed(state.seed+":condition-story:shelter")+prior.size())%3
	var key:=JSON.stringify([int(state.day),outside,kind,index,stock,reflected])
	if household_presence_mask()!=15:key=JSON.stringify([int(state.day),household_presence_mask(),outside,kind,index,stock,reflected])
	if not bank.variants.has(key):fail_contract("HOME_CONTENT_PENDING","当前留棚正文条件尚未编译。");return {}
	var event: Dictionary=decode_home_content(bank.events[bank.variants[key]],bank)
	event=_replace_content_token(event,"§WEATHER_NAME§",current_weather().name)
	if event.has("readingVariant"):event.readingVariant.previous=prior[-1].day if not prior.is_empty() else null
	var count: int=state.history.filter(func(row):return row.get("day",state.day)<state.day and row.get("type")=="focus-event" and (_object(row.get("readingVariant")).get("kind")==event.conditionKind or str(row.get("event","")).ends_with("."+event.conditionKind))).size()
	for parts in event.earlyDiaryParts.values():parts.priorCount=count
	for choice in event.choices:
		if choice.diaries.default is Dictionary and choice.diaries.default.has("$diary"):
			var parts: Dictionary=event.earlyDiaryParts[choice.diaries.default["$diary"]]
			choice.diaries.default="\n\n".join([parts.event,parts.family,parts.reflection])
	return event

func night_plan_editable() -> bool:
	return not state.ended and state.phase=="night" and _object(state.get("nightCycle")).get("day")!=state.day
func feed_plan_status(slot: String) -> Dictionary:
	var selected: bool=state.night.feedPoultry if slot=="poultry" else state.night.feedPet
	var reason: String=""
	if state.get("features",{}).get("animals",true)==false:reason="本周目动物模块已关闭。"
	elif state.animals.get(slot)==null or not animal_at_home(slot):reason="原先准备补喂的动物目前不在棚边。"
	elif not needs_animal_care(slot):reason="这只动物目前不需要补喂。"
	return {"selected":selected,"valid":reason=="","reason":reason}
func pigeon_plan_status() -> Dictionary:
	var value=state.night.get("pigeonAction","none")
	if value==null:value="none"
	if value is String and value=="none":return {"selected":false,"valid":true,"reason":""}
	var reason: String=""
	if not value is String or value not in ["send","collect","delay"]:reason="原求助或取物安排无法识别。"
	elif state.get("features",{}).get("animals",true)==false:reason="本周目动物功能已关闭。"
	elif not pigeon_action_allowed(value):reason="信鸽或放飞时机已有变化，当前不能按原安排放飞。" if value=="send" else "取物记录或约定期限已有变化，当前不能按原安排处理。"
	return {"selected":true,"valid":reason=="","reason":reason}

func record_animal_encounter(kind: String,outcome: String) -> void:
	if not state.memory.has("animalEncounters"):state.memory.animalEncounters={}
	if not state.memory.has("animalEncounterRecords"):state.memory.animalEncounterRecords={}
	state.memory.animalEncounters[kind]=true
	state.memory.animalEncounterRecords[kind]={"day":state.day,"outcome":outcome}
func expire_pigeon_pickup() -> void:
	var request=pigeon_request()
	if request==null or request.get("type")!="pigeon" or not request.get("pickup",false) or request.get("pickupDone",false) or state.day<=request.get("pickupDeadline",0):return
	request.pickup=false;request.pickupDone=true;request.pickupOutcome="expired"
	if request.get("pickupPlan")!=null:request.pickupPlan.status="expired"
	state.morningResults.append("纸条约定的留物期限已经过去。没有人在期限内取回它们，家里不再把那一份算作能够领取的接济。")
func process_animal_morning() -> void:
	for kind in ["cat","dog"]:
		if state.day>({"cat":17,"dog":31}[kind]) and not state.memory.get("animalEncounters",{}).get(kind,false):record_animal_encounter(kind,"window_passed")
	expire_pigeon_pickup()
	var bird: Dictionary=_object(state.animals.poultry)
	if state.day>=4 and bird.get("type")=="pigeon" and not bird.get("sent",false) and not state.memory.get("pigeonRouteKnown",false):
		state.memory.pigeonRouteKnown=true
		state.morningResults.append("家里终于问清托信的门路，也留下了如今草棚的位置。信鸽认得原来的巢，若那边有人接到信，可以循这处位置送来回应；今天起可在傍晚考虑放飞。这不是已经有人答应送粮。")
	var request=pigeon_request()
	if request==null or request.get("type")!="pigeon" or not request.get("sent",false) or request.get("resolved",false) or state.day<request.get("returnDay",0):return
	request.resolved=true
	if request.outcome=="no_reply":
		state.memory.pigeonRequest=request.duplicate(true)
		if is_same(state.animals.poultry,request):state.animals.poultry=null
		state.morningResults.append("到了约定等信的日子，仍没有人带来消息，信鸽也没有回到棚边。家里不知道它停在哪里，不能把未归写成已经死去；这次求助没有得到可以使用的回应。")
		state.history.append({"day":state.day,"type":"pigeon-reply","outcome":"no_reply"});return
	if request.outcome=="delivery":
		state.rice+=2
		var item: String=""
		for id in ["bandage","herbs","medkit","umbrella"]:
			if not state.tools.get(id,false):item=id;break
		if item!="":state.tools[item]=true
		else:state.rice+=1
		state.morningResults.append("清晨有人循着信中写明的位置找到棚边，连篓里的信鸽一起交还。他说钱世鑫那边凑了这份东西，往后不能保证还有。收到米粮＋2"+("、"+TOOL_NAMES[item]+"×1。" if item!="" else "；本想送来的药具家里已有，对方改留米粮＋1，不再多占一件。"))
	else:
		request.pickup=true;request.pickupDeadline=state.day+2
		state.morningResults.append("有人代送回信鸽和一张纸条：一份米和水暂存在认得的中间人那里，只留到第"+str(int(request.pickupDeadline)+1)+"日。今晚可安排罗瑾在后续白天去取；收到纸条不等于物资已经到家。")
	state.history.append({"day":state.day,"type":"pigeon-reply","outcome":request.outcome})

var missing_focus_prose: Dictionary={}
var missing_care_prose: Dictionary={}
var missing_home_prose: Dictionary={}
func household_presence_mask() -> int:
	var mask:=0
	for i in range(PEOPLE.size()):
		if present(PEOPLE[i]):mask|=1<<i
	return mask

func early_household_supported() -> bool:
	if state.day<38:return _chapter7_parent_25_early_household_supported()
	if not present("罗瑾"):return false
	for person in PEOPLE:
		if not state.people[person].away:continue
		if supported_expedition_absence(person):continue
		var record:=uncle_crisis_record()
		if person!="安仁叔叔" or record.get("status")!="pending" or not js_truthy(record.get("settled")) or not uncle_crisis_committed(record) or not record.has("pendingOrigin") or _object(record.pendingOrigin).get("receipt")!=record.get("receipt"):return false
	return true

func initialize_day_eleven_story() -> bool:
	if state.day<10 or state.ended:return true
	if state.day!=10:return false
	if state.get("storyMorningDays") is Array and state.storyMorningDays.size()==1 and typeof(state.storyMorningDays[0]) in [TYPE_INT,TYPE_FLOAT] and state.storyMorningDays[0]==11:return true
	var initial=JSON.parse_string(FileAccess.get_file_as_string("res://data/story_initial_state.json"))
	# Only the D11 initialization boundary is implemented here. Never silently apply or
	# discard later scheduled packets; those require the full later-story processor.
	for key in ["pendingMorningPackets","knowledgeFacts"]:
		if state.has(key) and (not state[key] is Array or (key=="pendingMorningPackets" and not state[key].is_empty())):return false
	if state.has("fixedNodeStates") and (not state.fixedNodeStates is Dictionary or not state.fixedNodeStates.is_empty()):
		if JSON.stringify(state.fixedNodeStates)!=JSON.stringify(initial.fixedNodeStates):return false
	if state.has("storyMorningDays"):
		if not state.storyMorningDays is Array:return false
		if state.storyMorningDays.size()==1 and typeof(state.storyMorningDays[0]) in [TYPE_INT,TYPE_FLOAT] and state.storyMorningDays[0]==11:return true
		if not state.storyMorningDays.is_empty():return false
	for key in initial:
		if key=="knowledgeFacts" and state.has(key):continue
		state[key]=initial[key].duplicate(true)
	return true


func c018_contract() -> Dictionary:
	if solitary_contract.is_empty():solitary_contract=JSON.parse_string(FileAccess.get_file_as_string("res://data/c018_contract.json"))
	return solitary_contract.contract
func protector_status(person: String) -> String:
	var p: Dictionary=_object(state.people.get(person))
	return "terminal_lost" if person not in PEOPLE.slice(1) or not p.get("alive",false) or p.get("permanentLost",false) else ("active_present" if present(person) else "active_absent")
func adult_protectors() -> Array:
	return PEOPLE.slice(1).filter(func(person):return protector_status(person)!="terminal_lost")
func acknowledge_solitary_warning() -> bool:
	if prepare_solitary_warning():return false
	var warning: Dictionary=_object(state.memory.get("solitaryHealthWarning"))
	if state.phase=="morning" and not warning.is_empty() and warning.get("ackDay")==null:warning.ackDay=state.day
	if not warning.is_empty():ensure_solitary_warning_fact(warning)
	return true
func solitary_health_night_eligible() -> bool:
	var contract:=c018_contract();var warning: Dictionary=_object(state.memory.get("solitaryHealthWarning"));var focus: Dictionary=state.focus
	var fact: Dictionary=ensure_solitary_warning_fact(warning)
	return not state.ended and present("罗瑾") and adult_protectors().is_empty() and warning.get("rule")==contract.rule and warning.get("contractRevision")==contract.revision and _whole_number(warning.get("day")) and _whole_number(warning.get("ackDay")) and warning.day<=warning.ackDay and warning.ackDay<=state.day and "player" in fact.get("knownBy",[]) and "罗瑾" in fact.get("knownBy",[]) and focus.get("day")==state.day and focus.get("settled",false)==true
func is_solitary_health_packet(packet: Variant) -> bool:
	if not packet is Dictionary:return false
	var effects=packet.get("effects");var contract:=c018_contract()
	if not effects is Array or effects.size()!=1 or not effects[0] is Dictionary:return false
	var effect: Dictionary=effects[0]
	return _object(packet.get("c018")).get("contractRevision")==contract.revision and effect.get("type")=="character_death" and effect.get("causeId")==contract.causeId and effect.get("irreversibleReviewId")==contract.reviewId
func find_solitary_health_packet() -> Variant:
	for packet in _object(state.get("nightCycle")).get("resultPackets",[]):
		if is_solitary_health_packet(packet):return packet
	return null
func queue_solitary_health_packet() -> Variant:
	var cycle: Dictionary=_object(state.get("nightCycle"));var warning: Dictionary=_object(state.memory.get("solitaryHealthWarning"));var contract:=c018_contract()
	if cycle.is_empty() or cycle.get("day")!=state.day or cycle.get("solitaryHealthEligible",false)!=true:return null
	if not cycle.has("resultPackets"):cycle.resultPackets=[]
	var existing=find_solitary_health_packet()
	if existing!=null:return existing
	if warning.get("rule")!=contract.rule or not _whole_number(warning.get("day")) or not _whole_number(warning.get("ackDay")) or not solitary_health_night_eligible():return null
	var fact:=ensure_solitary_warning_fact(warning)
	if fact.is_empty():return null
	var ids: Array=[fact.id];var id: String=cycle.id+":c018:solitary-health-failure"
	var context: Dictionary={"reviewId":contract.reviewId,"eventId":cycle.id,"choiceId":"night-plan-confirmed","safeExitId":"night-plan-survival-care","warningFacts":ids.duplicate(),"participants":["罗瑾"],"protectorCandidates":[],"contractRevision":contract.revision,"closure":contract.closure}
	var protectors: Dictionary={}
	for person in PEOPLE.slice(1):protectors[person]=protector_status(person)
	var packet: Dictionary={"id":id,"sourceEventInstanceId":cycle.id,"timing":"on_condition","subjectId":"罗瑾","effects":[{"type":"character_death","target":"罗瑾","targetCharacterId":"罗瑾","cause":contract.cause,"causeId":contract.causeId,"irreversibleReviewId":contract.reviewId,"warningFactIds":ids.duplicate(),"terminalOutcome":"luo_death_failure","requiresEmptyProtectorPool":true,"context":context}],"proseId":"c018.solitary-health-failure","revealTo":["player"],"knowledgeFactIds":ids.duplicate(),"scheduledDay":cycle.day,"condition":{"kind":"solitary_health_after_night_settlement","healthAtMost":0,"requiresEmptyProtectorPool":true},"status":"pending","c018":{"contractRevision":contract.revision,"rule":contract.rule,"warningDay":warning.day,"ackDay":warning.ackDay,"warningFactIds":ids.duplicate(),"lockedDay":cycle.day,"focusDay":state.focus.get("day"),"focusSettled":state.focus.get("settled",false)==true,"healthAtLock":state.people["罗瑾"].health,"protectorStatuses":protectors,"nightPlan":cycle.get("plan",{}).duplicate(true),"migration":false}}
	cycle.resultPackets.append(packet);return packet
func validate_solitary_health_packet(packet: Variant) -> bool:
	if not is_solitary_health_packet(packet):return false
	var cycle: Dictionary=_object(state.get("nightCycle"));var contract:=c018_contract()
	if packet.get("timing")!="on_condition" or packet.get("subjectId")!="罗瑾" or packet.get("sourceEventInstanceId")!=cycle.get("id"):return false
	if packet.get("status") not in ["pending","applied","cancelled"] or packet.get("scheduledDay")!=cycle.get("day"):return false
	var effect: Dictionary=packet.effects[0];var context: Dictionary=_object(effect.get("context"));var ids=packet.c018.get("warningFactIds")
	if effect.get("target")!="罗瑾" or effect.get("targetCharacterId")!="罗瑾" or effect.get("terminalOutcome")!="luo_death_failure" or effect.get("requiresEmptyProtectorPool")!=true or effect.get("cause")!=contract.cause:return false
	if context.get("reviewId")!=contract.reviewId or context.get("eventId")!=cycle.get("id") or context.get("choiceId")!="night-plan-confirmed" or context.get("safeExitId")!="night-plan-survival-care" or context.get("contractRevision")!=contract.revision or context.get("closure")!=contract.closure:return false
	if context.get("participants")!=["罗瑾"] or context.get("protectorCandidates")!=[]:return false
	if not ids is Array or ids.size()!=1 or not effect.get("warningFactIds") is Array or effect.warningFactIds.size()!=1 or effect.warningFactIds[0]!=ids[0] or not context.get("warningFacts") is Array or context.warningFacts.is_empty() or context.warningFacts[0]!=ids[0]:return false
	var fact: Dictionary={}
	for candidate in state.get("knowledgeFacts",[]):
		if candidate.get("id")==ids[0]:fact=candidate;break
	if fact.is_empty() or fact.get("contentId")!=contract.warningContentId or fact.get("contractRevision")!=contract.revision or "player" not in fact.get("knownBy",[]) or "罗瑾" not in fact.get("knownBy",[]) or fact.get("day",INF)>state.day+1:return false
	if packet.c018.get("rule")!=contract.rule or packet.c018.get("focusSettled")!=true or not _whole_number(packet.c018.get("warningDay")) or not _whole_number(packet.c018.get("ackDay")) or packet.c018.warningDay>packet.c018.ackDay:return false
	return true
func solitary_health_fatal_ready() -> bool:
	var cycle: Dictionary=_object(state.get("nightCycle"));var packet=find_solitary_health_packet()
	if packet==null or packet.get("status")!="pending" or cycle.get("c018SettlementStage")!="post_survival" or state.phase!="night" or cycle.get("day")!=state.day or cycle.get("status")!="settling" or state.people["罗瑾"].health>0:return false
	return validate_solitary_health_packet(packet) and solitary_health_night_eligible() and adult_protectors().is_empty()
func lock_luo_failure(cause: String,closure: String="") -> void:
	capture_r24_day_snapshot("failure")
	state.ended=true;state.endingLocked=true;state.endingType="luo_death_failure";state.memory.endingReason="luo_death_failure"
	# Current native window retains the initialized photo model unchanged; late photo work is gated.
	state.memory.failureRecord={"day":state.day,"cause":cause,"closure":closure,"photo":state.photo.duplicate(true)}
	state.phase="end";cancel_person_pending("罗瑾",cause)
func apply_solitary_health_packet(packet: Variant) -> bool:
	var cycle: Dictionary=_object(state.get("nightCycle"));var contract:=c018_contract()
	if state.get("effectLedger")==null:state.effectLedger={"appliedEffectIds":[]}
	if not state.effectLedger.has("appliedEffectIds"):state.effectLedger.appliedEffectIds=[]
	if packet!=null and (packet.get("status")=="applied" or packet.get("id") in state.effectLedger.appliedEffectIds):packet.status="applied";return false
	if packet==null or packet.get("status")!="pending":return false
	if not validate_solitary_health_packet(packet):fail_contract("C018_PACKET","C-018结果包结构不符合已接纳合同");return false
	if cycle.get("c018SettlementStage")!="post_critical":fail_contract("C018_STAGE","C-018结果包只能在当夜生存、照料、病程与危重检查完成后执行");return false
	var ready: bool=not state.ended and present("罗瑾") and adult_protectors().is_empty() and solitary_health_night_eligible() and state.people["罗瑾"].health<=0
	if not ready:
		packet.status="cancelled";packet.cancelReason="当夜全部既有结算完成后，致死条件未同时成立；不追溯重算。";packet.c018.settlementResult="survived";cycle.c018Outcome="survived";return false
	var p: Dictionary=state.people["罗瑾"];p.alive=false;p.away=false;p.health=0
	packet.status="applied";packet.appliedDay=state.day;packet.c018.settlementResult="failure";state.effectLedger.appliedEffectIds.append(packet.id);cycle.c018Outcome="failure"
	state.memory.lastDeath={"name":"罗瑾","cause":contract.cause,"causeId":contract.causeId,"day":state.day,"reviewId":contract.reviewId,"resultPacketId":packet.id,"contractRevision":contract.revision}
	if not state.history.any(func(row):return row.get("resultPacketId")==packet.id):state.history.append({"type":"person-loss","day":state.day,"name":"罗瑾","kind":"death","cause":contract.cause,"causeId":contract.causeId,"reviewId":contract.reviewId,"resultPacketId":packet.id,"contractRevision":contract.revision})
	lock_luo_failure(contract.cause,contract.closure)
	for key in ["causeId","reviewId","revision"]:state.memory.failureRecord["contractRevision" if key=="revision" else key]=contract[key]
	state.memory.failureRecord.resultPacketId=packet.id
	return true
func resolve_solitary_health_failure() -> bool:
	var packet=find_solitary_health_packet()
	return apply_solitary_health_packet(packet) if packet!=null else false


func can_work_later(person: String) -> bool:
	return understands(person) and focus_fit(person) and character_rest_reason(person)==""
func process_pre_photo_story_morning() -> bool:
	if state.day<=43:return _chapter9_parent_7_process_pre_photo_story_morning()
	if state.day<10 or state.ended or not state.people["罗瑾"].alive:return true
	if state.day>49:return false
	var initial=JSON.parse_string(FileAccess.get_file_as_string("res://data/story_initial_state.json"))
	if not state.has("fixedNodeStates"):state.fixedNodeStates={}
	for id in initial.fixedNodeStates:
		if not state.fixedNodeStates.has(id):state.fixedNodeStates[id]=initial.fixedNodeStates[id].duplicate(true)
	for key in ["pendingMorningPackets","storyMorningDays","knowledgeFacts"]:
		if not state.has(key):state[key]=[]
	var date: int=int(state.day)+1
	if state.storyMorningDays.any(func(value):return value==date):return true
	if state.pendingMorningPackets.any(func(packet):return packet.get("scheduledDay",INF)<=state.day and packet.get("status")=="pending"):return false
	if date>=22 and not state.photo.employed and not chapter_five_node_done(state.fixedNodeStates.employ) and not understands("罗瑾") and ["母亲","安仁叔叔","外祖父"].any(func(person):return understands(person)) and not js_truthy(state.memory.get("employment_offer_pending")):
		if not state.has("storySystemPackets"):state.storySystemPackets=[]
		var id: String=state.seed+":D"+str(date)+":system:employment-offer-pending"
		var found: Array=state.storySystemPackets.filter(func(packet):return packet.id==id)
		var packet: Dictionary={"id":id,"timing":"next_morning","subjectId":"family","effects":[{"type":"flag_set","flag":"employment_offer_pending","value":true}],"status":"pending"} if found.is_empty() else found[0]
		if found.is_empty():state.storySystemPackets.append(packet)
		apply_ordinary_pre_photo_packet(packet)
		state.morningResults.append("照相馆帮工的消息先由在场的大人接下；罗瑾还不能听清规矩，今天不算已经上工。")
	if date>=36 and not state.photo.deadline.announced:
		family_system_packet([{"type":"photo_progress","op":"deadline_transition","value":"announced"}],"deadline-announced")
		state.morningResults.append("照相馆传来店铺腾空的期限；到一月三十日，暗房便不能再照常使用。")
		deadline_notice_delivery()
	if relay_deadline_notice():state.morningResults.append("先前送来的店铺期限，如今也向罗瑾说明了；这条消息不涉及他私下有没有留下照片。")
	if date>=44 and not state.photo.deadline.urgent:
		family_system_packet([{"type":"photo_progress","op":"deadline_transition","value":"urgent"}],"deadline-urgent")
		state.morningResults.append("店里又催了一次清理。还要留在暗房处理的东西，不能再照先前那样等下去。")
	if date==49:family_system_packet([{ "type":"photo_progress","op":"deadline_transition","value":"final_day"}],"deadline-final")
	if date>43 and not chapter_five_node_done(state.fixedNodeStates.warning):state.fixedNodeStates.warning.status="unwarned";state.fixedNodeStates.warning.fallback="预警当日未得到合法返家转述"
	if contract_error!="":return false
	if date>state.fixedNodeStates.trial.due and not chapter_five_node_done(state.fixedNodeStates.trial):
		state.fixedNodeStates.trial.status="skipped";state.fixedNodeStates.trial.fallback="当日试印未执行，不顺延"
	for id in ["names","sources","discover","firstPrint","disclose"]:
		var node: Dictionary=state.fixedNodeStates[id]
		if date>node.due and not chapter_five_node_done(node) and not node.eligibleDays.is_empty():state.morningResults.append({"names":"前些天记下的寻人消息，仍有来处没问清。","sources":"几张纸上的听说与亲见，还需要分开放。","discover":"罗瑾惦记着店里的暗房；有机会时，还想亲自留意那里的情形。","firstPrint":"暗房里那一点空隙还没有用上；罗瑾仍在考虑自己能做到哪一步。","disclose":"罗瑾仍想找一个家人在旁的时候，把能说的部分说清。"}[id])
	process_mother_care_morning()
	process_uncle_boundary_morning()
	process_mother_crisis_morning()
	process_uncle_crisis_morning()
	process_r18_home_morning()
	state.storyMorningDays.append(state.day+1)
	return true

func make_pre_photo_plan(day: int=-1) -> Dictionary:
	if day<0:day=int(state.day)
	if day<44:return _chapter9_parent_7_make_pre_photo_plan(day)
	if day<10 or day>48:
		fail_contract("LATER_PLAN_SCOPE","当前测试支持第11至49日、无远行的日程模型。");return {}
	if not process_pre_photo_story_morning():fail_contract("STORY_MORNING_PENDING","此剧情晨间结果尚未迁移。");return {}
	var date: int=day+1;var rows: Dictionary={};var adults: Array=PEOPLE.slice(1)
	for person in PEOPLE:rows[person]=_work_row(person,"留在棚里，处理手边的家事")
	var keys=JSON.parse_string(FileAccess.get_file_as_string("res://data/late_day_keys.json"));var key: String=keys[str(date)]
	if date==13 and state.memory.get("burialAccepted",false):key="burialPrepare"
	if date==14 and state.memory.get("burialAccepted",false):key="burial"
	var primary: String="罗瑾" if key=="burial" else ("母亲" if key=="register" else ("安仁叔叔" if key=="inquiry" else ("罗瑾" if key in ["apprentice","oldphoto","materials"] and state.photo.employed else "home")))
	var balanced: bool=state.balanceVersion=="I2f"
	var yields: Dictionary={"母亲":{"rice":3 if balanced else 2},"外祖父":{"wood":5 if balanced else 3},"安仁叔叔":{"rice":3 if balanced else 2}}
	var worker: String=adults[(date-11)%3];var urgent:=false
	if balanced:
		var wood_need: bool=state.wood<=4 and can_work_later("外祖父");var food_need: bool=state.rice<=2
		var available: Array=["母亲","安仁叔叔"].filter(func(person):return can_work_later(person))
		var food_worker: String=available[date%2] if available.size()>date%2 else (available[0] if not available.is_empty() else "")
		if wood_need and (not food_need or float(state.wood)/2<=state.rice or food_worker==""):worker="外祖父";urgent=true
		elif food_need and food_worker!="":worker=food_worker;urgent=true
		if state.water<=1 and not can_work_later("罗瑾"):
			if not can_work_later(worker):
				for adult in adults:
					if can_work_later(adult):worker=adult;break
			if can_work_later(worker):urgent=true
	if date%4!=0 or urgent:
		rows[worker]=_work_row(worker,{"母亲":"到已问过的救济点排队","外祖父":"到附近收拢旧木料","安仁叔叔":"到委员会相关差事处做杂务"}[worker],{"母亲":"relief","外祖父":"wood","安仁叔叔":"committee"}[worker],true,yields[worker].duplicate(true))
		if urgent:rows[worker].reason="resource-need"
	if primary=="母亲":rows["母亲"]=_work_row("母亲","到登记处外问清手续，回程到已问过的救济处","registration",true,{"rice":3,"water":2});rows["母亲"].registrationProtocol="inquiry-I3e-4b"
	if primary=="安仁叔叔":rows["安仁叔叔"]=_work_row("安仁叔叔","办过差事以后，沿熟悉的路回来","committee",true,{"rice":2})
	if key=="burial":rows["罗瑾"]=_work_row("罗瑾","跟着已经问清的队伍做收殓帮手","burial",true,{})
	if state.photo.employed and date>=23 and date%5!=0:rows["罗瑾"]=_work_row("罗瑾","到照相馆做杂活，协助师傅","photo",true,{})
	if state.water<=2:
		var return_water: bool=balanced and not current_weather().get("severe",false) and rows["罗瑾"].type=="photo" and adults.any(func(person):return rows[person].outside and can_work_later(person))
		if not return_water:rows["罗瑾"]=_work_row("罗瑾","存水不多，今天先沿认过的近路取水","water",true,{"water":(4 if tool_available("bucket") else (3 if tool_available("canteen") else 2)) if balanced else 2})
	if key=="newyear":rows["罗瑾"]=_work_row("罗瑾","留在棚里，把新一年的日期记下")
	if date==13 and state.memory.get("burialAccepted",false):rows["罗瑾"]=_work_row("罗瑾","留在棚里，核清跟队的规矩和实际工具")
	var node_id: Variant=null
	if date==43 and (not can_work_later("安仁叔叔") or chapter_five_node_done(state.fixedNodeStates.warning)):
		state.fixedNodeStates.warning.status="unwarned";state.fixedNodeStates.warning.fallback="安仁当日不可用"
	if date>=47 and not chapter_five_node_done(state.fixedNodeStates.disclose) and not adults.any(func(person):return understands(person)):
		state.fixedNodeStates.disclose.status="no_recipient";state.fixedNodeStates.disclose.fallback="没有合法披露对象"
	var priority: Array=["ending"] if date==49 else (["disclose","discover","firstPrint","employ","names","sources"] if date>=47 else (["transfer","discover","firstPrint"] if date==45 else ["names","sources","employ","discover","trial","firstPrint","deadline"]))
	for id in priority:
		var node: Dictionary=state.fixedNodeStates[id]
		if date<node.due or chapter_five_node_done(node):continue
		var eligible: bool=understands("罗瑾")
		if id=="warning":eligible=date==43 and can_work_later("安仁叔叔")
		elif id=="trial":eligible=date==node.due and state.photo.employed and state.photo.evidence>0 and can_work_later("罗瑾")
		elif id=="ending":eligible=date==49
		elif id in ["discover","firstPrint","transfer"]:eligible=can_work_later("罗瑾") and state.photo.employed and (id=="discover" or state.photo.evidence>0)
		if eligible:node_id=id;break
	if node_id in ["discover","trial","firstPrint","transfer"]:
		rows["罗瑾"]=_work_row("罗瑾","到照相馆；今天有一件仍需亲自面对的事","photo",true,{});primary="罗瑾"
	elif node_id=="warning":primary="安仁叔叔";rows[primary]=_work_row(primary,"沿自己办差走过的路线回棚","committee",true,{"rice":2})
	elif node_id!=null:
		rows["罗瑾"]=_work_row("罗瑾","留在当下能够停留的地方，等待最后清点" if node_id=="ending" else "留在棚里，处理今天需要说清的事");primary="home"
		if node_id=="disclose":
			for person in ["母亲","安仁叔叔","外祖父"]:
				if understands(person):rows[person]=_work_row(person,"今天留在棚里，听罗瑾把话说清");break
	for person in PEOPLE:
		var p: Dictionary=state.people[person];var row: Dictionary=rows[person]
		if not p.alive or p.away or p.get("permanentLost",false) or p.get("detainedUntil")!=null:row.inactive=true;row.outside=false;row.base={};row.label=person_presence_label(person)
		elif row.outside and (not can_work_later(person) or (current_weather().get("severe",false) and (not tool_available("umbrella") or current_weather().id in ["blizzard","hail"]))):
			row.outside=false;row.base={};row.type="home";row.label="天气不宜赶路，今天留在棚里" if can_work_later(person) else "身体不适，今天留在棚里"
	if node_id in ["discover","trial","firstPrint","transfer","warning"] and not rows[primary].outside:
		state.fixedNodeStates[node_id].fallback="当日无法到达地点，不计合适日";node_id=null
	if date==45 and not chapter_five_node_done(state.fixedNodeStates.transfer) and node_id!="transfer":
		state.fixedNodeStates.transfer.status="skipped";state.fixedNodeStates.transfer.fallback="当日无法合法转移，不带照片；后续转移机会由照片专项另行绑定"
	var search: Dictionary=_object(_object(state.expedition.get("active")).get("search"))
	if search.get("day")==day and search.get("status")=="planned":
		if node_id!=null:fail_contract("SEARCH_NODE_CONFLICT","寻找不能挤占已到期剧情节点");return {}
		if search.get("mode")=="luo":rows["罗瑾"]=_work_row("罗瑾","沿约好的路线寻找家人；今天不做普通差事","search",true,{});primary="罗瑾"
		else:rows["罗瑾"]=_work_row("罗瑾","留在棚边，把家人的衣着和约定去处说清");primary="home"
		key="expeditionSearch"
	if plan_pigeon_pickup(day,node_id,key=="expeditionSearch"):rows["罗瑾"]=_work_row("罗瑾","按核对过的纸条取物，今天不做普通差事","pigeonPickup",true,{});primary="罗瑾";key="pigeonPickup"
	if balanced and state.water<=2 and not (rows["罗瑾"].type=="water" and rows["罗瑾"].outside) and not current_weather().get("severe",false):
		for adult in adults:
			if rows[adult].outside and not rows[adult].get("inactive",false) and can_work_later(adult):
				if rows[adult].base.get("water",0)<2:rows[adult].base.water=2;rows[adult].label+="，回程沿认过的近路取少量水"
				break
	for person in PEOPLE:
		var reason:=character_rest_reason(person)
		if reason!="" and not rows[person].get("inactive",false):rows[person].outside=false;rows[person].base={};rows[person].type="home";rows[person].label=reason
	var targets: Array=PEOPLE.filter(func(person):return rows[person].outside and not rows[person].get("inactive",false))
	if PEOPLE.any(func(person):return not rows[person].outside and not rows[person].get("inactive",false)):targets.append("home")
	if primary not in targets:primary="home" if "home" in targets else (targets[0] if not targets.is_empty() else "")
	if date==49:
		for person in PEOPLE:
			if not rows[person].get("inactive",false):rows[person]=_work_row(person,"留在当下能够停留的地方，等待最后清点")
		targets=["home"];primary="home"
		if can_work_later("罗瑾") and not current_weather().get("severe",false) and state.photo.employed and js_truthy(state.photo.evidence) and state.photo.album.selected>state.photo.transferCount and state.people["罗瑾"].spirit>2:
			rows["罗瑾"]=_work_row("罗瑾","最后一次到照相馆，处理仍待带出的成片","photo",true,{});targets.push_front("罗瑾")
			if not PEOPLE.any(func(person):return person!="罗瑾" and not rows[person].get("inactive",false)):targets.erase("home")
			primary="罗瑾"
	if node_id!=null:
		var node: Dictionary=state.fixedNodeStates[node_id]
		if not node.eligibleDays.any(func(value):return value==date):node.eligibleDays.append(date)
		node.fallback=null
	if key in ["pigeonPickup","expeditionSearch"]:targets=[primary]
	var result: Dictionary={"day":day,"rows":rows,"targets":targets,"primary":primary,"nodeId":node_id,"key":key,"photoWorkRules":"I2b-5a","reason":"固定节点优先，其次工作节奏、需求及可用性"}

	apply_r18_work_plan(result)
	return result

const HOME_ADMISSION_REV="WebR4-home-admission-v1"
const NEIGHBOUR_CHAINS={"rope":{"key":"neighbourRopeR2a","prefix":"neighbour.rope.R2a.D","start":13,"lastStart":40,"gap":3},"parcel":{"key":"neighbourParcelR2b","prefix":"neighbour.parcel.R2b.D","start":25,"lastStart":38,"gap":4}}
func js_truthy(value: Variant) -> bool:
	if value==null:return false
	if value is bool:return value
	if typeof(value) in [TYPE_INT,TYPE_FLOAT]:return value!=0 and not is_nan(float(value))
	if value is String:return value!=""
	return true
func home_reception_status(focus: Dictionary) -> Dictionary:
	var rows: Dictionary=_object(_object(focus.get("plan")).get("rows"));var home: Array=[]
	for person in PEOPLE:
		var row: Dictionary=_object(rows.get(person))
		if rows.get(person) is Dictionary and present(person) and not js_truthy(row.get("outside")) and not js_truthy(row.get("inactive")):home.append(person)
	var urgent: Array=home.filter(func(person):return state.people[person].health<=3 or state.ailments.get(person,{}).values().any(func(value):return value>=3))
	var able: Array=home.filter(func(person):return can_work_later(person))
	var resting: Array=home.filter(func(person):return person not in urgent and person not in able)
	return {"revision":HOME_ADMISSION_REV,"home":home,"urgent":urgent,"able":able,"resting":resting}
func neighbour_reception_witnesses(chain: String,record: Variant) -> Array:
	if not NEIGHBOUR_CHAINS.has(chain) or not record is Dictionary or (not _whole_number(record.get("stage")) or int(record.stage) not in [1,2]) or not _whole_number(record.get("lastDay")):return []
	var id: String=NEIGHBOUR_CHAINS[chain].prefix+str(int(record.lastDay))+"."+str(int(record.stage));var chosen: Dictionary={};var returned:=false
	for row in state.history:
		if row.get("event")==id and row.get("day")==record.lastDay-1:
			if row.get("type")=="later-choice" and chosen.is_empty():chosen=row
			if row.get("type")=="later-return":returned=true
	if chosen.is_empty() or not returned:return []
	var people: Array=[];var actor=_object(chosen.get("readingVariant")).get("actor")
	if actor in PEOPLE:people.append(actor)
	for fact in state.get("knowledgeFacts",[]):
		if fact.get("id")!=id+":return-knowledge" or fact.get("day")!=record.lastDay:continue
		if fact.get("source") in PEOPLE and fact.source not in people:people.append(fact.source)
		for person in fact.get("knownBy",[]):
			if person in PEOPLE and person not in people:people.append(person)
	return PEOPLE.filter(func(person):return person in people)
func neighbour_chain_due(chain: String,record: Variant,date: int) -> Dictionary:
	var config: Dictionary=NEIGHBOUR_CHAINS[chain]
	if date<config.start or date>48 or _object(record).get("stage")==3:return {}
	if not js_truthy(record):return {"chain":chain,"fresh":true,"due":config.start,"stage":1} if date<=config.lastStart else {}
	if not record is Dictionary or (not _whole_number(record.get("stage")) or int(record.stage) not in [1,2]) or not _whole_number(record.get("lastDay")):return {}
	var due: int=int(record.lastDay)+3 if chain=="rope" else maxi(int(record.lastDay)+4,32 if record.stage==1 else 41)
	return {"chain":chain,"fresh":false,"due":due,"stage":record.stage+1} if date>=due else {}
func home_focus_protected(focus: Dictionary) -> bool:
	var plan: Dictionary=_object(focus.get("plan"));var old: Dictionary=_object(_object(focus.get("laterEvents")).get(_object(plan.get("eventIds")).get("home")))
	for key in ["nodeId","recovery","motherCare","uncleBoundary","motherCrisis","uncleCrisis"]:
		if js_truthy(old.get(key)):return true
	return old.get("conditionKind")=="recovery" or js_truthy(plan.get("recoveryOffer")) or plan.get("key") in ["expeditionSearch","pigeonPickup"]
func home_admission_no(context: Dictionary,reason: String) -> Dictionary:
	var result: Dictionary=context.duplicate(true);result.allowed=false;result.actor=null;result.reason=reason;return result
func home_neighbour_admission(focus: Dictionary,requested: String) -> Dictionary:
	var context:=home_reception_status(focus);var date: int=int(focus.day)+1
	if context.home.is_empty():return home_admission_no(context,"no-present-home")
	if not context.urgent.is_empty():return home_admission_no(context,"urgent-care")
	if context.able.is_empty():return home_admission_no(context,"no-capable-host")
	if home_focus_protected(focus):return home_admission_no(context,"protected-focus")
	if requested=="day":
		if not context.resting.is_empty():return home_admission_no(context,"no-new-meeting-during-rest")
		var actor: String=context.able[0]
		for person in context.able:
			if person!="罗瑾":actor=person;break
		var result: Dictionary=context.duplicate(true);result.allowed=true;result.actor=actor;result.reason="ordinary-existing-day-scene";return result
	var old: Dictionary=_object(_object(focus.get("laterEvents")).get(_object(focus.plan.get("eventIds")).get("home")));var candidates: Array=[]
	for chain in ["rope","parcel"]:
		if chain=="rope" and ((date==13 and js_truthy(state.memory.get("burialAccepted"))) or (date in [15,17] and old.get("chapter4Revision")=="I3e-4b")):continue
		var record=state.memory.get(NEIGHBOUR_CHAINS[chain].key);var item:=neighbour_chain_due(chain,record,date)
		if item.is_empty() or (item.fresh and not context.resting.is_empty()):continue
		var known: Array=context.able if item.fresh else neighbour_reception_witnesses(chain,record)
		var hosts: Array=context.able.filter(func(person):return person in known)
		if hosts.is_empty():continue
		var actor: String=hosts[0]
		for person in hosts:
			if person!="罗瑾":actor=person;break
		item.actor=actor;candidates.append(item)
	candidates.sort_custom(func(a,b):return int(a.fresh)<int(b.fresh) if a.fresh!=b.fresh else (a.due<b.due if a.due!=b.due else ["rope","parcel"].find(a.chain)<["rope","parcel"].find(b.chain)))
	if candidates.is_empty():return home_admission_no(context,"no-due-known-capable-host")
	var winner: Dictionary=candidates[0]
	if winner.chain!=requested:
		var denied:=home_admission_no(context,"another-existing-encounter-first");denied.winner=winner;return denied
	var result: Dictionary=context.duplicate(true);result.allowed=true;result.actor=winner.actor;result.reason="fresh-when-household-available" if winner.fresh else "due-followup-with-capable-witness";result.winner=winner;return result

const CUSTODY_NIGHT_REV="WebR8-custody-two-nights-v1"
const CUSTODY_NIGHT_KEY="neighbourCustodyNightWebR8"
func custody_night_held(record: Variant) -> bool:
	return record is Dictionary and record.get("status") in ["held","awaiting"]
func custody_night_record_valid(record: Variant) -> bool:
	if not js_truthy(record):return true
	if not record is Dictionary:return false
	if record.get("revision")!=CUSTODY_NIGHT_REV or record.get("contract")!=CUSTODY_NIGHT_KEY or record.get("owner")!="d5-bundle-searcher" or not record.get("id") is String:return false
	for key in ["visits","actions","entries","identityWitnesses"]:
		if not record.get(key) is Array:return false
	if record.visits.is_empty() or record.get("status") not in ["held","awaiting","returned_owner","delivered_agent","declined"]:return false
	if not _whole_number(record.get("acceptDay")) or record.acceptDay<11 or record.acceptDay>43:return false
	if not _whole_number(record.get("originalDueDay")) or record.originalDueDay!=record.acceptDay+2:return false
	if not _whole_number(record.get("renewals")) or int(record.renewals) not in [0,1] or not _whole_number(record.get("dueDay")) or record.dueDay!=record.originalDueDay+record.renewals:return false
	if record.get("objectId")!=record.id+":closed-bundle":return false
	for visit in record.visits:
		if not visit is Dictionary or visit.get("revision")!=CUSTODY_NIGHT_REV or not visit.get("factId") is String or not visit.get("event") is String or not visit.get("choice") is String or not _whole_number(visit.get("day")) or visit.get("actor") not in PEOPLE or not visit.get("listeners") is Array:return false
		if not visit.listeners.all(func(person):return person in PEOPLE):return false
	for entry in record.entries:
		if not entry is Dictionary or not entry.get("factId") is String or not entry.get("result") is String or not _whole_number(entry.get("day")) or not _whole_number(entry.get("dueDay")) or entry.get("actor") not in PEOPLE:return false
	var action_ids: Dictionary={}
	for action in record.actions:
		if not action is Dictionary or not action.get("id") is String or not action.get("kind") is String or not _whole_number(action.get("day")) or action_ids.has(action.id):return false
		action_ids[action.id]=true
	if record.status=="declined":return record.get("holder")=="owner" and record.get("ownerReturnAuthorized") is bool and record.ownerReturnAuthorized==false and not js_truthy(record.get("authorization"))
	if not js_truthy(record.get("ownerReturnAuthorized")) or record.identityWitnesses.is_empty() or not record.identityWitnesses.all(func(person):return person in PEOPLE):return false
	if custody_night_held(record) and record.get("holder")!="household":return false
	if (record.status=="returned_owner" and record.get("holder")!="owner") or (record.status=="delivered_agent" and record.get("holder")!="designated-agent"):return false
	var authorization=record.get("authorization")
	if js_truthy(authorization):
		if not authorization is Dictionary or authorization.get("commission")!=record.id or authorization.get("agent")!=record.id+":designated-agent" or authorization.get("ownerPresent")!=true or authorization.get("scope")!="this-object-only" or not authorization.get("witnesses") is Array or authorization.witnesses.is_empty() or not authorization.witnesses.all(func(person):return person in PEOPLE):return false
	var accepts: int=record.actions.filter(func(action):return action.kind=="accept" and action.get("to")=="household").size()
	var deliveries: int=record.actions.filter(func(action):return action.kind in ["owner-return","agent-delivery"]).size()
	return accepts>0 and (record.status not in ["returned_owner","delivered_agent"] or deliveries==1)

const MESSAGE_THREAD_REV="WebR5-messages-v1"
const CUSTODY_HANDOFF_REV="WebR6-custody-sameday-v1"
const MESSAGE_WINDOWS=[null,[18,24],[18,30],[31,38],[33,42],[39,44],[43,48]]
func neighbour_knows(person: String,fact_id: String,scope: String) -> bool:
	return _object(state.memory.get("a3cT3")).get("knowledge",[]).any(func(fact):return fact.get("person")==person and fact.get("factId")==fact_id and fact.get("scope")==scope)
func neighbour_visit_done(visit: Variant,strict_returned:=false) -> bool:
	if not visit is Dictionary or not _whole_number(visit.get("day")):return false
	if strict_returned:
		if not visit.get("returned") is bool or visit.returned!=true:return false
	elif not js_truthy(visit.get("returned")):return false
	return state.history.any(func(row):return row.get("type")=="later-choice" and row.get("event")==visit.get("event") and row.get("choice")==visit.get("choice") and row.get("day")==visit.day-1) and state.history.any(func(row):return row.get("type")=="later-return" and row.get("event")==visit.get("event") and row.get("day")==visit.day-1)
func d5_bundle_evidence() -> Variant:
	var id: String="evt.d05.home.entrusted_bundle.v1";var chosen: Dictionary={}
	for row in state.history:
		if row.get("type")=="focus-event" and row.get("event")==id and row.get("focus")=="home" and row.get("choice") in ["keep_sealed","rest_with_bundle","record_return_place"]:chosen=row;break
	if chosen.is_empty() or not state.history.any(func(row):return row.get("type")=="focus-return" and row.get("event")==id and row.get("day")==chosen.day):return null
	return {"day":chosen.day+1,"choice":chosen.choice,"returned":chosen.choice=="keep_sealed","witnesses":["罗瑾","外祖父","安仁叔叔"]}
func custody_handoff_record_valid(record: Variant) -> bool:
	if not js_truthy(record):return true
	return record is Dictionary and record.get("revision")==CUSTODY_HANDOFF_REV and record.get("visits") is Array and not record.visits.is_empty() and record.visits.all(func(visit):return visit is Dictionary and visit.get("revision")==CUSTODY_HANDOFF_REV and visit.get("kind") in ["intake","handoff"])
func custody_acquaintance(person: String) -> Dictionary:
	var record=state.memory.get("neighbourCustodyWebR6");var seen: Array=[]
	if custody_handoff_record_valid(record) and record is Dictionary:
		seen=record.visits.filter(func(visit):return neighbour_visit_done(visit) and neighbour_knows(person,visit.get("factId",""),"custody-public"))
	if not seen.is_empty():return {"kind":"met" if seen.any(func(visit):return person in visit.get("listeners",[])) else "told","source":"WebR6","last":seen[-1].duplicate(true)}
	var prior=d5_bundle_evidence()
	if prior!=null and person in prior.witnesses:return {"kind":"met","source":"D5","d5":prior.duplicate(true)}
	var message: Dictionary=_object(state.memory.get("neighbourMessagesWebR5"))
	if message.get("revision")==MESSAGE_THREAD_REV:
		seen=message.get("visits",[]).filter(func(visit):return neighbour_visit_done(visit) and neighbour_knows(person,visit.get("factId",""),"public-summary"))
		if not seen.is_empty():return {"kind":"met" if seen.any(func(visit):return person in visit.get("recipients",[])) else "told","source":"WebR5"}
	return {"kind":"new","source":null}
func admission_denied(context: Dictionary,reason: String,revision: String="") -> Dictionary:
	var result: Dictionary=context.duplicate(true);result.allowed=false;result.reason=reason
	if revision!="":result.revision=revision
	return result
func neighbour_existing_scene_protected(focus: Dictionary,event: Dictionary,include_custody:=false,include_message:=true) -> bool:
	var plan: Dictionary=_object(focus.get("plan"))
	if js_truthy(plan.get("nodeId")) or js_truthy(plan.get("recoveryOffer")) or plan.get("key") in ["expeditionSearch","pigeonPickup"]:return true
	var flags: Array=["nodeId","recovery","motherCare","motherCrisis","uncleBoundary","uncleCrisis","neighbourhood","neighbourParcel","maintenance"]
	if include_message:flags.append("messageThread")
	if include_custody:flags.append("custodyHandoff")
	if flags.any(func(key):return js_truthy(event.get(key))):return true
	return js_truthy(event.get("conditionKind")) and event.get("conditionKind")!="home"
func message_thread_admission(focus: Dictionary) -> Dictionary:
	var date: int=int(focus.day)+1;var record=state.memory.get("neighbourMessagesWebR5");var context:=home_reception_status(focus);var plan: Dictionary=_object(focus.get("plan"));var event: Dictionary=_object(_object(focus.get("laterEvents")).get(_object(plan.get("eventIds")).get("home")))
	# Source deny spread places the reception revision last; preserve that observable contract.
	if "home" not in plan.get("targets",[]) or event.is_empty():return admission_denied(context,"no-home")
	if date<18 or date>48 or state.ended or not state.people["罗瑾"].alive or _object(record).get("stage")==6:return admission_denied(context,"outside-thread")
	if js_truthy(record) and (not record is Dictionary or record.get("revision")!=MESSAGE_THREAD_REV or not record.get("visits") is Array):return admission_denied(context,"unknown-contract-preserved")
	if not context.urgent.is_empty():return admission_denied(context,"urgent-care")
	if context.able.is_empty():return admission_denied(context,"no-capable-host")
	if neighbour_existing_scene_protected(focus,event,false,false):return admission_denied(context,"protected-existing-focus")
	if record is Dictionary and record.get("lastDay",-1)>=date:return admission_denied(context,"already-visited-today")
	var last: Dictionary={}
	if record is Dictionary:
		if not record.visits.is_empty():last=_object(record.visits[-1])
		if not neighbour_visit_done(last,true) or last.get("day")!=record.get("lastDay") or last.get("stage")!=record.get("stage"):return admission_denied(context,"prior-visit-not-returned")
	var hosts: Array=context.able.filter(func(person):return not js_truthy(record) or neighbour_knows(person,last.get("factId",""),"public-summary"))
	if not js_truthy(record) and not context.resting.is_empty():return admission_denied(context,"no-new-meeting-during-rest")
	if hosts.is_empty():return admission_denied(context,"no-known-capable-host")
	var previous=_object(record).get("stage",0)
	if not _whole_number(previous) or previous<0 or previous>6:return admission_denied(context,"unknown-contract-preserved")
	var stage:=0
	for index in range(int(previous)+1,7):
		if date>=MESSAGE_WINDOWS[index][0] and date<=MESSAGE_WINDOWS[index][1]:stage=index;break
	if stage==0:return admission_denied(context,"no-current-window")
	var actor: String=hosts[0]
	for person in hosts:
		if person!="罗瑾":actor=person;break
	var result: Dictionary=context.duplicate(true);result.allowed=true;result.reason="current-followup" if js_truthy(record) else "current-self-contained-entry";result.actor=actor;result.stage=stage;result.prior=d5_bundle_evidence();result.late=not js_truthy(record) and stage>1;result.revision=MESSAGE_THREAD_REV;return result
func custody_handoff_admission(focus: Dictionary) -> Dictionary:
	var context:=home_reception_status(focus);var night_record=state.memory.get(CUSTODY_NIGHT_KEY)
	if js_truthy(night_record) and (not custody_night_record_valid(night_record) or custody_night_held(night_record)):return admission_denied(context,"active-new-custody-no-object-clone")
	var date: int=int(focus.day)+1;var record=state.memory.get("neighbourCustodyWebR6");var plan: Dictionary=_object(focus.get("plan"));var event: Dictionary=_object(_object(focus.get("laterEvents")).get(_object(plan.get("eventIds")).get("home")))
	if date<11 or date>48 or state.ended or not state.people["罗瑾"].alive or event.is_empty() or "home" not in plan.get("targets",[]):return admission_denied(context,"no-later-home-slot",CUSTODY_HANDOFF_REV)
	if not custody_handoff_record_valid(record):return admission_denied(context,"unknown-or-invalid-record",CUSTODY_HANDOFF_REV)
	var visits: Array=record.visits if record is Dictionary else []
	if visits.any(func(visit):return visit.kind=="handoff"):return admission_denied(context,"handoff-already-chosen",CUSTODY_HANDOFF_REV)
	if visits.any(func(visit):return not neighbour_visit_done(visit)):return admission_denied(context,"prior-choice-not-returned",CUSTODY_HANDOFF_REV)
	if visits.any(func(visit):return visit.day>=date):return admission_denied(context,"one-visit-per-day",CUSTODY_HANDOFF_REV)
	if not context.urgent.is_empty():return admission_denied(context,"urgent-care",CUSTODY_HANDOFF_REV)
	if context.able.is_empty():return admission_denied(context,"no-able-host",CUSTODY_HANDOFF_REV)
	if neighbour_existing_scene_protected(focus,event):return admission_denied(context,"protected-existing-focus",CUSTODY_HANDOFF_REV)
	if (date in [15,17] and event.get("chapter4Revision")=="I3e-4b") or (date==13 and js_truthy(state.memory.get("burialAccepted"))):return admission_denied(context,"protected-earlier-commitment",CUSTODY_HANDOFF_REV)
	var kind: String="intake" if date<=17 else "handoff";var prior=d5_bundle_evidence()
	if kind=="intake" and (visits.any(func(visit):return visit.kind=="intake") or (prior!=null and prior.returned)):return admission_denied(context,"same-day-intake-already-told",CUSTODY_HANDOFF_REV)
	var hosts: Array=context.able.filter(func(person):return context.resting.is_empty() or visits.any(func(visit):return neighbour_visit_done(visit) and neighbour_knows(person,visit.get("factId",""),"custody-public")))
	if hosts.is_empty():return admission_denied(context,"no-new-meeting-during-rest",CUSTODY_HANDOFF_REV)
	var actor: String=hosts[0]
	for person in hosts:
		if person!="罗瑾":actor=person;break
	var result: Dictionary=context.duplicate(true);result.allowed=true;result.reason="actual-contact-followup" if js_truthy(record) else "self-contained-owner-present";result.revision=CUSTODY_HANDOFF_REV;result.kind=kind;result.actor=actor;result.acquaintance=custody_acquaintance(actor);return result
func custody_recognizes_owner(person: String,record: Dictionary) -> bool:
	return neighbour_knows(person,record.id,"custody-summary") and (neighbour_knows(person,record.id,"owner-recognized") or custody_acquaintance(person).kind=="met")
func custody_recognizes_agent(person: String,record: Dictionary) -> bool:
	return person in _object(record.get("authorization")).get("witnesses",[]) and neighbour_knows(person,record.id,"agent-authorized-face") and neighbour_knows(person,record.id,"custody-summary")
func custody_night_admission(focus: Dictionary) -> Dictionary:
	var context:=home_reception_status(focus);var date: int=int(focus.day)+1;var record=state.memory.get(CUSTODY_NIGHT_KEY);var plan: Dictionary=_object(focus.get("plan"));var event: Dictionary=_object(_object(focus.get("laterEvents")).get(_object(plan.get("eventIds")).get("home")))
	if date<11 or date>48 or state.ended or not state.people["罗瑾"].alive or event.is_empty() or "home" not in plan.get("targets",[]):return admission_denied(context,"no-home-window",CUSTODY_NIGHT_REV)
	if not custody_night_record_valid(record):return admission_denied(context,"invalid-record-quarantined",CUSTODY_NIGHT_REV)
	if js_truthy(record) and not custody_night_held(record):return admission_denied(context,"commission-ended",CUSTODY_NIGHT_REV)
	if not context.urgent.is_empty():return admission_denied(context,"urgent-care",CUSTODY_NIGHT_REV)
	if context.able.is_empty():return admission_denied(context,"no-capable-host",CUSTODY_NIGHT_REV)
	if neighbour_existing_scene_protected(focus,event,true) or (date in [15,17] and event.get("chapter4Revision")=="I3e-4b") or (date==13 and js_truthy(state.memory.get("burialAccepted"))):return admission_denied(context,"protected-existing-scene",CUSTODY_NIGHT_REV)
	if not js_truthy(record):
		if _object(state.get("features")).get("custodyNight")==false:return admission_denied(context,"new-custody-disabled",CUSTODY_NIGHT_REV)
		if date>43:return admission_denied(context,"new-intake-window-closed",CUSTODY_NIGHT_REV)
		if not context.resting.is_empty():return admission_denied(context,"no-new-request-during-rest",CUSTODY_NIGHT_REV)
		var actor: String=context.able[0]
		for person in context.able:
			if person!="罗瑾":actor=person;break
		var result: Dictionary=context.duplicate(true);result.allowed=true;result.reason="new-explicit-commission";result.revision=CUSTODY_NIGHT_REV;result.kind="intake";result.actor=actor;result.agentPresent=true;return result
	if record.visits.any(func(visit):return not neighbour_visit_done(visit)) or record.get("lastVisitDay",-1)>=date:return admission_denied(context,"previous-visit-unsettled-or-same-day",CUSTODY_NIGHT_REV)
	var hosts: Array=context.able.filter(func(person):return neighbour_knows(person,record.id,"custody-summary"))
	if hosts.is_empty():return admission_denied(context,"no-informed-capable-host",CUSTODY_NIGHT_REV)
	var kind: String=""
	if date<=record.dueDay and record.renewals==0 and not js_truthy(record.get("renewalAsked")):kind="renewal"
	elif date>=record.dueDay and not js_truthy(record.get("agentAsked")):kind="agent"
	else:return admission_denied(context,"no-new-negotiation-needed",CUSTODY_NIGHT_REV)
	var ready: Array=hosts.filter(func(person):return custody_recognizes_owner(person,record)) if kind=="renewal" else hosts
	if ready.is_empty():return admission_denied(context,"no-recognized-owner-for-renewal",CUSTODY_NIGHT_REV)
	var actor: String=ready[0];var matched:=false
	if kind=="agent":
		for person in ready:
			if custody_recognizes_agent(person,record):actor=person;matched=true;break
	if not matched:
		for person in ready:
			if person!="罗瑾":actor=person;break
	var result: Dictionary=context.duplicate(true);result.allowed=true;result.reason="informed-followup";result.revision=CUSTODY_NIGHT_REV;result.kind=kind;result.actor=actor;result.agentPresent=kind=="agent";result.authorized=custody_recognizes_agent(actor,record);return result

var custody_prose_bank: Dictionary={}
func custody_content_masks(admission: Dictionary) -> Dictionary:
	if not admission.get("home") is Array or not admission.get("resting") is Array or admission.get("actor") not in PEOPLE:return {}
	var home:=0;var resting:=0
	for person in admission.home:
		if person not in PEOPLE or not understands(person):return {}
		home|=1<<PEOPLE.find(person)
	for person in admission.resting:
		if person not in admission.home or person==admission.actor:return {}
		resting|=1<<PEOPLE.find(person)
	if admission.actor not in admission.home:return {}
	return {"home":home,"resting":resting}
func custody_prose_template(group: String,key: String) -> Dictionary:
	if custody_prose_bank.is_empty():custody_prose_bank=JSON.parse_string(FileAccess.get_file_as_string("res://data/custody_prose.json"))
	if not custody_prose_bank[group].has(key):fail_contract("CUSTODY_PROSE_PENDING","这一组托存正文条件尚未编译，保留原状态。");return {}
	return decode_home_content(custody_prose_bank.events[custody_prose_bank[group][key]],custody_prose_bank)
func make_custody_handoff_event(focus: Dictionary,admission: Dictionary) -> Dictionary:
	var masks:=custody_content_masks(admission);var date: int=int(focus.day)+1
	if masks.is_empty() or date<11 or date>48 or admission.get("kind") not in ["intake","handoff"] or not admission.get("acquaintance") is Dictionary:return {}
	var acquaintance: Dictionary=admission.acquaintance;var variant: String="new"
	if acquaintance.get("source")=="D5":variant="d5_returned" if _object(acquaintance.get("d5")).get("returned",false) else "d5_not_returned"
	elif acquaintance.get("kind")=="met":variant="r6_returned" if acquaintance.get("source")=="WebR6" and _object(acquaintance.get("last")).get("kind")=="intake" and acquaintance.last.get("result")=="returned_owner" else "met"
	elif acquaintance.get("kind")=="told":variant="told"
	var key:=JSON.stringify([admission.actor,admission.kind,masks.home,masks.resting,variant]);var event:=custody_prose_template("handoff",key)
	if event.is_empty():return {}
	var here: bool="罗瑾" in admission.home and understands("罗瑾")
	event.id="neighbour.custody.WebR6.D"+str(date)+"."+admission.kind
	event.custodyHandoff={"revision":CUSTODY_HANDOFF_REV,"kind":admission.kind,"day":date,"actor":admission.actor,"here":here,"acquaintance":acquaintance.duplicate(true),"resting":admission.resting.duplicate()}
	event.readingVariant.narratorHere=here
	return event
func make_custody_night_event(focus: Dictionary,admission: Dictionary) -> Dictionary:
	var masks:=custody_content_masks(admission);var date: int=int(focus.day)+1
	if masks.is_empty() or date<11 or date>48 or admission.get("kind") not in ["intake","renewal","agent"]:return {}
	var kind: String=admission.kind;var acquaintance: String=custody_acquaintance(admission.actor).kind if kind=="intake" else "new"
	var agent_present: bool=js_truthy(admission.get("agentPresent"));var authorized: bool=js_truthy(admission.get("authorized"));var band: int=0 if date<=14 else (1 if date<=17 else 2)
	var key:=JSON.stringify([admission.actor,kind,masks.home,masks.resting,acquaintance,agent_present if kind=="intake" else kind=="agent",authorized if kind=="agent" else false,band])
	var event:=custody_prose_template("night",key)
	if event.is_empty():return {}
	var record: Dictionary=_object(state.memory.get(CUSTODY_NIGHT_KEY));var due: int=int(record.dueDay) if js_truthy(record.get("dueDay")) else date+2
	event=_replace_content_token(event,"§DUE_DAY§",str(due))
	event=_replace_content_token(event,"§DUE_NEXT_DAY§",str(due+1))
	event.id="neighbour.custodyNight.WebR8.D"+str(date)+"."+kind
	var home: Array=admission.home.filter(func(person):return understands(person));var here: bool="罗瑾" in home
	event.custodyNight={"revision":CUSTODY_NIGHT_REV,"kind":kind,"day":date,"actor":admission.actor,"witnesses":home,"here":here,"commission":record.id if js_truthy(record.get("id")) else state.seed+"|custody-night|D"+str(date),"dueDay":due,"agentPresent":agent_present,"authorized":authorized}
	event.readingVariant.narratorHere=here
	return event

func current_later_focus_event() -> Dictionary:
	return _object(_object(state.focus.get("laterEvents")).get(state.focus.get("eventId")))
func later_event_eligible(event: Dictionary,plan: Dictionary) -> bool:
	return _chapter9_parent_2_later_event_eligible(event,plan) and disclosure_availability(event,plan).ok

func custody_night_choice_requirement(choice: Dictionary,event: Dictionary) -> Dictionary:
	var meta: Dictionary=_object(event.get("custodyNight"));var record=state.memory.get(CUSTODY_NIGHT_KEY);var context:=home_reception_status(state.focus)
	if meta.is_empty() or not choice.has("custodyNightResult"):return {"met":false,"reason":"不是这一笔托存的选择。"}
	if meta.get("revision")!=CUSTODY_NIGHT_REV or not custody_night_record_valid(record) or not meta.get("witnesses") is Array or meta.witnesses.is_empty() or event.actor not in meta.witnesses:return {"met":false,"reason":"托存记录不完整，暂停这笔交接，不猜测原物去向。"}
	var allowed: Dictionary={"intake":{"accept_owner":"accepted_owner","accept_agent":"accepted_agent","decline":"declined"},"renewal":{"extend_once":"extended","return_now":"returned_owner"},"agent":{"hand_agent":"delivered_agent","wait_owner":"agent_deferred","return_with_owner":"agent_deferred"}}
	if _object(allowed.get(meta.kind)).get(choice.id)!=choice.custodyNightResult.get("result") or not choice.get("immediateEffects") is Array or not choice.immediateEffects.is_empty() or not choice.get("returnEffects") is Array or not choice.returnEffects.is_empty():return {"met":false,"reason":"这项交接的选择与原合同不一致，不能改变物权或家用。"}
	if choice.id=="accept_agent" and not meta.agentPresent:return {"met":false,"reason":"没有当面引见，不授予代领许可。"}
	if not context.urgent.is_empty() or event.actor not in context.able or meta.day!=state.day+1 or state.ended:return {"met":false,"reason":"照料、日期或实际接待条件已改变。"}
	if not meta.witnesses.all(func(person):return person in context.home and understands(person)):return {"met":false,"reason":"当面见证者已经不在或不能接话，请保留原记录。"}
	if meta.kind=="intake":return {"met":false,"reason":"这一轮托问已经处理，不能再接一件。"} if js_truthy(record) else {"met":true,"reason":""}
	if not record is Dictionary or record.id!=meta.commission or not custody_night_held(record) or record.get("lastVisitDay",-1)>=meta.day or record.visits.any(func(visit):return not neighbour_visit_done(visit)) or not neighbour_knows(event.actor,record.id,"custody-summary"):return {"met":false,"reason":"没有对应的待交物或实际知情前情。"}
	if meta.kind=="renewal" and (js_truthy(record.renewals) or js_truthy(record.get("renewalAsked")) or meta.day>record.dueDay or not custody_recognizes_owner(event.actor,record)):return {"met":false,"reason":"已经续过、到期待交或本次请求已经答过。"}
	if meta.kind=="agent" and js_truthy(record.get("agentAsked")):return {"met":false,"reason":"这次代理领取已经问过了。"}
	if choice.id=="hand_agent" and not custody_recognizes_agent(event.actor,record):return {"met":false,"reason":"没有亲眼见过这次引见，不能凭摘要认人。"}
	return {"met":true,"reason":""}
func custody_base_choice(index: int,event: Dictionary,choice: Dictionary) -> bool:
	# Custody is deliberately inventory-neutral. Other later effects use a separate port.
	if not choice.get("immediateEffects") is Array or not choice.immediateEffects.is_empty() or not choice.get("returnEffects") is Array or not choice.returnEffects.is_empty():return false
	var focus: Dictionary=state.focus;var before:=focus_snapshot()
	apply_focus_effects([],event.id+":"+choice.id+":immediate","immediate",event.actor)
	queue_focus_packet([],event.id+":"+choice.id+":return","on_return",event.actor)
	focus.carriedAssets=[];focus.cancelWork=null;focus.partialWork=null;focus.choiceIndex=index;focus.outcomeKey="default";focus.immediateText=choice.closures.default;focus.immediateChange=describe_focus_change(before)
	focus.knowledge.player=[focus.immediateText];focus.knowledge.luo=[focus.immediateText] if focus.selected=="罗瑾" or (focus.selected=="home" and not focus.plan.rows["罗瑾"].outside) else []
	state.phase="focusResult";state.error=null;state.history.append({"day":state.day,"type":"later-choice","event":event.id,"choice":choice.id,"readingVariant":event.get("readingVariant") if event.get("conditionKind")==_object(event.get("readingVariant")).get("kind") else null})
	return true
func add_custody_action(record: Dictionary,kind: String,source: String,from: String,to: String,data: Dictionary={}) -> bool:
	var id: String=record.id+":"+kind
	if record.actions.any(func(action):return action.id==id):return false
	var action: Dictionary={"id":id,"kind":kind,"source":source,"day":state.day+1,"phase":state.phase,"from":from,"to":to}
	for key in data:action[key]=data[key].duplicate(true) if data[key] is Dictionary or data[key] is Array else data[key]
	record.actions.append(action);return true
func resolve_custody_choice(index: int) -> bool:
	if state.ended or state.day<10 or state.day>47 or state.phase!="focusEvent" or state.focus.get("choiceIndex")!=null:return false
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if event.is_empty() or index<0 or index>=event.get("choices",[]).size():return false
	var choice: Dictionary=event.choices[index];var context:=home_reception_status(focus);var backup:=state.duplicate(true)
	if event.has("custodyHandoff"):
		var meta: Dictionary=event.custodyHandoff;var prior=state.memory.get("neighbourCustodyWebR6");var reason: String=""
		if meta.get("revision")!=CUSTODY_HANDOFF_REV or not custody_handoff_record_valid(prior):reason="原合同或记录不匹配。"
		elif prior is Dictionary and prior.visits.any(func(visit):return visit.kind==meta.kind or not neighbour_visit_done(visit)):reason="已处理过这一段，或上一段尚未完成。"
		elif meta.day!=state.day+1 or not context.urgent.is_empty() or event.actor not in context.able or not later_event_eligible(event,focus.plan):reason="日期、照料或实际接待条件已改变。"
		var branches: Dictionary={"intake":{"accept_today":"returned_owner","decline_custody":"not_accepted"},"handoff":{"verify_owner":"delivered_authorized","owner_handles":"owner_retained"}}
		if reason=="" and _object(branches.get(meta.kind)).get(choice.id)!=_object(choice.get("custodyResult")).get("result"):reason="本次交接结果无法识别。"
		if reason!="":state.error="这次当面交接尚未提交："+reason;return false
		if not custody_base_choice(index,event,choice):state=backup;return false
		var fact_id: String=state.seed+"|"+event.id;var result: Dictionary=choice.custodyResult;var now: Dictionary=prior.duplicate(true) if prior is Dictionary else {"revision":CUSTODY_HANDOFF_REV,"contactId":"d5-bundle-searcher","visits":[]}
		var recipients: Array=[event.actor]
		if meta.here and understands("罗瑾"):recipients.append("罗瑾")
		var listeners:=deliver_fact({"factId":fact_id,"recipients":recipients,"source":event.id+":selected:"+choice.id,"scope":"custody-public","mode":"witnessed"})
		var transaction: String=fact_id+":handoff";var steps: Array=[]
		for i in range(result.trace.size()):steps.append({"id":transaction+":"+str(i),"order":i,"holder":result.trace[i]})
		var visit: Dictionary={"revision":CUSTODY_HANDOFF_REV,"day":meta.day,"event":event.id,"choice":choice.id,"kind":meta.kind,"result":result.result,"actor":event.actor,"here":meta.here,"factId":fact_id,"listeners":listeners,"returnListeners":[],"returned":false,"handoff":{"transactionId":transaction,"owner":"d5-bundle-searcher","object":"owners-closed-bundle","origin":"in-owners-hands-at-scene-start","term":"same-day-owner-return" if meta.kind=="intake" else "owner-present-same-scene","accepted":result.accepted,"authorization":result.get("authorization") if js_truthy(result.get("authorization")) else null,"steps":steps,"lastObservedHolder":result.lastHolder,"closed":true,"outstandingCustody":false},"summary":result.summary}
		now.visits.append(visit);now.lastDay=meta.day;now.closed=meta.kind=="handoff";state.memory.neighbourCustodyWebR6=now
		state.focus.custodyReceipt={"contract":"neighbourCustodyWebR6","revision":CUSTODY_HANDOFF_REV,"event":event.id,"choice":choice.id,"status":"result_locked","result":result.result,"factId":fact_id,"transactionId":transaction,"closed":true}
		return true
	if not event.has("custodyNight") or not later_event_eligible(event,focus.plan):return false
	var meta: Dictionary=event.custodyNight;var requirement:=custody_night_choice_requirement(choice,event)
	if not requirement.met:state.error=requirement.reason;return false
	if not custody_base_choice(index,event,choice):state=backup;return false
	var record: Dictionary=_object(state.memory.get(CUSTODY_NIGHT_KEY))
	if record.is_empty():record={"contract":CUSTODY_NIGHT_KEY,"revision":CUSTODY_NIGHT_REV,"id":meta.commission,"owner":"d5-bundle-searcher","objectId":meta.commission+":closed-bundle","acceptDay":meta.day,"originalDueDay":meta.day+2,"dueDay":meta.day+2,"renewals":0,"renewalAsked":false,"agentAsked":false,"ownerReturnAuthorized":false,"holder":"owner","status":"declined","identityWitnesses":[],"authorization":null,"actions":[],"visits":[],"entries":[]}
	var fact_id: String=record.id+":"+meta.kind+":"+choice.id;var source: String=event.id+":"+choice.id;var result: String=choice.custodyNightResult.result
	var listeners:=deliver_fact({"factId":fact_id,"recipients":meta.witnesses,"scope":"custody-summary","source":source,"mode":"witnessed"})
	if meta.kind=="intake":
		if choice.id!="decline":
			record.ownerReturnAuthorized=true;record.holder="household";record.location="shelter-custody-place";record.status="held";record.identityWitnesses=listeners.duplicate()
			for scope in ["custody-summary","owner-recognized"]:deliver_fact({"factId":record.id,"recipients":listeners,"scope":scope,"source":source,"mode":"witnessed"})
			if choice.id=="accept_agent":
				record.authorization={"commission":record.id,"agent":record.id+":designated-agent","ownerPresent":true,"scope":"this-object-only","witnesses":listeners.duplicate()}
				deliver_fact({"factId":record.id,"recipients":listeners,"scope":"agent-authorized-face","source":source,"mode":"witnessed"})
			add_custody_action(record,"accept",source,"owner","household",{"actor":event.actor,"dueDay":record.dueDay})
		else:add_custody_action(record,"decline",source,"owner","owner",{"actor":event.actor})
	elif meta.kind=="renewal":
		record.renewalAsked=true
		for scope in ["custody-summary","owner-recognized"]:deliver_fact({"factId":record.id,"recipients":listeners,"scope":scope,"source":source,"mode":"witnessed"})
		if choice.id=="extend_once":record.renewals=1;record.dueDay=record.originalDueDay+1;record.status="held";add_custody_action(record,"extend",source,"household","household",{"dueDay":record.dueDay})
		else:record.holder="owner";record.location="with-owner-at-handoff";record.status="returned_owner";add_custody_action(record,"owner-return",source,"household","owner",{"actor":event.actor})
	else:
		record.agentAsked=true
		if choice.id=="hand_agent":record.holder="designated-agent";record.location="with-agent-at-handoff";record.status="delivered_agent";add_custody_action(record,"agent-delivery",source,"household","designated-agent",{"actor":event.actor,"authorization":record.authorization})
		else:add_custody_action(record,"agent-deferred",source,"household","household",{"actor":event.actor})
	var visit: Dictionary={"revision":CUSTODY_NIGHT_REV,"event":event.id,"choice":choice.id,"kind":meta.kind,"day":meta.day,"actor":event.actor,"here":meta.here,"listeners":listeners,"returnListeners":[],"returned":false,"factId":fact_id,"result":result,"dueDay":record.dueDay,"holder":record.holder}
	record.visits.append(visit);record.lastVisitDay=meta.day;record.entries.append({"factId":fact_id,"result":result,"day":meta.day,"dueDay":record.dueDay,"holder":record.holder,"actor":event.actor});state.memory[CUSTODY_NIGHT_KEY]=record
	state.focus.custodyNightReceipt={"contract":CUSTODY_NIGHT_KEY,"revision":CUSTODY_NIGHT_REV,"commission":record.id,"event":event.id,"choice":choice.id,"status":"result_locked","result":result,"factId":fact_id}
	if not custody_night_record_valid(record):state=backup;state.error="托存选择未保存，物件与知识均已回退：新交接记录未通过本次物权校验";return false
	return true

# Serialized prose snapshots are authoritative: no fallback to current replacement rules.
func public_family_text(focus: Dictionary,slot: String,text: String) -> String:
	var cache: Dictionary=_object(focus.get("r4v3PublicFamilyText"))
	if cache.get("revision")!="R4V3-B7-public-family-r2" or cache.get("day")!=focus.day+1 or not cache.get("rules") is Array:return text
	var output: String=text
	if slot=="hearing":
		var hearing: Dictionary=_object(cache.get("eveningHearing"))
		if cache.day!=12 or hearing.get("revision")!="R4V3-B16-D12-hearing-v1" or hearing.get("day")!=12 or hearing.get("slot")!="hearing.D12" or hearing.get("before")!=text or not hearing.get("after") is String:return text
		output=hearing.after
	elif slot in ["family","reflection","ending"]:
		var matches: Array=cache.rules.filter(func(row):return row is Dictionary and row.get("day")==cache.day and row.get("slot") is String and row.slot.split(".")[0]==slot and row.get("before")==text and row.get("after") is String)
		if matches.size()!=1:return text
		output=matches[0].after
	else:return text
	var unresolved:=RegEx.new();unresolved.compile("\\$\\{[^}]+\\}")
	return text if output.is_empty() or unresolved.search(output)!=null else output

var chapter4_prose: Dictionary={}
func finish_custody_chapter4_diary() -> bool:
	# Bounded composer for custody scenes, which do not carry family-followup overrides.
	var focus: Dictionary=state.focus;var date: int=int(focus.day)+1;var event:=current_later_focus_event()
	if date<11 or date>17 or event.is_empty() or not (event.has("custodyHandoff") or event.has("custodyNight")) or event.has("familyFollowup") or not js_truthy(event.get("conditionKind")):return false
	if focus.get("choiceIndex")==null or int(focus.choiceIndex)<0 or int(focus.choiceIndex)>=event.choices.size():return false
	if not focus.get("diaryAllowed",false):focus.chapterDiary=[];return true
	if chapter4_prose.is_empty():chapter4_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter4_prose.json"))
	var choice: Dictionary=event.choices[int(focus.choiceIndex)];var key:=str(date)
	var at_return: Array=PEOPLE.filter(func(person):return present(person));var others: Array=at_return.filter(func(person):return person!="罗瑾")
	var active_others: Array=others.filter(func(person):return understands(person))
	var home_text: String="我坐在家人旁边，把说话声放轻。他们还没有力气接着讲白天的事，我便先收住问题，等有人愿意开口。" if not others.is_empty() and active_others.is_empty() else chapter4_prose.family[key]["alone" if others.is_empty() else "many"]
	var needs: Array=others.filter(func(person):return state.people[person].health<=3)
	var need: String="" if needs.is_empty() else "写到一半，"+needs[0]+"挪动了一下，仍显得很吃力。我停下笔，让手边的位置空出来，没有把安静当作已经好起来。"
	var work: String="";var mother: Dictionary=_object(focus.plan.rows.get("母亲"))
	if date==16 and mother.get("outside",false) and mother.get("type")=="registration" and present("母亲") and focus.selected!="母亲":
		if mother.get("registrationProtocol")=="inquiry-I3e-4b":work="娘回来了，先说今天问到了哪些手续，还有哪些没听准。她没有带回登记证明，袋里的救济是在另一处领的。我先前只盼着多回来一样东西，听她这样分开说，才明白这两件事并不在同一个地方办，也没有一起办成。"
		elif js_truthy(state.memory.get("registered")):work="娘回来后才拿出办到的纸。她没有把它称作护身符，只让我们问到时答自己的姓名、来处。回程带回的东西是在另一处领的，登记处没有随着这张纸一同发粮。"
		else:work="娘回来了，登记的事情还没有得到完整答复。她手里没有证明，只把今天问清和没问清的分别告诉我们；这件事还得再等消息。"
	if date==14 and focus.selected!="罗瑾" and _object(focus.plan.rows.get("罗瑾")).get("type")=="burial" and present("罗瑾"):work=focus.get("backgroundDiary","")
	var ending: String="写到这里，通道上还有人在问。我将纸收近身边，想起今天能走回来的人，也想起那女人仍看着的方向。" if date==16 else chapter4_prose.endings[key]
	focus.chapterDiary=[public_family_text(focus,"family",home_text),choice.diaries.get("default",""),work,public_family_text(focus,"hearing",chapter4_prose.news[key]),need,public_family_text(focus,"ending",ending)].filter(func(text):return not text.is_empty())
	focus.chapterDiaryContext={"day":date,"knownBy":"罗瑾","hearing":"傍晚棚口直接听到的情境演绎","present":at_return,"notSystemEffects":true}
	if event.has("custodyHandoff") and not focus.chapterDiary.is_empty():focus.custodyGenericReflection=focus.chapterDiary.back()
	return true

func pre_photo_packet_supported(packet: Dictionary) -> bool:
	if not packet.get("effects") is Array:return false
	for effect in packet.effects:
		if not effect is Dictionary:return false
		if effect.get("type")=="resource_delta":
			if effect.get("resource") not in ["rice","wood","water"] or typeof(effect.get("amount")) not in [TYPE_INT,TYPE_FLOAT]:return false
		elif effect.get("type")=="flag_set":
			if effect.get("flag") not in ["burialExperienced","registrationInquiry","registered"] or not effect.has("value"):return false
		else:return false
	return true
func apply_pre_photo_packet(packet: Dictionary) -> bool:
	if state.ended or not pre_photo_packet_supported(packet):return false
	if not state.has("effectLedger"):state.effectLedger={"appliedEffectIds":[]}
	if packet.status!="pending" or packet.id in state.effectLedger.appliedEffectIds:return false
	if packet.subjectId in PEOPLE and not present(packet.subjectId):packet.status="cancelled";packet.cancelReason="当事人未返家或已死亡";return false
	for effect in packet.effects:
		if effect.type=="resource_delta":
			state[effect.resource]=maxf(0,minf(state.waterCap if effect.resource=="water" else INF,state[effect.resource]+effect.amount))
			if effect.resource=="water" and state.water==0:state.memory.erase("waterExposure")
		elif effect.type=="flag_set":state.memory[effect.flag]=effect.value
	packet.status="applied";state.effectLedger.appliedEffectIds.append(packet.id);return true
func later_return_line(person: String,kind: String) -> String:
	var pools: Dictionary={"complete":["回到棚边，说明这趟差事已经做完。","回来以后，才把能说清的经过告诉家里。","办完原定的差事回到了棚边。"],"partial":["回来时说明差事只做完一部分，没有把原先打算带的也算进去。","带回的比原先预备的少，耽搁的部分也照实说了。","先将这一趟实际所得放下，没有拿没完成的差事充数。"]}
	return person+pools[kind][RNG.hash_seed(state.seed+":return:"+str(int(state.day))+":"+person+":"+kind)%3]
func custody_after_context(focus: Dictionary) -> Dictionary:
	var home: Array=PEOPLE.filter(func(person):return present(person) and focus.plan.rows.has(person) and not focus.plan.rows[person].get("inactive",false))
	return {"home":home,"urgent":home.filter(func(person):return state.people[person].health<=3 or _object(state.ailments.get(person)).values().any(func(value):return value>=3)),"able":home.filter(func(person):return can_work_later(person))}
func settle_custody_return() -> bool:
	# D11-D17 selected custody only. Later photos, crises, excursions and owner arrivals
	# on unrelated scenes remain gated until their complete contracts are implemented.
	if state.ended or state.day<10 or state.day>16:return false
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if event.is_empty() or not (event.has("custodyHandoff") or event.has("custodyNight")):return false
	if focus.get("settled",false):state.phase="focusReturn";return true
	if state.phase!="focusResult" or focus.get("choiceIndex")==null or int(focus.choiceIndex)<0 or int(focus.choiceIndex)>=event.choices.size():return false
	if js_truthy(focus.plan.get("nodeId")) or event.has("familyFollowup") or focus.plan.get("key") in ["expeditionSearch","pigeonPickup"]:return false
	if focus.plan.rows.values().any(func(row):return row.get("type") not in ["home","relief","wood","water","burial","registration","rest","committee"]):return false
	for key in ["motherCareReturned","uncleBoundaryReturned","motherCrisisR4a","uncleCrisisR4b","grandfatherHomeR18"]:
		if state.memory.get(key)!=null:return false
	if focus.resultPackets.any(func(packet):return not pre_photo_packet_supported(packet)):return false
	var night: bool=event.has("custodyNight");var record: Dictionary=_object(state.memory.get(CUSTODY_NIGHT_KEY if night else "neighbourCustodyWebR6"))
	if not (custody_night_record_valid(record) if night else custody_handoff_record_valid(record)):return false
	if night and focus.get("custodyNightRevision")!=CUSTODY_NIGHT_REV:return false
	var choice: Dictionary=event.choices[int(focus.choiceIndex)];var visits: Array=record.get("visits",[]).filter(func(row):return row.get("event")==event.id and row.get("choice")==choice.id)
	if visits.size()!=1 or not focus.get("custodyNightReceipt" if night else "custodyReceipt") is Dictionary:return false
	var backup:=state.duplicate(true);var before:=focus_snapshot();var lines: Array=[]
	var meta: Dictionary=event.custodyNight if night else event.custodyHandoff
	if not meta.here and not understands(event.actor):choice.diaries.default="我回来时，今天接话的家人还不能把经过讲清。没有听见这回怎样答应、怎样交物，就不从棚边的一只包猜出事情已经做到哪里。" if night else "我回来以后，今天在棚边接话的家人还不能把事情说明。我没有因为眼前少了或多了一处空地，就猜谁来过、什么东西交给了谁。先顾现在能顾的，没听到的那一段不往日记里补。"
	for row in focus.plan.rows.values():
		var packets: Array=focus.resultPackets.filter(func(packet):return packet.id==focus.workPackets.get(row.name));var packet: Dictionary={} if packets.is_empty() else packets[0]
		if not present(row.name) or row.get("inactive",false) or focus.get("cancelWork")==row.name:
			if not packet.is_empty():packet.status="cancelled";packet.cancelReason="未能完成或当事人未返家"
			if focus.get("cancelWork")==row.name and present(row.name) and row.outside:lines.append(row.name+"回到了棚边，原定的差事没有做完。")
			continue
		if not packet.is_empty():
			if focus.get("partialWork")==row.name:
				for effect in packet.effects:
					if typeof(effect.get("amount")) in [TYPE_INT,TYPE_FLOAT]:effect.amount=maxf(1,effect.amount-1)
			apply_pre_photo_packet(packet)
		if row.outside:lines.append(later_return_line(row.name,"partial" if focus.get("partialWork")==row.name else "complete"))
		if row.type=="burial":
			apply_pre_photo_packet(queue_focus_packet([{"type":"flag_set","flag":"burialExperienced","value":true}],"work:burial:experience","on_return","罗瑾"))
			if focus.selected!="罗瑾":focus.backgroundDiary="今天我跟队回来，没有在路上独自停留。我没有亲眼看见杀戮，却面对了它留下的后果。回到棚里以后，我想先看看家人还在不在眼前，并不想把一路所见立刻从头说完。"
		if row.type=="registration":
			var inquiry: bool=row.get("registrationProtocol")=="inquiry-I3e-4b"
			apply_pre_photo_packet(queue_focus_packet([{"type":"flag_set","flag":"registrationInquiry" if inquiry else "registered","value":"mother"}],"work:registration:inquiry" if inquiry else "work:registration:paper","on_return","母亲"))
	for packet in focus.resultPackets:
		if packet.timing=="on_return" and packet.status=="pending":apply_pre_photo_packet(packet)
	var known: bool=understands("罗瑾") and later_event_eligible(event,focus.plan)
	if known:state.knowledgeFacts.append({"id":event.id+":return-knowledge","day":state.day+1,"source":event.actor,"knownBy":["罗瑾"],"scope":"选择结果的可转述部分","text":choice.diaries.default})
	focus.diaryAllowed=known;focus.knowledge.luo=[choice.diaries.default] if known else []
	if known and focus.selected!="罗瑾" and (focus.selected!="home" or focus.plan.rows["罗瑾"].outside) and not lines.any(func(line):return line.begins_with(event.actor)):lines.append(event.actor+"在家里说起今天遇到的事。")
	focus.returnText=" ".join(lines);focus.returnChange=describe_focus_change(before);focus.settled=true;focus.carriedAssets=[];state.phase="focusReturn"
	if not finish_custody_chapter4_diary():state=backup;return false
	state.history.append({"day":state.day,"type":"later-return","event":event.id,"change":focus.returnChange})
	var visit: Dictionary=visits[0];visit.returned=true
	if night:
		var context:=custody_after_context(focus);var speaker: bool=event.actor in context.home and understands(event.actor) and neighbour_knows(event.actor,visit.factId,"custody-summary")
		if "罗瑾" in context.home and understands("罗瑾") and (meta.here or speaker):
			visit.returnListeners=deliver_fact({"factId":visit.factId,"recipients":["罗瑾"],"scope":"custody-summary","source":event.id+":return:"+event.actor,"mode":"witnessed" if meta.here else "told"})
			if record.status!="declined":deliver_fact({"factId":record.id,"recipients":["罗瑾"],"scope":"custody-summary","source":event.id+":return-summary:"+event.actor,"mode":"witnessed" if meta.here else "told"})
		if focus.diaryAllowed and not focus.get("chapterDiary",[]).any(func(text):return text.contains(choice.diaries.default)):
			if not focus.get("chapterDiary") is Array:focus.chapterDiary=[]
			focus.chapterDiary.append(choice.diaries.default)
		focus.custodyNightReceipt.returned=true
	else:
		if understands("罗瑾") and (meta.here or understands(event.actor)):visit.returnListeners=deliver_fact({"factId":visit.factId,"recipients":["罗瑾"],"source":event.id+(":witness-kept" if meta.here else ":return-telling:"+event.actor),"scope":"custody-public","mode":"witnessed" if meta.here else "told"})
		focus.custodyReceipt.returned=true
		if focus.diaryAllowed and not focus.get("chapterDiary",[]).is_empty():
			var text: String=choice.diaries.default;var parts: Array=Array(text.split("\n\n"));var tail: String=parts.pop_back();var body: String="\n\n".join(parts);var hit: bool=false
			for i in range(focus.chapterDiary.size()):
				if focus.chapterDiary[i].contains(text):hit=true;focus.chapterDiary[i]=focus.chapterDiary[i].replace(text,body)
			if not hit:focus.chapterDiary.append(tail if body.is_empty() else body)
			if js_truthy(focus.get("custodyGenericReflection")):focus.chapterDiary.erase(focus.custodyGenericReflection)
			if not body.is_empty():focus.chapterDiary.append(tail)
	return true

func settle_custody_owner_arrival(event: Dictionary) -> bool:
	var focus: Dictionary=state.focus;var record: Dictionary=_object(state.memory.get(CUSTODY_NIGHT_KEY));var date: int=int(state.day)+1
	if record.is_empty() or not custody_night_record_valid(record) or not custody_night_held(record) or not record.get("ownerReturnAuthorized",false) or date<record.dueDay or date>48 or state.ended or not state.people["罗瑾"].alive or not focus.get("settled",false) or focus.get("custodyNightRevision")!=CUSTODY_NIGHT_REV or js_truthy(focus.get("custodyOwnerArrival")) or record.get("lastVisitDay")==date:return false
	var context:=custody_after_context(focus)
	var major: bool=state.memory.get("irreversibleDay")==state.day or state.memory.get("majorOutcomeDay")==date
	for key in ["motherCrisisR4a","uncleCrisisR4b"]:
		var crisis: Dictionary=_object(state.memory.get(key))
		if crisis.get("messageDay")==date or crisis.get("confirmedDay")==date:major=true
	if not context.urgent.is_empty() or context.able.is_empty() or js_truthy(focus.plan.get("nodeId")) or js_truthy(event.get("nodeId")) or js_truthy(event.get("motherCrisis")) or js_truthy(event.get("uncleCrisis")) or js_truthy(event.get("uncleBoundary")) or js_truthy(event.get("motherCare")) or major or focus.plan.get("key") in ["expeditionSearch","pigeonPickup"]:return false
	var able: Array=context.able.filter(func(person):return custody_recognizes_owner(person,record))
	if able.is_empty():return false
	var actor: String=able[0]
	var text: String="到了收拾当天家用的时候，原主才走到棚边，问这次寄放的包能否取回。"+actor+"知道这笔约定，也认得原主本人，先同他对清是这一回交下的东西，再从原处取出。男人接住包底，将原结朝自己转过去，没有请人打开。\n\n他把整包提稳后自己带走，"+actor+"看见东西确实到了他手里。这一次没有另谈续期、代领或谢礼，也没有带来失散者已经找到的消息。"
	var fact_id: String=record.id+":owner-return";var source: String="custody-owner-arrival:D"+str(date)
	if not add_custody_action(record,"owner-return",source,"household","owner",{"actor":actor,"arrival":true}):return false
	record.status="returned_owner";record.holder="owner";record.location="with-owner-at-handoff"
	var witnesses: Array=context.home.filter(func(person):return understands(person))
	for pair in [[fact_id,"custody-summary"],[record.id,"custody-summary"],[record.id,"owner-recognized"]]:deliver_fact({"factId":pair[0],"recipients":witnesses,"scope":pair[1],"source":source,"mode":"witnessed"})
	record.entries.append({"factId":fact_id,"result":"returned_owner","day":date,"dueDay":record.dueDay,"holder":record.holder,"actor":actor})
	focus.custodyOwnerArrival={"revision":CUSTODY_NIGHT_REV,"commission":record.id,"factId":fact_id,"actor":actor,"witnesses":witnesses,"text":text,"day":date}
	focus.returnText="\n\n".join([focus.get("returnText",""),text].filter(func(value):return js_truthy(value)))
	if focus.get("diaryAllowed",false) and "罗瑾" in witnesses:
		if not focus.get("chapterDiary") is Array or not focus.chapterDiary.any(func(value):return value is String and not value.strip_edges().is_empty()):
			var choices: Array=event.get("choices",[]);var selected: int=int(focus.get("choiceIndex",-1))
			focus.chapterDiary=[_object(_object(choices[selected]).get("diaries")).get("default","") if selected>=0 and selected<choices.size() else ""]
		focus.chapterDiary.append("傍晚原主真的来取，我看着那一包从保管处交到他手里，才知道这一回已经交清。不是日子过了，东西便会自己回到他身边。\n\n他说完接着走，没有说找到同来的人了。我记下这次真正见到的交接，不用包已经离开来替他的寻找补一个好结尾。")
	return true


func ordinary_pre_photo_effect_supported(effect: Dictionary) -> bool:
	if effect.get("type")=="flag_set" and effect.get("flag") in ["householdInquiryNoted","familyReturnAgreement","testimonyBoundaryRespected"]:return effect.get("value") is bool and effect.value==true
	return _chapter9_parent_17_ordinary_pre_photo_effect_supported(effect)

func ordinary_pre_photo_requirement(choice: Dictionary) -> Dictionary:
	var result:=_chapter9_parent_2_ordinary_pre_photo_requirement(choice)
	if not result.met:return result
	var focus: Dictionary=state.focus;var event: Dictionary=_object(focus.get("laterEvents",{}).get(focus.get("eventId")))
	if state.phase=="focusEvent" and event.get("nodeId")=="disclose" and event.get("choices",[]).any(func(c):return is_same(c,choice)):
		var availability:=disclosure_availability(event,focus.get("plan",{}))
		if not availability.ok:return {"met":false,"reason":availability.reason}
	return result

func apply_ordinary_pre_photo_packet(packet: Dictionary) -> bool:
	if state.ended:return false
	if not state.has("effectLedger"):state.effectLedger={"appliedEffectIds":[]}
	if packet.status!="pending" or packet.id in state.effectLedger.appliedEffectIds:return false
	if packet.effects.any(func(e):return e.type=="mother_crisis_consequence"):return apply_mother_crisis_packet(packet)
	if packet.effects.any(func(e):return e.type=="uncle_crisis_commit"):return apply_uncle_crisis_packet(packet)
	if packet.effects.any(func(effect):return not ordinary_pre_photo_effect_supported(effect)):return false
	if packet.subjectId in PEOPLE and not present(packet.subjectId):packet.status="cancelled";packet.cancelReason="当事人未返家或已死亡";return false
	if js_truthy(packet.get("motherCare")) and not mother_care_return_allowed(packet):packet.status="cancelled";packet.cancelReason="本趟基本粮未实际交回，不补扣家庭库存";return false
	if js_truthy(packet.get("uncleBoundary")) and not uncle_boundary_return_allowed(packet):packet.status="cancelled";packet.cancelReason="本趟差事未实际交回，不补算门边问话";return false
	if not complete_route_warning_return(packet):return false
	for effect in packet.effects:
		if effect.type=="knowledge_grant" and not (route_validate_fact(effect.fact) if route_marked(effect.fact) else deadline_validate_fact(effect.fact)):return false
	for i in range(packet.effects.size()):
		var effect: Dictionary=packet.effects[i]
		match effect.type:
			"resource_delta":
				state[effect.resource]=maxf(0,minf(state.waterCap if effect.resource=="water" else INF,state[effect.resource]+effect.amount))
				if effect.resource=="water" and state.water==0:state.memory.erase("waterExposure")
			"shelter_delta":state.shelter=clampf(state.shelter+effect.amount,0,50)
			"item_consume":state.tools[effect.item]=false
			"item_gain":
				if state.tools.get(effect.item,false):state["rice" if effect.item=="whistle" else "wood"]+=1
				else:state.tools[effect.item]=true
			"character_health":
				if present(effect.target):state.people[effect.target].health=clampf(state.people[effect.target].health+effect.amount,0,10)
			"character_spirit":
				if present(effect.target):apply_packet_spirit(packet,effect,i)
			"ailment_reduce":
				change_ailment(effect.target,effect.ailment,-effect.amount)
			"flag_set":state.memory[effect.flag]=effect.value
			"node_resolve":
				var node: Dictionary=state.fixedNodeStates[effect.node];node.status=effect.get("status","resolved") if js_truthy(effect.get("status")) else "resolved";node.resolvedDay=state.day+1;node.fallback=effect.get("fallback") if js_truthy(effect.get("fallback")) else null
			"photo_progress":
				if not story_photo(effect.op,effect.get("value"),effect):return false
			"knowledge_grant":
				if route_marked(effect.fact):route_apply(effect.fact)
				else:deadline_apply(effect.fact)
				if contract_error!="":return false
	packet.status="applied";state.effectLedger.appliedEffectIds.append(packet.id);return true

func resolve_ordinary_pre_photo_choice(index: int) -> bool:
	if state.ended or state.day<10 or state.day>16 or state.phase!="focusEvent" or state.focus.get("choiceIndex")!=null:return false
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if event.is_empty() or index<0 or index>=event.get("choices",[]).size():return false
	for key in ["custodyHandoff","custodyNight","messageThread","neighbourhood","neighbourParcel","motherCare","uncleBoundary","motherCrisis","uncleCrisis","r4v7P1","recovery","maintenance","nodeId"]:
		if js_truthy(event.get(key)):return false
	if focus.plan.get("key") in ["expeditionSearch","pigeonPickup"] or js_truthy(focus.plan.get("nodeId")):return false
	var choice: Dictionary=event.choices[index]
	for key in ["motherCrisis","uncleCrisis","motherCare","uncleBoundary","photoTransfer","photoBatch","nextMorningEffects"]:
		if js_truthy(choice.get(key)):return false
	var immediate: Array=choice.get("immediateEffects",[]).duplicate(true)
	if js_truthy(choice.get("flag")):immediate.append({"type":"flag_set","flag":choice.flag,"value":true})
	if immediate.any(func(effect):return not ordinary_pre_photo_effect_supported(effect)) or choice.get("returnEffects",[]).any(func(effect):return not ordinary_pre_photo_effect_supported(effect)):return false
	var requirement:=ordinary_pre_photo_requirement(choice)
	if not requirement.met:state.error=requirement.reason;return false
	if not later_event_eligible(event,focus.plan):state.error="当事人已不能参与这段现场。";return false
	var before:=focus_snapshot()
	apply_ordinary_pre_photo_packet(queue_focus_packet(immediate,event.id+":"+choice.id+":immediate","immediate",event.actor))
	var packet:=queue_focus_packet(choice.get("returnEffects",[]),event.id+":"+choice.id+":return","on_return",event.actor)
	focus.carriedAssets=[]
	for effect in packet.effects:
		if effect.type=="resource_delta" and effect.amount>0:focus.carriedAssets.append({"owner":event.actor,"resource":effect.resource,"amount":effect.amount,"resultPacketId":packet.id})
	focus.cancelWork=focus.selected if choice.get("workImpact")=="complete" else null;focus.partialWork=focus.selected if choice.get("workImpact")=="partial" else null
	focus.choiceIndex=index;focus.outcomeKey="default";focus.immediateText=choice.closures.default;focus.immediateChange=describe_focus_change(before)
	focus.knowledge.player=[focus.immediateText];focus.knowledge.luo=[focus.immediateText] if focus.selected=="罗瑾" or (focus.selected=="home" and not focus.plan.rows["罗瑾"].outside) else []
	var history: Dictionary={"day":state.day,"type":"later-choice","event":event.id,"choice":choice.id}
	if event.get("conditionKind")==_object(event.get("readingVariant")).get("kind"):
		if event.has("readingVariant"):history.readingVariant=event.readingVariant
	else:history.readingVariant=null
	state.phase="focusResult";state.error=null;state.history.append(history);return true

func finish_ordinary_chapter4_diary() -> bool:
	# Bounded composer for custody scenes, which do not carry family-followup overrides.
	var focus: Dictionary=state.focus;var date: int=int(focus.day)+1;var event:=current_later_focus_event()
	if date<11 or date>17 or event.is_empty():return false
	if focus.get("choiceIndex")==null or int(focus.choiceIndex)<0 or int(focus.choiceIndex)>=event.choices.size():return false
	if not focus.get("diaryAllowed",false):focus.chapterDiary=[];return true
	if chapter4_prose.is_empty():chapter4_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter4_prose.json"))
	var choice: Dictionary=event.choices[int(focus.choiceIndex)];var key:=str(date)
	var body: String=choice.diaries.get("default","")
	var direct: bool=focus.selected=="罗瑾" or (focus.selected=="home" and not focus.plan.rows["罗瑾"].outside)
	if not direct and not js_truthy(event.get("conditionKind")):
		var told: String=event.actor+("等我回来，才说起白天棚边的事。" if focus.selected=="home" else "回来后把能够说清的部分告诉了我。")
		if date==14 and focus.selected=="home" and choice.id=="water":body="我听家里说，那人来时先不肯碰棚口的东西。原来有的人已经回来了，手上的动作、没说完的话，却还像留在外面。家里给了水，没能替那个女人认出她找的人。我没有见到他们离开，只能将听到的留在这里。"
		if date==14 and event.get("chapter4Revision") in ["I3c-2","I3e-4b"] and focus.selected=="home" and choice.id=="space":body="我回来时，来歇脚的男人已经走了。听说他只坐了一会儿，家里没有再分水，也没逼他将话说全。我还想问有没有别的事能替他做，抬头看向棚口，才发觉眼前已经没有人等这一句。我先把听来的记下。等我回来时人已经走了，这一次我确实没能再替他做什么。"
		if date==11 and focus.selected=="home" and choice.id=="boil":body="锅已从火上挪开，我回来才知道，为这一份水，家里又用了木料。我看着单放的碗，很想将它烧过这件事当成一句肯定的答复；听完来处还没问清，又没再催着说可以放心了。"
		if not (date==16 and event.get("chapter4Revision")=="I3e-4b" and focus.selected=="母亲"):body=told+body
	if date==14 and focus.selected=="罗瑾" and choice.id=="follow":body=body.replace("回来以后，我先看家里还有谁在，才肯坐下。","")
	var at_return: Array=PEOPLE.filter(func(person):return present(person));var others: Array=at_return.filter(func(person):return person!="罗瑾")
	var active_others: Array=others.filter(func(person):return understands(person))
	var home_text: String="我坐在家人旁边，把说话声放轻。他们还没有力气接着讲白天的事，我便先收住问题，等有人愿意开口。" if not others.is_empty() and active_others.is_empty() else chapter4_prose.family[key]["alone" if others.is_empty() else "many"]
	var needs: Array=others.filter(func(person):return state.people[person].health<=3)
	var need: String="" if needs.is_empty() else "写到一半，"+needs[0]+"挪动了一下，仍显得很吃力。我停下笔，让手边的位置空出来，没有把安静当作已经好起来。"
	var work: String="";var mother: Dictionary=_object(focus.plan.rows.get("母亲"))
	if date==16 and mother.get("outside",false) and mother.get("type")=="registration" and present("母亲") and focus.selected!="母亲":
		if mother.get("registrationProtocol")=="inquiry-I3e-4b":work="娘回来了，先说今天问到了哪些手续，还有哪些没听准。她没有带回登记证明，袋里的救济是在另一处领的。我先前只盼着多回来一样东西，听她这样分开说，才明白这两件事并不在同一个地方办，也没有一起办成。"
		elif js_truthy(state.memory.get("registered")):work="娘回来后才拿出办到的纸。她没有把它称作护身符，只让我们问到时答自己的姓名、来处。回程带回的东西是在另一处领的，登记处没有随着这张纸一同发粮。"
		else:work="娘回来了，登记的事情还没有得到完整答复。她手里没有证明，只把今天问清和没问清的分别告诉我们；这件事还得再等消息。"
	if date==14 and focus.selected!="罗瑾" and _object(focus.plan.rows.get("罗瑾")).get("type")=="burial" and present("罗瑾"):work=focus.get("backgroundDiary","")
	var ending: String="写到这里，通道上还有人在问。我将纸收近身边，想起今天能走回来的人，也想起那女人仍看着的方向。" if date==16 and event.get("chapter4Revision")!="I3e-4b" else chapter4_prose.endings[key]
	var hearing: String="晚些时候，一名办过登记的男人在棚口拿出纸，请识字的人帮他认姓名。他说日本兵先前在街上拦过他，所以才急着有一样东西能够拿出来。旁边的人问，以后是不是不必再挨问，他将纸收回去，没有替日本兵答这个话。我看见的倒是，他把那张纸压平以后，仍摸了一遍自己放纸的位置。" if date==16 and event.get("chapter4Revision")=="I3e-4b" else chapter4_prose.news[key]
	focus.chapterDiary=[public_family_text(focus,"family",home_text),body,work,public_family_text(focus,"hearing",hearing),need,public_family_text(focus,"ending",ending)].filter(func(text):return not text.is_empty())
	if js_truthy(event.get("familyFollowup")) and understands("罗瑾") and (not focus.plan.rows["罗瑾"].get("outside",false) or understands(event.actor)):focus.chapterDiary[1]+="\n\n"+event.familyFollowup.diary
	if _object(event.get("readingVariant")).get("revision")=="WebR2-home-care-prose-v1" and focus.chapterDiary.find(choice.diaries.get("default",""))>0 and not focus.get("grandfatherRecoveryAdded",false) and not js_truthy(event.get("nodeId")):focus.chapterDiary[0]=""
	focus.chapterDiaryContext={"day":date,"knownBy":"罗瑾","hearing":"傍晚棚口直接听到的情境演绎","present":at_return,"notSystemEffects":true}
	if event.has("custodyHandoff") and not focus.chapterDiary.is_empty():focus.custodyGenericReflection=focus.chapterDiary.back()
	return true

func settle_ordinary_pre_photo_return() -> bool:
	if state.day<44:return _chapter9_parent_16_settle_ordinary_pre_photo_return()
	# D11-D17 selected custody only. Later photos, crises, excursions and owner arrivals
	# on unrelated scenes remain gated until their complete contracts are implemented.
	if state.ended or state.day<44 or state.day>48:return false
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if event.is_empty():return false
	if focus.get("settled",false):state.phase="focusReturn";return true
	if state.phase!="focusResult" or focus.get("choiceIndex")==null or int(focus.choiceIndex)<0 or int(focus.choiceIndex)>=event.choices.size():return false
	if focus.plan.get("key") in ["expeditionSearch","pigeonPickup"]:return false
	if focus.plan.rows.values().any(func(row):return row.get("type") not in ["home","relief","wood","water","burial","registration","rest","committee","photo","grandfatherHomeVisit"]):return false
	if focus.resultPackets.any(func(packet):return packet.effects.any(func(effect):return not ordinary_pre_photo_effect_supported(effect) and effect.get("type")!="mother_crisis_consequence")):return false
	var choice: Dictionary=event.choices[int(focus.choiceIndex)]
	var backup:=state.duplicate(true);var before:=focus_snapshot();var lines: Array=[]
	if not before_uncle_crisis_return(focus,event):state=backup;state.error="返家尚未结算完成："+contract_message;return false
	for row in focus.plan.rows.values():
		var packets: Array=focus.resultPackets.filter(func(packet):return packet.id==focus.workPackets.get(row.name));var packet: Dictionary={} if packets.is_empty() else packets[0]
		if apply_c8_special_work(focus,event,row,packet,lines):continue
		if contract_error!="":state=backup;state.error="返家尚未结算完成："+contract_message;return false
		if not present(row.name) or row.get("inactive",false) or focus.get("cancelWork")==row.name:
			if not packet.is_empty():packet.status="cancelled";packet.cancelReason="未能完成或当事人未返家"
			if focus.get("cancelWork")==row.name and present(row.name) and row.outside:lines.append(row.name+"回到了棚边，原定的差事没有做完。")
			continue
		if not packet.is_empty():
			if focus.get("partialWork")==row.name:
				for effect in packet.effects:
					if effect.get("type")=="photo_progress" and effect.get("op")=="skill_delta":effect.value/=2
					elif typeof(effect.get("amount")) in [TYPE_INT,TYPE_FLOAT]:effect.amount=maxf(1,effect.amount-1)
			apply_ordinary_pre_photo_packet(packet)
		if row.outside and row.type!="photo" and not (row.name=="罗瑾" and js_truthy(focus.get("photoTransferReceipt"))):lines.append(later_return_line(row.name,"partial" if focus.get("partialWork")==row.name else "complete"))
		if row.type=="burial":
			apply_ordinary_pre_photo_packet(queue_focus_packet([{"type":"flag_set","flag":"burialExperienced","value":true}],"work:burial:experience","on_return","罗瑾"))
			if focus.selected!="罗瑾":focus.backgroundDiary="今天我跟队回来，没有在路上独自停留。我没有亲眼看见杀戮，却面对了它留下的后果。回到棚里以后，我想先看看家人还在不在眼前，并不想把一路所见立刻从头说完。"
		if row.type=="registration":
			var inquiry: bool=row.get("registrationProtocol")=="inquiry-I3e-4b"
			apply_ordinary_pre_photo_packet(queue_focus_packet([{"type":"flag_set","flag":"registrationInquiry" if inquiry else "registered","value":"mother"}],"work:registration:inquiry" if inquiry else "work:registration:paper","on_return","母亲"))
		if row.type=="photo" and row.outside and not js_truthy(focus.get("photoTransferReceipt")):lines.append("罗瑾只做完一部分杂活便离店回到棚边；没做完的那一段不能算上。" if focus.get("partialWork")==row.name else "罗瑾做完今天分到的杂活，离店回到棚边；主要冲洗仍由蒋孝义负责。")
	for packet in focus.resultPackets:
		if packet.timing=="on_return" and packet.status=="pending":apply_ordinary_pre_photo_packet(packet)
	if contract_error!="":state=backup;state.error="返家尚未结算完成："+contract_message;return false
	if not settle_chapter_five_default_node(focus,event,lines):state=backup;return false
	if not complete_c8_return_knowledge(focus,event):state=backup;state.error="返家尚未结算完成："+contract_message;return false
	var known: bool=c8_return_knowledge_allowed(focus,event) and mother_preparation_return_allowed(focus,event) and uncle_preparation_return_allowed(focus,event) and understands("罗瑾") and later_event_eligible(event,focus.plan) and (event.get("nodeId")!="warning" or not route_tracked() or route_known("罗瑾")) and (not event.get("motherCare",false) or mother_care_has_returned(focus)) and (not event.get("uncleBoundary",false) or uncle_boundary_has_returned(focus))
	if known and not js_truthy(event.get("r4v7P1")):state.knowledgeFacts.append({"id":event.id+":return-knowledge","day":state.day+1,"source":event.actor,"knownBy":["罗瑾"],"scope":"选择结果的可转述部分","text":choice.diaries.default})
	focus.diaryAllowed=known;focus.knowledge.luo=[choice.diaries.default] if known else []
	if known and focus.selected!="罗瑾" and (focus.selected!="home" or focus.plan.rows["罗瑾"].outside) and not lines.any(func(line):return line.begins_with(event.actor)):lines.append(event.actor+"在家里说起今天遇到的事。")
	focus.returnText=" ".join(lines);focus.returnChange=describe_focus_change(before);focus.settled=true;focus.carriedAssets=[];state.phase="focusReturn"
	finish_uncle_boundary_diary(focus,event)
	if not finish_chapter_six_diary(focus,event,choice):state=backup;return false
	if (event.has("motherCrisis") or focus.day==48) and not finish_mother_crisis_diary(focus,event,choice):state=backup;return false
	finish_uncle_crisis_diary(focus,event,choice)
	if has_method("finish_c9_grandfather_recovery"):call("finish_c9_grandfather_recovery",focus,event)
	if contract_error!="":state=backup;return false
	state.history.append({"day":state.day,"type":"later-return","event":event.id,"change":focus.returnChange})
	return true

var pre_photo_outdoor_prose: Dictionary={}
func make_pre_photo_outdoor_event(focus: Dictionary,target: String) -> Dictionary:
	if state.day<44:return _chapter9_parent_9_make_pre_photo_outdoor_event(focus,target)
	if state.day<10 or state.day>48 or target not in PEOPLE or target not in focus.plan.targets or (js_truthy(focus.plan.get("nodeId")) and target==focus.plan.primary):return {}
	var row: Dictionary=_object(focus.plan.rows.get(target));var type: String=row.get("type","")
	if not row.get("outside",false) or row.get("inactive",false) or not present(target):return {}
	if not ((target=="罗瑾" and type in ["water","burial","photo"]) or (target=="外祖父" and type=="wood") or (target=="母亲" and type in ["relief","registration"]) or (target=="安仁叔叔" and type=="committee")):return {}
	if type=="photo":
		var bank: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_nine_photo_ordinary.json"))
		var known: bool=state.get("knowledgeFacts",[]).any(func(k):return k.get("id")=="deadline.notice" and "罗瑾" in k.get("knownBy",[]))
		var ordinary_key: String=JSON.stringify([int(state.day)+1,js_truthy(state.photo.evidence),state.photo.prints>0,state.photo.album.selected>0,known,focus.plan.primary==target,state.photo.transferCount>0,state.photo.prints>0 and state.photo.transferCount>=state.photo.prints])
		if not bank.variants.has(ordinary_key):return {}
		var ordinary: Dictionary=decode_home_content(bank.events[bank.variants[ordinary_key]],bank)
		var receivers: Array=["母亲","安仁叔叔","外祖父"].filter(func(n):return present(n) and not focus.plan.rows[n].outside and understands(n))
		var at_home: Array=PEOPLE.filter(func(n):return n!="罗瑾" and present(n) and not focus.plan.rows[n].outside)
		var recipient_text: String=receivers[0] if not receivers.is_empty() else (at_home[0] if not at_home.is_empty() else "眼前的家人")
		ordinary.intro=ordinary.intro.replace("§RECIPIENT§",recipient_text)
		ordinary.recipient=null if receivers.is_empty() else receivers[0];ordinary.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":state.photo.evidence,"photoPrints":state.photo.prints};return ordinary
	var prior: Array=state.history.filter(func(history):return history.get("day",state.day)<state.day and _object(history.get("readingVariant")).get("group")=="water") if type=="water" else []
	var index: int=(RNG.hash_seed(state.seed+":condition-story:water")+prior.size())%3 if type=="water" else 0
	var previous: String="none" if prior.is_empty() else "many"
	if prior.size()==1:previous=prior[0].get("choice","") if prior[0].get("choice") in ["help","pole_help"] else "carry_home"
	var tool: String=state.memory.get("burialTool","none") if type=="burial" else "none"
	if tool not in ["shovel","rope"] or not tool_available(tool):tool="none"
	if chapter_nine_outdoor_prose.is_empty():chapter_nine_outdoor_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_nine_outdoor_prose.json"))
	var key:=JSON.stringify([int(state.day),target,type,index,state.water>=2 if type=="water" else false,tool_available("axe") if type=="wood" else false,tool,previous,type=="photo" and focus.plan.primary==target])
	if not chapter_nine_outdoor_prose.variants.has(key):return {}
	var event: Dictionary=decode_home_content(chapter_nine_outdoor_prose.events[chapter_nine_outdoor_prose.variants[key]],chapter_nine_outdoor_prose)
	var home: Array=PEOPLE.filter(func(person):return present(person) and not _object(focus.plan.rows.get(person)).get("outside",false))
	var recipients: Array=["母亲","安仁叔叔","外祖父"].filter(func(person):return person in home and understands(person))
	event.recipient=null if recipients.is_empty() else recipients[0]
	event.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":state.photo.get("evidence",0),"photoPrints":state.photo.get("prints",0)}
	if type=="water" and event.has("readingVariant"):
		event.readingVariant.previous=null if prior.is_empty() else prior.back().day
		event.readingVariant.narratorHere="罗瑾" in home
	return event

const HomeCareProse=preload("res://scripts/home_care_prose.gd")
var home_care_reader=HomeCareProse.new()
var later_scene_shells: Dictionary={}
func pre_photo_recovery_offer(focus: Dictionary) -> Dictionary:
	if state.day<44:return _chapter9_parent_9_pre_photo_recovery_offer(focus)
	if state.balanceVersion!="I2f" or state.day<10 or state.day>48:return {}
	var block: int=int(floor(float(state.day-10)/5));var offset: int=RNG.hash_seed(state.seed+":recovery-offer:"+str(block))%5
	if (int(state.day)-10)%5!=offset:return {}
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].get("outside",false));var actors: Array=home.filter(func(person):return can_work_later(person))
	if actors.is_empty():actors=home.filter(func(person):return understands(person))
	if actors.is_empty():return {}
	var sick: Array=home.filter(func(person):return state.ailments.get(person,{}).values().any(func(value):return value>=2))
	sick.sort_custom(func(a,b):return PEOPLE.find(a)<PEOPLE.find(b) if state.people[a].health==state.people[b].health else state.people[a].health<state.people[b].health)
	var item: Variant=null
	for person in sick:
		var types: Array=["cold","wound","nutrition"]
		types.sort_custom(func(a,b):return ["cold","wound","nutrition"].find(a)<["cold","wound","nutrition"].find(b) if state.ailments[person][a]==state.ailments[person][b] else state.ailments[person][a]>state.ailments[person][b])
		var candidate: String={"cold":"herbs","wound":"bandage","nutrition":"medkit"}[types[0]]
		if not tool_available(candidate) and not tool_available("medkit"):item=candidate;break
	if item==null and not (state.wood<=2 and not can_work_later("外祖父")):return {}
	return {"actor":actors[0],"kind":"medicine" if item!=null else "wood","item":item,"cost":2 if item!=null else 1,"day":state.day+1}

func make_pre_photo_care_event(focus: Dictionary,base_only: bool=false) -> Dictionary:
	if state.day<44:return _chapter9_parent_9_make_pre_photo_care_event(focus,base_only)
	if state.day<10 or state.day>48 or "home" not in focus.plan.targets:return {}
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].get("outside",false));var sick: Array=home.filter(func(person):return not focus_fit(person))
	if sick.is_empty():return {}
	sick.sort_custom(func(a,b):return PEOPLE.find(a)<PEOPLE.find(b) if state.people[a].health==state.people[b].health else state.people[a].health<state.people[b].health)
	var patient: String=sick[0];var others: Array=home.filter(func(person):return person!="罗瑾" and understands(person));var speakers: Array=home.filter(func(person):return understands(person));var adult_home: Array=home.filter(func(person):return person!="罗瑾");var actor: String=adult_home[0] if not adult_home.is_empty() else "罗瑾"
	var event: Dictionary={};var suffix: String="fallback.d"+str(int(state.day)+1)+".home.care"
	if focus.plan.primary=="home":
		if later_scene_shells.is_empty():later_scene_shells=JSON.parse_string(FileAccess.get_file_as_string("res://data/later_scene_shells.json"))
		var key: String=focus.plan.key
		if key in ["apprentice","oldphoto","materials","register","inquiry"]:key="papers"
		if key=="burial":key="returner"
		if key=="shelter" and state.shelter>=50:key="papers"
		event=later_scene_shells.get(key,later_scene_shells.papers).duplicate(true);suffix=event.id
	var recipients: Array=["母亲","安仁叔叔","外祖父"].filter(func(person):return person in home and understands(person))
	event.id="later.D"+str(int(state.day)+1)+".home."+suffix;event.title="";event.intro="";event.later=true;event.historyClass="F：家庭与店内为情境演绎；1月30日清理暗房为G游戏编排";event.target="home";event.actor=actor;event.participants=home.duplicate();event.homeParticipants=home.duplicate();event.recipient=null if recipients.is_empty() else recipients[0];event.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":state.photo.get("evidence",0),"photoPrints":state.photo.get("prints",0)};event.chapter="I2b-9";event.conditionKind="care"
	var repairers: Array=home.filter(func(person):return person!=patient and can_work_later(person))
	var raw_care:=pre_photo_raw_care_content(home,patient,repairers)
	if raw_care.is_empty():return {}
	for field in ["title","intro","choices"]:event[field]=raw_care[field]
	for choice in event.choices:choice.later=true
	if base_only:return event

	var offer:=pre_photo_recovery_offer(focus)
	if not offer.is_empty():
		event.id+=".exchange";event.actor=offer.actor;event.conditionKind="recovery"
		var medicine: bool=offer.item!=null;var name: String=TOOL_NAMES[offer.item] if medicine else "木料";var goods: String=name+"一份" if medicine else "能用的短木三份"
		var exchange: Dictionary={"id":"exchange","label":"用米粮"+str(int(offer.cost))+"份换"+goods,"hint":"米粮－"+str(int(offer.cost))+"；"+(name+"＋1，晚间另行用药，不当场治愈" if medicine else "木料＋3，不自动生火或修棚")+"。","requiresResources":{"rice":offer.cost},"immediateEffects":[{"type":"resource_delta","resource":"rice","amount":-offer.cost},{"type":"item_gain","item":offer.item} if medicine else {"type":"resource_delta","resource":"wood","amount":3}],"closures":{"default":""},"diaries":{"default":""}}
		event.choices=[exchange,event.choices[0],event.choices[1]]

	return event

var authored_home_prose: Dictionary={}
func pre_photo_authored_home_layer(focus: Dictionary) -> Dictionary:
	if state.day<10 or state.day>16 or "home" not in focus.plan.targets:return {}
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].get("outside",false))
	if home.any(func(person):return not focus_fit(person)) or not home.any(func(person):return person!="罗瑾" and understands(person)):return {}
	var mask:=0
	for person in home:mask|=1<<PEOPLE.find(person)
	var accepted: bool=js_truthy(state.memory.get("burialAccepted")) if int(state.day) in [11,12] else false
	var registered: bool=js_truthy(state.memory.get("registered")) if state.day==16 else false
	var key:=JSON.stringify([int(state.day),mask,mini(3,int(state.water)) if state.day==10 else 0,accepted,registered])
	if authored_home_prose.is_empty():authored_home_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/pre_photo_home_prose.json"))
	if not authored_home_prose.variants.has(key):return {}
	return decode_home_content(authored_home_prose.events[authored_home_prose.variants[key]],authored_home_prose)


var pre_photo_condition_home_prose: Dictionary={}
func make_pre_photo_condition_home(focus: Dictionary) -> Dictionary:
	if state.day<44:return _chapter9_parent_9_make_pre_photo_condition_home(focus)
	if state.day<10 or state.day>48:return {}
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].get("outside",false))
	if home.is_empty() or home.any(func(person):return not focus_fit(person)):return {}
	var mask:=0
	for person in home:mask|=1<<PEOPLE.find(person)
	var kind: String="weather" if current_weather().get("severe",false) else ("absence" if household_presence_mask()!=15 else ("maintenance" if state.shelter<41 and state.wood>0 else "home"))
	var prior: Array=[];var index:=0;var stock:=0;var gain:=0
	if kind in ["weather","maintenance"]:
		prior=state.history.filter(func(row):return row.get("day",state.day)<state.day and _object(row.get("readingVariant")).get("revision")=="R24-experience-polish-v1" and row.readingVariant.kind==kind)
		var last: Dictionary={}
		for row in prior:last[int(row.readingVariant.index)]=row.day
		var offset: int=RNG.hash_seed(state.seed+"|R24-experience-polish-v1|"+kind)%3;index=-1
		for step in range(3):
			var candidate: int=(offset+step)%3
			if not last.has(candidate):index=candidate;break
		if index<0:
			var candidates: Array=[0,1,2];candidates.sort_custom(func(a,b):return a<b if last[a]==last[b] else last[a]<last[b]);index=candidates[0]
		if kind=="weather":stock=(1 if state.wood>=1 else 0)+(2 if state.shelter>=50 else 0)+(4 if state.shelterItems.oilcloth else 0)
		else:
			var speakers: Array=home.filter(func(person):return person!="罗瑾");gain=formal_repair_gain(int(state.day),speakers[0] if not speakers.is_empty() else "罗瑾")
	else:
		prior=state.history.filter(func(row):return row.get("day",state.day)<state.day and _object(row.get("readingVariant")).get("group")=="shelter")
		index=(RNG.hash_seed(state.seed+":condition-story:shelter")+prior.size())%3
	if chapter_nine_condition_home_prose.is_empty():chapter_nine_condition_home_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_nine_condition_home.json"))
	var key:=JSON.stringify([int(state.day),mask,kind,index,stock,gain])
	if not chapter_nine_condition_home_prose.variants.has(key):return {}
	var event: Dictionary=decode_home_content(chapter_nine_condition_home_prose.events[chapter_nine_condition_home_prose.variants[key]],chapter_nine_condition_home_prose)
	event=_replace_content_token(event,"§WEATHER_NAME§",current_weather().name)
	if kind=="maintenance":
		var actor: String=event.get("actor","")
		if actor=="":
			var adults: Array=home.filter(func(n):return n!="罗瑾");actor=adults[0] if not adults.is_empty() else home[0]
		if not home.any(func(n):return n!=actor and can_work_later(n)):event.intro=event.intro.replace("还留在棚里的家人能搭手的，只接眼前这一段。","眼下能动手的人先顾自己做得到的地方，没有叫不在这里的人回来。")
	if event.has("readingVariant"):event.readingVariant.previous=null if prior.is_empty() else prior.back().day
	return event

const QIAN_D12_LEAD="这一次来传话的人先说明，消息是钱世鑫替慈善队那边问过以后托来的。前面罗家已经知道他在那边帮着联络；今天真正要问清的，是这支队伍由谁带、从哪里集合、怎样回来。\n\n"
const QIAN_D13_LEAD="昨天钱世鑫托来的收殓安排已经把集合、带队和回程问到能够执行的程度。今天家里准备的不是另一件新差事，只是把真正要跟队时能不能用上的东西再核一遍。\n\n"
const QIAN_HISTORY_SUFFIX="；R24：钱世鑫只承担既有收殓联络连续性，不新增其个人史实行为"
func connect_pre_photo_qian(focus: Dictionary,event: Dictionary) -> void:
	if int(focus.day)==11 and str(event.get("title","")).contains("先问怎样回来") and not str(event.get("intro","")).contains("钱世鑫"):event.intro=QIAN_D12_LEAD+event.intro;event.historyClass=event.get("historyClass","")+QIAN_HISTORY_SUFFIX
	if int(focus.day)==12 and js_truthy(state.memory.get("burialAccepted")) and str(event.get("title","")).contains("明天怎样用") and not str(event.get("intro","")).contains("钱世鑫"):event.intro=QIAN_D13_LEAD+event.intro
var family_followup_rules: Dictionary={}
func bind_pre_photo_family_followup(focus: Dictionary,event: Dictionary) -> void:
	if family_followup_rules.is_empty():family_followup_rules=JSON.parse_string(FileAccess.get_file_as_string("res://data/family_followup_rules.json"))
	var rule: Dictionary=_object(family_followup_rules.get(str(int(focus.day)+1)))
	if rule.is_empty() or not js_truthy(state.memory.get(rule.flag)) or js_truthy(event.get("conditionKind")) or js_truthy(event.get("familyFollowup")) or event.get("target")!="home":return
	var sources: Array=state.history.filter(func(row):return row.day<focus.day and row.get("choice")==rule.choice and row.get("type") in ["focus-event","later-choice"] and ((row.day==12 and str(row.get("event","")).begins_with(rule.prefix)) if rule.has("prefix") else row.get("event")==rule.event))
	if sources.is_empty():return
	var source: Dictionary=sources[0]
	if not state.history.any(func(row):return row.day==source.day and row.get("event")==source.event and row.get("type") in ["focus-return","later-return"]):return
	var paragraphs: Array=Array(event.intro.split("\n\n"));paragraphs.insert(1,rule.scene.replace("{{actor}}",event.actor));event.intro="\n\n".join(paragraphs)
	event.familyFollowup={"day":focus.day+1,"sourceDay":source.day,"sourceEvent":source.event,"sourceChoice":source.choice,"diary":rule.diary}
func make_pre_photo_home_base(focus: Dictionary) -> Dictionary:
	if state.day<10 or state.day>16 or "home" not in focus.plan.targets or js_truthy(focus.plan.get("nodeId")):return {}
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].get("outside",false))
	if home.is_empty():return {}
	if home.any(func(person):return not focus_fit(person)):return make_pre_photo_care_event(focus)
	var adults: Array=home.filter(func(person):return person!="罗瑾");var speaker: String=adults[0] if not adults.is_empty() else "罗瑾"
	var raw: Dictionary={};var event: Dictionary={};var suffix: String=""
	if focus.plan.primary=="home":
		if later_scene_shells.is_empty():later_scene_shells=JSON.parse_string(FileAccess.get_file_as_string("res://data/later_scene_shells.json"))
		var key: String=focus.plan.key
		if key in ["apprentice","oldphoto","materials","register","inquiry"]:key="papers"
		if key=="burial":key="returner"
		if key=="care" and not home.any(func(person):return state.people[person].health<9):key="papers"
		if key=="shelter" and state.shelter>=50:key="papers"
		event=later_scene_shells.get(key,later_scene_shells.papers).duplicate(true);suffix=event.id
	else:
		raw=make_pre_photo_condition_home(focus)
		if raw.is_empty():return {}
		event=raw.duplicate(true);suffix=raw.id
	var recipients: Array=["母亲","安仁叔叔","外祖父"].filter(func(person):return person in home and understands(person))
	event.id="later.D"+str(int(state.day)+1)+".home."+suffix;event.target="home";event.later=true;event.actor=speaker;event.participants=[speaker];event.homeParticipants=[speaker];event.recipient=null if recipients.is_empty() else recipients[0];event.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":state.photo.get("evidence",0),"photoPrints":state.photo.get("prints",0)};event.historyClass="F：普通难民家庭情境演绎；登记为12月底阶段背景，不指认罗家当日史实";event.chapter4Revision="I3e-4b";event.chapter="I2b-4"
	if adults.is_empty():
		if raw.is_empty():raw=make_pre_photo_condition_home(focus)
		if raw.is_empty():return {}
		var saved_id: String=event.id
		for key in raw:event[key]=raw[key].duplicate(true) if raw[key] is Dictionary or raw[key] is Array else raw[key]
		event.id=saved_id;event.actor=speaker
	else:
		var layer:=pre_photo_authored_home_layer(focus)
		if layer.is_empty():return {}
		for key in layer:event[key]=layer[key]
		event.erase("conditionKind")
		# R24 continuity runs after optional neighbours, not on displaced base scenes.
		event.intro=event.intro.trim_prefix(QIAN_D12_LEAD).trim_prefix(QIAN_D13_LEAD);event.historyClass=event.historyClass.trim_suffix(QIAN_HISTORY_SUFFIX)
		bind_pre_photo_family_followup(focus,event)
	# Original late maintenance binder may replace only its low-priority raw slot here.
	if event.id.ends_with(".maintenance") and state.wood>0:
		if raw.is_empty():raw=make_pre_photo_condition_home(focus)
		if raw.get("conditionKind")=="maintenance":
			event=raw.duplicate(true);event.later=true;event.historyClass="情境演绎；白天家庭维护为游戏安排，不是历史日期事实";event.id="later.D"+str(int(state.day)+1)+".home."+raw.id;event.target="home";event.actor=speaker;event.participants=home.duplicate();event.homeParticipants=home.duplicate()
	return event

func bind_day_eleven_twelve(f: Dictionary) -> bool:
	if f.plan.get("key")=="pigeonPickup":bind_pigeon_pickup(f);apply_middle_reading_context(f);return true
	return _pigeon_parent_1_bind_day_eleven_twelve(f)

func ensure_day_eleven_twelve_focus() -> Dictionary:
	if state.day<10:return ensure_early_focus()
	return _pigeon_parent_1_ensure_day_eleven_twelve_focus()

func enter_day_eleven_twelve_focus() -> bool:
	if not acknowledge_solitary_warning():return false
	if ensure_day_eleven_twelve_focus().is_empty():return false
	state.phase="focus";return true
func select_day_eleven_twelve_focus(target: String) -> bool:
	var focus:=ensure_day_eleven_twelve_focus()
	if focus.is_empty() or state.phase not in ["focus","morning","event"] or focus.get("choiceIndex")!=null:return false
	if target not in focus.plan.targets:state.error="这个注视入口不属于今天实际外出的人或留棚地点。";return false
	var event: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get(target)))
	if event.is_empty() or not later_event_eligible(event,focus.plan):return false
	focus.textContext=state.shelterItems.duplicate(true);focus.textContext.whistle=state.tools.whistle;focus.selected=target;focus.eventId=event.id;focus.choiceIndex=null;focus.outcomeKey=null;focus.immediateText="";focus.immediateChange="";focus.returnText="";focus.returnChange="";focus.settled=false;focus.cancelWork=null;focus.partialWork=null;focus.appliedEffects=[];focus.returnEffects=[];focus.knowledge={"player":[],"luo":[]};state.error=null;state.phase="focusEvent";return true

var pre_photo_care_raw_prose: Dictionary={}
func pre_photo_raw_care_content(home: Array,patient: String,repairers: Array) -> Dictionary:
	if state.day<44:return _chapter9_parent_9_pre_photo_raw_care_content(home,patient,repairers)
	var mask:=0
	for person in home:mask|=1<<PEOPLE.find(person)
	var worker: Variant=null;var gain:=0
	if state.shelter<41 and state.wood>0 and not repairers.is_empty():worker="外祖父" if "外祖父" in repairers else repairers[0];gain=formal_repair_gain(int(state.day),worker)
	if chapter_nine_care_raw_prose.is_empty():chapter_nine_care_raw_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_nine_care_raw_prose.json"))
	var key:=JSON.stringify([int(state.day),mask,patient,worker,state.water>0,gain])
	if not chapter_nine_care_raw_prose.variants.has(key):return {}
	var result: Dictionary=decode_home_content(chapter_nine_care_raw_prose.events[chapter_nine_care_raw_prose.variants[key]],chapter_nine_care_raw_prose)
	var description:=ailment_text(patient)
	return _replace_content_token(result,"§AILMENT_DESCRIPTION§",description if not description.is_empty() else "身上很不舒服")

func resolve_day_eleven_twelve_choice(index: int) -> bool:
	if current_later_focus_event().get("pigeonPickup",false):return commit_pigeon_choice_core(index)
	return _pigeon_parent_1_resolve_day_eleven_twelve_choice(index)

func settle_day_eleven_twelve_return() -> bool:
	if current_later_focus_event().get("pigeonPickup",false):return settle_pigeon_focus_return()
	return _pigeon_parent_1_settle_day_eleven_twelve_return()

func ordinary_pre_photo_effect_supported_base(effect: Dictionary) -> bool:
	match effect.get("type"):
		"resource_delta":return effect.get("resource") in ["rice","wood","water"] and typeof(effect.get("amount")) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(effect.amount))
		"shelter_delta":return typeof(effect.get("amount")) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(effect.amount))
		"item_gain","item_consume":return TOOL_NAMES.has(effect.get("item"))
		"character_health","character_spirit":return effect.get("target") in PEOPLE and typeof(effect.get("amount")) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(effect.amount))
		"flag_set":return effect.get("flag") in ["burialExperienced","burialPlacesRemembered","burialRoute","burialTool","burialAccepted","burialOfferHeard","burialDeferred","burialToolLent","certificate","keptHouseholdPrivate","papers","registrationInquiry","registered","sourcesSeparated","waterExposure"] and effect.has("value")
	return false

const ROPE_KEY="neighbourRopeR2a"

const ROPE_RANDOM="R2a-return-v1"

var rope_bank: Dictionary={}

func valid_rope_record(record: Variant) -> bool:
	if not record is Dictionary:return false
	for key in ["stage","firstDay","lastDay"]:
		if not _whole_number(record.get(key)):return false
	if record.stage<1 or record.stage>3 or record.firstDay<13 or record.firstDay>40 or record.lastDay<record.firstDay or record.lastDay>48:return false
	if not record.get("lent") is bool or not record.get("lastChoice") is String or not record.get("knownBy") is Array or record.knownBy.size()>4 or not record.knownBy.all(func(person):return person is String and person in PEOPLE):return false
	if typeof(record.get("roll")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(record.roll)) or record.roll<0 or record.roll>=1 or record.get("randomVersion")!=ROPE_RANDOM:return false
	if record.stage>=2 and (not record.get("follow") is String or not record.get("support") is bool):return false
	if record.stage==3 and record.get("result") not in ["returned","damaged","not_borrowed"]:return false
	return true

func make_rope_event(focus: Dictionary,admission: Dictionary,decorated: bool=true) -> Dictionary:
	var date: int=int(focus.day)+1;var record: Variant=state.memory.get(ROPE_KEY)
	if date<13 or date>48 or not admission.get("allowed",false) or not admission.get("home") is Array or admission.get("actor") not in admission.home:return {}
	if record!=null and not valid_rope_record(record):return {}
	var stage: int=1 if record==null else int(record.stage)+1
	if stage>3 or stage==1 and date>40:return {}
	var home_mask:=0
	for person in admission.home:
		if person not in PEOPLE or not present(person):return {}
		home_mask|=1<<PEOPLE.find(person)
	var lent: bool=record.lent if record!=null else false;var support: bool=record.get("support",false) if stage==3 and lent else false;var space: bool=record.get("follow")=="space" if stage==3 and not lent else false
	var result: String=""
	if stage==3:result=("returned" if record.roll<(0.85 if support else 0.70) else "damaged") if lent else "not_borrowed"
	if rope_bank.is_empty():rope_bank=JSON.parse_string(FileAccess.get_file_as_string("res://data/rope_prose.json"))
	var key:=JSON.stringify([stage,home_mask,admission.actor,lent,support,space,result,state.tools.rope])
	if not rope_bank.variants.has(key):return {}
	var event: Dictionary=decode_home_content((rope_bank.events if decorated else rope_bank.raw_events)[rope_bank.variants[key]],rope_bank);event.id="neighbour.rope.R2a.D"+str(date)+"."+str(stage)
	event.neighbourhood.prior=null if record==null else record.duplicate(true);event.neighbourhood.day=date
	if decorated:event.readingVariant.prior=null if record==null else {"lent":record.lent,"sent":js_truthy(record.get("sent")),"support":js_truthy(record.get("support")),"follow":record.get("follow") if js_truthy(record.get("follow")) else null}
	if decorated:event.readingVariant.sourceEvent=event.id;event.readingVariant.day=date
	var resting: Array=admission.get("resting",[])
	if not resting.is_empty():
		var names: String="、".join(resting);event.intro+="\n\n"+names+"今天仍照原来的安排歇着。"+event.actor+"在棚边接过来人的话，没有叫"+names+"起身帮忙。来人把这一回要交代的说清，家里的其余事情仍得另作安排。"
	return event

func resolve_rope_choice(index: int) -> bool:
	if state.ended or state.day<12 or state.day>47 or state.phase!="focusEvent" or state.focus.get("choiceIndex")!=null:return false
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if not event.get("neighbourhood") is Dictionary or event.neighbourhood.get("chain")!=ROPE_KEY or index<0 or index>=event.choices.size():return false
	var choice: Dictionary=event.choices[index];var requirement:=ordinary_pre_photo_requirement(choice)
	if not requirement.met:state.error=requirement.reason;return false
	if not later_event_eligible(event,focus.plan):state.error="当事人已不能参与这段现场。";return false
	var prior: Variant=state.memory.get(ROPE_KEY);var stage: int=int(event.neighbourhood.stage)
	if (0 if prior==null else prior.get("stage",0))!=stage-1:state.error="这次选择尚未结算：这次邻里往来的前情已经改变";return false
	var backup:=state.duplicate(true);var record: Dictionary={} if prior==null else prior.duplicate(true)
	record.stage=stage;record.lastDay=state.day+1;record.lastChoice=choice.id
	if stage==1:
		record.lent=choice.id=="lend";record.firstDay=record.lastDay;record.knownBy=PEOPLE.filter(func(person):return understands(person) and not focus.plan.rows[person].outside)
		record.roll=float(RNG.hash_seed(state.seed+"|neighbour-rope|R2a-return-v1"))/4294967296.0;record.randomVersion=ROPE_RANDOM
	if stage==2:record.follow=choice.id;record.support=choice.id=="support"
	if stage==3:record.result=event.neighbourhood.result
	if not valid_rope_record(record):return false
	choice.immediateEffects=choice.get("immediateEffects",[]).filter(func(effect):return not (effect.type=="flag_set" and effect.get("flag")==ROPE_KEY));choice.immediateEffects.append({"type":"flag_set","flag":ROPE_KEY,"value":record})
	if not commit_rope_choice_core(index):state=backup;return false
	if stage==1 and choice.id=="lend":focus.immediateChange=focus.immediateChange.replace("失去绳索×1","借出绳索×1（暂不在家）")
	return true

func finish_rope_diary(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	if not event.get("neighbourhood") is Dictionary or not focus.get("diaryAllowed",false):return true
	var record: Dictionary=_object(state.memory.get(ROPE_KEY)).duplicate(true)
	if not valid_rope_record(record):return false
	for person in PEOPLE:
		if understands(person) and person not in record.knownBy:record.knownBy.append(person)
	state.memory[ROPE_KEY]=record
	var parts: Array=Array(choice.diaries.default.split("\n\n"));var last: String=parts.pop_back();var body: String="\n\n".join(parts)
	if focus.get("chapterDiary") is Array and not focus.chapterDiary.is_empty():
		for i in range(focus.chapterDiary.size()):
			if focus.chapterDiary[i].contains(choice.diaries.default):focus.chapterDiary[i]=focus.chapterDiary[i].replace(choice.diaries.default,body)
		focus.chapterDiary[-1]=last
	else:focus.chapterDiary=[body,last]
	focus.neighbourReading={"stage":event.neighbourhood.stage,"chain":ROPE_KEY,"once":true};return true

func settle_rope_return() -> bool:
	if state.ended or state.day<12 or state.day>16:return false
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if not event.get("neighbourhood") is Dictionary:return false
	if focus.get("settled",false):state.phase="focusReturn";return true
	var backup:=state.duplicate(true)
	if not settle_ordinary_pre_photo_return():return false
	if not finish_rope_diary(focus,event,event.choices[int(focus.choiceIndex)]):state=backup;return false
	return true

func commit_rope_choice_core(index: int) -> bool:
	if state.ended or state.phase!="focusEvent" or state.focus.get("choiceIndex")!=null:return false
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if event.is_empty() or index<0 or index>=event.get("choices",[]).size():return false
	var choice: Dictionary=event.choices[index]
	for key in ["motherCrisis","uncleCrisis","motherCare","uncleBoundary","photoTransfer","photoBatch","nextMorningEffects"]:
		if js_truthy(choice.get(key)):return false
	var immediate: Array=choice.get("immediateEffects",[]).duplicate(true)
	if js_truthy(choice.get("flag")):immediate.append({"type":"flag_set","flag":choice.flag,"value":true})
	if immediate.any(func(effect):return not ordinary_pre_photo_effect_supported(effect)) or choice.get("returnEffects",[]).any(func(effect):return not ordinary_pre_photo_effect_supported(effect)):return false
	var requirement:=ordinary_pre_photo_requirement(choice)
	if not requirement.met:state.error=requirement.reason;return false
	if not later_event_eligible(event,focus.plan):state.error="当事人已不能参与这段现场。";return false
	var before:=focus_snapshot()
	apply_ordinary_pre_photo_packet(queue_focus_packet(immediate,event.id+":"+choice.id+":immediate","immediate",event.actor))
	var packet:=queue_focus_packet(choice.get("returnEffects",[]),event.id+":"+choice.id+":return","on_return",event.actor)
	focus.carriedAssets=[]
	for effect in packet.effects:
		if effect.type=="resource_delta" and effect.amount>0:focus.carriedAssets.append({"owner":event.actor,"resource":effect.resource,"amount":effect.amount,"resultPacketId":packet.id})
	focus.cancelWork=focus.selected if choice.get("workImpact")=="complete" else null;focus.partialWork=focus.selected if choice.get("workImpact")=="partial" else null
	focus.choiceIndex=index;focus.outcomeKey="default";focus.immediateText=choice.closures.default;focus.immediateChange=describe_focus_change(before)
	focus.knowledge.player=[focus.immediateText];focus.knowledge.luo=[focus.immediateText] if focus.selected=="罗瑾" or (focus.selected=="home" and not focus.plan.rows["罗瑾"].outside) else []
	var history: Dictionary={"day":state.day,"type":"later-choice","event":event.id,"choice":choice.id}
	if event.get("conditionKind")==_object(event.get("readingVariant")).get("kind"):
		if event.has("readingVariant"):history.readingVariant=event.readingVariant
	else:history.readingVariant=null
	state.phase="focusResult";state.error=null;state.history.append(history);return true

var rope_memory_prose: Dictionary={}

var rope_editorial: Dictionary={}

func confirm_chapter_night_core() -> bool:
	if state.ended or state.phase!="night" or _object(state.get("nightCycle")).get("day")==state.day:return false
	if not _opening_night_supported():state.error="当前开发候选尚未接通这一阶段的夜间流程。";return false
	if state.night.repair:state.error="普通修棚在白天家中注视中安排。今晚不接受长期修棚；未扣除物资。";return false
	var backup:=state.duplicate(true)
	if not validate_current_diet():state=backup;state.error="本次确认已撤回："+contract_message;return false
	for person in PEOPLE:
		diet_previous(person)
		if contract_error!="":state=backup;state.error="本次确认已撤回："+contract_message;return false
	if not validate_expedition_plan() or not validate_night_plan():return false
	if state.night.pigeonAction!="none" and not pigeon_action_allowed(state.night.pigeonAction):state.error="信鸽或取物的条件已有变化，请重新安排。";return false
	for pair in [["feedPoultry","poultry"],["feedPet","pet"]]:
		if state.night[pair[0]] and not needs_animal_care(pair[1]):state.error="这只动物暂不需要补喂，请重新选择。";return false
	var patient: String=state.night.treatment.get_slice("|",1)
	if not patient.is_empty() and _object(state.expedition.get("plan")).get("name")==patient and departure_block(patient).is_empty():state.error="准备离家的家人不能同时留棚接受这次治疗。";return false
	state.night.repair=false;var preview:=preview_night();var id: String=state.seed+":night:"+str(int(state.day))
	close_unanswered_animal_encounter()
	var cycle={"id":id,"day":state.day,"status":"awaiting_event","plan":state.night.duplicate(true),"cost":preview.cost.duplicate(true),"householdWater":preview.householdWater,"expeditionReservation":preview.expedition.duplicate(true),"repair":preview.repair.duplicate(true),"treatment":state.night.get("treatment","none"),"disturbed":false}
	state.nightCycle=cycle;cycle.shelterMaintenanceRevision=SHELTER_MAINTENANCE_REVISION;cycle.hungerRevision="A1";cycle.solitaryHealthEligible=solitary_health_night_eligible()
	if cycle.solitaryHealthEligible and queue_solitary_health_packet()==null:state=backup;state.error="C-018夜间资格已锁定，但统一结果包未能建立";return false
	var exposure: Dictionary=_object(state.memory.get("waterExposure"));cycle.waterExposure=exposure.duplicate(true) if exposure.get("day")==state.day else null;state.memory.erase("waterExposure")
	var departed:=commit_expedition()
	if not departed.is_empty():state.nightResults.append(departed)
	cycle.responseRevision=NIGHT_RESPONSE_REVISION;cycle.readingRevision="R3";cycle.readingStart=capture_night_reading()
	state.deltas={"rice":0,"water":0,"wood":0}
	for key in ["rice","water","wood"]:state[key]-=cycle.cost[key];state.deltas[key]=-cycle.cost[key]
	if cycle.treatment!="none":state.tools[cycle.treatment.split("|")[0]]=false
	if state.get("effectLedger")==null:state.effectLedger={"appliedEffectIds":[]}
	state.effectLedger.appliedEffectIds.append(id+":cost")
	settle_pigeon_care(state.night.feedPoultry,state.nightResults,true);cycle.pigeonCareDone=true;commit_pigeon_send()
	if not lock_current_diet(cycle):state=backup;state.error="本次确认已撤回："+contract_message;return false
	state.pendingNightEvent=prepare_night_event()
	if state.pendingNightEvent!=null and not prepare_night_reading(state.pendingNightEvent,cycle):state=backup;state.error="本次确认已撤回：夜间正文未接通。";return false
	cycle.outcomeRng=state.rngState;state.phase="nightEvent"
	return true

func make_chapter_home_base(focus: Dictionary) -> Dictionary:
	if state.day<44:return _chapter9_parent_9_make_chapter_home_base(focus)
	if state.day>48 or "home" not in focus.plan.targets:return {}
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].outside)
	if home.is_empty():return {}
	if home.any(func(person):return not focus_fit(person)):return make_pre_photo_care_event(focus)
	var adults: Array=home.filter(func(person):return person!="罗瑾");var speaker: String=adults[0] if not adults.is_empty() else "罗瑾"
	var event: Dictionary={};var raw: Dictionary={}
	if focus.plan.primary=="home":
		if later_scene_shells.is_empty():later_scene_shells=JSON.parse_string(FileAccess.get_file_as_string("res://data/later_scene_shells.json"))
		var key: String=focus.plan.key
		if key in ["apprentice","oldphoto","materials","register","inquiry"]:key="papers"
		if key=="shelter" and state.shelter>=50:key="papers"
		event=later_scene_shells.get(key,later_scene_shells.papers).duplicate(true)
	else:
		raw=make_pre_photo_condition_home(focus);event=raw.duplicate(true)
	if event.is_empty():return {}
	var suffix: String=event.id;var recipients: Array=["母亲","安仁叔叔","外祖父"].filter(func(person):return person in home and understands(person))
	event.id="later.D"+str(int(state.day)+1)+".home."+suffix;event.target="home";event.later=true;event.actor=speaker;event.participants=[speaker];event.homeParticipants=[speaker];event.recipient=null if recipients.is_empty() else recipients[0];event.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":state.photo.evidence,"photoPrints":state.photo.prints};event.historyClass="F：家庭与店内为情境演绎；1月30日清理暗房为G游戏编排";event.chapter="I2b-9"
	if home.any(func(person):return not can_work_later(person)):
		var fallback:=make_pre_photo_condition_home(focus);var old_id: String=event.id
		if fallback.is_empty():return {}
		for field in fallback:event[field]=fallback[field]
		event.id=old_id;event.target="home";event.later=true;event.chapter="I2b-9"
		for choice in event.choices:choice.later=true
		return event
	if chapter_nine_home_prose.is_empty():chapter_nine_home_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_nine_home_prose.json"))
	var mask:=0
	for person in home:mask|=1<<PEOPLE.find(person)
	var key: String=JSON.stringify([int(state.day),mask,2 if state.shelter>=50 else (0 if state.shelter<41 else 1),tool_available("bandage"),state.get("knowledgeFacts",[]).any(func(fact):return fact.get("id")=="deadline.notice" and speaker in fact.get("knownBy",[])),state.wood<2])
	if not chapter_nine_home_prose.variants.has(key):return {}
	var variant: Dictionary=chapter_nine_home_prose.variants[key]
	if variant.has("fallback"):
		var fallback:=make_pre_photo_condition_home(focus);var id: String=event.id
		if fallback.is_empty():return {}
		for field in fallback:event[field]=fallback[field]
		event.id=id;event.target="home";event.later=true;event.chapter="I2b-9"
		for choice in event.choices:choice.later=true
	else:
		var layer: Dictionary=decode_home_content(chapter_nine_home_prose.events[variant.event],chapter_nine_home_prose)
		for field in layer:event[field]=layer[field]
		event.erase("conditionKind")
	return event

func known_rope_facts(focus: Dictionary) -> Array:
	var facts: Array=[];var pattern:=RegEx.new();pattern.compile("^neighbour\\.(rope\\.R2a|parcel\\.R2b)\\.D\\d+\\.([123])$")
	for history in state.history:
		if history.get("type")!="later-choice" or history.day>=focus.day:continue
		var matched=pattern.search(str(history.get("event","")))
		if matched==null or not state.history.any(func(row):return row.get("type")=="later-return" and row.day==history.day and row.get("event")==history.event):continue
		var receipts: Array=state.get("knowledgeFacts",[]).filter(func(row):return row.get("id")==history.event+":return-knowledge" and "罗瑾" in row.get("knownBy",[]) and row.get("day",INF)<=focus.day+1)
		if receipts.is_empty():continue
		var chain: String="rope" if matched.get_string(1).begins_with("rope") else "parcel";var record: Dictionary=_object(state.memory.get(ROPE_KEY if chain=="rope" else PARCEL_KEY));var stage: int=int(matched.get_string(2));var variant: Dictionary=_object(history.get("readingVariant"))
		var fact: Dictionary={"key":history.event+":"+history.choice,"event":history.event,"choice":history.choice,"chain":chain,"stage":stage,"day":history.day+1,"source":receipts[0].source,"lent":js_truthy(record.get("lent")),"sent":js_truthy(record.get("sent")),"result":null,"wood":null,"duplicate":null}
		if chain=="rope":
			if stage==1:fact.lent=history.choice=="lend"
			if stage==3:fact.result="returned" if history.choice in ["take","give"] else ("damaged" if history.choice in ["compensate","release"] else "not_borrowed")
			if variant.get("revision")=="WebR3-neighbour-prose-v1":fact.duplicate=variant.get("duplicateRope")
		else:
			if stage==1:fact.sent=history.choice=="send"
			if stage==2:fact.result=variant.result if variant.get("revision")=="WebR3-neighbour-prose-v1" and js_truthy(variant.get("result")) else (record.get("result") if record.get("stage",0)>=2 else null)
			if stage==3:
				var earlier: Array=facts.filter(func(x):return x.chain=="parcel" and x.stage==2 and x.day<=history.day+1)
				fact.result=earlier[-1].result if not earlier.is_empty() else null
				if history.choice=="take" and record.get("stage")==3 and (record.get("wood")==1 or record.get("wood")==3):fact.wood=record.wood
		facts.append(fact)
	facts.sort_custom(func(a,b):return a.day<b.day);return facts

func apply_rope_memory_echo(focus: Dictionary,event: Dictionary) -> void:
	if event.is_empty() or js_truthy(event.get("nodeId")) or event.has("neighbourhood") or event.has("neighbourParcel") or event.get("conditionKind") not in ["care","recovery"] or _object(event.get("readingVariant")).get("revision")!="WebR2-home-care-prose-v1":return
	var facts:=known_rope_facts(focus)
	if facts.is_empty():return
	var used: Array=[]
	for history in state.history:
		if history.get("type")=="later-choice" and history.day<focus.day and state.history.any(func(row):return row.get("type")=="later-return" and row.day==history.day and row.get("event")==history.get("event")):
			var key=_object(_object(history.get("readingVariant")).get("neighbourEcho")).get("key")
			if js_truthy(key):used.append(key)
	var latest: Array=[]
	for chain in ["rope","parcel"]:
		var rows: Array=facts.filter(func(f):return f.chain==chain)
		if not rows.is_empty():latest.append(rows[-1])
	latest.sort_custom(func(a,b):return a.day>b.day)
	var unused: Array=latest.filter(func(f):return f.key not in used)
	if unused.is_empty():return
	var fact: Dictionary=unused[0]
	if rope_memory_prose.is_empty():rope_memory_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/rope_memory.json"))
	var text: String=rope_memory_prose.memory.get(fact.choice,"")
	if fact.chain=="parcel":
		if parcel_memory_prose.is_empty():parcel_memory_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/parcel_memory.json"))
		text=parcel_memory_prose.get(JSON.stringify([int(fact.stage),fact.choice,fact.sent,fact.result,fact.wood]),"")
	if text.is_empty():return
	event.readingVariant.neighbourEcho=fact.duplicate(true)
	for choice in event.choices:choice.diaries.default+="\n\n"+text

func rope_ending_text(focus: Dictionary) -> String:
	var facts:=known_rope_facts(focus)
	if facts.is_empty():return ""
	if rope_memory_prose.is_empty():rope_memory_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/rope_memory.json"))
	var fact: Dictionary=facts.back()
	return rope_memory_prose.ending.get(JSON.stringify([int(fact.stage),fact.choice,fact.lent,fact.duplicate==true]),"")

func apply_chapter_maintenance(focus: Dictionary) -> void:
	if state.day<44:_chapter9_parent_9_apply_chapter_maintenance(focus);return
	var current: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get("home")))
	if current.is_empty() or state.wood<=0:return
	var low: bool=current.id.ends_with(".maintenance");var fresh: bool=(current.has("neighbourhood") and current.neighbourhood.get("stage")==1 and not js_truthy(current.neighbourhood.get("prior"))) or (current.has("neighbourParcel") and current.neighbourParcel.get("stage")==1 and not js_truthy(current.neighbourParcel.get("prior"))) or current.id.begins_with("neighbour.day.R2b.")
	if not low and not (state.shelter<21 and fresh):return
	var raw:=make_pre_photo_condition_home(focus)
	if raw.get("conditionKind")!="maintenance":return
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].get("outside",false));var adults: Array=home.filter(func(person):return person!="罗瑾");var actor: String=adults[0] if not adults.is_empty() else "罗瑾"
	var event: Dictionary=raw.duplicate(true);event.later=true;event.historyClass="情境演绎；白天家庭维护为游戏安排，不是历史日期事实";event.id="later.D"+str(int(state.day)+1)+".home."+raw.id;event.target="home";event.actor=actor;event.participants=home.duplicate();event.homeParticipants=home.duplicate()
	if not low:focus.dayMaintenanceDisplaced={"id":current.id,"title":current.title,"reason":"shelter_below_21_with_wood","freshNeighbour":true}
	focus.laterEvents[event.id]=event;focus.plan.eventIds.home=event.id

func bind_chapter_rope(focus: Dictionary) -> bool:
	var date: int=int(focus.day)+1;var record=state.memory.get(ROPE_KEY)
	if date<13 or date>48 or "home" not in focus.plan.targets or (record is Dictionary and record.get("stage")==3):return true
	if date==13 and js_truthy(state.memory.get("burialAccepted")):return true
	var old: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get("home")))
	if date in [15,17] and old.get("chapter4Revision")=="I3e-4b":return true
	if old.is_empty() or js_truthy(old.get("nodeId")) or js_truthy(focus.plan.get("recoveryOffer")) or js_truthy(old.get("recovery")) or js_truthy(old.get("motherCare")) or js_truthy(old.get("uncleBoundary")) or focus.plan.get("key") in ["expeditionSearch","pigeonPickup"]:return true
	if record==null and date>40 or record is Dictionary and date<record.get("lastDay",INF)+3:return true
	var admission:=home_neighbour_admission(focus,"rope")
	if not admission.allowed:return true
	var event:=make_rope_event(focus,admission,false)
	if event.is_empty():return false
	focus.neighbourDisplaced={"id":old.id,"title":old.title};focus.laterEvents[event.id]=event;focus.plan.eventIds.home=event.id;return true

func animal_encounter_for_night() -> Variant:
	if state.phase!="night" or state.get("features",{}).get("animals",true)==false or minor_night_blocked():return null
	for kind in ["cat","dog"]:
		var window: Array=[14,17] if kind=="cat" else [28,31]
		if state.day<window[0] or state.day>window[1] or _object(state.memory.get("animalEncounters")).get(kind,false):continue
		var due: int=window[0]+RNG.hash_seed(state.seed+":encounter:"+kind)%(window[1]-window[0]+1)
		if state.day<due:continue
		return {"kind":kind,"text":"一只瘦猫在棚边停下来。人一伸手，它便退开；等手收回，又蹲在原处看着。这里并不是它原来的家，若留下它，以后也得从有限的米粮里留出一份。" if kind=="cat" else "一条瘦狗沿棚外嗅了一阵，在不挡路的地方伏下。人经过时，它抬起头，又放下。留它不只是这一夜的事；家里能给它一个位置，也得一直为它备粮。"}
	return null

func resolve_animal_encounter(choice: String,kind: String) -> bool:
	var encounter=animal_encounter_for_night()
	if encounter==null or encounter.kind!=kind or choice not in ["accept","decline"] or choice=="accept" and state.animals.pet!=null:return false
	if choice=="accept" and not add_animal("pet",kind):return false
	record_animal_encounter(kind,"adopted" if choice=="accept" else ("occupied" if state.animals.pet!=null else "declined"))
	state.nightResults.append(animal_name(state.animals.pet)+"被留在棚边，宠物格已有了它；需要另外按期喂养。" if choice=="accept" else ("那只猫" if kind=="cat" else "那条狗")+"没有被留下，后来也没有再来。")
	return true

func close_unanswered_animal_encounter() -> void:
	var encounter=animal_encounter_for_night()
	if encounter!=null:resolve_animal_encounter("decline",encounter.kind)

func rope_editorial_text(raw: Variant,variables: Dictionary) -> String:
	var result: String=str(raw) if raw!=null else ""
	for pass_index in range(2):
		for key in variables:result=result.replace("{"+key+"}",str(variables[key]))
	return result

func apply_rope_editorial(focus: Dictionary,event: Dictionary) -> void:
	var variant: Dictionary=_object(event.get("readingVariant"));var meta: Dictionary=_object(event.get("neighbourhood"));var date: int=int(focus.day)+1
	if variant.get("revision")!="WebR3-neighbour-prose-v1" or variant.get("chain")!="rope" or meta.get("chain")!=ROPE_KEY:return
	var first: bool=date==13 and meta.get("stage")==1 and event.id=="neighbour.rope.R2a.D13.1"
	var second: bool=date==16 and meta.get("stage")==2 and _object(meta.get("prior")).get("firstDay")==13 and event.id=="neighbour.rope.R2a.D16.2"
	if not first and not second:return
	var expected: Array=["decline","lend"] if first else (["support","wait"] if meta.prior.lent else ["no_space","space"]);var ids: Array=event.choices.map(func(choice):return choice.id);ids.sort();expected.sort()
	if ids!=expected or variant.get("actor") not in PEOPLE or event.actor!=variant.actor:return
	if rope_editorial.is_empty():rope_editorial=JSON.parse_string(FileAccess.get_file_as_string("res://data/rope_editorial.json"))
	var actor: String=variant.actor;var speaker: String="娘" if actor=="母亲" else ("叔叔" if actor=="安仁叔叔" else actor)
	var variables: Dictionary={"actor":actor,"speaker":speaker,"role1":rope_editorial.stage1.roles[actor],"ropeHere":rope_editorial.stage1.ropeHere if tool_available("rope") else rope_editorial.stage1.ropeAbsent,"directQuestion":rope_editorial.stage1.directQuestion_self if actor=="罗瑾" else rope_editorial.stage1.directQuestion_other}
	if first:event.intro=rope_editorial_text(rope_editorial.stage1.intro,variables)
	for choice in event.choices:
		var text: Dictionary=rope_editorial["stage1" if first else "stage2"].choices[choice.id]
		if first and choice.closures.get("default") is String:choice.closures.default=rope_editorial_text(text.closure,variables)
		if choice.diaries.get("default") is String:choice.diaries.default=rope_editorial_text(text["direct" if variant.narratorHere else "reported"],variables)

func _chapter4_parent_0_ordinary_pre_photo_effect_supported(effect: Dictionary) -> bool:
	if effect.get("type")=="flag_set" and effect.get("flag")==ROPE_KEY:return valid_rope_record(effect.get("value"))
	return ordinary_pre_photo_effect_supported_base(effect)

func chapter_five_node_done(node: Dictionary) -> bool:
	return node.get("status") in ["resolved","skipped","no_recipient","unwarned"]

var chapter_five_node_bank: Dictionary={}

var employment_bridge_bank: Dictionary={}

func make_chapter_five_node(node: String,plan: Dictionary) -> Dictionary:
	if node not in ["names","sources","employ"] or state.day<18 or state.day>23:return {}
	var home: int=0;var adults: int=0
	for i in range(PEOPLE.size()):
		var person: String=PEOPLE[i]
		if present(person) and not _object(plan.rows.get(person)).get("outside",false):home|=1<<i
		if i>0 and understands(person):adults|=1<<(i-1)
	if home&1==0:return {}
	if chapter_five_node_bank.is_empty():chapter_five_node_bank=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_five_nodes.json"))
	var key: String=JSON.stringify([node,int(state.day),home,adults,js_truthy(state.memory.get("visitorNameRecorded")),js_truthy(state.memory.get("employment_offer_pending"))])
	if not chapter_five_node_bank.variants.has(key):return {}
	var event: Dictionary=decode_home_content(chapter_five_node_bank.events[chapter_five_node_bank.variants[key]],chapter_five_node_bank)
	apply_employment_bridge(event)
	return event

func apply_employment_bridge(event: Dictionary) -> void:
	if event.get("nodeId")!="employ":return
	if employment_bridge_bank.is_empty():employment_bridge_bank=JSON.parse_string(FileAccess.get_file_as_string("res://data/employment_bridge.json"))
	var text: String=employment_bridge_bank.default
	for key in ["burialExperienced","burialAccepted","burialOfferHeard","burialLeadD10"]:
		if state.memory.get(key) is bool and state.memory.get(key)==true:text=employment_bridge_bank.by_flag[key];break
	for choice in event.choices:
		var old: String=employment_bridge_bank.default
		if choice.diaries.default.ends_with(old):choice.diaries.default=choice.diaries.default.trim_suffix(old)+text

func _chapter4_parent_2_ordinary_pre_photo_effect_supported(effect: Dictionary) -> bool:
	if effect.get("type")=="flag_set" and effect.get("flag")=="motherCareNoticeDay" and effect.get("value")==25:return true
	if effect.get("type")=="flag_set" and effect.get("flag")=="employment_offer_pending" and effect.get("value") is bool:return true
	return _chapter4_parent_0_ordinary_pre_photo_effect_supported(effect)


func _chapter4_parent_3_apply_chapter_maintenance(focus: Dictionary) -> void:
	var current: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get("home")))
	if current.is_empty() or state.wood<=0:return
	var low: bool=current.id.ends_with(".maintenance");var fresh: bool=current.has("neighbourhood") and current.neighbourhood.get("stage")==1 and not js_truthy(current.neighbourhood.get("prior"))
	if not low and not (state.shelter<21 and fresh):return
	var raw:=make_pre_photo_condition_home(focus)
	if raw.get("conditionKind")!="maintenance":return
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].get("outside",false));var adults: Array=home.filter(func(person):return person!="罗瑾");var actor: String=adults[0] if not adults.is_empty() else "罗瑾"
	var event: Dictionary=raw.duplicate(true);event.later=true;event.historyClass="情境演绎；白天家庭维护为游戏安排，不是历史日期事实";event.id="later.D"+str(int(state.day)+1)+".home."+raw.id;event.target="home";event.actor=actor;event.participants=home.duplicate();event.homeParticipants=home.duplicate()
	if not low:focus.dayMaintenanceDisplaced={"id":current.id,"title":current.title,"reason":"shelter_below_21_with_wood","freshNeighbour":true}
	focus.laterEvents[event.id]=event;focus.plan.eventIds.home=event.id


func _chapter4_parent_3_bind_day_eleven_twelve(focus: Dictionary) -> bool:
	if int(state.day) not in range(10,17) or focus.plan.get("key") in ["pigeonPickup","expeditionSearch"]:return false
	for key in ["neighbourParcelR2b","neighbourMessagesWebR5"]:
		if js_truthy(state.memory.get(key)):return false
	focus.laterEvents={};focus.plan.eventIds={};focus.plan.photoMidContract="photo-mid-v1"
	for target in focus.plan.targets:
		var event: Dictionary=make_chapter_home_base(focus) if target=="home" else make_pre_photo_outdoor_event(focus,target)
		if event.is_empty():return false
		focus.laterEvents[event.id]=event;focus.plan.eventIds[target]=event.id
		if target=="home" and event.get("conditionKind")=="recovery":
			var offer:=pre_photo_recovery_offer(focus)
			if offer.is_empty():return false
			var prior_care:=make_pre_photo_care_event(focus,true)
			if prior_care.is_empty():return false
			focus.laterEvents[prior_care.id]=prior_care
			focus.plan.rows[offer.actor].label+="；邻棚有人带来物品询问换粮"
			focus.plan.recoveryOffer={"kind":offer.kind,"item":offer.item,"cost":offer.cost,"day":offer.day}
	if not bind_chapter_rope(focus):return false
	apply_chapter_maintenance(focus)
	var base_home: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get("home")))
	focus.homeAdmissionAudit=home_reception_status(focus);focus.homeAdmissionAudit.eventId=base_home.get("id");focus.homeAdmissionAudit.actor=base_home.get("actor")
	focus.webR3NeighbourRevision="WebR3-neighbour-prose-v1"
	if base_home.has("neighbourhood"):
		var decorated:=make_rope_event(focus,{"allowed":true,"actor":base_home.actor,"home":focus.homeAdmissionAudit.home,"resting":focus.homeAdmissionAudit.resting})
		if decorated.is_empty():return false
		base_home.clear()
		for key in decorated:base_home[key]=decorated[key]
	apply_rope_memory_echo(focus,base_home)
	var message_admission:=message_thread_admission(focus)
	focus.messageAdmissionAudit={"revision":"WebR5-messages-v1","allowed":message_admission.allowed,"reason":message_admission.reason,"stage":message_admission.get("stage") if js_truthy(message_admission.get("stage")) else null,"actor":message_admission.get("actor") if js_truthy(message_admission.get("actor")) else null}
	if message_admission.allowed:return false
	var same_day:=custody_handoff_admission(focus)
	focus.custodyAdmissionAudit={"revision":CUSTODY_HANDOFF_REV,"allowed":same_day.allowed,"reason":same_day.reason,"actor":same_day.get("actor") if js_truthy(same_day.get("actor")) else null,"kind":same_day.get("kind") if js_truthy(same_day.get("kind")) else null}
	if same_day.allowed:
		var event:=make_custody_handoff_event(focus,same_day)
		if event.is_empty():return false
		var old: Dictionary=focus.laterEvents[focus.plan.eventIds.home];focus.custodyDisplaced={"id":old.id,"title":old.title};focus.laterEvents[event.id]=event;focus.plan.eventIds.home=event.id
	focus.custodyNightRevision=CUSTODY_NIGHT_REV;var overnight:=custody_night_admission(focus)
	focus.custodyNightAdmission={"revision":CUSTODY_NIGHT_REV,"allowed":overnight.allowed,"reason":overnight.reason,"actor":overnight.get("actor") if js_truthy(overnight.get("actor")) else null,"kind":overnight.get("kind") if js_truthy(overnight.get("kind")) else null}
	if overnight.allowed:
		var event:=make_custody_night_event(focus,overnight)
		if event.is_empty():return false
		var old: Dictionary=focus.laterEvents[focus.plan.eventIds.home];focus.custodyNightDisplaced={"id":old.id,"title":old.title};focus.laterEvents[event.id]=event;focus.plan.eventIds.home=event.id
	if focus.plan.eventIds.has("home"):connect_pre_photo_qian(focus,focus.laterEvents[focus.plan.eventIds.home]);apply_rope_editorial(focus,focus.laterEvents[focus.plan.eventIds.home])
	return true


func _chapter4_parent_3_ensure_day_eleven_twelve_focus() -> Dictionary:
	if state.ended or int(state.day) not in range(10,17) or not present("罗瑾"):return {}
	if state.focus.get("day")==state.day and state.focus.get("plan")!=null:return state.focus
	var backup:=state.duplicate(true);var template=JSON.parse_string(FileAccess.get_file_as_string("res://data/native_base_state_template.json"))
	state.focus=template.focus.duplicate(true);var focus: Dictionary=state.focus;focus.day=state.day;focus.grandfatherRecoveryRevision="R4c";focus.characterRevision="R4a";focus.uncleRevision="R4b";focus.neighbourhoodRevision="R2b";focus.integrationReadingRevision="FINAL-INTEGRATION"
	focus.plan=make_pre_photo_plan()
	if focus.plan.is_empty():state=backup;return {}
	focus.knowledge={"player":[],"luo":[]};focus.resultPackets=[]
	if not bind_day_eleven_twelve(focus):state=backup;return {}
	focus.workPackets={}
	for row in focus.plan.rows.values():
		if not row.get("inactive",false) and not row.base.is_empty():
			var effects: Array=[]
			for resource in row.base:effects.append({"type":"shelter_delta","amount":row.base[resource]} if resource=="shelter" else {"type":"resource_delta","resource":str(resource),"amount":row.base[resource]})
			focus.workPackets[row.name]=queue_focus_packet(effects,"work:"+row.name,"on_return",row.name).id
	var snapshots=JSON.parse_string(FileAccess.get_file_as_string("res://data/later_public_family_snapshots.json"))
	if snapshots.has(str(int(state.day))):focus.r4v3PublicFamilyText=snapshots[str(int(state.day))].duplicate(true)
	return focus


func _chapter4_parent_3_make_chapter_home_base(focus: Dictionary) -> Dictionary:
	if state.day<10 or state.day>16 or "home" not in focus.plan.targets or js_truthy(focus.plan.get("nodeId")):return {}
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].get("outside",false))
	if home.is_empty():return {}
	if home.any(func(person):return not focus_fit(person)):return make_pre_photo_care_event(focus)
	var adults: Array=home.filter(func(person):return person!="罗瑾");var speaker: String=adults[0] if not adults.is_empty() else "罗瑾"
	var raw: Dictionary={};var event: Dictionary={};var suffix: String=""
	if focus.plan.primary=="home":
		if later_scene_shells.is_empty():later_scene_shells=JSON.parse_string(FileAccess.get_file_as_string("res://data/later_scene_shells.json"))
		var key: String=focus.plan.key
		if key in ["apprentice","oldphoto","materials","register","inquiry"]:key="papers"
		if key=="burial":key="returner"
		if key=="care" and not home.any(func(person):return state.people[person].health<9):key="papers"
		if key=="shelter" and state.shelter>=50:key="papers"
		event=later_scene_shells.get(key,later_scene_shells.papers).duplicate(true);suffix=event.id
	else:
		raw=make_pre_photo_condition_home(focus)
		if raw.is_empty():return {}
		event=raw.duplicate(true);suffix=raw.id
	var recipients: Array=["母亲","安仁叔叔","外祖父"].filter(func(person):return person in home and understands(person))
	event.id="later.D"+str(int(state.day)+1)+".home."+suffix;event.target="home";event.later=true;event.actor=speaker;event.participants=[speaker];event.homeParticipants=[speaker];event.recipient=null if recipients.is_empty() else recipients[0];event.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":state.photo.get("evidence",0),"photoPrints":state.photo.get("prints",0)};event.historyClass="F：普通难民家庭情境演绎；登记为12月底阶段背景，不指认罗家当日史实";event.chapter4Revision="I3e-4b";event.chapter="I2b-4"
	if adults.is_empty():
		if raw.is_empty():raw=make_pre_photo_condition_home(focus)
		if raw.is_empty():return {}
		var saved_id: String=event.id
		for key in raw:event[key]=raw[key].duplicate(true) if raw[key] is Dictionary or raw[key] is Array else raw[key]
		event.id=saved_id;event.actor=speaker
	else:
		var layer:=pre_photo_authored_home_layer(focus)
		if layer.is_empty():return {}
		for key in layer:event[key]=layer[key]
		event.erase("conditionKind")
		# R24 continuity runs after optional neighbours, not on displaced base scenes.
		event.intro=event.intro.trim_prefix(QIAN_D12_LEAD).trim_prefix(QIAN_D13_LEAD);event.historyClass=event.historyClass.trim_suffix(QIAN_HISTORY_SUFFIX)
		bind_pre_photo_family_followup(focus,event)
	return event


func _chapter4_parent_3_make_pre_photo_care_event(focus: Dictionary,base_only: bool=false) -> Dictionary:
	if state.day<10 or state.day>16 or "home" not in focus.plan.targets or js_truthy(focus.plan.get("nodeId")):return {}
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].get("outside",false));var sick: Array=home.filter(func(person):return not focus_fit(person))
	if sick.is_empty():return {}
	sick.sort_custom(func(a,b):return PEOPLE.find(a)<PEOPLE.find(b) if state.people[a].health==state.people[b].health else state.people[a].health<state.people[b].health)
	var patient: String=sick[0];var others: Array=home.filter(func(person):return person!="罗瑾" and understands(person));var speakers: Array=home.filter(func(person):return understands(person));var actor: String=others[0] if not others.is_empty() else (speakers[0] if not speakers.is_empty() else home[0])
	var event: Dictionary={};var suffix: String="fallback.d"+str(int(state.day)+1)+".home.care"
	if focus.plan.primary=="home":
		if later_scene_shells.is_empty():later_scene_shells=JSON.parse_string(FileAccess.get_file_as_string("res://data/later_scene_shells.json"))
		var key: String=focus.plan.key
		if key in ["apprentice","oldphoto","materials","register","inquiry"]:key="papers"
		if key=="burial":key="returner"
		if key=="shelter" and state.shelter>=50:key="papers"
		event=later_scene_shells.get(key,later_scene_shells.papers).duplicate(true);suffix=event.id
	var recipients: Array=["母亲","安仁叔叔","外祖父"].filter(func(person):return person in home and understands(person))
	event.id="later.D"+str(int(state.day)+1)+".home."+suffix;event.title="";event.intro="";event.later=true;event.historyClass="F：普通难民家庭情境演绎；登记为12月底阶段背景，不指认罗家当日史实";event.target="home";event.actor=actor;event.participants=home.duplicate();event.homeParticipants=home.duplicate();event.recipient=null if recipients.is_empty() else recipients[0];event.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":state.photo.get("evidence",0),"photoPrints":state.photo.get("prints",0)};event.chapter4Revision="I3e-4b";event.chapter="I2b-4";event.conditionKind="care"
	var repairers: Array=home.filter(func(person):return person!=patient and can_work_later(person))
	var raw_care:=pre_photo_raw_care_content(home,patient,repairers)
	if raw_care.is_empty():return {}
	for field in ["title","intro","choices"]:event[field]=raw_care[field]
	for choice in event.choices:choice.later=true
	if "罗瑾" in home and not understands("罗瑾"):
		for choice in event.choices:choice.diaries={"default":"白天那一阵，我记得断断续续。有时听见近处的声响，等想听清，又只剩下自己难受的地方。现在能够停下来写几个字，也拼不回别人已经做过的每件事。我先把这点记忆留下，等有力气了再问。"}
	if base_only:return event

	var offer:=pre_photo_recovery_offer(focus)
	if not offer.is_empty():
		event.id+=".exchange";event.actor=offer.actor;event.conditionKind="recovery"
		var medicine: bool=offer.item!=null;var name: String=TOOL_NAMES[offer.item] if medicine else "木料";var goods: String=name+"一份" if medicine else "能用的短木三份"
		var exchange: Dictionary={"id":"exchange","label":"用米粮"+str(int(offer.cost))+"份换"+goods,"hint":"米粮－"+str(int(offer.cost))+"；"+(name+"＋1，晚间另行用药，不当场治愈" if medicine else "木料＋3，不自动生火或修棚")+"。","requiresResources":{"rice":offer.cost},"immediateEffects":[{"type":"resource_delta","resource":"rice","amount":-offer.cost},{"type":"item_gain","item":offer.item} if medicine else {"type":"resource_delta","resource":"wood","amount":3}],"closures":{"default":""},"diaries":{"default":""}}
		event.choices=[exchange,event.choices[0],event.choices[1]]
	if not home_care_reader.decorate(self,focus,event):return {}
	return event


func _chapter4_parent_3_make_pre_photo_condition_home(focus: Dictionary) -> Dictionary:
	if state.day<10 or state.day>16:return {}
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].get("outside",false))
	if home.is_empty() or home.any(func(person):return not focus_fit(person)):return {}
	var mask:=0
	for person in home:mask|=1<<PEOPLE.find(person)
	var kind: String="weather" if current_weather().get("severe",false) else ("absence" if household_presence_mask()!=15 else ("maintenance" if state.shelter<41 and state.wood>0 else "home"))
	var prior: Array=[];var index:=0;var stock:=0;var gain:=0
	if kind in ["weather","maintenance"]:
		prior=state.history.filter(func(row):return row.get("day",state.day)<state.day and _object(row.get("readingVariant")).get("revision")=="R24-experience-polish-v1" and row.readingVariant.kind==kind)
		var last: Dictionary={}
		for row in prior:last[int(row.readingVariant.index)]=row.day
		var offset: int=RNG.hash_seed(state.seed+"|R24-experience-polish-v1|"+kind)%3;index=-1
		for step in range(3):
			var candidate: int=(offset+step)%3
			if not last.has(candidate):index=candidate;break
		if index<0:
			var candidates: Array=[0,1,2];candidates.sort_custom(func(a,b):return a<b if last[a]==last[b] else last[a]<last[b]);index=candidates[0]
		if kind=="weather":stock=(1 if state.wood>=1 else 0)+(2 if state.shelter>=50 else 0)+(4 if state.shelterItems.oilcloth else 0)
		else:
			var speakers: Array=home.filter(func(person):return person!="罗瑾");gain=formal_repair_gain(int(state.day),speakers[0] if not speakers.is_empty() else "罗瑾")
	else:
		prior=state.history.filter(func(row):return row.get("day",state.day)<state.day and _object(row.get("readingVariant")).get("group")=="shelter")
		index=(RNG.hash_seed(state.seed+":condition-story:shelter")+prior.size())%3
	if pre_photo_condition_home_prose.is_empty():pre_photo_condition_home_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/pre_photo_condition_home.json"))
	var key:=JSON.stringify([int(state.day),mask,kind,index,stock,gain])
	if not pre_photo_condition_home_prose.variants.has(key):return {}
	var event: Dictionary=decode_home_content(pre_photo_condition_home_prose.events[pre_photo_condition_home_prose.variants[key]],pre_photo_condition_home_prose)
	event=_replace_content_token(event,"§WEATHER_NAME§",current_weather().name)
	if event.has("readingVariant"):event.readingVariant.previous=null if prior.is_empty() else prior.back().day
	return event


func _chapter4_parent_3_make_pre_photo_outdoor_event(focus: Dictionary,target: String) -> Dictionary:
	if state.day<10 or state.day>16 or target not in PEOPLE or target not in focus.plan.targets or js_truthy(focus.plan.get("nodeId")) or state.photo.get("employed",false):return {}
	var row: Dictionary=_object(focus.plan.rows.get(target));var type: String=row.get("type","")
	if not row.get("outside",false) or row.get("inactive",false) or not present(target):return {}
	if not ((target=="罗瑾" and type in ["water","burial"]) or (target=="外祖父" and type=="wood") or (target=="母亲" and type in ["relief","registration"]) or (target=="安仁叔叔" and type=="committee")):return {}
	var prior: Array=state.history.filter(func(history):return history.get("day",state.day)<state.day and _object(history.get("readingVariant")).get("group")=="water") if type=="water" else []
	var index: int=(RNG.hash_seed(state.seed+":condition-story:water")+prior.size())%3 if type=="water" else 0
	var previous: String="none" if prior.is_empty() else "many"
	if prior.size()==1:previous=prior[0].get("choice","") if prior[0].get("choice") in ["help","pole_help"] else "carry_home"
	var tool: String=state.memory.get("burialTool","none") if type=="burial" else "none"
	if tool not in ["shovel","rope"] or not tool_available(tool):tool="none"
	if pre_photo_outdoor_prose.is_empty():pre_photo_outdoor_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/pre_photo_outdoor_prose.json"))
	var key:=JSON.stringify([int(state.day),target,type,index,state.water>=2 if type=="water" else false,tool_available("axe") if type=="wood" else false,tool,previous,state.day==11 and type=="water" and focus.plan.primary==target])
	if not pre_photo_outdoor_prose.variants.has(key):return {}
	var event: Dictionary=decode_home_content(pre_photo_outdoor_prose.events[pre_photo_outdoor_prose.variants[key]],pre_photo_outdoor_prose)
	var home: Array=PEOPLE.filter(func(person):return present(person) and not _object(focus.plan.rows.get(person)).get("outside",false))
	var recipients: Array=["母亲","安仁叔叔","外祖父"].filter(func(person):return person in home and understands(person))
	event.recipient=null if recipients.is_empty() else recipients[0]
	event.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":state.photo.get("evidence",0),"photoPrints":state.photo.get("prints",0)}
	if type=="water" and event.has("readingVariant"):
		event.readingVariant.previous=null if prior.is_empty() else prior.back().day
		event.readingVariant.narratorHere="罗瑾" in home
	return event


func _chapter4_parent_3_pre_photo_raw_care_content(home: Array,patient: String,repairers: Array) -> Dictionary:
	var mask:=0
	for person in home:mask|=1<<PEOPLE.find(person)
	var worker: Variant=null;var gain:=0
	if state.shelter<41 and state.wood>0 and not repairers.is_empty():worker="外祖父" if "外祖父" in repairers else repairers[0];gain=formal_repair_gain(int(state.day),worker)
	if pre_photo_care_raw_prose.is_empty():pre_photo_care_raw_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/pre_photo_care_raw_prose.json"))
	var key:=JSON.stringify([int(state.day),mask,patient,worker,state.water>0,gain])
	if not pre_photo_care_raw_prose.variants.has(key):return {}
	var result: Dictionary=decode_home_content(pre_photo_care_raw_prose.events[pre_photo_care_raw_prose.variants[key]],pre_photo_care_raw_prose)
	var description:=ailment_text(patient)
	return _replace_content_token(result,"§AILMENT_DESCRIPTION§",description if not description.is_empty() else "身上很不舒服")


func _chapter4_parent_3_pre_photo_recovery_offer(focus: Dictionary) -> Dictionary:
	if state.balanceVersion!="I2f" or state.day<10 or state.day>16:return {}
	var block: int=int(floor(float(state.day-10)/5));var offset: int=RNG.hash_seed(state.seed+":recovery-offer:"+str(block))%5
	if (int(state.day)-10)%5!=offset:return {}
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].get("outside",false));var actors: Array=home.filter(func(person):return can_work_later(person))
	if actors.is_empty():actors=home.filter(func(person):return understands(person))
	if actors.is_empty():return {}
	var sick: Array=home.filter(func(person):return state.ailments.get(person,{}).values().any(func(value):return value>=2))
	sick.sort_custom(func(a,b):return PEOPLE.find(a)<PEOPLE.find(b) if state.people[a].health==state.people[b].health else state.people[a].health<state.people[b].health)
	var item: Variant=null
	for person in sick:
		var types: Array=["cold","wound","nutrition"]
		types.sort_custom(func(a,b):return ["cold","wound","nutrition"].find(a)<["cold","wound","nutrition"].find(b) if state.ailments[person][a]==state.ailments[person][b] else state.ailments[person][a]>state.ailments[person][b])
		var candidate: String={"cold":"herbs","wound":"bandage","nutrition":"medkit"}[types[0]]
		if not tool_available(candidate) and not tool_available("medkit"):item=candidate;break
	if item==null and not (state.wood<=2 and not can_work_later("外祖父")):return {}
	return {"actor":actors[0],"kind":"medicine" if item!=null else "wood","item":item,"cost":2 if item!=null else 1,"day":state.day+1}

var chapter_five_care_reader=preload("res://scripts/chapter_five_care_prose.gd").new()

var chapter_five_care_raw_prose: Dictionary={}

var chapter_five_condition_home_prose: Dictionary={}

var chapter_five_outdoor_prose: Dictionary={}

var chapter_five_home_prose: Dictionary={}

var chapter_five_bound_nodes: Dictionary={}

var chapter_five_d22_patch: Dictionary={}

var chapter_five_reading_revisions: Dictionary={}

var chapter_five_neighbour_day: Dictionary={}

var message_thread_prose: Dictionary={}

func make_bound_chapter_five_node(focus: Dictionary) -> Dictionary:
	if chapter_five_bound_nodes.is_empty():chapter_five_bound_nodes=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_five_bound_nodes.json"))
	var home:=0;var adults:=0
	for i in range(PEOPLE.size()):
		if present(PEOPLE[i]) and not focus.plan.rows[PEOPLE[i]].outside:home|=1<<i
		if i>0 and understands(PEOPLE[i]):adults|=1<<(i-1)
	var key: String=JSON.stringify([focus.plan.nodeId,int(state.day),home,adults,js_truthy(state.memory.get("visitorNameRecorded")),js_truthy(state.memory.get("employment_offer_pending"))])
	if not chapter_five_bound_nodes.variants.has(key):return {}
	var event: Dictionary=decode_home_content(chapter_five_bound_nodes.events[chapter_five_bound_nodes.variants[key]],chapter_five_bound_nodes)
	event.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":state.photo.evidence,"photoPrints":state.photo.prints}
	apply_employment_bridge(event)
	return event

func apply_middle_reading_context(focus: Dictionary) -> void:
	if state.day<38:_chapter7_parent_19_apply_middle_reading_context(focus);return
	if focus.get("middleReadingRevision")!="I3e-4c1" or focus.get("middleReadingBound",false):return
	for event in focus.laterEvents.values():
		if event.get("nodeId")=="names" and js_truthy(state.memory.get("visitorNameRecorded")):
			event.intro=event.intro.replace("早些时候有个女人沿棚边问人，罗瑾听过，留了几笔。","今天另有一位女人沿棚边问人，找的不是先前记下的那个人。罗瑾听她讲过，另留了几笔。")
			for choice in event.choices:choice.diaries.default=choice.diaries.default.replace("今天重写一个名字","今天整理另一位来人留下的姓名").replace("我今天没有将那页重抄","今天新记的那页，我没有再重抄")
		if event.get("nodeId")=="employ":event.intro=event.intro.replace("家里没有一个清醒的大人坐在旁边替他问。","这会儿没有能在旁边替他问的大人。")
		for choice in event.choices:
			if focus.day>=17 and focus.day<=23 and choice.get("diaries",{}).get("default")!=null:choice.diaries.default=choice.diaries.default.replace("她说同行的人提到日本兵以后就没找回来，可她也没看见究竟去了哪里。","妇人讲起同行的人没有回来时，提到了日本兵，却没看见那人究竟去了哪里。")
	focus.middleReadingBound=true

func chapter_json_equal(a: Variant,b: Variant) -> bool:
	if typeof(a) in [TYPE_INT,TYPE_FLOAT] and typeof(b) in [TYPE_INT,TYPE_FLOAT]:return float(a)==float(b)
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size():return false
		for key in a:
			if not b.has(key) or not chapter_json_equal(a[key],b[key]):return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for i in range(a.size()):
			if not chapter_json_equal(a[i],b[i]):return false
		return true
	return typeof(a)==typeof(b) and a==b

func apply_d22_local_text(focus: Dictionary) -> void:
	if state.saveVersion!=24 or state.ended or state.day!=21 or focus.day!=state.day or focus.plan.day!=state.day or focus.get("choiceIndex")!=null or focus.get("settled",false) or focus.plan.rows["罗瑾"].outside:return
	if chapter_five_d22_patch.is_empty():chapter_five_d22_patch=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_five_d22_patch.json"))
	var event: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get("home")))
	for key in ["D22_EVIDENCE","D22_MOTHER"]:
		var source: Dictionary=chapter_five_d22_patch.sources[key]
		if focus.plan.eventIds.get(source.target)!=source.id or not source.participants.all(func(person):return present(person)) or not chapter_json_equal(event,source):continue
		var draft: Dictionary=chapter_five_d22_patch.draft
		if event.intro.count(draft.old)==1:event.intro=event.intro.replace(draft.old,draft.new)
		return

func apply_chapter_five_reading_revisions(focus: Dictionary) -> void:
	if focus.day!=state.day:return
	if chapter_five_reading_revisions.is_empty():chapter_five_reading_revisions=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_five_reading_revisions.json"))
	for revision in ["r4v9-work-diary-v1","r4v9-return-repair-prose-v1"]:
		var entries: Array=[]
		for template in chapter_five_reading_revisions[revision].workParagraphs:
			var row: Dictionary=_object(focus.plan.rows.get(template.actor));var event: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get(template.actor)))
			if focus.day!=template.day-1 or row.get("type")!=template.kind or not row.get("outside",false) or row.get("inactive",false) or not present(template.actor) or event.get("chapter")!=template.chapter or event.get("target")!=template.actor or event.get("actor")!=template.actor:continue
			if revision=="r4v9-work-diary-v1":entries.append({"actor":template.actor,"kind":template.kind,"chapter":template.chapter,"source":template.source,"replacement":template.replacement})
			else:
				if event.get("id")!=template.eventId or event.get("conditionKind")!=template.kind or ["nodeId","uncleCrisis","motherCrisis","expeditionSearch","r4v7P1"].any(func(key):return js_truthy(event.get(key))):continue
				entries.append(template.duplicate(true))
		var key: String="r4v9WorkDiaryText" if revision=="r4v9-work-diary-v1" else "r4v9ReturnRepairText"
		if not entries.is_empty() and not focus.has(key):focus[key]={"revision":revision,"day":focus.day+1,"entries":entries}

func bind_chapter_five_neighbour_day(focus: Dictionary) -> void:
	if focus.day!=23 or "home" not in focus.plan.targets:return
	var old: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get("home")))
	if old.is_empty() or ["nodeId","neighbourhood","neighbourParcel","recovery","motherCare","uncleBoundary"].any(func(key):return js_truthy(old.get(key))) or js_truthy(focus.plan.get("recoveryOffer")):return
	var admission:=home_neighbour_admission(focus,"day")
	if not admission.allowed:return
	var mask:=0
	for person in admission.home:mask|=1<<PEOPLE.find(person)
	if chapter_five_neighbour_day.is_empty():chapter_five_neighbour_day=JSON.parse_string(FileAccess.get_file_as_string("res://data/neighbour_day.json"))
	var key: String=JSON.stringify([mask,admission.actor])
	if not chapter_five_neighbour_day.variants.has(key):return
	var event: Dictionary=chapter_five_neighbour_day.variants[key].duplicate(true)
	focus.laterEvents[event.id]=event;focus.plan.eventIds.home=event.id

func make_message_thread_event(focus: Dictionary,admission: Dictionary) -> Dictionary:
	if not admission.get("allowed",false) or admission.get("stage",0)<1 or admission.stage>6:return {}
	var record: Dictionary=_object(state.memory.get("neighbourMessagesWebR5"));var visits: Array=record.get("visits",[])
	var met: bool=visits.any(func(visit):return admission.actor in visit.get("recipients",[]))
	var contact: String="new" if record.is_empty() else ("met" if met else "told")
	var prior: Variant=admission.get("prior");var kind: String="none" if prior==null else ("returned" if prior.returned else "carried")
	var here: bool="罗瑾" in admission.home and understands("罗瑾")
	var pending: bool=visits.any(func(visit):return visit.get("correction")=="pending") and not visits.any(func(visit):return visit.get("correction")=="delivered")
	if message_thread_prose.is_empty():message_thread_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/message_thread_prose.json"))
	var key: String=JSON.stringify([int(admission.stage),admission.actor,here,contact,kind,pending])
	if not message_thread_prose.variants.has(key):return {}
	var event: Dictionary=decode_home_content(message_thread_prose.events[message_thread_prose.variants[key]],message_thread_prose)
	event.id="neighbour.message.WebR5.D"+str(int(focus.day)+1)+".C"+str(int(admission.stage))
	event.messageThread.day=focus.day+1;event.messageThread.prior=prior.duplicate(true) if prior is Dictionary else null;event.messageThread.previous=visits.duplicate(true);event.messageThread.resting=admission.resting.duplicate();event.messageThread.late=admission.late
	if not admission.resting.is_empty():event.intro+="\n\n"+"、".join(admission.resting)+"仍按原来的安排歇着，"+admission.actor+"没有叫他们起身接待。"
	qualify_message_custody(event)
	return event

func qualify_message_custody_text(text: String) -> String:
	var pairs: Array=[
		["包袱当日就由他本人领走了，这回没有物件等着罗家再交一次。","早先当日暂放的那一回包袱当日就由本人领走；他说的是旧事，不是在交代这次新委托的去向。"],
		["那回包袱一直由他自己带着，这里没有欠下一笔寄存。","那回包袱一直由他自己带着，旧回忆不表示今天另一笔委托的状态。"],
		["免得旁人以为东西还寄在罗家","免得旁人把早先已经交清的那一回误说成还没交"],
		["男人听过，没有留下物件","男人听过，这次谈话没有另外留下物件"],
		["也没有留下需要这里兑现的物件或口信","也没有在这次谈话里另留物件或口信"],
		["他这回自己继续去问，没有把物件或口信托下来","他这次说完消息仍自己去问，没有在本次谈话中另托物件或口信"]]
	for pair in pairs:
		var index: int=text.find(pair[0])
		if index>=0:text=text.left(index)+pair[1]+text.substr(index+pair[0].length())
	return text

func qualify_message_custody(event: Dictionary) -> void:
	if not js_truthy(state.memory.get(CUSTODY_NIGHT_KEY)):return
	event.intro=qualify_message_custody_text(event.intro)
	for choice in event.choices:
		for field in ["closures","diaries"]:
			for key in choice.get(field,{}):choice[field][key]=qualify_message_custody_text(choice[field][key])
		for key in ["here","away","summary"]:
			if js_truthy(choice.get("messageData",{}).get(key)):choice.messageData[key]=qualify_message_custody_text(choice.messageData[key])

func _chapter4_parent_4_resolve_day_eleven_twelve_choice(index: int) -> bool:
	if int(state.day) not in range(10,17):return false
	var event:=current_later_focus_event()
	if event.has("neighbourhood"):return resolve_rope_choice(index)
	return resolve_custody_choice(index) if event.has("custodyHandoff") or event.has("custodyNight") else resolve_ordinary_pre_photo_choice(index)

func resolve_message_thread_choice(index: int) -> bool:
	var focus: Dictionary=state.focus;var event:=current_later_focus_event();var record: Dictionary=_object(state.memory.get("neighbourMessagesWebR5"))
	if state.ended or state.phase!="focusEvent" or focus.get("choiceIndex")!=null or index<0 or index>=event.get("choices",[]).size() or not event.has("messageThread"):return false
	var view: Dictionary=event.messageThread;var choice: Dictionary=event.choices[index]
	if view.revision!=MESSAGE_THREAD_REV or not record.is_empty() and record.get("revision")!=MESSAGE_THREAD_REV:state.error="这条消息使用的原合同不可用，未替换为新版本。";return false
	if record.get("stage",0)>=view.stage or not can_work_later(event.actor) or not later_event_eligible(event,focus.plan) or not home_reception_status(focus).urgent.is_empty():state.error="这场交谈的前情或接待条件已经改变，尚未提交。";return false
	if not commit_rope_choice_core(index):return false
	var fact_id: String=state.seed+"|"+event.id
	var rec: Dictionary=record.duplicate(true) if not record.is_empty() else {"revision":MESSAGE_THREAD_REV,"contactId":"d5-bundle-searcher","stage":0,"visits":[]}
	var recipients: Array=[event.actor]
	if view.here and understands("罗瑾"):recipients.append("罗瑾")
	var visit: Dictionary={"revision":MESSAGE_THREAD_REV,"event":event.id,"choice":choice.id,"result":choice.messageData.result,"factId":fact_id,"day":state.day+1,"stage":view.stage,"actor":event.actor,"here":view.here,"returned":false,"publicSummary":choice.messageData.summary,"correction":choice.messageData.get("correction") if js_truthy(choice.messageData.get("correction")) else null,"claimKind":view.get("claimKind") if js_truthy(view.get("claimKind")) else null,"recipients":[],"returnRecipients":[],"privateScope":choice.messageData.get("privateScope") if js_truthy(choice.messageData.get("privateScope")) else null}
	visit.recipients=deliver_fact({"factId":fact_id,"recipients":recipients,"source":event.id+":selected:"+choice.id,"scope":"public-summary","mode":"witnessed"})
	if js_truthy(visit.privateScope):deliver_fact({"factId":fact_id,"recipients":recipients,"source":event.id+":original-speaker","scope":visit.privateScope,"mode":"witnessed"})
	if view.stage==5:visit.propagation={"source":"owner-confirmed-D5-return" if view.get("claimKind")=="parcel-reunion" else "eyewitness-qualified-description","permission":"owner/current-speaker stated limited scope in this selected scene","speaker":"message-neighbour-speaker","recipient":"message-neighbour-listener","claim":"reunion_claim_not_fact","heardDay":state.day+1,"corrected":visit.correction=="delivered"}
	rec.visits.append(visit);rec.stage=view.stage;rec.lastDay=state.day+1;rec.closed=view.stage==6;state.memory.neighbourMessagesWebR5=rec
	focus.messageReceipt={"contract":"neighbourMessagesWebR5","revision":MESSAGE_THREAD_REV,"event":event.id,"choice":choice.id,"status":"result_locked","result":visit.result,"factId":fact_id,"stage":view.stage}
	return true

var chapter_five_diary_bank: Dictionary={}

func diary_bank_text(group: String,key: Array) -> String:
	var encoded: String=JSON.stringify(key)
	if not chapter_five_diary_bank[group].has(encoded):return ""
	return chapter_five_diary_bank.strings[int(chapter_five_diary_bank[group][encoded])]

func finish_chapter_five_diary(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	if not focus.get("diaryAllowed",false):focus.chapterDiary=[];return true
	if focus.day<17 or focus.day>23:return false
	if chapter_five_diary_bank.is_empty():chapter_five_diary_bank=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_five_diary_prose.json"))
	var date: int=int(focus.day)+1;var here: Array=PEOPLE.filter(func(person):return present(person));var awake: Array=here.filter(func(person):return person!="罗瑾" and understands(person))
	var presence:=0;var awake_mask:=1
	for i in range(PEOPLE.size()):
		if PEOPLE[i] in here:presence|=1<<i
		if i>0 and PEOPLE[i] in awake:awake_mask|=1<<i
	var photo: bool=focus.plan.rows["罗瑾"].outside and focus.plan.rows["罗瑾"].type=="photo"
	var family: String=diary_bank_text("families",[int(focus.day),presence,awake_mask,event.id.ends_with(".newyear"),photo,state.photo.employed])
	if family.is_empty():return false
	var home_before: Array=here.filter(func(person):return not focus.plan.rows[person].outside)
	var body: String=choice.get("diaries",{}).get("default","")
	var firsthand: bool=focus.selected=="罗瑾" or focus.selected=="home" and "罗瑾" in home_before
	if not firsthand and not js_truthy(event.get("conditionKind")):
		var who: String="娘" if event.actor=="母亲" else event.actor
		if focus.selected=="home":body=who+"等我回来，才把棚边发生的事说清。"+body.replace("我想她在家里必定不会这样介绍丈夫","我听完便想，她在家里必定不会这样介绍丈夫").replace("我将能听清的留下","我将转述中能说清的留下").replace("她喝水的时候，我原想叫她坐久一些，后来听见她又念下一处要问的地方，便没再说。","家里说她喝过水仍急着走，还念着下一处要问的地方。我听着，原先想问为什么不留她多坐一会儿，也没再问。").replace("我看着她的背影，才觉得","我想着她又独自走了，才觉得")
		elif not ["娘","叔叔","外祖父"].any(func(prefix):return body.begins_with(prefix)):body=who+"回来讲过以后，我才知道今天还有这些事。"+body
	var work: Array=[]
	for row in focus.plan.rows.values():
		if not row.outside or row.get("inactive",false) or not present(row.name) or focus.get("cancelWork")==row.name or focus.selected==row.name:continue
		var packets: Array=focus.resultPackets.filter(func(packet):return packet.id==focus.workPackets.get(row.name))
		if row.type in ["relief","committee","wood","water"] and (packets.is_empty() or packets[0].status!="applied"):continue
		if row.type in ["relief","committee","wood","water","photo"]:work.append(diary_bank_text("work",[int(focus.day),row.type]))
	if js_truthy(focus.get("defaultNodeDiary")):work.append(focus.defaultNodeDiary)
	var ending: String=diary_bank_text("ends",[int(focus.day),state.photo.employed,state.fixedNodeStates.employ.get("resolvedDay")==date,event.id.ends_with(".oldphoto")])
	focus.chapterDiary=([family,body]+work+[chapter_five_diary_bank.news[str(date)],ending]).filter(func(text):return not text.is_empty())
	focus.chapterDiaryContext={"day":date,"chapter":"I2b-5","present":here,"actualWork":focus.plan.rows.values().filter(func(row):return row.outside and not row.get("inactive",false) and present(row.name) and focus.get("cancelWork")!=row.name).map(func(row):return row.name),"heardAtDusk":not chapter_five_diary_bank.news[str(date)].is_empty(),"hearingClass":"F：独立晚间听闻，不来自城市资料层，不执行数值","node":event.get("nodeId") if js_truthy(event.get("nodeId")) else null}
	if focus.get("middleReadingRevision")=="I3e-4c1":
		var closable: bool=date!=18 or event.id=="later.D18.home.visitor" and not js_truthy(event.get("conditionKind"))
		var source_known: bool=date!=21 or event.get("nodeId")=="sources" or focus.plan.get("nodeId")=="sources" and js_truthy(focus.get("defaultNodeDiary"))
		if chapter_five_diary_bank.middleEndings.has(str(date)) and closable and source_known and not (date==24 and event.id.ends_with(".oldphoto")):
			ending=chapter_five_diary_bank.middleEndings[str(date)]
			if date==18 and focus.plan.rows["罗瑾"].outside:ending="等家里将来问人的事讲完，我还想着那块补丁。她来时我不在，不能说自己认得她比过的衣袖；若路上擦身过去，也许便错过了。后来通道里有人侧身挤过，我先看脸，又看了一眼袖口，随后才给人让开。只知道这样一点模样，究竟能认出谁，我仍没有把握。"
			focus.chapterDiary[-1]=ending
		if js_truthy(focus.get("defaultNodeDiary")) and focus.plan.get("nodeId")=="employ":focus.chapterDiary=focus.chapterDiary.map(func(text):return "白天我留在棚里时，"+text if text==focus.defaultNodeDiary else text)
		focus.chapterDiaryContext.readingRevision="I3e-4c1"
	if focus.get("webM2ReadingRevision")=="WebM2-D18D24-v1":
		if event.get("nodeId")=="sources" and choice.id=="safe":focus.chapterDiary[-1]="另折的那一页收起来以后，我仍惦记着听见消息便起身的人。若有人说我等的人回来了，我也很想立刻相信。今天只是没有继续把这句话往下传，已经传出去的那几声，却不是折好一页纸便能收回来。"
		if date==23 and not js_truthy(event.get("nodeId")) and photo:focus.chapterDiary[-1]="写完今天做的活，我又把自己想问师傅的那一步想了一遍。眼前还没有答案，也并不全是害怕；有一点想早些再试。"+("眼前还有能听我说的人，我却没再把明天想做的也讲成今天已经会的。" if not awake.is_empty() else "眼前没有能接话的人，我先把想问的留在自己记得住的地方，没有替谁写一句夸奖。")+"我把这点愿意继续学的心思也留下，不只记哪里难。"
		focus.chapterDiaryContext.webM2ReadingRevision="WebM2-D18D24-v1"
	if _object(event.get("readingVariant")).get("revision")=="WebR2-home-care-prose-v1" and focus.chapterDiary.find(choice.diaries.default)>0 and not focus.get("grandfatherRecoveryAdded",false) and not js_truthy(event.get("nodeId")):focus.chapterDiary[0]=""
	if event.has("messageThread"):focus.messageGenericReflection=focus.chapterDiary[-1]
	if event.has("custodyHandoff"):focus.custodyGenericReflection=focus.chapterDiary[-1]
	apply_chapter_five_returned_work_prose(focus)
	return true

func apply_chapter_five_returned_work_prose(focus: Dictionary) -> void:
	if not understands("罗瑾") or not focus.diaryAllowed:return
	for spec in [["r4v9WorkDiaryText","r4v9-work-diary-v1"],["r4v9ReturnRepairText","r4v9-return-repair-prose-v1"]]:
		var marker: Dictionary=_object(focus.get(spec[0]))
		if marker.get("revision")!=spec[1] or marker.get("day")!=focus.day+1 or focus.day!=state.day:continue
		if chapter_five_reading_revisions.is_empty():chapter_five_reading_revisions=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_five_reading_revisions.json"))
		for template in chapter_five_reading_revisions[spec[1]].workParagraphs:
			var expected: Dictionary=template.duplicate(true) if spec[0]=="r4v9ReturnRepairText" else {"actor":template.actor,"kind":template.kind,"chapter":template.chapter,"source":template.source,"replacement":template.replacement}
			if template.day!=marker.day or not marker.get("entries",[]).any(func(entry):return chapter_json_equal(entry,expected)) or focus.chapterDiaryContext.chapter!=template.chapter or focus.selected==template.actor or focus.get("cancelWork")==template.actor or not understands(template.actor):continue
			var row: Dictionary=focus.plan.rows[template.actor];var id: Variant=focus.workPackets.get(template.actor);var packets: Array=focus.resultPackets.filter(func(packet):return packet.id==id)
			if row.type!=template.kind or not row.outside or row.get("inactive",false) or id==null or packets.size()!=1:continue
			var packet: Dictionary=packets[0]
			if packet.status!="applied" or packet.subjectId!=template.actor or packet.timing!="on_return" or packet.scheduledDay!=focus.day or id not in state.effectLedger.appliedEffectIds:continue
			if spec[0]=="r4v9WorkDiaryText":
				if not packet.effects.any(func(effect):return effect.type=="resource_delta" and effect.resource=="rice" and effect.amount>0):continue
			else:
				var event: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get(template.actor)))
				if focus.get("partialWork")==template.actor or event.get("id")!=template.eventId or event.get("actor")!=template.actor or event.get("target")!=template.actor or event.get("conditionKind")!=template.kind or event.get("chapter")!=template.chapter or ["nodeId","uncleCrisis","motherCrisis","expeditionSearch","r4v7P1"].any(func(key):return js_truthy(event.get(key))):continue
				if packet.sourceEventInstanceId!="D"+str(int(template.day))+":work" or packet.condition!=null or packet.cancelReason!=null or not packet.knowledgeFactIds.is_empty() or not packet.effects.all(func(effect):return effect.type=="resource_delta" and effect.resource in ["wood","water"] and effect.amount>0) or not packet.effects.any(func(effect):return effect.get("resource")==template.resource and effect.get("amount",0)>0):continue
			var indices: Array=[]
			for i in range(2,focus.chapterDiary.size()):
				if focus.chapterDiary[i]==template.source:indices.append(i)
			if indices.size()==1:focus.chapterDiary[indices[0]]=template.replacement

func _chapter4_parent_6_later_event_eligible(event: Dictionary,plan: Dictionary) -> bool:
	return event.get("participants",[]).all(func(person):return present(person)) and event.get("homeParticipants",[]).all(func(person):return not _object(_object(plan.get("rows")).get(person)).get("outside",false)) and (event.get("target")=="home" or _object(_object(plan.get("rows")).get(event.get("target"))).get("outside",false))

func _chapter4_parent_6_settle_day_eleven_twelve_return() -> bool:
	if int(state.day) not in range(10,17):return false
	var event:=current_later_focus_event();var was_settled: bool=state.focus.get("settled",false);var result: bool=false
	if event.has("neighbourhood"):result=settle_rope_return()
	elif event.has("custodyHandoff") or event.has("custodyNight"):result=settle_custody_return()
	else:result=settle_ordinary_pre_photo_return()
	if not result or was_settled:return result
	if state.focus.get("custodyNightRevision")==CUSTODY_NIGHT_REV and js_truthy(state.memory.get(CUSTODY_NIGHT_KEY)):
		if not custody_night_record_valid(state.memory[CUSTODY_NIGHT_KEY]):state.focus.custodyNightCompatibility="这笔跨夜托存记录不完整，交接已隔离；旧物权未猜改。"
		else:settle_custody_owner_arrival(event)
	return true


func _chapter4_parent_6_settle_ordinary_pre_photo_return() -> bool:
	# D11-D17 selected custody only. Later photos, crises, excursions and owner arrivals
	# on unrelated scenes remain gated until their complete contracts are implemented.
	if state.ended or state.day<10 or state.day>16:return false
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if event.is_empty() or event.has("custodyHandoff") or event.has("custodyNight"):return false
	if focus.get("settled",false):state.phase="focusReturn";return true
	if state.phase!="focusResult" or focus.get("choiceIndex")==null or int(focus.choiceIndex)<0 or int(focus.choiceIndex)>=event.choices.size():return false
	if js_truthy(focus.plan.get("nodeId")) or focus.plan.get("key") in ["expeditionSearch","pigeonPickup"]:return false
	if focus.plan.rows.values().any(func(row):return row.get("type") not in ["home","relief","wood","water","burial","registration","rest","committee"]):return false
	for key in ["motherCareReturned","uncleBoundaryReturned","motherCrisisR4a","uncleCrisisR4b","grandfatherHomeR18"]:
		if state.memory.get(key)!=null:return false
	if focus.resultPackets.any(func(packet):return packet.effects.any(func(effect):return not ordinary_pre_photo_effect_supported(effect))):return false
	var choice: Dictionary=event.choices[int(focus.choiceIndex)]
	var backup:=state.duplicate(true);var before:=focus_snapshot();var lines: Array=[]
	for row in focus.plan.rows.values():
		var packets: Array=focus.resultPackets.filter(func(packet):return packet.id==focus.workPackets.get(row.name));var packet: Dictionary={} if packets.is_empty() else packets[0]
		if not present(row.name) or row.get("inactive",false) or focus.get("cancelWork")==row.name:
			if not packet.is_empty():packet.status="cancelled";packet.cancelReason="未能完成或当事人未返家"
			if focus.get("cancelWork")==row.name and present(row.name) and row.outside:lines.append(row.name+"回到了棚边，原定的差事没有做完。")
			continue
		if not packet.is_empty():
			if focus.get("partialWork")==row.name:
				for effect in packet.effects:
					if typeof(effect.get("amount")) in [TYPE_INT,TYPE_FLOAT]:effect.amount=maxf(1,effect.amount-1)
			apply_ordinary_pre_photo_packet(packet)
		if row.outside:lines.append(later_return_line(row.name,"partial" if focus.get("partialWork")==row.name else "complete"))
		if row.type=="burial":
			apply_ordinary_pre_photo_packet(queue_focus_packet([{"type":"flag_set","flag":"burialExperienced","value":true}],"work:burial:experience","on_return","罗瑾"))
			if focus.selected!="罗瑾":focus.backgroundDiary="今天我跟队回来，没有在路上独自停留。我没有亲眼看见杀戮，却面对了它留下的后果。回到棚里以后，我想先看看家人还在不在眼前，并不想把一路所见立刻从头说完。"
		if row.type=="registration":
			var inquiry: bool=row.get("registrationProtocol")=="inquiry-I3e-4b"
			apply_ordinary_pre_photo_packet(queue_focus_packet([{"type":"flag_set","flag":"registrationInquiry" if inquiry else "registered","value":"mother"}],"work:registration:inquiry" if inquiry else "work:registration:paper","on_return","母亲"))
	for packet in focus.resultPackets:
		if packet.timing=="on_return" and packet.status=="pending":apply_ordinary_pre_photo_packet(packet)
	var known: bool=understands("罗瑾") and later_event_eligible(event,focus.plan)
	if known:state.knowledgeFacts.append({"id":event.id+":return-knowledge","day":state.day+1,"source":event.actor,"knownBy":["罗瑾"],"scope":"选择结果的可转述部分","text":choice.diaries.default})
	focus.diaryAllowed=known;focus.knowledge.luo=[choice.diaries.default] if known else []
	if known and focus.selected!="罗瑾" and (focus.selected!="home" or focus.plan.rows["罗瑾"].outside) and not lines.any(func(line):return line.begins_with(event.actor)):lines.append(event.actor+"在家里说起今天遇到的事。")
	focus.returnText=" ".join(lines);focus.returnChange=describe_focus_change(before);focus.settled=true;focus.carriedAssets=[];state.phase="focusReturn"
	if not finish_ordinary_chapter4_diary():state=backup;return false
	state.history.append({"day":state.day,"type":"later-return","event":event.id,"change":focus.returnChange})
	return true

func settle_chapter_five_default_node(focus: Dictionary,event: Dictionary,lines: Array) -> bool:
	if state.day<44:return _chapter9_parent_16_settle_chapter_five_default_node(focus,event,lines)
	var id: Variant=focus.plan.get("nodeId")
	if id==null:return true
	var node: Dictionary=state.fixedNodeStates[id]
	if chapter_five_node_done(node) or event.get("nodeId")==id:return true
	if id=="trial":node.status="skipped";node.fallback="当日未试印";return true
	if id in ["discover","ending"]:return true
	if id=="transfer":
		apply_ordinary_pre_photo_packet(queue_focus_packet([{"type":"node_resolve","node":"transfer","fallback":"未注视，不带照片"}],"node:transfer:unseen","on_return","罗瑾"));lines.append("罗瑾没有带照片进行这一次转移。");return contract_error==""
	if id not in ["names","sources","employ","firstPrint","disclose","deadline"]:return false
	if id!="employ" and node.eligibleDays.size()<2:return true
	var planned: Dictionary=focus.laterEvents[focus.plan.eventIds[focus.plan.primary]];var options: Array=planned.choices.filter(func(c):return c.id=="safe") if id=="firstPrint" else [planned.choices[0]]
	if options.is_empty():return false
	var choice: Dictionary=options[0]
	if not ordinary_pre_photo_requirement(choice).met:return true
	if id in ["names","sources","employ","firstPrint"] and not later_event_eligible(planned,focus.plan):return true
	if id=="disclose" and not disclosure_default_ready(planned,focus.plan):return contract_error==""
	var effects: Array=choice.get("immediateEffects",[]).duplicate(true)+choice.get("returnEffects",[]).duplicate(true);var packet:=queue_focus_packet(effects,"node:"+id+":default","on_return",planned.actor)
	if not attach_disclosure_knowledge(packet,planned,choice,"safe_default"):return false
	if not apply_ordinary_pre_photo_packet(packet):return false
	node.fallback="岗位保留默认" if id=="employ" else "第二个合适日稳妥默认"
	lines.append({"employ":"工作规矩已传到家里，罗瑾先保留这份帮工岗位。","names":"罗瑾只记下了姓名和消息来处。","sources":"罗瑾把公开说法与能核实的记录分开放好。","firstPrint":"罗瑾今天没有加印；这一回先维持普通工作。","disclose":"罗瑾向一位在场家人只说了最低限度的情况。","deadline":"罗瑾先认下往后争取留存的方向；今天没有因此新增照片。"}[id]);focus.defaultNodeDiary=choice.diaries.default
	return true

func settle_message_thread_return() -> bool:
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if not event.has("messageThread") or focus.get("choiceIndex")==null:return false
	if focus.get("settled",false):return settle_ordinary_pre_photo_return()
	var choice: Dictionary=event.choices[int(focus.choiceIndex)];var view: Dictionary=event.messageThread
	var can_tell: bool=understands(event.actor);var luo: bool=understands("罗瑾")
	if not view.here and not can_tell:choice.diaries.default="我回来以后，今天在棚边接话的家人还不能把经过讲清。我没有凭桌边放着的东西猜谁来过，也没有替没听到的一段补上消息。眼前能顾的先顾，等真有人愿意并能够说，再照听到的记。"
	if not settle_ordinary_pre_photo_return():return false
	focus=state.focus
	var record: Dictionary=_object(state.memory.get("neighbourMessagesWebR5"));var visits: Array=record.get("visits",[]).filter(func(visit):return visit.event==event.id and visit.choice==choice.id)
	if visits.size()!=1:return false
	var visit: Dictionary=visits[0];visit.returned=true
	if luo and (view.here or can_tell):visit.returnRecipients=deliver_fact({"factId":visit.factId,"recipients":["罗瑾"],"source":event.id+(":witness-kept" if view.here else ":actual-return-telling:"+event.actor),"scope":"public-summary","mode":"witnessed" if view.here else "told"})
	focus.messageReceipt.returned=true
	var parts: Array=Array(choice.diaries.default.split("\n\n"));var last: String=parts.pop_back();var body: String="\n\n".join(parts)
	if focus.diaryAllowed and focus.get("chapterDiary") is Array and not focus.chapterDiary.is_empty():
		var found:=false
		for i in range(focus.chapterDiary.size()):
			if focus.chapterDiary[i].contains(choice.diaries.default):found=true;focus.chapterDiary[i]=focus.chapterDiary[i].replace(choice.diaries.default,body)
		if not found:focus.chapterDiary.append(body)
		if js_truthy(focus.get("messageGenericReflection")):
			var at: int=focus.chapterDiary.find(focus.messageGenericReflection)
			if at>=0:focus.chapterDiary.remove_at(at)
		focus.chapterDiary.append(last)
	return true

func settle_chapter_five_custody_return() -> bool:
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if state.ended or state.day<17 or state.day>23 or event.is_empty() or not (event.has("custodyHandoff") or event.has("custodyNight")):return false
	if focus.get("settled",false):return settle_ordinary_pre_photo_return()
	if state.phase!="focusResult" or focus.get("choiceIndex")==null or int(focus.choiceIndex)<0 or int(focus.choiceIndex)>=event.choices.size():return false
	var night: bool=event.has("custodyNight");var record: Dictionary=_object(state.memory.get(CUSTODY_NIGHT_KEY if night else "neighbourCustodyWebR6"))
	if not (custody_night_record_valid(record) if night else custody_handoff_record_valid(record)):return false
	if night and focus.get("custodyNightRevision")!=CUSTODY_NIGHT_REV:return false
	var choice: Dictionary=event.choices[int(focus.choiceIndex)];var visits: Array=record.get("visits",[]).filter(func(row):return row.get("event")==event.id and row.get("choice")==choice.id)
	if visits.size()!=1 or not focus.get("custodyNightReceipt" if night else "custodyReceipt") is Dictionary:return false
	var backup: Dictionary=state.duplicate(true);var meta: Dictionary=event.custodyNight if night else event.custodyHandoff
	if not meta.here and not understands(event.actor):choice.diaries.default="我回来时，今天接话的家人还不能把经过讲清。没有听见这回怎样答应、怎样交物，就不从棚边的一只包猜出事情已经做到哪里。" if night else "我回来以后，今天在棚边接话的家人还不能把事情说明。我没有因为眼前少了或多了一处空地，就猜谁来过、什么东西交给了谁。先顾现在能顾的，没听到的那一段不往日记里补。"
	if not settle_ordinary_pre_photo_return():state=backup;return false
	var visit: Dictionary=visits[0];visit.returned=true
	if night:
		var context:=custody_after_context(focus);var speaker: bool=event.actor in context.home and understands(event.actor) and neighbour_knows(event.actor,visit.factId,"custody-summary")
		if "罗瑾" in context.home and understands("罗瑾") and (meta.here or speaker):
			visit.returnListeners=deliver_fact({"factId":visit.factId,"recipients":["罗瑾"],"scope":"custody-summary","source":event.id+":return:"+event.actor,"mode":"witnessed" if meta.here else "told"})
			if record.status!="declined":deliver_fact({"factId":record.id,"recipients":["罗瑾"],"scope":"custody-summary","source":event.id+":return-summary:"+event.actor,"mode":"witnessed" if meta.here else "told"})
		if focus.diaryAllowed and not focus.get("chapterDiary",[]).any(func(text):return text.contains(choice.diaries.default)):
			if not focus.get("chapterDiary") is Array:focus.chapterDiary=[]
			focus.chapterDiary.append(choice.diaries.default)
		focus.custodyNightReceipt.returned=true
	else:
		if understands("罗瑾") and (meta.here or understands(event.actor)):visit.returnListeners=deliver_fact({"factId":visit.factId,"recipients":["罗瑾"],"source":event.id+(":witness-kept" if meta.here else ":return-telling:"+event.actor),"scope":"custody-public","mode":"witnessed" if meta.here else "told"})
		focus.custodyReceipt.returned=true
		if focus.diaryAllowed and not focus.get("chapterDiary",[]).is_empty():
			var text: String=choice.diaries.default;var parts: Array=Array(text.split("\n\n"));var tail: String=parts.pop_back();var body: String="\n\n".join(parts);var hit: bool=false
			for i in range(focus.chapterDiary.size()):
				if focus.chapterDiary[i].contains(text):hit=true;focus.chapterDiary[i]=focus.chapterDiary[i].replace(text,body)
			if not hit:focus.chapterDiary.append(tail if body.is_empty() else body)
			if js_truthy(focus.get("custodyGenericReflection")):focus.chapterDiary.erase(focus.custodyGenericReflection)
			if not body.is_empty():focus.chapterDiary.append(tail)
	return true

func _chapter5_parent_0_apply_ordinary_pre_photo_packet(packet: Dictionary) -> bool:
	if state.ended or packet.effects.any(func(effect):return not ordinary_pre_photo_effect_supported(effect)):return false
	if not state.has("effectLedger"):state.effectLedger={"appliedEffectIds":[]}
	if packet.status!="pending" or packet.id in state.effectLedger.appliedEffectIds:return false
	if packet.subjectId in PEOPLE and not present(packet.subjectId):packet.status="cancelled";packet.cancelReason="当事人未返家或已死亡";return false
	for i in range(packet.effects.size()):
		var effect: Dictionary=packet.effects[i]
		match effect.type:
			"resource_delta":
				state[effect.resource]=maxf(0,minf(state.waterCap if effect.resource=="water" else INF,state[effect.resource]+effect.amount))
				if effect.resource=="water" and state.water==0:state.memory.erase("waterExposure")
			"shelter_delta":state.shelter=clampf(state.shelter+effect.amount,0,50)
			"item_consume":state.tools[effect.item]=false
			"item_gain":
				if state.tools.get(effect.item,false):state["rice" if effect.item=="whistle" else "wood"]+=1
				else:state.tools[effect.item]=true
			"character_health":
				if present(effect.target):state.people[effect.target].health=clampf(state.people[effect.target].health+effect.amount,0,10)
			"character_spirit":
				if present(effect.target):apply_packet_spirit(packet,effect,i)
			"flag_set":state.memory[effect.flag]=effect.value
			"node_resolve":
				var node: Dictionary=state.fixedNodeStates[effect.node];node.status=effect.get("status","resolved") if js_truthy(effect.get("status")) else "resolved";node.resolvedDay=state.day+1;node.fallback=effect.get("fallback") if js_truthy(effect.get("fallback")) else null
			"photo_progress":
				var p: Dictionary=state.photo
				if not js_truthy(p.get("evidenceStage")):p.evidenceStage="unavailable"
				if effect.op=="employ":p.unlocked=true;p.employed=true;p.evidenceStage="employed"
				elif effect.op=="skill_delta":p.skill=clampf(p.skill+effect.value,0,6)
	packet.status="applied";state.effectLedger.appliedEffectIds.append(packet.id);return true


func _chapter5_parent_0_ordinary_pre_photo_effect_supported(effect: Dictionary) -> bool:
	if effect.get("type")=="flag_set" and effect.get("flag") in ["namesChecked","oldPhotoAsked","visitorNameRecorded","newYearWritten","apprenticeOrderPractised","qianEmploymentBridge","accountantUncleIntroduced"] and effect.get("value") is bool:return true
	if effect.get("type")=="node_resolve":return effect.get("node") in ["names","sources","employ"] and (not effect.has("status") or effect.status in [null,"resolved","skipped"])
	if effect.get("type")=="photo_progress":return effect.get("op")=="employ" and effect.get("value")==true or effect.get("op")=="skill_delta" and typeof(effect.get("value")) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(effect.value))
	return _chapter4_parent_2_ordinary_pre_photo_effect_supported(effect)


var mother_care_prose: Dictionary={}

func load_mother_care_prose() -> void:
	if mother_care_prose.is_empty():mother_care_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/mother_care_prose.json"))

func family_system_packet(effects: Array,key: String) -> bool:
	if not state.has("storySystemPackets"):state.storySystemPackets=[]
	var id: String=state.seed+":D"+str(int(state.day)+1)+":system:"+key
	var existing: Array=state.storySystemPackets.filter(func(packet):return packet.id==id)
	var packet: Dictionary={"id":id,"timing":"next_morning","subjectId":"family","effects":effects.duplicate(true),"status":"pending"} if existing.is_empty() else existing[0]
	if existing.is_empty():state.storySystemPackets.append(packet)
	return apply_ordinary_pre_photo_packet(packet)

func process_mother_care_morning() -> void:
	if state.ended:return
	load_mother_care_prose();var date: Variant=state.day+1
	if date>=25 and date<=29 and not js_truthy(state.memory.get("motherCareNoticeDay")) and can_work_later("母亲"):
		family_system_packet([{"type":"flag_set","flag":"motherCareNoticeDay","value":date}],"mother-care-notice")
		state.morningResults.append(mother_care_prose.notice)
		state.knowledgeFacts.append({"id":"mother-care.notice","day":date,"knownBy":["player","母亲"]+(["罗瑾"] if understands("罗瑾") else []),"scope":"情境演绎：领物处照应不足的提醒，不是医疗岗位或安全保证"})
	var record: Dictionary=_object(state.memory.get("motherCareReturned"))
	if record.is_empty() or js_truthy(state.memory.get("motherCareFollowupDone")) or date<=record.day:return
	if not state.history.any(func(row):return row.get("type")=="later-return" and row.get("day")==record.day-1 and row.get("event")==record.event):return
	if not state.people["母亲"].alive or state.people["母亲"].get("permanentLost",false) or date>record.day+4:
		family_system_packet([{"type":"flag_set","flag":"motherCareFollowupDone","value":"closed"}],"mother-care-followup-close");return
	if not understands("母亲"):return
	if family_system_packet([{"type":"flag_set","flag":"motherCareFollowupDone","value":date}],"mother-care-followup"):
		state.morningResults.append(mother_care_prose.followup.get(record.choice,mother_care_prose.followup.unknown))
		state.knowledgeFacts.append({"id":"mother-care.followup","day":date,"knownBy":["player","母亲"]+(["罗瑾"] if understands("罗瑾") else []),"scope":"只回顾已经发生的选择，不证明陌生人的后续命运"})

func bind_mother_care(focus: Dictionary) -> void:
	var date: Variant=state.day+1;var row: Dictionary=_object(focus.plan.rows.get("母亲"));var id: Variant=focus.plan.eventIds.get("母亲");var old: Dictionary=_object(focus.laterEvents.get(id))
	var notice: bool=state.get("knowledgeFacts",[]).any(func(fact):return fact.get("id")=="mother-care.notice" and fact.get("day",INF)<date and "player" in fact.get("knownBy",[]) and "母亲" in fact.get("knownBy",[]))
	if date<26 or date>31 or js_truthy(state.memory.get("motherCareChosen")) or not notice or not can_work_later("母亲") or current_weather().get("severe",false) or not row.get("outside",false) or row.get("inactive",false) or row.get("type")!="relief" or float(_object(row.get("base")).get("rice",0))<2 or old.is_empty() or ["nodeId","motherCare","pigeonPickup","expeditionSearch"].any(func(key):return js_truthy(old.get(key))):return
	load_mother_care_prose();var event: Dictionary=old.duplicate(true)
	for key in ["motherCare","historyClass","title","intro","choices"]:event[key]=mother_care_prose.scene[key].duplicate(true) if mother_care_prose.scene[key] is Array or mother_care_prose.scene[key] is Dictionary else mother_care_prose.scene[key]
	for choice in event.choices:
		for key in ["immediateEffects","returnEffects"]:
			for effect in choice.get(key,[]):
				if effect.get("type")=="flag_set" and effect.get("flag") in ["motherCareChosen","motherCareReturned"]:effect.value={"day":date,"choice":choice.id,"event":id}
	focus.laterEvents[id]=event

func mother_care_requirement(choice: Dictionary) -> Dictionary:
	var focus: Dictionary=state.focus;var event: Dictionary=_object(focus.get("laterEvents",{}).get(focus.get("eventId")));var row: Dictionary=_object(_object(focus.get("plan")).get("rows",{}).get("母亲"))
	var packets: Array=focus.get("resultPackets",[]).filter(func(packet):return packet.get("id")==focus.get("workPackets",{}).get("母亲"));var packet: Dictionary={} if packets.is_empty() else packets[0];var rice: float=0
	for effect in packet.get("effects",[]):
		if effect.get("type")=="resource_delta" and effect.get("resource")=="rice":rice+=effect.amount
	var met: bool=js_truthy(event.get("motherCare")) and event.get("choices",[]).any(func(c):return c.id==choice.id) and not js_truthy(state.memory.get("motherCareChosen")) and can_work_later("母亲") and row.get("outside",false) and not row.get("inactive",false) and row.get("type")=="relief" and packet.get("subjectId")=="母亲" and packet.get("status")=="pending" and rice>=2
	return {"met":met,"reason":"" if met else "母亲这一趟领粮的条件已改变，不能从家中库存补算她手里的粮。"}

func mother_care_return_allowed(packet: Dictionary) -> bool:
	var focus: Dictionary=state.focus;var packets: Array=focus.get("resultPackets",[]).filter(func(p):return p.get("id")==_object(packet.get("motherCare")).get("workPacket"));var prior: Dictionary={} if packets.is_empty() else packets[0];var rice: float=0
	for effect in prior.get("effects",[]):
		if effect.get("type")=="resource_delta" and effect.get("resource")=="rice":rice+=effect.amount
	return not prior.is_empty() and prior.id==focus.get("workPackets",{}).get("母亲") and prior.get("subjectId")=="母亲" and packet.get("subjectId")=="母亲" and rice>=2 and prior.get("status")=="applied" and prior.id in state.get("effectLedger",{}).get("appliedEffectIds",[])

func mother_care_has_returned(focus: Dictionary) -> bool:
	return focus.get("resultPackets",[]).any(func(packet):return js_truthy(packet.get("motherCare")) and packet.get("status")=="applied" and packet.id in state.get("effectLedger",{}).get("appliedEffectIds",[]))

func _chapter5_parent_1_ordinary_pre_photo_effect_supported(effect: Dictionary) -> bool:
	if effect.get("type")=="flag_set":
		var key: Variant=effect.get("flag");var value: Variant=effect.get("value")
		if key=="motherCareNoticeDay":return _whole_number(value) and value>=25 and value<=29
		if key=="motherCareFollowupDone":return (value is String and value=="closed") or _whole_number(value) and value>=25 and value<=49
		if key in ["motherCareChosen","motherCareReturned"]:return value is Dictionary and value.size()==3 and _whole_number(value.get("day")) and value.day>=26 and value.day<=31 and value.get("choice") in ["leave","stay","share"] and value.get("event") is String
	return _chapter5_parent_0_ordinary_pre_photo_effect_supported(effect)


const PARCEL_KEY="neighbourParcelR2b"

var parcel_prose: Dictionary={}

func valid_parcel_record(record: Variant) -> bool:
	if not record is Dictionary:return false
	if not _whole_number(record.get("stage")) or record.stage<1 or record.stage>3 or not _whole_number(record.get("lastDay")) or record.lastDay<25 or record.lastDay>48:return false
	if not record.get("sent") is bool or not record.get("lastChoice") is String or not record.get("knownBy") is Array or record.knownBy.size()>4 or not record.knownBy.all(func(person):return person is String and person in PEOPLE):return false
	if typeof(record.get("roll")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(record.roll)) or record.roll<0 or record.roll>=1 or record.get("randomVersion")!="delivery-v1":return false
	if record.stage>=2 and record.get("result") not in ["delivered","spilled","not_sent"]:return false
	if record.has("wood") and (not _whole_number(record.wood) or record.wood!=1 and record.wood!=3):return false
	if record.has("usedAxe") and not record.usedAxe is bool:return false
	return true

func make_parcel_event(focus: Dictionary,admission: Dictionary,decorated: bool=true) -> Dictionary:
	if focus.get("webM3ReadingRevision")!="WebM3-D25D32-v1" or focus.day<24 or focus.day>31:return _chapter5_parent_7_make_parcel_event(focus,admission,decorated)
	if parcel_webm3_prose.is_empty():parcel_webm3_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/parcel_webm3_prose.json"))
	var previous: Dictionary=parcel_prose;parcel_prose=parcel_webm3_prose;var result: Dictionary=_chapter5_parent_7_make_parcel_event(focus,admission,decorated);parcel_prose=previous;return result

func prepare_parcel_choice(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	if not event.has("neighbourParcel"):return false
	var prior: Dictionary=_object(state.memory.get(PARCEL_KEY));var stage: Variant=event.neighbourParcel.stage
	if prior.get("stage",0)!=stage-1:return false
	var record: Dictionary=prior.duplicate(true);record.stage=stage;record.lastDay=focus.day+1;record.lastChoice=choice.id
	if stage==1:
		record.sent=choice.id=="send";record.knownBy=PEOPLE.filter(func(person):return understands(person) and not _object(focus.plan.rows.get(person)).get("outside",false));record.roll=float(RNG.hash_seed(state.seed+"|neighbour-parcel|delivery-v1"))/4294967296.0;record.randomVersion="delivery-v1"
	if stage==2:record.result=event.neighbourParcel.result
	if stage==3 and choice.id=="take":
		var axe: bool=tool_available("axe");var amount: int=3 if event.neighbourParcel.woodRoll<(0.8 if axe else 0.45) else 1;record.wood=amount;record.usedAxe=axe
		choice.immediateEffects=[{"type":"resource_delta","resource":"wood","amount":amount}]
		var decorated: bool=_object(event.get("readingVariant")).get("revision")=="WebR3-neighbour-prose-v1" and event.readingVariant.get("chain")=="parcel"
		var here: bool=present("罗瑾") and not focus.plan.rows["罗瑾"].get("outside",false) and not focus.plan.rows["罗瑾"].get("inactive",false)
		var key: String=JSON.stringify([decorated,event.actor,record.sent,here,axe,amount])
		if parcel_prose.is_empty():parcel_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/parcel_prose.json"))
		if not parcel_prose.outcomes.has(key):return false
		var text: Dictionary=decode_home_content(parcel_prose.outcomes[key],parcel_prose);choice.closures.default=text.closure;choice.diaries.default=text.diary
	if not valid_parcel_record(record):return false
	choice.immediateEffects=choice.get("immediateEffects",[]).filter(func(effect):return effect.get("flag")!=PARCEL_KEY)+[{"type":"flag_set","flag":PARCEL_KEY,"value":record}]
	return true

func bind_neighbour_parcel(focus: Dictionary) -> bool:
	var date: int=int(focus.day)+1;var prior: Variant=state.memory.get(PARCEL_KEY)
	if date<25 or date>48 or _object(prior).get("stage")==3 or "home" not in focus.plan.targets:return true
	var old: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get("home")))
	if old.is_empty() or ["nodeId","neighbourhood","recovery","motherCare","uncleBoundary"].any(func(key):return js_truthy(old.get(key))) or js_truthy(focus.plan.get("recoveryOffer")) or focus.plan.get("key") in ["expeditionSearch","pigeonPickup"]:return true
	if prior==null and date>38 or prior is Dictionary and date<maxf(prior.lastDay+4,32 if prior.stage==1 else 41):return true
	var admission:=home_neighbour_admission(focus,"parcel")
	if not admission.allowed:return true
	var event:=make_parcel_event(focus,admission,false)
	if event.is_empty():return false
	focus.neighbourParcelDisplaced={"id":old.id,"title":old.title};focus.laterEvents[event.id]=event;focus.plan.eventIds.home=event.id
	return true

func resolve_parcel_choice(index: int) -> bool:
	if state.ended or state.day<24 or state.day>47 or state.phase!="focusEvent" or state.focus.get("choiceIndex")!=null:return false
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if not event.get("neighbourParcel") is Dictionary or index<0 or index>=event.choices.size():return false
	var choice: Dictionary=event.choices[index];var requirement:=ordinary_pre_photo_requirement(choice)
	if not requirement.met:state.error=requirement.reason;return false
	if not later_event_eligible(event,focus.plan):state.error="当事人已不能参与这段现场。";return false
	if _object(state.memory.get(PARCEL_KEY)).get("stage",0)!=event.neighbourParcel.stage-1:state.error="这次选择尚未结算：邻里口信的前情已改变";return false
	var before: Dictionary=state.duplicate(true)
	if not prepare_parcel_choice(focus,event,choice) or not commit_rope_choice_core(index):state=before;return false
	return true

func finish_parcel_diary(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	# The separate D49 combined-chain ending is not part of this component yet.
	if focus.day==48:return false
	if not event.has("neighbourParcel") or not focus.get("diaryAllowed",false):return true
	var prior: Dictionary=_object(state.memory.get(PARCEL_KEY));var record: Dictionary=prior.duplicate(true)
	if not valid_parcel_record(record):return false
	# The source parcel record shares its applied flag value in uninterrupted play.
	# Reproduce that value update explicitly after deserialization too; never rely
	# on dictionary aliasing, and never rewrite another event's flag receipt.
	var receipts: Array=[]
	for packet in focus.get("resultPackets",[]):
		if packet.get("status")!="applied" or packet.get("timing")!="immediate" or packet.get("sourceEventInstanceId")!="D"+str(int(focus.day)+1)+":"+event.id:continue
		for effect in packet.get("effects",[]):
			if effect.get("type")=="flag_set" and effect.get("flag")==PARCEL_KEY and var_to_bytes(effect.get("value"))==var_to_bytes(prior):receipts.append(effect)
	if receipts.size()!=1:return false
	for person in PEOPLE:
		if understands(person) and person not in record.knownBy:record.knownBy.append(person)
	state.memory[PARCEL_KEY]=record;receipts[0].value=record.duplicate(true)
	var parts: Array=Array(choice.diaries.default.split("\n\n"));var last: String=parts.pop_back();var body: String="\n\n".join(parts)
	if focus.get("chapterDiary") is Array and not focus.chapterDiary.is_empty():
		for i in range(focus.chapterDiary.size()):
			if focus.chapterDiary[i].contains(choice.diaries.default):focus.chapterDiary[i]=focus.chapterDiary[i].replace(choice.diaries.default,body)
		focus.chapterDiary[-1]=last
	else:focus.chapterDiary=[body,last]
	return true

const MOTHER_CRISIS_KEY="motherCrisisR4a"

const MOTHER_CRISIS_REV="mother-crisis-v1"

const MOTHER_PREP_SOURCE_REV="R4-v9-B10-preparation-source-v1"

var mother_crisis_morning_prose: Dictionary={}

var mother_crisis_prose: Dictionary={}

func mother_crisis_actual_return(record: Dictionary) -> bool:
	return not record.is_empty() and state.history.any(func(row):return row.get("type")=="later-return" and row.get("event")==record.get("event") and row.get("day")==record.get("day",INF)-1)

func mother_crisis_fact(id: String) -> bool:
	return state.get("knowledgeFacts",[]).any(func(fact):return fact.get("id")==id and "player" in fact.get("knownBy",[]) and "母亲" in fact.get("knownBy",[]) and fact.get("day",INF)<state.day+1)

func mother_crisis_requirement(choice: Dictionary) -> Dictionary:
	var focus: Dictionary=state.focus;var event: Dictionary=_object(focus.get("laterEvents",{}).get(focus.get("eventId")));var record: Dictionary=_object(state.memory.get(MOTHER_CRISIS_KEY));var has_record: bool=js_truthy(state.memory.get(MOTHER_CRISIS_KEY));var reason: String=""
	if not js_truthy(event.get("motherCrisis")) or event.get("crisisRevision")!=MOTHER_CRISIS_REV or not event.get("choices",[]).any(func(c):return c.id==choice.id) or not understands("母亲"):reason="母亲目前不能参与这段谈话或现场。"
	elif event.motherCrisis.stage==1 and has_record or event.motherCrisis.stage>1 and (not has_record or record.get("stage")!=event.motherCrisis.stage-1 or not mother_crisis_actual_return(record)):reason="前一段经历尚未真正返家，不能补写后续。"
	elif event.motherCrisis.stage==2 and (not mother_crisis_fact("mother-crisis.prepared-notice") or js_truthy(record.get("closed")) or not can_work_later("母亲") or state.memory.get("irreversibleDay") == state.day):reason="尚无已知前兆，或当天不具备面对这场危险的条件。"
	elif js_truthy(choice.get("requiresPrepared")) and not js_truthy(record.get("prepared")):reason="此前没有安排共同搬送，不能凭空出现两位帮手。"
	elif js_truthy(choice.get("requiresSteady")) and state.people["母亲"].spirit<3:reason="母亲已经难以支撑继续周旋；可以退出眼前的危险。"
	elif js_truthy(choice.get("requiresMedicine")) and (not ["bandage","medkit"].any(func(item):return tool_available(item)) or not (state.people["母亲"].health<10 or state.ailments["母亲"].get("wound",0)>0)):reason="没有适用的外伤药，或眼下没有需要这次处理的外伤。"
	return {"met":reason.is_empty(),"reason":reason}

func mother_preparation_source(focus: Dictionary,event: Dictionary) -> Dictionary:
	var source: Dictionary=_object(event.get("r4v9PreparationSource"));var date: Variant=state.day+1;var rows: Dictionary=_object(_object(focus.get("plan")).get("rows"))
	if source.is_empty() or source.get("revision")!=MOTHER_PREP_SOURCE_REV or state.saveVersion!=24 or state.ended or date<28 or date>37 or focus.get("day")!=state.day or focus.plan.get("day")!=state.day or event.get("id")!="mother.crisis.R4a.D"+str(int(date))+".1" or source.get("day")!=date or source.get("eventId")!=event.id or source.get("target")!=event.get("target") or event.get("crisisRevision")!=MOTHER_CRISIS_REV or _object(event.get("motherCrisis")).get("stage")!=1 or event.get("actor")!="母亲" or event.get("conditionKind")!="mother-crisis":return {}
	if event.get("participants",[]).size()!=1 or event.participants[0]!="母亲" or not rows.has("罗瑾") or not rows.has("母亲") or event.get("choices",[]).size()!=2 or event.choices[0].get("id")!="prepare" or event.choices[1].get("id")!="no_promise":return {}
	if event.target=="母亲":
		if not rows["母亲"].get("outside",false) or rows["母亲"].get("inactive",false) or rows["母亲"].get("type")!="relief" or source.get("mode")!="return_telling":return {}
	elif event.target=="home":
		if rows["母亲"].get("outside",false) or rows["母亲"].get("inactive",false):return {}
		var mode: String="home_witness" if not rows["罗瑾"].get("outside",false) and not rows["罗瑾"].get("inactive",false) else "return_telling"
		if source.get("mode")!=mode:return {}
	else:return {}
	return source

func mother_preparation_return_allowed(focus: Dictionary,event: Dictionary) -> bool:
	if not event.has("r4v9PreparationSource"):return true
	var source:=mother_preparation_source(focus,event)
	return not source.is_empty() and (source.mode=="home_witness" or understands("母亲"))

func update_mother_crisis_record(prior: Dictionary,updated: Dictionary) -> void:
	# Preserve the source's observable applied-record values even after decoding.
	# Stage-2 consequence records are copies and therefore do not match the old
	# return payload; no unrelated receipt is inferred or rewritten.
	var matches: Array=[]
	for packet in state.focus.get("resultPackets",[]):
		if packet.get("status")!="applied" or packet.get("timing")!="on_return" or packet.get("sourceEventInstanceId")!="D"+str(int(prior.get("day",-1)))+":"+str(prior.get("event","")):continue
		for effect in packet.get("effects",[]):
			if effect.get("type")=="flag_set" and effect.get("flag")==MOTHER_CRISIS_KEY and var_to_bytes(effect.get("value"))==var_to_bytes(prior):matches.append(effect)
	state.memory[MOTHER_CRISIS_KEY]=updated
	if matches.size()==1:matches[0].value=updated.duplicate(true)

func process_mother_crisis_morning() -> void:
	var prior: Dictionary=_object(state.memory.get(MOTHER_CRISIS_KEY))
	if prior.is_empty() or state.ended:return
	var record: Dictionary=prior.duplicate(true);var date: Variant=state.day+1
	if mother_crisis_morning_prose.is_empty():mother_crisis_morning_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/mother_crisis_morning_prose.json"))
	if record.get("stage")==1 and date>41 and not js_truthy(record.get("closed")):
		record.closed=true;record.closeDay=date;state.morningResults.append(mother_crisis_morning_prose.close["true" if js_truthy(record.get("prepared")) else "false"])
	if record.get("stage")==2 and mother_crisis_actual_return(record) and date>record.day and not js_truthy(record.get("nextMorning")) and understands("母亲"):
		record.nextMorning=date;state.morningResults.append(mother_crisis_morning_prose.next.get(record.get("outcome",""),mother_crisis_morning_prose.next.withdrawn))
	if js_truthy(record.get("restUntil")) and date>record.restUntil and not js_truthy(record.get("restAnnounced")):
		record.restAnnounced=date
		if understands("母亲"):state.morningResults.append(mother_crisis_morning_prose.rest)
	update_mother_crisis_record(prior,record)

func make_mother_crisis_event(focus: Dictionary,stage: int,target: String,bridge: bool,prior_returned: bool,companion: String) -> Dictionary:
	var prior: Dictionary=_object(state.memory.get(MOTHER_CRISIS_KEY));var has_prior: bool=js_truthy(state.memory.get(MOTHER_CRISIS_KEY))
	var luo_home: bool=not focus.plan.rows["罗瑾"].get("outside",false)
	var needs_treatment: bool=state.people["母亲"].health<10 or state.ailments["母亲"].get("wound",0)>0
	var key: String=JSON.stringify([stage,target,bridge if stage==1 else false,luo_home,js_truthy(prior.get("prepared")) if stage==2 else false,prior.get("outcome","") if stage==3 else "",needs_treatment if stage==3 else false,companion if stage==3 else ""])
	if mother_crisis_prose.is_empty():mother_crisis_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/mother_crisis_prose.json"))
	if not mother_crisis_prose.variants.has(key):return {}
	var event: Dictionary=decode_home_content(mother_crisis_prose.events[mother_crisis_prose.variants[key]],mother_crisis_prose);var date: Variant=focus.day+1
	event.id="mother.crisis.R4a.D"+str(int(date))+"."+str(stage);event.motherCrisis.prior=prior.duplicate(true) if has_prior else null;event.motherCrisis.entry="notice-bridge" if bridge else ("care-return" if prior_returned else "direct")
	if event.has("r4v9PreparationSource"):event.r4v9PreparationSource.day=date;event.r4v9PreparationSource.eventId=event.id
	return event

func bind_mother_crisis(focus: Dictionary) -> bool:
	var date: Variant=focus.day+1;var record: Dictionary=_object(state.memory.get(MOTHER_CRISIS_KEY));var has_record: bool=js_truthy(state.memory.get(MOTHER_CRISIS_KEY))
	if focus.get("characterRevision")!="R4a" or date<28 or date>48 or state.ended or not understands("母亲") or not understands("罗瑾") or js_truthy(focus.plan.get("nodeId")) or focus.plan.get("key") in ["expeditionSearch","pigeonPickup"] or js_truthy(focus.plan.get("recoveryOffer")):return true
	var stage:=0;var target: String="";var bridge:=false
	var care: Dictionary=_object(state.memory.get("motherCareReturned"));var prior_returned: bool=mother_crisis_actual_return(care) and care.day<date and js_truthy(state.memory.get("motherCareFollowupDone"))
	if not has_record and date<=37 and can_work_later("母亲") and (prior_returned or date>=32 and (mother_crisis_fact("mother-care.notice") or js_truthy(state.memory.get("motherCareNoticeDay")))):
		stage=1;bridge=not prior_returned;var row: Dictionary=_object(focus.plan.rows.get("母亲"));target="母亲" if row.get("outside",false) and not row.get("inactive",false) and row.get("type")=="relief" else "home"
	elif record.get("stage")==1 and not js_truthy(record.get("closed")) and date>=record.day+2 and date<=41 and mother_crisis_actual_return(record) and mother_crisis_fact("mother-crisis.prepared-notice") and can_work_later("母亲"):stage=2;target="母亲"
	elif record.get("stage")==2 and date>=record.day+3 and mother_crisis_actual_return(record):stage=3;target="home"
	else:return true
	var row: Dictionary=_object(focus.plan.rows.get("母亲"));var old_id: Variant=focus.plan.get("eventIds",{}).get(target);var old: Dictionary=_object(focus.get("laterEvents",{}).get(old_id))
	if old.is_empty() or ["nodeId","recovery","expeditionSearch","pigeonPickup","motherCare","uncleBoundary"].any(func(key):return js_truthy(old.get(key))):return true
	if (stage==2 or stage==1 and target=="母亲") and (not row.get("outside",false) or row.get("inactive",false) or row.get("type")!="relief"):return true
	if target=="home" and ("home" not in focus.plan.targets or row.get("outside",false) or row.get("inactive",false)):return true
	var companions: Array=PEOPLE.filter(func(person):return person!="母亲" and understands(person) and not _object(focus.plan.rows.get(person)).get("outside",false) and not _object(focus.plan.rows.get(person)).get("inactive",false));var companion: String="" if companions.is_empty() else companions[0]
	if stage==3 and companion=="":return true
	if _object(old.get("neighbourhood")).get("stage",0)>1 or _object(old.get("neighbourParcel")).get("stage",0)>1:return true
	var event:=make_mother_crisis_event(focus,stage,target,bridge,prior_returned,companion)
	if event.is_empty():return false
	focus.motherCrisisDisplaced={"id":old.id,"title":old.title};focus.laterEvents[event.id]=event;focus.plan.eventIds[target]=event.id
	return true

func _chapter5_parent_3_ordinary_pre_photo_effect_supported(effect: Dictionary) -> bool:
	if effect.get("type")=="flag_set" and effect.get("flag")==PARCEL_KEY:return valid_parcel_record(effect.get("value"))
	return _chapter5_parent_1_ordinary_pre_photo_effect_supported(effect)


func _chapter5_parent_3_ordinary_pre_photo_requirement(choice: Dictionary) -> Dictionary:
	if js_truthy(choice.get("frozenReason")):return {"met":false,"reason":choice.frozenReason}
	var shelter_limit=choice.get("requiresShelterBelow")
	if not js_truthy(shelter_limit) and choice.get("id") in ["brace","pole_brace"] and choice.get("immediateEffects",[]).any(func(effect):return effect.type=="shelter_delta" and effect.amount>0):shelter_limit=50
	if js_truthy(shelter_limit) and state.shelter>=shelter_limit:return {"met":false,"reason":"草棚已是目前能修到的最好状态，这次无需再加固。"}
	if js_truthy(choice.get("requiresPerson")) and not present(choice.requiresPerson):return {"met":false,"reason":"所需人物不在场"}
	for tool in choice.get("requiresTools",[]):
		if not tool_available(tool):return {"met":false,"reason":"缺少"+TOOL_NAMES.get(tool,tool)}
	for resource in choice.get("requiresResources",{}):
		if state[resource]<choice.requiresResources[resource]:return {"met":false,"reason":"家中物资不足"}
	if js_truthy(choice.get("requiresMemory")) and not js_truthy(state.memory.get(choice.requiresMemory)):return {"met":false,"reason":"缺少此前准备"}
	if js_truthy(choice.get("requiresWaterSpace")) and state.waterCap-state.water<choice.requiresWaterSpace:return {"met":false,"reason":"容器容量不足"}
	return {"met":true,"reason":""}

const MOTHER_RISK_REV="mother-hold-fixed-v2"

const MOTHER_OUTCOMES=["withdrawn","evacuated","turned_back","covered","beaten","assault"]

func valid_mother_crisis_record(record: Variant) -> bool:
	if not record is Dictionary or record.get("revision")!=MOTHER_CRISIS_REV or not _whole_number(record.get("stage")) or record.stage<1 or record.stage>3 or not _whole_number(record.get("day")) or record.day<28 or record.day>48:return false
	if record.get("event")!="mother.crisis.R4a.D"+str(int(record.day))+"."+str(int(record.stage)) or not record.get("returned") is bool or not record.get("prepared") is bool or not _whole_number(record.get("warningDay")):return false
	var choices: Array=["prepare","no_promise"] if record.stage==1 else (["withdraw","together","hold"] if record.stage==2 else ["listen","treat"])
	if record.get("choice") not in choices:return false
	if record.stage>=2 and record.get("outcome") not in MOTHER_OUTCOMES:return false
	if record.has("roll") and (typeof(record.roll) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(record.roll)) or record.roll<0 or record.roll>=1):return false
	if record.has("knownBy") and (not record.knownBy is Array or not record.knownBy.all(func(person):return person is String and person in PEOPLE)):return false
	return true

func prepare_mother_crisis_choice(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	if not event.has("motherCrisis"):return false
	if not mother_crisis_requirement(choice).met:fail_contract("MOTHER_CRISIS_PRECONDITION","母亲支线前提已变化");return false
	var record: Dictionary=_object(state.memory.get(MOTHER_CRISIS_KEY)).duplicate(true);var stage: Variant=event.motherCrisis.stage;var date: Variant=state.day+1
	record.revision=MOTHER_CRISIS_REV;record.stage=stage;record.day=date;record.event=event.id;record.choice=choice.id;record.returned=false
	if stage==1:record.prepared=choice.id=="prepare";record.warningDay=date
	if stage==2:
		var roll: float=float(RNG.hash_seed(state.seed+"|"+MOTHER_CRISIS_REV+"|risk"))/4294967296.0;var pole: bool=tool_available("pole")
		record.roll=roll;record.poleUsed=choice.id=="together" and pole;record.riskRevision=MOTHER_RISK_REV;record.riskBand="fixed_high_risk" if choice.id=="hold" else "not_spirit_coupled"
		record.outcome="withdrawn" if choice.id=="withdraw" else (("evacuated" if roll<(0.85 if pole else 0.6) else "turned_back") if choice.id=="together" else ("assault" if roll<0.25 else ("beaten" if roll<0.7 else "covered")))
		if mother_crisis_prose.is_empty():mother_crisis_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/mother_crisis_prose.json"))
		var text: Dictionary=decode_home_content(mother_crisis_prose.outcomes[record.outcome+("_pole" if pole else "")],mother_crisis_prose);choice.closures.default=text.closure;choice.diaries.default=text.diary
		choice.returnEffects=[{"type":"mother_crisis_consequence","review":MOTHER_CRISIS_REV,"outcome":record.outcome,"event":event.id,"choice":choice.id}]
	if stage==3 and choice.id=="treat":
		var medicines: Array=["bandage","medkit"].filter(func(item):return tool_available(item))
		if medicines.is_empty():return false
		record.medicine=medicines[0];choice.immediateEffects=[{"type":"item_consume","item":record.medicine}]
		choice.returnEffects=[{"type":"character_health","target":"母亲","amount":1},{"type":"ailment_reduce","target":"母亲","ailment":"wound","amount":1}]
	if not valid_mother_crisis_record(record):return false
	choice.immediateEffects=choice.get("immediateEffects",[]).filter(func(effect):return effect.get("flag")!=MOTHER_CRISIS_KEY)+[{"type":"flag_set","flag":MOTHER_CRISIS_KEY,"value":record}]
	var returned: Dictionary=record.duplicate(true);returned.returned=true;choice.returnEffects=choice.get("returnEffects",[])+[{"type":"flag_set","flag":MOTHER_CRISIS_KEY,"value":returned}]
	if stage==2:
		var before: Dictionary={}
		for person in PEOPLE:before[person]={"spirit":state.people[person].spirit,"spiritMax":state.people[person].get("spiritMax",10)}
		var intervals: Dictionary={"deterministic":"withdrawn"} if choice.id=="withdraw" else ({"evacuatedBelow":0.85 if record.poleUsed else 0.6} if choice.id=="together" else {"assaultBelow":0.25,"beatenBelow":0.7,"otherwise":"covered"})
		if not focus.has("riskAudits"):focus.riskAudits=[]
		var matching: Array=focus.riskAudits.filter(func(a):return a.event==event.id and a.choice==choice.id and a.kind=="mother")
		if matching.is_empty():
			focus.riskAudits.append({"kind":"mother","event":event.id,"choice":choice.id,"day":date,"before":before,"contract":record.revision,"revision":record.riskRevision,"riskRevision":record.riskRevision,"intervals":intervals,"locked":record.duplicate(true)})
			matching=[focus.riskAudits[-1]]
		if not state.memory.has("a3cT3"):state.memory.a3cT3={"revision":"A3c-T3-v1","knowledge":[],"spirit":[],"death":{}}
		var book: Dictionary=state.memory.a3cT3
		if not book.has("riskAudits"):book.riskAudits=[]
		var audit: Dictionary=matching[0]
		if not book.riskAudits.any(func(a):return a.event==event.id and a.choice==choice.id and a.kind=="mother" and a.day==audit.day):book.riskAudits.append(audit.duplicate(true))
	return true

func mother_crisis_packet_error(text: String) -> bool:
	fail_contract("MOTHER_CRISIS_PACKET",text);return false

func apply_mother_crisis_packet(packet: Dictionary) -> bool:
	if packet.get("status")!="pending" or packet.get("id") in state.get("effectLedger",{}).get("appliedEffectIds",[]):return false
	var focus: Dictionary=state.focus;var event: Dictionary=_object(focus.get("laterEvents",{}).get(focus.get("eventId")));var index: Variant=focus.get("choiceIndex");var choice: Dictionary={}
	if typeof(index) in [TYPE_INT,TYPE_FLOAT] and index>=0 and index<event.get("choices",[]).size():choice=event.choices[int(index)]
	var consequences: Array=packet.get("effects",[]).filter(func(effect):return effect.get("type")=="mother_crisis_consequence");var consequence: Dictionary={} if consequences.is_empty() else consequences[0];var record: Dictionary=_object(state.memory.get(MOTHER_CRISIS_KEY))
	if not event.has("motherCrisis") or event.motherCrisis.get("stage")!=2 or event.get("crisisRevision")!=MOTHER_CRISIS_REV or packet.get("timing")!="on_return" or packet.get("subjectId")!="母亲" or consequence.get("review")!=MOTHER_CRISIS_REV or consequence.get("event")!=event.get("id") or consequence.get("choice")!=choice.get("id") or record.get("event")!=event.get("id") or record.get("choice")!=choice.get("id") or record.get("outcome")!=consequence.get("outcome") or not mother_crisis_fact("mother-crisis.prepared-notice"):return mother_crisis_packet_error("母亲严重后果合同未通过")
	var committed: Array=focus.get("resultPackets",[]).filter(func(p):return p.get("timing")=="immediate" and p.get("effects",[]).any(func(effect):return effect.get("type")=="flag_set" and effect.get("flag")==MOTHER_CRISIS_KEY and _object(effect.get("value")).get("event")==event.id))
	if committed.is_empty() or committed[0].get("status")!="applied" or committed[0].id not in state.effectLedger.appliedEffectIds or not state.history.any(func(row):return row.get("type")=="later-choice" and row.get("event")==event.id and row.get("choice")==choice.id) or consequence.outcome not in MOTHER_OUTCOMES:return mother_crisis_packet_error("没有对应的已执行选择")
	if packet.effects.size()!=2 or packet.effects[1].get("type")!="flag_set" or packet.effects[1].get("flag")!=MOTHER_CRISIS_KEY:return mother_crisis_packet_error("不接受混入的额外后果")
	if not present("母亲"):packet.status="cancelled";packet.cancelReason="母亲未实际返家，不应用家庭回收";return false
	if state.memory.get("irreversibleDay")==state.day and consequence.outcome=="assault":return mother_crisis_packet_error("同日不能追加另一场重大人物后果")
	if not valid_mother_crisis_record(packet.effects[1].get("value")):return mother_crisis_packet_error("母亲严重后果合同未通过")
	var person: Dictionary=state.people["母亲"];var hurt: bool=consequence.outcome in ["beaten","assault"];var trauma: bool=consequence.outcome=="assault"
	if hurt:person.health=maxf(1,person.health-(2 if trauma else 1));state.ailments["母亲"].wound=minf(3,state.ailments["母亲"].get("wound",0)+1)
	if trauma:state.memory.irreversibleDay=state.day
	var root: String=state.seed+":D"+str(int(state.day)+1)+":"+event.id
	deliver_fact({"factId":root,"recipients":["母亲"],"source":"母亲","scope":"本人亲历","mode":"experienced"})
	apply_spirit_fact({"factId":root,"person":"母亲","domain":"personal-experience","source":packet.id,"amount":-(4 if trauma else (3 if hurt else (2 if consequence.outcome=="turned_back" else 1))),"capLoss":2 if trauma else 0,"requiresKnowledge":true,"knowledgeScope":"本人亲历"})
	var next_record: Dictionary=packet.effects[1].value.duplicate(true);next_record.outcome=consequence.outcome;next_record.returned=true;next_record.knownScope="只知受伤返家与母亲要求暂不追问，不知侵害细节" if trauma else "母亲返家后主动说明的经过"
	next_record.knownBy=deliver_fact({"factId":root,"recipients":PEOPLE.filter(func(p):return understands(p)),"source":"母亲返家后当面说明","scope":next_record.knownScope})
	if hurt:next_record.restUntil=state.day+1+(3 if trauma else 2)
	if trauma:
		for name in next_record.knownBy:
			if name!="母亲":apply_spirit_fact({"factId":root,"person":name,"domain":"family-news","source":packet.id,"amount":-1,"requiresKnowledge":true,"knowledgeScope":next_record.knownScope})
	state.memory[MOTHER_CRISIS_KEY]=next_record;packet.status="applied";state.effectLedger.appliedEffectIds.append(packet.id)
	return true

func resolve_mother_crisis_choice(index: int) -> bool:
	if state.ended or state.day<27 or state.day>47 or state.phase!="focusEvent" or state.focus.get("choiceIndex")!=null:return false
	var event:=current_later_focus_event()
	if not event.get("motherCrisis") is Dictionary or index<0 or index>=event.choices.size():return false
	var requirement:=ordinary_pre_photo_requirement(event.choices[index])
	if not requirement.met:state.error=requirement.reason;return false
	if not later_event_eligible(event,state.focus.plan):state.error="当事人已不能参与这段现场。";return false
	var backup: Dictionary=state.duplicate(true)
	if not commit_mother_choice_core(index) or contract_error!="":state=backup;state.error="这次选择尚未结算："+contract_message;return false
	return true

func commit_mother_choice_core(index: int) -> bool:
	if state.ended or state.phase!="focusEvent" or state.focus.get("choiceIndex")!=null:return false
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if event.is_empty() or index<0 or index>=event.get("choices",[]).size():return false
	var choice: Dictionary=event.choices[index]
	for key in ["uncleCrisis","uncleBoundary","photoTransfer","photoBatch","nextMorningEffects"]:
		if js_truthy(choice.get(key)):return false
	if event.has("motherCrisis") and not prepare_mother_crisis_choice(focus,event,choice):return false
	var immediate: Array=choice.get("immediateEffects",[]).duplicate(true)
	if js_truthy(choice.get("flag")):immediate.append({"type":"flag_set","flag":choice.flag,"value":true})
	if immediate.any(func(effect):return not ordinary_pre_photo_effect_supported(effect)) or choice.get("returnEffects",[]).any(func(effect):return not ordinary_pre_photo_effect_supported(effect)):return false
	var requirement:=ordinary_pre_photo_requirement(choice)
	if not requirement.met:state.error=requirement.reason;return false
	if not later_event_eligible(event,focus.plan):state.error="当事人已不能参与这段现场。";return false
	var before:=focus_snapshot()
	apply_ordinary_pre_photo_packet(queue_focus_packet(immediate,event.id+":"+choice.id+":immediate","immediate",event.actor))
	var packet:=queue_focus_packet(choice.get("returnEffects",[]),event.id+":"+choice.id+":return","on_return",event.actor)
	if choice.get("motherCare",false):packet.motherCare={"workPacket":focus.workPackets.get("母亲"),"choice":choice.id}
	focus.carriedAssets=[]
	for effect in packet.effects:
		if effect.type=="resource_delta" and effect.amount>0:focus.carriedAssets.append({"owner":event.actor,"resource":effect.resource,"amount":effect.amount,"resultPacketId":packet.id})
	focus.cancelWork=focus.selected if choice.get("workImpact")=="complete" else null;focus.partialWork=focus.selected if choice.get("workImpact")=="partial" else null
	focus.choiceIndex=index;focus.outcomeKey="default";focus.immediateText=choice.closures.default;focus.immediateChange=describe_focus_change(before)
	focus.knowledge.player=[focus.immediateText];focus.knowledge.luo=[focus.immediateText] if focus.selected=="罗瑾" or (focus.selected=="home" and not focus.plan.rows["罗瑾"].outside) else []
	var history: Dictionary={"day":state.day,"type":"later-choice","event":event.id,"choice":choice.id}
	if event.get("conditionKind")==_object(event.get("readingVariant")).get("kind"):
		if event.has("readingVariant"):history.readingVariant=event.readingVariant
	else:history.readingVariant=null
	state.phase="focusResult";state.error=null;state.history.append(history);return true

func mother_preparation_choice_returned(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	var record: Dictionary=_object(state.memory.get(MOTHER_CRISIS_KEY));var index: Variant=focus.get("choiceIndex")
	if focus.get("eventId")!=event.id or typeof(index) not in [TYPE_INT,TYPE_FLOAT] or index<0 or index>=event.choices.size() or event.choices[int(index)]!=choice or record.get("stage")!=1 or record.get("event")!=event.id or record.get("day")!=state.day+1 or record.get("choice")!=choice.id or record.get("returned")!=true:return false
	if not state.history.any(func(h):return h.get("type")=="later-choice" and h.get("day")==state.day and h.get("event")==event.id and h.get("choice")==choice.id):return false
	for timing in ["immediate","on_return"]:
		var id: String=state.seed+":D"+str(int(state.day)+1)+":"+event.id+":"+choice.id+(":immediate" if timing=="immediate" else ":return")
		if not focus.resultPackets.any(func(p):return p.id==id and p.timing==timing and p.subjectId=="母亲" and p.status=="applied" and p.id in state.effectLedger.appliedEffectIds):return false
	return true

func finish_mother_crisis_diary(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	if focus.day!=48:return _chapter9_parent_17_finish_mother_crisis_diary(focus,event,choice)
	var r: Dictionary=_object(state.memory.get(MOTHER_CRISIS_KEY))
	if not focus.get("diaryAllowed",false) or not js_truthy(r.get("returned")) or float(r.get("stage",0))<2 or "罗瑾" not in r.get("knownBy",[]):return true
	var text: String
	if not state.people["母亲"].alive or js_truthy(state.people["母亲"].get("permanentLost")):text="娘那次回来以后说过的话，我还记着。如今她的位置已经空了，我不能替她补出那一日没有讲的部分，也不能用后来失去她，改写她曾怎样选择、需要怎样的照应。"
	elif not present("母亲"):text="娘现在不在棚里，我没有今天的新消息。她那次回来以后说过的话仍留在这里；记着从前，不能算作已知道她眼下的去处。"
	elif chapter_json_equal(r.stage,2):text="娘那次遇险回来，有些话至今没有再接着讲。我没有把沉默补写成事情已经过去，也没有因今天要清点留下的东西，便催她交出一个完整经过。"
	else:text="后来陪娘坐过的那一阵，我仍记着。她愿意说什么、不愿说什么，不该由我为了把故事写齐来决定。眼下能够留下的证据按实际清点，而娘也不是其中一件用来证明我已经懂事的东西。"
	if not focus.get("chapterDiary") is Array:focus.chapterDiary=[]
	focus.chapterDiary.append(text)
	if focus.get("webM4EndReadingRevision")=="WebM4-D45D49-v1" and chapter_json_equal(r.stage,3) and r.get("choice")=="treat":
		for i in range(focus.chapterDiary.size()):
			if focus.chapterDiary[i].begins_with("后来陪娘坐过的那一阵"):focus.chapterDiary[i]=focus.chapterDiary[i].replace("后来陪娘坐过的那一阵，我仍记着。","后来按娘愿意的范围处理伤处的那一回，我仍记着。")
	return true

func resolve_mother_care_choice(index: int) -> bool:
	if state.ended or state.day<25 or state.day>30 or state.phase!="focusEvent" or state.focus.get("choiceIndex")!=null:return false
	var event:=current_later_focus_event()
	if not event.get("motherCare",false) or index<0 or index>=event.choices.size():return false
	var requirement:=ordinary_pre_photo_requirement(event.choices[index])
	if not requirement.met:state.error=requirement.reason;return false
	if not later_event_eligible(event,state.focus.plan):state.error="当事人已不能参与这段现场。";return false
	var backup: Dictionary=state.duplicate(true)
	if not commit_mother_choice_core(index) or contract_error!="":state=backup;state.error="这次选择尚未结算："+contract_message;return false
	return true

var chapter_six_diary_bank: Dictionary={}

func finish_chapter_six_diary(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	var result: bool=_expedition_parent_12_finish_chapter_six_diary(focus,event,choice)
	if result:finish_expedition_grandfather_diary(focus)
	return result

func settle_mother_episode_return() -> bool:
	# D11-D17 selected custody only. Later photos, crises, excursions and owner arrivals
	# on unrelated scenes remain gated until their complete contracts are implemented.
	if state.ended or state.day<25 or state.day>47:return false
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if event.is_empty() or not (event.get("motherCare",false) or event.has("motherCrisis")):return false
	if focus.get("settled",false):state.phase="focusReturn";return true
	if state.phase!="focusResult" or focus.get("choiceIndex")==null or int(focus.choiceIndex)<0 or int(focus.choiceIndex)>=event.choices.size():return false
	if focus.plan.get("key") in ["expeditionSearch","pigeonPickup"]:return false
	if focus.plan.rows.values().any(func(row):return row.get("type") not in ["home","relief","wood","water","burial","registration","rest","committee","photo"]):return false
	for key in ["uncleBoundaryReturned","uncleCrisisR4b","grandfatherHomeR18"]:
		if state.memory.get(key)!=null:return false
	if focus.resultPackets.any(func(packet):return packet.effects.any(func(effect):return not ordinary_pre_photo_effect_supported(effect) and effect.get("type")!="mother_crisis_consequence")):return false
	var choice: Dictionary=event.choices[int(focus.choiceIndex)]
	var backup:=state.duplicate(true);var before:=focus_snapshot();var lines: Array=[]
	for row in focus.plan.rows.values():
		var packets: Array=focus.resultPackets.filter(func(packet):return packet.id==focus.workPackets.get(row.name));var packet: Dictionary={} if packets.is_empty() else packets[0]
		if not present(row.name) or row.get("inactive",false) or focus.get("cancelWork")==row.name:
			if not packet.is_empty():packet.status="cancelled";packet.cancelReason="未能完成或当事人未返家"
			if focus.get("cancelWork")==row.name and present(row.name) and row.outside:lines.append(row.name+"回到了棚边，原定的差事没有做完。")
			continue
		if not packet.is_empty():
			if focus.get("partialWork")==row.name:
				for effect in packet.effects:
					if effect.get("type")=="photo_progress" and effect.get("op")=="skill_delta":effect.value/=2
					elif typeof(effect.get("amount")) in [TYPE_INT,TYPE_FLOAT]:effect.amount=maxf(1,effect.amount-1)
			apply_ordinary_pre_photo_packet(packet)
		if row.outside and row.type!="photo":lines.append(later_return_line(row.name,"partial" if focus.get("partialWork")==row.name else "complete"))
		if row.type=="burial":
			apply_ordinary_pre_photo_packet(queue_focus_packet([{"type":"flag_set","flag":"burialExperienced","value":true}],"work:burial:experience","on_return","罗瑾"))
			if focus.selected!="罗瑾":focus.backgroundDiary="今天我跟队回来，没有在路上独自停留。我没有亲眼看见杀戮，却面对了它留下的后果。回到棚里以后，我想先看看家人还在不在眼前，并不想把一路所见立刻从头说完。"
		if row.type=="registration":
			var inquiry: bool=row.get("registrationProtocol")=="inquiry-I3e-4b"
			apply_ordinary_pre_photo_packet(queue_focus_packet([{"type":"flag_set","flag":"registrationInquiry" if inquiry else "registered","value":"mother"}],"work:registration:inquiry" if inquiry else "work:registration:paper","on_return","母亲"))
		if row.type=="photo" and row.outside:lines.append("罗瑾只做完一部分杂活便离店回到棚边；没做完的那一段不能算上。" if focus.get("partialWork")==row.name else "罗瑾做完今天分到的杂活，离店回到棚边；主要冲洗仍由蒋孝义负责。")
	for packet in focus.resultPackets:
		if packet.timing=="on_return" and packet.status=="pending":apply_ordinary_pre_photo_packet(packet)
	if contract_error!="":state=backup;state.error="返家尚未结算完成："+contract_message;return false
	if not settle_chapter_five_default_node(focus,event,lines):state=backup;return false
	var known: bool=mother_preparation_return_allowed(focus,event) and understands("罗瑾") and later_event_eligible(event,focus.plan) and (not event.get("motherCare",false) or mother_care_has_returned(focus))
	if known:state.knowledgeFacts.append({"id":event.id+":return-knowledge","day":state.day+1,"source":event.actor,"knownBy":["罗瑾"],"scope":"选择结果的可转述部分","text":choice.diaries.default})
	focus.diaryAllowed=known;focus.knowledge.luo=[choice.diaries.default] if known else []
	if known and focus.selected!="罗瑾" and (focus.selected!="home" or focus.plan.rows["罗瑾"].outside) and not lines.any(func(line):return line.begins_with(event.actor)):lines.append(event.actor+"在家里说起今天遇到的事。")
	focus.returnText=" ".join(lines);focus.returnChange=describe_focus_change(before);focus.settled=true;focus.carriedAssets=[];state.phase="focusReturn"
	if not finish_chapter_six_diary(focus,event,choice):state=backup;return false
	if event.get("motherCare",false) and focus.diaryAllowed and focus.get("chapterDiary") is Array:focus.chapterDiary=focus.chapterDiary.slice(1)
	if event.has("motherCrisis") and not finish_mother_crisis_diary(focus,event,choice):state=backup;return false
	state.history.append({"day":state.day,"type":"later-return","event":event.id,"change":focus.returnChange})
	return true

func _chapter5_parent_6_process_pre_photo_story_morning() -> bool:
	if state.day<10 or state.ended or not state.people["罗瑾"].alive:return true
	if state.day>24:return false
	for key in ["motherCareReturned","uncleBoundaryReturned","motherCrisisR4a","uncleCrisisR4b","grandfatherHomeR18"]:
		if state.memory.get(key)!=null:return false
	var initial=JSON.parse_string(FileAccess.get_file_as_string("res://data/story_initial_state.json"))
	if not state.has("fixedNodeStates"):state.fixedNodeStates={}
	for id in initial.fixedNodeStates:
		if not state.fixedNodeStates.has(id):state.fixedNodeStates[id]=initial.fixedNodeStates[id].duplicate(true)
	for key in ["pendingMorningPackets","storyMorningDays","knowledgeFacts"]:
		if not state.has(key):state[key]=[]
	var date: int=int(state.day)+1
	if state.storyMorningDays.any(func(value):return value==date):return true
	if state.pendingMorningPackets.any(func(packet):return packet.get("scheduledDay",INF)<=state.day and packet.get("status")=="pending"):return false
	if date>=22 and not state.photo.employed and not chapter_five_node_done(state.fixedNodeStates.employ) and not understands("罗瑾") and ["母亲","安仁叔叔","外祖父"].any(func(person):return understands(person)) and not js_truthy(state.memory.get("employment_offer_pending")):
		if not state.has("storySystemPackets"):state.storySystemPackets=[]
		var id: String=state.seed+":D"+str(date)+":system:employment-offer-pending"
		var found: Array=state.storySystemPackets.filter(func(packet):return packet.id==id)
		var packet: Dictionary={"id":id,"timing":"next_morning","subjectId":"family","effects":[{"type":"flag_set","flag":"employment_offer_pending","value":true}],"status":"pending"} if found.is_empty() else found[0]
		if found.is_empty():state.storySystemPackets.append(packet)
		apply_ordinary_pre_photo_packet(packet)
		state.morningResults.append("照相馆帮工的消息先由在场的大人接下；罗瑾还不能听清规矩，今天不算已经上工。")
	for id in ["names","sources"]:
		var node: Dictionary=state.fixedNodeStates[id]
		if date>node.due and not chapter_five_node_done(node) and not node.eligibleDays.is_empty():state.morningResults.append({"names":"前些天记下的寻人消息，仍有来处没问清。","sources":"几张纸上的听说与亲见，还需要分开放。"}[id])
	if date==25 and not js_truthy(state.memory.get("motherCareNoticeDay")) and can_work_later("母亲"):
		if not state.has("storySystemPackets"):state.storySystemPackets=[]
		var id: String=state.seed+":D25:system:mother-care-notice"
		var found: Array=state.storySystemPackets.filter(func(packet):return packet.id==id)
		var packet: Dictionary={"id":id,"timing":"next_morning","subjectId":"family","effects":[{"type":"flag_set","flag":"motherCareNoticeDay","value":25}],"status":"pending"} if found.is_empty() else found[0]
		if found.is_empty():state.storySystemPackets.append(packet)
		apply_ordinary_pre_photo_packet(packet)
		state.morningResults.append("棚边有人来问，领物的地方有没有人能照看走不动的伤者。母亲问清，那边有人办发放，却不能一直停下来照应每一个人。她记下了这句话，又把领物时要用的粮袋收在手边，没有答应立刻出去找人。")
		state.knowledgeFacts.append({"id":"mother-care.notice","day":25,"knownBy":["player","母亲"]+(["罗瑾"] if understands("罗瑾") else []),"scope":"情境演绎：领物处照应不足的提醒，不是医疗岗位或安全保证"})
	state.storyMorningDays.append(state.day+1)
	return true


func _chapter5_parent_7_make_parcel_event(focus: Dictionary,admission: Dictionary,decorated: bool=true) -> Dictionary:
	var date: int=int(focus.day)+1;var prior: Variant=state.memory.get(PARCEL_KEY)
	if not admission.get("allowed",false) or not admission.get("home") is Array or admission.get("actor") not in admission.home or date<25 or date>48:return {}
	if prior!=null and not valid_parcel_record(prior):return {}
	var stage: int=1 if prior==null else int(prior.stage)+1
	if stage>3 or stage==1 and date>38:return {}
	var mask:=0
	for person in admission.home:
		if person not in PEOPLE or not present(person):return {}
		mask|=1<<PEOPLE.find(person)
	var sent: bool=prior.sent if prior!=null else false;var delivered: bool=sent and prior.roll<0.8
	if parcel_prose.is_empty():parcel_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/parcel_prose.json"))
	var key: String=JSON.stringify([stage,mask,admission.actor,sent,delivered,state.tools.rope])
	if not parcel_prose.variants.has(key):return {}
	var event: Dictionary=decode_home_content((parcel_prose.events if decorated else parcel_prose.raw_events)[parcel_prose.variants[key]],parcel_prose)
	if stage==1 and state.rice<=0:event.intro=event.intro.replace("家里有米，但匀出一份，今晚能用的便少一份。","家里的米粮已经用尽，不能只因听着急便答应拿出没有的东西。")
	event.id="neighbour.parcel.R2b.D"+str(date)+"."+str(stage);event.neighbourParcel.prior=null if prior==null else prior.duplicate(true)
	if stage==3 and tool_available("axe"):event.intro=event.intro.replace("手边没有斧头，只能挑已经松开的部分，不能为多拿一点钻到压着的东西下面。","家里有斧头，能够从外侧将松处拆开，多留下些可以烧的部分。斧头不会把朽木劈成好木，也不能保证足够用很久。")
	if stage==3:event.neighbourParcel.woodRoll=float(RNG.hash_seed(state.seed+"|neighbour-parcel|wood-v1"))/4294967296.0
	if decorated:
		event.readingVariant.prior=null if prior==null else {"lent":js_truthy(prior.get("lent")),"sent":prior.sent,"support":js_truthy(prior.get("support")),"follow":prior.get("follow") if js_truthy(prior.get("follow")) else null}
		event.readingVariant.sourceEvent=event.id;event.readingVariant.day=focus.day+1
	return event


var parcel_webm3_prose: Dictionary={}

var parcel_memory_prose: Dictionary={}

var chapter_six_reading_revisions: Dictionary={}

var chapter_six_maintenance_revisions: Array=[]

func apply_chapter_six_reading_revisions(focus: Dictionary) -> void:
	if focus.day!=state.day:return
	if chapter_six_reading_revisions.is_empty():chapter_six_reading_revisions=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_six_reading_revisions.json"))
	for template in chapter_six_reading_revisions["r4v9-return-repair-prose-v1"].repairDiaries:
		var event: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get("home")));var row: Dictionary=_object(focus.plan.rows.get(template.actor))
		if template.day!=focus.day+1 or event.get("id")!=template.eventId or ["nodeId","chapter","photoMid","photoEnd","neighbourhood","neighbourParcel","uncleCrisis","motherCrisis","recovery"].any(func(key):return js_truthy(event.get(key))) or _object(event.get("readingVariant")).get("scene")!=template.scene or _object(event.get("readingVariant")).get("revision")!=template.readingRevision:continue
		if row.is_empty() or row.get("outside",false) or row.get("inactive",false) or not present(template.actor) or not understands(template.actor) or not understands("罗瑾"):continue
		if not template.sourceContract.keys().all(func(key):return chapter_json_equal(event.get(key),template.sourceContract[key])) or not event.participants.all(func(person):return present(person) and _object(focus.plan.rows.get(person)).get("outside")==false):continue
		for choice in event.choices:
			if choice.id==template.choiceId:choice.diaries.default=template.replacement
	for revision in ["r4v9-work-diary-v1","r4v9-return-repair-prose-v1"]:
		var entries: Array=[]
		for template in chapter_six_reading_revisions[revision].workParagraphs:
			var row: Dictionary=_object(focus.plan.rows.get(template.actor));var event: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get(template.actor)))
			if focus.day!=template.day-1 or row.get("type")!=template.kind or not row.get("outside",false) or row.get("inactive",false) or not present(template.actor) or event.get("chapter")!=template.chapter or event.get("target")!=template.actor or event.get("actor")!=template.actor:continue
			if revision=="r4v9-work-diary-v1":entries.append({"actor":template.actor,"kind":template.kind,"chapter":template.chapter,"source":template.source,"replacement":template.replacement})
			else:
				if event.get("id")!=template.eventId or event.get("conditionKind")!=template.kind or ["nodeId","uncleCrisis","motherCrisis","expeditionSearch","r4v7P1"].any(func(key):return js_truthy(event.get(key))):continue
				entries.append(template.duplicate(true))
		var key: String="r4v9WorkDiaryText" if revision=="r4v9-work-diary-v1" else "r4v9ReturnRepairText"
		if not entries.is_empty() and not focus.has(key):focus[key]={"revision":revision,"day":focus.day+1,"entries":entries}

func apply_chapter_six_maintenance_revision(focus: Dictionary) -> void:
	var row: Dictionary=_object(focus.plan.rows.get("罗瑾"))
	if state.saveVersion!=24 or state.ended or state.day!=focus.day or focus.plan.day!=focus.day or row.is_empty() or row.get("inactive",false) or not present("罗瑾") or not understands("罗瑾"):return
	if chapter_six_maintenance_revisions.is_empty():chapter_six_maintenance_revisions=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_six_maintenance_revisions.json"))
	var targets: Array=chapter_six_maintenance_revisions.filter(func(t):return t.day==focus.day+1)
	if targets.is_empty():return
	var t: Dictionary=targets[0];var event: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get("home")))
	if row.get("outside",false)!=t.get("luoOutside",true) or event.get("id")!=t.eventId or event.get("actor")!=t.actor or not present(t.actor) or not understands(t.actor):return
	var v: Dictionary=_object(event.get("readingVariant"))
	if v.get("revision")!="R24-experience-polish-v1" or v.get("group")!="r24-maintenance" or v.get("kind")!="maintenance" or v.get("scene")!=t.scene or v.get("index")!=t.index:return
	var source: Dictionary=event.duplicate(true);source.erase("readingVariant")
	if chapter_json_equal(source,t.expected):event.choices[0].diaries.default=t.replacement

func _chapter5_parent_8_apply_chapter_maintenance(focus: Dictionary) -> void:
	if state.day<17:_chapter4_parent_3_apply_chapter_maintenance(focus);return
	var current: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get("home")))
	if current.is_empty() or state.wood<=0:return
	var low: bool=current.id.ends_with(".maintenance");var fresh: bool=(current.has("neighbourhood") and current.neighbourhood.get("stage")==1 and not js_truthy(current.neighbourhood.get("prior"))) or (current.has("neighbourParcel") and current.neighbourParcel.get("stage")==1 and not js_truthy(current.neighbourParcel.get("prior"))) or current.id.begins_with("neighbour.day.R2b.")
	if not low and not (state.shelter<21 and fresh):return
	var raw:=make_pre_photo_condition_home(focus)
	if raw.get("conditionKind")!="maintenance":return
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].get("outside",false));var adults: Array=home.filter(func(person):return person!="罗瑾");var actor: String=adults[0] if not adults.is_empty() else "罗瑾"
	var event: Dictionary=raw.duplicate(true);event.later=true;event.historyClass="情境演绎；白天家庭维护为游戏安排，不是历史日期事实";event.id="later.D"+str(int(state.day)+1)+".home."+raw.id;event.target="home";event.actor=actor;event.participants=home.duplicate();event.homeParticipants=home.duplicate()
	if not low:focus.dayMaintenanceDisplaced={"id":current.id,"title":current.title,"reason":"shelter_below_21_with_wood","freshNeighbour":true}
	focus.laterEvents[event.id]=event;focus.plan.eventIds.home=event.id


func _chapter5_parent_8_bind_day_eleven_twelve(focus: Dictionary) -> bool:
	if state.day<17:return _chapter4_parent_3_bind_day_eleven_twelve(focus)
	if int(state.day) not in range(10,24) or focus.plan.get("key") in ["pigeonPickup","expeditionSearch"]:return false
	for key in ["neighbourParcelR2b"]:
		if js_truthy(state.memory.get(key)):return false
	var fresh: bool=focus.get("laterEvents",{}).is_empty()
	focus.laterEvents={};focus.plan.eventIds={};focus.plan.photoMidContract="photo-mid-v1"
	for target in focus.plan.targets:
		var event: Dictionary=make_bound_chapter_five_node(focus) if target==focus.plan.primary and js_truthy(focus.plan.get("nodeId")) else (make_chapter_home_base(focus) if target=="home" else make_pre_photo_outdoor_event(focus,target))
		if event.is_empty():return false
		focus.laterEvents[event.id]=event;focus.plan.eventIds[target]=event.id
		if target=="home" and event.get("conditionKind")=="recovery":
			var offer:=pre_photo_recovery_offer(focus)
			if offer.is_empty():return false
			var prior_care:=make_pre_photo_care_event(focus,true)
			if prior_care.is_empty():return false
			focus.laterEvents[prior_care.id]=prior_care
			focus.plan.rows[offer.actor].label+="；邻棚有人带来物品询问换粮"
			focus.plan.recoveryOffer={"kind":offer.kind,"item":offer.item,"cost":offer.cost,"day":offer.day}
	if not bind_chapter_rope(focus):return false
	bind_chapter_five_neighbour_day(focus)
	apply_chapter_maintenance(focus)
	var base_home: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get("home")))
	focus.homeAdmissionAudit=home_reception_status(focus);focus.homeAdmissionAudit.eventId=base_home.get("id");focus.homeAdmissionAudit.actor=base_home.get("actor")
	focus.webR3NeighbourRevision="WebR3-neighbour-prose-v1"
	if base_home.has("neighbourhood"):
		var decorated:=make_rope_event(focus,{"allowed":true,"actor":base_home.actor,"home":focus.homeAdmissionAudit.home,"resting":focus.homeAdmissionAudit.resting})
		if decorated.is_empty():return false
		base_home.clear()
		for key in decorated:base_home[key]=decorated[key]
	apply_rope_memory_echo(focus,base_home)
	var message_admission:=message_thread_admission(focus)
	focus.messageAdmissionAudit={"revision":"WebR5-messages-v1","allowed":message_admission.allowed,"reason":message_admission.reason,"stage":message_admission.get("stage") if js_truthy(message_admission.get("stage")) else null,"actor":message_admission.get("actor") if js_truthy(message_admission.get("actor")) else null}
	if message_admission.allowed:
		var old: Dictionary=focus.laterEvents[focus.plan.eventIds.home];var event:=make_message_thread_event(focus,message_admission)
		if event.is_empty():return false
		focus.messageDisplaced={"id":old.id,"title":old.title};focus.laterEvents[event.id]=event;focus.plan.eventIds.home=event.id
	var same_day:=custody_handoff_admission(focus)
	focus.custodyAdmissionAudit={"revision":CUSTODY_HANDOFF_REV,"allowed":same_day.allowed,"reason":same_day.reason,"actor":same_day.get("actor") if js_truthy(same_day.get("actor")) else null,"kind":same_day.get("kind") if js_truthy(same_day.get("kind")) else null}
	if same_day.allowed:
		var event:=make_custody_handoff_event(focus,same_day)
		if event.is_empty():return false
		var old: Dictionary=focus.laterEvents[focus.plan.eventIds.home];focus.custodyDisplaced={"id":old.id,"title":old.title};focus.laterEvents[event.id]=event;focus.plan.eventIds.home=event.id
	focus.custodyNightRevision=CUSTODY_NIGHT_REV;var overnight:=custody_night_admission(focus)
	focus.custodyNightAdmission={"revision":CUSTODY_NIGHT_REV,"allowed":overnight.allowed,"reason":overnight.reason,"actor":overnight.get("actor") if js_truthy(overnight.get("actor")) else null,"kind":overnight.get("kind") if js_truthy(overnight.get("kind")) else null}
	if overnight.allowed:
		var event:=make_custody_night_event(focus,overnight)
		if event.is_empty():return false
		var old: Dictionary=focus.laterEvents[focus.plan.eventIds.home];focus.custodyNightDisplaced={"id":old.id,"title":old.title};focus.laterEvents[event.id]=event;focus.plan.eventIds.home=event.id
	if focus.plan.eventIds.has("home"):connect_pre_photo_qian(focus,focus.laterEvents[focus.plan.eventIds.home]);apply_rope_editorial(focus,focus.laterEvents[focus.plan.eventIds.home])
	focus.webM2ReadingRevision="WebM2-D18D24-v1";apply_middle_reading_context(focus)
	if fresh:apply_chapter_five_reading_revisions(focus);apply_d22_local_text(focus)
	return true


func _chapter5_parent_8_ensure_day_eleven_twelve_focus() -> Dictionary:
	if state.day<17:return _chapter4_parent_3_ensure_day_eleven_twelve_focus()
	if state.ended or int(state.day) not in range(10,24) or not present("罗瑾"):return {}
	if state.focus.get("day")==state.day and state.focus.get("plan")!=null:return state.focus
	var backup:=state.duplicate(true);var template=JSON.parse_string(FileAccess.get_file_as_string("res://data/native_base_state_template.json"))
	state.focus=template.focus.duplicate(true);var focus: Dictionary=state.focus;focus.day=state.day;focus.grandfatherRecoveryRevision="R4c";focus.characterRevision="R4a";focus.uncleRevision="R4b";focus.neighbourhoodRevision="R2b";focus.integrationReadingRevision="FINAL-INTEGRATION";focus.middleReadingRevision="I3e-4c1"
	focus.plan=make_pre_photo_plan()
	if focus.plan.is_empty():state=backup;return {}
	focus.knowledge={"player":[],"luo":[]};focus.resultPackets=[]
	if not bind_day_eleven_twelve(focus):state=backup;return {}
	focus.workPackets={}
	for row in focus.plan.rows.values():
		if not row.get("inactive",false) and (not row.base.is_empty() or (row.type=="photo" and row.outside and state.photo.employed)):
			var effects: Array=[]
			for resource in row.base:effects.append({"type":"shelter_delta","amount":row.base[resource]} if resource=="shelter" else {"type":"resource_delta","resource":str(resource),"amount":row.base[resource]})
			if row.type=="photo" and row.outside and state.photo.employed:effects.append({"type":"photo_progress","op":"skill_delta","value":0.5})
			focus.workPackets[row.name]=queue_focus_packet(effects,"work:"+row.name,"on_return",row.name).id
	var snapshots=JSON.parse_string(FileAccess.get_file_as_string("res://data/later_public_family_snapshots.json"))
	if snapshots.has(str(int(state.day))):focus.r4v3PublicFamilyText=snapshots[str(int(state.day))].duplicate(true)
	return focus


func _chapter5_parent_8_make_chapter_home_base(focus: Dictionary) -> Dictionary:
	if state.day<17:return _chapter4_parent_3_make_chapter_home_base(focus)
	if state.day>23 or "home" not in focus.plan.targets or js_truthy(focus.plan.get("nodeId")):return {}
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].outside)
	if home.is_empty():return {}
	if home.any(func(person):return not focus_fit(person)):return make_pre_photo_care_event(focus)
	var adults: Array=home.filter(func(person):return person!="罗瑾");var speaker: String=adults[0] if not adults.is_empty() else "罗瑾"
	var event: Dictionary={};var raw: Dictionary={}
	if focus.plan.primary=="home":
		if later_scene_shells.is_empty():later_scene_shells=JSON.parse_string(FileAccess.get_file_as_string("res://data/later_scene_shells.json"))
		var key: String=focus.plan.key
		if key in ["apprentice","oldphoto","materials","register","inquiry"]:key="papers"
		event=later_scene_shells.get(key,later_scene_shells.papers).duplicate(true)
	else:
		raw=make_pre_photo_condition_home(focus);event=raw.duplicate(true)
	if event.is_empty():return {}
	var suffix: String=event.id;var recipients: Array=["母亲","安仁叔叔","外祖父"].filter(func(person):return person in home and understands(person))
	event.id="later.D"+str(int(state.day)+1)+".home."+suffix;event.target="home";event.later=true;event.actor=speaker;event.participants=[speaker];event.homeParticipants=[speaker];event.recipient=null if recipients.is_empty() else recipients[0];event.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":state.photo.evidence,"photoPrints":state.photo.prints};event.historyClass="F：普通难民情境演绎；城市阶段事实另列，非罗家逐日实录";event.chapter="I2b-5"
	if chapter_five_home_prose.is_empty():chapter_five_home_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_five_home_prose.json"))
	var mask:=0
	for person in home:mask|=1<<PEOPLE.find(person)
	var key: String=JSON.stringify([int(state.day),mask,state.photo.employed])
	if not chapter_five_home_prose.variants.has(key):return {}
	var variant: Dictionary=chapter_five_home_prose.variants[key]
	if variant.has("fallback"):
		var fallback:=make_pre_photo_condition_home(focus);var id: String=event.id
		if fallback.is_empty():return {}
		for field in fallback:event[field]=fallback[field]
		event.id=id;event.target="home";event.later=true;event.chapter="I2b-5"
		for choice in event.choices:choice.later=true
	else:
		var layer: Dictionary=decode_home_content(chapter_five_home_prose.events[variant.event],chapter_five_home_prose)
		for field in layer:event[field]=layer[field]
		event.erase("conditionKind")
	return event


func _chapter5_parent_8_make_pre_photo_care_event(focus: Dictionary,base_only: bool=false) -> Dictionary:
	if state.day<17:return _chapter4_parent_3_make_pre_photo_care_event(focus,base_only)
	if state.day<10 or state.day>23 or "home" not in focus.plan.targets or js_truthy(focus.plan.get("nodeId")):return {}
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].get("outside",false));var sick: Array=home.filter(func(person):return not focus_fit(person))
	if sick.is_empty():return {}
	sick.sort_custom(func(a,b):return PEOPLE.find(a)<PEOPLE.find(b) if state.people[a].health==state.people[b].health else state.people[a].health<state.people[b].health)
	var patient: String=sick[0];var others: Array=home.filter(func(person):return person!="罗瑾" and understands(person));var speakers: Array=home.filter(func(person):return understands(person));var actor: String=others[0] if not others.is_empty() else (speakers[0] if not speakers.is_empty() else home[0])
	var event: Dictionary={};var suffix: String="fallback.d"+str(int(state.day)+1)+".home.care"
	if focus.plan.primary=="home":
		if later_scene_shells.is_empty():later_scene_shells=JSON.parse_string(FileAccess.get_file_as_string("res://data/later_scene_shells.json"))
		var key: String=focus.plan.key
		if key in ["apprentice","oldphoto","materials","register","inquiry"]:key="papers"
		if key=="burial":key="returner"
		if key=="shelter" and state.shelter>=50:key="papers"
		event=later_scene_shells.get(key,later_scene_shells.papers).duplicate(true);suffix=event.id
	var recipients: Array=["母亲","安仁叔叔","外祖父"].filter(func(person):return person in home and understands(person))
	event.id="later.D"+str(int(state.day)+1)+".home."+suffix;event.title="";event.intro="";event.later=true;event.historyClass="F：普通难民情境演绎；城市阶段事实另列，非罗家逐日实录";event.target="home";event.actor=actor;event.participants=home.duplicate();event.homeParticipants=home.duplicate();event.recipient=null if recipients.is_empty() else recipients[0];event.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":state.photo.get("evidence",0),"photoPrints":state.photo.get("prints",0)};event.chapter="I2b-5";event.conditionKind="care"
	var repairers: Array=home.filter(func(person):return person!=patient and can_work_later(person))
	var raw_care:=pre_photo_raw_care_content(home,patient,repairers)
	if raw_care.is_empty():return {}
	for field in ["title","intro","choices"]:event[field]=raw_care[field]
	for choice in event.choices:choice.later=true
	if base_only:return event

	var offer:=pre_photo_recovery_offer(focus)
	if not offer.is_empty():
		event.id+=".exchange";event.actor=offer.actor;event.conditionKind="recovery"
		var medicine: bool=offer.item!=null;var name: String=TOOL_NAMES[offer.item] if medicine else "木料";var goods: String=name+"一份" if medicine else "能用的短木三份"
		var exchange: Dictionary={"id":"exchange","label":"用米粮"+str(int(offer.cost))+"份换"+goods,"hint":"米粮－"+str(int(offer.cost))+"；"+(name+"＋1，晚间另行用药，不当场治愈" if medicine else "木料＋3，不自动生火或修棚")+"。","requiresResources":{"rice":offer.cost},"immediateEffects":[{"type":"resource_delta","resource":"rice","amount":-offer.cost},{"type":"item_gain","item":offer.item} if medicine else {"type":"resource_delta","resource":"wood","amount":3}],"closures":{"default":""},"diaries":{"default":""}}
		event.choices=[exchange,event.choices[0],event.choices[1]]
	if not chapter_five_care_reader.decorate(self,focus,event):return {}
	return event


func _chapter5_parent_8_make_pre_photo_condition_home(focus: Dictionary) -> Dictionary:
	if state.day<17:return _chapter4_parent_3_make_pre_photo_condition_home(focus)
	if state.day<10 or state.day>23:return {}
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].get("outside",false))
	if home.is_empty() or home.any(func(person):return not focus_fit(person)):return {}
	var mask:=0
	for person in home:mask|=1<<PEOPLE.find(person)
	var kind: String="weather" if current_weather().get("severe",false) else ("absence" if household_presence_mask()!=15 else ("maintenance" if state.shelter<41 and state.wood>0 else "home"))
	var prior: Array=[];var index:=0;var stock:=0;var gain:=0
	if kind in ["weather","maintenance"]:
		prior=state.history.filter(func(row):return row.get("day",state.day)<state.day and _object(row.get("readingVariant")).get("revision")=="R24-experience-polish-v1" and row.readingVariant.kind==kind)
		var last: Dictionary={}
		for row in prior:last[int(row.readingVariant.index)]=row.day
		var offset: int=RNG.hash_seed(state.seed+"|R24-experience-polish-v1|"+kind)%3;index=-1
		for step in range(3):
			var candidate: int=(offset+step)%3
			if not last.has(candidate):index=candidate;break
		if index<0:
			var candidates: Array=[0,1,2];candidates.sort_custom(func(a,b):return a<b if last[a]==last[b] else last[a]<last[b]);index=candidates[0]
		if kind=="weather":stock=(1 if state.wood>=1 else 0)+(2 if state.shelter>=50 else 0)+(4 if state.shelterItems.oilcloth else 0)
		else:
			var speakers: Array=home.filter(func(person):return person!="罗瑾");gain=formal_repair_gain(int(state.day),speakers[0] if not speakers.is_empty() else "罗瑾")
	else:
		prior=state.history.filter(func(row):return row.get("day",state.day)<state.day and _object(row.get("readingVariant")).get("group")=="shelter")
		index=(RNG.hash_seed(state.seed+":condition-story:shelter")+prior.size())%3
	if chapter_five_condition_home_prose.is_empty():chapter_five_condition_home_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_five_condition_home.json"))
	var key:=JSON.stringify([int(state.day),mask,kind,index,stock,gain])
	if not chapter_five_condition_home_prose.variants.has(key):return {}
	var event: Dictionary=decode_home_content(chapter_five_condition_home_prose.events[chapter_five_condition_home_prose.variants[key]],chapter_five_condition_home_prose)
	event=_replace_content_token(event,"§WEATHER_NAME§",current_weather().name)
	if event.has("readingVariant"):event.readingVariant.previous=null if prior.is_empty() else prior.back().day
	return event


func _chapter5_parent_8_make_pre_photo_outdoor_event(focus: Dictionary,target: String) -> Dictionary:
	if state.day<17:return _chapter4_parent_3_make_pre_photo_outdoor_event(focus,target)
	if state.day<10 or state.day>23 or target not in PEOPLE or target not in focus.plan.targets or (js_truthy(focus.plan.get("nodeId")) and target==focus.plan.primary):return {}
	var row: Dictionary=_object(focus.plan.rows.get(target));var type: String=row.get("type","")
	if not row.get("outside",false) or row.get("inactive",false) or not present(target):return {}
	if not ((target=="罗瑾" and type in ["water","burial","photo"]) or (target=="外祖父" and type=="wood") or (target=="母亲" and type in ["relief","registration"]) or (target=="安仁叔叔" and type=="committee")):return {}
	var prior: Array=state.history.filter(func(history):return history.get("day",state.day)<state.day and _object(history.get("readingVariant")).get("group")=="water") if type=="water" else []
	var index: int=(RNG.hash_seed(state.seed+":condition-story:water")+prior.size())%3 if type=="water" else 0
	var previous: String="none" if prior.is_empty() else "many"
	if prior.size()==1:previous=prior[0].get("choice","") if prior[0].get("choice") in ["help","pole_help"] else "carry_home"
	var tool: String=state.memory.get("burialTool","none") if type=="burial" else "none"
	if tool not in ["shovel","rope"] or not tool_available(tool):tool="none"
	if chapter_five_outdoor_prose.is_empty():chapter_five_outdoor_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_five_outdoor_prose.json"))
	var key:=JSON.stringify([int(state.day),target,type,index,state.water>=2 if type=="water" else false,tool_available("axe") if type=="wood" else false,tool,previous,type=="photo" and focus.plan.primary==target])
	if not chapter_five_outdoor_prose.variants.has(key):return {}
	var event: Dictionary=decode_home_content(chapter_five_outdoor_prose.events[chapter_five_outdoor_prose.variants[key]],chapter_five_outdoor_prose)
	var home: Array=PEOPLE.filter(func(person):return present(person) and not _object(focus.plan.rows.get(person)).get("outside",false))
	var recipients: Array=["母亲","安仁叔叔","外祖父"].filter(func(person):return person in home and understands(person))
	event.recipient=null if recipients.is_empty() else recipients[0]
	event.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":state.photo.get("evidence",0),"photoPrints":state.photo.get("prints",0)}
	if type=="water" and event.has("readingVariant"):
		event.readingVariant.previous=null if prior.is_empty() else prior.back().day
		event.readingVariant.narratorHere="罗瑾" in home
	return event


func _chapter5_parent_8_pre_photo_raw_care_content(home: Array,patient: String,repairers: Array) -> Dictionary:
	if state.day<17:return _chapter4_parent_3_pre_photo_raw_care_content(home,patient,repairers)
	var mask:=0
	for person in home:mask|=1<<PEOPLE.find(person)
	var worker: Variant=null;var gain:=0
	if state.shelter<41 and state.wood>0 and not repairers.is_empty():worker="外祖父" if "外祖父" in repairers else repairers[0];gain=formal_repair_gain(int(state.day),worker)
	if chapter_five_care_raw_prose.is_empty():chapter_five_care_raw_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_five_care_raw_prose.json"))
	var key:=JSON.stringify([int(state.day),mask,patient,worker,state.water>0,gain])
	if not chapter_five_care_raw_prose.variants.has(key):return {}
	var result: Dictionary=decode_home_content(chapter_five_care_raw_prose.events[chapter_five_care_raw_prose.variants[key]],chapter_five_care_raw_prose)
	var description:=ailment_text(patient)
	return _replace_content_token(result,"§AILMENT_DESCRIPTION§",description if not description.is_empty() else "身上很不舒服")


func _chapter5_parent_8_pre_photo_recovery_offer(focus: Dictionary) -> Dictionary:
	if state.day<17:return _chapter4_parent_3_pre_photo_recovery_offer(focus)
	if state.balanceVersion!="I2f" or state.day<10 or state.day>23:return {}
	var block: int=int(floor(float(state.day-10)/5));var offset: int=RNG.hash_seed(state.seed+":recovery-offer:"+str(block))%5
	if (int(state.day)-10)%5!=offset:return {}
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].get("outside",false));var actors: Array=home.filter(func(person):return can_work_later(person))
	if actors.is_empty():actors=home.filter(func(person):return understands(person))
	if actors.is_empty():return {}
	var sick: Array=home.filter(func(person):return state.ailments.get(person,{}).values().any(func(value):return value>=2))
	sick.sort_custom(func(a,b):return PEOPLE.find(a)<PEOPLE.find(b) if state.people[a].health==state.people[b].health else state.people[a].health<state.people[b].health)
	var item: Variant=null
	for person in sick:
		var types: Array=["cold","wound","nutrition"]
		types.sort_custom(func(a,b):return ["cold","wound","nutrition"].find(a)<["cold","wound","nutrition"].find(b) if state.ailments[person][a]==state.ailments[person][b] else state.ailments[person][a]>state.ailments[person][b])
		var candidate: String={"cold":"herbs","wound":"bandage","nutrition":"medkit"}[types[0]]
		if not tool_available(candidate) and not tool_available("medkit"):item=candidate;break
	if item==null and not (state.wood<=2 and not can_work_later("外祖父")):return {}
	return {"actor":actors[0],"kind":"medicine" if item!=null else "wood","item":item,"cost":2 if item!=null else 1,"day":state.day+1}


var chapter_six_care_reader=preload("res://scripts/chapter_six_care_prose.gd").new()

var chapter_six_care_raw_prose: Dictionary={}

var chapter_six_condition_home_prose: Dictionary={}

var chapter_six_outdoor_prose: Dictionary={}

var chapter_six_home_prose: Dictionary={}

var chapter_six_bound_nodes: Dictionary={}

func make_bound_chapter_six_node(focus: Dictionary) -> Dictionary:
	if chapter_six_bound_nodes.is_empty():chapter_six_bound_nodes=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_six_bound_nodes.json"))
	var home:=0;var adults:=0
	for i in range(PEOPLE.size()):
		if present(PEOPLE[i]) and not focus.plan.rows[PEOPLE[i]].outside:home|=1<<i
		if i>0 and understands(PEOPLE[i]):adults|=1<<(i-1)
	var key: String=JSON.stringify([focus.plan.nodeId,int(state.day),home,adults,js_truthy(state.memory.get("visitorNameRecorded")),js_truthy(state.memory.get("employment_offer_pending"))])
	if not chapter_six_bound_nodes.variants.has(key):return {}
	var event: Dictionary=decode_home_content(chapter_six_bound_nodes.events[chapter_six_bound_nodes.variants[key]],chapter_six_bound_nodes)
	event.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":state.photo.evidence,"photoPrints":state.photo.prints}
	apply_employment_bridge(event)
	return event

func _chapter5_parent_9_finish_chapter_six_diary(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	var date:=int(focus.day)+1
	if date<25 or date>31 or not focus.plan.get("chapter6",false) or event.get("chapter")!="I2b-6" and not js_truthy(event.get("nodeId")):return true
	if not focus.get("diaryAllowed",false):focus.chapterDiary=[];return true
	if chapter_six_diary_bank.is_empty():chapter_six_diary_bank=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_six_diary_prose.json"))
	var bank: Dictionary=chapter_six_diary_bank;var here: Array=PEOPLE.filter(func(n):return present(n));var adults: Array=here.filter(func(n):return n!="罗瑾")
	var awake: Array=adults.filter(func(n):return understands(n) and state.people[n].health>3 and not state.ailments.get(n,{}).values().any(func(v):return v>=3))
	var actor: String="娘" if "母亲" in awake else ("" if awake.is_empty() else awake[0]);var opening: String
	if state.people["罗瑾"].health<=3 or state.ailments.get("罗瑾",{}).values().any(func(v):return v>=3):opening=bank.openings.weak
	elif actor!="":opening=bank.family[str(date)].replace("{{A}}",actor)
	elif not adults.is_empty():opening=bank.openings.resting
	elif PEOPLE.any(func(n):return n!="罗瑾" and state.people[n].alive and state.people[n].away):opening=bank.openings.away
	else:opening=bank.openings.alone
	var web: bool=focus.get("webM3ReadingRevision")=="WebM3-D25D32-v1"
	if web:
		var able: Array=adults.filter(func(n):return understands(n) and can_work_later(n));var preferred: String={27:"外祖父",28:"安仁叔叔",30:"外祖父",31:"安仁叔叔"}.get(date,"母亲")
		var name: String=preferred if preferred in able else ("" if able.is_empty() else able[0])
		if name!="" and can_work_later("罗瑾"):opening=bank.webFamily[str(date)]["娘" if name=="母亲" else ("叔叔" if name=="安仁叔叔" else name)]
	var work: Array=[]
	for row in focus.plan.rows.values():
		if not row.outside or row.get("inactive",false) or not present(row.name) or focus.selected==row.name or focus.get("cancelWork")==row.name:continue
		var packets: Array=focus.resultPackets.filter(func(p):return p.id==focus.workPackets.get(row.name))
		if row.type in ["wood","water","relief","committee","photo"] and (packets.is_empty() or packets[0].get("status")!="applied"):continue
		if row.type in ["wood","water","relief","committee","photo"]:work.append(bank.work[JSON.stringify([date,web,row.type])])
	if js_truthy(focus.get("defaultNodeDiary")):work.append(focus.defaultNodeDiary)
	var active: Dictionary=_object(state.expedition.get("active"));var absent: String=""
	if not active.is_empty() and state.people.has(active.get("name")) and state.people[active.name].alive and state.people[active.name].away:absent=bank.absence[JSON.stringify([active.name,"late" if active.get("announced",false) else "active"])]
	else:
		var returned: Array=state.expedition.get("history",[]).filter(func(r):return r.get("returnDay")==state.day and present(r.name))
		if not returned.is_empty():
			var r: Dictionary=returned[0];var goods: bool=r.get("carriedResources",{}).values().any(func(n):return n>0) or not r.get("carriedItemIds",[]).is_empty()
			absent=bank.absence[JSON.stringify([r.name,("dusk" if r.get("timing")=="on_return" else "dawn")+("_goods" if goods else "_empty")])]
	var heard: String=bank.heard.home28 if date==28 and focus.selected=="home" and not js_truthy(event.get("conditionKind")) and not js_truthy(event.get("nodeId")) else bank.news[str(date)]
	var ending: String=bank.ending[str(date)]
	if web:ending=("娘在领物处的经历，我已经听过；后来传来的这段没报姓名，我没有将它们接在同一个人身上。" if date==26 and event.get("motherCare",false) else "")+bank.webEnding[str(date)]
	focus.chapterDiary=([opening,choice.get("diaries",{}).get("default","")]+work+[absent,heard,ending]).filter(func(text):return not text.is_empty())
	focus.chapterDiaryContext={"chapter":"I2b-6","day":date,"present":here,"actualWork":focus.plan.rows.values().filter(func(r):return r.outside and not r.get("inactive",false) and present(r.name) and focus.get("cancelWork")!=r.name).map(func(r):return r.name),"heardAtDusk":true,"hearingClass":"F：独立晚间听闻；不执行资源、不自动读取城市资料","absent":active.get("name"),"node":event.get("nodeId") if js_truthy(event.get("nodeId")) else null}
	if web:focus.chapterDiaryContext.webM3ReadingRevision="WebM3-D25D32-v1"
	return true


func _chapter5_parent_9_resolve_day_eleven_twelve_choice(index: int) -> bool:
	if state.day<17:return _chapter4_parent_4_resolve_day_eleven_twelve_choice(index)
	if state.day>23:return false
	var event:=current_later_focus_event()
	if event.has("custodyNight") or event.has("custodyHandoff"):return resolve_custody_choice(index)
	if event.has("neighbourhood"):return resolve_rope_choice(index)
	if event.has("messageThread"):return resolve_message_thread_choice(index)
	return commit_rope_choice_core(index)


func _chapter5_parent_9_settle_day_eleven_twelve_return() -> bool:
	if state.day<17:return _chapter4_parent_6_settle_day_eleven_twelve_return()
	if state.day>23:return false
	var event:=current_later_focus_event();var was_settled: bool=state.focus.get("settled",false);var result: bool=false
	if event.has("messageThread"):result=settle_message_thread_return()
	elif event.has("neighbourhood"):
		result=settle_ordinary_pre_photo_return()
		if result:result=finish_rope_diary(state.focus,event,event.choices[int(state.focus.choiceIndex)])
	elif event.has("custodyHandoff") or event.has("custodyNight"):result=settle_chapter_five_custody_return()
	else:result=settle_ordinary_pre_photo_return()
	if result and not was_settled and state.focus.get("custodyNightRevision")==CUSTODY_NIGHT_REV and js_truthy(state.memory.get(CUSTODY_NIGHT_KEY)):
		if not custody_night_record_valid(state.memory[CUSTODY_NIGHT_KEY]):state.focus.custodyNightCompatibility="这笔跨夜托存记录不完整，交接已隔离；旧物权未猜改。"
		else:settle_custody_owner_arrival(event)
	return result


func _chapter5_parent_9_settle_ordinary_pre_photo_return() -> bool:
	if state.day<17:return _chapter4_parent_6_settle_ordinary_pre_photo_return()
	# D11-D17 selected custody only. Later photos, crises, excursions and owner arrivals
	# on unrelated scenes remain gated until their complete contracts are implemented.
	if state.ended or state.day<10 or state.day>23:return false
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if event.is_empty():return false
	if focus.get("settled",false):state.phase="focusReturn";return true
	if state.phase!="focusResult" or focus.get("choiceIndex")==null or int(focus.choiceIndex)<0 or int(focus.choiceIndex)>=event.choices.size():return false
	if focus.plan.get("key") in ["expeditionSearch","pigeonPickup"]:return false
	if focus.plan.rows.values().any(func(row):return row.get("type") not in ["home","relief","wood","water","burial","registration","rest","committee","photo"]):return false
	for key in ["motherCareReturned","uncleBoundaryReturned","motherCrisisR4a","uncleCrisisR4b","grandfatherHomeR18"]:
		if state.memory.get(key)!=null:return false
	if focus.resultPackets.any(func(packet):return packet.effects.any(func(effect):return not ordinary_pre_photo_effect_supported(effect))):return false
	var choice: Dictionary=event.choices[int(focus.choiceIndex)]
	var backup:=state.duplicate(true);var before:=focus_snapshot();var lines: Array=[]
	for row in focus.plan.rows.values():
		var packets: Array=focus.resultPackets.filter(func(packet):return packet.id==focus.workPackets.get(row.name));var packet: Dictionary={} if packets.is_empty() else packets[0]
		if not present(row.name) or row.get("inactive",false) or focus.get("cancelWork")==row.name:
			if not packet.is_empty():packet.status="cancelled";packet.cancelReason="未能完成或当事人未返家"
			if focus.get("cancelWork")==row.name and present(row.name) and row.outside:lines.append(row.name+"回到了棚边，原定的差事没有做完。")
			continue
		if not packet.is_empty():
			if focus.get("partialWork")==row.name:
				for effect in packet.effects:
					if effect.get("type")=="photo_progress" and effect.get("op")=="skill_delta":effect.value/=2
					elif typeof(effect.get("amount")) in [TYPE_INT,TYPE_FLOAT]:effect.amount=maxf(1,effect.amount-1)
			apply_ordinary_pre_photo_packet(packet)
		if row.outside and row.type!="photo":lines.append(later_return_line(row.name,"partial" if focus.get("partialWork")==row.name else "complete"))
		if row.type=="burial":
			apply_ordinary_pre_photo_packet(queue_focus_packet([{"type":"flag_set","flag":"burialExperienced","value":true}],"work:burial:experience","on_return","罗瑾"))
			if focus.selected!="罗瑾":focus.backgroundDiary="今天我跟队回来，没有在路上独自停留。我没有亲眼看见杀戮，却面对了它留下的后果。回到棚里以后，我想先看看家人还在不在眼前，并不想把一路所见立刻从头说完。"
		if row.type=="registration":
			var inquiry: bool=row.get("registrationProtocol")=="inquiry-I3e-4b"
			apply_ordinary_pre_photo_packet(queue_focus_packet([{"type":"flag_set","flag":"registrationInquiry" if inquiry else "registered","value":"mother"}],"work:registration:inquiry" if inquiry else "work:registration:paper","on_return","母亲"))
		if row.type=="photo" and row.outside:lines.append("罗瑾只做完一部分杂活便离店回到棚边；没做完的那一段不能算上。" if focus.get("partialWork")==row.name else "罗瑾做完今天分到的杂活，离店回到棚边；主要冲洗仍由蒋孝义负责。")
	for packet in focus.resultPackets:
		if packet.timing=="on_return" and packet.status=="pending":apply_ordinary_pre_photo_packet(packet)
	if not settle_chapter_five_default_node(focus,event,lines):state=backup;return false
	var known: bool=understands("罗瑾") and later_event_eligible(event,focus.plan)
	if known:state.knowledgeFacts.append({"id":event.id+":return-knowledge","day":state.day+1,"source":event.actor,"knownBy":["罗瑾"],"scope":"选择结果的可转述部分","text":choice.diaries.default})
	focus.diaryAllowed=known;focus.knowledge.luo=[choice.diaries.default] if known else []
	if known and focus.selected!="罗瑾" and (focus.selected!="home" or focus.plan.rows["罗瑾"].outside) and not lines.any(func(line):return line.begins_with(event.actor)):lines.append(event.actor+"在家里说起今天遇到的事。")
	focus.returnText=" ".join(lines);focus.returnChange=describe_focus_change(before);focus.settled=true;focus.carriedAssets=[];state.phase="focusReturn"
	if not finish_chapter_five_diary(focus,event,choice):state=backup;return false
	state.history.append({"day":state.day,"type":"later-return","event":event.id,"change":focus.returnChange})
	return true

func settle_chapter_six_custody_return() -> bool:
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if state.ended or state.day<24 or state.day>30 or event.is_empty() or not (event.has("custodyHandoff") or event.has("custodyNight")):return false
	if focus.get("settled",false):return settle_ordinary_pre_photo_return()
	if state.phase!="focusResult" or focus.get("choiceIndex")==null or int(focus.choiceIndex)<0 or int(focus.choiceIndex)>=event.choices.size():return false
	var night: bool=event.has("custodyNight");var record: Dictionary=_object(state.memory.get(CUSTODY_NIGHT_KEY if night else "neighbourCustodyWebR6"))
	if not (custody_night_record_valid(record) if night else custody_handoff_record_valid(record)):return false
	if night and focus.get("custodyNightRevision")!=CUSTODY_NIGHT_REV:return false
	var choice: Dictionary=event.choices[int(focus.choiceIndex)];var visits: Array=record.get("visits",[]).filter(func(row):return row.get("event")==event.id and row.get("choice")==choice.id)
	if visits.size()!=1 or not focus.get("custodyNightReceipt" if night else "custodyReceipt") is Dictionary:return false
	var backup: Dictionary=state.duplicate(true);var meta: Dictionary=event.custodyNight if night else event.custodyHandoff
	if not meta.here and not understands(event.actor):choice.diaries.default="我回来时，今天接话的家人还不能把经过讲清。没有听见这回怎样答应、怎样交物，就不从棚边的一只包猜出事情已经做到哪里。" if night else "我回来以后，今天在棚边接话的家人还不能把事情说明。我没有因为眼前少了或多了一处空地，就猜谁来过、什么东西交给了谁。先顾现在能顾的，没听到的那一段不往日记里补。"
	if not settle_ordinary_pre_photo_return():state=backup;return false
	var visit: Dictionary=visits[0];visit.returned=true
	if night:
		var context:=custody_after_context(focus);var speaker: bool=event.actor in context.home and understands(event.actor) and neighbour_knows(event.actor,visit.factId,"custody-summary")
		if "罗瑾" in context.home and understands("罗瑾") and (meta.here or speaker):
			visit.returnListeners=deliver_fact({"factId":visit.factId,"recipients":["罗瑾"],"scope":"custody-summary","source":event.id+":return:"+event.actor,"mode":"witnessed" if meta.here else "told"})
			if record.status!="declined":deliver_fact({"factId":record.id,"recipients":["罗瑾"],"scope":"custody-summary","source":event.id+":return-summary:"+event.actor,"mode":"witnessed" if meta.here else "told"})
		if focus.diaryAllowed and not focus.get("chapterDiary",[]).any(func(text):return text.contains(choice.diaries.default)):
			if not focus.get("chapterDiary") is Array:focus.chapterDiary=[]
			focus.chapterDiary.append(choice.diaries.default)
		focus.custodyNightReceipt.returned=true
	else:
		if understands("罗瑾") and (meta.here or understands(event.actor)):visit.returnListeners=deliver_fact({"factId":visit.factId,"recipients":["罗瑾"],"source":event.id+(":witness-kept" if meta.here else ":return-telling:"+event.actor),"scope":"custody-public","mode":"witnessed" if meta.here else "told"})
		focus.custodyReceipt.returned=true
		if focus.diaryAllowed and not focus.get("chapterDiary",[]).is_empty():
			var text: String=choice.diaries.default;var parts: Array=Array(text.split("\n\n"));var tail: String=parts.pop_back();var body: String="\n\n".join(parts);var hit: bool=false
			for i in range(focus.chapterDiary.size()):
				if focus.chapterDiary[i].contains(text):hit=true;focus.chapterDiary[i]=focus.chapterDiary[i].replace(text,body)
			if not hit:focus.chapterDiary.append(tail if body.is_empty() else body)
			if js_truthy(focus.get("custodyGenericReflection")):focus.chapterDiary.erase(focus.custodyGenericReflection)
			if not body.is_empty():focus.chapterDiary.append(tail)
	return true

func apply_chapter_six_returned_work_prose(focus: Dictionary) -> void:
	if not understands("罗瑾") or not focus.diaryAllowed:return
	for spec in [["r4v9WorkDiaryText","r4v9-work-diary-v1"],["r4v9ReturnRepairText","r4v9-return-repair-prose-v1"]]:
		var marker: Dictionary=_object(focus.get(spec[0]))
		if marker.get("revision")!=spec[1] or marker.get("day")!=focus.day+1 or focus.day!=state.day:continue
		if chapter_six_reading_revisions.is_empty():chapter_six_reading_revisions=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_six_reading_revisions.json"))
		for template in chapter_six_reading_revisions[spec[1]].workParagraphs:
			var expected: Dictionary=template.duplicate(true) if spec[0]=="r4v9ReturnRepairText" else {"actor":template.actor,"kind":template.kind,"chapter":template.chapter,"source":template.source,"replacement":template.replacement}
			if template.day!=marker.day or not marker.get("entries",[]).any(func(entry):return chapter_json_equal(entry,expected)) or focus.chapterDiaryContext.chapter!=template.chapter or focus.selected==template.actor or focus.get("cancelWork")==template.actor or not understands(template.actor):continue
			var row: Dictionary=focus.plan.rows[template.actor];var id: Variant=focus.workPackets.get(template.actor);var packets: Array=focus.resultPackets.filter(func(packet):return packet.id==id)
			if row.type!=template.kind or not row.outside or row.get("inactive",false) or id==null or packets.size()!=1:continue
			var packet: Dictionary=packets[0]
			if packet.status!="applied" or packet.subjectId!=template.actor or packet.timing!="on_return" or packet.scheduledDay!=focus.day or id not in state.effectLedger.appliedEffectIds:continue
			if spec[0]=="r4v9WorkDiaryText":
				if not packet.effects.any(func(effect):return effect.type=="resource_delta" and effect.resource=="rice" and effect.amount>0):continue
			else:
				var event: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get(template.actor)))
				if focus.get("partialWork")==template.actor or event.get("id")!=template.eventId or event.get("actor")!=template.actor or event.get("target")!=template.actor or event.get("conditionKind")!=template.kind or event.get("chapter")!=template.chapter or ["nodeId","uncleCrisis","motherCrisis","expeditionSearch","r4v7P1"].any(func(key):return js_truthy(event.get(key))):continue
				if packet.sourceEventInstanceId!="D"+str(int(template.day))+":work" or packet.condition!=null or packet.cancelReason!=null or not packet.knowledgeFactIds.is_empty() or not packet.effects.all(func(effect):return effect.type=="resource_delta" and effect.resource in ["wood","water"] and effect.amount>0) or not packet.effects.any(func(effect):return effect.get("resource")==template.resource and effect.get("amount",0)>0):continue
			var indices: Array=[]
			for i in range(2,focus.chapterDiary.size()):
				if focus.chapterDiary[i]==template.source:indices.append(i)
			if indices.size()==1:focus.chapterDiary[indices[0]]=template.replacement

func _chapter5_parent_10_describe_focus_change(before: Dictionary) -> String:
	var parts: Array=[]
	for pair in [["rice","米粮"],["water","饮水"],["wood","木料"]]:
		var delta: float=state[pair[0]]-before[pair[0]]
		if delta!=0:parts.append(pair[1]+("＋" if delta>0 else "－")+JS_JSON.encode(absf(delta)))
	var shelter: float=state.shelter-before.shelter
	if shelter!=0:parts.append("草棚"+("得到修补" if shelter>0 else "有所受损")+(("（"+("+" if shelter>0 else "")+JS_JSON.encode(shelter)+"）") if state.test else ""))
	if state.moisture!=before.moisture:parts.append("棚内"+("变得干燥" if state.moisture<before.moisture else "更加潮湿"))
	for id in state.tools:
		if before.tools.get(id)!=state.tools[id]:parts.append(("获得" if state.tools[id] else "失去")+TOOL_NAMES[id]+"×1")
	for person in PEOPLE:
		var b: Dictionary=before.people[person];var p: Dictionary=state.people[person]
		for key in ["health","spirit","spiritMax"]:
			if b[key]!=p[key]:parts.append(person+{"health":"健康","spirit":"精神","spiritMax":"精神上限"}[key]+(("回升" if p[key]>b[key] else "下降") if key=="spiritMax" else ("改善" if p[key]>b[key] else "下降")))
		if b.alive!=p.alive and not p.alive:parts.append(person+"死亡")
	return "，".join(parts)


func _chapter5_parent_10_ordinary_pre_photo_effect_supported(effect: Dictionary) -> bool:
	if effect.get("type")=="flag_set" and effect.get("flag")==MOTHER_CRISIS_KEY:return valid_mother_crisis_record(effect.get("value"))
	if effect.get("type")=="mother_crisis_consequence":return effect.get("review")==MOTHER_CRISIS_REV and effect.get("outcome") in MOTHER_OUTCOMES and effect.get("event") is String and effect.get("choice") in ["withdraw","together","hold"]
	if effect.get("type")=="ailment_reduce":return effect.get("target") in PEOPLE and effect.get("ailment") in ["cold","wound","nutrition"] and typeof(effect.get("amount")) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(effect.amount))
	return _chapter5_parent_3_ordinary_pre_photo_effect_supported(effect)

func photo_skill_label(value: float) -> String:
	return "熟悉协助流程" if value>=6 else ("能协助简单冲印" if value>=4 else ("能稳妥打下手" if value>=2 else "还需从杂活做起"))

const PHOTO_MID_CONTRACT="photo-mid-v1"

const PHOTO_STAGES=["unavailable","introduced","employed","discovered","printing","selected","transferred"]

func photo_stage_advance(stage: String) -> void:
	var prior: Variant=state.photo.get("evidenceStage")
	if PHOTO_STAGES.find(stage)>PHOTO_STAGES.find(prior if js_truthy(prior) else "unavailable"):state.photo.evidenceStage=stage

func photo_batch_requirement(kind: String) -> Dictionary:
	var p: Dictionary=state.photo;var row: Dictionary=_object(_object(_object(state.get("focus")).get("plan")).get("rows",{}).get("罗瑾"));var date: int=int(state.day)+1
	if not can_work_later("罗瑾") or not row.get("outside",false) or row.get("type")!="photo" or not p.employed or not js_truthy(p.evidence):return {"met":false,"reason":"罗瑾今天不能在暗房处理照片"}
	if state.people["罗瑾"].spirit<=2:return {"met":false,"reason":"心神太乱，今天只宜恢复原样"}
	if kind!="sort":return {"met":date>=35 and date<49 and p.prints<36,"reason":"没有本阶段可加印的空缺"}
	var base: Dictionary={"met":date>=44 and p.album.selected<minf(16,p.prints),"reason":"尚无可进一步选定的照片，或未到整理阶段"}
	if base.met:return base
	var early: bool=(p.strategy=="print" and date>=42 and date<49 and p.prints>=16 and p.album.selected<minf(16,p.prints)) or (p.strategy in ["organize","conceal"] and date>=40 and date<49 and p.album.selected<minf(16,p.prints))
	return {"met":true,"reason":""} if early else base

func photo_opportunity(plan: Dictionary) -> Variant:
	var p: Dictionary=state.photo;var date: int=int(state.day)+1;var row: Dictionary=_object(_object(plan.get("rows")).get("罗瑾"))
	if js_truthy(plan.get("nodeId")) or date<35 or date>=49 or not row.get("outside",false) or row.get("inactive",false) or row.get("type")!="photo" or not p.employed or not js_truthy(p.evidence):return null
	var mode: String=p.strategy;var can_print: bool=p.prints<36;var can_sort: bool=p.album.selected<minf(16,p.prints)
	if mode not in ["print","organize","conceal"]:
		var roll: float=float(RNG.hash_seed(state.seed+":photo-offer:"+str(date)))/4294967296.0
		can_sort=can_sort and date>=44
		if can_sort and (not can_print or roll<0.25 or state.balanceVersion=="I2f" and (p.prints>=16 or date>=46)):return "sort"
		if can_print and roll<0.6:return "print"
		return "sort" if can_sort else null
	var roll: float=float(RNG.hash_seed(state.seed+":r23-photo-offer:"+str(date)+":"+mode))/4294967296.0
	if mode=="print":
		if can_sort and date>=42 and (p.prints>=30 or date>=44):return "sort"
		if can_print and (p.prints<30 or roll<0.82):return "print"
		return "sort" if can_sort and date>=42 else null
	if mode=="organize":
		if can_print and p.prints<16:return "print"
		if date<40 and can_print:return "print"
		if can_sort and date>=40:return "sort"
		if can_print and date<=43 and roll<0.36:return "print"
		return null
	if date<42:
		if can_print and p.prints<8:return "print"
		if can_sort and date>=40 and p.album.selected<minf(8,p.prints):return "sort"
		if can_print and p.prints<16:return "print"
		if can_sort and date>=40 and p.album.selected<minf(16,p.prints):return "sort"
		if can_print and roll<0.25:return "print"
		return null
	if can_sort and p.album.selected<minf(16,p.prints):return "sort"
	if can_print and p.prints<16:return "print"
	if can_print and roll<0.35:return "print"
	return "sort" if can_sort else null

func apply_photo_mid_delta(op: String,value: Variant,effect: Dictionary) -> bool:
	var p: Dictionary=state.photo;var receipt: Dictionary=_object(state.focus.get("photoBatchReceipt"))
	if receipt.is_empty() or js_truthy(receipt.get("applied")) or effect.get("contract")!=PHOTO_MID_CONTRACT or receipt.get("day")!=state.day or receipt.get("amount")!=value or not _whole_number(value) or value<0 or (op=="prints_delta")!=(receipt.get("kind")=="print"):
		fail_contract("PHOTO_MID_RECEIPT","照片结果不属于已锁定批次");return false
	if op=="prints_delta":
		if p.prints+value>36:fail_contract("PHOTO_MID_CAP","加印超过批准批次上限");return false
		p.prints+=value
		if value!=0:photo_stage_advance("printing")
	else:
		if p.album.selected+value>minf(16,p.prints):fail_contract("PHOTO_MID_CAP","精选超过实际成片");return false
		p.album.selected+=value
		if value!=0:photo_stage_advance("selected")
	receipt.applied=true;return true

func prepare_photo_mid_numbers(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	var batch: Dictionary=_object(choice.get("photoBatch"))
	if batch.is_empty():return true
	var kind: String=batch.kind;var size: String=batch.size;var requirement:=photo_batch_requirement(kind)
	if not requirement.met:fail_contract("PHOTO_BATCH_REQUIREMENT",requirement.reason);return false
	var p: Dictionary=state.photo;var large: bool=size=="more";var before: Dictionary={}
	for person in PEOPLE:before[person]={"spirit":state.people[person].spirit,"spiritMax":state.people[person].get("spiritMax",10)}
	var chance: float=clampf((0.60 if large else 0.86)+p.skill*0.02+(0.04 if state.people["罗瑾"].spirit>=7 else (-0.15 if state.people["罗瑾"].spirit<=4 else 0.0))-p.attention*0.035,0.20,0.98)
	var roll: float=random_value();var success: bool=roll<chance;var partial: bool=not success and large and roll<minf(1,chance+0.18);var modern: bool=state.photoBalanceVersion=="I3"
	var print_batch: int=(8 if modern else 6) if large else (4 if modern else 3);var sort_batch: int=(16 if modern else 8) if large else (8 if modern else 4)
	var amount: Variant=minf(sort_batch if success else (2 if partial else 0),minf(16-p.album.selected,p.prints-p.album.selected)) if kind=="sort" else minf(print_batch if success else (2 if partial else 0),36-p.prints)
	var attention: int=(1 if large else 0) if kind=="sort" else ((2 if large else 1) if success else 2);var spirit: int=-2 if large else -1
	var receipt: Dictionary={"contract":PHOTO_MID_CONTRACT,"day":state.day,"kind":kind,"size":size,"roll":roll,"chance":chance,"amount":amount,"attention":attention,"spirit":spirit,"event":event.id};focus.photoBatchReceipt=receipt
	choice.immediateEffects.append_array([{"type":"photo_progress","op":"selected_delta" if kind=="sort" else "prints_delta","value":amount,"contract":PHOTO_MID_CONTRACT},{"type":"photo_progress","op":"attention_delta","value":attention},{"type":"character_spirit","target":"罗瑾","amount":spirit}])
	# A3c is earlier than R19/R23 in the actual loaded source. Its snapshot is
	# deliberately the base receipt, not retroactively rewritten final quantities.
	if not focus.has("riskAudits"):focus.riskAudits=[]
	var matching: Array=focus.riskAudits.filter(func(a):return a.event==event.id and a.choice==choice.id and a.kind=="photo-mid")
	if matching.is_empty():
		focus.riskAudits.append({"kind":"photo-mid","event":event.id,"choice":choice.id,"day":state.day+1,"before":before,"contract":PHOTO_MID_CONTRACT,"revision":PHOTO_MID_CONTRACT,"riskRevision":"legacy-spirit-coupled-v1","intervals":{"chance":chance,"amount":amount},"locked":receipt.duplicate(true)});matching=[focus.riskAudits[-1]]
	var book:=spirit_book()
	if not book.has("riskAudits"):book.riskAudits=[]
	var audit: Dictionary=matching[0]
	if not book.riskAudits.any(func(a):return a.event==event.id and a.choice==choice.id and a.kind=="photo-mid" and a.day==audit.day):book.riskAudits.append(audit.duplicate(true))
	var deltas: Array=choice.immediateEffects.filter(func(x):return x.type=="photo_progress" and x.op in ["prints_delta","selected_delta"]);var fx: Dictionary={} if deltas.is_empty() else deltas[0]
	var risks: Array=choice.immediateEffects.filter(func(x):return x.type=="photo_progress" and x.op=="attention_delta");var risk: Dictionary={} if risks.is_empty() else risks[0]
	var fatigues: Array=choice.immediateEffects.filter(func(x):return x.type=="character_spirit" and x.target=="罗瑾");var fatigue: Dictionary={} if fatigues.is_empty() else fatigues[0]
	if js_truthy(event.get("r19PhotoStrategy")) and not fx.is_empty():
		var mode: String=event.r19PhotoStrategy.mode;var next: Variant=receipt.amount
		if kind=="print" and mode=="print" and receipt.amount>0:next=minf(36-p.prints,receipt.amount+(2 if large else 1))
		if kind=="sort" and mode=="organize" and receipt.amount>0:next=minf(16-p.album.selected,minf(p.prints-p.album.selected,receipt.amount+(0 if large else 2)))
		if kind=="print" and mode=="conceal" and receipt.amount>0:next=minf(next,3)
		if kind=="sort" and mode=="conceal" and receipt.amount>0:next=minf(next,8)
		if next!=receipt.amount:receipt.amount=next;fx.value=next
		if kind=="print" and mode=="print" and large and not risk.is_empty():
			risk.value=minf(4,float(risk.get("value",0))+2);receipt.attention=risk.value
			if not fatigue.is_empty():fatigue.amount=minf(-1,float(fatigue.get("amount",0))-1)
		if not p.has("r19"):p.r19={}
		var key: String="printActions" if kind=="print" else "sortActions";p.r19[key]=p.r19.get(key,0)+1
	var mode: Variant=p.strategy if p.strategy in ["print","organize","conceal"] else null
	if mode=="print" and kind=="print" and large:
		if not risk.is_empty() and risk.value>3:risk.value=3;receipt.attention=3
		if not fatigue.is_empty() and fatigue.amount<-2:fatigue.amount=-2
	if mode=="organize" and kind=="sort" and not fatigue.is_empty() and fatigue.amount<-1:fatigue.amount=-1
	if not fx.is_empty() and ((mode=="organize" and kind=="print" and size=="small" and receipt.amount==4) or (mode=="conceal" and kind=="print" and receipt.amount==3)):
		var next: Variant=minf(6,36-p.prints);receipt.amount=next;fx.value=next
	return true

func story_photo(op: String,value: Variant,effect: Dictionary={}) -> bool:
	if op=="transferred_delta":return apply_c8_photo_end_delta(value,effect)
	return _chapter7_parent_22_story_photo(op,value,effect)

const DEADLINE_CONTENT="deadline.notice"

const DEADLINE_PREFIX="deadline.notice:received:"

const DEADLINE_REV="r3-deadline-acquisition-v1"

const DEADLINE_SCOPE="工作与店铺期限，不含照片秘密"

func deadline_own_fact(value: Variant) -> bool:
	if not value is Dictionary:return false
	var id: Variant=value.get("factId") if js_truthy(value.get("factId")) else value.get("id","")
	return str(id).begins_with(DEADLINE_PREFIX)

func deadline_who(fact: Dictionary) -> Array:
	return fact.knownBy if fact.get("knownBy") is Array else []

func deadline_known(person: String) -> bool:
	return state.get("knowledgeFacts",[]).any(func(f):return (f.get("id")==DEADLINE_CONTENT or deadline_own_fact(f)) and person in deadline_who(f))

func deadline_error(text: String) -> bool:
	fail_contract("DEADLINE_KNOWLEDGE_INVALID",text);return false

func deadline_build(person: String,packet_id: Variant,kind: String,speaker: Variant=null) -> Dictionary:
	if person not in PEOPLE or not _whole_number(state.day) or state.day<35 or state.day>48:deadline_error("店铺期限的接收者或日期不合法。");return {}
	if kind not in ["shop_delivery","family_relay","observed_deadline_scene"] or not js_truthy(packet_id):deadline_error("店铺期限缺少可定位的传达来源。");return {}
	if kind=="family_relay" and (speaker not in PEOPLE or speaker==person or not deadline_known(speaker)):deadline_error("转述者没有已经获得的期限记录。");return {}
	var id: String=DEADLINE_PREFIX+person+":D"+str(int(state.day)+1)
	var fact: Dictionary={"id":id,"factId":id,"contentId":DEADLINE_CONTENT,"knownBy":[person],"day":state.day+1,"acquiredDay":state.day+1,"source":"转述","sourceMode":"told","reliability":"可靠转述","secrecy":false,"disclosedToLuo":person=="罗瑾","diaryEligible":person=="罗瑾","scope":DEADLINE_SCOPE,"sourcePacketId":packet_id,"sourceKind":kind}
	if js_truthy(speaker):fact.sourceActor=speaker;fact.sourceFactId=DEADLINE_CONTENT
	fact.recordRevision=DEADLINE_REV;return fact

func deadline_validate_fact(fact: Dictionary) -> bool:
	if p1_fact_marked(fact):return _chapter9_parent_2_deadline_validate_fact(fact)
	return disclosure_validate_fact(fact) if disclosure_marked(fact) else _chapter9_parent_2_deadline_validate_fact(fact)

func deadline_validate() -> bool:
	var seen: Array=[];var subjects: Array=[]
	for fact in state.get("knowledgeFacts",[]):
		if not deadline_own_fact(fact):continue
		if not deadline_validate_fact(fact):return false
		var person: String=deadline_who(fact)[0]
		if fact.id in seen or person in subjects:return deadline_error("同一接收者的期限获得重复登记。")
		seen.append(fact.id);subjects.append(person)
	return true

func deadline_apply(fact: Dictionary) -> bool:
	if p1_fact_marked(fact):return _chapter9_parent_2_deadline_apply(fact)
	return disclosure_apply(fact) if disclosure_marked(fact) else _chapter9_parent_2_deadline_apply(fact)

func deadline_project() -> Dictionary:
	var p: Dictionary=state.photo;var failure: bool=state.get("ended",false) and state.get("endingType")=="luo_death_failure" or state.people["罗瑾"].alive==false
	var clock: String=p.deadlineState if js_truthy(p.get("deadlineState")) else ("final_day" if p.get("deadline",{}).get("final",false) else ("urgent" if p.get("deadline",{}).get("urgent",false) else ("announced" if p.get("deadline",{}).get("announced",false) else "inactive")))
	var people: Array=[]
	for person in PEOPLE:
		var facts: Array=state.get("knowledgeFacts",[]).filter(func(f):return deadline_own_fact(f) and person in deadline_who(f));var fact: Dictionary={} if facts.is_empty() else facts[0];var known:=deadline_known(person)
		people.append({"name":person,"known":known,"acquiredDay":fact.get("acquiredDay"),"sourceKind":fact.get("sourceKind"),"sourceActor":fact.get("sourceActor"),"legacy":known and fact.is_empty()})
	return {"clock":"stopped" if failure else clock,"people":people,"failure":failure,"scope":DEADLINE_SCOPE}

func deadline_system_packet(effects: Array,key: String) -> bool:
	if not state.has("storySystemPackets"):state.storySystemPackets=[]
	var id: String=state.seed+":D"+str(int(state.day)+1)+":system:"+key;var existing: Array=state.storySystemPackets.filter(func(p):return p.id==id)
	var packet: Dictionary={"id":id,"timing":"next_morning","subjectId":"family","effects":effects.duplicate(true),"status":"pending"} if existing.is_empty() else existing[0]
	if existing.is_empty():state.storySystemPackets.append(packet)
	if not state.has("effectLedger"):state.effectLedger={"appliedEffectIds":[]}
	if state.ended or packet.status!="pending" or packet.id in state.effectLedger.appliedEffectIds:return false
	for effect in packet.effects:
		if effect.get("type")!="knowledge_grant" or not deadline_validate_fact(effect.fact):return false
	for effect in packet.effects:
		deadline_apply(effect.fact)
		if contract_error!="":return false
	packet.status="applied";state.effectLedger.appliedEffectIds.append(packet.id);return true

func deadline_notice_delivery() -> bool:
	if state.ended or not state.people["罗瑾"].alive or state.day<35:return false
	var names: Array=PEOPLE.filter(func(n):return understands(n) and not deadline_known(n))
	if names.is_empty():return false
	var id: String=state.seed+":D"+str(int(state.day)+1)+":system:deadline-receipt";var effects: Array=[]
	for person in names:
		var fact:=deadline_build(person,id,"shop_delivery")
		if fact.is_empty():return false
		effects.append({"type":"knowledge_grant","fact":fact})
	return deadline_system_packet(effects,"deadline-receipt")

func relay_deadline_notice() -> bool:
	if state.ended or not understands("罗瑾") or deadline_known("罗瑾") or state.day<35:return false
	var speakers: Array=PEOPLE.filter(func(n):return n!="罗瑾" and understands(n) and deadline_known(n))
	if speakers.is_empty():return false
	var id: String=state.seed+":D"+str(int(state.day)+1)+":system:deadline-relay-to-luo";var fact:=deadline_build("罗瑾",id,"family_relay",speakers[0])
	if fact.is_empty():return false
	return deadline_system_packet([{"type":"knowledge_grant","fact":fact}],"deadline-relay-to-luo")

func attach_deadline_scene_knowledge(packet: Dictionary,event: Dictionary) -> bool:
	if event.get("nodeId")!="deadline" or not understands("罗瑾") or deadline_known("罗瑾"):return true
	var fact:=deadline_build("罗瑾",packet.get("id"),"observed_deadline_scene")
	if fact.is_empty():return false
	packet.effects.append({"type":"knowledge_grant","fact":fact});return true

var chapter_seven_photo_nodes: Dictionary={}

func make_chapter_seven_photo_node(focus: Dictionary) -> Dictionary:
	var node: Variant=focus.plan.get("nodeId")
	if node not in ["discover","trial","firstPrint","deadline"]:return {}
	if chapter_seven_photo_nodes.is_empty():chapter_seven_photo_nodes=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_seven_photo_nodes.json"))
	var p: Dictionary=state.photo;var strategy: String=p.strategy if node=="firstPrint" and p.strategy in ["print","organize","conceal"] else "steady"
	var key: String=JSON.stringify([int(state.day)+1,node,p.employed,js_truthy(p.evidence),p.prints>0,strategy])
	if not chapter_seven_photo_nodes.variants.has(key):fail_contract("PHOTO_NODE_PROSE","当前照片节点正文组合尚未接入。");return {}
	var event: Dictionary=decode_home_content(chapter_seven_photo_nodes.events[chapter_seven_photo_nodes.variants[key]],chapter_seven_photo_nodes)
	var recipients: Array=["母亲","安仁叔叔","外祖父"].filter(func(n):return present(n) and not _object(focus.plan.rows.get(n)).get("outside",false) and understands(n))
	if node=="discover" and ["lusuR17Seen","lusu","lusuSourceBoundary"].any(func(k):return js_truthy(state.memory.get(k))):
		for choice in event.choices:
			if not choice.immediateEffects.any(func(e):return e.get("flag")=="lusuPhotoEcho"):choice.immediateEffects.append({"type":"flag_set","flag":"lusuPhotoEcho","value":true})
	event.recipient=null if recipients.is_empty() else recipients[0]
	event.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":p.evidence,"photoPrints":p.prints}
	return event

var chapter_seven_photo_results: Dictionary={}

var photo_local_text_38: Dictionary={}

func load_photo_local_38() -> void:
	if photo_local_text_38.is_empty():photo_local_text_38=JSON.parse_string(FileAccess.get_file_as_string("res://data/photo_local_text_38.json"))

func photo_local_38_base(focus: Dictionary) -> bool:
	return state.saveVersion==24 and not state.ended and state.day==37 and focus.day==state.day and focus.plan.day==state.day and focus.get("choiceIndex")==null and not focus.get("settled",false)

func attach_photo_local_38(focus: Dictionary,event: Dictionary,fresh: bool) -> void:
	if not fresh or not photo_local_38_base(focus):return
	load_photo_local_38();var data: Dictionary=photo_local_text_38
	if focus.has(data.key):return
	var row: Dictionary=_object(focus.plan.rows.get("罗瑾"));var p: Dictionary=state.photo
	if focus.plan.eventIds.get("罗瑾")!=data.event.id or row.get("type")!="photo" or row.get("outside")!=true or row.get("inactive",false) or not present("罗瑾") or not understands("罗瑾") or focus.plan.get("photoOpportunity")!="print" or not p.employed or p.evidence!=1 or typeof(p.prints) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(p.prints)) or p.prints<=0:return
	if _object(event.get("receivedContext")).get("photoEvidence")!=1 or event.receivedContext.get("photoPrints")!=p.prints:return
	var expected: Dictionary=data.event.duplicate(true);expected.receivedContext.photoPrints=p.prints
	if chapter_json_equal(event,expected):focus[data.key]={"revision":data.revision,"day":38,"eventId":event.id,"choice":"more","priorPrints":p.prints}

func apply_photo_local_38(focus: Dictionary,event: Dictionary,choice: Dictionary) -> void:
	if not photo_local_38_base(focus):return
	load_photo_local_38();var data: Dictionary=photo_local_text_38;var marker: Dictionary=_object(focus.get(data.key));var receipt: Dictionary=_object(focus.get("photoBatchReceipt"));var p: Dictionary=state.photo;var row: Dictionary=_object(focus.plan.rows.get("罗瑾"))
	var expected_marker: Dictionary={"revision":data.revision,"day":38,"eventId":data.event.id,"choice":"more","priorPrints":p.prints}
	if not chapter_json_equal(marker,expected_marker) or typeof(marker.get("priorPrints")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(marker.priorPrints)) or marker.priorPrints<=0 or focus.get("eventId")!=marker.eventId or focus.get("selected")!="罗瑾":return
	if event.get("id")!=marker.eventId or js_truthy(event.get("nodeId")) or event.get("actor")!="罗瑾" or event.get("target")!="罗瑾" or not js_truthy(event.get("photoMid")) or event.get("choices",[]).size()<2 or event.choices[1]!=choice or choice.id!="more":return
	if focus.plan.eventIds.get("罗瑾")!=marker.eventId or focus.plan.get("photoOpportunity")!="print" or row.get("outside")!=true or row.get("type")!="photo" or row.get("inactive",false) or not present("罗瑾") or not understands("罗瑾") or p.evidence!=1:return
	if receipt.get("contract")!=PHOTO_MID_CONTRACT or receipt.get("day")!=focus.day or receipt.get("event")!=event.id or receipt.get("kind")!="print" or receipt.get("size")!="more" or receipt.get("amount")!=0 or js_truthy(receipt.get("applied")):return
	if not ["roll","chance","attention","spirit"].all(func(k):return typeof(receipt.get(k)) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(receipt[k]))) or receipt.roll<receipt.chance:return
	var expected: Dictionary=data.result.duplicate(true);expected.receivedContext.photoPrints=marker.priorPrints;expected.choices[1].immediateEffects[1].value=receipt.attention;expected.choices[1].immediateEffects[2].amount=receipt.spirit
	if not chapter_json_equal(event,expected):return
	var text: String=choice.closures.default
	if text.split(data.patch.old).size()==2:choice.closures.default=text.replace(data.patch.old,data.patch.new)

func prepare_chapter_seven_photo_choice(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	if not js_truthy(choice.get("photoBatch")):return true
	if state.day<34 or state.day>37 or focus.day!=state.day or focus.get("webM3bReadingRevision")!="WebM3-D33D38-v1" or event.get("photoMid")!=true or event.get("actor")!="罗瑾" or event.get("target")!="罗瑾" or choice.photoBatch.get("contract")!=PHOTO_MID_CONTRACT or choice.photoBatch.get("kind")!="print" or choice.id not in ["small","more"] or choice.id!=choice.photoBatch.get("size"):
		fail_contract("PHOTO_RESULT_TEXT_SCOPE","该照片结果正文合同尚未原生接通。");return false
	var p: Dictionary=state.photo;var prior_prints: Variant=p.prints;var mother: bool=present("母亲");var modern: bool=state.photoBalanceVersion=="I3";var strategy: String=p.strategy if p.strategy in ["print","organize","conceal"] else "steady"
	if not prepare_photo_mid_numbers(focus,event,choice):return false
	var receipt: Dictionary=focus.photoBatchReceipt
	if chapter_seven_photo_results.is_empty():chapter_seven_photo_results=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_seven_photo_results.json"))
	var key: String=JSON.stringify([int(state.day)+1,"firstPrint" if event.get("nodeId")=="firstPrint" else "optional",event.id,strategy,choice.id,int(prior_prints),modern,mother,false,int(receipt.amount),receipt.roll>=receipt.chance,int(receipt.attention)])
	if not chapter_seven_photo_results.variants.has(key):fail_contract("PHOTO_RESULT_TEXT_KEY","当前照片结果正文组合尚未接入。");return false
	var pair: Array=chapter_seven_photo_results.variants[key];choice.closures={"default":chapter_seven_photo_results.strings[int(pair[0])]};choice.diaries={"default":chapter_seven_photo_results.strings[int(pair[1])]}
	apply_photo_local_38(focus,event,choice);return true

func _chapter6_parent_6_ordinary_pre_photo_effect_supported(effect: Dictionary) -> bool:
	if effect.get("type")=="flag_set" and effect.get("flag")=="ordinaryWasteExplained":return effect.get("value") is bool
	return _chapter5_parent_10_ordinary_pre_photo_effect_supported(effect)


func _chapter6_parent_7_later_event_eligible(event: Dictionary,plan: Dictionary) -> bool:
	if not _chapter4_parent_6_later_event_eligible(event,plan):return false
	if event.get("nodeId") not in ["names","sources","employ"]:return true
	if state.ended or event.get("actor")!="罗瑾" or not understands("罗瑾"):return false
	if event.nodeId=="employ":
		var row: Dictionary=_object(_object(plan.get("rows")).get("罗瑾"))
		return not row.is_empty() and not row.get("inactive",false) and not row.get("outside",false) and event.target=="home"
	return true

func rollback_photo_choice(backup: Dictionary) -> bool:
	var reason: String=contract_message
	state=backup
	state.error="这次选择尚未结算："+reason
	return false

func resolve_chapter_seven_photo_choice(index: int) -> bool:
	if state.ended or state.day<32 or state.day>37 or state.phase!="focusEvent" or state.focus.get("choiceIndex")!=null:return false
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if event.is_empty() or index<0 or index>=event.get("choices",[]).size():return false
	if event.get("nodeId") not in ["discover","trial","firstPrint","deadline"] and not event.get("photoMid",false):return false
	var choice: Dictionary=event.choices[index]
	for key in ["motherCrisis","uncleCrisis","motherCare","uncleBoundary","photoTransfer","nextMorningEffects"]:
		if js_truthy(choice.get(key)):return false
	if js_truthy(choice.get("photoBatch")):
		var photo_req:=photo_batch_requirement(choice.photoBatch.kind)
		if not photo_req.met:state.error=photo_req.reason;return false
	var requirement:=ordinary_pre_photo_requirement(choice)
	if not requirement.met:state.error=requirement.reason;return false
	if not later_event_eligible(event,focus.plan):state.error="当事人已不能参与这段现场。";return false
	var backup:=state.duplicate(true);var before:=focus_snapshot();contract_error="";contract_message=""
	if not prepare_chapter_seven_photo_choice(focus,event,choice):return rollback_photo_choice(backup)
	var immediate: Array=choice.get("immediateEffects",[]).duplicate(true)
	if js_truthy(choice.get("flag")):immediate.append({"type":"flag_set","flag":choice.flag,"value":true})
	if immediate.any(func(effect):return not ordinary_pre_photo_effect_supported(effect)) or choice.get("returnEffects",[]).any(func(effect):return not ordinary_pre_photo_effect_supported(effect)):
		fail_contract("C7_EFFECT_SCOPE","当前结果类型尚未原生接通。");return rollback_photo_choice(backup)
	var result_packet:=queue_focus_packet(immediate,event.id+":"+choice.id+":immediate","immediate",event.actor)
	if not attach_deadline_scene_knowledge(result_packet,event):return rollback_photo_choice(backup)
	apply_ordinary_pre_photo_packet(result_packet)
	if contract_error!="":return rollback_photo_choice(backup)
	var packet:=queue_focus_packet(choice.get("returnEffects",[]),event.id+":"+choice.id+":return","on_return",event.actor)
	focus.carriedAssets=[]
	for effect in packet.effects:
		if effect.type=="resource_delta" and effect.amount>0:focus.carriedAssets.append({"owner":event.actor,"resource":effect.resource,"amount":effect.amount,"resultPacketId":packet.id})
	focus.cancelWork=focus.selected if choice.get("workImpact")=="complete" else null;focus.partialWork=focus.selected if choice.get("workImpact")=="partial" else null
	focus.choiceIndex=index;focus.outcomeKey="default";focus.immediateText=choice.closures.default;focus.immediateChange=describe_focus_change(before)
	focus.knowledge.player=[focus.immediateText];focus.knowledge.luo=[focus.immediateText] if focus.selected=="罗瑾" or (focus.selected=="home" and not focus.plan.rows["罗瑾"].outside) else []
	var history: Dictionary={"day":state.day,"type":"later-choice","event":event.id,"choice":choice.id}
	if event.get("conditionKind")==_object(event.get("readingVariant")).get("kind"):
		if event.has("readingVariant"):history.readingVariant=event.readingVariant
	else:history.readingVariant=null
	state.phase="focusResult";state.error=null;state.history.append(history);return true

func _chapter6_parent_8_ordinary_pre_photo_effect_supported(effect: Dictionary) -> bool:
	match effect.get("type"):
		"knowledge_grant":return effect.get("fact") is Dictionary and deadline_own_fact(effect.fact)
		"node_resolve":
			if effect.get("node") in ["discover","trial","firstPrint","deadline"]:return not effect.has("status") or effect.status in [null,"resolved","skipped"]
		"flag_set":
			if effect.get("flag") in ["accountantUncleWarned","filmOrder","lusuPhotoEcho"]:return effect.get("value") is bool
		"photo_progress":
			match effect.get("op"):
				"unlock","employ":return effect.get("value") is bool
				"stage_advance":return effect.get("value") in ["unavailable","introduced","employed","discovered","printing","selected","transferred"]
				"work_tendency_set":return effect.get("value") in ["steady","print","organize","conceal"]
				"deadline_transition":return effect.get("value") in ["announced","urgent","final_day","resolved"]
				"skill_delta","attention_delta","prints_delta","selected_delta":return typeof(effect.get("value")) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(effect.value))
	return _chapter6_parent_6_ordinary_pre_photo_effect_supported(effect)


func _chapter6_parent_8_process_pre_photo_story_morning() -> bool:
	if state.day<=24:return _chapter5_parent_6_process_pre_photo_story_morning()
	if state.day<10 or state.ended or not state.people["罗瑾"].alive:return true
	if state.day>31:return false
	for key in ["uncleBoundaryReturned","uncleCrisisR4b","grandfatherHomeR18"]:
		if state.memory.get(key)!=null:return false
	var initial=JSON.parse_string(FileAccess.get_file_as_string("res://data/story_initial_state.json"))
	if not state.has("fixedNodeStates"):state.fixedNodeStates={}
	for id in initial.fixedNodeStates:
		if not state.fixedNodeStates.has(id):state.fixedNodeStates[id]=initial.fixedNodeStates[id].duplicate(true)
	for key in ["pendingMorningPackets","storyMorningDays","knowledgeFacts"]:
		if not state.has(key):state[key]=[]
	var date: int=int(state.day)+1
	if state.storyMorningDays.any(func(value):return value==date):return true
	if state.pendingMorningPackets.any(func(packet):return packet.get("scheduledDay",INF)<=state.day and packet.get("status")=="pending"):return false
	if date>=22 and not state.photo.employed and not chapter_five_node_done(state.fixedNodeStates.employ) and not understands("罗瑾") and ["母亲","安仁叔叔","外祖父"].any(func(person):return understands(person)) and not js_truthy(state.memory.get("employment_offer_pending")):
		if not state.has("storySystemPackets"):state.storySystemPackets=[]
		var id: String=state.seed+":D"+str(date)+":system:employment-offer-pending"
		var found: Array=state.storySystemPackets.filter(func(packet):return packet.id==id)
		var packet: Dictionary={"id":id,"timing":"next_morning","subjectId":"family","effects":[{"type":"flag_set","flag":"employment_offer_pending","value":true}],"status":"pending"} if found.is_empty() else found[0]
		if found.is_empty():state.storySystemPackets.append(packet)
		apply_ordinary_pre_photo_packet(packet)
		state.morningResults.append("照相馆帮工的消息先由在场的大人接下；罗瑾还不能听清规矩，今天不算已经上工。")
	for id in ["names","sources"]:
		var node: Dictionary=state.fixedNodeStates[id]
		if date>node.due and not chapter_five_node_done(node) and not node.eligibleDays.is_empty():state.morningResults.append({"names":"前些天记下的寻人消息，仍有来处没问清。","sources":"几张纸上的听说与亲见，还需要分开放。"}[id])
	process_mother_care_morning()
	process_mother_crisis_morning()
	state.storyMorningDays.append(state.day+1)
	return true

func process_chapter_seven_uncle_notice() -> void:
	var date: int=int(state.day)+1
	if date>=38 and date<=40 and not js_truthy(state.memory.get("uncleBoundaryNoticeDay")) and can_work_later("安仁叔叔"):
		family_system_packet([{"type":"flag_set","flag":"uncleBoundaryNoticeDay","value":date}],"uncle-boundary-notice")
		var text: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_seven_uncle_notice.json"))
		state.morningResults.append(text.notice)
		var known: Array=["player","安仁叔叔"]
		if understands("罗瑾"):known.append("罗瑾")
		state.knowledgeFacts.append({"id":"uncle-boundary.notice","day":date,"knownBy":known,"scope":"F：指认住户的风险提醒；不是发现汉奸或照片搜捕"})

func _chapter6_parent_9_apply_chapter_maintenance(focus: Dictionary) -> void:
	if state.day<24:_chapter5_parent_8_apply_chapter_maintenance(focus);return
	var current: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get("home")))
	if current.is_empty() or state.wood<=0:return
	var low: bool=current.id.ends_with(".maintenance");var fresh: bool=(current.has("neighbourhood") and current.neighbourhood.get("stage")==1 and not js_truthy(current.neighbourhood.get("prior"))) or (current.has("neighbourParcel") and current.neighbourParcel.get("stage")==1 and not js_truthy(current.neighbourParcel.get("prior"))) or current.id.begins_with("neighbour.day.R2b.")
	if not low and not (state.shelter<21 and fresh):return
	var raw:=make_pre_photo_condition_home(focus)
	if raw.get("conditionKind")!="maintenance":return
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].get("outside",false));var adults: Array=home.filter(func(person):return person!="罗瑾");var actor: String=adults[0] if not adults.is_empty() else "罗瑾"
	var event: Dictionary=raw.duplicate(true);event.later=true;event.historyClass="情境演绎；白天家庭维护为游戏安排，不是历史日期事实";event.id="later.D"+str(int(state.day)+1)+".home."+raw.id;event.target="home";event.actor=actor;event.participants=home.duplicate();event.homeParticipants=home.duplicate()
	if not low:focus.dayMaintenanceDisplaced={"id":current.id,"title":current.title,"reason":"shelter_below_21_with_wood","freshNeighbour":true}
	focus.laterEvents[event.id]=event;focus.plan.eventIds.home=event.id


func _chapter6_parent_9_bind_day_eleven_twelve(focus: Dictionary) -> bool:
	if state.day<24:return _chapter5_parent_8_bind_day_eleven_twelve(focus)
	if int(state.day) not in range(10,31) or focus.plan.get("key")=="pigeonPickup":return false
	var fresh: bool=focus.get("laterEvents",{}).is_empty()
	focus.laterEvents={};focus.plan.eventIds={};focus.plan.photoMidContract="photo-mid-v1";focus.plan.chapter6=true;focus.webM3ReadingRevision="WebM3-D25D32-v1"
	for target in focus.plan.targets:
		var event: Dictionary=expedition_search_bound_event(focus) if focus.plan.key=="expeditionSearch" else make_bound_chapter_six_node(focus) if target==focus.plan.primary and js_truthy(focus.plan.get("nodeId")) else (make_chapter_home_base(focus) if target=="home" else make_pre_photo_outdoor_event(focus,target))
		if event.is_empty():return false
		focus.laterEvents[event.id]=event;focus.plan.eventIds[target]=event.id
		if target=="home" and event.get("conditionKind")=="recovery":
			var offer:=pre_photo_recovery_offer(focus)
			if offer.is_empty():return false
			var prior_care:=make_pre_photo_care_event(focus,true)
			if prior_care.is_empty():return false
			focus.laterEvents[prior_care.id]=prior_care
			focus.plan.rows[offer.actor].label+="；邻棚有人带来物品询问换粮"
			focus.plan.recoveryOffer={"kind":offer.kind,"item":offer.item,"cost":offer.cost,"day":offer.day}
	bind_mother_care(focus)
	if not bind_chapter_rope(focus):return false
	if not bind_neighbour_parcel(focus):return false
	# Ordinary neighbour-day scenes start outside this chapter.
	if not bind_mother_crisis(focus):return false
	apply_chapter_maintenance(focus)
	var base_home: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get("home")))
	focus.homeAdmissionAudit=home_reception_status(focus);focus.homeAdmissionAudit.eventId=base_home.get("id");focus.homeAdmissionAudit.actor=base_home.get("actor")
	focus.webR3NeighbourRevision="WebR3-neighbour-prose-v1"
	if base_home.has("neighbourhood"):
		var decorated:=make_rope_event(focus,{"allowed":true,"actor":base_home.actor,"home":focus.homeAdmissionAudit.home,"resting":focus.homeAdmissionAudit.resting})
		if decorated.is_empty():return false
		base_home.clear()
		for key in decorated:base_home[key]=decorated[key]
	if base_home.get("conditionKind") in ["care","recovery"] and not chapter_six_care_reader.decorate(self,focus,base_home):return false
	if base_home.has("neighbourParcel"):
		var decorated:=make_parcel_event(focus,{"allowed":true,"actor":base_home.actor,"home":focus.homeAdmissionAudit.home,"resting":focus.homeAdmissionAudit.resting})
		if decorated.is_empty():return false
		base_home.clear()
		for key in decorated:base_home[key]=decorated[key]
	apply_rope_memory_echo(focus,base_home)
	var message_admission:=message_thread_admission(focus)
	focus.messageAdmissionAudit={"revision":"WebR5-messages-v1","allowed":message_admission.allowed,"reason":message_admission.reason,"stage":message_admission.get("stage") if js_truthy(message_admission.get("stage")) else null,"actor":message_admission.get("actor") if js_truthy(message_admission.get("actor")) else null}
	if message_admission.allowed:
		var old: Dictionary=focus.laterEvents[focus.plan.eventIds.home];var event:=make_message_thread_event(focus,message_admission)
		if event.is_empty():return false
		focus.messageDisplaced={"id":old.id,"title":old.title};focus.laterEvents[event.id]=event;focus.plan.eventIds.home=event.id
	var same_day:=custody_handoff_admission(focus)
	focus.custodyAdmissionAudit={"revision":CUSTODY_HANDOFF_REV,"allowed":same_day.allowed,"reason":same_day.reason,"actor":same_day.get("actor") if js_truthy(same_day.get("actor")) else null,"kind":same_day.get("kind") if js_truthy(same_day.get("kind")) else null}
	if same_day.allowed:
		var event:=make_custody_handoff_event(focus,same_day)
		if event.is_empty():return false
		var old: Dictionary=focus.laterEvents[focus.plan.eventIds.home];focus.custodyDisplaced={"id":old.id,"title":old.title};focus.laterEvents[event.id]=event;focus.plan.eventIds.home=event.id
	focus.custodyNightRevision=CUSTODY_NIGHT_REV;var overnight:=custody_night_admission(focus)
	focus.custodyNightAdmission={"revision":CUSTODY_NIGHT_REV,"allowed":overnight.allowed,"reason":overnight.reason,"actor":overnight.get("actor") if js_truthy(overnight.get("actor")) else null,"kind":overnight.get("kind") if js_truthy(overnight.get("kind")) else null}
	if overnight.allowed:
		var event:=make_custody_night_event(focus,overnight)
		if event.is_empty():return false
		var old: Dictionary=focus.laterEvents[focus.plan.eventIds.home];focus.custodyNightDisplaced={"id":old.id,"title":old.title};focus.laterEvents[event.id]=event;focus.plan.eventIds.home=event.id
	if focus.plan.eventIds.has("home"):connect_pre_photo_qian(focus,focus.laterEvents[focus.plan.eventIds.home]);apply_rope_editorial(focus,focus.laterEvents[focus.plan.eventIds.home])
	apply_middle_reading_context(focus)
	if fresh:apply_chapter_six_reading_revisions(focus);apply_chapter_six_maintenance_revision(focus)
	return true

func _chapter6_parent_9_ensure_day_eleven_twelve_focus() -> Dictionary:
	if state.day<24:return _chapter5_parent_8_ensure_day_eleven_twelve_focus()
	if state.ended or int(state.day) not in range(10,31) or not present("罗瑾"):return {}
	if state.focus.get("day")==state.day and state.focus.get("plan")!=null:return state.focus
	var backup:=state.duplicate(true);var template=JSON.parse_string(FileAccess.get_file_as_string("res://data/native_base_state_template.json"))
	state.focus=template.focus.duplicate(true);var focus: Dictionary=state.focus;focus.day=state.day;focus.grandfatherRecoveryRevision="R4c";focus.characterRevision="R4a";focus.uncleRevision="R4b";focus.neighbourhoodRevision="R2b";focus.integrationReadingRevision="FINAL-INTEGRATION";focus.middleReadingRevision="I3e-4c1"
	focus.plan=make_pre_photo_plan()
	if focus.plan.is_empty():state=backup;return {}
	focus.knowledge={"player":[],"luo":[]};focus.resultPackets=[]
	if not bind_day_eleven_twelve(focus):state=backup;return {}
	focus.workPackets={}
	for row in focus.plan.rows.values():
		if not row.get("inactive",false) and (not row.base.is_empty() or (row.type=="photo" and row.outside and state.photo.employed)):
			var effects: Array=[]
			for resource in row.base:effects.append({"type":"shelter_delta","amount":row.base[resource]} if resource=="shelter" else {"type":"resource_delta","resource":str(resource),"amount":row.base[resource]})
			if row.type=="photo" and row.outside and state.photo.employed:effects.append({"type":"photo_progress","op":"skill_delta","value":0.5})
			focus.workPackets[row.name]=queue_focus_packet(effects,"work:"+row.name,"on_return",row.name).id
	var snapshots=JSON.parse_string(FileAccess.get_file_as_string("res://data/later_public_family_snapshots.json"))
	if snapshots.has(str(int(state.day))):focus.r4v3PublicFamilyText=snapshots[str(int(state.day))].duplicate(true)
	return focus


func _chapter6_parent_9_make_chapter_home_base(focus: Dictionary) -> Dictionary:
	if state.day<24:return _chapter5_parent_8_make_chapter_home_base(focus)
	if state.day>30 or "home" not in focus.plan.targets or js_truthy(focus.plan.get("nodeId")):return {}
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].outside)
	if home.is_empty():return {}
	if home.any(func(person):return not focus_fit(person)):return make_pre_photo_care_event(focus)
	var adults: Array=home.filter(func(person):return person!="罗瑾");var speaker: String=adults[0] if not adults.is_empty() else "罗瑾"
	var event: Dictionary={};var raw: Dictionary={}
	if focus.plan.primary=="home":
		if later_scene_shells.is_empty():later_scene_shells=JSON.parse_string(FileAccess.get_file_as_string("res://data/later_scene_shells.json"))
		var key: String=focus.plan.key
		if key in ["apprentice","oldphoto","materials","register","inquiry"]:key="papers"
		event=later_scene_shells.get(key,later_scene_shells.papers).duplicate(true)
	else:
		raw=make_pre_photo_condition_home(focus);event=raw.duplicate(true)
	if event.is_empty():return {}
	var suffix: String=event.id;var recipients: Array=["母亲","安仁叔叔","外祖父"].filter(func(person):return person in home and understands(person))
	event.id="later.D"+str(int(state.day)+1)+".home."+suffix;event.target="home";event.later=true;event.actor=speaker;event.participants=[speaker];event.homeParticipants=[speaker];event.recipient=null if recipients.is_empty() else recipients[0];event.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":state.photo.evidence,"photoPrints":state.photo.prints};event.historyClass="F：普通难民家庭、店内与工作情境；不是罗瑾逐日实录";event.chapter="I2b-6"
	if chapter_six_home_prose.is_empty():chapter_six_home_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_six_home_prose.json"))
	var mask:=0
	for person in home:mask|=1<<PEOPLE.find(person)
	var key: String=JSON.stringify([int(state.day),mask,state.photo.employed,state.shelter>=50 if state.day==25 else false,state.wood<=0 if state.day==25 else false])
	if not chapter_six_home_prose.variants.has(key):return {}
	var variant: Dictionary=chapter_six_home_prose.variants[key]
	if variant.has("fallback"):
		var fallback:=make_pre_photo_condition_home(focus);var id: String=event.id
		if fallback.is_empty():return {}
		for field in fallback:event[field]=fallback[field]
		event.id=id;event.target="home";event.later=true;event.chapter="I2b-6"
		for choice in event.choices:choice.later=true
	else:
		var layer: Dictionary=decode_home_content(chapter_six_home_prose.events[variant.event],chapter_six_home_prose)
		for field in layer:event[field]=layer[field]
		event.erase("conditionKind")
	return event


func _chapter6_parent_9_make_pre_photo_care_event(focus: Dictionary,base_only: bool=false) -> Dictionary:
	if state.day<24:return _chapter5_parent_8_make_pre_photo_care_event(focus,base_only)
	if state.day<10 or state.day>30 or "home" not in focus.plan.targets or js_truthy(focus.plan.get("nodeId")):return {}
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].get("outside",false));var sick: Array=home.filter(func(person):return not focus_fit(person))
	if sick.is_empty():return {}
	sick.sort_custom(func(a,b):return PEOPLE.find(a)<PEOPLE.find(b) if state.people[a].health==state.people[b].health else state.people[a].health<state.people[b].health)
	var patient: String=sick[0];var others: Array=home.filter(func(person):return person!="罗瑾" and understands(person));var speakers: Array=home.filter(func(person):return understands(person));var actor: String=others[0] if not others.is_empty() else (speakers[0] if not speakers.is_empty() else home[0])
	var event: Dictionary={};var suffix: String="fallback.d"+str(int(state.day)+1)+".home.care"
	if focus.plan.primary=="home":
		if later_scene_shells.is_empty():later_scene_shells=JSON.parse_string(FileAccess.get_file_as_string("res://data/later_scene_shells.json"))
		var key: String=focus.plan.key
		if key in ["apprentice","oldphoto","materials","register","inquiry"]:key="papers"
		if key=="burial":key="returner"
		if key=="shelter" and state.shelter>=50:key="papers"
		event=later_scene_shells.get(key,later_scene_shells.papers).duplicate(true);suffix=event.id
	var recipients: Array=["母亲","安仁叔叔","外祖父"].filter(func(person):return person in home and understands(person))
	event.id="later.D"+str(int(state.day)+1)+".home."+suffix;event.title="";event.intro="";event.later=true;event.historyClass="F：普通难民家庭、店内与工作情境；不是罗瑾逐日实录";event.target="home";event.actor=actor;event.participants=home.duplicate();event.homeParticipants=home.duplicate();event.recipient=null if recipients.is_empty() else recipients[0];event.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":state.photo.get("evidence",0),"photoPrints":state.photo.get("prints",0)};event.chapter="I2b-6";event.conditionKind="care"
	var repairers: Array=home.filter(func(person):return person!=patient and can_work_later(person))
	var raw_care:=pre_photo_raw_care_content(home,patient,repairers)
	if raw_care.is_empty():return {}
	for field in ["title","intro","choices"]:event[field]=raw_care[field]
	for choice in event.choices:choice.later=true
	if base_only:return event

	var offer:=pre_photo_recovery_offer(focus)
	if not offer.is_empty():
		event.id+=".exchange";event.actor=offer.actor;event.conditionKind="recovery"
		var medicine: bool=offer.item!=null;var name: String=TOOL_NAMES[offer.item] if medicine else "木料";var goods: String=name+"一份" if medicine else "能用的短木三份"
		var exchange: Dictionary={"id":"exchange","label":"用米粮"+str(int(offer.cost))+"份换"+goods,"hint":"米粮－"+str(int(offer.cost))+"；"+(name+"＋1，晚间另行用药，不当场治愈" if medicine else "木料＋3，不自动生火或修棚")+"。","requiresResources":{"rice":offer.cost},"immediateEffects":[{"type":"resource_delta","resource":"rice","amount":-offer.cost},{"type":"item_gain","item":offer.item} if medicine else {"type":"resource_delta","resource":"wood","amount":3}],"closures":{"default":""},"diaries":{"default":""}}
		event.choices=[exchange,event.choices[0],event.choices[1]]

	return event


func _chapter6_parent_9_make_pre_photo_condition_home(focus: Dictionary) -> Dictionary:
	if state.day<24:return _chapter5_parent_8_make_pre_photo_condition_home(focus)
	if state.day<10 or state.day>30:return {}
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].get("outside",false))
	if home.is_empty() or home.any(func(person):return not focus_fit(person)):return {}
	var mask:=0
	for person in home:mask|=1<<PEOPLE.find(person)
	var kind: String="weather" if current_weather().get("severe",false) else ("absence" if household_presence_mask()!=15 else ("maintenance" if state.shelter<41 and state.wood>0 else "home"))
	var prior: Array=[];var index:=0;var stock:=0;var gain:=0
	if kind in ["weather","maintenance"]:
		prior=state.history.filter(func(row):return row.get("day",state.day)<state.day and _object(row.get("readingVariant")).get("revision")=="R24-experience-polish-v1" and row.readingVariant.kind==kind)
		var last: Dictionary={}
		for row in prior:last[int(row.readingVariant.index)]=row.day
		var offset: int=RNG.hash_seed(state.seed+"|R24-experience-polish-v1|"+kind)%3;index=-1
		for step in range(3):
			var candidate: int=(offset+step)%3
			if not last.has(candidate):index=candidate;break
		if index<0:
			var candidates: Array=[0,1,2];candidates.sort_custom(func(a,b):return a<b if last[a]==last[b] else last[a]<last[b]);index=candidates[0]
		if kind=="weather":stock=(1 if state.wood>=1 else 0)+(2 if state.shelter>=50 else 0)+(4 if state.shelterItems.oilcloth else 0)
		else:
			var speakers: Array=home.filter(func(person):return person!="罗瑾");gain=formal_repair_gain(int(state.day),speakers[0] if not speakers.is_empty() else "罗瑾")
	else:
		prior=state.history.filter(func(row):return row.get("day",state.day)<state.day and _object(row.get("readingVariant")).get("group")=="shelter")
		index=(RNG.hash_seed(state.seed+":condition-story:shelter")+prior.size())%3
	if chapter_six_condition_home_prose.is_empty():chapter_six_condition_home_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_six_condition_home.json"))
	var key:=JSON.stringify([int(state.day),mask,kind,index,stock,gain])
	if not chapter_six_condition_home_prose.variants.has(key):return {}
	var event: Dictionary=decode_home_content(chapter_six_condition_home_prose.events[chapter_six_condition_home_prose.variants[key]],chapter_six_condition_home_prose)
	event=_replace_content_token(event,"§WEATHER_NAME§",current_weather().name)
	if event.has("readingVariant"):event.readingVariant.previous=null if prior.is_empty() else prior.back().day
	return event


func _chapter6_parent_9_make_pre_photo_outdoor_event(focus: Dictionary,target: String) -> Dictionary:
	if state.day<24:return _chapter5_parent_8_make_pre_photo_outdoor_event(focus,target)
	if state.day<10 or state.day>30 or target not in PEOPLE or target not in focus.plan.targets or (js_truthy(focus.plan.get("nodeId")) and target==focus.plan.primary):return {}
	var row: Dictionary=_object(focus.plan.rows.get(target));var type: String=row.get("type","")
	if not row.get("outside",false) or row.get("inactive",false) or not present(target):return {}
	if not ((target=="罗瑾" and type in ["water","burial","photo"]) or (target=="外祖父" and type=="wood") or (target=="母亲" and type in ["relief","registration"]) or (target=="安仁叔叔" and type=="committee")):return {}
	var prior: Array=state.history.filter(func(history):return history.get("day",state.day)<state.day and _object(history.get("readingVariant")).get("group")=="water") if type=="water" else []
	var index: int=(RNG.hash_seed(state.seed+":condition-story:water")+prior.size())%3 if type=="water" else 0
	var previous: String="none" if prior.is_empty() else "many"
	if prior.size()==1:previous=prior[0].get("choice","") if prior[0].get("choice") in ["help","pole_help"] else "carry_home"
	var tool: String=state.memory.get("burialTool","none") if type=="burial" else "none"
	if tool not in ["shovel","rope"] or not tool_available(tool):tool="none"
	if chapter_six_outdoor_prose.is_empty():chapter_six_outdoor_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_six_outdoor_prose.json"))
	var key:=JSON.stringify([int(state.day),target,type,index,state.water>=2 if type=="water" else false,tool_available("axe") if type=="wood" else false,tool,previous,type=="photo" and focus.plan.primary==target])
	if not chapter_six_outdoor_prose.variants.has(key):return {}
	var event: Dictionary=decode_home_content(chapter_six_outdoor_prose.events[chapter_six_outdoor_prose.variants[key]],chapter_six_outdoor_prose)
	var home: Array=PEOPLE.filter(func(person):return present(person) and not _object(focus.plan.rows.get(person)).get("outside",false))
	var recipients: Array=["母亲","安仁叔叔","外祖父"].filter(func(person):return person in home and understands(person))
	event.recipient=null if recipients.is_empty() else recipients[0]
	event.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":state.photo.get("evidence",0),"photoPrints":state.photo.get("prints",0)}
	if type=="water" and event.has("readingVariant"):
		event.readingVariant.previous=null if prior.is_empty() else prior.back().day
		event.readingVariant.narratorHere="罗瑾" in home
	return event


func _chapter6_parent_9_pre_photo_raw_care_content(home: Array,patient: String,repairers: Array) -> Dictionary:
	if state.day<24:return _chapter5_parent_8_pre_photo_raw_care_content(home,patient,repairers)
	var mask:=0
	for person in home:mask|=1<<PEOPLE.find(person)
	var worker: Variant=null;var gain:=0
	if state.shelter<41 and state.wood>0 and not repairers.is_empty():worker="外祖父" if "外祖父" in repairers else repairers[0];gain=formal_repair_gain(int(state.day),worker)
	if chapter_six_care_raw_prose.is_empty():chapter_six_care_raw_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_six_care_raw_prose.json"))
	var key:=JSON.stringify([int(state.day),mask,patient,worker,state.water>0,gain])
	if not chapter_six_care_raw_prose.variants.has(key):return {}
	var result: Dictionary=decode_home_content(chapter_six_care_raw_prose.events[chapter_six_care_raw_prose.variants[key]],chapter_six_care_raw_prose)
	var description:=ailment_text(patient)
	return _replace_content_token(result,"§AILMENT_DESCRIPTION§",description if not description.is_empty() else "身上很不舒服")


func _chapter6_parent_9_pre_photo_recovery_offer(focus: Dictionary) -> Dictionary:
	if state.day<24:return _chapter5_parent_8_pre_photo_recovery_offer(focus)
	if state.balanceVersion!="I2f" or state.day<10 or state.day>30:return {}
	var block: int=int(floor(float(state.day-10)/5));var offset: int=RNG.hash_seed(state.seed+":recovery-offer:"+str(block))%5
	if (int(state.day)-10)%5!=offset:return {}
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].get("outside",false));var actors: Array=home.filter(func(person):return can_work_later(person))
	if actors.is_empty():actors=home.filter(func(person):return understands(person))
	if actors.is_empty():return {}
	var sick: Array=home.filter(func(person):return state.ailments.get(person,{}).values().any(func(value):return value>=2))
	sick.sort_custom(func(a,b):return PEOPLE.find(a)<PEOPLE.find(b) if state.people[a].health==state.people[b].health else state.people[a].health<state.people[b].health)
	var item: Variant=null
	for person in sick:
		var types: Array=["cold","wound","nutrition"]
		types.sort_custom(func(a,b):return ["cold","wound","nutrition"].find(a)<["cold","wound","nutrition"].find(b) if state.ailments[person][a]==state.ailments[person][b] else state.ailments[person][a]>state.ailments[person][b])
		var candidate: String={"cold":"herbs","wound":"bandage","nutrition":"medkit"}[types[0]]
		if not tool_available(candidate) and not tool_available("medkit"):item=candidate;break
	if item==null and not (state.wood<=2 and not can_work_later("外祖父")):return {}
	return {"actor":actors[0],"kind":"medicine" if item!=null else "wood","item":item,"cost":2 if item!=null else 1,"day":state.day+1}


var chapter_seven_care_reader=preload("res://scripts/chapter_seven_care_prose.gd").new()

var chapter_seven_care_raw_prose: Dictionary={}

var chapter_seven_condition_home_prose: Dictionary={}

var chapter_seven_outdoor_prose: Dictionary={}

var chapter_seven_home_prose: Dictionary={}

var chapter_seven_bound_nodes: Dictionary={}

var chapter_seven_photo_optional: Dictionary={}

var chapter_seven_scoped_prose: Dictionary={}

var chapter_seven_reading_rules: Dictionary={}

func make_bound_chapter_seven_node(focus: Dictionary) -> Dictionary:
	if focus.plan.nodeId in ["discover","trial","firstPrint","deadline"]:return make_chapter_seven_photo_node(focus)
	if chapter_seven_bound_nodes.is_empty():chapter_seven_bound_nodes=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_seven_bound_nodes.json"))
	var home:=0;var adults:=0
	for i in range(PEOPLE.size()):
		if present(PEOPLE[i]) and not focus.plan.rows[PEOPLE[i]].outside:home|=1<<i
		if i>0 and understands(PEOPLE[i]):adults|=1<<(i-1)
	var key: String=JSON.stringify([focus.plan.nodeId,int(state.day),home,adults,js_truthy(state.memory.get("visitorNameRecorded")),js_truthy(state.memory.get("employment_offer_pending"))])
	if not chapter_seven_bound_nodes.variants.has(key):return {}
	var event: Dictionary=decode_home_content(chapter_seven_bound_nodes.events[chapter_seven_bound_nodes.variants[key]],chapter_seven_bound_nodes)
	event.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":state.photo.evidence,"photoPrints":state.photo.prints}
	apply_employment_bridge(event)
	return event

func bind_chapter_seven_photo_optional(focus: Dictionary) -> bool:
	for target in focus.plan.targets:
		var event: Dictionary=focus.laterEvents[focus.plan.eventIds[target]]
		if event.get("nodeId")=="firstPrint":focus.plan.photoOpportunity="print";continue
		if target!="罗瑾" or js_truthy(event.get("nodeId")):continue
		var kind: Variant=photo_opportunity(focus.plan)
		if kind==null or kind=="":continue
		if kind!="print" or int(state.day) not in [36,37]:fail_contract("C7_OPTIONAL_PHOTO_SCOPE","此照片机会正文未接入。");return false
		if chapter_seven_photo_optional.is_empty():chapter_seven_photo_optional=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_seven_photo_optional.json"))
		var strategy: String=state.photo.strategy if state.photo.strategy in ["print","organize","conceal"] else "steady"
		var key: String=JSON.stringify([int(state.day)+1,strategy,state.photo.prints>0,focus.plan.primary=="罗瑾"])
		if not chapter_seven_photo_optional.variants.has(key):return false
		var next: Dictionary=decode_home_content(chapter_seven_photo_optional.events[chapter_seven_photo_optional.variants[key]],chapter_seven_photo_optional)
		next.receivedContext=event.receivedContext.duplicate(true);next.recipient=event.get("recipient")
		focus.laterEvents[focus.plan.eventIds[target]]=next;focus.plan.photoOpportunity=kind
	return true

func apply_chapter_seven_scoped_reading(focus: Dictionary) -> void:
	if chapter_seven_scoped_prose.is_empty():chapter_seven_scoped_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_seven_scoped_prose.json"))
	var data: Dictionary=chapter_seven_scoped_prose
	for t in data.ordinary:
		var event: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get(t.target)));var row: Dictionary=_object(focus.plan.rows.get(t.target))
		if focus.day!=t.day or event.get("id")!=t.id or event.get("target")!=t.target or event.get("actor")!=t.target or event.get("nodeId")!=null or event.get("photoMid",false) or event.get("chapter")!="I2b-7" or event.get("conditionKind")!=t.condition or row.get("type")!=t.row or not row.get("outside",false) or row.get("inactive",false):continue
		if not chapter_json_equal(event.choices.map(func(c):return c.id),t.text.choices.keys()) or event.title!=t.source.title:continue
		var axe_intro: String=t.source.intro.replace("外祖父没有带能拆开它的工具，光凭手去硬扯，只会连别的东西也带下来。","外祖父带着斧头，可以先把露在外面的松散部分劈短，但有斧头也不等于可以钻到悬着的东西下面。")
		if event.intro!=t.source.intro and not (t.condition=="wood" and event.intro==axe_intro):continue
		if not event.choices.all(func(c):return c.closures.default==t.source.choices[c.id].closure and c.diaries.default==t.source.choices[c.id].diary):continue
		event.title=t.text.title;event.intro=t.text.intro
		for choice in event.choices:choice.closures.default=t.text.choices[choice.id].closure;choice.diaries.default=t.text.choices[choice.id].diary
	if focus.day==data.hearing.day and focus.plan.get("chapter7",false):focus.r4v6DuskText={"revision":data.revision,"day":focus.day,"source":data.hearing.source,"text":data.hearing.text}

func apply_chapter_seven_reading_marks(focus: Dictionary) -> void:
	if chapter_seven_reading_rules.is_empty():chapter_seven_reading_rules=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_seven_reading_rules.json"))
	chapter_six_reading_revisions=chapter_seven_reading_rules
	apply_chapter_six_reading_revisions(focus)
	var data: Dictionary=chapter_seven_reading_rules["r4v9-b6-photo-diary-v1"];var t: Dictionary=data.zero;var event: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get("罗瑾")));var row: Dictionary=_object(focus.plan.rows.get("罗瑾"));var p: Dictionary=state.photo
	if state.saveVersion==24 and not state.ended and state.day==t.day-1 and focus.day==state.day and focus.plan.day==focus.day and row.get("name")=="罗瑾" and row.get("type")=="photo" and row.get("outside")==true and not row.get("inactive",false) and present("罗瑾") and understands("罗瑾") and event.get("id")==t.eventId and event.get("actor")=="罗瑾" and event.get("target")=="罗瑾":
		if not ["photoEnd","conditionKind","neighbourhood","neighbourParcel","messageThread","motherCrisis","uncleCrisis","expeditionSearch","r4v7P1","nodeId"].any(func(k):return js_truthy(event.get(k))) and focus.plan.get("photoOpportunity")=="print" and p.employed and p.evidence==1 and p.prints>0 and event.get("receivedContext",{}).get("photoEvidence")==1 and event.get("receivedContext",{}).get("photoPrints")==p.prints:
			if t.expected.keys().all(func(k):return chapter_json_equal(event.get(k),t.expected[k])) and not focus.has(data.key):focus[data.key]={"revision":data.revision,"day":focus.day+1,"entries":[{"name":t.name,"day":t.day,"eventId":t.eventId,"source":t.source,"replacement":t.replacement}]}
	var local: Dictionary=chapter_seven_reading_rules["r4v10-local-text-v1"];var home: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get("home")));var source: Dictionary=local.sources.D38_BRACE
	if state.saveVersion==24 and not state.ended and state.day==37 and focus.day==state.day and focus.plan.day==state.day and focus.get("choiceIndex")==null and not focus.get("settled",false) and focus.plan.eventIds.get("home")==source.id and _object(focus.plan.rows.get("外祖父")).get("outside")==false and source.participants.all(func(n):return present(n)) and chapter_json_equal(home,source):
		var draft: Dictionary=local.drafts[2]
		if home.choices[0].id=="brace" and home.choices[0].hint==draft.old:home.choices[0].hint=draft.new

var chapter_seven_diary_prose: Dictionary={}

func finish_chapter_seven_diary(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	var date: int=int(focus.day)+1
	if date<32 or date>38 or not focus.plan.get("chapter7",false) or event.get("chapter")!="I2b-7" and not js_truthy(event.get("nodeId")):return true
	if not focus.get("diaryAllowed",false):focus.chapterDiary=[];return true
	if chapter_seven_diary_prose.is_empty():chapter_seven_diary_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_seven_diary_prose.json"))
	var bank: Dictionary=chapter_seven_diary_prose;var here: Array=PEOPLE.filter(func(n):return present(n));var adults: Array=here.filter(func(n):return n!="罗瑾");var healthy: Array=adults.filter(func(n):return can_work_later(n) and not _object(focus.plan.rows.get(n)).get("outside",false))
	var known: bool=state.get("knowledgeFacts",[]).any(func(f):return f.get("id")=="deadline.notice" and "罗瑾" in f.get("knownBy",[]));var evidence: bool=js_truthy(state.photo.evidence)
	var mode: String="weak"
	if can_work_later("罗瑾"):
		if not healthy.is_empty():mode="母亲" if "母亲" in healthy else healthy[0]
		elif not adults.is_empty():mode="allout" if adults.all(func(n):return can_work_later(n)) else "resting"
		elif PEOPLE.any(func(n):return n!="罗瑾" and state.people[n].alive and state.people[n].away):mode="away"
		else:mode="alone"
	var opening: String=bank.openings[JSON.stringify([date,mode,known])];var web: bool=(focus.get("webM3bReadingRevision")=="WebM3-D33D38-v1" and date>=33) or (date==32 and focus.get("webM3ReadingRevision")=="WebM3-D25D32-v1")
	if web and can_work_later("罗瑾"):
		var fit: Array=adults.filter(func(n):return understands(n) and can_work_later(n));var preferred: String={34:"外祖父",36:"安仁叔叔",38:"外祖父"}.get(date,"母亲")
		if not fit.is_empty():opening=bank.webOpenings[JSON.stringify([date,preferred if preferred in fit else fit[0],evidence])]
	var work: Array=[]
	for row in focus.plan.rows.values():
		if not row.outside or row.get("inactive",false) or not present(row.name) or focus.get("selected")==row.name or focus.get("cancelWork")==row.name:continue
		var packets: Array=focus.get("resultPackets",[]).filter(func(p):return p.id==focus.get("workPackets",{}).get(row.name))
		if packets.is_empty() or packets[0].status!="applied":continue
		if row.type in ["photo","water","relief","wood","committee"]:work.append(bank.work[JSON.stringify([date,web,row.type])])
	if js_truthy(focus.get("defaultNodeDiary")):work.append(focus.defaultNodeDiary)
	var active: Dictionary=_object(state.expedition.get("active"));var absent: String=""
	if not active.is_empty() and state.people.has(active.get("name")) and state.people[active.name].alive and state.people[active.name].away:absent=bank.absence[JSON.stringify([active.name,"late" if active.get("announced",false) else "active"])]
	else:
		var returned: Array=state.expedition.get("history",[]).filter(func(r):return r.get("returnDay")==state.day and present(r.name))
		if not returned.is_empty():absent=bank.absence[JSON.stringify([returned[0].name,"dusk" if returned[0].get("timing")=="on_return" else "dawn"])]
	focus.chapterDiary=([opening,choice.get("diaries",{}).get("default","")]+work+[absent,bank.news[str(date)],bank.endings[JSON.stringify([date,web,evidence,known])]]).filter(func(t):return js_truthy(t))
	if _object(event.get("readingVariant")).get("revision")=="WebR2-home-care-prose-v1" and focus.chapterDiary.find(choice.get("diaries",{}).get("default",""))>0 and not focus.get("grandfatherRecoveryAdded",false) and not js_truthy(event.get("nodeId")):focus.chapterDiary[0]=""
	focus.chapterDiaryContext={"chapter":"I2b-7","day":date,"present":here,"node":event.get("nodeId") if js_truthy(event.get("nodeId")) else null,"heardAtDusk":true,"hearingClass":"F：晚间独立听闻，不是城市资料自动转入人物知识","actualWork":focus.plan.rows.values().filter(func(r):return r.outside and not r.get("inactive",false) and present(r.name) and focus.get("cancelWork")!=r.name).map(func(r):return r.name)}
	if date==32 and web:focus.chapterDiaryContext.webM3ReadingRevision="WebM3-D25D32-v1"
	if chapter_seven_scoped_prose.is_empty():chapter_seven_scoped_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_seven_scoped_prose.json"))
	var marker: Dictionary=_object(focus.get("r4v6DuskText"));var hearing: Dictionary=chapter_seven_scoped_prose.hearing
	if focus.day==hearing.day and marker.get("revision")==chapter_seven_scoped_prose.revision and marker.get("day")==focus.day and marker.get("source")==hearing.source and marker.get("text")==hearing.text:focus.chapterDiary=focus.chapterDiary.map(func(t):return marker.text if t==marker.source else t)
	if chapter_seven_reading_rules.is_empty():chapter_seven_reading_rules=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_seven_reading_rules.json"))
	chapter_six_reading_revisions=chapter_seven_reading_rules;apply_chapter_six_returned_work_prose(focus)
	if event.has("messageThread") and not focus.chapterDiary.is_empty():focus.messageGenericReflection=focus.chapterDiary[-1]
	if event.has("custodyHandoff") and not focus.chapterDiary.is_empty():focus.custodyGenericReflection=focus.chapterDiary[-1]
	return true

func _chapter6_parent_11_finish_chapter_six_diary(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	if not _chapter5_parent_9_finish_chapter_six_diary(focus,event,choice):return false
	if not focus.get("diaryAllowed",false) or not focus.get("chapterDiary") is Array or focus.chapterDiary.is_empty():return true
	if _object(event.get("readingVariant")).get("revision")=="WebR2-home-care-prose-v1" and focus.chapterDiary.find(choice.diaries.default)>0 and not focus.get("grandfatherRecoveryAdded",false) and not js_truthy(event.get("nodeId")):focus.chapterDiary[0]=""
	if event.has("messageThread"):focus.messageGenericReflection=focus.chapterDiary[-1]
	if event.has("custodyHandoff"):focus.custodyGenericReflection=focus.chapterDiary[-1]
	apply_chapter_six_returned_work_prose(focus)
	return true


func _chapter6_parent_11_resolve_day_eleven_twelve_choice(index: int) -> bool:
	if state.day<24:return _chapter5_parent_9_resolve_day_eleven_twelve_choice(index)
	if state.day>30:return false
	var event:=current_later_focus_event()
	if event.has("motherCrisis"):return resolve_mother_crisis_choice(index)
	if event.get("motherCare",false):return resolve_mother_care_choice(index)
	if event.has("neighbourParcel"):return resolve_parcel_choice(index)
	if event.has("custodyNight") or event.has("custodyHandoff"):return resolve_custody_choice(index)
	if event.has("neighbourhood"):return resolve_rope_choice(index)
	if event.has("messageThread"):return resolve_message_thread_choice(index)
	return commit_rope_choice_core(index)


func _chapter6_parent_11_settle_chapter_five_default_node(focus: Dictionary,event: Dictionary,lines: Array) -> bool:
	var id: Variant=focus.plan.get("nodeId")
	if id==null:return true
	if id not in ["names","sources","employ"]:return false
	var node: Dictionary=state.fixedNodeStates[id]
	if chapter_five_node_done(node) or event.get("nodeId")==id:return true
	if id!="employ" and node.eligibleDays.size()<2:return true
	var planned: Dictionary=focus.laterEvents[focus.plan.eventIds[focus.plan.primary]];var choice: Dictionary=planned.choices[0]
	if not ordinary_pre_photo_requirement(choice).met or not later_event_eligible(planned,focus.plan):return true
	var effects: Array=choice.get("immediateEffects",[]).duplicate(true)+choice.get("returnEffects",[]).duplicate(true)
	if not apply_ordinary_pre_photo_packet(queue_focus_packet(effects,"node:"+id+":default","on_return",planned.actor)):return false
	node.fallback="岗位保留默认" if id=="employ" else "第二个合适日稳妥默认"
	lines.append({"employ":"工作规矩已传到家里，罗瑾先保留这份帮工岗位。","names":"罗瑾只记下了姓名和消息来处。","sources":"罗瑾把公开说法与能核实的记录分开放好。"}[id]);focus.defaultNodeDiary=choice.diaries.default
	return true


func _chapter6_parent_11_settle_day_eleven_twelve_return() -> bool:
	if state.day<24:return _chapter5_parent_9_settle_day_eleven_twelve_return()
	if state.day>30:return false
	var event:=current_later_focus_event();var was_settled: bool=state.focus.get("settled",false);var result: bool=false
	if event.has("messageThread"):result=settle_message_thread_return()
	elif event.has("neighbourhood"):
		result=settle_ordinary_pre_photo_return()
		if result:result=finish_rope_diary(state.focus,event,event.choices[int(state.focus.choiceIndex)])
	elif event.has("neighbourParcel"):
		result=settle_ordinary_pre_photo_return()
		if result:result=finish_parcel_diary(state.focus,event,event.choices[int(state.focus.choiceIndex)])
	elif event.has("custodyHandoff") or event.has("custodyNight"):result=settle_chapter_six_custody_return()
	else:result=settle_ordinary_pre_photo_return()
	if result and not was_settled and state.focus.get("custodyNightRevision")==CUSTODY_NIGHT_REV and js_truthy(state.memory.get(CUSTODY_NIGHT_KEY)):
		if not custody_night_record_valid(state.memory[CUSTODY_NIGHT_KEY]):state.focus.custodyNightCompatibility="这笔跨夜托存记录不完整，交接已隔离；旧物权未猜改。"
		else:settle_custody_owner_arrival(event)
	return result


func _chapter6_parent_11_settle_ordinary_pre_photo_return() -> bool:
	if state.day<24:return _chapter5_parent_9_settle_ordinary_pre_photo_return()
	# D11-D17 selected custody only. Later photos, crises, excursions and owner arrivals
	# on unrelated scenes remain gated until their complete contracts are implemented.
	if state.ended or state.day<24 or state.day>30:return false
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if event.is_empty():return false
	if focus.get("settled",false):state.phase="focusReturn";return true
	if state.phase!="focusResult" or focus.get("choiceIndex")==null or int(focus.choiceIndex)<0 or int(focus.choiceIndex)>=event.choices.size():return false
	if focus.plan.get("key") in ["expeditionSearch","pigeonPickup"]:return false
	if focus.plan.rows.values().any(func(row):return row.get("type") not in ["home","relief","wood","water","burial","registration","rest","committee","photo"]):return false
	for key in ["uncleBoundaryReturned","uncleCrisisR4b","grandfatherHomeR18"]:
		if state.memory.get(key)!=null:return false
	if focus.resultPackets.any(func(packet):return packet.effects.any(func(effect):return not ordinary_pre_photo_effect_supported(effect) and effect.get("type")!="mother_crisis_consequence")):return false
	var choice: Dictionary=event.choices[int(focus.choiceIndex)]
	var backup:=state.duplicate(true);var before:=focus_snapshot();var lines: Array=[]
	for row in focus.plan.rows.values():
		var packets: Array=focus.resultPackets.filter(func(packet):return packet.id==focus.workPackets.get(row.name));var packet: Dictionary={} if packets.is_empty() else packets[0]
		if not present(row.name) or row.get("inactive",false) or focus.get("cancelWork")==row.name:
			if not packet.is_empty():packet.status="cancelled";packet.cancelReason="未能完成或当事人未返家"
			if focus.get("cancelWork")==row.name and present(row.name) and row.outside:lines.append(row.name+"回到了棚边，原定的差事没有做完。")
			continue
		if not packet.is_empty():
			if focus.get("partialWork")==row.name:
				for effect in packet.effects:
					if effect.get("type")=="photo_progress" and effect.get("op")=="skill_delta":effect.value/=2
					elif typeof(effect.get("amount")) in [TYPE_INT,TYPE_FLOAT]:effect.amount=maxf(1,effect.amount-1)
			apply_ordinary_pre_photo_packet(packet)
		if row.outside and row.type!="photo":lines.append(later_return_line(row.name,"partial" if focus.get("partialWork")==row.name else "complete"))
		if row.type=="burial":
			apply_ordinary_pre_photo_packet(queue_focus_packet([{"type":"flag_set","flag":"burialExperienced","value":true}],"work:burial:experience","on_return","罗瑾"))
			if focus.selected!="罗瑾":focus.backgroundDiary="今天我跟队回来，没有在路上独自停留。我没有亲眼看见杀戮，却面对了它留下的后果。回到棚里以后，我想先看看家人还在不在眼前，并不想把一路所见立刻从头说完。"
		if row.type=="registration":
			var inquiry: bool=row.get("registrationProtocol")=="inquiry-I3e-4b"
			apply_ordinary_pre_photo_packet(queue_focus_packet([{"type":"flag_set","flag":"registrationInquiry" if inquiry else "registered","value":"mother"}],"work:registration:inquiry" if inquiry else "work:registration:paper","on_return","母亲"))
		if row.type=="photo" and row.outside:lines.append("罗瑾只做完一部分杂活便离店回到棚边；没做完的那一段不能算上。" if focus.get("partialWork")==row.name else "罗瑾做完今天分到的杂活，离店回到棚边；主要冲洗仍由蒋孝义负责。")
	for packet in focus.resultPackets:
		if packet.timing=="on_return" and packet.status=="pending":apply_ordinary_pre_photo_packet(packet)
	if contract_error!="":state=backup;state.error="返家尚未结算完成："+contract_message;return false
	if not settle_chapter_five_default_node(focus,event,lines):state=backup;return false
	var known: bool=mother_preparation_return_allowed(focus,event) and understands("罗瑾") and later_event_eligible(event,focus.plan) and (not event.get("motherCare",false) or mother_care_has_returned(focus))
	if known:state.knowledgeFacts.append({"id":event.id+":return-knowledge","day":state.day+1,"source":event.actor,"knownBy":["罗瑾"],"scope":"选择结果的可转述部分","text":choice.diaries.default})
	focus.diaryAllowed=known;focus.knowledge.luo=[choice.diaries.default] if known else []
	if known and focus.selected!="罗瑾" and (focus.selected!="home" or focus.plan.rows["罗瑾"].outside) and not lines.any(func(line):return line.begins_with(event.actor)):lines.append(event.actor+"在家里说起今天遇到的事。")
	focus.returnText=" ".join(lines);focus.returnChange=describe_focus_change(before);focus.settled=true;focus.carriedAssets=[];state.phase="focusReturn"
	if not finish_chapter_six_diary(focus,event,choice):state=backup;return false
	if event.get("motherCare",false) and focus.diaryAllowed and focus.get("chapterDiary") is Array:focus.chapterDiary=focus.chapterDiary.slice(1)
	if event.has("motherCrisis") and not finish_mother_crisis_diary(focus,event,choice):state=backup;return false
	state.history.append({"day":state.day,"type":"later-return","event":event.id,"change":focus.returnChange})
	return true

func settle_chapter_seven_custody_return() -> bool:
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if state.ended or state.day<31 or state.day>37 or event.is_empty() or not (event.has("custodyHandoff") or event.has("custodyNight")):return false
	if focus.get("settled",false):return settle_ordinary_pre_photo_return()
	if state.phase!="focusResult" or focus.get("choiceIndex")==null or int(focus.choiceIndex)<0 or int(focus.choiceIndex)>=event.choices.size():return false
	var night: bool=event.has("custodyNight");var record: Dictionary=_object(state.memory.get(CUSTODY_NIGHT_KEY if night else "neighbourCustodyWebR6"))
	if not (custody_night_record_valid(record) if night else custody_handoff_record_valid(record)):return false
	if night and focus.get("custodyNightRevision")!=CUSTODY_NIGHT_REV:return false
	var choice: Dictionary=event.choices[int(focus.choiceIndex)];var visits: Array=record.get("visits",[]).filter(func(row):return row.get("event")==event.id and row.get("choice")==choice.id)
	if visits.size()!=1 or not focus.get("custodyNightReceipt" if night else "custodyReceipt") is Dictionary:return false
	var backup: Dictionary=state.duplicate(true);var meta: Dictionary=event.custodyNight if night else event.custodyHandoff
	if not meta.here and not understands(event.actor):choice.diaries.default="我回来时，今天接话的家人还不能把经过讲清。没有听见这回怎样答应、怎样交物，就不从棚边的一只包猜出事情已经做到哪里。" if night else "我回来以后，今天在棚边接话的家人还不能把事情说明。我没有因为眼前少了或多了一处空地，就猜谁来过、什么东西交给了谁。先顾现在能顾的，没听到的那一段不往日记里补。"
	if not settle_ordinary_pre_photo_return():state=backup;return false
	var visit: Dictionary=visits[0];visit.returned=true
	if night:
		var context:=custody_after_context(focus);var speaker: bool=event.actor in context.home and understands(event.actor) and neighbour_knows(event.actor,visit.factId,"custody-summary")
		if "罗瑾" in context.home and understands("罗瑾") and (meta.here or speaker):
			visit.returnListeners=deliver_fact({"factId":visit.factId,"recipients":["罗瑾"],"scope":"custody-summary","source":event.id+":return:"+event.actor,"mode":"witnessed" if meta.here else "told"})
			if record.status!="declined":deliver_fact({"factId":record.id,"recipients":["罗瑾"],"scope":"custody-summary","source":event.id+":return-summary:"+event.actor,"mode":"witnessed" if meta.here else "told"})
		if focus.diaryAllowed and not focus.get("chapterDiary",[]).any(func(text):return text.contains(choice.diaries.default)):
			if not focus.get("chapterDiary") is Array:focus.chapterDiary=[]
			focus.chapterDiary.append(choice.diaries.default)
		focus.custodyNightReceipt.returned=true
	else:
		if understands("罗瑾") and (meta.here or understands(event.actor)):visit.returnListeners=deliver_fact({"factId":visit.factId,"recipients":["罗瑾"],"source":event.id+(":witness-kept" if meta.here else ":return-telling:"+event.actor),"scope":"custody-public","mode":"witnessed" if meta.here else "told"})
		focus.custodyReceipt.returned=true
		if focus.diaryAllowed and not focus.get("chapterDiary",[]).is_empty():
			var text: String=choice.diaries.default;var parts: Array=Array(text.split("\n\n"));var tail: String=parts.pop_back();var body: String="\n\n".join(parts);var hit: bool=false
			for i in range(focus.chapterDiary.size()):
				if focus.chapterDiary[i].contains(text):hit=true;focus.chapterDiary[i]=focus.chapterDiary[i].replace(text,body)
			if not hit:focus.chapterDiary.append(tail if body.is_empty() else body)
			if js_truthy(focus.get("custodyGenericReflection")):focus.chapterDiary.erase(focus.custodyGenericReflection)
			if not body.is_empty():focus.chapterDiary.append(tail)
	return true

const ROUTE_REV="r3-ordinary-route-warning-v1"

const ROUTE_CONTENT="ordinary.route.warning"

const ROUTE_SOURCE="安仁叔叔"

const ROUTE_SCOPE="ordinary_route_only"

func route_marked(value: Variant) -> bool:
	var fact:=_object(value)
	return chapter_json_equal(fact.get("contentId"),ROUTE_CONTENT) or chapter_json_equal(fact.get("contractRevision"),ROUTE_REV)

func route_tracked() -> bool:return _object(state.get("r3RouteWarningContract")).get("revision")==ROUTE_REV

func route_facts() -> Array:return state.get("knowledgeFacts",[]).filter(func(f):return route_marked(f))

func route_known(person: String) -> bool:
	return route_facts().any(func(f):return f.get("knownBy") is Array and f.knownBy.size()==1 and chapter_json_equal(f.knownBy[0],person))

func route_use_by_luo() -> bool:return route_known("罗瑾") if route_tracked() else js_truthy(state.memory.get("routeWarned"))

func route_error(code: String,message: String) -> bool:fail_contract(code,message);return false

func route_make(person: String,mode: String,packet_id: String) -> Dictionary:
	var contract: Dictionary=_object(state.get("r3RouteWarningContract"));var event: Variant=contract.get("sourceEventId");var prefix: String="null" if event==null else str(event)
	return {"id":prefix+":route-warning:"+person,"factId":prefix+":route-warning:"+person,"contentId":ROUTE_CONTENT,"contractRevision":ROUTE_REV,"knownBy":[person],"sourceMode":mode,"source":ROUTE_SOURCE,"sourceActor":ROUTE_SOURCE,"sourceEventInstanceId":event,"sourcePacketId":packet_id,"day":state.day+1,"acquiredDay":state.day+1,"scope":ROUTE_SCOPE,"reliability":"direct" if mode=="witnessed" else "reported","diaryEligible":person=="罗瑾","disclosedToLuo":person=="罗瑾"}

func route_validate_fact(fact: Dictionary) -> bool:
	var contract: Dictionary=_object(state.get("r3RouteWarningContract"));var who: Array=fact.knownBy if fact.get("knownBy") is Array else [];var person: Variant=null if who.is_empty() else who[0]
	if not route_tracked() or not js_truthy(contract.get("sourceEventId")):return route_error("ROUTE_CONTRACT","普通路线记录缺少已生成的告知现场。保留原文件，不自动补谈话。")
	if not chapter_json_equal(fact.get("contentId"),ROUTE_CONTENT) or not chapter_json_equal(fact.get("contractRevision"),ROUTE_REV) or not chapter_json_equal(fact.get("scope"),ROUTE_SCOPE):return route_error("ROUTE_SCOPE","普通路线提醒不能包含照片秘密或未知合同。")
	if who.size()!=1 or person not in ["player"]+PEOPLE:return route_error("ROUTE_RECIPIENT","路线提醒必须逐个记录实际接收者。")
	if not chapter_json_equal(fact.get("sourceActor"),ROUTE_SOURCE) or not chapter_json_equal(fact.get("source"),ROUTE_SOURCE) or not chapter_json_equal(fact.get("sourceEventInstanceId"),contract.sourceEventId):return route_error("ROUTE_SOURCE","路线提醒来源不匹配，不能换人代说。")
	if not chapter_json_equal(fact.get("id"),str(contract.sourceEventId)+":route-warning:"+person) or not chapter_json_equal(fact.get("factId"),fact.get("id")) or not fact.get("sourcePacketId") is String or fact.sourcePacketId.is_empty():return route_error("ROUTE_ID","路线提醒缺少唯一事实或结果包编号。")
	if not _whole_number(fact.get("acquiredDay")) or fact.acquiredDay!=43 or not chapter_json_equal(fact.get("day"),fact.acquiredDay) or not _whole_number(state.day) or fact.acquiredDay>state.day+1:return route_error("ROUTE_DAY","路线提醒获知日与实际D43现场不符；不倒填旧记录。")
	if fact.get("sourceMode") not in ["witnessed","told"] or person==ROUTE_SOURCE and fact.sourceMode!="witnessed" or person not in [ROUTE_SOURCE,"player"] and fact.sourceMode!="told":return route_error("ROUTE_MODE","路线提醒的亲见与转述身份不匹配。")
	if not chapter_json_equal(fact.get("reliability"),("direct" if fact.sourceMode=="witnessed" else "reported")) or not fact.get("diaryEligible") is bool or fact.diaryEligible!=(person=="罗瑾") or not fact.get("disclosedToLuo") is bool or fact.disclosedToLuo!=(person=="罗瑾"):return route_error("ROUTE_DIARY","路线消息的可靠程度或罗瑾日记准入不匹配。")
	return true

func route_apply(fact: Dictionary) -> bool:
	if not route_validate_fact(fact):return false
	if not state.has("knowledgeFacts"):state.knowledgeFacts=[]
	var prior: Array=state.knowledgeFacts.filter(func(f):return chapter_json_equal(f.get("id"),fact.id))
	if not prior.is_empty():
		if JS_JSON.encode(prior[0])!=JS_JSON.encode(fact):return route_error("ROUTE_DUPLICATE","同一人路线知识有矛盾版本；没有覆盖原记录。")
		return false
	state.knowledgeFacts.append(fact.duplicate(true));return true

func route_validate() -> bool:
	var contract: Dictionary=_object(state.get("r3RouteWarningContract"));var rows:=route_facts()
	if js_truthy(state.get("r3RouteWarningContract")):
		if not chapter_json_equal(contract.get("revision"),ROUTE_REV) or not _whole_number(contract.get("eventDay")) or contract.eventDay!=43 or state.day+1<43 or not contract.has("sourceEventId") or not (contract.get("sourceEventId")==null or contract.get("sourceEventId") is String and not contract.sourceEventId.is_empty()):return route_error("ROUTE_CONTRACT","路线知识合同身份或日期错误。")
	elif not rows.is_empty():return route_error("ROUTE_MARKER","逐人路线事实丢失合同标记，不能降格成旧聚合记录。")
	var seen: Array=[];var ledger: Array=state.get("effectLedger",{}).get("appliedEffectIds",[])
	for fact in rows:
		if not route_validate_fact(fact):return false
		if fact.knownBy[0] in seen:return route_error("ROUTE_DUPLICATE","同一人路线知识重复，未自动删减。")
		seen.append(fact.knownBy[0])
		if fact.sourcePacketId not in ledger:return route_error("ROUTE_PACKET","路线知识没有已执行结果包支持。")
	for packet in state.get("focus",{}).get("resultPackets",[]):
		if js_truthy(packet.get("routeWarningNotice")):
			var notice: Dictionary=_object(packet.routeWarningNotice)
			if not route_tracked() or not chapter_json_equal(notice.get("revision"),ROUTE_REV) or not chapter_json_equal(notice.get("eventId"),contract.get("sourceEventId")) or not chapter_json_equal(packet.get("timing"),"on_return") or not chapter_json_equal(packet.get("subjectId"),ROUTE_SOURCE):return route_error("ROUTE_PACKET","尚待转述的路线结果包身份不完整。")
		for effect in packet.get("effects",[]):
			if chapter_json_equal(effect.get("type"),"knowledge_grant") and route_marked(effect.get("fact")) and not route_validate_fact(effect.fact):return false
	if route_tracked() and js_truthy(state.memory.get("routeWarned")) and (ROUTE_SOURCE not in seen or "player" not in seen):return route_error("ROUTE_AGGREGATE","新路线预警标记缺少实际亲见或返家记录。")
	return true

func route_transfer_receipt() -> Dictionary:
	var focus: Dictionary=_object(state.get("focus"));var receipt: Dictionary=_object(focus.get("photoTransferReceipt"))
	if not js_truthy(focus.get("photoTransferReceipt")):return {"status":"none"}
	var executed: bool=receipt.get("applied") is bool and receipt.applied and focus.get("resultPackets",[]).any(func(p):return chapter_json_equal(p.get("status"),"applied") and p.get("id") in state.get("effectLedger",{}).get("appliedEffectIds",[]) and p.get("effects",[]).any(func(e):return chapter_json_equal(e.get("type"),"photo_progress") and chapter_json_equal(e.get("op"),"transferred_delta") and chapter_json_equal(e.get("contract"),receipt.get("contract")) and chapter_json_equal(e.get("value"),receipt.get("amount"))))
	if not executed:return {"status":"pending"}
	if not _whole_number(receipt.get("amount")) or receipt.amount<0 or not _whole_number(receipt.get("day")) or receipt.day<0 or receipt.day>state.day:return {"status":"invalid"}
	return {"status":"arrived" if receipt.amount>0 else "retreated","day":receipt.day+1,"amount":receipt.amount,"location":receipt.location if receipt.amount>0 and receipt.get("location") is String else null}

func route_project() -> Dictionary:
	var contract: Dictionary=_object(state.get("r3RouteWarningContract"));var rows:=route_facts();var tracked:=route_tracked();var legacy: bool=not tracked and js_truthy(state.memory.get("routeWarned"));var persons: Array=[]
	for person in ["player"]+PEOPLE:
		var found: Array=rows.filter(func(f):return f.get("knownBy") is Array and not f.knownBy.is_empty() and chapter_json_equal(f.knownBy[0],person));var fact: Dictionary={} if found.is_empty() else found[0]
		persons.append({"name":person,"known":not fact.is_empty(),"acquiredDay":fact.get("acquiredDay"),"mode":fact.get("sourceMode")})
	return {"tracked":tracked,"legacy":legacy,"playerKnown":route_known("player") if tracked else legacy,"luoKnown":route_known("罗瑾") if tracked else null,"people":persons,"sourceEventId":contract.get("sourceEventId") if js_truthy(contract.get("sourceEventId")) else null,"receipt":route_transfer_receipt(),"terminal":state.get("ended",false) or chapter_json_equal(state.get("phase"),"end"),"failure":chapter_json_equal(state.get("endingType"),"luo_death_failure") or state.people["罗瑾"].alive==false}

func bind_route_warning_marker(focus: Dictionary) -> void:
	if focus.day+1!=43 or js_truthy(state.memory.get("routeWarned")) or js_truthy(state.get("r3RouteWarningContract")):return
	var warnings: Array=focus.get("laterEvents",{}).values().filter(func(e):return chapter_json_equal(e.get("nodeId"),"warning") and chapter_json_equal(e.get("actor"),ROUTE_SOURCE))
	state.r3RouteWarningContract={"revision":ROUTE_REV,"eventDay":43,"sourceEventId":null if warnings.is_empty() else warnings[0].id};focus.r3RouteWarningRevision=ROUTE_REV

func current_route_warning(event: Dictionary) -> bool:
	return route_tracked() and state.day+1==43 and chapter_json_equal(state.focus.get("r3RouteWarningRevision"),ROUTE_REV) and chapter_json_equal(event.get("nodeId"),"warning") and chapter_json_equal(event.get("actor"),ROUTE_SOURCE) and chapter_json_equal(event.get("id"),state.r3RouteWarningContract.get("sourceEventId"))

func attach_route_warning_witness(packet: Dictionary,event: Dictionary) -> void:
	if not current_route_warning(event):return
	for person in [ROUTE_SOURCE,"player"]:
		if not route_known(person):packet.effects.append({"type":"knowledge_grant","fact":route_make(person,"witnessed",packet.id)})

func mark_route_warning_return(packet: Dictionary,event: Dictionary) -> void:
	if current_route_warning(event):packet.routeWarningNotice={"revision":ROUTE_REV,"eventId":event.id}

func complete_route_warning_return(packet: Dictionary) -> bool:
	if not js_truthy(packet.get("routeWarningNotice")):return true
	var notice: Dictionary=_object(packet.routeWarningNotice);var row: Dictionary=_object(_object(state.focus.get("plan")).get("rows",{}).get(ROUTE_SOURCE));var event: Dictionary=_object(state.focus.get("laterEvents",{}).get(notice.get("eventId")))
	if not current_route_warning(event) or not chapter_json_equal(notice.get("revision"),ROUTE_REV):return route_error("ROUTE_RETURN","路线转述不属于这次已锁现场。")
	if not row.get("outside",false) or row.get("inactive",false) or not understands(ROUTE_SOURCE):packet.status="cancelled";packet.cancelReason="原提醒者没有实际返家并完成转述，不换人代说。";return false
	var recipients: Array=[ROUTE_SOURCE,"player"]+PEOPLE.filter(func(n):return n!=ROUTE_SOURCE and understands(n))
	for person in recipients:
		if route_known(person) or packet.effects.any(func(e):return route_effect_targets(e,person)):continue
		packet.effects.append({"type":"knowledge_grant","fact":route_make(person,"witnessed" if person==ROUTE_SOURCE else "told",packet.id)})
	return true

func route_effect_targets(effect: Dictionary,person: String) -> bool:
	var who: Variant=_object(effect.get("fact")).get("knownBy")
	return chapter_json_equal(effect.get("type"),"knowledge_grant") and who is Array and not who.is_empty() and chapter_json_equal(who[0],person)

func _chapter7_parent_1_ordinary_pre_photo_effect_supported(effect: Dictionary) -> bool:
	if effect.get("type")=="flag_set" and effect.get("flag")=="uncleBoundaryNoticeDay":return _whole_number(effect.get("value")) and effect.value>=38 and effect.value<=40
	return _chapter6_parent_8_ordinary_pre_photo_effect_supported(effect)


const UNCLE_BOUNDARY_NOTICE="uncle-boundary.notice"

var uncle_boundary_prose: Dictionary={}

func valid_uncle_boundary_record(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=3 or not value.get("event") is String or not _whole_number(value.get("day")) or value.day<39 or value.day>42 or value.get("choice") not in ["leave","clarify"]:return false
	return value.event.begins_with("later.D"+str(int(value.day))+".安仁叔叔.")

func uncle_boundary_returned() -> Dictionary:
	var record: Dictionary=_object(state.memory.get("uncleBoundaryReturned"))
	if record.is_empty():return {}
	return record if state.history.any(func(h):return h.get("type")=="later-return" and h.get("day")==record.get("day",INF)-1 and h.get("event")==record.get("event")) else {}

func uncle_boundary_warned() -> bool:
	return state.get("knowledgeFacts",[]).any(func(k):return k.get("id")==UNCLE_BOUNDARY_NOTICE and k.get("day",INF)<state.day+1 and "player" in k.get("knownBy",[]) and "安仁叔叔" in k.get("knownBy",[]))

func process_uncle_boundary_morning() -> void:
	if state.ended:return
	if uncle_boundary_prose.is_empty():uncle_boundary_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/uncle_boundary_prose.json"))
	var date: int=int(state.day)+1
	if date>=38 and date<=40 and not js_truthy(state.memory.get("uncleBoundaryNoticeDay")) and can_work_later("安仁叔叔"):
		family_system_packet([{"type":"flag_set","flag":"uncleBoundaryNoticeDay","value":date}],"uncle-boundary-notice");state.morningResults.append(uncle_boundary_prose.notice)
		var recipients: Array=["player","安仁叔叔"]
		if understands("罗瑾"):recipients.append("罗瑾")
		state.knowledgeFacts.append({"id":UNCLE_BOUNDARY_NOTICE,"day":date,"knownBy":recipients,"scope":"F：指认住户的风险提醒；不是发现汉奸或照片搜捕"})
	var record:=uncle_boundary_returned()
	if record.is_empty() or js_truthy(state.memory.get("uncleBoundaryFollowupDone")) or date<=record.day:return
	if not state.people["安仁叔叔"].alive or state.people["安仁叔叔"].get("permanentLost",false) or date>record.day+3:
		family_system_packet([{"type":"flag_set","flag":"uncleBoundaryFollowupDone","value":"closed"}],"uncle-boundary-close");return
	if not understands("安仁叔叔"):return
	if family_system_packet([{"type":"flag_set","flag":"uncleBoundaryFollowupDone","value":date}],"uncle-boundary-followup"):
		state.morningResults.append(uncle_boundary_prose.leave if record.get("choice") is String and record.choice=="leave" else uncle_boundary_prose.clarify)
		var recipients: Array=["player","安仁叔叔"]
		if understands("罗瑾"):recipients.append("罗瑾")
		state.knowledgeFacts.append({"id":"uncle-boundary.followup","day":date,"knownBy":recipients,"scope":"只回顾真实已返家分支，不确证来人身份"})

func uncle_boundary_requirement(choice: Dictionary) -> Dictionary:
	var focus: Dictionary=state.focus;var event: Dictionary=_object(focus.get("laterEvents",{}).get(focus.get("eventId")));var row: Dictionary=_object(_object(focus.get("plan")).get("rows",{}).get("安仁叔叔"));var packets: Array=focus.get("resultPackets",[]).filter(func(p):return p.get("id")==focus.get("workPackets",{}).get("安仁叔叔"));var packet: Dictionary={} if packets.is_empty() else packets[0]
	var met: bool=js_truthy(event.get("uncleBoundary")) and event.get("choices",[]).any(func(c):return c.get("id")==choice.get("id")) and not js_truthy(state.memory.get("uncleBoundaryChosen")) and can_work_later("安仁叔叔") and row.get("outside",false) and not row.get("inactive",false) and row.get("type")=="committee" and packet.get("status")=="pending" and packet.get("subjectId")=="安仁叔叔"
	return {"met":met,"reason":"" if met else "叔叔的出工条件已经改变，不能继续补算这次门边问话。"}

func uncle_boundary_return_allowed(packet: Dictionary) -> bool:
	var focus: Dictionary=state.focus;var boundary: Dictionary=_object(packet.get("uncleBoundary"));var packets: Array=focus.get("resultPackets",[]).filter(func(p):return p.get("id")==boundary.get("workPacket"))
	if packets.is_empty():return false
	var work: Dictionary=packets[0]
	return work.get("id")==focus.get("workPackets",{}).get("安仁叔叔") and work.get("subjectId")=="安仁叔叔" and packet.get("subjectId")=="安仁叔叔" and work.get("status")=="applied" and work.id in state.get("effectLedger",{}).get("appliedEffectIds",[])

func uncle_boundary_has_returned(focus: Dictionary) -> bool:
	return focus.get("resultPackets",[]).any(func(p):return js_truthy(p.get("uncleBoundary")) and p.get("status")=="applied" and p.get("id") in state.get("effectLedger",{}).get("appliedEffectIds",[]))

func finish_uncle_boundary_diary(focus: Dictionary,event: Dictionary) -> void:
	if js_truthy(event.get("uncleBoundary")) and focus.get("diaryAllowed",false) and focus.get("chapterDiary") is Array:focus.chapterDiary=focus.chapterDiary.slice(1)

var uncle_boundary_scenes: Dictionary={}

func bind_uncle_boundary(focus: Dictionary) -> void:
	var date: int=int(focus.day)+1;var id: Variant=focus.plan.get("eventIds",{}).get("安仁叔叔");var old: Dictionary=_object(focus.get("laterEvents",{}).get(id));var row: Dictionary=_object(focus.plan.get("rows",{}).get("安仁叔叔"));var record:=uncle_boundary_returned()
	if date==43 and old.get("nodeId")=="warning" and not record.is_empty() and record.day<date and not js_truthy(old.get("uncleBoundaryConnection")):
		if uncle_boundary_scenes.is_empty():uncle_boundary_scenes=JSON.parse_string(FileAccess.get_file_as_string("res://data/uncle_boundary_scenes.json"))
		var known: bool=state.get("knowledgeFacts",[]).any(func(k):return k.get("id")==record.event+":return-knowledge" and "罗瑾" in k.get("knownBy",[]));var text: Dictionary=uncle_boundary_scenes.connection["true" if known else "false"]
		old.uncleBoundaryConnection=true;old.intro+=text.intro
		for choice in old.choices:choice.diaries.default+=text.diary
		return
	if date<39 or date>42 or js_truthy(state.memory.get("uncleBoundaryChosen")) or not uncle_boundary_warned() or not can_work_later("安仁叔叔") or current_weather().get("severe",false) or not row.get("outside",false) or row.get("inactive",false) or row.get("type")!="committee" or row.get("base",{}).get("rice",0)<=0 or old.is_empty() or ["nodeId","uncleBoundary","expeditionSearch","pigeonPickup"].any(func(k):return js_truthy(old.get(k))):return
	if uncle_boundary_scenes.is_empty():uncle_boundary_scenes=JSON.parse_string(FileAccess.get_file_as_string("res://data/uncle_boundary_scenes.json"))
	var event: Dictionary=old.duplicate(true);var layer: Dictionary=_replace_content_token(uncle_boundary_scenes.scenes[str(date)].duplicate(true),"§EVENT_ID§",id)
	for key in layer:event[key]=layer[key]
	focus.laterEvents[id]=event

func _chapter7_parent_3_apply_ordinary_pre_photo_packet(packet: Dictionary) -> bool:
	if packet.get("effects",[]).any(func(effect):return effect.get("type")=="mother_crisis_consequence"):return apply_mother_crisis_packet(packet)
	if state.ended or packet.effects.any(func(effect):return not ordinary_pre_photo_effect_supported(effect)):return false
	if not state.has("effectLedger"):state.effectLedger={"appliedEffectIds":[]}
	if packet.status!="pending" or packet.id in state.effectLedger.appliedEffectIds:return false
	if packet.subjectId in PEOPLE and not present(packet.subjectId):packet.status="cancelled";packet.cancelReason="当事人未返家或已死亡";return false
	if js_truthy(packet.get("motherCare")) and not mother_care_return_allowed(packet):packet.status="cancelled";packet.cancelReason="本趟基本粮未实际交回，不补扣家庭库存";return false
	for effect in packet.effects:
		if effect.type=="knowledge_grant" and not deadline_validate_fact(effect.fact):return false
	for i in range(packet.effects.size()):
		var effect: Dictionary=packet.effects[i]
		match effect.type:
			"resource_delta":
				state[effect.resource]=maxf(0,minf(state.waterCap if effect.resource=="water" else INF,state[effect.resource]+effect.amount))
				if effect.resource=="water" and state.water==0:state.memory.erase("waterExposure")
			"shelter_delta":state.shelter=clampf(state.shelter+effect.amount,0,50)
			"item_consume":state.tools[effect.item]=false
			"item_gain":
				if state.tools.get(effect.item,false):state["rice" if effect.item=="whistle" else "wood"]+=1
				else:state.tools[effect.item]=true
			"character_health":
				if present(effect.target):state.people[effect.target].health=clampf(state.people[effect.target].health+effect.amount,0,10)
			"character_spirit":
				if present(effect.target):apply_packet_spirit(packet,effect,i)
			"ailment_reduce":
				change_ailment(effect.target,effect.ailment,-effect.amount)
			"flag_set":state.memory[effect.flag]=effect.value
			"node_resolve":
				var node: Dictionary=state.fixedNodeStates[effect.node];node.status=effect.get("status","resolved") if js_truthy(effect.get("status")) else "resolved";node.resolvedDay=state.day+1;node.fallback=effect.get("fallback") if js_truthy(effect.get("fallback")) else null
			"photo_progress":
				if not story_photo(effect.op,effect.get("value"),effect):return false
			"knowledge_grant":
				deadline_apply(effect.fact)
				if contract_error!="":return false
	packet.status="applied";state.effectLedger.appliedEffectIds.append(packet.id);return true


func _chapter7_parent_3_ordinary_pre_photo_requirement(choice: Dictionary) -> Dictionary:
	if js_truthy(choice.get("motherCrisis")):
		var requirement:=mother_crisis_requirement(choice)
		if not requirement.met:return requirement
	if js_truthy(choice.get("motherCare")):
		var requirement:=mother_care_requirement(choice)
		if not requirement.met:return requirement
	return _chapter5_parent_3_ordinary_pre_photo_requirement(choice)

func resolve_uncle_boundary_choice(index: int) -> bool:
	if state.ended or state.day<38 or state.day>41 or state.phase!="focusEvent" or state.focus.get("choiceIndex")!=null:return false
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if event.is_empty() or index<0 or index>=event.get("choices",[]).size():return false
	if not event.get("uncleBoundary",false):return false
	var choice: Dictionary=event.choices[index]
	for key in ["motherCrisis","uncleCrisis","motherCare","photoTransfer","photoBatch","nextMorningEffects"]:
		if js_truthy(choice.get(key)):return false
	var immediate: Array=choice.get("immediateEffects",[]).duplicate(true)
	if js_truthy(choice.get("flag")):immediate.append({"type":"flag_set","flag":choice.flag,"value":true})
	if immediate.any(func(effect):return not ordinary_pre_photo_effect_supported(effect)) or choice.get("returnEffects",[]).any(func(effect):return not ordinary_pre_photo_effect_supported(effect)):return false
	var requirement:=ordinary_pre_photo_requirement(choice)
	if not requirement.met:state.error=requirement.reason;return false
	if not later_event_eligible(event,focus.plan):state.error="当事人已不能参与这段现场。";return false
	var backup:=state.duplicate(true);var before:=focus_snapshot();contract_error="";contract_message=""
	apply_ordinary_pre_photo_packet(queue_focus_packet(immediate,event.id+":"+choice.id+":immediate","immediate",event.actor))
	if contract_error!="":state=backup;state.error="这次选择尚未结算："+contract_message;return false
	var packet:=queue_focus_packet(choice.get("returnEffects",[]),event.id+":"+choice.id+":return","on_return",event.actor)
	packet.uncleBoundary={"workPacket":focus.workPackets["安仁叔叔"],"choice":choice.id}
	focus.carriedAssets=[]
	for effect in packet.effects:
		if effect.type=="resource_delta" and effect.amount>0:focus.carriedAssets.append({"owner":event.actor,"resource":effect.resource,"amount":effect.amount,"resultPacketId":packet.id})
	focus.cancelWork=focus.selected if choice.get("workImpact")=="complete" else null;focus.partialWork=focus.selected if choice.get("workImpact")=="partial" else null
	focus.choiceIndex=index;focus.outcomeKey="default";focus.immediateText=choice.closures.default;focus.immediateChange=describe_focus_change(before)
	focus.knowledge.player=[focus.immediateText];focus.knowledge.luo=[focus.immediateText] if focus.selected=="罗瑾" or (focus.selected=="home" and not focus.plan.rows["罗瑾"].outside) else []
	var history: Dictionary={"day":state.day,"type":"later-choice","event":event.id,"choice":choice.id}
	if event.get("conditionKind")==_object(event.get("readingVariant")).get("kind"):
		if event.has("readingVariant"):history.readingVariant=event.readingVariant
	else:history.readingVariant=null
	state.phase="focusResult";state.error=null;state.history.append(history);return true

const UNCLE_CRISIS_KEY="uncleCrisisR4b"

const UNCLE_CRISIS_REV="uncle-crisis-v1"

const UNCLE_RISK_REV="uncle-hold-fixed-v2"

const UNCLE_SUPPORT_REV="uncle-support-B-v1"

const UNCLE_PREP_SOURCE_REV="R4-v10-B19-uncle-preparation-source-v1"

func uncle_support_note(logistics: Dictionary,step: String) -> void:
	if not logistics.steps.any(func(x):return chapter_json_equal(_object(x).get("step"),step)):logistics.steps.append({"step":step,"day":state.day+1,"phase":state.phase})

func uncle_support_pickup(logistics: Dictionary) -> bool:
	if not chapter_json_equal(logistics.get("status"),"committed"):return false
	if state.rice<logistics.rice or state.wood<logistics.wood:fail_contract("UNCLE_SUPPORT","家庭旧存不足，不能完成这次取料");return false
	state.rice-=logistics.rice;state.wood-=logistics.wood;logistics.status="picked_up";uncle_support_note(logistics,"pickup");return true

func advance_uncle_support_logistics(record: Dictionary,target: String="delivered") -> bool:
	var logistics: Dictionary=_object(record.get("supportLogistics"))
	if not chapter_json_equal(logistics.get("revision"),UNCLE_SUPPORT_REV):return false
	if not js_truthy(logistics.get("steps")):logistics.steps=[]
	if target=="picked_up":return uncle_support_pickup(logistics)
	if target=="delivered":
		if chapter_json_equal(logistics.get("status"),"committed"):
			uncle_support_pickup(logistics)
			if contract_error!="":return false
		if chapter_json_equal(logistics.get("status"),"picked_up"):logistics.status="delivered";uncle_support_note(logistics,"delivery");return true
		return false
	if target=="returned":
		if chapter_json_equal(logistics.get("status"),"picked_up"):state.rice+=logistics.rice;state.wood+=logistics.wood;logistics.status="returned";uncle_support_note(logistics,"return");return true
		return false
	fail_contract("UNCLE_SUPPORT","未知叔叔support实物步骤");return false

func _chapter7_parent_5_person_presence_label(person: String) -> String:
	var p: Dictionary=state.people.get(person,{})
	if not p.get("alive",false):return "已经死亡"
	if p.get("permanentLost",false):return "失散，无法再接回"
	if p.get("detainedUntil")!=null:return "被扣留，尚未返家"
	return "远行未归" if p.get("away",false) else ""

func uncle_crisis_record() -> Dictionary:return _object(state.memory.get(UNCLE_CRISIS_KEY))

func uncle_crisis_actual_return(record: Dictionary) -> bool:
	return not record.is_empty() and _whole_number(record.get("day")) and state.history.any(func(h):return chapter_json_equal(h.get("type"),"later-return") and h.get("event")==record.get("event") and h.get("day")==record.get("day",INF)-1)

func uncle_crisis_warned() -> bool:
	return state.get("knowledgeFacts",[]).any(func(k):return chapter_json_equal(k.get("id"),"uncle-crisis.warning") and k.get("day",INF)<state.day+1 and "player" in k.get("knownBy",[]) and "安仁叔叔" in k.get("knownBy",[]))

func uncle_crisis_entry_ready() -> bool:return uncle_crisis_actual_return(_object(state.memory.get("uncleBoundaryReturned"))) or uncle_crisis_warned() or js_truthy(state.memory.get("uncleBoundaryNoticeDay"))

func uncle_crisis_requirement(choice: Dictionary) -> Dictionary:
	var focus: Dictionary=state.focus;var event: Dictionary=_object(focus.get("laterEvents",{}).get(focus.get("eventId")));var record:=uncle_crisis_record();var stage: Variant=_object(event.get("uncleCrisis")).get("stage");var reason: String=""
	if not js_truthy(event.get("uncleCrisis")) or not chapter_json_equal(event.get("crisisRevision"),UNCLE_CRISIS_REV) or not event.get("choices",[]).any(func(c):return chapter_json_equal(c.get("id"),choice.get("id"))) or not later_event_eligible(event,focus.plan):reason="叔叔支线的当事人或场景已变化。"
	elif chapter_json_equal(stage,1) and (js_truthy(state.memory.get(UNCLE_CRISIS_KEY)) or not uncle_crisis_entry_ready()):reason="没有可接续的实际前情。"
	elif chapter_json_equal(stage,2) and (record.is_empty() or not chapter_json_equal(record.get("stage"),1) or js_truthy(record.get("closed")) or not uncle_crisis_actual_return(record) or not uncle_crisis_warned() or not can_work_later("安仁叔叔") or chapter_json_equal(state.memory.get("irreversibleDay"),state.day)):reason="尚无真实预告、前情未返家，或今天不适合继续面对危险。"
	elif chapter_json_equal(stage,3) and (record.is_empty() or not chapter_json_equal(record.get("stage"),2) or chapter_json_equal(record.get("status"),"pending") or not js_truthy(record.get("messageDay")) or "罗瑾" not in record.get("knownBy",[])):reason="还没有已经告知家里的确切后续。"
	elif chapter_json_equal(choice.get("id"),"hold") and state.people["安仁叔叔"].spirit<3:reason="叔叔已难以继续周旋，可以退出。"
	return {"met":reason.is_empty(),"reason":reason}

func uncle_preparation_source(focus: Dictionary,event: Dictionary) -> Dictionary:
	if not _whole_number(state.day):return {}
	var marker: Dictionary=_object(event.get("r4v10UnclePreparationSource"));var date: int=int(state.day)+1;var plan: Dictionary=_object(focus.get("plan"));var rows: Dictionary=_object(plan.get("rows"))
	if not chapter_json_equal(marker.get("revision"),UNCLE_PREP_SOURCE_REV) or state.saveVersion!=24 or state.ended or date<40 or date>43 or not chapter_json_equal(focus.get("day"),state.day) or not chapter_json_equal(plan.get("day"),state.day) or not chapter_json_equal(event.get("id"),"uncle.crisis.R4b.D"+str(date)+".1") or not chapter_json_equal(marker.get("day"),date) or not chapter_json_equal(marker.get("eventId"),event.id) or not chapter_json_equal(marker.get("target"),event.get("target")) or not chapter_json_equal(event.get("crisisRevision"),UNCLE_CRISIS_REV) or not chapter_json_equal(_object(event.get("uncleCrisis")).get("stage"),1) or not chapter_json_equal(event.get("actor"),"安仁叔叔") or not chapter_json_equal(event.get("conditionKind"),"uncle-crisis") or not event.get("participants") is Array or event.participants.size()!=1 or not chapter_json_equal(event.participants[0],"安仁叔叔") or not rows.has("罗瑾") or not rows.has("安仁叔叔") or not event.get("choices") is Array or event.choices.size()!=2 or not chapter_json_equal(_object(event.choices[0]).get("id"),"hear") or not chapter_json_equal(_object(event.choices[1]).get("id"),"decline"):return {}
	var uncle: Dictionary=_object(rows["安仁叔叔"]);var luo: Dictionary=_object(rows["罗瑾"])
	if chapter_json_equal(event.get("target"),"安仁叔叔"):
		if not uncle.get("outside",false) or uncle.get("inactive",false) or not chapter_json_equal(uncle.get("type"),"committee") or not chapter_json_equal(marker.get("mode"),"return_telling"):return {}
	elif chapter_json_equal(event.get("target"),"home"):
		if uncle.get("outside",false) or uncle.get("inactive",false):return {}
		var mode: String="home_witness" if not luo.get("outside",false) and not luo.get("inactive",false) else "return_telling"
		if not chapter_json_equal(marker.get("mode"),mode):return {}
	else:return {}
	return marker

func uncle_crisis_committed(record: Dictionary) -> bool:
	return _whole_number(record.get("day")) and chapter_json_equal(record.get("revision"),UNCLE_CRISIS_REV) and record.get("receipt") in state.get("effectLedger",{}).get("appliedEffectIds",[]) and state.history.any(func(h):return chapter_json_equal(h.get("type"),"later-choice") and h.get("event")==record.get("event") and h.get("choice")==record.get("choice") and h.get("day")==record.get("day",INF)-1)

func uncle_preparation_choice_committed(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	var record:=uncle_crisis_record();var ids: Array=state.get("effectLedger",{}).get("appliedEffectIds",[]);var index: Variant=focus.get("choiceIndex")
	if choice.is_empty() or not chapter_json_equal(focus.get("eventId"),event.get("id")) or index==null or not _whole_number(index) or index<0 or index>=event.choices.size() or not is_same(event.choices[int(index)],choice) or not chapter_json_equal(record.get("stage"),1) or not chapter_json_equal(record.get("event"),event.id) or not chapter_json_equal(record.get("day"),state.day+1) or not chapter_json_equal(record.get("choice"),choice.get("id")) or not chapter_json_equal(record.get("revision"),UNCLE_CRISIS_REV) or not uncle_crisis_committed(record):return false
	var id: String=state.seed+":D"+str(int(state.day)+1)+":"+event.id+":"+choice.id+":immediate";var packets: Array=focus.get("resultPackets",[]).filter(func(p):return p.get("id")==id)
	return packets.size()==1 and packets[0].get("timing")=="immediate" and packets[0].get("subjectId")=="安仁叔叔" and packets[0].get("status")=="applied" and ids.count(id)==1

func uncle_preparation_choice_returned(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	if not uncle_preparation_choice_committed(focus,event,choice):return false
	var id: String=state.seed+":D"+str(int(state.day)+1)+":"+event.id+":"+choice.id+":return";var packets: Array=focus.get("resultPackets",[]).filter(func(p):return p.get("id")==id);var ids: Array=state.get("effectLedger",{}).get("appliedEffectIds",[])
	return packets.size()==1 and packets[0].get("timing")=="on_return" and packets[0].get("subjectId")=="安仁叔叔" and packets[0].get("status")=="applied" and ids.count(id)==1

func uncle_preparation_return_allowed(focus: Dictionary,event: Dictionary) -> bool:
	if not event.has("r4v10UnclePreparationSource"):return true
	var marker:=uncle_preparation_source(focus,event);var index: Variant=focus.get("choiceIndex");var choice: Dictionary={}
	if _whole_number(index) and index>=0 and index<event.get("choices",[]).size():choice=event.choices[int(index)]
	return not marker.is_empty() and uncle_preparation_choice_returned(focus,event,choice) and (marker.mode=="home_witness" or understands("安仁叔叔"))

var uncle_crisis_prose: Dictionary={}

func make_uncle_crisis_event(focus: Dictionary,stage: int,target: String,bridge: bool,prior_returned: bool,companion: String) -> Dictionary:
	if uncle_crisis_prose.is_empty():uncle_crisis_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/uncle_crisis_prose.json"))
	var record:=uncle_crisis_record();var luo: Dictionary=_object(focus.plan.rows.get("罗瑾"));var luo_home: bool=not luo.get("outside",false);var tracked: bool=stage==1 and state.saveVersion==24 and focus.plan.get("day")==focus.day and js_truthy(focus.plan.rows.get("罗瑾"))
	var key: String=JSON.stringify([stage,target,bridge if stage==1 else false,luo_home,record.get("status","") if stage==3 else "",companion if stage==3 else "",tracked])
	if not uncle_crisis_prose.variants.has(key):fail_contract("UNCLE_CRISIS_PROSE","叔叔支线正文组合尚未接入。");return {}
	var event: Dictionary=decode_home_content(uncle_crisis_prose.events[uncle_crisis_prose.variants[key]],uncle_crisis_prose);var date: int=int(focus.day)+1
	event.id="uncle.crisis.R4b.D"+str(date)+"."+str(stage);event.uncleCrisis.entry="notice-bridge" if bridge else ("boundary-return" if prior_returned else "direct")
	if event.has("r4v10UnclePreparationSource"):
		event.r4v10UnclePreparationSource.day=date;event.r4v10UnclePreparationSource.eventId=event.id;event.r4v10UnclePreparationSource.target=target;event.r4v10UnclePreparationSource.mode="home_witness" if target=="home" and not luo.get("outside",false) and not luo.get("inactive",false) else "return_telling"
	return event

func bind_uncle_crisis(focus: Dictionary) -> bool:
	var date: int=int(focus.day)+1;var record:=uncle_crisis_record();var has_record: bool=js_truthy(state.memory.get(UNCLE_CRISIS_KEY))
	if focus.get("uncleRevision")!="R4b" or date<40 or date>48 or state.ended or not understands("罗瑾") or js_truthy(focus.plan.get("nodeId")) or js_truthy(focus.plan.get("recoveryOffer")) or focus.plan.get("key") in ["expeditionSearch","pigeonPickup"]:return true
	var prior: Dictionary=_object(state.memory.get("uncleBoundaryReturned"));var prior_returned: bool=uncle_crisis_actual_return(prior) and prior.day<date;var stage:=0;var target: String="";var bridge:=false;var row: Dictionary=_object(focus.plan.rows.get("安仁叔叔"))
	if not has_record and date<=43 and can_work_later("安仁叔叔") and (prior_returned or uncle_crisis_entry_ready()):stage=1;bridge=not prior_returned;target="安仁叔叔" if row.get("outside",false) and not row.get("inactive",false) and row.get("type")=="committee" else "home"
	elif chapter_json_equal(record.get("stage"),1) and not js_truthy(record.get("closed")) and _whole_number(record.get("day")) and date>=record.day+2 and date<=46 and uncle_crisis_actual_return(record) and uncle_crisis_warned() and can_work_later("安仁叔叔"):stage=2;target="安仁叔叔"
	elif chapter_json_equal(record.get("stage"),2) and js_truthy(record.get("settled")) and not chapter_json_equal(record.get("status"),"pending") and js_truthy(record.get("messageDay")) and date>record.messageDay:stage=3;target="home"
	else:return true
	var old: Dictionary=_object(focus.laterEvents.get(focus.plan.get("eventIds",{}).get(target)))
	if old.is_empty() or ["nodeId","motherCrisis","motherCare","uncleBoundary"].any(func(k):return js_truthy(old.get(k))) or _object(old.get("neighbourhood")).get("stage",0)>1 or _object(old.get("neighbourParcel")).get("stage",0)>1:return true
	if stage==1 and target=="home" and (not present("安仁叔叔") or row.get("outside",false) or row.get("inactive",false)):return true
	if (stage==2 or stage==1 and target=="安仁叔叔") and (not row.get("outside",false) or row.get("inactive",false) or row.get("type")!="committee"):return true
	if target=="home" and "home" not in focus.plan.targets:return true
	var companions: Array=PEOPLE.filter(func(n):return n!="罗瑾" and understands(n) and not _object(focus.plan.rows.get(n)).get("outside",false));var companion: String="" if companions.is_empty() else companions[0]
	if stage==3 and (companion=="" or _object(focus.plan.rows.get("罗瑾")).get("outside",false) or "罗瑾" not in record.get("knownBy",[])):return true
	var event:=make_uncle_crisis_event(focus,stage,target,bridge,prior_returned,companion)
	if event.is_empty():return false
	focus.uncleCrisisDisplaced={"id":old.id,"title":old.title};focus.laterEvents[event.id]=event;focus.plan.eventIds[target]=event.id;return true

func prepare_uncle_crisis_choice(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	if not js_truthy(event.get("uncleCrisis")):return true
	if not uncle_crisis_requirement(choice).met:fail_contract("UNCLE_CRISIS_PRECONDITION","叔叔支线前提已改变");return false
	var before: Dictionary={}
	for person in PEOPLE:before[person]={"spirit":state.people[person].spirit,"spiritMax":state.people[person].get("spiritMax",10)}
	var stage: Variant=event.uncleCrisis.stage;var record:=uncle_crisis_record().duplicate(true);var date: int=int(state.day)+1
	record.stage=stage;record.day=date;record.event=event.id;record.choice=choice.id;record.revision=UNCLE_CRISIS_REV
	if chapter_json_equal(stage,1):record.closed=choice.id=="decline";record.status="declined" if record.closed else "prepared"
	if chapter_json_equal(stage,2):
		var roll: float=float(RNG.hash_seed(state.seed+"|"+UNCLE_CRISIS_REV+"|outcome"))/4294967296.0
		record.roll=roll;record.rope=choice.id=="support" and tool_available("rope");record.riskRevision=UNCLE_RISK_REV;record.riskBand="fixed_high_risk" if choice.id=="hold" else "not_spirit_coupled"
		record.outcome="withdrawn" if choice.id=="withdraw" else (("transferred" if roll<(0.8 if record.rope else 0.6) else "stopped") if choice.id=="support" else ("escaped" if roll<0.5 else ("released" if roll<0.8 else "dead")))
		record.status="pending" if record.outcome in ["released","dead"] else record.outcome;record.settled=false;record.crisisDay=date;record.messageDue=date+2
		if choice.id=="support" and chapter_json_equal(event.get("supportRevision"),UNCLE_SUPPORT_REV):
			record.supportRevision=UNCLE_SUPPORT_REV;record.supportLogistics={"revision":UNCLE_SUPPORT_REV,"contract":"uncle-support-logistics","source":"household_old","carrier":"安仁叔叔","rice":3,"wood":2,"status":"committed","event":event.id,"day":date,"steps":[]}
		if uncle_crisis_prose.is_empty():uncle_crisis_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/uncle_crisis_prose.json"))
		var text: Dictionary=decode_home_content(uncle_crisis_prose.outcomes[record.outcome+("_rope" if record.rope else "")],uncle_crisis_prose);choice.closures.default=text.closure;choice.diaries.default=text.diary
	choice.immediateEffects=[{"type":"uncle_crisis_commit","record":record}];choice.returnEffects=event.participants.map(func(target):return {"type":"character_spirit","target":target,"amount":1}) if chapter_json_equal(stage,3) and choice.id=="sit" else []
	if chapter_json_equal(stage,2):
		var intervals: Dictionary={"deterministic":"withdrawn"} if choice.id=="withdraw" else ({"transferredBelow":0.8 if record.rope else 0.6} if choice.id=="support" else {"escapedBelow":0.5,"releasedBelow":0.8,"otherwise":"dead"})
		if not js_truthy(focus.get("riskAudits")):focus.riskAudits=[]
		var matching: Array=focus.riskAudits.filter(func(a):return a.get("event")==event.id and a.get("choice")==choice.id and a.get("kind")=="uncle")
		if matching.is_empty():
			focus.riskAudits.append({"kind":"uncle","event":event.id,"choice":choice.id,"day":date,"before":before,"contract":record.get("contract") if js_truthy(record.get("contract")) else record.revision,"revision":record.riskRevision,"riskRevision":record.riskRevision,"intervals":intervals,"locked":record.duplicate(true)});matching=[focus.riskAudits[-1]]
		if not js_truthy(state.memory.get("a3cT3")):state.memory.a3cT3={"revision":"A3c-T3-v1","knowledge":[],"spirit":[],"death":{}}
		var book: Dictionary=state.memory.a3cT3
		if not js_truthy(book.get("riskAudits")):book.riskAudits=[]
		var audit: Dictionary=matching[0]
		if not book.riskAudits.any(func(a):return a.get("event")==event.id and a.get("choice")==choice.id and a.get("kind")=="uncle" and a.get("day")==audit.day):book.riskAudits.append(audit.duplicate(true))
	return true

func apply_uncle_crisis_packet(packet: Dictionary) -> bool:
	var focus: Dictionary=state.focus
	var event: Dictionary=_object(focus.laterEvents.get(focus.eventId))
	var effect: Dictionary=_object(packet.effects[0])
	var choice: Dictionary={}
	for item in event.get("choices",[]):
		var effects: Array=item.get("immediateEffects",[])
		if not effects.is_empty() and chapter_json_equal(_object(_object(effects[0]).get("record")).get("event"),_object(effect.get("record")).get("event")) and chapter_json_equal(item.id,_object(effect.get("record")).get("choice")):choice=item;break
	if not chapter_json_equal(packet.get("status"),"pending") or state.effectLedger.appliedEffectIds.has(packet.id):return false
	var registered: bool=focus.resultPackets.any(func(p):return is_same(p,packet))
	if state.phase!="focusEvent" or focus.get("choiceIndex")!=null or not chapter_json_equal(focus.get("selected"),event.get("target")) or not registered or packet.get("timing")!="immediate" or packet.effects.size()!=1 or not js_truthy(event.get("uncleCrisis")) or not chapter_json_equal(event.get("crisisRevision"),UNCLE_CRISIS_REV) or choice.is_empty() or not uncle_crisis_requirement(choice).met or not chapter_json_equal(packet.get("subjectId"),event.get("actor")) or JS_JSON.encode(effect)!=JS_JSON.encode(choice.immediateEffects[0]):
		fail_contract("UNCLE_CRISIS_PACKET","叔叔支线合同不匹配");return false
	var record: Dictionary=effect.record.duplicate(true)
	if chapter_json_equal(record.stage,2) and choice.id=="support":
		if chapter_json_equal(record.get("supportRevision"),UNCLE_SUPPORT_REV) and chapter_json_equal(_object(record.get("supportLogistics")).get("revision"),UNCLE_SUPPORT_REV):
			advance_uncle_support_logistics(record,"delivered")
			if contract_error!="":return false
		else:
			if state.rice<3 or state.wood<2:fail_contract("UNCLE_CRISIS_PACKET","准备物资不足");return false
			state.rice-=3;state.wood-=2
	record.receipt=packet.id;state.memory[UNCLE_CRISIS_KEY]=record;packet.status="applied";state.effectLedger.appliedEffectIds.append(packet.id);return true

func before_uncle_crisis_return(focus: Dictionary,event: Dictionary) -> bool:
	var record: Dictionary=uncle_crisis_record()
	if not js_truthy(event.get("uncleCrisis")) or not chapter_json_equal(_object(event.get("uncleCrisis")).get("stage"),2) or js_truthy(record.get("settled")):return true
	if not uncle_crisis_committed(record) or not chapter_json_equal(record.get("event"),event.id) or not uncle_crisis_warned():fail_contract("UNCLE_CRISIS_RETURN","叔叔现场尚未实际选择，不能补算后果");return false
	if chapter_json_equal(record.get("status"),"pending"):
		state.people["安仁叔叔"].away=true;state.people["安仁叔叔"].detainedUntil=999;record.pendingOrigin={"event":record.event,"day":record.day,"choice":record.choice,"receipt":record.receipt,"revision":UNCLE_CRISIS_REV}
	else:
		deliver_fact({"factId":record.receipt,"recipients":["安仁叔叔"],"source":"安仁叔叔","scope":"本人亲历","mode":"experienced"})
		apply_spirit_fact({"factId":record.receipt,"person":"安仁叔叔","domain":"personal-experience","source":"uncle-return","amount":-3 if record.outcome=="escaped" else -2,"requiresKnowledge":true,"knowledgeScope":"本人亲历"})
		if record.outcome=="escaped":state.people["安仁叔叔"].health=max(1,state.people["安仁叔叔"].health-2);state.ailments["安仁叔叔"].wound=min(3,state.ailments["安仁叔叔"].wound+1);record.restUntil=state.day+3
	record.settled=true;return true

func process_uncle_crisis_morning() -> void:
	var record:=uncle_crisis_record();var date: int=int(state.day)+1
	if record.is_empty() or js_truthy(state.get("ended")):return
	var prose: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/uncle_crisis_morning_prose.json"))
	if chapter_json_equal(record.get("stage"),1) and not js_truthy(record.get("closed")) and date>46:record.closed=true;state.morningResults.append(prose[0])
	if not chapter_json_equal(record.get("stage"),2) or not uncle_crisis_committed(record) or not uncle_crisis_actual_return(record) or not js_truthy(record.get("settled")):return
	if chapter_json_equal(record.get("status"),"pending") and date>=record.messageDue:
		var origin: Dictionary=_object(record.get("pendingOrigin"));var uncle: Dictionary=state.people["安仁叔叔"]
		if not uncle_crisis_warned() or record.day<42 or record.day>46 or date>49 or record.event!="uncle.crisis.R4b.D"+str(int(record.day))+".2" or origin.get("event")!=record.event or origin.get("day")!=record.day or origin.get("revision")!=UNCLE_CRISIS_REV or origin.get("receipt")!=record.receipt or record.choice!="hold" or record.outcome not in ["released","dead"] or not uncle.alive or not js_truthy(uncle.get("away")) or not chapter_json_equal(uncle.get("detainedUntil"),999):return
		if chapter_json_equal(state.memory.get("irreversibleDay"),state.day):return
		if record.outcome=="dead":
			var cause: String="已预告且主动留下掩护后，被日本兵杀害；原同伴返回现场亲见并于后日告知"
			uncle.alive=false;uncle.away=false;uncle.health=0;uncle.erase("detainedUntil")
			record.knownBy=deliver_fact({"factId":record.receipt+":confirmed","recipients":PEOPLE.filter(func(p):return understands(p)),"source":"同伴到棚内说明亲见并辨认安仁死亡","scope":"confirmed-death"})
			apply_death_shock(record.receipt+":confirmed");state.memory.lastDeath={"name":"安仁叔叔","cause":cause,"day":state.day,"reviewId":UNCLE_CRISIS_REV};cancel_person_pending("安仁叔叔",cause);state.memory.irreversibleDay=state.day
			state.history.append({"type":"person-loss","day":state.day,"name":"安仁叔叔","kind":"death","cause":cause,"reviewId":UNCLE_CRISIS_REV,"origin":origin});state.morningResults.append(prose[1])
		else:
			uncle.away=false;uncle.erase("detainedUntil");uncle.health=max(1,uncle.health-2);state.ailments["安仁叔叔"].wound=min(3,state.ailments["安仁叔叔"].wound+1);change_spirit("安仁叔叔",-3);record.restUntil=date+2;state.morningResults.append(prose[2])
		record.status=record.outcome;record.messageDay=date
		if record.status!="dead":record.knownBy=deliver_fact({"factId":record.receipt+":returned","recipients":PEOPLE.filter(func(p):return understands(p)),"source":"叔叔实际返家并主动说明","scope":"本人返家与愿意说明的经过"})
		state.knowledgeFacts.append({"id":"uncle-crisis.confirmation","day":date,"knownBy":["player"]+record.knownBy,"scope":"同伴说明折返后亲见死亡并辨认身份；并非猜测未归" if record.status=="dead" else "叔叔本人已返家，可知其主动说出的经过"})
	elif record.status!="pending" and not js_truthy(record.get("messageDay")) and date>record.crisisDay:
		record.messageDay=date;record.knownBy=PEOPLE.filter(func(p):return understands(p));state.morningResults.append(prose[3] if record.outcome=="escaped" else prose[4])
	var speaker: String=""
	for person in record.get("knownBy",[]):
		if person!="罗瑾" and understands(person):speaker=person;break
	if js_truthy(record.get("messageDay")) and "罗瑾" not in record.get("knownBy",[]) and understands("罗瑾") and speaker!="":
		if record.status=="dead":
			deliver_fact({"factId":record.receipt+":confirmed","recipients":["罗瑾"],"source":speaker+"当面转述已确认死讯","scope":"confirmed-death"});apply_death_shock(record.receipt+":confirmed")
		else:deliver_fact({"factId":record.receipt+":returned","recipients":["罗瑾"],"source":speaker+"当面转述","scope":"本人返家与愿意说明的经过"})
		record.knownBy=record.get("knownBy",[])+["罗瑾"];state.morningResults.append(prose[5] if record.status=="dead" else prose[6])

func finish_uncle_crisis_diary(focus: Dictionary,event: Dictionary,choice: Dictionary) -> void:
	_chapter9_parent_17_finish_uncle_crisis_diary(focus,event,choice)
	if focus.day!=48 or focus.get("webM4EndReadingRevision")!="WebM4-D45D49-v1" or not focus.get("diaryAllowed",false) or state.photo.evidence:return
	for i in range(focus.get("chapterDiary",[]).size()):
		if focus.chapterDiary[i].begins_with("叔叔已经不能看见今天这一次清点。"):
			focus.chapterDiary[i]=focus.chapterDiary[i].replace("如今留下多少照片，便照实记多少；它们不能换他回来，也不能因为少了一些，就使他的那一生只剩一句没有做成。","今天留下的记述不能换他回来。我记得的仍有他平常怎样接话、怎样办过一趟差事，不只最后这一回；没有讲完的，也不替他编一句遗言。")

func r18_stable_family_day(plan: Dictionary) -> bool:
	if plan.is_empty() or js_truthy(plan.get("nodeId")) or plan.get("key") in ["expeditionSearch","pigeonPickup"]:return false
	var uncle: Dictionary=_object(state.memory.get("uncleCrisisR4b"));var mother: Dictionary=_object(state.memory.get("motherCrisisR4a"))
	return not chapter_json_equal(uncle.get("status"),"pending") and not (chapter_json_equal(mother.get("stage"),2) and not js_truthy(mother.get("returned")))

func r18_conflict_event(event: Dictionary) -> bool:
	for key in ["nodeId","motherCrisis","uncleCrisis","motherCare","uncleBoundary","messageThread","custodyHandoff","custodyOvernight","recovery","maintenance","expeditionSearch","pigeonPickup"]:
		if js_truthy(event.get(key)):return true
	return event.get("conditionKind") in ["recovery","weather"] or _object(event.get("neighbourParcel")).get("stage",0)>1 or _object(event.get("neighbourhood")).get("stage",0)>1

func r18_home_event(stage: int) -> Dictionary:
	var bank: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/grandfather_home_raw_scenes.json"));var event: Dictionary=bank["stage"+str(stage)].duplicate(true);var date: int=int(state.day)+1
	for choice in event.choices:
		if stage==1:choice.immediateEffects[0].value.day=date
		else:
			var value: Dictionary=_object(state.memory.get("grandfatherHomeR18")).duplicate(true);value.stage=2;value.visitDay=date;value.status="visited";value.outcome=choice.id;value.seenBy=["罗瑾","外祖父"];choice.returnEffects[0].value=value
	return event

func bind_r18_grandfather_home(focus: Dictionary) -> void:
	var plan: Dictionary=focus.plan;var date: int=int(state.day)+1;var record: Dictionary=_object(state.memory.get("grandfatherHomeR18"));var row: Dictionary=_object(_object(plan.get("rows")).get("外祖父"))
	if record.is_empty() and date>=39 and date<=41 and r18_stable_family_day(plan) and present("外祖父"):
		var id: String=plan.eventIds.get("home","");var old: Dictionary=_object(focus.laterEvents.get(id))
		if id!="" and not old.is_empty() and not r18_conflict_event(old):
			var event:=r18_home_event(1);event.id="later.D"+str(date)+".home."+event.id;focus.laterEvents[event.id]=event;plan.eventIds.home=event.id;focus.r18GrandfatherHomeStage=1
	elif chapter_json_equal(record.get("status"),"planned") and chapter_json_equal(record.get("stage"),1) and date>record.day and date<=record.day+6 and r18_stable_family_day(plan) and present("外祖父") and can_work_later("外祖父") and js_truthy(row.get("outside")) and not js_truthy(current_weather().get("severe")):
		var id: String=plan.eventIds.get("外祖父","");var old: Dictionary=_object(focus.laterEvents.get(id))
		if id!="" and not old.is_empty() and not r18_conflict_event(old):
			var event:=r18_home_event(2);event.id="later.D"+str(date)+".外祖父."+event.id;focus.laterEvents[event.id]=event;plan.eventIds["外祖父"]=event.id;row.type="grandfatherHomeVisit";row.base={};row.label="按先前说好的路去旧住处附近看看；不把这趟当成找木差事";focus.r18GrandfatherHomeStage=2;plan.r18GrandfatherHomeVisit=true

func repair_r18_home_presentation(focus: Dictionary) -> void:
	var plan: Dictionary=focus.plan;var date: int=int(focus.day)+1;var bank: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/grandfather_home_presentation_templates.json"));var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/grandfather_home_raw_scenes.json"))
	var visit_id: String="later.D"+str(date)+".外祖父.grandfather.home.R18.stage2";var event: Dictionary=_object(focus.laterEvents.get(plan.eventIds.get("外祖父")));var row: Dictionary=_object(plan.rows.get("外祖父"))
	if date>=40 and date<=44 and focus.day==state.day and plan.eventIds.get("外祖父")==visit_id and event.get("id")==visit_id and event.get("actor")=="外祖父" and event.get("target")=="外祖父" and not js_truthy(event.get("nodeId")) and chapter_json_equal(event.get("participants"),["外祖父"]) and chapter_json_equal(event.get("homeParticipants"),[]) and _object(event.get("r18GrandfatherHome")).get("revision")=="R18-family-v1" and chapter_json_equal(_object(event.get("r18GrandfatherHome")).get("stage"),2) and row.get("type")=="grandfatherHomeVisit" and js_truthy(row.get("outside")) and not js_truthy(row.get("inactive")) and event.get("choices",[]).size()==2:
		var valid:=true
		for base_choice in raw.stage2.choices:
			var choices: Array=event.choices.filter(func(c):return c.id==base_choice.id)
			if choices.size()!=1:valid=false;break
			var choice: Dictionary=choices[0];var fx: Array=choice.get("returnEffects",[]);var value: Dictionary=_object(_object(fx[0] if not fx.is_empty() else {}).get("value"))
			if _object(choice.get("diaries")).get("default")!=base_choice.diaries.default or fx.size()!=1 or fx[0].get("type")!="flag_set" or fx[0].get("flag")!="grandfatherHomeR18" or value.get("revision")!="R18-family-v1" or not chapter_json_equal(value.get("stage"),2) or value.get("visitDay")!=date or value.get("status")!="visited" or value.get("outcome")!=base_choice.id or not chapter_json_equal(value.get("seenBy"),["罗瑾","外祖父"]):valid=false;break
		if valid:
			for choice in event.choices:
				var replacements: Array=bank['[2,40,true]'].after.choices.filter(func(c):return c.id==choice.id);choice.diaries=choice.diaries.duplicate(true);choice.diaries.default=replacements[0].diaries.default;choice.returnEffects=choice.returnEffects.duplicate(true);choice.returnEffects[0].value.seenBy=event.participants.duplicate()
	if not js_truthy(plan.get("chapter8")) or focus.day!=state.day or date<39 or date>41:return
	event=_object(focus.laterEvents.get(plan.eventIds.get("home")));var choices: Array=event.get("choices",[]);var look: Dictionary={}
	for choice in choices:
		if choice.get("id")=="look":look=choice;break
	var marker: Dictionary=_object(event.get("r18GrandfatherHome"));var direct: String=raw.stage1.choices[0].diaries.default;var reported: String="我回来后，外祖父才说起白天拿出旧钥匙、同家里商量的事。我先问还能带回什么，听他说到“认不清是谁的，就别碰”，才发现自己又把回去看一眼，想成了去把缺的东西补回来。家里只说等能走时再看，没有人说那里已经重新成了家。"
	if event.get("id")!="later.D"+str(date)+".home.grandfather.home.R18.stage1" or event.get("actor")!="外祖父" or event.get("target")!="home" or marker.get("revision")!="R18-family-v1" or not chapter_json_equal(marker.get("stage"),1) or not chapter_json_equal(event.get("participants"),["外祖父"]) or look.is_empty():return
	var luo: Dictionary=_object(plan.rows.get("罗瑾"))
	if luo.get("outside")==true and not js_truthy(luo.get("inactive")) and look.diaries.default==direct:look.diaries.default=reported
	if not chapter_json_equal(event.get("homeParticipants"),["外祖父"]) or choices.size()!=2 or not is_same(choices[0],look) or choices[1].get("id")!="keep" or look.diaries.default not in [direct,reported]:return
	var expected: Dictionary=raw.stage1.choices[0].duplicate(true);expected.immediateEffects[0].value.day=date;expected.diaries.default=look.diaries.default
	if not chapter_json_equal(look,expected):return
	var replacement: Dictionary=bank['[1,39,true]' if look.diaries.default==direct else '[1,40,false]'].after.choices[0]
	look.label=replacement.label;look.hint=replacement.hint;look.closures.default=replacement.closures.default;look.diaries.default=replacement.diaries.default

func process_r18_home_morning() -> void:
	var record: Dictionary=_object(state.memory.get("grandfatherHomeR18"));var date: int=int(state.day)+1
	if record.get("status")=="planned" and chapter_json_equal(record.get("stage"),1) and date>record.day+6:
		record.status="missed_window";record.closed=true;record.followupDay=date
		if understands("外祖父"):state.morningResults.append("那几天一直没有凑出合适的路况和人手，外祖父没有为了赶一趟旧住处硬走出去。钥匙和地址仍留着；没去成不能改写成已经看过。")
	if chapter_json_equal(record.get("stage"),2) and record.get("status")=="visited" and not js_truthy(record.get("followupDay")) and date>record.visitDay:
		record.followupDay=date
		if understands("外祖父"):state.morningResults.append("外祖父把带回的旧纸和旧物单独收好，说“找得到自己的东西”同“原来的日子回来了”不是一回事；今天仍按眼前的棚屋和家用过日子。" if record.outcome=="own_only" else "外祖父说，昨天只是去看过旧处。"+("他没有把罗瑾没见过的路上经过补成一段完整故事；家里只知道他确认过旧处，也没拿不明物。" if record.outcome=="unseen_return" else "没有带回东西也不是白走一趟；至少知道那里已经不能照从前的生活直接接下去。"))

func r18_work_applied(focus: Dictionary,person: String) -> bool:
	var id: Variant=_object(focus.get("workPackets")).get(person)
	return js_truthy(id) and focus.get("resultPackets",[]).any(func(p):return p.get("id")==id and p.get("status")=="applied")

func r18_add_diary(focus: Dictionary,text: String) -> void:
	if not js_truthy(focus.get("diaryAllowed")) or not understands("罗瑾") or text=="":return
	if not focus.get("chapterDiary") is Array:focus.chapterDiary=[]
	if text not in focus.chapterDiary:focus.chapterDiary.append(text)

func r18_append(a: String,b: String) -> String:return b if a=="" else a+"\n\n"+b

func finish_r18_family_return(focus: Dictionary,before: Dictionary) -> void:
	_chapter9_parent_17_finish_r18_family_return(focus,before)
	if focus.get("settled",false) and focus.day==47 and not js_truthy(state.memory.get("luoPortraitR18")) and state.people["罗瑾"].alive:
		var portrait:=c9_luo_portrait();state.memory.luoPortraitR18={"revision":"R18-family-v1","day":focus.day+1,"primary":portrait.primary};r18_add_diary(focus,portrait.text)

func apply_r18_work_plan(plan: Dictionary) -> void:
	var mother: Dictionary=_object(state.memory.get("motherCrisisR4a"));var uncle: Dictionary=_object(state.memory.get("uncleCrisisR4b"));var rows: Dictionary=_object(plan.get("rows"));var mr: Dictionary=_object(rows.get("母亲"));var ur: Dictionary=_object(rows.get("安仁叔叔"));var date: int=int(state.day)+1
	if mother.get("outcome") in ["beaten","assault"] and js_truthy(mother.get("returned")) and js_truthy(mother.get("restUntil")) and date>mother.restUntil and not js_truthy(state.memory.get("motherAftermathR18Done")) and js_truthy(mr.get("outside")) and not js_truthy(mr.get("inactive")) and not js_truthy(plan.get("nodeId")) and mr.get("type") not in ["search","pigeonPickup"]:
		plan.r18MotherAftermathOriginal={"label":mr.label};mr.label="先走熟悉的一段路，能停便停；不把“重新出门”当成已经恢复";plan.r18MotherAftermath=true
	if uncle.get("outcome") in ["escaped","released"] and js_truthy(uncle.get("restUntil")) and date>uncle.restUntil and not js_truthy(state.memory.get("uncleAftermathWorkR18")) and js_truthy(ur.get("outside")) and not js_truthy(ur.get("inactive")) and ur.get("type")=="committee" and not js_truthy(plan.get("nodeId")):
		plan.r18UncleAftermathOriginal={"label":ur.label}
		if _object(ur.get("base")).has("rice"):plan.r18UncleAftermathOriginal.rice=ur.base.rice
		if ur.get("base",{}).get("rice") is int or ur.get("base",{}).get("rice") is float:ur.base.rice=max(1,ur.base.rice-1)
		ur.label="伤后第一次再接差事，只做能做的一段，不把旧伤当作已经过去";plan.r18UncleAftermath=true

func bind_r18_aftermath(focus: Dictionary) -> void:
	var plan: Dictionary=focus.plan
	if js_truthy(plan.get("r18MotherAftermath")):
		var event: Dictionary=_object(focus.laterEvents.get(plan.eventIds.get("母亲")))
		if not event.is_empty() and not r18_conflict_event(event):
			var extra: String="母亲今天第一次在暂缓出工以后重新走一段熟悉的路。她先把回程和能停下的地方问清，没有把能迈出棚口当成已经回到从前。家里也没有催她走得更远。" if _object(state.memory.get("motherCrisisR4a")).get("outcome")=="assault" else "母亲今天第一次在养伤以后重新接一点熟悉的事。她起身时仍会避着疼处，先说明只做能做的一段；能够重新出门，不等于挨打留下的伤已经消失。"
			event.intro=r18_append(event.intro,extra);focus.r18MotherAftermath=true;event.r18MotherAftermath=true
		else:
			if js_truthy(plan.get("r18MotherAftermathOriginal")):plan.rows["母亲"].label=plan.r18MotherAftermathOriginal.label
			plan.erase("r18MotherAftermath")
	if js_truthy(plan.get("r18UncleAftermath")):
		var event: Dictionary=_object(focus.laterEvents.get(plan.eventIds.get("安仁叔叔")))
		if not event.is_empty() and not r18_conflict_event(event):event.intro=r18_append(event.intro,"叔叔这是伤后第一次重新接普通差事。今天没有人因为他从前能做多少，就把同样的分量重新压给他；他只把能完成的一段接下，回程所得也只按实际做完的算。");focus.r18UncleAftermath=true;event.r18UncleAftermath=true
		else:
			var original: Dictionary=_object(plan.get("r18UncleAftermathOriginal"))
			if not original.is_empty():
				plan.rows["安仁叔叔"].label=original.label
				if original.get("rice") is int or original.get("rice") is float:plan.rows["安仁叔叔"].base.rice=original.rice
			plan.erase("r18UncleAftermath")

const PHOTO_END_CONTRACT="photo-end-v1"

const PHOTO_END_LOCATION="棚内另包存放的照片"

func photo_transfer_requirement() -> Dictionary:
	var p: Dictionary=state.photo;var row: Dictionary=_object(_object(_object(state.get("focus")).get("plan")).get("rows",{}).get("罗瑾"));var date: int=int(state.day)+1
	if p.strategy=="conceal" and date==44 and p.transferCount>0 and p.album.selected<minf(16,p.prints):return {"met":false,"reason":"今天先把仍未核清的成片整理成下一小包"}
	var reason: String=""
	if state.ended or date<45 or date>49 or not can_work_later("罗瑾") or not js_truthy(row.get("outside")) or row.get("type")!="photo" or not p.employed or not js_truthy(p.evidence):reason="今天无法由罗瑾实际从照相馆带出"
	elif state.people["罗瑾"].spirit<=2:reason="心神太乱，今天先保住自己"
	elif p.album.selected<=p.transferCount:reason="尚无已选定、仍待带离暗房的成片"
	if reason=="":return {"met":true,"reason":""}
	var early: bool=p.strategy=="conceal" and date>=42 and date<=44 and not js_truthy(_object(state.focus.get("plan")).get("nodeId")) and can_work_later("罗瑾") and js_truthy(row.get("outside")) and row.get("type")=="photo" and p.employed and js_truthy(p.evidence) and state.people["罗瑾"].spirit>2 and p.album.selected>p.transferCount
	return {"met":early,"reason":"" if early else reason}

func bind_c8_early_transfer(focus: Dictionary) -> void:
	var date: int=int(focus.day)+1
	if state.photo.strategy!="conceal" or date<42 or date>44 or js_truthy(focus.plan.get("nodeId")) or not photo_transfer_requirement().met:return
	var event: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get("罗瑾")))
	if event.is_empty() or js_truthy(event.get("nodeId")):return
	event.photoMid=false;event.photoEnd=true;event.r19PhotoTransfer={"revision":"R19-photo-routes-v1","mode":"conceal","early":true};focus.plan.photoOpportunity="transfer_early"
	var prose: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_eight_early_transfer_scene.json"))
	for key in prose:event[key]=prose[key].duplicate(true) if prose[key] is Array or prose[key] is Dictionary else prose[key]

func prepare_c8_early_transfer(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	if not js_truthy(choice.get("photoTransfer")):return true
	if not js_truthy(_object(event.get("r19PhotoTransfer")).get("early")) or state.day<41 or state.day>43:fail_contract("C8_TRANSFER_SCOPE","只接入第42至44日提前分散候选。");return false
	var requirement:=photo_transfer_requirement()
	if not requirement.met:fail_contract("PHOTO_TRANSFER_REQUIREMENT",requirement.reason);return false
	var p: Dictionary=state.photo;var large: bool=choice.photoTransfer.size=="more";var before: Dictionary={}
	for person in PEOPLE:before[person]={"spirit":state.people[person].spirit,"spiritMax":state.people[person].get("spiritMax",10)}
	var available: float=maxf(0,minf(p.album.selected,p.prints)-p.transferCount)
	var chance: float=clampf((0.60 if large else 0.82)+(0.08 if route_use_by_luo() else 0.0)+(0.04 if state.people["罗瑾"].spirit>=7 else 0.0)-p.attention*0.035,0.30,0.94)
	var roll:=random_value();var amount: float=minf(16 if large else 8,available) if roll<chance else 0
	var record: Dictionary={"contract":PHOTO_END_CONTRACT,"event":event.id,"day":state.day,"amount":amount,"roll":roll,"chance":chance,"applied":false,"location":PHOTO_END_LOCATION};focus.photoTransferReceipt=record
	choice.immediateEffects=choice.photoTransfer.finish.duplicate(true)+[{"type":"photo_progress","op":"transferred_delta","value":amount,"contract":PHOTO_END_CONTRACT},{"type":"photo_progress","op":"attention_delta","value":0 if amount else -1},{"type":"character_spirit","target":"罗瑾","amount":-2 if large else -1},{"type":"flag_set","flag":"closure_method","value":"carried_to_shelter" if amount else "retreated_with_photos"}]
	if not focus.has("riskAudits"):focus.riskAudits=[]
	var audits: Array=focus.riskAudits.filter(func(a):return a.event==event.id and a.choice==choice.id and a.kind=="photo-end")
	if audits.is_empty():
		focus.riskAudits.append({"kind":"photo-end","event":event.id,"choice":choice.id,"day":state.day+1,"before":before,"contract":PHOTO_END_CONTRACT,"revision":PHOTO_END_CONTRACT,"riskRevision":"legacy-spirit-coupled-v1","intervals":{"chance":chance,"amount":amount},"locked":record.duplicate(true)});audits=[focus.riskAudits[-1]]
	var book:=spirit_book()
	if not book.has("riskAudits"):book.riskAudits=[]
	var audit: Dictionary=audits[0]
	if not book.riskAudits.any(func(a):return a.event==event.id and a.choice==choice.id and a.kind=="photo-end" and a.day==audit.day):book.riskAudits.append(audit.duplicate(true))
	var next: float=minf(6,amount) if amount>0 else (minf(6,available) if roll<minf(0.98,chance+0.15) else 0)
	record.amount=next
	for effect in choice.immediateEffects:
		if effect.get("type")=="photo_progress" and effect.get("op")=="transferred_delta":effect.value=next;break
	if not p.has("r19"):p.r19={}
	p.r19.transferActions=p.r19.get("transferActions",0)+1
	if next>0:p.r19.earlyTransfers=p.r19.get("earlyTransfers",0)+1
	var bank: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/c8_early_transfer_prose.json"));var key: String=("direct" if amount>0 else ("boost" if next>0 else "retreat"))+":"+str(int(next))
	if not bank.has(key):fail_contract("C8_TRANSFER_PROSE","提前分散结果正文尚缺。");return false
	choice.closures={"default":bank[key].closure};choice.diaries={"default":bank[key].diary};return true

func apply_c8_photo_end_delta(value: Variant,effect: Dictionary) -> bool:
	var record: Dictionary=_object(state.focus.get("photoTransferReceipt"));var p: Dictionary=state.photo
	if record.is_empty() or js_truthy(record.get("applied")) or record.get("day")!=state.day or record.get("contract")!=effect.get("contract") or effect.get("contract")!=PHOTO_END_CONTRACT or not chapter_json_equal(record.get("amount"),value) or not _whole_number(value) or value<0 or p.transferCount+value>minf(p.prints,p.album.selected):fail_contract("PHOTO_TRANSFER_DELTA","转移不属于当前实际结果包");return false
	p.transferCount+=value
	if value>0:p.transfer=record.location;photo_stage_advance("transferred")
	record.applied=true;return true

func _chapter7_parent_18_make_pre_photo_plan(day: int=-1) -> Dictionary:
	if day<0:day=int(state.day)
	if day<10 or day>37:
		fail_contract("LATER_PLAN_SCOPE","当前测试支持第11至38日、无远行的日程模型。");return {}
	if not process_pre_photo_story_morning():fail_contract("STORY_MORNING_PENDING","此剧情晨间结果尚未迁移。");return {}
	var date: int=day+1;var rows: Dictionary={};var adults: Array=PEOPLE.slice(1)
	for person in PEOPLE:rows[person]=_work_row(person,"留在棚里，处理手边的家事")
	var keys=JSON.parse_string(FileAccess.get_file_as_string("res://data/late_day_keys.json"));var key: String=keys[str(date)]
	if date==13 and state.memory.get("burialAccepted",false):key="burialPrepare"
	if date==14 and state.memory.get("burialAccepted",false):key="burial"
	var primary: String="罗瑾" if key=="burial" else ("母亲" if key=="register" else ("安仁叔叔" if key=="inquiry" else ("罗瑾" if key in ["apprentice","oldphoto","materials"] and state.photo.employed else "home")))
	var balanced: bool=state.balanceVersion=="I2f"
	var yields: Dictionary={"母亲":{"rice":3 if balanced else 2},"外祖父":{"wood":5 if balanced else 3},"安仁叔叔":{"rice":3 if balanced else 2}}
	var worker: String=adults[(date-11)%3];var urgent:=false
	if balanced:
		var wood_need: bool=state.wood<=4 and can_work_later("外祖父");var food_need: bool=state.rice<=2
		var available: Array=["母亲","安仁叔叔"].filter(func(person):return can_work_later(person))
		var food_worker: String=available[date%2] if available.size()>date%2 else (available[0] if not available.is_empty() else "")
		if wood_need and (not food_need or float(state.wood)/2<=state.rice or food_worker==""):worker="外祖父";urgent=true
		elif food_need and food_worker!="":worker=food_worker;urgent=true
		if state.water<=1 and not can_work_later("罗瑾"):
			if not can_work_later(worker):
				for adult in adults:
					if can_work_later(adult):worker=adult;break
			if can_work_later(worker):urgent=true
	if date%4!=0 or urgent:
		rows[worker]=_work_row(worker,{"母亲":"到已问过的救济点排队","外祖父":"到附近收拢旧木料","安仁叔叔":"到委员会相关差事处做杂务"}[worker],{"母亲":"relief","外祖父":"wood","安仁叔叔":"committee"}[worker],true,yields[worker].duplicate(true))
		if urgent:rows[worker].reason="resource-need"
	if primary=="母亲":rows["母亲"]=_work_row("母亲","到登记处外问清手续，回程到已问过的救济处","registration",true,{"rice":3,"water":2});rows["母亲"].registrationProtocol="inquiry-I3e-4b"
	if primary=="安仁叔叔":rows["安仁叔叔"]=_work_row("安仁叔叔","办过差事以后，沿熟悉的路回来","committee",true,{"rice":2})
	if key=="burial":rows["罗瑾"]=_work_row("罗瑾","跟着已经问清的队伍做收殓帮手","burial",true,{})
	if state.photo.employed and date>=23 and date%5!=0:rows["罗瑾"]=_work_row("罗瑾","到照相馆做杂活，协助师傅","photo",true,{})
	if state.water<=2:
		var return_water: bool=balanced and not current_weather().get("severe",false) and rows["罗瑾"].type=="photo" and adults.any(func(person):return rows[person].outside and can_work_later(person))
		if not return_water:rows["罗瑾"]=_work_row("罗瑾","存水不多，今天先沿认过的近路取水","water",true,{"water":(4 if tool_available("bucket") else (3 if tool_available("canteen") else 2)) if balanced else 2})
	if key=="newyear":rows["罗瑾"]=_work_row("罗瑾","留在棚里，把新一年的日期记下")
	if date==13 and state.memory.get("burialAccepted",false):rows["罗瑾"]=_work_row("罗瑾","留在棚里，核清跟队的规矩和实际工具")
	var node_id: Variant=null
	var priority: Array=["deadline"] if date==36 else ["names","sources","employ","discover","trial","firstPrint","deadline"]
	for id in priority:
		var node: Dictionary=state.fixedNodeStates[id]
		if date<node.due or chapter_five_node_done(node):continue
		var eligible: bool=understands("罗瑾")
		if id=="trial":eligible=date==node.due and state.photo.employed and state.photo.evidence>0 and can_work_later("罗瑾")
		elif id in ["discover","firstPrint"]:eligible=can_work_later("罗瑾") and state.photo.employed and (id=="discover" or state.photo.evidence>0)
		if eligible:node_id=id;break
	if node_id in ["discover","trial","firstPrint"]:
		rows["罗瑾"]=_work_row("罗瑾","到照相馆；今天有一件仍需亲自面对的事","photo",true,{});primary="罗瑾"
	elif node_id!=null:
		rows["罗瑾"]=_work_row("罗瑾","留在棚里，处理今天需要说清的事");primary="home"
	for person in PEOPLE:
		var p: Dictionary=state.people[person];var row: Dictionary=rows[person]
		if not p.alive or p.away or p.get("permanentLost",false) or p.get("detainedUntil")!=null:row.inactive=true;row.outside=false;row.base={};row.label=person_presence_label(person)
		elif row.outside and (not can_work_later(person) or (current_weather().get("severe",false) and (not tool_available("umbrella") or current_weather().id in ["blizzard","hail"]))):
			row.outside=false;row.base={};row.type="home";row.label="天气不宜赶路，今天留在棚里" if can_work_later(person) else "身体不适，今天留在棚里"
	if node_id in ["discover","trial","firstPrint"] and not rows[primary].outside:
		state.fixedNodeStates[node_id].fallback="当日无法到达地点，不计合适日";node_id=null
	var search: Dictionary=_object(_object(state.expedition.get("active")).get("search"))
	if search.get("day")==day and search.get("status")=="planned":
		if node_id!=null:fail_contract("SEARCH_NODE_CONFLICT","寻找不能挤占已到期剧情节点");return {}
		if search.get("mode")=="luo":rows["罗瑾"]=_work_row("罗瑾","沿约好的路线寻找家人；今天不做普通差事","search",true,{});primary="罗瑾"
		else:rows["罗瑾"]=_work_row("罗瑾","留在棚边，把家人的衣着和约定去处说清");primary="home"
		key="expeditionSearch"
	if plan_pigeon_pickup(day,node_id,key=="expeditionSearch"):rows["罗瑾"]=_work_row("罗瑾","按核对过的纸条取物，今天不做普通差事","pigeonPickup",true,{});primary="罗瑾";key="pigeonPickup"
	if balanced and state.water<=2 and not (rows["罗瑾"].type=="water" and rows["罗瑾"].outside) and not current_weather().get("severe",false):
		for adult in adults:
			if rows[adult].outside and not rows[adult].get("inactive",false) and can_work_later(adult):
				if rows[adult].base.get("water",0)<2:rows[adult].base.water=2;rows[adult].label+="，回程沿认过的近路取少量水"
				break
	for person in PEOPLE:
		var reason:=character_rest_reason(person)
		if reason!="" and not rows[person].get("inactive",false):rows[person].outside=false;rows[person].base={};rows[person].type="home";rows[person].label=reason
	var targets: Array=PEOPLE.filter(func(person):return rows[person].outside and not rows[person].get("inactive",false))
	if PEOPLE.any(func(person):return not rows[person].outside and not rows[person].get("inactive",false)):targets.append("home")
	if primary not in targets:primary="home" if "home" in targets else (targets[0] if not targets.is_empty() else "")
	if node_id!=null:
		var node: Dictionary=state.fixedNodeStates[node_id]
		if not node.eligibleDays.any(func(value):return value==date):node.eligibleDays.append(date)
		node.fallback=null
	if key in ["pigeonPickup","expeditionSearch"]:targets=[primary]
	return {"day":day,"rows":rows,"targets":targets,"primary":primary,"nodeId":node_id,"key":key,"photoWorkRules":"I2b-5a","reason":"固定节点优先，其次工作节奏、需求及可用性"}

func _chapter7_parent_18_process_pre_photo_story_morning() -> bool:
	if state.day<=30:return _chapter6_parent_8_process_pre_photo_story_morning()
	if state.day<10 or state.ended or not state.people["罗瑾"].alive:return true
	if state.day>38:return false
	for key in ["uncleBoundaryReturned","uncleCrisisR4b","grandfatherHomeR18"]:
		if state.memory.get(key)!=null:return false
	var initial=JSON.parse_string(FileAccess.get_file_as_string("res://data/story_initial_state.json"))
	if not state.has("fixedNodeStates"):state.fixedNodeStates={}
	for id in initial.fixedNodeStates:
		if not state.fixedNodeStates.has(id):state.fixedNodeStates[id]=initial.fixedNodeStates[id].duplicate(true)
	for key in ["pendingMorningPackets","storyMorningDays","knowledgeFacts"]:
		if not state.has(key):state[key]=[]
	var date: int=int(state.day)+1
	if state.storyMorningDays.any(func(value):return value==date):return true
	if state.pendingMorningPackets.any(func(packet):return packet.get("scheduledDay",INF)<=state.day and packet.get("status")=="pending"):return false
	if date>=22 and not state.photo.employed and not chapter_five_node_done(state.fixedNodeStates.employ) and not understands("罗瑾") and ["母亲","安仁叔叔","外祖父"].any(func(person):return understands(person)) and not js_truthy(state.memory.get("employment_offer_pending")):
		if not state.has("storySystemPackets"):state.storySystemPackets=[]
		var id: String=state.seed+":D"+str(date)+":system:employment-offer-pending"
		var found: Array=state.storySystemPackets.filter(func(packet):return packet.id==id)
		var packet: Dictionary={"id":id,"timing":"next_morning","subjectId":"family","effects":[{"type":"flag_set","flag":"employment_offer_pending","value":true}],"status":"pending"} if found.is_empty() else found[0]
		if found.is_empty():state.storySystemPackets.append(packet)
		apply_ordinary_pre_photo_packet(packet)
		state.morningResults.append("照相馆帮工的消息先由在场的大人接下；罗瑾还不能听清规矩，今天不算已经上工。")
	if date>=36 and not state.photo.deadline.announced:
		family_system_packet([{"type":"photo_progress","op":"deadline_transition","value":"announced"}],"deadline-announced")
		state.morningResults.append("照相馆传来店铺腾空的期限；到一月三十日，暗房便不能再照常使用。")
		deadline_notice_delivery()
	if relay_deadline_notice():state.morningResults.append("先前送来的店铺期限，如今也向罗瑾说明了；这条消息不涉及他私下有没有留下照片。")
	if contract_error!="":return false
	if date>state.fixedNodeStates.trial.due and not chapter_five_node_done(state.fixedNodeStates.trial):
		state.fixedNodeStates.trial.status="skipped";state.fixedNodeStates.trial.fallback="当日试印未执行，不顺延"
	for id in ["names","sources","discover","firstPrint","disclose"]:
		var node: Dictionary=state.fixedNodeStates[id]
		if date>node.due and not chapter_five_node_done(node) and not node.eligibleDays.is_empty():state.morningResults.append({"names":"前些天记下的寻人消息，仍有来处没问清。","sources":"几张纸上的听说与亲见，还需要分开放。","discover":"罗瑾惦记着店里的暗房；有机会时，还想亲自留意那里的情形。","firstPrint":"暗房里那一点空隙还没有用上；罗瑾仍在考虑自己能做到哪一步。","disclose":"罗瑾仍想找一个家人在旁的时候，把能说的部分说清。"}[id])
	process_mother_care_morning()
	process_chapter_seven_uncle_notice()
	process_mother_crisis_morning()
	state.storyMorningDays.append(state.day+1)
	return true


func _chapter7_parent_19_apply_chapter_maintenance(focus: Dictionary) -> void:
	if state.day<31:_chapter6_parent_9_apply_chapter_maintenance(focus);return
	var current: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get("home")))
	if current.is_empty() or state.wood<=0:return
	var low: bool=current.id.ends_with(".maintenance");var fresh: bool=(current.has("neighbourhood") and current.neighbourhood.get("stage")==1 and not js_truthy(current.neighbourhood.get("prior"))) or (current.has("neighbourParcel") and current.neighbourParcel.get("stage")==1 and not js_truthy(current.neighbourParcel.get("prior"))) or current.id.begins_with("neighbour.day.R2b.")
	if not low and not (state.shelter<21 and fresh):return
	var raw:=make_pre_photo_condition_home(focus)
	if raw.get("conditionKind")!="maintenance":return
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].get("outside",false));var adults: Array=home.filter(func(person):return person!="罗瑾");var actor: String=adults[0] if not adults.is_empty() else "罗瑾"
	var event: Dictionary=raw.duplicate(true);event.later=true;event.historyClass="情境演绎；白天家庭维护为游戏安排，不是历史日期事实";event.id="later.D"+str(int(state.day)+1)+".home."+raw.id;event.target="home";event.actor=actor;event.participants=home.duplicate();event.homeParticipants=home.duplicate()
	if not low:focus.dayMaintenanceDisplaced={"id":current.id,"title":current.title,"reason":"shelter_below_21_with_wood","freshNeighbour":true}
	focus.laterEvents[event.id]=event;focus.plan.eventIds.home=event.id


func _chapter7_parent_19_apply_middle_reading_context(focus: Dictionary) -> void:
	if focus.get("middleReadingRevision")!="I3e-4c1" or focus.get("middleReadingBound",false):return
	for event in focus.laterEvents.values():
		if event.get("nodeId")=="names" and js_truthy(state.memory.get("visitorNameRecorded")):
			event.intro=event.intro.replace("早些时候有个女人沿棚边问人，罗瑾听过，留了几笔。","今天另有一位女人沿棚边问人，找的不是先前记下的那个人。罗瑾听她讲过，另留了几笔。")
			for choice in event.choices:choice.diaries.default=choice.diaries.default.replace("今天重写一个名字","今天整理另一位来人留下的姓名").replace("我今天没有将那页重抄","今天新记的那页，我没有再重抄")
		if event.get("nodeId")=="employ":event.intro=event.intro.replace("家里没有一个清醒的大人坐在旁边替他问。","这会儿没有能在旁边替他问的大人。")
		for choice in event.choices:
			if choice.get("diaries",{}).get("default")!=null:choice.diaries.default=choice.diaries.default.replace("她说同行的人提到日本兵以后就没找回来，可她也没看见究竟去了哪里。","妇人讲起同行的人没有回来时，提到了日本兵，却没看见那人究竟去了哪里。")
	focus.middleReadingBound=true


func _chapter7_parent_19_bind_day_eleven_twelve(focus: Dictionary) -> bool:
	if state.day<31:return _chapter6_parent_9_bind_day_eleven_twelve(focus)
	if int(state.day) not in range(10,38) or focus.plan.get("key")=="pigeonPickup":return false
	var fresh: bool=focus.get("laterEvents",{}).is_empty()
	focus.laterEvents={};focus.plan.eventIds={};focus.plan.photoMidContract="photo-mid-v1";focus.plan.chapter7=true
	if state.day==31:focus.webM3ReadingRevision="WebM3-D25D32-v1"
	else:focus.webM3bReadingRevision="WebM3-D33D38-v1"
	for target in focus.plan.targets:
		var event: Dictionary=expedition_search_bound_event(focus) if focus.plan.key=="expeditionSearch" else make_bound_chapter_seven_node(focus) if target==focus.plan.primary and js_truthy(focus.plan.get("nodeId")) else (make_chapter_home_base(focus) if target=="home" else make_pre_photo_outdoor_event(focus,target))
		if event.is_empty():return false
		focus.laterEvents[event.id]=event;focus.plan.eventIds[target]=event.id
		if target=="home" and event.get("conditionKind")=="recovery":
			var offer:=pre_photo_recovery_offer(focus)
			if offer.is_empty():return false
			var prior_care:=make_pre_photo_care_event(focus,true)
			if prior_care.is_empty():return false
			focus.laterEvents[prior_care.id]=prior_care
			focus.plan.rows[offer.actor].label+="；邻棚有人带来物品询问换粮"
			focus.plan.recoveryOffer={"kind":offer.kind,"item":offer.item,"cost":offer.cost,"day":offer.day}
	if not bind_chapter_seven_photo_optional(focus):return false
	bind_mother_care(focus)
	if not bind_chapter_rope(focus):return false
	if not bind_neighbour_parcel(focus):return false
	# Ordinary neighbour-day scenes start outside this chapter.
	if not bind_mother_crisis(focus):return false
	apply_chapter_maintenance(focus)
	var base_home: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get("home")))
	focus.homeAdmissionAudit=home_reception_status(focus);focus.homeAdmissionAudit.eventId=base_home.get("id");focus.homeAdmissionAudit.actor=base_home.get("actor")
	focus.webR3NeighbourRevision="WebR3-neighbour-prose-v1"
	if base_home.has("neighbourhood"):
		var decorated:=make_rope_event(focus,{"allowed":true,"actor":base_home.actor,"home":focus.homeAdmissionAudit.home,"resting":focus.homeAdmissionAudit.resting})
		if decorated.is_empty():return false
		base_home.clear()
		for key in decorated:base_home[key]=decorated[key]
	if base_home.get("conditionKind") in ["care","recovery"] and not chapter_seven_care_reader.decorate(self,focus,base_home):return false
	if base_home.has("neighbourParcel"):
		var decorated:=make_parcel_event(focus,{"allowed":true,"actor":base_home.actor,"home":focus.homeAdmissionAudit.home,"resting":focus.homeAdmissionAudit.resting})
		if decorated.is_empty():return false
		base_home.clear()
		for key in decorated:base_home[key]=decorated[key]
	apply_rope_memory_echo(focus,base_home)
	var message_admission:=message_thread_admission(focus)
	focus.messageAdmissionAudit={"revision":"WebR5-messages-v1","allowed":message_admission.allowed,"reason":message_admission.reason,"stage":message_admission.get("stage") if js_truthy(message_admission.get("stage")) else null,"actor":message_admission.get("actor") if js_truthy(message_admission.get("actor")) else null}
	if message_admission.allowed:
		var old: Dictionary=focus.laterEvents[focus.plan.eventIds.home];var event:=make_message_thread_event(focus,message_admission)
		if event.is_empty():return false
		focus.messageDisplaced={"id":old.id,"title":old.title};focus.laterEvents[event.id]=event;focus.plan.eventIds.home=event.id
	var same_day:=custody_handoff_admission(focus)
	focus.custodyAdmissionAudit={"revision":CUSTODY_HANDOFF_REV,"allowed":same_day.allowed,"reason":same_day.reason,"actor":same_day.get("actor") if js_truthy(same_day.get("actor")) else null,"kind":same_day.get("kind") if js_truthy(same_day.get("kind")) else null}
	if same_day.allowed:
		var event:=make_custody_handoff_event(focus,same_day)
		if event.is_empty():return false
		var old: Dictionary=focus.laterEvents[focus.plan.eventIds.home];focus.custodyDisplaced={"id":old.id,"title":old.title};focus.laterEvents[event.id]=event;focus.plan.eventIds.home=event.id
	focus.custodyNightRevision=CUSTODY_NIGHT_REV;var overnight:=custody_night_admission(focus)
	focus.custodyNightAdmission={"revision":CUSTODY_NIGHT_REV,"allowed":overnight.allowed,"reason":overnight.reason,"actor":overnight.get("actor") if js_truthy(overnight.get("actor")) else null,"kind":overnight.get("kind") if js_truthy(overnight.get("kind")) else null}
	if overnight.allowed:
		var event:=make_custody_night_event(focus,overnight)
		if event.is_empty():return false
		var old: Dictionary=focus.laterEvents[focus.plan.eventIds.home];focus.custodyNightDisplaced={"id":old.id,"title":old.title};focus.laterEvents[event.id]=event;focus.plan.eventIds.home=event.id
	if focus.plan.eventIds.has("home"):connect_pre_photo_qian(focus,focus.laterEvents[focus.plan.eventIds.home]);apply_rope_editorial(focus,focus.laterEvents[focus.plan.eventIds.home])
	apply_middle_reading_context(focus)
	if fresh:apply_chapter_seven_scoped_reading(focus);apply_chapter_seven_reading_marks(focus);apply_chapter_six_maintenance_revision(focus)
	if fresh:
		var photo_event: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get("罗瑾")))
		if not photo_event.is_empty():attach_photo_local_38(focus,photo_event,true)
	return true

func _chapter7_parent_19_ensure_day_eleven_twelve_focus() -> Dictionary:
	if state.day<31:return _chapter6_parent_9_ensure_day_eleven_twelve_focus()
	if state.ended or int(state.day) not in range(10,38) or not present("罗瑾"):return {}
	if state.focus.get("day")==state.day and state.focus.get("plan")!=null:return state.focus
	var backup:=state.duplicate(true);var template=JSON.parse_string(FileAccess.get_file_as_string("res://data/native_base_state_template.json"))
	state.focus=template.focus.duplicate(true);var focus: Dictionary=state.focus;focus.day=state.day;focus.grandfatherRecoveryRevision="R4c";focus.characterRevision="R4a";focus.uncleRevision="R4b";focus.neighbourhoodRevision="R2b";focus.integrationReadingRevision="FINAL-INTEGRATION";focus.middleReadingRevision="I3e-4c1"
	focus.plan=make_pre_photo_plan()
	if focus.plan.is_empty():state=backup;return {}
	focus.knowledge={"player":[],"luo":[]};focus.resultPackets=[]
	if not bind_day_eleven_twelve(focus):state=backup;return {}
	focus.workPackets={}
	for row in focus.plan.rows.values():
		if not row.get("inactive",false) and (not row.base.is_empty() or (row.type=="photo" and row.outside and state.photo.employed)):
			var effects: Array=[]
			for resource in row.base:effects.append({"type":"shelter_delta","amount":row.base[resource]} if resource=="shelter" else {"type":"resource_delta","resource":str(resource),"amount":row.base[resource]})
			if row.type=="photo" and row.outside and state.photo.employed:effects.append({"type":"photo_progress","op":"skill_delta","value":0.5})
			focus.workPackets[row.name]=queue_focus_packet(effects,"work:"+row.name,"on_return",row.name).id
	var snapshots=JSON.parse_string(FileAccess.get_file_as_string("res://data/later_public_family_snapshots.json"))
	if snapshots.has(str(int(state.day))):focus.r4v3PublicFamilyText=snapshots[str(int(state.day))].duplicate(true)
	return focus


func _chapter7_parent_19_make_chapter_home_base(focus: Dictionary) -> Dictionary:
	if state.day<31:return _chapter6_parent_9_make_chapter_home_base(focus)
	if state.day>37 or "home" not in focus.plan.targets:return {}
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].outside)
	if home.is_empty():return {}
	if home.any(func(person):return not focus_fit(person)):return make_pre_photo_care_event(focus)
	var adults: Array=home.filter(func(person):return person!="罗瑾");var speaker: String=adults[0] if not adults.is_empty() else "罗瑾"
	var event: Dictionary={};var raw: Dictionary={}
	if focus.plan.primary=="home":
		if later_scene_shells.is_empty():later_scene_shells=JSON.parse_string(FileAccess.get_file_as_string("res://data/later_scene_shells.json"))
		var key: String=focus.plan.key
		if key in ["apprentice","oldphoto","materials","register","inquiry"]:key="papers"
		event=later_scene_shells.get(key,later_scene_shells.papers).duplicate(true)
	else:
		raw=make_pre_photo_condition_home(focus);event=raw.duplicate(true)
	if event.is_empty():return {}
	var suffix: String=event.id;var recipients: Array=["母亲","安仁叔叔","外祖父"].filter(func(person):return person in home and understands(person))
	event.id="later.D"+str(int(state.day)+1)+".home."+suffix;event.target="home";event.later=true;event.actor=speaker;event.participants=[speaker];event.homeParticipants=[speaker];event.recipient=null if recipients.is_empty() else recipients[0];event.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":state.photo.evidence,"photoPrints":state.photo.prints};event.historyClass="F：普通难民家庭、工作与听闻演绎，不是罗家逐日实录";event.chapter="I2b-7"
	if chapter_seven_home_prose.is_empty():chapter_seven_home_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_seven_home_prose.json"))
	var mask:=0
	for person in home:mask|=1<<PEOPLE.find(person)
	var key: String=JSON.stringify([int(state.day),mask,state.photo.employed,2 if state.shelter>=50 else (0 if state.shelter<=20 else 1),state.wood<=0,state.water<=0,state.rice<=2,state.get("knowledgeFacts",[]).any(func(fact):return fact.get("id")=="deadline.notice" and speaker in fact.get("knownBy",[]))])
	if not chapter_seven_home_prose.variants.has(key):return {}
	var variant: Dictionary=chapter_seven_home_prose.variants[key]
	if variant.has("fallback"):
		var fallback:=make_pre_photo_condition_home(focus);var id: String=event.id
		if fallback.is_empty():return {}
		for field in fallback:event[field]=fallback[field]
		event.id=id;event.target="home";event.later=true;event.chapter="I2b-7"
		for choice in event.choices:choice.later=true
	else:
		var layer: Dictionary=decode_home_content(chapter_seven_home_prose.events[variant.event],chapter_seven_home_prose)
		for field in layer:event[field]=layer[field]
		event.erase("conditionKind")
	return event


func _chapter7_parent_19_make_pre_photo_care_event(focus: Dictionary,base_only: bool=false) -> Dictionary:
	if state.day<31:return _chapter6_parent_9_make_pre_photo_care_event(focus,base_only)
	if state.day<10 or state.day>37 or "home" not in focus.plan.targets:return {}
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].get("outside",false));var sick: Array=home.filter(func(person):return not focus_fit(person))
	if sick.is_empty():return {}
	sick.sort_custom(func(a,b):return PEOPLE.find(a)<PEOPLE.find(b) if state.people[a].health==state.people[b].health else state.people[a].health<state.people[b].health)
	var patient: String=sick[0];var others: Array=home.filter(func(person):return person!="罗瑾" and understands(person));var speakers: Array=home.filter(func(person):return understands(person));var adult_home: Array=home.filter(func(person):return person!="罗瑾");var actor: String=adult_home[0] if not adult_home.is_empty() else "罗瑾"
	var event: Dictionary={};var suffix: String="fallback.d"+str(int(state.day)+1)+".home.care"
	if focus.plan.primary=="home":
		if later_scene_shells.is_empty():later_scene_shells=JSON.parse_string(FileAccess.get_file_as_string("res://data/later_scene_shells.json"))
		var key: String=focus.plan.key
		if key in ["apprentice","oldphoto","materials","register","inquiry"]:key="papers"
		if key=="burial":key="returner"
		if key=="shelter" and state.shelter>=50:key="papers"
		event=later_scene_shells.get(key,later_scene_shells.papers).duplicate(true);suffix=event.id
	var recipients: Array=["母亲","安仁叔叔","外祖父"].filter(func(person):return person in home and understands(person))
	event.id="later.D"+str(int(state.day)+1)+".home."+suffix;event.title="";event.intro="";event.later=true;event.historyClass="F：普通难民家庭、工作与听闻演绎，不是罗家逐日实录";event.target="home";event.actor=actor;event.participants=home.duplicate();event.homeParticipants=home.duplicate();event.recipient=null if recipients.is_empty() else recipients[0];event.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":state.photo.get("evidence",0),"photoPrints":state.photo.get("prints",0)};event.chapter="I2b-7";event.conditionKind="care"
	var repairers: Array=home.filter(func(person):return person!=patient and can_work_later(person))
	var raw_care:=pre_photo_raw_care_content(home,patient,repairers)
	if raw_care.is_empty():return {}
	for field in ["title","intro","choices"]:event[field]=raw_care[field]
	for choice in event.choices:choice.later=true
	if base_only:return event

	var offer:=pre_photo_recovery_offer(focus)
	if not offer.is_empty():
		event.id+=".exchange";event.actor=offer.actor;event.conditionKind="recovery"
		var medicine: bool=offer.item!=null;var name: String=TOOL_NAMES[offer.item] if medicine else "木料";var goods: String=name+"一份" if medicine else "能用的短木三份"
		var exchange: Dictionary={"id":"exchange","label":"用米粮"+str(int(offer.cost))+"份换"+goods,"hint":"米粮－"+str(int(offer.cost))+"；"+(name+"＋1，晚间另行用药，不当场治愈" if medicine else "木料＋3，不自动生火或修棚")+"。","requiresResources":{"rice":offer.cost},"immediateEffects":[{"type":"resource_delta","resource":"rice","amount":-offer.cost},{"type":"item_gain","item":offer.item} if medicine else {"type":"resource_delta","resource":"wood","amount":3}],"closures":{"default":""},"diaries":{"default":""}}
		event.choices=[exchange,event.choices[0],event.choices[1]]

	return event


func _chapter7_parent_19_make_pre_photo_condition_home(focus: Dictionary) -> Dictionary:
	if state.day<31:return _chapter6_parent_9_make_pre_photo_condition_home(focus)
	if state.day<10 or state.day>37:return {}
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].get("outside",false))
	if home.is_empty() or home.any(func(person):return not focus_fit(person)):return {}
	var mask:=0
	for person in home:mask|=1<<PEOPLE.find(person)
	var kind: String="weather" if current_weather().get("severe",false) else ("absence" if household_presence_mask()!=15 else ("maintenance" if state.shelter<41 and state.wood>0 else "home"))
	var prior: Array=[];var index:=0;var stock:=0;var gain:=0
	if kind in ["weather","maintenance"]:
		prior=state.history.filter(func(row):return row.get("day",state.day)<state.day and _object(row.get("readingVariant")).get("revision")=="R24-experience-polish-v1" and row.readingVariant.kind==kind)
		var last: Dictionary={}
		for row in prior:last[int(row.readingVariant.index)]=row.day
		var offset: int=RNG.hash_seed(state.seed+"|R24-experience-polish-v1|"+kind)%3;index=-1
		for step in range(3):
			var candidate: int=(offset+step)%3
			if not last.has(candidate):index=candidate;break
		if index<0:
			var candidates: Array=[0,1,2];candidates.sort_custom(func(a,b):return a<b if last[a]==last[b] else last[a]<last[b]);index=candidates[0]
		if kind=="weather":stock=(1 if state.wood>=1 else 0)+(2 if state.shelter>=50 else 0)+(4 if state.shelterItems.oilcloth else 0)
		else:
			var speakers: Array=home.filter(func(person):return person!="罗瑾");gain=formal_repair_gain(int(state.day),speakers[0] if not speakers.is_empty() else "罗瑾")
	else:
		prior=state.history.filter(func(row):return row.get("day",state.day)<state.day and _object(row.get("readingVariant")).get("group")=="shelter")
		index=(RNG.hash_seed(state.seed+":condition-story:shelter")+prior.size())%3
	if chapter_seven_condition_home_prose.is_empty():chapter_seven_condition_home_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_seven_condition_home.json"))
	var key:=JSON.stringify([int(state.day),mask,kind,index,stock,gain])
	if not chapter_seven_condition_home_prose.variants.has(key):return {}
	var event: Dictionary=decode_home_content(chapter_seven_condition_home_prose.events[chapter_seven_condition_home_prose.variants[key]],chapter_seven_condition_home_prose)
	event=_replace_content_token(event,"§WEATHER_NAME§",current_weather().name)
	if event.has("readingVariant"):event.readingVariant.previous=null if prior.is_empty() else prior.back().day
	return event


func _chapter7_parent_19_make_pre_photo_outdoor_event(focus: Dictionary,target: String) -> Dictionary:
	if state.day<31:return _chapter6_parent_9_make_pre_photo_outdoor_event(focus,target)
	if state.day<10 or state.day>37 or target not in PEOPLE or target not in focus.plan.targets or (js_truthy(focus.plan.get("nodeId")) and target==focus.plan.primary):return {}
	var row: Dictionary=_object(focus.plan.rows.get(target));var type: String=row.get("type","")
	if not row.get("outside",false) or row.get("inactive",false) or not present(target):return {}
	if not ((target=="罗瑾" and type in ["water","burial","photo"]) or (target=="外祖父" and type=="wood") or (target=="母亲" and type in ["relief","registration"]) or (target=="安仁叔叔" and type=="committee")):return {}
	var prior: Array=state.history.filter(func(history):return history.get("day",state.day)<state.day and _object(history.get("readingVariant")).get("group")=="water") if type=="water" else []
	var index: int=(RNG.hash_seed(state.seed+":condition-story:water")+prior.size())%3 if type=="water" else 0
	var previous: String="none" if prior.is_empty() else "many"
	if prior.size()==1:previous=prior[0].get("choice","") if prior[0].get("choice") in ["help","pole_help"] else "carry_home"
	var tool: String=state.memory.get("burialTool","none") if type=="burial" else "none"
	if tool not in ["shovel","rope"] or not tool_available(tool):tool="none"
	if chapter_seven_outdoor_prose.is_empty():chapter_seven_outdoor_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_seven_outdoor_prose.json"))
	var key:=JSON.stringify([int(state.day),target,type,index,state.water>=2 if type=="water" else false,tool_available("axe") if type=="wood" else false,tool,previous,type=="photo" and focus.plan.primary==target])
	if not chapter_seven_outdoor_prose.variants.has(key):return {}
	var event: Dictionary=decode_home_content(chapter_seven_outdoor_prose.events[chapter_seven_outdoor_prose.variants[key]],chapter_seven_outdoor_prose)
	var home: Array=PEOPLE.filter(func(person):return present(person) and not _object(focus.plan.rows.get(person)).get("outside",false))
	var recipients: Array=["母亲","安仁叔叔","外祖父"].filter(func(person):return person in home and understands(person))
	event.recipient=null if recipients.is_empty() else recipients[0]
	event.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":state.photo.get("evidence",0),"photoPrints":state.photo.get("prints",0)}
	if type=="water" and event.has("readingVariant"):
		event.readingVariant.previous=null if prior.is_empty() else prior.back().day
		event.readingVariant.narratorHere="罗瑾" in home
	return event


func _chapter7_parent_19_pre_photo_raw_care_content(home: Array,patient: String,repairers: Array) -> Dictionary:
	if state.day<31:return _chapter6_parent_9_pre_photo_raw_care_content(home,patient,repairers)
	var mask:=0
	for person in home:mask|=1<<PEOPLE.find(person)
	var worker: Variant=null;var gain:=0
	if state.shelter<41 and state.wood>0 and not repairers.is_empty():worker="外祖父" if "外祖父" in repairers else repairers[0];gain=formal_repair_gain(int(state.day),worker)
	if chapter_seven_care_raw_prose.is_empty():chapter_seven_care_raw_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_seven_care_raw_prose.json"))
	var key:=JSON.stringify([int(state.day),mask,patient,worker,state.water>0,gain])
	if not chapter_seven_care_raw_prose.variants.has(key):return {}
	var result: Dictionary=decode_home_content(chapter_seven_care_raw_prose.events[chapter_seven_care_raw_prose.variants[key]],chapter_seven_care_raw_prose)
	var description:=ailment_text(patient)
	return _replace_content_token(result,"§AILMENT_DESCRIPTION§",description if not description.is_empty() else "身上很不舒服")


func _chapter7_parent_19_pre_photo_recovery_offer(focus: Dictionary) -> Dictionary:
	if state.day<31:return _chapter6_parent_9_pre_photo_recovery_offer(focus)
	if state.balanceVersion!="I2f" or state.day<10 or state.day>37:return {}
	var block: int=int(floor(float(state.day-10)/5));var offset: int=RNG.hash_seed(state.seed+":recovery-offer:"+str(block))%5
	if (int(state.day)-10)%5!=offset:return {}
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].get("outside",false));var actors: Array=home.filter(func(person):return can_work_later(person))
	if actors.is_empty():actors=home.filter(func(person):return understands(person))
	if actors.is_empty():return {}
	var sick: Array=home.filter(func(person):return state.ailments.get(person,{}).values().any(func(value):return value>=2))
	sick.sort_custom(func(a,b):return PEOPLE.find(a)<PEOPLE.find(b) if state.people[a].health==state.people[b].health else state.people[a].health<state.people[b].health)
	var item: Variant=null
	for person in sick:
		var types: Array=["cold","wound","nutrition"]
		types.sort_custom(func(a,b):return ["cold","wound","nutrition"].find(a)<["cold","wound","nutrition"].find(b) if state.ailments[person][a]==state.ailments[person][b] else state.ailments[person][a]>state.ailments[person][b])
		var candidate: String={"cold":"herbs","wound":"bandage","nutrition":"medkit"}[types[0]]
		if not tool_available(candidate) and not tool_available("medkit"):item=candidate;break
	if item==null and not (state.wood<=2 and not can_work_later("外祖父")):return {}
	return {"actor":actors[0],"kind":"medicine" if item!=null else "wood","item":item,"cost":2 if item!=null else 1,"day":state.day+1}


var chapter_eight_care_reader=preload("res://scripts/chapter_eight_care_prose.gd").new()

var chapter_eight_care_raw_prose: Dictionary={}

var chapter_eight_condition_home_prose: Dictionary={}

var chapter_eight_outdoor_prose: Dictionary={}

var chapter_eight_home_prose: Dictionary={}

var chapter_eight_bound_nodes: Dictionary={}

var chapter_eight_photo_optional: Dictionary={}

var chapter_eight_photo_nodes: Dictionary={}

func make_bound_chapter_eight_node(focus: Dictionary) -> Dictionary:
	if focus.plan.nodeId=="warning":
		var event: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_eight_warning_scene.json"))
		var recipients: Array=["母亲","安仁叔叔","外祖父"].filter(func(n):return present(n) and not focus.plan.rows[n].outside and understands(n))
		event.recipient=null if recipients.is_empty() else recipients[0];event.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":state.photo.evidence,"photoPrints":state.photo.prints};return event
	if focus.plan.nodeId in ["discover","trial","firstPrint","deadline"]:return make_chapter_eight_photo_node(focus)
	if chapter_eight_bound_nodes.is_empty():chapter_eight_bound_nodes=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_eight_bound_nodes.json"))
	var home:=0;var adults:=0
	for i in range(PEOPLE.size()):
		if present(PEOPLE[i]) and not focus.plan.rows[PEOPLE[i]].outside:home|=1<<i
		if i>0 and understands(PEOPLE[i]):adults|=1<<(i-1)
	var key: String=JSON.stringify([focus.plan.nodeId,int(state.day),home,adults,js_truthy(state.memory.get("visitorNameRecorded")),js_truthy(state.memory.get("employment_offer_pending"))])
	if not chapter_eight_bound_nodes.variants.has(key):return {}
	var event: Dictionary=decode_home_content(chapter_eight_bound_nodes.events[chapter_eight_bound_nodes.variants[key]],chapter_eight_bound_nodes)
	event.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":state.photo.evidence,"photoPrints":state.photo.prints}
	apply_employment_bridge(event)
	return event

func bind_chapter_eight_photo_optional(focus: Dictionary) -> bool:
	for target in focus.plan.targets:
		var event: Dictionary=focus.laterEvents[focus.plan.eventIds[target]]
		if event.get("nodeId")=="firstPrint":focus.plan.photoOpportunity="print";continue
		if target!="罗瑾" or js_truthy(event.get("nodeId")):continue
		var kind: Variant=photo_opportunity(focus.plan)
		if kind==null or kind=="":continue
		if kind not in ["print","sort"] or int(state.day) not in range(38,44):fail_contract("C7_OPTIONAL_PHOTO_SCOPE","此照片机会正文未接入。");return false
		if chapter_eight_photo_optional.is_empty():chapter_eight_photo_optional=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_eight_photo_optional.json"))
		var strategy: String=state.photo.strategy if state.photo.strategy in ["print","organize","conceal"] else "steady"
		var key: String=JSON.stringify([int(state.day)+1,strategy,kind,mini(2,int(state.photo.prints)),state.photo.album.selected>0,state.get("knowledgeFacts",[]).any(func(k):return k.get("id")=="deadline.notice" and "罗瑾" in k.get("knownBy",[])),focus.plan.primary=="罗瑾"])
		if not chapter_eight_photo_optional.variants.has(key):return false
		var next: Dictionary=decode_home_content(chapter_eight_photo_optional.events[chapter_eight_photo_optional.variants[key]],chapter_eight_photo_optional)
		next.receivedContext=event.receivedContext.duplicate(true);next.recipient=event.get("recipient")
		focus.laterEvents[focus.plan.eventIds[target]]=next;focus.plan.photoOpportunity=kind
	return true

func make_chapter_eight_photo_node(focus: Dictionary) -> Dictionary:
	var node: Variant=focus.plan.get("nodeId")
	if node not in ["discover","trial","firstPrint","deadline"]:return {}
	if chapter_eight_photo_nodes.is_empty():chapter_eight_photo_nodes=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_eight_photo_nodes.json"))
	var p: Dictionary=state.photo;var strategy: String=p.strategy if node=="firstPrint" and p.strategy in ["print","organize","conceal"] else "steady"
	var key: String=JSON.stringify([int(state.day)+1,node,p.employed,js_truthy(p.evidence),p.prints>0,strategy])
	if not chapter_eight_photo_nodes.variants.has(key):fail_contract("PHOTO_NODE_PROSE","当前照片节点正文组合尚未接入。");return {}
	var event: Dictionary=decode_home_content(chapter_eight_photo_nodes.events[chapter_eight_photo_nodes.variants[key]],chapter_eight_photo_nodes)
	var recipients: Array=["母亲","安仁叔叔","外祖父"].filter(func(n):return present(n) and not _object(focus.plan.rows.get(n)).get("outside",false) and understands(n))
	if node=="discover" and ["lusuR17Seen","lusu","lusuSourceBoundary"].any(func(k):return js_truthy(state.memory.get(k))):
		for choice in event.choices:
			if not choice.immediateEffects.any(func(e):return e.get("flag")=="lusuPhotoEcho"):choice.immediateEffects.append({"type":"flag_set","flag":"lusuPhotoEcho","value":true})
	event.recipient=null if recipients.is_empty() else recipients[0]
	event.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":p.evidence,"photoPrints":p.prints}
	return event

func repair_c8_d44_care_hint(focus: Dictionary) -> void:
	if focus.day!=43 or not focus.plan.get("chapter8",false) or focus.day!=state.day:return
	var event: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get("home")))
	if event.get("id")!="later.D44.home.papers" or event.get("target")!="home" or event.get("conditionKind")!="care" or event.get("recipient")!="母亲" or _object(event.get("readingVariant")).get("revision")!="WebR2-home-care-prose-v1":return
	for choice in event.get("choices",[]):
		if choice.get("id")=="care_or_repair" and choice.get("hint")=="放弃这次白天照料收益；木料－1，草棚恢复8点。" and choice.get("requiresShelterBelow")==41 and _object(choice.get("requiresResources")).get("wood")==1 and chapter_json_equal(choice.get("immediateEffects"),[{"type":"resource_delta","resource":"wood","amount":-1},{"type":"shelter_delta","amount":8}]):choice.hint="放弃这次白天照料收益；木料－1，草棚会更牢靠。"

var chapter_eight_diary_prose: Dictionary={}

func finish_chapter_eight_diary(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	var date: int=int(focus.day)+1
	if date<39 or date>44 or not focus.plan.get("chapter8",false):return true
	if not focus.get("diaryAllowed",false):focus.chapterDiary=[];return true
	if chapter_eight_diary_prose.is_empty():chapter_eight_diary_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_eight_diary_prose.json"))
	var bank: Dictionary=chapter_eight_diary_prose;var here: Array=PEOPLE.filter(func(n):return present(n));var adults: Array=here.filter(func(n):return n!="罗瑾");var home_able: Array=adults.filter(func(n):return can_work_later(n) and not _object(focus.plan.rows.get(n)).get("outside",false))
	var mode: String=home_able[0] if not home_able.is_empty() else ("resting" if not adults.is_empty() else "alone");var family: String=bank.openings[JSON.stringify([date,mode])];var opening: String=family
	var special: bool=["motherCrisis","uncleCrisis","motherCare","uncleBoundary","expeditionSearch","pigeonPickup","neighbourhood","neighbourParcel"].any(func(k):return js_truthy(event.get(k)))
	var web: bool=focus.get("webM4ReadingRevision")=="WebM4-D39D44-v1" and not special
	if web and can_work_later("罗瑾"):
		var fit: Array=adults.filter(func(n):return understands(n) and can_work_later(n));var at_home: Array=fit.filter(func(n):return not _object(focus.plan.rows.get(n)).get("outside",false));var actor: String=at_home[0] if not at_home.is_empty() else (fit[0] if not fit.is_empty() else "")
		if actor!="":opening=bank.webOpenings[JSON.stringify([date,actor])]
	var known: bool=state.get("knowledgeFacts",[]).any(func(k):return k.get("id")=="deadline.notice" and "罗瑾" in k.get("knownBy",[]));var evidence: bool=js_truthy(state.photo.evidence);var work: Array=[]
	for row in focus.plan.rows.values():
		if not row.outside or row.get("inactive",false) or not present(row.name) or focus.get("selected")==row.name or focus.get("cancelWork")==row.name:continue
		var packets: Array=focus.get("resultPackets",[]).filter(func(p):return p.id==focus.get("workPackets",{}).get(row.name))
		if packets.is_empty() or packets[0].status!="applied" or row.type not in ["photo","water","relief","wood","committee"]:continue
		if row.type=="committee" and js_truthy(focus.get("defaultNodeDiary")):continue
		work.append(bank.work[JSON.stringify([date,web,row.type,evidence,not adults.is_empty()])])
	if js_truthy(focus.get("defaultNodeDiary")):work.append(bank.defaultWork[str(date)] if focus.plan.get("nodeId")=="warning" else focus.defaultNodeDiary)
	var active: Dictionary=_object(state.expedition.get("active"));var missing: String=""
	if not active.is_empty() and state.people.has(active.get("name")) and js_truthy(state.people[active.name].get("away")):missing=bank.absence[JSON.stringify([active.name,js_truthy(active.get("announced"))])]
	var body: String=_object(choice.get("diaries")).get("default","");var actual: Dictionary=_object(state.focus.get("photoBatchReceipt"))
	if not actual.is_empty():body=bank.results[JSON.stringify([date,"sort" if actual.get("kind")=="sort" else "print",js_truthy(actual.get("amount")),state.photo.album.selected>=minf(16,state.photo.prints)])]
	if web and not actual.is_empty() and js_truthy(choice.get("photoBatch")) and actual.get("event")==event.get("id"):body=choice.diaries.default
	var ending: String=bank.endings[JSON.stringify([date,web,known,route_use_by_luo(),present("安仁叔叔"),not adults.is_empty(),event.get("target")=="home"])]
	focus.chapterDiary=([opening,body]+work+[missing,bank.news[str(date)],ending]).filter(func(t):return js_truthy(t));focus.ordinaryDiaryLead=[family]
	focus.chapterDiaryContext={"chapter":"I2b-8","day":date,"present":here,"heardAtDusk":true,"hearingClass":"F：独立傍晚听闻；不是阅读城市层即获得人物知识","node":event.get("nodeId") if js_truthy(event.get("nodeId")) else null}
	if _object(event.get("readingVariant")).get("revision")=="WebR2-home-care-prose-v1" and focus.chapterDiary.find(_object(choice.get("diaries")).get("default",""))>0 and not focus.get("grandfatherRecoveryAdded",false) and not js_truthy(event.get("nodeId")):focus.chapterDiary[0]=""
	if event.has("messageThread") and not focus.chapterDiary.is_empty():focus.messageGenericReflection=focus.chapterDiary[-1]
	if event.has("custodyHandoff") and not focus.chapterDiary.is_empty():focus.custodyGenericReflection=focus.chapterDiary[-1]
	apply_c8_d43_diary_boundary(focus,event)
	apply_chapter_six_returned_work_prose(focus)
	return true

func apply_c8_d43_diary_boundary(focus: Dictionary,event: Dictionary) -> void:
	var marker: Dictionary=_object(focus.get("r4v7D43DiaryText"))
	if focus.day!=42 or state.day!=focus.day or focus.get("webM4ReadingRevision")!="WebM4-D39D44-v1" or not focus.get("diaryAllowed",false) or _object(focus.get("chapterDiaryContext")).get("chapter")!="I2b-8" or focus.get("chapterDiary",[]).is_empty() or not route_tracked() or focus.get("r3RouteWarningRevision")!=ROUTE_REV or route_use_by_luo():return
	if ["motherCrisis","uncleCrisis","motherCare","uncleBoundary","expeditionSearch","pigeonPickup","neighbourhood","neighbourParcel"].any(func(k):return js_truthy(event.get(k))):return
	var canonical: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_eight_d43_diary_contract.json"))
	if not chapter_json_equal(marker,canonical):return
	for i in range(2,focus.chapterDiary.size()):
		if focus.chapterDiary[i] in [marker.sourceWork,marker.sourceWebM4Work]:focus.chapterDiary[i]=marker.unknownWork
	if not understands("安仁叔叔"):
		var kept: Array=[]
		for i in range(focus.chapterDiary.size()):
			if i<=1 or focus.chapterDiary[i]!=marker.sourceUncleWork:kept.append(focus.chapterDiary[i])
		focus.chapterDiary=kept
	var tail: String=focus.chapterDiary[-1]
	if js_truthy(event.get("messageThread")) and tail in [marker.unknownEnding,marker.absentEnding] and focus.get("messageGenericReflection")==tail:focus.chapterDiary[-1]=marker.messageAbsentBoundary if tail==marker.absentEnding else marker.messageUnknownBoundary;focus.messageGenericReflection=null

var chapter_eight_photo_results: Dictionary={}

func prepare_chapter_eight_photo_choice(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	if not js_truthy(choice.get("photoBatch")):return true
	if state.day<38 or state.day>43 or focus.day!=state.day or focus.get("webM4ReadingRevision")!="WebM4-D39D44-v1" or event.get("photoMid")!=true or event.get("actor")!="罗瑾" or event.get("target")!="罗瑾" or choice.photoBatch.get("contract")!=PHOTO_MID_CONTRACT or choice.photoBatch.get("kind") not in ["print","sort"] or choice.id not in ["small","more"] or choice.id!=choice.photoBatch.get("size"):fail_contract("C8_PHOTO_RESULT_SCOPE","该照片结果正文合同尚未原生接通。");return false
	var p: Dictionary=state.photo;var prints: float=p.prints;var selected: float=p.album.selected;var transferred: float=p.transferCount;var modern: bool=state.photoBalanceVersion=="I3";var strategy: String=p.strategy if p.strategy in ["print","organize","conceal"] else "steady";var kind: String=choice.photoBatch.kind
	if not prepare_photo_mid_numbers(focus,event,choice):return false
	var receipt: Dictionary=focus.photoBatchReceipt
	if chapter_eight_photo_results.is_empty():chapter_eight_photo_results=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_eight_photo_results.json"))
	var key: String=JSON.stringify([int(state.day)+1,event.id,strategy,kind,choice.id,mini(2,int(prints)),selected>0,prints-selected==1,transferred>0,transferred>=prints,modern,mini(2,int(receipt.amount)),receipt.roll>=receipt.chance,int(receipt.attention)])
	if not chapter_eight_photo_results.variants.has(key):fail_contract("C8_PHOTO_RESULT_KEY","当前照片结果正文组合尚未接入。");return false
	var pair: Array=chapter_eight_photo_results.variants[key];choice.closures={"default":chapter_eight_photo_results.strings[int(pair[0])]};choice.diaries={"default":chapter_eight_photo_results.strings[int(pair[1])]};return true

func _chapter7_parent_22_ordinary_pre_photo_effect_supported(effect: Dictionary) -> bool:
	if effect.get("type")=="flag_set":
		if effect.get("flag") in ["uncleBoundaryChosen","uncleBoundaryReturned"]:return valid_uncle_boundary_record(effect.get("value"))
		if effect.get("flag")=="uncleBoundaryFollowupDone":return effect.get("value") is String and effect.value=="closed" or _whole_number(effect.get("value")) and effect.value>=40 and effect.value<=45
	return _chapter7_parent_1_ordinary_pre_photo_effect_supported(effect)


func _chapter7_parent_22_story_photo(op: String,value: Variant,effect: Dictionary={}) -> bool:
	var p: Dictionary=state.photo
	if not js_truthy(p.get("evidenceStage")):p.evidenceStage="unavailable"
	match op:
		"unlock":p.unlocked=true;p.evidenceStage="introduced"
		"employ":p.unlocked=true;p.employed=true;p.evidenceStage="employed"
		"skill_delta":p.skill=clampf(p.skill+value,0,6)
		"attention_delta":p.attention=clampf(p.attention+value,0,6)
		"stage_advance":
			photo_stage_advance(str(value))
			if value is String and value=="discovered":p.evidence=maxf(1,p.evidence)
		"prints_delta","selected_delta":
			if js_truthy(effect.get("contract")):return apply_photo_mid_delta(op,value,effect)
			if op=="selected_delta":fail_contract("PHOTO_OP","未批准照片操作");return false
			if value!=1 or state.day+1!=state.fixedNodeStates.trial.due or not js_truthy(p.evidence):fail_contract("PHOTO_TRIAL","未批准的照片批次");return false
			p.prints+=1;photo_stage_advance("printing")
		"work_tendency_set":p.strategy=value
		"deadline_transition":
			p.deadlineState=value;p.deadline.announced=value in ["announced","urgent","final_day","resolved"];p.deadline.urgent=value in ["urgent","final_day","resolved"];p.deadline.final=value in ["final_day","resolved"]
		_:
			fail_contract("PHOTO_OP","未批准照片操作");return false
	return true

func resolve_chapter_eight_prepared_choice(index: int) -> bool:
	if state.ended or state.day<38 or state.day>43 or state.phase!="focusEvent" or state.focus.get("choiceIndex")!=null:return false
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if event.is_empty() or index<0 or index>=event.get("choices",[]).size():return false
	if event.get("nodeId") not in ["discover","trial","firstPrint","deadline","warning"] and not event.get("photoMid",false) and not event.get("photoEnd",false) and not event.has("uncleCrisis"):return false
	var choice: Dictionary=event.choices[index]
	for key in ["motherCrisis","motherCare","uncleBoundary","nextMorningEffects"]:
		if js_truthy(choice.get(key)):return false
	if js_truthy(choice.get("photoBatch")):
		var photo_req:=photo_batch_requirement(choice.photoBatch.kind)
		if not photo_req.met:state.error=photo_req.reason;return false
	if js_truthy(choice.get("photoTransfer")):
		var req:=photo_transfer_requirement()
		if not req.met:state.error=req.reason;return false
	if event.has("uncleCrisis"):
		var req:=uncle_crisis_requirement(choice)
		if not req.met:state.error=req.reason;return false
	var requirement:=ordinary_pre_photo_requirement(choice)
	if not requirement.met:state.error=requirement.reason;return false
	if not later_event_eligible(event,focus.plan):state.error="当事人已不能参与这段现场。";return false
	var backup:=state.duplicate(true);var before:=focus_snapshot();contract_error="";contract_message=""
	if not prepare_chapter_eight_photo_choice(focus,event,choice):return rollback_photo_choice(backup)
	if not prepare_c8_early_transfer(focus,event,choice):return rollback_photo_choice(backup)
	if not prepare_uncle_crisis_choice(focus,event,choice):return rollback_photo_choice(backup)
	var immediate: Array=choice.get("immediateEffects",[]).duplicate(true)
	if js_truthy(choice.get("flag")):immediate.append({"type":"flag_set","flag":choice.flag,"value":true})
	if immediate.any(func(effect):return not ordinary_pre_photo_effect_supported(effect)) or choice.get("returnEffects",[]).any(func(effect):return not ordinary_pre_photo_effect_supported(effect)):
		fail_contract("C7_EFFECT_SCOPE","当前结果类型尚未原生接通。");return rollback_photo_choice(backup)
	var result_packet:=queue_focus_packet(immediate,event.id+":"+choice.id+":immediate","immediate",event.actor)
	if not attach_deadline_scene_knowledge(result_packet,event):return rollback_photo_choice(backup)
	attach_route_warning_witness(result_packet,event)
	apply_ordinary_pre_photo_packet(result_packet)
	if contract_error!="":return rollback_photo_choice(backup)
	var packet:=queue_focus_packet(choice.get("returnEffects",[]),event.id+":"+choice.id+":return","on_return",event.actor)
	mark_route_warning_return(packet,event)
	focus.carriedAssets=[]
	for effect in packet.effects:
		if effect.type=="resource_delta" and effect.amount>0:focus.carriedAssets.append({"owner":event.actor,"resource":effect.resource,"amount":effect.amount,"resultPacketId":packet.id})
	focus.cancelWork=focus.selected if choice.get("workImpact")=="complete" else null;focus.partialWork=focus.selected if choice.get("workImpact")=="partial" else null
	focus.choiceIndex=index;focus.outcomeKey="default";focus.immediateText=choice.closures.default;focus.immediateChange=describe_focus_change(before)
	focus.knowledge.player=[focus.immediateText];focus.knowledge.luo=[focus.immediateText] if focus.selected=="罗瑾" or (focus.selected=="home" and not focus.plan.rows["罗瑾"].outside) else []
	var history: Dictionary={"day":state.day,"type":"later-choice","event":event.id,"choice":choice.id}
	if event.get("conditionKind")==_object(event.get("readingVariant")).get("kind"):
		if event.has("readingVariant"):history.readingVariant=event.readingVariant
	else:history.readingVariant=null
	state.phase="focusResult";state.error=null;state.history.append(history);return true

func _chapter7_parent_24_finish_chapter_six_diary(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	if state.day<31:return _chapter6_parent_11_finish_chapter_six_diary(focus,event,choice)
	return finish_chapter_seven_diary(focus,event,choice)


func _chapter7_parent_24_resolve_day_eleven_twelve_choice(index: int) -> bool:
	if state.day<31:return _chapter6_parent_11_resolve_day_eleven_twelve_choice(index)
	if state.day>37:return false
	var event:=current_later_focus_event()
	if event.get("photoMid",false) or event.get("nodeId") in ["discover","trial","firstPrint","deadline"]:return resolve_chapter_seven_photo_choice(index)
	if event.has("motherCrisis"):return resolve_mother_crisis_choice(index)
	if event.get("motherCare",false):return resolve_mother_care_choice(index)
	if event.has("neighbourParcel"):return resolve_parcel_choice(index)
	if event.has("custodyNight") or event.has("custodyHandoff"):return resolve_custody_choice(index)
	if event.has("neighbourhood"):return resolve_rope_choice(index)
	if event.has("messageThread"):return resolve_message_thread_choice(index)
	return commit_rope_choice_core(index)


func _chapter7_parent_24_settle_chapter_five_default_node(focus: Dictionary,event: Dictionary,lines: Array) -> bool:
	if state.day<31:return _chapter6_parent_11_settle_chapter_five_default_node(focus,event,lines)
	var id: Variant=focus.plan.get("nodeId")
	if id==null:return true
	var node: Dictionary=state.fixedNodeStates[id]
	if chapter_five_node_done(node) or event.get("nodeId")==id:return true
	if id=="trial":node.status="skipped";node.fallback="当日未试印";return true
	if id=="discover":return true
	if id not in ["names","sources","employ","firstPrint","deadline"]:return false
	if id!="employ" and node.eligibleDays.size()<2:return true
	var planned: Dictionary=focus.laterEvents[focus.plan.eventIds[focus.plan.primary]];var options: Array=planned.choices.filter(func(c):return c.id=="safe") if id=="firstPrint" else [planned.choices[0]]
	if options.is_empty():return false
	var choice: Dictionary=options[0]
	if not ordinary_pre_photo_requirement(choice).met or not later_event_eligible(planned,focus.plan):return true
	var effects: Array=choice.get("immediateEffects",[]).duplicate(true)+choice.get("returnEffects",[]).duplicate(true)
	if not apply_ordinary_pre_photo_packet(queue_focus_packet(effects,"node:"+id+":default","on_return",planned.actor)):return false
	node.fallback="岗位保留默认" if id=="employ" else "第二个合适日稳妥默认"
	lines.append({"employ":"工作规矩已传到家里，罗瑾先保留这份帮工岗位。","names":"罗瑾只记下了姓名和消息来处。","sources":"罗瑾把公开说法与能核实的记录分开放好。","firstPrint":"罗瑾今天没有加印；这一回先维持普通工作。","deadline":"罗瑾先认下往后争取留存的方向；今天没有因此新增照片。"}[id]);focus.defaultNodeDiary=choice.diaries.default
	return true


func _chapter7_parent_24_settle_day_eleven_twelve_return() -> bool:
	if state.day<31:return _chapter6_parent_11_settle_day_eleven_twelve_return()
	if state.day>37:return false
	var focus_discovery_observed: bool=state.focus.plan.get("nodeId")=="discover" and state.focus.get("selected")=="罗瑾" and state.focus.get("choiceIndex")!=null and state.photo.evidence>0
	var event:=current_later_focus_event();var was_settled: bool=state.focus.get("settled",false);var result: bool=false
	if event.has("messageThread"):result=settle_message_thread_return()
	elif event.has("neighbourhood"):
		result=settle_ordinary_pre_photo_return()
		if result:result=finish_rope_diary(state.focus,event,event.choices[int(state.focus.choiceIndex)])
	elif event.has("neighbourParcel"):
		result=settle_ordinary_pre_photo_return()
		if result:result=finish_parcel_diary(state.focus,event,event.choices[int(state.focus.choiceIndex)])
	elif event.has("custodyHandoff") or event.has("custodyNight"):result=settle_chapter_seven_custody_return()
	else:result=settle_ordinary_pre_photo_return()
	if result and not was_settled and state.focus.get("custodyNightRevision")==CUSTODY_NIGHT_REV and js_truthy(state.memory.get(CUSTODY_NIGHT_KEY)):
		if not custody_night_record_valid(state.memory[CUSTODY_NIGHT_KEY]):state.focus.custodyNightCompatibility="这笔跨夜托存记录不完整，交接已隔离；旧物权未猜改。"
		else:settle_custody_owner_arrival(event)
	if result and focus_discovery_observed:
		if not js_truthy(state.memory.get("photoDiscoveryWorldDay")):state.memory.photoDiscoveryWorldDay=state.day+1
		state.memory.photoDiscoveryObserved=true;state.memory.photoDiscoveryObservedDay=state.day+1
	return result


func _chapter7_parent_24_settle_ordinary_pre_photo_return() -> bool:
	if state.day<31:return _chapter6_parent_11_settle_ordinary_pre_photo_return()
	# D11-D17 selected custody only. Later photos, crises, excursions and owner arrivals
	# on unrelated scenes remain gated until their complete contracts are implemented.
	if state.ended or state.day<31 or state.day>37:return false
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if event.is_empty():return false
	if focus.get("settled",false):state.phase="focusReturn";return true
	if state.phase!="focusResult" or focus.get("choiceIndex")==null or int(focus.choiceIndex)<0 or int(focus.choiceIndex)>=event.choices.size():return false
	if focus.plan.get("key") in ["expeditionSearch","pigeonPickup"]:return false
	if focus.plan.rows.values().any(func(row):return row.get("type") not in ["home","relief","wood","water","burial","registration","rest","committee","photo"]):return false
	for key in ["uncleBoundaryReturned","uncleCrisisR4b","grandfatherHomeR18"]:
		if state.memory.get(key)!=null:return false
	if focus.resultPackets.any(func(packet):return packet.effects.any(func(effect):return not ordinary_pre_photo_effect_supported(effect) and effect.get("type")!="mother_crisis_consequence")):return false
	var choice: Dictionary=event.choices[int(focus.choiceIndex)]
	var backup:=state.duplicate(true);var before:=focus_snapshot();var lines: Array=[]
	for row in focus.plan.rows.values():
		var packets: Array=focus.resultPackets.filter(func(packet):return packet.id==focus.workPackets.get(row.name));var packet: Dictionary={} if packets.is_empty() else packets[0]
		if not present(row.name) or row.get("inactive",false) or focus.get("cancelWork")==row.name:
			if not packet.is_empty():packet.status="cancelled";packet.cancelReason="未能完成或当事人未返家"
			if focus.get("cancelWork")==row.name and present(row.name) and row.outside:lines.append(row.name+"回到了棚边，原定的差事没有做完。")
			continue
		if not packet.is_empty():
			if focus.get("partialWork")==row.name:
				for effect in packet.effects:
					if effect.get("type")=="photo_progress" and effect.get("op")=="skill_delta":effect.value/=2
					elif typeof(effect.get("amount")) in [TYPE_INT,TYPE_FLOAT]:effect.amount=maxf(1,effect.amount-1)
			apply_ordinary_pre_photo_packet(packet)
		if row.outside and row.type!="photo":lines.append(later_return_line(row.name,"partial" if focus.get("partialWork")==row.name else "complete"))
		if row.type=="burial":
			apply_ordinary_pre_photo_packet(queue_focus_packet([{"type":"flag_set","flag":"burialExperienced","value":true}],"work:burial:experience","on_return","罗瑾"))
			if focus.selected!="罗瑾":focus.backgroundDiary="今天我跟队回来，没有在路上独自停留。我没有亲眼看见杀戮，却面对了它留下的后果。回到棚里以后，我想先看看家人还在不在眼前，并不想把一路所见立刻从头说完。"
		if row.type=="registration":
			var inquiry: bool=row.get("registrationProtocol")=="inquiry-I3e-4b"
			apply_ordinary_pre_photo_packet(queue_focus_packet([{"type":"flag_set","flag":"registrationInquiry" if inquiry else "registered","value":"mother"}],"work:registration:inquiry" if inquiry else "work:registration:paper","on_return","母亲"))
		if row.type=="photo" and row.outside:lines.append("罗瑾只做完一部分杂活便离店回到棚边；没做完的那一段不能算上。" if focus.get("partialWork")==row.name else "罗瑾做完今天分到的杂活，离店回到棚边；主要冲洗仍由蒋孝义负责。")
	for packet in focus.resultPackets:
		if packet.timing=="on_return" and packet.status=="pending":apply_ordinary_pre_photo_packet(packet)
	if contract_error!="":state=backup;state.error="返家尚未结算完成："+contract_message;return false
	if not settle_chapter_five_default_node(focus,event,lines):state=backup;return false
	var known: bool=mother_preparation_return_allowed(focus,event) and understands("罗瑾") and later_event_eligible(event,focus.plan) and (not event.get("motherCare",false) or mother_care_has_returned(focus))
	if known:state.knowledgeFacts.append({"id":event.id+":return-knowledge","day":state.day+1,"source":event.actor,"knownBy":["罗瑾"],"scope":"选择结果的可转述部分","text":choice.diaries.default})
	focus.diaryAllowed=known;focus.knowledge.luo=[choice.diaries.default] if known else []
	if known and focus.selected!="罗瑾" and (focus.selected!="home" or focus.plan.rows["罗瑾"].outside) and not lines.any(func(line):return line.begins_with(event.actor)):lines.append(event.actor+"在家里说起今天遇到的事。")
	focus.returnText=" ".join(lines);focus.returnChange=describe_focus_change(before);focus.settled=true;focus.carriedAssets=[];state.phase="focusReturn"
	if not finish_chapter_six_diary(focus,event,choice):state=backup;return false
	if event.get("motherCare",false) and focus.diaryAllowed and focus.get("chapterDiary") is Array:focus.chapterDiary=focus.chapterDiary.slice(1)
	if event.has("motherCrisis") and not finish_mother_crisis_diary(focus,event,choice):state=backup;return false
	state.history.append({"day":state.day,"type":"later-return","event":event.id,"change":focus.returnChange})
	return true

func settle_chapter_eight_custody_return() -> bool:
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if state.ended or state.day<38 or state.day>43 or event.is_empty() or not (event.has("custodyHandoff") or event.has("custodyNight")):return false
	if focus.get("settled",false):return settle_ordinary_pre_photo_return()
	if state.phase!="focusResult" or focus.get("choiceIndex")==null or int(focus.choiceIndex)<0 or int(focus.choiceIndex)>=event.choices.size():return false
	var night: bool=event.has("custodyNight");var record: Dictionary=_object(state.memory.get(CUSTODY_NIGHT_KEY if night else "neighbourCustodyWebR6"))
	if not (custody_night_record_valid(record) if night else custody_handoff_record_valid(record)):return false
	if night and focus.get("custodyNightRevision")!=CUSTODY_NIGHT_REV:return false
	var choice: Dictionary=event.choices[int(focus.choiceIndex)];var visits: Array=record.get("visits",[]).filter(func(row):return row.get("event")==event.id and row.get("choice")==choice.id)
	if visits.size()!=1 or not focus.get("custodyNightReceipt" if night else "custodyReceipt") is Dictionary:return false
	var backup: Dictionary=state.duplicate(true);var meta: Dictionary=event.custodyNight if night else event.custodyHandoff
	if not meta.here and not understands(event.actor):choice.diaries.default="我回来时，今天接话的家人还不能把经过讲清。没有听见这回怎样答应、怎样交物，就不从棚边的一只包猜出事情已经做到哪里。" if night else "我回来以后，今天在棚边接话的家人还不能把事情说明。我没有因为眼前少了或多了一处空地，就猜谁来过、什么东西交给了谁。先顾现在能顾的，没听到的那一段不往日记里补。"
	if not settle_ordinary_pre_photo_return():state=backup;return false
	var visit: Dictionary=visits[0];visit.returned=true
	if night:
		var context:=custody_after_context(focus);var speaker: bool=event.actor in context.home and understands(event.actor) and neighbour_knows(event.actor,visit.factId,"custody-summary")
		if "罗瑾" in context.home and understands("罗瑾") and (meta.here or speaker):
			visit.returnListeners=deliver_fact({"factId":visit.factId,"recipients":["罗瑾"],"scope":"custody-summary","source":event.id+":return:"+event.actor,"mode":"witnessed" if meta.here else "told"})
			if record.status!="declined":deliver_fact({"factId":record.id,"recipients":["罗瑾"],"scope":"custody-summary","source":event.id+":return-summary:"+event.actor,"mode":"witnessed" if meta.here else "told"})
		if focus.diaryAllowed and not focus.get("chapterDiary",[]).any(func(text):return text.contains(choice.diaries.default)):
			if not focus.get("chapterDiary") is Array:focus.chapterDiary=[]
			focus.chapterDiary.append(choice.diaries.default)
		focus.custodyNightReceipt.returned=true
	else:
		if understands("罗瑾") and (meta.here or understands(event.actor)):visit.returnListeners=deliver_fact({"factId":visit.factId,"recipients":["罗瑾"],"source":event.id+(":witness-kept" if meta.here else ":return-telling:"+event.actor),"scope":"custody-public","mode":"witnessed" if meta.here else "told"})
		focus.custodyReceipt.returned=true
		if focus.diaryAllowed and not focus.get("chapterDiary",[]).is_empty():
			var text: String=choice.diaries.default;var parts: Array=Array(text.split("\n\n"));var tail: String=parts.pop_back();var body: String="\n\n".join(parts);var hit: bool=false
			for i in range(focus.chapterDiary.size()):
				if focus.chapterDiary[i].contains(text):hit=true;focus.chapterDiary[i]=focus.chapterDiary[i].replace(text,body)
			if not hit:focus.chapterDiary.append(tail if body.is_empty() else body)
			if js_truthy(focus.get("custodyGenericReflection")):focus.chapterDiary.erase(focus.custodyGenericReflection)
			if not body.is_empty():focus.chapterDiary.append(tail)
	return true

func apply_c8_special_work(focus: Dictionary,event: Dictionary,row: Dictionary,packet: Dictionary,lines: Array) -> bool:return apply_p1_work(focus,event,row,packet,lines)

func complete_c8_return_knowledge(focus: Dictionary,event: Dictionary) -> bool:return complete_p1_return(focus,event)

func c8_return_knowledge_allowed(focus: Dictionary,event: Dictionary) -> bool:return p1_return_knowledge_allowed(focus,event)

func _chapter7_parent_25_early_household_supported() -> bool:
	if not present("罗瑾") or PEOPLE.any(func(person):return state.people[person].away and not supported_expedition_absence(person)):return false
	var count: int=PEOPLE.filter(func(person):return present(person)).size()
	return count==4 if state.day<4 else count>=1

func _chapter7_parent_26_ensure_day_eleven_twelve_focus() -> Dictionary:
	if state.day<38:return _chapter7_parent_19_ensure_day_eleven_twelve_focus()
	if state.ended or int(state.day) not in range(10,44) or not present("罗瑾"):return {}
	if state.focus.get("day")==state.day and state.focus.get("plan")!=null:return state.focus
	var backup:=state.duplicate(true);var template=JSON.parse_string(FileAccess.get_file_as_string("res://data/native_base_state_template.json"))
	state.focus=template.focus.duplicate(true);var focus: Dictionary=state.focus;focus.day=state.day;focus.grandfatherRecoveryRevision="R4c";focus.characterRevision="R4a";focus.uncleRevision="R4b";focus.neighbourhoodRevision="R2b";focus.integrationReadingRevision="FINAL-INTEGRATION";focus.middleReadingRevision="I3e-4c1"
	focus.plan=make_pre_photo_plan()
	if focus.plan.is_empty():state=backup;return {}
	focus.knowledge={"player":[],"luo":[]};focus.resultPackets=[]
	if not bind_day_eleven_twelve(focus):state=backup;return {}
	focus.workPackets={}
	for row in focus.plan.rows.values():
		if not row.get("inactive",false) and (not row.base.is_empty() or (row.type=="photo" and row.outside and state.photo.employed)):
			var effects: Array=[]
			for resource in row.base:effects.append({"type":"shelter_delta","amount":row.base[resource]} if resource=="shelter" else {"type":"resource_delta","resource":str(resource),"amount":row.base[resource]})
			if row.type=="photo" and row.outside and state.photo.employed:effects.append({"type":"photo_progress","op":"skill_delta","value":0.5})
			focus.workPackets[row.name]=queue_focus_packet(effects,"work:"+row.name,"on_return",row.name).id
	var snapshots=JSON.parse_string(FileAccess.get_file_as_string("res://data/later_public_family_snapshots.json"))
	if snapshots.has(str(int(state.day))):focus.r4v3PublicFamilyText=snapshots[str(int(state.day))].duplicate(true)
	return focus


func _chapter7_parent_26_ordinary_pre_photo_effect_supported(effect: Dictionary) -> bool:
	match effect.get("type"):
		"uncle_crisis_commit":return effect.get("record") is Dictionary and effect.record.get("revision")==UNCLE_CRISIS_REV
		"knowledge_grant":
			if effect.get("fact") is Dictionary and route_marked(effect.fact):return true
		"node_resolve":
			if effect.get("node")=="warning":return not effect.has("status") or effect.status in [null,"resolved","unwarned"]
		"flag_set":
			if effect.get("flag")=="routeWarned":return effect.get("value") is bool
			if effect.get("flag")=="closure_method":return effect.get("value") in ["carried_to_shelter","retreated_with_photos","transfer_retreat"]
			if effect.get("flag")=="grandfatherHomeR18":
				var record: Dictionary=_object(effect.get("value"))
				return record.get("revision")=="R18-family-v1" and (chapter_json_equal(record.get("stage"),1) or chapter_json_equal(record.get("stage"),2)) and _whole_number(record.get("day")) and record.day>=39 and record.day<=41 and record.get("choice") in ["look","keep"] and record.get("status") in ["planned","deferred","visited"]
		"photo_progress":
			if effect.get("op")=="transferred_delta":return effect.get("contract")==PHOTO_END_CONTRACT and _whole_number(effect.get("value")) and effect.value>=0
	return _chapter7_parent_22_ordinary_pre_photo_effect_supported(effect)


const P1_REV="r4v7-p1-adopted-v1"

const P1_CONTENT="r4v7.p1.ordinary"

const P1_EVENT_FIELDS=["id","title","intro","diary","choices","later","historyClass","target","actor","participants","homeParticipants","recipient","receivedContext","chapter"]

const P1_CHOICE_FIELDS=["id","label","hint","closures","diaries","immediateEffects","returnEffects","later"]

var p1_prose: Dictionary={}

func p1_same(a: Variant,b: Variant) -> bool:return JS_JSON.encode(a)==JS_JSON.encode(b)

func p1_load() -> void:
	if p1_prose.is_empty():p1_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/p1_prose.json"))

func p1_normal(event: Dictionary,actor: String,date: int,suffix: String,ids: Array) -> bool:
	if event.is_empty() or event.get("id")!="later.D"+str(date)+"."+actor+"."+suffix or event.get("actor")!=actor or event.get("target")!=actor or event.get("later")!=true:return false
	if event.keys().any(func(k):return k not in P1_EVENT_FIELDS) or not p1_same(event.get("participants"),[actor]) or not p1_same(event.get("homeParticipants"),[]):return false
	if not event.get("choices") is Array or not p1_same(event.choices.map(func(c):return c.get("id")),ids):return false
	return event.choices.all(func(c):return c.keys().all(func(k):return k in P1_CHOICE_FIELDS) and c.get("later")==true and p1_same(_object(c.get("closures")).keys(),["default"]) and p1_same(_object(c.get("diaries")).keys(),["default"]))

func p1_work_source(focus: Dictionary,actor: String) -> Dictionary:
	var id: Variant=_object(focus.get("workPackets")).get(actor);var all: Array=focus.get("resultPackets",[]);var ids: Array=all.map(func(p):return p.id)
	if not js_truthy(id) or ids.any(func(x):return ids.count(x)>1):return {}
	var found: Array=all.filter(func(p):return p.id==id)
	if found.is_empty():return {}
	var packet: Dictionary=found[0]
	if packet.get("status")!="pending" or id in state.effectLedger.appliedEffectIds or packet.get("timing")!="on_return" or packet.get("subjectId")!=actor or packet.get("scheduledDay")!=state.day or packet.get("sourceEventInstanceId")!="D"+str(int(state.day)+1)+":work" or packet.get("condition")!=null or packet.get("cancelReason")!=null or not p1_same(packet.get("revealTo"),["player"]) or not p1_same(packet.get("knowledgeFactIds"),[]):return {}
	if packet.keys().any(func(k):return k not in ["id","sourceEventInstanceId","timing","subjectId","effects","proseId","revealTo","knowledgeFactIds","scheduledDay","condition","cancelReason","status"]):return {}
	var resources: Array=[]
	for effect in packet.get("effects",[]):
		var keys: Array=effect.keys();keys.sort()
		if not p1_same(keys,["amount","resource","type"]) or effect.get("type")!="resource_delta" or effect.get("resource") not in ["rice","water"] or not _whole_number(effect.get("amount")) or effect.amount<0 or effect.amount>9007199254740991 or effect.resource in resources:return {}
		resources.append(effect.resource)
	if not packet.get("effects",[]).any(func(e):return e.resource=="rice" and e.amount>0):return {}
	return packet.duplicate(true)

func p1_scene_for(event: Dictionary) -> Dictionary:
	return {"asset":event.id+":empty-basket","sender":event.id+":clerk","delegate":event.id+":carrier","receiver":event.id+":receiver","origin":event.id+":desk","destination":event.id+":receiving-desk","observer":"安仁叔叔"}

func p1_choice(kind: String,id: String,extra: Variant=0,water: Variant=0) -> Dictionary:
	p1_load();var text: Dictionary=p1_prose[kind][id];var returned: Array=[{"type":"resource_delta","resource":"rice","amount":extra}] if kind=="queue" and id=="stay" and extra>0 else []
	return {"id":id,"label":text.label,"hint":text.hint,"closures":{"default":text.closure},"diaries":{"default":text.diary},"immediateEffects":[],"returnEffects":returned,"later":true,"workImpact":("partial" if water>0 else "complete") if kind=="queue" and id=="leave" else "none"}

func p1_card(focus: Dictionary,old: Dictionary,kind: String,source: Dictionary,extra: Variant=0) -> void:
	p1_load();var event:=old.duplicate(true);var date: int=int(focus.day)+1;var water: Variant=0
	for effect in source.effects:
		if effect.resource=="water":water=effect.amount;break
	event.id="later.D"+str(date)+"."+old.actor+".p1."+kind;event.title=p1_prose[kind].title;event.intro=p1_prose[kind].intro;event.diary="";event.historyClass="F：普通差事情境；D编号与出现窗口为G，不是新增日期史实"
	event.r4v7P1={"revision":P1_REV,"kind":kind,"occurrenceDay":date,"sourceEventId":old.id,"sourceEvent":old.duplicate(true),"sourceWork":source,"extra":extra}
	if kind=="delivery":event.r4v7P1.scene=p1_scene_for(event)
	event.choices=[]
	for id in (["delegate","route","self"] if kind=="delivery" else ["stay","return","leave"]):event.choices.append(p1_choice(kind,id,extra,water))
	if kind=="queue":
		if water>0:event.choices[2].closures.default=event.choices[2].closures.default.replace("沿认过的路回去","先朝原先说定的取水处走去，再沿认过的路回棚")
		var memo: Dictionary=_object(state.memory.get("motherCareReturned"));var chosen: Variant=state.memory.get("motherCareChosen")
		var valid: bool=_whole_number(memo.get("day")) and memo.day>=26 and memo.day<=31 and memo.day<date and memo.get("event") is String and memo.get("choice") in ["leave","stay","share"] and p1_same(chosen,memo)
		if valid and state.history.any(func(h):return h.get("type")=="later-return" and h.get("day")==memo.day-1 and h.get("event")==memo.event) and state.history.any(func(h):return h.get("type")=="later-choice" and h.get("day")==memo.day-1 and h.get("event")==memo.event and h.get("choice")==memo.choice):
			event.intro+="\n\n"+{"leave":"母亲想起以前离开照料现场时，仍有一段后来不曾亲见。今天有人应声，她便更留意应声与接手之间是否真的接上。","stay":"母亲想起以前留下照看的一阵。今天她仍先看是否有人真正接手，不能把自己曾经等过，算成眼前的人已经得到照料。","share":"母亲想起前次把已经拿到的粮分出一份。今天手里的袋子还空着，不能拿没有领到的东西替人解决眼前的事务。"}[memo.choice]
		if extra==0:event.choices[0].closures.default=event.choices[0].closures.default.replace("与这次添补","")
	focus.laterEvents[event.id]=event;focus.plan.eventIds[event.target]=event.id

func p1_produce_fresh(focus: Dictionary) -> void:
	var date: int=int(state.day)+1
	if state.ended or date<40 or date>43:return
	focus.p1Generation=P1_REV;var offered:=false;var rows: Dictionary=focus.plan.rows
	if date<=42 and not js_truthy(state.memory.get("p1DeliveryResult")) and "安仁叔叔" in focus.plan.targets and rows["安仁叔叔"].get("type")=="committee" and js_truthy(rows["安仁叔叔"].get("outside")) and not js_truthy(rows["安仁叔叔"].get("inactive")) and can_work_later("安仁叔叔"):
		var event: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get("安仁叔叔")));var work:=p1_work_source(focus,"安仁叔叔")
		if not work.is_empty() and p1_normal(event,"安仁叔叔",date,"inquiry",["brief","ask"]) and p1_same(event.choices[0].get("immediateEffects"),[{"type":"flag_set","flag":"keptHouseholdPrivate","value":true}]) and p1_same(event.choices[1].get("immediateEffects"),[]) and event.choices.all(func(c):return c.get("returnEffects",[]).is_empty()):p1_card(focus,event,"delivery",work);offered=true
	if date==41 and "母亲" in focus.plan.targets and rows["母亲"].get("type")=="relief" and js_truthy(rows["母亲"].get("outside")) and not js_truthy(rows["母亲"].get("inactive")) and can_work_later("母亲"):
		var event: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get("母亲")));var work:=p1_work_source(focus,"母亲")
		if not work.is_empty() and p1_normal(event,"母亲",date,"relief",["food","wood"]) and event.choices.all(func(c):return p1_same(c.get("immediateEffects"),[])):
			var a: Array=event.choices[0].get("returnEffects",[]);var b: Array=event.choices[1].get("returnEffects",[])
			if a.size()==1 and b.size()==1:
				var ak: Array=a[0].keys();ak.sort();var bk: Array=b[0].keys();bk.sort()
				if p1_same(ak,["amount","resource","type"]) and p1_same(bk,["amount","resource","type"]) and a[0].get("type")=="resource_delta" and b[0].get("type")=="resource_delta" and a[0].get("resource")=="rice" and b[0].get("resource")=="wood" and [a[0].get("amount"),b[0].get("amount")].all(func(v):return _whole_number(v) and v>=0 and v<=9007199254740991):p1_card(focus,event,"queue",work,a[0].amount)
	if not js_truthy(state.memory.get("p1DeliveryResult")):
		var old: Variant=state.memory.get("p1DeliveryWindow");var window: Dictionary=old.duplicate(true) if _object(old).get("revision")==P1_REV else {"revision":P1_REV,"trackingStartedDay":date,"offeredDays":[],"observedDays":[],"status":"open"}
		if date<=42 and not window.observedDays.any(func(v):return chapter_json_equal(v,date)):window.observedDays.append(date)
		if offered and not window.offeredDays.any(func(v):return chapter_json_equal(v,date)):window.offeredDays.append(date)
		if date==43:window.status="not_occurred";window.reason="offered_not_chosen" if not window.offeredDays.is_empty() else "never_eligible";window.completeWindow=[40,41,42].all(func(d):return window.observedDays.any(func(v):return chapter_json_equal(v,d)))
		if not p1_same(old,window):family_system_packet([{"type":"flag_set","flag":"p1DeliveryWindow","value":window}],"p1:window")

func _chapter7_parent_27_deadline_apply(fact: Dictionary) -> bool:
	if not deadline_validate_fact(fact):return false
	var person: String=deadline_who(fact)[0]
	if deadline_known(person):return false
	if not state.has("knowledgeFacts"):state.knowledgeFacts=[]
	var aggregates: Array=state.knowledgeFacts.filter(func(f):return f.get("id")==DEADLINE_CONTENT);var aggregate: Dictionary={} if aggregates.is_empty() else aggregates[0]
	if not aggregate.is_empty() and not aggregate.get("knownBy") is Array:return deadline_error("旧期限收件记录格式异常，不能自动替换。")
	state.knowledgeFacts.append(fact.duplicate(true))
	if aggregate.is_empty():aggregate={"id":DEADLINE_CONTENT,"day":fact.acquiredDay,"knownBy":[],"scope":DEADLINE_SCOPE};state.knowledgeFacts.append(aggregate)
	if person not in aggregate.knownBy:aggregate.knownBy.append(person)
	return true


func _chapter7_parent_27_deadline_validate_fact(fact: Dictionary) -> bool:
	if not deadline_own_fact(fact) or fact.get("id")!=fact.get("factId") or fact.get("contentId")!=DEADLINE_CONTENT or fact.get("recordRevision")!=DEADLINE_REV:return deadline_error("无法识别这份逐人期限记录；未改写旧记录。")
	var who:=deadline_who(fact)
	if who.size()!=1 or who[0] not in PEOPLE:return deadline_error("逐人期限记录的接收者不唯一。")
	if not _whole_number(fact.get("acquiredDay")) or fact.acquiredDay<36 or fact.acquiredDay>state.day+1 or fact.get("day")!=fact.acquiredDay:return deadline_error("获知日不能倒记、超前或与记录日矛盾。")
	if fact.id!=DEADLINE_PREFIX+who[0]+":D"+str(int(fact.acquiredDay)) or not js_truthy(fact.get("sourcePacketId")) or fact.get("sourceMode")!="told" or fact.get("sourceKind") not in ["shop_delivery","family_relay","observed_deadline_scene"]:return deadline_error("期限知识来源或编号不一致。")
	if fact.get("scope")!=DEADLINE_SCOPE or not fact.get("secrecy") is bool or fact.secrecy!=false or not fact.get("diaryEligible") is bool or fact.diaryEligible!=(who[0]=="罗瑾") or not fact.get("disclosedToLuo") is bool or fact.disclosedToLuo!=(who[0]=="罗瑾"):return deadline_error("店铺期限不能扩张为照片秘密或其他人的日记权限。")
	if fact.sourceKind=="family_relay" and (fact.get("sourceActor") not in PEOPLE or fact.sourceActor==who[0] or not deadline_known(fact.sourceActor)):return deadline_error("家人转述缺少既有知情来源。")
	return true


func _chapter7_parent_27_ordinary_pre_photo_effect_supported(effect: Dictionary) -> bool:
	if effect.get("type")=="flag_set" and effect.get("flag")=="p1DeliveryWindow":return effect.get("value") is Dictionary and effect.value.get("revision")==P1_REV
	return _chapter7_parent_26_ordinary_pre_photo_effect_supported(effect)


const P1_SCOPES={"ordinary_delivery_unconfirmed":"handoff","ordinary_delivery_confirmed":"observe_receive","route_only":"route","self_only":"self","queue_stay":"queue_stay","queue_return":"queue_return","queue_leave":"queue_leave"}

func p1_fail(message: String) -> bool:fail_contract("P1_CONTRACT","P1合同："+message);return false

func p1_marked(event: Dictionary) -> bool:return _object(event.get("r4v7P1")).get("revision")==P1_REV

func p1_fact_marked(fact: Dictionary) -> bool:return fact.get("contentId")==P1_CONTENT or fact.get("contractRevision")==P1_REV

func p1_eid(event: Dictionary,key: String) -> String:return state.seed+":D"+str(int(event.r4v7P1.occurrenceDay))+":"+event.id+":p1:"+key

func p1_validate_event(event: Dictionary) -> bool:
	if not js_truthy(event.get("r4v7P1")):return true
	var info: Dictionary=_object(event.r4v7P1);var date: Variant=info.get("occurrenceDay");var delivery: bool=info.get("kind")=="delivery";var actor: String="安仁叔叔" if delivery else "母亲"
	if info.get("revision")!=P1_REV or info.get("kind") not in ["delivery","queue"] or not _whole_number(date) or date<40 or date>42 or not delivery and date!=41 or event.get("id")!="later.D"+str(int(date))+"."+actor+".p1."+str(info.get("kind")) or event.get("target")!=actor or event.get("actor")!=actor or not p1_same(event.get("participants"),[actor]) or not p1_same(event.get("homeParticipants"),[]) or info.get("sourceEventId")!=_object(info.get("sourceEvent")).get("id") or _object(info.get("sourceWork")).get("status")!="pending" or not _whole_number(info.get("extra")) or info.extra<0 or info.extra>9007199254740991:return p1_fail("已缓存事件身份不匹配")
	if delivery and not p1_same(info.get("scene"),p1_scene_for(event)):return p1_fail("普通物/接收者/地点或观察者身份不匹配")
	if not p1_same(event.get("choices",[]).map(func(c):return c.get("id")),["delegate","route","self"] if delivery else ["stay","return","leave"]):return p1_fail("缓存选项不匹配")
	return true

func p1_expected_fact(fact: Dictionary) -> bool:
	var date: Variant=fact.get("day")
	if fact.get("contentId")!=P1_CONTENT or fact.get("contractRevision")!=P1_REV or not _whole_number(date) or date<40 or date>42 or date>state.day+1:return p1_fail("未知知识身份或日期")
	var delivery: bool=fact.get("actor")=="安仁叔叔";var mother: bool=fact.get("actor")=="母亲"
	if not delivery and not mother or mother and date!=41 or fact.get("eventId")!="later.D"+str(int(date))+"."+str(fact.get("actor"))+".p1."+("delivery" if delivery else "queue"):return p1_fail("知识人物或事件错位")
	var scopes: Array=["ordinary_delivery_unconfirmed","ordinary_delivery_confirmed","route_only","self_only"] if delivery else ["queue_stay","queue_return","queue_leave"]
	if fact.get("scope") not in scopes or fact.get("mode") not in ["witness","told"] or not fact.get("knownBy") is Array or fact.knownBy.size()!=1:return p1_fail("知识范围不合法")
	var who: Variant=fact.knownBy[0]
	if fact.get("source")!=fact.actor or (who not in ["player",fact.actor] if fact.mode=="witness" else (who not in PEOPLE or who==fact.actor)):return p1_fail("知识来源或受众错位")
	var action: String=P1_SCOPES[fact.scope];var prefix: String=state.seed+":D"+str(int(date))+":"+fact.eventId+":p1:"
	if fact.get("id")!=fact.eventId+":p1:"+fact.scope+":"+fact.mode+":"+str(who) or fact.get("originPacketId")!=prefix+action or fact.get("sourcePacketId")!=prefix+("tell" if fact.mode=="told" else action) or not fact.get("text") is String or fact.text.is_empty():return p1_fail("知识凭据错位")
	return true

func p1_validate_fact(fact: Dictionary) -> bool:
	if not p1_expected_fact(fact):return false
	var found: Array=state.focus.get("resultPackets",[]).filter(func(p):return p.get("id")==fact.sourcePacketId);var packet: Dictionary={} if found.is_empty() else found[0];var action: Dictionary=_object(packet.get("p1Action"))
	if packet.is_empty() or packet.get("status")!="pending" or packet.get("sourceEventInstanceId")!=fact.eventId or packet.get("subjectId")!=fact.actor or action.get("revision")!=P1_REV or action.get("day")!=fact.day or not packet.get("effects",[]).any(func(e):return e.get("type")=="knowledge_grant" and p1_same(e.get("fact"),fact)):return p1_fail("知识没有当前待执行动作")
	if fact.mode=="told" and (fact.originPacketId not in state.effectLedger.appliedEffectIds or not state.knowledgeFacts.any(func(k):return k.get("contentId")==P1_CONTENT and k.get("id")==fact.eventId+":p1:"+fact.scope+":witness:"+fact.actor)):return p1_fail("转述没有已执行的亲见来源")
	return true

func p1_apply_fact(fact: Dictionary) -> bool:
	if state.get("knowledgeFacts",[]).any(func(k):return k.get("id")==fact.get("id")):return p1_fail("知识重复授予")
	if not state.has("knowledgeFacts"):state.knowledgeFacts=[]
	state.knowledgeFacts.append(fact.duplicate(true));return true

func p1_facts(event: Dictionary,scope: String,text: String,mode: String="witness",names: Variant=null) -> Array:
	var recipients: Array=["player",event.actor] if names==null else names;var result: Array=[]
	for person in recipients:result.append({"type":"knowledge_grant","fact":{"id":event.id+":p1:"+scope+":"+mode+":"+person,"contentId":P1_CONTENT,"contractRevision":P1_REV,"eventId":event.id,"actor":event.actor,"source":event.actor,"day":event.r4v7P1.occurrenceDay,"knownBy":[person],"scope":scope,"mode":mode,"sourcePacketId":p1_eid(event,"tell" if mode=="told" else P1_SCOPES[scope]),"originPacketId":p1_eid(event,P1_SCOPES[scope]),"text":text}})
	return result

func p1_action_packet(event: Dictionary,key: String,effects: Array,timing: String="immediate",meta: Dictionary={}) -> Dictionary:
	var packet:=queue_focus_packet(effects,event.id+":p1:"+key,timing,event.actor);packet.sourceEventInstanceId=event.id;packet.knowledgeFactIds=effects.filter(func(e):return e.get("type")=="knowledge_grant").map(func(e):return e.fact.id);packet.p1Action={"revision":P1_REV,"eventId":event.id,"action":key,"day":event.r4v7P1.occurrenceDay}
	for field in meta:packet.p1Action[field]=meta[field].duplicate(true) if meta[field] is Array or meta[field] is Dictionary else meta[field]
	if not apply_ordinary_pre_photo_packet(packet):
		if contract_error=="":p1_fail("动作没有执行："+key)
		return {}
	return packet

func p1_check_choice(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	if not p1_marked(event):return true
	if not p1_validate_event(event):return false
	if not is_same(focus,state.focus) or focus.day!=state.day or event.target!=focus.selected or focus.plan.eventIds.get(event.target)!=event.id or event.r4v7P1.occurrenceDay!=focus.day+1 or not event.choices.any(func(c):return is_same(c,choice)):return p1_fail("实例/选择不相符")
	if not can_work_later(event.actor) or not later_event_eligible(event,focus.plan):return p1_fail("人物现时不能完成本场行动")
	var info: Dictionary=event.r4v7P1;var source: Dictionary=info.sourceWork;var found: Array=focus.resultPackets.filter(func(p):return p.id==source.id)
	if found.is_empty() or not p1_same(found[0],source) or source.id in state.effectLedger.appliedEffectIds or p1_work_source(focus,event.actor).is_empty():return p1_fail("基础工作已改变或执行")
	var water: Variant=0
	for effect in source.effects:
		if effect.resource=="water":water=effect.amount;break
	var expected:=p1_choice(info.kind,choice.id,info.extra,water)
	if choice.keys().any(func(k):return k not in P1_CHOICE_FIELDS and k!="workImpact") or not p1_same(choice.get("immediateEffects"),expected.immediateEffects) or not p1_same(choice.get("returnEffects"),expected.returnEffects) or choice.get("workImpact")!=expected.workImpact:return p1_fail("选择混入未采用的效果")
	if info.kind=="queue" and info.extra!=info.sourceEvent.choices[0].returnEffects[0].get("amount",0):return p1_fail("添补与原来源不符")
	return true

func prepare_p1_choice(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	if not p1_marked(event):return true
	if not p1_check_choice(focus,event,choice):return false
	if event.r4v7P1.kind=="queue" and choice.id=="leave":
		var source: Dictionary=event.r4v7P1.sourceWork;var packet:=queue_focus_packet(source.effects.filter(func(e):return e.resource=="water"),event.id+":p1:queue-work","on_return","母亲");packet.sourceEventInstanceId=event.id;packet.p1Work={"revision":P1_REV,"original":source.id,"source":source.duplicate(true),"eventId":event.id}
		var found: Array=focus.resultPackets.filter(func(p):return p.id==source.id);var old: Dictionary=found[0];old.status="cancelled";old.cancelReason="P1离队：未领取粮，回程水由"+packet.id+"单独结算";old.p1ReplacedBy=packet.id;focus.p1QueueWork={"revision":P1_REV,"original":source.id,"replacement":packet.id,"eventId":event.id}
	return true

func p1_delivery_result(event: Dictionary,status: String,key: String) -> Dictionary:
	return {"revision":P1_REV,"eventId":event.id,"occurrenceDay":event.r4v7P1.occurrenceDay,"status":status,"scene":event.r4v7P1.scene.duplicate(true),"sourcePacketId":p1_eid(event,key)}

func complete_p1_scene(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	if not p1_marked(event):return true
	p1_load();var base: String=state.seed+":D"+str(int(state.day)+1)+":"+event.id+":"+choice.id+":immediate"
	if state.phase!="focusEvent" or focus.get("choiceIndex")!=null or base not in state.effectLedger.appliedEffectIds:return p1_fail("没有原选择的已执行现场包")
	var info: Dictionary=event.r4v7P1
	if info.kind=="queue":
		var scope: String="queue_"+choice.id;var result: Dictionary={"revision":P1_REV,"eventId":event.id,"occurrenceDay":info.occurrenceDay,"choice":choice.id,"sourcePacketId":p1_eid(event,scope)}
		return not p1_action_packet(event,scope,[{"type":"flag_set","flag":"p1QueueResult","value":result}]+p1_facts(event,scope,p1_prose.queue[choice.id].closure)).is_empty()
	var window: Dictionary=_object(state.memory.get("p1DeliveryWindow")).duplicate(true);window.revision=P1_REV;window.status="decided";window.decidedDay=info.occurrenceDay;window.eventId=event.id;var window_effect: Dictionary={"type":"flag_set","flag":"p1DeliveryWindow","value":window}
	if choice.id=="delegate":
		var handed:=p1_delivery_result(event,"ordinary_delivery_unconfirmed","handoff");var handoff:=p1_action_packet(event,"handoff",[{"type":"flag_set","flag":"p1DeliveryResult","value":handed},window_effect]+p1_facts(event,handed.status,"安仁把同一只空竹筐交给本场代送者，尚未核实收件。"),"immediate",info.scene)
		if handoff.is_empty():return false
		var expected: Dictionary={"revision":P1_REV,"eventId":event.id,"action":"handoff","day":info.occurrenceDay}
		for key in info.scene:expected[key]=info.scene[key]
		if can_work_later("安仁叔叔") and later_event_eligible(event,focus.plan) and handoff.status=="applied" and handoff.id in state.effectLedger.appliedEffectIds and p1_same(handoff.p1Action,expected):
			var confirmed:=p1_delivery_result(event,"ordinary_delivery_confirmed","observe_receive");confirmed.handoffPacketId=handoff.id;var meta: Dictionary=info.scene.duplicate(true);meta.requiresAppliedPacket=handoff.id
			return not p1_action_packet(event,"observe_receive",[{"type":"flag_set","flag":"p1DeliveryResult","value":confirmed}]+p1_facts(event,confirmed.status,"安仁在本场指定收物处亲见同一只筐由接收者收下，并当面核清本次来件。"),"immediate",meta).is_empty()
		choice.closures.default=p1_prose.delivery.delegate.pending;choice.diaries.default=p1_prose.delivery.delegate.pendingDiary
	else:
		var result:=p1_delivery_result(event,"route_only" if choice.id=="route" else "self_only",choice.id)
		return not p1_action_packet(event,choice.id,[{"type":"flag_set","flag":"p1DeliveryResult","value":result},window_effect]+p1_facts(event,result.status,p1_prose.delivery[choice.id].closure),"immediate",info.scene).is_empty()
	return true

func apply_p1_work(focus: Dictionary,event: Dictionary,row: Dictionary,original: Dictionary,lines: Array) -> bool:
	if not p1_marked(event) or event.r4v7P1.kind!="queue" or focus.get("choiceIndex")==null or event.choices[int(focus.choiceIndex)].id!="leave" or row.name!="母亲":return false
	var info: Dictionary=_object(focus.get("p1QueueWork"));var source: Dictionary=event.r4v7P1.sourceWork;var found: Array=focus.resultPackets.filter(func(p):return p.id==info.get("replacement"));var packet: Dictionary={} if found.is_empty() else found[0]
	if info.is_empty() or info.get("eventId")!=event.id or packet.is_empty():return p1_fail("分项工作包不一致或重放")
	var expected:=source.duplicate(true);expected.status="cancelled";expected.cancelReason="P1离队：未领取粮，回程水由"+packet.id+"单独结算";expected.p1ReplacedBy=packet.id
	if packet.id!=p1_eid(event,"queue-work") or packet.get("scheduledDay")!=focus.day or not p1_same(_object(packet.get("p1Work")).get("source"),source) or not p1_same(original,expected) or not p1_same(packet.effects,source.effects.filter(func(e):return e.resource=="water")) or packet.subjectId!="母亲" or packet.timing!="on_return" or packet.sourceEventInstanceId!=event.id or _object(packet.get("p1Work")).get("original")!=source.id or packet.status!="pending" or source.id in state.effectLedger.appliedEffectIds or packet.id in state.effectLedger.appliedEffectIds:return p1_fail("分项工作包不一致或重放")
	if not present("母亲") or row.get("inactive",false):packet.status="cancelled";packet.cancelReason="母亲未实际返家，不入库";return true
	if not apply_ordinary_pre_photo_packet(packet):return p1_fail("回程水没有完成结算")
	lines.append("母亲回到了棚边；这趟没有领粮，原定回程已取得的东西另行清点。" if packet.effects.any(func(e):return e.resource=="water" and e.amount>0) else "母亲回到了棚边，没有把这趟未领到的粮算进家里。");return true

func complete_p1_return(focus: Dictionary,event: Dictionary) -> bool:
	if not p1_marked(event) or not understands(event.actor) or not later_event_eligible(event,focus.plan):return true
	var result: Dictionary=_object(state.memory.get("p1DeliveryResult" if event.r4v7P1.kind=="delivery" else "p1QueueResult"))
	if result.get("eventId")!=event.id:return p1_fail("返家之前没有现场结果")
	var scope: String=result.status if event.r4v7P1.kind=="delivery" else "queue_"+result.choice
	var origins: Array=state.knowledgeFacts.filter(func(k):return k.get("contentId")==P1_CONTENT and k.get("eventId")==event.id and k.get("scope")==scope and k.get("mode")=="witness" and p1_same(k.get("knownBy"),[event.actor]))
	if origins.is_empty() or origins[0].sourcePacketId not in state.effectLedger.appliedEffectIds:return p1_fail("返家缺少现场亲见来源")
	var origin: Dictionary=origins[0];var listeners: Array=PEOPLE.filter(func(n):return n!=event.actor and understands(n))
	if not listeners.is_empty():return not p1_action_packet(event,"tell",p1_facts(event,scope,origin.text,"told",listeners),"on_return",{"originPacketId":origin.sourcePacketId}).is_empty()
	return true

func p1_return_knowledge_allowed(focus: Dictionary,event: Dictionary) -> bool:
	return not p1_marked(event) or state.knowledgeFacts.any(func(k):return k.get("contentId")==P1_CONTENT and k.get("eventId")==event.id and k.get("mode")=="told" and p1_same(k.get("knownBy"),["罗瑾"]))

func _chapter7_parent_29_resolve_day_eleven_twelve_choice(index: int) -> bool:
	if state.day<38:return _chapter7_parent_24_resolve_day_eleven_twelve_choice(index)
	if state.day>43:return false
	var event:=current_later_focus_event()
	if event.get("photoMid",false) or event.get("photoEnd",false) or event.has("uncleCrisis") or event.get("nodeId") in ["discover","trial","firstPrint","deadline","warning"]:return resolve_chapter_eight_prepared_choice(index)
	if event.get("uncleBoundary",false):return resolve_uncle_boundary_choice(index)
	if event.has("motherCrisis"):return resolve_mother_crisis_choice(index)
	if event.get("motherCare",false):return resolve_mother_care_choice(index)
	if event.has("neighbourParcel"):return resolve_parcel_choice(index)
	if event.has("custodyNight") or event.has("custodyHandoff"):return resolve_custody_choice(index)
	if event.has("neighbourhood"):return resolve_rope_choice(index)
	if event.has("messageThread"):return resolve_message_thread_choice(index)
	return commit_rope_choice_core(index)

func resolve_p1_choice(index: int) -> bool:
	if state.ended or state.phase!="focusEvent" or state.focus.get("choiceIndex")!=null:return false
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if event.is_empty() or index<0 or index>=event.get("choices",[]).size():return false
	var choice: Dictionary=event.choices[index]
	for key in ["motherCrisis","uncleCrisis","motherCare","uncleBoundary","photoTransfer","photoBatch","nextMorningEffects"]:
		if js_truthy(choice.get(key)):return false
	var immediate: Array=choice.get("immediateEffects",[]).duplicate(true)
	if js_truthy(choice.get("flag")):immediate.append({"type":"flag_set","flag":choice.flag,"value":true})
	if immediate.any(func(effect):return not ordinary_pre_photo_effect_supported(effect)) or choice.get("returnEffects",[]).any(func(effect):return not ordinary_pre_photo_effect_supported(effect)):return false
	var requirement:=ordinary_pre_photo_requirement(choice)
	if not requirement.met:state.error=requirement.reason;return false
	if not later_event_eligible(event,focus.plan):state.error="当事人已不能参与这段现场。";return false
	var backup:=state.duplicate(true);var before:=focus_snapshot();contract_error="";contract_message=""
	if not prepare_p1_choice(focus,event,choice):return rollback_photo_choice(backup)
	apply_ordinary_pre_photo_packet(queue_focus_packet(immediate,event.id+":"+choice.id+":immediate","immediate",event.actor))
	if contract_error!="":return rollback_photo_choice(backup)
	if not complete_p1_scene(focus,event,choice):return rollback_photo_choice(backup)
	var packet:=queue_focus_packet(choice.get("returnEffects",[]),event.id+":"+choice.id+":return","on_return",event.actor)
	focus.carriedAssets=[]
	for effect in packet.effects:
		if effect.type=="resource_delta" and effect.amount>0:focus.carriedAssets.append({"owner":event.actor,"resource":effect.resource,"amount":effect.amount,"resultPacketId":packet.id})
	focus.cancelWork=focus.selected if choice.get("workImpact")=="complete" else null;focus.partialWork=focus.selected if choice.get("workImpact")=="partial" else null
	focus.choiceIndex=index;focus.outcomeKey="default";focus.immediateText=choice.closures.default;focus.immediateChange=describe_focus_change(before)
	focus.knowledge.player=[focus.immediateText];focus.knowledge.luo=[focus.immediateText] if focus.selected=="罗瑾" or (focus.selected=="home" and not focus.plan.rows["罗瑾"].outside) else []
	var history: Dictionary={"day":state.day,"type":"later-choice","event":event.id,"choice":choice.id}
	if event.get("conditionKind")==_object(event.get("readingVariant")).get("kind"):
		if event.has("readingVariant"):history.readingVariant=event.readingVariant
	else:history.readingVariant=null
	state.phase="focusResult";state.error=null;state.history.append(history);return true

func p1_validate_state() -> bool:
	if js_truthy(state.focus.get("p1Generation")) and state.focus.p1Generation!=P1_REV:return p1_fail("未知P1生成版本")
	for event in state.focus.get("laterEvents",{}).values():
		if not p1_validate_event(event):return false
	var facts: Array=state.get("knowledgeFacts",[]).filter(func(k):return p1_fact_marked(k));var ids: Array=facts.map(func(k):return k.get("id"))
	if ids.any(func(id):return ids.count(id)>1):return p1_fail("重复知识")
	for fact in facts:
		if not p1_expected_fact(fact):return false
		if fact.sourcePacketId not in state.effectLedger.appliedEffectIds or fact.originPacketId not in state.effectLedger.appliedEffectIds:return p1_fail("知识未执行")
		if fact.mode=="told" and not facts.any(func(k):return k.get("id")==fact.eventId+":p1:"+fact.scope+":witness:"+fact.actor):return p1_fail("转述来源缺失")
	var result: Dictionary=_object(state.memory.get("p1DeliveryResult"))
	if not result.is_empty():
		var day: Variant=result.get("occurrenceDay")
		if result.get("revision")!=P1_REV or not _whole_number(day) or day<40 or day>42 or day>state.day+1 or result.get("eventId")!="later.D"+str(int(day))+".安仁叔叔.p1.delivery" or result.get("status") not in ["ordinary_delivery_unconfirmed","ordinary_delivery_confirmed","route_only","self_only"]:return p1_fail("递送结果身份错误")
		var key: String=P1_SCOPES[result.status];var expected: String=state.seed+":D"+str(int(day))+":"+result.eventId+":p1:"+key
		if result.get("sourcePacketId")!=expected or result.sourcePacketId not in state.effectLedger.appliedEffectIds or not facts.any(func(k):return k.get("eventId")==result.eventId and k.get("scope")==result.status and k.get("mode")=="witness" and k.get("knownBy",[])[0]=="安仁叔叔"):return p1_fail("递送结果缺执行来源")
	return true

func p1_delivery_projection(person: String="罗瑾") -> Dictionary:
	var result: Dictionary=_object(state.memory.get("p1DeliveryResult"))
	if result.is_empty():return {"status":"not_occurred","known":false,"photoAssistance":false}
	var known: bool=state.get("knowledgeFacts",[]).any(func(k):return k.get("contentId")==P1_CONTENT and k.get("eventId")==result.get("eventId") and k.get("scope")==result.get("status") and person in k.get("knownBy",[]))
	return {"status":result.status,"occurrenceDay":result.occurrenceDay,"known":known,"sourceAvailable":understands("安仁叔叔"),"photoAssistance":false}

const DISCLOSURE_REV="r3-disclosure-receipt-v1"

const DISCLOSURE_CONTENT="family.disclosure.receipt"

const DISCLOSURE_ADULTS=["母亲","安仁叔叔","外祖父"]

const DISCLOSURE_SCOPES={"images_limited":"只讲亲见影像与眼下顾虑","ordinary_experience":"只讲普通经历与眼下顾虑","personal_unease":"只说明不安，未讲清事情"}

func disclosure_error(message: String) -> bool:fail_contract("DISCLOSURE_RECORD_INVALID",message);return false

func disclosure_marked(fact: Dictionary) -> bool:
	return fact.get("contentId")==DISCLOSURE_CONTENT or fact.get("contractRevision")==DISCLOSURE_REV or fact.get("id") is String and fact.id.contains(":disclosure-receipt:")

func disclosure_make(event: Dictionary,choice: Dictionary,packet: Dictionary,mode: String,person: String) -> Dictionary:
	var scope: String="personal_unease" if choice.id=="safe" else ("images_limited" if js_truthy(event.get("disclosureContextHadEvidence")) else "ordinary_experience");var id: String=packet.id+":disclosure-receipt:"+person
	return {"id":id,"factId":id,"contentId":DISCLOSURE_CONTENT,"contractRevision":DISCLOSURE_REV,"knownBy":[person],"recipient":event.recipient,"sourceActor":"罗瑾","sourceEventInstanceId":event.id,"sourcePacketId":packet.id,"choiceId":choice.id,"deliveryMode":mode,"sourceMode":"witnessed" if person=="player" and mode=="observed" else "told","day":state.day+1,"acquiredDay":state.day+1,"scope":scope,"sourceHasDiscovery":js_truthy(event.get("disclosureContextHadEvidence")),"numbersDisclosed":false,"locationDisclosed":false,"diaryEligible":false,"disclosedToLuo":false}

func disclosure_validate_fact(fact: Dictionary) -> bool:
	var who: Array=fact.get("knownBy",[]) if fact.get("knownBy") is Array else [];var person: Variant=who[0] if not who.is_empty() else null
	if fact.get("contentId")!=DISCLOSURE_CONTENT or fact.get("contractRevision")!=DISCLOSURE_REV:return disclosure_error("告知记录身份不完整；不降格为旧记录。")
	if fact.get("recipient") not in DISCLOSURE_ADULTS or who.size()!=1 or person not in [fact.get("recipient"),"player"]:return disclosure_error("告知只记录本次实际对象，不扩散成全家知情。")
	if fact.get("sourceActor")!="罗瑾" or not fact.get("sourceEventInstanceId") is String or fact.sourceEventInstanceId.is_empty() or not fact.get("sourcePacketId") is String or fact.sourcePacketId.is_empty() or fact.get("id")!=fact.sourcePacketId+":disclosure-receipt:"+str(person) or fact.get("factId")!=fact.get("id"):return disclosure_error("告知缺少原场景、说话人或唯一结果包。")
	if not _whole_number(fact.get("acquiredDay")) or fact.acquiredDay<47 or fact.acquiredDay>49 or fact.acquiredDay>state.day+1 or not chapter_json_equal(fact.get("day"),fact.acquiredDay):return disclosure_error("告知日与实际记录矛盾；不倒填旧日期。")
	if fact.get("choiceId") not in ["limited","safe"] or fact.get("deliveryMode") not in ["observed","safe_default"] or fact.deliveryMode=="safe_default" and fact.choiceId!="limited":return disclosure_error("不是本次已有的有限披露选项或默认分支。")
	if not fact.get("sourceHasDiscovery") is bool or fact.get("scope")!=("personal_unease" if fact.choiceId=="safe" else ("images_limited" if fact.sourceHasDiscovery else "ordinary_experience")):return disclosure_error("不能把普通经历或没有说清的话升级为照片秘密。")
	if ["numbersDisclosed","locationDisclosed","diaryEligible","disclosedToLuo"].any(func(k):return not fact.get(k) is bool or fact[k]!=false) or fact.get("sourceMode")!=("witnessed" if person=="player" and fact.deliveryMode=="observed" else "told"):return disclosure_error("告知范围或日记权限被扩大。")
	return true

func disclosure_apply(fact: Dictionary) -> bool:
	if not disclosure_validate_fact(fact):return false
	if not state.has("knowledgeFacts"):state.knowledgeFacts=[]
	var found: Array=state.knowledgeFacts.filter(func(k):return k.get("id")==fact.id)
	if not found.is_empty():
		if JS_JSON.encode(found[0])!=JS_JSON.encode(fact):return disclosure_error("同一告知存在矛盾记录；原事实未覆盖。")
		return false
	state.knowledgeFacts.append(fact.duplicate(true));return true

func disclosure_validate() -> bool:
	var facts: Array=state.get("knowledgeFacts",[]).filter(func(k):return disclosure_marked(k));var groups: Dictionary={};var seen: Array=[];var ledger: Array=state.get("effectLedger",{}).get("appliedEffectIds",[])
	for fact in facts:
		if not disclosure_validate_fact(fact):return false
		if fact.id in seen:return disclosure_error("告知记录重复。")
		seen.append(fact.id)
		if fact.sourcePacketId not in ledger:return disclosure_error("告知没有已执行结果包支持。")
		if not groups.has(fact.sourcePacketId):groups[fact.sourcePacketId]=[]
		groups[fact.sourcePacketId].append(fact)
	for group in groups.values():
		var first: Dictionary=group[0]
		if group.size()!=2 or not group.any(func(k):return k.knownBy[0]=="player") or not group.any(func(k):return k.knownBy[0]==first.recipient):return disclosure_error("告知现场与接收记录残缺，不自动补写。")
		for fact in group:
			for key in ["recipient","sourceActor","sourceEventInstanceId","choiceId","deliveryMode","acquiredDay","scope","sourceHasDiscovery"]:
				if not chapter_json_equal(fact[key],first[key]):return disclosure_error("同一次告知的来源或范围不一致。")
	for packet in state.focus.get("resultPackets",[]):
		if not js_truthy(packet.get("disclosureNotice")):continue
		var marker: Dictionary=_object(packet.disclosureNotice)
		if marker.get("revision")!=DISCLOSURE_REV or marker.get("recipient") not in DISCLOSURE_ADULTS or packet.get("subjectId")!="罗瑾" or packet.get("timing") not in ["immediate","on_return"]:return disclosure_error("告知结果包合同残缺。")
		var given: Array=packet.get("effects",[]).filter(func(e):return e.get("type")=="knowledge_grant" and disclosure_marked(_object(e.get("fact"))))
		if given.size()!=2:return disclosure_error("告知包缺少原定的两条知识记录。")
		for effect in given:
			if not disclosure_validate_fact(effect.fact):return false
			if effect.fact.sourcePacketId!=packet.id or effect.fact.recipient!=marker.recipient or effect.fact.sourceEventInstanceId!=marker.get("eventId"):return disclosure_error("告知包与知识来源不一致。")
			if packet.get("status")=="applied" and not facts.any(func(k):return k.id==effect.fact.id and JS_JSON.encode(k)==JS_JSON.encode(effect.fact)):return disclosure_error("已执行告知包的知识记录丢失。")
		if packet.get("status")=="applied" and packet.id not in ledger:return disclosure_error("已执行告知包缺少执行账本。")
	return true

func disclosure_availability(event: Dictionary,plan: Dictionary) -> Dictionary:
	if event.get("nodeId")!="disclose":return {"ok":true}
	var rows: Dictionary=_object(plan.get("rows"));var luo: Dictionary=_object(rows.get("罗瑾"));var receiver: Dictionary=_object(rows.get(event.get("recipient")))
	if state.ended or not understands("罗瑾") or js_truthy(luo.get("outside")) or js_truthy(luo.get("inactive")):return {"ok":false,"reason":"罗瑾此刻不能完成这段交谈，尚未记录告知。"}
	if event.get("recipient") not in DISCLOSURE_ADULTS or not understands(event.recipient) or js_truthy(receiver.get("outside")) or js_truthy(receiver.get("inactive")):return {"ok":false,"reason":"原定交谈对象此刻不能接话，尚未记录告知；不会自动换人。"}
	return {"ok":true}

func attach_disclosure_knowledge(packet: Dictionary,event: Dictionary,choice: Dictionary,mode: String) -> bool:
	if event.get("nodeId")!="disclose" or event.get("disclosureRecordRevision")!=DISCLOSURE_REV:return true
	var check:=disclosure_availability(event,state.focus.get("plan",{}))
	if not check.ok:return disclosure_error(check.reason)
	if packet.get("status")!="pending" or packet.id in state.effectLedger.appliedEffectIds:return true
	packet.disclosureNotice={"revision":DISCLOSURE_REV,"eventId":event.id,"recipient":event.recipient}
	for person in [event.recipient,"player"]:
		var fact:=disclosure_make(event,choice,packet,mode,person)
		if not disclosure_validate_fact(fact):return false
		if not packet.effects.any(func(e):return e.get("type")=="knowledge_grant" and _object(e.get("fact")).get("id")==fact.id):packet.effects.append({"type":"knowledge_grant","fact":fact})
	return true

func disclosure_legacy_photo27() -> Variant:
	var old: Variant=state.memory.get("photo27");var value: Variant=_object(old).get("33",_object(old).get(33)) if old is Dictionary else (old[33] if old is Array and old.size()>33 else null)
	if not chapter_json_equal(value,"tell"):return null
	return {"identity":"legacy.eventDefs.d34.mother.tell","projectionRevision":"r3-c017-legacy-photo27-projection-v1","sourcePath":"memory.photo27[33]","sourceValue":"tell","recipient":"母亲","acquiredDay":34,"date":"1938-01-15","scope":"legacy_full_including_storage","sourceActor":"罗瑾","sourceMode":"legacy_choice_flag","sourceHasDiscovery":true,"numbersDisclosed":false,"locationDisclosed":true,"ledgerBacked":false,"strictKnowledgeFact":false,"affectsD43":false,"mutatesState":false,"scopeLabel":"罗瑾把胶卷、秘密加印和暗室藏处告诉母亲"}

func disclosure_projection() -> Dictionary:
	var old_error: String=contract_error;var old_message: String=contract_message;var invalid: bool=not disclosure_validate();contract_error=old_error;contract_message=old_message
	var facts: Array=state.get("knowledgeFacts",[]).filter(func(k):return disclosure_marked(_object(k)));var ledger: Array=state.get("effectLedger",{}).get("appliedEffectIds",[]);var entries: Array=[]
	if not invalid:
		for fact in facts:
			if fact.knownBy[0]==fact.recipient and fact.sourcePacketId in ledger:entries.append({"recipient":fact.recipient,"day":fact.acquiredDay,"scope":fact.scope,"scopeLabel":DISCLOSURE_SCOPES[fact.scope],"mode":fact.deliveryMode})
	var legacy_photo: Variant=disclosure_legacy_photo27();var name: Variant=state.memory.get("photoDisclosedTo");var legacy: Variant=null
	if not invalid and name in DISCLOSURE_ADULTS and not entries.any(func(e):return e.recipient==name) and _object(legacy_photo).get("recipient")!=name:
		var scope: Variant=state.memory.get("photoDisclosureScope");legacy={"recipient":name,"day":null,"scopeLabel":"旧记录：有限说明" if chapter_json_equal(scope,"limited") else ("旧记录：尚未讲全" if chapter_json_equal(scope,"partial") else "旧记录未注明范围")}
	var alive: Variant=_object(state.people.get("罗瑾")).get("alive");var failure: bool=alive is bool and alive==false or state.get("endingType")=="luo_death_failure"
	return {"entries":entries,"legacyPhoto27":legacy_photo,"legacy":legacy,"invalid":invalid,"failure":failure,"terminal":failure or js_truthy(state.get("ended")) or state.get("phase")=="end","noRecipient":_object(state.get("fixedNodeStates",{}).get("disclose")).get("status")=="no_recipient"}

func disclosure_epilogue(has_evidence: bool=false) -> Array:
	var view:=disclosure_projection();var lines: Array=[]
	if view.legacyPhoto27!=null:
		lines.append("第34日，罗瑾曾把胶卷、秘密加印和暗室藏处告诉母亲。");lines.append("这段告知只说明母亲当时听见了这些事；不能据此推断其他家人也知情，也不表示母亲答应接手保存证据。")
	if view.invalid:
		lines.append("告知记录与结果包不一致；本页不据此判断此前是否有人知情，也不补写一次谈话。")
		if view.noRecipient:lines.append("这一回，他没能再向家里人说明更多。" if view.legacyPhoto27!=null else "这一回，他没有找到能够接话的家人。")
		return lines
	var scopes: Dictionary={"images_limited":"亲见影像与眼下顾虑的有限情况","ordinary_experience":"普通经历与眼下顾虑的有限情况","personal_unease":"自己仍不安、但尚未讲清事情的一点情况"}
	for entry in view.entries:lines.append("罗瑾曾向"+entry.recipient+"说过"+scopes.get(entry.scope,"记录中实际写明的有限情况")+"。")
	if view.legacy!=null:
		var scope: Variant=state.memory.get("photoDisclosureScope");lines.append("罗瑾曾向"+view.legacy.recipient+"说过"+("最低限度的情况" if chapter_json_equal(scope,"limited") else ("尚未讲全的一点情况" if chapter_json_equal(scope,"partial") else "范围未注明的一次情况"))+"。");lines.append("更早的告知情况未注明。")
	if not lines.is_empty():
		if view.noRecipient:lines.append("这一回，他没能再向家里人说明更多。")
		elif view.legacyPhoto27!=null and (not view.entries.is_empty() or view.legacy!=null):lines.append("其余告知仍只按各自记录的范围理解；不等于对方答应接手保存证据。")
		elif view.legacyPhoto27==null:lines.append("这些记录不公开照片数量与藏处，也不等于对方答应接手保存证据。")
		return lines
	if view.noRecipient:return ["这一回，他没有找到能够接话的家人。"]
	if has_evidence:return ["当前记录里没有可证的家人告知。不能据此断定从前无人知情，也不补写一次谈话。"]
	return []

func _chapter9_parent_2_deadline_apply(fact: Dictionary) -> bool:
	return p1_apply_fact(fact) if p1_fact_marked(fact) else _chapter7_parent_27_deadline_apply(fact)


func _chapter9_parent_2_deadline_validate_fact(fact: Dictionary) -> bool:
	return p1_validate_fact(fact) if p1_fact_marked(fact) else _chapter7_parent_27_deadline_validate_fact(fact)


func _chapter9_parent_2_later_event_eligible(event: Dictionary,plan: Dictionary) -> bool:
	if not _chapter6_parent_7_later_event_eligible(event,plan):return false
	if event.get("nodeId")!="firstPrint":return true
	var row: Dictionary=_object(_object(plan.get("rows")).get("罗瑾"))
	return not state.ended and event.get("actor")=="罗瑾" and understands("罗瑾") and can_work_later("罗瑾") and not row.is_empty() and not row.get("inactive",false) and row.get("outside",false) and row.get("type")=="photo" and state.photo.employed and state.photo.evidence>0


func _chapter9_parent_2_ordinary_pre_photo_effect_supported(effect: Dictionary) -> bool:
	if effect.get("type")=="knowledge_grant" and effect.get("fact") is Dictionary and p1_fact_marked(effect.fact):return true
	if effect.get("type")=="flag_set" and effect.get("flag") in ["p1DeliveryResult","p1QueueResult"]:return effect.get("value") is Dictionary and effect.value.get("revision")==P1_REV
	return _chapter7_parent_27_ordinary_pre_photo_effect_supported(effect)


func _chapter9_parent_2_ordinary_pre_photo_requirement(choice: Dictionary) -> Dictionary:
	if js_truthy(choice.get("uncleBoundary")):
		var required:=uncle_boundary_requirement(choice)
		if not required.met:return required
	return _chapter7_parent_3_ordinary_pre_photo_requirement(choice)

func bind_disclosure_records(focus: Dictionary) -> void:
	for event in focus.get("laterEvents",{}).values():
		if event.get("nodeId")=="disclose":event.disclosureRecordRevision=DISCLOSURE_REV;event.disclosureContextHadEvidence=state.photo.evidence>0

func disclosure_default_ready(event: Dictionary,plan: Dictionary) -> bool:
	var availability:=disclosure_availability(event,plan)
	if availability.ok:return true
	var rows: Dictionary=_object(plan.get("rows"));var anyone: bool=DISCLOSURE_ADULTS.any(func(n):return understands(n) and not js_truthy(_object(rows.get(n)).get("outside")) and not js_truthy(_object(rows.get(n)).get("inactive")))
	if not anyone:
		var packet:=queue_focus_packet([{"type":"node_resolve","node":"disclose","status":"no_recipient","fallback":"此刻没有合法披露对象，不生成谈话"}],"node:disclose:no-recipient-at-return","on_return","family");apply_ordinary_pre_photo_packet(packet)
	else:state.fixedNodeStates.disclose.fallback=availability.reason
	return false

const END_REVIEW_REV="r4-v9-b2-ending-intention-v1"

const END_REVIEW_KEY="r4v9EndingReview"

const END_INTENT_TEXT={"print":"当时的打算，是先留心真正经手的东西，争取将能够留下的留下。","organize":"当时的打算，是有了实际材料以后，先核清和整理。","conceal":"当时的打算，是宁可慢些，先顾收拾与存放。"}

func ending_intention_absent(reason: String) -> Dictionary:return {"reason":reason,"intention":null}

func ending_inspect_intention() -> Dictionary:
	var mode: Variant=_object(state.get("photo")).get("strategy")
	if mode not in ["print","organize","conceal"]:return ending_intention_absent("no_recognized_intention")
	var history: Variant=state.get("history");var ledger: Variant=_object(state.get("effectLedger")).get("appliedEffectIds")
	if not history is Array or not ledger is Array:return ending_intention_absent("missing_source_records")
	var records: Array=[]
	for item in history:
		var h: Dictionary=_object(item)
		if h.get("type")=="later-choice" and h.get("event") is String and h.event.ends_with(".node.deadline"):records.append(h)
	if records.size()!=1:return ending_intention_absent("missing_or_ambiguous_choice")
	var h: Dictionary=records[0];var raw_day: Variant=h.get("day")
	if not _whole_number(raw_day):return ending_intention_absent("choice_contract_mismatch")
	var day: int=int(raw_day)+1;var node: Dictionary=_object(_object(state.get("fixedNodeStates")).get("deadline"))
	if day<36 or day>49 or raw_day>state.day or h.get("choice")!=mode or h.event not in ["later.D"+str(day)+".home.node.deadline","later.D"+str(day)+".罗瑾.node.deadline"]:return ending_intention_absent("choice_contract_mismatch")
	if node.get("id")!="deadline" or node.get("status")!="resolved" or not chapter_json_equal(node.get("resolvedDay"),day):return ending_intention_absent("choice_not_resolved")
	var packet: String=str(state.seed)+":D"+str(day)+":"+h.event+":"+h.choice+":immediate"
	if ledger.count(packet)!=1:return ending_intention_absent("choice_not_uniquely_applied")
	return {"reason":"verified_chosen_intention","intention":{"day":day,"eventId":h.event,"choiceId":h.choice,"packetId":packet,"text":END_INTENT_TEXT[mode]}}

func ending_current_review() -> Variant:
	var focus: Dictionary=_object(state.get("focus"));var mark: Dictionary=_object(focus.get(END_REVIEW_KEY))
	if not chapter_json_equal(state.get("saveVersion"),24) or not chapter_json_equal(state.get("day"),48) or not js_truthy(state.get("ended")) or state.get("phase")!="end" or not js_truthy(_object(state.people.get("罗瑾")).get("alive")) or not chapter_json_equal(focus.get("day"),48) or mark.get("revision")!=END_REVIEW_REV or not chapter_json_equal(mark.get("day"),48):return null
	var checked:=ending_inspect_intention();var a: Variant=mark.get("intention");var b: Variant=checked.intention
	var matches: bool=js_truthy(a) and js_truthy(b)
	if matches:
		for key in ["day","eventId","choiceId","packetId","text"]:
			if not chapter_json_equal(_object(a).get(key),_object(b).get(key)):matches=false
	return {"intention":a if matches else null}

var ending_text_bank: Dictionary={}

func ending_photo_projection() -> Dictionary:
	if ending_text_bank.is_empty():ending_text_bank=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_nine_ending_text.json"))
	var photo: Dictionary=state.photo;var selected: Variant=photo.album.selected;var transferred: Variant=photo.transferCount;var prints: Variant=photo.prints
	var tier: String="failure" if not js_truthy(_object(state.people.get("罗瑾")).get("alive")) else ("complete" if prints>=30 and selected>=16 and transferred>=16 else ("core" if selected>=16 and transferred>=16 else ("partial" if transferred>0 else "lost")))
	var out: Dictionary=ending_text_bank.base[tier].duplicate(true);out.text=out.text.replace("{count}",JS_JSON.encode(transferred))
	if tier=="failure":return out
	var strategy: Variant=photo.get("strategy");var focus: Dictionary=_object(state.get("focus"))
	if focus.get("webM4EndReadingRevision")=="WebM4-D45D49-v1" and _whole_number(focus.get("day")) and focus.day>=44 and focus.day<=48 and chapter_json_equal(state.get("day"),48):
		var key: String=tier+("_more" if prints>transferred else "_all") if tier=="complete" else tier+("_all" if chapter_json_equal(prints,transferred) else "_more")
		if tier=="lost":key="lost_unseen" if not js_truthy(photo.get("evidence")) else ("lost_unprinted" if not js_truthy(prints) else ("lost_unselected" if chapter_json_equal(selected,0) else "lost_selected"))
		out.text=ending_text_bank.modern[key].replace("{count}",JS_JSON.encode(transferred))
	if strategy in ["print","organize","conceal"] and ending_current_review()==null:out.text+=" "+ending_text_bank.suffix[strategy]
	return out

func prepare_c9_transfer_numbers(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	if not js_truthy(choice.get("photoTransfer")):return true
	if js_truthy(_object(event.get("r19PhotoTransfer")).get("early")) or state.day<44 or state.day>48:fail_contract("C9_TRANSFER_SCOPE","只核第45至49日普通转移数值。");return false
	var requirement:=photo_transfer_requirement()
	if not requirement.met:fail_contract("PHOTO_TRANSFER_REQUIREMENT",requirement.reason);return false
	var p: Dictionary=state.photo;var large: bool=choice.photoTransfer.size=="more";var before: Dictionary={}
	for person in PEOPLE:before[person]={"spirit":state.people[person].spirit,"spiritMax":state.people[person].get("spiritMax",10)}
	var available: float=maxf(0,minf(p.album.selected,p.prints)-p.transferCount)
	var chance: float=clampf((0.60 if large else 0.82)+(0.08 if route_use_by_luo() else 0.0)+(0.04 if state.people["罗瑾"].spirit>=7 else 0.0)-p.attention*0.035,0.30,0.94)
	var roll:=random_value();var amount: float=minf(16 if large else 8,available) if roll<chance else 0
	var record: Dictionary={"contract":PHOTO_END_CONTRACT,"event":event.id,"day":state.day,"amount":amount,"roll":roll,"chance":chance,"applied":false,"location":PHOTO_END_LOCATION};focus.photoTransferReceipt=record
	choice.immediateEffects=choice.photoTransfer.finish.duplicate(true)+[{"type":"photo_progress","op":"transferred_delta","value":amount,"contract":PHOTO_END_CONTRACT},{"type":"photo_progress","op":"attention_delta","value":0 if amount else -1},{"type":"character_spirit","target":"罗瑾","amount":-2 if large else -1},{"type":"flag_set","flag":"closure_method","value":"carried_to_shelter" if amount else "retreated_with_photos"}]
	if not focus.has("riskAudits"):focus.riskAudits=[]
	var audits: Array=focus.riskAudits.filter(func(a):return a.event==event.id and a.choice==choice.id and a.kind=="photo-end")
	if audits.is_empty():
		focus.riskAudits.append({"kind":"photo-end","event":event.id,"choice":choice.id,"day":state.day+1,"before":before,"contract":PHOTO_END_CONTRACT,"revision":PHOTO_END_CONTRACT,"riskRevision":"legacy-spirit-coupled-v1","intervals":{"chance":chance,"amount":amount},"locked":record.duplicate(true)});audits=[focus.riskAudits[-1]]
	var book:=spirit_book()
	if not book.has("riskAudits"):book.riskAudits=[]
	var audit: Dictionary=audits[0]
	if not book.riskAudits.any(func(a):return a.event==event.id and a.choice==choice.id and a.kind=="photo-end" and a.day==audit.day):book.riskAudits.append(audit.duplicate(true))
	var mark: Dictionary=_object(event.get("r19PhotoTransfer"));var next: float=amount
	if not mark.is_empty():
		var bonus: float=0.15 if mark.get("mode")=="conceal" else (0.04 if mark.get("mode")=="organize" else 0.0)
		if next==0 and bonus>0 and roll<minf(0.98,chance+bonus):next=minf(16 if large else 8,available)
		if not p.has("r19"):p.r19={}
		p.r19.transferActions=p.r19.get("transferActions",0)+1
	if p.strategy=="organize" and next==0 and available>0 and roll<minf(0.97,chance+0.08):next=minf(16 if large else 8,available)
	record.amount=next
	for effect in choice.immediateEffects:
		if effect.get("type")=="photo_progress" and effect.get("op")=="transferred_delta":effect.value=next;break
	return true

var c9_transfer_prose: Dictionary={}

func prepare_c9_transfer(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	if not _chapter9_parent_8_prepare_c9_transfer(focus,event,choice):return false
	append_c9_p1_context(focus,event,choice)
	return true

func _chapter9_parent_7_make_pre_photo_plan(day: int=-1) -> Dictionary:
	if day<0:day=int(state.day)
	if day<38:return _chapter7_parent_18_make_pre_photo_plan(day)
	if day<10 or day>43:
		fail_contract("LATER_PLAN_SCOPE","当前测试支持第11至44日、无远行的日程模型。");return {}
	if not process_pre_photo_story_morning():fail_contract("STORY_MORNING_PENDING","此剧情晨间结果尚未迁移。");return {}
	var date: int=day+1;var rows: Dictionary={};var adults: Array=PEOPLE.slice(1)
	for person in PEOPLE:rows[person]=_work_row(person,"留在棚里，处理手边的家事")
	var keys=JSON.parse_string(FileAccess.get_file_as_string("res://data/late_day_keys.json"));var key: String=keys[str(date)]
	if date==13 and state.memory.get("burialAccepted",false):key="burialPrepare"
	if date==14 and state.memory.get("burialAccepted",false):key="burial"
	var primary: String="罗瑾" if key=="burial" else ("母亲" if key=="register" else ("安仁叔叔" if key=="inquiry" else ("罗瑾" if key in ["apprentice","oldphoto","materials"] and state.photo.employed else "home")))
	var balanced: bool=state.balanceVersion=="I2f"
	var yields: Dictionary={"母亲":{"rice":3 if balanced else 2},"外祖父":{"wood":5 if balanced else 3},"安仁叔叔":{"rice":3 if balanced else 2}}
	var worker: String=adults[(date-11)%3];var urgent:=false
	if balanced:
		var wood_need: bool=state.wood<=4 and can_work_later("外祖父");var food_need: bool=state.rice<=2
		var available: Array=["母亲","安仁叔叔"].filter(func(person):return can_work_later(person))
		var food_worker: String=available[date%2] if available.size()>date%2 else (available[0] if not available.is_empty() else "")
		if wood_need and (not food_need or float(state.wood)/2<=state.rice or food_worker==""):worker="外祖父";urgent=true
		elif food_need and food_worker!="":worker=food_worker;urgent=true
		if state.water<=1 and not can_work_later("罗瑾"):
			if not can_work_later(worker):
				for adult in adults:
					if can_work_later(adult):worker=adult;break
			if can_work_later(worker):urgent=true
	if date%4!=0 or urgent:
		rows[worker]=_work_row(worker,{"母亲":"到已问过的救济点排队","外祖父":"到附近收拢旧木料","安仁叔叔":"到委员会相关差事处做杂务"}[worker],{"母亲":"relief","外祖父":"wood","安仁叔叔":"committee"}[worker],true,yields[worker].duplicate(true))
		if urgent:rows[worker].reason="resource-need"
	if primary=="母亲":rows["母亲"]=_work_row("母亲","到登记处外问清手续，回程到已问过的救济处","registration",true,{"rice":3,"water":2});rows["母亲"].registrationProtocol="inquiry-I3e-4b"
	if primary=="安仁叔叔":rows["安仁叔叔"]=_work_row("安仁叔叔","办过差事以后，沿熟悉的路回来","committee",true,{"rice":2})
	if key=="burial":rows["罗瑾"]=_work_row("罗瑾","跟着已经问清的队伍做收殓帮手","burial",true,{})
	if state.photo.employed and date>=23 and date%5!=0:rows["罗瑾"]=_work_row("罗瑾","到照相馆做杂活，协助师傅","photo",true,{})
	if state.water<=2:
		var return_water: bool=balanced and not current_weather().get("severe",false) and rows["罗瑾"].type=="photo" and adults.any(func(person):return rows[person].outside and can_work_later(person))
		if not return_water:rows["罗瑾"]=_work_row("罗瑾","存水不多，今天先沿认过的近路取水","water",true,{"water":(4 if tool_available("bucket") else (3 if tool_available("canteen") else 2)) if balanced else 2})
	if key=="newyear":rows["罗瑾"]=_work_row("罗瑾","留在棚里，把新一年的日期记下")
	if date==13 and state.memory.get("burialAccepted",false):rows["罗瑾"]=_work_row("罗瑾","留在棚里，核清跟队的规矩和实际工具")
	var node_id: Variant=null
	if date==43 and (not can_work_later("安仁叔叔") or chapter_five_node_done(state.fixedNodeStates.warning)):
		state.fixedNodeStates.warning.status="unwarned";state.fixedNodeStates.warning.fallback="安仁当日不可用"
	var priority: Array=["warning","discover","firstPrint"] if date==43 else (["deadline"] if date==36 else ["names","sources","employ","discover","trial","firstPrint","deadline"])
	for id in priority:
		var node: Dictionary=state.fixedNodeStates[id]
		if date<node.due or chapter_five_node_done(node):continue
		var eligible: bool=understands("罗瑾")
		if id=="warning":eligible=date==43 and can_work_later("安仁叔叔")
		elif id=="trial":eligible=date==node.due and state.photo.employed and state.photo.evidence>0 and can_work_later("罗瑾")
		elif id in ["discover","firstPrint"]:eligible=can_work_later("罗瑾") and state.photo.employed and (id=="discover" or state.photo.evidence>0)
		if eligible:node_id=id;break
	if node_id in ["discover","trial","firstPrint"]:
		rows["罗瑾"]=_work_row("罗瑾","到照相馆；今天有一件仍需亲自面对的事","photo",true,{});primary="罗瑾"
	elif node_id=="warning":primary="安仁叔叔";rows[primary]=_work_row(primary,"沿自己办差走过的路线回棚","committee",true,{"rice":2})
	elif node_id!=null:
		rows["罗瑾"]=_work_row("罗瑾","留在棚里，处理今天需要说清的事");primary="home"
	for person in PEOPLE:
		var p: Dictionary=state.people[person];var row: Dictionary=rows[person]
		if not p.alive or p.away or p.get("permanentLost",false) or p.get("detainedUntil")!=null:row.inactive=true;row.outside=false;row.base={};row.label=person_presence_label(person)
		elif row.outside and (not can_work_later(person) or (current_weather().get("severe",false) and (not tool_available("umbrella") or current_weather().id in ["blizzard","hail"]))):
			row.outside=false;row.base={};row.type="home";row.label="天气不宜赶路，今天留在棚里" if can_work_later(person) else "身体不适，今天留在棚里"
	if node_id in ["discover","trial","firstPrint","warning"] and not rows[primary].outside:
		state.fixedNodeStates[node_id].fallback="当日无法到达地点，不计合适日";node_id=null
	var search: Dictionary=_object(_object(state.expedition.get("active")).get("search"))
	if search.get("day")==day and search.get("status")=="planned":
		if node_id!=null:fail_contract("SEARCH_NODE_CONFLICT","寻找不能挤占已到期剧情节点");return {}
		if search.get("mode")=="luo":rows["罗瑾"]=_work_row("罗瑾","沿约好的路线寻找家人；今天不做普通差事","search",true,{});primary="罗瑾"
		else:rows["罗瑾"]=_work_row("罗瑾","留在棚边，把家人的衣着和约定去处说清");primary="home"
		key="expeditionSearch"
	if plan_pigeon_pickup(day,node_id,key=="expeditionSearch"):rows["罗瑾"]=_work_row("罗瑾","按核对过的纸条取物，今天不做普通差事","pigeonPickup",true,{});primary="罗瑾";key="pigeonPickup"
	if balanced and state.water<=2 and not (rows["罗瑾"].type=="water" and rows["罗瑾"].outside) and not current_weather().get("severe",false):
		for adult in adults:
			if rows[adult].outside and not rows[adult].get("inactive",false) and can_work_later(adult):
				if rows[adult].base.get("water",0)<2:rows[adult].base.water=2;rows[adult].label+="，回程沿认过的近路取少量水"
				break
	for person in PEOPLE:
		var reason:=character_rest_reason(person)
		if reason!="" and not rows[person].get("inactive",false):rows[person].outside=false;rows[person].base={};rows[person].type="home";rows[person].label=reason
	var targets: Array=PEOPLE.filter(func(person):return rows[person].outside and not rows[person].get("inactive",false))
	if PEOPLE.any(func(person):return not rows[person].outside and not rows[person].get("inactive",false)):targets.append("home")
	if primary not in targets:primary="home" if "home" in targets else (targets[0] if not targets.is_empty() else "")
	if node_id!=null:
		var node: Dictionary=state.fixedNodeStates[node_id]
		if not node.eligibleDays.any(func(value):return value==date):node.eligibleDays.append(date)
		node.fallback=null
	if key in ["pigeonPickup","expeditionSearch"]:targets=[primary]
	var result: Dictionary={"day":day,"rows":rows,"targets":targets,"primary":primary,"nodeId":node_id,"key":key,"photoWorkRules":"I2b-5a","reason":"固定节点优先，其次工作节奏、需求及可用性"}

	apply_r18_work_plan(result)
	return result

func _chapter9_parent_7_process_pre_photo_story_morning() -> bool:
	if state.day<=37:return _chapter7_parent_18_process_pre_photo_story_morning()
	if state.day<10 or state.ended or not state.people["罗瑾"].alive:return true
	if state.day>44:return false
	var initial=JSON.parse_string(FileAccess.get_file_as_string("res://data/story_initial_state.json"))
	if not state.has("fixedNodeStates"):state.fixedNodeStates={}
	for id in initial.fixedNodeStates:
		if not state.fixedNodeStates.has(id):state.fixedNodeStates[id]=initial.fixedNodeStates[id].duplicate(true)
	for key in ["pendingMorningPackets","storyMorningDays","knowledgeFacts"]:
		if not state.has(key):state[key]=[]
	var date: int=int(state.day)+1
	if state.storyMorningDays.any(func(value):return value==date):return true
	if state.pendingMorningPackets.any(func(packet):return packet.get("scheduledDay",INF)<=state.day and packet.get("status")=="pending"):return false
	if date>=22 and not state.photo.employed and not chapter_five_node_done(state.fixedNodeStates.employ) and not understands("罗瑾") and ["母亲","安仁叔叔","外祖父"].any(func(person):return understands(person)) and not js_truthy(state.memory.get("employment_offer_pending")):
		if not state.has("storySystemPackets"):state.storySystemPackets=[]
		var id: String=state.seed+":D"+str(date)+":system:employment-offer-pending"
		var found: Array=state.storySystemPackets.filter(func(packet):return packet.id==id)
		var packet: Dictionary={"id":id,"timing":"next_morning","subjectId":"family","effects":[{"type":"flag_set","flag":"employment_offer_pending","value":true}],"status":"pending"} if found.is_empty() else found[0]
		if found.is_empty():state.storySystemPackets.append(packet)
		apply_ordinary_pre_photo_packet(packet)
		state.morningResults.append("照相馆帮工的消息先由在场的大人接下；罗瑾还不能听清规矩，今天不算已经上工。")
	if date>=36 and not state.photo.deadline.announced:
		family_system_packet([{"type":"photo_progress","op":"deadline_transition","value":"announced"}],"deadline-announced")
		state.morningResults.append("照相馆传来店铺腾空的期限；到一月三十日，暗房便不能再照常使用。")
		deadline_notice_delivery()
	if relay_deadline_notice():state.morningResults.append("先前送来的店铺期限，如今也向罗瑾说明了；这条消息不涉及他私下有没有留下照片。")
	if date>=44 and not state.photo.deadline.urgent:
		family_system_packet([{"type":"photo_progress","op":"deadline_transition","value":"urgent"}],"deadline-urgent")
		state.morningResults.append("店里又催了一次清理。还要留在暗房处理的东西，不能再照先前那样等下去。")
	if date>43 and not chapter_five_node_done(state.fixedNodeStates.warning):state.fixedNodeStates.warning.status="unwarned";state.fixedNodeStates.warning.fallback="预警当日未得到合法返家转述"
	if contract_error!="":return false
	if date>state.fixedNodeStates.trial.due and not chapter_five_node_done(state.fixedNodeStates.trial):
		state.fixedNodeStates.trial.status="skipped";state.fixedNodeStates.trial.fallback="当日试印未执行，不顺延"
	for id in ["names","sources","discover","firstPrint","disclose"]:
		var node: Dictionary=state.fixedNodeStates[id]
		if date>node.due and not chapter_five_node_done(node) and not node.eligibleDays.is_empty():state.morningResults.append({"names":"前些天记下的寻人消息，仍有来处没问清。","sources":"几张纸上的听说与亲见，还需要分开放。","discover":"罗瑾惦记着店里的暗房；有机会时，还想亲自留意那里的情形。","firstPrint":"暗房里那一点空隙还没有用上；罗瑾仍在考虑自己能做到哪一步。","disclose":"罗瑾仍想找一个家人在旁的时候，把能说的部分说清。"}[id])
	process_mother_care_morning()
	process_uncle_boundary_morning()
	process_mother_crisis_morning()
	process_uncle_crisis_morning()
	process_r18_home_morning()
	state.storyMorningDays.append(state.day+1)
	return true


func _chapter9_parent_8_prepare_c9_transfer(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	if not js_truthy(choice.get("photoTransfer")):return true
	if not prepare_c9_transfer_numbers(focus,event,choice):return false
	var record: Dictionary=focus.photoTransferReceipt;var audits: Array=focus.riskAudits.filter(func(a):return a.kind=="photo-end" and a.event==event.id and a.choice==choice.id);var original: Variant=audits[0].locked.amount;var mode: Variant=_object(event.get("r19PhotoTransfer")).get("mode");var outcome: String="direct" if original>0 else "retreat"
	if original==0 and record.amount>0:outcome="r19" if mode=="conceal" and record.roll<minf(0.98,record.chance+0.15) or mode=="organize" and record.roll<minf(0.98,record.chance+0.04) else "r23"
	var known: bool=state.knowledgeFacts.any(func(k):return k.get("id")=="deadline.notice" and "罗瑾" in k.get("knownBy",[]));var p: Dictionary=state.photo
	var key: String=":".join(["modern" if focus.get("webM4EndReadingRevision")=="WebM4-D45D49-v1" else "old",outcome,"one" if chapter_json_equal(record.amount,1) else "many","remaining" if p.prints-p.transferCount-record.amount>0 else "all","first" if chapter_json_equal(p.transferCount,0) else "again","final" if chapter_json_equal(focus.day,48) else "ordinary","known" if known else "unknown"])
	if c9_transfer_prose.is_empty():c9_transfer_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_nine_transfer_prose.json"))
	if not c9_transfer_prose.has(key):fail_contract("C9_TRANSFER_PROSE","缺少已核定转移结果正文："+key);return false
	var prose: Dictionary=c9_transfer_prose[key];choice.closures={"default":prose.closure.replace("{amount}",JS_JSON.encode(record.amount))};choice.diaries={"default":prose.diary.replace("{amount}",JS_JSON.encode(record.amount))};return true


const P1_CONTEXT_REV="r4-v8-b3-p1-context-v1"

const P1_CONTEXT_KEY="r4v8P1Context"

var p1_context_text: Dictionary={}

func p1_context_no(reason: String) -> Dictionary:return {"usable":false,"reason":reason,"photoAssistance":false}

func p1_context_inspect() -> Dictionary:
	var result: Dictionary=_object(state.memory.get("p1DeliveryResult"))
	if result.is_empty():return p1_context_no("not_occurred")
	var prior_error:=contract_error;var prior_message:=contract_message;var valid:=p1_validate_state();contract_error=prior_error;contract_message=prior_message
	if not valid:return p1_context_no("invalid_provenance")
	var projection:=p1_delivery_projection("罗瑾")
	if result.get("revision")!=P1_REV or result.get("status") not in ["ordinary_delivery_confirmed","ordinary_delivery_unconfirmed","route_only","self_only"] or projection.get("status")!=result.status or not chapter_json_equal(projection.get("occurrenceDay"),result.occurrenceDay) or projection.get("photoAssistance")!=false:return p1_context_no("unsupported_result")
	if projection.get("known")!=true:return p1_context_no("not_told_to_luo")
	var facts: Array=state.get("knowledgeFacts",[]).filter(func(k):return k.get("contentId")==P1_CONTENT and k.get("contractRevision")==P1_REV and k.get("eventId")==result.eventId and k.get("scope")==result.status and k.get("mode")=="told" and k.get("source")=="安仁叔叔" and k.get("knownBy",[]).size()==1 and k.knownBy[0]=="罗瑾" and k.get("originPacketId")==result.sourcePacketId)
	var ledger: Array=_object(state.get("effectLedger")).get("appliedEffectIds",[])
	if facts.size()!=1 or facts[0].sourcePacketId not in ledger or facts[0].originPacketId not in ledger:return p1_context_no("missing_personal_receipt")
	if not understands("罗瑾"):return p1_context_no("luo_cannot_understand")
	return {"usable":true,"status":result.status,"occurrenceDay":result.occurrenceDay,"originEventId":result.eventId,"originPacketId":result.sourcePacketId,"knowledgeFactId":facts[0].id,"sourceAvailable":projection.get("sourceAvailable")==true,"photoAssistance":false}

func p1_context_supported(focus: Dictionary,event: Dictionary) -> bool:
	if not chapter_json_equal(focus.get("day"),state.day) or not (_whole_number(focus.get("day")) and int(focus.day) in [44,48]) or state.ended or focus.get("webM4EndReadingRevision")!="WebM4-D45D49-v1" or not js_truthy(_object(focus.get("plan")).get("chapter9")) or event.get("actor")!="罗瑾" or _object(_object(focus.get("plan")).get("eventIds")).get(event.get("target"))!=event.get("id") or "罗瑾" not in event.get("participants",[]) or not understands("罗瑾"):return false
	if ["motherCrisis","uncleCrisis","neighbourhood","neighbourParcel","expeditionSearch","pigeonPickup"].any(func(k):return js_truthy(event.get(k))):return false
	if event.get("target")=="罗瑾":return event.get("photoEnd")==true or event.get("photoMid")==true or event.get("nodeId")=="ending"
	return chapter_json_equal(focus.day,48) and event.get("target")=="home" and event.get("nodeId")=="ending"

func p1_context_prose(projection: Dictionary,day: int) -> Dictionary:
	if p1_context_text.is_empty():p1_context_text=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_nine_p1_context_text.json"))
	return p1_context_text[projection.status+":"+("available" if projection.sourceAvailable else "unavailable")+":"+str(day)].duplicate(true)

func bind_c9_p1_context(focus: Dictionary) -> void:
	var projection:=p1_context_inspect()
	if not projection.usable:return
	for target in _object(focus.get("plan")).get("targets",[]):
		var event: Dictionary=_object(focus.get("laterEvents",{}).get(focus.plan.eventIds.get(target)))
		if not p1_context_supported(focus,event) or js_truthy(event.get(P1_CONTEXT_KEY)) or not event.get("intro") is String or not event.get("choices") is Array:continue
		var prose:=p1_context_prose(projection,int(focus.day)+1);event[P1_CONTEXT_KEY]={"revision":P1_CONTEXT_REV,"day":focus.day,"eventId":event.id,"projection":projection.duplicate(true),"introParagraph":prose.intro,"hintSuffix":prose.hint};event.intro+="\n\n"+prose.intro
		for choice in event.choices:
			if choice.get("hint") is String:choice.hint+=" "+prose.hint

func append_c9_p1_context(focus: Dictionary,event: Dictionary,choice: Dictionary) -> void:
	var mark: Dictionary=_object(event.get(P1_CONTEXT_KEY))
	if not p1_context_supported(focus,event) or mark.get("revision")!=P1_CONTEXT_REV or not chapter_json_equal(mark.get("day"),focus.day) or mark.get("eventId")!=event.id or focus.get("selected")!=event.target or focus.get("eventId")!=event.id or focus.get("choiceIndex")!=null or not event.choices.any(func(c):return is_same(c,choice)) or not _object(choice.get("closures")).get("default") is String or not _object(choice.get("diaries")).get("default") is String:return
	var projection:=p1_context_inspect();var old: Dictionary=_object(mark.get("projection"))
	if not projection.usable:return
	for key in ["originEventId","originPacketId","knowledgeFactId","status"]:
		if projection.get(key)!=old.get(key):return
	var prose:=p1_context_prose(projection,int(focus.day)+1);mark.decision={"choiceId":choice.id,"projection":projection.duplicate(true),"closureParagraph":prose.closure,"diaryParagraph":prose.diary}
	if not choice.closures.default.ends_with("\n\n"+prose.closure):choice.closures.default+="\n\n"+prose.closure
	if not choice.diaries.default.ends_with("\n\n"+prose.diary):choice.diaries.default+="\n\n"+prose.diary

func _chapter9_parent_9_apply_chapter_maintenance(focus: Dictionary) -> void:
	if state.day<38:_chapter7_parent_19_apply_chapter_maintenance(focus);return
	var current: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get("home")))
	if current.is_empty() or state.wood<=0:return
	var low: bool=current.id.ends_with(".maintenance");var fresh: bool=(current.has("neighbourhood") and current.neighbourhood.get("stage")==1 and not js_truthy(current.neighbourhood.get("prior"))) or (current.has("neighbourParcel") and current.neighbourParcel.get("stage")==1 and not js_truthy(current.neighbourParcel.get("prior"))) or current.id.begins_with("neighbour.day.R2b.")
	if not low and not (state.shelter<21 and fresh):return
	var raw:=make_pre_photo_condition_home(focus)
	if raw.get("conditionKind")!="maintenance":return
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].get("outside",false));var adults: Array=home.filter(func(person):return person!="罗瑾");var actor: String=adults[0] if not adults.is_empty() else "罗瑾"
	var event: Dictionary=raw.duplicate(true);event.later=true;event.historyClass="情境演绎；白天家庭维护为游戏安排，不是历史日期事实";event.id="later.D"+str(int(state.day)+1)+".home."+raw.id;event.target="home";event.actor=actor;event.participants=home.duplicate();event.homeParticipants=home.duplicate()
	if not low:focus.dayMaintenanceDisplaced={"id":current.id,"title":current.title,"reason":"shelter_below_21_with_wood","freshNeighbour":true}
	focus.laterEvents[event.id]=event;focus.plan.eventIds.home=event.id


func _chapter9_parent_9_make_chapter_home_base(focus: Dictionary) -> Dictionary:
	if state.day<38:return _chapter7_parent_19_make_chapter_home_base(focus)
	if state.day>43 or "home" not in focus.plan.targets:return {}
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].outside)
	if home.is_empty():return {}
	if home.any(func(person):return not focus_fit(person)):return make_pre_photo_care_event(focus)
	var adults: Array=home.filter(func(person):return person!="罗瑾");var speaker: String=adults[0] if not adults.is_empty() else "罗瑾"
	var event: Dictionary={};var raw: Dictionary={}
	if focus.plan.primary=="home":
		if later_scene_shells.is_empty():later_scene_shells=JSON.parse_string(FileAccess.get_file_as_string("res://data/later_scene_shells.json"))
		var key: String=focus.plan.key
		if key in ["apprentice","oldphoto","materials","register","inquiry"]:key="papers"
		if key=="shelter" and state.shelter>=50:key="papers"
		event=later_scene_shells.get(key,later_scene_shells.papers).duplicate(true)
	else:
		raw=make_pre_photo_condition_home(focus);event=raw.duplicate(true)
	if event.is_empty():return {}
	var suffix: String=event.id;var recipients: Array=["母亲","安仁叔叔","外祖父"].filter(func(person):return person in home and understands(person))
	event.id="later.D"+str(int(state.day)+1)+".home."+suffix;event.target="home";event.later=true;event.actor=speaker;event.participants=[speaker];event.homeParticipants=[speaker];event.recipient=null if recipients.is_empty() else recipients[0];event.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":state.photo.evidence,"photoPrints":state.photo.prints};event.historyClass="F：情境演绎；照片节点与期限为G，非罗家逐日实录";event.chapter="I2b-8"
	if home.any(func(person):return not can_work_later(person)):
		var fallback:=make_pre_photo_condition_home(focus);var old_id: String=event.id
		if fallback.is_empty():return {}
		for field in fallback:event[field]=fallback[field]
		event.id=old_id;event.target="home";event.later=true;event.chapter="I2b-8"
		for choice in event.choices:choice.later=true
		return event
	if chapter_eight_home_prose.is_empty():chapter_eight_home_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_eight_home_prose.json"))
	var mask:=0
	for person in home:mask|=1<<PEOPLE.find(person)
	var key: String=JSON.stringify([int(state.day),mask,2 if state.shelter>=50 else (0 if state.shelter<=20 else 1),tool_available("bandage"),state.get("knowledgeFacts",[]).any(func(fact):return fact.get("id")=="deadline.notice" and speaker in fact.get("knownBy",[]))])
	if not chapter_eight_home_prose.variants.has(key):return {}
	var variant: Dictionary=chapter_eight_home_prose.variants[key]
	if variant.has("fallback"):
		var fallback:=make_pre_photo_condition_home(focus);var id: String=event.id
		if fallback.is_empty():return {}
		for field in fallback:event[field]=fallback[field]
		event.id=id;event.target="home";event.later=true;event.chapter="I2b-8"
		for choice in event.choices:choice.later=true
	else:
		var layer: Dictionary=decode_home_content(chapter_eight_home_prose.events[variant.event],chapter_eight_home_prose)
		for field in layer:event[field]=layer[field]
		event.erase("conditionKind")
	return event


func _chapter9_parent_9_make_pre_photo_care_event(focus: Dictionary,base_only: bool=false) -> Dictionary:
	if state.day<38:return _chapter7_parent_19_make_pre_photo_care_event(focus,base_only)
	if state.day<10 or state.day>43 or "home" not in focus.plan.targets:return {}
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].get("outside",false));var sick: Array=home.filter(func(person):return not focus_fit(person))
	if sick.is_empty():return {}
	sick.sort_custom(func(a,b):return PEOPLE.find(a)<PEOPLE.find(b) if state.people[a].health==state.people[b].health else state.people[a].health<state.people[b].health)
	var patient: String=sick[0];var others: Array=home.filter(func(person):return person!="罗瑾" and understands(person));var speakers: Array=home.filter(func(person):return understands(person));var adult_home: Array=home.filter(func(person):return person!="罗瑾");var actor: String=adult_home[0] if not adult_home.is_empty() else "罗瑾"
	var event: Dictionary={};var suffix: String="fallback.d"+str(int(state.day)+1)+".home.care"
	if focus.plan.primary=="home":
		if later_scene_shells.is_empty():later_scene_shells=JSON.parse_string(FileAccess.get_file_as_string("res://data/later_scene_shells.json"))
		var key: String=focus.plan.key
		if key in ["apprentice","oldphoto","materials","register","inquiry"]:key="papers"
		if key=="burial":key="returner"
		if key=="shelter" and state.shelter>=50:key="papers"
		event=later_scene_shells.get(key,later_scene_shells.papers).duplicate(true);suffix=event.id
	var recipients: Array=["母亲","安仁叔叔","外祖父"].filter(func(person):return person in home and understands(person))
	event.id="later.D"+str(int(state.day)+1)+".home."+suffix;event.title="";event.intro="";event.later=true;event.historyClass="F：情境演绎；照片节点与期限为G，非罗家逐日实录";event.target="home";event.actor=actor;event.participants=home.duplicate();event.homeParticipants=home.duplicate();event.recipient=null if recipients.is_empty() else recipients[0];event.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":state.photo.get("evidence",0),"photoPrints":state.photo.get("prints",0)};event.chapter="I2b-8";event.conditionKind="care"
	var repairers: Array=home.filter(func(person):return person!=patient and can_work_later(person))
	var raw_care:=pre_photo_raw_care_content(home,patient,repairers)
	if raw_care.is_empty():return {}
	for field in ["title","intro","choices"]:event[field]=raw_care[field]
	for choice in event.choices:choice.later=true
	if base_only:return event

	var offer:=pre_photo_recovery_offer(focus)
	if not offer.is_empty():
		event.id+=".exchange";event.actor=offer.actor;event.conditionKind="recovery"
		var medicine: bool=offer.item!=null;var name: String=TOOL_NAMES[offer.item] if medicine else "木料";var goods: String=name+"一份" if medicine else "能用的短木三份"
		var exchange: Dictionary={"id":"exchange","label":"用米粮"+str(int(offer.cost))+"份换"+goods,"hint":"米粮－"+str(int(offer.cost))+"；"+(name+"＋1，晚间另行用药，不当场治愈" if medicine else "木料＋3，不自动生火或修棚")+"。","requiresResources":{"rice":offer.cost},"immediateEffects":[{"type":"resource_delta","resource":"rice","amount":-offer.cost},{"type":"item_gain","item":offer.item} if medicine else {"type":"resource_delta","resource":"wood","amount":3}],"closures":{"default":""},"diaries":{"default":""}}
		event.choices=[exchange,event.choices[0],event.choices[1]]

	return event


func _chapter9_parent_9_make_pre_photo_condition_home(focus: Dictionary) -> Dictionary:
	if state.day<38:return _chapter7_parent_19_make_pre_photo_condition_home(focus)
	if state.day<10 or state.day>43:return {}
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].get("outside",false))
	if home.is_empty() or home.any(func(person):return not focus_fit(person)):return {}
	var mask:=0
	for person in home:mask|=1<<PEOPLE.find(person)
	var kind: String="weather" if current_weather().get("severe",false) else ("absence" if household_presence_mask()!=15 else ("maintenance" if state.shelter<41 and state.wood>0 else "home"))
	var prior: Array=[];var index:=0;var stock:=0;var gain:=0
	if kind in ["weather","maintenance"]:
		prior=state.history.filter(func(row):return row.get("day",state.day)<state.day and _object(row.get("readingVariant")).get("revision")=="R24-experience-polish-v1" and row.readingVariant.kind==kind)
		var last: Dictionary={}
		for row in prior:last[int(row.readingVariant.index)]=row.day
		var offset: int=RNG.hash_seed(state.seed+"|R24-experience-polish-v1|"+kind)%3;index=-1
		for step in range(3):
			var candidate: int=(offset+step)%3
			if not last.has(candidate):index=candidate;break
		if index<0:
			var candidates: Array=[0,1,2];candidates.sort_custom(func(a,b):return a<b if last[a]==last[b] else last[a]<last[b]);index=candidates[0]
		if kind=="weather":stock=(1 if state.wood>=1 else 0)+(2 if state.shelter>=50 else 0)+(4 if state.shelterItems.oilcloth else 0)
		else:
			var speakers: Array=home.filter(func(person):return person!="罗瑾");gain=formal_repair_gain(int(state.day),speakers[0] if not speakers.is_empty() else "罗瑾")
	else:
		prior=state.history.filter(func(row):return row.get("day",state.day)<state.day and _object(row.get("readingVariant")).get("group")=="shelter")
		index=(RNG.hash_seed(state.seed+":condition-story:shelter")+prior.size())%3
	if chapter_eight_condition_home_prose.is_empty():chapter_eight_condition_home_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_eight_condition_home.json"))
	var key:=JSON.stringify([int(state.day),mask,kind,index,stock,gain])
	if not chapter_eight_condition_home_prose.variants.has(key):return {}
	var event: Dictionary=decode_home_content(chapter_eight_condition_home_prose.events[chapter_eight_condition_home_prose.variants[key]],chapter_eight_condition_home_prose)
	event=_replace_content_token(event,"§WEATHER_NAME§",current_weather().name)
	if kind=="maintenance":
		var actor: String=event.get("actor","")
		if actor=="":
			var adults: Array=home.filter(func(n):return n!="罗瑾");actor=adults[0] if not adults.is_empty() else home[0]
		if not home.any(func(n):return n!=actor and can_work_later(n)):event.intro=event.intro.replace("还留在棚里的家人能搭手的，只接眼前这一段。","眼下能动手的人先顾自己做得到的地方，没有叫不在这里的人回来。")
	if event.has("readingVariant"):event.readingVariant.previous=null if prior.is_empty() else prior.back().day
	return event


func _chapter9_parent_9_make_pre_photo_outdoor_event(focus: Dictionary,target: String) -> Dictionary:
	if state.day<38:return _chapter7_parent_19_make_pre_photo_outdoor_event(focus,target)
	if state.day<10 or state.day>43 or target not in PEOPLE or target not in focus.plan.targets or (js_truthy(focus.plan.get("nodeId")) and target==focus.plan.primary):return {}
	var row: Dictionary=_object(focus.plan.rows.get(target));var type: String=row.get("type","")
	if not row.get("outside",false) or row.get("inactive",false) or not present(target):return {}
	if not ((target=="罗瑾" and type in ["water","burial","photo"]) or (target=="外祖父" and type=="wood") or (target=="母亲" and type in ["relief","registration"]) or (target=="安仁叔叔" and type=="committee")):return {}
	if type=="photo":
		var bank: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_eight_photo_ordinary.json"))
		var known: bool=state.get("knowledgeFacts",[]).any(func(k):return k.get("id")=="deadline.notice" and "罗瑾" in k.get("knownBy",[]))
		var ordinary_key: String=JSON.stringify([int(state.day)+1,js_truthy(state.photo.evidence),state.photo.prints>0,state.photo.album.selected>0,known,focus.plan.primary==target])
		if not bank.variants.has(ordinary_key):return {}
		var ordinary: Dictionary=decode_home_content(bank.events[bank.variants[ordinary_key]],bank)
		var receivers: Array=["母亲","安仁叔叔","外祖父"].filter(func(n):return present(n) and not focus.plan.rows[n].outside and understands(n))
		ordinary.recipient=null if receivers.is_empty() else receivers[0];ordinary.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":state.photo.evidence,"photoPrints":state.photo.prints};return ordinary
	var prior: Array=state.history.filter(func(history):return history.get("day",state.day)<state.day and _object(history.get("readingVariant")).get("group")=="water") if type=="water" else []
	var index: int=(RNG.hash_seed(state.seed+":condition-story:water")+prior.size())%3 if type=="water" else 0
	var previous: String="none" if prior.is_empty() else "many"
	if prior.size()==1:previous=prior[0].get("choice","") if prior[0].get("choice") in ["help","pole_help"] else "carry_home"
	var tool: String=state.memory.get("burialTool","none") if type=="burial" else "none"
	if tool not in ["shovel","rope"] or not tool_available(tool):tool="none"
	if chapter_eight_outdoor_prose.is_empty():chapter_eight_outdoor_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_eight_outdoor_prose.json"))
	var key:=JSON.stringify([int(state.day),target,type,index,state.water>=2 if type=="water" else false,tool_available("axe") if type=="wood" else false,tool,previous,type=="photo" and focus.plan.primary==target])
	if not chapter_eight_outdoor_prose.variants.has(key):return {}
	var event: Dictionary=decode_home_content(chapter_eight_outdoor_prose.events[chapter_eight_outdoor_prose.variants[key]],chapter_eight_outdoor_prose)
	var home: Array=PEOPLE.filter(func(person):return present(person) and not _object(focus.plan.rows.get(person)).get("outside",false))
	var recipients: Array=["母亲","安仁叔叔","外祖父"].filter(func(person):return person in home and understands(person))
	event.recipient=null if recipients.is_empty() else recipients[0]
	event.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":state.photo.get("evidence",0),"photoPrints":state.photo.get("prints",0)}
	if type=="water" and event.has("readingVariant"):
		event.readingVariant.previous=null if prior.is_empty() else prior.back().day
		event.readingVariant.narratorHere="罗瑾" in home
	return event


func _chapter9_parent_9_pre_photo_raw_care_content(home: Array,patient: String,repairers: Array) -> Dictionary:
	if state.day<38:return _chapter7_parent_19_pre_photo_raw_care_content(home,patient,repairers)
	var mask:=0
	for person in home:mask|=1<<PEOPLE.find(person)
	var worker: Variant=null;var gain:=0
	if state.shelter<41 and state.wood>0 and not repairers.is_empty():worker="外祖父" if "外祖父" in repairers else repairers[0];gain=formal_repair_gain(int(state.day),worker)
	if chapter_eight_care_raw_prose.is_empty():chapter_eight_care_raw_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_eight_care_raw_prose.json"))
	var key:=JSON.stringify([int(state.day),mask,patient,worker,state.water>0,gain])
	if not chapter_eight_care_raw_prose.variants.has(key):return {}
	var result: Dictionary=decode_home_content(chapter_eight_care_raw_prose.events[chapter_eight_care_raw_prose.variants[key]],chapter_eight_care_raw_prose)
	var description:=ailment_text(patient)
	return _replace_content_token(result,"§AILMENT_DESCRIPTION§",description if not description.is_empty() else "身上很不舒服")


func _chapter9_parent_9_pre_photo_recovery_offer(focus: Dictionary) -> Dictionary:
	if state.day<38:return _chapter7_parent_19_pre_photo_recovery_offer(focus)
	if state.balanceVersion!="I2f" or state.day<10 or state.day>43:return {}
	var block: int=int(floor(float(state.day-10)/5));var offset: int=RNG.hash_seed(state.seed+":recovery-offer:"+str(block))%5
	if (int(state.day)-10)%5!=offset:return {}
	var home: Array=PEOPLE.filter(func(person):return present(person) and not focus.plan.rows[person].get("outside",false));var actors: Array=home.filter(func(person):return can_work_later(person))
	if actors.is_empty():actors=home.filter(func(person):return understands(person))
	if actors.is_empty():return {}
	var sick: Array=home.filter(func(person):return state.ailments.get(person,{}).values().any(func(value):return value>=2))
	sick.sort_custom(func(a,b):return PEOPLE.find(a)<PEOPLE.find(b) if state.people[a].health==state.people[b].health else state.people[a].health<state.people[b].health)
	var item: Variant=null
	for person in sick:
		var types: Array=["cold","wound","nutrition"]
		types.sort_custom(func(a,b):return ["cold","wound","nutrition"].find(a)<["cold","wound","nutrition"].find(b) if state.ailments[person][a]==state.ailments[person][b] else state.ailments[person][a]>state.ailments[person][b])
		var candidate: String={"cold":"herbs","wound":"bandage","nutrition":"medkit"}[types[0]]
		if not tool_available(candidate) and not tool_available("medkit"):item=candidate;break
	if item==null and not (state.wood<=2 and not can_work_later("外祖父")):return {}
	return {"actor":actors[0],"kind":"medicine" if item!=null else "wood","item":item,"cost":2 if item!=null else 1,"day":state.day+1}


var chapter_nine_care_reader=preload("res://scripts/chapter_nine_care_prose.gd").new()

var chapter_nine_care_raw_prose: Dictionary={}

var chapter_nine_condition_home_prose: Dictionary={}

var chapter_nine_outdoor_prose: Dictionary={}

var chapter_nine_home_prose: Dictionary={}

var c9_final_nodes: Dictionary={}

func c9_photo_context_mode() -> String:
	var p: Dictionary=state.photo
	if not js_truthy(p.evidence):return "unseen"
	if not js_truthy(p.prints):return "seen"
	if p.transferCount>=p.prints:return "all"
	if p.transferCount>0:return "partial"
	return "selected" if p.album.selected>0 else "printed"

func make_c9_final_home_node(focus: Dictionary) -> Dictionary:
	var node: Variant=focus.plan.get("nodeId")
	if node not in ["disclose","ending"] or focus.plan.primary!="home" or state.day<46 or state.day>48:return {}
	var home:=0;var adults:=0
	for i in range(PEOPLE.size()):
		if present(PEOPLE[i]) and not focus.plan.rows[PEOPLE[i]].outside:home|=1<<i
		if i>0 and understands(PEOPLE[i]):adults|=1<<(i-1)
	var key: String=JSON.stringify([node,int(state.day),home,adults,understands("罗瑾"),c9_photo_context_mode(),js_truthy(state.photo.employed),state.knowledgeFacts.any(func(k):return k.get("id")=="deadline.notice" and "罗瑾" in k.get("knownBy",[]))])
	if c9_final_nodes.is_empty():c9_final_nodes=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_nine_final_nodes.json"))
	if not c9_final_nodes.variants.has(key):fail_contract("C9_FINAL_NODE_SCOPE","尚无这一家庭与照片状态的正式节点正文。");return {}
	var event: Dictionary=decode_home_content(c9_final_nodes.events[c9_final_nodes.variants[key]],c9_final_nodes)
	event.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":state.photo.evidence,"photoPrints":state.photo.prints}
	return event

var chapter_nine_photo_results: Dictionary={}

func prepare_chapter_nine_photo_choice(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	if not js_truthy(choice.get("photoBatch")):return true
	if state.day<44 or state.day>48 or focus.day!=state.day or focus.get("webM4EndReadingRevision")!="WebM4-D45D49-v1" or event.get("photoMid")!=true or event.get("actor")!="罗瑾" or event.get("target")!="罗瑾" or choice.photoBatch.get("contract")!=PHOTO_MID_CONTRACT or choice.photoBatch.get("kind") not in ["print","sort"] or choice.id not in ["small","more"] or choice.id!=choice.photoBatch.get("size"):fail_contract("C9_PHOTO_RESULT_SCOPE","该照片结果正文合同尚未原生接通。");return false
	var p: Dictionary=state.photo;var prints: float=p.prints;var selected: float=p.album.selected;var transferred: float=p.transferCount;var modern: bool=state.photoBalanceVersion=="I3";var strategy: String=p.strategy if p.strategy in ["print","organize","conceal"] else "steady";var kind: String=choice.photoBatch.kind
	if not prepare_photo_mid_numbers(focus,event,choice):return false
	var receipt: Dictionary=focus.photoBatchReceipt
	if chapter_nine_photo_results.is_empty():chapter_nine_photo_results=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_nine_photo_results.json"))
	var base_amount: Variant=focus.riskAudits.filter(func(a):return a.kind=="photo-mid" and a.event==event.id and a.choice==choice.id)[0].locked.amount
	var key: String=JSON.stringify([int(state.day)+1,event.id,strategy,kind,choice.id,mini(2,int(prints)),selected>0,prints-selected==1,transferred>0,transferred>=prints,modern,mini(2,int(receipt.amount)),receipt.roll>=receipt.chance,int(receipt.attention),mini(2,int(base_amount)),chapter_json_equal(base_amount,receipt.amount)])
	if not chapter_nine_photo_results.variants.has(key):fail_contract("C9_PHOTO_RESULT_KEY","当前照片结果正文组合尚未接入。");return false
	var pair: Array=chapter_nine_photo_results.variants[key];choice.closures={"default":chapter_nine_photo_results.strings[int(pair[0])].replace("{amount}",JS_JSON.encode(receipt.amount)).replace("{base_amount}",JS_JSON.encode(base_amount))};choice.diaries={"default":chapter_nine_photo_results.strings[int(pair[1])].replace("{amount}",JS_JSON.encode(receipt.amount)).replace("{base_amount}",JS_JSON.encode(base_amount))};return true

var c9_diary_bank: Dictionary={}

func load_c9_diary() -> void:
	if c9_diary_bank.is_empty():c9_diary_bank=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_nine_diary_prose.json"))

func finish_chapter_nine_diary(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	var date: int=int(focus.day)+1
	if date<45 or date>49 or not focus.plan.get("chapter9",false):return true
	if not focus.get("diaryAllowed",false) or state.ended:focus.chapterDiary=[];return true
	if focus.get("integrationReadingRevision")!="FINAL-INTEGRATION":fail_contract("C9_DIARY_SCOPE","只接当前正式接线版本日记。");return false
	load_c9_diary();var bank: Dictionary=c9_diary_bank;var here: Array=PEOPLE.filter(func(n):return present(n));var grown: Array=here.filter(func(n):return n!="罗瑾")
	var special: bool=["motherCrisis","uncleCrisis","motherCare","uncleBoundary","expeditionSearch","pigeonPickup","neighbourhood","neighbourParcel"].any(func(k):return js_truthy(event.get(k)))
	var web: bool=focus.get("webM4EndReadingRevision")=="WebM4-D45D49-v1" and not special
	var active: Array=grown.filter(func(n):return can_work_later(n));var heard: Array=grown.filter(func(n):return understands(n));var actor: Variant=active[0] if not active.is_empty() else (heard[0] if web and not heard.is_empty() else null)
	var mode: String=("work:" if can_work_later(actor) else "rest:")+actor if actor!=null else ("unreply" if not grown.is_empty() else "alone")
	var lead: Array=bank.leads[JSON.stringify([date,web,mode,js_truthy(focus.plan.rows["罗瑾"].get("outside")),event.get("nodeId")=="disclose"])].duplicate(true)
	var frozen: Dictionary=_object(focus.get("r4v9FamilyLeadText"))
	if web and lead.size()>1 and actor!=null and can_work_later(actor) and date in [46,48,49] and frozen.get("revision")=="r4v9-family-lead-v1" and chapter_json_equal(frozen.get("day"),date):
		var line: Variant=_object(frozen.get("byPerson")).get(actor)
		if line is String and not line.strip_edges().is_empty():lead[1]=line
	var body: String=_object(choice.get("diaries")).get("default","");var receipt: Dictionary=_object(focus.get("photoBatchReceipt"));var p: Dictionary=state.photo
	if not receipt.is_empty():body=bank.results[JSON.stringify([receipt.kind,js_truthy(receipt.get("amount")),p.album.selected>=minf(p.prints,16),p.prints>p.transferCount])]
	if web and ((js_truthy(focus.get("photoTransferReceipt")) and js_truthy(choice.get("photoTransfer")) and focus.photoTransferReceipt.get("event")==event.get("id")) or (not receipt.is_empty() and js_truthy(choice.get("photoBatch")) and receipt.get("event")==event.get("id"))):body=choice.diaries.default
	var lines: Array=lead.duplicate(true)
	if js_truthy(body):lines.append(body)
	for row in focus.plan.rows.values():
		if not row.outside or row.get("inactive",false) or not present(row.name) or row.name==focus.get("selected") or focus.get("cancelWork")==row.name:continue
		if not focus.resultPackets.any(func(packet):return packet.id==focus.workPackets.get(row.name) and packet.status=="applied"):continue
		var kind: String=row.type if row.type in ["photo","water","relief","wood"] else "committee"
		lines.append(bank.work[JSON.stringify([date,web,js_truthy(p.evidence),not grown.is_empty(),kind])])
	if js_truthy(focus.get("defaultNodeDiary")):lines.append(focus.defaultNodeDiary)
	var expedition: Dictionary=_object(state.expedition.get("active"))
	if not expedition.is_empty() and state.people.has(expedition.get("name")) and state.people[expedition.name].away:lines.append(bank.absence[expedition.name])
	var photo_mode:=c9_photo_context_mode()
	if photo_mode=="partial" and p.transferCount>=16:photo_mode="corepartial"
	lines.append(bank.news[str(date)]);lines.append(bank.endings[JSON.stringify([date,web,photo_mode])])
	focus.ordinaryDiaryLead=lead;focus.chapterDiary=lines.filter(func(t):return js_truthy(t));focus.chapterDiaryContext={"chapter":"I2b-9","day":date,"present":here,"hearingClass":"F：傍晚独立转述，不是城市层自动赋知","node":event.get("nodeId") if js_truthy(event.get("nodeId")) else null}
	if _object(event.get("readingVariant")).get("revision")=="WebR2-home-care-prose-v1" and focus.chapterDiary.find(_object(choice.get("diaries")).get("default",""))>0 and not focus.get("grandfatherRecoveryAdded",false) and not js_truthy(event.get("nodeId")):focus.chapterDiary[0]=""
	if js_truthy(event.get("messageThread")):focus.messageGenericReflection=focus.chapterDiary[-1]
	if js_truthy(event.get("custodyHandoff")):focus.custodyGenericReflection=focus.chapterDiary[-1]
	return true

var c9_photo_scenes: Dictionary={}

var c9_photo_nodes: Dictionary={}

var c9_old_nodes: Dictionary={}

func c9_contextualize_scene(focus: Dictionary,event: Dictionary) -> Dictionary:
	var recipients: Array=["母亲","安仁叔叔","外祖父"].filter(func(n):return present(n) and not focus.plan.rows[n].outside and understands(n));var home: Array=PEOPLE.filter(func(n):return n!="罗瑾" and present(n) and not focus.plan.rows[n].outside)
	var who: String=recipients[0] if not recipients.is_empty() else (home[0] if not home.is_empty() else "眼前的家人")
	event.recipient=null if recipients.is_empty() else recipients[0];event.receivedContext={"luoHome":not focus.plan.rows["罗瑾"].outside,"photoEvidence":state.photo.evidence,"photoPrints":state.photo.prints}
	if event.get("intro") is String:event.intro=event.intro.replace("§RECIPIENT§",who)
	return event

func make_c9_photo_scene(focus: Dictionary,node: Variant=null) -> Dictionary:
	var p: Dictionary=state.photo;var day: int=int(state.day)+1;var row: Dictionary=focus.plan.rows["罗瑾"];var strategy: String=p.strategy if p.strategy in ["print","organize","conceal"] else "steady";var kind: Variant=photo_opportunity(focus.plan) if node==null else null
	var prep: bool=day==45 and node=="transfer" and strategy!="steady" and p.album.selected<=p.transferCount and p.prints>p.album.selected and row.outside and row.type=="photo" and can_work_later("罗瑾") and state.people["罗瑾"].spirit>2 and p.album.selected<minf(16,p.prints)
	if prep:
		var desired: String="print" if p.prints<16 else "sort"
		if photo_batch_requirement(desired).met:kind=desired
	var ending: bool=node=="transfer" or node=="ending" and photo_transfer_requirement().met or node==null and p.album.selected>p.transferCount and photo_transfer_requirement().met
	if not ending and kind==null:return {}
	if c9_photo_scenes.is_empty():c9_photo_scenes=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_nine_photo_scenes.json"))
	var available: float=maxf(0,minf(p.prints,p.album.selected)-p.transferCount);var known: bool=state.knowledgeFacts.any(func(k):return k.get("id")=="deadline.notice" and "罗瑾" in k.get("knownBy",[]))
	var key: String=JSON.stringify([day,node,focus.plan.primary=="罗瑾",kind,strategy,mini(2,int(p.prints)),p.album.selected>0,chapter_json_equal(minf(16,p.prints)-p.album.selected,1),mini(2,int(available)),p.transferCount>0,p.prints>0 and p.transferCount>=p.prints,known,route_use_by_luo()])
	if not c9_photo_scenes.variants.has(key):fail_contract("C9_PHOTO_SCENE_SCOPE","缺少当前照片场景正文："+key);return {}
	var event: Dictionary=decode_home_content(c9_photo_scenes.events[c9_photo_scenes.variants[key]],c9_photo_scenes)
	if kind!=null:focus.plan.photoOpportunity=kind
	return c9_contextualize_scene(focus,event)

func make_bound_chapter_nine_node(focus: Dictionary) -> Dictionary:
	var node: Variant=focus.plan.nodeId
	if node in ["disclose","ending"] and focus.plan.primary=="home":return make_c9_final_home_node(focus)
	if node in ["transfer","ending"]:return make_c9_photo_scene(focus,node)
	if node in ["discover","firstPrint","deadline"]:
		if c9_photo_nodes.is_empty():c9_photo_nodes=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_nine_photo_nodes.json"))
		var p: Dictionary=state.photo;var strategy: String=p.strategy if node=="firstPrint" and p.strategy in ["print","organize","conceal"] else "steady";var key: String=JSON.stringify([int(state.day)+1,node,js_truthy(p.employed),js_truthy(p.evidence),p.prints>0,strategy])
		if not c9_photo_nodes.variants.has(key):fail_contract("C9_PHOTO_NODE_SCOPE","缺少照片固定节点："+key);return {}
		var event: Dictionary=decode_home_content(c9_photo_nodes.events[c9_photo_nodes.variants[key]],c9_photo_nodes)
		if node=="discover" and ["lusuR17Seen","lusu","lusuSourceBoundary"].any(func(k):return js_truthy(state.memory.get(k))):
			for choice in event.choices:
				if not choice.immediateEffects.any(func(e):return e.get("flag")=="lusuPhotoEcho"):choice.immediateEffects.append({"type":"flag_set","flag":"lusuPhotoEcho","value":true})
		if node=="firstPrint":focus.plan.photoOpportunity="print"
		return c9_contextualize_scene(focus,event)
	if node not in ["names","sources","employ"]:return {}
	if c9_old_nodes.is_empty():c9_old_nodes=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_nine_bound_nodes.json"))
	var home:=0;var adults:=0
	for i in range(PEOPLE.size()):
		if present(PEOPLE[i]) and not focus.plan.rows[PEOPLE[i]].outside:home|=1<<i
		if i>0 and understands(PEOPLE[i]):adults|=1<<(i-1)
	var key: String=JSON.stringify([node,int(state.day),home,adults,js_truthy(state.memory.get("visitorNameRecorded")),js_truthy(state.memory.get("employment_offer_pending"))])
	if not c9_old_nodes.variants.has(key):return {}
	var event: Dictionary=decode_home_content(c9_old_nodes.events[c9_old_nodes.variants[key]],c9_old_nodes);apply_employment_bridge(event)
	return c9_contextualize_scene(focus,event)

func _chapter9_parent_14_bind_day_eleven_twelve(focus: Dictionary) -> bool:
	if state.day<38:return _chapter7_parent_19_bind_day_eleven_twelve(focus)
	if int(state.day) not in range(10,44) or focus.plan.get("key")=="pigeonPickup":return false
	var fresh: bool=focus.get("laterEvents",{}).is_empty()
	focus.laterEvents={};focus.plan.eventIds={};focus.plan.photoMidContract="photo-mid-v1";focus.plan.chapter8=true
	focus.webM4ReadingRevision="WebM4-D39D44-v1"
	for target in focus.plan.targets:
		var event: Dictionary=expedition_search_bound_event(focus) if focus.plan.key=="expeditionSearch" else make_bound_chapter_eight_node(focus) if target==focus.plan.primary and js_truthy(focus.plan.get("nodeId")) else (make_chapter_home_base(focus) if target=="home" else make_pre_photo_outdoor_event(focus,target))
		if event.is_empty():return false
		focus.laterEvents[event.id]=event;focus.plan.eventIds[target]=event.id
		if target=="home" and event.get("conditionKind")=="recovery":
			var offer:=pre_photo_recovery_offer(focus)
			if offer.is_empty():return false
			var prior_care:=make_pre_photo_care_event(focus,true)
			if prior_care.is_empty():return false
			focus.laterEvents[prior_care.id]=prior_care
			focus.plan.rows[offer.actor].label+="；邻棚有人带来物品询问换粮"
			focus.plan.recoveryOffer={"kind":offer.kind,"item":offer.item,"cost":offer.cost,"day":offer.day}
	if not bind_chapter_eight_photo_optional(focus):return false
	bind_c8_early_transfer(focus)
	bind_mother_care(focus)
	bind_uncle_boundary(focus)
	if not bind_chapter_rope(focus):return false
	if not bind_neighbour_parcel(focus):return false
	# Ordinary neighbour-day scenes start outside this chapter.
	if not bind_mother_crisis(focus):return false
	if not bind_uncle_crisis(focus):return false
	apply_chapter_maintenance(focus)
	var base_home: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get("home")))
	focus.homeAdmissionAudit=home_reception_status(focus);focus.homeAdmissionAudit.eventId=base_home.get("id");focus.homeAdmissionAudit.actor=base_home.get("actor")
	focus.webR3NeighbourRevision="WebR3-neighbour-prose-v1"
	if base_home.has("neighbourhood"):
		var decorated:=make_rope_event(focus,{"allowed":true,"actor":base_home.actor,"home":focus.homeAdmissionAudit.home,"resting":focus.homeAdmissionAudit.resting})
		if decorated.is_empty():return false
		base_home.clear()
		for key in decorated:base_home[key]=decorated[key]
	if base_home.get("conditionKind") in ["care","recovery"] and not chapter_eight_care_reader.decorate(self,focus,base_home):return false
	if base_home.has("neighbourParcel"):
		var decorated:=make_parcel_event(focus,{"allowed":true,"actor":base_home.actor,"home":focus.homeAdmissionAudit.home,"resting":focus.homeAdmissionAudit.resting})
		if decorated.is_empty():return false
		base_home.clear()
		for key in decorated:base_home[key]=decorated[key]
	apply_rope_memory_echo(focus,base_home)
	var message_admission:=message_thread_admission(focus)
	focus.messageAdmissionAudit={"revision":"WebR5-messages-v1","allowed":message_admission.allowed,"reason":message_admission.reason,"stage":message_admission.get("stage") if js_truthy(message_admission.get("stage")) else null,"actor":message_admission.get("actor") if js_truthy(message_admission.get("actor")) else null}
	if message_admission.allowed:
		var old: Dictionary=focus.laterEvents[focus.plan.eventIds.home];var event:=make_message_thread_event(focus,message_admission)
		if event.is_empty():return false
		focus.messageDisplaced={"id":old.id,"title":old.title};focus.laterEvents[event.id]=event;focus.plan.eventIds.home=event.id
	var same_day:=custody_handoff_admission(focus)
	focus.custodyAdmissionAudit={"revision":CUSTODY_HANDOFF_REV,"allowed":same_day.allowed,"reason":same_day.reason,"actor":same_day.get("actor") if js_truthy(same_day.get("actor")) else null,"kind":same_day.get("kind") if js_truthy(same_day.get("kind")) else null}
	if same_day.allowed:
		var event:=make_custody_handoff_event(focus,same_day)
		if event.is_empty():return false
		var old: Dictionary=focus.laterEvents[focus.plan.eventIds.home];focus.custodyDisplaced={"id":old.id,"title":old.title};focus.laterEvents[event.id]=event;focus.plan.eventIds.home=event.id
	focus.custodyNightRevision=CUSTODY_NIGHT_REV;var overnight:=custody_night_admission(focus)
	focus.custodyNightAdmission={"revision":CUSTODY_NIGHT_REV,"allowed":overnight.allowed,"reason":overnight.reason,"actor":overnight.get("actor") if js_truthy(overnight.get("actor")) else null,"kind":overnight.get("kind") if js_truthy(overnight.get("kind")) else null}
	if overnight.allowed:
		var event:=make_custody_night_event(focus,overnight)
		if event.is_empty():return false
		var old: Dictionary=focus.laterEvents[focus.plan.eventIds.home];focus.custodyNightDisplaced={"id":old.id,"title":old.title};focus.laterEvents[event.id]=event;focus.plan.eventIds.home=event.id
	if focus.plan.eventIds.has("home"):connect_pre_photo_qian(focus,focus.laterEvents[focus.plan.eventIds.home]);apply_rope_editorial(focus,focus.laterEvents[focus.plan.eventIds.home])
	bind_r18_aftermath(focus)
	bind_r18_grandfather_home(focus)
	bind_route_warning_marker(focus)
	if fresh and focus.day==42 and focus.plan.get("chapter8",false) and focus.get("webM4ReadingRevision")=="WebM4-D39D44-v1" and focus.get("r3RouteWarningRevision")==ROUTE_REV and route_tracked() and not focus.has("r4v7D43DiaryText"):focus.r4v7D43DiaryText=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_eight_d43_diary_contract.json"))
	repair_r18_home_presentation(focus)
	repair_c8_d44_care_hint(focus)
	apply_middle_reading_context(focus)
	if fresh:apply_chapter_seven_reading_marks(focus);apply_chapter_six_maintenance_revision(focus)
	return true

func _chapter9_parent_14_ensure_day_eleven_twelve_focus() -> Dictionary:
	var prior: Dictionary=state.focus;var fresh: bool=prior.is_empty() or prior.get("day")!=state.day or not js_truthy(_object(prior.get("plan")).get("eventIds"));var focus:=_chapter7_parent_26_ensure_day_eleven_twelve_focus()
	if not focus.is_empty() and fresh:p1_produce_fresh(focus)
	return focus

func bind_c9_photo_optional(focus: Dictionary) -> bool:
	if "罗瑾" not in focus.plan.targets:return true
	if focus.plan.primary=="罗瑾" and js_truthy(focus.plan.get("nodeId")):return true
	if focus.plan.rows["罗瑾"].type!="photo":return true
	var event:=make_c9_photo_scene(focus)
	if contract_error!="":return false
	if event.is_empty():return true
	focus.laterEvents[focus.plan.eventIds["罗瑾"]]=event
	return true

func bind_c9_neighbour_end(focus: Dictionary,fresh: bool) -> void:
	if focus.day!=48:return
	var facts:=known_rope_facts(focus);var lines: Array=[];var bank: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_nine_neighbour_end.json"))
	for chain in ["rope","parcel"]:
		var rows: Array=facts.filter(func(f):return f.chain==chain)
		if rows.is_empty():continue
		var fact: Dictionary=rows[-1];var choice: String=fact.choice if fact.choice in ["support","space","take","give","compensate","release","greet","leave"] else "other";var result: Variant=fact.result if fact.result in ["delivered","spilled","not_sent"] else null;var wood: Variant=fact.wood if chapter_json_equal(fact.wood,1) or chapter_json_equal(fact.wood,3) else null
		var key: String=JSON.stringify([chain,int(fact.stage),choice,fact.lent,fact.sent,result,wood,fact.duplicate==true]);var text: String=bank.strings[int(bank.variants[key])]
		if not text.is_empty():lines.append(text)
	focus.webR3NeighbourEnd=lines
	if fresh and state.saveVersion==24 and not state.ended and state.day==48 and focus.plan.day==48 and not focus.has("r4v9NeighbourEndDisplay") and not lines.is_empty() and lines.size()<=2 and (lines.size()==1 or lines[0]!=lines[1]):focus.r4v9NeighbourEndDisplay={"revision":"R4-v9-B8-ending-only-v1","day":49,"lines":lines.duplicate()}

func _chapter9_parent_15_ordinary_pre_photo_effect_supported(effect: Dictionary) -> bool:
	if effect.get("type")=="knowledge_grant" and effect.get("fact") is Dictionary and disclosure_marked(effect.fact):return true
	if effect.get("type")=="node_resolve" and effect.get("node")=="disclose":return not effect.has("status") or effect.status in [null,"resolved","no_recipient"]
	if effect.get("type")=="flag_set":
		if effect.get("flag")=="photoDisclosedTo":return effect.get("value") in DISCLOSURE_ADULTS
		if effect.get("flag")=="photoDisclosureScope":return effect.get("value") in ["limited","partial"]
	return _chapter9_parent_2_ordinary_pre_photo_effect_supported(effect)


func _chapter9_parent_15_resolve_day_eleven_twelve_choice(index: int) -> bool:
	if p1_marked(current_later_focus_event()):return resolve_p1_choice(index)
	return _chapter7_parent_29_resolve_day_eleven_twelve_choice(index)

func resolve_chapter_nine_prepared_choice(index: int) -> bool:
	if state.ended or state.day<44 or state.day>48 or state.phase!="focusEvent" or state.focus.get("choiceIndex")!=null:return false
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if event.is_empty() or index<0 or index>=event.get("choices",[]).size():return false
	if event.get("nodeId") not in ["discover","trial","firstPrint","deadline","warning","transfer","disclose","ending"] and not event.get("photoMid",false) and not event.get("photoEnd",false) and not event.has("uncleCrisis"):return false
	var choice: Dictionary=event.choices[index]
	for key in ["motherCrisis","motherCare","uncleBoundary","nextMorningEffects"]:
		if js_truthy(choice.get(key)):return false
	if js_truthy(choice.get("photoBatch")):
		var photo_req:=photo_batch_requirement(choice.photoBatch.kind)
		if not photo_req.met:state.error=photo_req.reason;return false
	if js_truthy(choice.get("photoTransfer")):
		var req:=photo_transfer_requirement()
		if not req.met:state.error=req.reason;return false
	if event.has("uncleCrisis"):
		var req:=uncle_crisis_requirement(choice)
		if not req.met:state.error=req.reason;return false
	var requirement:=ordinary_pre_photo_requirement(choice)
	if not requirement.met:state.error=requirement.reason;return false
	if not later_event_eligible(event,focus.plan):state.error="当事人已不能参与这段现场。";return false
	var backup:=state.duplicate(true);var before:=focus_snapshot();contract_error="";contract_message=""
	if not prepare_chapter_nine_photo_choice(focus,event,choice):return rollback_photo_choice(backup)
	if not prepare_c9_transfer(focus,event,choice):return rollback_photo_choice(backup)
	if not prepare_uncle_crisis_choice(focus,event,choice):return rollback_photo_choice(backup)
	var immediate: Array=choice.get("immediateEffects",[]).duplicate(true)
	if js_truthy(choice.get("flag")):immediate.append({"type":"flag_set","flag":choice.flag,"value":true})
	if immediate.any(func(effect):return not ordinary_pre_photo_effect_supported(effect)) or choice.get("returnEffects",[]).any(func(effect):return not ordinary_pre_photo_effect_supported(effect)):
		fail_contract("C7_EFFECT_SCOPE","当前结果类型尚未原生接通。");return rollback_photo_choice(backup)
	var result_packet:=queue_focus_packet(immediate,event.id+":"+choice.id+":immediate","immediate",event.actor)
	if not attach_deadline_scene_knowledge(result_packet,event):return rollback_photo_choice(backup)
	attach_route_warning_witness(result_packet,event)
	if not attach_disclosure_knowledge(result_packet,event,choice,"observed"):return rollback_photo_choice(backup)
	apply_ordinary_pre_photo_packet(result_packet)
	if contract_error!="":return rollback_photo_choice(backup)
	var packet:=queue_focus_packet(choice.get("returnEffects",[]),event.id+":"+choice.id+":return","on_return",event.actor)
	mark_route_warning_return(packet,event)
	focus.carriedAssets=[]
	for effect in packet.effects:
		if effect.type=="resource_delta" and effect.amount>0:focus.carriedAssets.append({"owner":event.actor,"resource":effect.resource,"amount":effect.amount,"resultPacketId":packet.id})
	focus.cancelWork=focus.selected if choice.get("workImpact")=="complete" else null;focus.partialWork=focus.selected if choice.get("workImpact")=="partial" else null
	focus.choiceIndex=index;focus.outcomeKey="default";focus.immediateText=choice.closures.default;focus.immediateChange=describe_focus_change(before)
	focus.knowledge.player=[focus.immediateText];focus.knowledge.luo=[focus.immediateText] if focus.selected=="罗瑾" or (focus.selected=="home" and not focus.plan.rows["罗瑾"].outside) else []
	var history: Dictionary={"day":state.day,"type":"later-choice","event":event.id,"choice":choice.id}
	if event.get("conditionKind")==_object(event.get("readingVariant")).get("kind"):
		if event.has("readingVariant"):history.readingVariant=event.readingVariant
	else:history.readingVariant=null
	state.phase="focusResult";state.error=null;state.history.append(history);return true

func _chapter9_parent_16_finish_chapter_six_diary(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	if state.day<38:return _chapter7_parent_24_finish_chapter_six_diary(focus,event,choice)
	return finish_chapter_eight_diary(focus,event,choice)


func _chapter9_parent_16_settle_chapter_five_default_node(focus: Dictionary,event: Dictionary,lines: Array) -> bool:
	if state.day<38:return _chapter7_parent_24_settle_chapter_five_default_node(focus,event,lines)
	var id: Variant=focus.plan.get("nodeId")
	if id==null:return true
	var node: Dictionary=state.fixedNodeStates[id]
	if chapter_five_node_done(node) or event.get("nodeId")==id:return true
	if id=="trial":node.status="skipped";node.fallback="当日未试印";return true
	if id=="discover":return true
	if id=="warning":
		if present("安仁叔叔"):
			var planned: Dictionary=focus.laterEvents[focus.plan.eventIds[focus.plan.primary]];var packet:=queue_focus_packet([{"type":"flag_set","flag":"routeWarned","value":true},{"type":"node_resolve","node":"warning"}],"node:warning:unseen","on_return","安仁叔叔");mark_route_warning_return(packet,planned)
			if apply_ordinary_pre_photo_packet(packet):
				lines.append("安仁叔叔回来后说起有人替日本兵问住户；没有断定对方在找自己家。")
				if not route_tracked() or route_known("罗瑾"):focus.defaultNodeDiary="叔叔回来说了自己走过的路，也说了没看清的地方。我没有从这句提醒里听到任何关于照片的事。"
		return contract_error==""
	if id not in ["names","sources","employ","firstPrint","deadline"]:return false
	if id!="employ" and node.eligibleDays.size()<2:return true
	var planned: Dictionary=focus.laterEvents[focus.plan.eventIds[focus.plan.primary]];var options: Array=planned.choices.filter(func(c):return c.id=="safe") if id=="firstPrint" else [planned.choices[0]]
	if options.is_empty():return false
	var choice: Dictionary=options[0]
	if not ordinary_pre_photo_requirement(choice).met or not later_event_eligible(planned,focus.plan):return true
	var effects: Array=choice.get("immediateEffects",[]).duplicate(true)+choice.get("returnEffects",[]).duplicate(true)
	if not apply_ordinary_pre_photo_packet(queue_focus_packet(effects,"node:"+id+":default","on_return",planned.actor)):return false
	node.fallback="岗位保留默认" if id=="employ" else "第二个合适日稳妥默认"
	lines.append({"employ":"工作规矩已传到家里，罗瑾先保留这份帮工岗位。","names":"罗瑾只记下了姓名和消息来处。","sources":"罗瑾把公开说法与能核实的记录分开放好。","firstPrint":"罗瑾今天没有加印；这一回先维持普通工作。","deadline":"罗瑾先认下往后争取留存的方向；今天没有因此新增照片。"}[id]);focus.defaultNodeDiary=choice.diaries.default
	return true


func _chapter9_parent_16_settle_day_eleven_twelve_return() -> bool:
	if state.day<38:return _chapter7_parent_24_settle_day_eleven_twelve_return()
	if state.day>43:return false
	var before_home: Dictionary=_object(state.memory.get("grandfatherHomeR18")).duplicate(true)
	var focus_discovery_observed: bool=state.focus.plan.get("nodeId")=="discover" and state.focus.get("selected")=="罗瑾" and state.focus.get("choiceIndex")!=null and state.photo.evidence>0
	var event:=current_later_focus_event();var was_settled: bool=state.focus.get("settled",false);var result: bool=false
	if event.has("messageThread"):result=settle_message_thread_return()
	elif event.has("neighbourhood"):
		result=settle_ordinary_pre_photo_return()
		if result:result=finish_rope_diary(state.focus,event,event.choices[int(state.focus.choiceIndex)])
	elif event.has("neighbourParcel"):
		result=settle_ordinary_pre_photo_return()
		if result:result=finish_parcel_diary(state.focus,event,event.choices[int(state.focus.choiceIndex)])
	elif event.has("custodyHandoff") or event.has("custodyNight"):result=settle_chapter_eight_custody_return()
	else:result=settle_ordinary_pre_photo_return()
	if result and not was_settled and state.focus.get("custodyNightRevision")==CUSTODY_NIGHT_REV and js_truthy(state.memory.get(CUSTODY_NIGHT_KEY)):
		if not custody_night_record_valid(state.memory[CUSTODY_NIGHT_KEY]):state.focus.custodyNightCompatibility="这笔跨夜托存记录不完整，交接已隔离；旧物权未猜改。"
		else:settle_custody_owner_arrival(event)
	if result:finish_r18_family_return(state.focus,before_home)
	if result and focus_discovery_observed:
		if not js_truthy(state.memory.get("photoDiscoveryWorldDay")):state.memory.photoDiscoveryWorldDay=state.day+1
		state.memory.photoDiscoveryObserved=true;state.memory.photoDiscoveryObservedDay=state.day+1
	return result


func _chapter9_parent_16_settle_ordinary_pre_photo_return() -> bool:
	if state.day<38:return _chapter7_parent_24_settle_ordinary_pre_photo_return()
	# D11-D17 selected custody only. Later photos, crises, excursions and owner arrivals
	# on unrelated scenes remain gated until their complete contracts are implemented.
	if state.ended or state.day<38 or state.day>43:return false
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if event.is_empty():return false
	if focus.get("settled",false):state.phase="focusReturn";return true
	if state.phase!="focusResult" or focus.get("choiceIndex")==null or int(focus.choiceIndex)<0 or int(focus.choiceIndex)>=event.choices.size():return false
	if focus.plan.get("key") in ["expeditionSearch","pigeonPickup"]:return false
	if focus.plan.rows.values().any(func(row):return row.get("type") not in ["home","relief","wood","water","burial","registration","rest","committee","photo","grandfatherHomeVisit"]):return false
	if focus.resultPackets.any(func(packet):return packet.effects.any(func(effect):return not ordinary_pre_photo_effect_supported(effect) and effect.get("type")!="mother_crisis_consequence")):return false
	var choice: Dictionary=event.choices[int(focus.choiceIndex)]
	var backup:=state.duplicate(true);var before:=focus_snapshot();var lines: Array=[]
	if not before_uncle_crisis_return(focus,event):state=backup;state.error="返家尚未结算完成："+contract_message;return false
	for row in focus.plan.rows.values():
		var packets: Array=focus.resultPackets.filter(func(packet):return packet.id==focus.workPackets.get(row.name));var packet: Dictionary={} if packets.is_empty() else packets[0]
		if apply_c8_special_work(focus,event,row,packet,lines):continue
		if contract_error!="":state=backup;state.error="返家尚未结算完成："+contract_message;return false
		if not present(row.name) or row.get("inactive",false) or focus.get("cancelWork")==row.name:
			if not packet.is_empty():packet.status="cancelled";packet.cancelReason="未能完成或当事人未返家"
			if focus.get("cancelWork")==row.name and present(row.name) and row.outside:lines.append(row.name+"回到了棚边，原定的差事没有做完。")
			continue
		if not packet.is_empty():
			if focus.get("partialWork")==row.name:
				for effect in packet.effects:
					if effect.get("type")=="photo_progress" and effect.get("op")=="skill_delta":effect.value/=2
					elif typeof(effect.get("amount")) in [TYPE_INT,TYPE_FLOAT]:effect.amount=maxf(1,effect.amount-1)
			apply_ordinary_pre_photo_packet(packet)
		if row.outside and row.type!="photo" and not (row.name=="罗瑾" and js_truthy(focus.get("photoTransferReceipt"))):lines.append(later_return_line(row.name,"partial" if focus.get("partialWork")==row.name else "complete"))
		if row.type=="burial":
			apply_ordinary_pre_photo_packet(queue_focus_packet([{"type":"flag_set","flag":"burialExperienced","value":true}],"work:burial:experience","on_return","罗瑾"))
			if focus.selected!="罗瑾":focus.backgroundDiary="今天我跟队回来，没有在路上独自停留。我没有亲眼看见杀戮，却面对了它留下的后果。回到棚里以后，我想先看看家人还在不在眼前，并不想把一路所见立刻从头说完。"
		if row.type=="registration":
			var inquiry: bool=row.get("registrationProtocol")=="inquiry-I3e-4b"
			apply_ordinary_pre_photo_packet(queue_focus_packet([{"type":"flag_set","flag":"registrationInquiry" if inquiry else "registered","value":"mother"}],"work:registration:inquiry" if inquiry else "work:registration:paper","on_return","母亲"))
		if row.type=="photo" and row.outside and not js_truthy(focus.get("photoTransferReceipt")):lines.append("罗瑾只做完一部分杂活便离店回到棚边；没做完的那一段不能算上。" if focus.get("partialWork")==row.name else "罗瑾做完今天分到的杂活，离店回到棚边；主要冲洗仍由蒋孝义负责。")
	for packet in focus.resultPackets:
		if packet.timing=="on_return" and packet.status=="pending":apply_ordinary_pre_photo_packet(packet)
	if contract_error!="":state=backup;state.error="返家尚未结算完成："+contract_message;return false
	if not settle_chapter_five_default_node(focus,event,lines):state=backup;return false
	if not complete_c8_return_knowledge(focus,event):state=backup;state.error="返家尚未结算完成："+contract_message;return false
	var known: bool=c8_return_knowledge_allowed(focus,event) and mother_preparation_return_allowed(focus,event) and uncle_preparation_return_allowed(focus,event) and understands("罗瑾") and later_event_eligible(event,focus.plan) and (event.get("nodeId")!="warning" or not route_tracked() or route_known("罗瑾")) and (not event.get("motherCare",false) or mother_care_has_returned(focus)) and (not event.get("uncleBoundary",false) or uncle_boundary_has_returned(focus))
	if known and not js_truthy(event.get("r4v7P1")):state.knowledgeFacts.append({"id":event.id+":return-knowledge","day":state.day+1,"source":event.actor,"knownBy":["罗瑾"],"scope":"选择结果的可转述部分","text":choice.diaries.default})
	focus.diaryAllowed=known;focus.knowledge.luo=[choice.diaries.default] if known else []
	if known and focus.selected!="罗瑾" and (focus.selected!="home" or focus.plan.rows["罗瑾"].outside) and not lines.any(func(line):return line.begins_with(event.actor)):lines.append(event.actor+"在家里说起今天遇到的事。")
	focus.returnText=" ".join(lines);focus.returnChange=describe_focus_change(before);focus.settled=true;focus.carriedAssets=[];state.phase="focusReturn"
	if not finish_chapter_six_diary(focus,event,choice):state=backup;return false
	finish_uncle_boundary_diary(focus,event)
	if event.get("motherCare",false) and focus.diaryAllowed and focus.get("chapterDiary") is Array:focus.chapterDiary=focus.chapterDiary.slice(1)
	if event.has("motherCrisis") and not finish_mother_crisis_diary(focus,event,choice):state=backup;return false
	finish_uncle_crisis_diary(focus,event,choice)
	state.history.append({"day":state.day,"type":"later-return","event":event.id,"change":focus.returnChange})
	return true

func settle_chapter_nine_custody_return() -> bool:
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if state.ended or state.day<44 or state.day>48 or event.is_empty() or not (event.has("custodyHandoff") or event.has("custodyNight")):return false
	if focus.get("settled",false):return settle_ordinary_pre_photo_return()
	if state.phase!="focusResult" or focus.get("choiceIndex")==null or int(focus.choiceIndex)<0 or int(focus.choiceIndex)>=event.choices.size():return false
	var night: bool=event.has("custodyNight");var record: Dictionary=_object(state.memory.get(CUSTODY_NIGHT_KEY if night else "neighbourCustodyWebR6"))
	if not (custody_night_record_valid(record) if night else custody_handoff_record_valid(record)):return false
	if night and focus.get("custodyNightRevision")!=CUSTODY_NIGHT_REV:return false
	var choice: Dictionary=event.choices[int(focus.choiceIndex)];var visits: Array=record.get("visits",[]).filter(func(row):return row.get("event")==event.id and row.get("choice")==choice.id)
	if visits.size()!=1 or not focus.get("custodyNightReceipt" if night else "custodyReceipt") is Dictionary:return false
	var backup: Dictionary=state.duplicate(true);var meta: Dictionary=event.custodyNight if night else event.custodyHandoff
	if not meta.here and not understands(event.actor):choice.diaries.default="我回来时，今天接话的家人还不能把经过讲清。没有听见这回怎样答应、怎样交物，就不从棚边的一只包猜出事情已经做到哪里。" if night else "我回来以后，今天在棚边接话的家人还不能把事情说明。我没有因为眼前少了或多了一处空地，就猜谁来过、什么东西交给了谁。先顾现在能顾的，没听到的那一段不往日记里补。"
	if not settle_ordinary_pre_photo_return():state=backup;return false
	var visit: Dictionary=visits[0];visit.returned=true
	if night:
		var context:=custody_after_context(focus);var speaker: bool=event.actor in context.home and understands(event.actor) and neighbour_knows(event.actor,visit.factId,"custody-summary")
		if "罗瑾" in context.home and understands("罗瑾") and (meta.here or speaker):
			visit.returnListeners=deliver_fact({"factId":visit.factId,"recipients":["罗瑾"],"scope":"custody-summary","source":event.id+":return:"+event.actor,"mode":"witnessed" if meta.here else "told"})
			if record.status!="declined":deliver_fact({"factId":record.id,"recipients":["罗瑾"],"scope":"custody-summary","source":event.id+":return-summary:"+event.actor,"mode":"witnessed" if meta.here else "told"})
		if focus.diaryAllowed and not focus.get("chapterDiary",[]).any(func(text):return text.contains(choice.diaries.default)):
			if not focus.get("chapterDiary") is Array:focus.chapterDiary=[]
			focus.chapterDiary.append(choice.diaries.default)
		focus.custodyNightReceipt.returned=true
	else:
		if understands("罗瑾") and (meta.here or understands(event.actor)):visit.returnListeners=deliver_fact({"factId":visit.factId,"recipients":["罗瑾"],"source":event.id+(":witness-kept" if meta.here else ":return-telling:"+event.actor),"scope":"custody-public","mode":"witnessed" if meta.here else "told"})
		focus.custodyReceipt.returned=true
		if focus.diaryAllowed and not focus.get("chapterDiary",[]).is_empty():
			var text: String=choice.diaries.default;var parts: Array=Array(text.split("\n\n"));var tail: String=parts.pop_back();var body: String="\n\n".join(parts);var hit: bool=false
			for i in range(focus.chapterDiary.size()):
				if focus.chapterDiary[i].contains(text):hit=true;focus.chapterDiary[i]=focus.chapterDiary[i].replace(text,body)
			if not hit:focus.chapterDiary.append(tail if body.is_empty() else body)
			if js_truthy(focus.get("custodyGenericReflection")):focus.chapterDiary.erase(focus.custodyGenericReflection)
			if not body.is_empty():focus.chapterDiary.append(tail)
	return true

func _chapter9_parent_17_finish_mother_crisis_diary(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	if focus.day==48:return false
	var prior: Dictionary=_object(state.memory.get(MOTHER_CRISIS_KEY));var record: Dictionary=prior.duplicate(true);var tracked: bool=event.has("r4v9PreparationSource");var origin:=mother_preparation_source(focus,event)
	if tracked and not origin.is_empty() and understands("罗瑾") and later_event_eligible(event,focus.plan) and mother_preparation_choice_returned(focus,event,choice):
		if not state.knowledgeFacts.any(func(k):return k.get("id")=="mother-crisis.prepared-notice"):
			state.knowledgeFacts.append({"id":"mother-crisis.prepared-notice","day":state.day+1,"knownBy":["player","母亲"]+(["罗瑾"] if origin.mode=="home_witness" else []),"scope":"实际看过准备现场及退出/严重伤害预告；不是已遭侵害"})
		if not focus.get("diaryAllowed",false):
			if not record.has("knownBy"):record.knownBy=[]
			if "母亲" not in record.knownBy:record.knownBy.append("母亲")
		else:
			var facts: Array=state.knowledgeFacts.filter(func(k):return k.get("id")==event.id+":return-knowledge" and k.get("day")==state.day+1 and k.get("source")=="母亲" and k.get("knownBy",[])==["罗瑾"] and k.get("text")==choice.diaries.default)
			if facts.size()==1:facts[0].scope="棚内亲见的准备商量与选择结果；不是后来危机的亲历" if origin.mode=="home_witness" else "母亲返家后明确转述的准备选择与退出安排；罗瑾未亲历准备现场"
	if event.has("motherCrisis") and focus.get("diaryAllowed",false):
		if not tracked and event.motherCrisis.stage==1 and not state.knowledgeFacts.any(func(k):return k.get("id")=="mother-crisis.prepared-notice"):
			state.knowledgeFacts.append({"id":"mother-crisis.prepared-notice","day":state.day+1,"knownBy":["player","母亲"]+(["罗瑾"] if understands("罗瑾") else []),"scope":"实际看过准备现场及退出/严重伤害预告；不是已遭侵害"})
		if not record.has("knownBy"):record.knownBy=[]
		for person in ["母亲","罗瑾"]:
			if person not in record.knownBy:record.knownBy.append(person)
		var work: Array=[]
		for row in focus.plan.rows.values():
			if row.name=="母亲" or not row.outside or row.get("inactive",false) or not present(row.name) or focus.get("cancelWork")==row.name:continue
			if row.name=="罗瑾":work.append("我今天仍到照相馆做分给我的普通杂活。收工后回到棚边，店里没经自己手的事情暂且放下，先看家里。" if row.type=="photo" else "我今天也走完了自己的那一趟路。回到棚边，先将手上要安顿的放妥，才腾出地方坐下。")
			else:work.append(row.name+"今天也走完了原先安排的那一趟，带回的东西照实清点，各有各的来处。")
		focus.chapterDiary=work+[choice.diaries.default]
	if record!=prior:update_mother_crisis_record(prior,record)
	return true


func _chapter9_parent_17_finish_r18_family_return(focus: Dictionary,before: Dictionary) -> void:
	if not js_truthy(focus.get("settled")):return
	var date: int=int(focus.day)+1
	if js_truthy(focus.get("r18MotherAftermath")) and r18_work_applied(focus,"母亲") and not js_truthy(state.memory.get("motherAftermathR18Done")):
		state.memory.motherAftermathR18Done={"revision":"R18-family-v1","day":date,"outcome":_object(state.memory.get("motherCrisisR4a")).get("outcome")};focus.returnText=r18_append(focus.returnText,"母亲按自己先前说好的分量做完便回来了。她能够重新走这一段，没有使先前的伤和惊惧自动消失；往后能不能再出去，仍按当天真实状态决定。");r18_add_diary(focus,"母亲今天又出过一次门。她没有把这件事说成已经好了，只说这一段能够走完。我也不想因为她回来了，就把先前发生的伤害写成已经过去。")
	if js_truthy(focus.get("r18UncleAftermath")) and r18_work_applied(focus,"安仁叔叔") and not js_truthy(state.memory.get("uncleAftermathWorkR18")):
		state.memory.uncleAftermathWorkR18={"revision":"R18-family-v1","day":date,"outcome":_object(state.memory.get("uncleCrisisR4b")).get("outcome")};focus.returnText=r18_append(focus.returnText,"叔叔只把今天真正做完的那一段交代回来。少做的部分没有被别人的期待补上，伤后第一次重新出工也没有按从前的分量计算。");r18_add_diary(focus,"叔叔伤后第一次又接了差事。今天带回来的比从前少一点，我却没有再把这当成“没做够”。能够出去和已经恢复，是两件事。")
	var record: Dictionary=_object(state.memory.get("grandfatherHomeR18"))
	if js_truthy(_object(focus.get("plan")).get("r18GrandfatherHomeVisit")) and before.get("status")=="planned" and chapter_json_equal(before.get("stage"),1) and (record.is_empty() or chapter_json_equal(record.get("stage"),1)):
		var next: Dictionary=before.duplicate(true);next.stage=2;next.visitDay=date;next.status="visited";next.outcome="unseen_return";next.seenBy=["外祖父"];state.memory.grandfatherHomeR18=next;focus.returnText=r18_append(focus.returnText,"外祖父也按先前说好的路回来。他只说看过旧处，没有把一路细节从头讲全；能够确认的是，他没有把说不清来处的东西当成无主物带回来。")
		if understands("罗瑾"):state.knowledgeFacts.append({"id":"grandfather.home.R18.unseen.D"+str(date),"day":date,"knownBy":["罗瑾","外祖父"],"source":"外祖父","scope":"返家后的有限口述：只知看过旧处并未取不明物，不补写罗瑾未见的现场"})


func _chapter9_parent_17_finish_uncle_crisis_diary(focus: Dictionary,event: Dictionary,choice: Dictionary) -> void:
	var record:=uncle_crisis_record()
	if record.is_empty():return
	if js_truthy(event.get("uncleCrisis")) and uncle_crisis_committed(record):
		var tracked: bool=event.has("r4v10UnclePreparationSource");var origin:=uncle_preparation_source(focus,event)
		if tracked and chapter_json_equal(event.uncleCrisis.stage,1):
			if not origin.is_empty() and uncle_preparation_choice_committed(focus,event,choice):
				if not js_truthy(record.get("closed")) and not state.knowledgeFacts.any(func(k):return k.get("id")=="uncle-crisis.warning"):
					state.knowledgeFacts.append({"id":"uncle-crisis.warning","day":state.day+1,"knownBy":["player","安仁叔叔"]+(["罗瑾"] if origin.mode=="home_witness" and understands("罗瑾") else []),"scope":"亲历准备谈话：可免费退出、可付物资协助，留下可能死亡；伤者非旧陌生问询对象的确证；不是后来危机的亲历"})
				if js_truthy(focus.get("diaryAllowed")):
					var facts: Array=state.knowledgeFacts.filter(func(k):return k.get("id")==event.id+":return-knowledge" and k.get("day")==state.day+1 and k.get("source")=="安仁叔叔" and k.get("knownBy",[]).size()==1 and k.knownBy[0]=="罗瑾" and k.get("text")==choice.diaries.default)
					if facts.size()==1:facts[0].scope="棚内亲见的准备商量与选择结果；不是后来危机的亲历" if origin.mode=="home_witness" else ("叔叔返家后明确转述" if event.target=="安仁叔叔" else "罗瑾返家后由叔叔明确转述")+"的准备选择与退出安排；罗瑾未亲历准备现场"
		else:
			if chapter_json_equal(event.uncleCrisis.stage,1) and not js_truthy(record.get("closed")) and not state.knowledgeFacts.any(func(k):return k.get("id")=="uncle-crisis.warning"):state.knowledgeFacts.append({"id":"uncle-crisis.warning","day":state.day+1,"knownBy":["player","安仁叔叔"]+(["罗瑾"] if understands("罗瑾") else []),"scope":"亲历准备谈话：可免费退出、可付物资协助，留下可能死亡；伤者非旧陌生问询对象的确证"})
			focus.diaryAllowed=understands("罗瑾")
		focus.chapterDiary=[choice.diaries.default] if js_truthy(focus.get("diaryAllowed")) else []
		if record.get("status")=="pending":focus.returnText="安仁叔叔这趟没有回来；他的差事所得尚未交到家里，不计入库存。 "+focus.returnText;focus.knowledge.luo=[choice.diaries.default] if js_truthy(focus.get("diaryAllowed")) else []
	var prose: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/uncle_crisis_diary_prose.json"))
	if not js_truthy(event.get("uncleCrisis")) and js_truthy(focus.get("diaryAllowed")) and chapter_json_equal(record.get("stage"),2) and js_truthy(record.get("settled")):
		if not js_truthy(focus.get("chapterDiary")):focus.chapterDiary=[choice.diaries.default]
		if record.status=="pending":focus.chapterDiary.append(prose[0])
		elif record.get("messageDay")==state.day+1 and "罗瑾" in record.get("knownBy",[]):
			var opening: String=prose[1] if record.status=="dead" else (prose[2] if record.status=="released" else prose[3]);var lead:=0
			while lead<focus.chapterDiary.size() and focus.chapterDiary[lead] in focus.get("ordinaryDiaryLead",[]):lead+=1
			focus.chapterDiary=[opening]+focus.chapterDiary.slice(lead)
	if focus.day==48 and js_truthy(focus.get("diaryAllowed")) and js_truthy(record.get("messageDay")) and "罗瑾" in record.get("knownBy",[]):
		if not js_truthy(focus.get("chapterDiary")):focus.chapterDiary=[choice.diaries.default]
		focus.chapterDiary.append(prose[4] if record.status=="dead" else (prose[5] if present("安仁叔叔") else prose[6]))


func _chapter9_parent_17_ordinary_pre_photo_effect_supported(effect: Dictionary) -> bool:
	if effect.get("type")=="node_resolve" and effect.get("node") in ["transfer","ending"]:return not effect.has("status") or effect.status in [null,"resolved","skipped"]
	if effect.get("type")=="flag_set":
		if effect.get("flag")=="closure_method":return effect.get("value") in ["carried_to_shelter","retreated_with_photos","transfer_retreat","stop_confirmed","record_confirmed","stop_and_tell","state_locked_by_incapacity"]
		if effect.get("flag")=="transferDeclined":return effect.get("value") is bool
	return _chapter9_parent_15_ordinary_pre_photo_effect_supported(effect)


func _chapter9_parent_17_settle_day_eleven_twelve_return() -> bool:
	if state.day<44:return _chapter9_parent_16_settle_day_eleven_twelve_return()
	if state.day>48:return false
	var before_home: Dictionary=_object(state.memory.get("grandfatherHomeR18")).duplicate(true)
	var focus_discovery_observed: bool=state.focus.plan.get("nodeId")=="discover" and state.focus.get("selected")=="罗瑾" and state.focus.get("choiceIndex")!=null and state.photo.evidence>0
	var event:=current_later_focus_event();var was_settled: bool=state.focus.get("settled",false);var result: bool=false
	if event.has("messageThread"):result=settle_message_thread_return()
	elif event.has("neighbourhood"):
		result=settle_ordinary_pre_photo_return()
		if result:result=finish_rope_diary(state.focus,event,event.choices[int(state.focus.choiceIndex)])
	elif event.has("neighbourParcel"):
		result=settle_ordinary_pre_photo_return()
		if result:result=finish_parcel_diary(state.focus,event,event.choices[int(state.focus.choiceIndex)])
	elif event.has("custodyHandoff") or event.has("custodyNight"):result=settle_chapter_nine_custody_return()
	else:result=settle_ordinary_pre_photo_return()
	if result and not was_settled and state.focus.get("custodyNightRevision")==CUSTODY_NIGHT_REV and js_truthy(state.memory.get(CUSTODY_NIGHT_KEY)):
		if not custody_night_record_valid(state.memory[CUSTODY_NIGHT_KEY]):state.focus.custodyNightCompatibility="这笔跨夜托存记录不完整，交接已隔离；旧物权未猜改。"
		else:settle_custody_owner_arrival(event)
	if result:finish_r18_family_return(state.focus,before_home)
	if result and focus_discovery_observed:
		if not js_truthy(state.memory.get("photoDiscoveryWorldDay")):state.memory.photoDiscoveryWorldDay=state.day+1
		state.memory.photoDiscoveryObserved=true;state.memory.photoDiscoveryObservedDay=state.day+1
	return result


var c9_recovery_text: Dictionary={}

func c9_luo_portrait() -> Dictionary:
	var score: Dictionary={"evidence":0,"family":0,"promise":0};var seen: Dictionary={};var patterns: Dictionary={}
	for pair in [["evidence","photo|discover|trial|firstprint|deadline|transfer|disclose|暗房|照相"],["family","mother|母亲|uncle|安仁|grandfather|外祖父|care|recovery|expeditionsearch|search"],["promise","neighbour|parcel|message|custody|names|sources|entrust|missing|托存|认领|消息|姓名|来处"]]:
		var regex:=RegEx.new();regex.compile(pair[1]);patterns[pair[0]]=regex
	for row in state.history:
		if row.get("type") not in ["later-choice","focus-event"]:continue
		var id: String=str(row.get("event")) if js_truthy(row.get("event")) else "";var choice: String=str(row.get("choice")) if js_truthy(row.get("choice")) else "";id=id.to_lower();choice=choice.to_lower();var key: String=id+"|"+choice
		if seen.has(key):continue
		seen[key]=true
		for kind in score:
			if patterns[kind].search(id)!=null:score[kind]+=1
	var ranked: Array=score.keys();ranked.sort_custom(func(a,b):return score[a]>score[b]);var primary: String=ranked[0] if score[ranked[0]]>=2 and score[ranked[0]]-score[ranked[1]]>=2 else "balanced";var text: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_nine_portrait.json"))
	return {"revision":"R18-family-v1","primary":primary,"score":score,"text":text[primary]}

func finish_c9_custody_night_end(focus: Dictionary,event: Dictionary) -> void:
	var record: Dictionary=_object(state.memory.get(CUSTODY_NIGHT_KEY))
	if focus.day!=48 or focus.get("custodyNightRevision")!=CUSTODY_NIGHT_REV or record.is_empty() or not custody_night_record_valid(record) or js_truthy(focus.get("custodyNightEnding")):return
	focus.custodyNightStatusText="受托物尚在棚内待交。原约定第"+str(int(record.originalDueDay))+"日，"+("实际续过一夜，改至第"+str(int(record.dueDay))+"日。" if js_truthy(record.renewals) else "没有实际续约。")+"终日没有追加领取。" if custody_night_held(record) else ("本次跨夜请求已拒绝，没有受托物留在家中。" if record.status=="declined" else ("本次包已交给经当面引见、当日核准的指定者。" if record.status=="delivered_agent" else "本次包已当面交还原主。"))
	if not focus.get("diaryAllowed",false) or not understands("罗瑾"):focus.custodyNightEnding=true;return
	var seen: Array=record.entries.filter(func(entry):return neighbour_knows("罗瑾",entry.factId,"custody-summary"))
	if seen.is_empty():focus.custodyNightEnding=true;return
	var last: Dictionary=seen[-1];var text: String="我记得这一次跨夜托问。说到这包东西，仍要从自己真正听清、看见的那一段记起。"
	if last.result=="declined":text+="那次家里没有接下，我也没有替他守过那两夜。"
	elif last.holder=="owner":text+="我最后实际知道的是，这一笔已经交还本人；他随后到了哪里，没有新的交代。"
	elif last.holder=="designated-agent":text+="我最后实际知道的是，包按这一回许可交到了指定者手里，不是以后谁来都可以领。"
	else:
		var context:=custody_after_context(focus)
		if "罗瑾" in context.home and neighbour_knows("罗瑾",record.id,"custody-summary") and custody_night_held(record):text+="我今天看见这次待交的包仍在棚里。自己知道的取回日是第"+str(int(last.dueDay))+"日，"+("已经过去了。" if state.day+1>last.dueDay else "还要照原约定等。")+"没有确切交接，就不写成已经还了。"
		else:text+="我最后听清时，它还在棚里，取回约定说到第"+str(int(last.dueDay))+"日。后来有没有交物，没有一回我真正听到的说明，不能补写。"
	text+="包不是家里的粮木，交清或尚未交清，也不是那一家人的团聚或死讯。"
	if not focus.get("chapterDiary") is Array or not focus.chapterDiary.any(func(t):return t is String and not t.strip_edges().is_empty()):focus.chapterDiary=[_object(event.choices[int(focus.choiceIndex)].get("diaries")).get("default","")]
	focus.chapterDiary.append(text);focus.custodyNightEnding=true

func c9_append_end(focus: Dictionary,event: Dictionary,text: String) -> void:
	if not focus.get("chapterDiary") is Array or not focus.chapterDiary.any(func(t):return t is String and not t.strip_edges().is_empty()):focus.chapterDiary=[_object(event.choices[int(focus.choiceIndex)].get("diaries")).get("default","")]
	focus.chapterDiary.append(text)

func finish_c9_message_handoff_end(focus: Dictionary,event: Dictionary) -> void:
	if focus.day!=48 or not focus.get("diaryAllowed",false) or not understands("罗瑾"):return
	var message: Dictionary=_object(state.memory.get("neighbourMessagesWebR5"))
	if message.get("revision")==MESSAGE_THREAD_REV and message.get("visits") is Array and not js_truthy(focus.get("messageEndingAdded")):
		var seen: Array=message.visits.filter(func(v):return neighbour_visit_done(v,true) and neighbour_knows("罗瑾",v.get("factId",""),"public-summary"))
		if not seen.is_empty():
			var last: Dictionary=seen[-1];var corrected: bool=seen.any(func(v):return v.get("correction")=="delivered");var pending: bool=not corrected and seen.any(func(v):return v.get("correction")=="pending");var text: String="我记得那个仍在寻找同来女人和孩子的男人。"
			text+="有一次传岔的话，确实向当场的听者更正了；那不是找到了人的消息。" if corrected else ("那句过满的话虽同本人核清过，原听者还没有一回我知道的更正；不能替他们写成已经听明白。" if pending else "我只知道自己实际听过的几回交代，没有他们已经团聚的确讯。")
			text+="最后那回说到能承担哪里，话便停在那里。" if chapter_json_equal(last.get("stage"),6) else "后来没有接着听全，我不把漏过的交谈补成自己也在场。";text+="今天写到这一页，不替还没有下落的人认定生死。";c9_append_end(focus,event,text);focus.messageEndingAdded=true
	var handoff: Dictionary=_object(state.memory.get("neighbourCustodyWebR6"))
	if not handoff.is_empty() and custody_handoff_record_valid(handoff) and not js_truthy(focus.get("custodyEndingAdded")):
		var seen: Array=handoff.visits.filter(func(v):return neighbour_visit_done(v) and neighbour_knows("罗瑾",v.get("factId",""),"custody-public"))
		if not seen.is_empty():
			var last: Dictionary=seen[-1];var text: String="我记得棚边关于包袱的那一次问答。" if seen.size()==1 else "我记得那几回关于包袱的问答。"
			match last.get("result"):
				"delivered_authorized":text+="我知道的最后一次，是原主当面指了接物的人，东西才按他那时的意思交过去。"
				"returned_owner":text+="那一回只替他放到当天，后来确实交回了他本人，并没有一直留在我们这里。"
				"owner_retained":text+="最后听明白的那一回，家里没有接物，是原主仍自己提着离开。"
				_:text+="有一次家里明确说接不过来，包没有留下；我不能将拒绝以后没听到的事写成替他守过。"
			text+="包里装的不是我们可以添进家用的东西。后来他又到了哪里，物件如今在谁手里，我没有新的确讯；那一回问答并没有给我带来他所找亲人的下落。";c9_append_end(focus,event,text);focus.custodyEndingAdded=true
	if focus.get("custodyNightRevision")==CUSTODY_NIGHT_REV and js_truthy(state.memory.get(CUSTODY_NIGHT_KEY)) and js_truthy(focus.get("custodyEndingAdded")) and focus.get("chapterDiary") is Array:
		for i in range(focus.chapterDiary.size()):focus.chapterDiary[i]=str(focus.chapterDiary[i]).replace("后来他又到了哪里，物件如今在谁手里，我没有新的确讯","那回交清之后到后来再次托问以前的经过，我没有一直在旁看着")

func finish_c9_grandfather_recovery(focus: Dictionary,event: Dictionary) -> void:
	if focus.get("grandfatherRecoveryRevision")!="R4c" or not focus.get("settled",false) or not focus.get("diaryAllowed",false) or state.ended or not understands("罗瑾") or js_truthy(focus.get("grandfatherRecoveryAdded")):return
	var eligible: Array=state.expedition.history.filter(func(a):return a.get("name")=="外祖父" and a.get("status")=="returned" and _object(a.get("grandfatherStory")).get("recoveryRevision")=="R4c")
	if eligible.is_empty():return
	var a: Dictionary=eligible[-1];var r: Dictionary=a.grandfatherStory;var heard: bool="罗瑾" in r.get("heardBy",[]);var final_day: bool=state.day==48
	if final_day:
		if not heard and "罗瑾" not in r.get("seenBy",[]):return
	else:
		if state.day<=a.returnDay or r.get("recoveryDay")!=null or not understands("外祖父") or state.people["外祖父"].health<4 or state.ailments["外祖父"].values().any(func(v):return v>=3):return
		var uncle: Dictionary=_object(state.memory.get("uncleCrisisR4b"))
		if js_truthy(event.get("nodeId")) or js_truthy(event.get("motherCrisis")) or js_truthy(event.get("uncleCrisis")) or uncle.get("status")=="pending" or uncle.get("messageDay")==state.day+1 or js_truthy(focus.get("grandfatherDiaryAdded")):return
	var person: Dictionary=state.people["外祖父"];var status: String="dead" if not person.alive else ("lost" if js_truthy(person.get("permanentLost")) else ("away" if not present("外祖父") else ("weak" if person.health<=3 else "present")))
	var condition: String="wound" if state.ailments["外祖父"].cold>0 or state.ailments["外祖父"].wound>0 else ("moisture" if state.moisture>=2 else ("wood" if state.wood==0 else "normal"))
	var outcome: String=a.get("outcomeId","");outcome=outcome if outcome in ["safe","exhausted"] else "detour"
	var key: String="|".join(["end" if final_day else "recovery",str(int(heard)),outcome,status,condition,"1"])
	if c9_recovery_text.is_empty():c9_recovery_text=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_nine_grandfather_recovery_text.json"))
	if not c9_recovery_text.has(key):fail_contract("c9-recovery-text","外祖父返家后记缺少已核对文本。");return
	var text: String=c9_recovery_text[key]
	if final_day and not state.photo.evidence:text=text.replace("今天照片留下多少，另照实记；不论多寡，都不是替家里的谁标一个值不值得。","这一页先记到这里。手边还有多少东西，不能替一个人将走过的日子都算完。")
	var existing: Array=focus.get("chapterDiary",[]).filter(func(t):return t is String and not t.strip_edges().is_empty())
	if existing.is_empty():
		var choice: Dictionary=event.choices[int(focus.choiceIndex)] if event.get("choices") is Array and focus.get("choiceIndex")!=null else {};var diary: String=_object(choice.get("diaries")).get("default","")
		if not js_truthy(event.get("conditionKind")) and focus.get("selected")!="罗瑾" and (focus.get("selected")!="home" or focus.plan.rows["罗瑾"].outside):diary=str(event.get("actor",""))+"把今天的经过讲给我听以后，我又想了一阵。"+diary
		existing=[diary,focus.get("backgroundDiary",""),focus.get("defaultNodeDiary","")].filter(func(t):return t is String and not t.strip_edges().is_empty())
	focus.chapterDiary=existing;focus.chapterDiary.append(text);focus.grandfatherRecoveryAdded=true
	if final_day:r.endingDay=state.day
	else:
		r.recoveryDay=state.day
		for field in ["heardBy","seenBy"]:
			if not r.has(field):r[field]=[]
			if "罗瑾" not in r[field]:r[field].append("罗瑾")
		state.knowledgeFacts.append({"id":a.id+":recovery-R4c","day":state.day+1,"knownBy":["罗瑾","外祖父"],"source":"外祖父","scope":"F：实际返家且恢复到能交谈之后，外祖父向罗瑾转述；不补进旧日记"})

# Source C8 shelter inquiry's two ordinary choices share this boolean memory.
# Do not broaden the generic flag allowlist to arbitrary names or values.

var c9_family_view_bank: Dictionary={}

func c9_family_epilogue() -> Array:
	if c9_family_view_bank.is_empty():c9_family_view_bank=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_nine_family_view.json"))
	var bank: Dictionary=c9_family_view_bank;var lines: Array=[];var modern: bool=state.people["罗瑾"].alive and state.day==48 and state.focus.get("webM4EndReadingRevision")=="WebM4-D45D49-v1" and state.focus.get("day",-1)>=44 and state.focus.get("day",99)<=48
	for name in PEOPLE:
		var p: Dictionary=state.people[name];var status: String="dead" if not p.alive else ("lost" if p.get("permanentLost",false) else ("away" if p.away or p.get("detainedUntil")!=null else "present"));var health: int=0 if p.health<=1 else (1 if p.health<4 else (2 if p.health<8 else 3));var spirit: int=0 if p.spirit<3 else (1 if p.spirit<7 else 2)
		var text: Variant=bank.people[JSON.stringify([name,status,health,spirit,state.shelter>0,modern])]
		if js_truthy(text):lines.append(text)
	if state.people["罗瑾"].alive:
		var evidence: bool=state.photo.evidence>0 or state.photo.prints>0;var disclosure:=disclosure_epilogue(evidence)
		if not disclosure.is_empty():lines.append_array(disclosure)
		elif not evidence:lines.append("罗瑾没有走到亲手留下照片的那一步。这些天见到与听到的事，不能被说成从未发生，也不能被当作已经保存下来的影像。")
		else:lines.append("当前记录里没有可证的家人告知。不能据此断定从前无人知情，也不补写一次谈话。")
	var home: Dictionary=_object(state.memory.get("grandfatherHomeR18"));var mother: Dictionary=_object(state.memory.get("motherCrisisR4a"));var uncle: Dictionary=_object(state.memory.get("uncleCrisisR4b"))
	if home.get("status") in ["deferred","missed_window","planned"]:lines.append(bank.home.pending)
	elif chapter_json_equal(home.get("stage"),2):lines.append(bank.home[home.outcome if home.get("outcome") in ["own_only","leave_uncertain"] else "unseen_return"])
	if mother.get("outcome") in ["beaten","assault"] and js_truthy(mother.get("returned")):lines.append(bank.mother)
	if uncle.get("outcome") in ["escaped","released"] and js_truthy(uncle.get("messageDay")):lines.append(bank.uncleWorked if js_truthy(state.memory.get("uncleAftermathWorkR18")) else bank.uncleRested)
	if state.people["罗瑾"].alive:lines.append(bank.portrait[c9_luo_portrait().primary])
	var review: Variant=ending_current_review();var strategy: Variant=state.photo.get("strategy");var strategy_line: String=""
	if review!=null:
		if review.intention!=null:strategy_line="守证方式｜"+review.intention.text+"那时说下这句话，并没有就此完成加印、核清或转移。"
	elif strategy in ["print","organize","conceal"]:strategy_line=bank.strategy[strategy]
	if not strategy_line.is_empty() and strategy_line not in lines:lines.append(strategy_line)
	for text in state.focus.get("webR3NeighbourEnd",[]):
		if js_truthy(text) and not lines.any(func(t):return str(t).contains(str(text))):lines.append("棚区｜"+str(text))
	if ["lusuR17Seen","lusu","lusuSourceBoundary"].any(func(k):return js_truthy(state.memory.get(k))):lines.append_array(bank.lusu)
	for text in bank.history:
		if text not in lines:lines.append(text)
	return lines

func native_ending_view() -> Dictionary:
	if not state.ended or state.phase!="end":return {"ok":false,"reason":"记录尚未结束"}
	# Rendering only: the terminal sentinel day49 is not a fiftieth playable day.
	# Never change the live state or the saved/replayed terminal state.
	var projector=get_script().new();projector.state=state.duplicate(true)
	var normal: bool=state.day==49 and state.people["罗瑾"].alive and state.focus.get("day")==48
	if normal:projector.state.day=48
	var ending: Dictionary=projector.ending_photo_projection();var family: Array=projector.c9_family_epilogue();var current: Array=[];var history: Array=[]
	for line in family:
		if line.begins_with("后来｜") or line.begins_with("史实中后来｜") or line.begins_with("史实边界｜"):history.append(line)
		else:current.append(line)
	return {"ok":true,"normal":normal,"runtime_day":state.day,"display_day":49 if normal else state.day+1,"last_playable_day_projection":normal,"ending":ending,"family":family,"current":current,"history":history,"prints":state.photo.prints,"selected":state.photo.album.selected,"transferred":state.photo.transferCount}

func native_photo_record_view() -> Dictionary:
	var projector=get_script().new();projector.state=state.duplicate(true)
	var deadline_valid: bool=projector.deadline_validate();var route_valid: bool=projector.route_validate();var p: Dictionary=state.photo
	var stage: String="完整证据已经转移" if p.prints>=30 and p.album.selected>=16 and p.transferCount>=16 else ("核心十六张已经转移" if p.transferCount>=16 else ("核心十六张已经选出" if p.album.selected>=16 else ("至少三十张已经加印" if p.prints>=30 else ("已经秘密加印" if p.prints>0 else ("看见暴行影像" if p.evidence>0 else "尚未接触")))))
	var skill: String="熟悉协助流程" if p.skill>=6 else ("能协助简单冲印" if p.skill>=4 else ("能稳妥打下手" if p.skill>=2 else "还需从杂活做起"))
	var attention: String="非常危险" if p.attention>=6 else ("容易引起怀疑" if p.attention>=4 else ("有人开始留意" if p.attention>=2 else "无人特别留意"))
	return {"stage":stage,"employed":p.employed,"skill":skill,"attention":attention,"prints":p.prints,"selected":p.album.selected,"transferred":p.transferCount,"terminal":state.ended or state.phase=="end","disclosure":projector.disclosure_projection(),"disclosure_lines":projector.disclosure_epilogue(p.evidence>0 or p.prints>0),"deadline_valid":deadline_valid,"deadline":projector.deadline_project(),"route_valid":route_valid,"route":projector.route_project()}

var expedition_rules: Dictionary={}

func load_expedition_rules() -> void:
	if expedition_rules.is_empty():expedition_rules=JSON.parse_string(FileAccess.get_file_as_string("res://data/expedition_plan_rules.json"))

func expedition_plan_shape(p: Variant) -> bool:
	load_expedition_rules()
	return p is Dictionary and p.get("name") is String and expedition_rules.routes.has(p.name) and state.people.has(p.name) and p.get("tools") is Array and p.tools.all(func(t):return t is String) and _whole_number(p.get("rice")) and int(p.rice) in [0,1] and _whole_number(p.get("water")) and int(p.water) in [0,1,2,3]

func reject_expedition_plan(message: String) -> bool:state.error=message;return false

func expedition_plan_status() -> Dictionary:
	load_expedition_rules();var raw=state.expedition.get("plan")
	if not js_truthy(raw):return {"selected":false,"valid":true,"renderNative":true,"reason":"","missingTools":[],"missingWater":false}
	if not expedition_plan_shape(raw):return {"selected":true,"valid":false,"renderNative":false,"label":"原远行准备","reason":"原准备记录无法完整识别，请保留原存档并重新核对。","missingTools":[],"missingWater":false}
	var p: Dictionary=raw;var missing: Array=p.tools.filter(func(t):return not tool_available(t));var block: String=departure_block(p.name);var seen: Array=[];var malformed:=false
	for t in p.tools:
		if t in seen or t not in expedition_rules.routes[p.name].tools:malformed=true
		seen.append(t)
	var missing_water: bool=p.water>0 and not tool_available("canteen");var reason: String=block
	if reason.is_empty() and malformed:reason="携带记录与原路线不相符，请撤下本次准备后重新选择。"
	if reason.is_empty() and not missing.is_empty():reason="原先选中的部分物品已不可用；预选不代表已经带走。"
	if reason.is_empty() and p.tools.size()>expedition_rules.max_items:reason="原携带记录超过本工程现有上限，请重新取舍。"
	if reason.is_empty() and (p.rice>state.rice or p.water>state.water):reason="当前粮水不足以按原准备出发，请调整或取消本次准备。"
	if reason.is_empty() and js_truthy(p.water) and "canteen" not in p.tools:reason="原携水准备缺少水壶，请重新核对。"
	return {"selected":true,"valid":reason.is_empty(),"renderNative":block.is_empty() and not malformed,"label":p.name+"的远行准备","reason":reason,"missingTools":missing,"missingWater":missing_water}

func plan_expedition(name: Variant) -> bool:
	load_expedition_rules()
	if not night_plan_editable():return reject_expedition_plan("现在不能改动远行准备；已确认的夜晚和在途远行保留原结果。")
	var p: Dictionary=_object(state.expedition.get("plan"))
	if name is String and (name==expedition_rules.cancel or (not p.is_empty() and p.get("name")==name)):state.expedition.plan=null;state.error=null;return true
	if not name is String or not expedition_rules.routes.has(name):return reject_expedition_plan("无法识别这项远行选择，原准备未被替换。")
	var block: String=departure_block(name)
	if not block.is_empty():return reject_expedition_plan(block)
	state.expedition.plan={"name":name,"tools":[],"rice":0,"water":0};state.error=null;return true

func toggle_expedition_tool(id: Variant) -> bool:
	load_expedition_rules()
	if not night_plan_editable():return reject_expedition_plan("现在不能修改远行携带；已经确认的夜晚保留原安排。")
	var p: Dictionary=_object(state.expedition.get("plan"))
	if p.is_empty() or not p.get("tools") is Array or not id is String:return reject_expedition_plan("当前没有可修改的远行携带准备。")
	if id in p.tools:
		p.tools=p.tools.filter(func(t):return t!=id)
		if id=="canteen":p.water=0
		state.error=null;return true
	if not expedition_plan_shape(p):return reject_expedition_plan("原准备记录无法完整识别，请先取消本次准备。")
	if id not in expedition_rules.routes[p.name].tools or not tool_available(id):return false
	if p.tools.size()>=expedition_rules.max_items:return reject_expedition_plan("一次远行最多携带2件随身物品；水壶和药物也算在内。先放下一件再选。")
	p.tools=p.tools.duplicate();p.tools.append(id);state.error=null;return true

func toggle_expedition_supply(key: Variant) -> bool:
	load_expedition_rules()
	if not night_plan_editable():return reject_expedition_plan("现在不能修改远行粮水；已经确认的夜晚保留原安排。")
	var raw=state.expedition.get("plan")
	if not expedition_plan_shape(raw) or key not in ["rice","water"]:return reject_expedition_plan("当前没有可修改的远行粮水准备。")
	var p: Dictionary=raw
	if key=="water" and p.water>0 and not tool_available("canteen"):p.water=0;p.tools=p.tools.filter(func(t):return t!="canteen");state.error=null;return true
	if key=="water" and not tool_available("canteen"):return reject_expedition_plan("远行携水需要可用的水壶；水桶留作家庭取水和储水。")
	if key=="rice":p.rice=0 if js_truthy(p.rice) else 1;state.error=null;return true
	var next: int=(int(p.water)+1)%4
	if next>0 and "canteen" not in p.tools:
		if p.tools.size()>=expedition_rules.max_items:return reject_expedition_plan("水壶也占一个随身物品位置；请先放下一件物品再装水。")
		p.tools.append("canteen")
	p.water=next
	if next==0 and "canteen" in p.tools:p.tools=p.tools.filter(func(t):return t!="canteen")
	state.error=null;return true

func validate_expedition_plan() -> bool:
	load_expedition_rules();var raw=state.expedition.get("plan")
	if not js_truthy(raw):return true
	if not expedition_plan_shape(raw):return reject_expedition_plan("原远行准备无法完整识别，未确认出发；请先取消本次准备。")
	var p: Dictionary=raw;var block: String=departure_block(p.name)
	if not block.is_empty():return reject_expedition_plan(block+" 请取消这次准备或重新选择。")
	var seen: Array=[]
	for t in p.tools:
		if t in seen or t not in expedition_rules.routes[p.name].tools or not tool_available(t):return reject_expedition_plan("准备携带的物品已不可用，请重新检查。")
		seen.append(t)
	if p.tools.size()>expedition_rules.max_items:return reject_expedition_plan("一次远行最多携带2件随身物品；请重新取舍。")
	if js_truthy(p.water) and "canteen" not in p.tools:return reject_expedition_plan("携带粮水安排不合法。")
	if p.rice>state.rice or p.water>state.water:return reject_expedition_plan("家里的粮水不够准备这趟路。")
	return true

func expedition_risk(plan: Dictionary) -> float:
	load_expedition_rules();var p: Dictionary=state.people[plan.name];var r: Dictionary=expedition_rules.routes[plan.name];var w:=current_weather(1)
	var risk: float=r.risk+(0.10 if p.health<=6 else 0.0)+(0.12 if p.spirit<=5 else 0.0)+(0.12 if w.get("severe",false) else (0.05 if js_truthy(w.get("wet")) or js_truthy(w.get("wind")) else 0.0))
	if js_truthy(plan.get("rice")):risk-=0.04
	if js_truthy(plan.get("water")):risk-=0.04
	return clampf(risk,0.08,0.58)

func expedition_roll(a: Dictionary,key: String) -> float:
	return float(RNG.hash_seed(str(int(a.outcomeSeed))+":"+key))/4294967296.0

func build_legacy_expedition_reward(a: Dictionary,mode: String) -> Dictionary:
	var reduced:=mode!="safe";var r: Dictionary={"rice":0,"water":0,"wood":0};var items: Array=[]
	if mode=="exhausted":return {"resources":r,"items":items,"notes":[]}
	if a.name=="母亲":
		r.rice=1 if reduced else 3+int(floor(expedition_roll(a,"rice")*3))
		if expedition_roll(a,"medicine")<(0.25 if reduced else 0.60):items.append(["bandage","herbs","medkit"][int(floor(expedition_roll(a,"medicineKind")*3))])
	elif a.name=="外祖父":
		r.wood=(2 if reduced else 4)+int(floor(expedition_roll(a,"wood")*(2 if reduced else 3)))+(2 if "axe" in a.tools else 0)
		if not reduced and expedition_roll(a,"rice")<0.3:r.rice=1
	else:
		r.rice=1 if reduced else 1+int(floor(expedition_roll(a,"rice")*2));r.wood=1 if reduced else 2+int(floor(expedition_roll(a,"wood")*3))
		if js_truthy(a.supplies.water) and "canteen" in a.tools:r.water=1
		if expedition_roll(a,"tool")<(0.15 if reduced else 0.4):items.append(["umbrella","lamp","shovel","rope"][int(floor(expedition_roll(a,"toolKind")*4))])
	if mode=="safe":r.water+=maxi(0,int(a.supplies.water)-1)
	return {"resources":r,"items":items,"notes":[]}

func build_expedition_reward(a: Dictionary,mode: String) -> Dictionary:
	load_expedition_rules()
	if a.contract==expedition_rules.legacy_contract:return build_legacy_expedition_reward(a,mode)
	var reduced:=mode!="safe";var r: Dictionary={"rice":0,"water":0,"wood":0};var items: Array=[];var notes: Array=[]
	if mode!="exhausted":
		r.rice=int(floor(expedition_roll(a,"rice")*2)) if reduced else 1+int(floor(expedition_roll(a,"rice")*3))
		r.wood=int(floor(expedition_roll(a,"wood")*2)) if reduced else 1+int(floor(expedition_roll(a,"wood")*3))
		if a.name=="母亲":
			if expedition_roll(a,"lean")<0.35:r.rice+=1
			if expedition_roll(a,"medicine")<(0.18 if reduced else 0.45):items.append(["bandage","herbs","medkit"][int(floor(expedition_roll(a,"medicineKind")*3))])
		elif a.name=="外祖父":
			r.wood+=1
			if not reduced and expedition_roll(a,"leanRice")<0.25:r.rice+=1
		else:
			if expedition_roll(a,"leanRice")<0.20:r.rice+=1
			if expedition_roll(a,"leanWood")<0.20:r.wood+=1
			if expedition_roll(a,"tool")<(0.10 if reduced else 0.30):items.append(["umbrella","lamp","rope"][int(floor(expedition_roll(a,"toolKind")*3))])
	if mode=="exhausted" and "rope" in a.tools:
		r["rice" if expedition_roll(a,"ropeKeep")<0.5 else "wood"]=1;notes.append("绳索把一份还能带回的东西固定住了，疲惫返家也没有完全空手")
	elif reduced and "rope" in a.tools:
		r["wood" if r.wood>=r.rice else "rice"]+=1;notes.append("绳索让晚归途中少丢下一份已经收拢的物资")
	if a.name=="外祖父" and "axe" in a.tools and r.wood>0 and mode!="exhausted" and expedition_roll(a,"axeSalvage")<0.70:
		r.wood+=1;notes.append("斧头只处理了本来就能取用的较粗材料，多整理木料＋1")
	if mode=="safe":r.water+=maxi(0,int(a.supplies.water)-1)
	return {"resources":r,"items":items,"notes":notes}

const SPECIAL_REV="R16-special-recall-v1"

const SPECIAL_TOOL_IDS=["rope_load","umbrella_paper","whistle_signal","medicine_stop","canteen_share"]

func expedition_special_candidates(plan: Variant) -> Array:
	if not js_truthy(plan):return []
	var out: Array=[];var kit: Array=plan.get("tools",[])
	for pair in [["rope","rope_load"],["umbrella","umbrella_paper"],["whistle","whistle_signal"]]:
		if pair[0] in kit:out.append(pair[1])
	if kit.any(func(t):return t in ["bandage","herbs","medkit"]):out.append("medicine_stop")
	if "canteen" in kit and plan.get("water",0)>=2:out.append("canteen_share")
	if plan.name=="母亲" and state.memory.get("helped",0)>0:out.append("mother_care")
	if plan.name=="外祖父":out.append("grandfather_oldstreet")
	if plan.name=="安仁叔叔":out.append("uncle_waypoint")
	if js_truthy(state.memory.get("expeditionAddress")) and not js_truthy(state.memory.get("expeditionAddressResolved")):out.push_front("address_followup")
	var seen: Variant=state.memory.get("expeditionSpecialSeen",[])
	if not seen is Array:seen=[]
	return out.filter(func(id):return id not in seen)

func prepare_expedition_narrative(a: Dictionary,plan: Dictionary) -> void:
	load_expedition_rules()
	if a.is_empty() or plan.is_empty() or a.contract!=expedition_rules.contract:return
	a.recallContract=SPECIAL_REV;a.special=null
	var special_count: int=state.expedition.history.filter(func(x):return _object(x.get("specialResult")).get("revision")==SPECIAL_REV).size()
	if special_count>=3:return
	var candidates:=expedition_special_candidates(plan)
	if candidates.is_empty():return
	var strong: bool=candidates.any(func(id):return id in SPECIAL_TOOL_IDS or id=="address_followup")
	if expedition_roll(a,SPECIAL_REV+":attach")>=(0.52 if strong else 0.30):return
	var index: int=mini(candidates.size()-1,int(floor(expedition_roll(a,SPECIAL_REV+":pick")*candidates.size())))
	a.special={"revision":SPECIAL_REV,"id":candidates[index],"attachedDay":a.departDay,"historyClass":"合成家庭微观情境；非罗瑾有据可查的个人史实"}

func lock_grandfather_story(a: Dictionary) -> void:
	if a.name=="外祖父":a.grandfatherStory={"revision":"I3d-4","departTools":a.tools.duplicate(),"supplies":a.supplies.duplicate(),"recoveryRevision":"R4c"}

func commit_expedition() -> String:
	load_expedition_rules();var raw=state.expedition.get("plan")
	if not js_truthy(raw):return ""
	if not validate_expedition_plan():return ""
	var p: Dictionary=raw;var reserve:=expedition_reservation();var route: Dictionary=expedition_rules.routes[p.name];var risk:=expedition_risk(p)
	var id: String=state.seed+":expedition:"+str(int(state.day))+":"+route.id;var risk_roll:=random_value();var w:=current_weather(1)
	var a: Dictionary={"id":id,"contract":expedition_rules.contract,"name":p.name,"route":route.name,"routeId":route.id,"status":"active","departDay":state.day,"expectedDay":state.day+3,"searchAvailableDay":state.day+4,"latestDay":state.day+6,"tools":p.tools.duplicate(),"supplies":{"rice":p.rice,"water":p.water},"capacityDrop":reserve.capacityDrop,"risk":risk,"overdue":risk_roll<risk,"announced":false,"searches":[],"search":null,"lastSearchDay":null,"processedDays":[],"shock":[],"outcomeSeed":random_int(1,999999999),"outcomeId":null,"carriedResources":{},"carriedItemIds":[],"variant":random_int(0,1),"departWeather":{"id":w.id,"name":w.name,"cold":w.get("cold",0),"wet":w.get("wet",0),"wind":w.get("wind",0),"severe":js_truthy(w.get("severe"))}}
	a.riskAudit={"contract":a.contract,"revision":a.contract,"spirit":state.people[p.name].spirit,"spiritMax":state.people[p.name].get("spiritMax",10),"roll":risk_roll,"chance":risk,"result":"overdue" if a.overdue else "on_time","outcomeSeed":a.outcomeSeed}
	lock_grandfather_story(a);prepare_expedition_narrative(a,p)
	state.people[p.name].away=true;state.waterCap-=a.capacityDrop;state.expedition.active=a;state.expedition.plan=null
	if expedition_window(p.name)=="temporary":state.memory.expeditionOpportunity.used=true
	var kit: Array=[]
	for tool in p.tools:kit.append(expedition_rules.tool_names[tool])
	if js_truthy(p.rice):kit.append("米粮×1")
	if js_truthy(p.water):kit.append("饮水×"+str(int(p.water)))
	return p.name+"把约定的回程日又说了一遍，"+route.name+"。"+("随身带走："+"、".join(kit)+"。" if not kit.is_empty() else "没有带家中的粮、水或专用工具。")+"约定第"+str(int(a.expectedDay)+1)+"日清晨回来；若未归，第"+str(int(a.searchAvailableDay)+1)+"日起可找，第"+str(int(a.latestDay)+1)+"日清晨给出本次远行的最终消息。"

var expedition_prose: Dictionary={}

func load_expedition_prose() -> void:
	if expedition_prose.is_empty():expedition_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/expedition_special_prose.json"))

func resolve_expedition_special(a: Dictionary,mode: String) -> Variant:
	load_expedition_prose();var special: Dictionary=_object(a.get("special"))
	if special.get("revision")!=SPECIAL_REV:return null
	var med: String="none"
	for t in a.get("tools",[]):
		if t in ["bandage","herbs","medkit"]:med=t;break
	var raw: Variant=expedition_prose.special.get(a.name,{}).get(special.get("id"),{}).get(med)
	if raw==null:return null
	var r: Dictionary=raw.duplicate(true)
	for key in r.memory:state.memory[key]=r.memory[key]
	if not state.memory.get("expeditionSpecialSeen") is Array:state.memory.expeditionSpecialSeen=[]
	if r.id not in state.memory.expeditionSpecialSeen:state.memory.expeditionSpecialSeen.append(r.id)
	return r

func build_expedition_recall(a: Dictionary,mode: String,special: Variant) -> Variant:
	load_expedition_prose()
	if a.get("recallContract")!=SPECIAL_REV:return null
	var key: String=mode if mode in ["safe","late","assisted","exhausted"] else "assisted"
	var r: Dictionary=expedition_prose.recall[a.name][key][str(int(a.variant)%2)].duplicate(true)
	if special is Dictionary:
		var paragraphs: Array=special.get("paragraphs",[])
		var tail=r.paragraphs.pop_back();r.paragraphs.append_array(paragraphs);r.paragraphs.append(tail)
		if js_truthy(special.get("diary")):r.diary=special.diary
		r.specialTitle=special.get("title") if js_truthy(special.get("title")) else null
	r.createdDay=state.day
	return r

var expedition_return_prose: Dictionary={}

func expedition_contract_valid(a: Variant) -> bool:
	load_expedition_rules();return a is Dictionary and a.get("contract") in [expedition_rules.contract,expedition_rules.legacy_contract]

func restore_expedition_worry(a: Dictionary) -> void:
	for row in a.get("shock",[]):
		var p: Dictionary=state.people.get(row.name,{})
		if not p.get("alive",false):continue
		p.spiritMax=minf(10,p.spiritMax+row.cap);change_spirit(row.name,row.spirit)
	a.shock=[]

func record_grandfather_return(a: Dictionary) -> void:
	if a.name!="外祖父" or _object(a.get("grandfatherStory")).get("revision")!="I3d-4":return
	var can_tell: bool=understands("外祖父") and state.people["外祖父"].health>=4
	a.grandfatherStory.canTell=can_tell;a.grandfatherStory.seenBy=PEOPLE.filter(func(n):return understands(n));a.grandfatherStory.heardBy=a.grandfatherStory.seenBy.duplicate() if can_tell else []
	if not state.has("knowledgeFacts"):state.knowledgeFacts=[]
	state.knowledgeFacts.append({"id":a.id+":grandfather-return","day":state.day+1,"knownBy":a.grandfatherStory.seenBy.duplicate(),"source":"外祖父","scope":"F：已回家后的有限转述及实际清点" if can_tell else "F：只见到人返家与清点，未听到完整途中转述"})

func expedition_return_story(a: Dictionary,mode: String) -> String:
	if expedition_return_prose.is_empty():expedition_return_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/expedition_return_prose.json"))
	var search: String="luo" if _object(a.get("search")).get("mode")=="luo" else "ask"
	if a.name=="外祖父" and _object(a.get("grandfatherStory")).get("revision")=="I3d-4":
		var lost: Array=a.get("toolsLost",[]);var mask: int=(1 if a.grandfatherStory.get("canTell",false) else 0)+(2 if js_truthy(_object(a.get("carriedResources")).get("wood")) else 0)+(4 if "axe" in a.tools else 0)+(8 if "axe" in lost else 0)+(16 if lost.any(func(t):return t in ["herbs","medkit","bandage"]) else 0)
		return expedition_return_prose.grandfather[mode+"|"+search+"|"+str(mask)]
	return expedition_return_prose.normal[a.name+"|"+mode+"|"+str(int(a.get("variant",0)))+"|"+search]

func finish_expedition(mode: String="safe",timing: String="next_morning") -> String:
	var raw=state.expedition.get("active")
	if not expedition_contract_valid(raw):return ""
	var a: Dictionary=raw
	if not state.has("effectLedger"):state.effectLedger={"appliedEffectIds":[]}
	var effect_id: String=a.id+":return"
	if effect_id in state.effectLedger.appliedEffectIds or not state.people.get(a.name,{}).get("alive",false):return ""
	var p: Dictionary=state.people[a.name];var receipt: Array=[];var tools_lost: Array=[]
	a.outcomeId=mode;a.status="returned";a.returnDay=state.day
	var special=resolve_expedition_special(a,mode)
	if special is Dictionary and js_truthy(special.get("waterUsed")):a.supplies.water=maxi(0,int(a.supplies.get("water",0))-int(special.waterUsed))
	var reward:=build_expedition_reward(a,mode)
	if special is Dictionary:
		for key in special.get("resources",{}):reward.resources[key]=reward.resources.get(key,0)+special.resources[key]
	a.carriedResources=reward.resources.duplicate(true);a.carriedItemIds=reward.items.duplicate();receipt.append_array(reward.notes)
	var consumed: Array=special.get("consumeTools",[]) if special is Dictionary else []
	for id in consumed:
		if state.tools.get(id,false):state.tools[id]=false;tools_lost.append(id)
	if special is Dictionary:receipt.append_array(special.get("receipt",[]))
	p.away=false;state.waterCap+=a.capacityDrop
	if mode!="safe":
		var legacy: bool=a.contract==expedition_rules.legacy_contract;var w: Dictionary=a.get("departWeather",{});var exposures: Array=a.get("weatherExposure",[])
		var exposed: bool=js_truthy(w.get("wet")) or js_truthy(w.get("wind")) or w.get("cold",0)>=3 or exposures.any(func(x):return js_truthy(x.get("wet")) or js_truthy(x.get("wind")) or x.get("cold",0)>=3)
		var health_loss: int=3 if mode=="exhausted" else 1;var illness: String=("cold" if a.name=="外祖父" else "wound") if legacy else ("cold" if expedition_roll(a,"returnAilment")<(0.60 if exposed else 0.25) else "wound");var severity: int=2 if mode=="exhausted" else 1
		if not legacy and "umbrella" in a.tools and exposed and illness=="cold":health_loss=maxi(0,health_loss-1);severity=maxi(0,severity-1);receipt.append("雨伞挡住了部分风雨，受寒后果减轻")
		p.health=maxf(1,p.health-health_loss);apply_spirit_fact({"factId":a.id,"person":a.name,"domain":"return-experience","source":effect_id,"amount":-3 if mode=="exhausted" else -1})
		if severity>0:change_ailment(a.name,illness,severity)
		var medicine: String=""
		if severity>0:
			if "medkit" in a.tools and "medkit" not in consumed:medicine="medkit"
			else:
				var target: String="herbs" if illness=="cold" else "bandage"
				if target in a.tools and target not in consumed:medicine=target
		if not medicine.is_empty():
			state.tools[medicine]=false;tools_lost.append(medicine)
			if medicine=="medkit":
				for type in ["cold","wound","nutrition"]:change_ailment(a.name,type,-2)
				p.health=clampf(p.health+1,0,10)
			else:change_ailment(a.name,illness,-1)
			receipt.append(expedition_rules.tool_names[medicine]+"在途中用去×1")
		if mode=="exhausted":
			for t in a.tools:
				if t not in consumed and t not in ["bandage","herbs","medkit","canteen","rope"]:state.tools[t]=false;tools_lost.append(t);receipt.append(expedition_rules.tool_names[t]+"遗失×1");break
	for key in reward.resources:
		var n: int=reward.resources[key];var actual: int=maxi(0,mini(n,int(state.waterCap-state.water))) if key=="water" else n;state[key]+=actual
		if actual:receipt.append({"rice":"米粮","water":"饮水","wood":"木料"}[key]+"＋"+str(actual))
		if actual<n:receipt.append("容器装不下的饮水未带入家中")
	for id in reward.items:
		if state.tools.get(id,false):state.rice+=1;receipt.append("已有"+expedition_rules.tool_names[id]+"，多得的一件在返程时换为米粮＋1")
		else:state.tools[id]=true;receipt.append(expedition_rules.tool_names[id]+"＋1")
	restore_expedition_worry(a);a.specialResult=special.duplicate(true) if special is Dictionary else null;a.recall=build_expedition_recall(a,mode,special);a.toolsLost=tools_lost;a.receipt=receipt;a.timing=timing;record_grandfather_return(a)
	state.expedition.history.append(a.duplicate(true));state.expedition.active=null;state.expedition.decision=null;state.effectLedger.appliedEffectIds.append(effect_id)
	var text: String=expedition_return_story(a,mode)+(" 清点："+"；".join(receipt)+"。" if not receipt.is_empty() else " 这趟没有新物资带回。")
	a.returnText=text;state.expedition.history[-1].returnText=text
	if timing=="next_morning":state.morningResults.append(text)
	return text

func asked_search_story(a: Dictionary,outcome: String) -> String:
	if outcome=="found":return "昨日托去打听的人回来了。他核对过"+a.name+"的衣着和约定去处"+("，也问过约定哨声的线索" if "whistle" in a.tools else "")+"，找到了能接回人的那一段路；这次不是只带回一句听说。"
	if outcome=="clue":return "托人打听有了回话：有人在约定路线附近见过衣着相符的人，时间也大致对得上。来人没有认准面孔，"+a.name+"的下落仍未确认。这条线索留下，后续寻找会从这里接着问。"
	return "打听的人回来，把问过的地方逐一说清，却没有找到能认准"+a.name+"的人。用去的粮食换来了这一趟查问，没有换来团聚的保证。家里仍在等消息。"

func finish_asked_search(a: Dictionary) -> void:
	var q: Dictionary=_object(a.get("search"))
	if q.get("status")!="waiting":return
	q.status="settled";var outcome: String=q.outcome;a.searches.append({"day":q.day,"mode":"ask","outcome":outcome});state.morningResults.append(asked_search_story(a,outcome))
	if outcome=="found":finish_expedition("assisted")

func process_expedition_morning() -> void:
	var raw=state.expedition.get("active")
	if state.ended or not expedition_contract_valid(raw):return
	var a: Dictionary=raw
	if state.day in a.processedDays:return
	a.processedDays.append(state.day)
	if not state.people.get(a.name,{}).get("alive",false):
		var record: Dictionary=a.duplicate(true);record.status="cancelled_by_death";record.returnDay=null;state.expedition.history.append(record)
		for t in a.tools:state.tools[t]=false
		state.expedition.active=null;state.expedition.decision=null;return
	if a.contract==expedition_rules.contract:
		var w:=current_weather()
		if not a.has("weatherExposure"):a.weatherExposure=[]
		if (js_truthy(w.get("wet")) or js_truthy(w.get("wind")) or w.get("cold",0)>=3) and not a.weatherExposure.any(func(x):return x.day==state.day):a.weatherExposure.append({"day":state.day,"id":w.id,"name":w.name,"cold":w.get("cold",0),"wet":w.get("wet",0),"wind":w.get("wind",0)})
	var search: Dictionary=_object(a.get("search"))
	if search.get("mode")=="ask" and search.get("status")=="waiting" and state.day>=search.dueDay:finish_asked_search(a)
	if state.expedition.active==null:return
	if not a.overdue and state.day>=a.expectedDay:finish_expedition("safe");return
	if a.overdue and state.day>=a.expectedDay and not a.announced:
		a.announced=true;a.status="overdue"
		for name in PEOPLE.filter(func(n):return present(n)):
			var p: Dictionary=state.people[name];var old: float=p.spirit;var cap: int=1 if p.spiritMax>1 else 0
			deliver_fact({"factId":a.id+":overdue","recipients":[name],"source":"约定归期已到，家人在棚内等候未见归人","scope":"只知逾期，不知结局","mode":"witnessed"});apply_spirit_fact({"factId":a.id,"person":name,"domain":"overdue-worry","source":a.id+":overdue","amount":-1,"capLoss":cap});a.shock.append({"name":name,"cap":cap,"spirit":maxf(0,old-p.spirit)})
		state.morningResults.append(a.name+"没有按约定回来。路上的盘查与绕行都可能耽搁归期，现在还不能断定下落。第"+str(int(a.searchAvailableDay)+1)+"日清晨仍未见人，就可以托人打听，或由罗瑾沿约定的路线寻找。")
	if state.day>=a.latestDay:finish_expedition("late" if a.searches.any(func(x):return x.outcome=="clue") else "exhausted");return
	if a.announced and state.day>=a.searchAvailableDay and a.lastSearchDay!=state.day:a.status="searchable";state.expedition.decision={"name":a.name,"day":state.day}

func search_luo_block() -> String:
	var date: int=int(state.day)+1
	if not process_pre_photo_story_morning():return "当前晨间结果尚未接通，未安排寻找。"
	if not can_work_later("罗瑾") or state.people["罗瑾"].spirit<=2:return "罗瑾目前无法支撑寻找。"
	if current_weather().get("severe",false):return "恶劣天气下不能让罗瑾独自沿路寻找。"
	var nodes: Dictionary=state.fixedNodeStates
	for key in ["names","sources","employ"]:
		if nodes[key].due<=date and nodes[key].status not in ["resolved","skipped"]:return "今天仍有已经到期的主线事情要处理，可托人打听。"
	var locked: Array=[48]
	for key in ["discover","trial","firstPrint","deadline","warning","transfer","disclose","ending"]:
		var due=nodes.get(key,{}).get("due")
		if _whole_number(due):locked.append(int(due))
	if date in locked or ["discover","firstPrint"].any(func(k):return nodes[k].due<=date and nodes[k].status not in ["resolved","skipped"]):return "今天有不能由寻找替代的照片／人物节点，可托人或继续等待。"
	if _object(state.get("focus")).get("day")==state.day and js_truthy(_object(state.get("focus")).get("plan")):return "今日去向已经锁定，请明晨再安排寻找。"
	return ""

func search_outcome(a: Dictionary,method: String) -> String:
	var search: Dictionary=a.search;var late: int=maxi(0,int(state.day-a.searchAvailableDay));var r:=expedition_roll(a,"search:"+str(int(search.day))+":"+method)
	var signal_bonus: float=0.12 if "whistle" in a.tools else 0.0;var route_clue: float=0.05 if js_truthy(state.memory.get("expeditionRoadClue")) else 0.0
	var found: float=(0.42 if search.mode=="luo" else 0.30)+(0.22 if search.get("clueBefore",false) else 0.0)+signal_bonus+route_clue-(late*0.07)+(0.04 if method=="verify" else 0.0)
	return "found" if r<found else ("clue" if r<minf(0.86,found+0.36) else "none")

func resolve_search(choice: Variant) -> bool:
	var a: Dictionary=_object(state.expedition.get("active"));var d: Dictionary=_object(state.expedition.get("decision"))
	if state.phase!="search" or a.is_empty() or d.is_empty() or d.day!=state.day or state.day>=a.latestDay or a.lastSearchDay==state.day:return false
	if choice not in ["wait","ask","luo"]:return false
	if choice=="luo":
		var reason:=search_luo_block()
		if not reason.is_empty():state.error=reason;return false
	if choice=="ask" and state.rice<1:state.error="托人打听需要米粮×1。";return false
	a.lastSearchDay=state.day;state.expedition.decision=null;state.error=null
	if choice=="wait":state.morningResults.append("家里再等"+a.name+"一天，没有把等待当作一定会回来。");return true
	if choice=="ask":state.rice-=1
	a.search={"mode":choice,"day":state.day,"dueDay":state.day+1,"status":"planned","clueBefore":a.searches.any(func(x):return x.outcome=="clue")}
	if choice=="ask":a.search.outcome=search_outcome(a,"verify");a.search.status="waiting"
	state.morningResults.append("家里用去米粮×1，请人核实约好的路线。来人收下粮食，答应明晨回话；其他家人今天的日常不变。" if choice=="ask" else "罗瑾今天沿约定路线寻找家人，不再安排普通取水或照相馆帮工。")
	return true

var expedition_search_scenes: Dictionary={}

func bind_expedition_search(f: Dictionary) -> void:
	var a: Dictionary=_object(state.expedition.get("active"));var q: Dictionary=_object(a.get("search"))
	if f.plan.key!="expeditionSearch" or q.get("mode")!="luo":return
	if expedition_search_scenes.is_empty():expedition_search_scenes=JSON.parse_string(FileAccess.get_file_as_string("res://data/expedition_search_scenes.json"))
	var home: bool=PEOPLE.any(func(n):return n!="罗瑾" and present(n) and not f.plan.rows[n].outside)
	var event: Dictionary=expedition_search_scenes[a.name+"|"+str(1 if q.get("clueBefore",false) else 0)+"|"+str(1 if home else 0)].duplicate(true)
	event.id="expedition.search."+a.id;f.laterEvents={};f.laterEvents[event.id]=event;f.plan.eventIds={"罗瑾":event.id}

func lock_expedition_search(f: Dictionary,e: Dictionary,c: Dictionary) -> bool:
	if not e.get("expeditionSearch",false):return true
	var a: Dictionary=_object(state.expedition.get("active"));var q: Dictionary=_object(a.get("search"))
	if q.get("status")!="planned":return false
	q.method=c.id;q.outcome=search_outcome(a,c.id);q.spiritCost=2 if c.id=="verify" else 1;q.status="return_pending"
	var close: String
	if q.outcome=="found":close=("罗瑾准备按约折回时，一个先前问过的人追上来，带他到附近能停留的地方。" if c.id=="withdraw" else "那人听完衣着和去处，带罗瑾到附近能停留的地方。")+"他终于认出了"+a.name+"，先前排练的话一句也没说出来。等确认还能走动，他接过能拿的东西，陪着家人沿认过的路往棚边走；人和东西都还没有到家。"
	elif q.outcome=="clue":close="罗瑾问到了衣着和时间大致对得上的说法，却没有见到家人本人。他把相符和对不上的地方一并记住，没有顺着一句“好像见过”继续追到日本兵所在的路口。到约好的时辰，他沿原路往回走。"
	else:close="问过这一处，仍没有人能认准家人的下落。罗瑾看了一眼前面的路口，把还想追问的话停住，记下已经问过的范围，按约好的时辰往回走。他没有找到人，也没有把自己留在家人同样等不到的地方。"
	f.immediateText=close;f.expeditionSearchResult={"day":q.day,"mode":q.mode,"outcome":q.outcome,"status":"pending"};return true

func settle_expedition_search(f: Dictionary,e: Dictionary) -> String:
	if not e.get("expeditionSearch",false):return ""
	var a: Dictionary=_object(state.expedition.get("active"));var q: Dictionary=_object(a.get("search"))
	if q.get("status")!="return_pending" or not present("罗瑾"):fail_contract("EXPEDITION_SEARCH_RETURN","罗瑾未能按寻找契约返家");return ""
	q.status="settled";change_spirit("罗瑾",-q.spiritCost);a.searches.append({"day":q.day,"mode":"luo","outcome":q.outcome});f.expeditionSearchResult=q.duplicate(true);f.expeditionSearchResult.name=a.name
	state.knowledgeFacts.append({"id":a.id+":search:"+str(int(q.day))+":known","day":state.day+1,"source":"罗瑾","knownBy":PEOPLE.filter(func(n):return understands(n)),"scope":"认出并接回本人" if q.outcome=="found" else ("只得到尚未认准的线索" if q.outcome=="clue" else "查问无结果")})
	if q.outcome=="found":return finish_expedition("assisted","on_return")
	return "罗瑾按约回到棚边，带回一条衣着和时间大致相合的线索；家人仍未归来，家庭库存没有因此增加。" if q.outcome=="clue" else "罗瑾回到棚边，没有带回可靠下落。他把问过的地方说清，没有声称这次已经找到家人。"

var expedition_diary_prose: Dictionary={}

func finish_expedition_diary(f: Dictionary,e: Dictionary) -> void:
	if not e.get("expeditionSearch",false):return
	if expedition_diary_prose.is_empty():expedition_diary_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/expedition_diary_prose.json"))
	var q: Dictionary=f.expeditionSearchResult;var mask:=0
	for i in range(1,PEOPLE.size()):
		var name: String=PEOPLE[i];var row: Dictionary=f.plan.rows[name]
		if row.outside and not row.get("inactive",false) and present(name) and f.resultPackets.any(func(p):return p.id==f.workPackets.get(name) and p.status=="applied"):mask|=1<<(i-1)
	var listener: bool=PEOPLE.any(func(n):return n!="罗瑾" and understands(n))
	f.chapterDiary=expedition_diary_prose[q.name+"|"+q.outcome+"|"+str(mask)+"|"+str(1 if listener else 0)].duplicate(true);f.diaryAllowed=understands("罗瑾")

func supported_expedition_absence(person: String) -> bool:
	var a: Dictionary=_object(state.expedition.get("active"))
	return state.day>=21 and expedition_contract_valid(a) and a.get("name")==person and a.get("status") in ["active","overdue","searchable"] and state.people[person].alive and not state.people[person].get("permanentLost",false) and state.people[person].get("detainedUntil")==null

func expedition_search_bound_event(focus: Dictionary) -> Dictionary:
	bind_expedition_search(focus)
	return _object(focus.laterEvents.get(focus.plan.eventIds.get("罗瑾")))

func _expedition_parent_12_finish_chapter_six_diary(focus: Dictionary,event: Dictionary,choice: Dictionary) -> bool:
	if state.day<44:return _chapter9_parent_16_finish_chapter_six_diary(focus,event,choice)
	return finish_chapter_nine_diary(focus,event,choice)


func _expedition_parent_12_resolve_day_eleven_twelve_choice(index: int) -> bool:
	if state.day<44:return _chapter9_parent_15_resolve_day_eleven_twelve_choice(index)
	if state.day>48:return false
	var event:=current_later_focus_event()
	if event.get("photoMid",false) or event.get("photoEnd",false) or event.has("uncleCrisis") or event.get("nodeId") in ["discover","trial","firstPrint","deadline","warning","transfer","disclose","ending"]:return resolve_chapter_nine_prepared_choice(index)
	if event.get("uncleBoundary",false):return resolve_uncle_boundary_choice(index)
	if event.has("motherCrisis"):return resolve_mother_crisis_choice(index)
	if event.get("motherCare",false):return resolve_mother_care_choice(index)
	if event.has("neighbourParcel"):return resolve_parcel_choice(index)
	if event.has("custodyNight") or event.has("custodyHandoff"):return resolve_custody_choice(index)
	if event.has("neighbourhood"):return resolve_rope_choice(index)
	if event.has("messageThread"):return resolve_message_thread_choice(index)
	return commit_rope_choice_core(index)


func _expedition_parent_12_settle_day_eleven_twelve_return() -> bool:
	var before: bool=state.focus.get("settled",false);var result:=_chapter9_parent_17_settle_day_eleven_twelve_return()
	if result and not before and state.day>=44:
		finish_c9_message_handoff_end(state.focus,current_later_focus_event());finish_c9_custody_night_end(state.focus,current_later_focus_event())
	return result


var expedition_grandfather_diary: Dictionary={}

func commit_expedition_choice_core(index: int) -> bool:
	if state.ended or state.phase!="focusEvent" or state.focus.get("choiceIndex")!=null:return false
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if event.is_empty() or index<0 or index>=event.get("choices",[]).size():return false
	var choice: Dictionary=event.choices[index]
	for key in ["motherCrisis","uncleCrisis","motherCare","uncleBoundary","photoTransfer","photoBatch","nextMorningEffects"]:
		if js_truthy(choice.get(key)):return false
	var immediate: Array=choice.get("immediateEffects",[]).duplicate(true)
	if js_truthy(choice.get("flag")):immediate.append({"type":"flag_set","flag":choice.flag,"value":true})
	if immediate.any(func(effect):return not ordinary_pre_photo_effect_supported(effect)) or choice.get("returnEffects",[]).any(func(effect):return not ordinary_pre_photo_effect_supported(effect)):return false
	var requirement:=ordinary_pre_photo_requirement(choice)
	if not requirement.met:state.error=requirement.reason;return false
	if not later_event_eligible(event,focus.plan):state.error="当事人已不能参与这段现场。";return false
	var before:=focus_snapshot()
	apply_ordinary_pre_photo_packet(queue_focus_packet(immediate,event.id+":"+choice.id+":immediate","immediate",event.actor))
	var packet:=queue_focus_packet(choice.get("returnEffects",[]),event.id+":"+choice.id+":return","on_return",event.actor)
	focus.carriedAssets=[]
	for effect in packet.effects:
		if effect.type=="resource_delta" and effect.amount>0:focus.carriedAssets.append({"owner":event.actor,"resource":effect.resource,"amount":effect.amount,"resultPacketId":packet.id})
	focus.cancelWork=focus.selected if choice.get("workImpact")=="complete" else null;focus.partialWork=focus.selected if choice.get("workImpact")=="partial" else null
	focus.choiceIndex=index;focus.outcomeKey="default";focus.immediateText=choice.closures.default;focus.immediateChange=describe_focus_change(before)
	if not lock_expedition_search(focus,event,choice):return false
	focus.knowledge.player=[focus.immediateText];focus.knowledge.luo=[focus.immediateText] if focus.selected=="罗瑾" or (focus.selected=="home" and not focus.plan.rows["罗瑾"].outside) else []
	var history: Dictionary={"day":state.day,"type":"later-choice","event":event.id,"choice":choice.id}
	if event.get("conditionKind")==_object(event.get("readingVariant")).get("kind"):
		if event.has("readingVariant"):history.readingVariant=event.readingVariant
	else:history.readingVariant=null
	state.phase="focusResult";state.error=null;state.history.append(history);return true

func settle_expedition_focus_return() -> bool:
	# D11-D17 selected custody only. Later photos, crises, excursions and owner arrivals
	# on unrelated scenes remain gated until their complete contracts are implemented.
	if state.ended or state.day<21 or state.day>48:return false
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if event.is_empty():return false
	if focus.get("settled",false):state.phase="focusReturn";return true
	if state.phase!="focusResult" or focus.get("choiceIndex")==null or int(focus.choiceIndex)<0 or int(focus.choiceIndex)>=event.choices.size():return false
	if focus.plan.get("key")!="expeditionSearch":return false
	if focus.plan.rows.values().any(func(row):return row.get("type") not in ["home","relief","wood","water","burial","registration","rest","committee","photo","grandfatherHomeVisit","search"]):return false
	if focus.resultPackets.any(func(packet):return packet.effects.any(func(effect):return not ordinary_pre_photo_effect_supported(effect) and effect.get("type")!="mother_crisis_consequence")):return false
	var choice: Dictionary=event.choices[int(focus.choiceIndex)]
	var backup:=state.duplicate(true);var before:=focus_snapshot();var lines: Array=[]
	if not before_uncle_crisis_return(focus,event):state=backup;state.error="返家尚未结算完成："+contract_message;return false
	for row in focus.plan.rows.values():
		var packets: Array=focus.resultPackets.filter(func(packet):return packet.id==focus.workPackets.get(row.name));var packet: Dictionary={} if packets.is_empty() else packets[0]
		if apply_c8_special_work(focus,event,row,packet,lines):continue
		if contract_error!="":state=backup;state.error="返家尚未结算完成："+contract_message;return false
		if not present(row.name) or row.get("inactive",false) or focus.get("cancelWork")==row.name:
			if not packet.is_empty():packet.status="cancelled";packet.cancelReason="未能完成或当事人未返家"
			if focus.get("cancelWork")==row.name and present(row.name) and row.outside:lines.append(row.name+"回到了棚边，原定的差事没有做完。")
			continue
		if not packet.is_empty():
			if focus.get("partialWork")==row.name:
				for effect in packet.effects:
					if effect.get("type")=="photo_progress" and effect.get("op")=="skill_delta":effect.value/=2
					elif typeof(effect.get("amount")) in [TYPE_INT,TYPE_FLOAT]:effect.amount=maxf(1,effect.amount-1)
			apply_ordinary_pre_photo_packet(packet)
		if row.outside and row.type not in ["photo","search","pigeonPickup"] and not (row.name=="罗瑾" and js_truthy(focus.get("photoTransferReceipt"))):lines.append(later_return_line(row.name,"partial" if focus.get("partialWork")==row.name else "complete"))
		if row.type=="burial":
			apply_ordinary_pre_photo_packet(queue_focus_packet([{"type":"flag_set","flag":"burialExperienced","value":true}],"work:burial:experience","on_return","罗瑾"))
			if focus.selected!="罗瑾":focus.backgroundDiary="今天我跟队回来，没有在路上独自停留。我没有亲眼看见杀戮，却面对了它留下的后果。回到棚里以后，我想先看看家人还在不在眼前，并不想把一路所见立刻从头说完。"
		if row.type=="registration":
			var inquiry: bool=row.get("registrationProtocol")=="inquiry-I3e-4b"
			apply_ordinary_pre_photo_packet(queue_focus_packet([{"type":"flag_set","flag":"registrationInquiry" if inquiry else "registered","value":"mother"}],"work:registration:inquiry" if inquiry else "work:registration:paper","on_return","母亲"))
		if row.type=="photo" and row.outside and not js_truthy(focus.get("photoTransferReceipt")):lines.append("罗瑾只做完一部分杂活便离店回到棚边；没做完的那一段不能算上。" if focus.get("partialWork")==row.name else "罗瑾做完今天分到的杂活，离店回到棚边；主要冲洗仍由蒋孝义负责。")
	for packet in focus.resultPackets:
		if packet.timing=="on_return" and packet.status=="pending":apply_ordinary_pre_photo_packet(packet)
	if contract_error!="":state=backup;state.error="返家尚未结算完成："+contract_message;return false
	if not settle_chapter_five_default_node(focus,event,lines):state=backup;return false
	if not complete_c8_return_knowledge(focus,event):state=backup;state.error="返家尚未结算完成："+contract_message;return false
	var known: bool=c8_return_knowledge_allowed(focus,event) and mother_preparation_return_allowed(focus,event) and uncle_preparation_return_allowed(focus,event) and understands("罗瑾") and later_event_eligible(event,focus.plan) and (event.get("nodeId")!="warning" or not route_tracked() or route_known("罗瑾")) and (not event.get("motherCare",false) or mother_care_has_returned(focus)) and (not event.get("uncleBoundary",false) or uncle_boundary_has_returned(focus))
	if known and not js_truthy(event.get("r4v7P1")):state.knowledgeFacts.append({"id":event.id+":return-knowledge","day":state.day+1,"source":event.actor,"knownBy":["罗瑾"],"scope":"选择结果的可转述部分","text":choice.diaries.default})
	focus.diaryAllowed=known;focus.knowledge.luo=[choice.diaries.default] if known else []
	if known and focus.selected!="罗瑾" and (focus.selected!="home" or focus.plan.rows["罗瑾"].outside) and not lines.any(func(line):return line.begins_with(event.actor)):lines.append(event.actor+"在家里说起今天遇到的事。")
	var search_result:=settle_expedition_search(focus,event)
	if not search_result.is_empty():lines.append(search_result)
	focus.returnText=" ".join(lines);focus.returnChange=describe_focus_change(before);focus.settled=true;focus.carriedAssets=[];state.phase="focusReturn"
	finish_uncle_boundary_diary(focus,event)
	if not _expedition_parent_12_finish_chapter_six_diary(focus,event,choice):state=backup;return false
	finish_expedition_diary(focus,event)
	finish_expedition_grandfather_diary(focus)
	if (event.has("motherCrisis") or focus.day==48) and not finish_mother_crisis_diary(focus,event,choice):state=backup;return false
	finish_uncle_crisis_diary(focus,event,choice)
	if has_method("finish_c9_grandfather_recovery"):call("finish_c9_grandfather_recovery",focus,event)
	if contract_error!="":state=backup;return false
	state.history.append({"day":state.day,"type":"later-return","event":event.id,"change":focus.returnChange})
	return true

func finish_expedition_grandfather_diary(f: Dictionary) -> void:
	var a: Dictionary={}
	for i in range(state.expedition.history.size()-1,-1,-1):
		var row: Dictionary=state.expedition.history[i]
		if row.name=="外祖父" and _object(row.get("grandfatherStory")).get("revision")=="I3d-4" and row.get("returnDay")==state.day and row.status=="returned":a=row;break
	if a.is_empty() or not f.get("diaryAllowed",false) or not understands("罗瑾") or not f.get("chapterDiary") is Array or f.get("grandfatherDiaryAdded",false) or "罗瑾" not in a.grandfatherStory.get("seenBy",[]):return
	if expedition_grandfather_diary.is_empty():expedition_grandfather_diary=JSON.parse_string(FileAccess.get_file_as_string("res://data/expedition_grandfather_diary.json"))
	var text: String=expedition_grandfather_diary[a.outcomeId+"|"+str(1 if "罗瑾" in a.grandfatherStory.get("heardBy",[]) else 0)];var summary: int=-1
	for i in range(f.chapterDiary.size()):
		if f.chapterDiary[i].begins_with("外祖父这一趟远路今天终于结束"):summary=i;break
	if summary>=0:
		var goods: bool=_object(a.get("carriedResources")).values().any(func(n):return n>0) or not a.get("carriedItemIds",[]).is_empty();var when: String="傍晚" if a.get("timing")=="on_return" else "清晨"
		f.chapterDiary[summary]="外祖父回到了棚边。"+(when+"清点过带回的东西。" if goods else when+"先把人安顿下来，这趟没有新的物资带回。")+text
	else:f.chapterDiary.insert(maxi(0,f.chapterDiary.size()-1),text)
	f.grandfatherDiaryAdded=true

func find_expedition_history(id: Variant) -> Variant:
	for a in state.expedition.get("history",[]):
		if a.get("id")==id:return a
	return null

func unread_expedition_recall() -> Variant:
	var history: Array=state.expedition.get("history",[])
	for i in range(history.size()-1,-1,-1):
		var r: Dictionary=_object(history[i].get("recall"))
		if js_truthy(r.get("available")) and not js_truthy(r.get("read")):return history[i]
	return null

func open_expedition_recall(id: Variant) -> bool:
	var a=find_expedition_history(id)
	if a==null or not js_truthy(_object(a.get("recall")).get("available")):return false
	state.expedition.recallViewing=id;state.expedition.recallReturnPhase=state.phase;state.phase="expeditionRecall";state.error=null;return true

func close_expedition_recall() -> bool:
	var a=find_expedition_history(state.expedition.get("recallViewing"))
	if a!=null and a.get("recall") is Dictionary:a.recall.read=true
	var back=state.expedition.get("recallReturnPhase");state.expedition.recallViewing=null;state.expedition.recallReturnPhase=null
	state.phase=back if back in ["morning","focus","focusEvent","focusResult","focusReturn","event","report","night","nightEvent","search","end"] else "morning"
	# Pure transition only. Native persistence remains the explicit validated store path.
	return true

var pigeon_pickup_prose: Dictionary={}

func load_pigeon_pickup_prose() -> void:
	if pigeon_pickup_prose.is_empty():pigeon_pickup_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/pigeon_pickup_prose.json"))

func bind_pigeon_pickup(f: Dictionary) -> void:
	if f.plan.get("key")!="pigeonPickup":return
	load_pigeon_pickup_prose();var event: Dictionary=pigeon_pickup_prose.scenes["water" if tool_available("canteen") else "dry"].duplicate(true);event.id="animal.pickup.D"+str(int(state.day)+1);f.laterEvents={};f.laterEvents[event.id]=event;f.plan.eventIds={"罗瑾":event.id}

func lock_pigeon_pickup(f: Dictionary,e: Dictionary,c: Dictionary) -> bool:
	if not e.get("pigeonPickup",false):return true
	var a: Dictionary=_object(pigeon_request());var q: Dictionary=_object(a.get("pickupPlan"))
	if not a.get("pickup",false) or q.get("day")!=state.day or q.get("status")!="planned":fail_contract("PIGEON_PICKUP_PLAN","取物安排与今天不符");return false
	var packet: Dictionary={}
	for p in f.resultPackets:
		if p.timing=="on_return" and p.id.contains(e.id+":"+c.id+":return"):packet=p;break
	if packet.is_empty():fail_contract("PIGEON_PICKUP_PACKET","取物返家结果不存在");return false
	var injured: bool=c.id=="full" and random_value()<0.22
	packet.effects.append({"type":"character_spirit","target":"罗瑾","amount":-2 if c.id=="full" else -1})
	if injured:packet.effects.append({"type":"character_health","target":"罗瑾","amount":-1})
	q.status="return_pending";q.choice=c.id;q.injured=injured;q.packetId=packet.id;f.pigeonPickupResult={"choice":c.id,"injured":injured,"water":packet.effects.any(func(x):return x.get("resource")=="water"),"status":"pending"};return true

func settle_pigeon_pickup(f: Dictionary,e: Dictionary) -> String:
	if not e.get("pigeonPickup",false):return ""
	var a: Dictionary=_object(pigeon_request());var q: Dictionary=_object(a.get("pickupPlan"));var result: Dictionary=_object(f.get("pigeonPickupResult"))
	if q.get("status")!="return_pending" or result.is_empty():fail_contract("PIGEON_PICKUP_RETURN","取物回程记录不完整");return ""
	a.pickup=false;a.pickupDone=true;var packet: Dictionary={}
	for p in f.resultPackets:
		if p.id==q.packetId:packet=p;break
	if not present("罗瑾") or packet.get("status")!="applied":q.status="cancelled";a.pickupOutcome="not_returned";result.status="cancelled";return "罗瑾没有完成这一次返家，纸条对应的物资没有进入家中。"
	q.status="settled";result.status="settled";a.pickupOutcome="withdrawn" if result.choice=="leave" else "collected";state.history.append({"day":state.day,"type":"pigeon-pickup","choice":result.choice,"injured":result.injured,"resultPacketId":q.packetId})
	return "罗瑾退回棚边，没有带回纸条上的接济。这一次取物就此结束。" if result.choice=="leave" else "罗瑾把纸条上的接济带回棚边，东西到家以后才收入家中。"+("回程匆忙避让时，他的手擦破了，仍需留意身体。" if result.injured else "")

func finish_pigeon_diary(f: Dictionary,e: Dictionary) -> void:
	if not e.get("pigeonPickup",false):return
	var result: Dictionary=_object(f.get("pigeonPickupResult"));f.diaryAllowed=result.get("status")=="settled" and understands("罗瑾")
	if not f.diaryAllowed:return
	load_pigeon_pickup_prose();var family: bool=PEOPLE.any(func(n):return n!="罗瑾" and understands(n));var mask:=0
	for i in range(1,PEOPLE.size()):
		var name: String=PEOPLE[i];var row: Dictionary=f.plan.rows[name]
		if row.outside and present(name) and f.resultPackets.any(func(p):return p.id==f.workPackets.get(name) and p.status=="applied"):mask|=1<<(i-1)
	f.chapterDiary=pigeon_pickup_prose.diary[result.choice+"|"+str(1 if result.injured else 0)+"|"+str(1 if family else 0)+"|"+str(mask)].duplicate(true)

func ensure_pigeon_story_fields() -> void:
	var initial: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/story_initial_state.json"))
	for key in initial:
		if not state.has(key):state[key]=initial[key].duplicate(true) if key=="fixedNodeStates" else []

func queue_pigeon_focus_work(f: Dictionary) -> void:
	f.workPackets={}
	for row in f.plan.rows.values():
		if not row.get("inactive",false) and (not row.base.is_empty() or (f.plan.get("photoWorkRules")=="I2b-5a" and row.type=="photo" and row.outside)):
			var effects: Array=[]
			for resource in row.base:effects.append({"type":"shelter_delta","amount":row.base[resource]} if resource=="shelter" else {"type":"resource_delta","resource":resource,"amount":row.base[resource]})
			if f.plan.get("photoWorkRules")=="I2b-5a" and row.type=="photo":effects.append({"type":"photo_progress","op":"skill_delta","value":0.5})
			f.workPackets[row.name]=queue_focus_packet(effects,"work:"+row.name,"on_return",row.name).id

func apply_pigeon_public_snapshot(f: Dictionary) -> void:
	if state.day<4 or state.day>=10:return
	if first_week_focus_prose.is_empty():first_week_focus_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/first_week_focus_prose.json"))
	var bank: Dictionary=first_week_focus_prose;var key: String=str(int(state.day))
	if household_presence_mask()!=15:
		if missing_focus_prose.is_empty():missing_focus_prose=JSON.parse_string(FileAccess.get_file_as_string("res://data/first_week_missing_focus_prose.json"))
		bank=missing_focus_prose;key=JSON.stringify([int(state.day),household_presence_mask()])
	if bank.public_family.has(key):f.r4v3PublicFamilyText=bank.public_family[key].duplicate(true)

func _pigeon_parent_1_bind_day_eleven_twelve(focus: Dictionary) -> bool:
	if state.day<44:return _chapter9_parent_14_bind_day_eleven_twelve(focus)
	if int(state.day) not in range(10,49) or focus.plan.get("key")=="pigeonPickup":return false
	var fresh: bool=focus.get("laterEvents",{}).is_empty()
	focus.laterEvents={};focus.plan.eventIds={};focus.plan.photoMidContract="photo-mid-v1";focus.plan.chapter9=true
	focus.webM4EndReadingRevision="WebM4-D45D49-v1"
	for target in focus.plan.targets:
		var event: Dictionary=expedition_search_bound_event(focus) if focus.plan.key=="expeditionSearch" else make_bound_chapter_nine_node(focus) if target==focus.plan.primary and js_truthy(focus.plan.get("nodeId")) else (make_chapter_home_base(focus) if target=="home" else make_pre_photo_outdoor_event(focus,target))
		if event.is_empty():return false
		focus.laterEvents[event.id]=event;focus.plan.eventIds[target]=event.id
		if target=="home" and event.get("conditionKind")=="recovery":
			var offer:=pre_photo_recovery_offer(focus)
			if offer.is_empty():return false
			var prior_care:=make_pre_photo_care_event(focus,true)
			if prior_care.is_empty():return false
			focus.laterEvents[prior_care.id]=prior_care
			focus.plan.rows[offer.actor].label+="；邻棚有人带来物品询问换粮"
			focus.plan.recoveryOffer={"kind":offer.kind,"item":offer.item,"cost":offer.cost,"day":offer.day}
	if not bind_c9_photo_optional(focus):return false
	bind_mother_care(focus)
	bind_uncle_boundary(focus)
	if not bind_chapter_rope(focus):return false
	if not bind_neighbour_parcel(focus):return false
	# Ordinary neighbour-day scenes start outside this chapter.
	if not bind_mother_crisis(focus):return false
	if not bind_uncle_crisis(focus):return false
	apply_chapter_maintenance(focus)
	var base_home: Dictionary=_object(focus.laterEvents.get(focus.plan.eventIds.get("home")))
	focus.homeAdmissionAudit=home_reception_status(focus);focus.homeAdmissionAudit.eventId=base_home.get("id");focus.homeAdmissionAudit.actor=base_home.get("actor")
	focus.webR3NeighbourRevision="WebR3-neighbour-prose-v1"
	if base_home.has("neighbourhood"):
		var decorated:=make_rope_event(focus,{"allowed":true,"actor":base_home.actor,"home":focus.homeAdmissionAudit.home,"resting":focus.homeAdmissionAudit.resting})
		if decorated.is_empty():return false
		base_home.clear()
		for key in decorated:base_home[key]=decorated[key]
	if base_home.get("conditionKind") in ["care","recovery"] and not chapter_nine_care_reader.decorate(self,focus,base_home):return false
	if base_home.has("neighbourParcel"):
		var decorated:=make_parcel_event(focus,{"allowed":true,"actor":base_home.actor,"home":focus.homeAdmissionAudit.home,"resting":focus.homeAdmissionAudit.resting})
		if decorated.is_empty():return false
		base_home.clear()
		for key in decorated:base_home[key]=decorated[key]
	apply_rope_memory_echo(focus,base_home)
	var message_admission:=message_thread_admission(focus)
	focus.messageAdmissionAudit={"revision":"WebR5-messages-v1","allowed":message_admission.allowed,"reason":message_admission.reason,"stage":message_admission.get("stage") if js_truthy(message_admission.get("stage")) else null,"actor":message_admission.get("actor") if js_truthy(message_admission.get("actor")) else null}
	if message_admission.allowed:
		var old: Dictionary=focus.laterEvents[focus.plan.eventIds.home];var event:=make_message_thread_event(focus,message_admission)
		if event.is_empty():return false
		focus.messageDisplaced={"id":old.id,"title":old.title};focus.laterEvents[event.id]=event;focus.plan.eventIds.home=event.id
	var same_day:=custody_handoff_admission(focus)
	focus.custodyAdmissionAudit={"revision":CUSTODY_HANDOFF_REV,"allowed":same_day.allowed,"reason":same_day.reason,"actor":same_day.get("actor") if js_truthy(same_day.get("actor")) else null,"kind":same_day.get("kind") if js_truthy(same_day.get("kind")) else null}
	if same_day.allowed:
		var event:=make_custody_handoff_event(focus,same_day)
		if event.is_empty():return false
		var old: Dictionary=focus.laterEvents[focus.plan.eventIds.home];focus.custodyDisplaced={"id":old.id,"title":old.title};focus.laterEvents[event.id]=event;focus.plan.eventIds.home=event.id
	focus.custodyNightRevision=CUSTODY_NIGHT_REV;var overnight:=custody_night_admission(focus)
	focus.custodyNightAdmission={"revision":CUSTODY_NIGHT_REV,"allowed":overnight.allowed,"reason":overnight.reason,"actor":overnight.get("actor") if js_truthy(overnight.get("actor")) else null,"kind":overnight.get("kind") if js_truthy(overnight.get("kind")) else null}
	if overnight.allowed:
		var event:=make_custody_night_event(focus,overnight)
		if event.is_empty():return false
		var old: Dictionary=focus.laterEvents[focus.plan.eventIds.home];focus.custodyNightDisplaced={"id":old.id,"title":old.title};focus.laterEvents[event.id]=event;focus.plan.eventIds.home=event.id
	if focus.plan.eventIds.has("home"):connect_pre_photo_qian(focus,focus.laterEvents[focus.plan.eventIds.home]);apply_rope_editorial(focus,focus.laterEvents[focus.plan.eventIds.home])
	bind_c9_neighbour_end(focus,fresh)
	bind_r18_aftermath(focus)
	bind_r18_grandfather_home(focus)
	bind_route_warning_marker(focus)
	repair_r18_home_presentation(focus)
	apply_middle_reading_context(focus)
	if fresh:
		apply_chapter_seven_reading_marks(focus);apply_chapter_six_maintenance_revision(focus)
		load_c9_diary()
		if c9_diary_bank.frozenFamily.has(str(int(focus.day)+1)) and not focus.has("r4v9FamilyLeadText"):focus.r4v9FamilyLeadText=c9_diary_bank.frozenFamily[str(int(focus.day)+1)].duplicate(true)
		if state.saveVersion==24 and not state.ended and state.day==48 and focus.day==48 and focus.plan.day==48 and not focus.has(END_REVIEW_KEY):
			focus[END_REVIEW_KEY]={"revision":END_REVIEW_REV,"day":48};focus[END_REVIEW_KEY].merge(ending_inspect_intention(),true)
		bind_c9_p1_context(focus)
	return true


func _pigeon_parent_1_current_first_focus_event() -> Dictionary:
	var f: Dictionary=state.focus
	var primary: Dictionary=_object(_object(f.get("earlyReadingEvents")).get(f.get("eventId")))
	return primary if not primary.is_empty() else (_object(f.get("fallback")) if _object(f.get("fallback")).get("id")==f.get("eventId") else {})

func _pigeon_parent_1_ensure_day_eleven_twelve_focus() -> Dictionary:
	if state.day<44:return _chapter9_parent_14_ensure_day_eleven_twelve_focus()
	if state.ended or int(state.day) not in range(10,49) or not present("罗瑾"):return {}
	if state.focus.get("day")==state.day and state.focus.get("plan")!=null:return state.focus
	var backup:=state.duplicate(true);var template=JSON.parse_string(FileAccess.get_file_as_string("res://data/native_base_state_template.json"))
	state.focus=template.focus.duplicate(true);var focus: Dictionary=state.focus;focus.day=state.day;focus.grandfatherRecoveryRevision="R4c";focus.characterRevision="R4a";focus.uncleRevision="R4b";focus.neighbourhoodRevision="R2b";focus.integrationReadingRevision="FINAL-INTEGRATION";focus.middleReadingRevision="I3e-4c1"
	focus.plan=make_pre_photo_plan()
	if focus.plan.is_empty():state=backup;return {}
	focus.knowledge={"player":[],"luo":[]};focus.resultPackets=[]
	if not bind_day_eleven_twelve(focus):state=backup;return {}
	focus.workPackets={}
	for row in focus.plan.rows.values():
		if not row.get("inactive",false) and (not row.base.is_empty() or (row.type=="photo" and row.outside and state.photo.employed)):
			var effects: Array=[]
			for resource in row.base:effects.append({"type":"shelter_delta","amount":row.base[resource]} if resource=="shelter" else {"type":"resource_delta","resource":str(resource),"amount":row.base[resource]})
			if row.type=="photo" and row.outside and state.photo.employed:effects.append({"type":"photo_progress","op":"skill_delta","value":0.5})
			focus.workPackets[row.name]=queue_focus_packet(effects,"work:"+row.name,"on_return",row.name).id
	var snapshots=JSON.parse_string(FileAccess.get_file_as_string("res://data/later_public_family_snapshots.json"))
	if snapshots.has(str(int(state.day))):focus.r4v3PublicFamilyText=snapshots[str(int(state.day))].duplicate(true)
	return focus


func _pigeon_parent_1_focus_choice_requirement(choice: Variant) -> Dictionary:
	if not choice is Dictionary or choice.is_empty():return {"met":false,"reason":"选项不存在"}
	if choice.get("later",false):return {"met":false,"reason":"后续白天选择尚未接入"}
	var shelter_limit: float=float(choice.get("requiresShelterBelow",50 if choice.id in ["brace","pole_brace"] and _object(state.focus.get("fallback")).get("conditionKind")=="weather" else 0))
	if shelter_limit>0 and state.shelter>=shelter_limit:return {"met":false,"reason":"草棚已是目前能修到的最好状态，这次无需再加固。"}
	for id in choice.get("requiresTools",[]):
		if not tool_available(id):return {"met":false,"reason":"缺少"+TOOL_NAMES.get(id,id)}
	for key in choice.get("requiresResources",{}):
		if state[key]<choice.requiresResources[key]:return {"met":false,"reason":{"rice":"米粮","water":"饮水","wood":"木料"}.get(key,key)+"不足"}
	if choice.get("requiresWaterSpace",0)>state.waterCap-state.water:return {"met":false,"reason":"储水容器装不下换来的水"}
	if choice.get("requiresMemory")!=null and not state.memory.get(choice.requiresMemory,false):return {"met":false,"reason":"家里还没有问到这处接待地点"}
	return {"met":true,"reason":""}

func _pigeon_parent_1_resolve_day_eleven_twelve_choice(index: int) -> bool:
	if current_later_focus_event().get("expeditionSearch",false):return commit_expedition_choice_core(index)
	return _expedition_parent_12_resolve_day_eleven_twelve_choice(index)


func _pigeon_parent_1_resolve_first_day_focus_choice(index: int) -> bool:
	if state.ended or state.day<1 or state.day>9:return false
	var f:=ensure_early_focus();var event:=current_first_focus_event()
	if state.phase!="focusEvent" or f.get("choiceIndex")!=null:return false
	if f.is_empty() or event.is_empty() or index<0 or index>=event.choices.size():state.error="这项白天选择不存在。";return false
	var choice: Dictionary=event.choices[index];var requirement:=focus_choice_requirement(choice)
	if not requirement.met:state.error=requirement.reason;return false
	var before:=focus_snapshot();var outcome: String="default"
	if event.id=="evt.d03.grandfather.unstable_timbers.v1" and choice.id=="lower_together":outcome="safe" if float(RNG.hash_seed(state.seed+":"+event.id+":"+choice.id))/4294967296.0<0.75 else "scratch"
	elif not choice.closures.has("default") and not choice.closures.is_empty():outcome=choice.closures.keys()[0]
	prepare_early_knowledge_choice(event,choice)
	if choice.get("workImpact")=="complete":f.cancelWork=f.selected
	if choice.get("workImpact")=="partial":f.partialWork=f.selected
	var effects: Array=choice.get("immediateEffects",[]).duplicate(true)
	if event.id=="evt.d02.luo.first_water.v1" and choice.id=="help_now":effects.append({"type":"character_spirit","target":"罗瑾","amount":-1})
	if event.id=="evt.d03.grandfather.unstable_timbers.v1" and choice.id=="lower_together" and outcome=="scratch":effects.append({"type":"character_health","target":"外祖父","amount":-1})
	if choice.get("flag")!=null:effects.append({"type":"flag_set","flag":choice.flag,"value":true})
	f.effectNotes=apply_focus_effects(effects,event.id+":"+choice.id+":immediate","immediate",f.selected);f.returnEffects=choice.get("returnEffects",[]).duplicate(true)
	if not f.returnEffects.is_empty():queue_focus_packet(f.returnEffects,event.id+":"+choice.id+":return","on_return",f.selected)
	normalize_people();f.choiceIndex=index;f.outcomeKey=outcome;f.immediateText=focus_choice_text(choice,"closures",outcome);f.immediateChange="；".join(([describe_focus_change(before)]+f.effectNotes).filter(func(x):return x!=""));f.knowledge.player=[f.immediateText]
	if (f.selected=="罗瑾" or (f.selected=="home" and not f.plan.rows["罗瑾"].outside)) and not early_knowledge_missing(event,choice):f.knowledge.luo=[f.immediateText]
	var history_row: Dictionary={"day":state.day,"type":"focus-event","focus":f.selected,"event":event.id,"choice":choice.id,"outcome":outcome,"change":f.immediateChange}
	if event.has("conditionKind"):history_row.readingVariant=event.get("readingVariant") if event.conditionKind==_object(event.get("readingVariant")).get("kind") else null
	state.history.append(history_row)
	state.error=null;state.phase="focusResult";return true

func _pigeon_parent_1_select_first_day_focus(target: String) -> bool:
	var f:=ensure_first_day_focus()
	if state.phase not in ["focus","morning","event"] or f.get("choiceIndex")!=null:return false
	if f.is_empty() or target not in f.plan.targets:state.error="这个注视入口不属于今天实际外出的人或留棚地点。";return false
	var context: Dictionary=state.shelterItems.duplicate(true);context.whistle=state.tools.whistle
	var chosen_event: Dictionary=_object(f.earlyReadingEvents.get(f.plan.eventIds.get(target)))
	if target=="home" and PEOPLE.any(func(person):return present(person) and not f.plan.rows[person].outside and not focus_fit(person)):
		chosen_event=make_early_care_event(f)
		if chosen_event.is_empty():return false
		f.fallback=chosen_event
	elif target!="home" and (chosen_event.is_empty() or f.plan.rows[target].get("reason")=="resource-need"):
		chosen_event=make_first_week_outdoor_event(target)
		if chosen_event.is_empty():return false
		f.fallback=chosen_event
	elif target=="home" and (chosen_event.is_empty() or not focus_event_eligible(chosen_event,f.plan)):
		chosen_event=make_first_week_home_event(f)
		if chosen_event.is_empty():return false
		f.fallback=chosen_event
	if chosen_event.is_empty():return false
	f.textContext=context;f.selected=target;f.eventId=chosen_event.id;f.choiceIndex=null;f.outcomeKey=null;f.immediateText="";f.immediateChange="";f.returnText="";f.returnChange="";f.settled=false;f.cancelWork=null;f.partialWork=null;f.appliedEffects=[];f.returnEffects=[];f.knowledge={"player":[],"luo":[]}
	if f.eventId=="evt.d06.home.salvage.v1":f.fullReviewSalvageRevision="WebR1-family-prose-v1"
	state.error=null;state.phase="focusEvent";return true

func _pigeon_parent_1_settle_day_eleven_twelve_return() -> bool:
	if current_later_focus_event().get("expeditionSearch",false):return settle_expedition_focus_return()
	var before: bool=state.focus.get("settled",false);var result: bool=_expedition_parent_12_settle_day_eleven_twelve_return()
	if result and not before:
		finish_c9_grandfather_recovery(state.focus,current_later_focus_event())
	return result


func _pigeon_parent_1_settle_first_day_focus_return() -> bool:
	if state.ended or state.day<1 or state.day>9:return false
	var f:=ensure_early_focus()
	if f.is_empty() or f.get("choiceIndex")==null:return false
	if f.settled:state.phase="focusReturn";return true
	if state.phase!="focusResult":return false
	var before:=focus_snapshot();var event:=current_first_focus_event();var choice: Dictionary=event.choices[f.choiceIndex];var lines:=apply_early_focus_base_work()
	lines.append_array(apply_focus_effects(f.returnEffects,event.id+":"+choice.id+":return","on_return",f.selected))
	var knowledge:=settle_early_knowledge_return(event,choice);f.unseen=[]
	if f.day>=4:
		for target in f.plan.targets:
			if target==f.selected:continue
			var other: Dictionary=_object(f.earlyReadingEvents.get(f.plan.eventIds.get(target)))
			if other.is_empty() or not focus_event_eligible(other,f.plan):continue
			var index: int=int(other.get("defaultChoice",0))
			if other.id=="evt.d06.home.salvage.v1":index=0 if not state.shelterItems.oilcloth else (1 if not state.shelterItems.mat else 0)
			var normal: Dictionary=other.choices[index]
			if not focus_choice_requirement(normal).met:continue
			var effects: Array=normal.get("immediateEffects",[]).duplicate(true);effects.append_array(normal.get("returnEffects",[]))
			if normal.get("flag")!=null:effects.append({"type":"flag_set","flag":normal.flag,"value":true})
			lines.append_array(apply_focus_effects(effects,other.id+":unseen:return","on_return",target))
			if other.get("unseenDiary","")!="" and not (f.day==9 and f.selected=="home"):f.unseen.append(other.unseenDiary)
	if f.selected not in ["罗瑾","home"] and present(f.selected):
		if not lines.any(func(line):return line.begins_with(f.selected)) and PEOPLE.any(func(person):return person!=f.selected and present(person)):lines.push_front(f.selected+"把白天遇见的事讲给家里。")
	elif f.selected=="home" and f.plan.rows["罗瑾"].outside:lines.push_front("罗瑾回到棚里以后，家人才把白天棚边发生的事告诉他。" if knowledge.is_empty() or knowledge.canReport else "棚边这段话没有在此时转述给罗瑾。")
	f.returnText=" ".join(lines);f.returnChange=describe_focus_change(before);f.settled=true
	var diary: String=focus_choice_text(choice,"diaries",f.outcomeKey)
	if diary!="" and present("罗瑾") and focus_event_eligible(event,f.plan) and (knowledge.is_empty() or knowledge.luoKnown):f.knowledge.luo.append(diary)
	state.history.append({"day":state.day,"type":"focus-return","focus":f.selected,"event":event.id,"change":f.returnChange});state.phase="focusReturn";return true

func commit_pigeon_choice_core(index: int) -> bool:
	if state.ended or state.phase!="focusEvent" or state.focus.get("choiceIndex")!=null:return false
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if event.is_empty() or index<0 or index>=event.get("choices",[]).size():return false
	var choice: Dictionary=event.choices[index]
	for key in ["motherCrisis","uncleCrisis","motherCare","uncleBoundary","photoTransfer","photoBatch","nextMorningEffects"]:
		if js_truthy(choice.get(key)):return false
	var immediate: Array=choice.get("immediateEffects",[]).duplicate(true)
	if js_truthy(choice.get("flag")):immediate.append({"type":"flag_set","flag":choice.flag,"value":true})
	if immediate.any(func(effect):return not ordinary_pre_photo_effect_supported(effect)) or choice.get("returnEffects",[]).any(func(effect):return not ordinary_pre_photo_effect_supported(effect)):return false
	var requirement:=ordinary_pre_photo_requirement(choice)
	if not requirement.met:state.error=requirement.reason;return false
	if not later_event_eligible(event,focus.plan):state.error="当事人已不能参与这段现场。";return false
	var before:=focus_snapshot()
	apply_ordinary_pre_photo_packet(queue_focus_packet(immediate,event.id+":"+choice.id+":immediate","immediate",event.actor))
	var packet:=queue_focus_packet(choice.get("returnEffects",[]),event.id+":"+choice.id+":return","on_return",event.actor)
	focus.carriedAssets=[]
	for effect in packet.effects:
		if effect.type=="resource_delta" and effect.amount>0:focus.carriedAssets.append({"owner":event.actor,"resource":effect.resource,"amount":effect.amount,"resultPacketId":packet.id})
	focus.cancelWork=focus.selected if choice.get("workImpact")=="complete" else null;focus.partialWork=focus.selected if choice.get("workImpact")=="partial" else null
	focus.choiceIndex=index;focus.outcomeKey="default";focus.immediateText=choice.closures.default;focus.immediateChange=describe_focus_change(before)
	if not lock_pigeon_pickup(focus,event,choice):return false
	focus.knowledge.player=[focus.immediateText];focus.knowledge.luo=[focus.immediateText] if focus.selected=="罗瑾" or (focus.selected=="home" and not focus.plan.rows["罗瑾"].outside) else []
	var history: Dictionary={"day":state.day,"type":"later-choice","event":event.id,"choice":choice.id}
	if event.get("conditionKind")==_object(event.get("readingVariant")).get("kind"):
		if event.has("readingVariant"):history.readingVariant=event.readingVariant
	else:history.readingVariant=null
	state.phase="focusResult";state.error=null;state.history.append(history);return true

func settle_pigeon_focus_return() -> bool:
	# D11-D17 selected custody only. Later photos, crises, excursions and owner arrivals
	# on unrelated scenes remain gated until their complete contracts are implemented.
	if state.ended or state.day<6 or state.day>48:return false
	var focus: Dictionary=state.focus;var event:=current_later_focus_event()
	if event.is_empty():return false
	if focus.get("settled",false):state.phase="focusReturn";return true
	if state.phase!="focusResult" or focus.get("choiceIndex")==null or int(focus.choiceIndex)<0 or int(focus.choiceIndex)>=event.choices.size():return false
	if focus.plan.get("key")!="pigeonPickup":return false
	if focus.plan.rows.values().any(func(row):return row.get("type") not in ["home","relief","wood","water","burial","registration","rest","committee","photo","grandfatherHomeVisit","search","pigeonPickup"]):return false
	if focus.resultPackets.any(func(packet):return packet.effects.any(func(effect):return not ordinary_pre_photo_effect_supported(effect) and effect.get("type")!="mother_crisis_consequence")):return false
	var choice: Dictionary=event.choices[int(focus.choiceIndex)]
	var backup:=state.duplicate(true);var before:=focus_snapshot();var lines: Array=[]
	var before_home: Dictionary=_object(state.memory.get("grandfatherHomeR18")).duplicate(true)
	if not before_uncle_crisis_return(focus,event):state=backup;state.error="返家尚未结算完成："+contract_message;return false
	for row in focus.plan.rows.values():
		var packets: Array=focus.resultPackets.filter(func(packet):return packet.id==focus.workPackets.get(row.name));var packet: Dictionary={} if packets.is_empty() else packets[0]
		if apply_c8_special_work(focus,event,row,packet,lines):continue
		if contract_error!="":state=backup;state.error="返家尚未结算完成："+contract_message;return false
		if not present(row.name) or row.get("inactive",false) or focus.get("cancelWork")==row.name:
			if not packet.is_empty():packet.status="cancelled";packet.cancelReason="未能完成或当事人未返家"
			if focus.get("cancelWork")==row.name and present(row.name) and row.outside:lines.append(row.name+"回到了棚边，原定的差事没有做完。")
			continue
		if not packet.is_empty():
			if focus.get("partialWork")==row.name:
				for effect in packet.effects:
					if effect.get("type")=="photo_progress" and effect.get("op")=="skill_delta":effect.value/=2
					elif typeof(effect.get("amount")) in [TYPE_INT,TYPE_FLOAT]:effect.amount=maxf(1,effect.amount-1)
			apply_ordinary_pre_photo_packet(packet)
		if row.outside and row.type not in ["photo","search","pigeonPickup"] and not (row.name=="罗瑾" and js_truthy(focus.get("photoTransferReceipt"))):lines.append(later_return_line(row.name,"partial" if focus.get("partialWork")==row.name else "complete"))
		if row.type=="burial":
			apply_ordinary_pre_photo_packet(queue_focus_packet([{"type":"flag_set","flag":"burialExperienced","value":true}],"work:burial:experience","on_return","罗瑾"))
			if focus.selected!="罗瑾":focus.backgroundDiary="今天我跟队回来，没有在路上独自停留。我没有亲眼看见杀戮，却面对了它留下的后果。回到棚里以后，我想先看看家人还在不在眼前，并不想把一路所见立刻从头说完。"
		if row.type=="registration":
			var inquiry: bool=row.get("registrationProtocol")=="inquiry-I3e-4b"
			apply_ordinary_pre_photo_packet(queue_focus_packet([{"type":"flag_set","flag":"registrationInquiry" if inquiry else "registered","value":"mother"}],"work:registration:inquiry" if inquiry else "work:registration:paper","on_return","母亲"))
		if row.type=="photo" and row.outside and not js_truthy(focus.get("photoTransferReceipt")):lines.append("罗瑾只做完一部分杂活便离店回到棚边；没做完的那一段不能算上。" if focus.get("partialWork")==row.name else "罗瑾做完今天分到的杂活，离店回到棚边；主要冲洗仍由蒋孝义负责。")
	for packet in focus.resultPackets:
		if packet.timing=="on_return" and packet.status=="pending":apply_ordinary_pre_photo_packet(packet)
	if contract_error!="":state=backup;state.error="返家尚未结算完成："+contract_message;return false
	ensure_pigeon_story_fields()
	if not settle_chapter_five_default_node(focus,event,lines):state=backup;return false
	if not complete_c8_return_knowledge(focus,event):state=backup;state.error="返家尚未结算完成："+contract_message;return false
	var known: bool=c8_return_knowledge_allowed(focus,event) and mother_preparation_return_allowed(focus,event) and uncle_preparation_return_allowed(focus,event) and understands("罗瑾") and later_event_eligible(event,focus.plan) and (event.get("nodeId")!="warning" or not route_tracked() or route_known("罗瑾")) and (not event.get("motherCare",false) or mother_care_has_returned(focus)) and (not event.get("uncleBoundary",false) or uncle_boundary_has_returned(focus))
	if known and not js_truthy(event.get("r4v7P1")):state.knowledgeFacts.append({"id":event.id+":return-knowledge","day":state.day+1,"source":event.actor,"knownBy":["罗瑾"],"scope":"选择结果的可转述部分","text":choice.diaries.default})
	focus.diaryAllowed=known;focus.knowledge.luo=[choice.diaries.default] if known else []
	if known and focus.selected!="罗瑾" and (focus.selected!="home" or focus.plan.rows["罗瑾"].outside) and not lines.any(func(line):return line.begins_with(event.actor)):lines.append(event.actor+"在家里说起今天遇到的事。")
	var search_result:=settle_pigeon_pickup(focus,event)
	if not search_result.is_empty():lines.append(search_result)
	focus.returnText=" ".join(lines);focus.returnChange=describe_focus_change(before);focus.settled=true;focus.carriedAssets=[];state.phase="focusReturn"
	finish_uncle_boundary_diary(focus,event)
	if not _expedition_parent_12_finish_chapter_six_diary(focus,event,choice):state=backup;return false
	if state.day>=10 and state.day<=16 and not finish_ordinary_chapter4_diary():state=backup;return false
	if state.day>=17 and state.day<=23 and not finish_chapter_five_diary(focus,event,choice):state=backup;return false
	finish_pigeon_diary(focus,event)
	finish_expedition_grandfather_diary(focus)
	if (event.has("motherCrisis") or focus.day==48) and not finish_mother_crisis_diary(focus,event,choice):state=backup;return false
	finish_uncle_crisis_diary(focus,event,choice)
	if has_method("finish_c9_grandfather_recovery"):call("finish_c9_grandfather_recovery",focus,event)
	if contract_error!="":state=backup;return false
	state.history.append({"day":state.day,"type":"later-return","event":event.id,"change":focus.returnChange})
	finish_r18_family_return(focus,before_home)
	return true
