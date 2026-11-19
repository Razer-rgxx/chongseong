class_name FieldBuilder
extends RefCounted
## 들판(16단계)의 땅과 꾸밈. 규칙과 상관없는 그림이라 고정 시드의 따로 된 랜덤을 쓴다.
## 땅·풀·나무·바위·하늘은 HillBuilder의 것을 쓰고, 나머지(길·개울·망루·옛 싸움터·목책)는 기본 도형이다.
## 같은 모양이 많은 것은 MultiMesh로, 바위와 작은 소품은 visibility range로 멀리서 그리지 않는다.
## 길이는 m. 칸 좌표는 FieldLayout 쪽(1칸 = 2m).

const DECK_Y: float = 0.35
const WATER_Y: float = -0.7

static var _n: FastNoiseLite
static var _road_m: PackedVector2Array = PackedVector2Array()   ## 길을 촘촘히 편 점들(m)
static var _mats: Dictionary = {}


static func setup() -> void:
	_n = FastNoiseLite.new()
	_n.seed = 31
	_n.frequency = 0.012
	_n.fractal_octaves = 3
	_road_m = _spline(FieldLayout.ROAD, 6)


static func brook_z(x: float) -> float:
	return 116.0 + 8.0 * sin(x * 0.045 + 1.0)


static func _outside(x: float, z: float) -> float:
	var w: float = FieldLayout.WORLD
	return Vector2(x - clampf(x, 0.0, w), z - clampf(z, 0.0, w)).length()


## 땅 높이(m): 완만한 굴곡, 개울 바닥, 북쪽으로 오르는 땅, 둘레의 오르막.
static func height(x: float, z: float) -> float:
	if _n == null:
		setup()
	var h: float = 1.0 + _n.get_noise_2d(x, z) * 1.6
	h += 7.0 * (1.0 - smoothstep(0.0, 70.0, z))
	var e: float = _outside(x, z)
	h += 14.0 * smoothstep(0.0, 60.0, e) + e * 0.03
	var w: float = exp(-pow((z - brook_z(x)) / 4.5, 2.0))
	return lerpf(h, -1.8, w * 0.95)


## 걸을 때의 높이: 돌다리 위는 다리 판 높이.
static func walk_height(x: float, z: float) -> float:
	var h: float = height(x, z)
	if absf(x - FieldLayout.BRIDGE_X) < 2.0 and absf(z - brook_z(FieldLayout.BRIDGE_X)) < 6.5:
		return maxf(h, DECK_Y)
	return h


static func road_dist(x: float, z: float) -> float:
	if _road_m.is_empty():
		setup()
	var best: float = 1e9
	for p in _road_m:
		best = minf(best, Vector2(x, z).distance_to(p))
	return best


## 칸 자리의 월드 좌표(땅 높이 위).
static func at_cell(c: Vector2, lift: float = 0.0) -> Vector3:
	var x: float = c.x * Grid.CELL
	var z: float = c.y * Grid.CELL
	return Vector3(x, walk_height(x, z) + lift, z)


# ---------------------------------------------------------------- 짓기

static func build(parent: Node3D, env: Environment) -> Dictionary:
	setup()
	var rng := RandomNumberGenerator.new()
	rng.seed = 16
	var rects: Array[Rect2] = []
	rects.append_array(FieldLayout.BORDER_RECTS)
	var circles: Array = []
	_terrain(parent)
	_water(parent)
	_road(parent)
	_bridge(parent, rects)
	_tower(parent, rects)
	_old_field(parent, rng, circles)
	_grove(parent, rng, circles)
	_foot(parent, circles)
	_crypt_gate(parent, rects)
	_palisade(parent)
	_far_hill(parent)
	_forest(parent, rng, circles)
	_rocks(parent, rng)
	_reeds(parent, rng)
	_grass(parent, rng)
	return {"rects": rects, "circles": circles}


static func _mat(key: String, c: Color, rough: float = 1.0, metal: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	_mats[key] = m
	return m


static func _stone() -> Material:
	return VillageBuilder.noise_mat("field_stone", Color(0.2, 0.2, 0.21), Color(0.42, 0.42, 0.43), 2.5, 0.06)


static func _wood() -> Material:
	return VillageBuilder.noise_mat("field_wood", Color(0.12, 0.09, 0.06), Color(0.3, 0.22, 0.14), 1.5, 0.08)


static func _box(parent: Node3D, size: Vector3, at: Vector3, m: Material, rot: Vector3 = Vector3.ZERO, far: float = 0.0) -> MeshInstance3D:
	var mi := VillageBuilder.box(parent, size, at, m, rot)
	if far > 0.0:
		mi.visibility_range_end = far
	return mi


static func _spline(pts: PackedVector2Array, per: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts.size() - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)] * Grid.CELL
		var p1: Vector2 = pts[i] * Grid.CELL
		var p2: Vector2 = pts[i + 1] * Grid.CELL
		var p3: Vector2 = pts[mini(i + 2, pts.size() - 1)] * Grid.CELL
		for k in per:
			out.append(p1.cubic_interpolate(p2, p0, p3, float(k) / per))
	out.append(pts[pts.size() - 1] * Grid.CELL)
	return out


## 정해진 점들을 따라 땅에 붙는 띠.
static func _ribbon(parent: Node3D, pts: PackedVector2Array, half: float, side: float, lift: float, m: Material, name: String) -> void:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var run: float = 0.0
	for i in pts.size():
		var a: Vector2 = pts[maxi(i - 1, 0)]
		var b: Vector2 = pts[mini(i + 1, pts.size() - 1)]
		var d: Vector2 = (b - a).normalized()
		var nrm := Vector2(-d.y, d.x)
		if i > 0:
			run += pts[i].distance_to(pts[i - 1])
		for s in [-1.0, 1.0]:
			var q: Vector2 = pts[i] + nrm * (side + half * s)
			verts.append(Vector3(q.x, walk_height(q.x, q.y) + lift, q.y))
			norms.append(Vector3.UP)
			uvs.append(Vector2(run / 4.0, 0.5 + 0.5 * s))
		if i > 0:
			var o: int = (i - 1) * 2
			idx.append_array([o, o + 2, o + 1, o + 1, o + 2, o + 3])
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	var mm: Material = m.duplicate()
	if mm is BaseMaterial3D:
		(mm as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


static func _road(parent: Node3D) -> void:
	_ribbon(parent, _road_m, 2.2, 0.0, 0.06, VillageBuilder.dirt(), "Road")
	var rut: Material = _mat("rut", Color(0.07, 0.055, 0.045))
	_ribbon(parent, _road_m, 0.16, -0.9, 0.075, rut, "RutL")
	_ribbon(parent, _road_m, 0.16, 0.9, 0.075, rut, "RutR")


# ---------------------------------------------------------------- 땅

static func _axis() -> PackedFloat32Array:
	var left: Array[float] = []
	var s: float = 2.0
	var q: float = -8.0
	while q > -560.0:
		s = minf(s * 1.12, 40.0)
		q -= s
		left.append(q)
	left.reverse()
	var a := PackedFloat32Array(left)
	var x: float = -8.0
	while x <= FieldLayout.WORLD + 8.0:
		a.append(x)
		x += 2.0
	s = 2.0
	q = x - 2.0
	while q < FieldLayout.WORLD + 560.0:
		s = minf(s * 1.12, 40.0)
		q += s
		a.append(q)
	return a


static func _terrain(parent: Node3D) -> void:
	var ax := _axis()
	var n: int = ax.size()
	var verts := PackedVector3Array()
	verts.resize(n * n)
	for j in n:
		for i in n:
			verts[j * n + i] = Vector3(ax[i], height(ax[i], ax[j]), ax[j])
	var norms := PackedVector3Array()
	norms.resize(n * n)
	for j in n:
		var j0: int = maxi(j - 1, 0)
		var j1: int = mini(j + 1, n - 1)
		for i in n:
			var i0: int = maxi(i - 1, 0)
			var i1: int = mini(i + 1, n - 1)
			var dx: Vector3 = verts[j * n + i1] - verts[j * n + i0]
			var dz: Vector3 = verts[j1 * n + i] - verts[j0 * n + i]
			norms[j * n + i] = dz.cross(dx).normalized()
	var idx := PackedInt32Array()
	idx.resize((n - 1) * (n - 1) * 6)
	var k: int = 0
	for j in n - 1:
		for i in n - 1:
			var a: int = j * n + i
			var c: int = a + n
			idx[k] = a
			idx[k + 1] = a + 1
			idx[k + 2] = c
			idx[k + 3] = a + 1
			idx[k + 4] = c + 1
			idx[k + 5] = c
			k += 6
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	var m: Material = HillBuilder._terrain_mat()
	if m is ShaderMaterial:
		(m as ShaderMaterial).set_shader_parameter("arena", Vector4(-9000.0, -9000.0, -8000.0, -8000.0))
	mi.material_override = m
	parent.add_child(mi)


static func _water(parent: Node3D) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.24, 0.27, 0.78)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.06
	m.metallic = 0.25
	var pm := PlaneMesh.new()
	pm.size = Vector2(300.0, 34.0)
	var mi := MeshInstance3D.new()
	mi.name = "Brook"
	mi.mesh = pm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(110.0, WATER_Y, 116.0)
	parent.add_child(mi)


## 돌다리: 판과 아치 밑 받침, 난간. 난간은 영주가 못 넘게 막는다.
static func _bridge(parent: Node3D, rects: Array[Rect2]) -> void:
	var bx: float = FieldLayout.BRIDGE_X
	var bz: float = brook_z(bx)
	var st: Material = _stone()
	_box(parent, Vector3(4.4, 0.5, 13.5), Vector3(bx, DECK_Y - 0.25, bz), st)
	for s in [-1.0, 1.0]:
		_box(parent, Vector3(0.35, 0.7, 12.0), Vector3(bx + 2.05 * s, DECK_Y + 0.35, bz), st)
		_box(parent, Vector3(0.6, 1.2, 0.6), Vector3(bx + 2.05 * s, DECK_Y + 0.6, bz - 6.0), st)
		_box(parent, Vector3(0.6, 1.2, 0.6), Vector3(bx + 2.05 * s, DECK_Y + 0.6, bz + 6.0), st)
		_box(parent, Vector3(0.9, 2.2, 0.9), Vector3(bx + 1.6 * s, -0.6, bz + 5.0 * s), st)
		var cx: float = (bx + 2.05 * s) / Grid.CELL
		rects.append(Rect2(cx - 0.12, (bz - 5.6) / Grid.CELL, 0.24, 11.2 / Grid.CELL))


# ---------------------------------------------------------------- 망루

static func _tower(parent: Node3D, rects: Array[Rect2]) -> void:
	var c := Vector3(FieldLayout.TOWER.x * Grid.CELL, 0.0, FieldLayout.TOWER.y * Grid.CELL)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var st: Material = _stone()
	var half: float = 3.4
	var base: float = height(c.x, c.z)
	for side in 4:
		var yaw: float = side * PI / 2.0
		for k in 5:
			var off: float = -half + 0.7 + k * 1.4
			var dir := Vector3(cos(yaw), 0, sin(yaw))
			var out := Vector3(-dir.z, 0, dir.x) * half
			var p: Vector3 = c + dir * off + out
			var h: float = rng.randf_range(1.2, 5.0)
			if side == 3 and k == 4:
				h = 9.5
			if side == 2 and k == 1:
				h = 8.0
			if side == 0 and k == 2:   # 남쪽 문 자리
				h = 0.0
			if h > 0.0:
				_box(parent, Vector3(1.4, h, 0.9), Vector3(p.x, base + h / 2.0 - 0.3, p.z), st, Vector3(0, -yaw + PI / 2.0, 0))
	# 무너져 내린 돌과 부러진 들보
	for i in 18:
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(half + 0.5, half + 4.5)
		var s: float = rng.randf_range(0.3, 0.9)
		_box(parent, Vector3(s, s * 0.7, s * 1.2), Vector3(c.x + cos(a) * r, height(c.x + cos(a) * r, c.z + sin(a) * r) + s * 0.2, c.z + sin(a) * r), st, Vector3(rng.randf() * 0.6, rng.randf() * TAU, rng.randf() * 0.6), 90.0)
	var wd: Material = _wood()
	for i in 3:
		_box(parent, Vector3(0.3, 0.3, 5.5), c + Vector3(rng.randf_range(-2, 2), base + 3.2 + i * 0.5, rng.randf_range(-2, 2)), wd, Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * PI, rng.randf_range(-0.3, 0.3)))
	rects.append(Rect2(FieldLayout.TOWER.x - 3.6, FieldLayout.TOWER.y - 3.6, 7.2, 7.2).grow(0.0))


# ---------------------------------------------------------------- 옛 싸움터

static func _old_field(parent: Node3D, rng: RandomNumberGenerator, circles: Array) -> void:
	var rust: Material = _mat("rust", Color(0.32, 0.17, 0.09), 0.9, 0.5)
	var area: Rect2 = FieldLayout.AREAS[&"old_field"]
	var blades: Array[Transform3D] = []
	var guards: Array[Transform3D] = []
	var shields: Array[Transform3D] = []
	var tries: int = 0
	while blades.size() < 46 and tries < 2000:
		tries += 1
		var c := Vector2(rng.randf_range(area.position.x + 2.0, area.end.x - 4.0), rng.randf_range(area.position.y + 2.0, area.end.y - 4.0))
		if not _free(c):
			continue
		var x: float = c.x * Grid.CELL
		var z: float = c.y * Grid.CELL
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)) * Basis(Vector3.FORWARD, rng.randf_range(-0.3, 0.3))
		var o := Vector3(x, height(x, z), z)
		blades.append(Transform3D(b, o + b * Vector3(0, 0.45, 0)))
		guards.append(Transform3D(b, o + b * Vector3(0, 0.95, 0)))
	var bm := BoxMesh.new()
	bm.size = Vector3(0.09, 1.4, 0.025)
	var gm := BoxMesh.new()
	gm.size = Vector3(0.5, 0.07, 0.06)
	HillBuilder._multi(parent, bm, blades, true, rust).visibility_range_end = 120.0
	HillBuilder._multi(parent, gm, guards, true, rust).visibility_range_end = 120.0
	for i in 12:
		var c := Vector2(rng.randf_range(area.position.x + 2.0, area.end.x - 4.0), rng.randf_range(area.position.y + 2.0, area.end.y - 4.0))
		if not _free(c):
			continue
		var x: float = c.x * Grid.CELL
		var z: float = c.y * Grid.CELL
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(1.0, 1.5))
		shields.append(Transform3D(b, Vector3(x, height(x, z) + 0.15, z)))
	var sm := CylinderMesh.new()
	sm.top_radius = 0.36
	sm.bottom_radius = 0.36
	sm.height = 0.05
	HillBuilder._multi(parent, sm, shields, true, _mat("shield", Color(0.25, 0.14, 0.1), 0.8, 0.3)).visibility_range_end = 100.0
	# 부서진 수레
	var cc := Vector2(76, 84)
	var cp := at_cell(cc)
	var wd: Material = _wood()
	var cart := Node3D.new()
	cart.position = cp
	cart.rotation = Vector3(0.0, 0.7, 0.12)
	parent.add_child(cart)
	_box(cart, Vector3(3.0, 0.2, 1.5), Vector3(0, 0.75, 0), wd)
	_box(cart, Vector3(3.0, 0.5, 0.15), Vector3(0, 1.1, 0.7), wd, Vector3(0.3, 0, 0))
	_box(cart, Vector3(0.15, 0.6, 1.5), Vector3(-1.4, 1.1, 0), wd)
	_box(cart, Vector3(3.2, 0.14, 0.14), Vector3(2.4, 0.5, 0.2), wd, Vector3(0, 0.1, -0.35))
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.75
	wheel.bottom_radius = 0.75
	wheel.height = 0.12
	var w1 := MeshInstance3D.new()
	w1.mesh = wheel
	w1.material_override = wd
	w1.rotation = Vector3(PI / 2.0, 0, 0)
	w1.position = Vector3(0.6, 0.7, 0.85)
	cart.add_child(w1)
	var w2 := MeshInstance3D.new()
	w2.mesh = wheel
	w2.material_override = wd
	w2.rotation = Vector3(1.2, 0.4, 0)
	w2.position = Vector3(-1.8, 0.2, -1.4)
	cart.add_child(w2)
	circles.append([cc, 1.5])
	circles.append([cc + Vector2(-1.0, 0.8), 0.7])


# ---------------------------------------------------------------- 검은 숲 가장자리

static func _grove(parent: Node3D, rng: RandomNumberGenerator, circles: Array) -> void:
	var area: Rect2 = FieldLayout.AREAS[&"grove"]
	var by_v: Array = [[], [], [], []]
	var tries: int = 0
	var n: int = 0
	while n < 90 and tries < 3000:
		tries += 1
		var c := Vector2(rng.randf_range(area.position.x + 3.0, area.end.x), rng.randf_range(area.position.y, area.end.y))
		if not _free(c, 3.0):
			continue
		var x: float = c.x * Grid.CELL
		var z: float = c.y * Grid.CELL
		var s: float = rng.randf_range(0.9, 1.5)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
		by_v[n % 4].append(Transform3D(b, Vector3(x, height(x, z) - 0.1, z)))
		circles.append([c, 0.3])
		n += 1
	for v in 4:
		var xs: Array[Transform3D] = []
		xs.assign(by_v[v])
		if not xs.is_empty():
			HillBuilder._multi(parent, HillBuilder.bare_tree(v), xs, true, HillBuilder.bark()).visibility_range_end = 150.0
	# 쓰러진 거목: 줄지은 둥근 막힘
	var a := Vector2(14, 34)
	var e := Vector2(26, 38)
	var pa: Vector3 = at_cell(a)
	var pe: Vector3 = at_cell(e)
	var mid: Vector3 = (pa + pe) / 2.0
	var cm := CylinderMesh.new()
	cm.top_radius = 0.7
	cm.bottom_radius = 0.95
	cm.height = pa.distance_to(pe)
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = HillBuilder.bark()
	mi.position = mid + Vector3(0, 0.6, 0)
	var dir: Vector3 = (pe - pa).normalized()
	mi.basis = Basis(Quaternion(Vector3.UP, dir))
	parent.add_child(mi)
	for k in 7:
		circles.append([a.lerp(e, float(k) / 6.0), 0.8])
	for k in 5:
		var rb := Vector3(rng.randf_range(-1, 1), 0.5, rng.randf_range(-1, 1))
		_box(parent, Vector3(0.18, 0.18, 2.2), pa + Vector3(0, 0.9, 0) + rb, _mat("dead_wood", Color(0.12, 0.1, 0.08)), Vector3(0.3, rng.randf() * TAU, 0.4))


# ---------------------------------------------------------------- 무덤 입구 (19단계)

## 무너진 무덤 입구: 기울어진 돌기둥 둘과 부러진 상인방, 땅속으로 내려가는 계단과 검은 입구. 글자 없음.
static func _crypt_gate(parent: Node3D, rects: Array[Rect2]) -> void:
	var b: Rect2 = FieldLayout.CRYPT_BLOCK
	var c: Vector2 = b.get_center()
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	var st: Material = _stone()
	var cx: float = c.x * Grid.CELL
	var cz: float = c.y * Grid.CELL
	var base: float = height(cx, cz)
	var hw: float = b.size.x * Grid.CELL / 2.0
	var hd: float = b.size.y * Grid.CELL / 2.0
	_box(parent, Vector3(hw * 2.0, 2.2, hd * 2.0), Vector3(cx, base + 0.5, cz - 0.4), st)   # 흙에 묻힌 돌 둔덕
	var dark := _mat("crypt_dark", Color(0.0, 0.0, 0.0), 1.0)
	_box(parent, Vector3(3.2, 3.0, 0.4), Vector3(cx, base + 1.4, cz + hd - 0.4), dark)   # 검은 입구
	for i in 4:   # 내려가는 계단
		_box(parent, Vector3(3.6, 0.3, 0.8), Vector3(cx, base + 0.15 - i * 0.05, cz + hd + 0.2 + i * 0.7), st)
	for s in [-1.0, 1.0]:
		_box(parent, Vector3(0.9, 4.2, 0.9), Vector3(cx + s * 2.3, base + 2.0, cz + hd - 0.2), st, Vector3(0, 0.1 * s, 0.07 * s))
	_box(parent, Vector3(2.4, 0.7, 1.0), Vector3(cx - 1.4, base + 4.0, cz + hd - 0.3), st, Vector3(0, 0.0, 0.25))   # 부러진 상인방
	for i in 12:   # 무너진 돌
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(hw * 0.8, hw + 2.5)
		var s: float = rng.randf_range(0.3, 1.0)
		var x: float = cx + cos(a) * r
		var z: float = cz + sin(a) * r * 0.7 + hd * 0.4
		_box(parent, Vector3(s, s * 0.7, s * 1.2), Vector3(x, height(x, z) + s * 0.2, z), st, Vector3(rng.randf() * 0.6, rng.randf() * TAU, rng.randf() * 0.6), 90.0)
	rects.append(b)


# ---------------------------------------------------------------- 언덕 발치

static func _foot(parent: Node3D, circles: Array) -> void:
	var st: Material = _stone()
	var cx: float = 55.0 * Grid.CELL
	for i in 9:
		var z: float = 46.0 - i * 3.6
		var y: float = walk_height(cx, z)
		_box(parent, Vector3(5.0, 0.4, 1.4), Vector3(cx, y + 0.02, z), st)
		if i % 2 == 0:
			_box(parent, Vector3(0.7, 0.5 + i * 0.03, 0.9), Vector3(cx - 3.2, y + 0.1, z), st)
			_box(parent, Vector3(0.7, 0.5 + i * 0.03, 0.9), Vector3(cx + 3.2, y + 0.1, z), st)
	# 길머리: 돌기둥 둘과 얹은 돌
	var tz: float = 7.0
	for s in [-1.0, 1.0]:
		_box(parent, Vector3(0.9, 5.0, 0.9), Vector3(cx + 2.7 * s, walk_height(cx, tz) + 2.4, tz), st)
		circles.append([Vector2(cx + 2.7 * s, tz) / Grid.CELL, 0.5])
	_box(parent, Vector3(6.8, 0.8, 1.1), Vector3(cx, walk_height(cx, tz) + 5.2, tz), st)
	# 꺼진 화톳불
	var fc := Vector3(cx + 14.0, 0.0, 44.0)
	fc.y = height(fc.x, fc.z)
	for k in 9:
		var a: float = k * TAU / 9.0
		_box(parent, Vector3(0.5, 0.35, 0.4), fc + Vector3(cos(a) * 1.1, 0.12, sin(a) * 1.1), st, Vector3(0, -a, 0))
	var ash := CylinderMesh.new()
	ash.top_radius = 0.95
	ash.bottom_radius = 0.95
	ash.height = 0.06
	var am := MeshInstance3D.new()
	am.mesh = ash
	am.material_override = _mat("ash", Color(0.06, 0.055, 0.05))
	am.position = fc + Vector3(0, 0.1, 0)
	parent.add_child(am)
	for k in 3:
		_box(parent, Vector3(0.12, 0.12, 1.1), fc + Vector3(0, 0.25, 0), _wood(), Vector3(0, k * 1.0, 0.1))
	circles.append([Vector2(fc.x, fc.z) / Grid.CELL, 1.0])


# ---------------------------------------------------------------- 마을 목책과 문

static func _palisade(parent: Node3D) -> void:
	var z: float = 217.0
	var gap_a: float = FieldLayout.GATE_GAP.x * Grid.CELL
	var gap_b: float = FieldLayout.GATE_GAP.y * Grid.CELL
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var xs: Array[Transform3D] = []
	var x: float = 0.0
	while x < FieldLayout.WORLD:
		if x < gap_a or x > gap_b:
			var h: float = rng.randf_range(2.6, 3.5)
			xs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1, h / 3.0, 1)), Vector3(x, height(x, z) + h / 2.0 - 0.3, z + rng.randf_range(-0.08, 0.08))))
		x += 0.55
	var pm := BoxMesh.new()
	pm.size = Vector3(0.3, 3.0, 0.3)
	HillBuilder._multi(parent, pm, xs, true, _wood()).name = "PalisadePosts"
	for r in 2:
		for seg in [[0.0, gap_a], [gap_b, FieldLayout.WORLD]]:
			var len: float = seg[1] - seg[0]
			var mx: float = (seg[0] + seg[1]) / 2.0
			_box(parent, Vector3(len, 0.2, 0.2), Vector3(mx, 1.0 + r * 1.3, z - 0.25), _wood())
	var st: Material = _stone()
	for gx in [gap_a, gap_b]:
		_box(parent, Vector3(0.9, 5.2, 0.9), Vector3(gx, height(gx, z) + 2.3, z), st)
	_box(parent, Vector3(gap_b - gap_a + 1.8, 0.8, 1.1), Vector3(110.0, height(110.0, z) + 5.3, z), st)


## 북쪽 멀리의 큰 언덕: 꼭대기에 싸움터 둘레의 돌기둥이 보인다.
static func _far_hill(parent: Node3D) -> void:
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 24
	sm.rings = 12
	var mi := MeshInstance3D.new()
	mi.name = "FarHill"
	mi.mesh = sm
	mi.material_override = _mat("far_hill", Color(0.09, 0.11, 0.08))
	mi.scale = Vector3(190.0, 95.0, 150.0)
	mi.position = Vector3(110.0, -8.0, -290.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var top := Vector3(110.0, 86.0, -290.0)
	var cm := CylinderMesh.new()
	cm.top_radius = 34.0
	cm.bottom_radius = 40.0
	cm.height = 3.0
	var pl := MeshInstance3D.new()
	pl.mesh = cm
	pl.material_override = _mat("far_top", Color(0.13, 0.12, 0.1))
	pl.position = top - Vector3(0, 1.0, 0)
	pl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(pl)
	var blade := BoxMesh.new()
	blade.size = Vector3(0.9, 9.0, 0.3)
	var ring: Array[Transform3D] = []
	for k in 40:
		var a: float = k * TAU / 40.0
		ring.append(Transform3D(Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, 0.0), top + Vector3(cos(a) * 32.0, 5.0, sin(a) * 26.0)))
	HillBuilder._multi(parent, blade, ring, false, _mat("far_blade", Color(0.35, 0.36, 0.4), 0.5, 0.6))


# ---------------------------------------------------------------- 숲·바위·갈대·풀

## 길·개울·찾을 것에서 떨어진 자리인가(칸 좌표).
static func _free(c: Vector2, gap: float = 2.5) -> bool:
	var x: float = c.x * Grid.CELL
	var z: float = c.y * Grid.CELL
	if road_dist(x, z) < 5.0 or absf(z - brook_z(x)) < 9.0:
		return false
	if c.distance_to(FieldLayout.CRYPT_DOOR) < 6.0:
		return false
	if c.distance_to(FieldLayout.TOWER) < 7.0 or c.distance_to(Vector2(76, 84)) < 4.0:
		return false
	if c.y > 105.0 or c.y < 7.0 and absf(c.x - 55.0) < 12.0:
		return false
	for k in FieldLayout.CACHES:
		if c.distance_to(FieldLayout.CACHES[k][0]) < gap:
			return false
	for k in FieldLayout.STONES:
		if c.distance_to(FieldLayout.STONES[k][0]) < gap:
			return false
	for g in FieldLayout.GLINTS:
		if c.distance_to(g) < gap:
			return false
	return true


static func _forest(parent: Node3D, rng: RandomNumberGenerator, circles: Array) -> void:
	var by_v: Array = [[], [], []]
	var tries: int = 0
	var n: int = 0
	var W: float = FieldLayout.WORLD
	while n < 520 and tries < 20000:
		tries += 1
		var x: float = rng.randf_range(-80.0, W + 80.0)
		var z: float = rng.randf_range(-100.0, W + 70.0)
		var e: float = _outside(x, z)
		var inner: float = minf(minf(x, W - x), minf(z, W - z))
		var in_field: bool = e <= 0.0
		# 들판 안은 둘레 6m 띠(막힌 곳)와 드문 외톨이만, 밖은 짙게
		if in_field and inner > 6.0:
			if rng.randf() > 0.06 or not _free(Vector2(x, z) / Grid.CELL, 4.0):
				continue
		if not in_field and e > 70.0 + 30.0 * rng.randf():
			continue
		if absf(x - 110.0) < 14.0 and (z < 14.0 or z > W - 14.0):
			continue
		var h: float = height(x, z)
		var s: float = rng.randf_range(0.9, 1.7)
		by_v[n % 3].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, h - 0.1, z)))
		if in_field and inner > 6.0:
			circles.append([Vector2(x, z) / Grid.CELL, 0.35])
		n += 1
	for v in 3:
		var xs: Array[Transform3D] = []
		xs.assign(by_v[v])
		var mmi: MultiMeshInstance3D = HillBuilder._multi(parent, HillBuilder.pine(v), xs, true, HillBuilder.pine_mat())
		mmi.visibility_range_end = 260.0


static func _rocks(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var parts: Array[Dictionary] = HillBuilder.rock_parts()
	var W: float = FieldLayout.WORLD
	for i in 46:
		var edge: bool = i < 36
		var x: float
		var z: float
		if edge:
			var side: int = rng.randi() % 3
			var t: float = rng.randf_range(0.0, W)
			if side == 0:
				x = rng.randf_range(2.0, 7.0)
				z = t
			elif side == 1:
				x = W - rng.randf_range(2.0, 7.0)
				z = t
			else:
				x = t
				z = rng.randf_range(2.0, 7.0)
			if z > W - 8.0 or absf(x - 110.0) < 12.0 and z < 12.0:
				continue
		else:
			x = rng.randf_range(10.0, W - 10.0)
			z = rng.randf_range(20.0, W - 20.0)
			if not _free(Vector2(x, z) / Grid.CELL, 3.0):
				continue
		var at := Vector3(x, height(x, z), z)
		var s: float = rng.randf_range(2.0, 4.5) if edge else rng.randf_range(0.8, 1.8)
		var mi: MeshInstance3D
		if parts.is_empty():
			mi = _box(parent, Vector3(1.4, 1.0, 1.1) * s, at + Vector3(0, 0.3 * s, 0), _stone(), Vector3(0, rng.randf() * TAU, 0))
		else:
			mi = HillBuilder.put_flat(parent, parts[rng.randi() % parts.size()], at, rng.randf() * TAU, s)
		mi.visibility_range_end = 160.0


static func _reeds(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var xs: Array[Transform3D] = []
	var tries: int = 0
	while xs.size() < 260 and tries < 4000:
		tries += 1
		var x: float = rng.randf_range(4.0, FieldLayout.WORLD - 4.0)
		var side: float = -1.0 if rng.randf() < 0.5 else 1.0
		var z: float = brook_z(x) + side * rng.randf_range(4.0, 8.0)
		if absf(x - FieldLayout.BRIDGE_X) < 4.0 or road_dist(x, z) < 3.0:
			continue
		var h: float = rng.randf_range(0.9, 1.6)
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2))
		xs.append(Transform3D(b.scaled(Vector3(1, h, 1)), Vector3(x, height(x, z) + h / 2.0 - 0.05, z)))
	var rm := BoxMesh.new()
	rm.size = Vector3(0.04, 1.0, 0.04)
	var mmi: MultiMeshInstance3D = HillBuilder._multi(parent, rm, xs, false, _mat("reed", Color(0.28, 0.27, 0.12)))
	mmi.visibility_range_end = 90.0


static func _grass(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var mesh: Mesh = HillBuilder._tuft_mesh(rng)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	var xs: Array[Transform3D] = []
	var cs: Array[Color] = []
	var tries: int = 0
	var W: float = FieldLayout.WORLD
	while xs.size() < 16000 and tries < 60000:
		tries += 1
		var x: float = rng.randf_range(4.0, W - 4.0)
		var z: float = rng.randf_range(4.0, W - 4.0)
		if road_dist(x, z) < 2.6:
			continue
		var h: float = height(x, z)
		if h < -0.3:
			continue
		var slope: float = absf(height(x + 1.0, z) - h) + absf(height(x, z + 1.0) - h)
		if slope > 1.0:
			continue
		var s: float = rng.randf_range(0.6, 1.3)
		xs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s)), Vector3(x, h - 0.03, z)))
		cs.append(Color(rng.randf(), rng.randf() * rng.randf(), rng.randf(), 1.0))
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
		mm.set_instance_custom_data(i, cs[i])
	var mat := ShaderMaterial.new()
	mat.shader = HillBuilder.GRASS_SHADER
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Grass"
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 80.0
	parent.add_child(mmi)


# ---------------------------------------------------------------- 찾을 것의 모양

## 유품 상자(홀수는 나무 상자, 짝수는 자루 꾸러미). 열림은 open_cache.
static func cache(parent: Node3D, id: String) -> Node3D:
	var n := Node3D.new()
	n.name = id
	n.position = at_cell(FieldLayout.CACHES[id][0])
	n.rotation.y = float(id.hash() % 628) / 100.0
	var chest: bool = int(id.substr(id.length() - 1)) % 2 == 1
	n.set_meta("chest", chest)
	if chest:
		_box(n, Vector3(1.0, 0.5, 0.65), Vector3(0, 0.25, 0), _wood())
		var lid := Node3D.new()
		lid.name = "Lid"
		lid.position = Vector3(0, 0.5, -0.32)
		n.add_child(lid)
		_box(lid, Vector3(1.04, 0.16, 0.69), Vector3(0, 0.08, 0.32), _wood())
		_box(lid, Vector3(0.12, 0.2, 0.72), Vector3(0.25, 0.09, 0.32), _mat("iron", Color(0.14, 0.14, 0.15), 0.6, 0.6))
	else:
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		var sack := MeshInstance3D.new()
		sack.name = "Sack"
		sack.mesh = sm
		sack.material_override = _mat("cloth", Color(0.36, 0.3, 0.2))
		sack.scale = Vector3(1.0, 0.8, 0.9)
		sack.position = Vector3(0, 0.38, 0)
		n.add_child(sack)
		_box(n, Vector3(0.06, 0.9, 0.06), Vector3(0.6, 0.45, 0), _wood(), Vector3(0, 0, -0.12))
		_box(n, Vector3(0.5, 0.06, 0.06), Vector3(0.6, 0.7, 0), _wood(), Vector3(0, 0, -0.12))
	parent.add_child(n)
	return n


static func open_cache(n: Node3D) -> void:
	var t := n.create_tween()
	if n.get_meta("chest", true):
		t.tween_property(n.get_node("Lid"), "rotation:x", -1.7, 0.35)
	else:
		t.tween_property(n.get_node("Sack"), "scale", Vector3(1.2, 0.35, 1.1), 0.3)


## 이야기 비석.
static func stone(parent: Node3D, id: String) -> Node3D:
	var n := Node3D.new()
	n.name = id
	n.position = at_cell(FieldLayout.STONES[id][0])
	n.rotation = Vector3(0, float(id.hash() % 628) / 100.0, 0.05)
	var m := VillageBuilder.noise_mat("field_stone", Color(0.2, 0.2, 0.21), Color(0.42, 0.42, 0.43), 2.5, 0.06)
	var slab := _box(n, Vector3(1.0, 1.9, 0.3), Vector3(0, 0.85, 0), m)
	slab.name = "Slab"
	_box(n, Vector3(1.4, 0.3, 0.8), Vector3(0, 0.05, 0), m)
	var moss := _mat("moss", Color(0.12, 0.2, 0.08))
	_box(n, Vector3(1.0, 0.4, 0.34), Vector3(0, 0.2, 0), moss)
	parent.add_child(n)
	return n


## 읽은 비석은 희미하게 빛난다.
static func read_stone(n: Node3D) -> void:
	var slab := n.get_node("Slab") as MeshInstance3D
	var g := StandardMaterial3D.new()
	g.albedo_color = Color(0.3, 0.3, 0.32)
	g.emission_enabled = true
	g.emission = Color(0.55, 0.7, 0.85)
	g.emission_energy_multiplier = 0.0
	slab.material_override = g
	var t := n.create_tween()
	t.tween_property(g, "emission_energy_multiplier", 0.5, 1.0)


## 흩어진 조각: 풀숲에 희미하게 반짝이는 쇳조각.
static func glint(parent: Node3D, i: int) -> Node3D:
	var n := Node3D.new()
	n.name = "glint_%d" % i
	n.position = at_cell(FieldLayout.GLINTS[i], 0.05)
	n.rotation.y = i * 1.3
	_box(n, Vector3(0.12, 0.03, 0.4), Vector3(0, 0.12, 0), _mat("glint", Color(0.95, 0.8, 0.45), 0.3, 0.8, 1.6), Vector3(0.3, 0, 0.2))
	_box(n, Vector3(0.08, 0.02, 0.2), Vector3(0.18, 0.08, 0.1), _mat("glint", Color(0.95, 0.8, 0.45), 0.3, 0.8, 1.6), Vector3(-0.2, 0.8, 0.1))
	parent.add_child(n)
	return n


## 줍힘: 작아지며 사라진다.
static func take_glint(n: Node3D) -> void:
	var t := n.create_tween()
	t.tween_property(n, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
	t.tween_callback(n.queue_free)
