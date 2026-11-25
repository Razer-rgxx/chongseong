class_name FutureBuilder
extends RefCounted
## 녹슨 미래 구역의 모양(docs/stranger.md 3단계). 기본 도형만. 가볍게: 메시와 재질은 나눠 쓰고, 자동차는 MultiMesh, 작은 것은 보이는 거리(visibility range)를 건다.
## 채도 낮은 차가운 파랑에 보라 조금. 세계에 글자 없음. 모든 자리는 FutureLayout에서 읽는다. 꾸밈 난수는 화면 쪽(지역 RandomNumberGenerator)이다.

const SMALL_RANGE: float = 80.0   ## 작은 소품이 보이는 거리(m)
const TEX_DIR: String = "res://assets/future/textures/"   ## Poly Haven CC0 1k jpg(CREDITS.md)
const FACADE_M: float = 12.0      ## 벽 질감 한 장이 덮는 가로·세로(m): 창 6 x 6칸
const FACADE_N: int = 6

static var _tex: Dictionary = {}


static func environment(env: Environment) -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = FutureLayout.BG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = FutureLayout.AMBIENT
	env.ambient_light_energy = 1.1
	env.fog_enabled = true
	env.fog_light_color = FutureLayout.FOG
	env.fog_density = 0.012   # 2026-11-25: 넓어진 도시의 높은 건물이 보이게 옅게
	env.fog_sky_affect = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.0
	env.ssr_enabled = true   # 젖은 길·웅덩이에 네온이 비친다(Forward+에서만, 웹판은 그냥 넘어간다)
	env.ssr_max_steps = 48


## 질감 한 벌(색·법선·거칠기). 파일이 없으면 null을 돌려준다(기본 색으로 돌아간다).
static func _pbr(key: String, id: String, scale_m: float, tint: Color, world: bool = true) -> StandardMaterial3D:
	if _tex.has(key):
		return _tex[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = 1.0
	var d: String = TEX_DIR + id + "/"
	if ResourceLoader.exists(d + "diff.jpg"):
		m.albedo_texture = load(d + "diff.jpg")
		m.roughness_texture = load(d + "rough.jpg")
		m.normal_enabled = true
		m.normal_texture = load(d + "nor.jpg")
		m.normal_scale = 0.8
	m.uv1_triplanar = true
	m.uv1_world_triplanar = world
	m.uv1_scale = Vector3.ONE / scale_m
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_tex[key] = m
	return m


static func _asphalt() -> StandardMaterial3D:
	return _pbr("asphalt", "asphalt_02", 5.0, Color(0.42, 0.45, 0.56))


static func _concrete() -> StandardMaterial3D:
	return _pbr("concrete", "cracked_concrete", 4.0, Color(0.42, 0.46, 0.58))


static func _rust() -> StandardMaterial3D:
	return _pbr("rust", "rusty_metal_02", 1.6, Color(0.45, 0.36, 0.33), false)


const KIT_C: String = "res://assets/future/models/city_commercial/"
const KIT_R: String = "res://assets/future/models/city_roads/"
const BLD_MODELS: Array[String] = ["building-a", "building-b", "building-c", "building-d", "building-f", "building-g", "building-h", "building-i", "building-l", "building-m", "building-skyscraper-a", "building-skyscraper-b", "building-skyscraper-c", "building-skyscraper-d", "building-skyscraper-e"]
const LOW_MODELS: Array[String] = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m"]
const UNIT_M: float = 9.0          ## 탑 둘레를 나눠 세우는 건물 한 채의 가로(m)
const ROAD_M: float = 8.0          ## 길 조각 한 칸(Kenney 1 단위)이 덮는 m
const ROAD_YAW: float = 0.0        ## 직선 길 조각이 놓이는 방향(0 = X 방향)
const LOW_FROM: float = 45.0       ## 먼 건물(저해상도)이 보이기 시작하는 거리(m)

static var _roof_bars: Array[Transform3D] = []


## Kenney 모델 하나의 메시와, 장면 뿌리에서 그 메시까지의 변환, 그 변환을 거친 경계 상자.
static func _kit(path: String) -> Dictionary:
	if _tex.has(path):
		return _tex[path]
	var out: Dictionary = {}
	if ResourceLoader.exists(path):
		var root: Node = (load(path) as PackedScene).instantiate()
		var found: Array = []
		_find_mesh(root, Transform3D.IDENTITY, found, root)
		if not found.is_empty():
			var mesh: Mesh = found[0].mesh
			var xf: Transform3D = found[0].xf
			out = {"mesh": mesh, "xf": xf, "aabb": xf * mesh.get_aabb()}
		root.free()
	_tex[path] = out
	return out


static func _find_mesh(n: Node, xf: Transform3D, found: Array, root: Node) -> void:
	var t: Transform3D = xf
	if n != root and n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and found.is_empty():
		found.append({"mesh": (n as MeshInstance3D).mesh, "xf": t})
		return
	for c in n.get_children():
		_find_mesh(c, t, found, root)


## 건물 재질(셰이더 하나를 다 나눠 쓴다).
static func _kit_building_mat() -> Material:
	if _tex.has("kit_bld"):
		return _tex.kit_bld
	var sm := ShaderMaterial.new()
	sm.shader = load("res://assets/future/kit_building.gdshader")
	sm.set_shader_parameter("colormap", load(KIT_C + "Textures/colormap.png"))
	sm.set_shader_parameter("conc_diff", load(TEX_DIR + "concrete_wall_004/diff.jpg"))
	sm.set_shader_parameter("conc_rough", load(TEX_DIR + "concrete_wall_004/rough.jpg"))
	# 2026-11-25 "미래들은 다 이런 느낌으로": 폐허 블록도 창이 조금 더 켜지고 분홍 창이 섞인다(네온 시가보다는 어둡게)
	sm.set_shader_parameter("warm_r", 0.12)
	sm.set_shader_parameter("cool_r", 0.22)
	sm.set_shader_parameter("pink_r", 0.27)
	sm.set_shader_parameter("dark_r", 0.42)
	sm.set_shader_parameter("flicker", 0.03)
	_tex["kit_bld"] = sm
	return sm


static func _kit_road_mat() -> Material:
	if _tex.has("kit_road"):
		return _tex.kit_road
	var sm := ShaderMaterial.new()
	sm.shader = load("res://assets/future/kit_road.gdshader")
	sm.set_shader_parameter("colormap", load(KIT_R + "Textures/colormap.png"))
	sm.set_shader_parameter("diff", load(TEX_DIR + "asphalt_02/diff.jpg"))
	sm.set_shader_parameter("rough_t", load(TEX_DIR + "asphalt_02/rough.jpg"))
	_tex["kit_road"] = sm
	return sm


## 모델마다 변환을 모아 두었다가 MultiMesh 하나씩으로 낸다. groups: 모델 경로 → Array[Transform3D].
static func _flush(root: Node3D, groups: Dictionary, mat: Material, vis_begin: float = 0.0, vis_end: float = 0.0) -> void:
	for path in groups:
		var info: Dictionary = _kit(String(path))
		if info.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = info.mesh
		var xs: Array = groups[path]
		mm.instance_count = xs.size()
		for i in xs.size():
			mm.set_instance_transform(i, xs[i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = mat
		mi.visibility_range_begin = vis_begin
		mi.visibility_range_begin_margin = 8.0 if vis_begin > 0.0 else 0.0
		mi.visibility_range_end = vis_end
		root.add_child(mi)


static func _put(groups: Dictionary, path: String, world: Transform3D) -> void:
	var info: Dictionary = _kit(path)
	if info.is_empty():
		return
	if not groups.has(path):
		groups[path] = []
	groups[path].append(world * (info.xf as Transform3D))


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
	_box(root, Vector3(W + 160.0, 0.4, D + 160.0), Vector3(W / 2.0, -0.2, D / 2.0), _asphalt())
	_roads(root, rng)
	_roof_bars.clear()
	var groups: Dictionary = {}
	for t in FutureLayout.TOWERS:
		_tower(groups, t, rng)
	_flush(root, groups, _kit_building_mat())
	_skyline(root, rng, W, D)
	NeonDistrict.build(root, rng)   # 2026-11-25 네온 시가(동쪽·남쪽으로 넓힌 곳)
	_overpass(root)
	_cars(root, rng)
	_puddles(root, rng)
	_debris(root, rng)
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


## 거리: Kenney 길 조각(직선·교차로)을 MultiMesh로 깔고, 갈라진 포장 조각과 틈, 길가 소품을 얹는다. 동서 길(고가 밑)과 남북 길(시작 자리에서 올라온다).
static func _roads(root: Node3D, rng: RandomNumberGenerator) -> void:
	var crack := _plain("crack", Color(0.03, 0.035, 0.05), 1.0)
	var pave := _concrete()
	for i in 9:
		_box(root, Vector3(rng.randf_range(5.0, 11.0), 0.016, rng.randf_range(4.0, 8.0)), Vector3(rng.randf_range(20.0, 60.0) * Grid.CELL, 0.008, rng.randf_range(20.0, 54.0) * Grid.CELL), pave, Vector3(0, rng.randf_range(0.0, 90.0), 0))
	var g: Dictionary = {}
	var straight: String = KIT_R + "road-straight.glb"
	var cross: String = KIT_R + "road-crossroad.glb"
	var flat := Basis.from_scale(Vector3(ROAD_M, 0.1, ROAD_M))
	var zc: float = 32.0 * Grid.CELL
	var xc: float = 40.0 * Grid.CELL
	for k in range(5, 16):
		var org := Vector3(8.0 * k, 0.02, zc)
		if k == 10:
			_put(g, cross, Transform3D(flat, org))
		else:
			_put(g, straight, Transform3D(Basis(Vector3.UP, ROAD_YAW) * flat, org))
	for m in range(-3, 8):
		if m == 0:
			continue
		_put(g, straight, Transform3D(Basis(Vector3.UP, ROAD_YAW + PI / 2.0) * flat, Vector3(xc, 0.02, zc + ROAD_M * m)))
	_flush(root, g, _kit_road_mat())
	_box(root, Vector3(0.12, 0.02, 9.0), Vector3(34.0 * Grid.CELL, 0.03, 42.0 * Grid.CELL), crack, Vector3(0, 25, 0))
	_box(root, Vector3(0.12, 0.02, 6.0), Vector3(58.0 * Grid.CELL, 0.03, 30.0 * Grid.CELL), crack, Vector3(0, -40, 0))
	# 길가 소품(Kenney 길 모음): 쓰레기통, 공사 차단대, 콘, 가로등
	var p: Dictionary = {}
	var rs := Vector3(ROAD_M, ROAD_M, ROAD_M)
	for at in [Vector2(27, 42), Vector2(58, 20), Vector2(24, 20), Vector2(66, 48)]:
		_put(p, KIT_R + "dumpster.glb", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(rs), Vector3(at.x * Grid.CELL, 0, at.y * Grid.CELL)))
	for i in 8:
		_put(p, KIT_R + "construction-barrier.glb", Transform3D(Basis(Vector3.UP, rng.randf_range(-0.3, 0.3) + (PI / 2.0 if i > 4 else 0.0)).scaled(rs), Vector3((41.0 + i * 1.6) * Grid.CELL, 0, 29.0 * Grid.CELL)))
	for i in 10:
		_put(p, KIT_R + "construction-cone.glb", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(rs), Vector3(rng.randf_range(36.0, 46.0) * Grid.CELL, 0, rng.randf_range(36.0, 52.0) * Grid.CELL)))
	for at in [Vector2(37.5, 44), Vector2(42.5, 48), Vector2(37.5, 24), Vector2(42.5, 24)]:
		_put(p, KIT_R + "light-square-double.glb", Transform3D(Basis(Vector3.UP, 0.0 if at.x < 40.0 else PI).scaled(rs), Vector3(at.x * Grid.CELL, 0, at.y * Grid.CELL)))
	_flush(root, p, _kit_road_mat(), 0.0, SMALL_RANGE * 1.6)


## 탑 하나: 둘레를 건물 모델(Kenney)로 채운다. 한 채는 가로 UNIT_M쯤, 발자국이 탑의 막힘 사각형을 딱 채운다. 높이는 탑의 h에 맞춘다.
## 무너진 탑은 동쪽 절반이 낮고 지붕에서 철근이 선다.
static func _tower(groups: Dictionary, t: Dictionary, rng: RandomNumberGenerator) -> void:
	var r: Rect2 = t.rect
	var h: float = float(t.h)
	var sx: float = r.size.x * Grid.CELL
	var sz: float = r.size.y * Grid.CELL
	var nx: int = maxi(1, roundi(sx / UNIT_M))
	var nz: int = maxi(1, roundi(sz / UNIT_M))
	var cx: float = sx / nx
	var cz: float = sz / nz
	for ix in nx:
		for iz in nz:
			if not (ix == 0 or ix == nx - 1 or iz == 0 or iz == nz - 1):
				continue   # 속은 안 보인다
			var yaw: float = 0.0
			if iz == 0:
				yaw = PI
			elif iz == nz - 1:
				yaw = 0.0
			elif ix == 0:
				yaw = -PI / 2.0
			else:
				yaw = PI / 2.0
			var rotated: bool = iz != 0 and iz != nz - 1
			var hh: float = h * rng.randf_range(0.88, 1.0)
			var low: bool = t.get("ruin", false) and ix >= nx / 2
			if low:
				hh = h * rng.randf_range(0.45, 0.65)
			var tx: float = cz if rotated else cx
			var tz: float = cx if rotated else cz
			# 가로 대비 높이가 가장 가까운 모델(조금 흔들어)
			var want: float = hh / maxf(cx, cz)
			var best: String = ""
			var best_s: float = 1e9
			for nm in BLD_MODELS:
				var info: Dictionary = _kit(KIT_C + nm + ".glb")
				if info.is_empty():
					continue
				var ab: AABB = info.aabb
				var sc: float = absf(log((ab.size.y / maxf(ab.size.x, ab.size.z)) / want)) + rng.randf() * 0.3
				if sc < best_s:
					best_s = sc
					best = nm
			if best == "":
				continue
			var path: String = KIT_C + best + ".glb"
			var ab: AABB = _kit(path).aabb
			var c: Vector3 = ab.position + ab.size * 0.5
			var wx: float = r.position.x * Grid.CELL + (ix + 0.5) * cx
			var wz: float = r.position.y * Grid.CELL + (iz + 0.5) * cz
			var body := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(tx / ab.size.x, hh / ab.size.y, tz / ab.size.z))
			var xf := Transform3D(body, Vector3(wx, 0, wz)) * Transform3D(Basis(), Vector3(-c.x, -ab.position.y, -c.z))
			_put_raw(groups, path, xf)
			if low:
				for i in 3:
					var rb := Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5))).scaled(Vector3(1.0, rng.randf_range(2.0, 4.0), 1.0))
					_roof_bars.append(Transform3D(rb, Vector3(wx + rng.randf_range(-cx, cx) * 0.35, hh + 0.4, wz + rng.randf_range(-cz, cz) * 0.35)))


## _put과 같지만 변환에 모델의 메시 변환을 이미 곱했다(경계 상자 기준으로 맞춘 경우).
static func _put_raw(groups: Dictionary, path: String, xf_with_aabb_space: Transform3D) -> void:
	var info: Dictionary = _kit(path)
	if info.is_empty():
		return
	if not groups.has(path):
		groups[path] = []
	groups[path].append(xf_with_aabb_space * (info.xf as Transform3D))


## 구역 밖의 먼 건물: 저해상도 Kenney 모델을 크게 키워 안개에 묻는다. LOW_FROM보다 가까우면 안 그린다(가까운 쪽은 진짜 건물).
static func _skyline(root: Node3D, rng: RandomNumberGenerator, w: float, d: float) -> void:
	var g: Dictionary = {}
	# 2026-11-25: 구역이 넓어져 둘레를 촘촘한 높은 건물 벽으로(창이 켜진 네온 시가 재질)
	for i in 64:
		var side: int = i % 4
		var hh: float = rng.randf_range(40.0, 130.0)
		var ww: float = rng.randf_range(12.0, 26.0)
		var p := Vector3.ZERO
		match side:
			0: p = Vector3(rng.randf_range(-20.0, w + 20.0), 0.0, -18.0 - rng.randf_range(0.0, 40.0))
			1: p = Vector3(rng.randf_range(-20.0, w + 20.0), 0.0, d + 18.0 + rng.randf_range(0.0, 40.0))
			2: p = Vector3(-18.0 - rng.randf_range(0.0, 40.0), 0.0, rng.randf_range(-20.0, d + 20.0))
			_: p = Vector3(w + 18.0 + rng.randf_range(0.0, 40.0), 0.0, rng.randf_range(-20.0, d + 20.0))
		var path: String = KIT_C + "low-detail-building-%s.glb" % LOW_MODELS[rng.randi() % LOW_MODELS.size()]
		var info: Dictionary = _kit(path)
		if info.is_empty():
			continue
		var ab: AABB = info.aabb
		var c: Vector3 = ab.position + ab.size * 0.5
		var body := Basis(Vector3.UP, float(rng.randi() % 4) * PI / 2.0) * Basis.from_scale(Vector3(ww / ab.size.x, hh / ab.size.y, ww / ab.size.z))
		_put_raw(g, path, Transform3D(body, p) * Transform3D(Basis(), Vector3(-c.x, -ab.position.y, -c.z)))
	_flush(root, g, NeonDistrict.mat_buildings(), LOW_FROM)


## 서 있는 고가 상판과 기둥, 무너져 누운 상판.
static func _overpass(root: Node3D) -> void:
	var concrete := _concrete()
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
	var wm := BoxMesh.new()
	wm.size = Vector3(bm.size.x * 0.94, 0.3, bm.size.z * 1.03)
	var wheels := MultiMesh.new()
	wheels.transform_format = MultiMesh.TRANSFORM_3D
	wheels.mesh = wm
	wheels.instance_count = n
	var body := MultiMesh.new()
	body.transform_format = MultiMesh.TRANSFORM_3D
	body.mesh = bm
	body.use_colors = true
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
		body.set_instance_color(i, [Color(1, 1, 1), Color(0.6, 0.7, 0.95), Color(0.9, 0.62, 0.5), Color(0.45, 0.5, 0.62), Color(0.75, 0.75, 0.8)][rng.randi() % 5])
		wheels.set_instance_transform(i, Transform3D(b, Vector3(c.x * Grid.CELL, 0.2, c.y * Grid.CELL)))
		cab.set_instance_transform(i, Transform3D(b, Vector3(c.x * Grid.CELL, 1.15, c.y * Grid.CELL) + b * Vector3(-0.2, 0, 0)))
	var bi := MultiMeshInstance3D.new()
	bi.multimesh = body
	var carmat: StandardMaterial3D = _rust().duplicate()
	carmat.vertex_color_use_as_albedo = true
	bi.material_override = carmat
	bi.visibility_range_end = SMALL_RANGE * 1.4
	root.add_child(bi)
	var wi := MultiMeshInstance3D.new()
	wi.multimesh = wheels
	wi.material_override = _plain("tire", Color(0.025, 0.03, 0.04), 0.9)
	wi.visibility_range_end = SMALL_RANGE * 1.4
	root.add_child(wi)
	var ci := MultiMeshInstance3D.new()
	ci.multimesh = cab
	ci.material_override = _plain("cab", Color(0.1, 0.12, 0.17), 0.4, 0.2)
	ci.visibility_range_end = SMALL_RANGE * 1.4
	root.add_child(ci)


## 웅덩이: 매끈한 어두운 원판들을 MultiMesh 하나로(거칠기가 아주 낮아 네온 빛이 희미하게 번쩍인다). 정해진 것 + 꾸밈용 여럿.
static func _puddles(root: Node3D, rng: RandomNumberGenerator) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.02
	cm.radial_segments = 16
	cm.rings = 1
	var spots: Array[Vector3] = FutureLayout.PUDDLES.duplicate()
	for i in 14:
		spots.append(Vector3(rng.randf_range(14.0, 66.0), rng.randf_range(16.0, 54.0), rng.randf_range(1.0, 3.4)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cm
	mm.instance_count = spots.size()
	for i in spots.size():
		var p: Vector3 = spots[i]
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(p.z, 1.0, p.z * rng.randf_range(0.55, 0.85)))
		mm.set_instance_transform(i, Transform3D(b, Vector3(p.x * Grid.CELL, 0.03, p.y * Grid.CELL)))
	var mat := _plain("puddle", Color(0.035, 0.045, 0.08), 0.03, 0.85)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.visibility_range_end = SMALL_RANGE * 1.3
	root.add_child(mi)


## 잔해: 콘크리트 덩어리와 삐져나온 철근을 MultiMesh로, 쓰러진 가로등 하나.
static func _debris(root: Node3D, rng: RandomNumberGenerator) -> void:
	var rects: Array = []
	for t in FutureLayout.TOWERS:
		rects.append((t.rect as Rect2).grow(0.5))
	var heaps: Array[Vector2] = []
	for t in FutureLayout.TOWERS:
		if t.get("ruin", false):
			var r: Rect2 = t.rect
			heaps.append(Vector2(r.position.x + r.size.x + 1.5, r.position.y + r.size.y * 0.5))
			heaps.append(Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y + 1.2))
	heaps.append(Vector2(44.0, 33.0))
	heaps.append(Vector2(54.0, 42.0))
	var chunks: Array[Transform3D] = []
	var bars: Array[Transform3D] = []
	for h in heaps:
		for i in 9:
			var at := Vector2(h.x + rng.randf_range(-2.5, 2.5), h.y + rng.randf_range(-2.5, 2.5))
			var ok: bool = at.x > 1.0 and at.y > 1.0 and at.x < FutureLayout.SIZE.x - 1.0 and at.y < FutureLayout.SIZE.y - 1.0
			for r in rects:
				if (r as Rect2).has_point(at):
					ok = false
			if not ok:
				continue
			var sc := Vector3(rng.randf_range(0.4, 1.6), rng.randf_range(0.3, 0.9), rng.randf_range(0.4, 1.4))
			var b := Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))).scaled(sc)
			chunks.append(Transform3D(b, Vector3(at.x * Grid.CELL, sc.y * 0.3, at.y * Grid.CELL)))
			if i % 3 == 0:
				var rb := Basis.from_euler(Vector3(rng.randf_range(-0.9, 0.9), rng.randf() * TAU, rng.randf_range(-0.9, 0.9))).scaled(Vector3(1.0, rng.randf_range(1.5, 3.6), 1.0))
				bars.append(Transform3D(rb, Vector3(at.x * Grid.CELL, 0.5, at.y * Grid.CELL)))
	bars.append_array(_roof_bars)
	var cm := BoxMesh.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.035
	rm.bottom_radius = 0.045
	rm.height = 1.0
	rm.radial_segments = 5
	rm.rings = 1
	_multi(root, cm, chunks, _concrete(), SMALL_RANGE * 1.5)
	_multi(root, rm, bars, _plain("rebar", FutureLayout.RUST.darkened(0.25), 0.75, 0.55), SMALL_RANGE)
	# 쓰러진 가로등: 기둥, 굽은 팔, 꺼진 머리
	var lamp := Node3D.new()
	lamp.position = Vector3(46.0 * Grid.CELL, 0.0, 17.0 * Grid.CELL)
	lamp.rotation_degrees = Vector3(0, 12, 0)
	root.add_child(lamp)
	var metal := _rust()
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.09
	pm.bottom_radius = 0.15
	pm.height = 7.0
	pm.radial_segments = 8
	pole.mesh = pm
	pole.material_override = metal
	pole.rotation_degrees = Vector3(0, 0, 90.0 - 3.0)
	pole.position = Vector3(0, 0.22, 0)
	lamp.add_child(pole)
	_box(lamp, Vector3(1.8, 0.1, 0.1), Vector3(-3.9, 0.55, 0), metal, Vector3(0, 0, 18))
	_box(lamp, Vector3(0.7, 0.18, 0.3), Vector3(-4.7, 0.62, 0), _plain("lamphead", Color(0.1, 0.11, 0.15), 0.5, 0.6), Vector3(0, 0, 18))
	_box(lamp, Vector3(0.5, 0.04, 0.2), Vector3(-4.7, 0.53, 0), _plain("lampbulb", Color(0.2, 0.22, 0.26), 0.2, 0.2), Vector3(0, 0, 18))


static func _multi(root: Node3D, mesh: Mesh, xf: Array[Transform3D], mat: Material, vis: float) -> void:
	if xf.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.visibility_range_end = vis
	root.add_child(mi)


## 네온 간판의 마디들: 가는 막대를 끊어 이은 모양. 반환: [{pos, size, rot}]. 글자 없음.
static func _neon_segments(shape: String, sz: Vector2) -> Array:
	var out: Array = []
	var horiz: bool = sz.x >= sz.y
	var L: float = maxf(sz.x, sz.y)
	var T: float = clampf(minf(sz.x, sz.y) * 0.4, 0.14, 0.32)
	var seg := func(along: float, perp: float, ln: float, ang: float) -> Dictionary:
		return {
			"pos": Vector3(along, perp, 0.0) if horiz else Vector3(perp, along, 0.0),
			"size": Vector3(ln, T, 0.1) if horiz else Vector3(T, ln, 0.1),
			"rot": Vector3(0, 0, ang)}
	match shape:
		"frame":
			var t: float = 0.18
			out.append({"pos": Vector3(0, sz.y / 2.0 - t / 2.0, 0), "size": Vector3(sz.x, t, 0.1), "rot": Vector3.ZERO})
			out.append({"pos": Vector3(0, -sz.y / 2.0 + t / 2.0, 0), "size": Vector3(sz.x, t, 0.1), "rot": Vector3.ZERO})
			out.append({"pos": Vector3(-sz.x / 2.0 + t / 2.0, 0, 0), "size": Vector3(t, sz.y - 2.0 * t, 0.1), "rot": Vector3.ZERO})
			out.append({"pos": Vector3(sz.x / 2.0 - t / 2.0, 0, 0), "size": Vector3(t, sz.y - 2.0 * t, 0.1), "rot": Vector3.ZERO})
		"arrow":
			var u: float = L * 0.7 / 3.0
			for k in 3:
				out.append(seg.call(-L * 0.5 + u * (k + 0.5), 0.0, u * 0.8, 0.0))
			out.append(seg.call(L * 0.5 - L * 0.12, L * 0.11, L * 0.3, 40.0))
			out.append(seg.call(L * 0.5 - L * 0.12, -L * 0.11, L * 0.3, -40.0))
		_:
			var u: float = L / 5.0
			for k in 5:
				out.append(seg.call(-L * 0.5 + u * (k + 0.5), 0.0, u * 0.78, 0.0))
	return out


## 꺼져 가는 네온: 마디마다 색 판(방출). 켜진 마디는 판 하나를 나눠 쓰고, 꺼진 마디는 어두운 쇠다. 깜빡임은 future.gd가 mat.emission_energy_multiplier를 흔든다. 몇 개만 곁에 작은 빛.
static func _neons(root: Node3D, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var dead_mat := _plain("neon_dead", Color(0.05, 0.06, 0.08), 0.6, 0.3)
	var frame_mat := _plain("frame", Color(0.06, 0.07, 0.1), 0.8, 0.5)
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
		var yaw: float = float(n.yaw)
		var at := Vector3(n.at.x * Grid.CELL, float(n.y), n.at.y * Grid.CELL)
		var sign := Node3D.new()
		sign.position = at
		sign.rotation_degrees = Vector3(0, yaw, 0)
		root.add_child(sign)
		var dead: Array = n.dead
		var segs: Array = _neon_segments(String(n.shape), sz)
		for k in segs.size():
			_box(sign, segs[k].size, segs[k].pos, dead_mat if dead.has(k) else m, segs[k].rot)
		_box(sign, Vector3(sz.x + 0.3, sz.y + 0.3, 0.06), Vector3(0, 0, -0.08), frame_mat)   # 어두운 쇠 뒤판
		var l: OmniLight3D = null
		if FutureLayout.NEON_LIGHTS.has(i):
			l = OmniLight3D.new()
			l.light_color = c
			l.light_energy = 1.1
			l.omni_range = 11.0
			l.shadow_enabled = false
			l.position = at + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, 1.2)
			l.set_meta("base", 1.1)
			root.add_child(l)
		out.append({"mat": m, "rate": float(n.rate), "phase": rng.randf() * TAU, "light": l, "mode": String(n.mode)})
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
	var rust := _rust()
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
