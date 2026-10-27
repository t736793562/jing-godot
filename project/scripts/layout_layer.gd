extends Control
var current: Dictionary = {}
var textures: Dictionary = {}
var fonts: Dictionary = {}
var coordinate_origin := Vector2.ZERO
const FONT_REG = "res://fonts/5d9c31a059600193c9d7968a998bde886ccdc77e934006ad243b41794c496a7d.ttc"
const FONT_BOLD = "res://fonts/1505ee3b9c0890fae6302ee0e9c6fd74d690f4a55a6ace1d9944f3f6352d622d.ttc"
const FONT_SANS = "res://fonts/b76b0433203017ca80401b2ee0dd69350349871c4b19d504c34dbdd80541690a.ttc"
func _draw() -> void:
	if current.is_empty():return
	var canvas := Vector2(float(current["canvas"][0]),float(current["canvas"][1]))
	draw_set_transform(-coordinate_origin)
	for op in current["operations"]:
		match op["type"]:
			"image":
				if textures.has(op["path"]):
					var b: Array = op["box"]
					var brightness := float(op.get("brightness",1))
					var tint := Color(brightness,brightness,brightness,1.0)
					if op.has("shadow"):
						var effect: Dictionary=op["shadow"]
						var padding:=float(effect["blur"])*3.0
						draw_texture_rect(textures[op["path"]],Rect2(b[0]+effect["offset"][0]-padding,b[1]+effect["offset"][1]-padding,b[2]+2*padding,b[3]+2*padding),false,tint)
					elif op.has("region"):
						var region: Array = op["region"]
						draw_texture_rect_region(textures[op["path"]],Rect2(b[0],b[1],b[2],b[3]),Rect2(region[0],region[1],region[2],region[3]),tint)
					else:draw_texture_rect(textures[op["path"]],Rect2(b[0],b[1],b[2],b[3]),false,tint)
			"text":
				var path: String = FONT_SANS if "Sans" in op["family"] else (FONT_BOLD if op["bold"] else FONT_REG)
				path = str(op.get("font_path",path))
				var face:=int(op.get("font_face",2 if "CJK SC" in op["family"] else 0))
				var font: Font = fonts[path+"#"+str(face)]
				var pt := Vector2(op["xy"][0],op["xy"][1])
				var font_size := int(ceil(float(op["size"])))
				var text_scale := float(op["size"])/float(font_size)
				var width := font.get_string_size(op["text"],HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*text_scale
				if op["anchor"] == "middle":pt.x -= width/2.0
				elif op["anchor"] == "end":pt.x -= width
				draw_set_transform(pt-coordinate_origin,0,Vector2.ONE*text_scale)
				draw_string(font,Vector2.ZERO,op["text"],HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color.from_string(op["color"],Color.BLACK))
				draw_set_transform(-coordinate_origin)
			"polyline":
				var points := PackedVector2Array()
				for xy in op["points"]:points.append(Vector2(xy[0],xy[1]))
				if op["closed"] and op["fill"]!="none":draw_colored_polygon(points,Color.from_string(op["fill"],Color.TRANSPARENT))
				if op["closed"] and not points.is_empty():points.append(points[0])
				if op["color"]!="none" and points.size()>1:
					var color:=Color.from_string(op["color"],Color.BLACK)
					draw_polyline(points,color,float(op["width"]),true)
					if op.get("round_caps",false):
						for pt in points:draw_circle(pt,float(op["width"])/2.0,color)
			"line":
				var p: Array = op["points"]
				draw_line(Vector2(p[0],p[1]),Vector2(p[2],p[3]),Color.from_string(op["color"],Color.BLACK),float(op["width"]),true)
			"ellipse":
				var b: Array = op["box"]
				var points := PackedVector2Array()
				for k in range(65):
					var angle := TAU*float(k)/64.0
					points.append(Vector2(b[0]+b[2]/2.0+cos(angle)*b[2]/2.0,b[1]+b[3]/2.0+sin(angle)*b[3]/2.0))
				if op["color"]!="none":draw_colored_polygon(points,Color.from_string(op["color"],Color.TRANSPARENT))
				if op["stroke"]!="none":draw_polyline(points,Color.from_string(op["stroke"],Color.BLACK),float(op["width"]),true)
			"rect":
				var b: Array = op["box"]
				var rect := Rect2(b[0],b[1],b[2],b[3])
				var style := StyleBoxFlat.new()
				style.bg_color = Color.TRANSPARENT if op["color"]=="none" else Color.from_string(op["color"],Color.TRANSPARENT)
				style.set_corner_radius_all(int(op["rx"]))
				if op["stroke"]!="none":
					style.border_color=Color.from_string(op["stroke"],Color.BLACK)
					style.set_border_width_all(int(op["width"]))
				draw_style_box(style,rect)
	draw_set_transform(Vector2.ZERO)
