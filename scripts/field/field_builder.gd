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
	return Vector2(x - clampf(x, 0.0, FieldLayout.WORLD_X), z - clampf(z, 0.0, FieldLayout.WORLD_Z)).length()


## 안개 늪 자리의 가장자리를 부드럽게 한 0~1(m 좌표).
static func marsh_mask(x: float, z: float) -> float:
	var a: Rect2 = FieldLayout.AREAS[&"marsh"]
	var x0: float = a.position.x * Grid.CELL
	var x1: float = a.end.x * Grid.CELL
	var z0: float = a.position.y * Grid.CELL
	var z1: float = a.end.y * Grid.CELL
	return smoothstep(0.0, 14.0, minf(x - x0, x1 - x)) * smoothstep(0.0, 14.0, minf(z - z0, z1 - z))


## 땅 높이(m): 완만한 굴곡, 개울 바닥, 북쪽으로 오르는 땅, 둘레의 오르막.
static func height(x: float, z: float) -> float:
	if _n == null:
		setup()
	var h: float = 1.0 + _n.get_noise_2d(x, z) * 1.6
	h += 7.0 * (1.0 - smoothstep(0.0, 70.0, z))
	var e: float = _outside(x, z)
	h += 14.0 * smoothstep(0.0, 60.0, e) + e * 0.03
	# 원래 동쪽 둘레(x 214~220m)는 개울 근처만 틈을 낸 언덕 띠(20단계)
	h += 4.5 * exp(-pow((x - 217.0) / 5.0, 2.0)) * smoothstep(6.0, 14.0, absf(z - 118.0))
	# 20단계 동쪽 둘레(x 334~340m): 틈(EAST_GAPS) 셋을 빼고 솟은 언덕 띠(28단계)
	var rk: float = 1.0
	for g in FieldLayout.EAST_GAPS:
		rk = minf(rk, smoothstep(g.y - 8.0, g.y, absf(z - g.x)))
	h += 4.5 * exp(-pow((x - 337.0) / 5.0, 2.0)) * rk
	h += new_land(x, z)
	var m: float = marsh_mask(x, z)
	if m > 0.0:   # 안개 늪: 얕은 물 높이보다 조금 높은 땅과 군데군데 웅덩이
		var pool: float = smoothstep(0.02, 0.22, _n.get_noise_2d(x * 2.6 + 900.0, z * 2.6))
		h = lerpf(h, 0.35 + _n.get_noise_2d(x * 5.0, z * 5.0) * 0.15 - pool * 0.9, m)
	var w: float = exp(-pow((z - brook_z(x)) / 4.5, 2.0))
	return lerpf(h, -1.8, w * 0.95)


## 새 곳 셋(28단계)이 더하는 높이(m): 채석장의 구덩이(깊이 QUARRY_PIT_DEPTH), 고개의 오르막과 양쪽 벼랑 옆 솟음.
static func new_land(x: float, z: float) -> float:
	var out: float = 0.0
	var c: Vector2 = FieldLayout.QUARRY_PIT_AT * Grid.CELL
	var r: Vector2 = FieldLayout.QUARRY_PIT_R * Grid.CELL
	var q: float = Vector2((x - c.x) / r.x, (z - c.y) / r.y).length()
	out -= FieldLayout.QUARRY_PIT_DEPTH * (1.0 - smoothstep(0.55, 1.0, q))
	if x > 340.0:   # 까마귀 고개: 동쪽으로 오르고, 길(z 184~196) 양쪽은 솟는다(불탄 마을 쪽 틈은 빼고)
		var in_pass: float = smoothstep(158.0, 170.0, z) * (1.0 - smoothstep(214.0, 222.0, z))
		out += FieldLayout.PASS_RISE * smoothstep(344.0, 452.0, x) * in_pass
		var side: float = smoothstep(8.0, 14.0, absf(z - 190.0)) * smoothstep(3.0, 9.0, absf(x - 386.0))
		out += FieldLayout.PASS_WALL * side * in_pass * smoothstep(340.0, 350.0, x)
	return out


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
	_keep(parent, rects)
	_east_ridge(parent, circles)
	_east_ridge(parent, circles, 337.0, 23)
	_quarry(parent, rects)
	_hamlet(parent, rects)
	_pass(parent, rects)
	_old_field(parent, rng, circles)
	_grove(parent, rng, circles)
	_foot(parent, circles)
	_crypt_gate(parent, rects)
	_palisade(parent)
	_far_hill(parent)
	_forest(parent, rng, circles)
	_rocks(parent, rng)
	_reeds(parent, rng)
	_marsh(parent, circles)
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

static func _axis(world: float) -> PackedFloat32Array:
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
	while x <= world + 8.0:
		a.append(x)
		x += 2.0
	s = 2.0
	q = x - 2.0
	while q < world + 560.0:
		s = minf(s * 1.12, 40.0)
		q += s
		a.append(q)
	return a


static func _terrain(parent: Node3D) -> void:
	var ax := _axis(FieldLayout.WORLD_X)
	var az := _axis(FieldLayout.WORLD_Z)
	var n: int = ax.size()
	var nz: int = az.size()
	var verts := PackedVector3Array()
	verts.resize(n * nz)
	for j in nz:
		for i in n:
			verts[j * n + i] = Vector3(ax[i], height(ax[i], az[j]), az[j])
	var norms := PackedVector3Array()
	norms.resize(n * nz)
	for j in nz:
		var j0: int = maxi(j - 1, 0)
		var j1: int = mini(j + 1, nz - 1)
		for i in n:
			var i0: int = maxi(i - 1, 0)
			var i1: int = mini(i + 1, n - 1)
			var dx: Vector3 = verts[j * n + i1] - verts[j * n + i0]
			var dz: Vector3 = verts[j1 * n + i] - verts[j0 * n + i]
			norms[j * n + i] = dz.cross(dx).normalized()
	var idx := PackedInt32Array()
	idx.resize((n - 1) * (nz - 1) * 6)
	var k: int = 0
	for j in nz - 1:
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
	pm.size = Vector2(560.0, 34.0)
	var mi := MeshInstance3D.new()
	mi.name = "Brook"
	mi.mesh = pm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(230.0, WATER_Y, 116.0)
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


# ---------------------------------------------------------------- 무너진 성채 (20단계)

## 무너진 성벽(KEEP_WALLS의 돌 상자 줄, 높이가 들쭉날쭉하고 군데군데 낮게 무너졌다)과 반쯤 남은 탑(KEEP_TOWER).
## 그린 곳이 곧 막힌 곳이다(표 하나). 글자 없음.
static func _keep(parent: Node3D, rects: Array[Rect2]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20
	var st: Material = _stone()
	for w in FieldLayout.KEEP_WALLS:
		var along_x: bool = w.size.x >= w.size.y
		var length: float = (w.size.x if along_x else w.size.y) * Grid.CELL
		var thick: float = (w.size.y if along_x else w.size.x) * Grid.CELL
		var n: int = maxi(int(length / 2.4), 1)
		var seg: float = length / n
		for k in n:
			var h: float = rng.randf_range(1.4, 4.4)
			if rng.randf() < 0.3:
				h = rng.randf_range(0.4, 1.0)   # 무너진 자리
			var along: float = (k + 0.5) * seg
			var cx: float = (w.position.x * Grid.CELL + along) if along_x else (w.position.x + w.size.x / 2.0) * Grid.CELL
			var cz: float = (w.position.y + w.size.y / 2.0) * Grid.CELL if along_x else (w.position.y * Grid.CELL + along)
			var size: Vector3 = Vector3(seg * 1.04, h, thick) if along_x else Vector3(thick, h, seg * 1.04)
			_box(parent, size, Vector3(cx, height(cx, cz) + h / 2.0 - 0.3, cz), st, Vector3(0.0, rng.randf_range(-0.04, 0.04), 0.0), 200.0)
		rects.append(w)
		# 벽 곁에 떨어진 돌
		for k in 6:
			var s: float = rng.randf_range(0.4, 1.0)
			var px: float = (w.position.x + w.size.x * rng.randf()) * Grid.CELL + (rng.randf_range(-3.5, 3.5) if not along_x else 0.0)
			var pz: float = (w.position.y + w.size.y * rng.randf()) * Grid.CELL + (rng.randf_range(-3.5, 3.5) if along_x else 0.0)
			_box(parent, Vector3(s, s * 0.7, s * 1.2), Vector3(px, height(px, pz) + s * 0.2, pz), st, Vector3(rng.randf() * 0.5, rng.randf() * TAU, rng.randf() * 0.5), 120.0)
	# 반쯤 남은 탑: 둘레에 돌 상자를 두르고 한쪽 모서리만 높이 남았다
	var c: Vector2 = FieldLayout.KEEP_TOWER.get_center() * Grid.CELL
	var half: float = FieldLayout.KEEP_TOWER.size.x * Grid.CELL / 2.0 - 0.8
	var base: float = height(c.x, c.y)
	for side in 4:
		var yaw: float = side * PI / 2.0
		var dir := Vector3(cos(yaw), 0, sin(yaw))
		var out := Vector3(-dir.z, 0, dir.x) * half
		for k in 7:
			var off: float = -half + 0.8 + k * 1.6
			var h: float = rng.randf_range(1.0, 5.0)
			if side == 3 and k >= 5:
				h = 10.5 if k == 6 else 8.0
			elif side == 1 and k >= 2 and k <= 4:
				h = rng.randf_range(0.3, 0.7)   # 무너져 열린 쪽
			var p: Vector3 = Vector3(c.x, 0, c.y) + dir * off + out
			_box(parent, Vector3(1.7, h, 1.0), Vector3(p.x, base + h / 2.0 - 0.3, p.z), st, Vector3(0, -yaw + PI / 2.0, 0), 220.0)
	for i in 14:   # 탑에서 쏟아진 돌
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(half + 1.0, half + 5.0)
		var s: float = rng.randf_range(0.4, 1.2)
		var x: float = c.x + cos(a) * r
		var z: float = c.y + sin(a) * r
		_box(parent, Vector3(s, s * 0.7, s * 1.2), Vector3(x, height(x, z) + s * 0.2, z), st, Vector3(rng.randf() * 0.6, rng.randf() * TAU, rng.randf() * 0.6), 120.0)
	var wd: Material = _wood()
	for i in 3:
		_box(parent, Vector3(0.3, 0.3, 6.0), Vector3(c.x + rng.randf_range(-1.5, 1.5), base + 3.4 + i * 0.5, c.y + rng.randf_range(-1.5, 1.5)), wd, Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * PI, rng.randf_range(-0.3, 0.3)))
	rects.append(FieldLayout.KEEP_TOWER)


# ---------------------------------------------------------------- 원래 동쪽 둘레 (20단계)

## 동쪽 둘레(원래 x 214~220m, 28단계에서 새 둘레 x 334~340m도)의 숲과 벼랑 돌. 틈(gaps: Vector2(가운데 z m, 반폭 m))만 비워 이어진다(막힘은 BORDER_RECTS).
static func _east_ridge(parent: Node3D, _circles: Array, cx: float = 217.0, seed_value: int = 22) -> void:
	var gaps: Array[Vector2] = [Vector2(118.0, 14.0)]
	if cx > 300.0:
		gaps.assign(FieldLayout.EAST_GAPS)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var by_v: Array = [[], [], []]
	var n: int = 0
	var tries: int = 0
	while n < 120 and tries < 4000:
		tries += 1
		var x: float = rng.randf_range(cx - 11.0, cx + 9.0)
		var z: float = rng.randf_range(-10.0, FieldLayout.WORLD_Z + 10.0)
		if _in_gap(z, gaps, 1.0):
			continue
		var s: float = rng.randf_range(0.9, 1.7)
		by_v[n % 3].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, height(x, z) - 0.1, z)))
		n += 1
	for v in 3:
		var xs: Array[Transform3D] = []
		xs.assign(by_v[v])
		if not xs.is_empty():
			HillBuilder._multi(parent, HillBuilder.pine(v), xs, true, HillBuilder.pine_mat()).visibility_range_end = 260.0
	var parts: Array[Dictionary] = HillBuilder.rock_parts()
	for i in 16:
		var x: float = rng.randf_range(cx - 7.0, cx + 7.0)
		var z: float = rng.randf_range(0.0, FieldLayout.WORLD_Z - 12.0)
		if _in_gap(z, gaps, 0.0):
			continue
		var at := Vector3(x, height(x, z), z)
		var s: float = rng.randf_range(2.5, 4.5)
		var mi: MeshInstance3D
		if parts.is_empty():
			mi = _box(parent, Vector3(1.4, 1.0, 1.1) * s, at + Vector3(0, 0.3 * s, 0), _stone(), Vector3(0, rng.randf() * TAU, 0))
		else:
			mi = HillBuilder.put_flat(parent, parts[rng.randi() % parts.size()], at, rng.randf() * TAU, s)
		mi.visibility_range_end = 160.0


static func _in_gap(z: float, gaps: Array[Vector2], extra: float) -> bool:
	for g in gaps:
		if absf(z - g.x) < g.y + extra:
			return true
	return false


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
	while x < FieldLayout.WORLD_X:
		if x < gap_a or x > gap_b:
			var h: float = rng.randf_range(2.6, 3.5)
			xs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1, h / 3.0, 1)), Vector3(x, height(x, z) + h / 2.0 - 0.3, z + rng.randf_range(-0.08, 0.08))))
		x += 0.55
	var pm := BoxMesh.new()
	pm.size = Vector3(0.3, 3.0, 0.3)
	HillBuilder._multi(parent, pm, xs, true, _wood()).name = "PalisadePosts"
	for r in 2:
		for seg in [[0.0, gap_a], [gap_b, FieldLayout.WORLD_X]]:
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
	for k in FieldLayout.PACKS:
		if c.distance_to(FieldLayout.PACKS[k].at) < float(FieldLayout.PACKS[k].wander) + 1.5:
			return false
	for w in FieldLayout.KEEP_WALLS:
		if w.grow(3.0).has_point(c):
			return false
	if FieldLayout.KEEP_TOWER.grow(5.0).has_point(c):
		return false
	for r in _new_blocks():   # 28단계 새 곳의 막힘 둘레에는 숲·바위 흩뿌림이 서지 않는다
		if r.grow(3.0).has_point(c):
			return false
	if FieldLayout.QUARRY_PIT_AT.distance_to(c) < FieldLayout.QUARRY_PIT_R.x + 2.0 and absf(c.y - FieldLayout.QUARRY_PIT_AT.y) < FieldLayout.QUARRY_PIT_R.y + 2.0:
		return false
	return true


## 돌바닥 곳(채석장·까마귀 고개): 숲과 풀이 서지 않는다(m 좌표).
static func _rocky(x: float, z: float) -> bool:
	var c := Vector2(x, z) / Grid.CELL
	return (FieldLayout.AREAS[&"quarry"] as Rect2).has_point(c) or (FieldLayout.AREAS[&"pass"] as Rect2).has_point(c)


## 새 곳 셋의 막힌 곳(칸 단위) 전부.
static func _new_blocks() -> Array[Rect2]:
	var out: Array[Rect2] = []
	out.append_array(FieldLayout.QUARRY_CLIFFS)
	out.append_array(FieldLayout.QUARRY_BLOCKS)
	out.append_array(FieldLayout.QUARRY_POSTS)
	out.append_array(FieldLayout.HAMLET_WALLS)
	out.append_array(FieldLayout.HAMLET_FENCES)
	out.append(FieldLayout.HAMLET_WELL)
	out.append_array(FieldLayout.PASS_CLIFFS)
	return out


static func _forest(parent: Node3D, rng: RandomNumberGenerator, circles: Array) -> void:
	var by_v: Array = [[], [], []]
	var tries: int = 0
	var n: int = 0
	var WX: float = FieldLayout.WORLD_X
	var WZ: float = FieldLayout.WORLD_Z
	while n < 920 and tries < 40000:
		tries += 1
		var x: float = rng.randf_range(-80.0, WX + 80.0)
		var z: float = rng.randf_range(-100.0, WZ + 70.0)
		var e: float = _outside(x, z)
		var inner: float = minf(minf(x, WX - x), minf(z, WZ - z))
		var in_field: bool = e <= 0.0
		# 들판 안은 둘레 6m 띠(막힌 곳)와 드문 외톨이만, 밖은 짙게
		if in_field and inner > 6.0:
			if rng.randf() > 0.06 or not _free(Vector2(x, z) / Grid.CELL, 4.0) or marsh_mask(x, z) > 0.0:
				continue
		if not in_field and e > 70.0 + 30.0 * rng.randf():
			continue
		if in_field and _rocky(x, z):
			continue
		if absf(x - 110.0) < 14.0 and (z < 14.0 or z > WZ - 14.0):
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
	var WX: float = FieldLayout.WORLD_X
	var WZ: float = FieldLayout.WORLD_Z
	for i in 80:
		var edge: bool = i < 64
		var x: float
		var z: float
		if edge:
			var side: int = rng.randi() % 3
			if side == 0:
				x = rng.randf_range(2.0, 7.0)
				z = rng.randf_range(0.0, WZ)
			elif side == 1:
				x = WX - rng.randf_range(2.0, 7.0)
				z = rng.randf_range(0.0, WZ)
			else:
				x = rng.randf_range(0.0, WX)
				z = rng.randf_range(2.0, 7.0)
			if z > WZ - 8.0 or absf(x - 110.0) < 12.0 and z < 12.0:
				continue
		else:
			x = rng.randf_range(10.0, WX - 10.0)
			z = rng.randf_range(20.0, WZ - 20.0)
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
	while xs.size() < 380 and tries < 6000:
		tries += 1
		var x: float = rng.randf_range(4.0, FieldLayout.WORLD_X - 4.0)
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
	while xs.size() < 28000 and tries < 110000:
		tries += 1
		var x: float = rng.randf_range(4.0, FieldLayout.WORLD_X - 4.0)
		var z: float = rng.randf_range(4.0, FieldLayout.WORLD_Z - 4.0)
		if road_dist(x, z) < 2.6:
			continue
		var h: float = height(x, z)
		if h < -0.3 or (h < 0.12 and marsh_mask(x, z) > 0.2) or _rocky(x, z):
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


# ---------------------------------------------------------------- 안개 늪 (20단계)

## 얕은 물 판, 마른 나무(MultiMesh), 갈대 덤불(MultiMesh). 안개는 field.gd가 화면만 짙게 한다.
static func _marsh(parent: Node3D, circles: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var a: Rect2 = FieldLayout.AREAS[&"marsh"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.13, 0.19, 0.16, 0.72)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	m.metallic = 0.2
	var pm := PlaneMesh.new()
	pm.size = a.size * Grid.CELL
	var water := MeshInstance3D.new()
	water.name = "MarshWater"
	water.mesh = pm
	water.material_override = m
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.position = Vector3(a.get_center().x * Grid.CELL, 0.0, a.get_center().y * Grid.CELL)
	parent.add_child(water)
	var by_v: Array = [[], [], [], []]
	var n: int = 0
	var tries: int = 0
	while n < 36 and tries < 3000:
		tries += 1
		var c := Vector2(rng.randf_range(a.position.x + 3.0, a.end.x - 3.0), rng.randf_range(a.position.y + 3.0, a.end.y - 3.0))
		if not _free(c, 3.0):
			continue
		var x: float = c.x * Grid.CELL
		var z: float = c.y * Grid.CELL
		if height(x, z) < 0.1:
			continue
		var s: float = rng.randf_range(0.9, 1.5)
		by_v[n % 4].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, height(x, z) - 0.1, z)))
		circles.append([c, 0.3])
		n += 1
	for v in 4:
		var xs: Array[Transform3D] = []
		xs.assign(by_v[v])
		if not xs.is_empty():
			HillBuilder._multi(parent, HillBuilder.bare_tree(v), xs, true, HillBuilder.bark()).visibility_range_end = 150.0
	var reeds: Array[Transform3D] = []
	var clumps: int = 0
	tries = 0
	while clumps < 90 and tries < 3000:
		tries += 1
		var cx: float = rng.randf_range(a.position.x + 2.0, a.end.x - 2.0) * Grid.CELL
		var cz: float = rng.randf_range(a.position.y + 2.0, a.end.y - 2.0) * Grid.CELL
		var hc: float = height(cx, cz)
		if hc > 0.6 or hc < -0.5:
			continue
		for k in 7:
			var x: float = cx + rng.randf_range(-1.4, 1.4)
			var z: float = cz + rng.randf_range(-1.4, 1.4)
			var h: float = rng.randf_range(1.1, 2.2)
			var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.25, 0.25))
			reeds.append(Transform3D(b.scaled(Vector3(1, h, 1)), Vector3(x, height(x, z) + h / 2.0 - 0.05, z)))
		clumps += 1
	var rm := BoxMesh.new()
	rm.size = Vector3(0.04, 1.0, 0.04)
	HillBuilder._multi(parent, rm, reeds, false, _mat("reed", Color(0.28, 0.27, 0.12))).visibility_range_end = 90.0


# ---------------------------------------------------------------- 새 곳 셋 (28단계)

static func _char_mat() -> Material:
	return VillageBuilder.noise_mat("hamlet_char", Color(0.02, 0.017, 0.015), Color(0.1, 0.078, 0.064), 3.0, 0.09)


static func _cut_stone() -> Material:
	return VillageBuilder.noise_mat("quarry_cut", Color(0.3, 0.28, 0.26), Color(0.52, 0.5, 0.46), 2.0, 0.05)


## 돌 벼랑 한 줄(칸 표 rect): 긴 쪽을 따라 돌 상자를 세운다(높이가 들쭉날쭉). 그린 곳이 곧 막힌 곳이다.
static func _cliff(parent: Node3D, r: Rect2, rng: RandomNumberGenerator, m: Material, hmin: float, hmax: float) -> void:
	var along_x: bool = r.size.x >= r.size.y
	var length: float = (r.size.x if along_x else r.size.y) * Grid.CELL
	var depth: float = (r.size.y if along_x else r.size.x) * Grid.CELL
	var n: int = maxi(int(length / 2.8), 1)
	var seg: float = length / n
	for k in n:
		var h: float = rng.randf_range(hmin, hmax)
		var along: float = (k + 0.5) * seg
		var cx: float = (r.position.x * Grid.CELL + along) if along_x else (r.position.x + r.size.x / 2.0) * Grid.CELL
		var cz: float = (r.position.y + r.size.y / 2.0) * Grid.CELL if along_x else (r.position.y * Grid.CELL + along)
		var base: float = height(cx, cz)
		var size: Vector3 = Vector3(seg * 1.05, h, depth) if along_x else Vector3(depth, h, seg * 1.05)
		_box(parent, size, Vector3(cx, base + h / 2.0 - 1.2, cz), m, Vector3(0.0, rng.randf_range(-0.03, 0.03), 0.0), 260.0)


## 흩어진 돌(깬 돌, 불탄 잔해)을 rect 둘레에 뿌린다. 작아서 막힘에 넣지 않는다.
static func _scatter(parent: Node3D, r: Rect2, count: int, spread: float, m: Material, rng: RandomNumberGenerator, smin: float = 0.3, smax: float = 0.9) -> void:
	for i in count:
		var x: float = (r.position.x + r.size.x * rng.randf()) * Grid.CELL + rng.randf_range(-spread, spread)
		var z: float = (r.position.y + r.size.y * rng.randf()) * Grid.CELL + rng.randf_range(-spread, spread)
		var sz: float = rng.randf_range(smin, smax)
		_box(parent, Vector3(sz, sz * 0.7, sz * 1.2), Vector3(x, height(x, z) + sz * 0.2, z), m, Vector3(rng.randf() * 0.5, rng.randf() * TAU, rng.randf() * 0.5), 110.0)


## 버려진 채석장: 파인 구덩이(땅 높이 new_land), 돌 벼랑, 잘린 돌덩이, 나무 비계 둘. 글자 없음.
static func _quarry(parent: Node3D, rects: Array[Rect2]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 28
	var st: Material = _stone()
	for c in FieldLayout.QUARRY_CLIFFS:
		_cliff(parent, c, rng, st, 4.0, 8.0)
		rects.append(c)
	var cut: Material = _cut_stone()
	for b in FieldLayout.QUARRY_BLOCKS:   # 잘린 돌덩이: 큰 상자 위에 얹은 작은 상자
		var cx: float = b.get_center().x * Grid.CELL
		var cz: float = b.get_center().y * Grid.CELL
		var h: float = rng.randf_range(2.2, 3.4)
		var base: float = height(cx, cz)
		_box(parent, Vector3(b.size.x * Grid.CELL, h, b.size.y * Grid.CELL), Vector3(cx, base + h / 2.0 - 0.4, cz), cut)
		_box(parent, Vector3(b.size.x * Grid.CELL * 0.5, 0.9, b.size.y * Grid.CELL * 0.6), Vector3(cx + 0.4, base + h + 0.1, cz - 0.2), cut, Vector3(0.0, rng.randf_range(-0.3, 0.3), 0.0))
		rects.append(b)
	_scatter(parent, Rect2(176, 6, 46, 32), 40, 0.0, cut, rng)
	# 나무 비계: 기둥(막힘) 위에 가로대와 반쯤 남은 널
	var wd: Material = _wood()
	for gi in 2:
		var posts: Array[Rect2] = []
		for i in FieldLayout.QUARRY_POSTS.size():
			if (i < 6) == (gi == 0):
				posts.append(FieldLayout.QUARRY_POSTS[i])
		var lo := Vector2(1e9, 1e9)
		var hi := Vector2(-1e9, -1e9)
		for p in posts:
			var pc: Vector2 = p.get_center() * Grid.CELL
			_box(parent, Vector3(p.size.x * Grid.CELL, 4.6, p.size.y * Grid.CELL), Vector3(pc.x, height(pc.x, pc.y) + 2.0, pc.y), wd, Vector3(0.0, 0.0, rng.randf_range(-0.03, 0.03)))
			rects.append(p)
			lo = lo.min(pc)
			hi = hi.max(pc)
		var mid: Vector2 = (lo + hi) / 2.0
		var base: float = height(mid.x, mid.y)
		_box(parent, Vector3(hi.x - lo.x + 0.4, 0.22, 0.22), Vector3(mid.x, base + 1.8, lo.y), wd)
		_box(parent, Vector3(hi.x - lo.x + 0.4, 0.22, 0.22), Vector3(mid.x, base + 1.8, hi.y), wd)
		_box(parent, Vector3(0.22, 0.22, hi.y - lo.y + 0.4), Vector3(lo.x, base + 3.4, mid.y), wd)
		_box(parent, Vector3(0.22, 0.22, hi.y - lo.y + 0.4), Vector3(hi.x, base + 3.4, mid.y), wd)
		_box(parent, Vector3((hi.x - lo.x) * 0.55, 0.16, hi.y - lo.y + 0.6), Vector3(lo.x + (hi.x - lo.x) * 0.3, base + 3.55, mid.y), wd)   # 반쯤 남은 널
		_box(parent, Vector3(0.18, 0.18, 4.2), Vector3(mid.x + 0.8, base + 1.2, mid.y), wd, Vector3(0.6, 0.4, 0.2))   # 쓰러진 대들보


## 불탄 마을: 지붕 없이 그을린 집 벽(HAMLET_WALLS, 군데군데 낮게 무너짐), 우물, 무너진 울타리, 재와 숯 들보. 글자 없음.
static func _hamlet(parent: Node3D, rects: Array[Rect2]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 29
	var ch: Material = _char_mat()
	for w in FieldLayout.HAMLET_WALLS:
		var along_x: bool = w.size.x >= w.size.y
		var length: float = (w.size.x if along_x else w.size.y) * Grid.CELL
		var thick: float = (w.size.y if along_x else w.size.x) * Grid.CELL
		var n: int = maxi(int(length / 1.4), 1)
		var seg: float = length / n
		for k in n:
			var h: float = rng.randf_range(1.6, 3.2)
			if rng.randf() < 0.3:
				h = rng.randf_range(0.4, 0.9)   # 타서 내려앉은 자리
			var along: float = (k + 0.5) * seg
			var cx: float = (w.position.x * Grid.CELL + along) if along_x else (w.position.x + w.size.x / 2.0) * Grid.CELL
			var cz: float = (w.position.y + w.size.y / 2.0) * Grid.CELL if along_x else (w.position.y * Grid.CELL + along)
			var size: Vector3 = Vector3(seg * 1.04, h, thick) if along_x else Vector3(thick, h, seg * 1.04)
			_box(parent, size, Vector3(cx, height(cx, cz) + h / 2.0 - 0.2, cz), ch, Vector3(0.0, rng.randf_range(-0.03, 0.03), 0.0), 220.0)
		rects.append(w)
	# 집마다 타다 남은 들보와 재 무더기
	var ash: Material = _mat("ash", Color(0.06, 0.055, 0.05))
	for hz in [Rect2(174, 45, 7, 5), Rect2(198, 45, 6, 5), Rect2(212, 45, 7, 5), Rect2(176, 66, 7, 6), Rect2(200, 67, 6, 6), Rect2(214, 66, 7, 6)]:
		var c: Vector2 = (hz as Rect2).get_center() * Grid.CELL
		var base: float = height(c.x, c.y)
		_box(parent, Vector3((hz as Rect2).size.x * Grid.CELL * 0.8, 0.05, (hz as Rect2).size.y * Grid.CELL * 0.8), Vector3(c.x, base + 0.04, c.y), ash)
		for i in 3:
			_box(parent, Vector3(0.22, 0.22, rng.randf_range(2.2, 4.0)), Vector3(c.x + rng.randf_range(-1.5, 1.5), base + 0.5 + i * 0.15, c.y + rng.randf_range(-1.2, 1.2)), ch, Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * PI, rng.randf_range(-0.25, 0.25)))
		_scatter(parent, hz, 5, 0.5, ch, rng, 0.3, 0.7)
	# 우물: 돌 테두리와 부러진 두레박 기둥
	var well: Rect2 = FieldLayout.HAMLET_WELL
	var wc: Vector2 = well.get_center() * Grid.CELL
	var wb: float = height(wc.x, wc.y)
	var st: Material = _stone()
	for k in 8:
		var a: float = k * TAU / 8.0
		_box(parent, Vector3(0.9, 0.9, 0.5), Vector3(wc.x + cos(a) * 1.3, wb + 0.4, wc.y + sin(a) * 1.3), st, Vector3(0, -a + PI / 2.0, 0))
	_box(parent, Vector3(2.0, 0.04, 2.0), Vector3(wc.x, wb + 0.1, wc.y), _mat("ash", Color(0.06, 0.055, 0.05)))
	_box(parent, Vector3(0.2, 2.6, 0.2), Vector3(wc.x + 1.3, wb + 1.3, wc.y), _wood())
	_box(parent, Vector3(1.8, 0.16, 0.16), Vector3(wc.x + 0.5, wb + 2.5, wc.y), _wood(), Vector3(0.0, 0.0, 0.35))
	rects.append(well)
	# 무너진 울타리: 기둥과 부러진 가로대
	var wd: Material = _wood()
	for f in FieldLayout.HAMLET_FENCES:
		var along_x: bool = f.size.x >= f.size.y
		var length: float = (f.size.x if along_x else f.size.y) * Grid.CELL
		var n: int = maxi(int(length / 1.6), 2)
		for k in n + 1:
			var t: float = float(k) / n
			var x: float = (f.position.x + (f.size.x * t if along_x else f.size.x / 2.0)) * Grid.CELL
			var z: float = (f.position.y + (f.size.y / 2.0 if along_x else f.size.y * t)) * Grid.CELL
			var h: float = rng.randf_range(0.5, 1.4)
			_box(parent, Vector3(0.18, h, 0.18), Vector3(x, height(x, z) + h / 2.0 - 0.1, z), wd, Vector3(rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(-0.2, 0.2)), 200.0)
		var mx: float = (f.get_center().x) * Grid.CELL
		var mz: float = (f.get_center().y) * Grid.CELL
		_box(parent, Vector3(length * 0.7, 0.1, 0.1) if along_x else Vector3(0.1, 0.1, length * 0.7), Vector3(mx, height(mx, mz) + 0.8, mz), wd, Vector3(0.0, 0.0, rng.randf_range(-0.15, 0.15)), 200.0)
		rects.append(f)


## 까마귀 고개: 양쪽 돌 벼랑(PASS_CLIFFS, 땅은 new_land가 오르막으로 만든다), 길 가의 돌과 마른 나무.
static func _pass(parent: Node3D, rects: Array[Rect2]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 30
	var st: Material = _stone()
	for c in FieldLayout.PASS_CLIFFS:
		_cliff(parent, c, rng, st, 6.0, 11.0)
		rects.append(c)
	_scatter(parent, Rect2(172, 91, 54, 8), 30, 0.0, st, rng, 0.3, 1.1)
	var bt: Array[Transform3D] = []
	for i in 7:
		var x: float = rng.randf_range(176.0, 220.0) * Grid.CELL
		var z: float = (rng.randf_range(91.8, 92.8) if i % 2 == 0 else rng.randf_range(97.2, 98.2)) * Grid.CELL
		var s: float = rng.randf_range(0.8, 1.3)
		bt.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, height(x, z) - 0.1, z)))
	HillBuilder._multi(parent, HillBuilder.bare_tree(0), bt, true, HillBuilder.bark()).visibility_range_end = 150.0


# ---------------------------------------------------------------- 찾을 것의 모양

## 유품 상자(홀수는 나무 상자, 짝수는 자루 꾸러미). 열림은 open_cache.
static func cache(parent: Node3D, id: String) -> Node3D:
	var n := Node3D.new()
	n.name = id
	n.position = at_cell(FieldLayout.CACHES[id][0])
	n.rotation.y = float(id.hash() % 628) / 100.0
	if FieldLayout.BIG_CACHES.has(id):
		n.scale = Vector3.ONE * 1.6
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
