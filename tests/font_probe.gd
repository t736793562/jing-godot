extends SceneTree
func _initialize() -> void:
	var f:=FontFile.new()
	f.data=FileAccess.get_file_as_bytes("res://fonts/5d9c31a059600193c9d7968a998bde886ccdc77e934006ad243b41794c496a7d.ttc")
	var variation:=FontVariation.new()
	variation.base_font=f
	var properties: Array=[]
	for p in variation.get_property_list():
		if "face" in p.name:properties.append(p.name)
	print(JSON.stringify({"default_name":f.get_font_name(),"face_properties":properties}))
	for i in range(5):
		variation.variation_face_index=i
		print(str(i)+":"+variation.get_font_name())
	quit()
