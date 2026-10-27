extends SceneTree
func _initialize():
 for x in [1.0,0.9,0.9+0.04,float(123456789)/4294967296.0,1e-7]:print(JSON.stringify({"ordinary":JSON.stringify(x),"precise":JSON.stringify(x,"",false,true),"str":str(x),"bits":var_to_bytes(x).hex_encode()}))
 quit()
