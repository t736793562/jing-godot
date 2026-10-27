extends RefCounted
const REVIEW="WebR10-ReviewA-D1D14-v1"
static func paragraphs(lines: Array) -> String:
	return "\n\n".join(lines.filter(func(text):return text!=null and text!=""))
static func label(person: Variant) -> String:
	return "娘" if person=="母亲" else ("叔叔" if person=="安仁叔叔" else ("null" if person==null else str(person)))
static func actor(v: Dictionary) -> String:
	return v.actor if v.actor!=null and v.actor!="" else (v.people[0] if not v.people.is_empty() else "留棚的人")
static func food(v: Dictionary) -> String:
	var a: String=v.actor if v.actor!=null and v.actor!="" else "留棚的人"
	if v.recipients.is_empty():return "今天留棚的人都已在外吃过饭。"+("、".join(v.priorHungry)+"仍会想起前一夜没吃上的工夫，今夜却不是又空腹过来。" if not v.priorHungry.is_empty() else "眼下说到的是过去吃饭的记忆，并不是家里又少吃了一顿。")
	var prefix: String="、".join(v.ateOutside)+"今天已经在外吃过；"+"、".join(v.recipients)+"还没有。" if not v.ateOutside.is_empty() else "今天在棚里的人还没有吃上这一顿。"
	if v.meal:return prefix+"今晚已经留出米和烧火的木料，饭尚未做好。"+a+"看过锅边，又把眼前的东西放稳，等真正做成再说。"
	return prefix+"今晚没有安排开伙。"+(a+"的手先向锅边伸了一点，又收回来。" if a in v.recipients else "已经吃过的人也没有替旁边的人说不饿。")+"锅仍在眼前，不会因为再看一次便多出饭来。"
static func text(scene: Dictionary,v: Dictionary,bucket: String,place: String,care: Dictionary) -> String:
	var a:=actor(v);var moment: String="";var tail: String=""
	if bucket=="care":
		moment=care[JSON.stringify([v.patient,v.helper,v.alone,v.patientCanReply,int(scene.focus)])]
		tail="今晚原先安排的照料还要接着做。眼前只是歇过这一会儿，不是药已经用过或伤病已经好了。" if v.treatment!="none" else "今晚没有另添治疗，先容这点安静留着，不用一句醒来就好催人睡下。"
	elif bucket=="absence":
		moment=(v.absent+"今晚不在棚里。" if v.absent!=null and v.absent!="" else "家里有人此刻不在这里。")+(a+"听完那阵声音，重新顾自己的睡处，没有同一个不在场的人说话。" if v.alone else (v.talk[0]+"朝棚外看，"+v.talk[1]+"只说没有看见来人，没有接着替对方猜一个下落。" if v.talk.size()>=2 else a+"听过外面的声音，旁边没有另一个能接话的人。这一会儿没有新的口信。"))
		tail="这一段夜话只到眼前这一阵动静。此后若真有人回来或送到消息，再从那次实际见闻接着说。"
	elif bucket=="damp":
		moment=(a+"将衣物从贴潮的地方收近些。" if not v.talk.is_empty() else "棚里的潮气仍在，身子却难以挪动，衣物贴着边缘的凉意没有被一段说话抹掉。")+("能挪的地方只在自己的睡处，没有谁从外面回来腾位置。" if v.alone else ("旁边的人也慢慢收近一点，彼此先认清位置，没叫病弱的人起身撑棚。" if v.talk.size()>=2 else "其余家人也难以动身，能够应付的人只顾眼前，不把无人接手的事算作已经完成。"))
		tail="今晚用火的木料已经留出，仍按原先的安排烧。挪动睡处没有再添一份火，也没有换掉原来的支撑。" if v.fire>0 else "今晚没有安排生火。东西挪过以后，原来的支架仍在，没有因此得到新的木料。"
	else:
		moment=food(v);tail="旁边没有应话的人，这点工夫就自己慢慢过，不向一个空着的位置递出不存在的饭。" if v.alone else "话停下来以后，各人仍照眼前的身体歇着，没有替旁人答应再忍几顿。"
	var body: Array=scene.body.duplicate()
	if bucket=="care" and v.helper==null:
		if scene.focus==1:
			body[1]="反复觉得自己应该好一点，身体却没有照着这个念头改变。难受的时候，连说清一句话也要费力，不能回答的那一部分就先留着。";body[2]="这一会儿先不勉强应声。身旁没有能搭手的人，做不到的动作便停下来，没有谁因为夜深了就忽然有了更多力气。"
		if scene.focus==2:
			body[1]="白天习惯自己放妥的东西，眼下也只能暂且搁着。身边没有能替着接手的人，那一小段距离就得等身子缓过来一些再试。";body[2]="这一夜不必一气把什么都收完。东西仍在原处，还没有放到想放的位置，就不能先说已经收好了。"
	return paragraphs([place,body[0],moment,body[1],body[2],tail])
static func summary(p: Dictionary) -> String:
	var v: Dictionary=p.context
	if p.bucket=="care":return label(v.patient if v.patient!=null else v.actor)+"昨夜独自在棚，身子难受，这一阵没有新来的人照料。" if v.alone else label(v.patient)+"昨夜歇得不稳。"+("病着的人只说明眼下需要的一小步，"+label(v.helper)+"搭手后没有再催问。" if v.patientCanReply and v.helper!=null else "没有强迫病着的人讲完经过，也没有把安静下来当作已经痊愈。")
	if p.bucket=="absence":return label(v.absent if v.absent!=null else "在外的人")+"在那段夜话时没有到棚里；那一阵脚步没有带来新口信。"
	if p.bucket=="damp":return "夜话时棚内仍潮湿。"+("留棚的人只挪了眼前衣物与睡处，" if not v.talk.is_empty() else "留棚的人当时很难挪动，")+"没有添料整修棚架。"
	return "那一夜留棚的人都已经在外吃过，谈起的是先前空腹的记忆。" if v.recipients.is_empty() else ("夜话时已经安排了开伙，饭还没做好；那一刻仍在等饭。" if v.meal else "夜话时没有安排开伙，"+"、".join(v.recipients.map(label))+"当时尚未吃上这一顿。")
static func closure(p: Dictionary) -> String:
	var v: Dictionary=p.context;var a:=actor(v)
	match p.bucket:
		"care":return (label(v.patient if v.patient!=null else a)+"停下来歇过一阵，手里的小事没有勉强做完。" if v.alone else label(v.patient)+"把话说到这里，"+(label(v.helper)+"没有再催问，也没有把这点安顿说成身体已经好了。" if v.helper!=null else "没有人逼着把没说完的事补齐。")) if v.patientCanReply else label(v.patient if v.patient!=null else a)+"仍没能清楚应话。身旁没有继续催促，也没有替他答一句已经好些了。"
		"absence":return "那阵声音过去，没有停下来报出一个人的去处。睡处仍照眼前安排，这一会儿没有新的口信。"
		"damp":return a+"把眼前能挪的部分放稳，便不再拆动棚边。睡处还是这些位置，支撑也没有添过料。" if not v.talk.is_empty() else "棚里渐渐少了声响，原来贴潮的地方却仍在。这一阵没有发生整修，也没有人从外面回来代劳。"
		"hunger":return "今夜已经吃过的饭照实记着，前一夜的记忆没有变成又一次没吃上。" if v.recipients.is_empty() else ("锅边的东西放妥了，饭还得接着做。没人因为等得久，就提前说今晚已经没饭。" if v.meal else "今晚没有另添一顿饭。话先停在这里，不拿忍住不说当作肚子已经不饿。")
	return ""
static func diary(p: Dictionary,scene: Dictionary) -> String:
	var v: Dictionary=p.context;var text: String=""
	if p.bucket=="care":
		if v.patient=="罗瑾":text="昨夜我想换个姿势，身子却不肯照平日那样动。"+(label(v.helper)+"在近处，没有催我一次讲完，只照我当时能说明的一点搭手。" if v.helper!=null else "旁边没有一个人可以接手，我只能把动作放慢。")
		else:
			var details: Array=["想换个姿势，却在中间停了几回。我先看清要搭哪一处，不再急着催这一段做完。","说先歇这一会儿，不必每动一下便问好些没有。我没有再接着问同一句话。","仍留意手边没放妥的东西，说明想放在哪里。我才知道自己急着收好的办法，未必就是需要的那一步。","说今晚先安静待着。我没有再找话催着讲白天的事，也没有劝一声便以为能马上睡着。"]
			text="昨夜"+label(v.patient)+"歇得不稳。"+(details[int(scene.focus)] if v.patientCanReply else "我没听清应声，便没有把未说的话替着补上。")
	elif p.bucket=="absence":text="昨夜"+label(v.absent if v.absent!=null else "在外的人")+"不在棚里。那一阵脚步没有停下，听不清的招呼也没有成一条新消息。"+("我独自守着眼前这一点地方。" if v.alone else "我听过以后又望了一眼棚口，没有替家里添一个自己猜的答案。")
	elif p.bucket=="damp":text="昨夜棚里还潮。"+("我自己避开贴湿的一边，膝盖收得比先前近。" if v.alone else "我们挪动身边的东西，想多留一点能躺的地方，结果谁也不能完全伸开。")+"原来的支撑没有动，衣物收近了，也仍知道那一边湿着。"
	elif "罗瑾" in v.ateOutside:text="我昨夜已经在外吃过饭。"+("回到棚里，"+"、".join(v.recipients.map(label))+"还没有吃上，我不能替他们说再等一会儿没什么。" if not v.recipients.is_empty() else "想起的是先前饿过的一顿，不把昨晚也说成空腹。")
	else:text="昨夜我还在等饭。米和柴留出了，锅边也收妥了，可没有端到手边以前，这一顿便还没真正吃上。" if v.meal else "昨夜没有开伙。我看过锅边，又将手收回来，眼前没有多出来的一顿饭。"
	var hook: String=scene.hook
	if p.get("editorialRevision")==REVIEW and p.bucket=="care" and scene.focus==1 and v.patientCanReply and not v.alone:hook="我已经说想先歇一会儿，便不再勉强多说。眼下能说明的只有这一点，不必为了叫人放心，再答一句已经没事。" if v.patient=="罗瑾" else label(v.patient)+"已经说想先歇一会儿，我却还想再问。把到了嘴边的那句话收住，才听见棚外其余细小的动静。"
	if p.bucket=="care" and scene.focus==3 and v.patient!="罗瑾":hook="那阵脚步过去以后，我没有再问睡着没有。"+label(v.patient)+"仍在身边歇着，不必为了让我放心再回答。"
	if v.alone and p.bucket=="care":hook=["我原想一下挪过去，身子却让我停了几回。等真正躺稳，也没有人催我把下一件事做完。","我没有再试着答一句没事。身子还是难受，先停下来的，只是反复催自己的那个念头。","东西还放在原处，我看了几眼，终于没有勉强伸手。没有做完的这一点，就留到自己真能动的时候。","棚外的脚步过去以后，我仍没有睡着，便先闭着眼歇，不再逼自己立刻睡熟。"][int(scene.focus)]
	if v.alone and p.bucket=="hunger" and p.id=="hunger-answer":hook="昨夜没有另一个人接话。我也没逼自己答一句不饿，先把难受留在它真正有的地方。"
	return paragraphs([text,hook])
