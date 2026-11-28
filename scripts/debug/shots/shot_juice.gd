extends SceneTree
## 손맛 꾸밈(docs/hit_juice.md) 전/후 그림. 첫 맞는 순간 두 프레임 뒤에 찍는다(점광원 0.1초, 붙잡힌 피).
## 돌리기: xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility --fixed-fps 30 -s scripts/debug/shots/shot_juice.gd -- before|after [hill|crypt|quarter|field]
## 그림은 /home/claude/shots/juice_<before|after>_<이름>.png.

const OUT: String = "/home/claude/shots/"
var _hits: int = 0


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(tag: String, name: String) -> void:
	root.get_texture().get_image().save_png(OUT + "juice_%s_%s.png" % [tag, name])
	print("shot ", tag, " ", name)


func _fight(c: Node, rules: Rules, tag: String, name: String, need: int, max_frames: int) -> void:
	_hits = 0
	var cb := func(_e: Enemy, _d: float, _b: bool) -> void: _hits += 1
	rules.enemy_hit.connect(cb)
	var f: int = 0
	while _hits < need and f < max_frames:
		c.set("_want_attack", f % 2 == 0)
		await process_frame
		f += 1
	await _frames(2)
	_save(tag, name)
	rules.enemy_hit.disconnect(cb)


func _init() -> void:
	var args: Array = Array(OS.get_cmdline_user_args())
	var tag: String = String(args[0]) if args.size() > 0 else "after"
	var which: Array = args.slice(1) if args.size() > 1 else ["hill", "crypt", "quarter", "field"]
	if which.has("hill") or which.has("quarter"):
		change_scene_to_file("res://scenes/world/main.tscn")
		await _frames(40)
		var m: Node = current_scene
		var rules: Rules = m.get("rules")
		rules.debug_god = true
		var cam: Node = m.get("_camera")
		cam.set("yaw", deg_to_rad(20.0))
		cam.set("pitch", deg_to_rad(20.0))
		cam.set("third_distance", 7.0)
		rules.give(rules.data.swords[60], 0)
		rules.start_night()
		await _frames(60)
		if which.has("hill"):
			await _fight(m, rules, tag, "hill", 3, 400)
		if which.has("quarter"):
			cam.call("toggle_mode")
			await _frames(20)
			_save(tag, "quarter")
	if which.has("crypt"):
		change_scene_to_file("res://scenes/crypt/crypt.tscn")
		await _frames(20)
		var c: Node = current_scene
		var rules2: Rules = c.get("rules")
		rules2.debug_god = true
		var cam2: Node = c.get("_camera")
		rules2.lord.pos = Vector2(35.0, 51.6)
		rules2.lord.prev_pos = rules2.lord.pos
		rules2.lord.face = -PI / 2.0
		cam2.set("yaw", 0.0)
		cam2.set("pitch", deg_to_rad(24.0))
		cam2.set("third_distance", 9.0)
		await _frames(3)
		cam2.call("snap")
		await _fight(c, rules2, tag, "crypt", 3, 600)
	if which.has("field"):
		change_scene_to_file("res://scenes/field/field.tscn")
		await _frames(30)
		var f2: Node = current_scene
		var rules3: Rules = f2.get("rules")
		rules3.debug_god = true
		rules3.field_clock = 300.0
		var cam3: Node = f2.get("_camera")
		cam3.set("yaw", deg_to_rad(160.0))
		cam3.set("pitch", deg_to_rad(20.0))
		cam3.set("third_distance", 9.0)
		rules3.lord.pos = Vector2(196, 64)
		rules3.lord.prev_pos = rules3.lord.pos
		await _frames(30)
		cam3.call("snap")
		_save(tag, "field_night")
	quit()
