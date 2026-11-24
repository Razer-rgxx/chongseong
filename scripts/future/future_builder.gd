class_name FutureBuilder
extends RefCounted
## 녹슨 미래 구역의 모양(docs/stranger.md 3단계). 기본 도형만. 가볍게: 메시와 재질은 나눠 쓰고, 자동차는 MultiMesh, 작은 것은 보이는 거리(visibility range)를 건다.
## 채도 낮은 차가운 파랑에 보라 조금. 세계에 글자 없음. 모든 자리는 FutureLayout에서 읽는다. 꾸밈 난수는 화면 쪽(지역 RandomNumberGenerator)이다.

const SMALL_RANGE: float = 80.0   ## 작은 소품이 보이는 거리(m)
const WIN_W: float = 4.0          ## 창틀 한 칸의 가로·세로(m): 질감 한 장이 덮는 크기

static var _tex: Dictionary = {}


static func environment(env: Environment) -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = FutureLayout.BG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = FutureLayout.AMBIENT
	env.ambient_light_energy = 1.2
	env.fog_enabled = true
	env.fog_light_color = FutureLayout.FOG
	env.fog_density = 0.016
	env.fog_sky_affect = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.05
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.78


## 콘크리트에 창틀 격자를 그린 질감 한 장(알베도와 불 켜진 창의 방출). 코드로 만든 작은 이미지라 파일이 필요 없다.
static func _facade() -> Array:
	if _tex.has("facade"):
		return _tex.facade
	var w: int = 64
	var h: int = 64
	var a := Image.create(w, h, false, Image.FORMAT_RGB8)
	var e := Image.create(w, h, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.09
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for y in h:
		for x in w:
			var n: float = noise.get_noise_2d(x, y) * 0.5 + 0.5
			a.set_pixel(x, y, FutureLayout.CONCRETE.lerp(Color(0.12, 0.14, 0.19), n * 0.7))
			e.set_pixel(x, y, Color.BLACK)
	# 창 두 줄 두 칸(칸 하나는 32 x 32 중 안쪽 18 x 14)
	for cy in 2:
		for cx in 2:
			var lit: bool = rng.randf() < 0.18
			var x0: int = cx * 32 + 7
			var y0: int = cy * 32 + 9
			for y in 14:
				for x in 18:
					var px: int = x0 + x
					var py: int = y0 + y
					a.set_pixel(px, py, Color(0.03, 0.04, 0.07))
					if lit:
						e.set_pixel(px, py, Color(0.18, 0.34, 0.5) if (cx + cy) % 2 == 0 else Color(0.3, 0.2, 0.46))
	var out: Array = [ImageTexture.create_from_image(a), ImageTexture.create_from_image(e)]
	_tex["facade"] = out
	return out


static func _tower_mat() -> StandardMaterial3D:
	if _tex.has("tower"):
		return _tex.tower
	var t: Array = _facade()
	var m := StandardMaterial3D.new()
	m.albedo_texture = t[0]
	m.roughness = 0.95
	m.emission_enabled = true
	m.emission_texture = t[1]
	m.emission_energy_multiplier = 0.9
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(1.0, 1.0, 1.0) / (WIN_W * 2.0)   # 질감 한 장 = 가로 8m, 창 둘
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	_tex["tower"] = m
	return m


static func _plain(key: String, c: Color, rough: float = 0.9, metal: float = 0.0) -> StandardMaterial3D:
	if _tex.has(key):
		return _tex[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	_tex[key] = m
	return m


static func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


## 구역 전체를 parent 아래에 짓는다. 돌려주는 것: {neons: [{mat, rate, phase}], sun}.
static func build(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "FutureCity"
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 311
	var W: float = FutureLayout.SIZE.x * Grid.CELL
	var D: float = FutureLayout.SIZE.y * Grid.CELL
	# 아스팔트 바닥(구역보다 넓게)
	var ground := _plain("ground", FutureLayout.ASPHALT.lightened(0.15), 0.7, 0.0)
	_box(root, Vector3(W + 160.0, 0.4, D + 160.0), Vector3(W / 2.0, -0.2, D / 2.0), ground)
	_roads(root)
	for t in FutureLayout.TOWERS:
		_tower(root, t, rng)
	_skyline(root, rng, W, D)
	_overpass(root)
	_cars(root, rng)
	_puddles(root)
	var neons: Array = _neons(root, rng)
	_extras(root)
	var sun := DirectionalLight3D.new()
	sun.light_color = FutureLayout.MOON
	sun.light_energy = 0.55
	sun.rotation_degrees = Vector3(-52, 28, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	root.add_child(sun)
	return {"neons": neons, "sun": sun}


## 거리 위의 흰 선과 갈라진 틈(어두운 줄). 얇은 판 몇 장.
static func _roads(root: Node3D) -> void:
	var line := _plain("line", Color(0.3, 0.33, 0.4), 0.8)
	var crack := _plain("crack", Color(0.03, 0.035, 0.05), 1.0)
	for i in 8:
		var x: float = (30.0 + i * 3.0) * Grid.CELL
		_box(root, Vector3(1.4, 0.02, 0.2), Vector3(x, 0.01, 27.0 * Grid.CELL), line)
	for i in 6:
		_box(root, Vector3(0.2, 0.02, 1.4), Vector3(40.0 * Grid.CELL, 0.01, (18.0 + i * 3.0) * Grid.CELL), line)
	_box(root, Vector3(0.12, 0.02, 9.0), Vector3(34.0 * Grid.CELL, 0.012, 42.0 * Grid.CELL), crack, Vector3(0, 25, 0))
	_box(root, Vector3(0.12, 0.02, 6.0), Vector3(58.0 * Grid.CELL, 0.012, 30.0 * Grid.CELL), crack, Vector3(0, -40, 0))


## 탑 하나: 창틀 격자 질감의 몸통, 지붕판, 무너진 탑은 윗부분이 비스듬히 잘려 철근 막대와 잔해가 나온다.
static func _tower(root: Node3D, t: Dictionary, rng: RandomNumberGenerator) -> void:
	var r: Rect2 = t.rect
	var h: float = float(t.h)
	var c: Vector3 = Vector3((r.position.x + r.size.x / 2.0) * Grid.CELL, h / 2.0, (r.position.y + r.size.y / 2.0) * Grid.CELL)
	var sz := Vector3(r.size.x * Grid.CELL, h, r.size.y * Grid.CELL)
	_box(root, sz, c, _tower_mat())
	var concrete := _plain("concrete", FutureLayout.CONCRETE.darkened(0.2), 1.0)
	var top: float = h
	if t.get("ruin", false):
		# 윗부분이 무너졌다: 한쪽이 낮은 비스듬한 덮개, 삐져나온 철근, 흩어진 덩어리
		_box(root, Vector3(sz.x * 0.55, 1.2, sz.z), Vector3(c.x - sz.x * 0.22, top + 0.4, c.z), concrete, Vector3(0, 0, 10))
		var rebar := _plain("rebar", FutureLayout.RUST.darkened(0.2), 0.8, 0.5)
		for i in 5:
			_box(root, Vector3(0.1, rng.randf_range(2.0, 4.0), 0.1), Vector3(c.x + rng.randf_range(0.0, sz.x * 0.4), top + 1.0, c.z + rng.randf_range(-sz.z * 0.4, sz.z * 0.4)), rebar, Vector3(rng.randf_range(-25, 25), 0, rng.randf_range(-25, 25)))
		for i in 4:
			var s: float = rng.randf_range(1.2, 2.6)
			_box(root, Vector3(s, s * 0.7, s), Vector3((r.position.x + r.size.x + rng.randf_range(0.3, 1.8)) * Grid.CELL, s * 0.3, c.z + rng.randf_range(-sz.z * 0.4, sz.z * 0.4)), concrete, Vector3(rng.randf_range(0, 40), rng.randf_range(0, 90), rng.randf_range(0, 40)))
	else:
		_box(root, Vector3(sz.x + 0.6, 0.5, sz.z + 0.6), Vector3(c.x, top + 0.25, c.z), concrete)
		_box(root, Vector3(sz.x * 0.25, 2.4, sz.z * 0.3), Vector3(c.x + sz.x * 0.2, top + 1.7, c.z), concrete)
	# 아래층 그늘진 띠(바닥과 만나는 어둠)
	_box(root, Vector3(sz.x + 0.1, 1.2, sz.z + 0.1), Vector3(c.x, 0.6, c.z), _plain("base", Color(0.07, 0.08, 0.11), 1.0))


## 구역 밖의 먼 탑 그림자(안개에 묻힌다). 상자 몇 개.
static func _skyline(root: Node3D, rng: RandomNumberGenerator, w: float, d: float) -> void:
	var far := _plain("far", Color(0.05, 0.06, 0.09), 1.0)
	for i in 14:
		var side: int = i % 4
		var hh: float = rng.randf_range(30.0, 70.0)
		var ww: float = rng.randf_range(10.0, 22.0)
		var p := Vector3.ZERO
		match side:
			0: p = Vector3(rng.randf_range(-20.0, w + 20.0), hh / 2.0, -30.0 - rng.randf_range(0.0, 30.0))
			1: p = Vector3(rng.randf_range(-20.0, w + 20.0), hh / 2.0, d + 30.0 + rng.randf_range(0.0, 30.0))
			2: p = Vector3(-30.0 - rng.randf_range(0.0, 30.0), hh / 2.0, rng.randf_range(-20.0, d + 20.0))
			_: p = Vector3(w + 30.0 + rng.randf_range(0.0, 30.0), hh / 2.0, rng.randf_range(-20.0, d + 20.0))
		_box(root, Vector3(ww, hh, ww), p, far)


## 서 있는 고가 상판과 기둥, 무너져 누운 상판.
static func _overpass(root: Node3D) -> void:
	var concrete := _plain("concrete", FutureLayout.CONCRETE.darkened(0.2), 1.0)
	var D: Rect2 = FutureLayout.DECK
	_box(root, Vector3(D.size.x * Grid.CELL, 0.8, D.size.y * Grid.CELL), Vector3((D.position.x + D.size.x / 2.0) * Grid.CELL, FutureLayout.DECK_H, (D.position.y + D.size.y / 2.0) * Grid.CELL), concrete)
	_box(root, Vector3(D.size.x * Grid.CELL, 0.9, 0.3), Vector3((D.position.x + D.size.x / 2.0) * Grid.CELL, FutureLayout.DECK_H + 0.8, D.position.y * Grid.CELL), concrete)
	var pillar := CylinderMesh.new()
	pillar.top_radius = 0.7
	pillar.bottom_radius = 0.8
	pillar.height = FutureLayout.DECK_H
	for p in FutureLayout.PILLARS:
		var mi := MeshInstance3D.new()
		mi.mesh = pillar
		mi.material_override = concrete
		mi.position = Vector3(p.x * Grid.CELL, FutureLayout.DECK_H / 2.0, p.y * Grid.CELL)
		root.add_child(mi)
	for f in FutureLayout.FALLEN:
		var r: Rect2 = f.rect
		var c := Vector3((r.position.x + r.size.x / 2.0) * Grid.CELL, 0.6, (r.position.y + r.size.y / 2.0) * Grid.CELL)
		var along_x: bool = r.size.x >= r.size.y
		var rot := Vector3(0, 0, float(f.tilt)) if along_x else Vector3(float(f.tilt), 0, 0)
		_box(root, Vector3(r.size.x * Grid.CELL, 0.8, r.size.y * Grid.CELL), c, concrete, rot)


## 녹슨 자동차: 몸통과 지붕을 각각 MultiMesh 하나로(몸 둘 + 지붕 하나가 그려질 뿐).
static func _cars(root: Node3D, rng: RandomNumberGenerator) -> void:
	var n: int = FutureLayout.CARS.size()
	var bm := BoxMesh.new()
	bm.size = Vector3(FutureLayout.CAR_SIZE.x * Grid.CELL * 0.9, 0.7, FutureLayout.CAR_SIZE.y * Grid.CELL * 0.9)
	var cm := BoxMesh.new()
	cm.size = Vector3(bm.size.x * 0.5, 0.5, bm.size.z * 0.85)
	var body := MultiMesh.new()
	body.transform_format = MultiMesh.TRANSFORM_3D
	body.mesh = bm
	body.instance_count = n
	var cab := MultiMesh.new()
	cab.transform_format = MultiMesh.TRANSFORM_3D
	cab.mesh = cm
	cab.instance_count = n
	for i in n:
		var c: Vector3 = FutureLayout.CARS[i]
		var yaw: float = PI / 2.0 if c.z != 0.0 else 0.0
		yaw += rng.randf_range(-0.12, 0.12)
		var b := Basis(Vector3.UP, yaw)
		body.set_instance_transform(i, Transform3D(b, Vector3(c.x * Grid.CELL, 0.55, c.y * Grid.CELL)))
		cab.set_instance_transform(i, Transform3D(b, Vector3(c.x * Grid.CELL, 1.15, c.y * Grid.CELL) + b * Vector3(-0.2, 0, 0)))
	var bi := MultiMeshInstance3D.new()
	bi.multimesh = body
	bi.material_override = _plain("rust", FutureLayout.RUST, 0.85, 0.3)
	bi.visibility_range_end = SMALL_RANGE * 1.4
	root.add_child(bi)
	var ci := MultiMeshInstance3D.new()
	ci.multimesh = cab
	ci.material_override = _plain("cab", Color(0.1, 0.12, 0.17), 0.4, 0.2)
	ci.visibility_range_end = SMALL_RANGE * 1.4
	root.add_child(ci)


## 웅덩이: 매끈한 어두운 원판 하나를 나눠 쓴다(비치는 듯 낮은 거칠기).
static func _puddles(root: Node3D) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.02
	cm.radial_segments = 14
	cm.rings = 1
	var mat := _plain("puddle", Color(0.05, 0.07, 0.12), 0.05, 0.6)
	for p in FutureLayout.PUDDLES:
		var mi := MeshInstance3D.new()
		mi.mesh = cm
		mi.material_override = mat
		mi.position = Vector3(p.x * Grid.CELL, 0.03, p.y * Grid.CELL)
		mi.scale = Vector3(p.z, 1.0, p.z * 0.7)
		mi.visibility_range_end = SMALL_RANGE
		root.add_child(mi)


## 꺼져 가는 네온: 색 판 하나(방출). 깜빡임은 future.gd가 mat.emission_energy_multiplier를 흔든다. 몇 개만 곁에 작은 빛.
static func _neons(root: Node3D, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for i in FutureLayout.NEONS.size():
		var n: Dictionary = FutureLayout.NEONS[i]
		var c: Color = n.color
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 2.0
		var sz: Vector2 = n.size
		var at := Vector3(n.at.x * Grid.CELL, float(n.y), n.at.y * Grid.CELL)
		_box(root, Vector3(sz.x, sz.y, 0.12), at, m, Vector3(0, float(n.yaw), 0))
		# 간판 틀: 어두운 쇠 테두리 하나
		var back: Vector3 = Basis(Vector3.UP, deg_to_rad(float(n.yaw))) * Vector3(0, 0, -0.08)
		_box(root, Vector3(sz.x + 0.3, sz.y + 0.3, 0.06), at + back, _plain("frame", Color(0.06, 0.07, 0.1), 0.8, 0.5), Vector3(0, float(n.yaw), 0))
		if FutureLayout.NEON_LIGHTS.has(i):
			var l := OmniLight3D.new()
			l.light_color = c
			l.light_energy = 1.1
			l.omni_range = 11.0
			l.shadow_enabled = false
			l.position = at + Basis(Vector3.UP, deg_to_rad(float(n.yaw))) * Vector3(0, 0, 1.2)
			l.set_meta("base", 1.1)
			root.add_child(l)
			out.append({"mat": m, "rate": float(n.rate), "phase": rng.randf() * TAU, "light": l})
		else:
			out.append({"mat": m, "rate": float(n.rate), "phase": rng.randf() * TAU, "light": null})
	return out


## 이 구역에서만 하는 일의 모양: 단말(어두운 기둥과 차가운 화면 판)과 상자(녹슨 금속 함).
static func _extras(root: Node3D) -> void:
	var dark := _plain("term", Color(0.08, 0.09, 0.13), 0.5, 0.6)
	var screen := StandardMaterial3D.new()
	screen.albedo_color = Color(0.3, 0.7, 1.0)
	screen.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen.emission_enabled = true
	screen.emission = Color(0.3, 0.7, 1.0)
	screen.emission_energy_multiplier = 1.5
	var t := Node3D.new()
	t.name = "Terminal"
	t.position = Vector3(FutureLayout.TERMINAL_AT.x * Grid.CELL, 0, FutureLayout.TERMINAL_AT.y * Grid.CELL)
	root.add_child(t)
	_box(t, Vector3(1.0, 1.4, 0.6), Vector3(0, 0.7, 0), dark)
	_box(t, Vector3(0.8, 0.5, 0.06), Vector3(0, 1.25, -0.34), screen, Vector3(-18, 0, 0))
	var l := OmniLight3D.new()
	l.light_color = Color(0.4, 0.75, 1.0)
	l.light_energy = 0.7
	l.omni_range = 6.0
	l.position = Vector3(0, 1.4, -1.0)
	t.add_child(l)
	var chest := Node3D.new()
	chest.name = "Cache"
	chest.position = Vector3(FutureLayout.CACHE_AT.x * Grid.CELL, 0, FutureLayout.CACHE_AT.y * Grid.CELL)
	root.add_child(chest)
	var rust := _plain("rust", FutureLayout.RUST, 0.85, 0.3)
	_box(chest, Vector3(1.4, 0.7, 0.9), Vector3(0, 0.35, 0), rust)
	var lid := _box(chest, Vector3(1.46, 0.16, 0.96), Vector3(0, 0.78, 0), dark)
	lid.name = "Lid"
	var lamp := _box(chest, Vector3(0.2, 0.08, 0.04), Vector3(0, 0.55, -0.47), screen)
	lamp.name = "Lamp"


static func open_cache(chest: Node3D) -> void:
	var lid := chest.get_node_or_null("Lid") as Node3D
	if lid:
		lid.rotation_degrees.x = 55.0
		lid.position += Vector3(0, 0.25, 0.3)
	var lamp := chest.get_node_or_null("Lamp") as Node3D
	if lamp:
		lamp.visible = false
