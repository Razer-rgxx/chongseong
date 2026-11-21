class_name Plot
extends Node3D
## 마을의 터 하나(2026-11-21): 짓기 전에는 말뚝과 줄로 둘러친 맨땅, 지으면 몸(집)이 아래부터 한 조각씩 떨어져 놓이며 올라간다.
## 검 보관집(StorageHouse)과 바깥 터의 건물(BuildingPlot)이 이것을 잇는다. 몸은 _make_body가, 터의 더미는 _site_extra가 만든다.
## 막힘은 마을이 rect()로 받아 밀어낸다(규칙 밖, 꾸밈). 세계에 글자는 없다.

## 조각이 몇 개 놓일 때마다(소리·먼지용, 월드 자리).
signal piece_placed(at: Vector3)
## 몸이 다 올라갔다.
signal raised()

## 다 올라가는 데 걸리는 시간(초), 조각 하나가 떨어져 자리를 잡는 시간, 떨어지기 시작하는 높이(m).
const RAISE_TIME: float = 3.2
const DROP_TIME: float = 0.24
const DROP_FROM: float = 0.9

## 몸의 너비 × 깊이(m). 앞(+Z)이 facing 쪽.
var size: Vector2 = Vector2(5.0, 4.0)
var _rng := RandomNumberGenerator.new()
var _site: Node3D = null
var _body: Node3D = null
## 올리는 중인 조각: [MeshInstance3D, 제자리(부모 기준), 나올 때(초)]
var _pieces: Array = []
var _t: float = -1.0
var _shown: int = 0
## 굴뚝 끝(월드). 없으면 Vector3.INF(연기 없음).
var _chimney: Vector3 = Vector3.INF


## 터나 몸을 만든다(트리에 넣은 뒤 부른다). built면 몸이 이미 서 있다(움직임 없이).
func build(built: bool) -> void:
	if built:
		_make_root()
		_smoke()
	else:
		_make_site()


func is_built() -> bool:
	return _body != null


## 막는 칸(칸 좌표, 마을 _rects에 넣는다). 짓기 전이면 터의 더미만.
func rect(center_cell: Vector2) -> Rect2:
	if _body:
		var half: Vector2 = _turned(size) / Grid.CELL / 2.0
		return Rect2(center_cell - half - Vector2(0.15, 0.15), half * 2.0 + Vector2(0.3, 0.3))
	return Rect2(center_cell + Vector2(-1.15, -0.55), Vector2(1.0, 0.7))


## 지금 몸을 올린다: 터를 걷고, 조각을 아래(가운데 높이)부터 차례로 떨어뜨려 놓는다.
func raise() -> void:
	if _body != null:
		return
	if _site:
		_site.queue_free()
		_site = null
	_make_root()
	_pieces = []
	var all: Array = []
	_collect(_body, all)
	all.sort_custom(func(a: MeshInstance3D, b: MeshInstance3D) -> bool:
		var ya: float = _mid_y(a)
		var yb: float = _mid_y(b)
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
		_smoke()
		raised.emit()


# ---------------------------------------------------------------- 잇는 쪽이 바꾸는 것

## 몸을 root(이 노드 기준, 앞 +Z)에 만든다. 굴뚝 끝(월드)이 있으면 돌려준다(없으면 Vector3.INF).
func _make_body(_root: Node3D) -> Vector3:
	return Vector3.INF


## 터에 쌓아 둔 더미(짓기 전).
func _site_extra(_site_node: Node3D) -> void:
	pass


# ---------------------------------------------------------------- 안쪽

func _make_root() -> void:
	_rng.seed = 2111 + int(absf(global_position.x) * 7.0 + absf(global_position.z) * 13.0)   # 마을 꾸밈과 따로: 늘 같은 모양
	_body = Node3D.new()
	add_child(_body)
	_chimney = _make_body(_body)


func _smoke() -> void:
	if _chimney != Vector3.INF:
		VillageBuilder.smoke(get_parent() as Node3D, _chimney, 0.8)


func _make_site() -> void:
	_rng.seed = 3111 + int(absf(global_position.x) * 7.0 + absf(global_position.z) * 13.0)
	_site = Node3D.new()
	add_child(_site)
	VillageBuilder.box(_site, Vector3(size.x + 0.6, 0.04, size.y + 0.6), Vector3(0.0, 0.025, 0.0), VillageBuilder.dirt())
	var wood := VillageBuilder.timber()
	var hx: float = size.x / 2.0
	var hz: float = size.y / 2.0
	var corners := [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)]
	for c in corners:
		VillageBuilder.box(_site, Vector3(0.09, 0.85, 0.09), c + Vector3(0, 0.42, 0), wood, Vector3(0.0, 0.0, _rng.randf_range(-0.06, 0.06)))
	var rope := VillageBuilder.plain(Color(0.42, 0.34, 0.22), 0.9)
	for i in 4:
		var a: Vector3 = corners[i] + Vector3(0, 0.7, 0)
		var b: Vector3 = corners[(i + 1) % 4] + Vector3(0, 0.7, 0)
		if i == 2:   # 앞 줄은 가운데가 처진다
			var mid := (a + b) / 2.0 + Vector3(0, -0.18, 0)
			_rope(rope, a, mid)
			_rope(rope, mid, b)
		else:
			_rope(rope, a, b)
	_site_extra(_site)


func _rope(m: Material, a: Vector3, b: Vector3) -> void:
	var d: Vector3 = b - a
	var len: float = d.length()
	VillageBuilder.box(_site, Vector3(0.03, 0.03, len), (a + b) / 2.0, m, Vector3(-asin(d.y / len), atan2(d.x, d.z), 0.0))


## 이 노드가 Y로 돈 만큼 너비·깊이를 바꾼다(90도 돌면 칸에서 가로세로가 바뀐다).
func _turned(v: Vector2) -> Vector2:
	var q: float = fposmod(rotation.y, PI)
	return Vector2(v.y, v.x) if absf(q - PI / 2.0) < 0.4 else v


## 통나무 더미(셋 · 둘)와 돌무더기: 터마다 쓰는 흔한 더미.
func _logs_and_stones(site: Node3D, at: Vector3) -> void:
	var log_mat := VillageBuilder.bark()
	for i in 3:
		var l := VillageBuilder.cyl(site, 0.16, 0.17, 2.4, at + Vector3(0, 0.17, -0.36 + 0.36 * i), log_mat, 10)
		l.rotation.z = PI / 2.0
	for i in 2:
		var l := VillageBuilder.cyl(site, 0.15, 0.16, 2.3, at + Vector3(0.05, 0.46, -0.18 + 0.36 * i), log_mat, 10)
		l.rotation.z = PI / 2.0
	for i in 5:
		VillageBuilder.rock(site, at + Vector3(2.5 + _rng.randf_range(-0.35, 0.35), 0.0, -0.2 + _rng.randf_range(-0.35, 0.35)), _rng, 0.45)


func _collect(n: Node, out: Array) -> void:
	if n == null:
		return
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)


## 조각의 놓이는 높이: 가운데 높이(굴뚝처럼 긴 것이 처음부터 우뚝 서지 않게).
func _mid_y(mi: MeshInstance3D) -> float:
	var box: AABB = mi.global_transform * mi.get_aabb()
	return box.get_center().y
