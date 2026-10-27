extends SceneTree
const Model=preload("res://scripts/game_model.gd")
func _initialize():
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://data/active_new_game_reference.json"));var failed=[]
 for case in reference.tests:
  var model=Model.new();model.new_game(case.seed)
  if not same_json(model.state,case.state):failed.append(case.seed)
 print(JSON.stringify({"checks":reference.tests.size(),"failed":failed,"full_game":false}));quit(0 if failed.is_empty() else 1)
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
