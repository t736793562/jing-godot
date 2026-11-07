extends Control
# Native component layout inspection stage. Not a playable-game completion claim.
var layouts: Array = []
var current: Dictionary = {}
var textures: Dictionary = {}
var fonts: Dictionary = {}
var current_index := 0
var holder: Control
const Layer = preload("res://scripts/layout_layer.gd")
const FADE_SHADER = "shader_type canvas_item; uniform float fade_start=0.78; void fragment(){ COLOR.a *= 1.0-clamp((UV.y-fade_start)/(1.0-fade_start),0.0,1.0); }"
var load_errors: Array[String] = []
const FONT_REG = "res://fonts/5d9c31a059600193c9d7968a998bde886ccdc77e934006ad243b41794c496a7d.ttc"
const FONT_BOLD = "res://fonts/1505ee3b9c0890fae6302ee0e9c6fd74d690f4a55a6ace1d9944f3f6352d622d.ttc"
const FONT_SANS = "res://fonts/b76b0433203017ca80401b2ee0dd69350349871c4b19d504c34dbdd80541690a.ttc"
func _ready() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/all_layouts.json"))
	if not parsed is Array:
		load_errors.append("layout data unavailable")
		return
	layouts = parsed
	# The packaged UI12 operations retain SVG viewBox coordinates (1672 x 941).
	# Its 1920 x 1080 width/height are output pixels, not the operation canvas.
	for layout in layouts:
		if layout.id=="SVG_jing_ui12_reconstruction_20261024_UI12_reconstruction_v04":
			layout.canvas=[1672,941]
		elif layout.id in ["SVG_content_states_day49","SVG_content_states_normal_day","SVG_content_states_long_top","SVG_content_states_long_middle","SVG_content_states_long_bottom","SVG_content_states_short_text","SVG_content_states_arrival_day"]:
			# These seven samples share a 1672 x 982 SVG viewBox.
			layout.canvas=[1672,982]
	for path in [FONT_REG,FONT_BOLD,FONT_SANS,"res://fonts/57f73e11f51999432bf7ab22ce55b6f945d5eca1bf824404cfa9ec2e3718c84e.ttf"]:
		var font: FontFile = load(path)
		fonts[path] = font
		fonts[path+"#0"] = font
		if path.ends_with(".ttc"):
			var chinese := FontVariation.new()
			chinese.base_font=font
			chinese.variation_face_index=2
			fonts[path+"#2"]=chinese
	holder=Control.new()
	add_child(holder)
	select_layout(0)
	resized.connect(_resize_layout)
func select_layout(index: int) -> bool:
	if index < 0 or index >= layouts.size(): return false
	if not layouts[index].get("ready_for_visual_check",false): return false
	current_index = index
	return present_layout(layouts[index])
func present_layout(layout: Dictionary) -> bool:
	current = layout
	for op in current["operations"]:
		if op["type"] == "image" and not textures.has(op["path"]):
			var texture=load(op["path"])
			if not texture is Texture2D:
				load_errors.append("missing component: " + str(op["path"]))
			else:textures[op["path"]]=texture
	for old in holder.get_children():
		holder.remove_child(old)
		old.free()
	for op in current["operations"]:
		var layer = Layer.new()
		layer.current={"canvas":current["canvas"],"operations":[op]}
		layer.textures=textures
		layer.fonts=fonts
		layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
		layer.modulate.a=float(op.get("opacity",1))
		if op.has("clip"):
			var clip: Array=op["clip"]
			layer.position=Vector2(clip[0],clip[1])
			layer.size=Vector2(clip[2],clip[3])
			layer.coordinate_origin=layer.position
			layer.clip_contents=true
		else:layer.size=Vector2(current["canvas"][0],current["canvas"][1])
		if op["type"]=="image" and (op.has("fade_start") or op.has("fade_bottom_px") or op.has("fade_edge_px") or op.has("alpha_from_rgb") or op.has("shadow")):
			var shader := load("res://scripts/component_effects.gdshader")
			var mat := ShaderMaterial.new()
			mat.shader=shader
			var texture: Texture2D = textures[op["path"]]
			var region := Vector4(0,0,1,1)
			if op.has("region"):
				var src: Array=op["region"]
				region=Vector4(src[0]/texture.get_width(),src[1]/texture.get_height(),src[2]/texture.get_width(),src[3]/texture.get_height())
			var b: Array=op["box"]
			mat.set_shader_parameter("sample_region",region)
			mat.set_shader_parameter("component_size",Vector2(b[2],b[3]))
			for key in ["fade_start","fade_bottom_px","fade_edge_px"]:
				if op.has(key):mat.set_shader_parameter(key,float(op[key]))
			if op.has("alpha_from_rgb"):
				mat.set_shader_parameter("alpha_from_rgb",true)
				mat.set_shader_parameter("alpha_subtract",float(op["alpha_from_rgb"]["subtract"]))
				mat.set_shader_parameter("alpha_multiply",float(op["alpha_from_rgb"]["multiply"]))
			if op.has("shadow"):
				var effect: Dictionary=op["shadow"]
				var padding:=float(effect["blur"])*3.0
				var rgb: Array=effect["rgb"]
				mat.set_shader_parameter("is_shadow",true)
				mat.set_shader_parameter("padding",padding)
				mat.set_shader_parameter("blur_sigma",float(effect["blur"]))
				mat.set_shader_parameter("output_size",Vector2(b[2]+2*padding,b[3]+2*padding))
				mat.set_shader_parameter("shadow_color",Vector4(rgb[0]/255.0,rgb[1]/255.0,rgb[2]/255.0,float(effect["opacity"])))
			layer.material=mat
		holder.add_child(layer)
	_resize_layout()
	return true
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_F6,KEY_F7]:
		var delta := 1 if event.keycode == KEY_F6 else -1
		for step in range(1,layouts.size()+1):
			var index := posmod(current_index+delta*step,layouts.size())
			if select_layout(index): break
		get_viewport().set_input_as_handled()

func _resize_layout() -> void:
	if current.is_empty() or holder==null:return
	var canvas:=Vector2(current["canvas"][0],current["canvas"][1])
	var factor:=minf(size.x/canvas.x,size.y/canvas.y)
	holder.size=canvas
	holder.scale=Vector2.ONE*factor
	holder.position=(size-canvas*factor)/2.0
