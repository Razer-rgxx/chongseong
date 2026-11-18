class_name Tokens
extends RefCounted
## 공격 표(docs/attack_tokens.md). 밤마다 구역만큼 표가 있고, 표를 가진 적만 영주를 때린다.
## 나머지는 기다림 거리 둘레에서 영주를 보며 옆으로 돈다. 둠(2016)·갓 오브 워(2018)·하프라이프 2의 방식.
## 랜덤을 쓰지 않는다(같은 상태면 같은 결과). Rules._step_enemies가 적마다 check_state·hold·wait_move를 부르고,
## 틱 끝에 deal로 나눠 준다. 화면은 Enemy.token(든 표 수)과 Enemy.attack_soon(곧 때린다)만 읽는다.

var r: Rules
## 돌려놓아 식는 중인 표: x = 표 수, y = 남은 시간(초).
var cooling: Array[Vector2] = []


func _init(rules: Rules) -> void:
	r = rules


## 밤이 시작될 때: 식는 표를 비우고 남아 있는 적의 표와 기다림을 거둔다.
func reset() -> void:
	cooling.clear()
	for e in r.enemies:
		e.token = 0
		e.token_t = 0.0
		e.windup = 0.0
		e.attack_soon = false
		e.waiting = false
		e.wait_t = 0.0


## 이 구역의 표 수. 0이면 표 없이 모두 덤빈다.
func total() -> int:
	var T: PackedInt32Array = r.data.run.attack_tokens
	if T.is_empty():
		return 0
	return T[clampi(r.zone, 0, T.size() - 1)]


## 그 적이 가져가야 하는 표 수(정예는 +1, 이 밤의 표 수를 넘지 않는다). 0이면 표 없이 덤빈다(언덕지기).
func cost(e: Enemy) -> int:
	var n: int = total()
	if n <= 0 or e.data.token_cost <= 0:
		return 0
	return mini(n, e.data.token_cost + (1 if e.elite else 0))


## 기다림 거리(칸, 영주와 적의 가운데 사이) = 사거리 + token_wait_gap.
## 멀리서 덤비는 새 적(활잡이, 돌격병)은 EnemyData.wait_range.
func wait_dist(e: Enemy) -> float:
	var w: float = r.foes.wait_range(e) if r.foes else 0.0
	if w > 0.0:
		return w
	return e.radius + r.data.run.enemy_reach + r.data.run.token_wait_gap


## 적들이 들고 있는 표.
func held() -> int:
	var n: int = 0
	for e in r.enemies:
		if not e.dead:
			n += e.token
	return n


## 식는 중인 표.
func cooling_count() -> int:
	var n: int = 0
	for c in cooling:
		n += int(c.x)
	return n


## 지금 나눠 줄 수 있는 표.
func free_count() -> int:
	return maxi(0, total() - held() - cooling_count())


## 표를 내려놓는다. cool이면 token_cooldown 동안 식은 뒤에 다시 나간다.
func release(e: Enemy, cool: bool) -> void:
	if e.token <= 0:
		return
	if cool and r.data.run.token_cooldown > 0.0:
		cooling.append(Vector2(e.token, r.data.run.token_cooldown))
	e.token = 0
	e.token_t = 0.0
	e.windup = 0.0
	e.attack_soon = false


## 적마다 틱의 처음: 묶였거나(기절·얼음) 망각이면 표를 내려놓는다.
func check_state(e: Enemy) -> void:
	if e.token > 0 and (e.stun > 0.0 or e.frozen or e.confused > 0.0):
		release(e, true)


## 표를 든 적이 움직이기 전에. d는 영주까지의 거리.
## 기다림 거리 × 2 밖으로 밀려났으면 내려놓고, token_hold_max 동안 못 때렸으면 식는 시간 없이 내려놓는다.
func hold(e: Enemy, d: float, dt: float) -> void:
	if e.token <= 0:
		return
	e.token_t += dt
	e.windup -= dt
	if d > wait_dist(e) * 2.0:
		release(e, true)
	elif e.token_t >= r.data.run.token_hold_max:
		release(e, false)


## 표 없는 적의 걸음. 둘레 밖이면 곧장 다가오되 둘레를 넘지 않는다.
## 둘레에 닿았으면 영주를 보며(face는 Rules가 영주 쪽으로 맞춘다) 옆으로 돈다: 짝수 번호는 시계, 홀수는 반시계(위에서 볼 때).
## 너무 가까우면 둘레까지 물러난다. 벗어난 거리는 token_settle에 걸쳐 되돌려 덜컥거리지 않고,
## 옆걸음은 둘레에 가까울수록 커져서(둘레에서 token_wait_gap 떨어지면 0) 물러나다가 부드럽게 돌기 시작한다.
func wait_move(e: Enemy, to: Vector2, d: float, speed: float, dt: float) -> void:
	if d < 0.001:
		return
	var R := r.data.run
	var inward: Vector2 = to / d
	var err: float = d - wait_dist(e)
	if not e.waiting:
		e.pos += inward * minf(speed * dt, maxf(0.0, err))
		return
	var radial: float = clampf(err / maxf(R.token_settle, dt), -speed, speed)
	# 영주에게서 바깥쪽을 기준으로 각이 커지는 쪽(칸 좌표 y가 아래라 위에서 보면 시계 방향)
	var side: float = 1.0 if e.id % 2 == 0 else -1.0
	var tangent := Vector2(inward.y, -inward.x) * side
	var near: float = clampf(1.0 - absf(err) / maxf(R.token_wait_gap, 0.001), 0.0, 1.0)
	e.pos += (inward * radial + tangent * speed * R.token_strafe * near) * dt


## 틱 끝(적이 다 움직이고 서로 밀어낸 뒤): 식는 표의 시간을 줄이고, 기다리는 적에게 표를 나눠 준다.
## 가장 오래 기다린 적부터(같으면 적 목록 순서). 맨 앞의 적이 받을 만큼 표가 없으면 뒤의 적도 기다린다
## (거인처럼 표가 많이 드는 적이 늑대들에게 밀려 굶지 않게).
func deal(dt: float) -> void:
	var R := r.data.run
	for i in range(cooling.size() - 1, -1, -1):
		var c: Vector2 = cooling[i]
		c.y -= dt
		if c.y <= 0.0:
			cooling.remove_at(i)
		else:
			cooling[i] = c
	var want: Array[int] = []
	for i in r.enemies.size():
		var e := r.enemies[i]
		if e.dead or cost(e) <= 0:
			e.waiting = false
			continue
		var d: float = e.pos.distance_to(r.lord.pos)
		var w: float = wait_dist(e)
		if d <= w + 0.001:
			e.waiting = true
		elif d > w * 2.0:
			e.waiting = false
		if e.token > 0 or not e.waiting or e.stun > 0.0 or e.frozen or e.confused > 0.0:
			continue
		if r.foes and not r.foes.can_take_token(e):
			continue
		e.wait_t += dt
		want.append(i)
	var list: Array[Enemy] = r.enemies
	want.sort_custom(func(a: int, b: int) -> bool:
		var ta: float = list[a].wait_t
		var tb: float = list[b].wait_t
		return ta > tb or (ta == tb and a < b))
	var free: int = free_count()
	for i in want:
		var e := r.enemies[i]
		var c: int = cost(e)
		if c > free:
			break
		free -= c
		e.token = c
		e.token_t = 0.0
		e.wait_t = 0.0
		e.windup = R.token_warn
	for e in r.enemies:
		e.attack_soon = e.token > 0 and time_to_hit(e) <= R.token_warn + 0.0001


## 표를 든 적이 영주를 때리기까지 남은 시간(어림): 간격·첫 기다림·걸어갈 시간 중 가장 긴 것.
## 새 적은 겨눔·머리 낮춤·심지 시간을 더한다(하고 있으면 남은 시간만).
func time_to_hit(e: Enemy) -> float:
	if r.foes and r.foes.busy(e):
		return r.foes.prep_left(e)
	var reach: float = r.foes.strike_reach(e) if r.foes else e.radius + r.data.run.enemy_reach
	var gap: float = e.pos.distance_to(r.lord.pos) - reach
	var sp: float = e.data.speed * (1.0 - e.slow_k)
	var walk: float = maxf(0.0, gap) / maxf(sp, 0.01)
	return maxf(maxf(e.cooldown, e.windup), walk) + (r.foes.prep_left(e) if r.foes else 0.0)
