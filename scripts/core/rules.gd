class_name Rules
extends RefCounted
## 게임 규칙. 노드에 기대지 않고 step() 한 번에 한 틱(1/30초)씩만 돈다.
## 랜덤은 전부 rng 하나를 거친다. 같은 시드와 같은 입력이면 결과가 같다.
## 화면은 신호를 받아 그린다. 지금(2단계)은 낮과 밤의 시계, 자원, 등급 굴리기, 영주, 허수아비가 있다.

signal day_started(day: int)
signal night_started(day: int)
signal run_ended(won: bool)
signal lord_swung(big: bool)
signal lord_dashed()
signal unit_hit(unit: Unit, damage: float, big: bool)

enum Phase { DAY, NIGHT, OVER }

var data: GameData
var rng := RandomNumberGenerator.new()
var seed_value: int
## 한 틱의 길이(초).
var dt: float
var tick: int = 0
var day: int = 1
var phase: Phase = Phase.DAY
## 밤까지 남은 시간(초).
var day_left: float
var wood: int
var stone: int
var gold: int
var lord := LordState.new()
var units: Array[Unit] = []
## 남은 히트스톱 틱. 0보다 크면 그 틱은 시간이 멈춘다.
var freeze: int = 0
var _next_id: int = 1


func _init(game_data: GameData, p_seed: int) -> void:
	data = game_data
	seed_value = p_seed
	rng.seed = p_seed
	dt = 1.0 / float(data.run.tick_rate)
	Grid.size = data.run.map_size
	wood = data.run.start_wood
	stone = data.run.start_stone
	gold = data.run.start_gold
	day_left = data.run.day_length
	lord.hp = data.lord.hp
	lord.pos = Vector2(Grid.center()) + Vector2(0.5, 2.5)
	lord.prev_pos = lord.pos


func step(input: LordInput = null) -> void:
	if phase == Phase.OVER:
		return
	tick += 1
	lord.prev_pos = lord.pos
	for u in units:
		u.prev_pos = u.pos
	if freeze > 0:
		freeze -= 1
		return
	_step_lord(input)
	_step_units()
	if phase == Phase.DAY:
		day_left -= dt
		if day_left <= 0.0:
			start_night()
	# 밤의 습격은 4단계에서 넣는다. 그전까지는 end_night()를 불러 넘긴다.


func start_night() -> void:
	if phase != Phase.DAY:
		return
	day_left = 0.0
	phase = Phase.NIGHT
	night_started.emit(day)


func end_night() -> void:
	if phase != Phase.NIGHT:
		return
	day += 1
	if day > data.run.days:
		phase = Phase.OVER
		run_ended.emit(true)
		return
	phase = Phase.DAY
	day_left = data.run.day_length
	day_started.emit(day)


## 1/N 표에서 높은 등급부터 차례로 굴린다. 설계함 등급과 사람 등급이 같이 쓴다.
func roll_tier(odds: PackedFloat64Array, luck: float) -> int:
	for i in range(odds.size() - 1, 0, -1):
		if rng.randf() < luck / odds[i]:
			return i
	return 0


## 시험용 허수아비. 맞으면 밀려났다가 제자리로 돌아오고, 체력이 다 닳으면 다시 찬다.
func add_dummy(at: Vector2) -> Unit:
	var u := Unit.new()
	u.id = _next_id
	_next_id += 1
	u.pos = at
	u.prev_pos = at
	u.home = at
	u.radius = 0.32
	u.max_hp = data.run.dummy_hp
	u.hp = u.max_hp
	u.dummy = true
	units.append(u)
	return u


func _step_lord(input: LordInput) -> void:
	var L := lord
	var D := data.lord
	L.cooldown -= dt
	L.swing -= dt
	L.invuln -= dt
	L.dash_cooldown -= dt
	var mv: Vector2 = input.move if input else Vector2.ZERO
	if mv.length() > 1.0:
		mv = mv.normalized()
	if mv.length() > 0.1:
		L.move_dir = mv.normalized()
	if input and input.dash and L.dash_cooldown <= 0.0 and L.dash <= 0.0:
		L.dash = D.dash_time
		L.dash_cooldown = D.dash_cooldown
		L.invuln = maxf(L.invuln, D.dash_time)
		L.dash_dir = L.move_dir
		lord_dashed.emit()
	var v: Vector2
	if L.dash > 0.0:
		L.dash -= dt
		v = L.dash_dir * D.dash_speed
	else:
		v = mv * D.speed
	var lim: float = float(Grid.size) - 0.3
	L.pos = (L.pos + v * dt).clamp(Vector2(0.3, 0.3), Vector2(lim, lim))
	if input and input.aim_valid and L.pos.distance_to(input.aim) > 0.05:
		L.face = (input.aim - L.pos).angle()
	elif mv.length() > 0.1:
		L.face = mv.angle()
	if input and input.attack and L.cooldown <= 0.0:
		_swing()
	if phase == Phase.DAY:
		L.hp = minf(D.hp, L.hp + D.regen_day * dt)


## 3연타의 세 번째가 강타다(1, 2, 3, 1, 2, 3 …). 부채꼴 안이거나 아주 가까운 것을 모두 친다.
func _swing() -> void:
	var L := lord
	var D := data.lord
	L.cooldown = D.cooldown
	L.combo = L.combo % 3 + 1
	var big: bool = L.combo == 3
	L.big = big
	L.swing = D.swing_time
	var reach: float = D.reach * (D.big_reach_mult if big else 1.0)
	var arc: float = D.arc * (D.big_arc_mult if big else 1.0)
	var dmg: float = D.damage * (D.big_damage_mult if big else 1.0)
	var hits: int = 0
	for u in units:
		var to: Vector2 = u.pos - L.pos
		var d: float = to.length()
		if d > reach + u.radius:
			continue
		if absf(angle_difference(L.face, to.angle())) > arc / 2.0 and d > u.radius + D.close_hit:
			continue
		hurt(u, dmg, to / maxf(d, 0.001) * D.knockback, big)
		hits += 1
	lord_swung.emit(big)
	if hits > 0:
		freeze = maxi(freeze, roundi((D.hitstop_big if big else D.hitstop) / dt))


func hurt(u: Unit, damage: float, knock: Vector2, big: bool) -> void:
	u.hp -= damage
	u.pos += knock * u.knockback_mult
	unit_hit.emit(u, damage, big)
	if u.dummy and u.hp <= 0.0:
		u.hp = u.max_hp


func _step_units() -> void:
	for u in units:
		if u.dummy:
			u.pos = u.pos.move_toward(u.home, data.run.dummy_return_speed * dt)
