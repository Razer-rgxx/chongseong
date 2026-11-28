class_name Landmarks
extends RefCounted
## 들판 구조물(2026-11-24, docs/landmarks.md): 옛 갱도, 무너진 수도교, 풍차, 물레방앗간, 거인의 뼈, 흔들다리의 땅·막힘·모양.
## 막힘은 FieldBuilder.build의 표(rects, low_rects, circles)에 그대로 더한다(decor가 거짓이어도 같다). 모양은 decor일 때만, LandmarkView 아래에 짓는다.
## 같은 모양이 많은 것(아치 돌, 갈비뼈, 널, 줄)은 MultiMesh 하나로, 멀리서는 visibility range로 그리지 않는다. 수치는 FieldLayout.
## 길이는 m, 표는 칸(1칸 = 2m).

static var _deck: PackedFloat32Array = PackedFloat32Array()
static var _meshes: Dictionary = {}


## ---- 땅 ----

## 땅 높이에 더하는 m: 거인의 움푹한 곳과 흔들다리 골짜기. 둘 다 정해진 작은 곳 밖에서는 바로 0.
static func land(x: float, z: float) -> float:
	var out: float = 0.0
	if x > 20.0 and x < 56.0 and z < 50.0:
		var dx: float = absf(x - FieldLayout.RAVINE_X)
		if dx < 5.4:
			var across: float = 1.0 - smoothstep(3.0, 5.2, dx)
			var along: float = smoothstep(FieldLayout.RAVINE_Z.x, FieldLayout.RAVINE_Z.x + 6.0, z) * (1.0 - smoothstep(FieldLayout.RAVINE_Z.y - 8.0, FieldLayout.RAVINE_Z.y, z))
			out -= FieldLayout.RAVINE_DEPTH * across * along
	var g: Vector2 = FieldLayout.GIANT_AT * Grid.CELL
	if absf(x - g.x) < 36.0 and absf(z - g.y) < 22.0:
		var q: float = Vector2((x - g.x) / (FieldLayout.GIANT_R.x * Grid.CELL), (z - g.y) / (FieldLayout.GIANT_R.y * Grid.CELL)).length()
		out -= FieldLayout.GIANT_DEPTH * (1.0 - smoothstep(0.5, 1.0, q))
	return out


## 옛 갱도 바닥을 평평하게 깎는 정도 0~1(굴 안과 입구 앞).
static func mine_w(x: float, z: float) -> float:
	if x < 306.0 or x > 368.0 or absf(z - FieldLayout.MINE_Z) > 9.0:
		return 0.0
	var zz: float = 1.0 - smoothstep(4.0, 8.5, absf(z - FieldLayout.MINE_Z))
	var xx: float = smoothstep(FieldLayout.MINE_X.x - 14.0, FieldLayout.MINE_X.x + 2.0, x) * (1.0 - smoothstep(FieldLayout.MINE_X.y - 2.0, FieldLayout.MINE_X.y + 14.0, x))
	return zz * xx


## 흔들다리 위 높이(m). 다리 줄 밖이면 -1e9. 양 끝은 땅 높이와 같고 가운데는 BRIDGE_SAG만큼 처진다.
static func bridge_y(x: float, z: float) -> float:
	if absf(z - FieldLayout.RAVINE_BRIDGE_Z) > 1.0 or x < FieldLayout.RAVINE_BRIDGE_X.x or x > FieldLayout.RAVINE_BRIDGE_X.y:
		return -1e9
	return deck_at(x)


static func deck_at(x: float) -> float:
	if _deck.is_empty():
		_deck.resize(2)
		_deck[0] = FieldBuilder.height(FieldLayout.RAVINE_BRIDGE_X.x, FieldLayout.RAVINE_BRIDGE_Z)
		_deck[1] = FieldBuilder.height(FieldLayout.RAVINE_BRIDGE_X.y, FieldLayout.RAVINE_BRIDGE_Z)
	var u: float = inverse_lerp(FieldLayout.RAVINE_BRIDGE_X.x, FieldLayout.RAVINE_BRIDGE_X.y, x)
	return lerpf(_deck[0], _deck[1], u) - FieldLayout.BRIDGE_SAG * 4.0 * u * (1.0 - u)


## 물레방앗간: 집(m 가운데)과 바퀴 자리. 개울 위치를 따라 앉는다.
static func watermill() -> Dictionary:
	var x: float = FieldLayout.WATERMILL_X * Grid.CELL
	var bz: float = FieldBuilder.brook_z(x)
	return {"x": x, "house_z": bz - 6.2, "wheel_z": bz - 3.2}


## ---- 막힘 ----

static func blockers(rects: Array[Rect2], low_rects: Array[Rect2], circles: Array) -> void:
	rects.append_array(FieldLayout.MINE_WALLS)
	rects.append_array(FieldLayout.RAVINE_WALLS)
	for k in FieldLayout.AQUEDUCT_PIERS.size():
		var px: float = FieldLayout.AQUEDUCT_PIERS[k]
		rects.append(Rect2(px - 0.4, FieldLayout.AQUEDUCT_Y - 0.65, 0.8, 1.3))
	var g: Vector2 = FieldLayout.GIANT_AT
	for i in FieldLayout.GIANT_RIBS:
		var off: float = _rib_x(i) / Grid.CELL
		var r: float = _rib_r(i) / Grid.CELL
		circles.append([Vector2(g.x + off, g.y - r), 0.15])
		circles.append([Vector2(g.x + off, g.y + r), 0.15])
	circles.append([g + Vector2(6.75, 0.0), 1.3])   # 해골
	rects.append(Rect2(g.x - 8.0, g.y - 1.3, 1.8, 2.6))   # 골반
	low_rects.append(Rect2(g.x - 5.25, g.y - 0.25, 10.5, 0.5))   # 등뼈(점프로 넘는다)
	low_rects.append(Rect2(g.x - 3.0, g.y + 4.0, 0.5, 2.5))   # 넓적다리뼈
	circles.append([FieldLayout.WINDMILL_AT, 1.3])
	var w: Dictionary = watermill()
	rects.append(Rect2((float(w.x) - 2.5) / Grid.CELL, (float(w.house_z) - 1.8) / Grid.CELL, 2.5, 1.8))
	rects.append(Rect2((float(w.x) - 2.0) / Grid.CELL, (float(w.wheel_z) - 0.5) / Grid.CELL, 2.0, 0.5))


static func _rib_x(i: int) -> float:
	return (float(i) - (FieldLayout.GIANT_RIBS - 1) / 2.0) * 3.0


static func _rib_r(i: int) -> float:
	return 1.8 + 1.5 * sin(PI * (float(i) + 0.5) / FieldLayout.GIANT_RIBS)


## ---- 모양 ----

static func _mesh(key: String, make: Callable) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = make.call()
	return _meshes[key]


static func _bm(size: Vector3) -> Mesh:
	return _mesh("b%s" % size, func() -> Mesh:
		var b := BoxMesh.new()
		b.size = size
		return b)


static func _put(parent: Node3D, mesh: Mesh, m: Material, at: Vector3, rot: Vector3 = Vector3.ZERO, far: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	mi.rotation = rot
	if far > 0.0:
		mi.visibility_range_end = far
	parent.add_child(mi)
	return mi


static func _multi(parent: Node3D, mesh: Mesh, m: Material, xf: Array[Transform3D], far: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m
	mi.visibility_range_end = far
	parent.add_child(mi)


static func build(view: LandmarkView) -> void:
	_mine(view)
	_aqueduct(view)
	_giant(view)
	_windmill(view)
	_watermill(view)
	_bridge(view)


static func _mine(view: LandmarkView) -> void:
	var st: Material = FieldBuilder._cut_stone()
	var wood: Material = FieldBuilder._wood()
	var fy: float = FieldLayout.MINE_FLOOR_Y
	var x0: float = FieldLayout.MINE_X.x
	var x1: float = FieldLayout.MINE_X.y
	var cx: float = (x0 + x1) / 2.0
	var len: float = x1 - x0
	var z: float = FieldLayout.MINE_Z
	for s in [-1.0, 1.0]:
		_put(view, _bm(Vector3(len, 3.4, 1.2)), st, Vector3(cx, fy + 1.7, z + 3.0 * s), Vector3.ZERO, 260.0)
	_put(view, _bm(Vector3(len, 2.4, 11.0)), st, Vector3(cx, fy + 4.6, z), Vector3.ZERO, 260.0)
	for r in [[Vector3(cx, fy + 6.6, z), Vector3(18, 3.0, 8.5), 0.05], [Vector3(cx - 7, fy + 5.9, z + 1), Vector3(9, 2.6, 7.0), -0.1], [Vector3(cx + 8, fy + 5.7, z - 1), Vector3(10, 2.4, 7.5), 0.12]]:
		_put(view, _bm(r[1]), st, r[0], Vector3(0.0, r[2], 0.0), 260.0)
	# 통나무 받침: 지붕을 받치는 기둥 쌍과 가로보
	var xs: Array[float] = []
	var px: float = x0 + 2.0
	while px <= x1 - 1.0:
		xs.append(px)
		px += 5.0
	for x in xs:
		for s in [-1.0, 1.0]:
			_put(view, _bm(Vector3(0.4, 3.3, 0.4)), wood, Vector3(x, fy + 1.65, z + 2.1 * s), Vector3.ZERO, 120.0)
		_put(view, _bm(Vector3(0.4, 0.4, 4.8)), wood, Vector3(x, fy + 3.3, z), Vector3.ZERO, 120.0)
	var lamp: Material = FieldBuilder._mat("lantern", Color(1.0, 0.7, 0.35), 0.5, 0.0, 2.2)
	for i in FieldLayout.MINE_LANTERNS.size():
		var lx: float = FieldLayout.MINE_LANTERNS[i]
		var side: float = 1.0 if i % 2 == 0 else -1.0
		_put(view, _bm(Vector3(0.3, 0.4, 0.3)), lamp, Vector3(lx, fy + 2.5, z + 2.0 * side), Vector3.ZERO, 120.0)
		if i != 1:
			var l := OmniLight3D.new()
			l.position = Vector3(lx, fy + 2.4, z + 1.6 * side)
			l.light_color = Color(1.0, 0.72, 0.42)
			l.light_energy = 1.3
			l.omni_range = 11.0
			l.shadow_enabled = false
			view.add_child(l)
	# 입구 앞에 부서진 광차 하나
	_put(view, _bm(Vector3(1.8, 0.7, 1.1)), wood, Vector3(x0 - 3.0, fy + 0.4, z - 1.0), Vector3(0.0, 0.5, 0.15), 120.0)


static func _aqueduct(view: LandmarkView) -> void:
	var st: Material = FieldBuilder._dressed_stone()
	var z: float = FieldLayout.AQUEDUCT_Y * Grid.CELL
	var sp: float = FieldLayout.AQUEDUCT_SPRING
	var piers: PackedFloat32Array = FieldLayout.AQUEDUCT_PIERS
	var n: int = piers.size()
	var span: float = (piers[1] - piers[0]) * Grid.CELL
	var r: float = (span - 1.6) / 2.0
	var vous: Array[Transform3D] = []
	for k in n:
		var x: float = piers[k] * Grid.CELL
		var top: float = sp + 0.3 if k < n - 1 else 2.6
		_put(view, _bm(Vector3(1.6, top + 0.5, 2.6)), st, Vector3(x, (top - 0.5) / 2.0, z), Vector3.ZERO, 300.0)
		if k < n - 2:   # 받침 위 메움돌
			_put(view, _bm(Vector3(1.6, 4.9, 2.6)), st, Vector3(x, sp + 0.3 + 2.45, z), Vector3.ZERO, 300.0)
	for k in n - 2:   # 아치 넷(다섯째 칸은 무너졌다)
		var xc: float = (piers[k] + piers[k + 1]) * Grid.CELL / 2.0
		for v in 9:
			var th: float = PI * (float(v) + 0.5) / 9.0
			vous.append(Transform3D(Basis(Vector3(0, 0, 1), th - PI / 2.0), Vector3(xc + cos(th) * r, sp + sin(th) * r, z)))
		_put(view, _bm(Vector3(span, 0.8, 2.6)), st, Vector3(xc, sp + r + 0.85, z), Vector3.ZERO, 300.0)
		for s in [-1.0, 1.0]:
			_put(view, _bm(Vector3(span, 0.6, 0.3)), st, Vector3(xc, sp + r + 1.5, z + 1.15 * s), Vector3.ZERO, 200.0)
	_multi(view, _bm(Vector3(1.7, 0.9, 2.6)), st, vous, 300.0)
	var rub: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in 9:
		var x: float = rng.randf_range(piers[n - 2], piers[n - 1] + 2.0) * Grid.CELL
		var zz: float = z + rng.randf_range(-3.0, 3.0)
		var s: float = rng.randf_range(0.6, 1.5)
		rub.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s * 1.4, s * 0.7, s)), Vector3(x, FieldBuilder.height(x, zz) + 0.2, zz)))
	_multi(view, _bm(Vector3(1.0, 1.0, 1.0)), st, rub, 200.0)


static func _giant(view: LandmarkView) -> void:
	var bone: Material = FieldBuilder._mat("bone", Color(0.62, 0.58, 0.5), 0.9)
	var dark: Material = FieldBuilder._mat("bone_dark", Color(0.03, 0.03, 0.03), 1.0)
	var c: Vector2 = FieldLayout.GIANT_AT * Grid.CELL
	var y0: float = FieldBuilder.height(c.x, c.y)
	var tm: Mesh = _mesh("rib", func() -> Mesh:
		var t := TorusMesh.new()
		t.inner_radius = 0.93
		t.outer_radius = 1.07
		t.rings = 14
		t.ring_segments = 5
		return t)
	var ribs: Array[Transform3D] = []
	for i in FieldLayout.GIANT_RIBS:
		ribs.append(Transform3D(Basis(Vector3(0, 0, 1), PI / 2.0).scaled(Vector3.ONE * _rib_r(i)), Vector3(c.x + _rib_x(i), y0 + 0.1, c.y)))
	_multi(view, tm, bone, ribs, 220.0)
	var sm := SphereMesh.new()
	sm.radius = 0.32
	sm.height = 0.64
	sm.radial_segments = 8
	sm.rings = 4
	var spine: Array[Transform3D] = []
	for k in 20:
		spine.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 0.9, 1.1)), Vector3(c.x - 10.5 + k * 1.1, y0 + 0.3, c.y)))
	_multi(view, sm, bone, spine, 220.0)
	var skull: MeshInstance3D = _put(view, sm, bone, Vector3(c.x + 13.5, y0 + 1.0, c.y), Vector3.ZERO, 220.0)
	skull.scale = Vector3(4.6, 3.6, 4.0)
	for s in [-1.0, 1.0]:
		var eye: MeshInstance3D = _put(view, sm, dark, Vector3(c.x + 15.0, y0 + 1.6, c.y + 0.75 * s), Vector3.ZERO, 160.0)
		eye.scale = Vector3(1.0, 1.2, 1.2)
	_put(view, _bm(Vector3(2.2, 0.5, 2.4)), bone, Vector3(c.x + 14.0, y0 + 0.25, c.y), Vector3(0.0, 0.0, 0.1), 220.0)
	_put(view, _bm(Vector3(3.6, 1.3, 5.0)), bone, Vector3(c.x - 14.0, y0 + 0.5, c.y), Vector3(0.0, 0.1, 0.0), 220.0)
	_put(view, _bm(Vector3(1.0, 0.7, 5.2)), bone, Vector3(c.x - 6.0, y0 + 0.35, c.y + 10.0), Vector3(0.0, 0.1, 0.0), 220.0)


static func _windmill(view: LandmarkView) -> void:
	var st: Material = FieldBuilder._stone()
	var wood: Material = FieldBuilder._wood()
	var cloth: Material = FieldBuilder._mat("cloth", Color(0.36, 0.3, 0.2))
	var p: Vector2 = FieldLayout.WINDMILL_AT * Grid.CELL
	var y0: float = FieldBuilder.height(p.x, p.y)
	var tower := CylinderMesh.new()
	tower.top_radius = 1.4
	tower.bottom_radius = 2.4
	tower.height = 7.0
	tower.radial_segments = 10
	_put(view, tower, st, Vector3(p.x, y0 + 3.4, p.y), Vector3.ZERO, 300.0)
	var cap := CylinderMesh.new()
	cap.top_radius = 0.0
	cap.bottom_radius = 1.9
	cap.height = 1.9
	cap.radial_segments = 10
	_put(view, cap, wood, Vector3(p.x, y0 + 7.9, p.y), Vector3.ZERO, 300.0)
	_put(view, _bm(Vector3(0.2, 1.8, 1.0)), FieldBuilder._mat("door", Color(0.05, 0.04, 0.03)), Vector3(p.x - 2.1, y0 + 0.9, p.y), Vector3.ZERO, 120.0)
	var hub := Node3D.new()
	hub.position = Vector3(p.x + 1.7, y0 + 7.2, p.y)
	view.add_child(hub)
	_put(hub, _bm(Vector3(0.5, 0.5, 0.5)), wood, Vector3.ZERO, Vector3.ZERO, 300.0)
	_put(hub, _bm(Vector3(0.18, 8.8, 0.22)), wood, Vector3.ZERO, Vector3.ZERO, 300.0)
	_put(hub, _bm(Vector3(0.18, 0.22, 8.8)), wood, Vector3.ZERO, Vector3.ZERO, 300.0)
	for s in [-1.0, 1.0]:
		_put(hub, _bm(Vector3(0.05, 3.2, 1.1)), cloth, Vector3(0.0, 2.8 * s, 0.65 * s), Vector3.ZERO, 300.0)
		_put(hub, _bm(Vector3(0.05, 1.1, 3.2)), cloth, Vector3(0.0, -0.65 * s, 2.8 * s), Vector3.ZERO, 300.0)
	view.wind_hub = hub


static func _watermill(view: LandmarkView) -> void:
	var wood: Material = FieldBuilder._wood()
	var st: Material = FieldBuilder._stone()
	var w: Dictionary = watermill()
	var x: float = w.x
	var hz: float = w.house_z
	var y0: float = FieldBuilder.height(x, hz)
	_put(view, _bm(Vector3(5.0, 3.4, 3.6)), st, Vector3(x, y0 + 1.4, hz), Vector3.ZERO, 300.0)
	var roof := PrismMesh.new()
	roof.size = Vector3(4.4, 1.8, 5.8)
	_put(view, roof, wood, Vector3(x, y0 + 4.0, hz), Vector3(0.0, PI / 2.0, 0.0), 300.0)
	_put(view, _bm(Vector3(1.0, 1.9, 0.2)), FieldBuilder._mat("door", Color(0.05, 0.04, 0.03)), Vector3(x - 1.2, y0 + 0.9, hz + 1.85), Vector3.ZERO, 120.0)
	var wheel := Node3D.new()
	wheel.position = Vector3(x, 1.2, float(w.wheel_z))
	view.add_child(wheel)
	var rim := TorusMesh.new()
	rim.inner_radius = 1.9
	rim.outer_radius = 2.1
	rim.rings = 16
	rim.ring_segments = 4
	for dz in [-0.4, 0.4]:
		_put(wheel, rim, wood, Vector3(0.0, 0.0, dz), Vector3(PI / 2.0, 0.0, 0.0), 220.0)
	for k in 6:
		_put(wheel, _bm(Vector3(4.0, 0.14, 0.16)), wood, Vector3.ZERO, Vector3(0.0, 0.0, k * PI / 6.0), 220.0)
	for k in 12:
		var a: float = k * TAU / 12.0
		_put(wheel, _bm(Vector3(0.12, 0.7, 1.0)), wood, Vector3(cos(a) * 2.0, sin(a) * 2.0, 0.0), Vector3(0.0, 0.0, a), 220.0)
	_put(view, _bm(Vector3(0.3, 0.3, 3.4)), wood, Vector3(x, 1.2, float(w.wheel_z) - 1.5), Vector3.ZERO, 220.0)
	view.mill_wheel = wheel


static func _bridge(view: LandmarkView) -> void:
	var wood: Material = FieldBuilder._wood()
	var rope: Material = FieldBuilder._mat("rope", Color(0.3, 0.24, 0.16))
	var xa: float = FieldLayout.RAVINE_BRIDGE_X.x
	var xb: float = FieldLayout.RAVINE_BRIDGE_X.y
	var z: float = FieldLayout.RAVINE_BRIDGE_Z
	var mid: float = (xa + xb) / 2.0
	var node := Node3D.new()
	node.position = Vector3(mid, deck_at(mid), z)
	view.add_child(node)
	var planks: Array[Transform3D] = []
	var ropes: Array[Transform3D] = []
	var n: int = 26
	var step: float = (xb - xa) / n
	for k in n:
		var x: float = xa + (k + 0.5) * step
		var slope: float = atan2(deck_at(x + 0.1) - deck_at(x - 0.1), 0.2)
		var at := Vector3(x - mid, deck_at(x) - deck_at(mid) + 0.05, 0.0)
		planks.append(Transform3D(Basis(Vector3(0, 0, 1), slope), at))
		for s in [-1.0, 1.0]:
			ropes.append(Transform3D(Basis(Vector3(0, 0, 1), slope), at + Vector3(0.0, 1.0, 0.85 * s)))
	_multi(node, _bm(Vector3(0.4, 0.1, 1.7)), wood, planks, 160.0)
	_multi(node, _bm(Vector3(step * 1.1, 0.06, 0.06)), rope, ropes, 160.0)
	for x in [xa, xb]:
		for s in [-1.0, 1.0]:
			_put(node, _bm(Vector3(0.18, 1.5, 0.18)), wood, Vector3(x - mid, deck_at(x) - deck_at(mid) + 0.7, 0.9 * s), Vector3.ZERO, 160.0)
	view.bridge = node
