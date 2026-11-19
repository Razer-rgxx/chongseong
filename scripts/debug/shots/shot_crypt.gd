extends SceneTree
## 31단계 확인용: 지하 무덤 방 싸움(정예의 금빛 고리, 늘어난 무리). 그림은 /home/claude/shots/crypt_hard*.png.
## 돌리기: xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s scripts/debug/shots/shot_crypt.gd
## Xvfb는 초당 2장쯤이라 프레임 수로 기다린다(틱은 프레임마다 최대 8). 영주는 무적(debug_god)이고 좌클릭을 계속 누른다.

const OUT: String = "/home/claude/shots/"
## 이름, 들어설 방, 영주 자리, 카메라 yaw(도), 싸우는 프레임 수
const SHOTS: Array = [
	["crypt_hard", &"r2", Vector2(35.0, 51.6), 0.0, 16],
	["crypt_hard_lord", &"r6", Vector2(57.0, 33.0), 0.0, 22],
]


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	var m := Meta.load_or_new()
	for s in SHOTS:
		change_scene_to_file("res://scenes/crypt/crypt.tscn")
		await _frames(20)
		var c: Node = current_scene
		var rules: Rules = c.get("rules")
		var crypt: CryptRun = c.get("crypt")
		rules.debug_god = true
		var cam: Node = c.get("_camera")
		rules.lord.pos = s[2]
		rules.lord.prev_pos = s[2]
		rules.lord.face = -PI / 2.0
		cam.set("yaw", deg_to_rad(float(s[3])))
		cam.set("pitch", deg_to_rad(24.0))
		cam.set("third_distance", 9.0)
		await _frames(2)
		cam.call("snap")
		if StringName(s[1]) == &"r6":
			rules.field_boss.hp = rules.field_boss.max_hp * 0.45   # 반쯤 깎아 첫 부르기를 보인다
		for i in int(s[4]):
			c.set("_want_attack", i % 3 == 0)
			await process_frame
		rules.freeze = 1000000
		await _frames(4)
		root.get_texture().get_image().save_png(OUT + str(s[0]) + ".png")
		var elites: int = 0
		var alive: int = 0
		for e in rules.enemies:
			if not e.dead:
				alive += 1
				elites += 1 if e.elite else 0
		print("shot ", s[0], " room=", crypt.room, " alive=", alive, " elites=", elites, " boss_summoned=", rules.field_boss.summoned if rules.field_boss else -1)
	m.save()   # 이 점검은 저장을 바꾸지 않는다(들어선 방 기록 등을 되돌린다)
	quit()
