class_name BuildingPlot
extends Plot
## 바깥 터의 마을 건물(2026-11-21 마을 키우기 2단계): BuildingData.kind대로 몸을 만든다.
## 오두막은 낮은 반목조 집과 장작, 나무꾼 움막은 열린 헛간(기둥과 지붕)에 쌓인 통나무와 모탕·도끼,
## 석공 마당은 돌벽 헛간에 다듬은 돌 더미와 작업대. 짓기 전 터에는 그 건물에 쓸 더미가 쌓여 있다.

var bd: BuildingData = null
## 돌담(kind wall)이 따라 세울 목책 줄: [[칸 from, 칸 to], …](마을이 넣는다).
var wall_lines: Array = []


func setup(p_bd: BuildingData) -> void:
	bd = p_bd
	size = bd.size


## 돌담은 목책 줄 위에 서니(목책의 막힘을 그대로 쓴다) 터 자리는 막지 않는다.
func rect(center_cell: Vector2) -> Rect2:
	if bd.kind == &"wall" and is_built():
		return Rect2(Vector2(-100, -100), Vector2.ZERO)
	return super.rect(center_cell)


func _make_body(root: Node3D) -> Vector3:
	var w: float = size.x
	var d: float = size.y
	match bd.kind:
		&"wall":
			raise_time = 5.5
			for l in wall_lines:
				VillageBuilder.stone_wall(root, Grid.cells_to_world(l[0]) - position, Grid.cells_to_world(l[1]) - position)
			return Vector3.INF
		&"longhouse":
			var top: Vector3 = VillageBuilder.house(root, Vector3.ZERO, 0.0, size, false, _rng)
			VillageBuilder.box(root, Vector3(1.4, 0.14, 0.6), Vector3(-w * 0.18, 0.07, d / 2.0 + 0.3), VillageBuilder.stone())
			VillageBuilder.bench(root, Vector3(w * 0.28, 0.0, d / 2.0 + 0.55), 0.0)
			VillageBuilder.firewood(root, Vector3(-w / 2.0 - 0.5, 0.0, 0.2), PI / 2.0)
			VillageBuilder.firewood(root, Vector3(w / 2.0 + 0.5, 0.0, -0.4), -PI / 2.0)
			return top
		&"woodcutter":
			_shed(root, w, d, VillageBuilder.timber())
			var log_mat := VillageBuilder.bark()
			for row in 3:   # 헛간 안에 쌓인 통나무
				for k in 4 - row:
					var l := VillageBuilder.cyl(root, 0.17, 0.18, 2.6, Vector3(-0.6, 0.2 + row * 0.32, -d / 2.0 + 0.6 + k * 0.36 + row * 0.18), log_mat, 10)
					l.rotation.z = PI / 2.0
			VillageBuilder.firewood(root, Vector3(1.2, 0.0, -d / 2.0 + 0.5), 0.0)
			_chopping(root, Vector3(1.4, 0.0, d / 2.0 + 0.9))
			return Vector3.INF
		&"mason":
			_shed(root, w, d, VillageBuilder.stone(), true)
			var cut := VillageBuilder.plain(Color(0.6, 0.58, 0.54), 0.9)
			for row in 3:   # 다듬은 돌 더미
				for k in 3:
					VillageBuilder.box(root, Vector3(0.6, 0.3, 0.4), Vector3(-1.2 + k * 0.62 + row * 0.1, 0.15 + row * 0.3, -d / 2.0 + 0.7), cut, Vector3(0, _rng.randf_range(-0.05, 0.05), 0))
			# 작업대와 그 위 돌·망치
			var wood := VillageBuilder.timber()
			VillageBuilder.box(root, Vector3(1.5, 0.12, 0.7), Vector3(1.0, 0.8, d / 2.0 + 0.8), wood)
			for sx in [-0.6, 0.6]:
				for sz in [-0.25, 0.25]:
					VillageBuilder.box(root, Vector3(0.1, 0.8, 0.1), Vector3(1.0 + sx, 0.4, d / 2.0 + 0.8 + sz), wood)
			VillageBuilder.box(root, Vector3(0.5, 0.28, 0.35), Vector3(0.9, 1.0, d / 2.0 + 0.8), cut, Vector3(0, 0.2, 0))
			VillageBuilder.box(root, Vector3(0.06, 0.06, 0.45), Vector3(1.4, 0.89, d / 2.0 + 0.7), wood, Vector3(0, 0.6, 0))
			VillageBuilder.box(root, Vector3(0.12, 0.1, 0.1), Vector3(1.53, 0.9, d / 2.0 + 0.88), VillageBuilder.plain(Color(0.35, 0.34, 0.33), 0.5, 0.8))
			return Vector3.INF
		_:
			var top: Vector3 = VillageBuilder.house(root, Vector3.ZERO, 0.0, size, false, _rng)
			VillageBuilder.box(root, Vector3(1.4, 0.14, 0.6), Vector3(-w * 0.18, 0.07, d / 2.0 + 0.3), VillageBuilder.stone())   # 문 앞 돌
			VillageBuilder.firewood(root, Vector3(w / 2.0 + 0.5, 0.0, 0.4), PI / 2.0)
			VillageBuilder.bench(root, Vector3(w * 0.22, 0.0, d / 2.0 + 0.55), 0.0)
			return top


func _site_extra(site: Node3D) -> void:
	match bd.kind:
		&"wall":
			var stone := VillageBuilder.stone()
			for i in 9:
				VillageBuilder.box(site, Vector3(0.6, 0.32, 0.42), Vector3(-0.7 + (i % 3) * 0.62, 0.16 + (i / 3) * 0.32, -0.1 + 0.08 * (i % 2)), stone, Vector3(0, _rng.randf_range(-0.15, 0.15), 0))
		&"mason":
			var stone := VillageBuilder.stone()
			for i in 6:
				VillageBuilder.box(site, Vector3(0.55, 0.3, 0.4), Vector3(-1.4 + (i % 3) * 0.6, 0.15 + (i / 3) * 0.3, -0.5), stone, Vector3(0, _rng.randf_range(-0.2, 0.2), 0))
			for i in 4:
				VillageBuilder.rock(site, Vector3(1.0 + _rng.randf_range(-0.4, 0.4), 0.0, 0.2 + _rng.randf_range(-0.4, 0.4)), _rng, 0.5)
		_:
			_logs_and_stones(site, Vector3(-1.2, 0.0, -0.4))


## 헛간: 네 기둥과 들보, 한쪽으로 기운 판자 지붕. stone이면 뒤와 옆 아래에 돌벽.
func _shed(root: Node3D, w: float, d: float, post_mat: Material, stone_walls: bool = false) -> void:
	var wood := VillageBuilder.timber()
	var h_front: float = 2.6
	var h_back: float = 2.0
	for sx in [-1.0, 1.0]:
		VillageBuilder.box(root, Vector3(0.2, h_front, 0.2), Vector3(sx * (w / 2.0 - 0.1), h_front / 2.0, d / 2.0 - 0.1), wood)
		VillageBuilder.box(root, Vector3(0.2, h_back, 0.2), Vector3(sx * (w / 2.0 - 0.1), h_back / 2.0, -d / 2.0 + 0.1), wood)
	VillageBuilder.box(root, Vector3(w, 0.18, 0.2), Vector3(0, h_front - 0.09, d / 2.0 - 0.1), wood)
	VillageBuilder.box(root, Vector3(w, 0.18, 0.2), Vector3(0, h_back - 0.09, -d / 2.0 + 0.1), wood)
	var slope: float = atan2(h_front - h_back, d)
	var len: float = sqrt(d * d + pow(h_front - h_back, 2.0)) + 0.8
	VillageBuilder.box(root, Vector3(w + 0.6, 0.08, len), Vector3(0, (h_front + h_back) / 2.0 + 0.06, 0), VillageBuilder.planks(), Vector3(slope, 0, 0))
	if stone_walls:
		var st := VillageBuilder.stone()
		VillageBuilder.box(root, Vector3(w, 1.4, 0.35), Vector3(0, 0.7, -d / 2.0 + 0.18), st)
		for sx in [-1.0, 1.0]:
			VillageBuilder.box(root, Vector3(0.35, 1.2, d - 0.4), Vector3(sx * (w / 2.0 - 0.18), 0.6, 0), st)
	else:
		VillageBuilder.box(root, Vector3(w - 0.2, 1.6, 0.08), Vector3(0, 0.8, -d / 2.0 + 0.12), VillageBuilder.planks())   # 뒤 판자벽


## 모탕(통나무 토막)과 박힌 도끼.
func _chopping(root: Node3D, at: Vector3) -> void:
	var bark := VillageBuilder.bark()
	VillageBuilder.cyl(root, 0.34, 0.38, 0.55, at + Vector3(0, 0.27, 0), bark, 10)
	VillageBuilder.cyl(root, 0.33, 0.33, 0.02, at + Vector3(0, 0.555, 0), VillageBuilder.plain(Color(0.6, 0.45, 0.3), 0.9), 10)
	VillageBuilder.box(root, Vector3(0.05, 0.75, 0.05), at + Vector3(0.1, 0.85, 0.05), VillageBuilder.timber(), Vector3(0.0, 0.0, -0.5))
	VillageBuilder.box(root, Vector3(0.22, 0.14, 0.03), at + Vector3(-0.05, 0.6, 0.05), VillageBuilder.plain(Color(0.4, 0.39, 0.37), 0.5, 0.8), Vector3(0.0, 0.0, -0.5))
