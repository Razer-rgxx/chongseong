extends RefCounted
## 32단계 곳마다 우두머리 테스트(docs/field_life.md). run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable

const KINDS: Dictionary = {
	"chief_tower": &"archer", "chief_grove": &"wolf", "chief_foot": &"giant", "chief_keep": &"shield",
	"chief_marsh": &"caller", "chief_quarry": &"charger", "chief_hamlet": &"giant", "chief_pass": &"grave_knight",
}


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/field_chief_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_data()
	_layout()
	_spawn()
	_wake()
	_leash()
	_acts()
	_night()
	_slain()
	_rewards()
	_replay()
	_save()
	Grid.size = Vector2i(34, 22)


func _field(seed_value: int = 1) -> Rules:
	var r := Rules.new(d, seed_value)
	Grid.size = FieldLayout.SIZE
	r.start_field()
	r.lord.pos = FieldLayout.START
	r.lord.prev_pos = r.lord.pos
	return r


## 우두머리 하나를 세우고 영주를 제자리에서 dist칸(오른쪽)에 둔다. 무적.
func _setup(id: String, dist: float, seed_value: int = 1) -> Rules:
	var r := _field(seed_value)
	r.debug_god = true
	r.spawn_chief(StringName(id))
	r.lord.pos = _home(id) + Vector2(dist, 0.0)
	r.lord.prev_pos = r.lord.pos
	return r


func _home(id: String) -> Vector2:
	return FieldLayout.CHIEFS[id].at


func _data() -> void:
	check.call(FieldLayout.CHIEFS.size() == 8, "우두머리: 곳 여덟에 하나씩")
	var areas: Dictionary = {}
	var swords: Array[int] = []
	var ok: bool = true
	var names: Dictionary = {}
	for id in FieldLayout.CHIEFS:
		var C: Dictionary = FieldLayout.CHIEFS[id]
		areas[C.area] = true
		swords.append(int(C.sword))
		var D: EnemyData = d.enemies.get(C.kind)
		var base: EnemyData = d.enemies.get(KINDS[id])
		ok = ok and D != null and base != null and D.acts() == KINDS[id] and D.boss and D.token_cost == 0 and D.big and D.hp > base.hp * (1.0 if base.boss else 3.0) and D.radius >= base.radius and D.display_name != ""
		names[D.display_name] = true
	check.call(ok, "우두머리: 이미 있는 적의 큰 판(행동을 빌리는 종류, 표 없이 덤빔, 체력은 그 적의 몇 배(기사형은 무덤 기사보다 많게), 구역 배수 없음)")
	check.call(names.size() == 8, "우두머리: 이름이 다 다르다")
	check.call(areas.size() == 8 and not areas.has(&"old_field") and not areas.has(&"road") and not areas.has(&"brook"), "우두머리: 망루·검은 숲·발치·성채·늪·채석장·불탄 마을·고개(옛 싸움터는 무덤 기사)")
	swords.sort()
	check.call(swords == [301, 302, 303, 304, 305, 306, 307, 308], "우두머리: 곳마다 오픈월드 한정 검 301~308")
	check.call(FieldLayout.CHIEF_WAKE == 8.0 and FieldLayout.CHIEF_LEASH == 14.0 and FieldLayout.CHIEF_FIRST_SHARDS == 50 and FieldLayout.CHIEF_SHARDS == 15, "우두머리: 깨어남 8칸, 놓아줌 14칸, 조각 50 / 15")
	var knight: EnemyData = d.enemies[&"chief_knight"]
	check.call(knight.model_scale > 0.0 and knight.swing_arc > 0.0 and knight.summon_count > 0, "고개의 기사: 무덤 기사형(휘두르기·돌진·부르기)")
	check.call(d.enemies[&"chief_caller"].summon_max > d.enemies[&"caller"].summon_max and d.enemies[&"chief_caller"].summon_count > d.enemies[&"caller"].summon_count, "늪의 부르는 자: 부르는 자보다 더 많이 부른다")
	check.call(d.enemies[&"chief_archer"].cooldown < d.enemies[&"archer"].cooldown and d.enemies[&"chief_archer"].aim_time < d.enemies[&"archer"].aim_time, "망루의 궁수장: 활잡이보다 빨리 연달아 쏜다")


func _layout() -> void:
	var root := Node3D.new()
	var blockers: Dictionary = FieldBuilder.build(root, Environment.new())
	var bad: Array[String] = []
	for id in FieldLayout.CHIEFS:
		var at: Vector2 = _home(id)
		var C: Dictionary = FieldLayout.CHIEFS[id]
		if FieldLayout.area_at(at) != C.area:
			bad.append(id + " 곳 밖")
		var clear: bool = true
		for a in 16:
			for k in [0.0, 0.5, 1.0]:
				var q: Vector2 = at + Vector2.from_angle(a * TAU / 16.0) * 3.0 * k
				for rc: Rect2 in blockers.rects:
					clear = clear and not rc.grow(0.4).has_point(q)
				for c in blockers.circles:
					clear = clear and q.distance_to(c[0]) >= float(c[1]) + 0.4
		if not clear:
			bad.append(id + " 막힘")
		for k in FieldLayout.CACHES:
			if at.distance_to(FieldLayout.CACHES[k][0]) <= 5.0:
				bad.append(id + " 상자 " + k)
		for k in FieldLayout.STONES:
			if at.distance_to(FieldLayout.STONES[k][0]) <= 5.0:
				bad.append(id + " 비석 " + k)
		for k in FieldLayout.PACKS:
			if at.distance_to(FieldLayout.PACKS[k].at) <= float(FieldLayout.PACKS[k].wander) + FieldLayout.CHIEF_WAKE:
				bad.append(id + " 무리 " + k)
		for k in FieldLayout.NIGHT_PACKS:
			if at.distance_to(FieldLayout.NIGHT_PACKS[k].at) <= float(FieldLayout.NIGHT_PACKS[k].wander) + FieldLayout.CHIEF_WAKE:
				bad.append(id + " 밤 무리 " + k)
		var near_road: float = 1e9
		for i in FieldLayout.ROAD.size() - 1:
			near_road = minf(near_road, at.distance_to(Geometry2D.get_closest_point_to_segment(at, FieldLayout.ROAD[i], FieldLayout.ROAD[i + 1])))
		if near_road <= FieldLayout.CHIEF_WAKE:
			bad.append(id + " 길")
		for p in [FieldLayout.GATE, FieldLayout.TRAILHEAD, FieldLayout.START, FieldLayout.CRYPT_DOOR, FieldLayout.CRYPT_WAKE]:
			if at.distance_to(p) <= FieldLayout.CHIEF_WAKE + 2.0:
				bad.append(id + " 문 %s" % p)
		if at.distance_to(FieldLayout.BOSS_AT) <= FieldLayout.CHIEF_WAKE + FieldLayout.BOSS_WAKE:
			bad.append(id + " 무덤 기사")
		for o in FieldLayout.CHIEFS:
			if o != id and at.distance_to(_home(o)) <= FieldLayout.CHIEF_LEASH + FieldLayout.CHIEF_WAKE:
				bad.append(id + " 다른 우두머리 " + o)
	root.free()
	check.call(bad.is_empty(), "우두머리 자리: 그 곳 안, 둘레 3칸은 막힘이 없고, 상자·비석·무리 둘레·길·문·무덤 기사·서로를 피한다 %s" % [bad])


func _spawn() -> void:
	var r := _field()
	r.spawn_chiefs()
	var ok: bool = r.chiefs.size() == 8
	for id in r.chiefs:
		var c: Dictionary = r.chiefs[id]
		var e: Enemy = c.e
		var D: EnemyData = d.enemies[FieldLayout.CHIEFS[String(id)].kind]
		ok = ok and e.chief == id and e.pack == &"" and e.pos == _home(String(id)) and c.home == e.pos and is_equal_approx(e.max_hp, D.hp) and is_equal_approx(e.damage, D.damage) and int(c.state) == Rules.BOSS_SLEEP
	check.call(ok, "spawn_chiefs: 여덟이 제자리에 자는 채로 서고 구역 배수를 받지 않는다")
	check.call(r.zone == 0 and r.spawn_chief(&"chief_tower") == null and r.spawn_chief(&"없는") == null, "spawn_chief: 두고 나서 구역은 그대로, 같은 우두머리는 한 번만")
	var r2 := _field()
	r2.spawn_chiefs({"chief_tower": 1, "chief_pass": 1})
	check.call(r2.chiefs.size() == 6 and not r2.chiefs.has(&"chief_tower") and not r2.chiefs.has(&"chief_pass"), "spawn_chiefs: 이번 판에 쓰러뜨린 것(Meta.chiefs_down)은 안 선다")


func _wake() -> void:
	var r := _setup("chief_grove", FieldLayout.CHIEF_WAKE + 1.0)
	var b: Enemy = r.chiefs[&"chief_grove"].e
	var woke: Array = []
	r.chief_woke.connect(func(id: StringName, _e: Enemy) -> void: woke.append(id))
	for t in 90:
		r.step()
	check.call(woke.is_empty() and int(r.chiefs[&"chief_grove"].state) == Rules.BOSS_SLEEP and b.pos == _home("chief_grove"), "깨어남: 영주가 8칸 밖이면 가만히 서 있다")
	r.lord.pos = _home("chief_grove") + Vector2(FieldLayout.CHIEF_WAKE - 0.5, 0.0)
	r.step()
	check.call(woke == [&"chief_grove"] and int(r.chiefs[&"chief_grove"].state) == Rules.BOSS_AWAKE and r.awake_chief() == b, "깨어남: 8칸 안에 오면 한 번 깨어난다(awake_chief)")
	var d0: float = b.pos.distance_to(r.lord.pos)
	for t in 30:
		r.step()
	check.call(b.pos.distance_to(r.lord.pos) < d0 - 1.0, "깨어남: 늑대왕은 영주 쪽으로 달려온다")
	check.call(r.zone == int(FieldLayout.CHIEFS["chief_grove"].zone) - 1, "깨어남: 공격 표와 불려 오는 적의 세기가 그 곳의 구역을 따른다")
	var r2 := _setup("chief_keep", 30.0)
	r2.hurt(r2.chiefs[&"chief_keep"].e, 1.0, Vector2.ZERO, false)
	check.call(int(r2.chiefs[&"chief_keep"].state) == Rules.BOSS_AWAKE, "깨어남: 먼 데서 맞아도 깨어난다")
	var r3 := _field()
	r3.spawn_chiefs()
	for t in 60:
		r3.step()
	var any: bool = false
	for id in r3.chiefs:
		any = any or int(r3.chiefs[id].state) != Rules.BOSS_SLEEP
	check.call(not any and r3.awake_chief() == null, "깨어남: 마을 문 앞(시작 자리)에서는 아무도 안 깬다")


func _leash() -> void:
	var r := _setup("chief_foot", 4.0)
	var b: Enemy = r.chiefs[&"chief_foot"].e
	var back: Array = []
	r.chief_returned.connect(func(id: StringName, _e: Enemy) -> void: back.append(id))
	for t in 30:
		r.step()
	b.hp = b.max_hp * 0.3
	b.pos = _home("chief_foot") + Vector2(10.0, 0.0)
	r.lord.pos = _home("chief_foot") + Vector2(FieldLayout.CHIEF_LEASH - 1.0, 0.0)
	r.step()
	check.call(int(r.chiefs[&"chief_foot"].state) == Rules.BOSS_AWAKE, "놓아줌: 14칸 안이면 계속 쫓는다")
	r.lord.pos = _home("chief_foot") + Vector2(FieldLayout.CHIEF_LEASH + 1.0, 0.0)
	r.step()
	check.call(int(r.chiefs[&"chief_foot"].state) == Rules.BOSS_RETURNING and r.awake_chief() == null, "놓아줌: 둘레 14칸을 넘으면 돌아간다(막대가 사라진다)")
	var hp0: float = b.hp
	for t in 12:
		r.step()
	check.call(b.hp > hp0, "놓아줌: 돌아가는 동안 체력이 찬다")
	for t in 900:
		r.step()
	check.call(b.hp == b.max_hp and b.pos.distance_to(_home("chief_foot")) < 0.1 and int(r.chiefs[&"chief_foot"].state) == Rules.BOSS_SLEEP and back == [&"chief_foot"], "놓아줌: 제자리에 닿으면 체력이 다 차고 다시 잔다")
	r.lord.pos = _home("chief_foot") + Vector2(3.0, 0.0)
	r.step()
	check.call(int(r.chiefs[&"chief_foot"].state) == Rules.BOSS_AWAKE, "놓아줌: 다시 가까이 오면 또 깨어난다")


## 종류마다 빌린 행동이 실제로 나온다.
func _acts() -> void:
	# 궁수장: 화살을 쏜다
	var r := _setup("chief_tower", 8.0)
	var shots: Array = [0]
	r.enemy_projectile_spawned.connect(func(p: Projectile) -> void: shots[0] += 1 if p.owner == r.chiefs[&"chief_tower"].e else 0)
	for t in 180:
		r.step()
	check.call(shots[0] >= 3, "궁수장: 6초에 화살 %d발(연사)" % shots[0])
	# 부르는 자: 망령을 부르고, 돌아가면 거둔다
	var c := _setup("chief_marsh", 6.0)
	var cb: Enemy = c.chiefs[&"chief_marsh"].e
	for t in 300:
		c.step()
	var called: int = 0
	for e in c.enemies:
		called += 1 if e.caller == cb.id and not e.dead and e.data.id == &"wraith" else 0
	check.call(called >= int(d.enemies[&"chief_caller"].summon_count) and cb.summoned == called, "늪의 부르는 자: 망령을 부른다(%d)" % called)
	c.lord.pos = _home("chief_marsh") + Vector2(FieldLayout.CHIEF_LEASH + 2.0, 0.0)
	c.step()
	var left: int = 0
	for e in c.enemies:
		left += 1 if e.caller == cb.id and not e.dead else 0
	check.call(left == 0 and cb.summoned == 0, "늪의 부르는 자: 돌아가면 불러낸 망령을 거둔다")
	# 감독: 머리를 낮추고 달린다
	var q := _setup("chief_quarry", 7.0)
	var acts: Dictionary = {}
	q.enemy_act.connect(func(_e: Enemy, act: StringName, _i: Dictionary) -> void: acts[act] = true)
	for t in 150:
		q.step()
	check.call(acts.has(&"wind") and acts.has(&"charge"), "채석장 감독: 돌격병처럼 돌진한다")
	# 방패대장: 앞에서 막는다
	var s := _setup("chief_keep", 2.0)
	var sb: Enemy = s.chiefs[&"chief_keep"].e
	sb.face = Vector2.RIGHT
	var hp0: float = sb.hp
	s.hurt(sb, 100.0, Vector2.ZERO, false, false, sb.pos + Vector2(2.0, 0.0))
	var front: float = hp0 - sb.hp
	hp0 = sb.hp
	s.hurt(sb, 100.0, Vector2.ZERO, false, false, sb.pos + Vector2(-2.0, 0.0))
	check.call(front < 20.0 and is_equal_approx(hp0 - sb.hp, 100.0), "성채의 방패대장: 앞에서 맞으면 막고(%.0f) 뒤는 그대로" % front)
	# 고개의 기사: 휘두른다
	var k := _setup("chief_pass", 2.5)
	var swung: Array = [false]
	k.enemy_act.connect(func(e: Enemy, act: StringName, _i: Dictionary) -> void: swung[0] = swung[0] or (act == &"swing" and e.chief == &"chief_pass"))
	for t in 200:
		k.lord.pos = _home("chief_pass") + Vector2(2.5, 0.0)
		k.step()
	check.call(swung[0], "고개의 기사: 무덤 기사처럼 크게 휘두른다")
	# 거인·늑대왕: 걸어와 때린다(무적을 끄고 맞는지)
	for id in ["chief_hamlet", "chief_grove"]:
		var g := _setup(id, 3.0)
		g.debug_god = false
		g.lord.hp = 99999.0
		var hits: Array = [0]
		g.lord_hurt.connect(func(_dmg: float) -> void: hits[0] += 1)
		for t in 240:
			g.lord.invuln = 0.0
			g.step()
		check.call(hits[0] >= 2, "%s: 걸어와 때린다(%d번)" % [d.enemies[FieldLayout.CHIEFS[id].kind].display_name, hits[0]])


func _night() -> void:
	var dmg: Array[float] = []
	for night in [false, true]:
		var r := _setup("chief_grove", 3.0)
		r.debug_god = false
		r.field_night = night
		var hp0: float = r.lord.hp
		r._hurt_lord(10.0, r.chiefs[&"chief_grove"].e)
		dmg.append(hp0 - r.lord.hp)
	check.call(is_equal_approx(dmg[0], 10.0) and is_equal_approx(dmg[1], 10.0 * FieldLayout.FIELD_NIGHT_DAMAGE), "밤: 우두머리도 무리처럼 피해 ×1.25 (%.1f → %.1f)" % dmg)
	var b := _field()
	b.field_night = true
	var boss: Enemy = b.spawn_field_boss()
	var hp1: float = b.lord.hp
	b._hurt_lord(10.0, boss)
	check.call(is_equal_approx(hp1 - b.lord.hp, 10.0), "밤: 옛 싸움터의 무덤 기사는 그대로")


func _slain() -> void:
	var r := _setup("chief_pass", 5.0)
	var b: Enemy = r.chiefs[&"chief_pass"].e
	var slain: Array = []
	r.chief_slain.connect(func(id: StringName, _e: Enemy) -> void: slain.append(id))
	b.hp = b.max_hp * 0.4
	for t in 400:
		r.step()
		if b.summoned > 0:
			break
	check.call(b.summoned > 0, "쓰러뜨림: (준비) 고개의 기사가 늑대를 불렀다")
	r.hurt(b, 99999.0, Vector2.ZERO, true)
	for t in 5:
		r.step()
	var minions: int = 0
	for e in r.enemies:
		minions += 1 if e.caller == b.id and not e.dead else 0
	check.call(slain == [&"chief_pass"] and int(r.chiefs[&"chief_pass"].state) == Rules.BOSS_DOWN and minions == 0, "쓰러뜨림: 신호는 한 번, 불려 온 적도 사라진다")
	for t in 60:
		r.step()
	check.call(slain.size() == 1 and r.awake_chief() == null, "쓰러뜨림: 다시 서지 않는다")


func _rewards() -> void:
	var m := Meta.new()
	var first: Dictionary = m.chief_defeat("chief_tower")
	check.call(first.shards == 50 and first.first and first.sword == 301 and m.shards == 50 and m.has_found(301), "보상: 처음 쓰러뜨리면 조각 50과 그 곳의 한정 검(도감에 든다)")
	var again: Dictionary = m.chief_defeat("chief_tower")
	check.call(again.shards == 15 and not again.first and again.sword == 0 and m.shards == 65 and int(m.found["301"]) == 1, "보상: 다음부터는 조각 15, 검은 다시 안 준다")
	var other: Dictionary = m.chief_defeat("chief_pass")
	check.call(other.shards == 50 and other.sword == 308 and m.chiefs_first.size() == 2 and m.chiefs_down.has("chief_pass"), "보상: 다른 곳의 우두머리는 따로 센다")
	check.call(m.chief_defeat("없는").shards == 0 and m.shards == 115, "보상: 모르는 id면 아무것도 없다")
	m.record_run(Rules.new(d, 5), d.meta)
	check.call(m.chiefs_down.is_empty() and m.chiefs_first.size() == 2, "보상: record_run이 이번 판 쓰러뜨림(chiefs_down)만 비운다(판이 끝나면 다시 선다)")


func _replay() -> void:
	var h: Array[int] = []
	for run in 2:
		var r := _setup("chief_keep", 6.0, 31)
		r.spawn_chief(&"chief_marsh")
		r.slots[0] = Sword.new(d.swords[0], d)
		for t in 600:
			r.step(_inputs(t, _home("chief_keep")))
		h.append(r.state_hash())
	check.call(h[0] == h[1], "결정성: 같은 시드·같은 입력이면 우두머리 싸움의 state_hash가 같다")
	var r3 := _setup("chief_keep", 6.0, 32)
	r3.spawn_chief(&"chief_marsh")
	r3.slots[0] = Sword.new(d.swords[0], d)
	for t in 600:
		r3.step(_inputs(t, _home("chief_keep")))
	check.call(r3.state_hash() != h[0], "결정성: 시드가 다르면 달라진다")
	var r4 := _setup("chief_keep", 30.0, 31)
	var before: int = r4.state_hash()
	r4.hurt(r4.chiefs[&"chief_keep"].e, 0.0, Vector2.ZERO, false)
	check.call(r4.state_hash() != before, "결정성: 우두머리 상태가 state_hash에 든다")


func _inputs(t: int, at: Vector2) -> LordInput:
	var i := LordInput.new()
	i.move = Vector2(-1.0, 0.0) if t % 200 < 100 else Vector2(1.0, 0.0)
	i.attack = t % 7 < 4
	i.dash = t % 90 == 0
	i.aim_valid = true
	i.aim = at
	return i


func _save() -> void:
	var path: String = "user://test_chief_save.json"
	var m := Meta.new()
	m.chief_defeat("chief_quarry")
	m.save(path)
	var m2 := Meta.load_or_new(path)
	check.call(m2.chiefs_first.has("chief_quarry") and m2.chiefs_down.has("chief_quarry") and m2.has_found(306), "저장: 처음 보상·이번 판 쓰러뜨림·얻은 검을 저장하고 읽는다")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"shards": 7, "boss_first": true}))
	f.close()
	var m3 := Meta.load_or_new(path)
	check.call(m3.shards == 7 and m3.chiefs_first.is_empty() and m3.chiefs_down.is_empty(), "저장: 옛 저장은 우두머리 칸이 비어 있다")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
