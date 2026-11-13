class_name VillageBuilder
extends RefCounted
## 마을의 집, 나무, 울타리, 소품을 기본 도형으로 짓는다. 모델 에셋이 들어오면 함수 하나씩 바꿔 끼운다.
## 질감은 assets/village/의 사진 질감이 있으면 쓰고(VillageMaterials), 없으면 잡음으로 만든 질감을 쓴다.
## 집의 앞은 지역 +Z다. facing(라디안)으로 돌려 세운다. 모든 랜덤은 꾸밈용이라 받은 rng만 쓴다.

static var _cache: Dictionary = {}


# ---------------------------------------------------------------- 재질

## 잡음으로 만든 질감. 색 둘 사이를 잡음으로 섞는다(사진 질감이 없을 때).
static func noise_mat(key: String, a: Color, b: Color, tile: float = 3.0, freq: float = 0.02, rough: float = 0.95) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var n := FastNoiseLite.new()
	n.seed = key.hash()
	n.frequency = freq
	n.fractal_octaves = 5
	var g := Gradient.new()
	g.colors = PackedColorArray([a, b])
	var t := NoiseTexture2D.new()
	t.noise = n
	t.color_ramp = g
	t.seamless = true
	t.width = 512
	t.height = 512
	var nt := NoiseTexture2D.new()
	nt.noise = n
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 4.0
	nt.width = 512
	nt.height = 512
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.normal_enabled = true
	m.normal_texture = nt
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / tile
	_cache[key] = m
	return m


static func plain(c: Color, rough: float = 0.85, metal: float = 0.0) -> StandardMaterial3D:
	var key: String = "plain|%s|%s|%s" % [c, rough, metal]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	_cache[key] = m
	return m


static func glow(c: Color, energy: float = 2.0) -> StandardMaterial3D:
	var key: String = "glow|%s|%s" % [c, energy]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	_cache[key] = m
	return m


static func grass() -> StandardMaterial3D:
	if VillageMaterials.has("grass"):
		return VillageMaterials.get_mat("grass", Color.DARK_OLIVE_GREEN, 3.0)
	return noise_mat("grass", Color(0.13, 0.17, 0.08), Color(0.3, 0.33, 0.17), 6.0, 0.035)


static func dirt() -> StandardMaterial3D:
	if VillageMaterials.has("dirt"):
		return VillageMaterials.get_mat("dirt", Color.SADDLE_BROWN, 3.0)
	return noise_mat("dirt", Color(0.13, 0.11, 0.09), Color(0.3, 0.26, 0.21), 4.0, 0.05)


static func plaster() -> StandardMaterial3D:
	return noise_mat("plaster", Color(0.62, 0.55, 0.44), Color(0.8, 0.74, 0.62), 2.0, 0.08)


static func timber() -> StandardMaterial3D:
	return VillageMaterials.get_mat("raw_plank_wall", Color(0.2, 0.14, 0.09), 1.5, Color(0.42, 0.33, 0.26))


static func planks() -> StandardMaterial3D:
	return VillageMaterials.get_mat("raw_plank_wall", Color(0.35, 0.26, 0.18), 1.5, Color(0.75, 0.66, 0.58))


static func stone() -> StandardMaterial3D:
	return VillageMaterials.get_mat("stone_wall", Color(0.36, 0.35, 0.34), 2.0, Color(0.85, 0.83, 0.8))


static func roof() -> StandardMaterial3D:
	if VillageMaterials.has("roof"):
		return VillageMaterials.get_mat("roof", Color(0.3, 0.2, 0.18), 2.0)
	# 지붕 질감이 오기 전: 판자 질감을 어둡게 해서 나무 너와처럼
	return VillageMaterials.get_mat("raw_plank_wall", Color(0.24, 0.16, 0.13), 1.2, Color(0.42, 0.3, 0.25))


static func bark() -> StandardMaterial3D:
	return noise_mat("bark", Color(0.1, 0.075, 0.055), Color(0.27, 0.21, 0.15), 1.0, 0.12)


static func leaves(dark: bool) -> StandardMaterial3D:
	if dark:
		return noise_mat("pine", Color(0.04, 0.08, 0.05), Color(0.11, 0.18, 0.1), 1.5, 0.15, 1.0)
	return noise_mat("leaves", Color(0.1, 0.15, 0.06), Color(0.27, 0.3, 0.12), 1.5, 0.15, 1.0)


# ---------------------------------------------------------------- 기본 도형

static func box(parent: Node3D, size: Vector3, at: Vector3, m: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = at
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func cyl(parent: Node3D, top: float, bottom: float, h: float, at: Vector3, m: Material, sides: int = 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	mi.mesh = c
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)
	return mi


static func ball(parent: Node3D, r: float, at: Vector3, m: Material, squash: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 10
	s.rings = 6
	mi.mesh = s
	mi.material_override = m
	mi.position = at
	mi.scale = squash
	parent.add_child(mi)
	return mi


static func place(parent: Node3D, at: Vector3, facing: float) -> Node3D:
	var n := Node3D.new()
	n.position = at
	n.rotation.y = facing
	parent.add_child(n)
	return n


## 바라볼 방향(월드 XZ)을 집 앞(+Z)이 그쪽을 보는 회전으로.
static func facing_to(dir: Vector2) -> float:
	return atan2(dir.x, dir.y)


# ---------------------------------------------------------------- 집

## 반목조 집: 1층은 돌, 2층은 회벽에 검은 나무 뼈대, 가파른 박공지붕, 굴뚝, 불 켜진 창.
## size: 너비(x) × 깊이(z) 미터. two_story가 아니면 돌로 된 단층집. 굴뚝 꼭대기(월드)를 돌려준다.
static func house(parent: Node3D, at: Vector3, facing: float, size: Vector2, two_story: bool, rng: RandomNumberGenerator) -> Vector3:
	var h := place(parent, at, facing)
	var w: float = size.x
	var d: float = size.y
	var g_h: float = 2.6
	box(h, Vector3(w, g_h, d), Vector3(0, g_h / 2.0, 0), stone())
	var top_y: float = g_h
	var uw: float = w
	var ud: float = d
	if two_story:
		# 2층은 앞뒤로 조금 내밀어 짓는다(목조 주택의 돌출층)
		var u_h: float = 2.4
		uw = w + 0.3
		ud = d + 0.5
		box(h, Vector3(uw, u_h, ud), Vector3(0, g_h + u_h / 2.0, 0), plaster())
		_frame(h, uw, ud, g_h, u_h)
		top_y = g_h + u_h
		for sx in [-1.0, 1.0]:
			_window(h, Vector3(sx * uw * 0.25, g_h + 1.25, ud / 2.0 + 0.03), rng)
	# 박공지붕: 두 장의 판을 기울여 처마를 내민다
	var pitch: float = deg_to_rad(rng.randf_range(48.0, 56.0))
	var half: float = ud / 2.0 + 0.6
	var slope: float = half / cos(pitch)
	var rise: float = tan(pitch) * (ud / 2.0)
	for side in [-1.0, 1.0]:
		var cy: float = top_y + rise - half * tan(pitch) / 2.0 + 0.1
		var r := box(h, Vector3(uw + 1.0, 0.18, slope), Vector3(0, cy, side * half / 2.0), roof())
		r.rotation.x = side * pitch
	# 박공(지붕 밑 삼각벽)
	var gable := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(ud, rise, uw - 0.05)
	gable.mesh = pm
	gable.material_override = plaster() if two_story else stone()
	gable.position = Vector3(0, top_y + rise / 2.0, 0)
	gable.rotation.y = PI / 2.0
	h.add_child(gable)
	box(h, Vector3(uw + 1.1, 0.2, 0.2), Vector3(0, top_y + rise + 0.12, 0), timber())
	# 문과 1층 창
	box(h, Vector3(1.1, 2.0, 0.12), Vector3(-w * 0.18, 1.0, d / 2.0 + 0.05), plain(Color(0.14, 0.09, 0.06)))
	box(h, Vector3(1.4, 0.16, 0.2), Vector3(-w * 0.18, 2.08, d / 2.0 + 0.08), timber())
	_window(h, Vector3(w * 0.22, 1.4, d / 2.0 + 0.03), rng)
	if rng.randf() < 0.6:
		_window(h, Vector3(w / 2.0 + 0.03, 1.4, 0), rng, PI / 2.0)
	# 굴뚝
	var cx: float = w * rng.randf_range(0.2, 0.35) * (1.0 if rng.randf() < 0.5 else -1.0)
	var ch_h: float = top_y + rise + 1.2
	box(h, Vector3(0.8, ch_h, 0.8), Vector3(cx, ch_h / 2.0, -ud * 0.15), stone())
	return h.to_global(Vector3(cx, ch_h + 0.2, -ud * 0.15))


## 2층 회벽의 나무 뼈대: 모서리 기둥, 위아래 들보, 가운데 기둥, 사선 버팀대. 앞뒤와 옆면.
static func _frame(h: Node3D, w: float, d: float, y0: float, uh: float) -> void:
	var t: float = 0.16
	var tm := timber()
	for face in [[Vector3(0, 0, 1), w], [Vector3(0, 0, -1), w], [Vector3(1, 0, 0), d], [Vector3(-1, 0, 0), d]]:
		var n: Vector3 = face[0]
		var len: float = face[1]
		var depth: float = (d if n.z != 0.0 else w) / 2.0 + 0.02
		var basis := Basis(Vector3.UP, atan2(n.x, n.z))
		var o: Vector3 = n * depth
		for y in [y0 + t / 2.0, y0 + uh - t / 2.0]:
			box(h, Vector3(len, t, t * 0.6), o + Vector3(0, y, 0), tm).basis = basis
		for x in [-len / 2.0 + t / 2.0, 0.0, len / 2.0 - t / 2.0]:
			var post := box(h, Vector3(t, uh, t * 0.6), o + basis * Vector3(x, 0, 0) + Vector3(0, y0 + uh / 2.0, 0), tm)
			post.basis = basis
		for sx in [-1.0, 1.0]:
			var br := box(h, Vector3(t, sqrt(pow(len / 2.0, 2) + uh * uh) * 0.9, t * 0.6), o + basis * Vector3(sx * len / 4.0, 0, 0) + Vector3(0, y0 + uh / 2.0, 0), tm)
			br.basis = basis * Basis(Vector3(0, 0, 1), sx * atan2(len / 2.0, uh))


## 창: 불 켜진 유리, 나무 틀, 십자 창살, 가끔 덧문.
static func _window(h: Node3D, at: Vector3, rng: RandomNumberGenerator, turn: float = 0.0) -> void:
	var w := place(h, at, turn)
	var lit: bool = rng.randf() < 0.75
	box(w, Vector3(0.8, 0.9, 0.05), Vector3.ZERO, glow(Color(1.0, 0.62, 0.3), 2.2) if lit else plain(Color(0.05, 0.05, 0.06), 0.2))
	var tm := timber()
	box(w, Vector3(1.0, 0.1, 0.1), Vector3(0, 0.5, 0.03), tm)
	box(w, Vector3(1.0, 0.1, 0.1), Vector3(0, -0.5, 0.03), tm)
	box(w, Vector3(0.1, 1.0, 0.1), Vector3(-0.45, 0, 0.03), tm)
	box(w, Vector3(0.1, 1.0, 0.1), Vector3(0.45, 0, 0.03), tm)
	box(w, Vector3(0.05, 0.9, 0.06), Vector3(0, 0, 0.04), tm)
	box(w, Vector3(0.8, 0.05, 0.06), Vector3(0, 0, 0.04), tm)
	if rng.randf() < 0.5:
		for sx in [-1.0, 1.0]:
			box(w, Vector3(0.42, 0.95, 0.05), Vector3(sx * 0.75, 0, 0.06), planks(), Vector3(0, sx * 0.4, 0))


# ---------------------------------------------------------------- 나무와 풀

## 침엽수(원뿔을 겹쳐 쌓음) 또는 활엽수(줄기 + 잎 덩어리 여러 개).
static func tree(parent: Node3D, at: Vector3, rng: RandomNumberGenerator, pine: bool) -> void:
	var t := place(parent, at, rng.randf() * TAU)
	var s: float = rng.randf_range(0.8, 1.35)
	if pine:
		var h: float = 7.0 * s
		cyl(t, 0.12 * s, 0.3 * s, h * 0.5, Vector3(0, h * 0.25, 0), bark(), 8)
		var layers: int = 4
		for i in layers:
			var k: float = float(i) / layers
			var r: float = lerpf(2.2, 0.7, k) * s
			var ch: float = lerpf(2.6, 1.8, k) * s
			var c := cyl(t, 0.0, r, ch, Vector3(0, h * (0.28 + k * 0.62), 0), leaves(true), 9)
			c.rotation.y = rng.randf() * TAU
	else:
		var h: float = 4.0 * s
		var trunk := cyl(t, 0.16 * s, 0.32 * s, h, Vector3(0, h / 2.0, 0), bark(), 8)
		trunk.rotation.z = rng.randf_range(-0.08, 0.08)
		for i in rng.randi_range(5, 8):
			var a: float = rng.randf() * TAU
			var r: float = rng.randf_range(0.6, 1.6) * s
			var p := Vector3(cos(a) * r, h + rng.randf_range(-0.4, 1.4) * s, sin(a) * r)
			ball(t, rng.randf_range(1.1, 1.8) * s, p, leaves(false), Vector3(1.0, rng.randf_range(0.7, 0.9), 1.0))


## 잎 없는 죽은 나무(어두운 분위기용).
static func dead_tree(parent: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	var t := place(parent, at, rng.randf() * TAU)
	var h: float = rng.randf_range(3.5, 5.5)
	cyl(t, 0.1, 0.28, h, Vector3(0, h / 2.0, 0), bark(), 7)
	for i in rng.randi_range(3, 5):
		var b := cyl(t, 0.02, 0.09, rng.randf_range(1.2, 2.2), Vector3(0, h * rng.randf_range(0.55, 0.95), 0), bark(), 5)
		b.rotation = Vector3(rng.randf_range(0.5, 1.1), rng.randf() * TAU, 0)
		b.position += b.basis.y * 0.6


static func bush(parent: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	for i in rng.randi_range(2, 4):
		ball(parent, rng.randf_range(0.4, 0.8), at + Vector3(rng.randf_range(-0.6, 0.6), 0.25, rng.randf_range(-0.6, 0.6)), leaves(rng.randf() < 0.5), Vector3(1, 0.7, 1))


static func rock(parent: Node3D, at: Vector3, rng: RandomNumberGenerator, size: float = 1.0) -> void:
	var r := ball(parent, size * rng.randf_range(0.4, 0.8), at, stone(), Vector3(rng.randf_range(0.9, 1.5), rng.randf_range(0.5, 0.8), rng.randf_range(0.8, 1.3)))
	r.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, 0)


# ---------------------------------------------------------------- 소품

static func barrel(parent: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	var b := cyl(parent, 0.38, 0.34, 1.0, at + Vector3(0, 0.5, 0), planks(), 12)
	b.rotation.y = rng.randf() * TAU
	for y in [0.15, 0.85]:
		cyl(parent, 0.39, 0.39, 0.06, at + Vector3(0, y, 0), plain(Color(0.12, 0.12, 0.13), 0.5, 0.6), 12)


static func crate(parent: Node3D, at: Vector3, rng: RandomNumberGenerator, s: float = 0.8) -> void:
	box(parent, Vector3(s, s, s), at + Vector3(0, s / 2.0, 0), planks(), Vector3(0, rng.randf() * TAU, 0))


static func hay(parent: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	var c := cyl(parent, 0.6, 0.6, 1.1, at + Vector3(0, 0.6, 0), noise_mat("hay", Color(0.45, 0.36, 0.17), Color(0.7, 0.6, 0.32), 1.0, 0.2), 14)
	c.rotation = Vector3(PI / 2.0, rng.randf() * TAU, 0)


static func firewood(parent: Node3D, at: Vector3, facing: float) -> void:
	var f := place(parent, at, facing)
	for row in 4:
		for i in 6 - row:
			var l := cyl(f, 0.11, 0.11, 1.0, Vector3((i - (5 - row) / 2.0) * 0.23, 0.11 + row * 0.2, 0), bark(), 7)
			l.rotation.x = PI / 2.0


static func bench(parent: Node3D, at: Vector3, facing: float) -> void:
	var b := place(parent, at, facing)
	box(b, Vector3(1.8, 0.08, 0.4), Vector3(0, 0.45, 0), planks())
	for x in [-0.75, 0.75]:
		box(b, Vector3(0.1, 0.45, 0.35), Vector3(x, 0.22, 0), timber())


## 우물: 돌 둘레, 나무 기둥 둘과 작은 지붕, 도르래.
static func well(parent: Node3D, at: Vector3) -> void:
	var st := stone()
	var ring := cyl(parent, 1.0, 1.05, 0.9, at + Vector3(0, 0.45, 0), st, 16)
	ring.name = "Well"
	cyl(parent, 0.82, 0.82, 0.05, at + Vector3(0, 0.8, 0), plain(Color(0.02, 0.03, 0.04), 0.1), 16)
	for x in [-0.85, 0.85]:
		box(parent, Vector3(0.15, 2.4, 0.15), at + Vector3(x, 1.2, 0), timber())
	box(parent, Vector3(1.9, 0.12, 0.12), at + Vector3(0, 2.1, 0), timber())
	for side in [-1.0, 1.0]:
		box(parent, Vector3(2.3, 0.08, 0.9), at + Vector3(0, 2.6, side * 0.38), roof(), Vector3(side * 0.6, 0, 0))
	cyl(parent, 0.18, 0.18, 0.3, at + Vector3(0, 1.4, 0), planks(), 8)


## 장터 좌판: 나무 탁자, 기둥 넷, 천 차양, 위에 자루와 바구니.
static func stall(parent: Node3D, at: Vector3, facing: float, cloth: Color, rng: RandomNumberGenerator) -> void:
	var s := place(parent, at, facing)
	box(s, Vector3(2.6, 0.1, 1.2), Vector3(0, 0.9, 0), planks())
	box(s, Vector3(2.6, 0.8, 0.08), Vector3(0, 0.45, 0.55), planks())
	for x in [-1.25, 1.25]:
		for z in [-0.55, 0.55]:
			box(s, Vector3(0.1, 2.3 if z < 0.0 else 2.0, 0.1), Vector3(x, 1.15 if z < 0.0 else 1.0, z), timber())
	var c := plain(cloth, 0.95)
	box(s, Vector3(2.9, 0.04, 1.6), Vector3(0, 2.15, 0.1), c, Vector3(-0.25, 0, 0))
	for i in 4:
		ball(s, rng.randf_range(0.15, 0.25), Vector3(-0.9 + i * 0.6, 1.1, rng.randf_range(-0.2, 0.2)), plain(Color(0.5, 0.42, 0.28)), Vector3(1, 0.8, 1))


## 등불 기둥: 기둥, 팔, 빛나는 등, 따뜻한 빛.
static func lantern(parent: Node3D, at: Vector3, facing: float, light: bool) -> void:
	var l := place(parent, at, facing)
	box(l, Vector3(0.14, 2.8, 0.14), Vector3(0, 1.4, 0), timber())
	box(l, Vector3(0.08, 0.08, 0.7), Vector3(0, 2.7, 0.3), timber())
	box(l, Vector3(0.26, 0.36, 0.26), Vector3(0, 2.38, 0.6), glow(Color(1.0, 0.62, 0.3), 1.4))
	box(l, Vector3(0.32, 0.06, 0.32), Vector3(0, 2.58, 0.6), plain(Color(0.08, 0.08, 0.09), 0.5, 0.6))
	if light:
		var o := OmniLight3D.new()
		o.light_color = Color(1.0, 0.7, 0.42)
		o.omni_range = 8.0
		o.light_energy = 1.1
		o.position = Vector3(0, 2.3, 0.6)
		l.add_child(o)


## 횃불(문 기둥에): 막대와 불꽃, 빛.
static func torch(parent: Node3D, at: Vector3) -> void:
	cyl(parent, 0.05, 0.05, 0.7, at, timber(), 6)
	ball(parent, 0.14, at + Vector3(0, 0.45, 0), glow(Color(1.0, 0.5, 0.18), 4.0), Vector3(1, 1.5, 1))
	var o := OmniLight3D.new()
	o.light_color = Color(1.0, 0.58, 0.28)
	o.omni_range = 7.0
	o.light_energy = 1.2
	o.position = at + Vector3(0, 0.6, 0)
	parent.add_child(o)


## 굴뚝 연기: 천천히 오르며 퍼지고 옅어지는 잿빛 점.
static func smoke(parent: Node3D, at: Vector3, strength: float = 1.0) -> void:
	var p := CPUParticles3D.new()
	p.amount = int(14 * strength)
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.local_coords = false
	p.direction = Vector3(0.25, 1, 0)
	p.spread = 12.0
	p.gravity = Vector3(0.15, 0.25, 0)
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 0.9
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 2.4))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.35, 0.33, 0.32, 0.0), Color(0.35, 0.33, 0.32, 0.45), Color(0.3, 0.29, 0.29, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	p.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2(1.2, 1.2)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = HitFx._soft_dot()
	q.material = m
	p.mesh = q
	p.position = at
	parent.add_child(p)


## 뾰족한 통나무 울타리(목책). from에서 to까지 한 줄. 많아서 MultiMesh로 그린다.
static func palisade(parent: Node3D, from: Vector3, to: Vector3, rng: RandomNumberGenerator) -> void:
	var len: float = from.distance_to(to)
	var n: int = maxi(1, int(len / 0.36))
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.17
	shaft.bottom_radius = 0.19
	shaft.height = 1.0
	shaft.radial_segments = 7
	shaft.rings = 1
	shaft.material = bark()
	var tip := CylinderMesh.new()
	tip.top_radius = 0.0
	tip.bottom_radius = 0.17
	tip.height = 0.45
	tip.radial_segments = 7
	tip.rings = 1
	tip.material = bark()
	var ms: Array[MultiMesh] = []
	for mesh in [shaft, tip]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = n
		ms.append(mm)
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		parent.add_child(mi)
	for i in n:
		var p: Vector3 = from.lerp(to, (i + 0.5) / n)
		var h: float = rng.randf_range(2.4, 3.1)
		var tilt := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.05))
		ms[0].set_instance_transform(i, Transform3D(tilt * Basis().scaled(Vector3(1, h, 1)), p + tilt * Vector3(0, h / 2.0, 0)))
		ms[1].set_instance_transform(i, Transform3D(tilt, p + tilt * Vector3(0, h + 0.22, 0)))
	# 가로 띠 둘
	for y in [0.7, 2.0]:
		var b := box(parent, Vector3(0.12, 0.14, len), (from + to) / 2.0 + Vector3(0, y, 0), timber())
		b.look_at_from_position(b.position, to + Vector3(0, y, 0), Vector3.UP)
