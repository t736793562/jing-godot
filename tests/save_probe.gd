extends SceneTree
func _initialize():
 var m=preload("res://scripts/game_model.gd").new();m.new_game("save")
 var s=preload("res://scripts/native_save.gd").new()
 m.state.memory.numeric_probe=[0.9+0.04,-0.0,1.0,1,0.0000001,{"2.0":true,"2":false}]
 print("valid:",s.valid_state(m.state))
 print(s.encode(m.state).length()," err ",s.error)
 print(s.encode_value(m.state.memory))
 quit()
