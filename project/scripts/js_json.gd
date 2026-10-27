extends RefCounted
# Match donor JSON.stringify for pure save-data values and deterministic contract hashes.
# Native persistence must retain float64 exactly; ordinary Godot JSON parsing is not lossless.
static func encode(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:return "null"
		TYPE_BOOL:return "true" if value else "false"
		TYPE_INT:return str(value)
		TYPE_FLOAT:return number(value)
		TYPE_STRING:return JSON.stringify(value)
		TYPE_ARRAY:
			var items: PackedStringArray=[]
			for item in value:items.append(encode(item))
			return "["+",".join(items)+"]"
		TYPE_DICTIONARY:
			var indices: Array=[];var others: Array=[]
			for key in value:
				var text:=str(key)
				if text.is_valid_int() and str(text.to_int())==text and text.to_int()>=0 and text.to_int()<4294967295:indices.append(text)
				else:others.append(key)
			indices.sort_custom(func(a,b):return a.to_int()<b.to_int())
			var fields: PackedStringArray=[]
			for key in indices+others:fields.append(JSON.stringify(str(key))+":"+encode(value[key]))
			return "{"+",".join(fields)+"}"
	push_error("Non-data value cannot enter a native save contract")
	return "null"
static var number_cache: Dictionary={}
static func _mul_small(text: String,factor: int) -> String:
	var carry:=0;var out: PackedStringArray=[]
	for i in range(text.length()-1,-1,-1):
		var product: int=(text.unicode_at(i)-48)*factor+carry
		out.append(str(product%10));carry=int(product/10)
	while carry>0:out.append(str(carry%10));carry=int(carry/10)
	out.reverse();return "".join(out)
static func _binary_decimal(coefficient: int,exponent: int) -> Dictionary:
	var digits:=str(coefficient);var scale:=0
	if exponent<0:
		scale=-exponent
		for _i in range(-exponent):digits=_mul_small(digits,5)
	else:
		for _i in range(exponent):digits=_mul_small(digits,2)
	return _trim_decimal(digits,scale)
static func _trim_decimal(digits: String,scale: int) -> Dictionary:
	while digits.length()>1 and digits.ends_with("0"):digits=digits.left(-1);scale-=1
	return {"digits":digits,"scale":scale}
static func _compare(a: Dictionary,b: Dictionary) -> int:
	var ao: int=a.digits.length()-a.scale;var bo: int=b.digits.length()-b.scale
	if ao!=bo:return -1 if ao<bo else 1
	var width: int=maxi(a.digits.length(),b.digits.length())
	var aa: String=a.digits+"0".repeat(width-a.digits.length());var bb: String=b.digits+"0".repeat(width-b.digits.length())
	return 0 if aa==bb else (-1 if aa<bb else 1)
static func _format_decimal(value: Dictionary) -> String:
	var digits: String=value.digits;var exponent: int=digits.length()-value.scale-1
	if exponent>=-6 and exponent<21:
		var point:=exponent+1
		if point<=0:return "0."+"0".repeat(-point)+digits
		if point>=digits.length():return digits+"0".repeat(point-digits.length())
		return digits.substr(0,point)+"."+digits.substr(point)
	var mantissa:=digits.left(1)+("."+digits.substr(1) if digits.length()>1 else "")
	return mantissa+"e"+("+" if exponent>=0 else "-")+str(absi(exponent))
static func number(value: float) -> String:
	if not is_finite(value):return "null"
	if value==0:return "0"
	if floor(value)==value and absf(value)<=9007199254740991.0:return str(int(value))
	var stream:=StreamPeerBuffer.new();stream.big_endian=false;stream.put_double(value)
	var cache_key:=stream.data_array.hex_encode()
	if number_cache.has(cache_key):return number_cache[cache_key]
	stream.seek(0);var low:=stream.get_u32();var high:=stream.get_u32()
	var negative: bool=(high&0x80000000)!=0;var biased: int=(high>>20)&0x7ff
	var fraction: int=((high&0xfffff)<<32)|low
	var mantissa: int=fraction+(4503599627370496 if biased>0 else 0)
	var exponent: int=biased-1023-52 if biased>0 else -1074
	var exact:=_binary_decimal(mantissa,exponent)
	var lower:=_binary_decimal(mantissa*4-(1 if fraction==0 and biased>1 else 2),exponent-2)
	var upper:=_binary_decimal(mantissa*4+2,exponent-2)
	var even: bool=(mantissa&1)==0
	for length in range(1,18):
		var candidate_scale: int=exact.scale-(exact.digits.length()-length)
		if exact.digits.length()<=length:
			var exact_text: String=("-" if negative else "")+_format_decimal(exact)
			number_cache[cache_key]=exact_text;return exact_text
		var prefix: int=exact.digits.substr(0,length).to_int()
		var remainder: String=exact.digits.substr(length)
		var round_up: bool=remainder.unicode_at(0)>53 or (remainder.unicode_at(0)==53 and (remainder.substr(1).replace("0","")!="" or prefix%2==1))
		var options: Array=[prefix+1,prefix] if round_up else [prefix,prefix+1]
		for coefficient in options:
			var candidate:=_trim_decimal(str(coefficient),candidate_scale)
			var low_cmp:=_compare(candidate,lower);var high_cmp:=_compare(candidate,upper)
			if (low_cmp>0 or (low_cmp==0 and even)) and (high_cmp<0 or (high_cmp==0 and even)):
				var result: String=("-" if negative else "")+_format_decimal(candidate)
				number_cache[cache_key]=result;return result
	push_error("No shortest float64 representation found")
	return "null"
