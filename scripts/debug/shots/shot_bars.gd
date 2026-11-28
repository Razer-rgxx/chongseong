extends SceneTree
## 체력 막대(2026-11-21) 확인용: 언덕 밤에 늑대·망령·거인·정예를 앞에 세우고 체력을 깎는다. 내 체력도 1/4로.
## 돌리기: xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s scripts/debug/shots/shot_bars.gd
## 그림은 /home/claude/shots/bars.png.


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	change_scene_to_file("res://scenes/world/main.tscn")
	await _wait(40)
	var m: Node = current_scene
	var rules: Rules = m.get("rules")
	rules.debug_god = true
	var cam: Node = m.get("_camera")
	rules.start_night()
	await _wait(5)
	var p: Vector2 = rules.lord.pos
	var foes: Array = []
	for k in [[&"wolf", Vector2(-2.0, -3.0), 0.7], [&"wraith", Vector2(0.0, -3.5), 0.35], [&"giant", Vector2(2.6, -4.0), 0.55], [&"wraith", Vector2(-0.8, -5.5), 0.85]]:
		var e: Enemy = rules.spawn_at(k[0], p + k[1])
		foes.append([e, k[2]])
	(foes[3][0] as Enemy).elite = true
	cam.set("yaw", 0.0)
	cam.set("pitch", deg_to_rad(18.0))
	cam.set("third_distance", 9.0)
	await _wait(10)
	rules.freeze = 1000000
	for f in foes:
		var e: Enemy = f[0]
		e.hp = e.max_hp * float(f[1])
	await _wait(6)
	rules.lord.hp = rules.max_hp() * 0.25   # 내 체력 막대: 깎인 몫이 옅게 남는지
	await _wait(3)
	root.get_texture().get_image().save_png("/home/claude/shots/bars.png")
	print("shot bars")
	quit()
