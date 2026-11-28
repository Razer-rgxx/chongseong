extends RefCounted
## 네온 시가(넓힌 미래 구역)·내 검 목록·버릴까요? 테스트(2026-11-25). run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/neon_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_blocks()
	_packs()
	_discard()
	_story2()
	_future_balance()


func _blocks() -> void:
	var blocks: Array[Rect2] = FutureLayout.neon_blocks()
	var area: Rect2 = Rect2(Vector2.ZERO, Vector2(FutureLayout.SIZE))
	var ok: bool = blocks.size() >= 20
	for r in blocks:
		ok = ok and not r.intersects(FutureLayout.OLD) and area.encloses(r)
	check.call(ok, "네온 시가: 블록 %d개, 옛 폐허와 안 겹치고 구역 안" % blocks.size())
	check.call(FutureLayout.plaza_rects().size() == FutureLayout.PLAZAS.size(), "네온 시가: 광장마다 비운 블록 하나")
	var spots: Array[Vector2] = [FutureLayout.START, FutureLayout.EXIT_AT, FutureLayout.TERMINAL_AT, FutureLayout.CACHE_AT, Story.VAULT_AT, Story.TIME_LOCK_AT, Story.GUARDIAN_AT, Story.FINAL_AT]
	spots.append_array(FutureLayout.CYBER_HILTS)
	for s in Story.SHARDS:
		spots.append(s.at)
	var free: bool = true
	for p in spots:
		for r in blocks:
			free = free and not r.grow(0.5).has_point(p)
	check.call(free, "네온 시가: 시작·틈·단말·상자·이야기·꽂힌 검 자리를 막지 않는다")
	var b: Dictionary = FutureLayout.blockers()
	check.call(b.rects.size() == FutureLayout.TOWERS.size() + blocks.size(), "네온 시가: 블록이 키 큰 막힘이 된다")
	# 옛 블록 동쪽·남쪽으로 걸어 나갈 길이 있다(옛 동쪽 탑들 사이, 남쪽 큰길)
	var east_gap: bool = not Blockers.inside(Vector2(78, 22), b.rects, b.circles) and not Blockers.inside(Vector2(84, 22), b.rects, b.circles)
	var south_gap: bool = not Blockers.inside(Vector2(40, 62), b.rects, b.circles) and not Blockers.inside(Vector2(40, 66), b.rects, b.circles)
	check.call(east_gap and south_gap, "네온 시가: 옛 블록에서 동쪽·남쪽으로 나가는 길이 트여 있다")


func _packs() -> void:
	Grid.size = FutureLayout.SIZE
	var r := Rules.new(d, 6)
	r.era = Rules.ERA_FUTURE
	r.start_field()
	var b: Dictionary = FutureLayout.blockers()
	r.set_blockers(b.rects, b.circles, b.low_rects, b.low_circles)
	var ok: bool = FutureLayout.NEON_PACKS.size() >= 3
	var n: int = 0
	for id in FutureLayout.NEON_PACKS:
		var P: Dictionary = FutureLayout.NEON_PACKS[id]
		ok = ok and FutureLayout.in_neon(P.at) and not Blockers.inside(P.at, b.rects, b.circles, b.low_rects, b.low_circles)
		ok = ok and not FutureLayout.PACKS.has(id)
		var es: Array[Enemy] = r.spawn_pack(StringName(id), P)
		for f in P.foes:
			ok = ok and d.enemies[f[0]].future
		n += es.size()
	for _k in 60:
		r.step(LordInput.new())
	check.call(ok and n >= 12 and r.enemies.size() == n, "네온 시가: 무리 %d마리가 막힘 밖 길·광장에 서고 틱이 돈다" % n)


func _discard() -> void:
	var h := Hud.new()
	var keep: int = GameSettings.discard_ask
	h._choice_grades = [2, 0, 4]   # 새 검 전설, 칸0 흔함, 칸1 초월
	GameSettings.discard_ask = 2
	var a: bool = h._ask_discard(-1) and not h._ask_discard(0) and h._ask_discard(1)
	GameSettings.discard_ask = 0
	var b: bool = h._ask_discard(-1) and h._ask_discard(0) and h._ask_discard(1)
	GameSettings.discard_ask = 6
	var c: bool = not h._ask_discard(-1) and not h._ask_discard(0) and not h._ask_discard(1)
	h._choice_grades = [1, -1]   # 빈 칸으로 바꾸면 버릴 검이 없다
	GameSettings.discard_ask = 0
	var e: bool = not h._ask_discard(0)
	GameSettings.discard_ask = keep
	h.free()
	check.call(a and b and c and e, "버릴까요?: 버려질 검의 등급이 설정 이상일 때만 묻는다(늘·묻지 않기·빈 칸)")


## 미래 2막 「닻 공사」(2026-11-26): 기록 다섯 → 1막을 마쳤을 때만 대수확자 → 한 번만 조각, 저장.
func _story2() -> void:
	var m := Meta.new()
	check.call(not m.harvester_ready() and m.read_log(0) and not m.read_log(0) and not m.read_log(99), "닻 공사: 기록은 한 번만 새로 읽힌다")
	for i in StoryNeon.LOGS.size():
		m.read_log(i)
	check.call(not m.harvester_ready(), "닻 공사: 기록을 다 읽어도 타임트래블러가 없으면 못 깨운다")
	m.time_traveller = true
	var before: int = m.shards
	check.call(m.harvester_ready() and m.harvester_slain() and m.shards == before + StoryNeon.REWARD_SHARDS and not m.harvester_slain() and m.shards == before + StoryNeon.REWARD_SHARDS, "닻 공사: 대수확자 보상은 한 번만")
	var m2 := Meta.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check.call(m2.neon_logs.size() == StoryNeon.LOGS.size() and m2.harvest_down, "닻 공사: 저장하고 다시 읽어도 남는다")
	var blocks: Array[Rect2] = FutureLayout.neon_blocks()
	var b: Dictionary = FutureLayout.blockers()
	var pts: Array[Vector2] = [StoryNeon.FIXER_AT, StoryNeon.STOP_AT, StoryNeon.HARVESTER_AT, StoryNeon.FINAL_AT]
	for l in StoryNeon.LOGS:
		pts.append(l.at)
	var ok: bool = true
	for p in pts:
		ok = ok and FutureLayout.in_neon(p) and not Blockers.inside(p, b.rects, b.circles, b.low_rects, b.low_circles)
	check.call(ok, "닻 공사: 단말·정보상·대수확자 자리는 네온 시가의 길·광장(막힘 밖)")
	check.call(d.enemies.has(StoryNeon.HARVESTER_ID) and d.enemies[StoryNeon.HARVESTER_ID].future and d.enemies[StoryNeon.HARVESTER_ID].boss, "닻 공사: 대수확자 자료(미래·보스)")
	var lines: bool = true
	for i in 6:
		lines = lines and StoryNeon.fixer_line(mini(i, 5), i > 4, false) != ""
	check.call(lines and StoryNeon.fixer_line(5, true, true) != StoryNeon.fixer_line(5, true, false), "닻 공사: 정보상의 말이 단계마다 바뀐다")


## 미래 검 밸런스(2026-11-26): 꽂힌 검은 언덕 판 하나 마칠 때마다 새로, 뽑은 것은 빠지고, 대수확자 뒤엔 운이 좋아지고, 사이버 검은 내구가 적다.
func _future_balance() -> void:
	var m := Meta.new()
	var r := Rules.new(d, 77)
	var a: Array[int] = m.future_set(r)
	var b: Array[int] = m.future_set(Rules.new(d, 78))
	check.call(a.size() == CyberSwords.FUTURE_HILTS and a == b, "미래 검: 같은 판 사이에는 드나들어도 같은 검이 선다")
	m.take_future_hilt(a[0])
	check.call(m.future_set(r).size() == CyberSwords.FUTURE_HILTS - 1, "미래 검: 뽑은 검은 다음 판까지 안 선다")
	m.runs += 1
	check.call(m.future_set(Rules.new(d, 79)).size() == CyberSwords.FUTURE_HILTS, "미래 검: 언덕 판을 마치면 새로 선다")
	var lo: float = 0.0
	var hi: float = 0.0
	for i in 300:
		for id in CyberSwords.roll_future(Rules.new(d, 1000 + i)):
			lo += d.sword_by_id(id).grade
		for id in CyberSwords.roll_future(Rules.new(d, 1000 + i), CyberSwords.FUTURE_LUCK_FREED):
			hi += d.sword_by_id(id).grade
	check.call(hi > lo * 1.1, "미래 검: 대수확자 뒤에는 평균 등급이 오른다 (%.2f → %.2f)" % [lo / 900.0, hi / 900.0])
	var m2 := Meta.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check.call(m2.future_hilts == m.future_hilts and m2.future_roll_run == m.runs, "미래 검: 선 검과 굴린 판 수가 저장된다")
	var normal: SwordData = null
	var cyber: SwordData = null
	for sw in d.swords:
		if sw.grade == 2 and sw.form == 1 and not sw.unbreakable and sw.inscriptions.is_empty():
			if sw.cyber and cyber == null:
				cyber = sw
			elif not sw.cyber and not sw.field_only and normal == null:
				normal = sw
	if normal and cyber:
		var sn := Sword.new(normal, d)
		var sc := Sword.new(cyber, d)
		check.call(is_equal_approx(sc.max_durability, maxf(1.0, roundf(sn.max_durability * d.powers.cyber_durability))), "사이버 검: 내구가 같은 등급·형태의 %.0f%%" % (d.powers.cyber_durability * 100.0))
