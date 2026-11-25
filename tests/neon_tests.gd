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
