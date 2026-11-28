extends SceneTree
## 들판 재료 자리(2026-11-21 마을 키우기 1단계)를 뽑는 개발용 도구: 곳마다 막히지 않고 길·다른 자리와 떨어진 점을 찍는다.
## 돌리기: godot --headless --path . -s scripts/debug/pick_mat_spots.gd  → FieldLayout.MATS에 붙여 넣을 줄을 찍는다.

const PLAN: Array = [
	[&"wood", &"grove", 3], [&"wood", &"brook", 2], [&"wood", &"foot", 2], [&"wood", &"marsh", 1],
	[&"stone", &"quarry", 3], [&"stone", &"keep", 2], [&"stone", &"pass", 2], [&"stone", &"watchtower", 1],
	[&"iron", &"old_field", 3], [&"iron", &"hamlet", 2], [&"iron", &"keep", 1], [&"iron", &"watchtower", 1], [&"iron", &"pass", 1],
]


func _init() -> void:
	change_scene_to_file("res://scenes/field/field.tscn")
	for i in 20:
		await process_frame
	var rules: Rules = current_scene.get("rules")
	var nav: Nav = rules.nav
	var cls: int = Nav.class_of(1.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2211
	var taken: Array[Vector2] = []
	for g in FieldLayout.GLINTS:
		taken.append(g)
	for k in FieldLayout.CACHES:
		taken.append(FieldLayout.CACHES[k][0])
	for k in FieldLayout.STONES:
		taken.append(FieldLayout.STONES[k][0])
	var out: Array[String] = []
	for p in PLAN:
		var r: Rect2 = FieldLayout.AREAS[p[1]]
		var got: int = 0
		for tries in 4000:
			if got >= int(p[2]):
				break
			var c := Vector2(rng.randf_range(r.position.x + 3, r.end.x - 3), rng.randf_range(r.position.y + 3, r.end.y - 3))
			if FieldLayout.area_at(c) != p[1] or not nav.free_at(c, cls):
				continue
			var ok: bool = true
			for i in FieldLayout.ROAD.size() - 1:
				if Geometry2D.get_closest_point_to_segment(c, FieldLayout.ROAD[i], FieldLayout.ROAD[i + 1]).distance_to(c) < 4.0:
					ok = false
			for t in taken:
				if t.distance_to(c) < 7.0:
					ok = false
			for k in FieldLayout.PACKS:   # 무리가 진 친 자리(포로가 묶이는 자리)와 밤 무리, 떠도는 사람 자리는 비운다
				if c.distance_to(FieldLayout.PACKS[k].at) < float(FieldLayout.PACKS[k].wander) + 4.0:
					ok = false
			for k in FieldLayout.NIGHT_PACKS:
				if c.distance_to(FieldLayout.NIGHT_PACKS[k].at) < float(FieldLayout.NIGHT_PACKS[k].wander) + 3.0:
					ok = false
			for w in FieldLayout.WANDERER_SPOTS:
				if c.distance_to(w.at) < 5.0:
					ok = false
			if not ok:
				continue
			taken.append(c)
			out.append("	[Vector2(%d, %d), &\"%s\"],   # %s" % [roundi(c.x), roundi(c.y), p[0], FieldLayout.AREA_NAMES[p[1]]])
			got += 1
		if got < int(p[2]):
			print("모자람 ", p)
	for l in out:
		print(l)
	quit()
