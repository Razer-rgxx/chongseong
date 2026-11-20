class_name Foes
extends RefCounted
## 11단계 새 적 5종의 행동(docs/content.md "11단계: 적 행동"). Rules가 하나 들고 있고, _step_enemies와 hurt에서 부른다.
##   활잡이   거리를 둔다(keep_near보다 가까우면 물러나고 keep_far보다 멀면 다가온다). 표를 받으면 aim_time 겨눈 뒤 화살을 쏜다.
##            화살은 Rules.enemy_projectiles(kind arrow)이고 영주의 좌클릭 판정·검기에 닿으면 부러진다. 돌진·갈고리 중에는 지나간다.
##   방패병   앞 guard_arc°에서 맞으면 피해·넉백을 줄인다. 마무리(큰 베기)에 앞을 맞으면 깨진다(기절, guard_down초 동안 못 막는다).
##            몸을 turn_rate로 천천히 돌려서 옆과 뒤가 열린다. 걷고 때리는 것은 망령과 같다.
##   돌격병   wait_range 둘레에서 표를 기다린다. 표를 받고 charge_min~charge_max칸이면 머리를 낮추고(wind_time), 곧게 달린다.
##            영주에게 닿으면 피해와 큰 넉백(영주가 밀려난다). 끝나면 비틀거리고 그동안 받는 피해 × stagger_mult.
##   자폭병   표를 받고 fuse_range칸 안이면 심지(fuse_time) 뒤 터져 영주와 다른 적을 다친다. 심지가 타는 동안 죽으면 바로 터진다.
##   부르는 자 표를 쓰지 않고 때리지 않는다. 멀리 도망치며 summon_interval초마다 summon_time 동안 불러내고 망령을 부른다.
## 들판의 우두머리(32단계)는 EnemyData.kind로 이 종류들의 행동을 그대로 빌린다(acts()).
##   무덤 기사 (18단계, 들판 보스) 표를 쓰지 않는다. 쿨다운이 끝나면 가까우면 크게 휘두르기(swing_wind: 앞 swing_arc° 부채꼴, swing_time초 예고),
##            charge_min~charge_max칸이면 charge_chance 확률로 돌진 베기(돌격병과 같은 wind → charge), 아니면 다가간다. 체력이 summon_below 밑이면 망령을 한 번 부른다(summon_again이 있으면 그 밑에서 한 번 더, 31단계 무덤 주인).
##            체력이 rage_hp 밑이면 빠르기·예고·돌진·쉬는 시간이 rage_mult배 빨라진다(_rate).
## 기절하면 겨눔·머리 낮춤·불러내기가 끊기고 돌진은 멈춘다(비틀거림). 심지와 방패 깨짐, 비틀거림은 기절해도 이어진다.
## 랜덤은 Rules.rng만 쓴다(부를 자리의 첫 각). 화면에는 Rules.enemy_act·enemy_projectile_spawned·enemy_projectile_ended로 알린다.

## 기절하면 끊기는 일.
const BREAKABLE: Array[StringName] = [&"aim", &"wind", &"call_wind", &"swing_wind"]
## 이 일 동안은 몸을 돌리지 않는다(정한 쪽을 본다).
const LOCK_FACE: Array[StringName] = [&"aim", &"shoot", &"wind", &"charge", &"charge_end", &"guard_break", &"swing_wind", &"swing"]
## 이 일 동안은 걷지 않는다(돌진은 따로 달린다). block은 막은 채 걷는다.
const HOLD: Array[StringName] = [&"aim", &"shoot", &"wind", &"charge_end", &"guard_break", &"fuse", &"explode", &"call_wind", &"call", &"swing_wind", &"swing"]

var r: Rules


func _init(rules: Rules) -> void:
	r = rules


# ---------------------------------------------------------------- Rules가 부르는 자리

## 나왔을 때: 부르는 자는 summon_interval 뒤에 처음 부른다.
func on_spawn(e: Enemy) -> void:
	if e.data.summon_count > 0:
		e.cooldown = e.data.summon_interval


## 표를 청하는 거리. 0이면 Tokens가 사거리로 정한다.
func wait_range(e: Enemy) -> float:
	return e.data.wait_range


## 표를 받을 수 있는지: 비틀거림·방패 깨짐·쏜 뒤처럼 다른 일을 하는 동안은 받지 않는다(표를 묶어 두지 않게).
## 막힘을 돌아오는 중(37단계, Enemy.detour)에도 받지 않는다(벽 너머에서 표를 묶어 두지 않게).
func can_take_token(e: Enemy) -> bool:
	return (e.act == &"" or e.act == &"block") and not e.detour


## 걷는 빠르기 배수(무덤 기사형이 빨라지면 rage_mult, 아니면 1). 막힘을 돌아올 때 Rules가 쓴다.
func pace(e: Enemy) -> float:
	return _rate(e)


## 막힘을 돌아오는 중(37단계, Rules._detour가 흐름장으로 걷는다)의 행동. true면 여기서 맡았다(걷지 않는다).
## 하던 돌진과 멈춘 일(겨눔·휘두르기 예고·심지 …)은 이어 가고, 부르기(부르는 자, 기사형)는 한다.
## 겨누기·머리 낮추기·휘두르기·심지는 곧게 보일 때만(step) 시작한다(벽 너머로 쏘거나 베지 않게).
func detour(e: Enemy, _k: float, dt: float) -> bool:
	if e.act == &"charge":
		_step_charge(e, dt)
		return true
	if HOLD.has(e.act):
		return true
	match e.data.acts():
		&"caller":
			return _try_call(e)
		&"grave_knight", &"crypt_lord":
			return _try_knight_call(e)
	return false


## 때릴 수 있는지: 표를 들었거나 표 없이 덤비는 밤(표 수 0).
func armed(e: Enemy) -> bool:
	return e.token > 0 or r.tokens.cost(e) <= 0


## 매 틱, 적마다(움직이기 전, 묶여 있어도). k는 이번 틱의 빠르기 배수(0이면 기절·얼음·멈춘 순간).
## 시간을 세고 끝난 일을 다음 일로 넘긴다.
func tick(e: Enemy, k: float, dt: float) -> void:
	if r.powers.stop_t > 0.0:
		return
	if e.guard_down > 0.0:
		e.guard_down = maxf(0.0, e.guard_down - dt)
	if e.act == &"":
		return
	if k <= 0.0:
		if BREAKABLE.has(e.act):
			if e.act == &"call_wind":
				e.cooldown = e.data.summon_interval
			elif e.act == &"swing_wind":
				e.cooldown = _cd(e)
			e.act = &""
			return
		if e.act == &"charge":
			_end_charge(e, false)
			return
	e.act_t += dt * _rate(e)
	if e.act_t < e.act_time - 0.0001:
		return
	match e.act:
		&"aim":
			_shoot(e)
		&"wind":
			_start_charge(e)
		&"charge":
			_end_charge(e, false)
		&"fuse":
			explode(e)
		&"call_wind":
			_call(e)
		&"swing_wind":
			_swing(e)
		_:
			e.act = &""


## 몸을 영주(또는 망각이면 다른 적) 쪽으로 돌린다. want는 단위 벡터.
func turn(e: Enemy, want: Vector2, dt: float) -> void:
	if LOCK_FACE.has(e.act):
		return
	var rate: float = e.data.turn_rate
	if rate <= 0.0:
		e.face = want
		return
	var a: float = e.face.angle()
	var diff: float = angle_difference(a, want.angle())
	var s: float = rate * dt
	e.face = Vector2.from_angle(a + clampf(diff, -s, s))


## 이 틱의 움직임. true면 여기서 맡았다(Rules의 걷기·때리기를 건너뛴다).
## foe는 망각으로 칠 다른 적(없으면 null), to·d는 목표까지의 벡터와 거리, k는 빠르기 배수.
func step(e: Enemy, foe: Enemy, to: Vector2, d: float, k: float, dt: float) -> bool:
	if e.act == &"charge":
		_step_charge(e, dt)
		return true
	if BREAKABLE.has(e.act) and foe != null:
		e.act = &""
	if HOLD.has(e.act):
		return true
	if foe != null:
		return false
	match e.data.acts():
		&"archer":
			_archer(e, to, d, k, dt)
			return true
		&"charger":
			_charger(e, to, d, k, dt)
			return true
		&"bomber":
			return _bomber(e, d)
		&"caller":
			_caller(e, to, d, k, dt)
			return true
		&"grave_knight", &"crypt_lord":
			_knight(e, to, d, k, dt)
			return true
	return false


## 적이 맞을 때(Rules.hurt, 피해를 깎기 전). [피해, 넉백]을 돌려준다.
## 방패병은 앞에서 막고 마무리에 깨지고, 비틀거리는 돌격병은 더 다친다. src는 때린 자리(영주 또는 폭발).
func taken(e: Enemy, dmg: float, knock: Vector2, big: bool, dot: bool, src: Vector2) -> Array:
	if e.act == &"charge_end":
		dmg *= e.data.stagger_mult
	var D := e.data
	if dot or D.guard_arc <= 0.0 or e.guard_down > 0.0 or e.stun > 0.0 or e.frozen or e.act == &"guard_break":
		return [dmg, knock]
	var to: Vector2 = src - e.pos
	if to.length() < 0.001 or absf(angle_difference(e.face.angle(), to.angle())) > deg_to_rad(D.guard_arc) / 2.0:
		return [dmg, knock]
	if big:
		e.guard_down = D.guard_down
		e.stun = maxf(e.stun, D.guard_stun)
		_begin(e, &"guard_break", D.guard_stun)
		r.enemy_act.emit(e, &"guard_break", {"at": e.pos, "time": D.guard_stun})
		return [dmg, knock]
	var dir: Vector2 = to.normalized()
	if e.act == &"" or e.act == &"block":
		_begin(e, &"block", D.act_after)
	r.enemy_act.emit(e, &"block", {"at": e.pos + dir * e.radius, "dir": dir})
	return [dmg * D.guard_mult, knock * D.guard_knock]


## 표를 든 적이 영주를 때리기까지 남은 시간에 더할 준비 시간(겨눔, 머리 낮춤, 심지). 이미 하고 있으면 남은 시간만.
func prep_left(e: Enemy) -> float:
	match e.act:
		&"aim", &"wind", &"fuse":
			return maxf(0.0, e.act_time - e.act_t)
		&"charge":
			return 0.0
	match e.data.acts():
		&"archer":
			return e.data.aim_time
		&"charger":
			return e.data.wind_time
		&"bomber":
			return e.data.fuse_time
	return 0.0


## 때리기 시작할 수 있는 거리(영주와 가운데 사이, 칸).
func strike_reach(e: Enemy) -> float:
	match e.data.acts():
		&"archer":
			return e.data.shot_range
		&"charger":
			return e.data.charge_max
		&"bomber":
			return e.data.fuse_range
	return e.radius + r.data.run.enemy_reach


## 지금 무엇을 하고 있어 곧 때리는지(겨눔·머리 낮춤·심지).
func busy(e: Enemy) -> bool:
	return e.act == &"aim" or e.act == &"wind" or e.act == &"fuse" or e.act == &"charge"


# ---------------------------------------------------------------- 활잡이

func _archer(e: Enemy, to: Vector2, d: float, k: float, dt: float) -> void:
	var D := e.data
	if armed(e) and e.cooldown <= 0.0 and e.windup <= 0.0 and d <= D.shot_range and d > 0.001:
		e.act_dir = to / d
		e.face = e.act_dir
		_begin(e, &"aim", D.aim_time)
		r.enemy_act.emit(e, &"aim", {"from": e.pos, "dir": e.act_dir, "time": D.aim_time, "length": D.shot_range})
		return
	_keep(e, to, d, D.keep_near, D.keep_far, D.speed * k, dt)


func _shoot(e: Enemy) -> void:
	var D := e.data
	var p := Projectile.new()
	p.kind = &"arrow"
	p.id = r._new_id()
	p.dir = e.act_dir
	p.pos = e.pos + e.act_dir * (e.radius + 0.1)
	p.prev_pos = p.pos
	p.speed = D.shot_speed
	p.distance = D.shot_range
	p.width = D.shot_radius * 2.0
	p.max_time = D.shot_range / maxf(D.shot_speed, 0.1) + 1.0
	p.owner = e
	p.damage = e.damage
	r.enemy_projectiles.append(p)
	_begin(e, &"shoot", D.act_after)
	e.cooldown = D.cooldown
	# 쏜 것이 때린 것이다: 표를 돌려놓는다
	r.tokens.release(e, true)
	r.enemy_act.emit(e, &"shoot", {"from": e.pos, "dir": e.act_dir})
	r.enemy_projectile_spawned.emit(p)


## 화살을 옮기고 영주에게 닿았는지 본다. Rules가 적이 다 움직인 뒤 부른다.
func step_arrows(dt: float) -> void:
	var L := r.lord
	for p in r.enemy_projectiles.duplicate():
		if not r.enemy_projectiles.has(p):
			continue
		p.age += dt
		var from: Vector2 = p.pos
		var s: float = p.speed * dt
		p.pos += p.dir * s
		p.travelled += s
		# 돌진·갈고리로 날아가는 중에는 지나간다
		if L.dash <= 0.0 and L.hook <= 0.0 and Moves._seg_dist(L.pos, from, p.pos) <= p.width / 2.0:
			r._hurt_lord(p.damage, p.owner)
			_end_arrow(p, true)
			continue
		if p.travelled >= p.distance - 0.0001 or p.age >= p.max_time:
			_end_arrow(p, false)


## 영주의 좌클릭에 부러졌다.
func cut_arrow(p: Projectile) -> void:
	if not r.enemy_projectiles.has(p):
		return
	p.cut = true
	_end_arrow(p, false)


func _end_arrow(p: Projectile, hit: bool) -> void:
	r.enemy_projectiles.erase(p)
	r.enemy_projectile_ended.emit(p, hit)


# ---------------------------------------------------------------- 돌격병

func _charger(e: Enemy, to: Vector2, d: float, k: float, dt: float) -> void:
	var D := e.data
	var sp: float = D.speed * k
	if not armed(e):
		r.tokens.wait_move(e, to, d, sp, dt)
		return
	if d < 0.001:
		return
	if e.cooldown <= 0.0 and e.windup <= 0.0 and d >= D.charge_min and d <= D.charge_max:
		e.act_dir = to / d
		e.face = e.act_dir
		e.act_from = e.pos
		var length: float = _lane(e.pos, e.act_dir, D.charge_length, e.radius)
		e.act_to = e.pos + e.act_dir * length
		_begin(e, &"wind", D.wind_time)
		r.enemy_act.emit(e, &"wind", {"from": e.pos, "dir": e.act_dir, "length": length, "time": D.wind_time, "width": e.radius * 2.0})
		return
	if d < D.charge_min:
		_move_in(e, -to / d * sp * dt)
	elif d > D.charge_max:
		e.pos += to / d * sp * dt


func _start_charge(e: Enemy) -> void:
	var D := e.data
	# 머리를 낮추는 동안 밀렸으면 지금 자리에서 같은 쪽으로
	e.act_from = e.pos
	var length: float = _lane(e.pos, e.act_dir, D.charge_length, e.radius)
	e.act_to = e.pos + e.act_dir * length
	if length < 0.05:
		_end_charge(e, false)
		return
	var time: float = length / maxf(D.charge_speed, 0.1)
	_begin(e, &"charge", time)
	r.enemy_act.emit(e, &"charge", {"from": e.act_from, "to": e.act_to, "time": time / _rate(e)})


func _step_charge(e: Enemy, dt: float) -> void:
	var D := e.data
	var L := r.lord
	e.push = Vector2.ZERO
	var from: Vector2 = e.pos
	var s: float = D.charge_speed * _rate(e) * dt
	var left: float = e.pos.distance_to(e.act_to)
	e.pos += e.act_dir * minf(s, left)
	if L.dash <= 0.0 and L.hook <= 0.0 and Moves._seg_dist(L.pos, from, e.pos) <= e.radius + r.data.run.enemy_reach:
		var parry: bool = L.parry > 0.0
		r._hurt_lord(e.damage, e)
		if not parry and r.phase == Rules.Phase.NIGHT:
			var away: Vector2 = L.pos - e.pos
			var dir: Vector2 = (e.act_dir + (away.normalized() if away.length() > 0.001 else e.act_dir)).normalized()
			# 틱마다 push × q로 줄어드니 다 밀려난 거리 = 처음 빠르기 × dt / (1 - q). 그게 charge_knock칸이 되게
			var q: float = pow(r.data.lord.knock_keep, r.dt)
			L.push += dir * D.charge_knock * (1.0 - q) / r.dt
		_end_charge(e, true)
		return
	if left <= s:
		_end_charge(e, false)


func _end_charge(e: Enemy, hit: bool) -> void:
	var D := e.data
	_begin(e, &"charge_end", D.stagger_time)
	e.cooldown = _cd(e)
	r.tokens.release(e, true)
	r.enemy_act.emit(e, &"charge_end", {"at": e.pos, "hit": hit, "time": D.stagger_time, "stun": D.stagger_time > 0.0})


## from에서 dir로 length칸 가되 싸움터 안(가장자리 0.5칸)에서 멈추는 길이. 싸움터 밖에서 시작하면 그대로.
## 막힘이 있으면(37단계) 반지름 rad인 몸이 막힘 앞에서 멈추는 길이로 줄인다.
func _lane(from: Vector2, dir: Vector2, length: float, rad: float = 0.0) -> float:
	if r.nav != null:
		length = r.nav.run_len(from, dir, length, Nav.class_of(rad))
	var lo := Vector2(0.5, 0.5)
	var hi := Vector2(Grid.size) - Vector2(0.5, 0.5)
	if from.x < lo.x or from.y < lo.y or from.x > hi.x or from.y > hi.y:
		return length
	var t: float = length
	if dir.x > 0.0001:
		t = minf(t, (hi.x - from.x) / dir.x)
	elif dir.x < -0.0001:
		t = minf(t, (lo.x - from.x) / dir.x)
	if dir.y > 0.0001:
		t = minf(t, (hi.y - from.y) / dir.y)
	elif dir.y < -0.0001:
		t = minf(t, (lo.y - from.y) / dir.y)
	return maxf(0.0, t)


# ---------------------------------------------------------------- 자폭병

## 표를 들고 가까우면 심지에 불을 붙인다. 아니면 망령처럼 걷는다(false).
func _bomber(e: Enemy, d: float) -> bool:
	var D := e.data
	if D.fuse_range <= 0.0 or not armed(e) or e.windup > 0.0 or d > D.fuse_range:
		return false
	_begin(e, &"fuse", D.fuse_time)
	r.enemy_act.emit(e, &"fuse", {"at": e.pos, "radius": D.blast_radius, "time": D.fuse_time})
	return true


## 터진다: 영주와 반지름 안의 다른 적을 다친다. 스스로 터진 것은 쓰러뜨린 것으로 치지 않는다.
## 심지가 타는 동안 쓰러지면 Rules.hurt가 부른다(그때는 이미 죽어 있다). 다른 자폭병의 심지도 이어서 터진다.
func explode(e: Enemy) -> void:
	if e.act == &"explode":
		return
	var D := e.data
	_begin(e, &"explode", 0.2)
	var was_dead: bool = e.dead
	e.dead = true
	r.tokens.release(e, true)
	r.enemy_act.emit(e, &"explode", {"at": e.pos, "radius": D.blast_radius})
	if not was_dead:
		r.enemy_died.emit(e)
	if e.pos.distance_to(r.lord.pos) <= D.blast_radius:
		r._hurt_lord(e.damage, e)
	for o in r.enemies.duplicate():
		if o == e or o.dead:
			continue
		var v: Vector2 = o.pos - e.pos
		var dist: float = v.length()
		if dist > D.blast_radius + o.radius:
			continue
		var dir: Vector2 = v / dist if dist > 0.001 else Vector2.RIGHT
		r.hurt(o, e.damage * D.blast_enemy_mult, dir * D.blast_knock, false, false, e.pos)


# ---------------------------------------------------------------- 부르는 자

func _caller(e: Enemy, to: Vector2, d: float, k: float, dt: float) -> void:
	var D := e.data
	if _try_call(e):
		return
	_keep(e, to, d, D.keep_near, D.keep_far, D.speed * k, dt)


## 부르는 자: 쿨다운이 끝났고 더 부를 수 있으면 불러내기를 시작한다(call_wind).
func _try_call(e: Enemy) -> bool:
	var D := e.data
	if e.cooldown <= 0.0 and D.summon_count > 0 and e.summoned < D.summon_max and _alive() < r.data.run.max_enemies and _inside(e.pos, 1.0):
		_aim_spots(e)
		_begin(e, &"call_wind", D.summon_time)
		r.enemy_act.emit(e, &"call_wind", {"at": e.pos, "radius": D.summon_radius, "time": D.summon_time})
		return true
	return false


## 불러낼 자리(e.act_spots): 둘레 summon_radius에 고르게(첫 각은 rng). 막힘이 있으면(37단계) 부른 자에서 곧게 갈 수 있는 데까지만.
func _aim_spots(e: Enemy) -> void:
	var D := e.data
	var n: int = D.summon_count
	var a0: float = r.rng.randf() * TAU
	e.act_spots = PackedVector2Array()
	var cls: int = Nav.class_of(r.data.enemies[D.summon_kind].radius) if r.nav != null and r.data.enemies.has(D.summon_kind) else 0
	for i in n:
		var at: Vector2 = _clamp(e.pos + Vector2.from_angle(a0 + TAU * i / n) * D.summon_radius, 1.0)
		if r.nav != null:
			at = r.nav.reach(e.pos, at, cls)
		e.act_spots.append(at)


func _call(e: Enemy) -> void:
	var D := e.data
	var n: int = mini(mini(D.summon_count, D.summon_max - e.summoned), r.data.run.max_enemies - _alive())
	n = clampi(n, 0, e.act_spots.size())
	var spots: Array[Vector2] = []
	for i in n:
		var at: Vector2 = e.act_spots[i]
		var s: Enemy = r.spawn_at(D.summon_kind, at)
		s.pack = e.pack   # 들판: 불려 온 적도 부른 자의 무리(제자리로 돌아간다)
		s.home = at
		s.caller = e.id
		spots.append(at)
	e.summoned += n
	e.cooldown = D.summon_interval
	_begin(e, &"call", D.act_after)
	r.enemy_act.emit(e, &"call", {"at": e.pos, "count": n, "spots": spots})


func _alive() -> int:
	var n: int = 0
	for o in r.enemies:
		if not o.dead:
			n += 1
	return n


# ---------------------------------------------------------------- 무덤 기사

## 빨라지는 배수: 체력이 rage_hp 밑이면 rage_mult, 아니면 1.
func _rate(e: Enemy) -> float:
	var D := e.data
	if D.rage_hp > 0.0 and e.hp <= e.max_hp * D.rage_hp:
		return D.rage_mult
	return 1.0


## 다음 행동까지 쉬는 시간(빨라지면 짧다).
func _cd(e: Enemy) -> float:
	return e.data.cooldown / _rate(e)


## 기사형의 다음 부르기가 되는 체력 비율: 처음은 summon_below, 한 번 불렀으면 summon_again(없으면 -1이라 다시 안 부른다).
## 부른 횟수는 summoned를 summon_count로 나눠 올림(한도 때문에 덜 불렀어도 한 번으로 친다).
func _summon_below(e: Enemy) -> float:
	var D := e.data
	var waves: int = ceili(float(e.summoned) / float(maxi(1, D.summon_count)))
	if waves <= 0:
		return D.summon_below
	if waves == 1 and D.summon_again > 0.0:
		return D.summon_again
	return -1.0


## 빨라졌는지(체력이 rage_hp 밑).
func raged(e: Enemy) -> bool:
	return _rate(e) > 1.0


func _knight(e: Enemy, to: Vector2, d: float, k: float, dt: float) -> void:
	var D := e.data
	var rate: float = _rate(e)
	if d < 0.001:
		return
	if _try_knight_call(e):
		return
	if e.cooldown <= 0.0:
		if d <= D.swing_range:
			e.act_dir = to / d
			e.face = e.act_dir
			_begin(e, &"swing_wind", D.swing_time)
			r.enemy_act.emit(e, &"swing_wind", {"at": e.pos, "dir": e.act_dir, "arc": D.swing_arc, "range": D.swing_range, "time": D.swing_time / rate})
			return
		if d >= D.charge_min and d <= D.charge_max:
			if r.rng.randf() < D.charge_chance:
				e.act_dir = to / d
				e.face = e.act_dir
				e.act_from = e.pos
				var length: float = _lane(e.pos, e.act_dir, D.charge_length, e.radius)
				e.act_to = e.pos + e.act_dir * length
				_begin(e, &"wind", D.wind_time)
				r.enemy_act.emit(e, &"wind", {"from": e.pos, "dir": e.act_dir, "length": length, "time": D.wind_time / rate, "width": e.radius * 2.0})
				return
			e.cooldown = D.charge_retry   # 이번엔 안 달린다: 조금 더 다가가 다시 고른다
	if d > D.swing_range * 0.85:
		e.pos += to / d * D.speed * k * rate * dt


## 기사형의 부르기: 체력이 summon_below 밑으로 내려오면 한 번, summon_again(0보다 크면) 밑으로 내려오면 한 번 더(summoned가 summon_max에 닿을 때까지 못 부른 만큼만).
func _try_knight_call(e: Enemy) -> bool:
	var D := e.data
	if D.summon_count > 0 and e.summoned < D.summon_max and e.hp <= e.max_hp * _summon_below(e) and e.cooldown <= 0.0 \
			and _alive() < r.data.run.max_enemies and _inside(e.pos, 1.0):
		_aim_spots(e)
		_begin(e, &"call_wind", D.summon_time)
		r.enemy_act.emit(e, &"call_wind", {"at": e.pos, "radius": D.summon_radius, "time": D.summon_time / _rate(e)})
		return true
	return false


## 예고가 끝났다: 앞 swing_arc° 부채꼴 안에 영주가 있으면 벤다(구르는 중이면 지나간다).
func _swing(e: Enemy) -> void:
	var D := e.data
	var L := r.lord
	var v: Vector2 = L.pos - e.pos
	var hit: bool = v.length() <= D.swing_range and absf(angle_difference(e.act_dir.angle(), v.angle())) <= deg_to_rad(D.swing_arc) / 2.0
	if hit and L.dash <= 0.0 and L.hook <= 0.0:
		r._hurt_lord(e.damage, e)
	_begin(e, &"swing", D.act_after)
	e.cooldown = _cd(e)
	r.enemy_act.emit(e, &"swing", {"at": e.pos, "dir": e.act_dir, "arc": D.swing_arc, "range": D.swing_range, "hit": hit})


# ---------------------------------------------------------------- 공통

func _begin(e: Enemy, act: StringName, time: float) -> void:
	e.act = act
	e.act_t = 0.0
	e.act_time = time


## 거리를 두는 걸음: near보다 가까우면 물러나고 far보다 멀면 다가오고, 그 사이면 영주를 보며 천천히 옆으로 돈다.
func _keep(e: Enemy, to: Vector2, d: float, near: float, far: float, sp: float, dt: float) -> void:
	if d < 0.001:
		return
	var inward: Vector2 = to / d
	if d < near:
		_move_in(e, -inward * sp * dt)
	elif d > far:
		e.pos += inward * minf(sp * dt, d - far)
	else:
		var side: float = 1.0 if e.id % 2 == 0 else -1.0
		_move_in(e, Vector2(inward.y, -inward.x) * side * sp * r.data.run.token_strafe * dt)


## 옮기되 싸움터 안에 있었으면 안(가장자리 0.5칸)에 남는다. 몰리면 벽을 따라 미끄러진다.
func _move_in(e: Enemy, by: Vector2) -> void:
	var was_in: bool = _inside(e.pos, 0.5)
	e.pos += by
	if was_in:
		e.pos = _clamp(e.pos, 0.5)


func _inside(p: Vector2, margin: float) -> bool:
	var size := Vector2(Grid.size)
	return p.x >= margin and p.y >= margin and p.x <= size.x - margin and p.y <= size.y - margin


func _clamp(p: Vector2, margin: float) -> Vector2:
	var size := Vector2(Grid.size)
	return p.clamp(Vector2(margin, margin), size - Vector2(margin, margin))
