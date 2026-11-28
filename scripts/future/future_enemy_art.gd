class_name FutureEnemyArt
extends RefCounted
## 녹슨 미래 구역의 적 몸(docs/stranger.md 3단계). EnemyView가 EnemyData.future일 때 부른다. 기본 도형만.
## 2026-11-25 사용자 "적 모델 … 사이버펑크풍": 검은 탄소·건메탈 판에 닳은 녹, 노랑·검정 경고 줄, 늘어진 전선,
## 몸의 모서리를 따라 가는 네온 줄(드론 청록·사수 자홍·금고지기 청록), 붉은 눈(렌즈·바이저). 네온 줄은 맞아도 하얘지지 않는다.
## 앞은 -Z. 돌려주는 것: {mats(맞으면 하얘지는 재질), eyes(눈 메시, 이름 Eye), height, arm(금고지기 오른팔 피벗, 없으면 없음)}.

const EYE: Color = Color(1.0, 0.12, 0.28)
const CYAN: Color = Color(0.0, 0.78, 1.0)
const MAGENTA: Color = Color(1.0, 0.08, 0.5)
const HAZARD: Color = Color(0.86, 0.62, 0.06)


static func _metal(c: Color, rough: float = 0.42, metal: float = 0.65) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


static func _glow(c: Color, energy: float = 2.4) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func _add(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3, rot: Vector3 = Vector3.ZERO, sc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.rotation_degrees = rot
	mi.scale = sc
	parent.add_child(mi)
	return mi


static func _box(parent: Node3D, size: Vector3, mat: Material, at: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _add(parent, b, mat, at, rot)


static func _cyl(parent: Node3D, r_top: float, r_bot: float, h: float, mat: Material, at: Vector3, rot: Vector3 = Vector3.ZERO, sides: int = 12) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	return _add(parent, c, mat, at, rot)


static func _sphere(parent: Node3D, r: float, mat: Material, at: Vector3, sc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	return _add(parent, s, mat, at, Vector3.ZERO, sc)


static func _ring(parent: Node3D, r_in: float, r_out: float, mat: Material, at: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = r_in
	t.outer_radius = r_out
	t.rings = 24
	t.ring_segments = 6
	return _add(parent, t, mat, at, rot)


## a → b 곧은 막대(전선·네온 줄·팔). 굵기 r.
static func _rod(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material, sides: int = 6) -> MeshInstance3D:
	var d: Vector3 = b - a
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = d.length()
	c.radial_segments = sides
	c.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = mat
	parent.add_child(mi)
	var up: Vector3 = d.normalized()
	var side: Vector3 = up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	mi.transform = Transform3D(Basis(side, up, side.cross(up)).orthonormalized(), (a + b) * 0.5)
	return mi


## a에서 b로 아래로 처진 전선(마디 n개).
static func _cable(parent: Node3D, a: Vector3, b: Vector3, sag: float, r: float, mat: Material, n: int = 4) -> void:
	var prev: Vector3 = a
	for i in range(1, n + 1):
		var t: float = float(i) / float(n)
		var p: Vector3 = a.lerp(b, t) + Vector3(0.0, -sag * 4.0 * t * (1.0 - t), 0.0)
		_rod(parent, prev, p, r, mat, 5)
		prev = p


## 노랑·검정 경고 줄: 판(size, 앞면이 -Z) 위에 비스듬한 띠 n개.
static func _hazard(parent: Node3D, size: Vector2, at: Vector3, yel: Material, blk: Material, n: int = 4, rot: Vector3 = Vector3.ZERO) -> void:
	var plate := Node3D.new()
	plate.position = at
	plate.rotation_degrees = rot
	parent.add_child(plate)
	_box(plate, Vector3(size.x, size.y, 0.012), blk, Vector3.ZERO)
	var step: float = size.x / float(n)
	for i in n:
		var x: float = -size.x * 0.5 + step * (float(i) + 0.5)
		_box(plate, Vector3(step * 0.45, size.y * 1.25, 0.014), yel, Vector3(x, 0.0, -0.002), Vector3(0, 0, 35)).scale = Vector3(1.0, 0.8, 1.0)


static func _eye_node(mi: MeshInstance3D) -> MeshInstance3D:
	mi.name = "Eye"
	return mi


## kind: &"wolf"이면 빠른 드론, &"grave_knight"이면 금고지기(보스), 나머지(archer)는 사수. grow는 몸 배율.
static func build(kind: StringName, body: Node3D, grow: float, c: Color) -> Dictionary:
	var root := Node3D.new()
	root.scale = Vector3.ONE * grow
	body.add_child(root)
	var m := {
		"carbon": _metal(Color(0.055, 0.06, 0.07).lerp(c, 0.12), 0.36, 0.5),
		"plate": _metal(Color(0.15, 0.16, 0.18).lerp(c, 0.3), 0.44, 0.72),
		"rust": _metal(FutureLayout.RUST, 0.85, 0.35),
		"rubber": _metal(Color(0.025, 0.025, 0.028), 0.75, 0.0),
		"yellow": _metal(HAZARD, 0.6, 0.1),
		"eye": _glow(EYE, 2.6),
	}
	var out: Dictionary
	match kind:
		&"wolf":
			out = _drone(root, m)
		&"grave_knight":
			out = _guardian(root, m)
		_:
			out = _gunner(root, m)
	out["mats"] = [m.carbon, m.plate, m.rust, m.rubber, m.yellow]
	return out


# ---------------------------------------------------------------- 드론

## 납작한 몸통에 앞 렌즈 하나, X자 팔 끝 덕트 넷(안쪽 청록 고리), 아래 총 꼬투리와 늘어진 전선.
static func _drone(root: Node3D, m: Dictionary) -> Dictionary:
	var neon: StandardMaterial3D = _glow(CYAN, 2.2)
	var y: float = 1.05
	_sphere(root, 0.27, m.carbon, Vector3(0, y, 0), Vector3(1.0, 0.62, 1.4))
	_sphere(root, 0.25, m.plate, Vector3(0, y + 0.07, 0.05), Vector3(0.92, 0.5, 1.3))
	# 등 위 칸막이 판과 닳은 녹
	_box(root, Vector3(0.05, 0.07, 0.42), m.carbon, Vector3(0, y + 0.19, 0.05))
	_box(root, Vector3(0.14, 0.02, 0.12), m.rust, Vector3(0.1, y + 0.17, 0.2), Vector3(0, 20, 0))
	_hazard(root, Vector2(0.2, 0.05), Vector3(-0.17, y + 0.08, 0.12), m.yellow, m.carbon, 3, Vector3(0, -90, -12))
	# 몸통 옆 네온 줄
	for sx in [-1.0, 1.0]:
		_rod(root, Vector3(0.26 * sx, y + 0.02, -0.25), Vector3(0.25 * sx, y + 0.03, 0.26), 0.011, neon)
	# 앞 렌즈 집과 렌즈(눈)
	_cyl(root, 0.11, 0.13, 0.14, m.carbon, Vector3(0, y - 0.01, -0.36), Vector3(90, 0, 0), 14)
	_ring(root, 0.085, 0.105, neon, Vector3(0, y - 0.01, -0.435), Vector3(90, 0, 0))
	var eye := _eye_node(_sphere(root, 0.07, m.eye, Vector3(0, y - 0.01, -0.43), Vector3(1, 1, 0.6)))
	# X자 팔과 덕트 넷
	for p in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var at := Vector3(0.5 * p.x, y + 0.04, 0.38 * p.y)
		_rod(root, Vector3(0.12 * p.x, y + 0.02, 0.1 * p.y), at, 0.03, m.carbon, 6)
		_ring(root, 0.15, 0.2, m.plate, at)
		_ring(root, 0.135, 0.15, neon, at + Vector3(0, 0.02, 0))
		_cyl(root, 0.03, 0.03, 0.06, m.rubber, at, Vector3.ZERO, 8)
		_box(root, Vector3(0.27, 0.008, 0.035), m.rubber, at + Vector3(0, 0.03, 0), Vector3(0, 30.0 * p.x * p.y, 0))
	# 아래 총 꼬투리
	_box(root, Vector3(0.1, 0.08, 0.26), m.plate, Vector3(0, y - 0.17, -0.12))
	_cyl(root, 0.022, 0.022, 0.22, m.carbon, Vector3(0, y - 0.18, -0.32), Vector3(90, 0, 0), 8)
	_ring(root, 0.018, 0.03, neon, Vector3(0, y - 0.18, -0.43), Vector3(90, 0, 0))
	# 뒤 안테나와 늘어진 전선
	_rod(root, Vector3(0.08, y + 0.1, 0.3), Vector3(0.12, y + 0.42, 0.42), 0.006, m.rubber, 4)
	_sphere(root, 0.018, m.eye, Vector3(0.12, y + 0.43, 0.42))
	_cable(root, Vector3(-0.08, y - 0.1, 0.18), Vector3(0.04, y - 0.14, -0.02), 0.16, 0.012, m.rubber)
	_cable(root, Vector3(0.1, y - 0.12, 0.25), Vector3(-0.02, y - 0.38, 0.32), 0.04, 0.01, m.rubber, 3)
	return {"eyes": [eye], "height": 1.5}


# ---------------------------------------------------------------- 사수

## 녹슨 사이보그 거리 사수: 육각 몸통에 가슴판(자홍 줄), 등에 빛나는 전지 셋과 머리로 가는 전선,
## 투구의 가로 바이저(눈)와 호흡기, 한쪽 어깨 갑옷, 두 손으로 든 긴 총(옆에 자홍 줄, 조준경).
static func _gunner(root: Node3D, m: Dictionary) -> Dictionary:
	var neon: StandardMaterial3D = _glow(MAGENTA, 2.2)
	var cell: StandardMaterial3D = _glow(Color(0.15, 1.0, 0.55), 1.6)
	# 다리: 허벅지·무릎 판·정강이·장화
	for sx in [-1.0, 1.0]:
		var x: float = 0.13 * sx
		_cyl(root, 0.085, 0.07, 0.44, m.carbon, Vector3(x, 0.7, 0.0), Vector3(0, 0, -4.0 * sx), 8)
		_box(root, Vector3(0.13, 0.12, 0.08), m.plate, Vector3(x, 0.48, -0.07), Vector3(-10, 0, 0))
		_cyl(root, 0.07, 0.06, 0.42, m.plate, Vector3(x * 1.06, 0.27, 0.02), Vector3(6, 0, 0), 8)
		_box(root, Vector3(0.14, 0.09, 0.26), m.rubber, Vector3(x * 1.08, 0.045, -0.04))
		_rod(root, Vector3(x * 1.3, 0.62, 0.05), Vector3(x * 1.3, 0.3, 0.06), 0.012, m.rubber, 4)
	# 허리와 몸통
	_box(root, Vector3(0.38, 0.14, 0.24), m.carbon, Vector3(0, 0.95, 0))
	_cyl(root, 0.27, 0.2, 0.56, m.carbon, Vector3(0, 1.27, 0), Vector3.ZERO, 6).scale = Vector3(1.0, 1.0, 0.66)
	_box(root, Vector3(0.42, 0.26, 0.06), m.plate, Vector3(0, 1.38, -0.17), Vector3(-6, 0, 0))
	_box(root, Vector3(0.16, 0.1, 0.02), m.rust, Vector3(-0.1, 1.42, -0.205), Vector3(-6, 0, 8))
	_box(root, Vector3(0.32, 0.016, 0.02), neon, Vector3(0, 1.3, -0.205))
	_box(root, Vector3(0.016, 0.2, 0.02), neon, Vector3(0.17, 1.38, -0.2), Vector3(-6, 0, 0))
	# 등 전지와 전선
	_box(root, Vector3(0.3, 0.36, 0.15), m.plate, Vector3(0, 1.3, 0.2))
	for i in 3:
		_box(root, Vector3(0.06, 0.2, 0.02), cell, Vector3(-0.08 + 0.08 * i, 1.32, 0.28))
	_hazard(root, Vector2(0.28, 0.05), Vector3(0, 1.1, 0.278), m.yellow, m.carbon, 4, Vector3(0, 180, 0))
	_cable(root, Vector3(0.12, 1.46, 0.2), Vector3(0.08, 1.66, 0.06), 0.06, 0.014, m.rubber, 3)
	_cable(root, Vector3(-0.1, 1.2, 0.24), Vector3(-0.2, 1.0, 0.06), 0.03, 0.014, m.rubber, 3)
	# 목·투구·바이저·호흡기·안테나
	_cyl(root, 0.06, 0.07, 0.1, m.rubber, Vector3(0, 1.58, 0), Vector3.ZERO, 8)
	_sphere(root, 0.145, m.plate, Vector3(0, 1.73, 0), Vector3(1.0, 1.02, 1.12))
	_box(root, Vector3(0.24, 0.07, 0.06), m.carbon, Vector3(0, 1.74, -0.135))
	var eye := _eye_node(_box(root, Vector3(0.2, 0.026, 0.02), m.eye, Vector3(0, 1.745, -0.168)))
	_box(root, Vector3(0.13, 0.08, 0.08), m.carbon, Vector3(0, 1.64, -0.11))
	for sx in [-1.0, 1.0]:
		_cyl(root, 0.025, 0.025, 0.05, m.rubber, Vector3(0.07 * sx, 1.62, -0.15), Vector3(90, 0, 0), 8)
	_rod(root, Vector3(0.12, 1.78, 0.04), Vector3(0.16, 2.02, 0.1), 0.006, m.rubber, 4)
	_sphere(root, 0.014, neon, Vector3(0.16, 2.02, 0.1))
	# 어깨 갑옷(왼쪽)과 팔
	_box(root, Vector3(0.18, 0.1, 0.24), m.plate, Vector3(-0.29, 1.53, 0), Vector3(0, 0, 18))
	_hazard(root, Vector2(0.16, 0.04), Vector3(-0.29, 1.5, -0.123), m.yellow, m.carbon, 3, Vector3(0, 0, 18))
	_rod(root, Vector3(0.27, 1.48, 0.0), Vector3(0.24, 1.24, -0.12), 0.05, m.carbon)
	_rod(root, Vector3(0.24, 1.24, -0.12), Vector3(0.18, 1.3, -0.34), 0.045, m.plate)
	_rod(root, Vector3(-0.27, 1.46, 0.0), Vector3(-0.16, 1.22, -0.2), 0.05, m.carbon)
	_rod(root, Vector3(-0.16, 1.22, -0.2), Vector3(0.12, 1.31, -0.56), 0.045, m.plate)
	# 긴 총
	var g := Node3D.new()
	g.position = Vector3(0.17, 1.33, -0.48)
	root.add_child(g)
	_box(g, Vector3(0.07, 0.12, 0.62), m.carbon, Vector3.ZERO)
	_box(g, Vector3(0.05, 0.08, 0.2), m.carbon, Vector3(0, -0.02, 0.36), Vector3(-8, 0, 0))
	_box(g, Vector3(0.05, 0.16, 0.08), m.plate, Vector3(0, -0.12, -0.06), Vector3(12, 0, 0))
	_cyl(g, 0.022, 0.022, 0.38, m.plate, Vector3(0, 0.01, -0.5), Vector3(90, 0, 0), 8)
	_ring(g, 0.024, 0.038, m.carbon, Vector3(0, 0.01, -0.66), Vector3(90, 0, 0))
	_cyl(g, 0.026, 0.026, 0.18, m.rubber, Vector3(0, 0.1, -0.05), Vector3(90, 0, 0), 8)
	_box(g, Vector3(0.012, 0.016, 0.5), neon, Vector3(0.038, 0.02, -0.02))
	return {"eyes": [eye], "height": 2.0}


# ---------------------------------------------------------------- 금고지기

## 경비 기계: 넓은 몸통 가운데 청록 반응로, 경고 줄 두른 큰 어깨, 파묻힌 머리의 둥근 붉은 눈 하나,
## 등 배기통, 오른팔은 빛 칼(어깨 피벗 arm, EnemyView._rust_pose가 휘두른다), 왼팔은 큰 주먹.
static func _guardian(root: Node3D, m: Dictionary) -> Dictionary:
	var neon: StandardMaterial3D = _glow(CYAN, 2.4)
	var blade: StandardMaterial3D = _glow(Color(0.35, 0.92, 1.0), 3.2)
	# 다리
	for sx in [-1.0, 1.0]:
		var x: float = 0.24 * sx
		_box(root, Vector3(0.2, 0.42, 0.24), m.carbon, Vector3(x, 0.78, 0.02), Vector3(8, 0, 0))
		_box(root, Vector3(0.22, 0.12, 0.16), m.plate, Vector3(x, 0.55, -0.1))
		_box(root, Vector3(0.22, 0.46, 0.26), m.plate, Vector3(x, 0.3, 0.0), Vector3(-6, 0, 0))
		_hazard(root, Vector2(0.18, 0.08), Vector3(x, 0.34, -0.14), m.yellow, m.carbon, 3, Vector3(-6, 0, 0))
		_box(root, Vector3(0.26, 0.1, 0.4), m.rubber, Vector3(x, 0.05, -0.05))
	# 허리와 몸통
	_box(root, Vector3(0.56, 0.16, 0.3), m.carbon, Vector3(0, 1.05, 0))
	_box(root, Vector3(0.86, 0.62, 0.5), m.plate, Vector3(0, 1.45, 0))
	_box(root, Vector3(0.7, 0.36, 0.06), m.carbon, Vector3(0, 1.5, -0.27))
	_cyl(root, 0.075, 0.075, 0.05, neon, Vector3(0, 1.48, -0.3), Vector3(90, 0, 0), 16)
	_ring(root, 0.085, 0.15, m.carbon, Vector3(0, 1.48, -0.3), Vector3(90, 0, 0))
	_ring(root, 0.15, 0.17, m.plate, Vector3(0, 1.48, -0.3), Vector3(90, 0, 0))
	for sx in [-1.0, 1.0]:
		for i in 3:
			_box(root, Vector3(0.16, 0.025, 0.02), m.rubber, Vector3(0.24 * sx, 1.4 + 0.05 * float(i), -0.305))
		_box(root, Vector3(0.016, 0.5, 0.02), neon, Vector3(0.43 * sx, 1.45, -0.26))
	_box(root, Vector3(0.3, 0.14, 0.02), m.rust, Vector3(0.18, 1.22, -0.255), Vector3(0, 0, -6))
	# 등 배기통
	for sx in [-1.0, 1.0]:
		_cyl(root, 0.07, 0.08, 0.5, m.carbon, Vector3(0.18 * sx, 1.78, 0.3), Vector3(-12, 0, 0), 10)
		_ring(root, 0.05, 0.07, neon, Vector3(0.18 * sx, 2.03, 0.36), Vector3(-12, 0, 0))
	# 어깨
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(0.34, 0.3, 0.44), m.plate, Vector3(0.6 * sx, 1.74, 0.0), Vector3(0, 0, -10.0 * sx))
		_hazard(root, Vector2(0.3, 0.1), Vector3(0.6 * sx, 1.74, -0.225), m.yellow, m.carbon, 4, Vector3(0, 0, -10.0 * sx))
	# 머리: 몸에 파묻힌 낮은 상자, 둥근 눈 하나
	_box(root, Vector3(0.32, 0.22, 0.3), m.carbon, Vector3(0, 1.86, -0.06))
	_box(root, Vector3(0.36, 0.06, 0.34), m.plate, Vector3(0, 1.98, -0.06))
	_cyl(root, 0.075, 0.075, 0.06, m.rubber, Vector3(0, 1.86, -0.22), Vector3(90, 0, 0), 14)
	var eye := _eye_node(_sphere(root, 0.06, m.eye, Vector3(0, 1.86, -0.25), Vector3(1, 1, 0.5)))
	_cable(root, Vector3(-0.14, 1.82, 0.08), Vector3(-0.5, 1.6, 0.18), 0.08, 0.02, m.rubber, 4)
	# 왼팔: 큰 주먹
	_box(root, Vector3(0.2, 0.42, 0.22), m.carbon, Vector3(-0.66, 1.38, 0.0))
	_box(root, Vector3(0.24, 0.4, 0.26), m.plate, Vector3(-0.68, 0.98, -0.04))
	_box(root, Vector3(0.26, 0.2, 0.26), m.carbon, Vector3(-0.68, 0.7, -0.06))
	_box(root, Vector3(0.016, 0.34, 0.02), neon, Vector3(-0.55, 0.98, -0.17))
	# 오른팔: 어깨 피벗에서 아래(-Y)로 팔과 빛 칼
	var arm := Node3D.new()
	arm.position = Vector3(0.66, 1.66, 0.0)
	root.add_child(arm)
	_box(arm, Vector3(0.2, 0.42, 0.22), m.carbon, Vector3(0, -0.24, 0))
	_box(arm, Vector3(0.24, 0.38, 0.26), m.plate, Vector3(0, -0.62, -0.02))
	_box(arm, Vector3(0.18, 0.14, 0.2), m.carbon, Vector3(0, -0.86, -0.02))
	_box(arm, Vector3(0.05, 0.16, 0.12), m.rubber, Vector3(0, -0.98, -0.02))
	_box(arm, Vector3(0.03, 1.2, 0.12), m.carbon, Vector3(0, -1.66, 0.02))
	_box(arm, Vector3(0.05, 1.24, 0.07), blade, Vector3(0, -1.68, -0.06))
	_box(arm, Vector3(0.016, 0.3, 0.02), neon, Vector3(0.13, -0.62, -0.1))
	arm.rotation = Vector3(-2.2, 0.0, 0.0)
	return {"eyes": [eye], "height": 2.05, "arm": arm}
