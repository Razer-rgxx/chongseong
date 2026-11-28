class_name CyberPowers
extends RefCounted
## 사이버 검의 새 능력 14가지(docs/cyber_swords.md). Powers가 하나 들고, 휘두르기·맞히기·쓰러뜨리기·틱 자리에서 부른다.
## 쥔 검의 SwordData.cyber_powers에 이름이 있을 때만 듣는다(결투에서 Powers.off면 아무것도 안 듣는다).
## 랜덤은 쓰지 않는다: 세는 값(몇 번째)과 시간만으로 결정된다. 수치는 PowerTable.cyber, 피해 배수는 등급(0~5)마다 +12%.
## 날아가는 탄은 Rules.projectiles(종류 bullet)를 쓰고 Moves.shoot_bullet이 만든다. 화면에는 Rules.effect(cy_shot·cy_blast·cy_rail·cy_blink)로 알린다.

var r: Rules
var P: Powers
var T: PowerTable
## 과열: 적 id → {n, t}
var heat: Dictionary = {}
var hit_n: int = 0
var swing_n: int = 0
var kill_n: int = 0
var clock_stacks: int = 0
var clock_t: float = 0.0
var blink_cd: float = 0.0
## 연사로 곧 나갈 탄: {t, face}
var shots: Array[Dictionary] = []
## 플라즈마가 남은 자리: {pos, t}
var trails: Array[Dictionary] = []


func _init(powers: Powers) -> void:
	P = powers
	r = powers.r
	T = powers.T


func clear() -> void:
	heat.clear()
	shots.clear()
	trails.clear()
	hit_n = 0
	swing_n = 0
	kill_n = 0
	clock_stacks = 0
	clock_t = 0.0
	blink_cd = 0.0


## 지금 쥔 검에 이 능력이 있는가.
func has(name: String) -> bool:
	if P.off:
		return false
	var s := r.current()
	return s != null and s.data.cyber and s.data.cyber_powers.has(name)


## 쥔 검 등급에 따른 피해 배수(흔함 ×1 … 무한 ×1.6).
func scale() -> float:
	var s := r.current()
	return 1.0 + T.cyber_grade_scale * (s.grade if s else 0)


# ---------------------------------------------------------------- 불러올 자리

## 공격 속도 배수(오버클럭).
func speed_mult() -> float:
	if clock_stacks > 0 and has("오버클럭"):
		return 1.0 + T.cy("오버클럭", "step") * clock_stacks
	return 1.0


## 한 적에게 들어갈 피해 배수(조준: 체력이 거의 가득한 적).
func strike_mult(e: Enemy) -> float:
	if has("조준") and e.hp >= e.max_hp * T.cy("조준", "hp"):
		return 1.0 + (T.cy("조준", "mult") - 1.0) * scale()
	return 1.0


## 동작 하나가 다 벤 뒤(Powers.after_swing 끝). dmg: 이 동작의 피해, big: 큰 베기(마무리).
func on_swing(st: Dictionary, dmg: float, big: bool) -> void:
	var s := r.current()
	if P.off or s == null or not s.data.cyber:
		return
	var L := r.lord
	var f: Vector2 = Vector2.from_angle(L.face)
	var sc: float = scale()
	if has("플라즈마 칼날"):
		for k in [0.45, 0.8]:
			if trails.size() < int(T.cy("플라즈마 칼날", "max")):
				trails.append({"pos": L.pos + f * float(st.reach) * k, "t": T.cy("플라즈마 칼날", "time")})
	if has("탄창"):
		swing_n += 1
		if swing_n % int(T.cy("탄창", "every")) == 0:
			_bullet("탄창", L.face, T.cy("탄창", "mult") * sc)
	if has("연사") and not big:
		for i in int(T.cy("연사", "count")):
			shots.append({"t": T.cy("연사", "gap") * float(i + 1), "face": L.face})
	if not big:
		return
	if has("레일"):
		_rail(L.pos, L.face, dmg * T.cy("레일", "mult") * sc)
	if has("산탄"):
		var arc: float = T.cy("산탄", "arc")
		var reach: float = T.cy("산탄", "reach")
		for e in P._in_arc(L.pos, L.face, reach, arc):
			r.hurt(e, dmg * T.cy("산탄", "mult") * sc, (e.pos - L.pos).normalized() * T.cy("산탄", "knock"), false)
		r.effect.emit(&"cy_blast", L.pos, {"face": L.face, "reach": reach, "arc": arc})
	if has("관통탄"):
		_bullet("관통탄", L.face, T.cy("관통탄", "mult") * sc)
	if has("EMP"):
		var rad: float = T.cy("EMP", "radius")
		for e in r.enemies:
			if e.dead or e.data.still or e.pos.distance_to(L.pos) > rad + e.radius:
				continue
			if e.data.future:
				e.stun = maxf(e.stun, T.cy("EMP", "stun"))
			else:
				P._slow(e, T.cy("EMP", "slow"), T.cy("EMP", "slow_t"))
		r.effect.emit(&"ring", L.pos, {"radius": rad, "color": Color(0.35, 0.85, 0.95)})
	if has("반동 돌진"):
		_bullet("반동 돌진", L.face, T.cy("반동 돌진", "mult") * sc)
		L.push -= f * T.cy("반동 돌진", "push")
	if has("글리치 순간베기") and blink_cd <= 0.0:
		_blink(dmg * T.cy("글리치 순간베기", "mult") * sc)


## 적 하나를 맞힌 뒤(Powers.after_strike). d: 들어간 피해, base: 휘두르기의 피해.
func on_hit(e: Enemy, d: float, base: float) -> void:
	if P.off:
		return
	if has("과열") and not e.dead:
		var h: Dictionary = heat.get(e.id, {"n": 0, "t": 0.0})
		h.n = int(h.n) + 1
		h.t = T.cy("과열", "keep")
		heat[e.id] = h
		if int(h.n) >= int(T.cy("과열", "stacks")):
			heat.erase(e.id)
			var rad: float = T.cy("과열", "radius")
			r.effect.emit(&"ring", e.pos, {"radius": rad, "color": Color(1.0, 0.55, 0.3)})
			for o in r.enemies.duplicate():
				if not o.dead and o.pos.distance_to(e.pos) <= rad + o.radius:
					r.hurt(o, base * T.cy("과열", "mult") * scale(), Vector2.ZERO, false)
					if not o.dead:
						o.burn = maxf(o.burn, T.cy("과열", "burn"))
	if has("해킹") and not e.dead and not e.data.boss:
		hit_n += 1
		if hit_n % int(T.cy("해킹", "every")) == 0:
			e.confused = maxf(e.confused, T.cy("해킹", "time"))
			r.effect.emit(&"cy_blink", e.pos, {"to": e.pos})


func on_kill(e: Enemy) -> void:
	heat.erase(e.id)
	if has("오버클럭"):
		clock_stacks = mini(int(T.cy("오버클럭", "max")), clock_stacks + 1)
		clock_t = T.cy("오버클럭", "time")
	if has("방벽"):
		kill_n += 1
		if kill_n % int(T.cy("방벽", "every")) == 0:
			P.shield = minf(T.cy("방벽", "max"), P.shield + T.cy("방벽", "shield") * scale())
			r.effect.emit(&"ring", r.lord.pos, {"radius": 1.4, "color": Color(0.35, 0.85, 0.95)})


## 매 틱(밤 동안).
func tick(dt: float) -> void:
	blink_cd -= dt
	if clock_stacks > 0:
		clock_t -= dt
		if clock_t <= 0.0:
			clock_stacks = 0
	for id in heat.keys():
		heat[id].t -= dt
		if heat[id].t <= 0.0:
			heat.erase(id)
	for sh in shots.duplicate():
		sh.t -= dt
		if sh.t > 0.0:
			continue
		shots.erase(sh)
		if has("연사"):
			_bullet("연사", float(sh.face), T.cy("연사", "mult") * scale())
	for tr in trails.duplicate():
		tr.t -= dt
		if tr.t <= 0.0:
			trails.erase(tr)
			continue
		if not has("플라즈마 칼날"):
			continue
		var rad: float = T.cy("플라즈마 칼날", "radius")
		for e in r.enemies:
			if not e.dead and e.pos.distance_to(tr.pos) <= rad + e.radius:
				e.burn = maxf(e.burn, T.cy("플라즈마 칼날", "burn"))


func hash_parts() -> Array:
	var out: Array = [hit_n, swing_n, kill_n, clock_stacks, clock_t, blink_cd, heat.size(), shots.size(), trails.size()]
	for id in heat:
		out.append_array([id, heat[id].n])
	for sh in shots:
		out.append(sh.t)
	for tr in trails:
		out.append_array([tr.pos, tr.t])
	return out


# ---------------------------------------------------------------- 도움

func _bullet(name: String, face: float, mult: float) -> void:
	var L := r.lord
	var origin: Vector2 = L.pos + Vector2.from_angle(face) * 0.8
	r.moves.shoot_bullet(origin, face, mult, T.cy(name, "speed"), T.cy(name, "width"), T.cy(name, "dist"))
	r.effect.emit(&"cy_shot", origin, {"face": face})


func _rail(from: Vector2, face: float, dmg: float) -> void:
	var f: Vector2 = Vector2.from_angle(face)
	var to: Vector2 = from + f * T.cy("레일", "reach")
	for e in r.enemies.duplicate():
		if e.dead:
			continue
		if Moves._seg_dist(e.pos, from, to) <= T.cy("레일", "width") / 2.0 + e.radius:
			r.hurt(e, dmg, f * 1.0, true)
	r.effect.emit(&"cy_rail", from, {"to": to})


func _blink(dmg: float) -> void:
	var L := r.lord
	var best: Enemy = null
	var bd: float = T.cy("글리치 순간베기", "range")
	for e in r.enemies:
		if e.dead or e.data.still:
			continue
		var d: float = e.pos.distance_to(L.pos)
		if d < bd:
			bd = d
			best = e
	if best == null:
		return
	blink_cd = T.cy("글리치 순간베기", "cd")
	var dir: Vector2 = (best.pos - L.pos).normalized() if bd > 0.001 else Vector2.from_angle(L.face)
	var from: Vector2 = L.pos
	var to: Vector2 = (best.pos + dir * T.cy("글리치 순간베기", "behind")).clamp(Vector2(0.5, 0.5), Vector2(Grid.size) - Vector2(0.5, 0.5))
	L.pos = to
	L.prev_pos = to
	L.face = (best.pos - to).angle()
	r.hurt(best, dmg, dir, true)
	r.effect.emit(&"cy_blink", from, {"to": to})
