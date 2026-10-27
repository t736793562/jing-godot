extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var script = load("res://scripts/layout_view.gd")
	if script == null:quit(1);return
	var view = script.new()
	root.add_child(view)
	await process_frame
	var passed := 0
	var blocked := 0
	for i in range(view.layouts.size()):
		if view.layouts[i]["ready_for_visual_check"]:
			if not view.select_layout(i):quit(1);return
			passed += 1
		else:blocked += 1
	await process_frame
	print(JSON.stringify({"structured_layouts":passed,"unsupported_layouts":blocked,"resource_errors":view.load_errors,"visual_test":false,"gameplay_connected":false}))
	quit(0 if view.load_errors.is_empty() else 1)
