extends SceneTree
## 넓힌 과거(판타지 월드, PastWorld) 확인 그림. 과거 장면을 그대로 열고 영주를 땅마다 옮겨(빛과 안개가 섞이게) 찍는다.
##   bones: 거인의 뼈 들, lake: 수정 호수, ash: 잿불 능선의 봉인 고리, beast: 깨어난 짐승, smith: 첫 대장간 곁 혼, sky: 위에서 본 전체.
## /home/claude/shots/past_<자리>.png. 돌리기:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility --fixed-fps 30 --resolution 1280x720 -s scripts/debug/shots/shot_past_world.gd

const OUT: String = "/home/claude/shots/"


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	change_scene_to_file("res://scenes/past/past.tscn")
	await _wait(40)
	var m: Node = current_scene
	var rules: Rules = m.get("rules")
	rules.debug_god = true
	(m.get("_camera") as Node).set("motion_blur", 0.0)   # 카메라를 옮겨 찍으니 번짐 판은 끈다
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.far = 900.0
	m.add_child(cam)
	cam.make_current()
	var C: float = Grid.CELL
	var shots: Array = [
		["ship", Vector2(112, 62), Vector3(108.0 * C, 4.0, 60.0 * C), Vector3(130.0 * C, 18.0, 80.0 * C)],
		["ship_side", Vector2(150, 100), Vector3(150.0 * C, 22.0, 108.0 * C), Vector3(130.0 * C, 22.0, 80.0 * C)],
		["captain", Vector2(124, 61), Vector3(124.0 * C + 1.2, 2.0, 64.6 * C - 3.2), Vector3(124.0 * C, 1.4, 64.6 * C)],
		["captain_hat", Vector2(124, 61), Vector3(124.0 * C + 0.3, 1.9, 64.6 * C - 1.1), Vector3(124.0 * C, 1.65, 64.6 * C)],
		["realm", Vector2(196, 50), Vector3(188.0 * C, 9.0, 52.0 * C), Vector3(232.0 * C, 10.0, 46.0 * C)],
		["nest", Vector2(212, 80), Vector3(210.0 * C, 7.0, 80.0 * C), Vector3(216.0 * C, 1.0, 92.0 * C)],
		["skull", Vector2(196, 22), Vector3(192.0 * C, 5.0, 24.0 * C), Vector3(200.0 * C, 3.0, 12.0 * C)],
		["bones", Vector2(100, 34), Vector3(100.0 * C, 6.0, 34.0 * C), Vector3(140.0 * C, 6.0, 18.0 * C)],
		["ash", Vector2(38, 72), Vector3(38.0 * C + 4.0, 12.0, 72.0 * C), Vector3(38.0 * C, 1.0, 88.0 * C)],
		["sky", Vector2(130, 50), Vector3(130.0 * C, 330.0, 170.0 * C), Vector3(130.0 * C, 0.0, 55.0 * C)],
	]
	for s in shots:
		rules.lord.pos = s[1]
		rules.lord.prev_pos = s[1]
		await _wait(150)   # 땅의 빛이 섞이게
		cam.look_at_from_position(s[2], s[3])
		await _wait(4)
		root.get_texture().get_image().save_png(OUT + "past_%s.png" % s[0])
		print("shot past_", s[0], " ", m.get("_region"))
	# 깨어난 짐승
	rules.lord.pos = StoryPast.SEAL_AT + Vector2(-10, 0)
	rules.lord.prev_pos = rules.lord.pos
	var e: Enemy = rules.spawn_field_boss(StoryPast.BEAST_AT, StoryPast.BEAST_ID, StoryPast.BEAST_ZONE)
	await _wait(150)
	rules.freeze = 1000000
	e.face = Vector2(0, -1)
	await _wait(4)
	var bp := Grid.cells_to_world(e.pos)
	cam.look_at_from_position(bp + Vector3(6.0, 4.0, -15.0), bp + Vector3(0, 4.0, 0))
	await _wait(4)
	root.get_texture().get_image().save_png(OUT + "past_beast.png")
	print("shot past_beast")
	quit()
