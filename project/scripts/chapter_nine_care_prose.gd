extends RefCounted
const REV="WebR2-home-care-prose-v1"
var data: Dictionary={}
func load_data() -> void:
	if data.is_empty():data=JSON.parse_string(FileAccess.get_file_as_string("res://data/home_care_components.json"))
func say(person: String) -> String:
	return "娘" if person=="母亲" else ("叔叔" if person=="安仁叔叔" else person)
func fill(text: String,view: Dictionary) -> String:
	return text.replace("{P}",view.patient).replace("{A}",view.actor).replace("{G}",view.get("goods") if view.get("goods")!=null else "")
func context(model,focus: Dictionary,event: Dictionary) -> Dictionary:
	load_data();var s: Dictionary=model.state;var home: Array=model.PEOPLE.filter(func(person):return model.present(person) and not focus.plan.rows[person].get("outside",false))
	var target: Variant=null
	for choice in event.choices:
		for effect in choice.get("immediateEffects",[]):
			if effect.get("type")=="character_health" and target==null:target=effect.target
	var patient: Variant=target if target in home else null
	if patient==null:
		var sorted: Array=home.duplicate();sorted.sort_custom(func(a,b):return model.PEOPLE.find(a)<model.PEOPLE.find(b) if s.people[a].health==s.people[b].health else s.people[a].health<s.people[b].health)
		for person in sorted:
			if s.people[person].health<=3 or s.ailments.get(person,{}).values().any(func(value):return value>=3):patient=person;break
	if patient==null:return {}
	var helpers: Array=home.filter(func(person):return person!=patient and model.can_work_later(person));var others: Array=home.filter(func(person):return person!=patient and model.understands(person))
	var returns: Dictionary={}
	for row in s.history:
		if row.get("type")=="later-return" and row.day<s.day:returns[str(int(row.day))+"|"+row.event]=true
	var past: Array=[]
	for row in s.history:
		var variant: Dictionary=model._object(row.get("readingVariant"))
		if row.get("type")=="later-choice" and row.day<s.day and returns.has(str(int(row.day))+"|"+row.event) and variant.get("revision")==REV and variant.get("patient")==patient:past.append(row)
	var same: Array=past.filter(func(row):return row.readingVariant.kind==event.conditionKind)
	var can_reply: bool=model.understands(patient);var pool: Array=data.RECOVERY if event.conditionKind=="recovery" else (data.CARD[patient] if can_reply else data.UNABLE)
	var index: int=(model.RNG.hash_seed(s.seed+"|"+REV+"|"+patient+"|"+event.conditionKind+"|"+("reply" if can_reply else "observe"))+same.size())%pool.size()
	var previous: Variant=null
	for i in range(past.size()-1,-1,-1):
		var row: Dictionary=past[i]
		if s.get("knowledgeFacts",[]).any(func(fact):return fact.get("id")==row.event+":return-knowledge" and "罗瑾" in fact.get("knownBy",[])):
			previous={"event":row.event,"choice":row.choice,"day":row.day,"patient":patient};break
	return {"revision":REV,"group":"home-care-continuity","kind":event.conditionKind,"index":index,"scene":event.conditionKind+"."+patient+"."+str(index),"patient":patient,"actor":event.actor,"helper":null if helpers.is_empty() else helpers[0],"other":null if others.is_empty() else others[0],"home":home,"narratorHere":"罗瑾" in home,"access":"direct" if "罗瑾" in home else ("told" if model.understands(event.actor) else "observed"),"canReply":can_reply,"alone":home.size()==1,"ordinal":same.size(),"previous":previous,"health":s.people[patient].health,"ailments":s.ailments[patient].duplicate(true),"water":s.water,"wood":s.wood,"goods":null,"cost":null,"sourceEvent":event.id}
func access(view: Dictionary) -> String:
	return data.access[JSON.stringify([view.patient,view.actor,view.access,int(view.ordinal)%6])]
func prior_echo(view: Dictionary) -> String:
	if view.previous==null or int(view.ordinal)%3!=2:return ""
	return data.prior.get(JSON.stringify([view.previous.patient,view.previous.choice]),"")
func choice_echo(view: Dictionary,id: String) -> String:
	return data.echo.get(JSON.stringify([view.patient,view.access,int(view.index),id,view.water>0]),"")
func compose_diary(view: Dictionary,card: Array,id: String) -> String:
	var echo: String=""
	if view.access!="observed":
		if not view.canReply and view.patient=="罗瑾":echo=data.UNABLE_SELF[int(view.index)%data.UNABLE_SELF.size()]
		elif view.alone:echo=card[2]
		elif view.access=="told":echo="听过白天能说清的这一点，我先没再问病者究竟想说什么。回来所见仍是一阵费力，不能从别人讲到的动作里认出一句完整答话。" if not view.canReply else data.INDIRECT[view.patient][int(view.index)%12]
		else:echo=card[2]
	var action:=choice_echo(view,id)
	if not view.canReply and id=="quiet" and view.access!="observed":action="白天先让这一阵静下来，没有另取水。问话没能接上，身体仍难受；我先记到这里，不将沉默认成一句已经答好的话。"
	return "\n\n".join([access(view),echo,action,prior_echo(view)].filter(func(text):return not text.is_empty()))
func close_care(model,view: Dictionary,id: String) -> Variant:
	var patient: String=view.patient;var helper: Variant=view.helper
	if id=="care_water":
		var action: String=helper+"取出这一份水，先清理靠近"+patient+"睡处的地方，再按眼前能做的慢慢照料。" if helper!=null else "这一份水取出后便用于眼前的清理照料。"+patient+"身边没有能稳当接过全部活的人，只能一小段一小段做。"
		return action+"用过的水单放，不再倒回存水里。"+(data.WATER_TAIL[patient] if view.canReply else patient+"这一阵略微安顿下来，仍没有清楚说出话。没有人替"+("她" if patient=="母亲" else "他")+"作出已经恢复的回答。")
	if id=="quiet":return "眼前的杂事暂时放下，"+("存水没有为这次清理取出，仍留作饮用。" if view.water>0 else "清理照料因没有存水先停下。")+(data.QUIET_TAIL[patient] if view.canReply else patient+"仍安静歇着，没有清楚应声，也没有已经被用药的经过。")
	if id=="care_or_repair":
		var workers: Array=view.home.filter(func(person):return person!=patient and model.can_work_later(person));var worker: String="外祖父" if "外祖父" in workers else (workers[0] if not workers.is_empty() else "undefined")
		return worker+"将要动的地方先腾开，用一份现有木料补住受力的支撑，再把家用放妥。"+patient+"仍在睡处，没有跟着搬动，也没有在同一阵得到那次用水照料。木料留在棚架上，眼前安顿好以后，"+worker+"才停下来歇。"
	return null
func decorate(model,focus: Dictionary,event: Dictionary) -> bool:
	if focus.day<10 or focus.day>48 or event.get("target")!="home" or event.get("conditionKind") not in ["care","recovery"] or model._object(event.get("readingVariant")).get("revision")==REV:return false
	for key in ["nodeId","motherCare","motherCrisis","uncleCrisis","uncleBoundary","expeditionSearch","pigeonPickup","neighbourhood","neighbourParcel"]:
		if model.js_truthy(event.get(key)):return false
	var view:=context(model,focus,event)
	if view.is_empty():return false
	var pool: Array=data.CARD[view.patient] if view.canReply else data.UNABLE;var card: Array=pool[int(view.index)%pool.size()]
	if event.conditionKind=="care":
		var own: String=fill(data.SOLO[int(view.ordinal)%data.SOLO.size()],view) if view.alone else fill(card[1],view)
		event.title="独自过眼前这一阵" if view.alone else ("先看眼前这一阵" if not view.canReply and view.index==0 else card[0])
		var physical: String=model.ailment_text(view.patient)
		if physical.is_empty():physical="身体很虚弱"
		var relation: String=data.relationship[JSON.stringify([view.patient,view.helper,view.other,view.alone,view.canReply,int(view.ordinal)%4])]
		var needs: String=data.needs[JSON.stringify([view.water>0,event.choices.any(func(choice):return choice.id=="care_or_repair"),int(view.ordinal)%6])]
		event.intro="\n\n".join([view.patient+"今天仍留在棚里。眼前能看出来的是"+physical+"，这会儿还不能照常做事。",own,relation,needs])
		if view.alone:card=[event.title,own,"今天眼前只有我自己，做一小段就得停。没人接手，也没有谁等着听我说好些了；我仍会嫌自己慢，却不能靠急着做完使东西自己移近。" if view.patient=="罗瑾" else "我听到这段独自安顿的经过，才想到"+say(view.patient)+"在棚里还要自己伸手、自己停下歇息。我回来以后看见的，不是白天每一次勉强动过的样子。"]
		for choice in event.choices:
			var text=close_care(model,view,choice.id)
			if text!=null:choice.closures.default=text;choice.diaries.default=compose_diary(view,card,choice.id)
	else:
		var exchanges: Array=event.choices.filter(func(choice):return choice.id=="exchange")
		if exchanges.is_empty():return false
		var gains: Array=exchanges[0].get("immediateEffects",[]).filter(func(effect):return effect.type=="item_gain" or effect.type=="resource_delta" and effect.amount>0)
		if gains.is_empty():return false
		var gain: Dictionary=gains[0];view.cost=exchanges[0].requiresResources.rice;view.goods=model.TOOL_NAMES[gain.item]+"一份" if gain.type=="item_gain" else "能用的短木三份";view.offerItem=gain.item if gain.type=="item_gain" else null
		var offer: Array=data.RECOVERY[int(view.index)];event.title=offer[0]
		event.intro="\n\n".join([view.patient+"仍需要照料。"+(view.actor+"先靠稳，没有勉强起身迎人。" if view.actor==view.patient else view.actor+"在棚口接过问话，没有叫病者起来招呼。"),fill(offer[1],view),"说定的是米粮"+str(int(view.cost))+"份换"+view.goods+"。"+("家中现存的米足够这一回，换过以后便少下留作开伙的一部分。" if view.water>=0 and model.state.rice>=view.cost else "家里的米眼下不够，来人没有答应赊欠。"),"即使把药物接下，也要照家里实际的病症和用药安排另行处理。来人只是换物，没有替病者诊断，也没保证换过便会好起来。" if gain.type=="item_gain" else "这几份木料若接下，烧火和修棚仍须各自安排。来人没答应替家里搭棚，也没有接下往后的供料。","不换时，对方带自己的东西离开；眼前的照料或歇息仍要接着决定，没有人因拒绝这次交换便欠下另一回。"])
		for choice in event.choices:
			if choice.id=="exchange":
				choice.closures.default=view.actor+"当面点出米粮"+str(int(view.cost))+"份，接过"+view.goods+"。来人将换到的粮收妥，沿通道离开，没有留下下一次必来的约定。"+("药物先放好，病者这时没有因此用过药。" if gain.type=="item_gain" else "木料放在家中，还没有送进火里或顶上支架。")
				var tail: String=("药还放着，我仍想快些好起来，今天却只先把它换到了。" if view.patient=="罗瑾" else "我很想马上从病者的样子看出不同，却不能将刚得的药当成已经用过。") if gain.type=="item_gain" else "我先想到今晚的火，又想到棚上松处；同一份木还得分清用途，不能看见到了家就都算作已经顾上。"
				choice.diaries.default="\n\n".join([access(view),data.RECOVERY_YES[int(view.index)],"今天换来的"+view.goods+"确实收到了，米也已交出去。"+tail,prior_echo(view)].filter(func(text):return not text.is_empty()))
			elif choice.id in ["care_water","quiet"]:
				choice.closures.default=view.actor+"说明这次不换。来人拿回"+view.goods+"离开，没有留物，也没有答应以后补送。"+str(close_care(model,view,choice.id))
				choice.diaries.default="\n\n".join([access(view),data.RECOVERY_NO[int(view.index)],"今天没有换那份东西，它随来人走了。"+choice_echo(view,choice.id),prior_echo(view)].filter(func(text):return not text.is_empty()))
	event.readingVariant=view;return true
