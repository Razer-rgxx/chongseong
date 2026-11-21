class_name StorageHouse
extends Node3D
## 검 보관집(2026-11-21): 마을 북동쪽 터. 짓기 전에는 말뚝과 줄로 둘러친 빈 터에 통나무와 돌이 쌓여 있고,
## 지으면 진짜 집(VillageBuilder.house, 2층 반목조)이 아래에서부터 한 조각씩 놓이며 올라간다.
## 문 옆 검집 걸이에 산 검집이 단계마다 하나씩 걸린다. 세계에 글자는 없다.
## 마을(lobby.gd)이 놓고, 막힘은 마을이 rect()로 받아 밀어낸다(규칙 밖, 꾸밈).

## 조각이 몇 개 놓일 때마다(소리·먼지용, 월드 자리).
signal piece_placed(at: Vector3)
## 집이 다 올라갔다.
signal raised()

## 집 너비 × 깊이(m). 앞(+Z)이 남쪽 광장을 본다.
const SIZE: Vector2 = Vector2(5.0, 4.0)
## 다 올라가는 데 걸리는 시간(초), 조각 하나가 떨어져 자리를 잡는 시간, 떨어지기 시작하는 높이(m).
const RAISE_TIME: float = 3.2
const DROP_TIME: float = 0.24
const DROP_FROM: float = 0.9
## 검집 걸이: 집 앞에서의 자리(집 기준 m)와 못 수(검집 단계 수).
const RACK_AT: Vector3 = Vector3(1.55, 0.0, 2.75)
const PEGS: int = 2

var _rng := RandomNumberGenerator.new()
var _site: Node3D = null
var _house: Node3D = null
var _rack: Node3D = null
var _sheaths: Array[Node3D] = []
## 올리는 중인 조각: [MeshInstance3D, 제자리(부모 기준), 나올 때(초)]
var _pieces: Array = []
var _t: float = -1.0
var _shown: int = 0
var _chimney: Vector3 = Vector3.ZERO


## 터나 집을 만든다(트리에 넣은 뒤 부른다). built면 집이 이미 서 있다(움직임 없이).
func build(built: bool, level: int) -> void:
	if built:
		_make_house()
		VillageBuilder.smoke(get_parent() as Node3D, _chimney, 0.8)
	else:
		_make_site()
	set_level(level)


## 집이 막는 칸(칸 좌표, 마을 _rects에 넣는다). 짓기 전이면 쌓아 둔 통나무만.
func rect(center_cell: Vector2) -> Rect2:
	if _house:
		var half := SIZE / Grid.CELL / 2.0
		return Rect2(center_cell - half - Vector2(0.15, 0.15), half * 2.0 + Vector2(0.3, 0.3))
	return Rect2(center_cell + Vector2(-1.15, -0.55), Vector2(1.0, 0.7))


## 걸이의 검집 수(산 단계). 집이 없으면 아무것도 안 건다.
func set_level(level: int) -> void:
	for i in _sheaths.size():
		_sheaths[i].visible = i < level


## 지금 집을 올린다: 터를 걷고, 집의 조각을 아래(가운데 높이)부터 차례로 떨어뜨려 놓는다.
func raise() -> void:
	if _house != null:
		return
	if _site:
		_site.queue_free()
		_site = null
	_make_house()
	_pieces = []
	var all: Array = []
	_collect(_house, all)
	_collect(_rack, all)
	all.sort_custom(func(a: MeshInstance3D, b: MeshInstance3D) -> bool:
		var ya: float = _bottom(a)
		var yb: float = _bottom(b)
		return ya < yb - 0.01 or (absf(ya - yb) <= 0.01 and a.global_position.x < b.global_position.x))
	var n: int = all.size()
	for i in n:
		var mi: MeshInstance3D = all[i]
		_pieces.append([mi, mi.position, RAISE_TIME * float(i) / float(maxi(1, n - 1))])
		mi.visible = false
	_t = 0.0
	_shown = 0


func raising() -> bool:
	return _t >= 0.0


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	var landed_now: int = 0
	for p in _pieces:
		var mi: MeshInstance3D = p[0]
		var home: Vector3 = p[1]
		var at: float = float(p[2])
		if _t < at:
			continue
		var k: float = clampf((_t - at) / DROP_TIME, 0.0, 1.0)
		if not mi.visible:
			mi.visible = true
			_shown += 1
			if _shown % 7 == 1:
				landed_now += 1
		mi.position = home + Vector3(0.0, DROP_FROM * (1.0 - k * k), 0.0)   # 떨어지며 빨라진다
	if landed_now > 0:
		piece_placed.emit(global_position + Vector3(_rng.randf_range(-2.0, 2.0), 0.3, _rng.randf_range(-1.5, 1.5)))
	if _t >= RAISE_TIME + DROP_TIME:
		for p in _pieces:
			(p[0] as MeshInstance3D).position = p[1]
		_pieces = []
		_t = -1.0
		VillageBuilder.smoke(get_parent() as Node3D, _chimney, 0.8)
		raised.emit()


# ---------------------------------------------------------------- 안쪽

func _make_house() -> void:
	_rng.seed = 2111   # 마을 꾸밈(_deco)과 따로: 집 모양이 늘 같다
	_house = Node3D.new()
	add_child(_house)
	_chimney = VillageBuilder.house(_house, Vector3.ZERO, 0.0, SIZE, true, _rng)
	# 문 앞 돌계단과 처마 밑 등
	VillageBuilder.box(_house, Vector3(1.6, 0.16, 0.7), Vector3(-SIZE.x * 0.18, 0.08, SIZE.y / 2.0 + 0.35), VillageBuilder.stone())
	_make_rack()


## 검집 걸이: 두 기둥과 가로대, 못마다 검집(가죽 집, 쇠 끝, 손잡이). 산 단계만 보인다.
func _make_rack() -> void:
	_rack = Node3D.new()
	_rack.position = RACK_AT
	add_child(_rack)
	var wood := VillageBuilder.timber()
	var w: float = 1.3
	for sx in [-1.0, 1.0]:
		VillageBuilder.box(_rack, Vector3(0.12, 1.75, 0.12), Vector3(sx * w / 2.0, 0.875, 0.0), wood)
	VillageBuilder.box(_rack, Vector3(w + 0.2, 0.12, 0.14), Vector3(0.0, 1.62, 0.0), wood)
	VillageBuilder.box(_rack, Vector3(w, 0.08, 0.1), Vector3(0.0, 0.35, 0.0), wood)
	var leather := VillageBuilder.plain(Color(0.17, 0.09, 0.05), 0.7)
	var iron := VillageBuilder.plain(Color(0.42, 0.4, 0.37), 0.45, 0.8)
	var grip := VillageBuilder.plain(Color(0.08, 0.06, 0.05), 0.8)
	_sheaths = []
	for i in PEGS:
		var x: float = lerpf(-w / 2.0 + 0.35, w / 2.0 - 0.35, float(i) / float(maxi(1, PEGS - 1)))
		VillageBuilder.box(_rack, Vector3(0.04, 0.04, 0.14), Vector3(x, 1.52, 0.1), iron)   # 못
		var s := Node3D.new()
		s.position = Vector3(x, 0.0, 0.12)
		s.rotation.z = (0.06 if i % 2 == 0 else -0.05)
		_rack.add_child(s)
		VillageBuilder.box(s, Vector3(0.1, 0.98, 0.055), Vector3(0.0, 0.98, 0.0), leather)    # 집
		VillageBuilder.box(s, Vector3(0.115, 0.09, 0.065), Vector3(0.0, 0.52, 0.0), iron)     # 끝 쇠
		VillageBuilder.box(s, Vector3(0.12, 0.07, 0.07), Vector3(0.0, 1.44, 0.0), iron)       # 아가리 쇠
		VillageBuilder.box(s, Vector3(0.05, 0.03, 0.12), Vector3(0.0, 1.2, 0.04), leather)    # 띠
		VillageBuilder.box(s, Vector3(0.3, 0.045, 0.06), Vector3(0.0, 1.5, 0.0), iron)        # 코등이
		VillageBuilder.cyl(s, 0.022, 0.024, 0.2, Vector3(0.0, 1.62, 0.0), grip, 8)          # 손잡이
		VillageBuilder.ball(s, 0.038, Vector3(0.0, 1.74, 0.0), iron)                         # 머리
		_sheaths.append(s)


func _make_site() -> void:
	_site = Node3D.new()
	add_child(_site)
	var dirt := VillageBuilder.dirt()
	VillageBuilder.box(_site, Vector3(SIZE.x + 0.6, 0.04, SIZE.y + 0.6), Vector3(0.0, 0.025, 0.0), dirt)
	var wood := VillageBuilder.timber()
	var hx: float = SIZE.x / 2.0
	var hz: float = SIZE.y / 2.0
	var corners := [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)]
	for c in corners:
		VillageBuilder.box(_site, Vector3(0.09, 0.85, 0.09), c + Vector3(0, 0.42, 0), wood, Vector3(0.0, 0.0, _rng.randf_range(-0.06, 0.06)))
	var rope := VillageBuilder.plain(Color(0.42, 0.34, 0.22), 0.9)
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		if i == 2:   # 앞(남쪽) 줄은 가운데가 처진다: 둘로 나눠 건다
			var mid := (a + b) / 2.0 + Vector3(0, -0.18, 0)
			_rope(rope, a + Vector3(0, 0.7, 0), mid + Vector3(0, 0.7, 0))
			_rope(rope, mid + Vector3(0, 0.7, 0), b + Vector3(0, 0.7, 0))
		else:
			_rope(rope, a + Vector3(0, 0.7, 0), b + Vector3(0, 0.7, 0))
	# 쌓아 둔 통나무(셋 · 둘)와 돌무더기, 바닥 돌 몇 개
	var log_mat := VillageBuilder.bark()
	var pile := Vector3(-1.3, 0.0, -0.4)
	for i in 3:
		var l := VillageBuilder.cyl(_site, 0.16, 0.17, 2.4, pile + Vector3(0, 0.17, -0.36 + 0.36 * i), log_mat, 10)
		l.rotation.z = PI / 2.0
	for i in 2:
		var l := VillageBuilder.cyl(_site, 0.15, 0.16, 2.3, pile + Vector3(0.05, 0.46, -0.18 + 0.36 * i), log_mat, 10)
		l.rotation.z = PI / 2.0
	for i in 5:
		VillageBuilder.rock(_site, Vector3(1.2 + _rng.randf_range(-0.35, 0.35), 0.0, -0.6 + _rng.randf_range(-0.35, 0.35)), _rng, 0.45)
	var stone := VillageBuilder.stone()
	for i in 4:
		VillageBuilder.box(_site, Vector3(0.5, 0.25, 0.35), Vector3(-hx + 0.5 + i * 1.3, 0.12, -hz + 0.25), stone, Vector3(0, _rng.randf_range(-0.2, 0.2), 0))


func _rope(m: Material, a: Vector3, b: Vector3) -> void:
	var d: Vector3 = b - a
	var len: float = d.length()
	VillageBuilder.box(_site, Vector3(0.03, 0.03, len), (a + b) / 2.0, m, Vector3(-asin(d.y / len), atan2(d.x, d.z), 0.0))


func _collect(n: Node, out: Array) -> void:
	if n == null:
		return
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)


## 조각의 놓이는 높이: 가운데 높이(굴뚝처럼 긴 것이 처음부터 우뚝 서지 않게).
func _bottom(mi: MeshInstance3D) -> float:
	var box: AABB = mi.global_transform * mi.get_aabb()
	return box.get_center().y
