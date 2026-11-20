class_name Nav
extends RefCounted
## 적 길찾기(37단계, docs/open_world2.md). 노드에 기대지 않는다. Rules.set_blockers가 하나 만들고,
## 막힘이 없는 곳(언덕 싸움터, 결투, 마을 수련장)에는 없다(Rules.nav == null, 적은 예전처럼 곧장 온다).
##
## 막힘 표는 장면이 쓰는 것과 같다(들판: FieldBuilder.build의 rects·circles·low_rects·low_circles, 무덤: 걷는 판 walk(방)·문 gates·관).
## 적은 뛰지 않으므로 낮은 막힘도 막힘이다. 표를 RES칸 격자에 한 번 굽는다(격자 칸의 가운데가 넓힌 막힘 안이면 막힘).
## 몸 크기별로 두 장: 작은 적(반지름 ≤ SMALL_R)은 SMALL_R만큼, 큰 적은 BIG_R만큼 넓힌다.
##
## 흐름장: 목표(영주, 또는 돌아갈 제자리) 칸에서 4방향 BFS로 걸음 수를 채운다. BFS는 한 틱에 FLOW_BUDGET칸까지만 돌고 남은 것은 다음 틱에 잇는다
## (그동안은 지난 흐름장을 쓴다. 한 틱이 길어지지 않게). 영주 쪽은 막힌 적이 있을 때만 FLOW_EVERY틱마다 새로 채우고, 막힌 적들의 칸에 다 닿으면
## (FLOW_MARGIN을 더 채운 뒤) 멈춘다(걸음 한도 FLOW_RADIUS칸). 제자리 쪽은 한 번 채워 두고(HOME_KEEP개까지) 막힘이 바뀔 때(무덤 문)만 버린다.
## 적은 곧은 선(몸만큼 넓힌 격자 위)이 트였으면 곧장 걷고, 막혔으면 흐름장의 내리막을 LOOK칸 따라가 곧게 보이는 가장 먼 칸으로 걷는다.
## 밀어내기(push)는 격자가 아니라 표 그대로(Blockers.push_out, 적의 반지름)이고, 칸 묶음(BUCKET)으로 가까운 막힘만 본다.
## 랜덤을 쓰지 않는다. 같은 표·같은 상태면 같은 결과다(결정성).

## 격자 한 칸의 길이(칸).
const RES: float = 0.5
## 몸 크기 두 장: 이 반지름(칸) 이하는 작은 적, 넘으면 큰 적. 큰 적 격자는 BIG_R만큼 넓힌다(가장 큰 적 0.9칸).
const SMALL_R: float = 0.45
const BIG_R: float = 0.95
## 흐름장이 닿는 걸음 수 한도(칸, 4방향 걸음이라 대각으로도 이만큼 가게 √2배 걸음까지).
const FLOW_RADIUS: float = 45.0
## 영주 쪽 흐름장을 다시 채우는 틱 간격(30Hz에서 0.2초).
const FLOW_EVERY: int = 6
## 막힌 적들의 칸에 다 닿은 뒤 더 채우는 걸음 수(격자 칸, 그 사이 조금 물러나도 흐름장 안에 있게).
const FLOW_MARGIN: int = 12
## 흐름장의 내리막을 앞으로 볼 격자 칸 수(곧게 보이는 가장 먼 칸으로 걷는다).
const LOOK: int = 12
## 곧은 선을 볼 때 처음 이만큼(칸)은 막힘이어도 넘어간다(벽에 붙어 밀려난 적이 넓힌 막힘 안에서 시작하므로).
const START_SLACK: float = 0.75
## 흐름장 BFS를 한 틱에 이만큼(격자 칸)까지만 돈다(남은 것은 다음 틱에 이어서, 그동안은 지난 흐름장을 쓴다).
const FLOW_BUDGET: int = 3000
## 제자리 쪽 흐름장을 이만큼까지 둔다(넘으면 먼저 채운 것부터 버린다).
const HOME_KEEP: int = 12
## 영주·적이 넓힌 막힘 안에 서 있으면 이만큼(격자 칸) 둘레에서 가장 가까운 빈 칸을 쓴다.
const NEAR_RING: int = 4
## 밀어내기용 칸 묶음 한 변(칸).
const BUCKET: float = 4.0

const BLOCK: int = -2
const FREE: int = -1
const RADII: Array[float] = [SMALL_R, BIG_R]

## 격자 크기(가장자리 한 줄은 늘 막힘).
var gw: int = 0
var gh: int = 0
var size: Vector2 = Vector2.ZERO
## 적에게는 모두 막힘(높은 것과 낮은 것을 합쳤다).
var rects: Array[Rect2] = []
var circles: Array = []
## 걷는 판(무덤): 비어 있지 않으면 이 안(과 열린 문)만 걸을 수 있다.
var walk: Array[Rect2] = []
## 문: id → 열렸을 때 걷는 곳(Rect2). open에 든 것만 걷는다.
var gates: Dictionary = {}
var open: Dictionary = {}
## 몸 크기별로 구운 격자(BLOCK / FREE).
var _base: Array[PackedInt32Array] = []
## 영주 쪽 흐름장(몸 크기별), 채운 틱, 다시 채워야 하는지.
var _flow: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
var _flow_tick: PackedInt32Array = PackedInt32Array([0, 0])
var _flow_dirty: Array[bool] = [true, true]
## 영주 쪽 흐름장을 채우는 중인 것(몸 크기별, 없으면 null)과 그 BFS 줄.
var _jobs: Array[Job] = [null, null]
var _lord_q: Array[PackedInt32Array] = []
## 제자리 쪽 흐름장: "몸 크기:격자 칸" → 걸음 수(HOME_KEEP개까지), 채우는 중인 것.
var _homes: Dictionary = {}
var _home_jobs: Dictionary = {}
## 밀어내기용 칸 묶음마다 가까운 막힘.
var _bw: int = 0
var _bh: int = 0
var _brects: Array = []
var _bcircles: Array = []
## 잰 것(성능 확인용): 다 채운 흐름장 수와 BFS가 꺼낸 칸 수.
var fills: int = 0
var filled_cells: int = 0


## size는 칸 수(Grid.size), 막힘 표는 칸 단위. gates는 id → Rect2(열렸을 때 걷는 곳), 처음에는 모두 열려 있다.
func _init(p_size: Vector2, p_rects: Array, p_circles: Array, low_rects: Array = [], low_circles: Array = [], p_walk: Array = [], p_gates: Dictionary = {}) -> void:
	size = p_size
	for r in p_rects:
		rects.append(r)
	for r in low_rects:
		rects.append(r)
	circles = p_circles.duplicate()
	circles.append_array(low_circles)
	for w in p_walk:
		walk.append(w)
	gates = p_gates.duplicate()
	for id in gates:
		open[id] = 1
	gw = int(ceil(size.x / RES)) + 2
	gh = int(ceil(size.y / RES)) + 2
	for cls in RADII.size():
		var q := PackedInt32Array()
		q.resize(gw * gh)
		_lord_q.append(q)
	for cls in RADII.size():
		var b := PackedInt32Array()
		b.resize(gw * gh)
		_base.append(b)
		_bake(cls, Rect2i(0, 0, gw, gh))
	_make_buckets()


## 반지름(칸)에 맞는 격자: 0 작은 적, 1 큰 적.
static func class_of(radius: float) -> int:
	return 0 if radius <= SMALL_R + 0.0001 else 1


# ---------------------------------------------------------------- 굽기

## 격자의 한 구역(격자 칸, 가장자리 포함 좌표)을 표에서 다시 굽는다.
func _bake(cls: int, region: Rect2i) -> void:
	var B: PackedInt32Array = _base[cls]
	var rc: float = RADII[cls]
	var walled: bool = not walk.is_empty()
	var whole: bool = region.position == Vector2i.ZERO and region.size == Vector2i(gw, gh)
	if whole:
		B.fill(BLOCK if walled else FREE)
	else:
		_fill_rect_cells(B, region, BLOCK if walled else FREE)
	if walled:
		for w in _walk_now():
			_fill_rect(B, w.grow(-rc), FREE, region)
	for r in rects:
		_fill_rect(B, r.grow(rc), BLOCK, region)
	for c in circles:
		_fill_circle(B, c[0], float(c[1]) + rc, region)
	# 가장자리 한 줄은 늘 막힘(이웃을 볼 때 범위를 따지지 않으려고)
	for gx in gw:
		B[gx] = BLOCK
		B[(gh - 1) * gw + gx] = BLOCK
	for gy in gh:
		B[gy * gw] = BLOCK
		B[gy * gw + gw - 1] = BLOCK


func _walk_now() -> Array[Rect2]:
	var out: Array[Rect2] = walk.duplicate()
	for id in gates:
		if open.has(id):
			out.append(gates[id])
	return out


func _fill_rect_cells(B: PackedInt32Array, cells: Rect2i, v: int) -> void:
	for gy in range(maxi(0, cells.position.y), mini(gh, cells.end.y)):
		var row: int = gy * gw
		for gx in range(maxi(0, cells.position.x), mini(gw, cells.end.x)):
			B[row + gx] = v


## 가운데가 rect(칸) 안인 격자 칸을 v로. 격자 칸 gx의 가운데는 (gx - 0.5) × RES칸이다.
func _fill_rect(B: PackedInt32Array, r: Rect2, v: int, region: Rect2i) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var x0: int = maxi(region.position.x, int(ceil(r.position.x / RES + 0.5)))
	var x1: int = mini(region.end.x, int(ceil(r.end.x / RES + 0.5)))
	var y0: int = maxi(region.position.y, int(ceil(r.position.y / RES + 0.5)))
	var y1: int = mini(region.end.y, int(ceil(r.end.y / RES + 0.5)))
	for gy in range(y0, y1):
		var row: int = gy * gw
		for gx in range(x0, x1):
			B[row + gx] = v


func _fill_circle(B: PackedInt32Array, c: Vector2, rad: float, region: Rect2i) -> void:
	var x0: int = maxi(region.position.x, int(floor((c.x - rad) / RES + 0.5)))
	var x1: int = mini(region.end.x, int(ceil((c.x + rad) / RES + 0.5)) + 1)
	var y0: int = maxi(region.position.y, int(floor((c.y - rad) / RES + 0.5)))
	var y1: int = mini(region.end.y, int(ceil((c.y + rad) / RES + 0.5)) + 1)
	var r2: float = rad * rad
	for gy in range(y0, y1):
		var cy: float = (gy - 0.5) * RES - c.y
		var row: int = gy * gw
		for gx in range(x0, x1):
			var cx: float = (gx - 0.5) * RES - c.x
			if cx * cx + cy * cy < r2:
				B[row + gx] = BLOCK


func _make_buckets() -> void:
	_bw = int(ceil(size.x / BUCKET)) + 1
	_bh = int(ceil(size.y / BUCKET)) + 1
	_brects.clear()
	_bcircles.clear()
	for i in _bw * _bh:
		_brects.append([])
		_bcircles.append([])
	var m: float = BIG_R + 0.25
	for r in rects:
		var g: Rect2 = r.grow(m)
		for b in _buckets_in(g.position, g.end):
			(_brects[b] as Array).append(r)
	for c in circles:
		var at: Vector2 = c[0]
		var e: float = float(c[1]) + m
		for b in _buckets_in(at - Vector2(e, e), at + Vector2(e, e)):
			(_bcircles[b] as Array).append(c)


func _buckets_in(a: Vector2, b: Vector2) -> PackedInt32Array:
	var out := PackedInt32Array()
	var x0: int = clampi(int(floor(a.x / BUCKET)), 0, _bw - 1)
	var x1: int = clampi(int(floor(b.x / BUCKET)), 0, _bw - 1)
	var y0: int = clampi(int(floor(a.y / BUCKET)), 0, _bh - 1)
	var y1: int = clampi(int(floor(b.y / BUCKET)), 0, _bh - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			out.append(y * _bw + x)
	return out


func _bucket(p: Vector2) -> int:
	return clampi(int(floor(p.y / BUCKET)), 0, _bh - 1) * _bw + clampi(int(floor(p.x / BUCKET)), 0, _bw - 1)


## 문을 연다/닫는다(무덤, open: id → 아무 값). 바뀐 문 둘레만 다시 굽고 흐름장을 버린다.
func set_open(p_open: Dictionary) -> bool:
	var changed: Array = []
	for id in gates:
		if p_open.has(id) != open.has(id):
			changed.append(id)
	if changed.is_empty():
		return false
	open.clear()
	for id in gates:
		if p_open.has(id):
			open[id] = 1
	for id in changed:
		var g: Rect2 = (gates[id] as Rect2).grow(BIG_R + 1.0)
		var region := Rect2i(int(floor(g.position.x / RES)), int(floor(g.position.y / RES)), int(ceil(g.size.x / RES)) + 3, int(ceil(g.size.y / RES)) + 3)
		for cls in RADII.size():
			_bake(cls, region)
	_homes.clear()
	_home_jobs.clear()
	_jobs = [null, null]
	_flow_dirty = [true, true]
	return true


# ---------------------------------------------------------------- 격자 읽기

## 칸 자리 p의 격자 칸(가장자리 줄 안으로 자른다).
func cell(p: Vector2) -> int:
	var gx: int = clampi(int(floor(p.x / RES)) + 1, 0, gw - 1)
	var gy: int = clampi(int(floor(p.y / RES)) + 1, 0, gh - 1)
	return gy * gw + gx


## 격자 칸의 가운데(칸 자리).
func center(n: int) -> Vector2:
	return Vector2((n % gw - 0.5) * RES, (n / gw - 0.5) * RES)


## 몸 크기 cls의 적이 그 자리(가운데)에 설 수 있는가(격자).
func free_at(p: Vector2, cls: int) -> bool:
	return _base[cls][cell(p)] != BLOCK


## a에서 b까지 곧은 선이 몸 크기 cls의 격자에서 트였는가. 처음 START_SLACK칸 안의 막힘은 넘어간다(벽에 붙은 적).
func clear(a: Vector2, b: Vector2, cls: int) -> bool:
	var B: PackedInt32Array = _base[cls]
	var ga: Vector2 = a / RES + Vector2.ONE
	var gb: Vector2 = b / RES + Vector2.ONE
	var x: int = clampi(int(floor(ga.x)), 0, gw - 1)
	var y: int = clampi(int(floor(ga.y)), 0, gh - 1)
	var ex: int = clampi(int(floor(gb.x)), 0, gw - 1)
	var ey: int = clampi(int(floor(gb.y)), 0, gh - 1)
	var d: Vector2 = gb - ga
	var length: float = d.length() * RES
	var slack: float = START_SLACK / maxf(length, 0.0001)   # 매개변수 t(0~1)로 바꾼 넘어가는 거리
	var started: bool = B[y * gw + x] != BLOCK
	var sx: int = 1 if d.x > 0.0 else -1
	var sy: int = 1 if d.y > 0.0 else -1
	var tdx: float = absf(1.0 / d.x) if absf(d.x) > 1e-9 else INF
	var tdy: float = absf(1.0 / d.y) if absf(d.y) > 1e-9 else INF
	var tmx: float = ((x + 1 - ga.x) if sx > 0 else (ga.x - x)) * tdx if tdx < INF else INF
	var tmy: float = ((y + 1 - ga.y) if sy > 0 else (ga.y - y)) * tdy if tdy < INF else INF
	var n: int = absi(ex - x) + absi(ey - y)
	for i in n:
		var t: float
		if tmx < tmy:
			t = tmx
			x += sx
			tmx += tdx
		else:
			t = tmy
			y += sy
			tmy += tdy
		if B[y * gw + x] == BLOCK:
			if started or t > slack:
				return false
		else:
			started = true
	return started or length <= START_SLACK


## a에서 b 쪽으로 몸 크기 cls가 막힘 없이 갈 수 있는 가장 먼 자리(0.25칸씩 본다). 처음 START_SLACK칸 안의 막힘은 넘어가고(벽에 붙은 적),
## 그 뒤 막히면 그 앞에서 멈춘다. 끝까지 트였으면 b.
func reach(a: Vector2, b: Vector2, cls: int) -> Vector2:
	var v: Vector2 = b - a
	var length: float = v.length()
	if length < 0.001:
		return a
	var steps: int = int(ceil(length / 0.25))
	var last: Vector2 = a
	var started: bool = free_at(a, cls)
	for i in range(1, steps + 1):
		var u: float = float(i) / steps
		var q: Vector2 = a + v * u
		if free_at(q, cls):
			started = true
			last = q
		elif started or length * u > START_SLACK:
			return last
	return b if started else a


## from에서 dir(단위)로 length칸 가되 막힘 앞에서 멈추는 길이(돌진). 끝까지 트였으면 length 그대로.
func run_len(from: Vector2, dir: Vector2, length: float, cls: int) -> float:
	var to: Vector2 = from + dir * length
	var got: Vector2 = reach(from, to, cls)
	return length if got == to else from.distance_to(got)


## 막힌 곳 밖으로 민다(적의 반지름 r, 표 그대로). 무덤이면 먼저 걷는 판(방과 열린 문) 안으로 넣는다.
func push(p: Vector2, r: float) -> Vector2:
	if not walk.is_empty():
		p = _push_in(p, r)
	var b: int = _bucket(p)
	var R: Array = _brects[b]
	var C: Array = _bcircles[b]
	if R.is_empty() and C.is_empty():
		return p
	return Blockers.push_out(p, R, C, [], [], false, r)


## 걷는 판 밖이면 가장 가까운 걸을 수 있는 곳(반지름만큼 안쪽)으로(CryptLayout.push_in과 같은 셈).
func _push_in(p: Vector2, r: float) -> Vector2:
	var best: Vector2 = p
	var best_d: float = INF
	for w in _walk_now():
		var inner: Rect2 = w.grow(-r)
		var q := Vector2(clampf(p.x, inner.position.x, inner.end.x), clampf(p.y, inner.position.y, inner.end.y))
		var d: float = p.distance_squared_to(q)
		if d < best_d:
			best_d = d
			best = q
			if d == 0.0:
				break
	return best


## p 둘레에서 몸 크기 cls가 설 수 있는 가장 가까운 격자 칸(p의 칸이 막혔으면 NEAR_RING칸 둘레를 본다). 없으면 -1.
func free_cell(p: Vector2, cls: int) -> int:
	var B: PackedInt32Array = _base[cls]
	var n: int = cell(p)
	if B[n] != BLOCK:
		return n
	var best: int = -1
	var best_d: float = INF
	var gx: int = n % gw
	var gy: int = n / gw
	for k in range(1, NEAR_RING + 1):
		for dy in range(-k, k + 1):
			for dx in range(-k, k + 1):
				if maxi(absi(dx), absi(dy)) != k:
					continue
				var x: int = gx + dx
				var y: int = gy + dy
				if x < 0 or y < 0 or x >= gw or y >= gh:
					continue
				var m: int = y * gw + x
				if B[m] == BLOCK:
					continue
				var dd: float = center(m).distance_squared_to(p)
				if dd < best_d:
					best_d = dd
					best = m
		if best >= 0:
			return best
	return -1


# ---------------------------------------------------------------- 흐름장

## 채우는 중인 흐름장 하나(BFS를 여러 틱에 나눠 돈다).
class Job:
	var cls: int = 0
	var dist: PackedInt32Array
	var q: PackedInt32Array
	var head: int = 0
	var tail: int = 0
	var depth: int = 0
	var cap: int = 0
	var want: PackedInt32Array
	var reached: bool = false
	## 시작한 틱, 마지막으로 이어 돈 틱(한 틱에 한 번만 돈다).
	var tick: int = 0
	var last: int = -1


## 영주 쪽 흐름장: 때가 됐으면(지난번 시작에서 FLOW_EVERY틱, 또는 막힘이 바뀜) 새로 채우기 시작하고, 채우는 중이면 이 틱 몫(FLOW_BUDGET칸)을 더 채운다.
## 다 채우면 그것으로 바꾼다(그때까지는 지난 흐름장을 쓴다). want는 막힌 적들의 격자 칸(free_cell), tick은 Rules.tick.
func update_flow(cls: int, goal: Vector2, tick: int, want: PackedInt32Array) -> void:
	var job: Job = _jobs[cls]
	if job != null and tick - job.tick > FLOW_EVERY * 4:
		job = null   # 오래 멈춰 있던 것(막힌 적이 없던 동안)은 목표가 낡았다
	if job == null:
		if not _flow[cls].is_empty() and not _flow_dirty[cls] and tick - _flow_tick[cls] < FLOW_EVERY:
			return
		job = _start(cls, goal, want, tick, _lord_q[cls])
		_jobs[cls] = job
		_flow_dirty[cls] = false
	if job.last == tick:
		return
	job.last = tick
	if _advance(job, FLOW_BUDGET):
		_flow[cls] = job.dist
		_flow_tick[cls] = job.tick
		_jobs[cls] = null


## 영주 쪽 흐름장을 따라 p에서 걸을 다음 자리(칸). 흐름장이 없거나 닿지 않은 자리면 INF(곧장 간다).
func flow_step(cls: int, p: Vector2) -> Vector2:
	if _flow[cls].is_empty():
		return Vector2.INF
	return _next(_flow[cls], p, cls)


## 제자리 home 쪽 흐름장을 따라 p에서 걸을 다음 자리. 처음 쓸 때 채우기 시작해(틱마다 FLOW_BUDGET칸) 다 채운 것을 둔다.
## 다 채우기 전에는 INF(곧장 간다).
func home_step(cls: int, home: Vector2, p: Vector2, tick: int) -> Vector2:
	var key: String = "%d:%d" % [cls, cell(home)]
	if _homes.has(key):
		return _next(_homes[key], p, cls)
	var job: Job = _home_jobs.get(key)
	if job == null:
		var q := PackedInt32Array()
		q.resize(gw * gh)
		job = _start(cls, home, PackedInt32Array(), tick, q)
		_home_jobs[key] = job
	if job.last != tick:
		job.last = tick
		if _advance(job, FLOW_BUDGET):
			_home_jobs.erase(key)
			if _homes.size() >= HOME_KEEP:
				_homes.erase(_homes.keys()[0])   # 가장 먼저 채운 것부터 버린다(넣은 차례라 결정적)
			_homes[key] = job.dist
			return _next(job.dist, p, cls)
	return Vector2.INF


## 걸음 한도(격자 칸 수).
static func flow_steps() -> int:
	return int(ceil(FLOW_RADIUS / RES * 1.42))


## goal에서 4방향 BFS를 시작한다. want가 있으면 한도를 want까지의 거리로 줄인다(_advance가 그 칸들에 다 닿고 FLOW_MARGIN을 더 채운 뒤 멈춘다).
func _start(cls: int, goal: Vector2, want: PackedInt32Array, tick: int, q: PackedInt32Array) -> Job:
	var job := Job.new()
	job.cls = cls
	job.dist = _base[cls].duplicate()
	job.q = q
	job.want = want
	job.tick = tick
	job.cap = flow_steps()
	job.reached = want.is_empty()
	var s: int = free_cell(goal, cls)
	if s < 0:
		return job   # 목표 둘레가 다 막혔다: 빈 흐름장
	job.dist[s] = 0
	job.q[0] = s
	job.tail = 1
	if not want.is_empty():
		var far: int = 0
		var sx: int = s % gw
		var sy: int = s / gw
		for w in want:
			far = maxi(far, absi(w % gw - sx) + absi(w / gw - sy))
		job.cap = mini(job.cap, far * 2 + FLOW_MARGIN * 2)
	return job


## BFS를 budget칸까지 더 돈다. 다 돌았으면 true.
func _advance(job: Job, budget: int) -> bool:
	var dist: PackedInt32Array = job.dist
	var q: PackedInt32Array = job.q
	var W: int = gw
	var head: int = job.head
	var tail: int = job.tail
	var depth: int = job.depth
	var cap: int = job.cap
	var stop: int = head + budget
	var finished: bool = true
	while head < tail:
		if head >= stop:
			finished = false
			break
		var c: int = q[head]
		var dc: int = dist[c]
		if dc != depth:
			depth = dc
			if not job.reached:
				var all: bool = true
				for w in job.want:
					if dist[w] < 0:
						all = false
						break
				if all:
					job.reached = true
					cap = mini(cap, depth + FLOW_MARGIN)
			if depth >= cap:
				break
		head += 1
		var nd: int = dc + 1
		var n: int = c + 1
		if dist[n] == FREE:
			dist[n] = nd
			q[tail] = n
			tail += 1
		n = c - 1
		if dist[n] == FREE:
			dist[n] = nd
			q[tail] = n
			tail += 1
		n = c + W
		if dist[n] == FREE:
			dist[n] = nd
			q[tail] = n
			tail += 1
		n = c - W
		if dist[n] == FREE:
			dist[n] = nd
			q[tail] = n
			tail += 1
	filled_cells += head - job.head
	job.head = head
	job.tail = tail
	job.depth = depth
	job.cap = cap
	if finished:
		fills += 1
	return finished


## 흐름장 dist에서 c의 이웃 중 가장 가까운(걸음 수가 작은) 칸. 대각은 두 옆 칸이 막히지 않았을 때만(모서리를 깎지 않게). 없으면 -1.
func _down(dist: PackedInt32Array, c: int) -> int:
	var W: int = gw
	var bv: int = dist[c]
	var best: int = -1
	var v: int = dist[c + 1]
	if v >= 0 and v < bv:
		bv = v
		best = c + 1
	v = dist[c - 1]
	if v >= 0 and v < bv:
		bv = v
		best = c - 1
	v = dist[c + W]
	if v >= 0 and v < bv:
		bv = v
		best = c + W
	v = dist[c - W]
	if v >= 0 and v < bv:
		bv = v
		best = c - W
	var right: bool = dist[c + 1] != BLOCK
	var left: bool = dist[c - 1] != BLOCK
	var down: bool = dist[c + W] != BLOCK
	var up: bool = dist[c - W] != BLOCK
	if right and down:
		v = dist[c + 1 + W]
		if v >= 0 and v < bv:
			bv = v
			best = c + 1 + W
	if left and down:
		v = dist[c - 1 + W]
		if v >= 0 and v < bv:
			bv = v
			best = c - 1 + W
	if right and up:
		v = dist[c + 1 - W]
		if v >= 0 and v < bv:
			bv = v
			best = c + 1 - W
	if left and up:
		v = dist[c - 1 - W]
		if v >= 0 and v < bv:
			bv = v
			best = c - 1 - W
	return best


## p에서 흐름장을 따라 걸을 자리: 내리막을 LOOK칸 따라가 곧게 보이는 가장 먼 칸의 가운데. 흐름장 밖이거나 이미 목표 칸이면 INF.
func _next(dist: PackedInt32Array, p: Vector2, cls: int) -> Vector2:
	var n: int = _reached_cell(dist, p, cls)
	if n < 0 or dist[n] <= 0:
		return Vector2.INF
	var path := PackedInt32Array([n])
	var cur: int = n
	for i in LOOK:
		var nx: int = _down(dist, cur)
		if nx < 0:
			break
		path.append(nx)
		cur = nx
		if dist[nx] == 0:
			break
	if path.size() < 2:
		return Vector2.INF
	for k in [LOOK, 8, 5, 3, 2]:
		var i: int = mini(k, path.size() - 1)
		if i < 2:
			break
		if clear(p, center(path[i]), cls):
			return center(path[i])
	return center(path[1])


## p의 격자 칸이 흐름장에 닿았으면 그 칸, 아니면(막혔거나 안 닿음) 둘레에서 닿은 가장 가까운 칸. 없으면 -1.
func _reached_cell(dist: PackedInt32Array, p: Vector2, cls: int) -> int:
	var n: int = cell(p)
	if dist[n] >= 0:
		return n
	var best: int = -1
	var best_d: float = INF
	var gx: int = n % gw
	var gy: int = n / gw
	for k in range(1, NEAR_RING + 1):
		for dy in range(-k, k + 1):
			for dx in range(-k, k + 1):
				if maxi(absi(dx), absi(dy)) != k:
					continue
				var x: int = gx + dx
				var y: int = gy + dy
				if x < 0 or y < 0 or x >= gw or y >= gh:
					continue
				var m: int = y * gw + x
				if dist[m] < 0:
					continue
				var dd: float = center(m).distance_squared_to(p)
				if dd < best_d:
					best_d = dd
					best = m
		if best >= 0:
			return best
	return -1
