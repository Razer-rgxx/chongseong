class_name HillBuilder
extends RefCounted
## 언덕(한 판의 싸움터) 둘레의 땅과 꾸밈. 규칙과 상관없는 그림이라 고정 시드의 따로 된 랜덤을 쓴다.
## 싸움터(높이 0)는 언덕 꼭대기의 평평한 자리이고, 둘레 FLAT m까지 평평하다(적이 한 칸 밖에서 올라온다).
## 그 밖은 비탈이 내려가 골짜기가 되고, 멀리 산등성이가 둘러싼다.
## 에셋: assets/hill/(땅·나무껍질 질감), assets/nature/(Poly Haven 바위·통나무 모델), assets/sky/(하늘 HDRI).
## 파일이 없으면 그 자리는 단색이나 기본 도형으로 대신한다. 에셋을 바꿀 때는 이 파일만 고친다.

const FLAT: float = 5.0
const HILL_DIR: String = "res://assets/hill/"
const NATURE_DIR: String = "res://assets/nature/"
const SKY_DAY: String = "res://assets/sky/overcast_soil_puresky.hdr"
const SKY_NIGHT: String = "res://assets/sky/kloppenheim_02_puresky.hdr"
const TERRAIN_SHADER: Shader = preload("res://scripts/world/terrain.gdshader")
const SKY_SHADER: Shader = preload("res://scripts/world/hill_sky.gdshader")
const GRASS_SHADER: Shader = preload("res://scripts/world/grass.gdshader")

static var _w: float = 68.0
static var _d: float = 44.0
static var _n: FastNoiseLite
static var _r: FastNoiseLite


static func setup(size_m: Vector2) -> void:
	_w = size_m.x
	_d = size_m.y
	_n = FastNoiseLite.new()
	_n.seed = 11
	_n.frequency = 0.018
	_n.fractal_octaves = 4
	_r = FastNoiseLite.new()
	_r.seed = 23
	_r.frequency = 0.005
	_r.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_r.fractal_octaves = 4


## 싸움터 사각형 밖으로의 거리(m). 안이면 0.
static func outside(x: float, z: float) -> float:
	var cx: float = clampf(x, 0.0, _w)
	var cz: float = clampf(z, 0.0, _d)
	return Vector2(x - cx, z - cz).length()


## 땅 높이(m). 싸움터와 둘레 FLAT m는 0. 적이 싸움터 밖으로 밀려나면 화면이 이 높이에 세운다.
static func height(x: float, z: float) -> float:
	if _n == null:
		setup(Vector2(_w, _d))
	var e: float = outside(x, z) - FLAT
	if e <= 0.0:
		return 0.0
	var h: float = -26.0 * (1.0 - exp(-e / 22.0)) - e * 0.03
	h += _n.get_noise_2d(x, z) * 5.0 * smoothstep(6.0, 30.0, e)
	var r: float = Vector2(x - _w * 0.5, z - _d * 0.5).length()
	h += smoothstep(170.0, 420.0, r) * (55.0 + 55.0 * _r.get_noise_2d(x, z))
	return h


static func build(parent: Node3D, env: Environment, forms: Array[FormData]) -> void:
	setup(Vector2(Grid.size) * Grid.CELL)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_terrain(parent)
	_sky(env)
	_rocks(parent, rng)
	_logs(parent, rng)
	_dead_trees(parent, rng)
	_swords(parent, rng, forms)
	_floor(parent, rng)
	_pines(parent, rng)
	_grass(parent, rng)


# ---------------------------------------------------------------- 마을과 같이 쓰는 것(한 번 만들어 둔다)

static var _shared: Dictionary = {}


## 전나무 메시(변형 0~2).
static func pine(variant: int) -> Mesh:
	var key: String = "pine%d" % variant
	if not _shared.has(key):
		var rng := RandomNumberGenerator.new()
		rng.seed = 300 + variant
		_shared[key] = _pine_mesh(rng)
	return _shared[key]


static func pine_mat() -> Material:
	if not _shared.has("pine_mat"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 1.0
		_shared["pine_mat"] = m
	return _shared["pine_mat"]


## 잎 없는 나무 메시(변형 0~3).
static func bare_tree(variant: int) -> Mesh:
	var key: String = "bare%d" % variant
	if not _shared.has(key):
		var rng := RandomNumberGenerator.new()
		rng.seed = 500 + variant
		_shared[key] = _bare_tree_mesh(rng)
	return _shared[key]


static func bark() -> Material:
	if not _shared.has("bark"):
		_shared["bark"] = _bark_mat()
	return _shared["bark"]


## 이끼 낀 바위 조각들(Poly Haven). 없으면 빈 배열.
static func rock_parts() -> Array[Dictionary]:
	if not _shared.has("rocks"):
		_shared["rocks"] = _parts("rock_moss_set_01") + _parts("rock_moss_set_02")
	var out: Array[Dictionary] = []
	out.assign(_shared["rocks"])
	return out


static func branch_parts() -> Array[Dictionary]:
	if not _shared.has("branches"):
		_shared["branches"] = _parts("dry_branches_medium_01")
	var out: Array[Dictionary] = []
	out.assign(_shared["branches"])
	return out


## 평평한 땅(높이 0) 위에 조각 하나를 놓는다(마을용).
static func put_flat(parent: Node3D, part: Dictionary, at: Vector3, yaw: float, s: float, sink: float = 0.3) -> MeshInstance3D:
	var b := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s)
	var xf: Transform3D = Transform3D(b, at - Vector3(0, sink * part.size.y * s, 0)) * (part.xf as Transform3D)
	return _put(parent, part.mesh, xf, 0.0, true, part.mat)


## 하늘(HDRI)을 다른 장면(마을)에도 깐다. tint로 저녁빛을 준다.
static func apply_sky(env: Environment, tint: Color, energy: float) -> void:
	_sky(env)
	if sky_material:
		sky_material.set_shader_parameter("tint", tint)
		sky_material.set_shader_parameter("day_energy", energy)


# ---------------------------------------------------------------- 땅

## 한 축의 격자 위치. 싸움터 근처는 1m 간격, 멀어질수록 넓힌다.
static func _axis(lo: float, hi: float, near: float, far: float) -> PackedFloat32Array:
	var left: Array[float] = []
	var s: float = 1.0
	var q: float = lo - near
	while q > lo - far:
		s = minf(s * 1.1, 18.0)
		q -= s
		left.append(q)
	left.reverse()
	var a := PackedFloat32Array(left)
	var x: float = lo - near
	while x <= hi + near:
		a.append(x)
		x += 1.0
	s = 1.0
	q = x - 1.0
	while q < hi + far:
		s = minf(s * 1.1, 18.0)
		q += s
		a.append(q)
	return a


static func _terrain(parent: Node3D) -> void:
	var xs := _axis(0.0, _w, 60.0, 560.0)
	var zs := _axis(0.0, _d, 60.0, 560.0)
	var nx: int = xs.size()
	var nz: int = zs.size()
	var verts := PackedVector3Array()
	verts.resize(nx * nz)
	for j in nz:
		for i in nx:
			verts[j * nx + i] = Vector3(xs[i], height(xs[i], zs[j]), zs[j])
	var norms := PackedVector3Array()
	norms.resize(nx * nz)
	for j in nz:
		var j0: int = maxi(j - 1, 0)
		var j1: int = mini(j + 1, nz - 1)
		for i in nx:
			var i0: int = maxi(i - 1, 0)
			var i1: int = mini(i + 1, nx - 1)
			var dx: Vector3 = verts[j * nx + i1] - verts[j * nx + i0]
			var dz: Vector3 = verts[j1 * nx + i] - verts[j0 * nx + i]
			norms[j * nx + i] = dz.cross(dx).normalized()
	var idx := PackedInt32Array()
	idx.resize((nx - 1) * (nz - 1) * 6)
	var k: int = 0
	for j in nz - 1:
		for i in nx - 1:
			var a: int = j * nx + i
			var c: int = a + nx
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
	mi.material_override = _terrain_mat()
	parent.add_child(mi)


static func _terrain_mat() -> Material:
	if not _has_tex("forrest_ground_01") or not _has_tex("forest_ground_04") or not _has_tex("lichen_rock"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.2, 0.22, 0.16)
		m.roughness = 1.0
		return m
	var s := ShaderMaterial.new()
	s.shader = TERRAIN_SHADER
	for pair in [["grass", "forrest_ground_01"], ["dirt", "forest_ground_04"], ["rock", "lichen_rock"]]:
		var key: String = pair[0]
		var name: String = pair[1]
		var base: String = HILL_DIR + name + "/" + name
		s.set_shader_parameter(key + "_a", load(base + "_diff.jpg"))
		s.set_shader_parameter(key + "_n", load(base + "_nor_gl.jpg"))
		if ResourceLoader.exists(base + "_rough.jpg"):
			s.set_shader_parameter(key + "_r", load(base + "_rough.jpg"))
	var noise := FastNoiseLite.new()
	noise.seed = 5
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	tex.generate_mipmaps = true
	s.set_shader_parameter("macro", tex)
	s.set_shader_parameter("arena", Vector4(0.0, 0.0, _w, _d))
	return s


static func _has_tex(name: String) -> bool:
	return ResourceLoader.exists(HILL_DIR + name + "/" + name + "_diff.jpg")


# ---------------------------------------------------------------- 하늘

## 낮과 밤의 하늘을 하나의 셰이더로 섞는다. 반환한 재질의 night 값을 main이 0↔1로 옮긴다.
static var sky_material: ShaderMaterial = null


static func _sky(env: Environment) -> void:
	if not ResourceLoader.exists(SKY_DAY) or not ResourceLoader.exists(SKY_NIGHT):
		return
	var m := ShaderMaterial.new()
	m.shader = SKY_SHADER
	m.set_shader_parameter("day_sky", load(SKY_DAY))
	m.set_shader_parameter("night_sky", load(SKY_NIGHT))
	m.set_shader_parameter("night", 0.0)
	var sky := Sky.new()
	sky.sky_material = m
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	sky_material = m


# ---------------------------------------------------------------- 모델 조각

## 모델 파일 하나에 든 메시들. 각 메시를 바닥 가운데가 원점이 되게 옮기는 변환과 함께 돌려준다.
static func _parts(name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var path: String = NATURE_DIR + name + "/" + name + ".gltf"
	if not ResourceLoader.exists(path):
		return out
	var root: Node = (load(path) as PackedScene).instantiate()
	_collect(root, Transform3D.IDENTITY, out)
	root.free()
	return out


static func _collect(n: Node, t: Transform3D, out: Array[Dictionary]) -> void:
	var tt: Transform3D = t
	if n is Node3D:
		tt = t * (n as Node3D).transform
	var mi := n as MeshInstance3D
	if mi and mi.mesh:
		var a: AABB = tt * mi.mesh.get_aabb()
		var c: Vector3 = a.get_center()
		var fix := Transform3D(Basis.IDENTITY, Vector3(-c.x, -a.position.y, -c.z))
		out.append({"mesh": mi.mesh, "xf": fix * tt, "size": a.size, "mat": _tint(mi.mesh)})
	for ch in n.get_children():
		_collect(ch, tt, out)


## 사진 질감이 땅보다 밝고 따뜻해서 조금 어둡고 차갑게 맞춘다.
static func _tint(mesh: Mesh) -> Material:
	var src := mesh.surface_get_material(0) as StandardMaterial3D
	if src == null:
		return null
	var m := src.duplicate() as StandardMaterial3D
	m.albedo_color = Color(0.62, 0.62, 0.62)
	return m


## 같은 메시를 여러 곳에 놓는다(MultiMesh 하나).
static func _multi(parent: Node3D, mesh: Mesh, xforms: Array[Transform3D], shadows: bool = true, mat: Material = null) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if mat:
		mmi.material_override = mat
	parent.add_child(mmi)
	return mmi


## 메시 하나를 한 자리에 놓는다. 하나씩 두어야 거리에 따라 단순한 모양(LOD)으로 바뀌고 화면 밖은 그리지 않는다.
## far: 이 거리(m)보다 멀면 그리지 않는다(0이면 늘 그린다).
static func _put(parent: Node3D, mesh: Mesh, xf: Transform3D, far: float = 0.0, shadows: bool = true, mat: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = xf
	if far > 0.0:
		mi.visibility_range_end = far
		mi.visibility_range_end_margin = far * 0.1
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if mat:
		mi.material_override = mat
	parent.add_child(mi)
	return mi


## 땅 위의 한 자리에 놓는 변환. sink: 크기에 대해 땅에 묻히는 비율.
static func _on_ground(x: float, z: float, yaw: float, s: float, tilt: float = 0.0, sink: float = 0.0, size_y: float = 1.0) -> Transform3D:
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt)
	b = b.scaled(Vector3.ONE * s)
	return Transform3D(b, Vector3(x, height(x, z) - sink * size_y * s, z))


## 싸움터 밖의 아무 자리. 거리(밖으로 몇 m)를 lo~hi에서 고른다.
static func _ring_point(rng: RandomNumberGenerator, lo: float, hi: float) -> Vector2:
	var per: float = 2.0 * (_w + _d)
	var t: float = rng.randf() * per
	var p := Vector2.ZERO
	var nrm := Vector2.ZERO
	if t < _w:
		p = Vector2(t, 0.0)
		nrm = Vector2(0, -1)
	elif t < _w + _d:
		p = Vector2(_w, t - _w)
		nrm = Vector2(1, 0)
	elif t < 2.0 * _w + _d:
		p = Vector2(t - _w - _d, _d)
		nrm = Vector2(0, 1)
	else:
		p = Vector2(0.0, t - 2.0 * _w - _d)
		nrm = Vector2(-1, 0)
	var d: float = rng.randf_range(lo, hi)
	# 모서리에서는 둥글게 돌아가게 옆으로도 조금 흩는다
	return p + nrm * d + nrm.orthogonal() * rng.randf_range(-1.5, 1.5)


# ---------------------------------------------------------------- 바위

static func _rocks(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var holder := _holder(parent, "Rocks")
	var small: Array[Dictionary] = _parts("rock_moss_set_01") + _parts("rock_moss_set_02")
	if small.is_empty():
		return
	# 꼭대기 둘레: 무너진 돌담처럼 무리를 지어(사이사이는 비운다)
	for c in 24:
		var center: Vector2 = _ring_point(rng, 3.5, FLAT + 1.0)
		for k in rng.randi_range(2, 4):
			var p: Vector2 = center + Vector2(rng.randf_range(-2.5, 2.5), rng.randf_range(-2.5, 2.5))
			if outside(p.x, p.y) < 3.0:
				continue
			var part: Dictionary = small[rng.randi() % small.size()]
			var s: float = rng.randf_range(0.5, 1.2)
			_put(holder, part.mesh, _on_ground(p.x, p.y, rng.randf() * TAU, s, rng.randf_range(-0.15, 0.15), 0.3, part.size.y) * part.xf, 140.0, true, part.mat)
	# 비탈과 골짜기: 크고 드문드문
	for i in 110:
		var p: Vector2 = _ring_point(rng, FLAT + 6.0, 120.0)
		var part: Dictionary = small[rng.randi() % small.size()]
		var s: float = rng.randf_range(0.9, 3.0)
		_put(holder, part.mesh, _on_ground(p.x, p.y, rng.randf() * TAU, s, rng.randf_range(-0.3, 0.3), 0.35, part.size.y) * part.xf, 220.0, true, part.mat)
	# 벼랑 바위: 비탈에 반쯤 묻어 크게
	var faces: Array[Dictionary] = _parts("rock_face_01") + _parts("rock_face_02")
	for f in faces:
		for i in 14:
			var p: Vector2 = _ring_point(rng, FLAT + 7.0, 80.0)
			var s: float = rng.randf_range(1.6, 4.0)
			_put(holder, f.mesh, _on_ground(p.x, p.y, rng.randf() * TAU, s, rng.randf_range(-0.2, 0.2), 0.4, f.size.y) * f.xf, 300.0, true, f.mat)
	for f in _parts("boulder_01"):
		for i in 6:
			var p: Vector2 = _ring_point(rng, FLAT + 10.0, 70.0)
			_put(holder, f.mesh, _on_ground(p.x, p.y, rng.randf() * TAU, rng.randf_range(2.5, 4.5), 0.0, 0.3, f.size.y) * f.xf, 300.0, true, f.mat)


static func _holder(parent: Node3D, name: String) -> Node3D:
	var n := Node3D.new()
	n.name = name
	parent.add_child(n)
	return n


# ---------------------------------------------------------------- 쓰러진 나무, 그루터기, 가지

static func _logs(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var holder := _holder(parent, "Logs")
	for spec in [["dead_tree_trunk_02", 8, FLAT + 4.0, 60.0, 0.9, 1.4, 180.0], ["tree_stump_01", 12, FLAT + 3.0, 70.0, 0.8, 1.5, 150.0], ["dry_branches_medium_01", 60, 2.5, 25.0, 0.9, 1.6, 60.0]]:
		var parts: Array[Dictionary] = _parts(spec[0])
		if parts.is_empty():
			continue
		for i in int(spec[1]):
			var part: Dictionary = parts[i % parts.size()]
			var p: Vector2 = _ring_point(rng, spec[2], spec[3])
			var s: float = rng.randf_range(spec[4], spec[5])
			_put(holder, part.mesh, _on_ground(p.x, p.y, rng.randf() * TAU, s, rng.randf_range(-0.1, 0.1), 0.15, part.size.y) * part.xf, spec[6], spec[6] > 100.0, part.mat)


# ---------------------------------------------------------------- 죽은 나무

static func _dead_trees(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var mat := _bark_mat()
	var variants: Array[Mesh] = []
	for v in 4:
		variants.append(_bare_tree_mesh(rng))
	var holder := _holder(parent, "DeadTrees")
	for i in 40:
		var p: Vector2 = _ring_point(rng, FLAT + 7.0, 110.0)
		var s: float = rng.randf_range(0.8, 1.5)
		_put(holder, variants[i % 4], _on_ground(p.x, p.y, rng.randf() * TAU, s, rng.randf_range(-0.12, 0.12), 0.05), 260.0, true, mat)


static func _bark_mat() -> Material:
	var m := StandardMaterial3D.new()
	var base: String = HILL_DIR + "bark_brown_02/bark_brown_02"
	if ResourceLoader.exists(base + "_diff.jpg"):
		m.albedo_texture = load(base + "_diff.jpg")
		m.albedo_color = Color(0.55, 0.52, 0.5)
		m.normal_enabled = true
		m.normal_texture = load(base + "_nor_gl.jpg")
		m.roughness_texture = load(base + "_rough.jpg")
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	else:
		m.albedo_color = Color(0.16, 0.13, 0.1)
		m.roughness = 0.95
	return m


## 잎 없는 나무 한 그루를 메시 하나로. 줄기가 갈라지며 가늘어진다.
static func _bare_tree_mesh(rng: RandomNumberGenerator) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h: float = rng.randf_range(4.5, 7.5)
	_branch(st, Vector3(0, -0.3, 0), Vector3(rng.randf_range(-0.1, 0.1), 1.0, rng.randf_range(-0.1, 0.1)).normalized(), h, 0.26, 0, rng)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func _branch(st: SurfaceTool, from: Vector3, dir: Vector3, length: float, r: float, depth: int, rng: RandomNumberGenerator) -> void:
	var segs: int = 4
	var p: Vector3 = from
	var d: Vector3 = dir
	var rr: float = r
	for s in segs:
		var seg_len: float = length / segs
		var nd: Vector3 = (d + Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.05, 0.1), rng.randf_range(-0.25, 0.25))).normalized()
		var q: Vector3 = p + nd * seg_len
		var r2: float = rr * 0.8
		_tube(st, p, q, rr, r2, 6 if depth < 2 else 4, float(s) * seg_len, seg_len)
		# 갈라지기
		if depth < 3 and s >= 1 and rng.randf() < 0.75:
			var side: Vector3 = nd.cross(Vector3(rng.randf_range(-1, 1), 0.0, rng.randf_range(-1, 1))).normalized()
			var bd: Vector3 = (nd * 0.6 + side * rng.randf_range(0.6, 1.0) + Vector3.UP * 0.2).normalized()
			_branch(st, q, bd, length * rng.randf_range(0.35, 0.55), r2 * 0.6, depth + 1, rng)
		p = q
		d = nd
		rr = r2
	# 끝은 가늘게 닫는다
	_tube(st, p, p + d * length * 0.12, rr, 0.005, 4, length, length * 0.12)


static func _tube(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, sides: int, v0: float, len: float) -> void:
	var ax: Vector3 = (b - a).normalized()
	var u: Vector3 = ax.cross(Vector3.FORWARD if absf(ax.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var w: Vector3 = ax.cross(u)
	for i in sides:
		var t0: float = TAU * i / sides
		var t1: float = TAU * (i + 1) / sides
		var n0: Vector3 = u * cos(t0) + w * sin(t0)
		var n1: Vector3 = u * cos(t1) + w * sin(t1)
		var p00: Vector3 = a + n0 * ra
		var p01: Vector3 = a + n1 * ra
		var p10: Vector3 = b + n0 * rb
		var p11: Vector3 = b + n1 * rb
		var uv00 := Vector2(float(i) / sides, v0 / 2.0)
		var uv01 := Vector2(float(i + 1) / sides, v0 / 2.0)
		var uv10 := Vector2(float(i) / sides, (v0 + len) / 2.0)
		var uv11 := Vector2(float(i + 1) / sides, (v0 + len) / 2.0)
		st.set_uv(uv00)
		st.add_vertex(p00)
		st.set_uv(uv10)
		st.add_vertex(p10)
		st.set_uv(uv01)
		st.add_vertex(p01)
		st.set_uv(uv01)
		st.add_vertex(p01)
		st.set_uv(uv10)
		st.add_vertex(p10)
		st.set_uv(uv11)
		st.add_vertex(p11)


# ---------------------------------------------------------------- 꽂힌 검들

## 언덕 둘레에 먼저 온 이들이 남긴 검. 녹슬고 기울고, 반쯤 묻혔다.
## 뽑을 수 있는 검(HiltView)은 싸움터 안에만 있고, 이것들은 싸움터 밖에만 둔다.
static func _swords(parent: Node3D, rng: RandomNumberGenerator, forms: Array[FormData]) -> void:
	var variants: Array[SwordModel] = []
	for v in 10:
		var f: FormData = forms[v % forms.size()] if not forms.is_empty() else null
		variants.append(SwordModel.make(f, 0, 900 + v * 17, Color.WHITE))
	var holder := Node3D.new()
	holder.name = "Swords"
	parent.add_child(holder)
	for i in 190:
		# 가까울수록 많이(꼭대기 둘레에 몰리게)
		var lo: float = 2.8
		var p: Vector2 = _ring_point(rng, lo, lo + 3.0 + pow(rng.randf(), 2.0) * 45.0)
		var src: SwordModel = variants[rng.randi() % variants.size()]
		var sw: Node3D = src.duplicate() as Node3D
		var lean := Vector3(rng.randf_range(-0.45, 0.45), 0.0, rng.randf_range(-0.45, 0.45))
		sw.basis = Basis.from_euler(Vector3(PI + lean.x, rng.randf() * TAU, lean.z))
		# 칼날이 땅에 박혀 코등이가 무릎에서 허리 높이
		var stick: float = rng.randf_range(0.25, 0.85)
		sw.position = Vector3(p.x, height(p.x, p.y) + stick, p.y)
		holder.add_child(sw)
	for v in variants:
		v.free()


# ---------------------------------------------------------------- 싸움터 바닥

## 싸움터 안의 작은 것들(돌멩이, 마른 가지, 쓰러진 녹슨 칼). 발목 아래 높이라 싸움을 가리지 않는다.
static func _floor(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var holder := _holder(parent, "Floor")
	var pebbles: Array[Dictionary] = _parts("rock_moss_set_02")
	for i in (70 if not pebbles.is_empty() else 0):
		var part: Dictionary = pebbles[rng.randi() % pebbles.size()]
		var x: float = rng.randf_range(1.0, _w - 1.0)
		var z: float = rng.randf_range(1.0, _d - 1.0)
		_put(holder, part.mesh, _on_ground(x, z, rng.randf() * TAU, rng.randf_range(0.08, 0.22), rng.randf_range(-0.3, 0.3), 0.3, part.size.y) * part.xf, 60.0, false, part.mat)
	var twigs: Array[Dictionary] = _parts("dry_branches_medium_01")
	for i in (24 if not twigs.is_empty() else 0):
		var part: Dictionary = twigs[rng.randi() % twigs.size()]
		var x: float = rng.randf_range(1.0, _w - 1.0)
		var z: float = rng.randf_range(1.0, _d - 1.0)
		_put(holder, part.mesh, _on_ground(x, z, rng.randf() * TAU, rng.randf_range(0.6, 1.0), 0.0, 0.1, part.size.y) * part.xf, 50.0, false, part.mat)


# ---------------------------------------------------------------- 먼 숲

static func _pines(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var mesh := _pine_mesh(rng)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	var xs: Array[Transform3D] = []
	var tries: int = 0
	while xs.size() < 700 and tries < 8000:
		tries += 1
		var p: Vector2 = _ring_point(rng, 85.0, 380.0)
		var h: float = height(p.x, p.y)
		# 높은 산등성이에는 드물게
		if h > 30.0 and rng.randf() < 0.85:
			continue
		var s: float = rng.randf_range(0.8, 1.6)
		xs.append(_on_ground(p.x, p.y, rng.randf() * TAU, s, rng.randf_range(-0.05, 0.05), 0.0))
	_multi(parent, mesh, xs, true, mat)


## 원뿔 몇 겹의 어두운 전나무. 멀리 안개 속에서 실루엣으로 보인다.
static func _pine_mesh(rng: RandomNumberGenerator) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := Color(0.1, 0.08, 0.06)
	st.set_color(trunk)
	_tube_c(st, Vector3(0, -0.5, 0), Vector3(0, 5.0, 0), 0.32, 0.1, 6)
	var layers: int = 6
	for i in layers:
		var k: float = float(i) / layers
		var y0: float = 2.2 + k * 9.5
		var r: float = lerpf(3.2, 0.7, k)
		var hh: float = lerpf(3.4, 2.4, k)
		_cone(st, y0, r, hh, 11, rng, Color(0.05, 0.075, 0.05).lerp(Color(0.08, 0.11, 0.07), k))
	st.generate_normals()
	return st.commit()


static func _cone(st: SurfaceTool, y0: float, r: float, h: float, sides: int, rng: RandomNumberGenerator, c: Color) -> void:
	var rim: Array[Vector3] = []
	for i in sides:
		var t: float = TAU * i / sides + rng.randf_range(-0.1, 0.1)
		var rr: float = r * rng.randf_range(0.8, 1.1)
		rim.append(Vector3(cos(t) * rr, y0 - rng.randf_range(0.0, 0.5), sin(t) * rr))
	var top := Vector3(rng.randf_range(-0.1, 0.1), y0 + h, rng.randf_range(-0.1, 0.1))
	var under := Vector3(0, y0 + h * 0.15, 0)
	for i in sides:
		var a: Vector3 = rim[i]
		var b: Vector3 = rim[(i + 1) % sides]
		st.set_color(c)
		st.add_vertex(top)
		st.set_color(c)
		st.add_vertex(b)
		st.set_color(c * 0.7)
		st.add_vertex(a)
		st.set_color(c * 0.5)
		st.add_vertex(under)
		st.set_color(c * 0.7)
		st.add_vertex(a)
		st.set_color(c * 0.7)
		st.add_vertex(b)


static func _tube_c(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, sides: int) -> void:
	for i in sides:
		var t0: float = TAU * i / sides
		var t1: float = TAU * (i + 1) / sides
		var n0 := Vector3(cos(t0), 0, sin(t0))
		var n1 := Vector3(cos(t1), 0, sin(t1))
		st.add_vertex(a + n0 * ra)
		st.add_vertex(b + n0 * rb)
		st.add_vertex(a + n1 * ra)
		st.add_vertex(a + n1 * ra)
		st.add_vertex(b + n0 * rb)
		st.add_vertex(b + n1 * rb)


# ---------------------------------------------------------------- 풀

static func _grass(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var mesh := _tuft_mesh(rng)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	var xs: Array[Transform3D] = []
	var cs: Array[Color] = []
	var tries: int = 0
	while xs.size() < 18000 and tries < 80000:
		tries += 1
		var x: float = rng.randf_range(-35.0, _w + 35.0)
		var z: float = rng.randf_range(-35.0, _d + 35.0)
		var o: float = outside(x, z)
		var inner: float = minf(minf(x, _w - x), minf(z, _d - z))
		# 싸움터 안은 짓밟혀 풀이 없다(가장자리에만 조금)
		if o <= 0.0 and (inner > 1.5 or rng.randf() > 0.3):
			continue
		var h: float = height(x, z)
		var slope: float = absf(height(x + 1.0, z) - h) + absf(height(x, z + 1.0) - h)
		if slope > 0.9:
			continue
		var s: float = rng.randf_range(0.6, 1.25) * (0.7 if o <= 0.0 else 1.0)
		xs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s)), Vector3(x, h - 0.03, z)))
		cs.append(Color(rng.randf(), rng.randf() * rng.randf(), rng.randf(), 1.0))
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
		mm.set_instance_custom_data(i, cs[i])
	var mat := ShaderMaterial.new()
	mat.shader = GRASS_SHADER
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Grass"
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 80.0
	parent.add_child(mmi)


## 가는 잎 여러 장이 모인 풀 한 포기(높이 약 0.45m). UV.y는 잎의 높이(0 뿌리 ~ 1 끝).
static func _tuft_mesh(rng: RandomNumberGenerator) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in 7:
		var a: float = rng.randf() * TAU
		var lean: float = rng.randf_range(0.15, 0.6)
		var hh: float = rng.randf_range(0.25, 0.55)
		var wd: float = rng.randf_range(0.012, 0.022)
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x)
		var off := dir * rng.randf_range(0.0, 0.08)
		var pts: Array[Vector3] = []
		var segs: int = 2
		for s in segs + 1:
			var t: float = float(s) / segs
			pts.append(off + dir * lean * hh * t * t + Vector3(0, hh * t, 0))
		for s in segs:
			var t0: float = float(s) / segs
			var t1: float = float(s + 1) / segs
			var w0: float = wd * (1.0 - t0)
			var w1: float = wd * (1.0 - t1)
			var p0: Vector3 = pts[s]
			var p1: Vector3 = pts[s + 1]
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(0, t0))
			st.add_vertex(p0 - side * w0)
			st.set_uv(Vector2(0, t1))
			st.add_vertex(p1 - side * w1)
			st.set_uv(Vector2(1, t0))
			st.add_vertex(p0 + side * w0)
			st.set_uv(Vector2(1, t0))
			st.add_vertex(p0 + side * w0)
			st.set_uv(Vector2(0, t1))
			st.add_vertex(p1 - side * w1)
			st.set_uv(Vector2(1, t1))
			st.add_vertex(p1 + side * w1)
	return st.commit()
