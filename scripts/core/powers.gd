class_name Powers
extends RefCounted
## 각인 36종과 검의 고유 능력. Rules가 하나 들고 있고, 휘두르기·베기·쓰러뜨리기·맞기·돌진·뽑기·부러짐 때마다 부른다.
## 시험판(prototype/game_reference.js)의 규칙을 옮겼다. 정해진 수치는 data/powers.tres(PowerTable).
## 고유 능력은 검 이름으로 찾는다. using(이름)은 지금 쥔 검, holding(이름)은 두 칸 중 어디든.
## 랜덤은 Rules.rng만 쓴다.

## 고유 능력이 규칙에 들어간 검(이름). 표의 unique_ready와 같아야 한다(테스트가 본다).
const READY: PackedStringArray = [
	"성주의 저울", "백 명의 이름", "백 년 전쟁", "부러지지 않는 맹세", "바람의 왕", "마지막 숨", "핏빛 맹세",
	"처음이자 마지막 칼", "메아리 계곡", "언덕의 심장", "폭풍 부르는 자", "떨어진 검", "굶주린 칼", "상처 세는 자",
	"얼음 무덤", "끝나지 않는 겨울", "거인의 무릎", "끌어당기는 손", "구름 가르는 천둥", "화형대", "꺼지지 않는 불",
	"거인 왕의 뼈", "산 자의 몫", "행운의 녹", "모래시계", "멈춘 순간", "바람 가르는 깃", "무너진 왕좌", "충신",
	"영원한 파수", "두 번째 기회", "새벽 나팔", "피의 왕좌", "쌍칼 서약", "언덕", "첫 번째 왕", "언덕의 첫 검",
	"모든 검의 어머니", "이름을 잃은 검", "마지막 장례", "겨울의 끝", "늪지기", "대화재", "피의 강", "망각",
]

var r: Rules
var T: PowerTable

# ---- 판 동안
## 이 판에서 뽑은 모든 검의 각인 중 가장 큰 값(언덕).
var run_ins: Dictionary = {}
## 판마다 한 번(두 번째 기회).
var run_used: Dictionary = {}
## 다음 뽑기의 운 ×3(행운의 녹).
var luck3: bool = false

# ---- 밤 동안
var night_used: Dictionary = {}
var night_kills: int = 0
var shield: float = 0.0
## 남은 동안 쓰러지지 않는다(영원한 파수).
var undying: float = 0.0
var giant_t: float = 0.0
var oath: int = 0
var starve: float = 0.0
var stop_t: float = 0.0
var stop_cd: float = 0.0
var hit_n: int = 0
var thunder_n: int = 0
var big_n: int = 0
## 바꿔 쥔 뒤 첫 공격(바꿔 쥐기).
var swapped: bool = false
## 돌진 충전(바람 가르는 깃은 2).
var dash_charges: int = 1
var dash_recharge: float = 0.0
## 다음 찌르기가 화면 끝까지(겨울의 끝).
var ice_spear: bool = false
## 늦게 터지는 것들: {kind, t, pos, face, reach, arc, dmg, big, radius}
var pending: Array[Dictionary] = []
## 땅에 남는 자리: {kind(swamp/fire/blood), pos, radius, t}
var zones: Array[Dictionary] = []
var _dash_hit: Dictionary = {}
var _snapshot: Dictionary = {}


func _init(rules: Rules) -> void:
	r = rules
	T = rules.data.powers


# ---------------------------------------------------------------- 묻기

func using(name: String) -> bool:
	var s := r.current()
	return s != null and s.data.display_name == name


func holding(name: String) -> bool:
	for s in r.slots:
		if s and s.data.display_name == name:
			return true
	return false


func king() -> float:
	return T.u("첫 번째 왕", "mult") if holding("첫 번째 왕") else 1.0


## 지금 쥔 검의 각인 값(쌍칼 서약, 언덕, 첫 번째 왕을 반영).
func ins(k: String) -> float:
	var s := r.current()
	if s == null:
		return 0.0
	var v: float = float(s.ins.get(k, 0.0))
	var o := r.slots[1 - r.active]
	if using("쌍칼 서약") and o:
		v = maxf(v, float(o.ins.get(k, 0.0)))
	if using("언덕"):
		v = maxf(v, float(run_ins.get(k, 0.0)))
	return v * king()


## 들고만 있어도 되는 각인(두 칸의 합).
func held(k: String) -> float:
	var v: float = 0.0
	for s in r.slots:
		if s:
			v += float(s.ins.get(k, 0.0))
	return v * king()


func luck_mult() -> float:
	return (1.0 + held("행운") / 100.0) * (T.u("행운의 녹", "luck") if luck3 else 1.0)


func pull_discount() -> float:
	return held("가벼운 손")


# ---------------------------------------------------------------- 휘두르기

## 지금 쥔 검으로 한 번 휘두를 때의 수치. {dmg, spd, reach, arc, pierce}
func stats() -> Dictionary:
	var D := r.data.lord
	var s := r.current()
	var F: FormData = s.form if s else r.data.unarmed
	var g_mult: float = r.data.grades.damage_mult[s.grade] * s.bonus if s else 1.0
	var dmg: float = D.damage * F.damage * g_mult * (1.0 + ins("날") / 100.0)
	if ins("투박함") > 0.0:
		dmg *= T.i("투박함_피해")
	var spd: float = F.speed * (1.0 + ins("가벼움") / 100.0)
	if ins("무거움") > 0.0:
		spd *= T.i("무거움_속도")
	var hp_k: float = clampf(r.lord.hp / r.max_hp(), 0.0, 1.0)
	dmg *= 1.0 + ins("광기") / 100.0 * (1.0 - hp_k)
	if r.phase == Rules.Phase.NIGHT and r.night_left <= T.i("새벽_남은시간"):
		dmg *= 1.0 + ins("새벽") / 100.0 + (T.u("새벽 나팔", "dmg") if night_used.has("horn") else 0.0)
	dmg *= 1.0 + ins("피의 값") / 100.0
	if using("성주의 저울") and hp_k >= T.u("성주의 저울", "hp"):
		dmg *= T.u("성주의 저울", "dmg")
	if using("백 명의 이름"):
		dmg *= 1.0 + minf(T.u("백 명의 이름", "max"), floorf(night_kills / T.u("백 명의 이름", "per")) * T.u("백 명의 이름", "step"))
	if using("백 년 전쟁") and r.phase == Rules.Phase.NIGHT:
		var passed: float = r.data.run.night_length - r.night_left
		dmg *= 1.0 + T.u("백 년 전쟁", "step") * floorf(passed / T.u("백 년 전쟁", "every"))
	if using("부러지지 않는 맹세"):
		dmg *= 1.0 + minf(T.u("부러지지 않는 맹세", "dmg_max"), oath * T.u("부러지지 않는 맹세", "dmg_step"))
		spd *= 1.0 - minf(T.u("부러지지 않는 맹세", "spd_max"), oath * T.u("부러지지 않는 맹세", "spd_step"))
	var reach: float = D.reach * F.reach * (1.0 + ins("긴 날") / 100.0)
	var arc: float = D.arc * F.arc * (1.0 + ins("넓은 날") / 100.0)
	if giant_t > 0.0:
		dmg *= T.u("거인 왕의 뼈", "mult")
		reach *= T.u("거인 왕의 뼈", "mult")
	var pierce: int = F.pierce
	if pierce > 0:
		pierce += int(ins("꿰뚫기"))
	if using("바람의 왕"):
		reach = T.u("바람의 왕", "reach")
		pierce = 0
	if ice_spear:
		reach = maxf(reach, T.u("겨울의 끝", "reach"))
		pierce = 0
	return {"dmg": dmg, "spd": spd, "reach": reach, "arc": minf(arc, TAU), "pierce": pierce, "form": F}


## 큰 베기인지(연타의 마지막, 또는 마지막 숨).
func force_big() -> bool:
	return using("마지막 숨") and r.lord.hp <= r.max_hp() * T.u("마지막 숨", "hp")


## 휘두르기 직전. 체력을 쓰는 각인과 맹세를 센다. 처음이자 마지막 칼이면 true(이번 휘두르기는 그걸로 끝).
func before_swing() -> bool:
	if ins("피의 값") > 0.0 and r.lord.hp > T.i("피의값_체력"):
		r.lord.hp -= T.i("피의값_체력")
	if using("부러지지 않는 맹세"):
		oath += 1
	if using("처음이자 마지막 칼") and r.phase == Rules.Phase.NIGHT and not night_used.has("last"):
		night_used["last"] = true
		for e in r.enemies.duplicate():
			if not e.dead:
				r.hurt(e, e.max_hp * T.u("처음이자 마지막 칼", "boss") if e.data.boss else e.hp + 1.0, Vector2.ZERO, true)
		r.effect.emit(&"flash", r.lord.pos, {"color": Color.WHITE})
		return true
	return false


## 피해에 휘두르기 전체로 붙는 배수(큰 베기, 바꿔 쥐기, 핏빛 맹세).
func swing_damage(dmg: float, big: bool) -> float:
	if big:
		dmg *= (1.0 + ins("무거움") / 100.0) * (1.0 + ins("연격") / 100.0)
	if swapped:
		dmg *= 1.0 + ins("바꿔 쥐기") / 100.0
		swapped = false
	if big and using("핏빛 맹세") and r.lord.hp > T.u("핏빛 맹세", "cost"):
		r.lord.hp -= T.u("핏빛 맹세", "cost")
		dmg *= T.u("핏빛 맹세", "mult")
	return dmg


func crowd_mult(n: int) -> float:
	return 1.0 + ins("무리 베기") / 100.0 if n >= int(T.i("무리베기_수")) else 1.0


func knock_mult() -> float:
	return 1.0 + ins("밀쳐내기") / 100.0


## 벤 뒤에 따라오는 것들(메아리, 언덕의 심장, 폭풍, 떨어진 검). hit: 이번에 벤 적들.
func after_swing(hit: Array[Enemy], st: Dictionary, dmg: float, big: bool) -> void:
	var L := r.lord
	ice_spear = false
	if using("메아리 계곡"):
		pending.append({"kind": "echo", "t": T.u("메아리 계곡", "delay"), "pos": L.pos, "face": L.face, "reach": st.reach, "arc": st.arc, "dmg": dmg, "big": big})
	if using("언덕의 심장"):
		var near: Array[Enemy] = _nearest(L.pos, T.u("언덕의 심장", "range"), int(T.u("언덕의 심장", "count")), null)
		for e in near:
			r.effect.emit(&"spike", e.pos, {})
			r.hurt(e, dmg * T.u("언덕의 심장", "mult"), Vector2.ZERO, false)
	if big and using("폭풍 부르는 자"):
		for e in _in_arc(L.pos, L.face, T.u("폭풍 부르는 자", "reach"), T.u("폭풍 부르는 자", "arc")):
			_zap(L.pos, e, dmg * T.u("폭풍 부르는 자", "mult"))
	if hit.size() > 0:
		starve = 0.0
		if big and using("떨어진 검"):
			big_n += 1
			if big_n % int(T.u("떨어진 검", "every")) == 0:
				var at: Vector2 = L.pos + Vector2.from_angle(L.face) * T.u("떨어진 검", "ahead")
				pending.append({"kind": "fall", "t": T.u("떨어진 검", "delay"), "pos": at, "dmg": dmg * T.u("떨어진 검", "mult"), "radius": T.u("떨어진 검", "radius")})
				r.effect.emit(&"fall_warn", at, {"radius": T.u("떨어진 검", "radius")})
		if using("늪지기"):
			for e in hit:
				_zone(&"swamp", e.pos, T.u("늪지기", "radius"), T.u("늪지기", "time"))
	if using("대화재"):
		_zone(&"fire", L.pos + Vector2.from_angle(L.face) * st.reach * 0.6, T.u("대화재", "radius"), T.u("대화재", "time"))


## 이 휘두르기로 쥔 검의 내구가 닳는지.
func wears() -> bool:
	return not using("굶주린 칼")


# ---------------------------------------------------------------- 한 적을 벨 때

## 적 하나에 들어갈 피해를 고친다(처형, 첫 타, 등 뒤, 거인·망령, 무릎, 얼음…). knock을 바꿀 수 있어 Dictionary로 돌려준다.
func strike(e: Enemy, dmg: float, knock: Vector2) -> Dictionary:
	var L := r.lord
	var d: float = dmg
	if e.hp <= e.max_hp * T.i("처형_체력"):
		d *= 1.0 + ins("처형") / 100.0
	if not e.was_hit:
		d *= 1.0 + ins("첫 타") / 100.0
	var to: Vector2 = e.pos - L.pos
	if to.length() > 0.001 and to.dot(e.face) > T.i("등뒤_내적") * to.length():
		d *= 1.0 + ins("등 뒤") / 100.0
	if e.data.big:
		d *= 1.0 + ins("거인 베기") / 100.0
	if e.data.wraith:
		d *= 1.0 + ins("망령 베기") / 100.0
	if e.vuln > 0.0:
		d *= 2.0
	if using("상처 세는 자") and e.bleed_t > 0.0:
		d += e.bleed * e.bleed_t
		e.bleed_t = 0.0
	if using("얼음 무덤"):
		if e.frozen:
			e.frozen = false
			e.stun = 0.0
			d *= T.u("얼음 무덤", "mult")
			r.effect.emit(&"ring", e.pos, {"radius": T.u("얼음 무덤", "spread"), "color": Color(0.62, 0.9, 1.0)})
			for o in r.enemies:
				if o != e and not o.dead and o.pos.distance_to(e.pos) < T.u("얼음 무덤", "spread"):
					_slow(o, T.u("얼음 무덤", "slow"), T.u("얼음 무덤", "slow_t"))
			if holding("겨울의 끝"):
				ice_spear = true
		elif e.slow_t > 0.0:
			e.frozen = true
			e.stun = maxf(e.stun, T.u("얼음 무덤", "freeze"))
	if using("끝나지 않는 겨울"):
		e.stun = maxf(e.stun, T.u("끝나지 않는 겨울", "freeze"))
	if using("거인의 무릎") and e.data.big:
		e.knee += 1
		if e.knee >= int(T.u("거인의 무릎", "hits")):
			e.knee = 0
			e.vuln = T.u("거인의 무릎", "vuln")
			e.stun = maxf(e.stun, T.u("거인의 무릎", "stun"))
	if ins("출혈") > 0.0:
		e.bleed = ins("출혈") / T.i("출혈_시간")
		e.bleed_t = T.i("출혈_시간")
	if ins("불씨") > 0.0 and r.rng.randf() < ins("불씨") / 100.0:
		e.burn = maxf(e.burn, T.i("불씨_시간"))
	if ins("서리") > 0.0:
		_slow(e, T.i("서리_느림"), ins("서리"))
	if using("끌어당기는 손"):
		e.pos = L.pos + Vector2.from_angle(L.face) * T.u("끌어당기는 손", "dist")
		knock = Vector2.ZERO
	if using("망각"):
		e.confused = T.u("망각", "time")
	return {"dmg": d, "knock": knock}


## 벤 뒤(흡혈, 잔상, 번개, 천둥). d: 이 적에게 들어간 피해, base: 휘두르기의 피해.
func after_strike(e: Enemy, d: float, base: float) -> void:
	heal(d * ins("흡혈") / 100.0)
	if ins("잔상") > 0.0 and not e.dead and r.rng.randf() < ins("잔상") / 100.0:
		r.hurt(e, d, Vector2.ZERO, false)
	if ins("번개") > 0.0:
		hit_n += 1
		if hit_n >= int(ins("번개")):
			hit_n = 0
			for o in _nearest(e.pos, 99.0, int(T.i("번개_대상")), e):
				_zap(e.pos, o, d * T.i("번개_피해"))
	if using("구름 가르는 천둥"):
		thunder_n += 1
		if thunder_n >= int(T.u("구름 가르는 천둥", "every")):
			thunder_n = 0
			var alive: Array[Enemy] = []
			for o in r.enemies:
				if not o.dead:
					alive.append(o)
			alive.sort_custom(func(a: Enemy, b: Enemy) -> bool: return a.hp > b.hp)
			for o in alive.slice(0, int(T.u("구름 가르는 천둥", "count"))):
				_zap(o.pos, o, base * T.u("구름 가르는 천둥", "mult"))


# ---------------------------------------------------------------- 피해와 쓰러뜨림

## 적이 피해를 입을 때(영원한 파수 동안은 준 만큼 체력을 되찾는다).
func on_damage(e: Enemy, d: float) -> void:
	e.was_hit = true
	if undying > 0.0:
		heal(minf(d, maxf(0.0, e.hp)))


func on_kill(e: Enemy) -> void:
	night_kills += 1
	heal(ins("사냥"))
	var s := r.current()
	if s and s.breakable():
		s.durability = minf(s.max_durability, s.durability + ins("숫돌") + (T.u("굶주린 칼", "refill") if using("굶주린 칼") else 0.0))
	if e.burn > 0.0 and (using("화형대") or using("꺼지지 않는 불")):
		var name: String = "화형대" if using("화형대") else "꺼지지 않는 불"
		r.effect.emit(&"ring", e.pos, {"radius": T.u(name, "radius"), "color": Color(1.0, 0.54, 0.24)})
		for o in r.enemies:
			if not o.dead and o.pos.distance_to(e.pos) < T.u(name, "radius"):
				o.burn = maxf(o.burn, T.u(name, "burn"))
	if e.bleed_t > 0.0 and using("피의 강"):
		_zone(&"blood", e.pos, T.u("피의 강", "radius"), T.u("피의 강", "time"))
	if e.data.big and using("거인 왕의 뼈"):
		giant_t = T.u("거인 왕의 뼈", "time")
	if holding("산 자의 몫") and r.rng.randf() < T.u("산 자의 몫", "chance") and r.free_pulls < r.data.run.max_free_pulls:
		r.free_pulls += 1
		r.effect.emit(&"free_pull", r.lord.pos, {})


func heal(v: float) -> void:
	if v <= 0.0 or r.lord.hp <= 0.0:
		return
	var over: float = r.lord.hp + v - r.max_hp()
	r.lord.hp = minf(r.max_hp(), r.lord.hp + v)
	if over > 0.0 and using("피의 왕좌"):
		shield = minf(T.u("피의 왕좌", "max"), shield + over)


## 영주가 맞을 때 받는 피해를 줄인다. attacker는 null일 수 있다.
func lord_damage(d: float, attacker: Enemy) -> float:
	var L := r.lord
	d *= 1.0 - minf(T.i("버팀_상한"), ins("버팀") / 100.0)
	if L.swing > 0.0:
		d *= 1.0 - minf(T.i("막기_상한"), ins("막기") / 100.0)
	if using("성주의 저울") and L.hp < r.max_hp() * T.u("성주의 저울", "hp"):
		d *= T.u("성주의 저울", "taken")
	if using("무너진 왕좌"):
		var n: int = 0
		for o in r.enemies:
			if not o.dead and o.pos.distance_to(L.pos) < T.u("무너진 왕좌", "radius"):
				n += 1
		d *= 1.0 - minf(T.u("무너진 왕좌", "max"), T.u("무너진 왕좌", "step") * n)
	if shield > 0.0:
		var a: float = minf(shield, d)
		shield -= a
		d -= a
	if attacker and ins("가시") > 0.0:
		r.hurt(attacker, ins("가시"), Vector2.ZERO, false)
	return d


## 체력이 0이 됐을 때 버틸 수 있으면 버티고 true. 충신, 영원한 파수, 두 번째 기회.
func save_from_death() -> bool:
	var L := r.lord
	if undying > 0.0:
		L.hp = 1.0
		return true
	for k in 2:
		var s := r.slots[k]
		if s and s.data.display_name == "충신" and not night_used.has("loyal"):
			night_used["loyal"] = true
			L.hp = T.u("충신", "hp")
			L.invuln = T.u("충신", "invuln")
			r.break_slot(k)
			r.effect.emit(&"saved", L.pos, {"by": "충신"})
			return true
	if holding("영원한 파수") and not night_used.has("eternal"):
		night_used["eternal"] = true
		undying = T.u("영원한 파수", "time")
		L.hp = 1.0
		r.effect.emit(&"saved", L.pos, {"by": "영원한 파수"})
		return true
	if holding("두 번째 기회") and not run_used.has("second") and not _snapshot.is_empty():
		run_used["second"] = true
		_restore()
		r.effect.emit(&"saved", L.pos, {"by": "두 번째 기회"})
		return true
	return false


# ---------------------------------------------------------------- 돌진

func dash_cooldown() -> float:
	return r.data.lord.dash_cooldown * (1.0 - minf(T.i("날랜발_상한"), ins("날랜 발") / 100.0))


func max_charges() -> int:
	return int(T.u("바람 가르는 깃", "charges")) if using("바람 가르는 깃") else 1


func on_dash() -> void:
	_dash_hit.clear()
	if using("모래시계"):
		for e in r.enemies:
			if e.pos.distance_to(r.lord.pos) < T.u("모래시계", "radius"):
				_slow(e, T.u("모래시계", "slow"), T.u("모래시계", "time"))
	if using("멈춘 순간") and stop_cd <= 0.0:
		stop_t = T.u("멈춘 순간", "time")
		stop_cd = T.u("멈춘 순간", "cooldown")
		r.effect.emit(&"stop", r.lord.pos, {"time": stop_t})


## 돌진 중 매 틱: 지나간 적을 벤다(돌진 베기).
func dash_tick() -> void:
	var v: float = ins("돌진 베기")
	if v <= 0.0:
		return
	for e in r.enemies:
		if not e.dead and not _dash_hit.has(e.id) and e.pos.distance_to(r.lord.pos) < 0.8 + e.radius:
			_dash_hit[e.id] = true
			r.hurt(e, v, Vector2.ZERO, false)


# ---------------------------------------------------------------- 밤과 낮

func on_night_start() -> void:
	night_used.clear()
	night_kills = 0
	shield = 0.0
	undying = 0.0
	starve = 0.0
	oath = 0
	stop_t = 0.0
	giant_t = 0.0
	pending.clear()
	zones.clear()
	ice_spear = false
	dash_charges = max_charges()
	dash_recharge = 0.0
	_snapshot = {"hp": r.lord.hp, "active": r.active, "slots": [], "kills": r.kills}
	for s in r.slots:
		_snapshot.slots.append([s, s.durability if s else 0.0])


func _restore() -> void:
	var sn := _snapshot
	r.lord.hp = sn.hp
	for k in 2:
		var pair: Array = sn.slots[k]
		r.slots[k] = pair[0]
		if pair[0]:
			(pair[0] as Sword).durability = pair[1]
	r.active = sn.active
	r.enemies.clear()
	r.phase = Rules.Phase.DAY
	r.start_night()
	r.slots_changed.emit()


## 매 틱(낮과 밤 모두). 늦게 터지는 것, 땅의 자리, 타이머.
func tick(dt: float) -> void:
	var L := r.lord
	giant_t -= dt
	stop_cd -= dt
	if stop_t > 0.0:
		stop_t -= dt
	if undying > 0.0:
		undying -= dt
		if undying <= 0.0 and L.hp <= 1.0 and r.phase == Rules.Phase.NIGHT:
			undying = 0.0
			L.hp = 0.0
			r.lord_died()
			return
	if dash_charges < max_charges():
		dash_recharge -= dt
		if dash_recharge <= 0.0:
			dash_charges += 1
			dash_recharge = dash_cooldown()
	if r.phase != Rules.Phase.NIGHT:
		return
	if using("굶주린 칼"):
		starve += dt
		if starve > T.u("굶주린 칼", "starve") and L.hp > 1.0:
			L.hp = maxf(1.0, L.hp - T.u("굶주린 칼", "drain") * dt)
	if holding("새벽 나팔") and not night_used.has("horn") and r.night_left <= T.u("새벽 나팔", "left"):
		night_used["horn"] = true
		L.hp = r.max_hp()
		r.effect.emit(&"flash", L.pos, {"color": Color(1.0, 0.91, 0.66)})
	for p in pending.duplicate():
		p.t -= dt
		if p.t > 0.0:
			continue
		pending.erase(p)
		match p.kind:
			"echo":
				for e in _in_arc(p.pos, p.face, p.reach, p.arc):
					r.hurt(e, p.dmg, Vector2.ZERO, p.big)
				r.effect.emit(&"echo", p.pos, {"face": p.face, "reach": p.reach, "arc": p.arc})
			"fall":
				r.effect.emit(&"fall", p.pos, {"radius": p.radius})
				for e in r.enemies.duplicate():
					if not e.dead and e.pos.distance_to(p.pos) < p.radius + e.radius:
						r.hurt(e, p.dmg, Vector2.ZERO, true)
	for z in zones.duplicate():
		z.t -= dt
		if z.t <= 0.0:
			zones.erase(z)
			continue
		if z.kind == &"blood" and L.pos.distance_to(z.pos) < z.radius:
			heal(T.u("피의 강", "heal") * dt)
		for e in r.enemies:
			if e.dead or e.pos.distance_to(z.pos) > z.radius + e.radius:
				continue
			if z.kind == &"swamp":
				_slow(e, T.u("늪지기", "slow"), 0.2)
			elif z.kind == &"fire":
				e.burn = maxf(e.burn, T.u("대화재", "burn"))


## 적 하나의 상태(출혈, 불, 묶임, 느림)를 한 틱 돌린다. 돌려주는 값은 이번 틱 움직임 배수(0이면 못 움직이고 못 때린다).
func enemy_tick(e: Enemy, dt: float) -> float:
	e.vuln -= dt
	if e.bleed_t > 0.0:
		e.bleed_t -= dt
		r.hurt(e, e.bleed * dt, Vector2.ZERO, false, true)
		if e.dead:
			return 0.0
	if e.burn > 0.0:
		if not using("꺼지지 않는 불"):
			e.burn -= dt
		var s := r.current()
		r.hurt(e, (T.i("불_초당") + T.i("불_등급당") * (s.grade if s else 0)) * dt, Vector2.ZERO, false, true)
		if e.dead:
			return 0.0
		if r.rng.randf() < dt * T.i("불_번짐"):
			for o in r.enemies:
				if o != e and not o.dead and o.burn <= 0.0 and o.pos.distance_to(e.pos) < 1.0:
					o.burn = T.i("불씨_시간")
					break
	if stop_t > 0.0:
		return 0.0
	if e.stun > 0.0:
		e.stun -= dt
		if e.stun <= 0.0:
			e.frozen = false
		return 0.0
	if e.slow_t > 0.0:
		e.slow_t -= dt
		if e.slow_t <= 0.0:
			e.slow_k = 0.0
	if e.confused > 0.0:
		e.confused -= dt
	var winter: float = 1.0 - T.u("끝나지 않는 겨울", "slow") if holding("끝나지 않는 겨울") else 1.0
	return (1.0 - e.slow_k) * winter



# ---------------------------------------------------------------- 뽑기와 부러짐

## 낮에 뽑은 검에 붙는 것(언덕의 첫 검, 모든 검의 어머니). 이 판의 각인 기록(언덕).
func on_pulled(s: Sword) -> void:
	luck3 = false
	if holding("언덕의 첫 검") and s.breakable():
		s.max_durability = roundf(s.max_durability * (1.0 + T.u("언덕의 첫 검", "dur")))
		s.durability = s.max_durability
	if holding("모든 검의 어머니"):
		var keys: Array = r.data.inscriptions.keys().filter(func(k: String) -> bool: return not s.ins.has(k))
		if not keys.is_empty():
			s.add_ins(keys[r.rng.randi_range(0, keys.size() - 1)], r.data)
	for k in s.ins:
		run_ins[k] = maxf(float(run_ins.get(k, 0.0)), float(s.ins[k]))
	if s.data.display_name == "이름을 잃은 검":
		r.effect.emit(&"dex_all", r.lord.pos, {})


## 검이 부러질 때(마지막 일격, 행운의 녹, 마지막 장례).
func on_break(s: Sword) -> void:
	var v: float = float(s.ins.get("마지막 일격", 0.0)) * king()
	if v > 0.0:
		r.effect.emit(&"ring", r.lord.pos, {"radius": T.i("마지막일격_반경"), "color": r.data.grades.colors[s.grade]})
		for e in r.enemies.duplicate():
			if not e.dead and e.pos.distance_to(r.lord.pos) < T.i("마지막일격_반경") + e.radius:
				r.hurt(e, v, Vector2.ZERO, true)
	if s.data.display_name == "행운의 녹":
		luck3 = true
	for o in r.slots:
		if o and o != s and o.data.display_name == "마지막 장례" and o.extra_ins.size() < int(T.u("마지막 장례", "max")):
			for k in s.ins:
				if not o.ins.has(k):
					o.add_ins(k, r.data)
					break


# ---------------------------------------------------------------- 도움

func _slow(e: Enemy, k: float, t: float) -> void:
	e.slow_k = maxf(e.slow_k, k)
	e.slow_t = maxf(e.slow_t, t)


func _zap(from: Vector2, e: Enemy, d: float) -> void:
	r.effect.emit(&"zap", from, {"to": e.pos})
	r.hurt(e, d, Vector2.ZERO, false)


func _zone(kind: StringName, at: Vector2, radius: float, time: float) -> void:
	zones.append({"kind": kind, "pos": at, "radius": radius, "t": time, "time": time})


func _nearest(at: Vector2, within: float, n: int, skip: Enemy) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in r.enemies:
		if not e.dead and e != skip and e.pos.distance_to(at) < within:
			out.append(e)
	out.sort_custom(func(a: Enemy, b: Enemy) -> bool: return a.pos.distance_squared_to(at) < b.pos.distance_squared_to(at))
	return out.slice(0, n)


func _in_arc(at: Vector2, face: float, reach: float, arc: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in r.enemies:
		if e.dead:
			continue
		var to: Vector2 = e.pos - at
		var d: float = to.length()
		if d > reach + e.radius:
			continue
		if absf(angle_difference(face, to.angle())) > arc / 2.0 and d > e.radius + r.data.lord.close_hit:
			continue
		out.append(e)
	return out
