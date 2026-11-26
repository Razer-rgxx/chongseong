class_name BuildingPlot
extends Plot
## 바깥 터의 마을 건물(2026-11-21 마을 키우기 2단계): BuildingData.kind대로 몸을 만든다.
## 오두막은 낮은 반목조 집과 장작, 나무꾼 움막은 열린 헛간(기둥과 지붕)에 쌓인 통나무와 모탕·도끼,
## 석공 마당은 돌벽 헛간에 다듬은 돌 더미와 작업대. 짓기 전 터에는 그 건물에 쓸 더미가 쌓여 있다.

var bd: BuildingData = null
## 돌담(kind wall)이 따라 세울 목책 줄: [[칸 from, 칸 to], …](마을이 넣는다).
var wall_lines: Array = []


## 균열에 망가진 모습(docs/rift_raid.md): 재질을 검게 그을리고, 지붕 높이의 조각 일부를 떼고, 부서진 더미와 검은 연기를 얹는다. build 전에 켠다.
var ruined: bool = false
var _ruin: Node3D = null
var _hidden: Array[MeshInstance3D] = []
var _orig: Dictionary = {}   ## 그을리기 전 재질(MeshInstance3D → 재질, 되돌릴 때)


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
		&"tower":
			_tower(root)
			return Vector3.INF
		&"forge":
			var st := VillageBuilder.stone()
			VillageBuilder.box(root, Vector3(w, 2.6, d), Vector3(0, 1.3, 0), st)
			var slope: float = 0.5
			for sz in [-1.0, 1.0]:
				VillageBuilder.box(root, Vector3(w + 0.5, 0.12, d / 2.0 / cos(slope) + 0.4), Vector3(0, 2.6 + d / 4.0 * tan(slope), sz * d / 4.0), VillageBuilder.roof(), Vector3(sz * -slope, 0, 0))
			VillageBuilder.box(root, Vector3(0.9, 4.6, 0.9), Vector3(w / 2.0 - 0.7, 2.3, -d / 2.0 + 0.6), st)   # 굴뚝
			VillageBuilder.box(root, Vector3(1.3, 1.5, 0.1), Vector3(-w * 0.15, 0.75, d / 2.0 + 0.02), VillageBuilder.glow(Color(1.0, 0.42, 0.14), 2.4))   # 열린 아궁이 빛
			var iron := VillageBuilder.plain(Color(0.2, 0.2, 0.21), 0.45, 0.85)
			VillageBuilder.cyl(root, 0.3, 0.36, 0.55, Vector3(1.0, 0.27, d / 2.0 + 1.0), VillageBuilder.bark(), 10)   # 모루 받침
			VillageBuilder.box(root, Vector3(0.7, 0.22, 0.3), Vector3(1.0, 0.66, d / 2.0 + 1.0), iron)            # 모루
			VillageBuilder.box(root, Vector3(0.22, 0.14, 0.18), Vector3(1.42, 0.66, d / 2.0 + 1.0), iron)
			var o := OmniLight3D.new()
			o.light_color = Color(1.0, 0.5, 0.2)
			o.omni_range = 6.0
			o.light_energy = 1.4
			o.position = Vector3(-w * 0.15, 1.0, d / 2.0 + 0.6)
			root.add_child(o)
			return to_global(Vector3(w / 2.0 - 0.7, 4.7, -d / 2.0 + 0.6))
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


## 망루: 네 기둥(위로 좁아진다)과 엇갈린 버팀대, 높은 마루와 난간, 뾰족 지붕, 사다리.
func _tower(root: Node3D) -> void:
	var wood := VillageBuilder.timber()
	var h: float = 7.0
	var lo: float = size.x / 2.0
	var hi: float = lo * 0.7
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var a := Vector3(sx * lo, 0.0, sz * lo)
			var b := Vector3(sx * hi, h, sz * hi)
			var mid: Vector3 = (a + b) / 2.0
			var dv: Vector3 = b - a
			VillageBuilder.box(root, Vector3(0.24, dv.length(), 0.24), mid, wood, Vector3(atan2(dv.z, dv.y), 0.0, -atan2(dv.x, dv.y)))
	for k in 3:   # 층마다 가로대
		var y: float = 1.4 + k * 2.0
		var r: float = lerpf(lo, hi, y / h)
		for sz in [-1.0, 1.0]:
			VillageBuilder.box(root, Vector3(r * 2.0, 0.14, 0.14), Vector3(0, y, sz * r), wood)
			VillageBuilder.box(root, Vector3(0.14, 0.14, r * 2.0), Vector3(sz * r, y, 0), wood)
	VillageBuilder.box(root, Vector3(hi * 2.0 + 0.8, 0.16, hi * 2.0 + 0.8), Vector3(0, h, 0), VillageBuilder.planks())   # 마루
	for sx in [-1.0, 1.0]:   # 난간
		VillageBuilder.box(root, Vector3(0.1, 0.9, hi * 2.0 + 0.8), Vector3(sx * (hi + 0.4), h + 0.45, 0), wood)
		VillageBuilder.box(root, Vector3(hi * 2.0 + 0.8, 0.9, 0.1), Vector3(0, h + 0.45, sx * (hi + 0.4)), wood)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			VillageBuilder.box(root, Vector3(0.12, 1.6, 0.12), Vector3(sx * (hi + 0.35), h + 0.8, sz * (hi + 0.35)), wood)
	var cone := MeshInstance3D.new()   # 뾰족 지붕(네모뿔)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = (hi + 0.8) * 1.414
	cm.height = 1.6
	cm.radial_segments = 4
	cone.mesh = cm
	cone.material_override = VillageBuilder.roof()
	cone.position = Vector3(0, h + 2.4, 0)
	cone.rotation.y = PI / 4.0
	root.add_child(cone)
	for k in 12:   # 사다리(앞)
		VillageBuilder.box(root, Vector3(0.6, 0.06, 0.06), Vector3(0, 0.4 + k * 0.55, lo + 0.25 - k * 0.025), wood)
	for sx in [-1.0, 1.0]:
		VillageBuilder.box(root, Vector3(0.08, h, 0.08), Vector3(sx * 0.3, h / 2.0, lo + 0.1), wood, Vector3(-0.04, 0, 0))


## 모탕(통나무 토막)과 박힌 도끼.
func _chopping(root: Node3D, at: Vector3) -> void:
	var bark := VillageBuilder.bark()
	VillageBuilder.cyl(root, 0.34, 0.38, 0.55, at + Vector3(0, 0.27, 0), bark, 10)
	VillageBuilder.cyl(root, 0.33, 0.33, 0.02, at + Vector3(0, 0.555, 0), VillageBuilder.plain(Color(0.6, 0.45, 0.3), 0.9), 10)
	VillageBuilder.box(root, Vector3(0.05, 0.75, 0.05), at + Vector3(0.1, 0.85, 0.05), VillageBuilder.timber(), Vector3(0.0, 0.0, -0.5))
	VillageBuilder.box(root, Vector3(0.22, 0.14, 0.03), at + Vector3(-0.05, 0.6, 0.05), VillageBuilder.plain(Color(0.4, 0.39, 0.37), 0.5, 0.8), Vector3(0.0, 0.0, -0.5))


# ---------------------------------------------------------------- 균열에 망가진 모습

func _make_root() -> void:
	super._make_root()
	if ruined:
		_ruin_on()


func _smoke() -> void:
	if not ruined:
		super._smoke()


## 망가뜨린다(이미 서 있는 몸에도).
func set_ruined(on: bool) -> void:
	if on == ruined:
		return
	ruined = on
	if _body == null:
		return
	if on:
		_ruin_on()
	else:
		_ruin_off()
		_smoke()


func _ruin_on() -> void:
	var all: Array = []
	_collect(_body, all)
	var r := RandomNumberGenerator.new()
	r.seed = 9001 + int(absf(global_position.x) * 7.0 + absf(global_position.z) * 13.0)
	_hidden = []
	_orig = {}
	var charred: Dictionary = {}   # 같은 재질은 같은 그을린 복사본을 쓴다
	for mi in all:
		var m: MeshInstance3D = mi
		var base: Material = m.material_override if m.material_override != null else m.get_active_material(0)
		if base is StandardMaterial3D:
			_orig[m] = m.material_override
			if not charred.has(base):
				var c: StandardMaterial3D = (base as StandardMaterial3D).duplicate()
				c.albedo_color = c.albedo_color.darkened(0.7)
				c.emission_enabled = false
				charred[base] = c
			m.material_override = charred[base]
		if _mid_y(m) > size.y * 0.55 + 1.2 and m.position.y > 1.8 and r.randf() < 0.45:   # 지붕 조각이 떨어져 나갔다
			m.visible = false
			_hidden.append(m)
	_ruin = Node3D.new()
	add_child(_ruin)
	var dark := VillageBuilder.plain(Color(0.1, 0.085, 0.075), 0.95)
	var ember := VillageBuilder.glow(Color(1.0, 0.36, 0.1), 1.6)
	for i in 14:   # 부서진 판자·돌 더미
		var sz := Vector3(r.randf_range(0.25, 0.9), r.randf_range(0.08, 0.22), r.randf_range(0.12, 0.3))
		var at := Vector3(r.randf_range(-size.x * 0.7, size.x * 0.7), sz.y / 2.0, r.randf_range(-size.y * 0.7, size.y * 0.7))
		VillageBuilder.box(_ruin, sz, at, dark, Vector3(0.0, r.randf() * TAU, r.randf_range(-0.25, 0.25)))
	for i in 3:
		VillageBuilder.box(_ruin, Vector3(0.18, 0.1, 0.18), Vector3(r.randf_range(-size.x * 0.4, size.x * 0.4), 0.12, r.randf_range(-size.y * 0.3, size.y * 0.5)), ember)
	var o := OmniLight3D.new()   # 잉걸 빛(약하게)
	o.light_color = Color(1.0, 0.4, 0.15)
	o.omni_range = 4.0
	o.light_energy = 0.5
	o.position = Vector3(0, 0.6, 0)
	o.shadow_enabled = false
	_ruin.add_child(o)
	VillageBuilder.smoke(_ruin, Vector3(r.randf_range(-0.6, 0.6), 1.4, 0.0), 1.3)   # 검은 연기


func _ruin_off() -> void:
	if _ruin != null:
		_ruin.queue_free()
		_ruin = null
	for m in _orig:
		if is_instance_valid(m):
			(m as MeshInstance3D).material_override = _orig[m]
	_orig = {}
	for m in _hidden:
		if is_instance_valid(m):
			m.visible = true
	_hidden = []
