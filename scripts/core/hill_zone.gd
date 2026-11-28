class_name HillZone
extends RefCounted
## 언덕 재설계(docs/hill_events.md) 1단계: 한 구역의 검 지도·깨어남·정산 규칙. 화면도 Rules도 모른다.
## 같은 시드면 같은 지도. step(dt, 영주 자리)를 틱마다 부르고, 사건이 시작되면 started에 쌓인다(부른 쪽이 비운다).

enum Event { DUEL, TRADE, CHASE }
enum State { SLEEP, AWAKE, PULLED, DONE }

class Blade:
	var at: Vector2
	var grade: int = 0
	var event: int = Event.DUEL
	var state: int = State.SLEEP
	## 깨어나 오른 등급(최대 wake_max).
	var woke: int = 0
	## 주인 자리와 깨어난 뒤 지난 시간. 깨어나지 않았으면 쓰지 않는다.
	var owner_at: Vector2
	var awake_for: float = 0.0
	var links: Array[int] = []

	func final_grade(top: int) -> int:
		return mini(grade + woke, top)


var d: HillZoneData
var blades: Array[Blade] = []
var rng := RandomNumberGenerator.new()
## 이번 틱까지 시작된 사건의 검 번호(뽑기·주인 도착). 부른 쪽이 읽고 비운다.
var started: Array[int] = []
var reckoning: bool = false
var top_grade: int = 5


func _init(data: HillZoneData, p_seed: int, p_top_grade: int = 5) -> void:
	d = data
	top_grade = p_top_grade
	rng.seed = p_seed
	_place()
	_link()


func _place() -> void:
	var tries: int = 0
	while blades.size() < d.swords and tries < 5000:
		tries += 1
		var a: float = rng.randf() * TAU
		var r: float = sqrt(rng.randf()) * d.radius
		var p := Vector2(cos(a), sin(a)) * r
		var ok: bool = true
		for b in blades:
			if b.at.distance_to(p) < d.min_gap:
				ok = false
				break
		if not ok:
			continue
		var b := Blade.new()
		b.at = p
		b.grade = _pick(d.grade_weights)
		b.event = _pick(d.event_weights)
		blades.append(b)


func _pick(w: PackedFloat32Array) -> int:
	var total: float = 0.0
	for x in w:
		total += x
	var r: float = rng.randf() * total
	for i in w.size():
		r -= w[i]
		if r < 0.0:
			return i
	return w.size() - 1


## 가까운 순으로 max_links까지 잇는다(양쪽 다 자리가 있을 때만). 외톨이는 가장 가까운 하나와 잇는다.
func _link() -> void:
	var pairs: Array = []
	for i in blades.size():
		for j in range(i + 1, blades.size()):
			var dd: float = blades[i].at.distance_to(blades[j].at)
			if dd <= d.link_dist:
				pairs.append([dd, i, j])
	pairs.sort_custom(func(a, b): return a[0] < b[0])
	for p in pairs:
		var i: int = p[1]
		var j: int = p[2]
		if blades[i].links.size() < d.max_links and blades[j].links.size() < d.max_links:
			blades[i].links.append(j)
			blades[j].links.append(i)
	for i in blades.size():
		if blades[i].links.is_empty():
			var best: int = -1
			var bd: float = INF
			for j in blades.size():
				if j != i and blades[i].at.distance_to(blades[j].at) < bd:
					bd = blades[i].at.distance_to(blades[j].at)
					best = j
			if best >= 0:
				blades[i].links.append(best)
				blades[best].links.append(i)


## 뽑으면 깨어날 수 있는 이웃(아직 뽑히지 않은 것). 지도에 미리 보여 준다.
func wake_candidates(i: int) -> Array[int]:
	var out: Array[int] = []
	for j in blades[i].links:
		if blades[j].state == State.SLEEP or blades[j].state == State.AWAKE:
			out.append(j)
	return out


## 검을 뽑는다: 사건이 시작되고 이웃이 깨어난다. 뽑을 수 없으면 거짓.
func pull(i: int) -> bool:
	var b := blades[i]
	if b.state == State.PULLED or b.state == State.DONE or reckoning:
		return false
	b.state = State.PULLED
	started.append(i)
	wake_neighbors(i)
	return true


func wake_neighbors(i: int) -> void:
	var cand := wake_candidates(i)
	if cand.is_empty():
		return
	var n: int = 2 if rng.randf() < d.wake_two else 1
	for k in mini(n, cand.size()):
		var at: int = rng.randi_range(0, cand.size() - 1)
		_wake(cand[at])
		cand.remove_at(at)


func _wake(j: int) -> void:
	var b := blades[j]
	b.woke = mini(b.woke + d.wake_grade, d.wake_max)
	if b.state == State.SLEEP:
		b.state = State.AWAKE
		b.owner_at = b.at
		b.awake_for = 0.0


## 깨어난 주인이 다가오고, 닿거나 시간이 다 되면 그 검의 사건이 시작된다.
func step(dt: float, lord_at: Vector2) -> void:
	if reckoning:
		return
	for i in blades.size():
		var b := blades[i]
		if b.state != State.AWAKE:
			continue
		b.awake_for += dt
		b.owner_at = b.owner_at.move_toward(lord_at, d.owner_speed * dt)
		if b.awake_for >= d.owner_timeout or b.owner_at.distance_to(lord_at) <= d.owner_reach:
			b.state = State.PULLED
			started.append(i)


## 구역 끝: 깨어나고 안 뽑힌 검의 주인이 한꺼번에 온다. 그 검 번호들을 돌려준다.
func begin_reckoning() -> Array[int]:
	reckoning = true
	var out: Array[int] = []
	for i in blades.size():
		if blades[i].state == State.AWAKE:
			blades[i].state = State.PULLED
			out.append(i)
	return out


## 사건이 끝났다(이겼든 졌든). won이면 검을 얻는 것은 부른 쪽이 한다.
func finish(i: int, won: bool) -> void:
	blades[i].state = State.DONE if won else State.SLEEP
	if not won:
		blades[i].woke = 0


func duel_hp_mult(i: int) -> float:
	return pow(d.duel_hp_step, float(blades[i].final_grade(top_grade)))


func awake_count() -> int:
	var n: int = 0
	for b in blades:
		if b.state == State.AWAKE:
			n += 1
	return n
