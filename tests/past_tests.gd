extends RefCounted
## 과거 신화 구역 테스트(docs/stranger.md 5단계). run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/past_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_unlock()
	_travel()
	_era()
	_reforge()
	_cache_save()
	_packs()
	_admin()
	Grid.size = Vector2i(34, 22)


func _field() -> Rules:
	var r := Rules.new(d, 5)
	r.start_field()
	Grid.size = PastLayout.SIZE
	r.lord.pos = PastLayout.START
	return r


func _unlock() -> void:
	var m := Meta.new()
	check.call(not m.past_open(), "과거: 타임트래블러가 없으면 과거가 안 열린다")
	m.set_story(4)
	check.call(m.past_open() and TimeTravel.NAMES.has(TimeTravel.ERA_PAST), "과거: 타임트래블러를 얻으면 과거가 열린다")
	check.call(Story.FINAL_LINES.any(func(l: String) -> bool: return l.contains("최초의 대장간")), "과거: 낯선 사람의 마지막 말이 첫 대장간을 가리킨다")


func _travel() -> void:
	var m := Meta.new()
	m.set_story(4)
	var r := _field()
	check.call(m.can_travel(r), "과거: 적이 없으면 건널 수 있다")
	r.spawn_at(&"stag", r.lord.pos + Vector2(5.0, 0.0))
	check.call(TimeTravel.in_combat(r) and not m.can_travel(r), "과거: 싸움 중에는 시간이 막힌다")


func _strike(era: StringName) -> Dictionary:
	var r := _field()
	r.era = era
	var e: Enemy = r.spawn_at(&"stone", r.lord.pos + Vector2(3.0, 0.0))
	return r.powers.strike(e, 10.0, Vector2(2.0, 0.0))


func _era() -> void:
	var now: Dictionary = _strike(&"")
	var past: Dictionary = _strike(Rules.ERA_PAST)
	var fut: Dictionary = _strike(Rules.ERA_FUTURE)
	check.call(is_equal_approx(now.dmg, 10.0) and is_equal_approx(fut.dmg, 10.0) and now.knock == Vector2(2.0, 0.0), "과거 능력: 과거가 아니면 피해와 밀림이 그대로")
	check.call(is_equal_approx(past.dmg, 10.0 * PastLayout.DMG_MULT) and is_equal_approx(past.knock.x, 2.0 * PastLayout.KNOCK_MULT), "과거 능력: 과거에서만 피해 +10%, 밀림 +25%")
	var a := _field()
	var b := _field()
	b.era = Rules.ERA_PAST
	check.call(a.state_hash() != b.state_hash(), "과거 능력: era가 state_hash에 든다")
	check.call(_strike(Rules.ERA_PAST).dmg == past.dmg, "과거 능력: 같은 입력이면 같은 결과")


func _sheath_meta() -> Meta:
	var m := Meta.new()
	for s in d.swords:
		if s.grade >= d.meta.sheath_min_grade and not s.unbreakable:
			m.sheath_id = s.id
			m.note_found(s.id)
			break
	return m


func _reforge() -> void:
	var none := Meta.new()
	check.call(String(none.reforge(d).why) == "none", "다시 벼리기: 검집이 비면 못 한다")
	var m := _sheath_meta()
	check.call(m.sheath_id >= 0, "다시 벼리기: 시험할 검집 검이 있다")
	m.shards = PastLayout.REFORGE_COST - 1
	check.call(String(m.reforge(d).why) == "poor" and m.shards == PastLayout.REFORGE_COST - 1 and m.reforged.is_empty(), "다시 벼리기: 조각이 모자라면 못 한다")
	var base: float = m.sheath_sword(d).max_durability
	m.shards = PastLayout.REFORGE_COST * 2
	check.call(String(m.reforge(d).why) == "ok" and m.shards == PastLayout.REFORGE_COST, "다시 벼리기: 조각을 내고 한 번 벼린다")
	check.call(String(m.reforge(d).why) == "done" and m.shards == PastLayout.REFORGE_COST, "다시 벼리기: 같은 검은 한 번만(조각을 또 받지 않는다)")
	var after: float = m.sheath_sword(d).max_durability
	check.call(is_equal_approx(after, roundf(base * (1.0 + PastLayout.REFORGE_DUR))) and after > base, "다시 벼리기: 검집에서 꺼낸 검의 내구가 10% 오른다")
	var path: String = "user://test_past_save.json"
	m.save(path)
	var m2 := Meta.load_or_new(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check.call(m2.reforged.has(str(m.sheath_id)) and String(m2.reforge(d).why) == "done" and is_equal_approx(m2.sheath_sword(d).max_durability, after), "다시 벼리기: 저장하고 읽는다")


func _cache_save() -> void:
	var m := Meta.new()
	check.call(m.past_cache() == PastLayout.CACHE_SHARDS and m.shards == PastLayout.CACHE_SHARDS, "과거 함: 처음 열면 조각")
	check.call(m.past_cache() == 0 and m.shards == PastLayout.CACHE_SHARDS, "과거 함: 한 번만")
	var path: String = "user://test_past_save2.json"
	m.save(path)
	var m2 := Meta.load_or_new(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check.call(m2.past_cache() == 0, "과거 함: 저장하고 읽어도 한 번만")


func _packs() -> void:
	var ok: bool = true
	for k in ["stag", "stone", "ward"]:
		ok = ok and d.enemies.has(StringName(k)) and d.enemies[StringName(k)].past
	check.call(ok, "과거 적: 사슴 정령·돌 파수꾼·돌방패 수호자 자료가 있다")
	var r := _field()
	var b: Dictionary = PastLayout.blockers()
	r.set_blockers(b.rects, b.circles, b.low_rects, b.low_circles)
	var n: int = 0
	for id in PastLayout.PACKS:
		n += r.spawn_pack(StringName(id), PastLayout.PACKS[id]).size()
	check.call(n == 4 + 2 + 4, "과거 적: 무리 셋이 선다")
	var free: bool = true
	for t in PastLayout.TREES:
		for id in PastLayout.PACKS:
			free = free and Vector2(t.x, t.y).distance_to(PastLayout.PACKS[id].at) > t.z + 1.0
	check.call(free, "과거 적: 무리 자리가 나무 안이 아니다")
	check.call(PastLayout.START.distance_to(PastLayout.ALTAR_AT) > 10.0 and not (PastLayout.ALTAR_AT.distance_to(PastLayout.EXIT_AT) < 5.0), "과거 구역: 시작과 제단, 돌문 자리")


func _admin() -> void:
	var r := _field()
	var m := Meta.new()
	var msg: String = AdminCmd.apply(AdminCmd.parse("시대 과거"), r, m)
	var to_past: bool = Meta.go_past
	Meta.go_past = false
	check.call(to_past and msg.begins_with("관리"), "관리: `시대 과거` 명령")
	r.era = Rules.ERA_PAST
	var again: String = AdminCmd.apply(AdminCmd.parse("시대 과거"), r, m)
	AdminCmd.apply(AdminCmd.parse("시대 현재"), r, m)
	var to_now: bool = Meta.go_present
	Meta.go_present = false
	check.call(to_now and again.contains("이미"), "관리: 과거에서 `시대 현재`로 돌아오고 이미 과거면 알린다")
