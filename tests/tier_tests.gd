extends RefCounted
## 마을 키우기 4단계 테스트(2026-11-21, docs/village_growth.md): 개척지 → 마을 → 읍 → 성읍. 건물 수(2·5·7)와 사는 사람(1·3·6), 성읍은 돌담.
## run_all.gd가 부른다: run(데이터, check).


static func run(d: GameData, check: Callable) -> void:
	var md := d.meta
	var m := Meta.new()
	check.call(m.village_tier(d) == 0 and md.tier_names[0] == "개척지", "처음은 개척지")
	var need: Dictionary = m.next_tier_need(d)
	check.call(int(need.tier) == 1 and int(need.buildings) == md.tier_buildings[1] and int(need.residents) == md.tier_residents[1] and not bool(need.wall), "다음(마을)까지 모자란 것 %s" % [need])
	m.mats = {&"wood": 999, &"stone": 999, &"iron": 999}
	m.storage_house = true
	m.build(d.building(&"cottage"), d)
	check.call(m.building_count() == 2 and m.village_tier(d) == 0, "건물 둘이어도 사는 사람이 없으면 개척지")
	m.residents.append({"name": "돌쇠", "look": &"peasant", "job": &""})
	check.call(m.village_tier(d) == 1, "건물 둘, 사는 사람 하나면 마을")
	check.call(not d.building(&"wall").min_tier <= 1 and not m.build(d.building(&"wall"), d) and not m.has_built(&"wall"), "돌담은 읍이 되어야 짓는다")
	check.call(m.build(d.building(&"longhouse"), d), "긴 집은 마을이면 짓는다")
	for id in [&"woodcutter", &"mason"]:
		m.build(d.building(id), d)
	for n in ["끝순", "덕배"]:
		m.residents.append({"name": n, "look": &"peasant", "job": &""})
	check.call(m.building_count() == 5 and m.village_tier(d) == 2, "건물 다섯, 사는 사람 셋이면 읍")
	check.call(m.build(d.building(&"wall"), d), "읍이 되면 돌담을 짓는다")
	for n in ["언년", "삼월", "칠복"]:
		m.residents.append({"name": n, "look": &"peasant", "job": &""})
	check.call(m.building_count() == 6 and m.village_tier(d) == 2, "돌담이 있어도 건물이 일곱이 안 되면 아직 읍 %d" % m.building_count())
	m.built.erase(&"cottage2")
	check.call(m.village_tier(d) == 2, "건물 여섯이면 읍")
	m.built[&"cottage2"] = true
	m.built[&"extra"] = true
	check.call(m.building_count() == 8 and m.village_tier(d) == 3 and m.next_tier_need(d).is_empty(), "건물 일곱 이상, 사는 사람 여섯, 돌담이면 성읍(끝)")
	m.built.erase(&"extra")
	check.call(m.building_count() == 7 and m.village_tier(d) == 3, "지금 지을 수 있는 건물(검 보관집 포함 일곱)을 다 지으면 성읍")
	m.built.erase(&"wall")
	check.call(m.village_tier(d) == 2, "돌담 없이는 성읍이 아니다")
	check.call(m.housing(d) >= md.tier_residents[3], "집을 다 지으면 성읍에 필요한 사람(%d)이 살 수 있다 (집 %d)" % [md.tier_residents[3], m.housing(d)])
	var m2 := Meta.new()
	m.tier_seen = 2
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check.call(m2.tier_seen == 2, "알린 단계는 저장한다")
