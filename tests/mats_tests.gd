extends RefCounted
## 마을 키우기 1단계 테스트(2026-11-21, docs/village_growth.md): 나무·돌·쇠를 들판에서 거두고 언덕 판이 끝나면 받는다.
## run_all.gd가 부른다: run(데이터, check).


static func run(d: GameData, check: Callable) -> void:
	var m := Meta.new()
	m.rng.seed = 5
	check.call(m.mat(&"wood") == 0 and m.mat(&"stone") == 0 and m.mat(&"iron") == 0, "재료는 0에서 시작")
	# 들판 자리: 재료마다 MAT_ACTIVE곳
	m.roll_mat_spots()
	var per: Dictionary = {}
	for i in m.mat_spots:
		var id: StringName = FieldLayout.MATS[i][1]
		per[id] = int(per.get(id, 0)) + 1
	check.call(per.get(&"wood", 0) == FieldLayout.MAT_ACTIVE and per.get(&"stone", 0) == FieldLayout.MAT_ACTIVE and per.get(&"iron", 0) == FieldLayout.MAT_ACTIVE,
		"들판 재료 자리: 나무·돌·쇠마다 %d곳" % FieldLayout.MAT_ACTIVE)
	var spot: int = m.mat_spots[0]
	var got: Array = m.take_mat(spot)
	var y: Vector2i = FieldLayout.MAT_YIELD[got[0]]
	check.call(got[0] == FieldLayout.MATS[spot][1] and int(got[1]) >= y.x and int(got[1]) <= y.y and m.mat(got[0]) == int(got[1]), "재료 자리에서 그 재료를 %d~%d 거둔다" % [y.x, y.y])
	check.call(int(m.take_mat(spot)[1]) == 0 and not m.mat_spots.has(spot), "거둔 자리는 이번 판에 다시 안 생긴다")
	# 내기
	m.mats = {&"wood": 5, &"stone": 3, &"iron": 1}
	check.call(not m.pay({&"wood": 2, &"iron": 2}) and m.mat(&"wood") == 5, "모자라면 아무것도 안 낸다")
	check.call(m.pay({&"wood": 2, &"stone": 3}) and m.mat(&"wood") == 3 and m.mat(&"stone") == 0, "다 있으면 낸다")
	# 저장
	var m2 := Meta.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check.call(m2.mat(&"wood") == 3 and m2.mat(&"iron") == 1 and m2.mat_spots == m.mat_spots and m2.mat_spots_ready, "재료와 들판 자리는 저장하고 불러온다")
	var old := m.to_dict()
	old.erase("mats")
	m2 = Meta.new()
	m2.from_dict(old)
	check.call(m2.mat(&"wood") == 0, "예전 저장은 재료 0")
	# 언덕 판 보상
	var r := Rules.new(d, 3)
	r.zone = 3
	r.elites_killed = 2
	var got_run: Dictionary = Meta.run_mats(r, d.meta)
	check.call(got_run[&"wood"] == 3 * d.meta.run_wood_per_zone and got_run[&"stone"] == 3 * d.meta.run_stone_per_zone
		and got_run[&"iron"] == 3 * d.meta.run_iron_per_zone + 2 * d.meta.run_iron_per_elite, "언덕 판: 넘긴 구역마다 나무·돌·쇠, 정예마다 쇠 %s" % [got_run])
	var before: int = m.mat(&"stone")
	var rr: Dictionary = m.record_run(r, d.meta)
	check.call(m.mat(&"stone") == before + int(rr.mats[&"stone"]) and m.mat_spots_ready and m.mat_spots.size() == FieldLayout.MAT_ACTIVE * 3, "판이 끝나면 재료를 받고 들판 자리를 새로 뽑는다")
	# 자리는 곳에 맞는다
	var ok: bool = true
	for e in FieldLayout.MATS:
		var a: StringName = FieldLayout.area_at(e[0])
		var want: Dictionary = {&"wood": [&"grove", &"brook", &"foot", &"marsh"], &"stone": [&"quarry", &"keep", &"pass", &"watchtower"], &"iron": [&"old_field", &"hamlet", &"keep", &"watchtower", &"pass"]}
		ok = ok and (want[e[1]] as Array).has(a)
	check.call(ok, "재료 자리는 제 곳에 있다(나무는 숲·개울, 돌은 채석장·성채, 쇠는 옛 싸움터·불탄 마을…)")
