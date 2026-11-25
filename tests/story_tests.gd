extends RefCounted
## 타임트래블러 이야기 테스트(docs/stranger.md 4단계). run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/story_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_shards()
	_vault()
	_guardian()
	_combat()
	_lock()
	_admin()
	Grid.size = Vector2i(34, 22)


func _field() -> Rules:
	var r := Rules.new(d, 3)
	r.start_field()
	Grid.size = FutureLayout.SIZE
	r.lord.pos = Vector2(40, 30)
	return r


func _shards() -> void:
	var m := Meta.new()
	check.call(m.story() == 0 and not m.take_shard(-1) and not m.take_shard(3), "이야기: 처음은 0, 없는 조각은 못 줍는다")
	check.call(m.take_shard(1) and not m.take_shard(1) and m.story_shards.size() == 1 and m.story() == 1, "이야기: 조각은 한 번만 줍는다")
	m.take_shard(0)
	m.take_shard(2)
	check.call(m.story() == 2 and m.story_shards.size() == 3, "이야기: 조각 셋이면 2단계")
	var path: String = "user://test_story_save.json"
	m.open_vault()
	m.save(path)
	var m2 := Meta.load_or_new(path)
	check.call(m2.story_shards.size() == 3 and m2.vault_open and m2.story() == 3 and not m2.time_traveller, "이야기: 조각·금고를 저장하고 읽는다")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var ok: bool = true
	for s in Story.SHARDS:
		var at: Vector2 = s.at
		for t in FutureLayout.TOWERS:
			ok = ok and not (t.rect as Rect2).grow(0.5).has_point(at)
	for p in [Story.VAULT_AT, Story.TIME_LOCK_AT, Story.GUARDIAN_AT, Story.FINAL_AT]:
		for t in FutureLayout.TOWERS:
			ok = ok and not (t.rect as Rect2).grow(0.5).has_point(p)
	check.call(ok, "이야기: 조각·금고·단말 자리는 탑 밖")


func _vault() -> void:
	var m := Meta.new()
	m.take_shard(0)
	m.take_shard(1)
	check.call(not m.open_vault() and not m.vault_open, "금고: 조각 둘로는 안 열린다")
	m.take_shard(2)
	check.call(m.open_vault() and m.vault_open and not m.open_vault(), "금고: 조각 셋이면 한 번 열린다")


func _guardian() -> void:
	var m := Meta.new()
	check.call(not m.guardian_slain() and not m.time_traveller, "금고지기: 금고를 열기 전에는 장치를 안 준다")
	m.set_story(3)
	check.call(m.story() == 3 and not m.time_traveller, "금고지기: 3단계는 장치 없음")
	var r := _field()
	var b: Enemy = r.spawn_field_boss(Story.GUARDIAN_AT, Story.GUARDIAN_ID, Story.GUARDIAN_ZONE)
	check.call(b != null and b.data.future and b.data.acts() == &"grave_knight" and b.max_hp > 500.0, "금고지기: 미래 모습의 무덤 기사 행동으로 선다")
	var slain: Array = [0]
	r.field_boss_slain.connect(func(_e: Enemy) -> void:
		slain[0] += 1
		if m.guardian_slain():
			slain[0] += 10)
	r.hurt(b, 999999.0, Vector2.ZERO, true)
	for t in 5:
		r.step()
	check.call(slain[0] == 11 and m.time_traveller and m.story() == 4, "금고지기: 쓰러뜨리면 타임트래블러를 받는다")
	check.call(not m.guardian_slain(), "금고지기: 두 번 받지 않는다")
	var path: String = "user://test_story_save2.json"
	m.save(path)
	check.call(Meta.load_or_new(path).time_traveller, "금고지기: 장치를 저장한다")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _combat() -> void:
	var m := Meta.new()
	var r := _field()
	check.call(not m.can_travel(r), "시대: 장치가 없으면 못 건넌다")
	m.time_traveller = true
	check.call(m.can_travel(r) and not TimeTravel.in_combat(r), "시대: 장치가 있고 조용하면 건넌다")
	var e: Enemy = r.spawn_at(&"drone", r.lord.pos + Vector2(6.0, 0.0))
	check.call(TimeTravel.in_combat(r) and not m.can_travel(r), "시대: 가까운 적이 있으면 싸움 중이라 못 건넌다")
	e.dead = true
	check.call(m.can_travel(r), "시대: 적이 사라지면 다시 건넌다")
	var far: Enemy = r.spawn_at(&"drone", r.lord.pos + Vector2(30.0, 0.0))
	check.call(not TimeTravel.in_combat(r) and far != null, "시대: 먼 적은 싸움 중이 아니다")
	var b: Enemy = r.spawn_field_boss(Vector2(40, 40), Story.GUARDIAN_ID, Story.GUARDIAN_ZONE)
	r.field_boss_state = Rules.BOSS_AWAKE
	check.call(TimeTravel.in_combat(r) and b != null, "시대: 깨어난 보스는 싸움 중")


func _lock() -> void:
	var m := Meta.new()
	check.call(not m.buy_time_lock() and not m.time_lock, "시간 고정: 조각이 모자라면 못 산다")
	m.shards = Story.TIME_LOCK_COST * 2
	check.call(m.buy_time_lock() and m.time_lock and m.shards == Story.TIME_LOCK_COST, "시간 고정: 조각을 내고 산다")
	check.call(not m.buy_time_lock() and m.shards == Story.TIME_LOCK_COST, "시간 고정: 이미 있으면 조각을 또 받지 않는다")
	var path: String = "user://test_story_save3.json"
	m.save(path)
	var m2 := Meta.load_or_new(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check.call(m2.time_lock, "시간 고정: 저장한다")
	Grid.size = Vector2i(34, 22)
	var r := Rules.new(d, 7, m2)
	var h: Hilt = r.hilts[0]
	check.call(h.omen == 3 and h.shown_omen == 3 and not m2.time_lock, "시간 고정: 다음 언덕 첫 손잡이 조짐이 3이고 한 번 쓰면 꺼진다")


func _admin() -> void:
	var m := Meta.new()
	m.set_story(2)
	check.call(m.story() == 2 and m.story_shards.size() == 3 and m.rift_open() and not m.vault_open, "관리: 이야기 2")
	m.set_story(4)
	check.call(m.story() == 4 and m.time_traveller and m.vault_open, "관리: 이야기 4")
	m.set_story(0)
	check.call(m.story() == 0 and not m.time_traveller and m.story_shards.is_empty(), "관리: 이야기 0은 처음으로")
	var msg: String = AdminCmd.apply(AdminCmd.parse("이야기 1"), null, m)
	check.call(m.story() == 1 and msg.begins_with("관리"), "관리: `이야기 n` 명령")
	var r := _field()
	AdminCmd.apply(AdminCmd.parse("시대 미래"), r, m)
	var to_future: bool = Meta.go_future
	Meta.go_future = false
	r.era = Rules.ERA_FUTURE
	AdminCmd.apply(AdminCmd.parse("시대 현재"), r, m)
	var to_now: bool = Meta.go_present
	Meta.go_present = false
	check.call(to_future and to_now, "관리: `시대 미래`·`시대 현재` 명령")
