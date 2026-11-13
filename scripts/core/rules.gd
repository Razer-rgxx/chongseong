class_name Rules
extends RefCounted
## 게임 규칙. 노드에 기대지 않고 step() 한 번에 한 틱(1/30초)씩만 돈다.
## 랜덤은 전부 rng 하나를 거친다. 같은 시드와 같은 입력이면 결과가 같다.
## 화면은 신호와 상태를 받아 그린다.
## 지금(1단계): 낮에 꽂힌 검 뽑기, 두 칸과 바꿔 쥐기, 밤의 적, 형태별 베기, 내구와 부러짐, 구역 오르기, 언덕지기.
## 각인과 고유 능력은 표에 수치만 있고 규칙에는 아직 없다(4, 5단계).

signal day_started(zone: int)
signal night_started(zone: int)
signal run_ended(won: bool)
signal pull_started(hilt: Hilt, grade: int)
signal pull_step(hilt: Hilt, step: int)
signal pull_refused(reason: String)
signal sword_pulled(sword: Sword)
signal choice_needed(sword: Sword)
signal slots_changed()
signal sword_broke(slot: int, sword: Sword)
signal lord_swung(big: bool)
signal lord_dashed()
signal lord_hurt(damage: float)
signal enemy_spawned(enemy: Enemy)
signal enemy_hit(enemy: Enemy, damage: float, big: bool)
signal enemy_died(enemy: Enemy)
signal boss_spawned(enemy: Enemy)

enum Phase { DAY, NIGHT, OVER }

var data: GameData
var rng := RandomNumberGenerator.new()
var seed_value: int
## 한 틱의 길이(초).
var dt: float
var tick: int = 0
var phase: Phase = Phase.DAY
## 0부터 센다. 마지막 구역은 zone_count() - 1.
var zone: int = 0
## 새벽까지 남은 시간(초). 0 아래로 내려가도 마지막 구역에서는 언덕지기를 쓰러뜨릴 때까지 밤이다.
var night_left: float = 0.0
var lord := LordState.new()
## 두 칸. 빈 칸은 null.
var slots: Array[Sword] = [null, null]
var active: int = 0
var hilts: Array[Hilt] = []
var enemies: Array[Enemy] = []
## 뽑는 중인 검. 뽑는 동안 영주는 움직이지 않는다.
var pull_hilt: Hilt = null
var pull_grade: int = 0
var pull_t: float = 0.0
var pull_steps: int = 0
## 두 칸이 다 차서 어디에 들지 기다리는 검. 고르기 전에는 시간이 멈춘다.
var pending: Sword = null
var won: bool = false
var boss_out: bool = false
var kills: int = 0
var pulls: int = 0
var best_grade: int = -1
## 남은 히트스톱 틱. 0보다 크면 그 틱은 시간이 멈춘다.
var freeze: int = 0
## 관리용: 영주가 다치지 않는다 / 다음 뽑기 등급을 고정한다(-1이면 굴린다).
var debug_god: bool = false
var debug_grade: int = -1
var _spawn_t: float = 0.0
var _next_id: int = 1


func _init(game_data: GameData, p_seed: int) -> void:
	data = game_data
	seed_value = p_seed
	rng.seed = p_seed
	dt = 1.0 / float(data.run.tick_rate)
	Grid.size = data.run.arena_size
	lord.hp = data.lord.hp
	_new_day()


func zone_count() -> int:
	return data.run.zone_names.size()


func last_zone() -> bool:
	return zone == zone_count() - 1


func current() -> Sword:
	return slots[active]


func luck() -> float:
	return data.run.zone_luck[mini(zone, data.run.zone_luck.size() - 1)]


func step(input: LordInput = null) -> void:
	if phase == Phase.OVER:
		return
	tick += 1
	lord.prev_pos = lord.pos
	for e in enemies:
		e.prev_pos = e.pos
	if freeze > 0:
		freeze -= 1
		return
	if pending != null:
		return
	if pull_hilt != null:
		_step_pull()
		return
	_step_lord(input)
	if phase == Phase.NIGHT:
		_step_night()
		if phase == Phase.NIGHT:
			_step_enemies()


# ---------------------------------------------------------------- 낮과 밤

## 낮에만. 뽑는 중이거나 고르는 중이면 못 한다.
func start_night() -> void:
	if phase != Phase.DAY or pull_hilt != null or pending != null:
		return
	phase = Phase.NIGHT
	night_left = data.run.night_length
	_spawn_t = data.run.spawn_first
	boss_out = false
	hilts.clear()
	night_started.emit(zone)


## 관리용: 지금 밤을 바로 끝낸다(마지막 구역이면 이긴 것으로 친다).
func skip_night() -> void:
	if phase == Phase.NIGHT:
		_end_night()


func _new_day() -> void:
	var R := data.run
	phase = Phase.DAY
	hilts.clear()
	lord.pos = Grid.middle()
	lord.prev_pos = lord.pos
	for i in R.hilts_per_day:
		var p := Vector2.ZERO
		for tries in 40:
			p = Vector2(rng.randf_range(2.0, R.arena_size.x - 2.0), rng.randf_range(2.0, R.arena_size.y - 2.0))
			if _hilt_spot_ok(p):
				break
		var h := Hilt.new()
		h.id = _new_id()
		h.pos = p
		h.tilt = rng.randf_range(-0.25, 0.25)
		hilts.append(h)
	day_started.emit(zone)


func _hilt_spot_ok(p: Vector2) -> bool:
	if p.distance_to(lord.pos) < data.run.hilt_clear:
		return false
	for h in hilts:
		if h.pos.distance_to(p) < data.run.hilt_spacing:
			return false
	return true


func _end_night() -> void:
	enemies.clear()
	if last_zone():
		phase = Phase.OVER
		won = true
		run_ended.emit(true)
		return
	zone += 1
	lord.hp = minf(data.lord.hp, lord.hp + data.run.heal_per_dawn)
	_new_day()


# ---------------------------------------------------------------- 뽑기

## 1/N 표에서 높은 등급부터 차례로 굴린다. 보장은 없다.
func roll_grade(p_luck: float) -> int:
	var odds := data.grades.odds
	for g in range(odds.size() - 1, 0, -1):
		if rng.randf() < p_luck / odds[g]:
			return g
	return 0


func nearest_hilt(reach: float) -> Hilt:
	var best: Hilt = null
	var bd: float = reach
	for h in hilts:
		if h.gone:
			continue
		var d: float = h.pos.distance_to(lord.pos)
		if d < bd:
			bd = d
			best = h
	return best


func pull_duration() -> float:
	return data.run.pull_time + data.run.pull_step * pull_grade


func _try_pull() -> void:
	if phase != Phase.DAY or pending != null or pull_hilt != null:
		return
	var h := nearest_hilt(data.run.pull_reach)
	if h == null:
		return
	if lord.hp <= data.run.pull_cost:
		pull_refused.emit("체력이 모자라. 더 뽑으면 쓰러진다.")
		return
	pull_hilt = h
	pull_grade = debug_grade if debug_grade >= 0 else roll_grade(luck())
	pull_t = 0.0
	pull_steps = 0
	pull_started.emit(h, pull_grade)


## 등급이 높을수록 오래 버틴다. 한 단계 버틸 때마다 pull_step 신호가 온다.
func _step_pull() -> void:
	pull_t += dt
	var st: int = mini(pull_grade, int(pull_t / data.run.pull_step))
	if st > pull_steps:
		pull_steps = st
		pull_step.emit(pull_hilt, st)
	if pull_t < pull_duration():
		return
	var h := pull_hilt
	pull_hilt = null
	h.gone = true
	lord.hp -= data.run.pull_cost
	pulls += 1
	best_grade = maxi(best_grade, pull_grade)
	var list: PackedInt32Array = data.swords_by_grade[pull_grade]
	var s := Sword.new(data.swords[list[rng.randi_range(0, list.size() - 1)]], data)
	sword_pulled.emit(s)
	_receive(s)


func _receive(s: Sword) -> void:
	for k in 2:
		if slots[k] == null:
			slots[k] = s
			if slots[active] == null:
				active = k
			slots_changed.emit()
			return
	pending = s
	choice_needed.emit(s)


## 두 칸이 다 찼을 때 새 검을 둘 칸(0, 1). -1이면 두고 간다.
func choose(k: int) -> void:
	if pending == null:
		return
	if k == 0 or k == 1:
		slots[k] = pending
	pending = null
	slots_changed.emit()


## 관리·테스트용: 그 칸에 검을 바로 쥐여 준다.
func give(d: SwordData, k: int) -> Sword:
	var s := Sword.new(d, data)
	slots[k] = s
	if slots[active] == null:
		active = k
	slots_changed.emit()
	return s


## 다른 칸의 검으로 바꿔 쥔다. 2는 "다른 칸".
func swap(k: int) -> void:
	if k == 2:
		k = 1 - active
	if k < 0 or k > 1 or k == active or slots[k] == null:
		return
	active = k
	lord.combo = 0
	slots_changed.emit()


# ---------------------------------------------------------------- 영주

func _step_lord(input: LordInput) -> void:
	var L := lord
	var D := data.lord
	L.cooldown -= dt
	L.swing -= dt
	L.invuln -= dt
	L.dash_cooldown -= dt
	L.combo_timer -= dt
	if input and input.swap_to >= 0:
		swap(input.swap_to)
	if input and input.pull:
		_try_pull()
		if pull_hilt != null:
			L.moving = false
			return
	var mv: Vector2 = input.move if input else Vector2.ZERO
	if mv.length() > 1.0:
		mv = mv.normalized()
	L.moving = mv.length() > 0.1
	if L.moving:
		L.move_dir = mv.normalized()
	if input and input.dash and L.dash_cooldown <= 0.0 and L.dash <= 0.0:
		L.dash = D.dash_time
		L.dash_cooldown = D.dash_cooldown
		L.invuln = maxf(L.invuln, D.dash_time + 0.05)
		L.dash_dir = L.move_dir if L.moving else Vector2.from_angle(L.face)
		lord_dashed.emit()
	var v: Vector2
	if L.dash > 0.0:
		L.dash -= dt
		v = L.dash_dir * D.dash_speed
	else:
		v = mv * D.speed * (D.swing_move_mult if L.swing > 0.0 else 1.0)
	var lim := Vector2(Grid.size) - Vector2(0.5, 0.5)
	L.pos = (L.pos + v * dt).clamp(Vector2(0.5, 0.5), lim)
	if input and input.aim_valid and L.pos.distance_to(input.aim) > 0.05:
		L.face = (input.aim - L.pos).angle()
	elif L.moving:
		L.face = mv.angle()
	if input and input.attack and phase == Phase.NIGHT and L.cooldown <= 0.0 and L.dash <= 0.0:
		_swing()


## 형태마다 연타 수가 다르다(대검 2, 나머지 3). 연타의 마지막이 큰 베기다.
## 부채꼴 안이거나 아주 가까운 적을 가까운 순서로 벤다(세검은 앞의 2명까지).
func _swing() -> void:
	var L := lord
	var D := data.lord
	var s := current()
	var F: FormData = s.form if s else data.unarmed
	var g_mult: float = data.grades.damage_mult[s.grade] if s else 1.0
	if L.combo_timer <= 0.0:
		L.combo = 0
	L.combo = L.combo % F.combo + 1
	L.combo_timer = D.combo_window
	var big: bool = L.combo == F.combo
	L.big = big
	L.cooldown = D.cooldown / F.speed * (D.big_cooldown_mult if big else 1.0)
	var reach: float = D.reach * F.reach
	var arc: float = minf(D.arc * F.arc, TAU)
	L.swing = D.swing_time
	L.swing_arc = arc
	L.swing_reach = reach
	var dmg: float = D.damage * F.damage * g_mult * (D.big_damage_mult if big else 1.0)
	var knock: float = D.knockback * F.knockback * (D.big_knockback_mult if big else 1.0)
	var hit: Array[Enemy] = []
	for e in enemies:
		if e.dead:
			continue
		var to: Vector2 = e.pos - L.pos
		var d: float = to.length()
		if d > reach + e.data.radius:
			continue
		if absf(angle_difference(L.face, to.angle())) > arc / 2.0 and d > e.data.radius + D.close_hit:
			continue
		hit.append(e)
	var at: Vector2 = L.pos
	hit.sort_custom(func(a: Enemy, b: Enemy) -> bool: return a.pos.distance_squared_to(at) < b.pos.distance_squared_to(at))
	if F.pierce > 0 and hit.size() > F.pierce:
		hit.resize(F.pierce)
	for e in hit:
		var dir: Vector2 = e.pos - L.pos
		dir = dir / dir.length() if dir.length() > 0.001 else Vector2.from_angle(L.face)
		hurt(e, dmg, dir * knock, big)
	lord_swung.emit(big)
	if hit.size() > 0:
		freeze = maxi(freeze, roundi((D.hitstop_big if big else D.hitstop) / dt))
		if s and s.breakable():
			s.durability -= 1.0
			if s.durability <= 0.0:
				_break(active)


func _break(k: int) -> void:
	var s := slots[k]
	slots[k] = null
	if k == active and slots[1 - k] != null:
		active = 1 - k
	lord.combo = 0
	sword_broke.emit(k, s)
	slots_changed.emit()


func hurt(e: Enemy, damage: float, knock: Vector2, big: bool) -> void:
	if e.dead:
		return
	e.hp -= damage
	e.push += knock * e.data.knockback_mult * data.lord.knock_speed
	enemy_hit.emit(e, damage, big)
	if e.hp <= 0.0:
		e.dead = true
		kills += 1
		enemy_died.emit(e)


func _hurt_lord(d: float) -> void:
	var L := lord
	if L.invuln > 0.0 or L.dash > 0.0 or phase != Phase.NIGHT or debug_god:
		return
	L.hp -= d
	L.invuln = data.lord.hurt_invuln
	lord_hurt.emit(d)
	if L.hp <= 0.0:
		L.hp = 0.0
		phase = Phase.OVER
		won = false
		run_ended.emit(false)


# ---------------------------------------------------------------- 적

func _step_night() -> void:
	var R := data.run
	night_left -= dt
	var prog: float = 1.0 - maxf(0.0, night_left) / R.night_length
	if last_zone() and not boss_out and night_left <= R.night_length * R.boss_at:
		boss_out = true
		boss_spawned.emit(_spawn(&"boss"))
	_spawn_t -= dt
	if _spawn_t <= 0.0 and enemies.size() < R.max_enemies and (night_left > 0.0 or last_zone()):
		_spawn_t = (R.spawn_start - R.spawn_drop * minf(1.0, prog)) / (1.0 + R.spawn_zone * zone)
		var r: float = rng.randf()
		var giant_p: float = minf(R.giant_chance.z, R.giant_chance.x + R.giant_chance.y * zone)
		var wolf_p: float = minf(R.wolf_chance.z, R.wolf_chance.x + R.wolf_chance.y * zone)
		var kind: StringName = &"wraith"
		if zone >= 1 and prog > R.giant_after and r < giant_p:
			kind = &"giant"
		elif r < wolf_p:
			kind = &"wolf"
		_spawn(kind)
	if night_left <= 0.0 and (not last_zone() or (boss_out and not boss_alive())):
		_end_night()


func boss_alive() -> bool:
	for e in enemies:
		if e.data.boss and not e.dead:
			return true
	return false


## 싸움터 네 변 바깥 한 칸에서 나온다.
func _spawn(kind: StringName) -> Enemy:
	var size := Vector2(Grid.size)
	var side: int = rng.randi_range(0, 3)
	var p := Vector2.ZERO
	match side:
		0:
			p = Vector2(rng.randf() * size.x, -1.0)
		1:
			p = Vector2(rng.randf() * size.x, size.y + 1.0)
		2:
			p = Vector2(-1.0, rng.randf() * size.y)
		_:
			p = Vector2(size.x + 1.0, rng.randf() * size.y)
	return spawn_at(kind, p)


func spawn_at(kind: StringName, p: Vector2) -> Enemy:
	var D: EnemyData = data.enemies[kind]
	var e := Enemy.new()
	e.id = _new_id()
	e.data = D
	e.pos = p
	e.prev_pos = p
	var zi: int = mini(zone, data.run.zone_hp.size() - 1)
	e.max_hp = D.hp * (1.0 if D.boss else data.run.zone_hp[zi])
	e.hp = e.max_hp
	e.damage = D.damage * (1.0 if D.boss else data.run.zone_damage[zi])
	e.cooldown = rng.randf() * 0.5
	enemies.append(e)
	enemy_spawned.emit(e)
	return e


## 영주에게 곧장 다가가 닿으면 때린다. 서로 겹치지 않게 밀어낸다.
func _step_enemies() -> void:
	var keep: float = pow(data.lord.knock_keep, dt)
	var reach: float = data.run.enemy_reach
	for e in enemies:
		if e.dead:
			continue
		e.pos += e.push * dt
		e.push *= keep
		var to: Vector2 = lord.pos - e.pos
		var d: float = to.length()
		if d > 0.001:
			e.face = to / d
		e.cooldown -= dt
		if d > e.data.radius + reach:
			e.pos += e.face * e.data.speed * dt
		elif e.cooldown <= 0.0:
			e.cooldown = e.data.cooldown
			_hurt_lord(e.damage)
	var n: int = enemies.size()
	for i in n:
		var a := enemies[i]
		for j in range(i + 1, n):
			var b := enemies[j]
			var dv: Vector2 = b.pos - a.pos
			var d: float = dv.length()
			var m: float = a.data.radius + b.data.radius
			if d < m and d > 0.0001:
				var p: Vector2 = dv * ((m - d) / 2.0 / d)
				a.pos -= p
				b.pos += p
	var alive: Array[Enemy] = []
	for e in enemies:
		if not e.dead:
			alive.append(e)
	enemies = alive


func _new_id() -> int:
	_next_id += 1
	return _next_id


## 같은 시드·같은 입력이면 같은 값이 나와야 한다(테스트용).
func state_hash() -> int:
	var parts: Array = [tick, zone, phase, lord.pos, lord.hp, kills, pulls, active, enemies.size(), hilts.size(), rng.state]
	for e in enemies:
		parts.append(e.pos)
		parts.append(e.hp)
	for s in slots:
		parts.append(s.data.id if s else -1)
		parts.append(s.durability if s else -1.0)
	return hash(str(parts))
