extends SceneTree
## 37단계 적 길찾기 확인용 화면: 망루 북쪽의 무리를 덤비게 하고, 망루(막힘) 남쪽의 영주에게 둘레를 돌아오는 순간을 찍는다.
## 돌리기: xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s scripts/debug/shots/shot_pathing.gd
## 그림은 /home/claude/shots/pathing.png(3인칭)와 pathing_quarter.png(쿼터뷰). Xvfb는 느려서 규칙 틱을 직접 돌려 그 순간까지 간 뒤 몇 프레임 그린다.

const OUT: String = "/home/claude/shots/"
const LORD_AT: Vector2 = Vector2(92, 42.6)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	change_scene_to_file("res://scenes/field/field.tscn")
	for i in 30:
		await process_frame
	var f: Node = current_scene
	var rules: Rules = f.get("rules")
	rules.debug_god = true
	rules.field_clock = 70.0
	rules.freeze = 100000   # 곳 이름(AreaTitle)이 사라질 때까지 규칙을 멈춰 둔다
	rules.lord.pos = LORD_AT
	rules.lord.prev_pos = LORD_AT
	rules.lord.face = -PI / 2.0
	var cam: Node = f.get("_camera")
	cam.set("yaw", deg_to_rad(8.0))
	cam.set("pitch", deg_to_rad(38.0))
	cam.set("third_distance", 13.0)
	for i in 30:
		await process_frame
	rules.freeze = 0
	if not rules.packs.has(&"tower"):
		rules.spawn_pack(&"tower")
	rules._engage_pack(&"tower")
	# 무리 둘 이상이 망루 옆(곧은 선이 막힌 곳)의 남쪽 반을 돌 때까지 틱을 직접 돌린다
	var beside: int = 0
	var t: int = 0
	while t < 400:
		rules.step(LordInput.new())
		rules.lord.pos = LORD_AT
		t += 1
		beside = 0
		for e in rules.enemies:
			if e.pack == &"tower" and not e.dead and e.pos.y > 35.0 and e.pos.y < 39.6 and (e.pos.x < 88.4 or e.pos.x > 95.6):
				beside += 1
		if beside >= 2:
			break
	var line: String = "tick %d beside %d:" % [t, beside]
	for e in rules.enemies:
		if e.pack == &"tower":
			line += " %s(%.1f,%.1f)%s" % [e.data.id, e.pos.x, e.pos.y, "D" if e.detour else ""]
	print(line)
	rules.freeze = 100000   # 찍는 동안 멈춘다(화면은 그대로 그린다)
	for i in 8:
		await process_frame
	root.get_texture().get_image().save_png(OUT + "pathing.png")
	cam.call("toggle_mode")
	cam.set("distance", 30.0)
	for i in 8:
		await process_frame
	root.get_texture().get_image().save_png(OUT + "pathing_quarter.png")
	print("shot pathing")
	quit()
