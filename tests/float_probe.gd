extends SceneTree
func _initialize():
 var a: float=0.9;a+=0.04
 var b=JSON.parse_string("0.9400000000000001")
 var c=JSON.parse_string("0.94")
 print({"native":var_to_bytes(a).hex_encode(),"reference":var_to_bytes(b).hex_encode(),"short":var_to_bytes(c).hex_encode(),"equal":a==b});quit()
