extends RefCounted
## 마을 키우기 3단계 테스트(2026-11-21, docs/village_growth.md): 들판 무리에 잡힌 사람을 풀어 주면 오두막에 살고, 일터에 두면 판마다 더 모은다.
## run_all.gd가 부른다: run(데이터, check).


static func run(d: GameData, check: Callable) -> void:
	var m := Meta.new()
	m.rng.seed = 9
	m.roll_captives()
	check.call(m.captive_packs.size() == FieldLayout.CAPTIVES and m.captives_ready, "판마다 무리 %d곳에 사람이 잡혀 있다" % FieldLayout.CAPTIVES)
	var pk: String = m.captive_packs[0]
	check.call(not m.captive_waiting(pk), "무리를 쓰러뜨리기 전에는 풀어 줄 수 없다")
	m.packs_cleared[pk] = 1
	check.call(m.captive_waiting(pk), "무리를 쓰러뜨리면 묶인 사람이 보인다")
	check.call(m.housing(d) == 0 and m.free_captive(pk, d).is_empty() and m.residents.is_empty(), "집이 없으면 풀어 줘도 갈 곳이 없다(그대로 묶여 있다)")
	m.mats = {&"wood": 100, &"stone": 100, &"iron": 0}
	m.build(d.building(&"cottage"))
	check.call(m.housing(d) == 2, "오두막 하나에 둘")
	var r: Dictionary = m.free_captive(pk, d)
	check.call(not r.is_empty() and m.residents.size() == 1 and FieldLayout.RESIDENT_NAMES.has(r.name) and r.job == &"" and not m.captive_waiting(pk), "풀어 주면 이름 있는 주민이 되고, 그 무리에는 이제 없다")
	check.call(m.free_captive(pk, d).is_empty(), "같은 사람을 두 번 풀어 줄 수 없다")
	var pk2: String = m.captive_packs[1]
	m.packs_cleared[pk2] = 1
	var r2: Dictionary = m.free_captive(pk2, d)
	check.call(r2.name != r.name and m.residents.size() == 2 and not m.has_room(d), "둘째는 다른 이름, 오두막이 찬다")
	# 일
	check.call(not m.set_job(0, &"woodcutter", d), "일터를 짓기 전에는 일을 맡길 수 없다")
	m.build(d.building(&"woodcutter"))
	var base: int = int(m.village_made(d)[&"wood"])
	check.call(m.set_job(0, &"woodcutter", d) and m.workers_at(&"woodcutter") == 1, "나무꾼 움막에 일을 맡긴다")
	var wc: BuildingData = d.building(&"woodcutter")
	check.call(int(m.village_made(d)[&"wood"]) == base + wc.per_worker, "일꾼 하나가 판마다 나무 +%d" % wc.per_worker)
	check.call(not m.set_job(1, &"cottage", d), "오두막은 일터가 아니다")
	m.set_job(1, &"woodcutter", d)
	check.call(int(m.village_made(d)[&"wood"]) == wc.made_wood + 2 * wc.per_worker, "둘이면 둘 몫")
	check.call(m.set_job(0, &"", d) and m.workers_at(&"woodcutter") == 1, "쉬게 하면 일터에서 빠진다")
	# 저장
	var m2 := Meta.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check.call(m2.residents.size() == 2 and m2.residents[1].job == &"woodcutter" and m2.residents[0].name == r.name and m2.captives_freed.size() == 2, "주민과 일, 풀어 준 무리는 저장하고 불러온다")
	# 판이 끝나면 새로 잡혀 있다
	var rr := Rules.new(d, 3)
	m.record_run(rr, d.meta)
	check.call(m.captives_freed.is_empty() and m.captive_packs.size() == FieldLayout.CAPTIVES and m.residents.size() == 2, "판이 끝나면 다른 무리에 새로 잡혀 있고, 주민은 그대로")
