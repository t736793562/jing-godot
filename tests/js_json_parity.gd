extends SceneTree
const Codec=preload("res://scripts/js_json.gd")
func _initialize():
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/js_json_reference.json"));var failed=[]
 for i in range(data.tests.size()):
  var row=data.tests[i];var value: Variant
  if row.kind=="number":
   var stream=StreamPeerBuffer.new();stream.big_endian=false;stream.data_array=row.bits.hex_decode();value=stream.get_double()
  else:value=row.value
  var actual=Codec.encode(value)
  if actual!=row.expected:failed.append({"index":i,"actual":actual,"expected":row.expected})
 print(JSON.stringify({"checks":data.tests.size(),"failed":failed,"full_game":false}));quit(0 if failed.is_empty() else 1)
