class_name Moves
extends RefCounted
## 좌클릭 동작 실행(docs/attacks.md). Rules가 하나 들고 있고, 좌클릭 한 번마다 attack()을 부른다.
## 쥔 검의 공격 방식(PatternData)에서 다음 동작(MoveData)을 골라, 판정 모양(부채꼴·띠·원·고리·십자)과
## 늦게 터지는 판정, 여러 번 맞히기, 영주를 옮기는 동작, 날아가는 것(Rules.projectiles), 반격 자세, 속성, 메아리를 돌린다.
## 맞힐 때마다 Powers의 자리(before_swing, swing_damage, crowd_mult, knock_mult, strike, after_strike, after_swing,
## wears, force_big)를 예전 _swing과 같은 순서로 부른다. before_swing·swing_damage·after_swing은 동작마다 한 번,
## strike·after_strike는 맞은 적마다, crowd_mult·히트스톱은 판정마다, 내구는 동작마다 한 번 닳는다.
## 시간은 이 객체의 시계(_clock, 히트스톱 동안 멈춘다)로 잰다. 랜덤은 쓰지 않는다.

const EPS: float = 0.0001

var r: Rules
## 늦게 터지는 판정: {at_time, run, kind(area, shot, lunge_echo), area}
var events: Array[Dictionary] = []
## 갈고리 베기로 날아가는 중인 동작. 오른쪽 클릭 갈고리면 null.
var hook_run: MoveRun = null
var _clock: float = 0.0
var _serial: int = 0
## 지금 하는 동작(화면에 알린 것)과 시작한 때.
var _move_run: MoveRun = null
var _move_t0: float = 0.0
## 영주를 옮기는 동작(찌르기의 반 칸, 물러나 베기, 돌진베기, 도약).
var _go_run: MoveRun = null
var _go_from := Vector2.ZERO
var _go_to := Vector2.ZERO
var _go_t0: float = 0.0
var _go_t1: float = 0.0
## 반격 자세.
var _parry_run: MoveRun = null


func _init(rules: Rules) -> void:
	r = rules


# ---------------------------------------------------------------- 묻기

## 쥔 검(없으면 맨손)의 공격 방식.
func pattern() -> PatternData:
	var s := r.current()
	if s and s.pattern:
		return s.pattern
	return r.data.unarmed_pattern()


## 갈고리 검을 쥐었는지(우클릭 갈고리).
func has_hook() -> bool:
	var p := pattern()
	return p != null and p.has_hook()


## 영주를 규칙이 옮기는 중인지(그동안 걷지 못한다).
func steering() -> bool:
	return _go_run != null


## 동작 동안 걷는 빠르기 배수. 0보다 작으면 정해진 것이 없다(보통 휘두르기).
func walk_mult() -> float:
	var L := r.lord
	if _move_run and L.move != &"" and L.move_t < L.move_time and _move_run.move.walk >= 0.0:
		return _move_run.move.walk
	return -1.0


# ---------------------------------------------------------------- 좌클릭

## 좌클릭 한 번: 방식의 다음 동작. 연타가 끊기면(combo_window) 처음부터. 마지막 동작이 마무리(큰 베기)다.
func attack(input: LordInput) -> void:
	var L := r.lord
	var D := r.data.lord
	var pat := pattern()
	var n: int = maxi(1, pat.steps())
	if L.combo_timer <= 0.0:
		L.combo = 0
	L.combo = L.combo % n + 1
	var step: int = L.combo
	var m: MoveData = r.data.move(pat.move_at(step))
	# 동작이 하나뿐인 방식(맨손)은 마무리가 없다
	var finisher: bool = step == n and n > 1
	var big: bool = finisher or r.powers.force_big()
	var st: Dictionary = r.powers.stats()
	var busy: float = busy_time(m)
	L.big = big
	L.swing = D.swing_time
	L.swing_arc = st.arc
	L.swing_reach = minf(st.reach, 12.0)
	L.cooldown = maxf(D.cooldown / maxf(0.05, st.spd) * m.cooldown * (D.big_cooldown_mult if big else 1.0), busy)
	L.combo_timer = busy + D.combo_window
	if r.powers.before_swing():
		r.lord_swung.emit(true)
		return
	var run := _new_run(m, step, n, big, st, pat.element)
	run.finisher = finisher
	run.echo_next = finisher and pat.echo
	_begin(run, input)
	r.lord_swung.emit(big)


## 39단계 말 위 베기: 좌클릭은 한 가지뿐이다. 기본 동작 횡베기(sweep)를 쥔 검의 수치(Powers.stats)로, 사거리 × HorseData.slash_reach,
## 부채꼴 slash_arc_deg도, 피해 × slash_damage로 넓게 한 번 벤다(달리며 지나가는 적을 벤다). 연타·마무리·방식의 다른 동작은 없다.
## 속성은 쥔 검의 방식을 따른다. 맨손이면 Rules가 부르지 않는다. 화면에는 sweep로 알린다(info.ride = true).
func ride_attack(_input: LordInput) -> void:
	var L := r.lord
	var D := r.data.lord
	var H := r.data.horse
	var m: MoveData = r.data.move(&"sweep")
	var st: Dictionary = r.powers.stats()
	var reach: float = st.reach * H.slash_reach
	var arc: float = deg_to_rad(H.slash_arc_deg)
	L.combo = 0
	L.combo_timer = 0.0
	L.big = false
	L.swing = D.swing_time
	L.swing_arc = arc
	L.swing_reach = minf(reach, 12.0)
	L.cooldown = maxf(D.cooldown / maxf(0.05, st.spd) * m.cooldown * H.slash_cooldown, busy_time(m))
	if r.powers.before_swing():
		r.lord_swung.emit(true)
		return
	var run := _new_run(m, 1, 1, false, st, pattern().element)
	run.base *= H.slash_damage
	var a := _arc_raw(run, L.pos, run.face, reach, minf(arc, TAU), m.damage)
	a["main"] = true
	_started(run, a, {"ride": true})
	_fire(run, a)
	r.lord_swung.emit(false)


## 동작이 이어지는 동안(초). 이보다 빨리 다음 좌클릭을 받지 않는다.
static func busy_time(m: MoveData) -> float:
	return maxf(maxf(m.lock, m.delay), maxf(m.go_after + m.go_time, (m.hits - 1) * m.interval))


func _new_run(m: MoveData, step: int, steps: int, big: bool, st: Dictionary, element: StringName) -> MoveRun:
	var D := r.data.lord
	var F: FormData = st.form
	var run := MoveRun.new()
	_serial += 1
	run.id = _serial
	run.move = m
	run.step = step
	run.steps = steps
	run.big = big
	run.element = element
	run.sword = r.current()
	run.st = st
	run.base = r.powers.swing_damage(st.dmg, big) * r.memory_mult(run.sword)   # 검의 기억
	run.knock = D.knockback * F.knockback * r.powers.knock_mult()
	run.at = r.lord.pos
	run.face = r.lord.face
	return run


func _begin(run: MoveRun, input: LordInput) -> void:
	var L := r.lord
	var m := run.move
	var fwd := Vector2.from_angle(run.face)
	var reach: float = run.st.reach
	match m.id:
		&"thrust":
			var a := _line(run, L.pos, run.face, reach * m.reach, m.width, m.damage)
			a["main"] = true
			_go(run, L.pos, _clamp(L.pos + fwd * m.dist), m.go_after, m.go_time)
			_started(run, a)
			_fire(run, a)
		&"flurry":
			var a := _line(run, L.pos, run.face, reach * m.reach, m.width, m.damage)
			a["minor"] = true
			a["emit"] = true
			a["follow"] = true
			_started(run, a)
			for k in m.hits:
				var ak: Dictionary = a.duplicate()
				ak["main"] = k == 0
				if k == 0:
					_fire(run, ak)
				else:
					_schedule(k * m.interval, run, ak)
		&"retreat":
			var a := _arc(run, L.pos, run.face, m)
			a["main"] = true
			_go(run, L.pos, _clamp(L.pos + fwd * m.dist), m.go_after, m.go_time)
			_started(run, a)
			_fire(run, a)
		&"pull":
			var a := _arc(run, L.pos, run.face, m)
			a["main"] = true
			a["pull_to"] = m.pull_to
			_started(run, a)
			_fire(run, a)
		&"smash":
			var a := _circle(run, L.pos + fwd * reach * m.ahead, _radius(run, m), m.damage)
			a["main"] = true
			a["emit"] = true
			a["stun"] = m.stun
			_started(run, a, {"delay": m.delay})
			_schedule(m.delay, run, a)
		&"spin":
			var a := _circle(run, L.pos, _radius(run, m), m.damage)
			a["main"] = true
			_started(run, a)
			_fire(run, a)
		&"lunge":
			var to := _clamp(L.pos + fwd * m.dist)
			var a := _line(run, L.pos, run.face, L.pos.distance_to(to), m.path_width * 2.0, m.damage)
			_go(run, L.pos, to, 0.0, m.go_time)
			_started(run, a, {"time": m.go_time})
		&"wave", &"boomerang":
			var a := _line(run, L.pos, run.face, m.distance, m.shot_width, m.damage)
			_started(run, a)
			_shoot(run, L.pos, run.face)
		&"leap":
			var to := _leap_to(run, input)
			var a := _circle(run, to, _radius(run, m), m.damage)
			a["main"] = true
			a["emit"] = true
			_go(run, L.pos, to, 0.0, m.go_time)
			_started(run, a, {"time": m.go_time})
			_schedule(m.go_time, run, a)
		&"iaido":
			var a := _line(run, L.pos, run.face, reach * m.reach, m.width, m.damage)
			a["main"] = true
			a["emit"] = true
			_started(run, a, {"delay": m.delay})
			_schedule(m.delay, run, a)
		&"cross":
			var a := _line(run, L.pos, run.face, reach * m.reach, m.width, m.damage)
			a["shape"] = &"plus"
			a["cross"] = reach * m.cross_reach
			a["main"] = true
			_started(run, a)
			_fire(run, a)
		&"quake":
			var a := _circle(run, L.pos, _radius(run, m), m.damage)
			a["main"] = true
			_started(run, a)
			_fire(run, a)
			for k in mini(m.ring_radii.size(), m.ring_times.size()):
				var ring := _circle(run, L.pos, m.ring_radii[k], m.ring_damage)
				ring["shape"] = &"ring"
				ring["thick"] = m.ring_thick
				ring["minor"] = true
				ring["emit"] = true
				# 퍼지는 한 물결이라 적마다 고리 하나에만 맞는다(넉백으로 다음 고리에 밀려가도)
				ring["once"] = true
				_schedule(m.ring_times[k], run, ring)
		&"whirl":
			var a := _circle(run, L.pos, _radius(run, m), m.damage)
			a["minor"] = true
			a["emit"] = true
			a["follow"] = true
			_started(run, a)
			for k in m.hits:
				var ak: Dictionary = a.duplicate()
				ak["main"] = k == 0
				if k == 0:
					_fire(run, ak)
				else:
					_schedule(k * m.interval, run, ak)
		&"blink":
			var e := _seek(L.pos, run.face, m.seek_range, deg_to_rad(m.seek_cone))
			if e == null:
				_fallback(run)
				return
			var dir: Vector2 = (e.pos - L.pos).normalized()
			var from: Vector2 = L.pos
			var to := _clamp(e.pos + dir * m.behind)
			L.pos = to
			L.face = (e.pos - to).angle() if e.pos.distance_to(to) > 0.01 else run.face + PI
			run.face = L.face
			run.at = to
			run.from = from
			run.to = to
			L.move_from = from
			L.move_to = to
			var a := _arc(run, to, run.face, m)
			a["main"] = true
			_started(run, a, {"from": from, "to": to})
			_fire(run, a)
		&"hook":
			var e := r.find_hook_target(run.face)
			if e == null:
				_fallback(run)
				return
			r.start_hook(e, run)
			var flight: float = hook_flight(e)
			L.combo_timer = maxf(L.combo_timer, flight + r.data.lord.combo_window)
		&"parry":
			var a := _circle(run, L.pos, reach * m.counter_reach, m.counter_damage)
			a["shape"] = &"arc"
			a["reach"] = reach
			a["arc"] = run.st.arc
			_parry_run = run
			L.parry = m.time
			_started(run, a)
		_:
			# 횡베기, 올려베기, 반월
			var a := _arc(run, L.pos, run.face, m)
			a["main"] = true
			a["stun"] = m.stun
			_started(run, a)
			_fire(run, a)


## 대상이 없을 때(순간 베기, 갈고리 베기): 그 자리에서 횡베기. 화면에는 원래 동작으로 알린다(from/to 없이).
func _fallback(run: MoveRun) -> void:
	var fb: MoveData = r.data.move(run.move.fallback) if run.move.fallback != &"" else null
	if fb == null:
		fb = r.data.move(&"sweep")
	var a := _arc(run, r.lord.pos, run.face, fb)
	a["main"] = true
	_started(run, a)
	_fire(run, a)


## 도약: 겨눈 쪽 부채꼴 안 가장 가까운 적의 자리로. 없으면 겨눈 곳(최대 dist칸, 겨눔이 없으면 dist칸).
func _leap_to(run: MoveRun, input: LordInput) -> Vector2:
	var L := r.lord
	var m := run.move
	var e := _seek(L.pos, run.face, m.seek_range, deg_to_rad(m.seek_cone))
	if e:
		return _clamp(e.pos)
	var d: float = m.dist
	if input and input.aim_valid:
		d = clampf(L.pos.distance_to(input.aim), 1.0, m.dist)
	return _clamp(L.pos + Vector2.from_angle(run.face) * d)


## 갈고리로 그 적까지 날아가는 시간(초, 화면에 알린다).
func hook_flight(e: Enemy) -> float:
	var D := r.data.lord
	var d: float = maxf(0.0, r.lord.pos.distance_to(e.pos) - e.radius - D.hook_gap)
	return clampf(d / D.hook_speed, r.dt, D.hook_max_time)


# ---------------------------------------------------------------- 갈고리

## 날아가기 시작했다(우클릭이든 갈고리 베기든). 화면에 갈고리 동작을 알린다.
func hook_started(e: Enemy, run: MoveRun) -> void:
	var L := r.lord
	var D := r.data.lord
	hook_run = run
	var to: Vector2 = e.pos - (e.pos - L.pos).normalized() * (e.radius + D.hook_gap)
	var pat := pattern()
	var info := {
		"at": to, "face": L.face, "shape": &"arc", "reach": r.powers.stats().reach, "arc": r.powers.stats().arc,
		"big": run.big if run else true, "element": pat.element, "step": run.step if run else 1,
		"steps": run.steps if run else pat.steps(), "time": hook_flight(e), "from": L.pos, "to": to, "echo": false,
	}
	_set_move(run if run else _grapple_run_stub(), info)
	L.move_from = L.pos
	L.move_to = to
	r.move_started.emit(&"hook", info)


func _grapple_run_stub() -> MoveRun:
	var run := MoveRun.new()
	run.move = r.data.move(&"hook")
	run.grapple = true
	return run


## 닿았다: 큰 베기. 갈고리 베기면 그 동작의 배수, 우클릭이면 큰 베기 × hook_damage_mult(예전과 같다).
func hook_arrived() -> void:
	var L := r.lord
	var D := r.data.lord
	var run := hook_run
	hook_run = null
	if run == null:
		var st: Dictionary = r.powers.stats()
		L.big = true
		L.swing = D.swing_time
		L.swing_arc = st.arc
		L.swing_reach = minf(st.reach, 12.0)
		if r.powers.before_swing():
			r.lord_swung.emit(true)
			return
		var pat := pattern()
		run = _new_run(r.data.move(&"hook"), 1, pat.steps(), true, st, pat.element)
		run.grapple = true
		run.face = L.face
		var a := _arc_raw(run, L.pos, L.face, st.reach, st.arc, D.big_damage_mult * D.hook_damage_mult)
		a["main"] = true
		a["emit"] = true
		_fire(run, a)
		r.lord_swung.emit(true)
		return
	run.face = L.face
	run.at = L.pos
	var b := _arc(run, L.pos, L.face, run.move)
	b["main"] = true
	b["emit"] = true
	_fire(run, b)


## 갈고리가 닿지 못하고 끝났다(적이 죽음, 시간).
func hook_ended() -> void:
	hook_run = null


# ---------------------------------------------------------------- 반격 자세

## 영주가 맞으려 할 때 Rules._hurt_lord가 부른다. 자세 중이면 피해 없이 둘레를 반격하고 true.
func parried(_attacker: Enemy) -> bool:
	var L := r.lord
	if L.parry <= 0.0 or _parry_run == null:
		return false
	var run := _parry_run
	var m := run.move
	_parry_run = null
	L.parry = 0.0
	L.move_lock = 0.0
	L.invuln = maxf(L.invuln, m.counter_invuln)
	run.big = true
	var a := _circle(run, L.pos, run.st.reach * m.counter_reach, m.counter_damage)
	a["main"] = true
	a["emit"] = true
	_fire(run, a)
	return true


## 자세가 끝날 때까지 안 맞았다: 약한 횡베기.
func _parry_weak(run: MoveRun) -> void:
	var L := r.lord
	var m := run.move
	_parry_run = null
	var a := _arc_raw(run, L.pos, L.face, run.st.reach, run.st.arc, m.weak_damage)
	a["main"] = true
	a["emit"] = true
	_fire(run, a)


# ---------------------------------------------------------------- 시간

## 매 틱(히트스톱·고르기·뽑기 동안은 부르지 않는다) Rules.step이 _step_lord 전에 부른다.
func advance(dt: float) -> void:
	_clock += dt


## 매 틱 _step_lord 뒤에: 영주를 옮기는 동작, 늦게 터지는 판정, 날아가는 것, 반격 자세.
func tick(dt: float) -> void:
	var L := r.lord
	if _move_run:
		L.move_t = _clock - _move_t0
		if L.move_t >= L.move_time - EPS and _go_run == null and L.hook <= 0.0 and L.parry <= 0.0:
			L.move = &""
			_move_run = null
	_step_go()
	if _parry_run and L.parry > 0.0:
		L.parry -= dt
		if L.parry <= EPS:
			L.parry = 0.0
			_parry_weak(_parry_run)
	for ev in events.duplicate():
		if float(ev.at_time) > _clock + EPS:
			continue
		events.erase(ev)
		var run: MoveRun = ev.run
		match ev.kind:
			"area":
				var a: Dictionary = ev.area
				if bool(a.get("follow", false)) and not run.echo:
					a["at"] = L.pos
				if run.echo and not run.echo_started:
					run.echo_started = true
					_announce_echo(run, a)
				_fire(run, a)
			"shot":
				if run.echo and not run.echo_started:
					run.echo_started = true
					_announce_echo(run, ev.area)
				_shoot(run, ev.area.at, float(ev.area.face))
	_step_shots(dt)


func _schedule(after: float, run: MoveRun, a: Dictionary, kind: String = "area") -> void:
	events.append({"at_time": _clock + after, "run": run, "kind": kind, "area": a})


## 밤이 끝나거나 다시 시작할 때 남은 것을 모두 지운다.
func clear() -> void:
	var L := r.lord
	for p in r.projectiles.duplicate():
		r.projectiles.erase(p)
		r.projectile_ended.emit(p)
	events.clear()
	hook_run = null
	_go_run = null
	_parry_run = null
	_move_run = null
	L.move = &""
	L.move_t = 0.0
	L.move_time = 0.0
	L.move_lock = 0.0
	L.parry = 0.0


# ---------------------------------------------------------------- 영주를 옮기기

func _go(run: MoveRun, from: Vector2, to: Vector2, after: float, time: float) -> void:
	var L := r.lord
	_go_run = run
	_go_from = from
	_go_to = to
	_go_t0 = _clock + after
	_go_t1 = _go_t0 + maxf(time, r.dt)
	run.from = from
	run.to = to
	L.move_from = from
	L.move_to = to
	if run.move.invuln:
		L.invuln = maxf(L.invuln, after + time + 0.05)


func _step_go() -> void:
	if _go_run == null:
		return
	var L := r.lord
	if _clock < _go_t0 - EPS:
		return
	var run := _go_run
	var k: float = clampf((_clock - _go_t0) / (_go_t1 - _go_t0), 0.0, 1.0)
	var prev: Vector2 = L.pos
	L.pos = _go_from.lerp(_go_to, k)
	var step: Vector2 = L.pos - prev
	if step.length() > 0.0001:
		L.moving = true
		L.move_dir = step.normalized()
	if run.move.id == &"lunge":
		var seg := {"shape": &"path", "from": prev, "to": L.pos, "width": run.move.path_width, "at": L.pos,
			"face": run.face, "mult": run.move.damage, "minor": true, "once": true}
		_fire(run, seg)
	if k >= 1.0:
		_go_run = null
		if run.move.id == &"lunge":
			_after(run)
			if run.echo_next:
				var line := _line(run, _go_from, run.face, _go_from.distance_to(_go_to), run.move.path_width * 2.0, run.move.damage)
				_schedule(r.data.lord.echo_delay, _echo_run(run), line)


# ---------------------------------------------------------------- 날아가는 것

func _shoot(run: MoveRun, origin: Vector2, face: float) -> void:
	var m := run.move
	var p := Projectile.new()
	p.kind = m.id
	p.pos = origin
	p.prev_pos = origin
	p.dir = Vector2.from_angle(face)
	p.element = run.element
	p.width = m.shot_width
	p.id = r._new_id()
	p.speed = m.speed
	p.distance = m.distance
	p.max_time = m.shot_max_time
	p.run = run
	r.projectiles.append(p)
	r.projectile_spawned.emit(p)
	if run.echo_next and not run.echo:
		var a := {"at": origin, "face": face, "shape": &"line", "reach": m.distance, "width": m.shot_width}
		_schedule(r.data.lord.echo_delay, _echo_run(run), a, "shot")


func _step_shots(dt: float) -> void:
	var lim := Vector2(Grid.size)
	for p in r.projectiles.duplicate():
		p.age += dt
		var step: float = p.speed * dt
		var done: bool = false
		if p.returning:
			var to: Vector2 = r.lord.pos - p.pos
			if to.length() <= step + 0.3:
				p.pos = r.lord.pos
				done = true
			else:
				p.dir = to.normalized()
				p.pos += p.dir * step
		else:
			p.pos += p.dir * step
			p.travelled += step
		_shot_hits(p)
		if not p.returning and p.travelled >= p.distance - EPS:
			if p.kind == &"boomerang":
				p.returning = true
				p.hit_ids.clear()
			else:
				done = true
		if p.kind != &"boomerang" and (p.pos.x < -1.0 or p.pos.y < -1.0 or p.pos.x > lim.x + 1.0 or p.pos.y > lim.y + 1.0):
			done = true
		if p.age >= p.max_time:
			done = true
		if done:
			_end_shot(p)


func _shot_hits(p: Projectile) -> void:
	# 검기·던진 칼이 지나간 길의 적의 화살은 부러진다
	for q in r.enemy_projectiles.duplicate():
		if _seg_dist(q.pos, p.prev_pos, p.pos) <= (p.width + q.width) / 2.0:
			r.foes.cut_arrow(q)
	var hits: Array[Enemy] = []
	for e in r.enemies:
		if e.dead or p.hit_ids.has(e.id):
			continue
		if _seg_dist(e.pos, p.prev_pos, p.pos) <= p.width / 2.0 + e.radius:
			hits.append(e)
	if hits.is_empty():
		return
	for e in hits:
		p.hit_ids[e.id] = true
	var a := {"at": p.pos, "face": p.dir.angle(), "mult": p.run.move.damage, "minor": true, "knock_dir": p.dir}
	_deal(p.run, hits, a)


func _end_shot(p: Projectile) -> void:
	r.projectiles.erase(p)
	r.projectile_ended.emit(p)
	_after(p.run)


# ---------------------------------------------------------------- 판정

func _arc(run: MoveRun, at: Vector2, face: float, m: MoveData) -> Dictionary:
	var arc: float = deg_to_rad(m.arc_deg) if m.arc_deg > 0.0 else run.st.arc * m.arc
	return _arc_raw(run, at, face, run.st.reach * m.reach, minf(arc, TAU), m.damage)


func _arc_raw(_run: MoveRun, at: Vector2, face: float, reach: float, arc: float, mult: float) -> Dictionary:
	return {"shape": &"arc", "at": at, "face": face, "reach": reach, "arc": arc, "mult": mult}


func _line(_run: MoveRun, at: Vector2, face: float, length: float, width: float, mult: float) -> Dictionary:
	return {"shape": &"line", "at": at, "face": face, "reach": length, "width": width, "mult": mult}


func _circle(run: MoveRun, at: Vector2, radius: float, mult: float) -> Dictionary:
	return {"shape": &"circle", "at": at, "face": run.face, "radius": radius, "mult": mult}


func _radius(run: MoveRun, m: MoveData) -> float:
	return run.st.reach * m.radius_reach if m.radius_reach > 0.0 else m.radius


## 판정 하나: 모양 안의 적을 찾아 화면에 알리고(필요하면) 벤다.
func _fire(run: MoveRun, a: Dictionary) -> Array[Enemy]:
	var hits := _find(run, a)
	_cut_arrows(run, a)
	if run.echo or bool(a.get("emit", false)):
		var info := _info(run, a)
		info["hits"] = hits.size()
		r.move_area.emit(run.move.id, info)
	_deal(run, hits, a)
	if run.echo_next and not run.echo and a.get("shape") != &"path":
		_schedule(r.data.lord.echo_delay, _echo_run(run), a.duplicate())
	if bool(a.get("main", false)):
		_after(run)
	return hits


## 메아리는 동작마다 하나(처음 다시 울릴 때 move_started를 한 번 보낸다).
func _echo_run(run: MoveRun) -> MoveRun:
	if run.echo_run == null:
		run.echo_run = run.echo_copy(r.data.lord.echo_damage)
	return run.echo_run


func _find(run: MoveRun, a: Dictionary) -> Array[Enemy]:
	var out: Array[Enemy] = []
	var at: Vector2 = a.at
	var face: float = float(a.get("face", run.face))
	var shape: StringName = a.shape
	var once: bool = bool(a.get("once", false))
	for e in r.enemies:
		if e.dead or (once and run.seen.has(e.id)):
			continue
		if covers(a, face, e.pos, e.radius):
			out.append(e)
	out.sort_custom(func(x: Enemy, y: Enemy) -> bool: return x.pos.distance_squared_to(at) < y.pos.distance_squared_to(at))
	var pierce: int = int(run.st.get("pierce", 0))
	if shape == &"arc" and pierce > 0 and out.size() > pierce:
		out.resize(pierce)
	if once:
		for e in out:
			run.seen[e.id] = true
	return out


## 판정 모양 a(face 쪽)가 p에 선 크기 rad의 것에 닿는지. 적과 적의 화살(11단계)이 같이 쓴다.
func covers(a: Dictionary, face: float, p: Vector2, rad: float) -> bool:
	var at: Vector2 = a.at
	var close: float = r.data.lord.close_hit
	var d: float = p.distance_to(at)
	match a.shape:
		&"arc":
			return d <= float(a.reach) + rad and (absf(angle_difference(face, (p - at).angle())) <= float(a.arc) / 2.0 or d <= rad + close)
		&"line":
			return _in_line_p(p, rad, at, face, float(a.reach), float(a.width)) or d <= rad + close
		&"plus":
			var dir := Vector2.from_angle(face)
			var side := dir.orthogonal()
			var half: float = float(a.cross) / 2.0
			var mid: Vector2 = at + dir * float(a.reach) / 2.0
			return _in_line_p(p, rad, at, face, float(a.reach), float(a.width)) or _in_line_p(p, rad, mid - side * half, side.angle(), float(a.cross), float(a.width)) or d <= rad + close
		&"circle":
			return d <= float(a.radius) + rad
		&"ring":
			return absf(d - float(a.radius)) <= float(a.thick) / 2.0 + rad
		&"path":
			return _seg_dist(p, a.from, a.to) <= float(a.width) + rad
	return false


## 판정에 닿은 적의 화살(Rules.enemy_projectiles)을 부러뜨린다.
func _cut_arrows(run: MoveRun, a: Dictionary) -> void:
	if r.enemy_projectiles.is_empty():
		return
	var face: float = float(a.get("face", run.face))
	for p in r.enemy_projectiles.duplicate():
		if covers(a, face, p.pos, p.width / 2.0) or covers(a, face, p.prev_pos, p.width / 2.0):
			r.foes.cut_arrow(p)


func _in_line(e: Enemy, at: Vector2, face: float, length: float, width: float) -> bool:
	return _in_line_p(e.pos, e.radius, at, face, length, width)


static func _in_line_p(p: Vector2, rad: float, at: Vector2, face: float, length: float, width: float) -> bool:
	var dir := Vector2.from_angle(face)
	var to: Vector2 = p - at
	var along: float = to.dot(dir)
	return along >= -rad and along <= length + rad and absf(to.cross(dir)) <= width / 2.0 + rad


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var l2: float = ab.length_squared()
	if l2 < 0.000001:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


## 벤다: 적마다 Powers.strike → Rules.hurt → Powers.after_strike → 속성. 맞힌 게 있으면 히트스톱과 내구.
func _deal(run: MoveRun, hits: Array[Enemy], a: Dictionary) -> void:
	if hits.is_empty():
		return
	var D := r.data.lord
	var P := r.powers
	var at: Vector2 = a.at
	var face: float = float(a.get("face", run.face))
	var dmg: float = run.base * float(a.get("mult", 1.0)) * P.crowd_mult(hits.size())
	var knock: float = run.knock * run.move.knock * (D.big_knockback_mult if run.big else 1.0)
	var pull_to: float = float(a.get("pull_to", 0.0))
	var shape: StringName = a.get("shape", &"")
	var n: int = 0
	for e in hits:
		var dir: Vector2
		if a.has("knock_dir"):
			dir = a.knock_dir
		elif shape == &"line" or shape == &"plus":
			dir = Vector2.from_angle(face)
		else:
			dir = e.pos - (r.lord.pos if shape == &"path" else at)
			dir = dir / dir.length() if dir.length() > 0.001 else Vector2.from_angle(face)
		var kv: Vector2 = dir * knock
		if pull_to > 0.0:
			# 영주 앞으로 끌어온다. 같은 자리에 겹치지 않게 순서대로 조금씩 띄운다
			var to: Vector2 = e.pos - r.lord.pos
			var toward: Vector2 = to.normalized() if to.length() > 0.001 else Vector2.from_angle(face)
			e.pos = _clamp(r.lord.pos + toward * (pull_to + e.radius * 0.5 + 0.05 * n))
			e.push = Vector2.ZERO
			kv = Vector2.ZERO
			n += 1
		var res: Dictionary = P.strike(e, dmg, kv)
		r.hurt(e, res.dmg, res.knock, run.big)
		P.after_strike(e, res.dmg, dmg)
		_element(run, e, res.dmg)
		var stun: float = float(a.get("stun", 0.0))
		if stun > 0.0 and not e.dead:
			e.stun = maxf(e.stun, stun)
		if not run.hits.has(e):
			run.hits.append(e)
	var minor: bool = bool(a.get("minor", false))
	var stop: float = D.hitstop_big if run.big and not minor else D.hitstop
	if r.duel:
		stop = r.data.duel.hitstop_big if run.big and not minor else r.data.duel.hitstop
	if not minor and not r.duel:   # 결투는 예전 히트스톱 그대로(두 사람의 리듬이 바뀌지 않게)
		for e in hits:
			if e.dead:
				# 쓰러뜨린 베기는 더 길게 멈춘다. 정예·보스(우두머리 포함)는 가장 길게
				var big_foe: bool = e.elite or e.chief != &"" or (e.data != null and e.data.boss)
				stop = maxf(stop, D.hitstop_elite_kill if big_foe else D.hitstop_kill)
	r.freeze = maxi(r.freeze, roundi(stop / r.dt))
	_wear(run)


## 내구: 동작마다 한 번. 휘두른 검이 아직 쥔 검일 때만(예전 _swing과 같다).
func _wear(run: MoveRun) -> void:
	if run.wore or run.echo:
		return
	var s := run.sword
	if s and s == r.current() and s.breakable() and r.powers.wears():
		run.wore = true
		s.durability -= 1.0
		if s.durability <= 0.0:
			r.break_slot(r.active)


## 동작 하나가 다 벤 뒤(동작마다 한 번): Powers.after_swing.
func _after(run: MoveRun) -> void:
	if run.swung or run.echo:
		return
	run.swung = true
	r.powers.after_swing(run.hits, run.st, run.base * run.move.damage, run.big)


## 속성(docs/attacks.md 2절). d: 이 적에게 들어간 피해.
func _element(run: MoveRun, e: Enemy, d: float) -> void:
	var D := r.data.lord
	match run.element:
		&"fire":
			if not e.dead:
				e.burn = maxf(e.burn, D.fire_burn)
		&"ice":
			if not e.dead:
				r.powers._slow(e, D.ice_slow, D.ice_slow_time)
				e.ice_hits += 1
				if e.ice_hits >= D.ice_freeze_hits:
					e.ice_hits = 0
					e.frozen = true
					e.stun = maxf(e.stun, D.ice_freeze_time)
		&"bolt":
			for o in r.powers._nearest(e.pos, D.bolt_range, D.bolt_count, e):
				r.powers._zap(e.pos, o, d * D.bolt_damage)
		&"blood":
			if not e.dead and D.blood_bleed_time > 0.0:
				e.bleed = maxf(e.bleed, d * D.blood_bleed / D.blood_bleed_time)
				e.bleed_t = maxf(e.bleed_t, D.blood_bleed_time)
			r.powers.heal(d * D.blood_heal)


# ---------------------------------------------------------------- 알리기

## 동작 시작을 화면에 알린다(LordState.move…도 채운다).
func _started(run: MoveRun, a: Dictionary, extra: Dictionary = {}) -> void:
	var info := _info(run, a)
	info.merge(extra, true)
	if run.from != run.to and not info.has("from"):
		info["from"] = run.from
		info["to"] = run.to
	_set_move(run, info)
	r.move_started.emit(run.move.id, info)


func _set_move(run: MoveRun, info: Dictionary) -> void:
	var L := r.lord
	_move_run = run
	_move_t0 = _clock
	L.move = run.move.id
	L.move_t = 0.0
	L.move_time = float(info.get("time", run.move.time))
	L.move_lock = maxf(L.move_lock, run.move.lock)
	L.move_from = info.get("from", L.pos)
	L.move_to = info.get("to", L.pos)


func _announce_echo(run: MoveRun, a: Dictionary) -> void:
	var info := _info(run, a)
	r.move_started.emit(run.move.id, info)


func _info(run: MoveRun, a: Dictionary) -> Dictionary:
	var info := {
		"at": a.get("at", r.lord.pos), "face": float(a.get("face", run.face)), "shape": a.get("shape", &"arc"),
		"big": run.big, "element": run.element, "step": run.step, "steps": run.steps,
		"time": run.move.time, "echo": run.echo,
	}
	for k in ["reach", "arc", "width", "radius", "thick", "cross", "from", "to", "delay"]:
		if a.has(k):
			info[k] = a[k]
	return info


# ---------------------------------------------------------------- 도움

## 앞 cone(라디안, 전체 폭)·range칸 안의 가장 가까운 적.
func _seek(at: Vector2, face: float, range_cells: float, cone: float) -> Enemy:
	var best: Enemy = null
	var bd: float = INF
	for e in r.enemies:
		if e.dead:
			continue
		var to: Vector2 = e.pos - at
		var d: float = to.length()
		if d > range_cells + e.radius or d < 0.001:
			continue
		if absf(angle_difference(face, to.angle())) > cone / 2.0:
			continue
		if d < bd - EPS:
			bd = d
			best = e
	return best


func _clamp(p: Vector2) -> Vector2:
	return p.clamp(Vector2(0.5, 0.5), Vector2(Grid.size) - Vector2(0.5, 0.5))
