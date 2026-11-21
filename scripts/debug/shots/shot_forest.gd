extends SceneTree
## 들판 검의 숲 점검(옛 싸움터, 넓은 들판). shot_field.gd와 같고 자리만 다르다.
## 돌리기: xvfb-run -a godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s scripts/debug/shots/shot_forest.gd
## 그림은 /home/claude/shots/field_<이름>.png. 헤드리스로 돌리면 BFS만 본다(--headless, 그림은 비어 있다).

const OUT: String = "/home/claude/shots/"
## 이름, 영주 자리, 카메라 yaw(도), 시계(초, -1이면 그대로), 카메라 거리(m)
const SHOTS: Array = [
	["forest_old_field", Vector2(84, 96), 20.0, 60.0, 16.0],
	["forest_old_field_low", Vector2(80, 82), 200.0, 60.0, 9.0],
	["forest_wide", Vector2(30, 70), 120.0, 60.0, 16.0],
]


func _init() -> void:
	change_scene_to_file("res://scenes/field/field.tscn")
	for i in 30:
		await process_frame
	var f: Node = current_scene
	if DisplayServer.get_name() == "headless":
		_reach(f)   # BFS는 느려서(몇 분) 헤드리스로 돌릴 때만
		quit()
		return
	var rules: Rules = f.get("rules")
	rules.debug_god = true   # 무리 곁에 세워도 쓰러져 마을로 가지 않게
	var cam: Node = f.get("_camera")
	for s in SHOTS:
		if float(s[3]) >= 0.0:
			rules.field_clock = float(s[3])
		rules.lord.pos = s[1]
		rules.lord.prev_pos = s[1]
		cam.set("yaw", deg_to_rad(float(s[2])))
		cam.set("distance", float(s[4]))
		for i in 40:
			await process_frame
		root.get_texture().get_image().save_png(OUT + "field_" + str(s[0]) + ".png")
		print("shot ", s[0], " area=", FieldLayout.area_at(s[1]), " clock=", rules.field_clock)
	quit()


## 0.5칸 격자 BFS: _push_out이 움직이지 않는 자리만 걷는다.
func _reach(f: Node) -> void:
	var step: float = 0.5
	var w: int = int(FieldLayout.SIZE.x / step)
	var h: int = int(FieldLayout.SIZE.y / step)
	var seen := PackedByteArray()
	seen.resize(w * h)
	var free := func(p: Vector2) -> bool:
		if p.x < 0.5 or p.y < 0.5 or p.x > FieldLayout.SIZE.x - 0.5 or p.y > FieldLayout.SIZE.y - 0.5:
			return false
		return (f.call("_push_out", p) as Vector2).distance_to(p) < 0.01
	var start: Vector2 = FieldLayout.START
	var q: Array[Vector2i] = [Vector2i(int(start.x / step), int(start.y / step))]
	seen[q[0].y * w + q[0].x] = 1
	var n: int = 0
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		n += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = c + d
			if nb.x < 0 or nb.y < 0 or nb.x >= w or nb.y >= h or seen[nb.y * w + nb.x] == 1:
				continue
			if free.call(Vector2(nb) * step):
				seen[nb.y * w + nb.x] = 1
				q.append(nb)
	var near := func(p: Vector2, r: float) -> bool:
		# p에서 r칸 안의 걸을 수 있는 자리에 닿았는가(상자·비석은 그 자체가 막힘일 수 있다)
		for yy in range(int((p.y - r) / step), int((p.y + r) / step) + 1):
			for xx in range(int((p.x - r) / step), int((p.x + r) / step) + 1):
				if xx >= 0 and yy >= 0 and xx < w and yy < h and seen[yy * w + xx] == 1:
					return true
		return false
	var bad: Array[String] = []
	for k in FieldLayout.CACHES:
		if not near.call(FieldLayout.CACHES[k][0], 2.0):
			bad.append(str(k))
	for k in FieldLayout.STONES:
		if not near.call(FieldLayout.STONES[k][0], 2.0):
			bad.append(str(k))
	for k in FieldLayout.PACKS:
		if not near.call(FieldLayout.PACKS[k]["at"], 3.0):
			bad.append("pack " + str(k))
	for k in FieldLayout.NIGHT_PACKS:
		if not near.call(FieldLayout.NIGHT_PACKS[k]["at"], 3.0):
			bad.append("night " + str(k))
	for i in FieldLayout.GLINTS.size():
		if not near.call(FieldLayout.GLINTS[i], 1.5):
			bad.append("glint %d" % i)
	for a in FieldLayout.AREAS:
		var r: Rect2 = FieldLayout.AREAS[a]
		if not near.call(r.get_center(), 6.0):
			bad.append("area " + str(a))
	print("reach cells=", n, " unreachable=", bad)
