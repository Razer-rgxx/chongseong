extends RefCounted
## 보스 패턴 테스트(2026-11-23, docs/boss_patterns.md): 연속 베기, 내려찍기·충격파, 칼비·무덤 손, 땅 가르기, 그림자 걸음.
## 들판의 옛 싸움터 자리에 보스를 세워 돌린다(spawn_field_boss의 kind). run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/boss_pattern_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_data()
	_combo()
	_slam()
	_quake()
	_rain()
	_hands()
	_cleave()
	_blink()
	_all_seen()
	_replay()
	Grid.size = Vector2i(34, 22)


## kind 보스를 깨워 세우고 영주를 dist칸 오른쪽에 둔다. tune이 있으면 그 보스만의 표 사본을 고친다(다른 테스트에 번지지 않게).
func _setup(kind: StringName, dist: float, tune: Dictionary = {}, seed_value: int = 1) -> Rules:
	var r := Rules.new(d, seed_value)
	Grid.size = FieldLayout.SIZE
	r.start_field()
	r.debug_god = false
	var b: Enemy = r.spawn_field_boss(FieldLayout.BOSS_AT, kind)
	if not tune.is_empty():
		b.data = b.data.duplicate()
		for k: String in tune:
			b.data.set(k, tune[k])
	b.summoned = b.data.summon_max
	r.lord.pos = FieldLayout.BOSS_AT + Vector2(dist, 0.0)
	r.lord.prev_pos = r.lord.pos
	r.hurt(b, 0.0, Vector2.ZERO, false)   # 깨운다
	b.cooldown = 0.0   # 곧바로 고른다(깨면 쉬는 시간이 붙는다)
	return r


## 보스가 한 일을 [틱, 이름, info]로 적는다.
func _log(r: Rules) -> Array:
	var log: Array = []
	r.enemy_act.connect(func(_e: Enemy, act: StringName, i: Dictionary) -> void: log.append([r.tick, act, i]))
	return log


func _acts(log: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for x: Array in log:
		out.append(x[1])
	return out


func _falls(r: Rules, kind: StringName) -> Array[Projectile]:
	var out: Array[Projectile] = []
	for p in r.enemy_projectiles:
		if p.kind == kind:
			out.append(p)
	return out


func _data() -> void:
	var H: EnemyData = d.enemies[&"boss"]
	var K: EnemyData = d.enemies[&"grave_knight"]
	var C: EnemyData = d.enemies[&"crypt_lord"]
	check.call(H.swing_arc > 0.0 and H.combo == 1 and H.combo_rage == 1 and H.slam_chance > 0.0 and H.quake_range > H.slam_radius and H.rain_count == 5 and not H.rain_line and H.rain_look == &"sword",
		"보스 패턴: 언덕지기는 연속 베기·내려찍기(충격파)·칼비를 쓴다")
	check.call(K.combo == 0 and K.combo_rage == 1 and K.cleave_chance > 0.0 and K.slam_chance == 0.0 and K.rain_count == 0,
		"보스 패턴: 무덤 기사는 땅 가르기를 쓰고 빨라지면 두 번 벤다")
	check.call(C.combo == 1 and C.blink_chance > 0.0 and C.rain_count > 0 and C.rain_line and C.rain_look == &"hand",
		"보스 패턴: 무덤 주인은 연속 베기·그림자 걸음·무덤 손(줄)을 쓴다")
	var chief: EnemyData = d.enemies[&"chief_knight"]
	check.call(chief.combo == 0 and chief.combo_rage == 0 and chief.cleave_chance == 0.0 and chief.blink_chance == 0.0,
		"보스 패턴: 우두머리(무덤 기사형)는 그대로")


## 연속 베기: 무덤 기사는 체력이 가득이면 한 번, 50% 밑이면 다시 겨눠 두 번 벤다. 무덤 주인은 늘 두 번.
func _combo() -> void:
	var counts: Array[int] = []
	var second: Array = []
	for row in [[&"grave_knight", 1.0], [&"grave_knight", 0.4], [&"crypt_lord", 1.0]]:
		var r := _setup(row[0], 2.5, {"cleave_chance": 0.0, "blink_chance": 0.0, "rain_count": 0})
		var b: Enemy = r.field_boss
		b.hp = b.max_hp * float(row[1])
		r.debug_god = true
		var log := _log(r)
		for t in 240:
			r.lord.pos = b.pos + Vector2(2.5, 0.0)
			r.step()
			if b.act == &"" and _acts(log).has(&"swing"):
				break
		var n: int = _acts(log).count(&"swing")
		counts.append(n)
		var winds: Array = log.filter(func(x: Array) -> bool: return x[1] == &"swing_wind")
		second.append(winds[1][2] if winds.size() > 1 else {})
	check.call(counts == [1, 2, 2], "연속 베기: 기사 1번 → 빨라지면 2번, 무덤 주인 2번(%s)" % str(counts))
	var K: EnemyData = d.enemies[&"grave_knight"]
	var w: Dictionary = second[1]
	check.call(not w.is_empty() and is_equal_approx(float(w.time), K.combo_wind / K.rage_mult), "연속 베기: 이어지는 베기는 combo_wind초 알린다(빨라지면 짧게)")
	# 이어지는 베기는 영주 쪽으로 다시 겨눈다
	var r2 := _setup(&"crypt_lord", 2.5, {"blink_chance": 0.0, "rain_count": 0})
	var b2: Enemy = r2.field_boss
	r2.debug_god = true
	var log2 := _log(r2)
	for t in 240:
		var swung: bool = _acts(log2).has(&"swing")
		r2.lord.pos = b2.pos + (Vector2(0.0, 2.5) if swung else Vector2(2.5, 0.0))
		r2.step()
		if _acts(log2).count(&"swing_wind") >= 2:
			break
	var ws: Array = log2.filter(func(x: Array) -> bool: return x[1] == &"swing_wind")
	check.call(ws.size() >= 2 and (ws[1][2].dir as Vector2).dot(Vector2(0.0, 1.0)) > 0.95, "연속 베기: 다음 베기는 영주가 간 쪽을 겨눈다")
	# 기절하면 그친다
	var r3 := _setup(&"crypt_lord", 2.5, {"blink_chance": 0.0, "rain_count": 0})
	var b3: Enemy = r3.field_boss
	r3.debug_god = true
	var log3 := _log(r3)
	for t in 240:
		r3.lord.pos = b3.pos + Vector2(2.5, 0.0)
		r3.step()
		if _acts(log3).has(&"swing"):
			break
	b3.stun = 1.0
	for t in 20:
		r3.step()
	check.call(_acts(log3).count(&"swing_wind") == 1 and b3.combo_left == 0, "연속 베기: 묶이면 그친다")


## 내려찍기: 둘레 안이면 피해 × slam_mult와 밀림, 고리는 안쪽을 다시 치지 않는다. 기절하면 예고가 끊긴다.
func _slam() -> void:
	var r := _setup(&"boss", 2.0, {"slam_chance": 1.0})
	var b: Enemy = r.field_boss
	var D: EnemyData = b.data
	var log := _log(r)
	var hp0: float = r.lord.hp
	var push: Array = [0.0]
	for t in 200:
		r.lord.pos = b.pos + Vector2(2.0, 0.0)
		r.lord.invuln = 0.0 if not _acts(log).has(&"slam") else r.lord.invuln
		r.step()
		push[0] = maxf(push[0], r.lord.push.length())
		if _acts(log).has(&"slam") and _falls(r, &"ring").is_empty():
			break
	var sw: Array = log.filter(func(x: Array) -> bool: return x[1] == &"slam_wind")
	var sl: Array = log.filter(func(x: Array) -> bool: return x[1] == &"slam")
	check.call(not sw.is_empty() and is_equal_approx(float(sw[0][2].time), D.slam_time) and float(sw[0][2].radius) == D.slam_radius, "내려찍기: slam_time초 둘레를 알린다")
	check.call(not sl.is_empty() and sl[0][2].hit and is_equal_approx(r.lord.hp, hp0 - b.damage * D.slam_mult), "내려찍기: 둘레 안이면 피해 × slam_mult 한 번(고리는 안쪽을 다시 치지 않는다)")
	check.call(push[0] > 0.5, "내려찍기: 맞으면 밀려난다")
	check.call(not sw.is_empty() and not sl.is_empty() and sl[0][0] - sw[0][0] >= roundi(D.slam_time * 30.0) - 1, "내려찍기: 예고가 다 찬 뒤에 친다")
	var r2 := _setup(&"boss", 2.0, {"slam_chance": 1.0})
	var b2: Enemy = r2.field_boss
	for t in 60:
		r2.step()
		if b2.act == &"slam_wind":
			break
	b2.stun = 1.0
	r2.step()
	check.call(b2.act == &"" and b2.cooldown > 0.0 and _falls(r2, &"ring").is_empty(), "내려찍기: 묶이면 예고가 끊기고 쉰다")


## 충격파 고리: 밖으로 퍼지며 지나가는 영주를 한 번 맞히고, 구르는 중이면 지나간다. 칼로 부러지지 않는다.
func _quake() -> void:
	var D: EnemyData = d.enemies[&"boss"]
	var hits: Array[float] = []
	for roll in [false, true]:
		var r := _setup(&"boss", 2.0, {"slam_chance": 1.0})
		var b: Enemy = r.field_boss
		var hp0: float = r.lord.hp
		var ring: Array = [null]
		for t in 200:
			if b.act == &"" and ring[0] == null:
				r.lord.pos = b.pos + Vector2(2.0, 0.0)   # 고르게 가까이 있다가
			elif ring[0] == null:
				r.lord.pos = b.pos + Vector2(6.0, 0.0)   # 예고가 뜨면 물러난다
			if roll:
				r.lord.dash = 0.2
			r.step()
			var rs := _falls(r, &"ring")
			if not rs.is_empty():
				ring[0] = rs[0]
			if ring[0] != null and not r.enemy_projectiles.has(ring[0]):
				break
		hits.append(hp0 - r.lord.hp)
		if not roll:
			var p: Projectile = ring[0]
			check.call(p != null and p.landed and is_equal_approx(p.distance, D.quake_range), "충격파: 고리가 quake_range칸까지 퍼지며 영주를 맞힌다")
	check.call(is_equal_approx(hits[0], D.damage * D.quake_mult) and hits[1] == 0.0, "충격파: 피해 × quake_mult 한 번, 구르면 지나간다(%.1f, %.1f)" % [hits[0], hits[1]])
	# 부러지지 않는다
	var r3 := _setup(&"boss", 2.0, {"slam_chance": 1.0})
	for t in 80:
		r3.step()
		if not _falls(r3, &"ring").is_empty():
			break
	var rs3 := _falls(r3, &"ring")
	if not rs3.is_empty():
		r3.foes.cut_arrow(rs3[0])
	check.call(rs3.size() == 1 and r3.enemy_projectiles.has(rs3[0]) and not rs3[0].cut, "충격파: 영주의 칼에 부러지지 않는다")


## 칼비: 영주 자리 하나와 둘레에 rain_count곳, rain_delay초 뒤부터 차례로 떨어진다. 선 자리면 맞고, 비켜서면 안 맞는다.
func _rain() -> void:
	var D: EnemyData = d.enemies[&"boss"]
	var r := _setup(&"boss", 6.0, {"rain_chance": 1.0, "charge_chance": 0.0})
	var b: Enemy = r.field_boss
	var spots: Array[Projectile] = []
	r.enemy_projectile_spawned.connect(func(p: Projectile) -> void: spots.append(p))
	var at: Vector2 = r.lord.pos
	for t in 60:
		r.lord.pos = at
		r.step()
		if not spots.is_empty():
			break
	check.call(spots.size() == D.rain_count and spots.all(func(p: Projectile) -> bool: return p.kind == &"fall" and p.look == &"sword"), "칼비: rain_count곳(%d)" % spots.size())
	check.call(not spots.is_empty() and spots[0].pos.distance_to(at) < 0.01 and spots.all(func(p: Projectile) -> bool: return p.pos.distance_to(at) <= D.rain_spread + 0.01), "칼비: 첫 곳은 영주 자리, 나머지는 둘레 rain_spread칸 안")
	var times: Array[float] = []
	for p in spots:
		times.append(p.max_time)
	check.call(times.size() > 1 and is_equal_approx(times[0], D.rain_delay) and is_equal_approx(times[1] - times[0], D.rain_step), "칼비: rain_delay초 뒤부터 rain_step초 간격")
	var hp0: float = r.lord.hp
	r.foes.cut_arrow(spots[0])
	var cut_ok: bool = r.enemy_projectiles.has(spots[0])
	for t in 90:
		r.lord.pos = at
		r.lord.invuln = 0.0
		r.step()
	check.call(cut_ok and spots[0].landed and r.lord.hp <= hp0 - b.damage * D.rain_mult + 0.001, "칼비: 선 자리에 떨어지면 맞는다(칼로 못 쳐낸다)")
	# 비켜서면 안 맞는다
	var r2 := _setup(&"boss", 6.0, {"rain_chance": 1.0, "charge_chance": 0.0, "rain_count": 1})
	var b2: Enemy = r2.field_boss
	var sp2: Array[Projectile] = []
	r2.enemy_projectile_spawned.connect(func(p: Projectile) -> void: sp2.append(p))
	for t in 60:
		r2.step()
		if not sp2.is_empty():
			break
	r2.lord.pos = sp2[0].pos + Vector2(0.0, D.rain_radius + 0.6) if not sp2.is_empty() else r2.lord.pos
	var hp2: float = r2.lord.hp
	for t in 60:
		r2.step()
		if b2.act == &"" and sp2.size() == 1 and not r2.enemy_projectiles.has(sp2[0]):
			break
	check.call(sp2.size() == 1 and not sp2[0].landed and r2.lord.hp == hp2, "칼비: 표시 밖으로 비키면 안 맞는다")
	# 빨라지면 더 많이
	var r3 := _setup(&"boss", 6.0, {"rain_chance": 1.0, "charge_chance": 0.0})
	r3.field_boss.hp = r3.field_boss.max_hp * 0.4
	var n3: Array = [0]
	r3.enemy_projectile_spawned.connect(func(_p: Projectile) -> void: n3[0] += 1)
	for t in 60:
		r3.step()
		if n3[0] > 0:
			break
	check.call(n3[0] == D.rain_count + D.rain_rage, "칼비: 빨라지면 rain_rage곳 더(%d)" % n3[0])


## 무덤 손: 무덤 주인에서 영주를 지나 rain_spread칸 더 가는 줄로, 가까운 곳부터 차례로 솟는다.
func _hands() -> void:
	var D: EnemyData = d.enemies[&"crypt_lord"]
	var r := _setup(&"crypt_lord", 5.0, {"rain_chance": 1.0, "blink_chance": 0.0, "charge_chance": 0.0})
	var b: Enemy = r.field_boss
	var spots: Array[Projectile] = []
	r.enemy_projectile_spawned.connect(func(p: Projectile) -> void: spots.append(p))
	for t in 60:
		r.step()
		if not spots.is_empty():
			break
	var on_line: bool = spots.size() == D.rain_count
	for i in spots.size():
		var p: Projectile = spots[i]
		on_line = on_line and p.look == &"hand" and absf(p.pos.y - b.pos.y) < 0.01 and p.pos.x > b.pos.x
		if i > 0:
			on_line = on_line and p.pos.x > spots[i - 1].pos.x and p.max_time > spots[i - 1].max_time
	check.call(on_line, "무덤 손: 보스에서 영주 쪽 줄로 가까운 곳부터 솟는다")
	check.call(not spots.is_empty() and spots[-1].pos.x >= r.lord.pos.x + D.rain_spread - 0.5, "무덤 손: 영주를 지나 rain_spread칸 더 간다")


## 땅 가르기: 앞길을 알린 뒤 참격파가 곧게 가서 영주를 맞힌다. 칼로 부러지지 않는다.
func _cleave() -> void:
	var D: EnemyData = d.enemies[&"grave_knight"]
	var r := _setup(&"grave_knight", 6.0, {"cleave_chance": 1.0})
	var b: Enemy = r.field_boss
	var log := _log(r)
	var shots: Array[Projectile] = []
	r.enemy_projectile_spawned.connect(func(p: Projectile) -> void:
		shots.append(p)
		r.foes.cut_arrow(p))
	var hp0: float = r.lord.hp
	for t in 120:
		r.step()
		if not shots.is_empty() and not r.enemy_projectiles.has(shots[0]):
			break
	var cw: Array = log.filter(func(x: Array) -> bool: return x[1] == &"cleave_wind")
	check.call(not cw.is_empty() and is_equal_approx(float(cw[0][2].time), D.cleave_time) and float(cw[0][2].length) <= D.cleave_range + 0.001, "땅 가르기: cleave_time초 앞길을 알린다")
	check.call(shots.size() == 1 and shots[0].kind == &"shock" and not shots[0].cut and is_equal_approx(r.lord.hp, hp0 - b.damage * D.cleave_mult), "땅 가르기: 참격파가 영주를 맞힌다(칼로 못 부러뜨린다)")


## 그림자 걸음: 나올 자리(영주 너머 blink_dist칸)를 알리고 땅으로 꺼졌다가 그 자리에서 솟아 곧바로 짧게 알린 휘두르기.
func _blink() -> void:
	var D: EnemyData = d.enemies[&"crypt_lord"]
	var r := _setup(&"crypt_lord", 6.0, {"blink_chance": 1.0, "rain_count": 0})
	var b: Enemy = r.field_boss
	var log := _log(r)
	var lord_at: Vector2 = r.lord.pos
	var arrived: Array = [false, false]
	for t in 90:
		r.step()
		if b.act == &"swing_wind" and not arrived[0]:
			arrived[0] = true
			arrived[1] = b.prev_pos == b.pos
			break
	var bw: Array = log.filter(func(x: Array) -> bool: return x[1] == &"blink_wind")
	var to: Vector2 = bw[0][2].to if not bw.is_empty() else Vector2.INF
	check.call(not bw.is_empty() and to.distance_to(lord_at + Vector2(D.blink_dist, 0.0)) < 0.01 and is_equal_approx(float(bw[0][2].time), D.blink_time), "그림자 걸음: 영주 너머 blink_dist칸을 blink_time초 알린다")
	check.call(arrived[0] and b.pos.distance_to(to) < 0.01 and arrived[1], "그림자 걸음: 그 자리에 바로 솟는다(틱 사이로 잇지 않는다)")
	var sw: Array = log.filter(func(x: Array) -> bool: return x[1] == &"swing_wind")
	check.call(not sw.is_empty() and is_equal_approx(float(sw[0][2].time), D.blink_swing) and (sw[0][2].dir as Vector2).dot(Vector2.LEFT) > 0.99, "그림자 걸음: 솟자마자 영주 쪽으로 blink_swing초 알린 휘두르기")


## 오래 싸우면 모든 패턴이 나온다(영주가 가까이·멀리 오간다).
func _all_seen() -> void:
	var want: Dictionary = {
		&"boss": [&"swing_wind", &"slam_wind", &"slam", &"rain_wind", &"rain", &"wind", &"charge"],
		&"grave_knight": [&"swing_wind", &"cleave_wind", &"cleave", &"wind"],
		&"crypt_lord": [&"swing_wind", &"blink_wind", &"blink", &"rain_wind"],
	}
	for kind: StringName in want:
		var r := _setup(kind, 6.0, {}, 3)
		r.debug_god = true
		var b: Enemy = r.field_boss
		var log := _log(r)
		for t in 2400:
			if b.act == &"":
				r.lord.pos = b.pos + Vector2(7.0 if (t / 300) % 2 == 0 else 2.0, 0.0)
			r.step()
		var seen := _acts(log)
		var miss: Array = (want[kind] as Array).filter(func(a: StringName) -> bool: return not seen.has(a))
		check.call(miss.is_empty(), "패턴: %s의 패턴이 모두 나온다(빠진 것 %s)" % [kind, str(miss)])


## 같은 시드·같은 입력이면 같다.
func _replay() -> void:
	var hashes: Array[int] = []
	for i in 2:
		var r := _setup(&"boss", 6.0, {}, 7)
		r.debug_god = true
		var b: Enemy = r.field_boss
		for t in 900:
			if b.act == &"":
				r.lord.pos = b.pos + Vector2(6.5 if (t / 150) % 2 == 0 else 2.0, 1.0)
			r.step()
		hashes.append(r.state_hash())
	check.call(hashes[0] == hashes[1], "보스 패턴: 같은 시드면 같다")
