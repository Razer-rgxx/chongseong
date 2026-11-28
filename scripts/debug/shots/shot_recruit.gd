extends SceneTree
## 34단계 확인용: 들판에 선 떠도는 사람(말을 건 띠)과, 영입해서 마을에 선 사람들.
## 돌리기: xvfb-run -a godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s scripts/debug/shots/shot_recruit.gd
## 그림은 /home/claude/shots/recruit_field.png, recruit_village.png와 둘을 반씩 붙인 recruit.png. 저장 파일은 건드리지 않는다(Meta만 고친다).

const OUT: String = "/home/claude/shots/"
## 들판: 세울 사람, 후보 자리 번호, 영주가 설 자리(사람에서), 카메라 yaw(도), 시계(초)
const FIELD: Array = ["knight", 1, Vector2(1.3, 1.3), 340.0, 200.0]


func _init() -> void:
	change_scene_to_file("res://scenes/field/field.tscn")
	for i in 30:
		await process_frame
	var f: Node = current_scene
	var meta: Meta = f.get("meta")
	var rules: Rules = f.get("rules")
	rules.debug_god = true
	meta.wanderer = FIELD[0]
	meta.wanderer_at = FIELD[1]
	meta.chiefs_first = {"chief_tower": 1, "chief_grove": 1}
	f.call("_build_wanderer")
	var at: Vector2 = FieldLayout.WANDERER_SPOTS[FIELD[1]].at
	rules.field_clock = float(FIELD[4])
	rules.lord.pos = at + FIELD[2]
	rules.lord.prev_pos = rules.lord.pos
	var cam: Node = f.get("_camera")
	cam.set("yaw", deg_to_rad(float(FIELD[3])))
	cam.set("distance", 5.5)
	for i in 16:
		await process_frame
	f.call("_interact")   # 인사
	for i in 4:
		await process_frame
	f.call("_interact")   # 조건과 진행
	for i in 10:
		await process_frame
	var a: Image = root.get_texture().get_image()
	a.save_png(OUT + "recruit_field.png")
	print("shot recruit_field near=", f.get("_near"), " step=", f.get("_wander_step"))
	# 마을: 다섯 사람을 다 데려왔다고 치고 세운다. 기사에게 말을 건다
	change_scene_to_file("res://scenes/lobby/lobby.tscn")
	for i in 30:
		await process_frame
	var l: Node = current_scene
	var lm: Meta = l.get("meta")
	lm.recruits = ["gatherer", "smith", "hunter", "pilgrim", "knight"]
	var R: Dictionary = (l.get_script() as GDScript).get_script_constant_map()["RECRUITS"]
	for id in R:
		l.call("_add_folk", id, R[id][0], R[id][1])
	var lr: Rules = l.get("rules")
	lr.lord.pos = Vector2(24.4, 12.4)
	lr.lord.prev_pos = lr.lord.pos
	var lc: Node = l.get("_camera")
	lc.set("yaw", deg_to_rad(262.0))
	lc.set("distance", 5.5)
	for i in 16:
		await process_frame
	l.call("_start_talk", &"knight")
	for i in 10:
		await process_frame
	var b: Image = root.get_texture().get_image()
	b.save_png(OUT + "recruit_village.png")
	print("shot recruit_village")
	# 둘을 반씩 붙인다(위 들판, 아래 마을)
	var w: int = a.get_width()
	var h: int = a.get_height()
	a.resize(w / 2, h / 2)
	b.resize(w / 2, h / 2)
	var both := Image.create(w / 2, h, false, a.get_format())
	both.blit_rect(a, Rect2i(0, 0, w / 2, h / 2), Vector2i(0, 0))
	both.blit_rect(b, Rect2i(0, 0, w / 2, h / 2), Vector2i(0, h / 2))
	both.save_png(OUT + "recruit.png")
	quit()
