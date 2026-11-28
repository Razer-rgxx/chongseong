extends RefCounted
## 19단계 지하 무덤 테스트(docs/outside.md). 31단계(docs/field_life.md): 8~10구역·방마다 적 +2·정예 하나, 무덤 주인 2000·24·두 번 부르기·×1.3, 큰 관의 오픈월드 한정 검.
## run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/crypt_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_data()
	_layout()
	_doors()
	_clear_open()
	_coffins()
	_final_room()
	_elites()
	_two_summons()
	_big_coffin_sword()
	_persist()
	_death()
	_replay()
	_save()
	_entrance()
	Grid.size = Vector2i(34, 22)


## 31단계 기대값: 방마다 적 수(19단계 +2, r5는 +3)와 세기 구역.
const WANT_FOES: Dictionary = {&"r1": 6, &"r2": 7, &"r3": 7, &"r5": 8, &"r4": 7}
const WANT_ZONE: Dictionary = {&"r1": 8, &"r2": 8, &"r3": 9, &"r5": 10, &"r4": 9}


func _crypt(seed_value: int = 1, meta: Meta = null) -> CryptRun:
	var r := Rules.new(d, seed_value)
	Grid.size = CryptLayout.SIZE
	r.start_field()
	r.lord.pos = CryptLayout.START
	r.lord.prev_pos = r.lord.pos
	r.debug_god = true
	var m: Meta = meta if meta != null else Meta.new()
	return CryptRun.new(r, m)


func _go(c: CryptRun, p: Vector2) -> void:
	c.rules.lord.pos = p
	c.rules.lord.prev_pos = p
	c.rules.step()
	c.step()


## 그 방의 적(무리·무덤 주인)을 모두 쓰러뜨린다.
func _wipe(c: CryptRun, id: StringName) -> void:
	for e in c.rules.enemies.duplicate():
		if not e.dead and (e.pack == id or e == c.rules.field_boss):
			c.rules.hurt(e, 1.0e9, Vector2.ZERO, false)
	c.rules.step()
	c.step()


func _data() -> void:
	var L: EnemyData = d.enemies[&"crypt_lord"]
	var K: EnemyData = d.enemies[FieldLayout.BOSS_ID]
	check.call(L.boss and L.big and L.token_cost == 0 and L.display_name == "무덤 주인", "무덤 주인: 표 없이 덤비는 큰 적, 이름 무덤 주인")
	check.call(L.hp == 2000.0 and L.damage == 24.0 and L.summon_count == 4 and L.summon_max == 8 and L.summon_below == 0.5 and L.summon_again == 0.25 and L.rage_mult == 1.3, "무덤 주인(31단계): 체력 2000, 피해 24, 망령 4마리를 체력 50%·25%에서 두 번, 빨라짐 ×1.3")
	check.call(L.radius < K.radius and L.model_scale < K.model_scale, "무덤 주인: 몸은 무덤 기사보다 작다")
	check.call(K.summon_again == 0.0 and K.summon_max == K.summon_count and K.hp == 1800.0 and K.rage_mult == 1.2, "무덤 기사: 그대로(부르기 한 번, 1800, ×1.2)")
	check.call(L.swing_arc == K.swing_arc and L.charge_length == K.charge_length and L.rage_hp == K.rage_hp, "무덤 주인: 행동(휘두르기·돌진·빨라짐)은 무덤 기사를 빌린다")
	check.call(CryptLayout.COFFIN_MIN == 10 and CryptLayout.COFFIN_MAX == 25 and CryptLayout.BIG_SHARDS == 60, "무덤: 관 조각 10~25, 큰 관 60")


func _layout() -> void:
	var rect_all := Rect2(Vector2.ZERO, Vector2(CryptLayout.SIZE))
	check.call(CryptLayout.ROOM_ORDER.size() == 6 and CryptLayout.ROOMS.size() == 6 and CryptLayout.DOORS.size() == 5, "배치: 방 6개, 문 5개")
	var ok_in: bool = true
	var ok_pack: bool = true
	var ok_zone: bool = true
	var ok_coffin: bool = true
	var ok_dist: bool = true
	for id in CryptLayout.ROOM_ORDER:
		var R: Dictionary = CryptLayout.ROOMS[id]
		var rect: Rect2 = R.rect
		ok_in = ok_in and rect_all.encloses(rect)
		for id2 in CryptLayout.ROOM_ORDER:
			if id2 != id and rect.intersects(CryptLayout.ROOMS[id2].rect):
				ok_in = false
		var home: Vector2 = CryptLayout.home_of(id)
		ok_coffin = ok_coffin and rect.grow(-1.5).has_point(R.coffin) and home.distance_to(R.coffin) > 3.5
		ok_dist = ok_dist and rect.grow(-1.5).has_point(home)
		if R.has("pack"):
			var n: int = 0
			for f in R.pack.foes:
				n += int(f[1])
				ok_pack = ok_pack and d.enemies.has(f[0])
			ok_pack = ok_pack and n == int(WANT_FOES[id])
			var has_elite: bool = false
			for f in R.pack.foes:
				has_elite = has_elite or StringName(f[0]) == StringName(R.pack.get("elite", &""))
			ok_pack = ok_pack and has_elite and StringName(R.pack.elite) != &"caller"
			ok_zone = ok_zone and int(R.pack.zone) == int(WANT_ZONE[id]) and int(R.pack.zone) <= d.run.zone_hp.size()
			ok_dist = ok_dist and rect.grow(-R.pack.wander - 1.0).has_point(home)
		else:
			ok_zone = ok_zone and int(R.boss.zone) == 10 and CryptLayout.LORD_ZONE == 10 and d.enemies.has(R.boss.kind)
	check.call(ok_in, "배치: 방은 무덤 안에 있고 서로 겹치지 않는다")
	check.call(ok_pack, "배치(31단계): 방마다 적 +2(서쪽 끝 r5는 +3), 적 종류가 표에 있고 정예 종류가 무리에 있다")
	check.call(ok_zone, "배치(31단계): 세기 8~10구역(r1·r2 8, r3·r4 9, r5 10, 무덤 주인 10), 구역 표 끝을 넘지 않는다")
	check.call(ok_coffin and ok_dist, "배치: 관은 방 안쪽, 무리·무덤 주인 자리에서 떨어져 있다. 무리는 서성여도 방 안")
	check.call(CryptLayout.ROOMS[&"r6"].has("boss") and bool(CryptLayout.ROOMS[&"r6"].big) and not CryptLayout.ROOMS[&"r1"].has("big"), "배치: 마지막 방만 무덤 주인과 큰 관")
	# 문은 두 방 사이에 닿고 걷는 곳이 두 방과 겹친다
	var ok_door: bool = true
	for k in CryptLayout.DOORS:
		var D: Dictionary = CryptLayout.DOORS[k]
		var a: Rect2 = CryptLayout.ROOMS[D.rooms[0]].rect
		var b: Rect2 = CryptLayout.ROOMS[D.rooms[1]].rect
		var w: Rect2 = D.walk
		ok_door = ok_door and w.intersects(a) and w.intersects(b) and w.encloses(D.gap) and not D.gap.intersects(a) and not D.gap.intersects(b)
	check.call(ok_door, "배치: 문 복도는 두 방 사이에 닿고, 걷는 곳이 두 방에 겹친다")
	# 모든 문을 열면 입구에서 모든 방에 닿는다(나무 모양)
	var seen := {&"r1": true}
	var grew: bool = true
	while grew:
		grew = false
		for k in CryptLayout.DOORS:
			var rs: Array = CryptLayout.DOORS[k].rooms
			if seen.has(rs[0]) != seen.has(rs[1]):
				seen[rs[0]] = true
				seen[rs[1]] = true
				grew = true
	check.call(seen.size() == 6, "배치: 입구 방에서 모든 방에 이어진다")
	check.call(CryptLayout.room_at(CryptLayout.START) == &"r1" and CryptLayout.EXIT_AT.distance_to(CryptLayout.START) < 3.0 and CryptLayout.ROOMS[&"r1"].rect.has_point(CryptLayout.EXIT_AT), "배치: 시작은 입구 방, 나가는 문 가까이")


func _doors() -> void:
	var c := _crypt()
	c.step()
	check.call(c.room == &"r1" and c.rules.packs.has(&"r1") and c.rules.pack_alive(&"r1") == int(WANT_FOES[&"r1"]), "문: 방에 들어서면 그 방 무리가 선다(31단계 6마리)")
	check.call(c.door_closed(&"d12") and not c.door_closed(&"d23") and not c.door_closed(&"d46"), "문: 들어선 방의 문만 닫힌다")
	# 닫힌 문 쪽으로 밀려도 못 나간다
	var p: Vector2 = c.push(Vector2(35, 57))
	check.call(CryptLayout.ROOMS[&"r1"].rect.has_point(p), "문: 닫힌 문 복도로는 못 들어간다(방 안으로 밀려난다)")
	var wall: Vector2 = c.push(Vector2(24, 65))
	check.call(CryptLayout.ROOMS[&"r1"].rect.has_point(wall) and wall.x > 26.0, "문: 방 벽 밖으로는 못 나간다(방 안으로 밀려난다)")
	var open: Vector2 = CryptLayout.push_in(Vector2(35, 56), {&"d12": 1})
	check.call(absf(open.x - 35.0) < 0.01 and absf(open.y - 56.0) < 0.01, "문: 열린 문 복도는 걸을 수 있다")
	# 방 가장자리(들어선 곳 밖)에서는 문이 안 닫힌다: 물러날 수 있다
	var c2 := _crypt()
	c2.rules.lord.pos = Vector2(35, 57.5)
	c2.step()
	check.call(c2.room == &"" and not c2.door_closed(&"d12") and c2.rules.packs.is_empty(), "문: 방 가장자리(들어서기 전)에서는 문이 안 닫히고 무리도 안 선다")


func _clear_open() -> void:
	var c := _crypt(2)
	c.step()
	var got: Array = []
	c.room_cleared.connect(func(id: StringName) -> void: got.append(id))
	check.call(not c.cleared(&"r1") and c.door_closed(&"d12"), "열림: 무리가 남아 있으면 안 쓰러뜨린 방")
	var alive: Array[Enemy] = []
	for e in c.rules.enemies:
		if e.pack == &"r1":
			alive.append(e)
	for i in alive.size() - 1:
		c.rules.hurt(alive[i], 1.0e9, Vector2.ZERO, false)
	c.rules.step()
	c.step()
	check.call(not c.cleared(&"r1") and c.door_closed(&"d12"), "열림: 하나라도 남으면 문은 닫혀 있다")
	_wipe(c, &"r1")
	check.call(c.cleared(&"r1") and not c.door_closed(&"d12") and got == [&"r1"], "열림: 무리를 다 쓰러뜨리면 문이 열리고 신호가 한 번 온다")
	check.call(c.meta.crypt_cleared.has("r1"), "열림: 쓰러뜨린 방이 Meta에 적힌다")
	c.step()
	check.call(got == [&"r1"], "열림: 신호는 한 번만")
	# 열린 문으로 두 번째 방에 들어서면 다시 닫힌다
	_go(c, Vector2(35, 46))
	check.call(c.room == &"r2" and c.rules.packs.has(&"r2") and c.door_closed(&"d12") and c.door_closed(&"d23") and c.door_closed(&"d24") and not c.door_closed(&"d35"), "열림: 다음 방에 들어서면 그 방의 문이 모두 닫힌다(왔던 문도)")
	# 쓰러뜨린 방은 다시 들어서도 무리가 안 서고 문이 안 닫힌다
	_go(c, Vector2(35, 63))
	check.call(c.room == &"r1" and not c.door_closed(&"d12"), "열림: 쓰러뜨린 방에 다시 들어서도 문은 열려 있다")
	var before: int = c.rules.enemies.size()
	c.step()
	check.call(c.rules.enemies.size() == before, "열림: 쓰러뜨린 방에는 무리가 다시 서지 않는다")
	# 저장된 방은 처음부터 안 선다(쓰러졌다 돌아온 경우)
	var m := Meta.new()
	m.crypt_cleared["r1"] = 1
	var c3 := _crypt(3, m)
	c3.step()
	check.call(c3.room == &"r1" and c3.rules.packs.is_empty() and not c3.door_closed(&"d12") and c3.cleared(&"r1"), "열림: 이미 쓰러뜨린 방은 무리가 안 서고 문이 열려 있다")


func _coffins() -> void:
	var c := _crypt(4)
	c.step()
	check.call(not c.coffin_ready(&"r1"), "관: 방을 쓰러뜨리기 전에는 못 연다")
	check.call(c.meta.crypt_open("r1").shards == 0 and c.meta.shards == 0, "관: 쓰러뜨리기 전에 열면 아무것도 못 받는다")
	_wipe(c, &"r1")
	check.call(c.coffin_ready(&"r1"), "관: 방을 쓰러뜨리면 열 수 있다")
	var r: Dictionary = c.meta.crypt_open("r1")
	check.call(r.shards >= 10 and r.shards <= 25 and not r.charm and c.meta.shards == r.shards, "관: 조각 10~25를 받는다")
	check.call(c.meta.crypt_opened.has("r1") and not c.coffin_ready(&"r1"), "관: 열면 다시 못 연다")
	var again: Dictionary = c.meta.crypt_open("r1")
	check.call(again.shards == 0 and c.meta.shards == r.shards, "관: 같은 관에서 또 받지 못한다")
	# 분포: 여러 관이 모두 범위 안이고 서로 다를 수 있다
	var seen := {}
	var in_range: bool = true
	for i in 40:
		var m := Meta.new()
		m.rng.seed = i
		m.crypt_cleared["r3"] = 1
		var n: int = int(m.crypt_open("r3").shards)
		seen[n] = true
		in_range = in_range and n >= 10 and n <= 25
	check.call(in_range and seen.size() > 5, "관: 조각은 범위 안에서 Meta.rng로 고르게 뽑힌다")
	var m1 := Meta.new()
	var m2 := Meta.new()
	m1.rng.seed = 7
	m2.rng.seed = 7
	m1.crypt_cleared["r4"] = 1
	m2.crypt_cleared["r4"] = 1
	check.call(m1.crypt_open("r4").shards == m2.crypt_open("r4").shards, "관: 같은 시드면 같은 조각")
	check.call(c.meta.crypt_open("nope").shards == 0, "관: 없는 방은 못 연다")


func _final_room() -> void:
	var c := _crypt(5)
	_go(c, Vector2(57, 34.0))
	check.call(c.room == &"r6" and c.rules.field_boss != null and c.rules.field_boss.data.id == &"crypt_lord", "마지막 방: 들어서면 무덤 주인이 선다")
	check.call(c.door_closed(&"d46") and not c.cleared(&"r6") and c.rules.pack_alive(&"r6") == 0, "마지막 방: 무덤 주인이 서 있는 동안 문이 닫힌다")
	check.call(c.rules.field_boss.pos.distance_to(CryptLayout.ROOMS[&"r6"].boss.at) < 0.01 and CryptLayout.ROOMS[&"r6"].rect.has_point(c.rules.field_boss.pos), "마지막 방: 방 안에 선다")
	# 무덤 주인이 깨어나 움직인다
	var woke: Array = []
	c.rules.field_boss_woke.connect(func(_e: Enemy) -> void: woke.append(1))
	for i in 5:
		c.rules.step()
	check.call(c.rules.field_boss_state == Rules.BOSS_AWAKE and woke.size() == 1, "마지막 방: 가까이 가면 깨어난다")
	check.call(not c.coffin_ready(&"r6") and c.meta.crypt_open("r6").shards == 0, "마지막 방: 무덤 주인을 쓰러뜨리기 전에는 큰 관을 못 연다")
	_wipe(c, &"r6")
	check.call(c.cleared(&"r6") and not c.door_closed(&"d46") and c.meta.crypt_cleared.has("r6"), "마지막 방: 무덤 주인을 쓰러뜨리면 문이 열리고 적힌다")
	var r: Dictionary = c.meta.crypt_open("r6")
	check.call(r.shards == 60 and r.charm and c.meta.shards == 60 and c.meta.pack.has(&"charm"), "마지막 방: 큰 관은 조각 60과 운 부적(Meta.pack)")
	var again: Dictionary = c.meta.crypt_open("r6")
	check.call(again.shards == 0 and c.meta.shards == 60 and c.meta.pack.count(&"charm") == 1, "마지막 방: 큰 관도 한 번만, 부적이 겹치지 않는다")
	# 이미 운 부적이 있으면 부적은 다시 안 든다(조각은 받는다)
	var m := Meta.new()
	m.pack.append(&"charm")
	m.crypt_cleared["r6"] = 1
	var r2: Dictionary = m.crypt_open("r6")
	check.call(r2.shards == 60 and not r2.charm and m.pack.count(&"charm") == 1, "마지막 방: 이미 운 부적이 있으면 겹쳐 들지 않는다")
	# 부적을 쥐고 다음 판을 시작한다
	var next := Rules.new(d, 9, c.meta)
	check.call(next.has_pack(&"charm"), "마지막 방: 얻은 운 부적을 다음 판이 쥐고 시작한다")
	# 불려 온 망령의 세기는 방이 정한다
	check.call(c.rules.field_boss_zone == 10, "마지막 방: 불려 오는 적의 세기 구역은 10")


## 31단계: 방마다 정예 하나(언덕 밤의 정예와 같은 배수: Rules.make_elite).
func _elites() -> void:
	var R := d.run
	var ok: bool = true
	var detail: String = ""
	for id in [&"r1", &"r2", &"r3", &"r5", &"r4"]:
		var c := _crypt(7)
		var P: Dictionary = CryptLayout.ROOMS[id].pack
		var made: Array[Enemy] = c.rules.spawn_pack(id, P)
		var elites: Array[Enemy] = []
		var plain: Enemy = null
		for e in made:
			if e.elite:
				elites.append(e)
			elif e.data.id == StringName(P.elite) and plain == null:
				plain = e
		var one: bool = elites.size() == 1 and made.size() == int(WANT_FOES[id]) and elites[0].data.id == StringName(P.elite)
		if one:
			var e: Enemy = elites[0]
			var zk: float = d.run.zone_hp[int(P.zone) - 1]
			one = absf(e.max_hp - e.data.hp * zk * R.elite_hp) < 0.01 and e.hp == e.max_hp and absf(e.radius - e.data.radius * R.elite_size) < 0.0001
			if plain != null:
				one = one and absf(e.damage - plain.damage * R.elite_damage) < 0.001
		ok = ok and one
		detail += "%s %d " % [id, elites.size()]
	check.call(ok, "정예(31단계): 방마다 정해진 종류 하나가 정예(체력 %.0f배·피해 %.1f배·몸 %.1f배, 언덕과 같다) [%s]" % [R.elite_hp, R.elite_damage, R.elite_size, detail.strip_edges()])
	# 언덕 밤의 정예도 같은 함수를 쓴다(배수 그대로)
	var r := Rules.new(d, 4)
	r.start_night()
	var hill := r._spawn_elite()
	check.call(hill.elite and absf(hill.radius - hill.data.radius * R.elite_size) < 0.0001 and hill.hp == hill.max_hp, "정예: 언덕 밤의 정예는 그대로(make_elite)")
	# 들판 무리는 정예가 없다
	var f := _crypt(7)
	var any: bool = false
	for e in f.rules.spawn_pack(&"road_south"):
		any = any or e.elite
	check.call(not any, "정예: 들판 무리(elite 칸 없음)는 그대로")


## 무덤 주인을 깨워 n틱 돌린다(영주는 곁에 서 있고 무적).
func _boss_ticks(c: CryptRun, n: int, until_summoned: int = -1) -> void:
	for i in n:
		c.rules.step()
		if until_summoned >= 0 and c.rules.field_boss.summoned >= until_summoned and c.rules.field_boss.act == &"":
			return


## 31단계: 무덤 주인은 체력 50%와 25%에서 망령 4마리씩 두 번 부른다. 무덤 기사는 50%에서 한 번.
func _two_summons() -> void:
	var c := _crypt(11)
	_go(c, Vector2(57, 34.0))
	_boss_ticks(c, 5)
	var b: Enemy = c.rules.field_boss
	var calls: Array = []
	c.rules.enemy_act.connect(func(e: Enemy, act: StringName, info: Dictionary) -> void:
		if e == b and act == &"call":
			calls.append(int(info.count)))
	_boss_ticks(c, 150)
	check.call(b.summoned == 0 and calls.is_empty(), "두 번 부르기: 체력이 50% 위면 안 부른다")
	b.hp = b.max_hp * 0.49
	_boss_ticks(c, 300, 4)
	check.call(b.summoned == 4 and calls == [4], "두 번 부르기: 50% 밑에서 망령 4마리")
	b.hp = b.max_hp * 0.3
	_boss_ticks(c, 300)
	check.call(b.summoned == 4 and calls.size() == 1, "두 번 부르기: 25% 위에서는 다시 안 부른다")
	b.hp = b.max_hp * 0.24
	_boss_ticks(c, 300, 8)
	var minions: int = 0
	for e in c.rules.enemies:
		minions += 1 if e.caller == b.id and not e.dead else 0
	check.call(b.summoned == 8 and calls == [4, 4] and minions == 8, "두 번 부르기: 25% 밑에서 4마리 더(모두 %d마리)" % minions)
	_boss_ticks(c, 300)
	check.call(calls.size() == 2, "두 번 부르기: 세 번째는 없다")
	var lord_zone: int = c.rules.zone
	check.call(lord_zone == CryptLayout.LORD_ZONE - 1, "두 번 부르기: 불려 오는 망령은 10구역 세기")
	# 무덤 기사는 지금처럼 한 번
	var r := Rules.new(d, 12)
	Grid.size = FieldLayout.SIZE
	r.start_field()
	r.debug_god = true
	var k: Enemy = r.spawn_field_boss()
	r.lord.pos = FieldLayout.BOSS_AT + Vector2(0, 3)
	r.lord.prev_pos = r.lord.pos
	var kc: Array = []
	r.enemy_act.connect(func(e: Enemy, act: StringName, _i: Dictionary) -> void:
		if e == k and act == &"call":
			kc.append(1))
	for i in 5:
		r.step()
	k.hp = k.max_hp * 0.49
	for i in 300:
		r.step()
	k.hp = k.max_hp * 0.2
	for i in 400:
		r.step()
	check.call(kc.size() == 1 and k.summoned == 4, "무덤 기사: 부르기는 지금처럼 한 번(25% 밑에서도 더 안 부른다)")
	Grid.size = CryptLayout.SIZE


## 31단계: 큰 관을 처음 열면 오픈월드 한정 검(BIG_COFFIN_SWORD)을 도감에 넣는다. 검 파일(33단계)이 없으면 건너뛴다.
func _big_coffin_sword() -> void:
	check.call(CryptLayout.BIG_COFFIN_SWORD == 309, "큰 관의 검: 309번(오픈월드 한정 검 301~310 중)")
	var has_file: bool = ResourceLoader.exists("res://data/swords/309.tres")
	check.call(CryptLayout.big_coffin_sword_path() == ("res://data/swords/309.tres" if has_file else ""), "큰 관의 검: 파일이 있을 때만 경로를 준다")
	var m := Meta.new()
	m.crypt_cleared["r6"] = 1
	var r: Dictionary = m.crypt_open("r6")
	if has_file:
		check.call(int(r.sword) == 309 and m.has_found(309) and int(m.found["309"]) == 1, "큰 관의 검: 처음 열면 309번이 도감에 든다")
	else:
		check.call(int(r.sword) == -1 and not m.has_found(309) and r.shards == 60, "큰 관의 검: 검 파일이 없으면 조용히 건너뛴다(조각·부적은 그대로)")
	# 다음 판에 다시 열어도(record_run이 비운 뒤) 검은 다시 안 준다
	m.crypt_opened.clear()
	var r2: Dictionary = m.crypt_open("r6")
	check.call(int(r2.sword) == -1 and r2.shards == 60, "큰 관의 검: 처음 한 번만(이미 도감에 있으면 다시 안 준다)")
	var r3: Dictionary = m.crypt_open("r1")
	check.call(int(r3.sword) == -1, "큰 관의 검: 일반 관은 검을 안 준다")


func _persist() -> void:
	var path: String = "user://test_crypt_save.json"
	var m := Meta.new()
	m.crypt_clear("r1")
	m.crypt_clear("r2")
	m.crypt_open("r1")
	m.save(path)
	var m2 := Meta.load_or_new(path)
	check.call(m2.crypt_cleared.has("r1") and m2.crypt_cleared.has("r2") and m2.crypt_opened.has("r1") and not m2.crypt_opened.has("r2"), "저장: 쓰러뜨린 방과 연 관을 저장하고 읽는다")
	# 쓰러져 장면을 바꿔도(저장하고 다시 읽어도) 남는다
	var c := _crypt(6, m2)
	c.step()
	check.call(c.cleared(&"r1") and c.meta.crypt_opened.has("r1") and not c.coffin_ready(&"r1"), "남는 것: 다시 읽어도 쓰러뜨린 방은 쓰러뜨린 채, 연 관은 연 채")
	check.call(c.meta.crypt_open("r2").shards > 0 and not c.meta.crypt_open("r2").charm, "남는 것: 쓰러뜨리고 안 연 관은 이어서 열 수 있다")
	# 판이 끝나면 다시 찬다
	var hill := Rules.new(d, 8)
	m2.record_run(hill, d.meta)
	check.call(m2.crypt_cleared.is_empty() and m2.crypt_opened.is_empty(), "다시: 판이 끝나면(record_run) 쓰러뜨린 방과 연 관이 비워진다")
	var c2 := _crypt(7, m2)
	c2.step()
	check.call(c2.rules.packs.has(&"r1") and c2.door_closed(&"d12") and not c2.coffin_ready(&"r1"), "다시: 비워진 무덤은 무리가 다시 서고 문이 닫히고 관이 잠긴다")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _death() -> void:
	var m := Meta.new()
	var c := _crypt(8, m)
	c.step()
	_wipe(c, &"r1")
	m.crypt_open("r1")
	var shards: int = m.shards
	var over: Array = []
	c.rules.run_ended.connect(func(won: bool) -> void: over.append(won))
	c.rules.debug_god = false
	c.rules.lord.hp = 1.0
	c.rules.lord.invuln = 0.0
	c.rules._hurt_lord(500.0)
	check.call(c.rules.phase == Rules.Phase.OVER and over == [false], "쓰러짐: 무덤에서 쓰러지면 신호가 온다")
	check.call(m.crypt_cleared.has("r1") and m.crypt_opened.has("r1") and m.shards == shards, "쓰러짐: 쓰러뜨린 방·연 관·조각은 그대로 남는다(record_run 없음)")
	# 쓰러지고 다시 들어오면 쓰러뜨린 방은 열려 있다. 안 쓰러뜨린 방은 처음부터
	var c2 := _crypt(9, m)
	_go(c2, Vector2(35, 46))
	check.call(c2.cleared(&"r1") and c2.rules.packs.has(&"r2") and c2.rules.pack_alive(&"r2") == int(WANT_FOES[&"r2"]), "쓰러짐: 다시 들어오면 쓰러뜨린 방은 그대로, 못 쓰러뜨린 방은 새 무리")


func _replay() -> void:
	var h: Array[int] = []
	for run in 2:
		var c := _crypt(11)
		c.rules.slots[0] = Sword.new(d.swords[0], d)
		for t in 600:
			var i := LordInput.new()
			i.move = Vector2(0.0, -1.0) if t < 150 else Vector2(1.0, 0.0) if t % 200 < 100 else Vector2(-1.0, 0.0)
			i.attack = t % 7 < 4
			i.dash = t % 90 == 0
			i.aim_valid = true
			i.aim = Vector2(35, 60)
			c.rules.step(i)
			c.step()
			c.rules.lord.pos = c.push(c.rules.lord.pos)
		h.append(c.rules.state_hash())
	check.call(h[0] == h[1], "결정성: 같은 시드·같은 입력이면 무덤 싸움의 state_hash가 같다")
	var c3 := _crypt(12)
	c3.step()
	var a: int = c3.rules.state_hash()
	var c4 := _crypt(13)
	c4.step()
	check.call(c4.rules.state_hash() != a, "결정성: 시드가 다르면 무리 자리가 달라 해시가 다르다")


func _save() -> void:
	var path: String = "user://test_crypt_old.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"shards": 9, "packs_cleared": {"grove": 1}, "boss_first": true}))
	f.close()
	var m := Meta.load_or_new(path)
	check.call(m.shards == 9 and m.crypt_cleared.is_empty() and m.crypt_opened.is_empty() and m.boss_first, "옛 저장: 무덤 칸이 없으면 빈 값으로 읽힌다")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _entrance() -> void:
	# 들판 입구: 검은 숲 가장자리, 막힘 밖에서 E가 닿고 나온 자리는 막힘 밖
	check.call(FieldLayout.area_at(FieldLayout.CRYPT_DOOR) == &"grove", "입구: 검은 숲 가장자리 안")
	var root := Node3D.new()
	var blockers: Dictionary = FieldBuilder.build(root, Environment.new())
	var rects: Array = blockers.rects
	var circles: Array = blockers.circles + blockers.low_circles
	var in_rect: bool = false
	for r in rects:
		if (r as Rect2).grow(0.3).has_point(FieldLayout.CRYPT_DOOR) or (r as Rect2).grow(0.3).has_point(FieldLayout.CRYPT_WAKE):
			in_rect = true
	check.call(rects.has(FieldLayout.CRYPT_BLOCK) and not in_rect, "입구: 무덤 모양은 막히고, E 자리와 깨는 자리는 막힘 밖")
	var near: bool = false
	for r in rects:
		if r == FieldLayout.CRYPT_BLOCK:
			continue
	var clear_c: bool = true
	for c in circles:
		if FieldLayout.CRYPT_DOOR.distance_to(c[0]) < float(c[1]) + 1.2 or FieldLayout.CRYPT_WAKE.distance_to(c[0]) < float(c[1]) + 0.6:
			clear_c = false
	check.call(clear_c and not near, "입구: 나무·바위 막힘이 입구 앞을 가리지 않는다")
	# 영주가 닿을 수 있는 가장 가까운 자리에서 E 거리(2칸) 안
	var reach_pt := Vector2(FieldLayout.CRYPT_DOOR.x, FieldLayout.CRYPT_BLOCK.end.y + 0.3)
	check.call(reach_pt.distance_to(FieldLayout.CRYPT_DOOR) < 2.0, "입구: 막힘 바로 앞에서 E가 닿는다")
	for pk in FieldLayout.PACKS:
		check.call(FieldLayout.PACKS[pk].at.distance_to(FieldLayout.CRYPT_DOOR) > FieldLayout.PACK_AGGRO, "입구: 들판 무리 %s가 입구 앞에서 덤비지 않는다" % pk)
	for k in FieldLayout.CACHES:
		check.call(FieldLayout.CACHES[k][0].distance_to(FieldLayout.CRYPT_DOOR) > 3.0, "입구: 유품 %s와 겹치지 않는다" % k)
	root.free()
	# 나오는 문 표시와 검 넘기기
	check.call(Meta.wake_at_crypt == false, "입구: 나오는 표시는 기본이 꺼져 있다")
	Meta.carry_sword = 5
	var s: Sword = Meta.new().unbreakable_sword(d, Meta.carry_sword)
	check.call(s != null, "입구: 들판에서 쥔 검(carry_sword)을 무덤에서도 부러지지 않는 검으로 쥔다")
	Meta.carry_sword = -1
