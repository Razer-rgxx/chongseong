class_name PastBuilder
extends RefCounted
## 과거 신화 구역의 모양(docs/stranger.md 5단계). 기본 도형만. 가볍게: 재질은 나눠 쓰고, 먼 숲은 MultiMesh, 작은 소품은 보이는 거리를 건다.
## 따뜻한 금빛 늦은 오후, 어두운 사실풍. 세계에 글자 없음. 자리는 모두 PastLayout에서 읽는다. 꾸밈 난수는 지역 RandomNumberGenerator다.

static var _mats: Dictionary = {}


static func environment(env: Environment) -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = PastLayout.BG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = PastLayout.AMBIENT
	env.ambient_light_energy = 1.0
	env.fog_enabled = true
	env.fog_light_color = PastLayout.FOG
	env.fog_density = 0.008
	env.fog_sky_affect = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.04
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.95


static func _plain(key: String, c: Color, rough: float = 0.95, emit: float = 0.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m


static func _put(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3, rot: Vector3 = Vector3.ZERO, far: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.rotation_degrees = rot
	if far > 0.0:
		mi.visibility_range_end = far
	parent.add_child(mi)
	return mi


static func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _put(parent, bm, mat, at, rot)


static func _m(p: Vector2) -> Vector3:
	return Vector3(p.x * Grid.CELL, 0.0, p.y * Grid.CELL)


## 구역 전체를 parent 아래에 짓는다. 돌려주는 것: {sun, fires: [{light, phase}], motes}.
static func build(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "PastHill"
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3000
	var W: float = PastLayout.SIZE.x * Grid.CELL
	var D: float = PastLayout.SIZE.y * Grid.CELL
	_box(root, Vector3(W + 200.0, 0.4, D + 200.0), Vector3(W / 2.0, -0.2, D / 2.0), _plain("ground", PastLayout.GROUND, 0.98))
	_floor_patches(root, rng)
	for t in PastLayout.TREES:
		_big_tree(root, Vector2(t.x, t.y), t.z, rng, false)
	_grove(root, rng)
	_far_forest(root, rng, W, D)
	_stones(root, rng)
	var fires: Array = _forge(root)
	_gate(root, fires)
	_cache(root)
	var sun := DirectionalLight3D.new()
	sun.light_color = PastLayout.SUN
	sun.light_energy = 1.5
	sun.rotation_degrees = Vector3(-17, -62, 0)   # 낮게 깔린 늦은 빛
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	root.add_child(sun)
	var motes := _motes(root)
	return {"sun": sun, "fires": fires, "motes": motes}


## 땅의 어두운 흙과 금빛 낙엽 자국(납작한 원판 몇 장).
static func _floor_patches(root: Node3D, rng: RandomNumberGenerator) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 10
	var leaf := _plain("leaf_gold", Color(0.34, 0.24, 0.09), 1.0)
	var dirt := _plain("dirt", Color(0.11, 0.09, 0.06), 1.0)
	for i in 26:
		var p := Vector3(rng.randf_range(4.0, PastLayout.SIZE.x - 4.0) * Grid.CELL, 0.012 + 0.002 * (i % 3), rng.randf_range(4.0, PastLayout.SIZE.y - 4.0) * Grid.CELL)
		var mi := _put(root, disc, leaf if i % 2 == 0 else dirt, p, Vector3.ZERO, 90.0)
		mi.scale = Vector3(rng.randf_range(3.0, 7.0), 1.0, rng.randf_range(3.0, 6.0))


## 큰 나무: 뿌리 부푼 굵은 줄기와 겹친 잎덩이. white면 성스러운 숲의 흰 나무(잎이 금빛으로 은은히 빛난다).
static func _big_tree(root: Node3D, at: Vector2, r_cells: float, rng: RandomNumberGenerator, white: bool) -> void:
	var r: float = r_cells * Grid.CELL * 0.6
	var h: float = rng.randf_range(16.0, 24.0) if not white else rng.randf_range(12.0, 15.0)
	var bark: StandardMaterial3D = _plain("bark_w", Color(0.62, 0.58, 0.5), 0.9) if white else _plain("bark", PastLayout.BARK, 1.0)
	var leaf: StandardMaterial3D = _plain("leaf_w", Color(0.5, 0.4, 0.14), 0.9, 0.35) if white else _plain("leaf", PastLayout.LEAF, 1.0)
	var o := _m(at)
	var trunk := CylinderMesh.new()
	trunk.top_radius = r * 0.55
	trunk.bottom_radius = r
	trunk.height = h
	trunk.radial_segments = 8
	_put(root, trunk, bark, o + Vector3(0, h / 2.0, 0))
	var flare := CylinderMesh.new()
	flare.top_radius = r * 0.95
	flare.bottom_radius = r * 1.5
	flare.height = 1.6
	flare.radial_segments = 8
	_put(root, flare, bark, o + Vector3(0, 0.8, 0))
	var ball := SphereMesh.new()
	ball.radial_segments = 8
	ball.rings = 4
	for k in 3:
		var s: float = rng.randf_range(4.5, 7.0)
		ball.radius = 1.0
		ball.height = 1.4
		var mi := _put(root, ball, leaf, o + Vector3(rng.randf_range(-2.5, 2.5), h + rng.randf_range(-2.0, 1.5), rng.randf_range(-2.5, 2.5)))
		mi.scale = Vector3(s, s * 0.7, s)


## 성스러운 숲: 흰 나무 고리, 한가운데 이끼 낀 둥근 돌 단과 금빛 작은 빛.
static func _grove(root: Node3D, rng: RandomNumberGenerator) -> void:
	for i in PastLayout.GROVE_COUNT:
		_big_tree(root, PastLayout.grove_at(i), PastLayout.GROVE_TREE_R * 1.3, rng, true)
	var o := _m(PastLayout.GROVE_AT)
	var base := CylinderMesh.new()
	base.top_radius = 2.4
	base.bottom_radius = 2.8
	base.height = 0.3
	base.radial_segments = 12
	_put(root, base, _plain("moss_stone", Color(0.22, 0.26, 0.14), 1.0), o + Vector3(0, 0.15, 0))
	var l := OmniLight3D.new()
	l.light_color = PastLayout.GOLD
	l.light_energy = 0.9
	l.omni_range = 9.0
	l.position = o + Vector3(0, 3.0, 0)
	root.add_child(l)


## 구역 밖의 먼 숲: 줄기와 잎덩이를 MultiMesh 둘로.
static func _far_forest(root: Node3D, rng: RandomNumberGenerator, w: float, d: float) -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.7
	trunk.bottom_radius = 1.3
	trunk.height = 20.0
	trunk.radial_segments = 6
	var ball := SphereMesh.new()
	ball.radius = 5.0
	ball.height = 7.0
	ball.radial_segments = 6
	ball.rings = 3
	var xs: Array[Transform3D] = []
	var ys: Array[Transform3D] = []
	var tries: int = 0
	while xs.size() < 90 and tries < 2000:
		tries += 1
		var p := Vector2(rng.randf_range(-70.0, w + 70.0), rng.randf_range(-70.0, d + 70.0))
		if p.x > -4.0 and p.x < w + 4.0 and p.y > -4.0 and p.y < d + 4.0:
			continue
		var s: float = rng.randf_range(0.9, 1.5)
		xs.append(Transform3D(Basis.from_scale(Vector3(s, s, s)), Vector3(p.x, 10.0 * s, p.y)))
		ys.append(Transform3D(Basis.from_scale(Vector3(s * 1.4, s * 1.1, s * 1.4)), Vector3(p.x, 21.0 * s, p.y)))
	_multi(root, trunk, xs, _plain("bark", PastLayout.BARK, 1.0))
	_multi(root, ball, ys, _plain("leaf", PastLayout.LEAF, 1.0))


static func _multi(root: Node3D, mesh: Mesh, xs: Array[Transform3D], mat: Material) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)


## 선돌 고리: 기울고 이끼 낀 높은 돌 여덟(윗면이 깨진 모양을 위해 작은 조각을 하나 얹는다).
static func _stones(root: Node3D, rng: RandomNumberGenerator) -> void:
	var rock: StandardMaterial3D = _plain("menhir", PastLayout.STONE, 0.95)
	var moss: StandardMaterial3D = _plain("moss_stone", Color(0.22, 0.26, 0.14), 1.0)
	for i in PastLayout.STONE_COUNT:
		var o := _m(PastLayout.stone_at(i))
		var h: float = rng.randf_range(4.0, 6.5)
		var tilt := Vector3(rng.randf_range(-5.0, 5.0), rng.randf() * 360.0, rng.randf_range(-5.0, 5.0))
		_box(root, Vector3(1.5, h, 1.1), o + Vector3(0, h / 2.0 - 0.2, 0), rock, tilt)
		_box(root, Vector3(1.6, 0.4, 1.2), o + Vector3(0, 0.1, 0), moss, tilt)


## 첫 대장간 제단: 넓은 돌판, 모루 돌, 화로(금빛 불과 작은 빛), 물통, 돌판 둘레에 꽂힌 첫 칼들. 화로 불빛 목록을 돌려준다.
static func _forge(root: Node3D) -> Array:
	var o := _m(PastLayout.ALTAR_AT)
	var altar := Node3D.new()
	altar.name = "Altar"
	altar.position = o
	root.add_child(altar)
	var slab := _plain("slab", Color(0.26, 0.24, 0.21), 0.9)
	var dark := _plain("anvil", Color(0.09, 0.08, 0.08), 0.5)
	_box(altar, Vector3(11.0, 0.5, 9.0), Vector3(0, 0.25, 0), slab)
	_box(altar, Vector3(9.0, 0.2, 7.0), Vector3(0, 0.6, 0), slab)
	_box(altar, Vector3(2.0, 0.9, 1.0), Vector3(0, 1.05, 0), dark)
	_box(altar, Vector3(2.6, 0.35, 1.3), Vector3(0, 1.65, 0), dark)
	_box(altar, Vector3(0.7, 0.5, 0.5), Vector3(1.6, 1.45, 0), dark)   # 모루 뿔
	var fires: Array = []
	var fire_m: StandardMaterial3D = _plain("fire", Color(1.0, 0.55, 0.15), 0.5, 2.2)
	fire_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for sx in [-1.0, 1.0]:
		var bowl := CylinderMesh.new()
		bowl.top_radius = 0.9
		bowl.bottom_radius = 0.5
		bowl.height = 0.8
		bowl.radial_segments = 10
		_put(altar, bowl, slab, Vector3(3.6 * sx, 1.1, -2.2))
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.6
		cone.height = 1.3
		cone.radial_segments = 8
		_put(altar, cone, fire_m, Vector3(3.6 * sx, 2.0, -2.2))
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.6, 0.25)
		l.light_energy = 1.6
		l.omni_range = 11.0
		l.position = Vector3(3.6 * sx, 2.8, -2.2)
		altar.add_child(l)
		fires.append({"light": l, "phase": 1.7 * sx})
	var trough := _plain("trough", Color(0.1, 0.12, 0.13), 0.3)
	_box(altar, Vector3(2.4, 0.6, 0.9), Vector3(-3.0, 0.8, 2.4), slab)
	_box(altar, Vector3(2.0, 0.1, 0.6), Vector3(-3.0, 1.12, 2.4), trough)
	var blade := _plain("firstblade", Color(0.55, 0.5, 0.42), 0.4)
	for i in 7:
		var a: float = TAU * i / 7.0 + 0.2
		var p := Vector3(cos(a) * 4.6, 0.0, sin(a) * 3.6)
		_box(altar, Vector3(0.12, 2.0, 0.04), p + Vector3(0, 1.4, 0), blade, Vector3(0, rad_to_deg(-a), 7.0))
	return fires


## 돌아가는 문: 낮은 돌 두 기둥과 상인방, 그 사이로 어른거리는 금빛.
static func _gate(root: Node3D, fires: Array) -> void:
	var o := _m(PastLayout.EXIT_AT)
	var g := Node3D.new()
	g.name = "Gate"
	g.position = o
	root.add_child(g)
	var rock := _plain("menhir", PastLayout.STONE, 0.95)
	_box(g, Vector3(0.7, 3.0, 0.7), Vector3(-1.4, 1.5, 0), rock)
	_box(g, Vector3(0.7, 3.0, 0.7), Vector3(1.4, 1.5, 0), rock)
	_box(g, Vector3(3.8, 0.6, 0.8), Vector3(0, 3.2, 0), rock)
	var shim := _plain("shimmer", Color(1.0, 0.8, 0.45, 0.35), 0.5, 1.4)
	shim.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shim.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_box(g, Vector3(2.1, 2.9, 0.05), Vector3(0, 1.5, 0), shim)
	var l := OmniLight3D.new()
	l.light_color = PastLayout.GOLD
	l.light_energy = 0.8
	l.omni_range = 7.0
	l.position = Vector3(0, 1.6, -1.0)
	g.add_child(l)
	fires.append({"light": l, "phase": 0.4})


## 성스러운 숲의 함(오래된 나무 함).
static func _cache(root: Node3D) -> void:
	var chest := Node3D.new()
	chest.name = "Cache"
	chest.position = _m(PastLayout.CACHE_AT)
	root.add_child(chest)
	var wood := _plain("chest_wood", Color(0.22, 0.14, 0.08), 0.9)
	_box(chest, Vector3(1.4, 0.7, 0.9), Vector3(0, 0.65, 0), wood)
	var lid := _box(chest, Vector3(1.46, 0.16, 0.96), Vector3(0, 1.08, 0), _plain("chest_band", Color(0.4, 0.3, 0.12), 0.5))
	lid.name = "Lid"


static func open_cache(chest: Node3D) -> void:
	var lid := chest.get_node_or_null("Lid") as Node3D
	if lid:
		lid.rotation_degrees.x = 55.0
		lid.position += Vector3(0, 0.25, 0.3)


## 떠다니는 먼지 알갱이(영주를 따라다닌다). 웹판에서는 적게.
static func _motes(root: Node3D) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 40 if WebQuality.on() else 110
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(30.0, 6.0, 30.0)
	p.direction = Vector3(0.3, 0.15, 0.1)
	p.spread = 180.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.4
	p.gravity = Vector3(0, -0.02, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.85, 0.5, 0.6)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m
	p.mesh = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(p)
	return p
