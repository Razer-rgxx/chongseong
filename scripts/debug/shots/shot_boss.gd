extends SceneTree
## 보스 패턴 확인용(docs/boss_patterns.md): 들판 옛 싸움터의 보스에게 패턴 하나씩만 남겨 쓰게 하고 예고·터짐을 찍는다.
## 돌리기: xvfb-run -a godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility --fixed-fps 30 -s scripts/debug/shots/shot_boss.gd [-- 이름 …]
## (--fixed-fps: 소프트웨어 그리기가 느려도 한 화면이 1/30초라 규칙과 효과의 때가 맞는다)
## 그림은 /home/claude/shots/boss_<이름>.png. 저장 파일은 건드리지 않는다.

const OUT: String = "/home/claude/shots/"
## 이름 → [보스 표(그 표의 패턴을 쓴다), 남길 패턴의 칸, 영주 거리(칸), 기다릴 일, 그 일의 몇 할에서 찍나(1보다 크면 그 일이 끝나고 (값 - 1)초 뒤)]
const SHOTS: Dictionary = {
	"slam": [&"boss", {"slam_chance": 1.0}, 2.0, &"slam_wind", 0.75],
	"quake": [&"boss", {"slam_chance": 1.0}, 2.0, &"slam", 0.4],
	"rain": [&"boss", {"rain_chance": 1.0}, 6.0, &"rain", 1.5],
	"rain_land": [&"boss", {"rain_chance": 1.0}, 6.0, &"rain", 2.6],
	"hands": [&"crypt_lord", {"rain_chance": 1.0}, 5.0, &"rain", 1.45],
	"cleave": [&"grave_knight", {"cleave_chance": 1.0}, 7.0, &"cleave_wind", 0.8],
	"shock": [&"grave_knight", {"cleave_chance": 1.0}, 7.0, &"cleave", 0.5],
	"blink": [&"crypt_lord", {"blink_chance": 1.0}, 6.0, &"blink_wind", 0.7],
	"combo": [&"crypt_lord", {}, 2.5, &"swing_wind", 0.6],
}
## 패턴을 고를 때 끄는 칸(하나만 남긴다).
const OFF: Dictionary = {"slam_chance": 0.0, "rain_count": 0, "cleave_chance": 0.0, "blink_chance": 0.0, "charge_chance": 0.0, "summon_count": 0}


func _init() -> void:
	var names: Array = Array(OS.get_cmdline_user_args())
	if names.is_empty():
		names = SHOTS.keys()
	change_scene_to_file("res://scenes/field/field.tscn")
	for i in 30:
		await process_frame
	var f: Node = current_scene
	var rules: Rules = f.get("rules")
	rules.debug_god = true
	rules.field_clock = 70.0
	var cam: Node = f.get("_camera")
	var b: Enemy = rules.field_boss
	var home: Vector2 = FieldLayout.BOSS_AT
	for name: String in names:
		var v: Array = SHOTS[name]
		var D: EnemyData = (rules.data.enemies[v[0]] as EnemyData).duplicate()
		var keep: Dictionary = v[1]
		for k: String in OFF:
			if not keep.has(k) and not (k == "rain_count" and keep.has("rain_chance")):
				D.set(k, OFF[k])
		for k: String in keep:
			D.set(k, keep[k])
		D.model_scale = (rules.data.enemies[&"grave_knight"] as EnemyData).model_scale   # 몸은 들판 보스의 것 그대로
		b.data = D
		b.summoned = 99
		b.act = &""
		b.combo_left = 0
		b.pos = home
		b.prev_pos = home
		b.face = Vector2.RIGHT
		rules.lord.pos = home + Vector2(float(v[2]), 0.0)
		rules.lord.prev_pos = rules.lord.pos
		rules.hurt(b, 0.0, Vector2.ZERO, false)
		b.cooldown = 99.0
		cam.set("yaw", deg_to_rad(90.0))
		cam.set("distance", 13.0)
		for i in 4:
			await process_frame
		b.cooldown = 0.0
		var want: StringName = v[3]
		var at: float = v[4]
		var seen: bool = false
		var done_t: int = -1
		for i in 900:
			await process_frame
			if b.act == want:
				seen = true
				if at <= 1.0 and b.act_t >= b.act_time * at:
					break
			elif seen and done_t < 0:
				done_t = rules.tick
			if at > 1.0 and done_t >= 0 and (rules.tick - done_t) * rules.dt >= at - 1.0:
				break
			if not seen and b.act == &"":
				rules.lord.pos = b.pos + Vector2(float(v[2]), 0.0)   # 고를 때까지 거리를 둔다
		root.get_texture().get_image().save_png(OUT + "boss_" + name + ".png")
		print("shot ", name, " act=", b.act, " seen=", seen)
		for i in 8:
			await process_frame
	quit()
