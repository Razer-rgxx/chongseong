extends RefCounted
## 마을 키우기 2단계 테스트(2026-11-21, docs/village_growth.md): 바깥 터의 건물을 재료로 짓고, 지은 건물이 언덕 판마다 재료를 모아 둔다.
## run_all.gd가 부른다: run(데이터, check).


static func run(d: GameData, check: Callable) -> void:
	var ids: Array = d.buildings.map(func(b: BuildingData) -> StringName: return b.id)
	check.call(ids == [&"cottage", &"woodcutter", &"mason", &"cottage2", &"longhouse", &"wall", &"tower", &"forge"], "건물(파일 이름 순서): 오두막·나무꾼 움막·석공 마당·작은 집·긴 집·돌담·망루·풀무간 %s" % [ids])
	var ok: bool = true
	for b in d.buildings:
		ok = ok and b.plot.x > 34.0 and b.plot.x < 50.0 and b.plot.y > 3.5 and b.plot.y < 21.0 and b.cost().size() > 0 and b.desc != ""
		for o in d.buildings:
			if o != b:
				ok = ok and Rect2(b.plot - b.size / 4.0, b.size / 2.0).grow(0.5).intersects(Rect2(o.plot - o.size / 4.0, o.size / 2.0)) == false
	check.call(ok, "건물 자리는 바깥 터(칸 34~50) 안이고 서로 겹치지 않는다, 값과 하는 일이 있다")
	var m := Meta.new()
	var cot: BuildingData = d.building(&"cottage")
	check.call(not m.build(cot) and not m.has_built(&"cottage"), "재료가 모자라면 못 짓는다")
	m.mats = {&"wood": 100, &"stone": 100, &"iron": 100}
	check.call(m.build(cot) and m.has_built(&"cottage") and m.mat(&"wood") == 100 - cot.cost_wood and m.mat(&"stone") == 100 - cot.cost_stone, "지으면 재료를 낸다")
	check.call(not m.build(cot), "같은 건물은 한 번만")
	check.call(m.village_made(d) == {&"wood": 0, &"stone": 0, &"iron": 0}, "오두막은 재료를 모으지 않는다")
	m.build(d.building(&"woodcutter"))
	m.build(d.building(&"mason"))
	var made: Dictionary = m.village_made(d)
	check.call(made[&"wood"] == d.building(&"woodcutter").made_wood and made[&"stone"] == d.building(&"mason").made_stone and made[&"wood"] > 0, "나무꾼 움막은 나무, 석공 마당은 돌을 판마다 모은다 %s" % [made])
	var r := Rules.new(d, 3)
	r.zone = 0
	var before: int = m.mat(&"wood")
	var rr: Dictionary = m.record_run(r, d.meta)
	check.call(m.mat(&"wood") == before + made[&"wood"] and int(rr.mats[&"wood"]) == made[&"wood"], "판이 끝나면 건물이 모은 것을 받는다(구역 0이어도)")
	var m2 := Meta.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check.call(m2.has_built(&"cottage") and m2.has_built(&"mason") and m2.built.size() == 3, "지은 건물은 저장하고 불러온다")
	# 건물 안(2026-11-21): 종류마다 방과 문 쪽 카메라, 마주 설 사람
	var ok2: bool = true
	for k in [&"forge", &"shrine", &"storage", &"house", &"smithy"]:
		var room := Interior.new()
		room.build(k)
		room.set_npc(&"peasant")
		ok2 = ok2 and room.cam != null and room.get_child_count() > 10
		room.set_npc(&"")
		room.free()
	check.call(ok2, "건물 안: 대장간·성소·검 보관집·집·풀무간 방이 지어지고 카메라가 있다")
