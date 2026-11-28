extends RefCounted
## 마을 키우기 5단계 테스트(2026-11-21, docs/village_growth.md): 마을 단계와 건물이 여는 것.
## 망루 → 까마귀 고개로 가는 길, 마을 단계 → 언덕을 더 깊은 구역부터, 풀무간 → 판 시작에 벼린 검.
## run_all.gd가 부른다: run(데이터, check).


static func run(d: GameData, check: Callable) -> void:
	var md := d.meta
	var m := Meta.new()
	check.call(m.start_zones(d) == [1], "개척지에서는 1구역부터만")
	m.storage_house = true
	m.mats = {&"wood": 999, &"stone": 999, &"iron": 999}
	m.build(d.building(&"cottage"), d)
	m.residents.append({"name": "돌쇠", "look": &"peasant", "job": &""})
	check.call(m.village_tier(d) == 1 and m.start_zones(d) == [1, md.tier_start_zone[1]], "마을이 되면 %d구역부터도 오른다" % md.tier_start_zone[1])
	# 깊은 구역부터
	m.start_zone = md.tier_start_zone[1]
	var r := Rules.new(d, 4, m)
	check.call(r.zone == md.tier_start_zone[1] - 1 and r.start_zone == r.zone, "고른 구역에서 판이 시작된다(구역 %d)" % (r.zone + 1))
	var got: Dictionary = Meta.run_mats(r, md)
	check.call(int(got[&"wood"]) == 0 and int(Meta.run_shards(r, md).zone) == 0, "건너뛴 구역은 보상에 안 센다")
	r.zone += 2
	check.call(int(Meta.run_mats(r, md)[&"stone"]) == 2 * md.run_stone_per_zone, "넘긴 구역만 센다")
	m.start_zone = 7
	check.call(Rules.new(d, 4, m).zone == 0, "열리지 않은 구역은 고를 수 없다(1구역부터)")
	# 풀무간
	m.start_zone = 1
	check.call(m.forge_grade(d) == -1 and Rules.new(d, 4, m).forged == -1, "풀무간이 없으면 벼린 검도 없다")
	check.call(m.build(d.building(&"forge"), d), "풀무간은 마을이면 짓는다")
	var r2 := Rules.new(d, 4, m)
	check.call(r2.forged >= 0 and r2.slots[r2.forged] != null and r2.slots[r2.forged].grade == md.tier_forge_grade[1], "풀무간: 판을 시작할 때 빈 칸에 벼린 검(%s)" % [r2.slots[r2.forged].label() if r2.forged >= 0 and r2.slots[r2.forged] else "없음"])
	var r3 := Rules.new(d, 4, m)
	check.call(r3.slots[r3.forged].data == r2.slots[r2.forged].data, "같은 씨앗이면 같은 검(결정성)")
	# 망루
	check.call(d.building(&"tower").min_tier == 1 and FieldLayout.PASS_BARRICADES.size() == 2, "망루는 마을이면 짓고, 까마귀 고개로 가는 막힌 길은 둘")
	var ok: bool = true
	for b in FieldLayout.PASS_BARRICADES:
		ok = ok and (b.intersects(Rect2(167, 91, 3, 8)) or b.intersects(Rect2(190, 80, 6, 11)))
	check.call(ok, "막힌 길은 늪 → 고개, 불탄 마을 → 고개의 틈에 있다")
	var m2 := Meta.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check.call(m2.start_zone == 1 and m2.has_built(&"forge"), "시작 구역은 저장한다")
