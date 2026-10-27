extends RefCounted
const MASK := 0xffffffff
var state: int = 0
static func hash_seed(value: String) -> int:
	var h: int = 2166136261
	for index in range(value.length()):
		var code := value.unicode_at(index)
		# JS for-of visits Unicode code points; charCodeAt(0) takes the leading UTF-16 unit.
		if code > 0xffff:code = 0xd800 + ((code - 0x10000) >> 10)
		h = ((h ^ code) * 16777619) & MASK
	return h
func seed_with(value: String) -> void:
	state=hash_seed(value)
func next_float() -> float:
	var x := state & MASK
	x=(x ^ (x<<13)) & MASK
	x=(x ^ (x>>17)) & MASK
	x=(x ^ (x<<5)) & MASK
	state=x
	return float(state%1000000)/1000000.0
func integer(minimum: int, maximum: int) -> int:
	return minimum+int(floor(next_float()*(maximum-minimum+1)))
static func weather_plan(seed_value: String, catalog: Array) -> Array:
	var generator = new()
	generator.seed_with(seed_value+"-weather")
	var plan: Array=[]
	for day in range(50):
		var weights: Array[float]=[]
		var total: float=0.0
		for weather in catalog:
			var weight: float=float(weather["weight"])
			if day>=9 and weather["id"] in ["sleet","snow","blizzard","hail"]:weight*=1.35
			if not plan.is_empty() and plan[-1].get("severe",false) and weather.get("severe",false):weight=0
			weights.append(weight)
			total+=weight
		var roll: float=generator.next_float()*total
		var chosen: Dictionary=catalog[0]
		for i in range(catalog.size()):
			roll-=weights[i]
			if roll<=0:
				chosen=catalog[i]
				break
		plan.append(chosen.duplicate(true))
	return plan
