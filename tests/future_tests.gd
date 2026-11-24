extends RefCounted
## 녹슨 미래 구역 테스트(docs/stranger.md 3단계). run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/future_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_rift()
	_era()
	_packs()
	_only_here()
	_save()
	Grid.size = Vector2i(34, 22)


func _rift() -> void:
	var m := Meta.new()
	check.call(not m.rift_open(), "미래 구역: 사이버 카타나를 얻기 전에는 틈이 안 선다")
	m.stranger_seen = 4
	m.stranger_drop = 2
	check.call(not m.rift_open(), "미래 구역: 물건만 떨어져 있으면 아직 안 선다")
	m.take_stranger_sword()
	check.call(m.rift_open(), "미래 구역: 낯선 사람 이야기를 마치면 틈이 선다")
	check.call(FutureLayout.RIFT_FIELD.distance_to(FieldLayout.STRANGER_SPOTS[0]) < 6.0 and FieldLayout.START.distance_to(FutureLayout.RIFT_FIELD) > 3.0, "미래 구역: 틈은 낯선 사람이 서던 자리 곁")


func _inp(attack: bool = false) -> LordInput:
	var i := LordInput.new()
	i.attack = attack
	return i


func _echo_hits(era: StringName) -> int:
	Grid.size = Vector2i(34, 22)
	var r := Rules.new(d, 1)
	r.start_night()
	r.lord.face = 0.0
	r.enemies.clear()
	r.era = era
	var s := r.give(d.sword_by_name("녹슨 장검"), 0)
	s.ins.clear()
	var p := PatternData.new()
	p.moves = PackedStringArray(["sweep", "spin"])
	s.pattern = p
	r.debug_god = true
	var e := r.spawn_at(&"giant", r.lord.pos + Vector2(1.0, 0.0))
	e.max_hp = 99999.0
	e.hp = e.max_hp
	e.stun = 99.0
	var n := [0]
	r.enemy_hit.connect(func(_e: Enemy, _d: float, _b: bool) -> void: n[0] += 1)
	for _k in 2:
		r.lord.cooldown = 0.0
		r.freeze = 0
		r.step(_inp(true))
	for _k in 24:
		r.freeze = 0
		r.step(_inp())
	return n[0]


func _era() -> void:
	Grid.size = Vector2i(34, 22)
	var a := Rules.new(d, 1)
	a.start_night()
	a.give(d.sword_by_name("녹슨 장검"), 0)
	var b := Rules.new(d, 1)
	b.start_night()
	b.give(d.sword_by_name("녹슨 장검"), 0)
	b.era = Rules.ERA_FUTURE
	var ra: float = a.powers.stats().reach
	var rb: float = b.powers.stats().reach
	check.call(is_equal_approx(rb, ra * FutureLayout.REACH_MULT) and FutureLayout.REACH_MULT == 1.15, "미래 능력: 미래에서만 사거리 +15%% (%.2f → %.2f)" % [ra, rb])
	check.call(a.era == &"" and a.state_hash() != b.state_hash(), "미래 능력: 시대는 규칙 상태(state_hash에 든다)")
	var plain: int = _echo_hits(&"")
	var fut: int = _echo_hits(Rules.ERA_FUTURE)
	check.call(plain == 2 and fut == 3, "미래 능력: 미래에서만 마무리 뒤 데이터 메아리가 한 번 더 친다(%d → %d)" % [plain, fut])
	check.call(_echo_hits(Rules.ERA_FUTURE) == fut, "미래 능력: 같은 입력이면 결과가 같다")


func _packs() -> void:
	Grid.size = FutureLayout.SIZE
	var r := Rules.new(d, 5)
	r.era = Rules.ERA_FUTURE
	r.start_field()
	var b: Dictionary = FutureLayout.blockers()
	r.set_blockers(b.rects, b.circles, b.low_rects, b.low_circles)
	check.call(FutureLayout.PACKS.size() >= 2 and FutureLayout.PACKS.size() <= 3, "미래 구역: 무리 2~3개")
	var ok: bool = true
	var total: int = 0
	var want: int = 0
	for id in FutureLayout.PACKS:
		var P: Dictionary = FutureLayout.PACKS[id]
		var es: Array[Enemy] = r.spawn_pack(StringName(id), P)
		var w: int = 0
		for f in P.foes:
			w += int(f[1])
			ok = ok and d.enemies.has(f[0]) and d.enemies[f[0]].future
		want += w
		total += es.size()
		ok = ok and es.size() == w and r.pack_alive(StringName(id)) == w
		ok = ok and not Blockers.inside(P.at, b.rects, b.circles)
	check.call(ok and total == want and total >= 8, "미래 구역: 무리가 선다(%d마리, 녹슨 드론·사수, 막힘 밖)" % total)
	var drone: EnemyData = d.enemies[&"drone"]
	var husk: EnemyData = d.enemies[&"husk"]
	check.call(drone.acts() == &"wolf" and husk.acts() == &"archer" and drone.speed > d.enemies[&"wolf"].speed and husk.shot_range > 0.0, "미래 구역: 드론은 늑대, 사수는 활잡이의 행동을 빌린다")
	for _k in 90:
		r.step(_inp())
	check.call(r.state_hash() == r.state_hash() and r.enemies.size() == total, "미래 구역: 틱이 돈다")
	check.call(FutureLayout.START.distance_to(FutureLayout.EXIT_AT) < 4.0 and not Blockers.inside(FutureLayout.START, b.rects, b.circles, b.low_rects, b.low_circles) and not Blockers.inside(FutureLayout.TERMINAL_AT, b.rects, b.circles, b.low_rects, b.low_circles) and not Blockers.inside(FutureLayout.CACHE_AT, b.rects, b.circles, b.low_rects, b.low_circles), "미래 구역: 시작·틈·단말·상자는 막힘 밖")


func _only_here() -> void:
	var m := Meta.new()
	check.call(m.future_cache() == FutureLayout.CACHE_SHARDS and m.shards == FutureLayout.CACHE_SHARDS, "미래 상자: 조각을 준다")
	check.call(m.future_cache() == 0 and m.shards == FutureLayout.CACHE_SHARDS, "미래 상자: 한 번만 준다")
	check.call(m.future_terminal() and m.pack.has(&"note"), "단말: 다음 언덕 판에 조짐 쪽지(note)를 건넨다")
	check.call(not m.future_terminal() and m.pack.count(&"note") == 1, "단말: 겹쳐 받지 않는다")
	check.call(d.village.goods_by_id(&"note") != null, "단말: 쪽지는 마을 물건 note와 같은 것(손잡이 조짐을 모두 보인다)")


func _save() -> void:
	var path: String = "user://test_future_save.json"
	var m := Meta.new()
	m.stranger_done = true
	m.future_cache()
	m.future_terminal()
	m.save(path)
	var m2 := Meta.load_or_new(path)
	check.call(m2.rift_open() and m2.field_found.has(FutureLayout.CACHE_ID) and m2.future_cache() == 0 and m2.pack.has(&"note") and m2.shards == FutureLayout.CACHE_SHARDS, "미래 구역: 상자·단말·틈을 저장하고 읽는다")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
