extends SceneTree
## 미래 구역 적 모델(FutureEnemyArt, 2026-11-25 사이버펑크풍)과 적 머리 위 막대(enemy_bar.gdshader) 확인 그림.
## 드론·정예 드론·사수·금고지기를 미래 구역 처음 자리 앞에 세우고 체력을 깎는다. /home/claude/shots/future_foes.png, future_foes_near.png.
## 돌리기: xvfb-run -a godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1600x900 -s scripts/debug/shots/shot_future_foes.gd


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("/home/claude/shots")
	change_scene_to_file("res://scenes/future/future.tscn")
	await _wait(40)
	var m: Node = current_scene
	var rules: Rules = m.get("rules")
	rules.debug_god = true
	var p: Vector2 = rules.lord.pos
	var foes: Array = []
	for k in [[&"drone", Vector2(-2.2, -3.0), 0.7], [&"husk", Vector2(-0.6, -3.6), 0.45], [&"guardian", Vector2(1.6, -4.4), 1.0], [&"drone", Vector2(3.4, -3.0), 0.3], [&"husk", Vector2(-3.4, -4.6), 0.85]]:
		var e: Enemy = rules.spawn_at(k[0], p + k[1])
		foes.append([e, k[2]])
	(foes[3][0] as Enemy).elite = true
	await _wait(6)
	rules.freeze = 1000000
	for f in foes:
		var e: Enemy = f[0]
		e.face = Vector2(0.0, 1.0)
		e.hp = e.max_hp * float(f[1]) - 0.01
	await _wait(4)
	var cam := Camera3D.new()
	cam.fov = 50.0
	m.add_child(cam)
	var C: float = Grid.CELL
	var lp := Grid.cells_to_world(p)
	cam.look_at_from_position(lp + Vector3(0.0, 2.4, 1.2 * C), lp + Vector3(0.0, 1.6, -4.0 * C))
	cam.make_current()
	await _wait(4)
	root.get_texture().get_image().save_png("/home/claude/shots/future_foes.png")
	print("shot future_foes")
	cam.look_at_from_position(lp + Vector3(-1.0 * C, 1.6, -1.6 * C), lp + Vector3(-1.2 * C, 1.1, -3.4 * C))
	await _wait(4)
	root.get_texture().get_image().save_png("/home/claude/shots/future_foes_near.png")
	print("shot future_foes_near")
	quit()
