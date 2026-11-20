class_name Uniques
extends RefCounted
## 7단계 남은 고유 능력 8종이 만드는 것들(Powers가 하나 들고, 부른다). 결정적이다(랜덤은 Rules.rng만).
## 정한 것:
##  - 아군(allies)은 Enemy가 아니라 Dictionary다: Rules.enemies에 들지 않아 적의 표·영주 노림·승패·쓰러뜨린 수에 끼지 않는다.
##    적은 아군을 때리지도 노리지도 않는다(아군은 다치지 않고 수명(초)으로 사라진다). 종류: wraith(망령), shadow(그림자), knight(기사).
##    망령·그림자는 가까운 적에게 가서 때리고, 적이 없으면 영주 곁을 따른다. 기사는 영주 곁을 돌며 영주의 베기마다 따라 벤다.
##  - 벽(walls)은 선분(a, b)과 굵기(radius)다. 적은 틱 끝에 선분 안으로 못 들어오게 밀려난다(37단계 Nav와 따로, 영주는 막지 않는다).
##    쇠말뚝은 길이 0(기둥), 언덕을 쌓은 검은 영주 앞을 가로지르는 선이다.
##  - 날아가는 칼(blades)은 돌진할 때 나가 가고(맞힌 적 기록) 돌아오며(다시 한 번) 벤다.
##  - 운명 베기: 낮에 뽑은 검을 내구 30을 써서 버리고 등급을 다시 굴려 다시 뽑는다(낮마다 3번). Rules.fate_reroll().
## 수치는 data/powers.tres(PowerTable)의 고유 능력 칸과 "아군_*" 줄.

var r: Rules
var P: Powers
var T: PowerTable
## 아군: {id, kind, pos, face, t(남은 초, -1은 끝없음), cd, mult, slot}
var allies: Array[Dictionary] = []
## 벽: {a, b, radius, t, time, kind}
var walls: Array[Dictionary] = []
## 날아가는 칼: {pos, prev, dir, going, travelled, age, hit}
var blades: Array[Dictionary] = []
## 운명 베기: 오늘 남은 횟수와 가장 최근에 뽑은 검.
var fate_left: int = 3
var last_pulled: Sword = null
var _next: int = 1


func _init(powers: Powers) -> void:
	P = powers
	r = powers.r
	T = powers.T
	fate_left = int(T.u("운명 베기", "per_day"))


func clear() -> void:
	allies.clear()
	walls.clear()
	blades.clear()


func on_night_start() -> void:
	clear()
	fate_left = int(T.u("운명 베기", "per_day"))


# ---------------------------------------------------------------- 불러올 자리

## 큰 베기든 아니든 동작이 다 벤 뒤. dmg: 이 동작의 피해, st: 휘두르기 수치.
func on_swing(dmg: float, st: Dictionary, big: bool) -> void:
	var L := r.lord
	if P.using("천 명의 기사"):
		for k in allies:
			if k.kind == &"knight":
				for e in P._in_arc(k.pos, L.face, T.u("천 명의 기사", "reach"), T.u("천 명의 기사", "arc")):
					r.hurt(e, dmg * T.u("천 명의 기사", "mult"), Vector2.ZERO, false)
				r.effect.emit(&"echo", k.pos, {"face": L.face, "reach": T.u("천 명의 기사", "reach"), "arc": T.u("천 명의 기사", "arc")})
	if not big:
		return
	var f: Vector2 = Vector2.from_angle(L.face)
	if P.using("쇠말뚝"):
		var at: Vector2 = _in_arena(L.pos + f * T.u("쇠말뚝", "ahead"))
		_wall(at, at, T.u("쇠말뚝", "radius"), T.u("쇠말뚝", "time"), &"stake", int(T.u("쇠말뚝", "max")))
	if P.using("언덕을 쌓은 검"):
		var c: Vector2 = _in_arena(L.pos + f * T.u("언덕을 쌓은 검", "ahead"))
		var side: Vector2 = f.orthogonal() * T.u("언덕을 쌓은 검", "half")
		_wall(c - side, c + side, T.u("언덕을 쌓은 검", "radius"), T.u("언덕을 쌓은 검", "time"), &"mound", int(T.u("언덕을 쌓은 검", "max")))


func on_kill(e: Enemy) -> void:
	if e.data.still:
		return
	if P.using("망자들의 왕관"):
		_raise(e.pos, &"wraith", T.u("망자들의 왕관", "time"), T.u("망자들의 왕관", "mult"), int(T.u("망자들의 왕관", "max")))
	elif P.using("무덤 파수") and r.rng.randf() < T.u("무덤 파수", "chance"):
		_raise(e.pos, &"wraith", T.u("무덤 파수", "time"), T.u("무덤 파수", "mult"), int(T.u("무덤 파수", "max")))


func on_dash() -> void:
	var L := r.lord
	if P.using("그림자 왕"):
		_raise(L.pos, &"shadow", T.u("그림자 왕", "time"), T.u("그림자 왕", "mult"), int(T.u("그림자 왕", "max")), true)
	if P.using("되돌아오는 칼") and blades.size() < int(T.u("되돌아오는 칼", "max")):
		blades.append({"pos": L.pos, "prev": L.pos, "dir": L.dash_dir.normalized() if L.dash_dir.length() > 0.001 else Vector2.from_angle(L.face),
				"going": true, "travelled": 0.0, "age": 0.0, "hit": {}})
		r.effect.emit(&"ring", L.pos, {"radius": 0.7, "color": Color(0.8, 0.9, 1.0)})


# ---------------------------------------------------------------- 매 틱 (밤)

func tick(dt: float) -> void:
	var L := r.lord
	_keep_knights()
	for w in walls.duplicate():
		w.t -= dt
		if w.t <= 0.0:
			walls.erase(w)
	for a in allies.duplicate():
		if a.t > 0.0:
			a.t -= dt
			if a.t <= 0.0:
				allies.erase(a)
				continue
		a.cd -= dt
		if a.kind == &"knight":
			_follow(a, _knight_spot(a), T.i("아군_속도") * 2.0, dt, 0.05)
			continue
		var foe: Enemy = _foe(a)
		if foe == null:
			_follow(a, L.pos, T.i("아군_속도"), dt, T.i("아군_곁"))
		elif a.pos.distance_to(foe.pos) > T.i("아군_사거리") + foe.radius:
			_follow(a, foe.pos, T.i("아군_속도"), dt, 0.0)
		else:
			a.face = (foe.pos - a.pos).angle()
			if a.cd <= 0.0:
				a.cd = T.i("아군_주기")
				r.effect.emit(&"echo", a.pos, {"face": a.face, "reach": T.i("아군_사거리"), "arc": 1.6})
				r.hurt(foe, P.stats().dmg * a.mult, Vector2.ZERO, false)
	_step_blades(dt)


func _foe(a: Dictionary) -> Enemy:
	var best: Enemy = null
	var bd: float = T.i("아군_탐색") * T.i("아군_탐색")
	for e in r.enemies:
		if e.dead or e.seat >= 0:
			continue
		var d: float = e.pos.distance_squared_to(a.pos)
		if d < bd:
			bd = d
			best = e
	return best


func _follow(a: Dictionary, to: Vector2, speed: float, dt: float, stop: float) -> void:
	var v: Vector2 = to - a.pos
	var d: float = v.length()
	if d <= stop + 0.001:
		return
	a.face = v.angle()
	a.pos = _in_arena(a.pos + v / d * minf(d - stop, speed * dt))


func _knight_spot(a: Dictionary) -> Vector2:
	var n: int = int(T.u("천 명의 기사", "count"))
	var ang: float = r.lord.face + PI + (float(a.slot) - float(n - 1) / 2.0) * 0.9
	return r.lord.pos + Vector2.from_angle(ang) * T.u("천 명의 기사", "ring")


## 천 명의 기사를 쥔 동안 기사가 모자라면 영주 곁에서 일어서고, 안 쥐면 사라진다.
func _keep_knights() -> void:
	var have: Array[int] = []
	for a in allies.duplicate():
		if a.kind == &"knight":
			if not P.using("천 명의 기사"):
				allies.erase(a)
			else:
				have.append(int(a.slot))
	if not P.using("천 명의 기사"):
		return
	for k in int(T.u("천 명의 기사", "count")):
		if not have.has(k):
			_add({"kind": &"knight", "pos": r.lord.pos, "t": -1.0, "mult": T.u("천 명의 기사", "mult"), "slot": k})
			r.effect.emit(&"ring", r.lord.pos, {"radius": 0.8, "color": Color(0.55, 0.75, 1.0)})


func _step_blades(dt: float) -> void:
	var L := r.lord
	var W: String = "되돌아오는 칼"
	for b in blades.duplicate():
		b.age += dt
		b.prev = b.pos
		var step: float = T.u(W, "speed") * dt
		if b.going:
			b.pos += b.dir * step
			b.travelled += step
		else:
			var to: Vector2 = L.pos - b.pos
			if to.length() <= step + 0.3:
				blades.erase(b)
				continue
			b.dir = to.normalized()
			b.pos += b.dir * step
		var d: float = P.stats().dmg * T.u(W, "mult")
		for e in r.enemies.duplicate():
			if e.dead or b.hit.has(e.id):
				continue
			if _seg_dist(e.pos, b.prev, b.pos) <= T.u(W, "width") / 2.0 + e.radius:
				b.hit[e.id] = true
				r.hurt(e, d, b.dir * 0.5, false)
		if b.going and b.travelled >= T.u(W, "dist"):
			b.going = false
			b.hit.clear()
		if b.age >= T.u(W, "max_time"):
			blades.erase(b)


# ---------------------------------------------------------------- 벽

## 적 하나를 벽 밖으로 민다(Rules가 틱 끝에 부른다).
func push(e: Enemy) -> void:
	for w in walls:
		var q: Vector2 = _closest(e.pos, w.a, w.b)
		var v: Vector2 = e.pos - q
		var m: float = w.radius + e.radius
		var d: float = v.length()
		if d >= m:
			continue
		var out: Vector2 = v / d if d > 0.0001 else (e.pos - r.lord.pos).normalized()
		if out.length() < 0.5:
			out = Vector2.DOWN
		e.pos = q + out * m


func _wall(a: Vector2, b: Vector2, radius: float, time: float, kind: StringName, max_n: int) -> void:
	var mine: Array[Dictionary] = []
	for w in walls:
		if w.kind == kind:
			mine.append(w)
	if mine.size() >= max_n:
		walls.erase(mine[0])
	walls.append({"a": a, "b": b, "radius": radius, "t": time, "time": time, "kind": kind})
	r.effect.emit(&"spike", a, {})
	r.effect.emit(&"ring", (a + b) / 2.0, {"radius": maxf(radius, a.distance_to(b) / 2.0 + radius), "color": Color(0.75, 0.8, 0.9)})


# ---------------------------------------------------------------- 아군 만들기

func _raise(at: Vector2, kind: StringName, time: float, mult: float, max_n: int, replace: bool = false) -> void:
	var mine: Array[Dictionary] = []
	for a in allies:
		if a.kind == kind:
			mine.append(a)
	if mine.size() >= max_n:
		if not replace:
			return
		allies.erase(mine[0])
	_add({"kind": kind, "pos": at, "t": time, "mult": mult, "slot": 0})
	r.effect.emit(&"ring", at, {"radius": 0.9, "color": Color(0.5, 0.7, 1.0)})


func _add(a: Dictionary) -> void:
	a["id"] = _next
	_next += 1
	a["cd"] = T.i("아군_주기") * 0.5
	a["face"] = r.lord.face
	allies.append(a)


# ---------------------------------------------------------------- 운명 베기

## 낮에 뽑은 검을 내구 30을 써서 버리고 등급부터 다시 굴려 다시 뽑는다. 된 일이면 true.
func fate_reroll() -> bool:
	var W: String = "운명 베기"
	if r.phase != Rules.Phase.DAY or r.pull_hilt != null or r.altar_open or r.path_open or r.duel:
		return false
	var s: Sword = last_pulled
	if s == null or fate_left <= 0 or not P.holding(W):
		return false
	var cost: float = T.u(W, "cost")
	var holder: Sword = null
	for h in r.slots:
		if h and h != s and h.data.display_name == W and h.breakable() and h.durability > cost:
			holder = h
	if holder == null:
		return false
	if r.pending == s:
		r.pending = null
	elif r.slots.has(s):
		r.slots[r.slots.find(s)] = null
	else:
		return false
	holder.durability -= cost
	fate_left -= 1
	var n := Sword.new(r.pick_sword(r.roll_grade(r.luck())), r.data)
	P.on_pulled(n)
	r.effect.emit(&"ring", r.lord.pos, {"radius": 1.6, "color": Color(0.9, 0.8, 0.5)})
	r.sword_pulled.emit(n)
	r._receive(n)
	return true


# ---------------------------------------------------------------- 상태 해시

func hash_parts() -> Array:
	var out: Array = [fate_left, allies.size(), walls.size(), blades.size()]
	for a in allies:
		out.append_array([a.id, a.kind, a.pos, a.t])
	for w in walls:
		out.append_array([w.a, w.b, w.t])
	for b in blades:
		out.append_array([b.pos, b.going, b.hit.size()])
	return out


# ---------------------------------------------------------------- 도움

func _in_arena(p: Vector2) -> Vector2:
	return p.clamp(Vector2(0.5, 0.5), Vector2(Grid.size) - Vector2(0.5, 0.5))


static func _closest(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab: Vector2 = b - a
	var l2: float = ab.length_squared()
	if l2 < 0.000001:
		return a
	return a + ab * clampf((p - a).dot(ab) / l2, 0.0, 1.0)


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(_closest(p, a, b))
