extends SceneTree
## 언덕 판 점검(docs/sword_hill.md): 검의 숲(낮), 밤에도 꽂힌 검, 발검, 주인의 잔영.
## 돌리기: xvfb-run -a godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s scripts/debug/shots/shot_hill.gd
## 그림은 /home/claude/shots/hill_<이름>.png.

const OUT: String = "/home/claude/shots/"


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(OUT + "hill_" + name + ".png")
	print("shot ", name)


func _init() -> void:
	change_scene_to_file("res://scenes/world/main.tscn")
	await _wait(40)
	var m: Node = current_scene
	var rules: Rules = m.get("rules")
	rules.debug_god = true
	var cam: Node = m.get("_camera")
	cam.set("yaw", deg_to_rad(30.0))
	await _wait(30)
	_shot("day")
	# 넓게: 싸움터와 둘레의 검 숲
	cam.set("third_distance", 26.0)
	cam.set("pitch", deg_to_rad(24.0))
	await _wait(40)
	_shot("forest")
	cam.set("third_distance", 8.0)
	cam.set("pitch", deg_to_rad(22.0))
	# 밤: 쥔 검 하나, 주인의 잔영 하나(가짜 기록), 발검
	rules.give(rules.data.swords[40], 0)
	rules.start_night()
	await _wait(20)
	var g: Array = []
	for t in 150:
		g.append_array([rules.lord.pos.x + sin(t * 0.08) * 2.0, rules.lord.pos.y + 1.5, t * 0.1, 1.0 if t % 25 == 24 else 0.0])
	rules._spawn_ghost({"id": rules.data.swords[120].id, "run": 1, "zone": 3, "kills": 40, "ghost": g}, rules.lord.pos + Vector2(1.5, 1.0))
	var h := rules.nearest_hilt(100.0)
	rules.lord.pos = h.pos + Vector2(0.3, 0)
	rules.lord.prev_pos = rules.lord.pos
	await _wait(30)
	_shot("night")
	var i := LordInput.new()
	i.pull = true
	rules.step(i)
	await _wait(6)
	_shot("draw")
	quit()
