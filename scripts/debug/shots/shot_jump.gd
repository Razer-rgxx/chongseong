extends SceneTree
## 30단계 점프 확인용: 들판 불탄 마을의 무너진 울타리(HAMLET_FENCES, 낮은 막힘)를 넘는 순간과 뛰는 순간·내려앉는 순간.
## 돌리기: xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s scripts/debug/shots/shot_jump.gd
## Xvfb는 초당 2장쯤이라 실제 시간을 기다리지 않고 규칙을 멈춰(freeze) 공중 시간을 직접 놓는다. 그림은 /home/claude/shots/jump*.png.

const OUT: String = "/home/claude/shots/"
## 이름, 공중에 남은 비율(1 = 막 뜸, 0.5 = 가장 높음, 0 = 땅), 내려앉은 뒤 초(-1이면 아님), 넘는 것의 가운데에서 남북 어긋남(칸), 자리(없으면 울타리)
const SHOTS: Array = [
	["jump", 0.5, -1.0, 0.2],
	["jump_takeoff", 0.93, -1.0, -0.9],
	["jump_land", 0.0, 0.06, 1.3],
	["jump_log", 0.5, -1.0, 0.0, Vector2(20.0, 36.0)],   # 검은 숲의 쓰러진 거목(낮은 둥근 막힘)
]


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	change_scene_to_file("res://scenes/field/field.tscn")
	await _frames(30)
	var f: Node = current_scene
	var rules: Rules = f.get("rules")
	rules.debug_god = true
	rules.field_clock = 70.0
	var cam: Node = f.get("_camera")
	var lord: Node = f.get("_lord")
	var fence: Rect2 = FieldLayout.HAMLET_FENCES[0]   # (176, 77) 남쪽 울타리, 동서로 7칸
	var D: LordData = rules.data.lord
	(f.get("_shown") as Dictionary)[&"hamlet"] = true   # 곳 이름(AreaTitle)이 몸을 가리지 않게
	(f.get("_shown") as Dictionary)[&"grove"] = true
	for s in SHOTS:
		var mid: Vector2 = s[4] if s.size() > 4 else fence.get_center() - Vector2(0.6, 0.0)
		var at := Vector2(mid.x, mid.y + float(s[3]))
		rules.lord.pos = at
		rules.lord.prev_pos = at
		rules.lord.face = PI / 2.0   # 남쪽으로 넘는다
		rules.lord.move_dir = Vector2.DOWN
		rules.lord.air = D.jump_time * float(s[1])
		rules.lord.prev_air = rules.lord.air
		rules.freeze = 1000000   # 규칙을 멈춘다(공중 시간이 줄지 않게)
		cam.set("yaw", deg_to_rad(-48.0))   # 남서쪽에서 북동쪽을 본다: 울타리가 화면을 비스듬히 가로지른다
		cam.set("pitch", deg_to_rad(4.0))
		cam.set("third_distance", 6.0)
		Engine.time_scale = 1.0
		await _frames(3)
		cam.call("snap")
		Engine.time_scale = 0.0005   # 화면의 시간(내려앉은 뒤 무릎 굽힘)이 거의 흐르지 않게
		if float(s[2]) >= 0.0:
			lord.set("_land_t", float(s[2]))
			lord.set("_was_air", false)
		await _frames(12)
		root.get_texture().get_image().save_png(OUT + str(s[0]) + ".png")
		print("shot ", s[0], " air=", rules.lord.air, " h=", LordState.air_height(rules.lord.air, D), " area=", FieldLayout.area_at(at))
	quit()
